# Walkthrough: LociHub Implementation (Complete Phase 1–4)

All phases of the LociHub project have been successfully completed, verified, and compiled. Below is a detailed summary of the architecture, components created, and verification results.

---

## 1. Environment & SDK Setup
We configured the environment natively on the host machine to support Android SDK development:
- **Java**: Adoptium (Eclipse Temurin) OpenJDK 17 (`openjdk 17.0.19`)
- **Android SDK**: Command Line Tools, Android SDK Platform-36, Build-Tools 36.0.0, and Platform-Tools (API 34, 35, 36)
- **Flutter SDK**: Channel `stable` (`3.44.1`)
- All Android developer licenses were accepted, and `flutter doctor` was run to verify zero Android toolchain errors.

---

## 2. Project Skeleton & Build Configurations
- Initialized a Kotlin-based Flutter project (`loci_hub`) with organization `com.locihub`.
- Updated package identifiers to match the project requirements:
  - Application ID: `com.locihub.app`
  - MainActivity Package: `com.locihub.app` (restructured `/android/app/src/main/kotlin/com/locihub/app/MainActivity.kt`)
- Integrated build properties:
  - Created a local-only `MAPS_API_KEY` placeholder in `local.properties`.
  - Configured Gradle key injection using `manifestPlaceholders` in `android/app/build.gradle.kts`.
- Configured Gradle SDK parameters:
  - `minSdk = 34` (Android 14+ / Galaxy Z Fold 6 optimization boundary)
  - `targetSdk = 35` (Android 15 / targetSdkVersion 35 compliance)
  - `compileSdk = 36` (to support newer dependencies requiring Android 16 compileSdk)
  - Overrode compile SDK version to `36` for all project plugin dependencies dynamically via `android/build.gradle.kts` to prevent compilation/AAR checks failures.

---

## 3. Database Schema & Models
We implemented the SQLite database schema inside [app_database.dart](file:///home/thehans.han/LociHub/loci_hub/lib/data/database/app_database.dart).

### Database Schema Details:
- **`PRAGMA foreign_keys = ON`** is explicitly enabled in `onConfigure` to enforce data integrity.
- **`DailyJournal`** table: Tracks dates in local timezone string format (`YYYY-MM-DD`).
- **`LocationLogs`** table: Stores UTC epoch timestamp coordinates and quality columns (accuracy, altitude, speed, heading, provider). Enforces a foreign key constraint to `DailyJournal` with `ON DELETE CASCADE`. Includes `created_at` field to track insert times.
- **`PhotoMetadata`** table: Stores Scoped Storage asset IDs, taken time source, time differentials, and a matched status field (`pending`, `matched`, `unmatched_no_location`, `unmatched_out_of_tolerance`). Enforces a foreign key constraint to `DailyJournal` with `ON DELETE CASCADE`.
- **Composite Indexes** added to optimize query sorting:
  - `idx_location_date_timestamp` on `LocationLogs(journal_date, timestamp)`
  - `idx_photo_date_taken` on `PhotoMetadata(journal_date, taken_at)`

### Models Implemented:
- [MatchStatus](file:///home/thehans.han/LociHub/loci_hub/lib/data/models/match_status.dart): String-to-DB mapping methods (`toDbValue()` and `fromDb()`).
- [TakenTimeSource](file:///home/thehans.han/LociHub/loci_hub/lib/data/models/taken_time_source.dart): String-to-DB mapping methods and confidence source weights.
- [DailyJournal](file:///home/thehans.han/LociHub/loci_hub/lib/data/models/daily_journal.dart), [LocationLog](file:///home/thehans.han/LociHub/loci_hub/lib/data/models/location_log.dart), [PhotoMetadata](file:///home/thehans.han/LociHub/loci_hub/lib/data/models/photo_metadata.dart): Type-safe data objects with serialization/deserialization helpers (`toMap()`, `fromMap()`, `copyWith()`).

---

## 4. DAOs, Repositories, and DI
- **DAOs**: Implemented [DailyJournalDao](file:///home/thehans.han/LociHub/loci_hub/lib/data/database/dao/daily_journal_dao.dart), [LocationLogDao](file:///home/thehans.han/LociHub/loci_hub/lib/data/database/dao/location_log_dao.dart) (supports fast binary-index-aware search for closest coordinates), and [PhotoMetadataDao](file:///home/thehans.han/LociHub/loci_hub/lib/data/database/dao/photo_metadata_dao.dart).
- **Repositories**: Implemented [JournalRepository](file:///home/thehans.han/LociHub/loci_hub/lib/data/repositories/journal_repository.dart), [LocationRepository](file:///home/thehans.han/LociHub/loci_hub/lib/data/repositories/location_repository.dart), and [PhotoRepository](file:///home/thehans.han/LociHub/loci_hub/lib/data/repositories/photo_repository.dart). They handle wrapping database transactions and ensuring foreign key records exist beforehand.
- **Service Locator**: Configured Dependency Injection in [service_locator.dart](file:///home/thehans.han/LociHub/loci_hub/lib/core/di/service_locator.dart) using `GetIt`.

---

## 5. Background Location Tracking (Phase 2)
- Implemented [LocationBackgroundService](file:///home/thehans.han/LociHub/loci_hub/lib/services/location/location_background_service.dart) leveraging `flutter_background_service` to run a sticky foreground service with a customized notification UI.
- Developed [MotionDetector](file:///home/thehans.han/LociHub/loci_hub/lib/services/location/motion_detector.dart) that dynamically shifts the location sampling rate based on speed and distance metrics:
  - **Stationary**: 5 minutes interval (reduces battery drain)
  - **Walking**: 1 minute interval
  - **Vehicle**: 30 seconds interval
- Connected the service isolate with a separate DB connection to prevent thread lock issues.
- **Bug Fix (Android Notification Channel Crash)**: Resolved a crash where starting location tracking from the "tracking stopped" status caused the app to terminate with `invalid channel for service notification: Notification(channel=loci_hub_tracking)`. We fixed this by registering the required `loci_hub_tracking` notification channel in Kotlin ([MainActivity.kt](file:///home/thehans.han/LociHub/loci_hub/android/app/src/main/kotlin/com/locihub/app/MainActivity.kt)) on application startup.

---

## 6. EXIF Photo Matching Engine (Phase 3)
- Configured Scoped Storage permissions (`READ_MEDIA_IMAGES` and `READ_MEDIA_VISUAL_USER_SELECTED` for Android 14+ partial selection).
- Implemented [PhotoScannerService](file:///home/thehans.han/LociHub/loci_hub/lib/services/photo/photo_scanner_service.dart) to detect newly added photos in the local gallery.
- Implemented [ExifParserService](file:///home/thehans.han/LociHub/loci_hub/lib/services/photo/exif_parser_service.dart) using `exif` to extract DateTimeOriginal, fallback to DateTimeDigitized, DateTime, and file creation dates.
- Implemented [BinarySearchMatcher](file:///home/thehans.han/LociHub/loci_hub/lib/services/photo/binary_search_matcher.dart) to associate photo timestamps to coordinates with confidence decaying by time-offset, scaled by the precision of the EXIF date source.

---

## 7. Foldable Responsive UI & Google Maps (Phase 4)
- Integrates `google_maps_flutter` inside [LociMapView](file:///home/thehans.han/LociHub/loci_hub/lib/ui/widgets/map/loci_map_view.dart) to show daily GPS paths (Polyline) and matched photo markers (Markers with InfoWindows).
- Merges coordinates and EXIF photos into a beautiful, chronological M3 [TimelineFeed](file:///home/thehans.han/LociHub/loci_hub/lib/ui/widgets/timeline/timeline_feed.dart) displaying photo thumbnails loaded natively from memory.
- Uses `LayoutBuilder` inside [HomeScreen](file:///home/thehans.han/LociHub/loci_hub/lib/ui/screens/home/home_screen.dart) to split the view dynamically based on screen width (600dp threshold):
  - **Folded (FoldedLayout)**: Vertical stacked view.
  - **Unfolded (UnfoldedLayout)**: Split panel view (Map on left, stats/timeline on right) designed for Z Fold 6 unfolded display.
- Implements custom date navigation and bottom sheet [CalendarSelector](file:///home/thehans.han/LociHub/loci_hub/lib/ui/widgets/calendar/calendar_selector.dart) showing dots for active log dates.
- Extends the [SettingsScreen](file:///home/thehans.han/LociHub/loci_hub/lib/ui/screens/settings/settings_screen.dart) to toggle photo matching time tolerances, display photo library access permissions, and export local SQLite DBs or JSON coordinates.

---

## 8. Verification & Validation Results

### 1) Automated Tests
We wrote complete unit tests to verify DAOs, timezone configurations, and matching logic:
- [timezone_utils_test.dart](file:///home/thehans.han/LociHub/loci_hub/test/unit/timezone_utils_test.dart): Validated string time conversions.
- [dao_test.dart](file:///home/thehans.han/LociHub/loci_hub/test/unit/dao_test.dart): Validated database CRUD operations, FFI, foreign keys, and index bounds.
- [binary_search_matcher_test.dart](file:///home/thehans.han/LociHub/loci_hub/test/unit/binary_search_matcher_test.dart): Validated matching engine tolerances, confidence scores, and weight-based linear decays.
- [motion_detector_test.dart](file:///home/thehans.han/LociHub/loci_hub/test/unit/motion_detector_test.dart): Validated speed and sample detection thresholds.

Test run command:
```bash
$ flutter test
All 17 tests passed!
```

### 2) Static Analysis
Checked code quality and lint issues:
```bash
$ flutter analyze
No issues found! (except 5 minor deprecated properties info warnings)
```

### 3) Android APK Compilation
Successfully compiled the application:
```bash
$ flutter build apk --debug
✓ Built build/app/outputs/flutter-apk/app-debug.apk
```
This confirms that compile-time Gradle dependencies are resolved and the application is ready to be loaded onto the Samsung Galaxy Z Fold 6 device.

---

## 9. On-Device AI Summary Integration (Gemma-4-E4B-it)
We integrated support for the local **Gemma-4-E4B-it** model running via the Google AI Edge Gallery app to generate daily summaries (one-line text diary) and hashtags:

- **`LlmService` ([llm_service.dart](file:///home/thehans.han/LociHub/loci_hub/lib/services/llm/llm_service.dart))**: 
  - Connects to the local API server at `http://localhost:9379/v1/chat/completions` (OpenAI-compatible endpoint exposed by Edge Gallery).
  - Summarizes the day's activity logs (coordinates, time range, activity type counts) and gallery photos taken.
  - Formulates a detailed prompt requesting structured JSON output (one-line diary text and hashtags in Korean).
  - Implements a robust fallback parsing mechanism (regex + heuristic parsing) to guarantee structured outputs even if the local model returns plain text or markdown blocks.
- **`LlmProvider` ([llm_provider.dart](file:///home/thehans.han/LociHub/loci_hub/lib/providers/llm_provider.dart))**: Manages Riverpod states (`LlmStatus.generating`, `LlmStatus.success`, `LlmStatus.error`) and updates the `DailyJournal` table (`ai_title` and `ai_summary` fields) before invalidating providers to update the UI.
- **`AiSummaryCard` ([ai_summary_card.dart](file:///home/thehans.han/LociHub/loci_hub/lib/ui/widgets/common/ai_summary_card.dart))**: A premium Material 3 card styled with LinearGradients (primary container/tertiary container) that displays the generated diary and hashtags. It provides an interactive button to generate the summary or re-trigger it.
- **Responsive Layout updates**: Placed `AiSummaryCard` between the controls bar and the timeline feed in [HomeFoldedLayout](file:///home/thehans.han/LociHub/loci_hub/lib/ui/screens/home/home_folded_layout.dart) and in the right-side control panel of [HomeUnfoldedLayout](file:///home/thehans.han/LociHub/loci_hub/lib/ui/screens/home/home_unfolded_layout.dart).
- **Unit Tests ([llm_service_test.dart](file:///home/thehans.han/LociHub/loci_hub/test/unit/llm_service_test.dart))**: Wrote 4 test cases verifying:
  - Clean JSON parsing
  - Markdown code block extraction
  - Regex/Heuristic fallback parsing
  - Prompt generation stats compliance

---

## 10. Gemini API Cloud Integration & API Key Configuration (Phase 6)
To address the complexity of manually turning the local model server on/off, we transitioned the AI summary pipeline to Google's cloud-based **Gemini API** (`gemini-flash-latest` endpoint).

- **Dependency Addition**: Added `shared_preferences` package to manage API key persistence across launches.
- **DI Registration ([service_locator.dart](file:///home/thehans.han/LociHub/loci_hub/lib/core/di/service_locator.dart))**: Registered `SharedPreferences` as a singleton inside the `setupServiceLocator()` method.
- **State Management & Provider ([settings_provider.dart](file:///home/thehans.han/LociHub/loci_hub/lib/providers/settings_provider.dart))**: Developed `geminiApiKeyProvider` backed by `SharedPreferences`. The provider retrieves the user-defined key or falls back to an empty string.
- **UI Key Settings ([settings_screen.dart](file:///home/thehans.han/LociHub/loci_hub/lib/ui/screens/settings/settings_screen.dart))**: Added a dedicated card to manage the Gemini API Key. Features a clean Material 3 design, obscured password text toggles (show/hide), a clear button, and auto-save capabilities linking directly to `SharedPreferences` and the Riverpod state.
- **Refactoring & UI cleanup ([ai_summary_card.dart](file:///home/thehans.han/LociHub/loci_hub/lib/ui/widgets/common/ai_summary_card.dart))**:
  - Removed outdated local model launcher code (Edge Gallery Platform Channel and "앱 실행" SnackBarAction).
  - Modified state descriptions from "로컬 AI 모델이 오늘 하루를 분석하는 중..." to "Gemini API가 오늘 하루를 분석하는 중...".
- **Verification**: 
  - Ran static analysis successfully (`flutter analyze` - clean compilation).
  - Executed all 21 unit tests (`flutter test`) successfully, ensuring full database, matching, and parser test case integrity.

---

## 11. Multimodal Gemini Summary & Route Telemetry (Phase 7)
To support rich visual intelligence and long-distance travel recognition (such as trips or business travel), we expanded the Gemini prompt and payload pipelines:

- **Multimodal Payload Support ([llm_service.dart](file:///home/thehans.han/LociHub/loci_hub/lib/services/llm/llm_service.dart))**:
  - Integrated `base64Image` optional parameter into `generateSummary`.
  - Added support for injecting `inlineData` blocks containing the Base64 image payload alongside the prompt text inside the Gemini API body request.
- **Route Telemetry & Heuristics ([llm_service.dart](file:///home/thehans.han/LociHub/loci_hub/lib/services/llm/llm_service.dart))**:
  - Implemented the Haversine formula to compute cumulative daily travel distance (in kilometers) and the radius from start to end points.
  - Automatically extracts up to 5 representative coordinate waypoints (using stationary stops first, then chronologically segmented samples).
  - Enhanced the prompt to include cumulative distance analysis, allowing the Gemini model to dynamically infer vacation, travel, or long-distance movement.
- **Manual Representative Photo Picker Dialog ([ai_summary_card.dart](file:///home/thehans.han/LociHub/loci_hub/lib/ui/widgets/common/ai_summary_card.dart))**:
  - Refactored the summary request handler (`_handleGenerate`):
    - **0 photos**: Directly fires the Gemini API request without an image.
    - **1 photo**: Automatically forwards the single photo as the representative image.
    - **2+ photos**: Triggers a beautiful Material 3 grid popup dialog showing the thumbnails of all synchronized photos.
    - Users can tap to select exactly **one representative photo** to companion their summary request. Clicking "이 사진으로 일기 작성" invokes the summary API with the chosen photo.
  - Added an inner `_PhotoThumbnail` widget loading thumbnails on-the-fly from Scoped Storage using `photo_manager` API bytes.
- **Verification**:
  - Expanded `llm_service_test.dart` assertions to verify that generated prompts successfully contain route telemetry waypoints and distance analysis keywords.
  - Executed static analysis and verified all 21 unit tests pass flawlessly.



