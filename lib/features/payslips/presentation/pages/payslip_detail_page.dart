import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_file_dialog/flutter_file_dialog.dart';
import 'package:flutter_pdfview/flutter_pdfview.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:path/path.dart' as p;
import 'package:share_plus/share_plus.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../di/service_locator.dart';
import '../../domain/entities/payslip_summary.dart';
import '../../domain/payslip_exception.dart';
import '../cubit/payslip_detail_cubit.dart';
import '../payslip_session.dart';

/// Shows the server-generated payslip PDF -- the same document HR prints from
/// the web (Payroll > Salary > Payslip). The layout is deliberately NOT
/// rebuilt in widgets, so it can never drift from the web version.
class PayslipDetailPage extends StatelessWidget {
  const PayslipDetailPage({super.key, required this.item});

  /// The list row that was tapped. Only months the list endpoint returned
  /// can be opened.
  final PayslipSummary item;

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => PayslipDetailCubit(getIt(), item.period)..load(),
      child: _PayslipDetailView(item: item),
    );
  }
}

class _PayslipDetailView extends StatefulWidget {
  const _PayslipDetailView({required this.item});

  final PayslipSummary item;

  @override
  State<_PayslipDetailView> createState() => _PayslipDetailViewState();
}

class _PayslipDetailViewState extends State<_PayslipDetailView> {
  bool _busy = false;

  Rect? _originOf(BuildContext buttonContext) {
    // Required by the iPad share popover; harmless elsewhere.
    final box = buttonContext.findRenderObject() as RenderBox?;
    if (box == null || !box.hasSize) return null;
    return box.localToGlobal(Offset.zero) & box.size;
  }

  Future<void> _share(BuildContext buttonContext, File file) async {
    final origin = _originOf(buttonContext);
    await Share.shareXFiles(
      [XFile(file.path, mimeType: 'application/pdf')],
      subject: 'Payslip ${widget.item.label}',
      sharePositionOrigin: origin,
    );
  }

  /// Android: the system "save as" dialog (Storage Access Framework), which
  /// defaults to Downloads. iOS: the share sheet, whose "Save to Files" is the
  /// platform's way to save a document.
  Future<void> _download(BuildContext buttonContext, File file) async {
    if (_busy) return;
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _busy = true);
    try {
      if (Platform.isIOS) {
        final result = await Share.shareXFiles(
          [XFile(file.path, mimeType: 'application/pdf')],
          subject: 'Payslip ${widget.item.label}',
          sharePositionOrigin: _originOf(buttonContext),
        );
        if (result.status == ShareResultStatus.success) {
          final toFiles = result.raw.contains('SaveToFiles');
          messenger.showSnackBar(
            SnackBar(
              content: Text(
                toFiles ? 'Payslip saved to Files' : 'Payslip exported',
              ),
            ),
          );
        }
        return;
      }

      final saved = await FlutterFileDialog.saveFile(
        params: SaveFileDialogParams(
          sourceFilePath: file.path,
          fileName: p.basename(file.path),
          mimeTypesFilter: const ['application/pdf'],
        ),
      );
      if (saved != null) {
        messenger.showSnackBar(
          SnackBar(content: Text('Saved ${p.basename(file.path)}')),
        );
      }
    } catch (e) {
      debugPrint('[Payslips] Save failed: ${e.runtimeType}');
      messenger.showSnackBar(
        const SnackBar(
          content: Text('Could not save the payslip. Please try again.'),
          backgroundColor: AppColors.error,
        ),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return BlocConsumer<PayslipDetailCubit, PayslipDetailState>(
      listenWhen: (previous, current) =>
          current.error?.kind == PayslipErrorKind.session &&
          previous.error?.kind != PayslipErrorKind.session,
      listener: (context, state) => PayslipSession.expire(context),
      builder: (context, state) {
        final file = state.status == PayslipDetailStatus.ready
            ? state.file
            : null;

        return Scaffold(
          backgroundColor: isDark
              ? const Color(0xFF121212)
              : AppColors.backgroundPurple,
          appBar: AppBar(
            elevation: 0,
            backgroundColor: isDark ? const Color(0xFF1E1E1E) : Colors.white,
            title: Text(widget.item.label),
            actions: [
              Builder(
                builder: (buttonContext) => IconButton(
                  tooltip: 'Download',
                  icon: const Icon(Icons.download_rounded),
                  onPressed: file == null || _busy
                      ? null
                      : () => _download(buttonContext, file),
                ),
              ),
              Builder(
                builder: (buttonContext) => IconButton(
                  tooltip: 'Share',
                  icon: const Icon(Icons.share_rounded),
                  onPressed: file == null
                      ? null
                      : () => _share(buttonContext, file),
                ),
              ),
            ],
          ),
          body: Column(
            children: [
              _SummaryCard(item: widget.item),
              Expanded(child: _buildBody(context, state)),
            ],
          ),
        );
      },
    );
  }

  Widget _buildBody(BuildContext context, PayslipDetailState state) {
    final cubit = context.read<PayslipDetailCubit>();

    switch (state.status) {
      case PayslipDetailStatus.loading:
        return Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const CircularProgressIndicator(),
              SizedBox(height: 16.h),
              Text('Preparing payslip…', style: TextStyle(fontSize: 14.sp)),
            ],
          ),
        );
      case PayslipDetailStatus.failure:
        final kind = state.error?.kind;
        return _ErrorView(
          message: state.error?.message ?? 'Payslip not available',
          // Nothing usable is cached after a failure, so always re-download.
          onRetry: kind == PayslipErrorKind.network
              ? () => cubit.load(forceRefresh: true)
              : null,
        );
      case PayslipDetailStatus.ready:
        final file = state.file!;
        return PDFView(
          key: ValueKey(file.path),
          filePath: file.path,
          enableSwipe: true,
          autoSpacing: true,
          pageFling: false,
          pageSnap: false,
          fitPolicy: FitPolicy.WIDTH,
          maxZoom: 5,
          onError: (_) => cubit.onRenderError(),
        );
    }
  }
}

/// Key figures from the tapped list row, readable without zooming the PDF.
class _SummaryCard extends StatelessWidget {
  const _SummaryCard({required this.item});

  final PayslipSummary item;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final primary = isDark ? AppColors.secondary : theme.primaryColor;

    Widget figure(String label, num value, Color color, {bool big = false}) {
      return Expanded(
        child: Column(
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: 11.sp,
                color: isDark ? Colors.white54 : AppColors.textSecondary,
              ),
            ),
            SizedBox(height: 2.h),
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                PayslipFormat.money(value),
                style: TextStyle(
                  fontSize: big ? 18.sp : 14.sp,
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      margin: EdgeInsets.fromLTRB(16.w, 12.h, 16.w, 12.h),
      padding: EdgeInsets.symmetric(vertical: 12.h, horizontal: 8.w),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
        borderRadius: BorderRadius.circular(16.r),
      ),
      child: Row(
        children: [
          figure('Net Payable', item.netPayable, primary, big: true),
          figure('Total Earning', item.totalEarning, AppColors.success),
          figure('Total Deduction', item.totalDeduction, AppColors.error),
        ],
      ),
    );
  }
}

class _ErrorView extends StatelessWidget {
  const _ErrorView({required this.message, this.onRetry});

  final String message;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Center(
      child: Padding(
        padding: EdgeInsets.all(24.w),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              onRetry == null
                  ? Icons.receipt_long_outlined
                  : Icons.cloud_off_rounded,
              size: 56.sp,
              color: Colors.grey.shade400,
            ),
            SizedBox(height: 12.h),
            Text(
              message,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 15.sp,
                color: isDark ? Colors.white70 : Colors.grey.shade700,
              ),
            ),
            if (onRetry != null) ...[
              SizedBox(height: 16.h),
              FilledButton.icon(
                onPressed: onRetry,
                icon: const Icon(Icons.refresh_rounded),
                label: const Text('Retry'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
