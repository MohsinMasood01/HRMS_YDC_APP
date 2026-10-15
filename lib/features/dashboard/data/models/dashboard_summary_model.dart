import '../../../leaves/domain/entities/leave_balance.dart';
import '../../domain/entities/dashboard_summary.dart';

class DashboardSummaryModel extends DashboardSummary {
  const DashboardSummaryModel({
    required super.empPk,
    required super.cardNo1,
    required super.empNo,
    required super.empName,
    required super.dateOfJoin,
    required super.nicNo,
    required super.designation,
    required super.department,
    required super.compcnm,
    required super.compc,
    required super.branch,
    required super.brnchnm,
    required super.hod,
    required super.hodNm,
    required super.balances,
    super.profilePictureUrl,
  });

  factory DashboardSummaryModel.fromJson(Map<String, dynamic> json) {
    // Helper function to safely parse numbers with default 0
    int safeInt(dynamic value) {
      if (value == null) return 0;
      if (value is int) return value;
      if (value is String) {
        return int.tryParse(value) ?? 0;
      }
      return 0;
    }

    // Helper function to safely parse strings with default "-"
    String safeString(dynamic value) {
      if (value == null) return '-';
      final str = value.toString().trim();
      return str.isEmpty ? '-' : str;
    }

    return DashboardSummaryModel(
      empPk: safeInt(json['emp_pk']),
      cardNo1: safeString(json['card_no1']),
      empNo: safeString(json['emp_no']),
      empName: safeString(json['emp_name']),
      dateOfJoin: safeString(json['date_of_join']),
      nicNo: safeString(json['nic_no']),
      designation: safeString(json['designation']),
      department: safeString(json['department']),
      compcnm: safeString(json['compcnm']),
      compc: safeInt(json['compc']),
      branch: safeInt(json['branch']),
      brnchnm: safeString(json['brnchnm']),
      hod: safeInt(json['hod']),
      hodNm: safeString(json['hod_nm']),
      balances: const <LeaveBalance>[],
      profilePictureUrl: json['profile_picture_url'] as String?,
    );
  }
}
