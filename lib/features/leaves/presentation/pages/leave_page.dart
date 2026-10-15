import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../../core/utils/date_formatter.dart';
import '../../../../di/service_locator.dart';
import '../../../../shared/widgets/app_button.dart';
import '../../../../shared/widgets/app_card.dart';
import '../../../../shared/widgets/loading_indicator.dart';
import '../../../../shared/widgets/status_badge.dart';
import '../../domain/entities/leave_request.dart';
import '../bloc/leave_application/leave_application_bloc.dart';
import '../bloc/leave_balance/leave_balance_bloc.dart';
import '../bloc/leave_status/leave_status_bloc.dart';

class LeavePage extends StatelessWidget {
  const LeavePage({super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 3,
      child: Column(
        children: const [
          TabBar(
            tabs: [
              Tab(text: 'Balances'),
              Tab(text: 'Apply'),
              Tab(text: 'Status'),
            ],
          ),
          Expanded(
            child: TabBarView(
              children: [
                _LeaveBalanceView(),
                _LeaveApplicationView(),
                _LeaveStatusView(),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _LeaveBalanceView extends StatelessWidget {
  const _LeaveBalanceView();

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) =>
          getIt<LeaveBalanceBloc>()..add(const LeaveBalanceRequested()),
      child: BlocBuilder<LeaveBalanceBloc, LeaveBalanceState>(
        builder: (context, state) {
          if (state.status == LeaveBalanceStatus.loading) {
            return const LoadingIndicator();
          }
          if (state.balances.isEmpty) {
            return const Center(child: Text('No balances available'));
          }
          return ListView.separated(
            padding: EdgeInsets.all(16.w),
            itemCount: state.balances.length,
            separatorBuilder: (_, __) => SizedBox(height: 12.h),
            itemBuilder: (context, index) {
              final balance = state.balances[index];
              return AppCard(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            balance.name,
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                          Text(
                            balance.code,
                            style: Theme.of(context).textTheme.labelMedium,
                          ),
                        ],
                      ),
                    ),
                    Text(
                      '${balance.balance < 0 ? 0 : balance.balance} days',
                      style: Theme.of(context).textTheme.headlineSmall
                          ?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: balance.balance <= 0 ? Colors.grey : null,
                      ),
                    ),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }
}

class _LeaveApplicationView extends StatelessWidget {
  const _LeaveApplicationView();

  @override
  Widget build(BuildContext context) {
    return MultiBlocProvider(
      providers: [
        BlocProvider(create: (_) => getIt<LeaveApplicationBloc>()),
        BlocProvider(
          create: (_) =>
              getIt<LeaveBalanceBloc>()..add(const LeaveBalanceRequested()),
        ),
      ],
      child: BlocConsumer<LeaveApplicationBloc, LeaveApplicationState>(
        listener: (context, state) {
          if (state.status == LeaveApplicationStatus.success) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Leave submitted successfully'),
                duration: Duration(seconds: 2),
              ),
            );
          } else if (state.status == LeaveApplicationStatus.failure) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(state.errorMessage ?? 'Failed to submit leave'),
                duration: const Duration(seconds: 2),
              ),
            );
          }
        },
        builder: (context, state) {
          return BlocBuilder<LeaveBalanceBloc, LeaveBalanceState>(
            builder: (context, balanceState) {
              // Only show leave types with positive balance
              final availableTypes = balanceState.balances
                  .where((b) => b.balance > 0)
                  .toList();

              // If selected type no longer has balance, reset it
              final currentType = state.leaveType;
              final isCurrentTypeValid = currentType.isEmpty ||
                  availableTypes.any((b) => b.code == currentType);

          return ListView(
            padding: EdgeInsets.all(16.w),
            children: [
              DropdownButtonFormField<String>(
                decoration: const InputDecoration(labelText: 'Leave Type'),
                initialValue: isCurrentTypeValid ? (currentType.isEmpty ? null : currentType) : null,
                items: availableTypes
                    .map(
                      (b) => DropdownMenuItem(
                        value: b.code,
                        child: Text('${b.code} - ${b.name} (${b.balance} days)'),
                      ),
                    )
                    .toList(),
                onChanged: (value) => context.read<LeaveApplicationBloc>().add(
                  LeaveTypeChanged(value ?? ''),
                ),
                hint: availableTypes.isEmpty
                    ? const Text('No leave balance available')
                    : const Text('Select leave type'),
              ),
              SizedBox(height: 12.h),
              // A half-day leave covers a single day, so the range pickers
              // collapse into one Date field.
              if (state.halfDay)
                _datePicker(
                  context,
                  'Date',
                  state.fromDate,
                  (date) => context.read<LeaveApplicationBloc>().add(
                    LeaveDatesChanged(date, date),
                  ),
                )
              else
                Row(
                  children: [
                    Expanded(
                      child: _datePicker(
                        context,
                        'From',
                        state.fromDate,
                        (date) => context.read<LeaveApplicationBloc>().add(
                          LeaveDatesChanged(date, state.toDate),
                        ),
                      ),
                    ),
                    SizedBox(width: 12.w),
                    Expanded(
                      child: _datePicker(
                        context,
                        'To',
                        state.toDate,
                        (date) => context.read<LeaveApplicationBloc>().add(
                          LeaveDatesChanged(state.fromDate, date),
                        ),
                      ),
                    ),
                  ],
                ),
              SizedBox(height: 12.h),
              CheckboxListTile(
                value: state.halfDay,
                onChanged: (value) => context.read<LeaveApplicationBloc>().add(
                  LeaveHalfDayToggled(value ?? false),
                ),
                title: const Text('Half Day'),
                contentPadding: EdgeInsets.zero,
              ),
              if (state.halfDay) ...[
                SizedBox(height: 4.h),
                Text(
                  'Select Half',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                SizedBox(height: 8.h),
                SegmentedButton<HalfDaySession>(
                  segments: HalfDaySession.values
                      .map(
                        (session) => ButtonSegment<HalfDaySession>(
                          value: session,
                          label: Text(session.label),
                          icon: Icon(
                            session == HalfDaySession.firstHalf
                                ? Icons.wb_twilight
                                : Icons.wb_sunny_outlined,
                          ),
                        ),
                      )
                      .toList(),
                  selected: <HalfDaySession>{
                    state.halfDaySession ?? HalfDaySession.firstHalf,
                  },
                  showSelectedIcon: false,
                  onSelectionChanged: (selection) =>
                      context.read<LeaveApplicationBloc>().add(
                        LeaveHalfDaySessionChanged(selection.first),
                      ),
                ),
                SizedBox(height: 12.h),
              ],
              // Placeholder is the auto-generated reason for the selected
              // leave type; submitting with an empty box sends exactly that.
              TextFormField(
                key: ValueKey('leave-reason-${state.leaveType}'),
                decoration: InputDecoration(
                  labelText: 'Reason',
                  hintText: autoReasonFor(
                    state.leaveType,
                    leaveName: availableTypes
                        .where((b) => b.code == state.leaveType)
                        .map((b) => b.name)
                        .firstOrNull,
                  ),
                  helperText: state.reason.trim().isEmpty
                      ? 'Leave blank to use the suggested reason'
                      : null,
                  helperMaxLines: 2,
                ),
                minLines: 2,
                maxLines: 4,
                initialValue: state.reason,
                onChanged: (value) => context.read<LeaveApplicationBloc>().add(
                  LeaveReasonChanged(value),
                ),
              ),
              SizedBox(height: 24.h),
              AppButton(
                label: 'Submit Request',
                isLoading: state.status == LeaveApplicationStatus.submitting,
                onPressed: () => context.read<LeaveApplicationBloc>().add(
                  const LeaveSubmitted(),
                ),
              ),
            ],
          );
            },
          );
        },
      ),
    );
  }

  Widget _datePicker(
    BuildContext context,
    String label,
    DateTime date,
    ValueChanged<DateTime> onSelected,
  ) {
    return TextButton(
      onPressed: () async {
        final picked = await showDatePicker(
          context: context,
          initialDate: date,
          firstDate: DateTime(2020),
          lastDate: DateTime(2100),
        );
        if (picked != null) {
          onSelected(picked);
        }
      },
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: Theme.of(context).textTheme.bodySmall),
          SizedBox(height: 4.h),
          Text(
            DateFormatter.formatDate(date),
            style: Theme.of(context).textTheme.titleMedium,
          ),
        ],
      ),
    );
  }

}

class _LeaveStatusView extends StatelessWidget {
  const _LeaveStatusView();

  Color _statusColor(LeaveStatus status) {
    switch (status) {
      case LeaveStatus.approved:
        return Colors.green;
      case LeaveStatus.rejected:
        return Colors.red;
      default:
        return Colors.orange;
    }
  }

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) =>
          getIt<LeaveStatusBloc>()..add(const LeaveStatusRequested()),
      child: BlocBuilder<LeaveStatusBloc, LeaveStatusState>(
        buildWhen: (previous, current) {
          return previous.status != current.status ||
              previous.requests != current.requests;
        },
        builder: (context, state) {
          if (state.status == LeaveStatusEnum.loading) {
            return const LoadingIndicator();
          }
          if (state.requests.isEmpty) {
            return const Center(child: Text('No leave requests found'));
          }
          return ListView.separated(
            padding: EdgeInsets.all(16.w),
            itemCount: state.requests.length,
            separatorBuilder: (_, __) => SizedBox(height: 12.h),
            itemBuilder: (context, index) {
              final request = state.requests[index];
              return AppCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(
                            '${request.type}${request.halfDay ? ' (Half Day'
                                '${request.halfDaySession != null ? ' - ${request.halfDaySession!.label}' : ''})' : ''}',
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                        ),
                        StatusBadge(
                          label: request.status.name.toUpperCase(),
                          color: _statusColor(request.status),
                        ),
                      ],
                    ),
                    SizedBox(height: 8.h),
                    Text(
                      '${DateFormatter.formatDate(request.fromDate)} - ${DateFormatter.formatDate(request.toDate)}',
                    ),
                    SizedBox(height: 8.h),
                    Text(request.reason),
                    if (request.approverComment != null) ...[
                      SizedBox(height: 6.h),
                      Text('Approver: ${request.approverComment}'),
                    ],
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }
}
