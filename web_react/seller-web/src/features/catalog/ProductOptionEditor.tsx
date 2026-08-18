import { useMemo, useState } from 'react'
import type {
  ProductOptionGroup,
  ProductOptionGroupInput,
  SellerProduct,
  StoreOptionTemplate,
  StoreOptionTemplateUsage,
} from '../../types'

type DraftOption = {
  key: string
  name: string
  additionalPrice: string
}

export type EditableOptionGroup = ProductOptionGroupInput & {
  optionGroupId: number | null
}

type DraftGroup = {
  key: string
  optionGroupId: number | null
  templateId: number | null
  appliedTemplateVersion: number | null
  name: string
  required: boolean
  maxSelect: string
  options: DraftOption[]
}

type OptionErrors = Record<string, { name?: string; price?: string }>
type GroupErrors = Record<
  string,
  { name?: string; maxSelect?: string; options?: string; optionErrors: OptionErrors }
>

type RemovalPrompt = {
  groupKey: string
  groupName: string
  optionCount: number
  templateId: number | null
  otherCount: number
}

type BulkPrompt = {
  groupKey: string
  usage: StoreOptionTemplateUsage
  group: EditableOptionGroup
}

type Props = {
  product: SellerProduct
  initialGroups: ProductOptionGroup[]
  initialTemplates: StoreOptionTemplate[]
  onCancel: () => void
  onSave: (
    groups: ProductOptionGroupInput[],
    templateIdsToDelete: number[],
  ) => Promise<void>
  onCreateTemplate: (
    group: ProductOptionGroupInput,
  ) => Promise<StoreOptionTemplate>
  onFindTemplateUsage: (templateId: number) => Promise<StoreOptionTemplateUsage>
  onApplyTemplateToAll: (
    group: EditableOptionGroup,
  ) => Promise<StoreOptionTemplate>
}

function draftKey() {
  return crypto.randomUUID()
}

function emptyOption(): DraftOption {
  return { key: draftKey(), name: '', additionalPrice: '0' }
}

function emptyGroup(): DraftGroup {
  return {
    key: draftKey(),
    optionGroupId: null,
    templateId: null,
    appliedTemplateVersion: null,
    name: '',
    required: false,
    maxSelect: '1',
    options: [emptyOption()],
  }
}

function toDraftGroup(group: ProductOptionGroup): DraftGroup {
  return {
    key: String(group.optionGroupId),
    optionGroupId: group.optionGroupId,
    templateId: group.templateId,
    appliedTemplateVersion: group.appliedTemplateVersion,
    name: group.name,
    required: group.required,
    maxSelect: String(group.maxSelect),
    options: group.options.map((option) => ({
      key: String(option.optionId),
      name: option.name,
      additionalPrice: String(option.additionalPrice),
    })),
  }
}

function toInput(group: DraftGroup, displayOrder: number): EditableOptionGroup {
  return {
    optionGroupId: group.optionGroupId,
    name: group.name.trim(),
    minSelect: group.required ? 1 : 0,
    maxSelect: Number(group.maxSelect),
    required: group.required,
    displayOrder,
    templateId: group.templateId,
    appliedTemplateVersion: group.appliedTemplateVersion,
    options: group.options.map((option, optionIndex) => ({
      name: option.name.trim(),
      additionalPrice: Number(option.additionalPrice),
      displayOrder: optionIndex,
    })),
  }
}

function templateChanged(group: DraftGroup, template: StoreOptionTemplate) {
  if (
    group.name.trim() !== template.name ||
    group.required !== template.required ||
    (group.required ? 1 : 0) !== template.minSelect ||
    Number(group.maxSelect) !== template.maxSelect ||
    group.options.length !== template.options.length
  ) {
    return true
  }
  return group.options.some((option, index) => {
    const saved = template.options[index]
    return (
      option.name.trim() !== saved.name ||
      Number(option.additionalPrice) !== saved.additionalPrice ||
      index !== saved.displayOrder
    )
  })
}

function validateGroup(group: DraftGroup): {
  input: EditableOptionGroup
  errors: GroupErrors[string]
  valid: boolean
} {
  const input = toInput(group, 0)
  const errors: GroupErrors[string] = { optionErrors: {} }
  if (!input.name) errors.name = '옵션 그룹 이름을 입력해주세요.'
  if (!Number.isInteger(input.maxSelect)) {
    errors.maxSelect = '최대 선택 수를 숫자로 입력해주세요.'
  } else if (input.maxSelect < input.minSelect) {
    errors.maxSelect = input.required
      ? '필수 선택은 최대 선택 수가 1개 이상이어야 합니다.'
      : '최대 선택 수를 확인해주세요.'
  } else if (input.maxSelect > input.options.length) {
    errors.maxSelect = `등록된 옵션 ${input.options.length}개를 넘을 수 없습니다.`
  }
  if (input.options.length === 0) {
    errors.options = '옵션 항목을 1개 이상 등록해주세요.'
  }
  input.options.forEach((option, index) => {
    const draftOption = group.options[index]
    const optionError: { name?: string; price?: string } = {}
    if (!option.name) optionError.name = '옵션 이름을 입력해주세요.'
    if (!Number.isInteger(option.additionalPrice)) {
      optionError.price = '금액을 숫자로 입력해주세요.'
    } else if (option.additionalPrice < 0) {
      optionError.price = '추가 금액은 0원 이상이어야 합니다.'
    }
    if (optionError.name || optionError.price) {
      errors.optionErrors[draftOption.key] = optionError
    }
  })
  return {
    input,
    errors,
    valid:
      !errors.name &&
      !errors.maxSelect &&
      !errors.options &&
      Object.keys(errors.optionErrors).length === 0,
  }
}

export function ProductOptionEditor({
  product,
  initialGroups,
  initialTemplates,
  onCancel,
  onSave,
  onCreateTemplate,
  onFindTemplateUsage,
  onApplyTemplateToAll,
}: Props) {
  const [groups, setGroups] = useState(() => initialGroups.map(toDraftGroup))
  const [templates, setTemplates] = useState(initialTemplates)
  const [templateIdsToDelete, setTemplateIdsToDelete] = useState<number[]>([])
  const [errors, setErrors] = useState<GroupErrors>({})
  const [formError, setFormError] = useState<string | null>(null)
  const [saving, setSaving] = useState(false)
  const [removalPrompt, setRemovalPrompt] = useState<RemovalPrompt | null>(null)
  const [bulkPrompt, setBulkPrompt] = useState<BulkPrompt | null>(null)

  const templatesByName = useMemo(
    () => new Map(templates.map((template) => [template.name.toLowerCase(), template])),
    [templates],
  )

  function updateGroup(groupKey: string, patch: Partial<DraftGroup>) {
    setGroups((current) =>
      current.map((group) =>
        group.key === groupKey ? { ...group, ...patch } : group,
      ),
    )
    setErrors((current) => {
      if (!current[groupKey]) return current
      const next = { ...current }
      delete next[groupKey]
      return next
    })
  }

  function updateOption(
    groupKey: string,
    optionKey: string,
    patch: Partial<DraftOption>,
  ) {
    setGroups((current) =>
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
    setErrors((current) => {
      if (!current[groupKey]?.optionErrors[optionKey]) return current
      return {
        ...current,
        [groupKey]: {
          ...current[groupKey],
          optionErrors: {
            ...current[groupKey].optionErrors,
            [optionKey]: {},
          },
        },
      }
    })
  }

  function fillGroupFromTemplate(groupKey: string, template: StoreOptionTemplate) {
    setGroups((current) =>
      current.map((group) =>
        group.key === groupKey
          ? {
              ...group,
              optionGroupId:
                group.templateId === template.templateId
                  ? group.optionGroupId
                  : null,
              templateId: template.templateId,
              appliedTemplateVersion: template.version,
              name: template.name,
              required: template.required,
              maxSelect: String(template.maxSelect),
              options: template.options.map((option) => ({
                key: draftKey(),
                name: option.name,
                additionalPrice: String(option.additionalPrice),
              })),
            }
          : group,
      ),
    )
  }

  async function askToRemove(group: DraftGroup) {
    setSaving(true)
    try {
      let otherCount = 0
      if (group.templateId !== null && group.optionGroupId !== null) {
        const usage = await onFindTemplateUsage(group.templateId)
        otherCount = usage.products.filter(
          (item) => item.productId !== product.productId,
        ).length
      }
      setRemovalPrompt({
        groupKey: group.key,
        groupName: group.name.trim(),
        optionCount: group.options.length,
        templateId:
          group.templateId !== null && group.optionGroupId !== null
            ? group.templateId
            : null,
        otherCount,
      })
      setFormError(null)
    } catch {
      setFormError('공용 옵션 사용 메뉴를 확인하지 못했습니다.')
    } finally {
      setSaving(false)
    }
  }

  function removeGroup(deleteTemplate: boolean) {
    if (!removalPrompt) return
    if (deleteTemplate && removalPrompt.templateId !== null) {
      setTemplateIdsToDelete((current) => [
        ...new Set([...current, removalPrompt.templateId!]),
      ])
    }
    setGroups((current) =>
      current.filter((group) => group.key !== removalPrompt.groupKey),
    )
    setRemovalPrompt(null)
  }

  async function askToApply(group: DraftGroup) {
    const validation = validateGroup(group)
    setErrors((current) => ({ ...current, [group.key]: validation.errors }))
    if (
      !validation.valid ||
      group.templateId === null ||
      group.optionGroupId === null
    ) {
      setFormError('일괄 적용 전에 표시된 입력 항목을 확인해주세요.')
      return
    }
    setSaving(true)
    try {
      const usage = await onFindTemplateUsage(group.templateId)
      setBulkPrompt({ groupKey: group.key, usage, group: validation.input })
      setFormError(null)
    } catch {
      setFormError('공용 옵션 사용 메뉴를 확인하지 못했습니다.')
    } finally {
      setSaving(false)
    }
  }

  async function applyToAll() {
    if (!bulkPrompt) return
    setSaving(true)
    try {
      const updated = await onApplyTemplateToAll(bulkPrompt.group)
      setTemplates((current) =>
        current.map((template) =>
          template.templateId === updated.templateId ? updated : template,
        ),
      )
      setGroups((current) =>
        current.map((group) =>
          group.key === bulkPrompt.groupKey
            ? { ...group, appliedTemplateVersion: updated.version }
            : group,
        ),
      )
      setBulkPrompt(null)
      setFormError(null)
    } catch {
      setFormError('공용 옵션 일괄 적용에 실패했습니다. 다시 시도해주세요.')
      setBulkPrompt(null)
    } finally {
      setSaving(false)
    }
  }

  async function save() {
    const nextErrors: GroupErrors = {}
    const validated = groups.map((group, index) => {
      const result = validateGroup(group)
      nextErrors[group.key] = result.errors
      return { ...result, input: { ...result.input, displayOrder: index } }
    })
    setErrors(nextErrors)
    if (validated.some((result) => !result.valid)) {
      setFormError('저장되지 않았습니다. 표시된 입력 항목을 확인해주세요.')
      return
    }

    setSaving(true)
    try {
      const linked: ProductOptionGroupInput[] = []
      const nextTemplates = [...templates]
      for (const result of validated) {
        const input = result.input
        let template = input.templateId
          ? nextTemplates.find((item) => item.templateId === input.templateId)
          : nextTemplates.find(
              (item) => item.name.toLowerCase() === input.name.toLowerCase(),
            )
        if (!template) {
          template = await onCreateTemplate(input)
          nextTemplates.push(template)
        }
        linked.push({
          ...input,
          templateId: template.templateId,
          appliedTemplateVersion:
            input.appliedTemplateVersion ?? template.version,
        })
      }
      setTemplates(nextTemplates)
      await onSave(linked, templateIdsToDelete)
    } catch (caught) {
      setFormError(
        caught instanceof Error
          ? caught.message
          : '공용 옵션을 저장하지 못했습니다. 이름 중복 여부를 확인해주세요.',
      )
      setSaving(false)
    }
  }

  return (
    <div className="modal-backdrop option-backdrop" role="presentation">
      <section
        className="option-modal app-option-editor"
        role="dialog"
        aria-modal="true"
        aria-labelledby="option-title"
      >
        <header>
          <div>
            <p className="eyebrow">OPTION BUILDER</p>
            <h2 id="option-title">{product.name} 옵션 편집</h2>
          </div>
          <button className="modal-close" aria-label="닫기" onClick={onCancel}>
            ×
          </button>
        </header>

        {formError && <p className="option-form-error" role="alert">{formError}</p>}

        <div className="option-group-list">
          {groups.length === 0 && (
            <p className="option-empty">옵션 그룹이 없습니다. 아래 버튼으로 추가하세요.</p>
          )}
          {groups.map((group, groupIndex) => {
            const template = templates.find(
              (item) => item.templateId === group.templateId,
            )
            const canApply =
              group.optionGroupId !== null &&
              template !== undefined &&
              templateChanged(group, template)
            const groupError = errors[group.key]
            return (
              <article className="option-group-editor" key={group.key}>
                <header>
                  <span className="option-group-number">{groupIndex + 1}</span>
                  <b>옵션 그룹</b>
                  <button
                    type="button"
                    aria-label={`옵션 그룹 ${groupIndex + 1} 삭제`}
                    disabled={saving}
                    onClick={() => void askToRemove(group)}
                  >
                    삭제
                  </button>
                </header>

                <section className="option-section">
                  <h3>옵션 그룹 이름</h3>
                  <p>고객에게 어떤 선택을 요청할지 적어주세요.</p>
                  <label>
                    <span className="sr-only">{groupIndex + 1}번 옵션 그룹 이름</span>
                    <input
                      list={`option-templates-${group.key}`}
                      aria-label={`${groupIndex + 1}번 옵션 그룹 이름`}
                      value={group.name}
                      placeholder="예: 사이즈, 맵기, 토핑"
                      onChange={(event) => {
                        const name = event.target.value
                        updateGroup(group.key, { name })
                        const selected = templatesByName.get(name.trim().toLowerCase())
                        if (selected && selected.templateId !== group.templateId) {
                          fillGroupFromTemplate(group.key, selected)
                        }
                      }}
                    />
                    <datalist id={`option-templates-${group.key}`}>
                      {templates.map((item) => (
                        <option key={item.templateId} value={item.name}>
                          {item.options.length}개 옵션 · 버전 {item.version}
                        </option>
                      ))}
                    </datalist>
                    <small>
                      {templates.length === 0
                        ? '새 이름으로 저장하면 매장 공용 옵션으로 등록됩니다.'
                        : '기존 공용 옵션을 선택하거나 새 이름을 입력하세요.'}
                    </small>
                    {groupError?.name && <em>{groupError.name}</em>}
                  </label>
                  {canApply && (
                    <button
                      className="template-apply-button"
                      type="button"
                      disabled={saving}
                      onClick={() => void askToApply(group)}
                    >
                      동일 그룹에 변경사항 일괄 적용
                    </button>
                  )}
                </section>

                <section className="option-section">
                  <h3>선택 방법</h3>
                  <label className="required-switch">
                    <span>
                      <b>필수 선택</b>
                      <small>
                        {group.required
                          ? '고객이 반드시 1개 이상 선택해야 합니다.'
                          : '고객이 선택하지 않아도 주문할 수 있습니다.'}
                      </small>
                    </span>
                    <input
                      type="checkbox"
                      checked={group.required}
                      onChange={(event) =>
                        updateGroup(group.key, { required: event.target.checked })
                      }
                    />
                  </label>
                  <label>
                    최대 선택 수
                    <span className="number-with-suffix">
                      <input
                        aria-label={`${groupIndex + 1}번 그룹 최대 선택 수`}
                        inputMode="numeric"
                        value={group.maxSelect}
                        onChange={(event) =>
                          updateGroup(group.key, { maxSelect: event.target.value })
                        }
                      />
                      개
                    </span>
                    <small>이 그룹에서 고객이 선택할 수 있는 최대 개수</small>
                    {groupError?.maxSelect && <em>{groupError.maxSelect}</em>}
                  </label>
                </section>

                <section className="option-section">
                  <div className="option-section-title">
                    <div>
                      <h3>옵션 항목</h3>
                      <p>고객이 실제로 선택할 항목과 추가금액을 등록합니다.</p>
                    </div>
                    <small>{group.options.length}개</small>
                  </div>
                  <div className="draft-options">
                    {group.options.map((option, optionIndex) => {
                      const optionError = groupError?.optionErrors[option.key]
                      return (
                        <div key={option.key}>
                          <span>{optionIndex + 1}</span>
                          <label>
                            <span className="sr-only">옵션 이름</span>
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
                            {optionError?.name && <em>{optionError.name}</em>}
                          </label>
                          <label className="option-price-field">
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
                            {optionError?.price && <em>{optionError.price}</em>}
                          </label>
                          <button
                            type="button"
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
                      )
                    })}
                    {groupError?.options && <em>{groupError.options}</em>}
                    <button
                      className="add-option"
                      type="button"
                      onClick={() =>
                        updateGroup(group.key, {
                          options: [...group.options, emptyOption()],
                        })
                      }
                    >
                      + 옵션 항목 추가
                    </button>
                  </div>
                </section>
              </article>
            )
          })}
          <button
            className="add-option-group"
            type="button"
            onClick={() => setGroups((current) => [...current, emptyGroup()])}
          >
            + 그룹 추가
          </button>
        </div>
        <footer>
          <button className="secondary-action" disabled={saving} onClick={onCancel}>
            취소
          </button>
          <button className="primary-action" disabled={saving} onClick={() => void save()}>
            {saving ? '저장 중…' : '저장'}
          </button>
        </footer>
      </section>

      {removalPrompt && (
        <div className="nested-confirm-backdrop" role="presentation">
          <section className="option-confirm" role="alertdialog" aria-labelledby="remove-option-title">
            <h3 id="remove-option-title">옵션 그룹을 삭제할까요?</h3>
            <p>
              {removalPrompt.templateId !== null
                ? removalPrompt.otherCount > 0
                  ? `이 공용 옵션은 다른 메뉴 ${removalPrompt.otherCount}개에서도 사용 중입니다. 현재 메뉴에서만 삭제할 수 있습니다.`
                  : '다른 메뉴에서 사용하지 않는 공용 옵션입니다. 현재 메뉴에서만 제거하거나 공용 옵션까지 삭제할 수 있습니다.'
                : removalPrompt.groupName
                  ? `“${removalPrompt.groupName}” 그룹과 등록된 옵션 ${removalPrompt.optionCount}개가 함께 삭제됩니다.`
                  : `이 옵션 그룹과 등록된 옵션 ${removalPrompt.optionCount}개가 함께 삭제됩니다.`}
            </p>
            <footer>
              <button onClick={() => setRemovalPrompt(null)}>취소</button>
              <button onClick={() => removeGroup(false)}>
                {removalPrompt.templateId !== null ? '현재 메뉴에서만 삭제' : '삭제'}
              </button>
              {removalPrompt.templateId !== null && removalPrompt.otherCount === 0 && (
                <button className="danger-action" onClick={() => removeGroup(true)}>
                  공용 옵션도 삭제
                </button>
              )}
            </footer>
          </section>
        </div>
      )}

      {bulkPrompt && (
        <div className="nested-confirm-backdrop" role="presentation">
          <section className="option-confirm" role="alertdialog" aria-labelledby="bulk-option-title">
            <h3 id="bulk-option-title">동일 옵션 그룹을 일괄 변경할까요?</h3>
            <p>동일 옵션이 적용된 메뉴들이 {bulkPrompt.usage.totalCount}개 있습니다.</p>
            <ul>
              {bulkPrompt.usage.products.slice(0, 3).map((item) => (
                <li key={item.productId}>{item.productName}</li>
              ))}
            </ul>
            {bulkPrompt.usage.totalCount > 3 && (
              <p>… 외 {bulkPrompt.usage.totalCount - 3}개</p>
            )}
            <p>
              현재 “{bulkPrompt.group.name}” 설정으로 모두 변경합니다. 각 메뉴에서 개별 수정한 옵션도 바뀌며, 일괄 적용은 즉시 저장되어 편집을 취소해도 되돌릴 수 없습니다.
            </p>
            <footer>
              <button onClick={() => setBulkPrompt(null)}>취소</button>
              <button className="primary-action" onClick={() => void applyToAll()}>
                일괄 적용
              </button>
            </footer>
          </section>
        </div>
      )}
    </div>
  )
}
