import 'package:equatable/equatable.dart';

class AttendanceSummary extends Equatable {
  const AttendanceSummary({
    required this.casualLeave,
    required this.earnedLeave,
    required this.medicalLeave,
    required this.compensatoryLeave,
    required this.sickLeave,
    required this.lossOfPay,
    required this.absent,
    required this.outdoorDuty,
    required this.approvedExtraWork,
    required this.lateCount,
    this.totalDays = 0,
    this.presentDays = 0,
    this.incompleteDays = 0,
    this.totalMinutes = 0,
  });

  final int casualLeave;
  final int earnedLeave;
  final int medicalLeave;
  final int compensatoryLeave;
  final int sickLeave;
  final int lossOfPay;
  final int absent;
  final int outdoorDuty;
  final int approvedExtraWork;
  final int lateCount;
  final int totalDays;
  final int presentDays;
  final int incompleteDays;
  final int totalMinutes;

  @override
  List<Object?> get props => [
        casualLeave,
        earnedLeave,
        medicalLeave,
        compensatoryLeave,
        sickLeave,
        lossOfPay,
        absent,
        outdoorDuty,
        approvedExtraWork,
        lateCount,
        totalDays,
        presentDays,
        incompleteDays,
        totalMinutes,
      ];
}

