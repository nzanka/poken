# 포근길 (Flutter 앱 스캐폴드)

산책 모드와 러닝 모드를 한 엔진으로 지원하는 걷기 RPG. **아직 컴파일, 실행 검증 전**이므로 아래 1~3단계를 먼저 하세요.

## 구조
- `lib/core/game_engine.dart` : 성장, 지도, 보스, 부정 방지 규칙 (순수 Dart, 테스트 있음)
- `lib/services/activity_source.dart` : 건강 데이터(HealthKit / Health Connect) 읽기 + 에뮬레이터용 Mock
- `lib/services/crew_repository.dart` : 크루 생성, 가입, 주간 합산 (Supabase)
- `lib/main.dart` : 모드 선택 + 홈 화면 최소 구현
- `supabase/schema.sql` : 크루, 활동 기록 테이블과 보안 정책

## 시작하기
1. Flutter SDK 설치 후, 이 폴더에서 플랫폼 파일 생성:
   `flutter create --project-name pokeun_gil --org com.yourname .`
   (기존 lib, pubspec은 유지하세요. 덮어쓰기 확인이 나오면 lib/main.dart와 pubspec.yaml은 건너뜀)
2. `flutter pub get` 후 `flutter test` (엔진 테스트 7개)
3. `flutter run` (에뮬레이터는 Mock 걸음 수 버튼 사용)

## 건강 데이터 연동 (실기기)
**Android** (`android/app/src/main/AndroidManifest.xml`)
- 권한: `android.permission.health.READ_STEPS`, `READ_DISTANCE`, `READ_EXERCISE`
- `<activity>` 안에 intent-filter 추가: `androidx.health.ACTION_SHOW_PERMISSIONS_RATIONALE`
- `MainActivity`를 `FlutterFragmentActivity`로 변경, minSdk 26 이상

**iOS**
- Xcode에서 HealthKit capability 추가
- `Info.plist`에 `NSHealthShareUsageDescription` (예: 걸음 수와 달리기 기록으로 캐릭터를 키워요)

실기기 실행: `flutter run --dart-define=USE_HEALTH=true`

## 크루 서버
1. Supabase 프로젝트 생성 → SQL Editor에서 `supabase/schema.sql` 실행
2. `flutter run --dart-define=SUPABASE_URL=... --dart-define=SUPABASE_ANON_KEY=...`

## 다음 할 일 (우선순위)
1. 실기기에서 건강 데이터 연동 확인 (health 패키지 버전 API 맞추기)
2. 로그인(익명 로그인 → 소셜), 프로필 생성
3. 웹 프로토타입의 이벤트, 동료, 캠프 꾸미기를 Flutter로 이식
4. 크루 화면 + 주간 레이드 (crew_weekly_totals 기반 보스 HP)
5. 홈 화면 위젯, 푸시 알림, 구독 결제 (RevenueCat 권장)

## 개인정보 원칙
GPS 경로는 저장하지 않고 걸음 수, 거리, 평균 페이스만 사용. 수동 입력 기록은 제외.

## 내 컴퓨터에 Flutter 없이 APK 받기 (무료)
1. github.com 가입 → 새 저장소(Repository) 만들기
2. 이 폴더의 내용 전체를 저장소에 업로드 (`.github` 폴더 포함)
3. 저장소의 Actions 탭 → "Build Android APK" 실행 (업로드하면 자동 실행됨)
4. 완료되면 실행 결과 화면 맨 아래 Artifacts에서 `pokeun-gil-apk` 다운로드 → APK를 안드로이드 폰에 설치
5. 빨간 X로 실패하면 로그를 복사해서 Claude에게 전달 (오류 수정에 필요)

## 참고
- tools/debug.keystore 는 **테스트 빌드용 공개 키**입니다. 스토어 출시 때는 별도의 비공개 키로 교체하세요.
- 앱을 다시 열 때마다 걸음 수를 새로 읽고, 날짜가 바뀌면 전날 못 받은 보상을 자동 정산합니다.
