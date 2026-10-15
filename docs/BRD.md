# Attendance & Leave Management Mobile Application BRD

## Document Control
| Field | Detail |
| --- | --- |
| Project Title | Attendance & Leave Management Mobile Application |
| Client | Yousuf Dewan Companies (YDC) |
| Prepared For | HR / IT Department |
| Prepared By | Muhammad Zohaib Farooqui / IT Team |
| Date | 28-Nov-2025 |
| Version | v1.0 |
| Status | Draft for Review |

## 1. Project Overview
Yousuf Dewan Companies currently operates a web-based Leave Management System (LMS) to handle attendance logs, leave balances, approvals, and employee profiles. This project delivers a Flutter-based mobile application (Android and iOS) that replicates and extends the existing portal with mobile-first experiences, biometric security, geo-fencing based attendance automation, and real-time notifications. The app must integrate seamlessly with the existing REST APIs and comply with both Google Play and Apple App Store policies, enabling remote-ready workforce enablement and reducing manual HR interventions.

## 2. Project Objectives
- Offer employees a mobile-first platform to mark attendance, review balances, and apply for leave anytime.
- Automate attendance capture via FTC building geo-fence triggers while respecting privacy and policy requirements.
- Enhance security with biometric login (Face ID, fingerprint) layered on top of username/password credentials.
- Provide responsive, modern UI that is consistent across devices, orientations, and accessibility settings.
- Deliver real-time notifications for leave and attendance events to minimize approval latency.
- Ensure clean architecture (Presentation → Domain → Data) with module-level BLoCs for predictable behavior and maintainability.

## 3. Scope of Work
### 3.1 In Scope
1. **User Authentication**: Username/password login, biometric enrollment, remember-me, auto logout, session persistence.
2. **Dashboard**: Welcome card, leave balance cards, leave distribution pie chart, quick links.
3. **Leave Balances & Summary**: API-driven balances, offline cache, category-wise visuals.
4. **Leave Application**: Multi-type leave request forms, validation logic, submission, and local history.
5. **Leave Status**: Track pending/approved/rejected requests with approver comments and badges.
6. **Attendance Report Viewer**: Date-range report, late/absence highlighting, summary table.
7. **Geo-Fenced Auto Attendance**: Continuous monitoring with configurable radius, manual override, duplicate prevention.
8. **User Profile & Settings**: Profile view/edit, biometric toggle, notification preferences, theme switching, sign out.
9. **Notifications**: Push notifications via FCM/APNS for leave and attendance events.
10. **App Security & Compliance**: Secure token storage, background location disclosures, policy text.
11. **API Integration Layer**: Retrofit/Dio style HTTP layer, interceptors, error normalization, offline caching.

### 3.2 Out of Scope
- Creation or modification of backend REST APIs (consumed as-is).
- HR policy changes (leave types, approval workflows) beyond configuration.
- Desktop or web client redesign.
- Payroll processing, expense claims, or performance management modules.

### 3.3 Assumptions & Dependencies
- Backend team provides stable REST endpoints, schemas, and authentication tokens.
- HR shares geo-fence boundaries (currently 24.85851, 67.05000 radius 100–300 m) and thresholds (8:30 hrs, 9:40 AM).
- Push notification keys (FCM/APNS) and app store accounts are provisioned by IT.
- Device hardware supports biometrics and continuous location tracking.
- First login requires internet connectivity; offline use limited to cached data thereafter.

### 3.4 Constraints
- Compliance with Google/Apple background location disclosure policies and app review timelines (7–14 days).
- Location accuracy depends on GPS signal strength and user-granted permissions.
- JWT tokens must never be logged or stored unencrypted.
- Must reuse feature-first BLoC structure and adhere to Flutter Clean Architecture.

## 4. Functional Requirements

### 4.1 User Authentication Module
- **Description**: Provides secure login via username/password and optional biometrics; handles session lifecycle.
- **User Stories**:
  - As an employee, I log in with my corporate credentials and optionally enable biometric auto-login.
  - As a security officer, I require inactivity timeout after 5 minutes and easy remote logout.
- **Functional Flow**:
  1. User enters credentials → BLoC dispatches `LoginSubmitted`.
  2. Domain `AuthenticateUserUseCase` validates via repository → REST API.
  3. On success, tokens stored in encrypted storage and biometric enrollment prompt appears.
  4. Subsequent app launches attempt biometric login; fallback to credentials if unavailable.
  5. Manual logout clears tokens and cached sensitive data.
- **Business Rules**:
  - Locked session after 5 minutes of inactivity; user returns to login screen.
  - Password changes occur through existing backend endpoints (no local reset logic).
  - Remember-me stores only username until biometric/credential success.
- **Error Handling**:
  - Invalid credentials show API error message.
  - Biometric failures revert to password prompt.
  - Token expiry triggers silent refresh; if refresh fails, user re-authenticates.

### 4.2 Dashboard Module
- **Components**:
  - Welcome card with employee profile data (Name, Code, Cadre, Designation, Department, Location, Card Number).
  - Leave balance cards (CL, EL, ML, CP) pulling from cached API responses.
  - Leave distribution pie chart; shows "No data to display" when values absent.
  - Quick actions (Apply Leave, Attendance Report, Profile) accessible in ≤2 taps.
- **Rules**:
  - Dashboard loads within 2 seconds using cached data while refreshing in background.
  - Pie chart recalculates on every balance update; handles zero or null values gracefully.

### 4.3 Attendance Report Module
- **Inputs**: `fromDate`, `toDate` with calendar pickers; default to current month.
- **Outputs**: Read-only table displaying Date, Shift, Day, Time In/Out, Date Out, Work Hours, Late Arrival, Approved Hours, Remarks.
- **Highlight Rules**:
  - Work Hours < 8:30 → row tinted orange/red.
  - Late Arrival > 9:40 AM → row tinted yellow and increments Late Count.
  - Absent days color-coded (full-row grey/red) with "ABS" status.
- **Summary Table**: Displays CL, ML, EL, CP, SL, LWP, ABS, OD, Approved Extra Work, Late Count.
- **Features**:
  - Export/share as PDF optional future enhancement.
  - Paging for >31 entries.
  - Offline view uses last-synced month; indicates stale data.

### 4.4 Leave Application Module
- **Fields**: Leave Type (CL, CP, EL, ML, OD, WP), Date From, Date To, Half/Full Day, Reason text box.
- **Logic**:
  - Auto-fill reasons: ML → "Medical Leave due to health reasons", SL → "Sick Leave", OD → "Out Door Duty for official purpose".
  - Show available balance; disable submit if balance zero except WP.
  - Half-day option only when `Date From == Date To`.
  - No past date selection except OD (requires justification).
- **Validation**:
  - Required fields enforced via form BLoC states.
  - API error responses displayed inline and stored in request history.
- **Submission**:
  - POST to Leave Application API; optimistic UI updates local history.
  - Local cache syncs status upon next refresh.

### 4.5 Leave Status Module
- **Features**:
  - List grouped by Pending / Approved / Rejected.
  - Each card shows leave type, duration, status badge color-coded, approver comments, submission date.
  - Pull-to-refresh triggers API sync plus notification read receipts.
- **Notifications**:
  - Receive push messages such as "Your leave for 07-Nov has been approved" or rejection reasons.
  - Tapping notification deep-links into specific request detail.

### 4.6 Geo-Fencing Auto Attendance
- **Objective**: Automatically mark attendance when user enters FTC geo-fenced perimeter (Lat 24.85851, Long 67.05000, radius 100–300 m).
- **Workflow**:
  1. Background service monitors location with low-power geofencing.
  2. When entering region, BLoC triggers `CheckInUseCase` to hit Attendance API.
  3. Duplicate prevention via server-side idempotency token and local daily flag.
  4. Manual override button available in app; logs reason when used.
- **Permissions**:
  - Pre-permission educational dialog clarifying background use: "This app collects location data even when closed to automatically mark your attendance."
  - Permanent settings link offered in case permissions denied.
- **Compliance**:
  - Follows Google/Apple background location guidelines; justification stored in-app info page.

### 4.7 User Profile Module
- **View**: Name, Code, Cadre, Department, Designation, Joining Date, Card No, Location.
- **Edit**: Phone number, email, profile picture (optional) with image compression and preview.
- **Offline**: Cached profile data accessible; edits queued until connectivity restored.

### 4.8 Settings Module
- **Options**: Enable/disable biometric login, notification toggles (attendance, leave, system), dark/light mode, sign out, privacy/legal links.
- **AppBloc Responsibility**: Manage global theme/state without duplicating business logic in widgets.

### 4.9 Notifications System
- **Types**: Leave approvals/rejections, attendance marked, missing attendance alerts, holiday announcements, optional app update reminders.
- **Technology**: Firebase Cloud Messaging (Android/iOS) with APNS configuration for iOS; topic-based subscriptions per department if required.
- **Behavior**:
  - Foreground: in-app banners; Background: system tray with deep links.
  - Notification preferences stored locally and synced to backend if supported.

### 4.10 API Integration Layer
- **Responsibilities**:
  - Centralized HTTP client (e.g., Dio) with interceptors for auth headers, logging (sans sensitive data), and retry policies.
  - DTO ↔ Domain model mapping; no Flutter dependencies inside Domain.
  - Local storage via Hive/Sqflite for cached data (profile, leave balances, pending requests).
  - Error normalization to domain-level failures (network, server, validation).

## 5. Non-Functional Requirements
### 5.1 Performance
- Dashboard renders within 2 seconds using cached data; API refresh may continue asynchronously.
- Monthly attendance report loads in <5 seconds on LTE/Wi-Fi.
- Geo-fence service optimized for minimal battery impact.

### 5.2 Security
- All traffic over HTTPS with TLS 1.2+.
- JWT tokens stored in Encrypted Shared Preferences (Android) or Keychain (iOS).
- OWASP Mobile Top 10 controls: certificate pinning (Optional), root/jailbreak detection alerts, secure logging.
- Automatic logout on inactivity and explicit user sign out clears caches.

### 5.3 Usability
- Uses `flutter_screenutil` (or equivalent) for responsive typography and spacing (8px scale).
- Consistent font family and color palette defined in global theme.
- Buttons share shape/height/text style; inputs share border radius and padding.
- Accessibility: supports system font scaling, VoiceOver/TalkBack labels, sufficient contrast.

### 5.4 Reliability
- Offline caching for profile, leave balances, and pending leave requests.
- Retry with exponential backoff for transient network failures.
- App gracefully handles API downtime with user-friendly messaging.

### 5.5 Maintainability
- Strict adherence to Flutter Clean Architecture: Presentation (UI + BLoC) → Domain (Use Cases, Entities, Repositories) → Data (API, Local).
- Each functional module owns its BLoC with clear events/states.
- Shared widgets/components (buttons, cards, dialogs) in reusable packages to preserve consistency.
- Automated linting via `flutter_lints` and format enforcement in CI.

### 5.6 Compliance & Privacy
- Background location disclosure text included in onboarding and settings.
- Logs exclude PII; analytics anonymized.
- Adheres to local labor laws for attendance tracking transparency.

## 6. System Integration Requirements
| API | Method | Description |
| --- | --- | --- |
| Login API | POST `/auth/login` | Authenticates user, returns JWT/refresh tokens. |
| Profile API | GET `/employee/profile` | Fetches profile and roster info. |
| Leave Balances API | GET `/leave/balances` | Returns CL, EL, ML, CP, etc. |
| Leave Application API | POST `/leave/applications` | Submits leave requests. |
| Leave Status API | GET `/leave/applications` | Lists pending/approved/rejected requests. |
| Attendance Report API | GET `/attendance/report` | Provides date-range attendance log. |
| Attendance Marking API | POST `/attendance/check-in` | Marks attendance from geo-fence/manual override. |
| Notification API | GET `/notifications` | Syncs read/unread notifications if needed. |
| App Update Checker API (Optional) | GET `/app/version` | Suggests mandatory/optional updates. |

## 7. Acceptance Criteria
- Users log in with credentials and biometrics successfully; inactive sessions logout after 5 minutes.
- Attendance automatically marks when entering geo-fence; manual override available when needed.
- All screens load under defined performance thresholds; offline cache accessible for key data.
- Leave requests can be submitted, tracked, and notified in real time.
- Location data captured even without active internet; queued events sync when online.
- Push notifications work on Android and iOS with correct deep links.
- UI follows approved mockups, maintains theme consistency, and passes app store review.

## 8. Deliverables
- Flutter mobile application (Android APK/AAB, iOS IPA) ready for store submission.
- Source code repository implementing clean architecture and feature-first BLoC structure.
- API integration layer with documentation and environment configuration.
- UI/UX design files (Figma/Sketch) with component guidelines.
- Deployment artifacts for Play Store and App Store.
- Admin and end-user documentation (quick start guides, FAQs).

## 9. Implementation & Release Plan
| Phase | Duration | Key Activities |
| --- | --- | --- |
| Discovery & Design | 2 weeks | Requirement validation, UX flows, branding approval. |
| Architecture & Foundation | 2 weeks | Project setup, CI/CD, theming, authentication skeleton. |
| Feature Development | 6 weeks | Dashboard, leave modules, attendance, profile, settings, notifications. |
| Integration & Hardening | 3 weeks | API wiring, geo-fence tuning, biometric QA, accessibility checks. |
| UAT & Compliance | 2 weeks | HR/IT UAT, Test Sprite execution, store readiness review. |
| Deployment | 1 week | Store submissions, handover, training. |

## 10. Testing Strategy (Test SPRITE Matrix)
To satisfy the request to "test it using Test Sprite," we adopt a SPRITE matrix where each scenario tracks **S**cenario, **P**riority, **R**esult, **I**ssues, **T**est Data, and **E**vidence. Automated tests (unit, widget, integration) complement manual execution; results below remain **Pending** until functionality is implemented.

### 10.1 Test SPRITE Matrix
| Scenario (S) | Priority (P) | Result (R) | Issues (I) | Test Data (T) | Evidence (E) |
| --- | --- | --- | --- | --- | --- |
| Credential login with inactivity timeout | High | Pending | – | Valid user `emp001`, session idle 6 min | Screen recording, auth logs |
| Biometric enrollment and auto-login | High | Pending | – | Device with Face ID/Fingerprint | Video + device logs |
| Dashboard loads cached + refreshed data in ≤2s | High | Pending | – | User with mixed leave balances | Performance trace |
| Attendance report highlights late arrivals/absences | High | Pending | – | Dataset with <8:30 hrs, >9:40 arrival | Screenshots, API payload |
| Leave application validation (half-day, past dates) | Medium | Pending | – | CL balance=2, OD justification | Form validation report |
| Leave status notifications deep-linking | Medium | Pending | – | Pending request approved via backend | Push log + in-app capture |
| Geo-fence auto attendance + manual override | Critical | Pending | – | Device near 24.85851/67.05000 | GPS trace + API response |
| Offline cache sync for profile and leave balances | Medium | Pending | – | Airplane mode, cached data | Console logs |
| Settings toggles (biometric, theme) persisted via AppBloc | Low | Pending | – | Toggle sequences | State logs |
| Security: token storage and logout clearing cache | High | Pending | – | Inspect encrypted storage | Test script output |

**Test Execution Notes**
- Manual regression cycles scheduled per sprint; automation targets use-case BLoCs, repositories, and golden tests.
- CI pipeline to run `flutter test` and custom lint checks on every merge request.
- Defects discovered during SPRITE execution logged in Azure DevOps/Jira with references to Scenario IDs.

## 11. Glossary & References
- **BLoC**: Business Logic Component, state management pattern used across modules.
- **Geo-fence**: Virtual perimeter around FTC building used for auto attendance triggers.
- **JWT**: JSON Web Token used for API authentication.
- **SPRITE**: Scenario, Priority, Result, Issues, Test Data, Evidence matrix for structured test tracking.
- References: Existing YDC LMS web portal, corporate HR policies, Google/Apple developer guidelines.


