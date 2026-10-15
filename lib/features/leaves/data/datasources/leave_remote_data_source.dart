import 'package:dio/dio.dart';

import '../../../../core/network/dio_client.dart';
import '../../domain/entities/leave_balance.dart';
import '../../domain/entities/leave_request.dart';

abstract class LeaveRemoteDataSource {
  Future<List<LeaveBalance>> fetchBalances(String cardNo1);
  Future<List<LeaveRequest>> fetchRequests(String cardNo1);
  Future<void> submitRequest({
    required String empPk,
    required Map<String, dynamic> body,
  });
}

class LeaveRemoteDataSourceImpl implements LeaveRemoteDataSource {
  LeaveRemoteDataSourceImpl({Dio? dio}) : _dio = dio ?? DioClient.instance;

  final Dio _dio;

  @override
  Future<List<LeaveBalance>> fetchBalances(String cardNo1) async {
    final response = await _dio.get<Map<String, dynamic>>(
      '/auth/leave-balances/$cardNo1',
    );

    final responseData = response.data;
    if (responseData == null) {
      return [];
    }

    // API returns data in 'body.items' array format (ORDS REST API format)
    List<dynamic> items = [];

    // Check if response has 'body' with 'items' array
    if (responseData.containsKey('body')) {
      final body = responseData['body'] as Map<String, dynamic>?;
      if (body != null && body.containsKey('items')) {
        items = body['items'] as List<dynamic>? ?? [];
      }
    } else if (responseData.containsKey('items')) {
      // Items at root level (fallback)
      items = responseData['items'] as List<dynamic>? ?? [];
    }

    return items.map((b) => _mapBalance(b as Map<String, dynamic>)).toList();
  }

  @override
  Future<List<LeaveRequest>> fetchRequests(String cardNo1) async {
    // The backend exposes leave status via ORDS at /empdata/leavestatus/:card_no1
    // Use the provided card_no1 (empPk) returned on login/profile/dashboard.
    // Keeping parsing generic to support ORDS `body.items` format.
    // Base URL already points to /empdata — request the leavestatus path relative to it
    final response = await _dio.get<Map<String, dynamic>>(
      '/auth/leave-status/$cardNo1',
    );

    final responseData = response.data;
    if (responseData == null) return [];

    // ORDS style: body.items
    List<dynamic> items = [];
    if (responseData.containsKey('body')) {
      final body = responseData['body'] as Map<String, dynamic>?;
      if (body != null && body.containsKey('items')) {
        items = body['items'] as List<dynamic>? ?? [];
      }
    } else if (responseData.containsKey('items')) {
      items = responseData['items'] as List<dynamic>? ?? [];
    } else if (responseData.containsKey('data') && responseData['data'] is List) {
      items = responseData['data'] as List<dynamic>;
    }

    return items.map((r) => _mapRequest(r as Map<String, dynamic>)).toList();
  }

  @override
  Future<void> submitRequest({
    required String empPk,
    required Map<String, dynamic> body,
  }) async {
    await _dio.post('/auth/apply-leave/$empPk', data: body);
  }

  LeaveBalance _mapBalance(Map<String, dynamic> json) {
    // Handle new API format with leave_type, leave_desc, balance
    final code = (json['leave_type'] ?? json['code'] ?? '').toString();
    final name =
        (json['leave_desc'] ?? json['leave_type'] ?? json['name'] ?? '')
            .toString();

    // Balance can be double (e.g., 54.5) - convert to int by rounding
    final balanceValue =
        json['balance'] ?? json['available'] ?? json['total_available'] ?? 0;
    final balance = (balanceValue is num)
        ? balanceValue.round()
        : (int.tryParse(balanceValue.toString()) ?? 0);

    return LeaveBalance(code: code, name: name, balance: balance);
  }

  LeaveRequest _mapRequest(Map<String, dynamic> json) {
    LeaveStatus statusFromString(String value) {
      switch (value.toLowerCase()) {
        case 'approved':
        case 'approve':
          return LeaveStatus.approved;
        case 'rejected':
        case 'reject':
          return LeaveStatus.rejected;
        default:
          return LeaveStatus.pending;
      }
    }

    // Map incoming JSON keys from API sample
    final id = (json['entry_date'] ?? json['leave_date_from'] ?? json['card_no'] ?? json['emp_no'] ?? '').toString();
    final type = (json['leave_desc'] ?? json['type'] ?? '').toString();

    DateTime parseDate(dynamic v) {
      if (v == null) return DateTime.now();
      try {
        return DateTime.parse(v.toString());
      } catch (_) {
        return DateTime.tryParse(v.toString()) ?? DateTime.now();
      }
    }

    final from = parseDate(json['leave_date_from'] ?? json['from_date']);
    final to = parseDate(json['leave_date_to'] ?? json['to_date']);

    final statusValue = (json['approval_status'] ?? json['status'] ?? '').toString();
    final reason = (json['reason'] ?? json['leave_reason'] ?? '').toString();
    final leaveDays = (json['leave_days'] is num) ? (json['leave_days'] as num).toDouble() : double.tryParse((json['leave_days'] ?? '').toString()) ?? 0.0;

    final isHalfDay = (leaveDays == 0.5) ||
        (json['half_day'] == true) ||
        (json['half_day']?.toString().toUpperCase() == 'Y');

    return LeaveRequest(
      id: id,
      type: type,
      fromDate: from,
      toDate: to,
      status: statusFromString(statusValue),
      reason: reason,
      halfDay: isHalfDay,
      halfDaySession: isHalfDay
          ? HalfDaySessionX.fromApi(
              (json['half_day_session'] ?? json['half_day_type'] ?? json['session'])
                  ?.toString(),
            )
          : null,
      approverComment: (json['approver_comment'] ?? json['approverComment'] ?? json['remarks'])?.toString(),
    );
  }
}
