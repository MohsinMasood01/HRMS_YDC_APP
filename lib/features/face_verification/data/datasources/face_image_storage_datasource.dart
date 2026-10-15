import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;

/// Data source for storing face enrollment images on device
///
/// Saves images to app's documents directory for later verification.
/// Images are stored in: {appDocuments}/face_enrollment/
abstract class FaceImageStorageDataSource {
  /// Save enrollment image to device storage
  /// Returns the saved file path
  Future<String> saveEnrollmentImage(File imageFile, int imageIndex);

  /// Get all saved enrollment image paths
  Future<List<String>> getEnrollmentImagePaths();

  /// Delete all enrollment images
  Future<void> deleteAllEnrollmentImages();

  /// Delete a specific enrollment image
  Future<void> deleteEnrollmentImage(String imagePath);
}

class FaceImageStorageDataSourceImpl implements FaceImageStorageDataSource {
  static const String _enrollmentFolder = 'face_enrollment';

  /// Get the directory for storing enrollment images
  Future<Directory> get _enrollmentDirectory async {
    final appDir = await getApplicationDocumentsDirectory();
    final enrollmentDir = Directory(path.join(appDir.path, _enrollmentFolder));

    if (!await enrollmentDir.exists()) {
      await enrollmentDir.create(recursive: true);
    }

    return enrollmentDir;
  }

  @override
  Future<String> saveEnrollmentImage(File imageFile, int imageIndex) async {
    final enrollmentDir = await _enrollmentDirectory;
    final fileName = 'enrollment_$imageIndex.jpg';
    final destinationPath = path.join(enrollmentDir.path, fileName);

    // Copy image to enrollment directory
    final savedFile = await imageFile.copy(destinationPath);
    return savedFile.path;
  }

  @override
  Future<List<String>> getEnrollmentImagePaths() async {
    final enrollmentDir = await _enrollmentDirectory;
    if (!await enrollmentDir.exists()) {
      return [];
    }

    final files = enrollmentDir
        .listSync()
        .whereType<File>()
        .where(
          (file) => file.path.endsWith('.jpg') || file.path.endsWith('.png'),
        )
        .map((file) => file.path)
        .toList();

    // Sort by filename to maintain order
    files.sort();
    return files;
  }

  @override
  Future<void> deleteAllEnrollmentImages() async {
    final enrollmentDir = await _enrollmentDirectory;
    if (await enrollmentDir.exists()) {
      await enrollmentDir.delete(recursive: true);
      // Recreate empty directory
      await enrollmentDir.create(recursive: true);
    }
  }

  @override
  Future<void> deleteEnrollmentImage(String imagePath) async {
    final file = File(imagePath);
    if (await file.exists()) {
      await file.delete();
    }
  }
}






