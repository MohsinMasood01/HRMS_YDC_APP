# LMS Mobile App Architecture

## Overview
The Attendance & Leave Management mobile app follows Flutter Clean Architecture with feature-first BLoC modules. Each feature owns its _data_, _domain_, and _presentation_ layers, and all shared concerns live under `lib/core`.

```
lib/
 ├─ app.dart / main.dart            # Root widgets, routing, theming
 ├─ core/                           # Design system, DI, services, utils
 ├─ features/
 │   ├─ authentication/
 │   │   ├─ data/
 │   │   ├─ domain/
 │   │   └─ presentation/
 │   ├─ dashboard/
 │   ├─ attendance/
 │   ├─ leaves/
 │   │   ├─ balances/
 │   │   ├─ application/
 │   │   └─ status/
 │   ├─ geofence/
 │   ├─ profile/
 │   ├─ settings/
 │   └─ notifications/
 └─ shared/                         # Reusable widgets and bloc observers
```

## Layer Responsibilities
- **Presentation**: UI widgets + BLoC/Cubit + view models. Consumes domain use cases only.
- **Domain**: Entities, repository abstractions, and use cases. Pure Dart; no Flutter imports.
- **Data**: DTOs, remote/local data sources, repository implementations that fulfill domain contracts.

## Cross-Cutting Services
- `NetworkClient (Dio)` handles REST requests, interceptors, retries.
- `SecureStorage` wraps encrypted shared preferences / keychain.
- `LocalCache` (SharedPreferences/Hive) caches profiles, leave balances, pending requests.
- `LocationService` + `GeoFenceService` monitor background geofencing using `geolocator`.
- `NotificationService` integrates with FCM/APNS (via `firebase_messaging` in future iteration).
- `AppTheme`, `AppTypography`, `AppSpacing`, `AppIcons` enforce UI consistency.

## Navigation
- Splash → Auth Gate decides between `LoginPage` and `HomeShell`.
- `HomeShell` hosts a bottom navigation with tabs:
  - Dashboard
  - Attendance
  - Leave (Balances/Application/Status via nested navigator)
  - Profile
  - Settings
- Notifications accessible via app bar icon and deep links.

## State Management
- **Global**: `AppBloc` handles theme mode, session, and notification badges.
- **Feature BLoCs/Cubits**:
  - `AuthBloc`
  - `DashboardBloc`
  - `LeaveBalanceBloc`
  - `LeaveApplicationBloc`
  - `LeaveStatusBloc`
  - `AttendanceBloc`
  - `GeoFenceBloc`
  - `ProfileBloc`
  - `SettingsCubit`
  - `NotificationsBloc`

## Testing (Test SPRITE Alignment)
Each SPRITE scenario from the BRD maps to:
- Widget/integration tests to assert UI flows (login, dashboard, attendance highlights).
- Bloc tests to cover validation logic (leave rules, late counts, settings persistence).
- Service tests for token storage, cache clearing, and geofence triggers (mocked).

Manual SPRITE execution artifacts (screenshots, logs) are captured during UAT.

## Next Steps
- Implement dependency injection using `GetIt`.
- Scaffold feature modules using the structure above.
- Wire repositories to mock data first, then swap to live REST endpoints once backend contracts are finalized.


