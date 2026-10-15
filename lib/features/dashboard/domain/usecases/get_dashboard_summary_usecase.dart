import '../entities/dashboard_summary.dart';
import '../repositories/dashboard_repository.dart';

class GetDashboardSummaryUseCase {
  GetDashboardSummaryUseCase(this._repository);

  final DashboardRepository _repository;

  Future<DashboardSummary> call() => _repository.fetchDashboard();
  DashboardSummary? cached() => _repository.cachedDashboard();
}

