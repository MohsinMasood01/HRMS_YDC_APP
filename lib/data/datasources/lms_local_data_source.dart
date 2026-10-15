import '../../core/services/local_storage_service.dart';
import '../../features/attendance/domain/entities/attendance_record.dart';
import '../../features/attendance/domain/entities/attendance_summary.dart';
import '../../features/dashboard/domain/entities/dashboard_summary.dart';
import '../../features/leaves/domain/entities/leave_balance.dart';
import '../../features/leaves/domain/entities/leave_request.dart';
import '../../features/notifications/domain/entities/notification_message.dart';
import '../../features/profile/domain/entities/enhanced_profile_entity.dart';

class LmsLocalDataSource {
  LmsLocalDataSource(this._storage);

  static const _dashboardKey = 'dashboard_cache';
  static const _balancesKey = 'leave_balances_cache';
  static const _requestsKey = 'leave_requests_cache';
  static const _profileKey = 'profile_cache';
  static const _attendanceKey = 'attendance_cache';
  static const _attendanceSummaryKey = 'attendance_summary_cache';
  static const _notificationsKey = 'notifications_cache';

  final LocalStorageService _storage;

  Future<void> cacheDashboard(DashboardSummary summary) async {
    await _storage.writeJson(_dashboardKey, {
      'empPk': summary.empPk,
      'cardNo1': summary.cardNo1,
      'empNo': summary.empNo,
      'empName': summary.empName,
      'dateOfJoin': summary.dateOfJoin,
      'nicNo': summary.nicNo,
      'designation': summary.designation,
      'department': summary.department,
      'compcnm': summary.compcnm,
      'compc': summary.compc,
      'branch': summary.branch,
      'brnchnm': summary.brnchnm,
      'hod': summary.hod,
      'hodNm': summary.hodNm,
      'balances': summary.balances
          .map(
            (balance) => {
              'code': balance.code,
              'name': balance.name,
              'balance': balance.balance,
            },
          )
          .toList(),
    });
  }

  DashboardSummary? dashboard() {
    final data = _storage.readJson(_dashboardKey);
    if (data == null) return null;

    int safeInt(dynamic value) {
      if (value == null) return 0;
      if (value is int) return value;
      if (value is String) return int.tryParse(value) ?? 0;
      return 0;
    }

    String safeString(dynamic value) {
      if (value == null) return '-';
      return value.toString();
    }

    return DashboardSummary(
      empPk: safeInt(data['empPk'] ?? data['emp_pk']),
      cardNo1: safeString(
        data['cardNo1'] ?? data['card_no'] ?? data['cardNumber'],
      ),
      empNo: safeString(
        data['empNo'] ?? data['emp_no'] ?? data['employeeCode'],
      ),
      empName: safeString(
        data['empName'] ?? data['emp_name'] ?? data['userName'],
      ),
      dateOfJoin: safeString(data['dateOfJoin'] ?? data['date_of_join']),
      nicNo: safeString(data['nicNo'] ?? data['nic_no']),
      designation: safeString(data['designation']),
      department: safeString(data['department']),
      compcnm: safeString(data['compcnm']),
      compc: safeInt(data['compc']),
      branch: safeInt(data['branch']),
      brnchnm: safeString(data['brnchnm'] ?? data['location']),
      hod: safeInt(data['hod']),
      hodNm: safeString(data['hodNm'] ?? data['hod_nm']),
      balances:
          (data['balances'] as List<dynamic>?)
              ?.map(
                (e) => LeaveBalance(
                  code: e['code'] as String,
                  name: e['name'] as String,
                  balance: e['balance'] as int,
                ),
              )
              .toList() ??
          const [],
    );
  }

  Future<void> cacheBalances(List<LeaveBalance> balances) async {
    await _storage.writeJson(_balancesKey, {
      'items': balances
          .map((e) => {'code': e.code, 'name': e.name, 'balance': e.balance})
          .toList(),
    });
  }

  List<LeaveBalance>? balances() {
    final data = _storage.readJson(_balancesKey);
    if (data == null) return null;
    return (data['items'] as List<dynamic>)
        .map(
          (e) => LeaveBalance(
            code: e['code'] as String,
            name: e['name'] as String,
            balance: e['balance'] as int,
          ),
        )
        .toList();
  }

  Future<void> cacheLeaveRequests(List<LeaveRequest> requests) async {
    await _storage.writeJson(_requestsKey, {
      'items': requests
          .map(
            (e) => {
              'id': e.id,
              'type': e.type,
              'from': e.fromDate.toIso8601String(),
              'to': e.toDate.toIso8601String(),
              'status': e.status.name,
              'reason': e.reason,
              'halfDay': e.halfDay,
              'approverComment': e.approverComment,
            },
          )
          .toList(),
    });
  }

  List<LeaveRequest>? leaveRequests() {
    final data = _storage.readJson(_requestsKey);
    if (data == null) return null;
    return (data['items'] as List<dynamic>)
        .map(
          (e) => LeaveRequest(
            id: e['id'] as String,
            type: e['type'] as String,
            fromDate: DateTime.parse(e['from'] as String),
            toDate: DateTime.parse(e['to'] as String),
            status: LeaveStatus.values.firstWhere(
              (status) => status.name == e['status'],
            ),
            reason: e['reason'] as String,
            halfDay: e['halfDay'] as bool,
            approverComment: e['approverComment'] as String?,
          ),
        )
        .toList();
  }

  Future<void> cacheProfile(EnhancedProfileEntity profile) async {
    await _storage.writeJson(_profileKey, {
      'name': profile.name,
      'employeeCode': profile.employeeCode,
      'cadre': profile.cadre,
      'department': profile.department,
      'designation': profile.designation,
      'joiningDate': profile.joiningDate,
      'location': profile.location,
      'cardNumber': profile.cardNumber,
      'email': profile.email,
      'phoneNumber': profile.phoneNumber,
      'gender': profile.gender,
      'branch': profile.branch,
      'dateOfBirth': profile.dateOfBirth,
    });
  }

  EnhancedProfileEntity? profile() {
    final data = _storage.readJson(_profileKey);
    if (data == null) return null;
    return EnhancedProfileEntity(
      id: data['employeeCode'] as String,
      employeeCode: data['employeeCode'] as String,
      name: data['name'] as String,
      email: data['email'] as String,
      phoneNumber: data['phoneNumber'] as String,
      gender: data['gender'] as String? ?? 'M',
      dateOfBirth: data['dateOfBirth'] as String? ?? '-',
      joiningDate: data['joiningDate'] as String? ?? '-',
      department: data['department'] as String,
      designation: data['designation'] as String,
      cadre: data['cadre'] as String? ?? '',
      location: data['location'] as String? ?? '',
      branch: data['branch'] as String? ?? '',
      cardNumber: data['cardNumber'] as String? ?? '',
    );
  }

  Future<void> cacheAttendance(List<AttendanceRecord> records) async {
    await _storage.writeJson(_attendanceKey, {
      'items': records
          .map(
            (e) => {
              'date': e.date.toIso8601String(),
              'shift': e.shift,
              'day': e.day,
              'timeIn': e.timeIn.inMinutes,
              'timeOut': e.timeOut.inMinutes,
              'workHours': e.workHours.inMinutes,
              'lateArrival': e.lateArrival.inMinutes,
              'approvedHours': e.approvedHours.inMinutes,
              'remarks': e.remarks,
              'isAbsent': e.isAbsent,
            },
          )
          .toList(),
    });
  }

  List<AttendanceRecord>? attendance() {
    final data = _storage.readJson(_attendanceKey);
    if (data == null) return null;
    return (data['items'] as List<dynamic>)
        .map(
          (e) => AttendanceRecord(
            date: DateTime.parse(e['date'] as String),
            shift: e['shift'] as String,
            day: e['day'] as int,
            timeIn: Duration(minutes: e['timeIn'] as int),
            timeOut: Duration(minutes: e['timeOut'] as int),
            workHours: Duration(minutes: e['workHours'] as int),
            lateArrival: Duration(minutes: e['lateArrival'] as int),
            approvedHours: Duration(minutes: e['approvedHours'] as int),
            remarks: e['remarks'] as String,
            isAbsent: e['isAbsent'] as bool,
          ),
        )
        .toList();
  }

  Future<void> cacheAttendanceSummary(AttendanceSummary summary) async {
    await _storage.writeJson(_attendanceSummaryKey, {
      'casualLeave': summary.casualLeave,
      'earnedLeave': summary.earnedLeave,
      'medicalLeave': summary.medicalLeave,
      'compensatoryLeave': summary.compensatoryLeave,
      'sickLeave': summary.sickLeave,
      'lossOfPay': summary.lossOfPay,
      'absent': summary.absent,
      'outdoorDuty': summary.outdoorDuty,
      'approvedExtraWork': summary.approvedExtraWork,
      'lateCount': summary.lateCount,
    });
  }

  AttendanceSummary? attendanceSummary() {
    final data = _storage.readJson(_attendanceSummaryKey);
    if (data == null) return null;
    return AttendanceSummary(
      casualLeave: data['casualLeave'] as int,
      earnedLeave: data['earnedLeave'] as int,
      medicalLeave: data['medicalLeave'] as int,
      compensatoryLeave: data['compensatoryLeave'] as int,
      sickLeave: data['sickLeave'] as int,
      lossOfPay: data['lossOfPay'] as int,
      absent: data['absent'] as int,
      outdoorDuty: data['outdoorDuty'] as int,
      approvedExtraWork: data['approvedExtraWork'] as int,
      lateCount: data['lateCount'] as int,
    );
  }

  Future<void> cacheNotifications(
    List<NotificationMessage> notifications,
  ) async {
    await _storage.writeJson(_notificationsKey, {
      'items': notifications
          .map(
            (e) => {
              'id': e.id,
              'title': e.title,
              'body': e.body,
              'createdAt': e.createdAt.toIso8601String(),
              'isRead': e.isRead,
            },
          )
          .toList(),
    });
  }

  List<NotificationMessage>? notifications() {
    final data = _storage.readJson(_notificationsKey);
    if (data == null) return null;
    return (data['items'] as List<dynamic>)
        .map(
          (e) => NotificationMessage(
            id: e['id'] as String,
            title: e['title'] as String,
            body: e['body'] as String,
            createdAt: DateTime.parse(e['createdAt'] as String),
            isRead: e['isRead'] as bool,
          ),
        )
        .toList();
  }
}
