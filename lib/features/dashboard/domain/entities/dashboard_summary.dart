import 'package:equatable/equatable.dart';

import '../../../leaves/domain/entities/leave_balance.dart';

class DashboardSummary extends Equatable {
  const DashboardSummary({
    required this.empPk,
    required this.cardNo1,
    required this.empNo,
    required this.empName,
    required this.dateOfJoin,
    required this.nicNo,
    required this.designation,
    required this.department,
    required this.compcnm,
    required this.compc,
    required this.branch,
    required this.brnchnm,
    required this.hod,
    required this.hodNm,
    required this.balances,
    this.profilePictureUrl,
  });

  final int empPk;
  final String cardNo1;
  final String empNo;
  final String empName;
  final String dateOfJoin;
  final String nicNo;
  final String designation;
  final String department;
  final String compcnm;
  final int compc;
  final int branch;
  final String brnchnm;
  final int hod;
  final String hodNm;
  final List<LeaveBalance> balances;
  final String? profilePictureUrl;

  // Convenience getters for backward compatibility
  String get userName => empName;
  String get employeeCode => empNo;
  String get cardNumber => cardNo1;
  String get location => brnchnm;
  String get cadre => designation;

  @override
  List<Object?> get props => [
    empPk,
    cardNo1,
    empNo,
    empName,
    dateOfJoin,
    nicNo,
    designation,
    department,
    compcnm,
    compc,
    branch,
    brnchnm,
    hod,
    hodNm,
    balances,
    profilePictureUrl,
  ];
}
