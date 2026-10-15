import 'dart:io';

import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';

import '../../features/attendance/domain/entities/location_info.dart';

/// Service for saving attendance records to a local text file
/// 
/// This service handles:
/// - Creating/appending attendance records to a text file
/// - Reading attendance history from the file
/// - Formatting attendance data for display
class AttendanceFileService {
  static const String _fileName = 'attendance_records.txt';
  static final String _separator = '═' * 60;
  
  /// Get the directory for storing attendance files
  Future<Directory> get _attendanceDirectory async {
    final appDir = await getApplicationDocumentsDirectory();
    final attendanceDir = Directory('${appDir.path}/attendance');
    
    if (!await attendanceDir.exists()) {
      await attendanceDir.create(recursive: true);
    }
    
    return attendanceDir;
  }
  
  /// Get the attendance file
  Future<File> get _attendanceFile async {
    final dir = await _attendanceDirectory;
    return File('${dir.path}/$_fileName');
  }
  
  /// Save attendance record to file
  Future<AttendanceFileSaveResult> saveAttendance({
    required String employeeId,
    required String attendanceType,
    required String biometricType,
    required LocationInfo locationInfo,
    required DateTime timestamp,
  }) async {
    try {
      final file = await _attendanceFile;
      final dateFormatter = DateFormat('yyyy-MM-dd');
      final timeFormatter = DateFormat('HH:mm:ss');
      final fullFormatter = DateFormat('yyyy-MM-dd HH:mm:ss');
      
      final record = StringBuffer();
      
      // Header
      record.writeln(_separator);
      record.writeln('ATTENDANCE RECORD');
      record.writeln(_separator);
      
      // Basic Info
      record.writeln('Employee ID     : $employeeId');
      record.writeln('Date            : ${dateFormatter.format(timestamp)}');
      record.writeln('Time            : ${timeFormatter.format(timestamp)}');
      record.writeln('Type            : ${attendanceType == 'check_in' ? 'CHECK IN' : 'CHECK OUT'}');
      record.writeln('Biometric       : ${biometricType == 'face' ? 'Face Recognition' : 'Fingerprint'}');
      record.writeln('');
      
      // Location Info
      record.writeln('--- LOCATION DETAILS ---');
      record.writeln('Coordinates     : ${locationInfo.latitude.toStringAsFixed(6)}, ${locationInfo.longitude.toStringAsFixed(6)}');
      record.writeln('Accuracy        : ${locationInfo.accuracy.toStringAsFixed(1)} meters');
      
      if (locationInfo.formattedAddress != null && locationInfo.formattedAddress!.isNotEmpty) {
        record.writeln('Address         : ${locationInfo.formattedAddress}');
      }
      
      if (locationInfo.streetAddress != null && locationInfo.streetAddress!.isNotEmpty) {
        record.writeln('Street          : ${locationInfo.streetAddress}');
      }
      
      if (locationInfo.subLocality != null && locationInfo.subLocality!.isNotEmpty) {
        record.writeln('Area            : ${locationInfo.subLocality}');
      }
      
      if (locationInfo.locality != null && locationInfo.locality!.isNotEmpty) {
        record.writeln('City            : ${locationInfo.locality}');
      }
      
      if (locationInfo.postalCode != null && locationInfo.postalCode!.isNotEmpty) {
        record.writeln('Postal Code     : ${locationInfo.postalCode}');
      }
      
      if (locationInfo.country != null && locationInfo.country!.isNotEmpty) {
        record.writeln('Country         : ${locationInfo.country}');
      }
      
      if (locationInfo.nearestLandmark != null && locationInfo.nearestLandmark!.isNotEmpty) {
        record.writeln('Nearest Landmark: ${locationInfo.nearestLandmark}');
      }
      
      if (locationInfo.famousPlace != null && locationInfo.famousPlace!.isNotEmpty) {
        record.writeln('Famous Place    : ${locationInfo.famousPlace}');
      }
      
      if (locationInfo.distanceToLandmark != null) {
        record.writeln('Distance to LM  : ${locationInfo.distanceToLandmark!.toStringAsFixed(1)} meters');
      }
      
      record.writeln('');
      record.writeln('Recorded At     : ${fullFormatter.format(DateTime.now())}');
      record.writeln(_separator);
      record.writeln('');
      record.writeln('');
      
      // Append to file
      await file.writeAsString(
        record.toString(),
        mode: FileMode.append,
      );
      
      return AttendanceFileSaveResult(
        success: true,
        message: 'Attendance saved successfully',
        filePath: file.path,
        savedAt: DateTime.now(),
      );
    } catch (e) {
      return AttendanceFileSaveResult(
        success: false,
        message: 'Failed to save attendance: $e',
        filePath: null,
        savedAt: null,
      );
    }
  }
  
  /// Read all attendance records from file
  Future<String> readAttendanceHistory() async {
    try {
      final file = await _attendanceFile;
      
      if (!await file.exists()) {
        return 'No attendance records found.';
      }
      
      return await file.readAsString();
    } catch (e) {
      return 'Error reading attendance records: $e';
    }
  }
  
  /// Get the path to the attendance file
  Future<String> getFilePath() async {
    final file = await _attendanceFile;
    return file.path;
  }
  
  /// Check if attendance file exists
  Future<bool> hasRecords() async {
    final file = await _attendanceFile;
    return await file.exists();
  }
  
  /// Get today's attendance records
  Future<List<AttendanceEntry>> getTodayRecords() async {
    try {
      final file = await _attendanceFile;
      
      if (!await file.exists()) {
        return [];
      }
      
      final content = await file.readAsString();
      final today = DateFormat('yyyy-MM-dd').format(DateTime.now());
      
      // Parse records (simplified parsing)
      final records = <AttendanceEntry>[];
      final entries = content.split(_separator);
      
      for (final entry in entries) {
        if (entry.contains('Date            : $today')) {
          // Extract basic info
          final lines = entry.split('\n');
          String? employeeId;
          String? time;
          String? type;
          
          for (final line in lines) {
            if (line.startsWith('Employee ID')) {
              employeeId = line.split(':').last.trim();
            } else if (line.startsWith('Time')) {
              time = line.split(':').sublist(1).join(':').trim();
            } else if (line.startsWith('Type')) {
              type = line.split(':').last.trim();
            }
          }
          
          if (employeeId != null && time != null && type != null) {
            records.add(AttendanceEntry(
              employeeId: employeeId,
              date: today,
              time: time,
              type: type,
            ));
          }
        }
      }
      
      return records;
    } catch (e) {
      return [];
    }
  }
  
  /// Clear all attendance records
  Future<bool> clearRecords() async {
    try {
      final file = await _attendanceFile;
      
      if (await file.exists()) {
        await file.delete();
      }
      
      return true;
    } catch (e) {
      return false;
    }
  }
}

/// Result of saving attendance to file
class AttendanceFileSaveResult {
  final bool success;
  final String message;
  final String? filePath;
  final DateTime? savedAt;
  
  AttendanceFileSaveResult({
    required this.success,
    required this.message,
    required this.filePath,
    required this.savedAt,
  });
}

/// Simple attendance entry for display
class AttendanceEntry {
  final String employeeId;
  final String date;
  final String time;
  final String type;
  
  AttendanceEntry({
    required this.employeeId,
    required this.date,
    required this.time,
    required this.type,
  });
}

