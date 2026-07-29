# POPQ Flutter 워크스페이스

## 활성 앱

```text
mobile_flutter/
├─ apps/
│  ├─ customer_app/      # 회원 소비자 Android/iOS 앱
│  └─ seller_app/        # 판매자 Android/iOS 앱
└─ packages/
   ├─ app_core/          # 환경·API envelope·인증 세션 계약
   └─ design_system/     # 테마·공통 UI primitive
```

기존 루트의 `lib/`, `android/`, `windows/`, `web/`은 앱 분리 전에 생성된 기본 카운터 템플릿으로, 현재 릴리스 대상이 아니다. 새 기능은 반드시 `apps/customer_app` 또는 `apps/seller_app`에 구현한다. 루트 템플릿은 새 앱의 플랫폼 빌드가 확인된 뒤 별도 정리한다.

## 실행

소비자 앱:

```powershell
cd mobile_flutter\apps\customer_app
flutter run
```

판매자 앱:

```powershell
cd mobile_flutter\apps\seller_app
flutter run
```

Android 에뮬레이터의 기본 백엔드 주소는 `http://10.0.2.2:8082`다. 다른 환경은 Dart define으로 주입한다.

```powershell
flutter run `
  --dart-define=POPQ_FLAVOR=staging `
  --dart-define=POPQ_API_BASE_URL=https://api.example.com `
  --dart-define=POPQ_ENABLE_NETWORK_LOGS=false
```

## 전체 검증

```powershell
powershell -ExecutionPolicy Bypass -File mobile_flutter\tool\verify.ps1
```

Docker는 Flutter 화면·단위 테스트에 필요하지 않다. 실제 Spring Boot 계약을 검증할 때만 통합 스택을 실행한다.

