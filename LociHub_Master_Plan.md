# Master Development Plan: LociHub
> **Project Name:** LociHub (로치허브 - Location + Loci + Data Hub)  
> **File Name:** LociHub_Master_Plan.md  
> **Target Device:** Samsung Galaxy Z Fold 6 (Android)  
> **Development Environment:** Ubuntu Linux Build PC  
> **Framework:** Flutter (Dart)  

---

## 1. 프로젝트 비전 (Project Vision)
**LociHub**는 외부 서버를 전혀 거치지 않고 사용자의 스마트폰 내부(On-device)에서만 작동하는 **개인 정보 통합 및 AI 비서 플랫폼**입니다. 

일차적으로 '시간'과 '공간'을 인덱스로 삼아 **위치 경로와 사진을 자동으로 매칭하는 스마트 저널**로 출발하며, 향후 통화록, 투두, 건강 데이터 등을 플러그인처럼 흡수할 수 있는 유연한 데이터 구조를 가집니다.

---

## 2. 확장형 데이터 도메인 구조 (Data Hierarchy)
모든 라이프 로그 데이터는 날짜(`YYYY-MM-DD`) 마스터 테이블을 중심축으로 설정하고, 시간축을 기준으로 정렬 및 결합됩니다.

```
[DailyJournal (마스터 인덱스: YYYY-MM-DD)]
   │
   ├── 📄 LocationLogs (시간축 기반 위·경도 배열) ────────────── [1차 구현]
   ├── 🖼️ PhotoMetadata (EXIF 시간 기준 매칭 사진 주소) ──────── [1차 구현]
   ├── 📞 CallLogs (동일 시간대 발생 통화 이력 개체) ─────────── [향후 확장]
   ├── 📝 TodoLogs (해당 날짜에 완료 처리된 투두 항목) ────────── [향후 확장]
   └── 🩺 HealthSnapshot (당일 총 걸음 수, 심박수, 수면 시간) ── [향후 확장]
```

---

## 3. 1차 구현 목표 (Phase 1: Location & Photo Mapping)

### 3.1 백그라운드 위치 추적 (Background Tracker)
*   **핵심 기술:** `flutter_background_service` 및 Android Foreground Service 프로토콜 연동.
*   **동작 방식:** 앱이 종료되어도 상단 바 알림(Notification)을 유지하여 OS에 의한 강제 종료 방지.
*   **배터리 최적화:** `Fused Location Provider API` 기반 가변 수집 알고리즘 적용. 기기가 정지 상태일 때는 GPS 조회를 중단하고 기지국/Wi-Fi 신호 변화만 감지하며, 이동 시 속도에 따라 30초~2분 주기로 자동 스위칭.

### 3.2 로컬 사진 EXIF 매칭 엔진 (EXIF Matcher)
*   **핵심 기술:** `photo_manager` 및 `exif` 패키지 파싱.
*   **매칭 메커니즘:**
    1.  갤러리 내 신규 사진 탐색 후 `EXIF:DateTimeOriginal`(촬영 시간) 추출.
    2.  시간순으로 정렬된 `LocationLogs` 테이블을 대상으로 **이진 탐색(Binary Search, $O(\log N)$)** 수행.
    3.  사진 촬영 시간 기준 오차 범위 $\pm N$분 이내의 가장 인접한 위도/경도 좌표를 찾아 매핑 및 썸네일 포인터 생성.

### 3.3 사용자 인터페이스 (UI/UX) - Galaxy Z Fold 6 최적화
*   **반응형 레이아웃(Responsive Layout):** 폴더블 기기의 특성을 고려한 듀얼 레이아웃 설계.
    *   **Main Screen (펼친 화면):** 태블릿 모드로 동작. 좌측 레이어에는 대형 지도(`flutter_map` 오픈스트리트맵 기반 로컬 렌더링), 우측 레이어에는 당일 타임라인 피드를 동시 노출(Split View).
    *   **Cover Screen (접은 화면):** 일반 모드로 동작. 상단 지어와 하단 수직 카드 피드로 구성된 스택 구조.
*   **캘린더 내비게이션:** 메인 화면 상단의 날짜 영역을 풀다운(Pull Down)하거나 탭하면 월간 달력 레이어가 드롭다운 형태로 노출. 특정 날짜 터치 시 로컬 DB에서 해당 날짜의 스냅샷 데이터로 즉시 쿼리 리로드.

---

## 4. 로컬 데이터베이스 스키마 설계 (SQLite)

관계형 쿼리 구조와 가벼운 인덱싱을 지원하는 SQLite(`sqflite` 패키지) 기반 설계입니다.

```sql
-- 1. 날짜별 마스터 저널 테이블
CREATE TABLE DailyJournal (
    journal_date TEXT PRIMARY KEY, -- YYYY-MM-DD
    ai_title TEXT,                 -- 로컬 LLM 생성 제목 (Phase 2 예정)
    ai_summary TEXT,               -- 로컬 LLM 생성 요약 (Phase 2 예정)
    created_at INTEGER
);

-- 2. 시계열 위치 로그 테이블
CREATE TABLE LocationLogs (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    journal_date TEXT,
    timestamp INTEGER,             -- Epoch Time (초 단위)
    latitude REAL,
    longitude REAL,
    activity_type TEXT,            -- 정지, 도보, 차량 이동 등 (OS 센서값)
    FOREIGN KEY(journal_date) REFERENCES DailyJournal(journal_date)
);

-- 3. 매칭된 사진 메타데이터 테이블 (원본 파일은 복사하지 않고 경로만 참조)
CREATE TABLE PhotoMetadata (
    id TEXT PRIMARY KEY,           -- 로컬 미디어 고유 ID
    journal_date TEXT,
    photo_path TEXT,               -- 원본 이미지 로컬 상대 경로
    taken_at INTEGER,              -- EXIF 촬영 시간
    matched_lat REAL,              -- 매칭된 위도
    matched_lng REAL,              -- 매칭된 경도
    FOREIGN KEY(journal_date) REFERENCES DailyJournal(journal_date)
);

-- 성능 최적화를 위한 시간축 인덱스 설정
CREATE INDEX idx_location_timestamp ON LocationLogs(timestamp);
CREATE INDEX idx_photo_taken ON PhotoMetadata(taken_at);
```

---

## 5. 단계별 개발 로드맵 (Roadmap)

### 📌 [1단계] 우분투 환경 구성 및 프로젝트 스켈레톤 생성
*   우분투 PC 내 Flutter SDK 및 Android Studio 개발 환경 세팅 (`flutter doctor` 통과).
*   Galaxy Z Fold 6 개발자 모드(USB 디버깅) 연동 및 베이스 앱 빌드(APK) 구동 확인.
*   SQLite 데이터베이스 헬퍼 클래스 및 초기 테이블 생성 스크립트 작성.

### 📌 [2단계] 백그라운드 위치 트래커 구현
*   Foreground Service 기반 상시 위치 수집 모듈 개발.
*   가변 주기 수집 알고리즘 구현 및 Fold 6 실기기 배터리 소모량 필드 테스트.
*   수집된 GPS 로그의 SQLite 시계열 적재 정합성 검증.

### 📌 [3단계] EXIF 파서 및 이진 탐색 매칭 엔진 구현
*   로컬 갤러리 접근 권한 확보 및 사진 메타데이터 파싱 모듈 개발.
*   시간축 정렬 데이터 기반 $O(\log N)$ 이진 탐색 매칭 알고리즘 검증.

### 📌 [4단계] 하이브리드 UI 및 폴더블 반응형 리팩토링
*   지도 위 Polyline 드로잉 및 사진 썸네일 커스텀 마커 매핑.
*   달력 컴포넌트 연동을 통한 풀다운 내비게이션 및 일자별 데이터 스위칭 완성.
*   Fold 6 디스플레이 상태 변화에 대응하는 반응형 스플릿 뷰 UI 폴리싱.

---
**본 문서는 프로젝트 루트 디렉토리에 `LociHub_Master_Plan.md`으로 저장되어 개발 마일스톤 관리 및 소스코드 모듈화의 표준 가이드라인으로 활용됩니다.**
