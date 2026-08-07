# 판매자 새 주문 알림음 교체

판매자 앱은 결제가 끝나 주문 상태가 `PLACED`가 될 때 활성 사업장 구성원에게
`ORDER_PLACED` 푸시를 보냅니다. Android 앱이 전면에 있어도, 백그라운드에
있어도 전용 주문 알림 채널을 통해 음성이 재생됩니다.

## 음원 교체 위치

아래 파일을 같은 이름의 새 MP3 파일로 교체합니다.

`mobile_flutter/apps/seller_app/android/app/src/main/res/raw/popq_order_arrived.mp3`

Android raw 리소스 이름은 영문 소문자, 숫자, 밑줄만 사용할 수 있으므로 파일
이름을 변경할 때 이 규칙을 지켜야 합니다.

## 반드시 함께 바꿀 채널 버전

Android 8 이상에서는 한 번 만들어진 알림 채널의 소리를 앱 업데이트로 변경할
수 없습니다. 기존 설치 기기에도 새 음원을 적용하려면 다음 두 상수의 채널 ID를
같은 값으로 올립니다. 예: `popq_new_orders_v1` → `popq_new_orders_v2`.

- Flutter: `seller_push_notification_service.dart`의 `_newOrderChannelId`
- Backend: `SellerOrderPushNotificationService.java`의
  `NEW_ORDER_ANDROID_CHANNEL_ID`

음원 파일 이름까지 변경했다면 다음 소리 리소스 상수도 확장자를 제외한 같은
이름으로 함께 수정합니다.

- Flutter: `_newOrderSoundResource`
- Backend: `NEW_ORDER_ANDROID_SOUND`

기기 설정에서 사용자가 해당 알림 채널을 무음으로 지정했거나 방해금지 모드를
사용 중인 경우에는 앱이 강제로 소리를 재생할 수 없습니다.
