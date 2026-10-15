import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:get_it/get_it.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/config/app_config.dart';
import '../core/network/mock_api_service.dart';
import '../core/network/network_client.dart';
import '../core/services/attendance_file_service.dart';
import '../core/services/attendance_validation_service.dart';
import '../core/services/biometric_service.dart';
import '../core/services/geocoding_service.dart';
import '../core/services/geofence_service.dart';
import '../core/services/tracking_session_store.dart';
import '../features/location_tracking/data/datasources/location_local_data_source.dart';
import '../features/location_tracking/data/datasources/location_remote_data_source.dart';
import '../features/location_tracking/data/repositories/location_repository_impl.dart';
import '../features/location_tracking/domain/repositories/location_repository.dart';
import '../core/services/apk_updater.dart';
import '../core/services/app_version_service.dart';
import '../core/services/local_storage_service.dart';
import '../core/services/location_service.dart';
import '../core/database/location_track_db.dart';
import '../core/services/location_tracking_config_service.dart';
import '../core/services/location_tracking_service.dart';
import '../core/services/tracelet_service.dart';
import '../core/services/notification_service.dart';
import '../core/services/permission_service.dart';
import '../core/services/secure_storage_service.dart';
import '../core/services/update_service.dart';
import '../data/datasources/lms_local_data_source.dart';
import '../data/datasources/lms_remote_data_source.dart';
import '../features/attendance/data/datasources/attendance_remote_data_source.dart';
import '../features/attendance/data/repositories/attendance_repository_impl.dart';
import '../features/attendance/domain/repositories/attendance_repository.dart';
import '../features/attendance/domain/usecases/mark_biometric_attendance_usecase.dart';
import '../features/attendance/domain/usecases/get_attendance_report_usecase.dart';
import '../features/attendance/domain/usecases/get_attendance_summary_usecase.dart';
import '../features/attendance/presentation/bloc/attendance_bloc.dart';
import '../features/authentication/data/datasources/auth_local_data_source.dart';
import '../features/authentication/data/datasources/auth_remote_data_source.dart';
import '../features/authentication/data/repositories/auth_repository_impl.dart';
import '../features/authentication/domain/repositories/auth_repository.dart';
import '../features/authentication/domain/usecases/authenticate_user_usecase.dart';
import '../features/authentication/domain/usecases/get_cached_user_usecase.dart';
import '../features/authentication/domain/usecases/logout_usecase.dart';
import '../features/authentication/domain/usecases/toggle_biometric_usecase.dart';
import '../features/authentication/presentation/bloc/auth_bloc.dart';
import '../features/dashboard/data/repositories/dashboard_repository_impl.dart';
import '../features/dashboard/domain/repositories/dashboard_repository.dart';
import '../features/dashboard/domain/usecases/get_dashboard_summary_usecase.dart';
import '../features/dashboard/presentation/bloc/dashboard_bloc.dart';
import '../features/geofence/data/repositories/geofence_repository_impl.dart';
import '../features/geofence/domain/repositories/geofence_repository.dart';
import '../features/geofence/domain/usecases/manual_attendance_override_usecase.dart';
import '../features/geofence/domain/usecases/mark_automatic_check_in_usecase.dart';
import '../features/geofence/presentation/bloc/geofence_bloc.dart';
import '../features/leaves/data/datasources/leave_remote_data_source.dart';
import '../features/leaves/data/repositories/leave_repository_impl.dart';
import '../features/leaves/domain/repositories/leave_repository.dart';
import '../features/leaves/domain/usecases/get_leave_balances_usecase.dart';
import '../features/leaves/domain/usecases/get_leave_requests_usecase.dart';
import '../features/leaves/domain/usecases/submit_leave_request_usecase.dart';
import '../features/leaves/presentation/bloc/leave_application/leave_application_bloc.dart';
import '../features/leaves/presentation/bloc/leave_balance/leave_balance_bloc.dart';
import '../features/leaves/presentation/bloc/leave_status/leave_status_bloc.dart';
import '../features/notifications/data/datasources/notification_remote_data_source.dart';
import '../features/notifications/data/repositories/notification_repository_impl.dart';
import '../features/notifications/domain/repositories/notification_repository.dart';
import '../features/notifications/domain/usecases/get_notifications_usecase.dart';
import '../features/notifications/domain/usecases/mark_notification_read_usecase.dart';
import '../features/notifications/presentation/bloc/notification_bloc.dart';
import '../features/payslips/data/datasources/payslip_file_cache.dart';
import '../features/payslips/data/datasources/payslip_remote_data_source.dart';
import '../features/payslips/data/repositories/payslip_repository.dart';
import '../features/payslips/presentation/cubit/payslips_cubit.dart';
import '../features/profile/data/datasources/profile_remote_data_source.dart';
import '../features/profile/data/repositories/profile_repository_impl.dart';
import '../features/profile/domain/repositories/profile_repository.dart';
import '../features/profile/domain/usecases/get_profile_usecase.dart';
import '../features/profile/domain/usecases/update_profile_contacts_usecase.dart';
import '../features/profile/domain/usecases/change_password_usecase.dart';
import '../features/profile/presentation/bloc/profile_bloc.dart';
import '../features/settings/data/repositories/settings_repository_impl.dart';
import '../features/settings/domain/repositories/settings_repository.dart';
import '../features/settings/presentation/cubit/settings_cubit.dart';
import '../features/face_verification/data/datasources/face_verification_remote_data_source.dart';
import '../features/face_verification/data/datasources/face_storage_datasource.dart';
import '../features/face_verification/data/datasources/face_image_storage_datasource.dart';
import '../features/face_verification/data/repositories/face_verification_repository_impl.dart';
import '../features/face_verification/domain/repositories/face_verification_repository.dart';
import '../features/face_verification/domain/usecases/enroll_face_usecase.dart';
import '../features/face_verification/domain/usecases/verify_face_usecase.dart'
    as face_verification;
import '../features/face_verification/data/datasources/face_camera_datasource.dart';
import '../features/face_verification/data/datasources/face_embedding_datasource.dart';
import '../features/face_verification/presentation/bloc/face_verification_bloc.dart';
import '../features/face_auth/data/datasources/face_remote_datasource.dart';
import '../features/face_auth/data/repositories/face_repository_impl.dart';
import '../features/face_auth/domain/repositories/face_repository.dart';
import '../features/face_auth/domain/usecases/face_status_usecase.dart';
import '../features/face_auth/domain/usecases/register_face_usecase.dart';
import '../features/face_auth/domain/usecases/identify_face_usecase.dart';
import '../features/face_auth/domain/usecases/verify_face_usecase.dart'
    as face_auth;
import '../features/face_auth/presentation/bloc/face_bloc.dart';
import '../shared/bloc/app_bloc.dart';
import '../features/profile/data/datasources/emergency_contact_store.dart';
import '../features/attendance/domain/usecases/get_today_attendance_state_usecase.dart';

final getIt = GetIt.instance;

Future<void> configureDependencies() async {
  final preferences = await SharedPreferences.getInstance();

  // Core
  getIt
    ..registerLazySingleton<AppConfig>(() => const AppConfig())
    ..registerLazySingleton<LocalStorageService>(
      () => LocalStorageService(preferences),
    )
    ..registerLazySingleton<SecureStorageService>(() => SecureStorageService())
    ..registerLazySingleton<AppVersionService>(() => AppVersionService())
    ..registerLazySingleton<UpdateService>(
      () => UpdateService(getIt<AppVersionService>()),
    )
    ..registerLazySingleton<ApkUpdater>(() => ApkUpdater())
    ..registerLazySingleton<MockApiService>(() => MockApiService())
    ..registerLazySingleton<NetworkClient>(
      () => NetworkClient(getIt<AppConfig>()),
    )
    ..registerLazySingleton<LocationService>(() => LocationService())
    ..registerLazySingleton<GeocodingService>(
      () => GeocodingService(getIt<LocationService>()),
    )
    ..registerLazySingleton<GeoFenceService>(
      () => GeoFenceService(getIt<AppConfig>(), getIt<LocationService>()),
    )
    ..registerLazySingleton<NotificationService>(() => NotificationService())
    ..registerLazySingleton<BiometricService>(() => BiometricService())
    ..registerLazySingleton<LocationTrackDb>(() => LocationTrackDb())
    ..registerLazySingleton<TrackingSessionStore>(() => TrackingSessionStore())
    // Location tracking: local-first storage + batch sync. The background
    // isolate builds this same graph by hand via
    // createBackgroundLocationRepository() since get_it is not configured
    // there.
    ..registerLazySingleton<LocationLocalDataSource>(
      () => LocationLocalDataSource(getIt<LocationTrackDb>()),
    )
    ..registerLazySingleton<LocationRemoteDataSource>(
      () => LocationRemoteDataSource(),
    )
    ..registerLazySingleton<LocationRepository>(
      () => LocationRepositoryImpl(
        local: getIt<LocationLocalDataSource>(),
        remote: getIt<LocationRemoteDataSource>(),
      ),
    )
    ..registerLazySingleton<LocationTrackingConfigService>(
      () => LocationTrackingConfigService(),
    )
    ..registerLazySingleton<TraceletService>(
      () => TraceletService(configService: getIt<LocationTrackingConfigService>()),
    )
    ..registerLazySingleton<LocationTrackingService>(
      () => LocationTrackingService(
        repository: getIt<LocationRepository>(),
        sessionStore: getIt<TrackingSessionStore>(),
        configService: getIt<LocationTrackingConfigService>(),
        secureStorage: getIt<SecureStorageService>(),
        tracelet: getIt<TraceletService>(),
      ),
    )
    ..registerLazySingleton<PermissionService>(() => PermissionService())
    ..registerLazySingleton<AttendanceFileService>(
      () => AttendanceFileService(),
    )
    ..registerLazySingleton<AttendanceValidationService>(
      () => AttendanceValidationService(preferences),
    )
    ..registerLazySingleton<LmsLocalDataSource>(
      () => LmsLocalDataSource(getIt<LocalStorageService>()),
    )
    ..registerLazySingleton<LmsRemoteDataSourceImpl>(
      () => LmsRemoteDataSourceImpl(
        getIt<NetworkClient>(),
        getIt<AppConfig>(),
        getIt<MockApiService>(),
      ),
    )
    ..registerLazySingleton<LmsRemoteDataSource>(
      () => getIt<LmsRemoteDataSourceImpl>(),
    );

  // Auth
  getIt
    ..registerLazySingleton<AuthLocalDataSource>(
      () => AuthLocalDataSourceImpl(
        getIt<LocalStorageService>(),
        getIt<SecureStorageService>(),
      ),
    )
    ..registerLazySingleton<AuthRemoteDataSource>(
      () => AuthRemoteDataSourceImpl(),
    )
    ..registerLazySingleton<AuthRepository>(
      () => AuthRepositoryImpl(
        getIt<AuthRemoteDataSource>(),
        getIt<AuthLocalDataSource>(),
      ),
    )
    ..registerLazySingleton(() => AuthenticateUserUseCase(getIt()))
    ..registerLazySingleton(() => GetCachedUserUseCase(getIt()))
    ..registerLazySingleton(() => LogoutUseCase(getIt()))
    ..registerLazySingleton(() => ToggleBiometricUseCase(getIt()))
    ..registerFactory(
      () => AuthBloc(
        authenticateUserUseCase: getIt(),
        getCachedUserUseCase: getIt(),
        logoutUseCase: getIt(),
        toggleBiometricUseCase: getIt(),
        authRepository: getIt(),
        biometricService: getIt(),
      ),
    );

  Future<String?> cardNo1Provider() async {
    final ss = getIt<SecureStorageService>();
    return await ss.read('card_no1') ?? await ss.read('card_no');
  }

  Future<String?> empPkProvider() =>
      getIt<SecureStorageService>().read('emp_pk');

  // Dashboard
  getIt
    ..registerLazySingleton<DashboardRepository>(
      () => DashboardRepositoryImpl(
        getIt<LmsRemoteDataSource>(),
        getIt<LmsLocalDataSource>(),
        getIt<GetProfileUseCase>(),
      ),
    )
    ..registerLazySingleton(() => GetDashboardSummaryUseCase(getIt()))
    ..registerFactory(() => DashboardBloc(getIt()));

  // Payslips
  getIt
    ..registerLazySingleton<PayslipFileCache>(() => PayslipFileCache())
    ..registerLazySingleton<PayslipRemoteDataSource>(
      () => PayslipRemoteDataSource(),
    )
    ..registerLazySingleton<PayslipRepository>(
      () => PayslipRepository(
        remote: getIt(),
        cache: getIt(),
        secureStorage: getIt(),
      ),
    )
    ..registerFactory(() => PayslipsCubit(getIt()));

  // Attendance
  getIt
    ..registerLazySingleton<AttendanceRemoteDataSource>(
      () => AttendanceRemoteDataSourceImpl(cardNo1Provider: cardNo1Provider),
    )
    ..registerLazySingleton<AttendanceRepository>(
      () => AttendanceRepositoryImpl(
        getIt<AttendanceRemoteDataSource>(),
        empPkProvider,
      ),
    )
    ..registerLazySingleton(() => GetAttendanceReportUseCase(getIt()))
    ..registerLazySingleton(() => GetTodayAttendanceStateUseCase(getIt()))
    ..registerLazySingleton(() => GetAttendanceSummaryUseCase(getIt()))
    ..registerLazySingleton(() => MarkBiometricAttendanceUseCase(getIt()))
    ..registerFactory(() => AttendanceBloc(getIt()));

  // Leaves
  getIt
    ..registerLazySingleton<LeaveRemoteDataSource>(
      () => LeaveRemoteDataSourceImpl(),
    )
    ..registerLazySingleton<LeaveRepository>(
      () => LeaveRepositoryImpl(
        getIt<LeaveRemoteDataSource>(),
        cardNo1Provider,
        empPkProvider,
      ),
    )
    ..registerLazySingleton(() => GetLeaveBalancesUseCase(getIt()))
    ..registerLazySingleton(() => GetLeaveRequestsUseCase(getIt()))
    ..registerLazySingleton(() => SubmitLeaveRequestUseCase(getIt()))
    ..registerFactory(() => LeaveBalanceBloc(getIt()))
    ..registerFactory(() => LeaveStatusBloc(getIt()))
    ..registerFactory(() => LeaveApplicationBloc(getIt(), getBalancesUseCase: getIt()));

  // Profile
  getIt
    ..registerLazySingleton<ProfileRemoteDataSource>(
      () => ProfileRemoteDataSourceImpl(),
    )
    ..registerLazySingleton(
      () => EmergencyContactStore(getIt<LocalStorageService>()),
    )
    ..registerLazySingleton<EnhancedProfileRepository>(
      () => ProfileRepositoryImpl(
        getIt<LmsRemoteDataSource>(),
        getIt<LmsLocalDataSource>(),
        getIt<EmergencyContactStore>(),
      ),
    )
    ..registerLazySingleton(() => GetProfileUseCase(getIt()))
    ..registerLazySingleton(() => UpdateProfileContactsUseCase(getIt()))
    ..registerLazySingleton(() => ChangePasswordUseCase(getIt()))
    ..registerFactory(() => ProfileBloc(getIt(), getIt(), getIt()));

  // Notifications
  getIt
    ..registerLazySingleton<NotificationRemoteDataSource>(
      () => NotificationRemoteDataSourceImpl(),
    )
    ..registerLazySingleton<NotificationRepository>(
      () => NotificationRepositoryImpl(
        getIt<NotificationRemoteDataSource>(),
        empPkProvider,
      ),
    )
    ..registerLazySingleton(() => GetNotificationsUseCase(getIt()))
    ..registerLazySingleton(() => MarkNotificationReadUseCase(getIt()))
    ..registerFactory(() => NotificationBloc(getIt(), getIt()));

  // GeoFence
  getIt
    ..registerLazySingleton<GeoFenceRepository>(
      () => GeoFenceRepositoryImpl(getIt<LmsRemoteDataSource>()),
    )
    ..registerLazySingleton(() => MarkAutomaticCheckInUseCase(getIt()))
    ..registerLazySingleton(() => ManualAttendanceOverrideUseCase(getIt()))
    ..registerFactory(() => GeoFenceBloc(getIt(), getIt(), getIt()));

  // Settings
  getIt
    ..registerLazySingleton<SettingsRepository>(
      () => SettingsRepositoryImpl(getIt<LocalStorageService>()),
    )
    ..registerFactory(() => SettingsCubit(getIt()));

  // Face Verification
  getIt
    ..registerLazySingleton<FaceVerificationRemoteDataSource>(
      () => FaceVerificationRemoteDataSourceImpl(config: getIt<AppConfig>()),
    )
    ..registerLazySingleton<FaceStorageDataSource>(
      () => FaceStorageDataSourceImpl(getIt<SecureStorageService>()),
    )
    ..registerLazySingleton<FaceImageStorageDataSource>(
      () => FaceImageStorageDataSourceImpl(),
    )
    ..registerLazySingleton<FaceVerificationRepository>(
      () => FaceVerificationRepositoryImpl(
        getIt<FaceVerificationRemoteDataSource>(),
        getIt<FaceStorageDataSource>(),
        getIt<FaceImageStorageDataSource>(),
      ),
    )
    ..registerLazySingleton(() => EnrollFaceUseCase(getIt()))
    ..registerLazySingleton(() => face_verification.VerifyFaceUseCase(getIt()))
    ..registerLazySingleton<FaceCameraDataSource>(
      () => FaceCameraDataSourceImpl(),
    )
    ..registerLazySingleton<FaceEmbeddingDataSource>(
      () => FaceEmbeddingDataSourceImpl(),
    )
    ..registerFactory(
      () => FaceVerificationBloc(
        cameraDataSource: getIt<FaceCameraDataSource>(),
        embeddingDataSource: getIt<FaceEmbeddingDataSource>(),
        repository: getIt<FaceVerificationRepository>(),
        enrollFaceUseCase: getIt<EnrollFaceUseCase>(),
        registerFaceUseCase: getIt<RegisterFaceUseCase>(),
        authVerifyFaceUseCase: getIt<face_auth.VerifyFaceUseCase>(),
        imageStorageDataSource: getIt<FaceImageStorageDataSource>(),
      ),
    );

  // Face Auth (New FastAPI Backend)
  getIt
    ..registerLazySingleton<FaceRemoteDataSource>(
      () => FaceRemoteDataSourceImpl(config: getIt<AppConfig>()),
    )
    ..registerLazySingleton<FaceRepository>(
      () => FaceRepositoryImpl(getIt<FaceRemoteDataSource>()),
    )
    ..registerLazySingleton(() => FaceStatusUseCase(getIt()))
    ..registerLazySingleton(() => RegisterFaceUseCase(getIt()))
    ..registerLazySingleton(() => face_auth.VerifyFaceUseCase(getIt()))
    ..registerLazySingleton(() => IdentifyFaceUseCase(getIt()))
    ..registerFactory(
      () => FaceBloc(
        faceStatusUseCase: getIt(),
        registerFaceUseCase: getIt(),
        verifyFaceUseCase: getIt(),
      ),
    );

  // Global Blocs
  getIt.registerLazySingleton(
    () => AppBloc(storageService: getIt<LocalStorageService>()),
  );

  // Initialise location tracking (Tracelet SDK, connectivity listener, session
  // reconciliation).
  //
  // Deliberately NOT awaited: main() awaits configureDependencies() before
  // runApp(), so anything slow or stuck on this path delays -- or permanently
  // prevents -- the first frame, which surfaces to the user as a white screen.
  // None of this work is needed before the UI mounts, so it runs in the
  // background and its failures stay non-fatal.
  unawaited(
    getIt<LocationTrackingService>().init().catchError((Object e) {
      debugPrint('[DI] Location tracking init failed (non-fatal): $e');
    }),
  );
}
