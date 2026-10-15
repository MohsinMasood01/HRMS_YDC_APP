# Face Auth Integration Guide

## Overview
The `face_auth` feature module integrates with the FastAPI face recognition backend for face enrollment and verification.

## Integration with Attendance Flow

### Step 1: Verify Face Before Marking Attendance

```dart
// In your attendance marking flow (e.g., BiometricAttendanceBloc)

// 1. Collect 5 frames using camera
final frames = await FrameCollector.collectFrames(
  controller: cameraController,
  requiredFrames: 5,
  onFrameCollected: (current, total) {
    // Update UI with progress
    print('Collected $current/$total frames');
  },
);

// 2. Verify face using FaceBloc
final faceBloc = getIt<FaceBloc>();
faceBloc.add(FaceVerifyRequested(
  cardNo1: employeeCardNo,
  frames: frames,
));

// 3. Listen to verification result
faceBloc.stream.listen((state) {
  if (state.status == FaceStatus.success) {
    if (state.isMatch) {
      // Face verified successfully - proceed with attendance marking
      // Call main backend attendance API
      markAttendance();
    } else {
      // Face verification failed
      showError('Face verification failed');
    }
  } else if (state.status == FaceStatus.failure) {
    showError(state.errorMessage ?? 'Face verification error');
  }
});
```

## Face Registration Flow

```dart
// 1. Collect 10 frames
final frames = await FrameCollector.collectFrames(
  controller: cameraController,
  requiredFrames: 10,
);

// 2. Register face
final faceBloc = getIt<FaceBloc>();
faceBloc.add(FaceRegisterRequested(
  cardNo1: employeeCardNo,
  frames: frames,
));

// 3. Check result
faceBloc.stream.listen((state) {
  if (state.status == FaceStatus.success && state.isRegistered) {
    // Registration successful
    showSuccess('Face registered successfully');
  }
});
```

## Check Face Status

```dart
final faceBloc = getIt<FaceBloc>();
faceBloc.add(FaceStatusRequested(cardNo1: employeeCardNo));

faceBloc.stream.listen((state) {
  if (state.status == FaceStatus.success) {
    if (!state.isRegistered) {
      // Prompt user to enroll face
      showEnrollmentPrompt();
    }
  }
});
```

## Configuration

Update `AppConfig` with your FastAPI backend URL:

```dart
AppConfig(
  faceAuthBaseUrl: 'http://your-fastapi-server:8000',
)
```


