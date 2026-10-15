import 'dart:async';
import 'dart:convert';
import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as img;

/// Helper class for collecting camera frames and converting to base64
class FrameCollector {
  /// Convert camera image to base64 string
  ///
  /// [image] - CameraImage from camera controller
  /// Returns base64 encoded JPEG string
  static String imageToBase64(CameraImage image) {
    try {
      // Convert YUV420 to RGB
      final rgbImage = _convertYUV420ToRGB(image);
      
      // Convert to JPEG
      final jpegBytes = img.encodeJpg(rgbImage, quality: 85);
      
      // Encode to base64
      return base64Encode(jpegBytes);
    } catch (e) {
      debugPrint('FrameCollector: Error converting image to base64: $e');
      rethrow;
    }
  }

  /// Convert CameraImage (YUV420) to RGB Image
  static img.Image _convertYUV420ToRGB(CameraImage image) {
    final width = image.width;
    final height = image.height;

    // Convert YUV to RGB
    final rgbBytes = Uint8List(width * height * 3);
    
    if (image.format.group == ImageFormatGroup.yuv420) {
      final yPlane = image.planes[0].bytes;
      final uPlane = image.planes[1].bytes;
      final vPlane = image.planes[2].bytes;

      int yIndex = 0;
      int uvIndex = 0;
      int rgbIndex = 0;

      for (int y = 0; y < height; y++) {
        for (int x = 0; x < width; x++) {
          final yValue = yPlane[yIndex];
          final uValue = uPlane[uvIndex & ~1] - 128;
          final vValue = vPlane[uvIndex | 1] - 128;

          // YUV to RGB conversion
          int r = (yValue + (1.402 * vValue)).round().clamp(0, 255);
          int g = (yValue - (0.344 * uValue) - (0.714 * vValue)).round().clamp(0, 255);
          int b = (yValue + (1.772 * uValue)).round().clamp(0, 255);

          rgbBytes[rgbIndex] = r;
          rgbBytes[rgbIndex + 1] = g;
          rgbBytes[rgbIndex + 2] = b;

          yIndex++;
          rgbIndex += 3;
          if ((y % 2 == 0) && (x % 2 == 0)) {
            uvIndex++;
          }
        }
      }
    } else {
      // For other formats, try direct conversion
      final plane = image.planes[0];
      rgbBytes.setRange(0, plane.bytes.length, plane.bytes);
    }

    // Create Image object from RGB bytes
    return img.Image.fromBytes(
      width: width,
      height: height,
      bytes: rgbBytes.buffer,
    );
  }

  /// Collect frames from camera controller
  ///
  /// [controller] - Camera controller
  /// [requiredFrames] - Number of frames to collect
  /// [onFrameCollected] - Callback when a frame is collected (currentCount, totalCount)
  /// [interval] - Time interval between frame captures (default: 200ms)
  /// Returns list of base64 encoded frames
  static Future<List<String>> collectFrames({
    required CameraController controller,
    required int requiredFrames,
    void Function(int current, int total)? onFrameCollected,
    Duration interval = const Duration(milliseconds: 200),
  }) async {
    final frames = <String>[];
    int collected = 0;

    while (collected < requiredFrames) {
      if (!controller.value.isInitialized) {
        throw Exception('Camera not initialized');
      }

      try {
        final image = await controller.takePicture();
        final imageBytes = await image.readAsBytes();
        final base64Frame = base64Encode(imageBytes);
        frames.add(base64Frame);
        collected++;

        onFrameCollected?.call(collected, requiredFrames);

        // Wait before capturing next frame (except for the last one)
        if (collected < requiredFrames) {
          await Future.delayed(interval);
        }
      } catch (e) {
        debugPrint('FrameCollector: Error capturing frame: $e');
        // Continue trying
        await Future.delayed(const Duration(milliseconds: 100));
      }
    }

    return frames;
  }

  /// Alternative: Collect frames from stream (real-time)
  ///
  /// [controller] - Camera controller
  /// [requiredFrames] - Number of frames to collect
  /// [onFrameCollected] - Callback when a frame is collected
  /// Returns list of base64 encoded frames
  static Future<List<String>> collectFramesFromStream({
    required CameraController controller,
    required int requiredFrames,
    void Function(int current, int total)? onFrameCollected,
  }) async {
    final frames = <String>[];
    int collected = 0;
    StreamSubscription<CameraImage>? subscription;

    final completer = Completer<List<String>>();

    void onImageStream(CameraImage image) async {
      if (collected >= requiredFrames) {
        await subscription?.cancel();
        await controller.stopImageStream();
        if (!completer.isCompleted) {
          completer.complete(frames);
        }
        return;
      }

      try {
        final base64Frame = imageToBase64(image);
        frames.add(base64Frame);
        collected++;

        onFrameCollected?.call(collected, requiredFrames);

        if (collected >= requiredFrames) {
          await subscription?.cancel();
          await controller.stopImageStream();
          if (!completer.isCompleted) {
            completer.complete(frames);
          }
        }
      } catch (e) {
        debugPrint('FrameCollector: Error processing frame: $e');
        // Continue collecting
      }
    }

    subscription = controller.startImageStream(onImageStream) as StreamSubscription<CameraImage>?;

    // Timeout after 30 seconds
    Future.delayed(const Duration(seconds: 30), () {
      if (!completer.isCompleted) {
        subscription?.cancel();
        controller.stopImageStream();
        completer.completeError(
          Exception('Timeout: Could not collect $requiredFrames frames'),
        );
      }
    });

    return completer.future;
  }
}

