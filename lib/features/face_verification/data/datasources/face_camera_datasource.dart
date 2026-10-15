import 'dart:async';
import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image/image.dart' as img;

/// Capture state machine for clean lifecycle management
///
/// Prevents race conditions, late frames, and camera surface crashes
enum CaptureState {
  /// Initial state - not capturing
  idle,

  /// Actively capturing frames
  capturing,

  /// Stopping capture - waiting for in-flight frames
  stopping,

  /// Capture completed - ready for finalization
  completed,
}

/// Data source for camera operations
///
/// Handles:
/// - Camera initialization
/// - Capturing images and frames
/// - Converting frames to images for backend
abstract class FaceCameraDataSource {
  /// Initialize camera
  Future<CameraController> initializeCamera();

  /// Capture image from camera
  Future<XFile> captureImage(CameraController controller);

  /// Capture burst of frames from camera stream
  ///
  /// Captures raw frames from camera and converts them to images.
  /// Returns list of full-frame images (not cropped).
  /// [onProgress] callback is called with frame count.
  Future<List<img.Image>> captureBurstFrames(
    CameraController controller,
    int numFrames, {
    void Function(int frameCount)? onProgress,
  });

  /// Dispose camera controller
  Future<void> disposeCamera(CameraController controller);
}

class FaceCameraDataSourceImpl implements FaceCameraDataSource {
  FaceCameraDataSourceImpl();

  @override
  Future<CameraController> initializeCamera() async {
    final cameras = await availableCameras();
    final frontCamera = cameras.firstWhere(
      (camera) => camera.lensDirection == CameraLensDirection.front,
      orElse: () => cameras.first,
    );

    // Use medium resolution (640x480) — sufficient for face detection,
    // significantly faster YUV→RGB conversion than high (1280x720)
    ResolutionPreset resolutionPreset = ResolutionPreset.medium;
    try {
      final controller = CameraController(
        frontCamera,
        resolutionPreset,
        enableAudio: false,
        imageFormatGroup: ImageFormatGroup.yuv420,
      );
      await controller.initialize();

      // Log actual resolution achieved
      debugPrint(
        'FaceCameraDataSource: Camera initialized - '
        'Resolution: ${controller.value.previewSize?.width}x${controller.value.previewSize?.height}, '
        'Sensor orientation: ${frontCamera.sensorOrientation}, '
        'Lens direction: ${frontCamera.lensDirection}',
      );

      return controller;
    } catch (e) {
      // Fallback to medium resolution if high is not supported
      debugPrint(
        'FaceCameraDataSource: High resolution not supported, falling back to medium: $e',
      );
      final controller = CameraController(
        frontCamera,
        ResolutionPreset.medium,
        enableAudio: false,
        imageFormatGroup: ImageFormatGroup.jpeg,
      );
      await controller.initialize();

      debugPrint(
        'FaceCameraDataSource: Camera initialized (medium) - '
        'Resolution: ${controller.value.previewSize?.width}x${controller.value.previewSize?.height}, '
        'Sensor orientation: ${frontCamera.sensorOrientation}',
      );

      return controller;
    }
  }

  @override
  Future<XFile> captureImage(CameraController controller) async {
    if (!controller.value.isInitialized) {
      throw StateError('Camera not initialized');
    }

    // Ensure image stream is stopped before taking picture
    // This is handled by the bloc, but adding safety check here
    try {
      return await controller.takePicture();
    } catch (e) {
      throw StateError('Failed to capture image: ${e.toString()}');
    }
  }

  /// Convert YUV420 CameraImage to RGB Image
  img.Image? _convertYUV420ToImage(CameraImage cameraImage) {
    try {
      final width = cameraImage.width;
      final height = cameraImage.height;

      if (cameraImage.planes.length < 3) {
        debugPrint(
          'FaceCameraDataSource: ERROR - Invalid YUV420 format, expected 3 planes, got ${cameraImage.planes.length}',
        );
        return null;
      }

      final yPlane = cameraImage.planes[0];
      final uPlane = cameraImage.planes[1];
      final vPlane = cameraImage.planes[2];

      // Validate plane dimensions
      if (yPlane.bytesPerRow <= 0 || yPlane.bytes.isEmpty) {
        debugPrint(
          'FaceCameraDataSource: ERROR - Invalid Y plane: bytesPerRow=${yPlane.bytesPerRow}, '
          'bytes.length=${yPlane.bytes.length}',
        );
        return null;
      }

      // Detect semi-planar (NV12/NV21) vs planar (I420) format:
      // NV12/NV21: UV bytesPerRow == full image width (interleaved, pixel stride = 2)
      // I420:      UV bytesPerRow == half image width  (separate planes, pixel stride = 1)
      final uvPixelStride = (uPlane.bytesPerRow > (width ~/ 2)) ? 2 : 1;

      // Create RGB image
      final image = img.Image(width: width, height: height);

      // Convert YUV to RGB
      for (int y = 0; y < height; y++) {
        for (int x = 0; x < width; x++) {
          try {
            final yIndex = y * yPlane.bytesPerRow + x;

            if (yIndex >= yPlane.bytes.length) continue;

            final uvRow = y ~/ 2;
            final uvCol = x ~/ 2;

            int uValue = 128;
            int vValue = 128;

            final uIndex = uvRow * uPlane.bytesPerRow + uvCol * uvPixelStride;
            if (uIndex >= 0 && uIndex < uPlane.bytes.length) {
              uValue = uPlane.bytes[uIndex];
            }

            final vIndex = uvRow * vPlane.bytesPerRow + uvCol * uvPixelStride;
            if (vIndex >= 0 && vIndex < vPlane.bytes.length) {
              vValue = vPlane.bytes[vIndex];
            }

            final yValue = yPlane.bytes[yIndex];

            // YUV to RGB conversion
            final r = (yValue + 1.402 * (vValue - 128)).clamp(0, 255).toInt();
            final g = (yValue - 0.344 * (uValue - 128) - 0.714 * (vValue - 128))
                .clamp(0, 255)
                .toInt();
            final b = (yValue + 1.772 * (uValue - 128)).clamp(0, 255).toInt();

            // Set pixel with RGBA values directly
            image.setPixelRgba(x, y, r, g, b, 255);
          } catch (e) {
            // Skip this pixel if conversion fails
            debugPrint(
              'FaceCameraDataSource: Error converting pixel at ($x, $y): $e',
            );
            continue;
          }
        }
      }

      return image;
    } catch (e, stackTrace) {
      debugPrint('FaceCameraDataSource: ERROR in _convertYUV420ToImage - $e');
      debugPrint('FaceCameraDataSource: Stack trace: $stackTrace');
      return null;
    }
  }

  @override
  Future<List<img.Image>> captureBurstFrames(
    CameraController controller,
    int numFrames, {
    void Function(int frameCount)? onProgress,
  }) async {
    final frames = <img.Image>[];
    int capturedFrames = 0;
    int skippedBusy = 0;
    int conversionErrors = 0;

    // Busy flag prevents the camera stream (which fires at ~30fps) from
    // queueing up dozens of slow YUV→RGB conversions in microtasks on slow
    // devices. We only process one frame at a time; new stream frames that
    // arrive mid-processing are silently dropped. The capture takes longer
    // wall-clock but reliably progresses on any device.
    bool processingFrame = false;
    CaptureState captureState = CaptureState.idle;

    try {
      if (controller.value.isStreamingImages) {
        await controller.stopImageStream();
        await Future.delayed(const Duration(milliseconds: 200));
      }
    } catch (_) {}

    final completer = Completer<void>();
    captureState = CaptureState.capturing;

    // Timeout scales with target frame count so slow devices still get to
    // capture them all. 2.5 s/frame budget + 5 s baseline gives a 10-frame
    // burst a 30 s window — generous enough for phones whose YUV→RGB
    // pipeline takes 2+ s per frame, while keeping fast phones snappy
    // (they finish in their own time well below the cap).
    final timeoutSeconds = (numFrames * 2.5).ceil() + 5;
    final captureStarted = DateTime.now();

    try {
      await controller.startImageStream((CameraImage image) {
        if (captureState != CaptureState.capturing) return;
        if (processingFrame) {
          skippedBusy++;
          return; // drop this frame; we'll get another one shortly
        }
        processingFrame = true;

        Future.microtask(() async {
          try {
            if (captureState != CaptureState.capturing) return;

            final rgbImage = _convertYUV420ToImage(image);
            if (rgbImage == null) {
              conversionErrors++;
              debugPrint('Failed to convert frame to RGB');
              return;
            }

            // ================================
            // 🔥 IMAGE PROCESSING PIPELINE
            // ================================

            // 1. FIX MIRROR (front camera)
            img.Image fixed = img.flipHorizontal(rgbImage);

            // 2. FIX ROTATION — sensor orientation 270 means raw image is landscape
            //    when the phone is held in portrait; rotate to upright portrait
            final sensorOrientation =
                controller.description.sensorOrientation;
            if (sensorOrientation == 270) {
              fixed = img.copyRotate(fixed, angle: 90);
            } else if (sensorOrientation == 90) {
              fixed = img.copyRotate(fixed, angle: -90);
            }

            // 3. RESIZE to 480px wide — large enough for InsightFace detection
            img.Image resized = img.copyResize(fixed, width: 480);

            // Add full portrait frame
            frames.add(resized);
            capturedFrames++;

            onProgress?.call(capturedFrames);

            debugPrint(
              'Processed frame $capturedFrames/$numFrames (${resized.width}x${resized.height})',
            );

            // Stop condition
            if (capturedFrames >= numFrames && !completer.isCompleted) {
              captureState = CaptureState.stopping;
              try {
                await controller.stopImageStream();
              } catch (_) {}
              captureState = CaptureState.completed;
              completer.complete();
            }
          } catch (e) {
            debugPrint('Frame processing error: $e');
          } finally {
            processingFrame = false; // release the busy lock
          }
        });
      });

      await completer.future.timeout(
        Duration(seconds: timeoutSeconds),
        onTimeout: () {
          final elapsed = DateTime.now().difference(captureStarted).inSeconds;
          debugPrint(
            'Capture timeout after ${elapsed}s — captured ${frames.length}/$numFrames '
            'frames (skipped while busy: $skippedBusy, conversion errors: $conversionErrors)',
          );
          captureState = CaptureState.stopping;
          try {
            controller.stopImageStream();
          } catch (_) {}
          captureState = CaptureState.completed;
        },
      );
    } catch (e) {
      debugPrint('Burst capture error: $e');
    } finally {
      try {
        if (controller.value.isStreamingImages) {
          await controller.stopImageStream();
        }
      } catch (_) {}

      captureState = CaptureState.completed;
    }

    final elapsed = DateTime.now().difference(captureStarted).inSeconds;
    debugPrint(
      'Burst capture completed in ${elapsed}s — ${frames.length}/$numFrames frames '
      '(skipped while busy: $skippedBusy, conversion errors: $conversionErrors)',
    );

    return frames;
  }

  @override
  Future<void> disposeCamera(CameraController controller) async {
    try {
      if (controller.value.isStreamingImages) {
        await controller.stopImageStream();
      }
    } catch (_) {}

    await controller.dispose();
  }
}
