# Task List: LociHub Development

## Phase 1: Environment & DB Skeleton
- [x] Environment Setup
  - [x] Install JDK 17, Android SDK cmdline-tools, platforms, build-tools
  - [x] Clone Flutter Stable SDK
  - [x] Run `flutter doctor` and verify configuration
- [x] Project Initialization
  - [x] Create Flutter project `loci_hub`
  - [x] Configure `minSdkVersion 34`, `targetSdkVersion 35`, `compileSdkVersion 35`
  - [x] Configure `AndroidManifest.xml` (Google Maps key placeholder, etc.)
- [x] Database & Data Models
  - [x] Implement `MatchStatus` enum and string mappings
  - [x] Implement data models (`DailyJournal`, `LocationLog`, `PhotoMetadata`)
  - [x] Implement `AppDatabase` with full schema, PRAGMA foreign_keys, and composite indexes
  - [x] Implement DAOs (`DailyJournalDao`, `LocationLogDao`, `PhotoMetadataDao`)
- [x] Core Utilities & Theme
  - [x] Implement `TimezoneUtils`
  - [x] Implement `DbExportUtil`
  - [x] Set up Material 3 App Theme (Light + Dark support)
  - [x] Set up Service Locator (`GetIt`)
  - [x] Set up routing skeleton with `go_router`
- [x] Phase 1 Verification
  - [x] Write unit tests for DAOs, `TimezoneUtils`, and `BinarySearchMatcher` (basic test)
  - [x] Run unit tests and static analysis (`flutter analyze` + `flutter test`)
  - [x] Build basic APK and verify table initialization

## Phase 2: Background Location Tracking
- [x] Permissions & Manifests
  - [x] Add coarse, fine, background location, and foreground service permissions to AndroidManifest
  - [x] Implement `PermissionHandler` for progressive runtime permission requests
- [x] Background Service
  - [x] Implement `LocationBackgroundService` (using `flutter_background_service`)
  - [x] Set up background isolate DB connection
- [x] Location Collection Logic
  - [x] Implement dynamic GPS collection loop using `geolocator`
  - [x] Implement `MotionDetector` for dynamic interval adjustments
  - [x] Handle timezone changes and daily journal crossing
- [x] Phase 2 Verification
  - [x] Test background service persistence and notification controls
  - [x] Test motion states and interval adjustment logic in real conditions

## Phase 3: EXIF Photo Matching Engine
- [x] Permissions & Photo API
  - [x] Configure photo permission manifests for Android 14+ Scoped Storage
  - [x] Implement `PermissionHandler` for 3-level photo access (Full, Partial, Denied)
  - [x] Set up `PhotoScannerService` using `photo_manager`
- [x] EXIF Metadata Extraction
  - [x] Implement `ExifParserService` using `exif` package
  - [x] Implement taken time parsing (exif-original -> UTC Epoch) with fallback heuristics
- [x] Matching Algorithm
  - [x] Implement binary search matching engine (`BinarySearchMatcher`) with source weight confidence
  - [x] Implement photo sync pipeline and state transition logic
- [x] Phase 3 Verification
  - [x] Write unit tests for `ExifParserService` and `BinarySearchMatcher`
  - [x] Manually verify gallery scans and GPS matching results

## Phase 4: Foldable Responsive UI & Google Maps
- [x] Google Maps Integration
  - [x] Integrate `google_maps_flutter`
  - [x] Set up API key configuration
- [x] UI Component Development
  - [x] Build calendar selector and timeline feed widgets
  - [x] Build map widget showing daily route polyline and matched photo markers
- [x] Responsive Layout for Z Fold 6
  - [x] Build Folded/Unfolded layout responsive shell
  - [x] Implement state synchronization (active date change)
- [x] Phase 4 Verification & Polish
  - [x] Verify Edge-to-Edge UI compliance for Android 15
  - [x] Test layout transition on Fold 6 emulator/device
  - [x] Deploy developer DB export to settings page

## Phase 5: On-Device AI Summary Integration (Gemma-4-E4B-it)
- [x] Local LLM API Service
  - [x] Implement `LlmService` to call `http://localhost:9379/v1/chat/completions`
  - [x] Structure daily activity prompt (GPS coordinates, time span, photo count, match status)
  - [x] Implement robust fallback JSON parser for model outputs
- [x] State Management & DB Update
  - [x] Implement `LlmNotifier` and `llmProvider` (Riverpod)
  - [x] Persist AI summary to `DailyJournal` table (`ai_title` and `ai_summary` fields)
- [x] UI Integration
  - [x] Create Material 3 styled `AiSummaryCard`
  - [x] Integrate into `HomeFoldedLayout` and `HomeUnfoldedLayout`
- [x] Verification
  - [x] Write and run unit tests for `LlmService`
  - [x] Verify static analysis and compilation

## Phase 6: Gemini API Integration & API Key Settings
- [x] Initialize `SharedPreferences` in `service_locator.dart`
- [x] Implement `geminiApiKeyProvider` in `settings_provider.dart` (Default fallback empty string)
- [x] Update `LlmNotifier` in `llm_provider.dart` to read and pass Gemini API Key
- [x] Add Gemini API configuration section in `settings_screen.dart`
- [x] Remove Edge Gallery logic and refine text/error behavior in `ai_summary_card.dart`
- [x] Run analysis and tests to verify correctness

## Phase 7: Multimodal Gemini Summary & Route Telemetry
- [x] Implement Haversine distance and path summary in `llm_provider.dart`
- [x] Implement multimodal Base64 image payload logic in `llm_service.dart`
- [x] Implement manual photo picker dialog in `ai_summary_card.dart`
- [x] Update `llm_service_test.dart` to verify image and route prompts
- [x] Run static analysis and tests to confirm zero errors


