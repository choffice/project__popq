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

Android 에뮬레이터의 기본 백엔드 주소는 `http://10.0.2.2:8082`다. Flutter Web은 `http://localhost:8082`를 기본으로 사용한다. 다른 환경은 Dart define으로 주입한다.

```powershell
flutter run `
  --dart-define=POPQ_FLAVOR=staging `
  --dart-define=POPQ_API_BASE_URL=https://api.example.com `
  --dart-define=POPQ_ENABLE_NETWORK_LOGS=false
```

### Chrome 통합 실행

React 앱과 충돌하지 않도록 Flutter Web 개발 포트를 다음과 같이 고정한다.

```text
React popq              http://localhost:5173
React seller-web        http://localhost:5174
Flutter customer_app    http://localhost:5183
Flutter seller_app      http://localhost:5184
Spring Boot API         http://localhost:8082
```

서로 다른 터미널에서 다음 명령을 실행한다.

```powershell
powershell -ExecutionPolicy Bypass -File scripts\run-flutter-web.ps1 -App customer
powershell -ExecutionPolicy Bypass -File scripts\run-flutter-web.ps1 -App seller
```

Android Studio에서는 상단 Run Configuration 목록에서 `Flutter Web - Customer (5183)` 또는 `Flutter Web - Seller (5184)`를 선택한 뒤 Chrome 기기로 실행한다. `main.dart (1)`처럼 자동 생성된 임시 구성은 고정 포트 인자를 포함하지 않는다.

## 전체 검증

```powershell
powershell -ExecutionPolicy Bypass -File mobile_flutter\tool\verify.ps1
```

Docker는 Flutter 화면·단위 테스트에 필요하지 않다. 실제 Spring Boot 계약을 검증할 때만 통합 스택을 실행한다.

소비자 앱 디버그 APK는 다음 명령과 경로에서 확인한다.

```powershell
cd mobile_flutter\apps\customer_app
flutter build apk --debug
# build\app\outputs\flutter-apk\app-debug.apk
```

판매자 앱은 별도 application ID와 보안 세션 키를 사용한다. 디버그 APK는 다음 경로에서 생성한다.

```powershell
cd mobile_flutter\apps\seller_app
flutter build apk --debug
# build\app\outputs\flutter-apk\app-debug.apk
```
