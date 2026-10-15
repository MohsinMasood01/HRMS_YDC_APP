import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:local_auth/local_auth.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/network/dio_client.dart';
import '../../../../core/services/biometric_service.dart';
import '../../../../core/services/secure_storage_service.dart';
import '../../../../di/service_locator.dart';
import '../../../../shared/widgets/loading_indicator.dart';
import '../../../authentication/data/datasources/auth_local_data_source.dart';
import '../../../face_verification/domain/repositories/face_verification_repository.dart';
import '../../../face_verification/presentation/bloc/face_verification_bloc.dart';
import '../../../face_verification/presentation/pages/face_enrollment_page.dart';
import '../../domain/entities/enhanced_profile_entity.dart';
import '../bloc/profile_bloc.dart';

/// Enhanced Profile Page with premium UI
///
/// Features:
/// - Personal information display
/// - Emergency contact management
/// - Day type calendar view
/// - Contact editing
/// - Biometric account linking
class EnhancedProfilePage extends StatefulWidget {
  const EnhancedProfilePage({super.key});

  @override
  State<EnhancedProfilePage> createState() => _EnhancedProfilePageState();
}

class _EnhancedProfilePageState extends State<EnhancedProfilePage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _emergencyNameController = TextEditingController();
  final _emergencyPhoneController = TextEditingController();
  final _emergencyRelationController = TextEditingController();
  final _oldPasswordController = TextEditingController();
  final _newPasswordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final _oldPasswordFocusNode = FocusNode();
  final _newPasswordFocusNode = FocusNode();
  final _confirmPasswordFocusNode = FocusNode();
  bool _obscureOldPassword = true;
  bool _obscureNewPassword = true;
  bool _obscureConfirmPassword = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _emergencyNameController.dispose();
    _emergencyPhoneController.dispose();
    _emergencyRelationController.dispose();
    _oldPasswordController.dispose();
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    _oldPasswordFocusNode.dispose();
    _newPasswordFocusNode.dispose();
    _confirmPasswordFocusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => getIt<ProfileBloc>()..add(const ProfileRequested()),
      child: BlocConsumer<ProfileBloc, ProfileState>(
        listener: (context, state) {
          if (state.profile != null) {
            _emailController.text = state.profile!.email;
            _phoneController.text = state.profile!.phoneNumber;
          }

          if (state.status == ProfileStatus.success) {
            if (state.passwordChangeSuccess) {
              // Password change success
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: const Text('Password changed successfully'),
                  backgroundColor: AppColors.success,
                  behavior: SnackBarBehavior.floating,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10.r),
                  ),
                  duration: const Duration(seconds: 3),
                ),
              );
              // Clear password fields
              _oldPasswordController.clear();
              _newPasswordController.clear();
              _confirmPasswordController.clear();
              // Show WhatsApp notification message
              final whatsappMessenger = ScaffoldMessenger.of(context);
              Future.delayed(const Duration(seconds: 1), () {
                if (mounted) {
                  whatsappMessenger.showSnackBar(
                    SnackBar(
                      content: Text(
                        'WhatsApp notification sent to your registered phone number.',
                      ),
                      backgroundColor: AppColors.info,
                      behavior: SnackBarBehavior.floating,
                      duration: const Duration(seconds: 4),
                    ),
                  );
                }
              });
            } else {
              // Profile update success
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: const Text('Profile updated successfully'),
                  backgroundColor: AppColors.success,
                  behavior: SnackBarBehavior.floating,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10.r),
                  ),
                ),
              );
            }
          }
        },
        builder: (context, state) {
          if (state.status == ProfileStatus.loading && state.profile == null) {
            return const LoadingIndicator();
          }

          return _buildContent(context, state);
        },
      ),
    );
  }

  Widget _buildContent(BuildContext context, ProfileState state) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    // CRITICAL: Only use profile from API - NO cached data fallback
    // This ensures we always show the current logged-in user's data
    if (state.profile == null) {
      // If profile is null, show loading or error
      if (state.status == ProfileStatus.failure) {
        return Center(
          child: Padding(
            padding: EdgeInsets.all(24.w),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.error_outline, size: 64.sp, color: Colors.red),
                SizedBox(height: 16.h),
                Text(
                  state.errorMessage ?? 'Failed to load profile',
                  style: TextStyle(fontSize: 16.sp),
                  textAlign: TextAlign.center,
                ),
                SizedBox(height: 24.h),
                ElevatedButton(
                  onPressed: () {
                    context.read<ProfileBloc>().add(const ProfileRequested());
                  },
                  child: const Text('Retry'),
                ),
              ],
            ),
          ),
        );
      }
      // Still loading
      return const LoadingIndicator();
    }

    final profile = state.profile!;

    return NestedScrollView(
      headerSliverBuilder: (context, innerBoxIsScrolled) => [
        SliverToBoxAdapter(
          child: _buildProfileHeader(context, profile, isDark),
        ),
        SliverPersistentHeader(
          delegate: _SliverAppBarDelegate(
            TabBar(
              controller: _tabController,
              labelColor: isDark ? AppColors.secondary : theme.primaryColor,
              unselectedLabelColor: isDark ? Colors.white54 : Colors.grey,
              indicatorColor: isDark ? AppColors.secondary : theme.primaryColor,
              indicatorWeight: 3,
              tabs: [
                Tab(text: 'Info', icon: Icon(Icons.person_outline, size: 20.sp)),
                Tab(
                  text: 'Schedule',
                  icon: Icon(Icons.calendar_today, size: 20.sp),
                ),
                Tab(text: 'Edit', icon: Icon(Icons.edit_outlined, size: 20.sp)),
              ],
            ),
            isDark: isDark,
          ),
          pinned: true,
        ),
      ],
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildInfoTab(context, profile, isDark),
          _buildScheduleTab(context, profile, isDark),
          _buildEditTab(context, profile, state, isDark),
        ],
      ),
    );
  }

  Widget _buildProfileHeader(
    BuildContext context,
    EnhancedProfileEntity profile,
    bool isDark,
  ) {
    final theme = Theme.of(context);

    return Container(
      padding: EdgeInsets.all(20.w),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: isDark
              ? [const Color(0xFF1E1E1E), const Color(0xFF2D2D2D)]
              : [theme.primaryColor, theme.primaryColor.withValues(alpha: 0.8)],
        ),
      ),
      child: SafeArea(
        bottom: false,
        child: Column(
          children: [
            // Profile Avatar (No upload feature)
            Container(
              width: 100.w,
              height: 100.w,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 3),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.2),
                    blurRadius: 15,
                    spreadRadius: 2,
                  ),
                ],
              ),
              child:
                  profile.profilePictureUrl != null &&
                      profile.profilePictureUrl!.isNotEmpty
                  ? ClipOval(
                      child: CachedNetworkImage(
                        imageUrl: profile.profilePictureUrl!,
                        width: 100.w,
                        height: 100.w,
                        fit: BoxFit.cover,
                        placeholder: (context, url) => Container(
                          color: Colors.white,
                          child: Center(
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(
                                theme.primaryColor,
                              ),
                            ),
                          ),
                        ),
                        errorWidget: (context, url, error) => CircleAvatar(
                          radius: 50.w,
                          backgroundColor: Colors.white,
                          child: Text(
                            profile.initials,
                            style: TextStyle(
                              fontSize: 32.sp,
                              fontWeight: FontWeight.bold,
                              color: isDark
                                  ? AppColors.secondary
                                  : theme.primaryColor,
                            ),
                          ),
                        ),
                      ),
                    )
                  : CircleAvatar(
                      radius: 50.w,
                      backgroundColor: Colors.white,
                      child: Text(
                        profile.initials,
                        style: TextStyle(
                          fontSize: 32.sp,
                          fontWeight: FontWeight.bold,
                          color: isDark
                              ? AppColors.secondary
                              : theme.primaryColor,
                        ),
                      ),
                    ),
            ),

            SizedBox(height: 16.h),

            // Name
            Text(
              profile.name,
              style: TextStyle(
                fontSize: 24.sp,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
            ),

            SizedBox(height: 4.h),

            // Designation & Department
            Text(
              '${profile.designation} • ${profile.department}',
              style: TextStyle(
                fontSize: 14.sp,
                color: Colors.white.withValues(alpha: 0.9),
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
            ),

            SizedBox(height: 12.h),

            // Employee Code Badge
            Container(
              padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 6.h),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(20.r),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.badge_outlined, size: 16.sp, color: Colors.white),
                  SizedBox(width: 6.w),
                  Text(
                    profile.employeeCode,
                    style: TextStyle(
                      fontSize: 14.sp,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
            ),

            SizedBox(height: 20.h),

            // Quick Stats (wrap for small screens)
            Wrap(
              spacing: 12.w,
              runSpacing: 8.h,
              alignment: WrapAlignment.center,
              children: [
                _buildQuickStat(
                  'Experience',
                  profile.experienceFormatted,
                  Icons.work_history_outlined,
                ),
                _buildQuickStat(
                  'Gender',
                  profile.genderText,
                  profile.isMale ? Icons.male_rounded : Icons.female_rounded,
                ),
                _buildQuickStat(
                  'Branch',
                  profile.branch,
                  Icons.location_city_outlined,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuickStat(String label, String value, IconData icon) {
    return Column(
      children: [
        Container(
          padding: EdgeInsets.all(10.w),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.2),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: Colors.white, size: 22.sp),
        ),
        SizedBox(height: 6.h),
        Text(
          value,
          style: TextStyle(
            fontSize: 14.sp,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        Text(
          label,
          style: TextStyle(
            fontSize: 11.sp,
            color: Colors.white.withValues(alpha: 0.8),
          ),
        ),
      ],
    );
  }

  Widget _buildInfoTab(
    BuildContext context,
    EnhancedProfileEntity profile,
    bool isDark,
  ) {
    return ListView(
      padding: EdgeInsets.all(16.w),
      children: [
        // Personal Information
        _buildSection(
          context,
          title: 'Personal Information',
          icon: Icons.person_outline,
          isDark: isDark,
          children: [
            if (profile.fatherName != null && profile.fatherName!.isNotEmpty)
              _buildInfoRow(
                'Father Name',
                profile.fatherName!,
                Icons.family_restroom_outlined,
                isDark,
              ),
            _buildInfoRow('Email', profile.email, Icons.email_outlined, isDark),
            _buildInfoRow(
              'Phone',
              profile.phoneNumber,
              Icons.phone_outlined,
              isDark,
            ),
            _buildInfoRow(
              'Date of Birth',
              _formatDate(profile.dateOfBirth),
              Icons.cake_outlined,
              isDark,
            ),
            _buildInfoRow(
              'Gender',
              profile.genderText,
              profile.isMale ? Icons.male_rounded : Icons.female_rounded,
              isDark,
            ),
            if (profile.nicNo != null && profile.nicNo!.isNotEmpty)
              _buildInfoRow(
                'NIC Number',
                profile.nicNo!,
                Icons.badge_outlined,
                isDark,
              ),
            if (profile.eobiNo != null && profile.eobiNo!.isNotEmpty)
              _buildInfoRow(
                'EOBI Number',
                profile.eobiNo!,
                Icons.account_box_outlined,
                isDark,
              ),
            if (profile.uicCardNo != null && profile.uicCardNo!.isNotEmpty)
              _buildInfoRow(
                'UIC Card Number',
                profile.uicCardNo!,
                Icons.credit_card_outlined,
                isDark,
              ),
          ],
        ),

        SizedBox(height: 16.h),

        // Work Information
        _buildSection(
          context,
          title: 'Work Information',
          icon: Icons.work_outline,
          isDark: isDark,
          children: [
            _buildInfoRow(
              'Employee Code',
              _orValue(profile.employeeCode),
              Icons.badge_outlined,
              isDark,
            ),
            _buildInfoRow(
              'Joining Date',
              _formatDate(profile.joiningDate),
              Icons.event_outlined,
              isDark,
            ),
            // Always rendered: hiding the row when the backend omits the date
            // made it look like the field did not exist.
            _buildInfoRow(
              'Confirmation Date',
              _formatDate(_orValue(profile.confirmationDate)),
              Icons.check_circle_outline,
              isDark,
            ),
            _buildInfoRow(
              'Designation',
              profile.designation,
              Icons.work_outline,
              isDark,
            ),
            _buildInfoRow(
              'Department',
              profile.department,
              Icons.business_outlined,
              isDark,
            ),
            _buildInfoRow(
              'Cadre',
              profile.cadre,
              Icons.category_outlined,
              isDark,
            ),
            if (profile.salary != null)
              _buildInfoRow(
                'Salary',
                'PKR ${profile.salary!.toStringAsFixed(0)}',
                Icons.attach_money_outlined,
                isDark,
              ),
            if (profile.managerAboveSts != null &&
                profile.managerAboveSts!.isNotEmpty)
              _buildInfoRow(
                'Manager Above Status',
                profile.managerAboveSts!,
                Icons.admin_panel_settings_outlined,
                isDark,
              ),
            if (profile.companyAccommodation != null &&
                profile.companyAccommodation!.isNotEmpty)
              _buildInfoRow(
                'Company Accommodation',
                profile.companyAccommodation!,
                Icons.home_outlined,
                isDark,
              ),
          ],
        ),

        SizedBox(height: 16.h),

        // Organization Information
        _buildSection(
          context,
          title: 'Organization Information',
          icon: Icons.business_outlined,
          isDark: isDark,
          // Always render every organization row. Hiding a row when the
          // backend omits the value made the whole section look empty; a
          // dash makes the gap visible instead.
          children: [
            _buildInfoRow(
              'Company',
              _orValue(profile.compcnm),
              Icons.business_outlined,
              isDark,
            ),
            _buildInfoRow(
              'Department',
              _orValue(profile.department),
              Icons.apartment_outlined,
              isDark,
            ),
            _buildInfoRow(
              'Branch',
              _orValue(profile.branch),
              Icons.location_on_outlined,
              isDark,
            ),
            _buildInfoRow(
              'Location',
              _orValue(profile.location),
              Icons.place_outlined,
              isDark,
            ),
            _buildInfoRow(
              'Card Number',
              _orValue(profile.cardNumber),
              Icons.credit_card_outlined,
              isDark,
            ),
          ],
        ),

        SizedBox(height: 16.h),

        // Emergency Contact
        _buildSection(
          context,
          title: 'Emergency Contact',
          icon: Icons.emergency_outlined,
          isDark: isDark,
          children: profile.emergencyContact != null
              ? [
                  _buildInfoRow(
                    'Name',
                    profile.emergencyContact!.name,
                    Icons.person_outline,
                    isDark,
                  ),
                  _buildInfoRow(
                    'Relationship',
                    profile.emergencyContact!.relationship,
                    Icons.family_restroom_outlined,
                    isDark,
                  ),
                  _buildInfoRow(
                    'Phone',
                    profile.emergencyContact!.phoneNumber,
                    Icons.phone_outlined,
                    isDark,
                  ),
                ]
              : [
                  Padding(
                    padding: EdgeInsets.all(16.w),
                    child: Text(
                      'No emergency contact added. Tap Edit to add one.',
                      style: TextStyle(
                        color: isDark
                            ? Colors.white54
                            : AppColors.textSecondary,
                      ),
                    ),
                  ),
                ],
        ),

        SizedBox(height: 16.h),

        // Reporting Manager
        if (profile.reportingTo != null)
          _buildSection(
            context,
            title: 'Reporting To',
            icon: Icons.supervisor_account_outlined,
            isDark: isDark,
            children: [
              _buildInfoRow(
                'HOD Name',
                profile.reportingTo!.name,
                Icons.person_outline,
                isDark,
              ),
              if (profile.reportingTo!.phoneNumber != null &&
                  profile.reportingTo!.phoneNumber!.isNotEmpty &&
                  profile.reportingTo!.phoneNumber != '-')
                _buildInfoRow(
                  'HOD Phone Number',
                  profile.reportingTo!.phoneNumber!,
                  Icons.phone_outlined,
                  isDark,
                ),
            ],
          ),

        SizedBox(height: 16.h),

        // Face Verification Section
        _buildFaceVerificationSection(context, isDark),

        SizedBox(height: 16.h),

        // HR Admin Section (only if HR_ADMIN = 'Y')
        _buildHrAdminSection(context, isDark),

        SizedBox(height: 80.h),
      ],
    );
  }

  Widget _buildFaceVerificationSection(BuildContext context, bool isDark) {
    final theme = Theme.of(context);
    final faceBloc = getIt<FaceVerificationBloc>();
    // Initialize if not already initialized
    if (faceBloc.state.status == FaceVerificationStatus.initial) {
      faceBloc.add(const FaceVerificationInitialized());
    }

    return BlocBuilder<FaceVerificationBloc, FaceVerificationState>(
      bloc: faceBloc,
      builder: (context, faceState) {
        final hasEnrolled = faceState.hasEnrolledFace;

        return _buildSection(
          context,
          title: 'Face Verification',
          icon: Icons.face_outlined,
          isDark: isDark,
          children: [
            Container(
              padding: EdgeInsets.all(16.w),
              decoration: BoxDecoration(
                color: isDark
                    ? Colors.white.withValues(alpha: 0.05)
                    : Colors.grey.shade50,
                borderRadius: BorderRadius.circular(12.r),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        hasEnrolled ? Icons.check_circle : Icons.info_outline,
                        color: hasEnrolled
                            ? AppColors.success
                            : (isDark
                                  ? AppColors.secondary
                                  : theme.primaryColor),
                        size: 20.sp,
                      ),
                      SizedBox(width: 12.w),
                      Expanded(
                        child: Text(
                          hasEnrolled
                              ? 'Face enrolled for attendance verification'
                              : 'Enroll your face for attendance verification',
                          style: TextStyle(
                            fontSize: 14.sp,
                            fontWeight: FontWeight.w600,
                            color: isDark
                                ? Colors.white
                                : AppColors.textPrimary,
                          ),
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 16.h),
                  Row(
                    children: [
                      if (!hasEnrolled)
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: () async {
                              final navigator = Navigator.of(context);
                              final result = await navigator.push<bool>(
                                MaterialPageRoute(
                                  builder: (_) => const FaceEnrollmentPage(),
                                ),
                              );
                              if (result == true) {
                                if (!mounted) return;
                                faceBloc.add(
                                  const FaceVerificationInitialized(),
                                );
                              }
                            },
                            icon: Icon(Icons.add_circle_outline, size: 18.sp),
                            label: const Text('Enroll Face'),
                            style: ElevatedButton.styleFrom(
                              padding: EdgeInsets.symmetric(vertical: 12.h),
                              backgroundColor: isDark
                                  ? AppColors.secondary
                                  : theme.primaryColor,
                              foregroundColor: Colors.white,
                            ),
                          ),
                        ),
                      if (hasEnrolled) ...[
                        Expanded(
                          flex: 2,
                          child: ElevatedButton.icon(
                            onPressed: null,
                            icon: Icon(
                              Icons.check_circle,
                              size: 18.sp,
                            ),
                            label: const Text('Face Enrolled'),
                            style: ElevatedButton.styleFrom(
                              padding: EdgeInsets.symmetric(vertical: 12.h),
                              backgroundColor: AppColors.success,
                              disabledBackgroundColor:
                                  AppColors.success.withValues(alpha: 0.6),
                              disabledForegroundColor: Colors.white,
                            ),
                          ),
                        ),
                        SizedBox(width: 12.w),
                        Expanded(
                          flex: 1,
                          child: ElevatedButton.icon(
                          onPressed: () async {
                            final messenger = ScaffoldMessenger.of(context);
                            final confirmed = await showDialog<bool>(
                              context: context,
                              builder: (context) => AlertDialog(
                                title: const Text('Delete Face Enrollment?'),
                                content: const Text(
                                  'This will remove your enrolled face data. '
                                  'You will need to enroll again to use face verification.',
                                ),
                                actions: [
                                  TextButton(
                                    onPressed: () =>
                                        Navigator.pop(context, false),
                                    child: const Text('Cancel'),
                                  ),
                                  ElevatedButton(
                                    onPressed: () =>
                                        Navigator.pop(context, true),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: AppColors.error,
                                    ),
                                    child: const Text('Delete'),
                                  ),
                                ],
                              ),
                            );

                            if (confirmed == true) {
                              if (!mounted) return;
                              final repository =
                                  getIt<FaceVerificationRepository>();
                              final secureStorage =
                                  getIt<SecureStorageService>();
                              final cardNo1 =
                                  await secureStorage.read('card_no1') ?? '';

                              if (cardNo1.isNotEmpty) {
                                await repository.deleteEnrolledFace(cardNo1);
                              }

                              if (!mounted) return;
                              faceBloc.add(const FaceVerificationInitialized());

                              if (!mounted) return;
                              messenger.showSnackBar(
                                SnackBar(
                                  content: const Text(
                                    'Face enrollment deleted',
                                  ),
                                  backgroundColor: AppColors.success,
                                  duration: const Duration(seconds: 2),
                                ),
                              );
                            }
                          },
                          icon: Icon(Icons.delete_outline, size: 18.sp),
                          label: const Text('Delete'),
                          style: ElevatedButton.styleFrom(
                            padding: EdgeInsets.symmetric(
                              vertical: 12.h,
                              horizontal: 16.w,
                            ),
                            backgroundColor: AppColors.error,
                            foregroundColor: Colors.white,
                          ),
                        ),
                        ),
                      ],
                    ],
                  ),
                  SizedBox(height: 8.h),
                  Text(
                    'Face verification uses on-device processing. '
                    'Only numeric face embeddings are stored, not images.',
                    style: TextStyle(
                      fontSize: 11.sp,
                      color: isDark ? Colors.white54 : AppColors.textSecondary,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildHrAdminSection(BuildContext context, bool isDark) {
    final theme = Theme.of(context);
    final secureStorage = getIt<SecureStorageService>();

    return FutureBuilder<String?>(
      future: secureStorage.read('hr_admin'),
      builder: (context, snapshot) {
        final hrAdmin = snapshot.data;
        if (hrAdmin != 'Y') return const SizedBox.shrink();

        return _buildSection(
          context,
          title: 'HR Admin',
          icon: Icons.admin_panel_settings_outlined,
          isDark: isDark,
          children: [
            Container(
              padding: EdgeInsets.all(16.w),
              decoration: BoxDecoration(
                color: isDark
                    ? Colors.white.withValues(alpha: 0.05)
                    : Colors.grey.shade50,
                borderRadius: BorderRadius.circular(12.r),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.how_to_reg_rounded,
                        color: isDark
                            ? AppColors.secondary
                            : theme.primaryColor,
                        size: 20.sp,
                      ),
                      SizedBox(width: 12.w),
                      Expanded(
                        child: Text(
                          'Register face for other employees',
                          style: TextStyle(
                            fontSize: 14.sp,
                            fontWeight: FontWeight.w500,
                            color: isDark
                                ? Colors.white
                                : AppColors.textPrimary,
                          ),
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 8.h),
                  Text(
                    'Enter an employee\'s mobile number to enroll their face for attendance verification.',
                    style: TextStyle(
                      fontSize: 12.sp,
                      color: isDark ? Colors.white54 : AppColors.textSecondary,
                    ),
                  ),
                  SizedBox(height: 16.h),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: () => _showHrFaceEnrollDialog(context, isDark),
                      icon: const Icon(Icons.person_add_alt_1_rounded),
                      label: const Text('Register Employee Face'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: isDark
                            ? AppColors.secondary
                            : theme.primaryColor,
                        foregroundColor: Colors.white,
                        padding: EdgeInsets.symmetric(vertical: 14.h),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12.r),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }

  void _showHrFaceEnrollDialog(BuildContext context, bool isDark) {
    final phoneController = TextEditingController();
    final theme = Theme.of(context);

    showDialog(
      context: context,
      builder: (dialogContext) {
        bool isLoading = false;
        String? errorText;
        // Employee details after lookup
        String? foundCardNo;
        String? foundEmpName;
        String? foundEmpCode;

        return StatefulBuilder(
          builder: (ctx, setDialogState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16.r),
              ),
              title: Row(
                children: [
                  Icon(
                    Icons.person_search_rounded,
                    color: isDark ? AppColors.secondary : theme.primaryColor,
                  ),
                  SizedBox(width: 8.w),
                  const Text('Find Employee'),
                ],
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: phoneController,
                    keyboardType: TextInputType.phone,
                    decoration: InputDecoration(
                      labelText: 'Mobile Number / Employee Code',
                      hintText: 'Enter phone number or code',
                      prefixIcon: const Icon(Icons.phone_outlined),
                      errorText: errorText,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12.r),
                      ),
                    ),
                  ),
                  // Show employee details after successful lookup
                  if (foundCardNo != null) ...[
                    SizedBox(height: 16.h),
                    Container(
                      width: double.infinity,
                      padding: EdgeInsets.all(12.w),
                      decoration: BoxDecoration(
                        color: (isDark
                                ? AppColors.secondary
                                : theme.primaryColor)
                            .withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(12.r),
                        border: Border.all(
                          color: (isDark
                                  ? AppColors.secondary
                                  : theme.primaryColor)
                              .withValues(alpha: 0.3),
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(
                                Icons.check_circle_rounded,
                                color: AppColors.success,
                                size: 20.sp,
                              ),
                              SizedBox(width: 8.w),
                              Text(
                                'Employee Found',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14.sp,
                                  color: AppColors.success,
                                ),
                              ),
                            ],
                          ),
                          SizedBox(height: 8.h),
                          if (foundEmpName != null &&
                              foundEmpName!.isNotEmpty) ...[
                            _buildDetailRow(
                                'Name', foundEmpName!, isDark, theme),
                            SizedBox(height: 4.h),
                          ],
                          if (foundEmpCode != null &&
                              foundEmpCode!.isNotEmpty) ...[
                            _buildDetailRow(
                                'Code', foundEmpCode!, isDark, theme),
                            SizedBox(height: 4.h),
                          ],
                          _buildDetailRow(
                              'Card No', foundCardNo!, isDark, theme),
                        ],
                      ),
                    ),
                  ],
                  if (isLoading) ...[
                    SizedBox(height: 16.h),
                    const CircularProgressIndicator(),
                  ],
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogContext),
                  child: const Text('Cancel'),
                ),
                if (foundCardNo != null)
                  ElevatedButton.icon(
                    onPressed: () {
                      Navigator.pop(dialogContext);
                      if (!context.mounted) return;
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => FaceEnrollmentPage(
                            overrideCardNo: foundCardNo!,
                          ),
                        ),
                      );
                    },
                    icon: Icon(Icons.face_rounded, size: 18.sp),
                    label: const Text('Register Face'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: isDark
                          ? AppColors.secondary
                          : theme.primaryColor,
                      foregroundColor: Colors.white,
                    ),
                  )
                else
                  ElevatedButton(
                    onPressed: isLoading
                        ? null
                        : () async {
                            final phone = phoneController.text.trim();
                            if (phone.isEmpty) {
                              setDialogState(() {
                                errorText = 'Please enter a phone number';
                              });
                              return;
                            }

                            setDialogState(() {
                              isLoading = true;
                              errorText = null;
                              foundCardNo = null;
                              foundEmpName = null;
                              foundEmpCode = null;
                            });

                            try {
                              final response = await DioClient.instance
                                  .get('/auth/lookup/$phone');
                              final cardNo =
                                  response.data['card_no']?.toString();
                              final empName =
                                  response.data['emp_name']?.toString();
                              final empCode =
                                  response.data['empcode']?.toString();

                              if (cardNo == null || cardNo.isEmpty) {
                                setDialogState(() {
                                  isLoading = false;
                                  errorText = 'Employee not found';
                                });
                                return;
                              }

                              setDialogState(() {
                                isLoading = false;
                                foundCardNo = cardNo;
                                foundEmpName = empName;
                                foundEmpCode = empCode;
                              });
                            } catch (e) {
                              setDialogState(() {
                                isLoading = false;
                                errorText = e.toString().contains('404')
                                    ? 'Employee not found'
                                    : 'Connection error';
                              });
                            }
                          },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: isDark
                          ? AppColors.secondary
                          : theme.primaryColor,
                      foregroundColor: Colors.white,
                    ),
                    child: const Text('Look Up'),
                  ),
              ],
            );
          },
        );
      },
    );
  }

  Widget _buildDetailRow(
      String label, String value, bool isDark, ThemeData theme) {
    return Row(
      children: [
        SizedBox(width: 28.w),
        SizedBox(
          width: 60.w,
          child: Text(
            '$label:',
            style: TextStyle(
              fontSize: 12.sp,
              color: isDark ? Colors.white54 : AppColors.textSecondary,
            ),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: TextStyle(
              fontSize: 13.sp,
              fontWeight: FontWeight.w500,
              color: isDark ? Colors.white : AppColors.textPrimary,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildScheduleTab(
    BuildContext context,
    EnhancedProfileEntity profile,
    bool isDark,
  ) {
    final theme = Theme.of(context);

    return ListView(
      padding: EdgeInsets.all(16.w),
      children: [
        // Day Types Legend
        _buildSection(
          context,
          title: 'Day Types',
          icon: Icons.legend_toggle_outlined,
          isDark: isDark,
          children: [
            Padding(
              padding: EdgeInsets.all(12.w),
              child: Wrap(
                spacing: 16.w,
                runSpacing: 12.h,
                children: [
                  _buildDayTypeLegend(
                    'G',
                    'General (Working)',
                    AppColors.success,
                    isDark,
                  ),
                  _buildDayTypeLegend(
                    'R',
                    'Rest (Weekly Off)',
                    Colors.orange,
                    isDark,
                  ),
                ],
              ),
            ),
          ],
        ),

        SizedBox(height: 16.h),

        // Weekly Schedule
        _buildSection(
          context,
          title: 'Weekly Schedule',
          icon: Icons.calendar_view_week_outlined,
          isDark: isDark,
          children: [
            Padding(
              padding: EdgeInsets.all(12.w),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun']
                    .asMap()
                    .entries
                    .map((entry) {
                      final dayIndex = entry.key + 1; // 1-7 for Monday-Sunday
                      final dayType = profile.getDayType(
                        DateTime.now().subtract(
                          Duration(days: DateTime.now().weekday - dayIndex),
                        ),
                      );

                      return _buildDayCircle(
                        entry.value,
                        dayType,
                        theme,
                        isDark,
                      );
                    })
                    .toList(),
              ),
            ),
          ],
        ),

        SizedBox(height: 16.h),

        // Shift Timings
        if (profile.workSchedule != null)
          _buildSection(
            context,
            title: 'Shift Timings',
            icon: Icons.access_time_outlined,
            isDark: isDark,
            children: [
              _buildInfoRow(
                'Start Time',
                profile.workSchedule!.shiftStartTime ?? '09:30 AM',
                Icons.login_outlined,
                isDark,
              ),
              _buildInfoRow(
                'End Time',
                profile.workSchedule!.shiftEndTime ?? '06:00 PM',
                Icons.logout_outlined,
                isDark,
              ),
              _buildInfoRow(
                'Grace Period',
                '${profile.workSchedule!.graceMinutes} minutes',
                Icons.timer_outlined,
                isDark,
              ),
            ],
          ),

        SizedBox(height: 80.h),
      ],
    );
  }

  Widget _buildEditTab(
    BuildContext context,
    EnhancedProfileEntity profile,
    ProfileState state,
    bool isDark,
  ) {
    final theme = Theme.of(context);

    return ListView(
      padding: EdgeInsets.all(16.w),
      children: [
        // Contact Information (Read-only)
        _buildSection(
          context,
          title: 'Contact Information',
          icon: Icons.contact_mail_outlined,
          isDark: isDark,
          children: [
            Padding(
              padding: EdgeInsets.all(16.w),
              child: Column(
                children: [
                  // Email - Read-only
                  Container(
                    padding: EdgeInsets.symmetric(
                      horizontal: 16.w,
                      vertical: 12.h,
                    ),
                    decoration: BoxDecoration(
                      color: isDark
                          ? Colors.white.withValues(alpha: 0.05)
                          : Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(12.r),
                      border: Border.all(
                        color: isDark ? Colors.white12 : Colors.grey.shade300,
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.email_outlined,
                          color: isDark
                              ? Colors.white54
                              : AppColors.textSecondary,
                          size: 20.sp,
                        ),
                        SizedBox(width: 12.w),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Email',
                                style: TextStyle(
                                  fontSize: 11.sp,
                                  color: isDark
                                      ? Colors.white54
                                      : AppColors.textSecondary,
                                ),
                              ),
                              SizedBox(height: 2.h),
                              Text(
                                profile.email.isNotEmpty && profile.email != '-'
                                    ? profile.email
                                    : 'Not provided',
                                style: TextStyle(
                                  fontSize: 14.sp,
                                  fontWeight: FontWeight.w500,
                                  color: isDark
                                      ? Colors.white
                                      : AppColors.textPrimary,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Icon(
                          Icons.lock_outline,
                          size: 16.sp,
                          color: isDark
                              ? Colors.white38
                              : AppColors.textSecondary,
                        ),
                      ],
                    ),
                  ),
                  SizedBox(height: 16.h),
                  // Phone - Read-only
                  Container(
                    padding: EdgeInsets.symmetric(
                      horizontal: 16.w,
                      vertical: 12.h,
                    ),
                    decoration: BoxDecoration(
                      color: isDark
                          ? Colors.white.withValues(alpha: 0.05)
                          : Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(12.r),
                      border: Border.all(
                        color: isDark ? Colors.white12 : Colors.grey.shade300,
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.phone_outlined,
                          color: isDark
                              ? Colors.white54
                              : AppColors.textSecondary,
                          size: 20.sp,
                        ),
                        SizedBox(width: 12.w),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Phone Number',
                                style: TextStyle(
                                  fontSize: 11.sp,
                                  color: isDark
                                      ? Colors.white54
                                      : AppColors.textSecondary,
                                ),
                              ),
                              SizedBox(height: 2.h),
                              Text(
                                profile.phoneNumber.isNotEmpty &&
                                        profile.phoneNumber != '-'
                                    ? profile.phoneNumber
                                    : 'Not provided',
                                style: TextStyle(
                                  fontSize: 14.sp,
                                  fontWeight: FontWeight.w500,
                                  color: isDark
                                      ? Colors.white
                                      : AppColors.textPrimary,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Icon(
                          Icons.lock_outline,
                          size: 16.sp,
                          color: isDark
                              ? Colors.white38
                              : AppColors.textSecondary,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),

        SizedBox(height: 16.h),

        // Emergency Contact
        _buildSection(
          context,
          title: 'Emergency Contact',
          icon: Icons.emergency_outlined,
          isDark: isDark,
          children: [
            Padding(
              padding: EdgeInsets.all(16.w),
              child: Column(
                children: [
                  _buildTextField(
                    controller: _emergencyNameController,
                    label: 'Contact Name',
                    icon: Icons.person_outline,
                    isDark: isDark,
                  ),
                  SizedBox(height: 16.h),
                  _buildTextField(
                    controller: _emergencyRelationController,
                    label: 'Relationship',
                    icon: Icons.family_restroom_outlined,
                    isDark: isDark,
                  ),
                  SizedBox(height: 16.h),
                  _buildTextField(
                    controller: _emergencyPhoneController,
                    label: 'Phone Number',
                    icon: Icons.phone_outlined,
                    keyboardType: TextInputType.phone,
                    isDark: isDark,
                  ),
                ],
              ),
            ),
          ],
        ),

        SizedBox(height: 16.h),

        // Change Password
        _buildSection(
          context,
          title: 'Change Password',
          icon: Icons.lock_outline,
          isDark: isDark,
          children: [
            Padding(
              padding: EdgeInsets.all(16.w),
              child: _buildChangePasswordSection(context, state, isDark),
            ),
          ],
        ),

        SizedBox(height: 16.h),

        // Biometric Account Linking
        _buildSection(
          context,
          title: 'Security & Biometric',
          icon: Icons.fingerprint_outlined,
          isDark: isDark,
          children: [
            Padding(
              padding: EdgeInsets.all(16.w),
              child: Column(
                children: [
                  FutureBuilder<bool>(
                    future: getIt<AuthLocalDataSource>().isBiometricEnabled(),
                    builder: (context, snapshot) {
                      final isEnabled = snapshot.data ?? false;
                      return Container(
                        padding: EdgeInsets.all(16.w),
                        decoration: BoxDecoration(
                          color: isEnabled
                              ? AppColors.success.withValues(alpha: 0.1)
                              : (isDark
                                    ? Colors.white.withValues(alpha: 0.05)
                                    : Colors.grey.shade100),
                          borderRadius: BorderRadius.circular(12.r),
                          border: Border.all(
                            color: isEnabled
                                ? AppColors.success
                                : (isDark
                                      ? Colors.white12
                                      : Colors.grey.shade300),
                          ),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              isEnabled
                                  ? Icons.fingerprint
                                  : Icons.fingerprint_outlined,
                              color: isEnabled
                                  ? AppColors.success
                                  : (isDark
                                        ? Colors.white54
                                        : AppColors.textSecondary),
                              size: 28.sp,
                            ),
                            SizedBox(width: 12.w),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    isEnabled
                                        ? 'Biometric Linked'
                                        : 'Link Biometric',
                                    style: TextStyle(
                                      fontSize: 15.sp,
                                      fontWeight: FontWeight.w600,
                                      color: isDark
                                          ? Colors.white
                                          : AppColors.textPrimary,
                                    ),
                                  ),
                                  SizedBox(height: 4.h),
                                  Text(
                                    isEnabled
                                        ? 'Your biometric is linked to your account'
                                        : 'Link fingerprint/face ID for quick login',
                                    style: TextStyle(
                                      fontSize: 12.sp,
                                      color: isDark
                                          ? Colors.white54
                                          : AppColors.textSecondary,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            IconButton(
                              onPressed: () =>
                                  _showBiometricLinkingDialog(context),
                              icon: Icon(
                                isEnabled
                                    ? Icons.settings
                                    : Icons.arrow_forward_ios,
                                size: 20.sp,
                                color: isDark
                                    ? AppColors.secondary
                                    : AppColors.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
          ],
        ),

        SizedBox(height: 24.h),

        // Save Button
        Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                theme.primaryColor,
                theme.primaryColor.withValues(alpha: 0.8),
              ],
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
              onTap: state.status == ProfileStatus.loading
                  ? null
                  : () => _saveProfile(context),
              borderRadius: BorderRadius.circular(16.r),
              child: Padding(
                padding: EdgeInsets.symmetric(vertical: 16.h),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    if (state.status == ProfileStatus.loading)
                      SizedBox(
                        width: 20.w,
                        height: 20.w,
                        child: const CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation(Colors.white),
                        ),
                      )
                    else
                      Icon(
                        Icons.save_outlined,
                        color: Colors.white,
                        size: 22.sp,
                      ),
                    SizedBox(width: 10.w),
                    Text(
                      state.status == ProfileStatus.loading
                          ? 'Saving...'
                          : 'Save Changes',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 16.sp,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),

        SizedBox(height: 80.h),
      ],
    );
  }

  Widget _buildSection(
    BuildContext context, {
    required String title,
    required IconData icon,
    required bool isDark,
    required List<Widget> children,
  }) {
    final theme = Theme.of(context);

    return Container(
      decoration: BoxDecoration(
        color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.white,
        borderRadius: BorderRadius.circular(16.r),
        border: Border.all(
          color: isDark ? Colors.white12 : Colors.grey.shade200,
        ),
        boxShadow: isDark
            ? null
            : [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.04),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: EdgeInsets.all(16.w),
            child: Row(
              children: [
                Container(
                  padding: EdgeInsets.all(8.w),
                  decoration: BoxDecoration(
                    color: (isDark ? AppColors.secondary : theme.primaryColor)
                        .withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10.r),
                  ),
                  child: Icon(
                    icon,
                    color: isDark ? AppColors.secondary : theme.primaryColor,
                    size: 20.sp,
                  ),
                ),
                SizedBox(width: 12.w),
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 16.sp,
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.white : AppColors.textPrimary,
                  ),
                ),
              ],
            ),
          ),
          Divider(
            height: 1,
            color: isDark ? Colors.white12 : Colors.grey.shade200,
          ),
          ...children,
        ],
      ),
    );
  }

  /// Displays '-' for values the backend did not send, so a row is never
  /// silently dropped from a section.
  static String _orValue(String? value) {
    final text = value?.trim() ?? '';
    return text.isEmpty || text.toLowerCase() == 'null' ? '-' : text;
  }

  Widget _buildInfoRow(String label, String value, IconData icon, bool isDark) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 12.h),
      child: Row(
        children: [
          Icon(
            icon,
            size: 20.sp,
            color: isDark ? AppColors.secondary : AppColors.textSecondary,
          ),
          SizedBox(width: 12.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 12.sp,
                    color: isDark
                        ? AppColors.secondary
                        : AppColors.textSecondary,
                  ),
                ),
                SizedBox(height: 2.h),
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 14.sp,
                    fontWeight: FontWeight.w500,
                    color: isDark ? Colors.white : AppColors.textPrimary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    required bool isDark,
    TextInputType? keyboardType,
    FocusNode? focusNode,
    bool obscureText = false,
    Widget? suffixIcon,
  }) {
    return TextField(
      controller: controller,
      focusNode: focusNode,
      keyboardType: keyboardType,
      obscureText: obscureText,
      style: TextStyle(color: isDark ? Colors.white : AppColors.textPrimary),
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(
          icon,
          size: 22.sp,
          color: isDark ? AppColors.secondary : Colors.grey.shade600,
        ),
        suffixIcon: suffixIcon,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12.r)),
        filled: true,
        fillColor: isDark
            ? Colors.white.withValues(alpha: 0.05)
            : Colors.grey.shade50,
      ),
    );
  }

  Widget _buildChangePasswordSection(
    BuildContext context,
    ProfileState state,
    bool isDark,
  ) {
    final theme = Theme.of(context);
    return Column(
      children: [
        _buildTextField(
          controller: _oldPasswordController,
          label: 'Old Password',
          icon: Icons.lock_outline,
          isDark: isDark,
          focusNode: _oldPasswordFocusNode,
          obscureText: _obscureOldPassword,
          suffixIcon: IconButton(
            icon: Icon(
              _obscureOldPassword ? Icons.visibility_off : Icons.visibility,
              color: isDark ? Colors.white54 : Colors.grey.shade600,
            ),
            onPressed: () {
              setState(() {
                _obscureOldPassword = !_obscureOldPassword;
              });
            },
          ),
        ),
        SizedBox(height: 16.h),
        _buildTextField(
          controller: _newPasswordController,
          label: 'New Password',
          icon: Icons.lock,
          isDark: isDark,
          focusNode: _newPasswordFocusNode,
          obscureText: _obscureNewPassword,
          suffixIcon: IconButton(
            icon: Icon(
              _obscureNewPassword ? Icons.visibility_off : Icons.visibility,
              color: isDark ? Colors.white54 : Colors.grey.shade600,
            ),
            onPressed: () {
              setState(() {
                _obscureNewPassword = !_obscureNewPassword;
              });
            },
          ),
        ),
        SizedBox(height: 16.h),
        _buildTextField(
          controller: _confirmPasswordController,
          label: 'Confirm New Password',
          icon: Icons.lock_outline,
          isDark: isDark,
          focusNode: _confirmPasswordFocusNode,
          obscureText: _obscureConfirmPassword,
          suffixIcon: IconButton(
            icon: Icon(
              _obscureConfirmPassword ? Icons.visibility_off : Icons.visibility,
              color: isDark ? Colors.white54 : Colors.grey.shade600,
            ),
            onPressed: () {
              setState(() {
                _obscureConfirmPassword = !_obscureConfirmPassword;
              });
            },
          ),
        ),
        SizedBox(height: 20.h),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: state.status == ProfileStatus.loading
                ? null
                : () => _handleChangePassword(context),
            icon: state.status == ProfileStatus.loading
                ? SizedBox(
                    width: 16.w,
                    height: 16.w,
                    child: const CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                  )
                : Icon(Icons.check_circle_outline, size: 20.sp),
            label: Text(
              state.status == ProfileStatus.loading
                  ? 'Changing Password...'
                  : 'Change Password',
              style: TextStyle(fontSize: 15.sp, fontWeight: FontWeight.w600),
            ),
            style: ElevatedButton.styleFrom(
              padding: EdgeInsets.symmetric(vertical: 14.h),
              backgroundColor: theme.primaryColor,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12.r),
              ),
            ),
          ),
        ),
        if (state.errorMessage != null &&
            state.status == ProfileStatus.failure) ...[
          SizedBox(height: 12.h),
          Container(
            padding: EdgeInsets.all(12.w),
            decoration: BoxDecoration(
              color: AppColors.error.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8.r),
              border: Border.all(color: AppColors.error.withValues(alpha: 0.3)),
            ),
            child: Row(
              children: [
                Icon(Icons.error_outline, color: AppColors.error, size: 20.sp),
                SizedBox(width: 8.w),
                Expanded(
                  child: Text(
                    state.errorMessage!,
                    style: TextStyle(color: AppColors.error, fontSize: 12.sp),
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  void _handleChangePassword(BuildContext context) {
    final oldPassword = _oldPasswordController.text.trim();
    final newPassword = _newPasswordController.text.trim();
    final confirmPassword = _confirmPasswordController.text.trim();

    // Validation
    if (oldPassword.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Please enter your old password'),
          backgroundColor: AppColors.error,
        ),
      );
      _oldPasswordFocusNode.requestFocus();
      return;
    }

    if (newPassword.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Please enter a new password'),
          backgroundColor: AppColors.error,
        ),
      );
      _newPasswordFocusNode.requestFocus();
      return;
    }

    if (newPassword.length < 6) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text(
            'New password must be at least 6 characters long',
          ),
          backgroundColor: AppColors.error,
        ),
      );
      _newPasswordFocusNode.requestFocus();
      return;
    }

    if (newPassword != confirmPassword) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('New passwords do not match'),
          backgroundColor: AppColors.error,
        ),
      );
      _confirmPasswordFocusNode.requestFocus();
      return;
    }

    if (oldPassword == newPassword) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text(
            'New password must be different from old password',
          ),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    // Trigger password change
    context.read<ProfileBloc>().add(
      PasswordChangeRequested(
        oldPassword: oldPassword,
        newPassword: newPassword,
      ),
    );
  }

  Widget _buildDayTypeLegend(
    String code,
    String label,
    Color color,
    bool isDark,
  ) {
    return Row(
      children: [
        Container(
          width: 28.w,
          height: 28.w,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.2),
            shape: BoxShape.circle,
            border: Border.all(color: color, width: 2),
          ),
          child: Center(
            child: Text(
              code,
              style: TextStyle(
                fontSize: 12.sp,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
          ),
        ),
        SizedBox(width: 8.w),
        Text(
          label,
          style: TextStyle(
            fontSize: 13.sp,
            color: isDark ? Colors.white70 : AppColors.textPrimary,
          ),
        ),
      ],
    );
  }

  Widget _buildDayCircle(
    String day,
    DayType dayType,
    ThemeData theme,
    bool isDark,
  ) {
    final color = dayType == DayType.rest ? Colors.orange : AppColors.success;

    return Column(
      children: [
        Container(
          width: 36.w,
          height: 36.w,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.2),
            shape: BoxShape.circle,
            border: Border.all(color: color, width: 2),
          ),
          child: Center(
            child: Text(
              dayType.code,
              style: TextStyle(
                fontSize: 14.sp,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
          ),
        ),
        SizedBox(height: 4.h),
        Text(
          day,
          style: TextStyle(
            fontSize: 11.sp,
            color: isDark ? Colors.white54 : AppColors.textSecondary,
          ),
        ),
      ],
    );
  }

  void _showBiometricLinkingDialog(BuildContext context) async {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final biometricService = getIt<BiometricService>();
    final authLocalDataSource = getIt<AuthLocalDataSource>();
    final messenger = ScaffoldMessenger.of(context);

    // Check if biometric is already enabled
    final isEnabled = await authLocalDataSource.isBiometricEnabled();
    final isAvailable = await biometricService.isBiometricAvailable();
    final availableBiometrics = await biometricService.getAvailableBiometrics();

    if (!mounted) return;

    if (!isAvailable) {
      messenger.showSnackBar(
        SnackBar(
          content: const Text(
            'Biometric authentication is not available on this device',
          ),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    if (!mounted) return;
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20.r),
        ),
        title: Text(
          'Link Biometric Account',
          style: TextStyle(
            fontSize: 20.sp,
            fontWeight: FontWeight.bold,
            color: isDark ? Colors.white : AppColors.textPrimary,
          ),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Link your ${availableBiometrics.contains(BiometricType.face) ? "Face ID" : "Fingerprint"} to your account for quick login and attendance marking.',
              style: TextStyle(
                fontSize: 14.sp,
                color: isDark ? Colors.white70 : AppColors.textSecondary,
              ),
            ),
            SizedBox(height: 16.h),
            if (isEnabled)
              Container(
                padding: EdgeInsets.all(12.w),
                decoration: BoxDecoration(
                  color: AppColors.success.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12.r),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.check_circle,
                      color: AppColors.success,
                      size: 20.sp,
                    ),
                    SizedBox(width: 8.w),
                    Text(
                      'Biometric is currently linked',
                      style: TextStyle(
                        fontSize: 13.sp,
                        color: AppColors.success,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(dialogContext);
              final biometricMessenger = ScaffoldMessenger.of(context);

              // Authenticate to link
              final result = await biometricService.authenticate(
                reason: 'Authenticate to link biometric to your account',
                biometricOnly: true,
              );

              if (result.success) {
                await authLocalDataSource.setBiometricEnabled(true);
                if (!mounted) return;
                biometricMessenger.showSnackBar(
                  SnackBar(
                    content: Text('Biometric linked successfully!'),
                    backgroundColor: AppColors.success,
                  ),
                );
              } else {
                if (!mounted) return;
                biometricMessenger.showSnackBar(
                  SnackBar(
                    content: Text(result.message),
                    backgroundColor: AppColors.error,
                  ),
                );
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: theme.primaryColor,
              foregroundColor: Colors.white,
            ),
            child: Text(isEnabled ? 'Re-link' : 'Link Now'),
          ),
        ],
      ),
    );
  }

  void _saveProfile(BuildContext context) {
    final emergencyName = _emergencyNameController.text.trim();
    final emergencyPhone = _emergencyPhoneController.text.trim();
    final emergencyRelation = _emergencyRelationController.text.trim();

    // Validate emergency contact fields
    if (emergencyName.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Please enter emergency contact name'),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    if (emergencyPhone.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Please enter emergency contact phone number'),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    if (emergencyRelation.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Please enter relationship'),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    context.read<ProfileBloc>().add(
      ProfileContactUpdated(
        emergencyName: emergencyName,
        emergencyPhone: emergencyPhone,
        emergencyRelation: emergencyRelation,
      ),
    );
  }

  String _formatDate(String dateStr) {
    final trimmed = dateStr.trim();
    if (trimmed.isEmpty || trimmed == '-') return dateStr;
    DateTime? date = DateTime.tryParse(trimmed);
    if (date == null) {
      // Try "dd-MMM-yyyy" format (e.g. "27-oct-2025")
      try {
        final parts = trimmed.split('-');
        if (parts.length == 3) {
          const months = {'jan': 1, 'feb': 2, 'mar': 3, 'apr': 4, 'may': 5, 'jun': 6, 'jul': 7, 'aug': 8, 'sep': 9, 'oct': 10, 'nov': 11, 'dec': 12};
          final month = months[parts[1].toLowerCase()];
          if (month != null) {
            date = DateTime(int.parse(parts[2]), month, int.parse(parts[0]));
          }
        }
      } catch (_) {}
    }
    if (date == null) return dateStr;
    return '${date.day}/${date.month}/${date.year}';
  }
}

class _SliverAppBarDelegate extends SliverPersistentHeaderDelegate {
  _SliverAppBarDelegate(this._tabBar, {required this.isDark});

  final TabBar _tabBar;
  final bool isDark;

  @override
  double get minExtent => _tabBar.preferredSize.height;

  @override
  double get maxExtent => _tabBar.preferredSize.height;

  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) {
    return Container(
      color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
      child: _tabBar,
    );
  }

  @override
  bool shouldRebuild(_SliverAppBarDelegate oldDelegate) => false;
}
