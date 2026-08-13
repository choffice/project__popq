import { useState } from 'react'
import type { SellerConnection } from '../../types'
import { SupportManagement } from '../support/SupportManagement'
import { AdminSupportManagement } from './AdminSupportManagement'

type Props = {
  connection: SellerConnection | null
  onError: (message: string | null) => void
}

export function AdminSupportHub({ connection, onError }: Props) {
  const [source, setSource] = useState<'customer' | 'unified'>('customer')
  const [customerUnread, setCustomerUnread] = useState(0)

  return (
    <>
      <div className="admin-tabs admin-support-tabs" role="tablist" aria-label="문의 접수 채널">
        <button
          type="button"
          role="tab"
          aria-selected={source === 'customer'}
          className={source === 'customer' ? 'active' : ''}
          onClick={() => setSource('customer')}
        >
          구매자 앱 문의
          {customerUnread > 0 && <b>{customerUnread}</b>}
        </button>
        <button
          type="button"
          role="tab"
          aria-selected={source === 'unified'}
          className={source === 'unified' ? 'active' : ''}
          onClick={() => setSource('unified')}
        >
          판매자 · 통합 문의
        </button>
      </div>
      {source === 'customer' ? (
        <SupportManagement
          connection={connection}
          onError={onError}
          onUnreadChange={setCustomerUnread}
        />
      ) : (
        <AdminSupportManagement connection={connection} onError={onError} />
      )}
    </>
  )
}
