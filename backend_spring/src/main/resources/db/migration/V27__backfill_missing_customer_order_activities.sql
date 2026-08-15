INSERT INTO customer_activity_sources (
    user_id,
    store_id,
    activity_type,
    source_type,
    source_key,
    activity_date,
    active,
    occurred_at,
    revoked_at,
    created_at,
    updated_at
)
SELECT
    o.user_id,
    o.store_id,
    'STORE_PURCHASE',
    'ORDER',
    o.order_public_id,
    DATE(DATE_ADD(p.approved_at, INTERVAL 9 HOUR)),
    TRUE,
    p.approved_at,
    NULL,
    p.approved_at,
    p.approved_at
FROM orders o
JOIN payments p ON p.order_id = o.order_id
WHERE o.user_id IS NOT NULL
  AND p.approved_at IS NOT NULL
  AND p.status = 'PAID'
  AND NOT EXISTS (
      SELECT 1
      FROM customer_activity_sources existing
      WHERE existing.source_type = 'ORDER'
        AND existing.source_key = o.order_public_id
  );
