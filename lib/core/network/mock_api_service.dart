import 'dart:async';

import '../../features/attendance/domain/entities/attendance_record.dart';
import '../../features/attendance/domain/entities/attendance_summary.dart';
import '../../features/authentication/domain/entities/user_entity.dart';
import '../../features/dashboard/domain/entities/dashboard_summary.dart';
import '../../features/leaves/domain/entities/leave_balance.dart';
import '../../features/leaves/domain/entities/leave_request.dart';
import '../../features/notifications/domain/entities/notification_message.dart';
import '../../features/profile/domain/entities/enhanced_profile_entity.dart';

class MockApiService {
  Future<UserEntity> login(String username, String password) async {
    await Future<void>.delayed(const Duration(milliseconds: 500));
    if (username == 'emp001' && password == 'Password@123') {
      final user = UserEntity(
        id: 'u-100',
        name: 'Sara Khan',
        employeeCode: 'EMP001',
        department: 'Human Resources',
        designation: 'HR Specialist',
        location: 'FTC Building',
        cardNumber: 'CARD-7788',
      );
      return user;
    }
    throw Exception('Invalid credentials');
  }

  Future<DashboardSummary> fetchDashboard() async {
    await Future<void>.delayed(const Duration(milliseconds: 600));
    return DashboardSummary(
      empPk: 100,
      cardNo1: 'CARD-7788',
      empNo: 'EMP001',
      empName: 'Sara Khan',
      dateOfJoin: '2020-01-15T00:00:00Z',
      nicNo: '12345-1234567-1',
      designation: 'HR Specialist',
      department: 'Human Resources',
      compcnm: 'Main Company',
      compc: 1,
      branch: 1,
      brnchnm: 'FTC Building',
      hod: 50,
      hodNm: 'John Manager',
      balances: const [
        LeaveBalance(code: 'CL', name: 'Casual Leave', balance: 6),
        LeaveBalance(code: 'EL', name: 'Earned Leave', balance: 15),
        LeaveBalance(code: 'ML', name: 'Medical Leave', balance: 8),
        LeaveBalance(code: 'CP', name: 'Compensatory Leave', balance: 3),
      ],
    );
  }

  Future<List<LeaveBalance>> fetchBalances() async {
    await Future<void>.delayed(const Duration(milliseconds: 400));
    return const [
      LeaveBalance(code: 'CL', name: 'Casual Leave', balance: 6),
      LeaveBalance(code: 'EL', name: 'Earned Leave', balance: 15),
      LeaveBalance(code: 'ML', name: 'Medical Leave', balance: 8),
      LeaveBalance(code: 'CP', name: 'Compensatory Leave', balance: 3),
      LeaveBalance(code: 'SL', name: 'Sick Leave', balance: 2),
    ];
  }

  Future<List<LeaveRequest>> fetchLeaveRequests() async {
    await Future<void>.delayed(const Duration(milliseconds: 400));
    return [
      LeaveRequest(
        id: 'lr-1',
        type: 'CL',
        fromDate: DateTime.now().add(const Duration(days: 2)),
        toDate: DateTime.now().add(const Duration(days: 3)),
        status: LeaveStatus.pending,
        reason: 'Family commitment',
        approverComment: null,
      ),
      LeaveRequest(
        id: 'lr-2',
        type: 'ML',
        fromDate: DateTime.now().subtract(const Duration(days: 5)),
        toDate: DateTime.now().subtract(const Duration(days: 4)),
        status: LeaveStatus.approved,
        reason: 'Medical Leave due to health reasons',
        approverComment: 'Approved by HR',
      ),
    ];
  }

  Future<List<AttendanceRecord>> fetchAttendance(
    DateTime from,
    DateTime to,
  ) async {
    await Future<void>.delayed(const Duration(milliseconds: 500));
    final records = <AttendanceRecord>[];
    var current = from;
    while (current.isBefore(to.add(const Duration(days: 1)))) {
      records.add(
        AttendanceRecord(
          date: current,
          shift: 'General',
          day: current.weekday,
          timeIn: const Duration(hours: 9, minutes: 15),
          timeOut: const Duration(hours: 18, minutes: 5),
          workHours: const Duration(hours: 8, minutes: 50),
          lateArrival: current.weekday % 3 == 0
              ? const Duration(minutes: 10)
              : Duration.zero,
          approvedHours: const Duration(hours: 8, minutes: 30),
          remarks: current.weekday % 5 == 0 ? 'Approved work from home' : '',
          isAbsent: current.weekday == DateTime.sunday,
        ),
      );
      current = current.add(const Duration(days: 1));
    }
    return records;
  }

  Future<AttendanceSummary> fetchAttendanceSummary() async {
    await Future<void>.delayed(const Duration(milliseconds: 300));
    return const AttendanceSummary(
      casualLeave: 1,
      earnedLeave: 0,
      medicalLeave: 0,
      compensatoryLeave: 0,
      sickLeave: 0,
      lossOfPay: 0,
      absent: 1,
      outdoorDuty: 0,
      approvedExtraWork: 4,
      lateCount: 2,
    );
  }

  Future<EnhancedProfileEntity> fetchProfile() async {
    await Future<void>.delayed(const Duration(milliseconds: 350));
    return EnhancedProfileEntity(
      name: 'Sara Khan',
      employeeCode: 'EMP001',
      cadre: 'Assistant Manager',
      department: 'Human Resources',
      designation: 'HR Specialist',
      joiningDate: '12-jan-2019',
      location: 'FTC Building',
      cardNumber: 'CARD-7788',
      email: 'sara.khan@ydc.com',
      phoneNumber: '+92-300-1234567',
      id: '',
      gender: '',
      dateOfBirth: '09-may-2003',
      branch: 'karachi',
    );
  }

  Future<List<NotificationMessage>> fetchNotifications() async {
    await Future<void>.delayed(const Duration(milliseconds: 350));
    return [
      NotificationMessage(
        id: 'nt-1',
        title: 'Leave Approved',
        body: 'Your leave for 07-Nov has been approved.',
        createdAt: DateTime.now().subtract(const Duration(hours: 2)),
        isRead: false,
      ),
      NotificationMessage(
        id: 'nt-2',
        title: 'Attendance Marked',
        body: 'Attendance marked automatically via geo-fence.',
        createdAt: DateTime.now().subtract(const Duration(days: 1)),
        isRead: true,
      ),
    ];
  }
}
