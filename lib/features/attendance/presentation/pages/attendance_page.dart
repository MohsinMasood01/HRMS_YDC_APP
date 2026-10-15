import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:lms/features/attendance/presentation/bloc/biometric_attendance_bloc.dart';
import 'package:open_filex/open_filex.dart';
import 'package:path_provider/path_provider.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/network/dio_client.dart';
import '../../../../core/services/attendance_status_service.dart'
    as status_service;
import '../../../../core/services/secure_storage_service.dart';
import '../../../../core/utils/date_formatter.dart';
import '../../../../di/service_locator.dart';
import '../../../../shared/widgets/loading_indicator.dart';
import '../../../authentication/presentation/bloc/auth_bloc.dart';
import '../../domain/entities/attendance_record.dart';
import '../bloc/attendance_bloc.dart';
import '../widgets/attendance_calendar.dart';
import 'biometric_attendance_page.dart';

class AttendancePage extends StatefulWidget {
  const AttendancePage({super.key});

  @override
  State<AttendancePage> createState() => _AttendancePageState();
}

class _AttendancePageState extends State<AttendancePage> {
  DateTime _selectedDate = DateTime.now();
  late DateTime _summaryFrom;
  late DateTime _summaryTo;
  bool _downloadingPdf = false;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _summaryFrom = DateTime(now.year, now.month, 1);
    _summaryTo = DateTime(now.year, now.month + 1, 0);
  }

  void _onMonthChanged(BuildContext context, DateTime focusedDay) {
    final start = DateTime(focusedDay.year, focusedDay.month, 1);
    final end = DateTime(focusedDay.year, focusedDay.month + 1, 0);
    setState(() {
      _summaryFrom = start;
      _summaryTo = end;
    });
    context.read<AttendanceBloc>().add(
      AttendanceRequested(from: start, to: end),
    );
  }

  Future<void> _pickDateRange(BuildContext context) async {
    final now = DateTime.now();
    // Clamp dates so they don't exceed lastDate (today)
    final clampedFrom = _summaryFrom.isAfter(now) ? now : _summaryFrom;
    final clampedTo = _summaryTo.isAfter(now) ? now : _summaryTo;
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: now,
      initialDateRange: DateTimeRange(start: clampedFrom, end: clampedTo),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: Theme.of(context).colorScheme,
          ),
          child: child!,
        );
      },
    );
    if (picked != null) {
      setState(() {
        _summaryFrom = picked.start;
        _summaryTo = picked.end;
      });
      if (context.mounted) {
        context.read<AttendanceBloc>().add(
          AttendanceRequested(from: picked.start, to: picked.end),
        );
      }
    }
  }

  /// Formats a [DateTime] as `YYYY-MM-DD` for the backend query parameters.
  /// Kept separate from [DateFormatter.formatDate] which is for display only.
  String _ymd(DateTime d) {
    final m = d.month.toString().padLeft(2, '0');
    final day = d.day.toString().padLeft(2, '0');
    return '${d.year}-$m-$day';
  }

  Future<void> _downloadPdfReport() async {
    if (_downloadingPdf) return;

    final messenger = ScaffoldMessenger.of(context);
    setState(() => _downloadingPdf = true);

    try {
      final ss = getIt<SecureStorageService>();
      final cardNo =
          (await ss.read('card_no1') ?? await ss.read('card_no') ?? '').trim();
      if (cardNo.isEmpty) {
        throw Exception('Card number not found. Please login again.');
      }

      final from = _ymd(_summaryFrom);
      final to = _ymd(_summaryTo);

      // Send the bearer token like the other /auth/attendance report calls so
      // the backend can authorize this endpoint the same way.
      final token = await ss.read('token');
      final headers = <String, dynamic>{};
      if (token != null && token.isNotEmpty) {
        headers['Authorization'] = 'Bearer $token';
      }

      final response = await DioClient.instance.get<List<int>>(
        '/auth/attendance/report-pdf/$cardNo',
        queryParameters: {'from_date': from, 'to_date': to},
        options: Options(
          responseType: ResponseType.bytes,
          headers: headers,
        ),
      );

      final bytes = response.data;
      if (bytes == null || bytes.isEmpty) {
        throw Exception('Empty PDF received');
      }

      final dir = await getTemporaryDirectory();
      final file = File('${dir.path}/attendance_${cardNo}_${from}_to_$to.pdf');
      await file.writeAsBytes(bytes, flush: true);

      final result = await OpenFilex.open(file.path);
      if (result.type != ResultType.done) {
        messenger.showSnackBar(
          SnackBar(content: Text('PDF saved to: ${file.path}')),
        );
      }
    } catch (e) {
      messenger.showSnackBar(
        SnackBar(
          content: Text('Failed to download report: $e'),
          backgroundColor: AppColors.error,
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _downloadingPdf = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => getIt<AttendanceBloc>()..add(const AttendanceRequested()),
      child: BlocBuilder<AttendanceBloc, AttendanceState>(
        buildWhen: (previous, current) {
          return previous.records != current.records ||
              previous.status != current.status;
        },
        builder: (context, state) {
          if (state.status == AttendanceStatus.loading &&
              state.records.isEmpty) {
            return const LoadingIndicator();
          }

          final rangeCounts = _computeRangeCounts(state.records);

          // Records for the selected date range, newest first
          final rangeRecords = state.records
              .where((r) {
                final d = DateTime(r.date.year, r.date.month, r.date.day);
                final from = DateTime(_summaryFrom.year, _summaryFrom.month, _summaryFrom.day);
                final to = DateTime(_summaryTo.year, _summaryTo.month, _summaryTo.day);
                return !d.isBefore(from) && !d.isAfter(to);
              })
              .toList()
            ..sort((a, b) => b.date.compareTo(a.date));

          return RefreshIndicator(
            onRefresh: () async =>
                context.read<AttendanceBloc>().add(AttendanceRequested(
                  from: _summaryFrom,
                  to: _summaryTo,
                )),
            child: ListView(
              padding: EdgeInsets.all(16.w),
              children: [
                // 1. Mark Attendance Button
                const _BiometricAttendanceButton(),
                SizedBox(height: 16.h),

                // 2. Date Range Filter
                Row(
                  children: [
                    Expanded(
                      child: _DateRangeSelector(
                        from: _summaryFrom,
                        to: _summaryTo,
                        onTap: () => _pickDateRange(context),
                      ),
                    ),
                    SizedBox(width: 8.w),
                    _PdfDownloadButton(
                      downloading: _downloadingPdf,
                      onTap: _downloadPdfReport,
                    ),
                  ],
                ),
                SizedBox(height: 16.h),

                // 3. Calendar View
                const _SectionHeader(
                  title: 'Attendance Calendar',
                  icon: Icons.calendar_month_rounded,
                ),
                SizedBox(height: 12.h),
                AttendanceCalendar(
                  records: state.records,
                  selectedDate: _selectedDate,
                  onDateSelected: (date) {
                    setState(() {
                      _selectedDate = date;
                    });
                  },
                  onPageChanged: (focusedDay) =>
                      _onMonthChanged(context, focusedDay),
                ),
                SizedBox(height: 12.h),
                // Legend inline below calendar
                const _CalendarLegend(),
                SizedBox(height: 20.h),

                // 4. Records list for the selected range
                _SectionHeader(
                  title: 'Daily Records (${rangeRecords.length})',
                  icon: Icons.list_alt_rounded,
                ),
                SizedBox(height: 12.h),
                if (rangeRecords.isEmpty)
                  Container(
                    padding: EdgeInsets.all(24.w),
                    decoration: BoxDecoration(
                      color: Theme.of(context).brightness == Brightness.dark
                          ? Colors.white.withValues(alpha: 0.05)
                          : Colors.white,
                      borderRadius: BorderRadius.circular(16.r),
                      border: Border.all(color: Colors.grey.shade200),
                    ),
                    child: Center(
                      child: Text(
                        'No records for selected period',
                        style: TextStyle(
                          fontSize: 14.sp,
                          color: Theme.of(context).brightness == Brightness.dark
                              ? Colors.white38
                              : AppColors.textSecondary,
                        ),
                      ),
                    ),
                  )
                else
                  ...rangeRecords.map((r) => Padding(
                    padding: EdgeInsets.only(bottom: 8.h),
                    child: _AttendanceDetailsCard(record: r),
                  )),
                SizedBox(height: 20.h),

                // 5. Summary
                const _SectionHeader(
                  title: 'Summary',
                  icon: Icons.analytics_outlined,
                ),
                SizedBox(height: 12.h),
                _SummaryGrid(counts: rangeCounts),
                SizedBox(height: 20.h),
              ],
            ),
          );
        },
      ),
    );
  }

  MonthlyStatusCounts _computeRangeCounts(List<AttendanceRecord> records) {
    int present = 0;
    int late = 0;
    int halfDay = 0;
    int absent = 0;

    final fromNorm = DateTime(_summaryFrom.year, _summaryFrom.month, _summaryFrom.day);
    final toNorm = DateTime(_summaryTo.year, _summaryTo.month, _summaryTo.day);

    for (final record in records) {
      final d = DateTime(record.date.year, record.date.month, record.date.day);
      if (d.isBefore(fromNorm) || d.isAfter(toNorm)) continue;

      final status = _getStatus(record);
      switch (status) {
        case status_service.AttendanceDayStatus.present:
          present++;
          break;
        case status_service.AttendanceDayStatus.late:
          late++;
          break;
        case status_service.AttendanceDayStatus.halfDay:
          halfDay++;
          break;
        case status_service.AttendanceDayStatus.absent:
          absent++;
          break;
        default:
          break;
      }
    }

    return MonthlyStatusCounts(
      present: present,
      late: late,
      halfDay: halfDay,
      absent: absent,
    );
  }

  status_service.AttendanceDayStatus _getStatus(AttendanceRecord record) {
    if (record.isAbsent) {
      return status_service.AttendanceDayStatus.absent;
    }
    final checkInDateTime = DateTime(
      record.date.year,
      record.date.month,
      record.date.day,
    ).add(record.timeIn);

    return status_service.AttendanceStatusService.calculateStatus(
      checkInTime: checkInDateTime,
      isAbsent: record.isAbsent,
      isLeave: false,
    );
  }
}

class _CalendarLegend extends StatelessWidget {
  const _CalendarLegend();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final legendItems = [
      _LegendItem(
        'Present',
        Color(
          status_service.AttendanceStatusService.getStatusColor(
            status_service.AttendanceDayStatus.present,
          ),
        ),
        status_service.AttendanceStatusService.getStatusIcon(
          status_service.AttendanceDayStatus.present,
        ),
      ),
      _LegendItem(
        'Late',
        Color(
          status_service.AttendanceStatusService.getStatusColor(
            status_service.AttendanceDayStatus.late,
          ),
        ),
        status_service.AttendanceStatusService.getStatusIcon(
          status_service.AttendanceDayStatus.late,
        ),
      ),
      _LegendItem(
        'Half Day',
        Color(
          status_service.AttendanceStatusService.getStatusColor(
            status_service.AttendanceDayStatus.halfDay,
          ),
        ),
        status_service.AttendanceStatusService.getStatusIcon(
          status_service.AttendanceDayStatus.halfDay,
        ),
      ),
      _LegendItem(
        'On Leave',
        Color(
          status_service.AttendanceStatusService.getStatusColor(
            status_service.AttendanceDayStatus.onLeave,
          ),
        ),
        status_service.AttendanceStatusService.getStatusIcon(
          status_service.AttendanceDayStatus.onLeave,
        ),
      ),
      _LegendItem(
        'Absent',
        Color(
          status_service.AttendanceStatusService.getStatusColor(
            status_service.AttendanceDayStatus.absent,
          ),
        ),
        status_service.AttendanceStatusService.getStatusIcon(
          status_service.AttendanceDayStatus.absent,
        ),
      ),
    ];

    return Container(
      padding: EdgeInsets.all(16.w),
      decoration: BoxDecoration(
        color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.white,
        borderRadius: BorderRadius.circular(16.r),
        border: Border.all(
          color: isDark ? Colors.white12 : Colors.grey.shade200,
        ),
      ),
      child: Wrap(
        spacing: 16.w,
        runSpacing: 12.h,
        children: legendItems
            .map((item) => _buildLegendItem(item, isDark))
            .toList(),
      ),
    );
  }

  Widget _buildLegendItem(_LegendItem item, bool isDark) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 24.w,
          height: 24.w,
          decoration: BoxDecoration(
            color: item.color.withValues(alpha: 0.2),
            shape: BoxShape.circle,
            border: Border.all(color: item.color, width: 2),
          ),
          child: Center(
            child: Text(
              item.icon,
              style: TextStyle(
                color: item.color,
                fontSize: 12.sp,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ),
        SizedBox(width: 8.w),
        Text(
          item.label,
          style: TextStyle(
            fontSize: 12.sp,
            color: isDark ? Colors.white70 : AppColors.textSecondary,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
}

class _LegendItem {
  final String label;
  final Color color;
  final String icon;

  _LegendItem(this.label, this.color, this.icon);
}

class _AttendanceDetailsCard extends StatelessWidget {
  const _AttendanceDetailsCard({required this.record});

  final AttendanceRecord record;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    // Calculate status
    final checkInDateTime = DateTime(
      record.date.year,
      record.date.month,
      record.date.day,
    ).add(record.timeIn);

    final status = status_service.AttendanceStatusService.calculateStatus(
      checkInTime: checkInDateTime,
      isAbsent: record.isAbsent,
    );

    final statusColor = Color(
      status_service.AttendanceStatusService.getStatusColor(status),
    );
    final statusName = status_service.AttendanceStatusService.getStatusName(
      status,
    );

    return Container(
      padding: EdgeInsets.all(16.w),
      decoration: BoxDecoration(
        color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.white,
        borderRadius: BorderRadius.circular(16.r),
        border: Border.all(
          color: isDark ? Colors.white12 : Colors.grey.shade200,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: EdgeInsets.all(8.w),
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10.r),
                ),
                child: Text(
                  status_service.AttendanceStatusService.getStatusIcon(status),
                  style: TextStyle(
                    color: statusColor,
                    fontSize: 18.sp,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              SizedBox(width: 12.w),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      DateFormatter.formatDate(record.date),
                      style: TextStyle(
                        fontSize: 16.sp,
                        fontWeight: FontWeight.bold,
                        color: isDark ? Colors.white : AppColors.textPrimary,
                      ),
                    ),
                    SizedBox(height: 4.h),
                    Text(
                      statusName,
                      style: TextStyle(
                        fontSize: 13.sp,
                        color: statusColor,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          SizedBox(height: 16.h),
          Row(
            children: [
              _TimeDetail(
                icon: Icons.login_rounded,
                label: 'Check In',
                value: DateFormatter.formatHours(record.timeIn),
                color: AppColors.success,
                isDark: isDark,
              ),
              SizedBox(width: 16.w),
              _TimeDetail(
                icon: Icons.logout_rounded,
                label: 'Check Out',
                value: record.timeOut.inHours > 0
                    ? DateFormatter.formatHours(record.timeOut)
                    : '--',
                color: AppColors.error,
                isDark: isDark,
              ),
              SizedBox(width: 16.w),
              _TimeDetail(
                icon: Icons.timer_outlined,
                label: 'Hours',
                value: DateFormatter.formatHours(record.workHours),
                color: theme.primaryColor,
                isDark: isDark,
              ),
            ],
          ),
          if (record.remarks.isNotEmpty) ...[
            SizedBox(height: 12.h),
            Container(
              padding: EdgeInsets.all(12.w),
              decoration: BoxDecoration(
                color: isDark
                    ? Colors.white.withValues(alpha: 0.03)
                    : Colors.grey.shade50,
                borderRadius: BorderRadius.circular(8.r),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.note_outlined,
                    size: 16.sp,
                    color: isDark ? Colors.white38 : Colors.grey.shade500,
                  ),
                  SizedBox(width: 8.w),
                  Expanded(
                    child: Text(
                      record.remarks,
                      style: TextStyle(
                        fontSize: 12.sp,
                        color: isDark
                            ? Colors.white54
                            : AppColors.textSecondary,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _TimeDetail extends StatelessWidget {
  const _TimeDetail({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
    required this.isDark,
  });

  final IconData icon;
  final String label;
  final String value;
  final Color color;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 14.sp, color: color),
              SizedBox(width: 4.w),
              Text(
                label,
                style: TextStyle(
                  fontSize: 11.sp,
                  color: isDark ? Colors.white38 : AppColors.textSecondary,
                ),
              ),
            ],
          ),
          SizedBox(height: 4.h),
          Text(
            value,
            style: TextStyle(
              fontSize: 14.sp,
              fontWeight: FontWeight.w600,
              color: isDark ? Colors.white : AppColors.textPrimary,
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title, required this.icon});

  final String title;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Row(
      children: [
        Container(
          padding: EdgeInsets.all(8.w),
          decoration: BoxDecoration(
            color: theme.primaryColor.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(10.r),
          ),
          child: Icon(icon, size: 18.sp, color: theme.primaryColor),
        ),
        SizedBox(width: 12.w),
        Text(
          title,
          style: TextStyle(
            fontSize: 17.sp,
            fontWeight: FontWeight.bold,
            color: isDark ? Colors.white : AppColors.textPrimary,
          ),
        ),
      ],
    );
  }
}

class _SummaryGrid extends StatelessWidget {
  const _SummaryGrid({required this.counts});

  final MonthlyStatusCounts counts;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final entries = [
      _SummaryItem('Present', counts.present, const Color(0xFF4CAF50)),
      _SummaryItem('Absent', counts.absent, const Color(0xFFF44336)),
      _SummaryItem('Half Day', counts.halfDay, const Color(0xFFFF9800)),
      _SummaryItem('Late', counts.late, const Color(0xFFF44336)),
    ];

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        childAspectRatio: 2.6,
        mainAxisSpacing: 12.h,
        crossAxisSpacing: 12.w,
      ),
      itemCount: entries.length,
      itemBuilder: (context, index) {
        final item = entries[index];
        return Container(
          decoration: BoxDecoration(
            color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.white,
            borderRadius: BorderRadius.circular(12.r),
            border: Border.all(
              color: isDark ? Colors.white12 : Colors.grey.shade200,
            ),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                '${item.value}',
                style: TextStyle(
                  fontSize: 18.sp,
                  fontWeight: FontWeight.bold,
                  color: item.color,
                ),
              ),
              SizedBox(height: 2.h),
              Text(
                item.label,
                style: TextStyle(
                  fontSize: 10.sp,
                  color: isDark ? Colors.white54 : AppColors.textSecondary,
                  fontWeight: FontWeight.w500,
                ),
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        );
      },
    );
  }
}

class _SummaryItem {
  final String label;
  final int value;
  final Color color;

  _SummaryItem(this.label, this.value, this.color);
}

class MonthlyStatusCounts {
  const MonthlyStatusCounts({
    required this.present,
    required this.late,
    required this.halfDay,
    required this.absent,
  });

  final int present;
  final int late;
  final int halfDay;
  final int absent;
}

class _DateRangeSelector extends StatelessWidget {
  const _DateRangeSelector({
    required this.from,
    required this.to,
    required this.onTap,
  });

  final DateTime from;
  final DateTime to;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12.r),
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 12.h),
        decoration: BoxDecoration(
          color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.white,
          borderRadius: BorderRadius.circular(12.r),
          border: Border.all(
            color: isDark ? Colors.white12 : Colors.grey.shade200,
          ),
        ),
        child: Row(
          children: [
            Icon(
              Icons.date_range_rounded,
              size: 20.sp,
              color: theme.primaryColor,
            ),
            SizedBox(width: 10.w),
            Text(
              '${DateFormatter.formatDate(from)}  -  ${DateFormatter.formatDate(to)}',
              style: TextStyle(
                fontSize: 13.sp,
                fontWeight: FontWeight.w600,
                color: isDark ? Colors.white : AppColors.textPrimary,
              ),
            ),
            const Spacer(),
            Icon(
              Icons.edit_calendar_rounded,
              size: 18.sp,
              color: isDark ? Colors.white54 : AppColors.textSecondary,
            ),
          ],
        ),
      ),
    );
  }
}

class _PdfDownloadButton extends StatelessWidget {
  const _PdfDownloadButton({
    required this.downloading,
    required this.onTap,
  });

  final bool downloading;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return InkWell(
      onTap: downloading ? null : onTap,
      borderRadius: BorderRadius.circular(12.r),
      child: Container(
        padding: EdgeInsets.all(12.h),
        decoration: BoxDecoration(
          color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.white,
          borderRadius: BorderRadius.circular(12.r),
          border: Border.all(
            color: isDark ? Colors.white12 : Colors.grey.shade200,
          ),
        ),
        child: downloading
            ? SizedBox(
                width: 20.sp,
                height: 20.sp,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor:
                      AlwaysStoppedAnimation<Color>(theme.primaryColor),
                ),
              )
            : Icon(
                Icons.picture_as_pdf_rounded,
                size: 20.sp,
                color: theme.primaryColor,
              ),
      ),
    );
  }
}

class _BiometricAttendanceButton extends StatelessWidget {
  const _BiometricAttendanceButton();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return BlocBuilder<AuthBloc, AuthState>(
      buildWhen: (previous, current) {
        // Only rebuild when user changes
        return previous.user?.id != current.user?.id;
      },
      builder: (context, authState) {
        final employeeId = authState.user?.id ?? 'unknown';

        return Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                theme.primaryColor,
                theme.primaryColor.withValues(alpha: 0.8),
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(16.r),
            boxShadow: [
              BoxShadow(
                color: theme.primaryColor.withValues(alpha: 0.3),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => BlocProvider(
                      create: (_) => BiometricAttendanceBloc(
                        biometricService: getIt(),
                        geocodingService: getIt(),
                        attendanceFileService: getIt(),
                        validationService: getIt(),
                        appConfig: getIt(),
                        employeeId: employeeId,
                        locationService: getIt(),
                        authRepository: getIt(),
                        markBiometricAttendanceUseCase: getIt(),
                        faceStatusUseCase: getIt(),
                        verifyFaceUseCase: getIt(),
                        faceCameraDataSource: getIt(),
                      )..add(const BiometricAttendanceInitialized()),
                      child: const BiometricAttendancePage(),
                    ),
                  ),
                );
              },
              borderRadius: BorderRadius.circular(16.r),
              child: Padding(
                padding: EdgeInsets.all(20.w),
                child: Row(
                  children: [
                    Container(
                      padding: EdgeInsets.all(12.w),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(12.r),
                      ),
                      child: Icon(
                        Icons.fingerprint_rounded,
                        color: Colors.white,
                        size: 28.sp,
                      ),
                    ),
                    SizedBox(width: 16.w),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Mark Attendance',
                            style: TextStyle(
                              fontSize: 18.sp,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                          SizedBox(height: 4.h),
                          Text(
                            'Use biometric authentication',
                            style: TextStyle(
                              fontSize: 13.sp,
                              color: Colors.white.withValues(alpha: 0.9),
                            ),
                          ),
                        ],
                      ),
                    ),
                    Icon(
                      Icons.arrow_forward_ios_rounded,
                      color: Colors.white,
                      size: 20.sp,
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
