import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

// ignore_for_file: todo

import '../../../../core/services/biometric_service.dart';
import '../../../../di/service_locator.dart';

/// App Lock Screen for biometric/PIN authentication
/// 
/// Features:
/// - Fingerprint authentication
/// - Face ID authentication
/// - PIN code fallback
/// - Secure unlock mechanism
class AppLockPage extends StatefulWidget {
  const AppLockPage({
    super.key,
    required this.onUnlocked,
    this.canUseBiometrics = true,
  });

  final VoidCallback onUnlocked;
  final bool canUseBiometrics;

  @override
  State<AppLockPage> createState() => _AppLockPageState();
}

class _AppLockPageState extends State<AppLockPage>
    with SingleTickerProviderStateMixin {
  final _biometricService = getIt<BiometricService>();
  final _pinController = TextEditingController();
  final _pinFocusNode = FocusNode();

  late AnimationController _shakeController;
  late Animation<double> _shakeAnimation;

  bool _isLoading = false;
  bool _showPin = false;
  bool _hasBiometrics = false;
  bool _hasFaceId = false;
  bool _hasFingerprint = false;
  String _errorMessage = '';
  String _enteredPin = '';

  static const String _correctPin = '1234'; // TODO: Store securely

  @override
  void initState() {
    super.initState();
    
    _shakeController = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
    );
    
    _shakeAnimation = Tween<double>(begin: 0, end: 10)
        .chain(CurveTween(curve: Curves.elasticIn))
        .animate(_shakeController);

    _checkBiometrics();
  }

  Future<void> _checkBiometrics() async {
    if (!widget.canUseBiometrics) {
      setState(() => _showPin = true);
      return;
    }

    final isAvailable = await _biometricService.isBiometricAvailable();
    final hasFace = await _biometricService.isFaceIdAvailable();
    final hasFingerprint = await _biometricService.isFingerprintAvailable();

    setState(() {
      _hasBiometrics = isAvailable;
      _hasFaceId = hasFace;
      _hasFingerprint = hasFingerprint;
    });

    if (isAvailable) {
      // Auto-prompt biometric on load
      Future.delayed(const Duration(milliseconds: 500), _authenticateWithBiometrics);
    } else {
      setState(() => _showPin = true);
    }
  }

  Future<void> _authenticateWithBiometrics() async {
    if (_isLoading) return;

    setState(() {
      _isLoading = true;
      _errorMessage = '';
    });

    final result = await _biometricService.authenticate(
      reason: 'Unlock LMS App',
      biometricOnly: false,
    );

    setState(() => _isLoading = false);

    if (result.success) {
      widget.onUnlocked();
    } else {
      setState(() => _errorMessage = result.message);
      
      // Show PIN option after failed biometric
      if (result.error == BiometricError.lockedOut ||
          result.error == BiometricError.permanentlyLockedOut) {
        setState(() => _showPin = true);
      }
    }
  }

  void _onPinDigitEntered(String digit) {
    if (_enteredPin.length >= 4) return;

    setState(() {
      _enteredPin += digit;
      _errorMessage = '';
    });

    if (_enteredPin.length == 4) {
      _verifyPin();
    }
  }

  void _onPinBackspace() {
    if (_enteredPin.isEmpty) return;
    
    setState(() {
      _enteredPin = _enteredPin.substring(0, _enteredPin.length - 1);
      _errorMessage = '';
    });
  }

  void _verifyPin() {
    if (_enteredPin == _correctPin) {
      HapticFeedback.mediumImpact();
      widget.onUnlocked();
    } else {
      HapticFeedback.heavyImpact();
      _shakeController.forward().then((_) => _shakeController.reset());
      
      setState(() {
        _enteredPin = '';
        _errorMessage = 'Incorrect PIN. Please try again.';
      });
    }
  }

  @override
  void dispose() {
    _shakeController.dispose();
    _pinController.dispose();
    _pinFocusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: isDark
                ? [const Color(0xFF1A1A2E), const Color(0xFF16213E)]
                : [theme.primaryColor, theme.primaryColor.withValues(alpha: 0.7)],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              const Spacer(flex: 2),
              
              // Logo
              _buildLogo(),
              
              SizedBox(height: 24.h),
              
              // Title
              Text(
                'Welcome Back',
                style: TextStyle(
                  fontSize: 28.sp,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              
              SizedBox(height: 8.h),
              
              Text(
                _showPin ? 'Enter your PIN to unlock' : 'Verify your identity',
                style: TextStyle(
                  fontSize: 14.sp,
                  color: Colors.white.withValues(alpha: 0.8),
                ),
              ),
              
              const Spacer(),
              
              // Content based on mode
              if (_showPin)
                _buildPinInput()
              else
                _buildBiometricPrompt(),
              
              // Error message
              if (_errorMessage.isNotEmpty)
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: 32.w, vertical: 16.h),
                  child: Container(
                    padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 12.h),
                    decoration: BoxDecoration(
                      color: Colors.red.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(12.r),
                      border: Border.all(
                        color: Colors.red.withValues(alpha: 0.5),
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.error_outline,
                          color: Colors.red.shade200,
                          size: 20.sp,
                        ),
                        SizedBox(width: 8.w),
                        Expanded(
                          child: Text(
                            _errorMessage,
                            style: TextStyle(
                              color: Colors.red.shade200,
                              fontSize: 13.sp,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              
              const Spacer(flex: 2),
              
              // Toggle between PIN and biometric
              if (_hasBiometrics)
                _buildToggleButton(),
              
              SizedBox(height: 32.h),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLogo() {
    return Container(
      width: 100.w,
      height: 100.w,
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.15),
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.2),
            blurRadius: 20,
            spreadRadius: 5,
          ),
        ],
      ),
      child: Padding(
        padding: EdgeInsets.all(20.w),
        child: Image.asset(
          'lib/assets/images/YDC-HD.png',
          fit: BoxFit.contain,
          errorBuilder: (_, __, ___) => Icon(
            Icons.lock_rounded,
            size: 50.sp,
            color: Colors.white,
          ),
        ),
      ),
    );
  }

  Widget _buildBiometricPrompt() {
    return Column(
      children: [
        // Biometric icon
        GestureDetector(
          onTap: _isLoading ? null : _authenticateWithBiometrics,
          child: Container(
            width: 120.w,
            height: 120.w,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.15),
              shape: BoxShape.circle,
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.3),
                width: 2,
              ),
            ),
            child: _isLoading
                ? Center(
                    child: CircularProgressIndicator(
                      color: Colors.white,
                      strokeWidth: 3,
                    ),
                  )
                : Icon(
                    _hasFaceId
                        ? Icons.face_rounded
                        : Icons.fingerprint_rounded,
                    size: 60.sp,
                    color: Colors.white,
                  ),
          ),
        ),
        
        SizedBox(height: 20.h),
        
        Text(
          _hasFaceId
              ? 'Tap to use Face ID'
              : 'Tap to use Fingerprint',
          style: TextStyle(
            fontSize: 14.sp,
            color: Colors.white.withValues(alpha: 0.8),
          ),
        ),
        
        // Available biometrics
        SizedBox(height: 16.h),
        
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (_hasFingerprint) ...[
              _buildBiometricChip(
                Icons.fingerprint_rounded,
                'Fingerprint',
              ),
              if (_hasFaceId) SizedBox(width: 12.w),
            ],
            if (_hasFaceId)
              _buildBiometricChip(
                Icons.face_rounded,
                'Face ID',
              ),
          ],
        ),
      ],
    );
  }

  Widget _buildBiometricChip(IconData icon, String label) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 8.h),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(20.r),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.3),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: Colors.white, size: 18.sp),
          SizedBox(width: 6.w),
          Text(
            label,
            style: TextStyle(
              color: Colors.white,
              fontSize: 12.sp,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPinInput() {
    return AnimatedBuilder(
      animation: _shakeAnimation,
      builder: (context, child) {
        return Transform.translate(
          offset: Offset(_shakeAnimation.value, 0),
          child: child,
        );
      },
      child: Column(
        children: [
          // PIN dots
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(4, (index) {
              final isFilled = index < _enteredPin.length;
              return Container(
                margin: EdgeInsets.symmetric(horizontal: 12.w),
                width: 20.w,
                height: 20.w,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: isFilled
                      ? Colors.white
                      : Colors.white.withValues(alpha: 0.3),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.5),
                    width: 2,
                  ),
                ),
              );
            }),
          ),
          
          SizedBox(height: 40.h),
          
          // Number pad
          _buildNumberPad(),
        ],
      ),
    );
  }

  Widget _buildNumberPad() {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 60.w),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: ['1', '2', '3'].map(_buildNumberButton).toList(),
          ),
          SizedBox(height: 16.h),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: ['4', '5', '6'].map(_buildNumberButton).toList(),
          ),
          SizedBox(height: 16.h),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: ['7', '8', '9'].map(_buildNumberButton).toList(),
          ),
          SizedBox(height: 16.h),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              // Empty space for biometric
              if (_hasBiometrics)
                _buildIconButton(
                  Icons.fingerprint_rounded,
                  _authenticateWithBiometrics,
                )
              else
                SizedBox(width: 70.w),
              _buildNumberButton('0'),
              _buildIconButton(
                Icons.backspace_rounded,
                _onPinBackspace,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildNumberButton(String digit) {
    return GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact();
        _onPinDigitEntered(digit);
      },
      child: Container(
        width: 70.w,
        height: 70.w,
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.1),
          shape: BoxShape.circle,
          border: Border.all(
            color: Colors.white.withValues(alpha: 0.2),
          ),
        ),
        child: Center(
          child: Text(
            digit,
            style: TextStyle(
              fontSize: 28.sp,
              fontWeight: FontWeight.w600,
              color: Colors.white,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildIconButton(IconData icon, VoidCallback onTap) {
    return GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact();
        onTap();
      },
      child: Container(
        width: 70.w,
        height: 70.w,
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.1),
          shape: BoxShape.circle,
        ),
        child: Center(
          child: Icon(
            icon,
            size: 28.sp,
            color: Colors.white,
          ),
        ),
      ),
    );
  }

  Widget _buildToggleButton() {
    return TextButton.icon(
      onPressed: () {
        setState(() {
          _showPin = !_showPin;
          _enteredPin = '';
          _errorMessage = '';
        });
      },
      icon: Icon(
        _showPin ? Icons.fingerprint_rounded : Icons.dialpad_rounded,
        color: Colors.white,
      ),
      label: Text(
        _showPin ? 'Use Biometrics' : 'Use PIN',
        style: TextStyle(
          color: Colors.white,
          fontSize: 14.sp,
        ),
      ),
    );
  }
}

