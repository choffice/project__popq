import { useEffect, useMemo, useState } from 'react'
import {
  createDemoProductDetail,
  freshDemoCategories,
  freshDemoProducts,
} from '../../data/demo'
import {
  createSellerCategory,
  createSellerProduct,
  getSellerCategories,
  getSellerProductDetail,
  getSellerProducts,
  replaceProductOptions,
  updateProductAvailability,
} from '../../services/api'
import type {
  ProductDetail,
  ProductOptionGroupInput,
  SellerCategory,
  SellerConnection,
  SellerProduct,
} from '../../types'

type Props = {
  connection: SellerConnection | null
  onError: (message: string | null) => void
}

type DraftOption = {
  key: string
  name: string
  additionalPrice: string
}

type DraftGroup = {
  key: string
  name: string
  required: boolean
  maxSelect: string
  options: DraftOption[]
}

function key() {
  return crypto.randomUUID()
}

function money(value: number) {
  return `${value.toLocaleString('ko-KR')}원`
}

function emptyOption(): DraftOption {
  return { key: key(), name: '', additionalPrice: '0' }
}

function emptyGroup(): DraftGroup {
  return {
    key: key(),
    name: '',
    required: false,
    maxSelect: '1',
    options: [emptyOption()],
  }
}

function toDraftGroups(detail: ProductDetail): DraftGroup[] {
  return detail.optionGroups.map((group) => ({
    key: String(group.optionGroupId),
    name: group.name,
    required: group.required,
    maxSelect: String(group.maxSelect),
    options: group.options.map((option) => ({
      key: String(option.optionId),
      name: option.name,
      additionalPrice: String(option.additionalPrice),
    })),
  }))
}

export function ProductManagement({ connection, onError }: Props) {
  const isDemo = !connection
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
  const [newCategoryName, setNewCategoryName] = useState('')
  const [showProductForm, setShowProductForm] = useState(false)
  const [productCategoryId, setProductCategoryId] = useState(() =>
    isDemo ? String(freshDemoCategories()[0]?.categoryId ?? '') : '',
  )
  const [productName, setProductName] = useState('')
  const [productDescription, setProductDescription] = useState('')
  const [productPrice, setProductPrice] = useState('')
  const [optionProduct, setOptionProduct] = useState<SellerProduct | null>(null)
  const [draftGroups, setDraftGroups] = useState<DraftGroup[]>([])
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

  const categoryNames = useMemo(
    () => ['전체', ...categories.map((item) => item.name)],
    [categories],
  )
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

  async function addCategory() {
    const name = newCategoryName.trim()
    if (!name) {
      onError('카테고리 이름을 입력해 주세요.')
      return
    }
    setUpdatingId(-1)
    try {
      const created = isDemo
        ? {
            categoryId:
              Math.max(0, ...categories.map((item) => item.categoryId)) + 1,
            name,
            displayOrder: categories.length,
            status: 'ACTIVE' as const,
          }
        : await createSellerCategory(connection, name, categories.length)
      setCategories((current) => [...current, created])
      setProductCategoryId(String(created.categoryId))
      setNewCategoryName('')
      setShowCategoryForm(false)
      onError(null)
    } catch (caught) {
      onError(
        caught instanceof Error
          ? caught.message
          : '카테고리를 생성하지 못했습니다.',
      )
    } finally {
      setUpdatingId(null)
    }
  }

  async function addProduct() {
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
    setUpdatingId(-2)
    try {
      let detail: ProductDetail
      if (isDemo) {
        const created: SellerProduct = {
          productId:
            Math.max(0, ...products.map((item) => item.productId)) + 1,
          categoryId,
          categoryName: selectedCategory.name,
          name,
          description: productDescription.trim() || null,
          imageUrl: null,
          basePrice,
          status: 'ACTIVE',
          soldOut: false,
          availableForQr: true,
          salesStartAt: null,
          salesEndAt: null,
          qrWebEnabled: true,
          customerAppEnabled: true,
        }
        detail = {
          ...createDemoProductDetail(created),
          optionGroups: [],
        }
      } else {
        detail = await createSellerProduct(connection, {
          categoryId,
          name,
          description: productDescription.trim() || null,
          imageUrl: null,
          basePrice,
        })
      }
      setProducts((current) => [...current, detail.product])
      setDetails((current) => ({
        ...current,
        [detail.product.productId]: detail,
      }))
      setProductName('')
      setProductDescription('')
      setProductPrice('')
      setShowProductForm(false)
      onError(null)
    } catch (caught) {
      onError(
        caught instanceof Error
          ? caught.message
          : '상품을 생성하지 못했습니다.',
      )
    } finally {
      setUpdatingId(null)
    }
  }

  async function openOptionEditor(product: SellerProduct) {
    setUpdatingId(product.productId)
    try {
      const detail = isDemo
        ? (details[product.productId] ?? createDemoProductDetail(product))
        : await getSellerProductDetail(connection, product.productId)
      setDetails((current) => ({ ...current, [product.productId]: detail }))
      setOptionProduct(product)
      setDraftGroups(toDraftGroups(detail))
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

  function updateGroup(groupKey: string, patch: Partial<DraftGroup>) {
    setDraftGroups((current) =>
      current.map((group) =>
        group.key === groupKey ? { ...group, ...patch } : group,
      ),
    )
  }

  function updateOption(
    groupKey: string,
    optionKey: string,
    patch: Partial<DraftOption>,
  ) {
    setDraftGroups((current) =>
      current.map((group) =>
        group.key === groupKey
          ? {
              ...group,
              options: group.options.map((option) =>
                option.key === optionKey ? { ...option, ...patch } : option,
              ),
            }
          : group,
      ),
    )
  }

  async function saveOptions() {
    if (!optionProduct) return
    const groups: ProductOptionGroupInput[] = draftGroups.map(
      (group, groupIndex) => ({
        name: group.name.trim(),
        minSelect: group.required ? 1 : 0,
        maxSelect: Number(group.maxSelect),
        required: group.required,
        displayOrder: groupIndex,
        options: group.options.map((option, optionIndex) => ({
          name: option.name.trim(),
          additionalPrice: Number(option.additionalPrice),
          displayOrder: optionIndex,
        })),
      }),
    )
    const invalid = groups.some(
      (group) =>
        !group.name ||
        !Number.isInteger(group.maxSelect) ||
        group.maxSelect < 1 ||
        group.maxSelect > group.options.length ||
        group.options.length === 0 ||
        group.options.some(
          (option) =>
            !option.name ||
            !Number.isInteger(option.additionalPrice) ||
            option.additionalPrice < 0,
        ),
    )
    if (invalid) {
      onError('옵션 그룹 이름, 선택 수, 옵션 이름과 추가 금액을 확인해 주세요.')
      return
    }
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
      setDetails((current) => ({
        ...current,
        [optionProduct.productId]: detail,
      }))
      setShowOptions(false)
      setOptionProduct(null)
      onError(null)
    } catch (caught) {
      onError(
        caught instanceof Error
          ? caught.message
          : '옵션을 저장하지 못했습니다.',
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
        <button className="hero-action" onClick={() => setShowProductForm(true)}>
          + 새 상품
        </button>
      </section>

      <section className="catalog-toolbar">
        <div className="category-pills" aria-label="상품 카테고리">
          {categoryNames.map((item) => (
            <button
              key={item}
              className={item === category ? 'active' : ''}
              onClick={() => setCategory(item)}
            >
              {item}
            </button>
          ))}
          <button
            className="add-category"
            onClick={() => setShowCategoryForm(true)}
          >
            + 카테고리
          </button>
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
            <span>옵션</span>
          </header>
          {visibleProducts.map((product, index) => (
            <article key={product.productId}>
              <div className="product-identity">
                <span className={`product-swatch tone-${index % 4}`}>
                  {product.name.slice(0, 1)}
                </span>
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
                disabled={updatingId === product.productId}
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
                disabled={updatingId === product.productId}
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
                disabled={updatingId === product.productId}
                onClick={() =>
                  void update(product, {
                    customerAppEnabled: !product.customerAppEnabled,
                  })
                }
              >
                <span />
              </button>
              <button
                className="option-edit-button"
                disabled={updatingId === product.productId}
                onClick={() => void openOptionEditor(product)}
              >
                옵션 편집
              </button>
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
            className="connection-modal"
            role="dialog"
            aria-modal="true"
            aria-labelledby="category-title"
          >
            <button
              className="modal-close"
              aria-label="닫기"
              onClick={() => setShowCategoryForm(false)}
            >
              ×
            </button>
            <p className="eyebrow">NEW CATEGORY</p>
            <h2 id="category-title">카테고리 추가</h2>
            <p>새 카테고리는 현재 목록의 마지막 순서에 추가됩니다.</p>
            <label>
              카테고리 이름
              <input
                value={newCategoryName}
                onChange={(event) => setNewCategoryName(event.target.value)}
                placeholder="예: 시즌 메뉴"
              />
            </label>
            <button
              className="primary-action"
              disabled={updatingId === -1}
              onClick={() => void addCategory()}
            >
              카테고리 추가하기
            </button>
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
              onClick={() => setShowProductForm(false)}
            >
              ×
            </button>
            <p className="eyebrow">NEW PRODUCT</p>
            <h2 id="product-title">새 상품</h2>
            <p>기본 상품을 만든 뒤 목록의 옵션 편집에서 구성을 추가할 수 있습니다.</p>
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
              disabled={updatingId === -2 || categories.length === 0}
              onClick={() => void addProduct()}
            >
              {updatingId === -2 ? '생성 중…' : '상품 생성하기'}
            </button>
          </section>
        </div>
      )}

      {showOptions && optionProduct && (
        <div className="modal-backdrop option-backdrop" role="presentation">
          <section
            className="option-modal"
            role="dialog"
            aria-modal="true"
            aria-labelledby="option-title"
          >
            <header>
              <div>
                <p className="eyebrow">OPTION BUILDER</p>
                <h2 id="option-title">{optionProduct.name} 옵션</h2>
              </div>
              <button
                className="modal-close"
                aria-label="닫기"
                onClick={() => setShowOptions(false)}
              >
                ×
              </button>
            </header>
            <p className="option-help">
              저장하면 기존 옵션 구성을 아래 내용으로 완전히 교체합니다.
            </p>
            <div className="option-group-list">
              {draftGroups.map((group, groupIndex) => (
                <article className="option-group-editor" key={group.key}>
                  <header>
                    <b>그룹 {groupIndex + 1}</b>
                    <button
                      aria-label={`옵션 그룹 ${groupIndex + 1} 삭제`}
                      onClick={() =>
                        setDraftGroups((current) =>
                          current.filter((item) => item.key !== group.key),
                        )
                      }
                    >
                      삭제
                    </button>
                  </header>
                  <div className="option-group-fields">
                    <label>
                      그룹 이름
                      <input
                        value={group.name}
                        onChange={(event) =>
                          updateGroup(group.key, { name: event.target.value })
                        }
                        placeholder="예: 온도"
                      />
                    </label>
                    <label>
                      최대 선택
                      <input
                        inputMode="numeric"
                        value={group.maxSelect}
                        onChange={(event) =>
                          updateGroup(group.key, {
                            maxSelect: event.target.value,
                          })
                        }
                      />
                    </label>
                    <label className="required-check">
                      <input
                        type="checkbox"
                        checked={group.required}
                        onChange={(event) =>
                          updateGroup(group.key, {
                            required: event.target.checked,
                          })
                        }
                      />
                      필수 선택
                    </label>
                  </div>
                  <div className="draft-options">
                    {group.options.map((option, optionIndex) => (
                      <div key={option.key}>
                        <span>{optionIndex + 1}</span>
                        <input
                          aria-label={`${groupIndex + 1}번 그룹 ${optionIndex + 1}번 옵션 이름`}
                          value={option.name}
                          onChange={(event) =>
                            updateOption(group.key, option.key, {
                              name: event.target.value,
                            })
                          }
                          placeholder="옵션 이름"
                        />
                        <label>
                          +
                          <input
                            aria-label={`${groupIndex + 1}번 그룹 ${optionIndex + 1}번 추가 금액`}
                            inputMode="numeric"
                            value={option.additionalPrice}
                            onChange={(event) =>
                              updateOption(group.key, option.key, {
                                additionalPrice: event.target.value,
                              })
                            }
                          />
                          원
                        </label>
                        <button
                          aria-label={`${groupIndex + 1}번 그룹 ${optionIndex + 1}번 옵션 삭제`}
                          onClick={() =>
                            updateGroup(group.key, {
                              options: group.options.filter(
                                (item) => item.key !== option.key,
                              ),
                            })
                          }
                        >
                          ×
                        </button>
                      </div>
                    ))}
                    <button
                      className="add-option"
                      onClick={() =>
                        updateGroup(group.key, {
                          options: [...group.options, emptyOption()],
                        })
                      }
                    >
                      + 옵션 추가
                    </button>
                  </div>
                </article>
              ))}
              <button
                className="add-option-group"
                onClick={() =>
                  setDraftGroups((current) => [...current, emptyGroup()])
                }
              >
                + 옵션 그룹 추가
              </button>
            </div>
            <footer>
              <button
                className="secondary-action"
                onClick={() => setShowOptions(false)}
              >
                취소
              </button>
              <button
                className="primary-action"
                disabled={updatingId === optionProduct.productId}
                onClick={() => void saveOptions()}
              >
                옵션 저장
              </button>
            </footer>
          </section>
        </div>
      )}

      <p className="source-note">
        {isDemo
          ? '데모 데이터 변경은 새로고침 시 초기화됩니다.'
          : '상품과 옵션은 Spring Boot와 MySQL을 최종 기준으로 저장합니다.'}
      </p>
    </main>
  )
}
