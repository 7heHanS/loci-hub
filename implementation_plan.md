# LociHub 세부 구현 계획서 (v3 — 최종)

> **기반 문서:** [LociHub_Master_Plan.md](file:///home/thehans.han/LociHub/LociHub_Master_Plan.md)
> **대상 디바이스:** Samsung Galaxy Z Fold 6 (Android 14 / One UI 6, API 34+)
> **프레임워크:** Flutter Stable 채널 (Dart)
> **개발 환경:** Ubuntu Linux
> **패키지명:** `com.locihub.app`

---

## v2 → v3 변경 요약

| # | 변경 사항 | 분류 |
|---|---|---|
| 1 | Google Maps 오프라인 캐싱 문구 삭제, 네트워크 의존성 명시 | 필수 |
| 2 | Google Cloud 프로젝트/API Key/결제/SHA-1 제한 정책 추가 | 필수 |
| 3 | Android 14+ 부분 사진 접근 권한(`READ_MEDIA_VISUAL_USER_SELECTED`) 대응 | 필수 |
| 4 | `targetSdkVersion 35` Android 15 동작 변경 검증 항목 추가 | 필수 |
| 5 | 복합 인덱스 추가 (`journal_date, timestamp` / `journal_date, taken_at`) | 필수 |
| 6 | `PhotoMetadata.match_status` 필드 추가 | 권장 |
| 7 | `LocationLogs.created_at` 필드 추가 | 권장 |
| 8 | EXIF source별 confidence 가중치 적용 | 권장 |
| 9 | 개발자용 DB export를 1단계에 선반영 | 권장 |

---

## 시간/타임존 정책

> [!IMPORTANT]
> 이 정책은 모든 단계에서 일관되게 적용됩니다.

| 데이터 | 저장 형식 | 기준 |
|---|---|---|
| `LocationLogs.timestamp` | UTC Epoch 초 | `DateTime.now().toUtc().millisecondsSinceEpoch ~/ 1000` |
| `LocationLogs.created_at` | UTC Epoch 초 | DB 삽입 시점 |
| `PhotoMetadata.taken_at` | UTC Epoch 초 | EXIF → 로컬 타임존으로 해석 → UTC 변환 |
| `DailyJournal.journal_date` | `YYYY-MM-DD` 문자열 | **단말 로컬 날짜** 기준 |
| `DailyJournal.created_at` | UTC Epoch 초 | |
| `DailyJournal.updated_at` | UTC Epoch 초 | |

**EXIF 시간 해석:**
```
1. EXIF DateTimeOriginal은 타임존 정보가 없음 → 단말 로컬 타임존으로 간주
2. 로컬 DateTime → UTC Epoch으로 변환하여 DB 저장
3. 해외 여행 사진 오차는 Phase 2에서 EXIF GPS 좌표 기반 타임존 추론으로 보완
```

---

## Google Maps SDK 정책

> [!WARNING]
> Google Maps SDK는 지도 렌더링 품질과 UX가 우수하나, **앱 주도의 오프라인 타일 캐싱/지역 다운로드 제어는 MVP 범위에서 제외**한다. 네트워크가 없는 환경에서는 지도 배경이 제한될 수 있으며, 위치 로그와 사진 매칭 데이터는 로컬 DB에서 계속 조회 가능하다.

### Google Cloud 설정 (1단계 사전 작업)

```
1. Google Cloud Console에서 프로젝트 생성
2. "Maps SDK for Android" API 활성화
3. 결제 계정 연결 확인 (무료 할당량: 월 $200 크레딧)
4. API Key 생성 후 Android 앱 제한 설정:
   - Package name: com.locihub.app
   - SHA-1 fingerprint: debug/release 키스토어 모두 등록
5. API Key를 소스에 직접 커밋하지 않음
   - local.properties 또는 Gradle secrets-gradle-plugin 방식으로 관리
   - .gitignore에 API 키 파일 등록
```

### `AndroidManifest.xml` 설정

```xml
<meta-data
    android:name="com.google.android.geo.API_KEY"
    android:value="${MAPS_API_KEY}" />
```

---

## Android 15 (targetSdkVersion 35) 대응 정책

> [!IMPORTANT]
> `targetSdkVersion 35` 사용 시 Android 15 동작 변경을 별도 검증한다.

| 변경 사항 | 영향 | 대응 |
|---|---|---|
| Edge-to-edge UI 기본 적용 | 상태바/네비게이션바 투명화 | `SystemUiOverlayStyle` 설정 확인 |
| Foreground Service 시작 제한 강화 | `location` 타입은 직접 영향 제한적 | 사용자 명시적 시작 정책으로 이미 대응 |
| `dataSync`/`mediaProcessing` 타입 시간 제한 | 본 앱 미사용 | 해당 없음 |
| BOOT_COMPLETED 자동 시작 제한 | autoStart 미사용 | 해당 없음 |
| 부분 사진 접근 권한 UX 변경 | Photo Picker 권장 강화 | 3단계 권한 플로우에서 대응 |

---

## 프로젝트 디렉토리 구조

```
LociHub/
├── LociHub_Master_Plan.md              # 마스터 플랜 (기존)
├── loci_hub/                           # Flutter 프로젝트 루트
│   ├── android/
│   │   └── app/src/main/
│   │       ├── AndroidManifest.xml
│   │       └── res/
│   ├── lib/
│   │   ├── main.dart                   # 앱 진입점
│   │   ├── app.dart                    # MaterialApp 및 라우팅
│   │   │
│   │   ├── core/
│   │   │   ├── constants/
│   │   │   │   ├── app_constants.dart
│   │   │   │   └── tracking_constants.dart
│   │   │   ├── theme/
│   │   │   │   ├── app_theme.dart
│   │   │   │   └── app_colors.dart
│   │   │   ├── utils/
│   │   │   │   ├── date_utils.dart
│   │   │   │   ├── timezone_utils.dart
│   │   │   │   ├── permission_handler.dart
│   │   │   │   └── db_export_util.dart       # [NEW] 개발자용 DB export
│   │   │   └── di/
│   │   │       └── service_locator.dart
│   │   │
│   │   ├── data/
│   │   │   ├── database/
│   │   │   │   ├── app_database.dart
│   │   │   │   └── dao/
│   │   │   │       ├── daily_journal_dao.dart
│   │   │   │       ├── location_log_dao.dart
│   │   │   │       └── photo_metadata_dao.dart
│   │   │   ├── models/
│   │   │   │   ├── daily_journal.dart
│   │   │   │   ├── location_log.dart
│   │   │   │   ├── photo_metadata.dart
│   │   │   │   └── match_status.dart         # [NEW] enum
│   │   │   └── repositories/
│   │   │       ├── journal_repository.dart
│   │   │       ├── location_repository.dart
│   │   │       └── photo_repository.dart
│   │   │
│   │   ├── services/
│   │   │   ├── location/
│   │   │   │   ├── location_service.dart
│   │   │   │   ├── location_background_service.dart
│   │   │   │   └── motion_detector.dart
│   │   │   └── photo/
│   │   │       ├── exif_parser_service.dart
│   │   │       ├── photo_scanner_service.dart
│   │   │       └── binary_search_matcher.dart
│   │   │
│   │   ├── providers/
│   │   │   ├── journal_provider.dart
│   │   │   ├── location_provider.dart
│   │   │   ├── photo_provider.dart
│   │   │   ├── map_provider.dart
│   │   │   └── calendar_provider.dart
│   │   │
│   │   └── ui/
│   │       ├── screens/
│   │       │   ├── home/
│   │       │   │   ├── home_screen.dart
│   │       │   │   ├── home_unfolded_layout.dart
│   │       │   │   └── home_folded_layout.dart
│   │       │   └── settings/
│   │       │       └── settings_screen.dart
│   │       ├── widgets/
│   │       │   ├── map/
│   │       │   │   ├── loci_map_view.dart
│   │       │   │   ├── route_polyline.dart
│   │       │   │   └── photo_marker.dart
│   │       │   ├── timeline/
│   │       │   │   ├── timeline_feed.dart
│   │       │   │   └── timeline_card.dart
│   │       │   ├── calendar/
│   │       │   │   ├── calendar_selector.dart
│   │       │   │   └── calendar_day_cell.dart
│   │       │   └── common/
│   │       │       ├── tracking_status_indicator.dart
│   │       │       └── loading_shimmer.dart
│   │       └── navigation/
│   │           └── app_router.dart
│   │
│   ├── test/
│   │   ├── unit/
│   │   │   ├── binary_search_matcher_test.dart
│   │   │   ├── motion_detector_test.dart
│   │   │   ├── exif_parser_test.dart
│   │   │   ├── timezone_utils_test.dart
│   │   │   └── dao_test.dart
│   │   └── widget/
│   │       └── home_screen_test.dart
│   │
│   └── pubspec.yaml
```

---

## 핵심 패키지 의존성

| 패키지 | 용도 | 단계 |
|---|---|---|
| `sqflite` | SQLite 로컬 DB | 1단계 |
| `path_provider` | 앱 내부 스토리지 경로 | 1단계 |
| `flutter_riverpod` | 상태 관리 | 1단계 |
| `get_it` | 서비스 로케이터 DI | 1단계 |
| `go_router` | 선언적 라우팅 | 1단계 |
| `intl` | 날짜/시간 포맷팅 | 1단계 |
| `share_plus` | DB/JSON 내보내기 공유 | 1단계 |
| `flutter_background_service` | Foreground Service | 2단계 |
| `geolocator` | GPS 위치 수집 | 2단계 |
| `permission_handler` | 런타임 권한 관리 | 2단계 |
| `photo_manager` | 로컬 갤러리 접근 | 3단계 |
| `exif` | EXIF 메타데이터 파싱 | 3단계 |
| `google_maps_flutter` | Google Maps 렌더링 | 4단계 |
| `table_calendar` | 캘린더 위젯 | 4단계 |

> [!NOTE]
> `flutter_map`, `latlong2`, `cached_network_image` 제거. Google Maps SDK로 지도 렌더링 품질을 우선한다. 단, **오프라인 지도 캐싱은 MVP 범위에서 제외**한다.

---

## Proposed Changes

---

### 📌 1단계: 환경 구성 및 프로젝트 스켈레톤

> 목표: Flutter 프로젝트 생성, 코어 아키텍처 수립, SQLite DB 초기화, 개발자용 DB export

---

#### [NEW] 사전 작업: Google Cloud 설정

```
1. Google Cloud Console 프로젝트 생성
2. Maps SDK for Android 활성화
3. 결제 계정 연결 확인
4. API Key 생성 → Android 앱 제한 설정
   - Package name: com.locihub.app
   - SHA-1: debug keystore fingerprint 등록
5. API Key 관리 정책:
   - android/local.properties에 MAPS_API_KEY=xxx 저장
   - build.gradle에서 manifestPlaceholders로 주입
   - .gitignore에 local.properties 포함 (기본값)
```

---

#### [NEW] Flutter 프로젝트 초기화

```bash
flutter create --org com.locihub --project-name loci_hub --platforms android ./loci_hub
```

- `minSdkVersion 34`, `targetSdkVersion 35`, `compileSdkVersion 35`
- Google Maps API 키: `AndroidManifest.xml`에 `<meta-data>` 추가

> [!IMPORTANT]
> **`targetSdkVersion 35` 리스크**: Android 15 동작 변경(edge-to-edge 기본 적용 등)을 4단계 UI 검증 시 확인한다. 본 앱의 핵심 서비스 타입(`location`)에는 직접 영향이 제한적이나, UI 레이아웃에 영향 가능.

---

#### [NEW] `lib/main.dart`

```dart
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await setupServiceLocator();
  await getIt<AppDatabase>().initialize();
  runApp(const ProviderScope(child: LociHubApp()));
}
```

---

#### [NEW] `lib/core/theme/app_theme.dart`

Material 3 기반 **라이트 + 다크** 테마. Galaxy Z Fold 6 최적화 타이포그래피.

---

#### [NEW] `lib/data/database/app_database.dart` — 최종 스키마

```sql
-- 1. 날짜별 마스터 저널
CREATE TABLE DailyJournal (
    journal_date TEXT PRIMARY KEY,
    ai_title TEXT,
    ai_summary TEXT,
    created_at INTEGER,
    updated_at INTEGER                    -- [v3] 추가
);

-- 2. 시계열 위치 로그
CREATE TABLE LocationLogs (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    journal_date TEXT,
    timestamp INTEGER,                    -- UTC Epoch 초 (위치 발생 시각)
    latitude REAL,
    longitude REAL,
    accuracy REAL,                        -- [v2] GPS 정확도 (미터)
    altitude REAL,                        -- [v2] 고도
    speed REAL,                           -- [v2] 속도 (m/s)
    heading REAL,                         -- [v2] 방향
    provider TEXT,                        -- [v2] 위치 제공자
    activity_type TEXT,                   -- 정지/도보/차량
    created_at INTEGER,                   -- [v3] DB 삽입 시각 (UTC Epoch)
    FOREIGN KEY(journal_date) REFERENCES DailyJournal(journal_date)
);

-- 3. 매칭된 사진 메타데이터
CREATE TABLE PhotoMetadata (
    asset_id TEXT PRIMARY KEY,            -- [v2] Scoped Storage 대응
    journal_date TEXT,
    asset_title TEXT,                     -- [v2] 파일명
    relative_path TEXT,                   -- [v2] 상대 경로 (보조)
    photo_path TEXT,                      -- nullable, 보조 정보
    taken_at INTEGER,                     -- UTC Epoch 초
    taken_time_source TEXT,               -- [v2] exif_original|exif_digitized|image_datetime|asset_create_time
    matched_lat REAL,
    matched_lng REAL,
    matched_confidence REAL,              -- [v2] 0.0~1.0 (source 가중치 반영)
    match_time_diff_seconds INTEGER,      -- [v2] 시간 차이 (초)
    match_status TEXT DEFAULT 'pending',  -- [v3] pending|matched|unmatched_no_location|unmatched_out_of_tolerance
    FOREIGN KEY(journal_date) REFERENCES DailyJournal(journal_date)
);

-- 성능 인덱스
CREATE INDEX idx_location_timestamp ON LocationLogs(timestamp);
CREATE INDEX idx_location_date ON LocationLogs(journal_date);
CREATE INDEX idx_location_date_timestamp ON LocationLogs(journal_date, timestamp);  -- [v3] 복합
CREATE INDEX idx_photo_taken ON PhotoMetadata(taken_at);
CREATE INDEX idx_photo_date ON PhotoMetadata(journal_date);
CREATE INDEX idx_photo_date_taken ON PhotoMetadata(journal_date, taken_at);          -- [v3] 복합
```

> [!NOTE]
> **v3 추가 사항:**
> - `LocationLogs.created_at`: DB 삽입 시각. 장시간 테스트/디버깅용
> - `PhotoMetadata.match_status`: 매칭 상태 enum. UI 표시 및 재매칭 로직에 활용
> - 복합 인덱스 2개: `getByDateSorted()` 쿼리 최적화

---

#### [NEW] `lib/data/models/match_status.dart`

```dart
enum MatchStatus {
  pending,                    // 스캔 완료, 매칭 미시도
  matched,                   // 매칭 성공
  unmatchedNoLocation,        // 해당 날짜 위치 로그 없음
  unmatchedOutOfTolerance,    // 위치 로그 있으나 허용 오차 초과
}
```

---

#### [NEW] `lib/data/models/` — 데이터 모델 3종

**`DailyJournal`:**
- `journalDate`, `aiTitle`, `aiSummary`, `createdAt`, `updatedAt`

**`LocationLog`:**
- `id`, `journalDate`, `timestamp`, `latitude`, `longitude`
- `accuracy`, `altitude`, `speed`, `heading`, `provider`, `activityType`
- `createdAt`

**`PhotoMetadata`:**
- `assetId`(PK), `journalDate`, `assetTitle`, `relativePath`, `photoPath`
- `takenAt`, `takenTimeSource`
- `matchedLat`, `matchedLng`, `matchedConfidence`, `matchTimeDiffSeconds`
- `matchStatus`

각 모델: `toMap()`, `fromMap()`, `copyWith()` 포함.

---

#### [NEW] `lib/data/database/dao/` — DAO 3종

**`DailyJournalDao`:**
- `insertOrReplace()`, `getByDate()`, `getDateRange()`, `getDatesWithData()`
- `updateTimestamp()` — `updated_at` 갱신

**`LocationLogDao`:**
- `insertBatch()`, `getByDateSorted()` — 복합 인덱스 활용
- `getByTimestampRange()`, `getClosestToTimestamp()`
- `getCountByDate()`, `getHighAccuracyByDate(accuracy)`

**`PhotoMetadataDao`:**
- `insertOrReplace()`, `getByDate()`, `getUnmatched()`, `getPending()`
- `updateMatchResult()`, `existsByAssetId()`
- `getByMatchStatus(MatchStatus)`

---

#### [NEW] `lib/core/utils/timezone_utils.dart`

```dart
class TimezoneUtils {
  /// EXIF "YYYY:MM:DD HH:MM:SS" → UTC Epoch 초
  static int exifToUtcEpoch(String exifDateStr) { ... }
  
  /// UTC Epoch → 로컬 journal_date (YYYY-MM-DD)
  static String epochToJournalDate(int utcEpoch) { ... }
  
  /// 현재 시각의 journal_date
  static String todayJournalDate() { ... }
}
```

---

#### [NEW] `lib/core/utils/db_export_util.dart` — 개발자용 DB export

> [!NOTE]
> 개발 중 데이터 검증을 위해 1단계에 선반영. 4단계에서 사용자용 UI로 승격.

```dart
class DbExportUtil {
  /// SQLite DB 파일을 외부 공유 가능 경로로 복사
  Future<File> exportDbFile() async { ... }
  
  /// LocationLogs를 JSON으로 내보내기
  Future<File> exportLocationLogsJson({String? journalDate}) async { ... }
  
  /// PhotoMetadata를 JSON으로 내보내기
  Future<File> exportPhotoMetadataJson({String? journalDate}) async { ... }
}
```

---

#### 1단계 검증

- `flutter doctor` 통과
- Galaxy Z Fold 6 USB 디버깅 빌드 & 실행
- SQLite 테이블 생성 검증 (전체 컬럼 + 인덱스)
- DAO 단위 테스트: 인메모리 DB CRUD + 복합 인덱스 쿼리
- `TimezoneUtils` 단위 테스트
- `DbExportUtil` 수동 확인: `adb pull`로 DB 파일 추출 가능 확인
- Google Maps API 키 설정 확인 (4단계 대비 사전 검증)

---

### 📌 2단계: 백그라운드 위치 트래커 구현

> 목표: **사용자가 명시적으로 추적을 시작한 경우**, Foreground Service 알림을 유지하면서 지속 수집

---

#### [NEW] `android/app/src/main/AndroidManifest.xml` 퍼미션

```xml
<!-- 위치 권한 -->
<uses-permission android:name="android.permission.ACCESS_FINE_LOCATION" />
<uses-permission android:name="android.permission.ACCESS_COARSE_LOCATION" />
<uses-permission android:name="android.permission.ACCESS_BACKGROUND_LOCATION" />

<!-- Foreground Service (Android 14+ 필수) -->
<uses-permission android:name="android.permission.FOREGROUND_SERVICE" />
<uses-permission android:name="android.permission.FOREGROUND_SERVICE_LOCATION" />
<uses-permission android:name="android.permission.POST_NOTIFICATIONS" />

<!-- 서비스 등록 -->
<service
    android:name="id.flutter.flutter_background_service.BackgroundService"
    android:foregroundServiceType="location" />
```

> [!NOTE]
> `ACTIVITY_RECOGNITION` 및 ActivityRecognition API는 초기 구현에서 **제외**. GPS 속도/거리 기반 간이 판정으로 대체.

---

#### [NEW] `lib/core/utils/permission_handler.dart`

**단계적 권한 요청 플로우:**

```
1단계: ACCESS_FINE_LOCATION
   → 거부: 기능 제한 안내 → 설정 유도

2단계: ACCESS_BACKGROUND_LOCATION (별도 단계)
   → 미허용: "앱 사용 중에만 수집, 백그라운드 추적 불가" 안내

3단계: POST_NOTIFICATIONS
   → 거부: "추적 상태 표시가 제한될 수 있으며,
           기기/OS 정책에 따라 서비스 유지성이 달라질 수 있음" 안내
```

---

#### [NEW] `lib/services/location/location_background_service.dart`

```dart
class LocationBackgroundService {
  /// 사용자가 "추적 시작" 탭 시 호출
  Future<bool> startTracking() async { ... }
  
  /// 사용자가 "추적 중지" 탭 시 호출
  Future<void> stopTracking() async { ... }
  
  /// 추적 상태 조회
  Future<bool> isTracking() async { ... }
}
```

> [!IMPORTANT]
> - `autoStart: false` — 자동 재시작하지 않음
> - 앱 강제 종료/재부팅 후 사용자가 명시적으로 재시작해야 함
> - `autoStartOnBoot` 옵션은 Phase 2 검토

**서비스 Isolate 로직:**
- Isolate 내 별도 DB 연결 생성
- `MotionDetector`로 수집 간격 동적 조절
- accuracy 기록, 자정 교차 감지, UI 갱신 알림
- `LocationLogs.created_at`에 DB 삽입 시각 기록

---

#### [NEW] `lib/services/location/motion_detector.dart`

**GPS 속도/거리 기반 간이 이동 상태 감지:**

```dart
enum MotionState { stationary, walking, vehicle }

class MotionDetector {
  MotionState detectMotion(List<LocationLog> recentLogs) {
    // 판정 기준:
    // 1. accuracy <= 50m인 샘플만 사용
    // 2. 최근 5개 좌표의 이동 거리 합 계산
    // 3. 평균 속도 계산 (geolocator speed 필드)
    //
    // 분기:
    // - 거리합 < 30m AND 평균 속도 < 0.5 m/s → STATIONARY (5분)
    // - 평균 속도 < 2.0 m/s → WALKING (60초)
    // - 평균 속도 >= 2.0 m/s → VEHICLE (30초)
  }
}
```

**상수 (`tracking_constants.dart`):**
```dart
const int kIntervalStationary = 300;     // 5분
const int kIntervalWalking = 60;         // 1분
const int kIntervalVehicle = 30;         // 30초
const double kStationaryDistanceM = 30;
const double kStationarySpeedMs = 0.5;
const double kWalkingSpeedMs = 2.0;
const double kAccuracyThresholdM = 50;
const int kRecentSampleCount = 5;
```

---

#### 2단계 검증

**자동 테스트:** `MotionDetector` 상태 전환, 거리 계산

**실기기 테스트:**

| 시나리오 | 검증 항목 |
|---|---|
| 추적 시작 → 홈 나감 | 알림 유지 |
| 30분 도보 | 좌표 ≈ 30개, 간격 ≈ 60초 |
| 10분 정지 | 주기 5분 전환 |
| 차량 10분 | 주기 30초, 좌표 ≈ 20개 |
| 앱 강제 종료 | 서비스 유지 여부 |
| 앱 설정>강제 중지 | 서비스 종료 (예상) |
| 재부팅 | 자동 재시작 안 함 |
| 자정 넘김 | 새 DailyJournal 생성 |
| 3시간 연속 도보 | ≈ 180 포인트, 누락 없음 |
| 8시간 대기 | ≈ 96 포인트, 배터리 소모 최소 |
| 배터리 소모 | 3시간 추적 후 통계 |

**권한 테스트:**

| 시나리오 | 예상 |
|---|---|
| 위치 완전 거부 | 추적 시작 불가 |
| "앱 사용 중에만" | 포그라운드만 수집 |
| 항상 허용 | 정상 동작 |
| 알림 거부 | 서비스 시작 가능, 유지성 리스크 안내 |
| 추적 중 권한 철회 | graceful 종료 |

---

### 📌 3단계: EXIF 파서 및 이진 탐색 매칭 엔진

> 목표: 갤러리 사진 촬영 시간 추출, 위치 로그 자동 매핑

---

#### [NEW] 퍼미션 — Android 14+ 부분 사진 접근 대응

```xml
<uses-permission android:name="android.permission.READ_MEDIA_IMAGES" />
<uses-permission android:name="android.permission.READ_MEDIA_VISUAL_USER_SELECTED" />
```

**사진 접근 권한 3단계 분기:**

| 상태 | 동작 |
|---|---|
| **전체 접근 허용** | 모든 사진 자동 스캔 및 매칭 |
| **선택 사진만 허용** | 접근 가능한 사진만 스캔. "전체 접근 허용" 전환 안내 표시 |
| **거부** | 사진 매칭 기능 비활성화. 위치 추적만 사용 가능 |

```dart
// permission_handler.dart에 추가
Future<PhotoAccessLevel> checkPhotoAccess() async {
  // Android 14+: READ_MEDIA_VISUAL_USER_SELECTED 상태 확인
  // 전체 허용 / 부분 허용 / 거부 3단계 분기
}
```

---

#### [NEW] `lib/services/photo/photo_scanner_service.dart`

```dart
class PhotoScannerService {
  Future<List<AssetEntity>> scanNewPhotos({
    required DateTime from,
    required DateTime to,
  }) async {
    // 1. photo_manager로 날짜 범위 필터링
    // 2. DB 기등록 asset_id 제외 (Set 차집합)
    // 3. 부분 접근 상태에서는 접근 가능 사진만 반환
  }
}
```

---

#### [NEW] `lib/services/photo/exif_parser_service.dart`

```dart
class ExifParserService {
  Future<TakenTimeResult> extractTakenTime(AssetEntity asset) async {
    // EXIF 태그 우선순위:
    // 1. DateTimeOriginal (source: exifOriginal)
    // 2. DateTimeDigitized (source: exifDigitized)
    // 3. DateTime (source: imageDateTime)
    // 4. asset.createDateTime (source: assetCreateTime)
    //
    // 타임존 정책: EXIF → 로컬 해석 → UTC 변환
  }
}

enum TakenTimeSource {
  exifOriginal,     // 가중치 1.0
  exifDigitized,    // 가중치 0.9
  imageDateTime,    // 가중치 0.8
  assetCreateTime,  // 가중치 0.5
}
```

---

#### [NEW] `lib/services/photo/binary_search_matcher.dart`

**confidence 계산 — source 가중치 반영:**

```dart
class BinarySearchMatcher {
  static const int defaultToleranceMinutes = 5;

  /// source별 신뢰도 가중치
  static const Map<TakenTimeSource, double> sourceWeights = {
    TakenTimeSource.exifOriginal: 1.0,
    TakenTimeSource.exifDigitized: 0.9,
    TakenTimeSource.imageDateTime: 0.8,
    TakenTimeSource.assetCreateTime: 0.5,
  };

  MatchResult? findClosestLocation({
    required int photoTimestamp,
    required List<LocationLog> sortedLogs,
    required TakenTimeSource timeSource,    // [v3] source 전달
    int toleranceMinutes = defaultToleranceMinutes,
  }) {
    if (sortedLogs.isEmpty) return null;
    
    final toleranceSec = toleranceMinutes * 60;
    
    // 이진 탐색 (v2와 동일)
    int lo = 0, hi = sortedLogs.length - 1;
    while (lo < hi) {
      final mid = (lo + hi) ~/ 2;
      if (sortedLogs[mid].timestamp < photoTimestamp) lo = mid + 1;
      else hi = mid;
    }
    
    LocationLog? closest;
    int minDiff = toleranceSec + 1;
    for (int i = max(0, lo - 1); i <= min(lo, sortedLogs.length - 1); i++) {
      final diff = (sortedLogs[i].timestamp - photoTimestamp).abs();
      if (diff < minDiff) { minDiff = diff; closest = sortedLogs[i]; }
    }
    
    if (closest != null && minDiff <= toleranceSec) {
      // [v3] 최종 confidence = 시간 기반 × source 가중치
      final timeConfidence = 1.0 - (minDiff / toleranceSec);
      final sourceWeight = sourceWeights[timeSource] ?? 0.5;
      final finalConfidence = timeConfidence * sourceWeight;
      
      return MatchResult(
        location: closest,
        timeDiffSeconds: minDiff,
        confidence: finalConfidence,
        matchStatus: MatchStatus.matched,
      );
    }
    return null;
  }
}
```

**매칭 파이프라인 (match_status 반영):**

```
[포그라운드 진입 또는 수동 동기화]
    │
    ▼
[PhotoScannerService] → 신규 사진 → match_status = pending
    │
    ▼
[ExifParserService] → taken_at + taken_time_source
    │
    ▼
[날짜별 그룹핑]
    │
    ├── 해당 날짜 LocationLogs 없음 → match_status = unmatched_no_location
    │
    └── LocationLogs 있음 → [BinarySearchMatcher]
        │
        ├── 매칭 성공 → match_status = matched
        └── 오차 초과 → match_status = unmatched_out_of_tolerance
```

> [!IMPORTANT]
> **매칭 트리거:**
> 1. 앱 포그라운드 진입 시 → 신규 사진 자동 매칭
> 2. 사용자 "사진 동기화" 버튼 → 수동 트리거
> 3. ~~백그라운드 주기 실행~~ → **제거됨**

---

#### 3단계 검증

**단위 테스트:**

| 대상 | 케이스 |
|---|---|
| `BinarySearchMatcher` | 빈 리스트, 정확 일치, ±5분 경계, 로그 1개, 범위 밖 |
| `BinarySearchMatcher` | source 가중치: exifOriginal(1.0) vs assetCreateTime(0.5) |
| `ExifParserService` | EXIF 있음/없음, 태그 우선순위, 잘못된 날짜 |
| `TimezoneUtils` | EXIF→UTC 변환, 자정 전후 |
| `match_status` 전이 | pending→matched, pending→unmatched_* |

**통합 테스트 (실기기):**

| 시나리오 | 검증 |
|---|---|
| 추적 중 사진 촬영 → 앱 진입 | 올바른 좌표 매칭, status=matched |
| 5분 차이 | 매칭 성공, confidence ≈ 0.0 × sourceWeight |
| 6분 차이 | 매칭 실패, status=unmatched_out_of_tolerance |
| EXIF 없는 스크린샷 | source=assetCreateTime, confidence 낮음 |
| 위치 로그 없는 날짜 | status=unmatched_no_location |
| 부분 사진 접근 | 선택된 사진만 스캔됨 |
| 전체 사진 접근 | 모든 사진 스캔 |

---

### 📌 4단계: 하이브리드 UI 및 폴더블 반응형 리팩토링

> 목표: Galaxy Z Fold 6 최적화 UI — **MVP 범위**

---

#### MVP 기능

| 기능 | 포함 |
|---|---|
| 날짜 선택 (캘린더 picker) | ✅ |
| 당일 Google Maps Polyline | ✅ |
| 사진 위치 기본 마커 | ✅ |
| 타임라인 리스트 (시간순) | ✅ |
| 추적 ON/OFF 토글 + 상태 | ✅ |
| 펼침/접음 반응형 분기 | ✅ |
| DB 내보내기 UI (설정 화면) | ✅ |

#### 후순위 (Phase 2)

| 기능 | 비고 |
|---|---|
| 지도 ↔ 타임라인 양방향 동기화 | 양방향 스크롤 연동 |
| 사진 썸네일 커스텀 마커 | 기본 마커로 시작 |
| 마커 탭 확대 애니메이션 | UX 폴리싱 |
| 풀다운 캘린더 드래그 제스처 | 단순 picker로 시작 |
| 그라데이션 Polyline | 단색으로 시작 |
| 포인트 다운샘플링 (Douglas-Peucker) | 2,000개 초과 시 |

---

#### [NEW] `lib/ui/screens/home/home_screen.dart`

```dart
class HomeScreen extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isUnfolded = constraints.maxWidth > 600;
        return isUnfolded ? HomeUnfoldedLayout() : HomeFoldedLayout();
      },
    );
  }
}
```

---

#### [NEW] `lib/ui/screens/home/home_unfolded_layout.dart` (펼침)

```
┌──────────────────────────────────────────────────────────────┐
│  📅 2026년 6월 8일 일요일                    [날짜 선택 버튼] │
├──────────────────────────┬───────────────────────────────────┤
│                          │                                   │
│     🗺️ Google Maps       │  🕐 09:00  이동 시작              │
│     ── Polyline 경로 ──  │  📷 09:15  [사진 썸네일]           │
│     📍 사진 마커         │  🕐 09:30  정지                   │
│          (60%)           │           (40%)                   │
├──────────────────────────┴───────────────────────────────────┤
│  ● 추적 중 [중지]  |  1,234 포인트  |  12장 매칭             │
└──────────────────────────────────────────────────────────────┘
```

---

#### [NEW] `lib/ui/screens/home/home_folded_layout.dart` (접음)

```
┌─────────────────────────┐
│ 📅 2026.06.08   [선택]  │
├─────────────────────────┤
│   🗺️ Google Maps (40%)  │
│   ── Polyline + 마커 ── │
├─────────────────────────┤
│ ┌─────────────────────┐ │
│ │ 🕐 09:00 이동 시작  │ │
│ └─────────────────────┘ │
│ ┌─────────────────────┐ │
│ │ 🕐 09:30 정지       │ │
│ └─────────────────────┘ │
└─────────────────────────┘
```

> [!IMPORTANT]
> `GoogleMap` 위젯은 **bounded size** 안에 있어야 함. `Expanded`, `SizedBox` 등으로 명확한 크기 제약 필요. `ListView` 내부에 직접 배치 시 Flutter 예외 발생 가능.

---

#### [NEW] `lib/ui/widgets/map/loci_map_view.dart`

`google_maps_flutter` 래퍼:
- `Polyline`: 당일 이동 경로 단색 표시
- `Marker`: 매칭 사진 위치에 기본 마커
- 마커 탭 → `InfoWindow`로 시간/매칭 정보 표시
- bounded widget 내 배치 보장

---

#### [NEW] `lib/ui/screens/settings/settings_screen.dart`

- 추적 설정 (수집 주기 표시)
- 사진 매칭 오차 범위 설정 (1/3/5/10/30분 선택)
- **DB 내보내기**: SQLite 파일 / JSON 공유 (`share_plus`)
- 사진 접근 권한 상태 표시 + 설정 이동

---

#### 4단계 검증

**위젯 테스트:** `LayoutBuilder` 600dp 분기

**실기기 테스트:**

| 시나리오 | 검증 |
|---|---|
| 펼침/접음 전환 | 레이아웃 즉시 전환, 깜빡임 없음 |
| Polyline 1,000 포인트 | 정상 렌더링 |
| 기본 마커 100개 | 프레임 드롭 없음 |
| 캘린더 날짜 전환 | 로드 < 500ms |
| 추적 토글 | 상태 즉시 반영 |
| DB 내보내기 | JSON/SQLite 공유 정상 |
| Edge-to-edge (Android 15) | 상태바/네비바 겹침 없음 |
| GoogleMap bounded size | Expanded 내 정상 렌더링 |

**성능 테스트:**

| 규모 | 검증 |
|---|---|
| LocationLogs 10만 건 | 날짜별 조회 < 100ms |
| PhotoMetadata 1만 건 | 날짜별 조회 < 50ms |
| 하루 5,000 포인트 | Polyline 렌더링 |
| 마커 100개 | 지도 렌더링 |

---

## Verification Plan (전체)

### Automated Tests

```bash
cd loci_hub

# 정적 분석
flutter analyze

# 전체 단위 테스트
flutter test

# 개별 테스트
flutter test test/unit/binary_search_matcher_test.dart
flutter test test/unit/motion_detector_test.dart
flutter test test/unit/exif_parser_test.dart
flutter test test/unit/timezone_utils_test.dart
flutter test test/unit/dao_test.dart
```

### Manual Verification

**장시간 테스트 (2단계 이후):**
- 3시간 연속 이동, 8시간 대기, 자정 넘김
- 앱 강제 종료, 재부팅 후 동작 확인

**데이터 정합성 (3단계 이후):**
- timestamp 중복, journal_date 경계, EXIF 없는 사진
- 위치 로그 없는 날짜, match_status 전이 확인

**권한 테스트 (2, 3단계):**
- 위치: 거부/사용 중만/항상
- 알림: 거부/허용
- 사진: 거부/부분/전체

**Android 15 대응 (4단계):**
- Edge-to-edge UI 확인
- Foreground Service 동작 확인
