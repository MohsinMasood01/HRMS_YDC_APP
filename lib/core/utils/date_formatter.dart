import 'package:intl/intl.dart';

class DateFormatter {
  static final _date = DateFormat('dd-MMM-yyyy');
  static final _time = DateFormat('hh:mm a');
  static final _dateTime = DateFormat('dd-MMM-yyyy hh:mm a');

  static String formatDate(DateTime date) => _date.format(date);

  static String formatTime(dynamic timeOrDuration) {
    if (timeOrDuration == null) return '--';
    if (timeOrDuration is DateTime) {
      return _time.format(timeOrDuration);
    }
    if (timeOrDuration is Duration) {
      final dt = DateTime(0).add(timeOrDuration);
      return _time.format(dt);
    }
    return '--';
  }

  static String formatDateTime(DateTime dateTime) => _dateTime.format(dateTime);

  static String formatHours(Duration duration) {
    final hours = duration.inHours;
    final minutes = duration.inMinutes.remainder(60);
    return '${hours.toString().padLeft(2, '0')}:${minutes.toString().padLeft(2, '0')}';
  }
}

