import { useEffect, useMemo, useState } from 'react'
import type { ChangeEvent } from 'react'
import {
  createDemoProductDetail,
  freshDemoCategories,
  freshDemoOptionTemplates,
  freshDemoProducts,
} from '../../data/demo'
import {
  applyStoreOptionTemplateToAll,
  createStoreOptionTemplate,
  createSellerCategory,
  createSellerProduct,
  deleteSellerCategory,
  deleteStoreOptionTemplate,
  deleteSellerProduct,
  getSellerCategories,
  getSellerProductDetail,
  getSellerProducts,
  getStoreOptionTemplates,
  getStoreOptionTemplateUsage,
  replaceProductOptions,
  updateSellerProduct,
  updateSellerCategory,
  updateProductAvailability,
  uploadSellerProductImage,
} from '../../services/api'
import type {
  ProductDetail,
  ProductOptionGroupInput,
  SellerCategory,
  SellerConnection,
  SellerProduct,
  StoreOptionTemplate,
  StoreOptionTemplateUsage,
  StoreRole,
} from '../../types'
import {
  ProductOptionEditor,
  type EditableOptionGroup,
} from './ProductOptionEditor'

type Props = {
  connection: SellerConnection | null
  storeRole?: StoreRole
  onError: (message: string | null) => void
}

function money(value: number) {
  return `${value.toLocaleString('ko-KR')}원`
}

const MAX_IMAGE_SIZE = 10 * 1024 * 1024
const ACCEPTED_IMAGE_TYPES = ['image/jpeg', 'image/png', 'image/webp']

function readFileAsDataUrl(file: File) {
  return new Promise<string>((resolve, reject) => {
    const reader = new FileReader()
    reader.addEventListener('load', () => resolve(String(reader.result)))
    reader.addEventListener('error', () => reject(new Error('이미지를 미리 볼 수 없습니다.')))
    reader.readAsDataURL(file)
  })
}

export function ProductManagement({ connection, storeRole, onError }: Props) {
  const isDemo = !connection
  const canManage = isDemo || storeRole === 'OWNER' || storeRole === 'MANAGER'
  const [products, setProducts] = useState<SellerProduct[]>(() =>
    isDemo ? freshDemoProducts() : [],
  )
  const [categories, setCategories] = useState<SellerCategory[]>(() =>
    isDemo ? freshDemoCategories() : [],
  )
  const [details, setDetails] = useState<Record<number, ProductDetail>>({})
  const [category, setCategory] = useState('전체')
  const [query, setQuery] = useState('')
  const [loading, setLoading] = useState(!isDemo)
  const [updatingId, setUpdatingId] = useState<number | null>(null)
  const [showCategoryForm, setShowCategoryForm] = useState(false)
  const [editingCategory, setEditingCategory] = useState<SellerCategory | null>(null)
  const [newCategoryName, setNewCategoryName] = useState('')
  const [showCategoryDeleteConfirm, setShowCategoryDeleteConfirm] = useState(false)
  const [updatingCategoryId, setUpdatingCategoryId] = useState<number | null>(null)
  const [showProductForm, setShowProductForm] = useState(false)
  const [editingProduct, setEditingProduct] = useState<SellerProduct | null>(null)
  const [productCategoryId, setProductCategoryId] = useState(() =>
    isDemo ? String(freshDemoCategories()[0]?.categoryId ?? '') : '',
  )
  const [productName, setProductName] = useState('')
  const [productDescription, setProductDescription] = useState('')
  const [productPrice, setProductPrice] = useState('')
  const [productImageFile, setProductImageFile] = useState<File | null>(null)
  const [productImagePreview, setProductImagePreview] = useState<string | null>(null)
  const [removeProductImage, setRemoveProductImage] = useState(false)
  const [showDeleteConfirm, setShowDeleteConfirm] = useState(false)
  const [optionProduct, setOptionProduct] = useState<SellerProduct | null>(null)
  const [optionTemplates, setOptionTemplates] = useState<StoreOptionTemplate[]>(
    () => (isDemo ? freshDemoOptionTemplates() : []),
  )
  const [showOptions, setShowOptions] = useState(false)

  useEffect(() => {
    const timer = window.setTimeout(() => {
      if (!connection) {
        const categoryData = freshDemoCategories()
        setProducts(freshDemoProducts())
        setCategories(categoryData)
        setProductCategoryId(
          (current) => current || String(categoryData[0]?.categoryId ?? ''),
        )
        setLoading(false)
        return
      }
      setLoading(true)
      void Promise.all([
        getSellerProducts(connection),
        getSellerCategories(connection),
      ])
        .then(([productData, categoryData]) => {
          setProducts(productData)
          setCategories(categoryData)
          setProductCategoryId(
            (current) => current || String(categoryData[0]?.categoryId ?? ''),
          )
          onError(null)
        })
        .catch((caught: unknown) =>
          onError(
            caught instanceof Error
              ? caught.message
              : '상품 목록을 불러오지 못했습니다.',
          ),
        )
        .finally(() => setLoading(false))
    }, 0)
    return () => window.clearTimeout(timer)
  }, [connection, onError])

  const visibleProducts = useMemo(() => {
    const normalized = query.trim().toLocaleLowerCase('ko-KR')
    return products.filter(
      (product) =>
        (category === '전체' || product.categoryName === category) &&
        (!normalized ||
          product.name.toLocaleLowerCase('ko-KR').includes(normalized)),
    )
  }, [category, products, query])
  const soldOutCount = products.filter((product) => product.soldOut).length
  const hiddenCount = products.filter(
    (product) => !product.qrWebEnabled,
  ).length

  async function update(
    product: SellerProduct,
    changes: Partial<
      Pick<SellerProduct, 'soldOut' | 'qrWebEnabled' | 'customerAppEnabled'>
    >,
  ) {
    setUpdatingId(product.productId)
    try {
      let updated: SellerProduct
      if (isDemo) {
        updated = {
          ...product,
          ...changes,
          availableForQr:
            !(changes.soldOut ?? product.soldOut) &&
            (changes.qrWebEnabled ?? product.qrWebEnabled),
        }
      } else {
        const detail = await updateProductAvailability(
          connection,
          product,
          changes,
        )
        updated = detail.product
      }
      setProducts((current) =>
        current.map((item) =>
          item.productId === updated.productId ? updated : item,
        ),
      )
      onError(null)
    } catch (caught) {
      onError(
        caught instanceof Error
          ? caught.message
          : '판매 상태를 변경하지 못했습니다.',
      )
    } finally {
      setUpdatingId(null)
    }
  }

  function openCategoryEditor(categoryToEdit: SellerCategory | null = null) {
    setEditingCategory(categoryToEdit)
    setNewCategoryName(categoryToEdit?.name ?? '')
    setShowCategoryDeleteConfirm(false)
    setShowCategoryForm(true)
    onError(null)
  }

  function closeCategoryEditor() {
    setShowCategoryForm(false)
    setEditingCategory(null)
    setNewCategoryName('')
    setShowCategoryDeleteConfirm(false)
  }

  async function saveCategory() {
    const name = newCategoryName.trim()
    if (!name) {
      onError('카테고리 이름을 입력해 주세요.')
      return
    }
    const duplicate = categories.some(
      (item) =>
        item.categoryId !== editingCategory?.categoryId &&
        item.name.toLocaleLowerCase('ko-KR') === name.toLocaleLowerCase('ko-KR'),
    )
    if (duplicate) {
      onError('같은 이름의 카테고리가 이미 있습니다.')
      return
    }

    const processingId = editingCategory?.categoryId ?? -1
    setUpdatingCategoryId(processingId)
    try {
      const displayOrder = editingCategory
        ? editingCategory.displayOrder
        : Math.max(-1, ...categories.map((item) => item.displayOrder)) + 1
      const saved = isDemo
        ? editingCategory
          ? { ...editingCategory, name }
          : {
              categoryId:
                Math.max(0, ...categories.map((item) => item.categoryId)) + 1,
              name,
              displayOrder,
              status: 'ACTIVE' as const,
            }
        : editingCategory
          ? await updateSellerCategory(
              connection,
              editingCategory.categoryId,
              name,
              displayOrder,
            )
          : await createSellerCategory(connection, name, displayOrder)

      setCategories((current) =>
        editingCategory
          ? current
              .map((item) =>
                item.categoryId === saved.categoryId ? saved : item,
              )
              .sort((left, right) => left.displayOrder - right.displayOrder)
          : [...current, saved],
      )
      if (editingCategory) {
        setProducts((current) =>
          current.map((product) =>
            product.categoryId === saved.categoryId
              ? { ...product, categoryName: saved.name }
              : product,
          ),
        )
        setCategory((current) =>
          current === editingCategory.name ? saved.name : current,
        )
      } else {
        setProductCategoryId(String(saved.categoryId))
      }
      closeCategoryEditor()
      onError(null)
    } catch (caught) {
      onError(
        caught instanceof Error
          ? caught.message
          : `카테고리를 ${editingCategory ? '수정' : '생성'}하지 못했습니다.`,
      )
    } finally {
      setUpdatingCategoryId(null)
    }
  }

  async function removeCategory() {
    if (!editingCategory) return
    const hasProducts = products.some(
      (product) => product.categoryId === editingCategory.categoryId,
    )
    if (hasProducts) {
      onError('이 카테고리에 등록된 상품이 있습니다. 상품을 먼저 삭제해 주세요.')
      setShowCategoryDeleteConfirm(false)
      return
    }

    setUpdatingCategoryId(editingCategory.categoryId)
    try {
      if (!isDemo) {
        await deleteSellerCategory(connection, editingCategory.categoryId)
      }
      const deletedId = editingCategory.categoryId
      const deletedName = editingCategory.name
      const remaining = categories.filter((item) => item.categoryId !== deletedId)
      setCategories(remaining)
      setCategory((current) => (current === deletedName ? '전체' : current))
      setProductCategoryId((current) =>
        current === String(deletedId)
          ? String(remaining[0]?.categoryId ?? '')
          : current,
      )
      closeCategoryEditor()
      onError(null)
    } catch (caught) {
      onError(
        caught instanceof Error
          ? caught.message
          : '카테고리를 삭제하지 못했습니다. 연결된 상품이 없는지 확인해 주세요.',
      )
    } finally {
      setUpdatingCategoryId(null)
    }
  }

  function resetProductForm() {
    setEditingProduct(null)
    setProductCategoryId(String(categories[0]?.categoryId ?? ''))
    setProductName('')
    setProductDescription('')
    setProductPrice('')
    setProductImageFile(null)
    setProductImagePreview(null)
    setRemoveProductImage(false)
    setShowDeleteConfirm(false)
  }

  function openNewProductForm() {
    resetProductForm()
    setShowProductForm(true)
  }

  function openProductEditor(product: SellerProduct) {
    setEditingProduct(product)
    setProductCategoryId(String(product.categoryId))
    setProductName(product.name)
    setProductDescription(product.description ?? '')
    setProductPrice(String(product.basePrice))
    setProductImageFile(null)
    setProductImagePreview(product.imageUrl)
    setRemoveProductImage(false)
    setShowDeleteConfirm(false)
    setShowProductForm(true)
  }

  function closeProductForm() {
    setShowProductForm(false)
    resetProductForm()
  }

  async function selectProductImage(event: ChangeEvent<HTMLInputElement>) {
    const file = event.target.files?.[0]
    if (!file) return
    if (!ACCEPTED_IMAGE_TYPES.includes(file.type)) {
      event.target.value = ''
      onError('JPG, PNG 또는 WEBP 이미지 파일만 첨부할 수 있습니다.')
      return
    }
    if (file.size > MAX_IMAGE_SIZE) {
      event.target.value = ''
      onError('이미지는 최대 10MB까지 첨부할 수 있습니다.')
      return
    }
    try {
      const preview = await readFileAsDataUrl(file)
      setProductImageFile(file)
      setProductImagePreview(preview)
      setRemoveProductImage(false)
      onError(null)
    } catch (caught) {
      onError(caught instanceof Error ? caught.message : '이미지를 미리 볼 수 없습니다.')
    }
  }

  async function saveProduct() {
    const categoryId = Number(productCategoryId)
    const name = productName.trim()
    const basePrice = Number(productPrice)
    const selectedCategory = categories.find(
      (item) => item.categoryId === categoryId,
    )
    if (
      !selectedCategory ||
      !name ||
      !productPrice.trim() ||
      !Number.isInteger(basePrice) ||
      basePrice < 0
    ) {
      onError('카테고리, 상품 이름, 0원 이상의 판매가를 확인해 주세요.')
      return
    }
    const processingId = editingProduct?.productId ?? -2
    setUpdatingId(processingId)
    try {
      const imageUrl = productImageFile
        ? isDemo
          ? productImagePreview
          : await uploadSellerProductImage(connection, productImageFile)
        : removeProductImage
          ? null
          : editingProduct?.imageUrl ?? null
      const payload = {
        categoryId,
        name,
        description: productDescription.trim() || null,
        imageUrl,
        basePrice,
      }
      let detail: ProductDetail
      if (isDemo) {
        const savedProduct: SellerProduct = editingProduct
          ? {
              ...editingProduct,
              ...payload,
              categoryName: selectedCategory.name,
            }
          : {
              productId:
                Math.max(0, ...products.map((item) => item.productId)) + 1,
              ...payload,
              categoryName: selectedCategory.name,
              status: 'ACTIVE',
              soldOut: false,
              availableForQr: true,
              salesStartAt: null,
              salesEndAt: null,
              qrWebEnabled: true,
              customerAppEnabled: true,
            }
        const existingDetail = editingProduct
          ? (details[editingProduct.productId] ??
            createDemoProductDetail(editingProduct))
          : createDemoProductDetail(savedProduct)
        detail = { ...existingDetail, product: savedProduct }
      } else {
        detail = editingProduct
          ? await updateSellerProduct(connection, editingProduct.productId, payload)
          : await createSellerProduct(connection, payload)
      }
      setProducts((current) =>
        editingProduct
          ? current.map((item) =>
              item.productId === detail.product.productId
                ? detail.product
                : item,
            )
          : [...current, detail.product],
      )
      setDetails((current) => ({
        ...current,
        [detail.product.productId]: detail,
      }))
      closeProductForm()
      onError(null)
    } catch (caught) {
      onError(
        caught instanceof Error
          ? caught.message
          : `상품을 ${editingProduct ? '수정' : '생성'}하지 못했습니다.`,
      )
    } finally {
      setUpdatingId(null)
    }
  }

  async function removeProduct() {
    if (!editingProduct) return
    setUpdatingId(editingProduct.productId)
    try {
      if (!isDemo) {
        await deleteSellerProduct(connection, editingProduct.productId)
      }
      const productId = editingProduct.productId
      setProducts((current) =>
        current.filter((item) => item.productId !== productId),
      )
      setDetails((current) => {
        const next = { ...current }
        delete next[productId]
        return next
      })
      closeProductForm()
      onError(null)
    } catch (caught) {
      onError(
        caught instanceof Error ? caught.message : '상품을 삭제하지 못했습니다.',
      )
    } finally {
      setUpdatingId(null)
    }
  }

  async function openOptionEditor(product: SellerProduct) {
    setUpdatingId(product.productId)
    try {
      const [detail, templates] = isDemo
        ? [
            details[product.productId] ?? createDemoProductDetail(product),
            optionTemplates,
          ]
        : await Promise.all([
            getSellerProductDetail(connection, product.productId),
            getStoreOptionTemplates(connection),
          ])
      setDetails((current) => ({ ...current, [product.productId]: detail }))
      setOptionTemplates(templates)
      setOptionProduct(detail.product)
      setShowOptions(true)
      onError(null)
    } catch (caught) {
      onError(
        caught instanceof Error
          ? caught.message
          : '상품 옵션을 불러오지 못했습니다.',
      )
    } finally {
      setUpdatingId(null)
    }
  }

  async function createOptionTemplateForEditor(group: ProductOptionGroupInput) {
    if (!isDemo) {
      const created = await createStoreOptionTemplate(connection, group)
      setOptionTemplates((current) => [...current, created])
      return created
    }
    const created: StoreOptionTemplate = {
      templateId: Math.max(0, ...optionTemplates.map((item) => item.templateId)) + 1,
      storeId: 1,
      name: group.name,
      minSelect: group.minSelect,
      maxSelect: group.maxSelect,
      required: group.required,
      version: 1,
      options: group.options.map((option, index) => ({
        optionId: Date.now() + index,
        ...option,
      })),
    }
    setOptionTemplates((current) => [...current, created])
    return created
  }

  async function findTemplateUsageForEditor(
    templateId: number,
  ): Promise<StoreOptionTemplateUsage> {
    if (!isDemo) return getStoreOptionTemplateUsage(connection, templateId)
    const usingProducts = products.filter((product) => {
      const detail = details[product.productId] ?? createDemoProductDetail(product)
      return detail.optionGroups.some((group) => group.templateId === templateId)
    })
    return {
      templateId,
      totalCount: usingProducts.length,
      products: usingProducts.map((product) => ({
        productId: product.productId,
        productName: product.name,
      })),
    }
  }

  async function applyTemplateForEditor(group: EditableOptionGroup) {
    if (!optionProduct || group.templateId == null || group.optionGroupId == null) {
      throw new Error('일괄 적용할 공용 옵션 연결 정보가 없습니다.')
    }
    if (!isDemo) {
      const updated = await applyStoreOptionTemplateToAll(
        connection,
        group.templateId,
        optionProduct.productId,
        group.optionGroupId,
        group,
      )
      setOptionTemplates((current) =>
        current.map((item) =>
          item.templateId === updated.templateId ? updated : item,
        ),
      )
      return updated
    }

    const currentTemplate = optionTemplates.find(
      (item) => item.templateId === group.templateId,
    )
    if (!currentTemplate) throw new Error('공용 옵션을 찾지 못했습니다.')
    const updated: StoreOptionTemplate = {
      ...currentTemplate,
      name: group.name,
      minSelect: group.minSelect,
      maxSelect: group.maxSelect,
      required: group.required,
      version: currentTemplate.version + 1,
      options: group.options.map((option, index) => ({
        optionId: currentTemplate.options[index]?.optionId ?? Date.now() + index,
        ...option,
      })),
    }
    setOptionTemplates((current) =>
      current.map((item) =>
        item.templateId === updated.templateId ? updated : item,
      ),
    )
    setDetails((current) => {
      const next = { ...current }
      products.forEach((product) => {
        const detail = next[product.productId] ?? createDemoProductDetail(product)
        next[product.productId] = {
          ...detail,
          optionGroups: detail.optionGroups.map((savedGroup) =>
            savedGroup.templateId === updated.templateId
              ? {
                  ...savedGroup,
                  name: updated.name,
                  minSelect: updated.minSelect,
                  maxSelect: updated.maxSelect,
                  required: updated.required,
                  appliedTemplateVersion: updated.version,
                  options: updated.options.map((option, index) => ({
                    ...option,
                    optionId:
                      savedGroup.options[index]?.optionId ??
                      product.productId * 10_000 + index,
                  })),
                }
              : savedGroup,
          ),
        }
      })
      return next
    })
    return updated
  }

  async function saveOptionGroups(
    groups: ProductOptionGroupInput[],
    templateIdsToDelete: number[],
  ) {
    if (!optionProduct) return
    setUpdatingId(optionProduct.productId)
    try {
      let detail: ProductDetail
      if (isDemo) {
        detail = {
          ...(details[optionProduct.productId] ??
            createDemoProductDetail(optionProduct)),
          optionGroups: groups.map((group, groupIndex) => ({
            optionGroupId: optionProduct.productId * 100 + groupIndex,
            ...group,
            templateId: group.templateId ?? null,
            appliedTemplateVersion: group.appliedTemplateVersion ?? null,
            options: group.options.map((option, optionIndex) => ({
              optionId:
                optionProduct.productId * 10_000 +
                groupIndex * 100 +
                optionIndex,
              ...option,
            })),
          })),
        }
      } else {
        detail = await replaceProductOptions(
          connection,
          optionProduct.productId,
          groups,
        )
      }

      let templateDeleteFailed = false
      for (const templateId of templateIdsToDelete) {
        try {
          if (!isDemo) await deleteStoreOptionTemplate(connection, templateId)
          setOptionTemplates((current) =>
            current.filter((template) => template.templateId !== templateId),
          )
        } catch {
          templateDeleteFailed = true
        }
      }
      setDetails((current) => ({
        ...current,
        [optionProduct.productId]: detail,
      }))
      setShowOptions(false)
      setOptionProduct(null)
      onError(
        templateDeleteFailed
          ? '현재 상품의 옵션은 저장했지만 일부 공용 옵션은 삭제하지 못했습니다.'
          : null,
      )
    } finally {
      setUpdatingId(null)
    }
  }

  return (
    <main className="management-page">
      <section className="management-hero catalog-hero">
        <div>
          <p className="eyebrow">MENU CONTROL</p>
          <h2>상품 판매 상태</h2>
          <p>
            상품 생성부터 옵션 구성, 품절과 채널 노출까지 한곳에서 관리합니다.
          </p>
        </div>
        <div className="hero-stat-grid">
          <article>
            <small>전체 상품</small>
            <strong>{products.length}</strong>
          </article>
          <article>
            <small>현재 품절</small>
            <strong>{soldOutCount}</strong>
          </article>
          <article>
            <small>QR 숨김</small>
            <strong>{hiddenCount}</strong>
          </article>
        </div>
        {canManage && <button className="hero-action" onClick={openNewProductForm}>
          + 새 상품
        </button>}
      </section>

      {!canManage && <p className="permission-notice">STAFF 권한은 상품을 조회할 수 있지만 상품·옵션·판매 채널을 변경할 수 없습니다.</p>}

      <section className="catalog-toolbar">
        <div className="category-pills" aria-label="상품 카테고리">
          <button
            className={category === '전체' ? 'active' : ''}
            onClick={() => setCategory('전체')}
          >
            전체
          </button>
          {categories.map((item) => (
            <span
              className={`category-pill-control ${item.name === category ? 'active' : ''}`}
              key={item.categoryId}
            >
              <button
                className="category-filter-button"
                onClick={() => setCategory(item.name)}
              >
                {item.name}
              </button>
              {canManage && (
                <button
                  className="category-manage-button"
                  aria-label={`${item.name} 카테고리 수정`}
                  title="카테고리 수정"
                  onClick={() => openCategoryEditor(item)}
                >
                  수정
                </button>
              )}
            </span>
          ))}
          {canManage && <button
            className="add-category"
            onClick={() => openCategoryEditor()}
          >
            + 카테고리
          </button>}
        </div>
        <label className="search-field">
          <span>⌕</span>
          <input
            type="search"
            aria-label="상품 검색"
            placeholder="상품 이름 검색"
            value={query}
            onChange={(event) => setQuery(event.target.value)}
          />
        </label>
      </section>

      {loading ? (
        <div className="management-empty">상품을 불러오는 중입니다…</div>
      ) : (
        <section className="product-table editable" aria-label="상품 판매 목록">
          <header>
            <span>상품</span>
            <span>판매가</span>
            <span>판매 상태</span>
            <span>QR 주문</span>
            <span>고객 앱</span>
            <span>관리</span>
          </header>
          {visibleProducts.map((product, index) => (
            <article key={product.productId}>
              <div className="product-identity">
                {product.imageUrl ? (
                  <img
                    className="product-thumbnail"
                    src={product.imageUrl}
                    alt=""
                  />
                ) : (
                  <span className={`product-swatch tone-${index % 4}`}>
                    {product.name.slice(0, 1)}
                  </span>
                )}
                <div>
                  <strong>{product.name}</strong>
                  <small>
                    {product.categoryName} · ID {product.productId}
                  </small>
                </div>
              </div>
              <strong className="product-price">{money(product.basePrice)}</strong>
              <button
                className={`availability-chip ${product.soldOut ? 'off' : 'on'}`}
                role="switch"
                aria-checked={!product.soldOut}
                aria-label={`${product.name} 품절 설정`}
                disabled={!canManage || updatingId === product.productId}
                onClick={() =>
                  void update(product, { soldOut: !product.soldOut })
                }
              >
                <span />
                {product.soldOut ? '품절' : '판매 중'}
              </button>
              <button
                className={`channel-switch ${product.qrWebEnabled ? 'on' : ''}`}
                role="switch"
                aria-checked={product.qrWebEnabled}
                aria-label={`${product.name} QR 판매 설정`}
                disabled={!canManage || updatingId === product.productId}
                onClick={() =>
                  void update(product, {
                    qrWebEnabled: !product.qrWebEnabled,
                  })
                }
              >
                <span />
              </button>
              <button
                className={`channel-switch ${product.customerAppEnabled ? 'on' : ''}`}
                role="switch"
                aria-checked={product.customerAppEnabled}
                aria-label={`${product.name} 고객 앱 판매 설정`}
                disabled={!canManage || updatingId === product.productId}
                onClick={() =>
                  void update(product, {
                    customerAppEnabled: !product.customerAppEnabled,
                  })
                }
              >
                <span />
              </button>
              <div className="product-actions">
                {canManage ? <><button
                  className="product-edit-button"
                  aria-label={`${product.name} 상품 편집`}
                  disabled={updatingId === product.productId}
                  onClick={() => openProductEditor(product)}
                >
                  상품 편집
                </button>
                <button
                  className="option-edit-button"
                  disabled={updatingId === product.productId}
                  onClick={() => void openOptionEditor(product)}
                >
                  옵션 편집
                </button></> : <span>조회 전용</span>}
              </div>
            </article>
          ))}
          {visibleProducts.length === 0 && (
            <div className="management-empty">
              조건에 맞는 상품이 없습니다.
            </div>
          )}
        </section>
      )}

      {showCategoryForm && (
        <div className="modal-backdrop" role="presentation">
          <section
            className="connection-modal category-form-modal"
            role="dialog"
            aria-modal="true"
            aria-labelledby="category-title"
          >
            <button
              className="modal-close"
              aria-label="닫기"
              onClick={closeCategoryEditor}
            >
              ×
            </button>
            <p className="eyebrow">
              {editingCategory ? 'EDIT CATEGORY' : 'NEW CATEGORY'}
            </p>
            <h2 id="category-title">
              {editingCategory ? '카테고리 수정' : '카테고리 추가'}
            </h2>
            <p>
              {editingCategory
                ? '카테고리 이름을 변경하면 연결된 상품에도 바로 반영됩니다.'
                : '새 카테고리는 현재 목록의 마지막 순서에 추가됩니다.'}
            </p>
            <label>
              카테고리 이름
              <input
                value={newCategoryName}
                maxLength={100}
                onChange={(event) => setNewCategoryName(event.target.value)}
                placeholder="예: 시즌 메뉴"
              />
            </label>
            <button
              className="primary-action"
              disabled={
                updatingCategoryId === (editingCategory?.categoryId ?? -1)
              }
              onClick={() => void saveCategory()}
            >
              {updatingCategoryId === (editingCategory?.categoryId ?? -1)
                ? '저장 중…'
                : editingCategory
                  ? '변경사항 저장'
                  : '카테고리 추가하기'}
            </button>
            {editingCategory && (
              <div className="category-delete-zone">
                {products.some(
                  (product) => product.categoryId === editingCategory.categoryId,
                ) ? (
                  <p>
                    이 카테고리에 등록된 상품이 있습니다. 상품을 먼저 삭제하거나 다른 카테고리로 옮겨 주세요.
                  </p>
                ) : showCategoryDeleteConfirm ? (
                  <div>
                    <p>“{editingCategory.name}” 카테고리를 삭제할까요?</p>
                    <small>삭제하면 상품 등록 화면에서 더 이상 표시되지 않습니다.</small>
                    <button
                      className="secondary-action"
                      type="button"
                      onClick={() => setShowCategoryDeleteConfirm(false)}
                    >
                      취소
                    </button>
                    <button
                      className="danger-action"
                      type="button"
                      disabled={updatingCategoryId === editingCategory.categoryId}
                      onClick={() => void removeCategory()}
                    >
                      삭제 확인
                    </button>
                  </div>
                ) : (
                  <button
                    className="delete-category-button"
                    type="button"
                    onClick={() => setShowCategoryDeleteConfirm(true)}
                  >
                    카테고리 삭제
                  </button>
                )}
              </div>
            )}
          </section>
        </div>
      )}

      {showProductForm && (
        <div className="modal-backdrop" role="presentation">
          <section
            className="connection-modal product-form-modal"
            role="dialog"
            aria-modal="true"
            aria-labelledby="product-title"
          >
            <button
              className="modal-close"
              aria-label="닫기"
              onClick={closeProductForm}
            >
              ×
            </button>
            <p className="eyebrow">
              {editingProduct ? 'EDIT PRODUCT' : 'NEW PRODUCT'}
            </p>
            <h2 id="product-title">
              {editingProduct ? '상품 편집' : '새 상품'}
            </h2>
            <p>
              {editingProduct
                ? '상품의 이미지와 기본 정보를 수정하거나 상품을 삭제할 수 있습니다.'
                : '이미지와 기본 정보를 등록한 뒤 옵션 구성을 추가할 수 있습니다.'}
            </p>
            <div className="product-image-field">
              <span>상품 이미지</span>
              <div className="product-image-input">
                {productImagePreview ? (
                  <img src={productImagePreview} alt="상품 이미지 미리보기" />
                ) : (
                  <div className="product-image-placeholder">이미지 없음</div>
                )}
                <div>
                  <label className="image-file-button">
                    이미지 선택
                    <input
                      type="file"
                      aria-label="상품 이미지"
                      accept="image/jpeg,image/png,image/webp"
                      onChange={(event) => void selectProductImage(event)}
                    />
                  </label>
                  {productImagePreview && (
                    <button
                      className="remove-image-button"
                      type="button"
                      onClick={() => {
                        setProductImageFile(null)
                        setProductImagePreview(null)
                        setRemoveProductImage(true)
                      }}
                    >
                      이미지 삭제
                    </button>
                  )}
                  <small>JPG, PNG, WEBP · 최대 10MB</small>
                </div>
              </div>
            </div>
            <label>
              카테고리
              <select
                value={productCategoryId}
                onChange={(event) => setProductCategoryId(event.target.value)}
              >
                {categories.map((item) => (
                  <option key={item.categoryId} value={item.categoryId}>
                    {item.name}
                  </option>
                ))}
              </select>
            </label>
            <label>
              상품 이름
              <input
                value={productName}
                onChange={(event) => setProductName(event.target.value)}
                placeholder="예: 얼그레이 크림 라떼"
              />
            </label>
            <label>
              상품 설명
              <textarea
                rows={3}
                value={productDescription}
                onChange={(event) => setProductDescription(event.target.value)}
                placeholder="고객 메뉴에 표시할 짧은 설명"
              />
            </label>
            <label>
              판매가
              <input
                inputMode="numeric"
                value={productPrice}
                onChange={(event) => setProductPrice(event.target.value)}
                placeholder="0"
              />
            </label>
            <button
              className="primary-action"
              disabled={updatingId === (editingProduct?.productId ?? -2) || categories.length === 0}
              onClick={() => void saveProduct()}
            >
              {updatingId === (editingProduct?.productId ?? -2)
                ? '저장 중…'
                : editingProduct
                  ? '변경사항 저장'
                  : '상품 생성하기'}
            </button>
            {editingProduct && (
              <div className="product-delete-zone">
                {showDeleteConfirm ? (
                  <div>
                    <p>이 상품을 삭제할까요? 주문 기록은 유지됩니다.</p>
                    <button
                      className="secondary-action"
                      type="button"
                      onClick={() => setShowDeleteConfirm(false)}
                    >
                      취소
                    </button>
                    <button
                      className="danger-action"
                      type="button"
                      disabled={updatingId === editingProduct.productId}
                      onClick={() => void removeProduct()}
                    >
                      삭제 확인
                    </button>
                  </div>
                ) : (
                  <button
                    className="delete-product-button"
                    type="button"
                    onClick={() => setShowDeleteConfirm(true)}
                  >
                    상품 삭제
                  </button>
                )}
              </div>
            )}
          </section>
        </div>
      )}

      {showOptions && optionProduct && (
        <ProductOptionEditor
          product={optionProduct}
          initialGroups={
            (details[optionProduct.productId] ??
              createDemoProductDetail(optionProduct)).optionGroups
          }
          initialTemplates={optionTemplates}
          onCancel={() => {
            setShowOptions(false)
            setOptionProduct(null)
          }}
          onCreateTemplate={createOptionTemplateForEditor}
          onFindTemplateUsage={findTemplateUsageForEditor}
          onApplyTemplateToAll={applyTemplateForEditor}
          onSave={saveOptionGroups}
        />
      )}

      <p className="source-note">
        {isDemo
          ? '데모 데이터 변경은 새로고침 시 초기화됩니다.'
          : '상품과 옵션은 Spring Boot와 MySQL을 최종 기준으로 저장합니다.'}
      </p>
    </main>
  )
}
