import { expect, test } from '@playwright/test'

async function addMenuToCart(page: import('@playwright/test').Page) {
  await page.goto('/')
  await page
    .getByRole('button', { name: /블랙 세서미 크림 라떼/ })
    .click()
  await expect(
    page.getByRole('dialog', { name: /블랙 세서미 크림 라떼 옵션 선택/ }),
  ).toBeVisible()
  await page.getByRole('radio', { name: /ICE/ }).check()
  await page.getByRole('button', { name: /6,800원 담기/ }).click()
  await expect(
    page.getByRole('button', { name: /장바구니 보기/ }),
  ).toBeVisible()
}

test('장바구니와 주문을 새로고침 후 복구하고 고객이 취소한다', async ({
  page,
}) => {
  await addMenuToCart(page)

  await page.reload()
  await expect(
    page.getByRole('button', { name: '장바구니 1개' }),
  ).toBeVisible()
  await page.getByRole('button', { name: '장바구니 1개' }).click()
  await page.getByRole('button', { name: /6,800원 결제하기/ }).click()
  await expect(
    page.getByRole('heading', { name: '주문이 전달됐어요' }),
  ).toBeVisible()

  await page.reload()
  await expect(
    page.getByRole('heading', { name: '주문이 전달됐어요' }),
  ).toBeVisible()
  await page.getByRole('button', { name: '주문 취소' }).click()
  await expect(
    page.getByRole('heading', { name: '주문이 취소됐어요' }),
  ).toBeVisible()
  await page.getByRole('button', { name: '새 주문 시작하기' }).click()
  await expect(
    page.getByRole('heading', { name: '오늘의 한 잔, 가볍게 골라보세요.' }),
  ).toBeVisible()
})

test('데모 주문을 완료 상태까지 진행한다', async ({ page }) => {
  await addMenuToCart(page)
  await page.getByRole('button', { name: /장바구니 보기/ }).click()
  await page.getByRole('button', { name: /6,800원 결제하기/ }).click()

  const nextStatus = page.getByRole('button', {
    name: '데모 상태 다음으로',
  })
  await nextStatus.click()
  await expect(
    page.getByRole('heading', { name: '주문을 접수했어요' }),
  ).toBeVisible()
  await nextStatus.click()
  await expect(
    page.getByRole('heading', { name: '맛있게 준비 중이에요' }),
  ).toBeVisible()
  await nextStatus.click()
  await expect(
    page.getByRole('heading', { name: '주문이 준비됐어요' }),
  ).toBeVisible()
  await nextStatus.click()
  await expect(
    page.getByRole('heading', { name: '이용해 주셔서 고마워요' }),
  ).toBeVisible()
  await expect(
    page.getByRole('button', { name: '새 주문 시작하기' }),
  ).toBeVisible()
})
