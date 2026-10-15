# Face Verification Feature Setup Guide

## Overview

This document describes the face verification feature implementation for the LMS attendance system. The feature uses on-device TFLite models for face recognition and follows Clean Architecture principles.

## Architecture

The feature is organized following Clean Architecture with feature-first structure:

```
lib/features/face_verification/
├── data/
│   ├── datasources/
│   │   ├── face_camera_datasource.dart      # Camera operations & face detection
│   │   ├── face_embedding_datasource.dart   # TFLite embedding extraction
│   │   └── face_storage_datasource.dart     # Secure storage of embeddings
│   ├── models/
│   │   └── face_embedding_model.dart        # Data model for storage
│   └── repositories/
│       └── face_verification_repository_impl.dart
├── domain/
│   ├── entities/
│   │   └── face_embedding.dart              # Domain entity
│   ├── repositories/
│   │   └── face_verification_repository.dart # Repository interface
│   └── usecases/
│       ├── enroll_face_usecase.dart         # Enrollment logic
│       └── verify_face_usecase.dart         # Verification logic
└── presentation/
    ├── bloc/
    │   ├── face_verification_bloc.dart      # State management
    │   ├── face_verification_event.dart
    │   └── face_verification_state.dart
    ├── pages/
    │   ├── face_enrollment_page.dart        # Enrollment UI
    │   └── face_verification_page.dart      # Verification UI
    └── widgets/
        ├── camera_preview_widget.dart       # Camera preview component
        └── face_instruction_overlay.dart    # Instruction overlay
```

## Key Features

### 1. Face Enrollment
- Captures 5-10 face images
- Ensures only 1 face per image
- Extracts 128-dimensional embeddings
- Averages embeddings for master template
- Stores only numeric vectors (no images)

### 2. Face Verification
- Captures live image
- Extracts embedding
- Compares with stored embedding using cosine similarity
- Threshold: 0.75 (configurable)

### 3. Liveness Detection
- Basic head turn detection using head pose angles
- Prevents spoofing with photos
- Can be enhanced with blink detection

### 4. Privacy & Security
- ✅ No raw images stored
- ✅ Only numeric embeddings stored
- ✅ Encrypted storage using `flutter_secure_storage`
- ✅ Images deleted immediately after processing
- ✅ On-device processing only

## Setup Instructions

### Step 1: Add TFLite Model File

1. Download or train a face recognition TFLite model (128-D embeddings)
   - Recommended: MobileFaceNet (lightweight)
   - Alternatives: FaceNet, ArcFace

2. Place the model file in:
   ```
   assets/models/face_recognition.tflite
   ```

3. Update `pubspec.yaml`:
   ```yaml
   flutter:
     assets:
       - assets/models/face_recognition.tflite
   ```

### Step 2: Add Required Dependencies

The following dependencies are already added to `pubspec.yaml`:
- `camera: ^0.11.0+1` - Camera access
- `tflite_flutter: ^0.11.0` - TFLite model inference
- `image: ^4.3.0` - Image processing
- `google_mlkit_face_detection: ^0.9.0` - Face detection

Run:
```bash
flutter pub get
```

### Step 3: Configure Permissions

#### Android (`android/app/src/main/AndroidManifest.xml`):
```xml
<uses-permission android:name="android.permission.CAMERA" />
<uses-feature android:name="android.hardware.camera" android:required="false" />
<uses-feature android:name="android.hardware.camera.front" android:required="false" />
```

#### iOS (`ios/Runner/Info.plist`):
```xml
<key>NSCameraUsageDescription</key>
<string>Camera access is required for face verification</string>
```

### Step 4: Model Configuration

Update `face_embedding_datasource.dart` if your model has different:
- Input size (default: 112x112)
- Embedding dimension (default: 128)
- Normalization range (default: [-1, 1])

## Usage

### Enrollment Flow

1. Navigate to Profile → Info tab
2. Scroll to "Face Verification" section
3. Tap "Enroll Face"
4. Follow on-screen instructions:
   - Center face in frame
   - Capture 5 images
   - Turn head slightly for liveness
5. Complete enrollment

### Verification Flow

1. Navigate to Profile → Info tab
2. Tap "Verify Face" (if enrolled)
3. Center face in frame
4. Tap "Verify Face" button
5. System compares with enrolled face

### Integration with Attendance

The face verification can be integrated into the attendance flow:

```dart
// In biometric_attendance_page.dart or similar
final verified = await Navigator.push<bool>(
  context,
  MaterialPageRoute(
    builder: (_) => const FaceVerificationPage(),
  ),
);

if (verified == true) {
  // Proceed with attendance marking
}
```

## Model Recommendations

### MobileFaceNet
- **Size**: ~4MB
- **Accuracy**: Good
- **Speed**: Fast
- **Best for**: Mobile devices with limited resources

### FaceNet
- **Size**: ~20MB
- **Accuracy**: Excellent
- **Speed**: Moderate
- **Best for**: Higher accuracy requirements

### ArcFace
- **Size**: ~30MB
- **Accuracy**: State-of-the-art
- **Speed**: Moderate
- **Best for**: Maximum accuracy needs

## Troubleshooting

### Model Not Found Error
- Ensure model file exists at `assets/models/face_recognition.tflite`
- Check `pubspec.yaml` includes the asset path
- Run `flutter clean` and `flutter pub get`

### Camera Permission Denied
- Check platform-specific permission configurations
- Request permissions at runtime using `permission_handler`

### Low Verification Accuracy
- Ensure good lighting conditions
- Check face is centered and clearly visible
- Consider adjusting similarity threshold
- Verify model input size matches your model

### Performance Issues
- Use lower resolution camera preset (`ResolutionPreset.medium`)
- Consider using MobileFaceNet for better performance
- Optimize image preprocessing

## Privacy Compliance

This implementation is designed to be App Store compliant:

- ✅ No cloud APIs used
- ✅ No raw images stored
- ✅ Only numeric embeddings stored
- ✅ On-device processing only
- ✅ Encrypted storage
- ✅ Images deleted immediately after processing

## Future Enhancements

1. **Enhanced Liveness Detection**
   - Blink detection
   - 3D face depth estimation
   - Challenge-response patterns

2. **Model Optimization**
   - Quantized models for smaller size
   - GPU acceleration support
   - Model caching strategies

3. **UI Improvements**
   - Real-time face detection overlay
   - Progress indicators
   - Better error messages

4. **Integration**
   - Direct integration with attendance flow
   - Batch enrollment option
   - Re-enrollment prompts

## Notes

- The feature is NOT a replacement for biometric authentication (FaceID/TouchID)
- It's designed for attendance verification only
- All processing happens on-device for privacy
- No network calls are made during verification






