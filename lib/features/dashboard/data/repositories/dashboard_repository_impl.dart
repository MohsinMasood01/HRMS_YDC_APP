import '../../../../core/services/secure_storage_service.dart';
import '../../../../di/service_locator.dart';
import '../../../../data/datasources/lms_local_data_source.dart';
import '../../../../data/datasources/lms_remote_data_source.dart';
import '../../../profile/domain/usecases/get_profile_usecase.dart';
import '../../domain/entities/dashboard_summary.dart';
import '../../domain/repositories/dashboard_repository.dart';

class DashboardRepositoryImpl implements DashboardRepository {
  DashboardRepositoryImpl(
    this._remoteDataSource,
    this._localDataSource,
    this._getProfileUseCase,
  );

  final LmsRemoteDataSource _remoteDataSource;
  final LmsLocalDataSource _localDataSource;
  final GetProfileUseCase _getProfileUseCase;

  DashboardSummary? _cache;

  @override
  DashboardSummary? cachedDashboard() {
    // Return in-memory cache if available
    if (_cache != null) return _cache;

    // Try to load from local storage
    final cached = _localDataSource.dashboard();
    if (cached != null) {
      _cache = cached;
      return _cache;
    }
    return null;
  }

  @override
  Future<DashboardSummary> fetchDashboard() async {
    // Get card_no from secure storage
    final secureStorage = getIt<SecureStorageService>();
    final cardNo1 = await secureStorage.read('card_no') ?? '';

    if (cardNo1.isEmpty) {
      throw Exception('Card number not found. Please login again.');
    }

    // Fetch dashboard data, leave balances, and profile in parallel
    final summary = await _remoteDataSource.dashboard();
    final balances = await _remoteDataSource.leaveBalances();

    // Fetch profile to get profile picture URL (silently fail if it doesn't work)
    String? profilePictureUrl;
    try {
      final profile = await _getProfileUseCase();
      profilePictureUrl = profile.profilePictureUrl;
    } catch (e) {
      // Ignore profile fetch errors - profile picture is optional
      profilePictureUrl = null;
    }

    // Merge leave balances and profile picture into dashboard summary
    final summaryWithBalances = DashboardSummary(
      empPk: summary.empPk,
      cardNo1: summary.cardNo1,
      empNo: summary.empNo,
      empName: summary.empName,
      dateOfJoin: summary.dateOfJoin,
      nicNo: summary.nicNo,
      designation: summary.designation,
      department: summary.department,
      compcnm: summary.compcnm,
      compc: summary.compc,
      branch: summary.branch,
      brnchnm: summary.brnchnm,
      hod: summary.hod,
      hodNm: summary.hodNm,
      balances: balances,
      profilePictureUrl: profilePictureUrl,
    );

    // Store card_no from dashboard response if not already stored
    if (summaryWithBalances.cardNo1.isNotEmpty) {
      final storedCardNo1 = await secureStorage.read('card_no');
      if (storedCardNo1 == null || storedCardNo1.isEmpty) {
        await secureStorage.write('card_no', summaryWithBalances.cardNo1);
      }
    }

    // Cache in memory
    _cache = summaryWithBalances;

    // Cache to local storage for persistence
    await _localDataSource.cacheDashboard(summaryWithBalances);

    return summaryWithBalances;
  }
}
