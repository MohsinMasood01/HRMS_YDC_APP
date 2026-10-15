/// Islamic Calendar utility for Hajj leave validation
/// 
/// Provides:
/// - Hijri date conversion
/// - Hajj season detection (8th-13th Dhul Hijjah)
/// - Islamic month names
class IslamicCalendar {
  /// Convert Gregorian date to Hijri date
  static HijriDate gregorianToHijri(DateTime gregorian) {
    // Algorithm based on the Kuwaiti algorithm
    final jd = _gregorianToJulian(gregorian);
    return _julianToHijri(jd);
  }

  /// Check if a date falls within Hajj season
  /// Hajj is performed from 8th to 13th of Dhul Hijjah
  static bool isHajjSeason(DateTime date) {
    final hijri = gregorianToHijri(date);
    
    // Dhul Hijjah is month 12
    if (hijri.month != 12) return false;
    
    // Hajj days are 8-13 (with some flexibility for travel)
    // We extend it to 1-15 to allow for preparation and return
    return hijri.day >= 1 && hijri.day <= 15;
  }

  /// Get Hajj season dates for a given Gregorian year
  static HajjSeasonDates getHajjSeasonForYear(int gregorianYear) {
    // Find approximate Hajj dates for the given year
    // Hajj typically falls between June and November
    
    // Start checking from June
    DateTime checkDate = DateTime(gregorianYear, 6, 1);
    DateTime? hajjStart;
    DateTime? hajjEnd;
    
    // Check each day from June to December
    while (checkDate.year == gregorianYear && checkDate.month <= 12) {
      final hijri = gregorianToHijri(checkDate);
      
      // Found start of Dhul Hijjah
      if (hijri.month == 12 && hijri.day == 1 && hajjStart == null) {
        hajjStart = checkDate;
      }
      
      // Found end of Hajj period (15th Dhul Hijjah)
      if (hijri.month == 12 && hijri.day == 15) {
        hajjEnd = checkDate;
        break;
      }
      
      checkDate = checkDate.add(const Duration(days: 1));
    }
    
    return HajjSeasonDates(
      startDate: hajjStart ?? DateTime(gregorianYear, 7, 1),
      endDate: hajjEnd ?? DateTime(gregorianYear, 7, 15),
    );
  }

  /// Validate if a leave date range is valid for Hajj leave
  static HajjValidationResult validateHajjLeave(DateTime fromDate, DateTime toDate) {
    final fromHijri = gregorianToHijri(fromDate);
    final toHijri = gregorianToHijri(toDate);
    
    // Check if the leave overlaps with Hajj season
    bool overlapsHajjSeason = false;
    DateTime checkDate = fromDate;
    
    while (!checkDate.isAfter(toDate)) {
      if (isHajjSeason(checkDate)) {
        overlapsHajjSeason = true;
        break;
      }
      checkDate = checkDate.add(const Duration(days: 1));
    }
    
    if (!overlapsHajjSeason) {
      return HajjValidationResult(
        isValid: false,
        message: 'Hajj leave must include dates during Hajj season '
            '(8th-13th Dhul Hijjah). Current Hajj season dates should be verified.',
        fromHijri: fromHijri,
        toHijri: toHijri,
      );
    }
    
    return HajjValidationResult(
      isValid: true,
      message: 'Leave dates fall within Hajj season',
      fromHijri: fromHijri,
      toHijri: toHijri,
    );
  }

  /// Get Islamic month name
  static String getIslamicMonthName(int month) {
    const months = [
      'Muharram',
      'Safar',
      'Rabi al-Awwal',
      'Rabi al-Thani',
      'Jumada al-Awwal',
      'Jumada al-Thani',
      'Rajab',
      'Shaban',
      'Ramadan',
      'Shawwal',
      'Dhul Qadah',
      'Dhul Hijjah',
    ];
    
    if (month < 1 || month > 12) return 'Unknown';
    return months[month - 1];
  }

  /// Format Hijri date as string
  static String formatHijriDate(HijriDate date) {
    return '${date.day} ${getIslamicMonthName(date.month)} ${date.year} AH';
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // PRIVATE CONVERSION METHODS
  // ═══════════════════════════════════════════════════════════════════════════

  static int _gregorianToJulian(DateTime date) {
    int year = date.year;
    int month = date.month;
    int day = date.day;

    if (month <= 2) {
      year -= 1;
      month += 12;
    }

    int a = (year / 100).floor();
    int b = 2 - a + (a / 4).floor();

    return (365.25 * (year + 4716)).floor() +
        (30.6001 * (month + 1)).floor() +
        day +
        b -
        1524;
  }

  static HijriDate _julianToHijri(int jd) {
    int l = jd - 1948440 + 10632;
    int n = ((l - 1) / 10631).floor();
    l = l - 10631 * n + 354;
    
    int j = (((10985 - l) / 5316).floor()) * ((((50 * l) / 17719).floor())) +
        (((l / 5670).floor())) * ((((43 * l) / 15238).floor()));
    l = l - (((30 - j) / 15).floor()) * (((17719 * j) / 50).floor()) -
        (((j / 16).floor())) * (((15238 * j) / 43).floor()) + 29;
    
    int month = ((24 * l) / 709).floor();
    int day = l - ((709 * month) / 24).floor();
    int year = 30 * n + j - 30;

    return HijriDate(year: year, month: month, day: day);
  }
}

/// Hijri (Islamic) date
class HijriDate {
  const HijriDate({
    required this.year,
    required this.month,
    required this.day,
  });

  final int year;
  final int month;
  final int day;

  @override
  String toString() => IslamicCalendar.formatHijriDate(this);
}

/// Hajj season dates
class HajjSeasonDates {
  const HajjSeasonDates({
    required this.startDate,
    required this.endDate,
  });

  final DateTime startDate;
  final DateTime endDate;
}

/// Result of Hajj leave validation
class HajjValidationResult {
  const HajjValidationResult({
    required this.isValid,
    required this.message,
    required this.fromHijri,
    required this.toHijri,
  });

  final bool isValid;
  final String message;
  final HijriDate fromHijri;
  final HijriDate toHijri;
}

