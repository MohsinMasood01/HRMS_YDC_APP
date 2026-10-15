import 'package:equatable/equatable.dart';
import 'package:intl/intl.dart';

/// Enhanced profile entity with additional fields
///
/// Includes:
/// - Profile picture
/// - Gender
/// - Emergency contact
/// - Day types (Rest/General)
class EnhancedProfileEntity extends Equatable {
  const EnhancedProfileEntity({
    required this.id,
    required this.employeeCode,
    required this.name,
    required this.email,
    required this.phoneNumber,
    required this.gender,
    required this.dateOfBirth,
    required this.joiningDate,
    required this.department,
    required this.designation,
    required this.cadre,
    required this.location,
    required this.branch,
    required this.cardNumber,
    this.profilePictureUrl,
    this.emergencyContact,
    this.address,
    this.reportingTo,
    this.workSchedule,
    this.fatherName,
    this.nicNo,
    this.eobiNo,
    this.uicCardNo,
    this.salary,
    this.managerAboveSts,
    this.confirmationDate,
    this.companyAccommodation,
    this.compcnm,
    this.compc,
  });

  final String id;
  final String employeeCode;
  final String name;
  final String email;
  final String phoneNumber;

  /// Gender: 'M' for Male, 'F' for Female
  final String gender;

  /// Raw date strings as returned by backend (e.g. "27-oct-2025").
  /// We keep these as-is for display and only parse when needed.
  final String dateOfBirth;
  final String joiningDate;
  final String department;
  final String designation;
  final String cadre;
  final String location;
  final String branch;
  final String cardNumber;

  /// URL to profile picture (can be local path or remote URL)
  final String? profilePictureUrl;

  /// Emergency contact information
  final EmergencyContact? emergencyContact;

  /// Home address
  final Address? address;

  /// Reporting manager info
  final ReportingManager? reportingTo;

  /// Work schedule configuration
  final WorkSchedule? workSchedule;

  // Additional fields from API
  final String? fatherName;
  final String? nicNo;
  final String? eobiNo;
  final String? uicCardNo;
  final int? salary;
  final String? managerAboveSts;
  final String? confirmationDate;
  final String? companyAccommodation;
  final String? compcnm;
  final int? compc;

  /// Whether the employee is male
  bool get isMale => gender.toUpperCase() == 'M';

  /// Whether the employee is female
  bool get isFemale => gender.toUpperCase() == 'F';

  /// Get gender display text
  String get genderText => isMale ? 'Male' : 'Female';

  /// Get years of service (integer, for backward compatibility)
  int get yearsOfService {
    final parsed = _parseBackendDate(joiningDate);
    if (parsed == null) return 0;
    return DateTime.now().difference(parsed).inDays ~/ 365;
  }

  /// Get formatted experience string (e.g., "1 year 6 months", "3 months", "1 year")
  String get experienceFormatted {
    final parsed = _parseBackendDate(joiningDate);
    if (parsed == null) return 'Not available';

    final now = DateTime.now();

    // Calculate total months
    int totalMonths =
        (now.year - parsed.year) * 12 + (now.month - parsed.month);

    // Adjust if current day is before joining day in the month
    if (now.day < parsed.day) {
      totalMonths--;
    }

    // Calculate years and remaining months
    final years = totalMonths ~/ 12;
    final months = totalMonths % 12;

    // Format the string
    if (years == 0 && months == 0) {
      return 'Less than 1 month';
    } else if (years == 0) {
      return months == 1 ? '1 month' : '$months months';
    } else if (months == 0) {
      return years == 1 ? '1 year' : '$years years';
    } else {
      final yearText = years == 1 ? '1 year' : '$years years';
      final monthText = months == 1 ? '1 month' : '$months months';
      return '$yearText $monthText';
    }
  }

  /// Get day type for a given date
  DayType getDayType(DateTime date) {
    // Default: Saturday and Sunday are rest days
    if (date.weekday == DateTime.saturday || date.weekday == DateTime.sunday) {
      return DayType.rest;
    }

    // Use custom schedule if available
    if (workSchedule != null) {
      return workSchedule!.getDayType(date.weekday);
    }

    return DayType.general;
  }

  /// Get initials for avatar
  String get initials {
    final parts = name.split(' ');
    if (parts.length >= 2) {
      return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    }
    return name.isNotEmpty ? name[0].toUpperCase() : '?';
  }

  EnhancedProfileEntity copyWith({
    String? id,
    String? employeeCode,
    String? name,
    String? email,
    String? phoneNumber,
    String? gender,
    String? dateOfBirth,
    String? joiningDate,
    String? department,
    String? designation,
    String? cadre,
    String? location,
    String? branch,
    String? cardNumber,
    String? profilePictureUrl,
    EmergencyContact? emergencyContact,
    Address? address,
    ReportingManager? reportingTo,
    WorkSchedule? workSchedule,
    String? fatherName,
    String? nicNo,
    String? eobiNo,
    String? uicCardNo,
    int? salary,
    String? managerAboveSts,
    String? confirmationDate,
    String? companyAccommodation,
    String? compcnm,
    int? compc,
  }) {
    return EnhancedProfileEntity(
      id: id ?? this.id,
      employeeCode: employeeCode ?? this.employeeCode,
      name: name ?? this.name,
      email: email ?? this.email,
      phoneNumber: phoneNumber ?? this.phoneNumber,
      gender: gender ?? this.gender,
      dateOfBirth: dateOfBirth ?? this.dateOfBirth,
      joiningDate: joiningDate ?? this.joiningDate,
      department: department ?? this.department,
      designation: designation ?? this.designation,
      cadre: cadre ?? this.cadre,
      location: location ?? this.location,
      branch: branch ?? this.branch,
      cardNumber: cardNumber ?? this.cardNumber,
      profilePictureUrl: profilePictureUrl ?? this.profilePictureUrl,
      emergencyContact: emergencyContact ?? this.emergencyContact,
      address: address ?? this.address,
      reportingTo: reportingTo ?? this.reportingTo,
      workSchedule: workSchedule ?? this.workSchedule,
      fatherName: fatherName ?? this.fatherName,
      nicNo: nicNo ?? this.nicNo,
      eobiNo: eobiNo ?? this.eobiNo,
      uicCardNo: uicCardNo ?? this.uicCardNo,
      salary: salary ?? this.salary,
      managerAboveSts: managerAboveSts ?? this.managerAboveSts,
      confirmationDate: confirmationDate ?? this.confirmationDate,
      companyAccommodation: companyAccommodation ?? this.companyAccommodation,
      compcnm: compcnm ?? this.compcnm,
      compc: compc ?? this.compc,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'employee_code': employeeCode,
      'name': name,
      'email': email,
      'phone_number': phoneNumber,
      'gender': gender,
      'date_of_birth': dateOfBirth,
      'joining_date': joiningDate,
      'department': department,
      'designation': designation,
      'cadre': cadre,
      'location': location,
      'branch': branch,
      'card_number': cardNumber,
      'profile_picture_url': profilePictureUrl,
      'emergency_contact': emergencyContact?.toJson(),
      'address': address?.toJson(),
      'reporting_to': reportingTo?.toJson(),
      'work_schedule': workSchedule?.toJson(),
      'father_name': fatherName,
      'nic_no': nicNo,
      'eobi_no': eobiNo,
      'uic_card_no': uicCardNo,
      'salary': salary,
      'manager_above_sts': managerAboveSts,
      'confirmation_date': confirmationDate,
      'company_accomodation': companyAccommodation,
      'compcnm': compcnm,
      'compc': compc,
    };
  }

  factory EnhancedProfileEntity.fromJson(Map<String, dynamic> json) {
    return EnhancedProfileEntity(
      id: json['id'] as String,
      employeeCode: json['employee_code'] as String,
      name: json['name'] as String,
      email: json['email'] as String,
      phoneNumber: json['phone_number'] as String,
      gender: json['gender'] as String,
      dateOfBirth: json['date_of_birth'] as String,
      joiningDate: json['joining_date'] as String,
      department: json['department'] as String,
      designation: json['designation'] as String,
      cadre: json['cadre'] as String,
      location: json['location'] as String,
      branch: json['branch'] as String,
      cardNumber: json['card_number'] as String,
      profilePictureUrl: json['profile_picture_url'] as String?,
      emergencyContact: json['emergency_contact'] != null
          ? EmergencyContact.fromJson(
              json['emergency_contact'] as Map<String, dynamic>,
            )
          : null,
      address: json['address'] != null
          ? Address.fromJson(json['address'] as Map<String, dynamic>)
          : null,
      reportingTo: json['reporting_to'] != null
          ? ReportingManager.fromJson(
              json['reporting_to'] as Map<String, dynamic>,
            )
          : null,
      workSchedule: json['work_schedule'] != null
          ? WorkSchedule.fromJson(json['work_schedule'] as Map<String, dynamic>)
          : null,
      fatherName: json['father_name'] as String?,
      nicNo: json['nic_no'] as String?,
      eobiNo: json['eobi_no'] as String?,
      uicCardNo: json['uic_card_no'] as String?,
      salary: json['salary'] as int?,
      managerAboveSts: json['manager_above_sts'] as String?,
      confirmationDate: json['confirmation_date'] as String?,
      companyAccommodation: json['company_accomodation'] as String?,
      compcnm: json['compcnm'] as String?,
      compc: json['compc'] as int?,
    );
  }

  @override
  List<Object?> get props => [
    id,
    employeeCode,
    name,
    email,
    phoneNumber,
    gender,
    dateOfBirth,
    joiningDate,
    department,
    designation,
    cadre,
    location,
    branch,
    cardNumber,
    profilePictureUrl,
    emergencyContact,
    address,
    reportingTo,
    workSchedule,
    fatherName,
    nicNo,
    eobiNo,
    uicCardNo,
    salary,
    managerAboveSts,
    confirmationDate,
    companyAccommodation,
    compcnm,
    compc,
  ];
}

/// Helper to parse both ISO strings and "dd-MMM-yyyy" backend strings.
DateTime? _parseBackendDate(String? value) {
  if (value == null) return null;
  final trimmed = value.trim();
  if (trimmed.isEmpty || trimmed == '-') return null;

  // Try ISO first
  try {
    return DateTime.parse(trimmed);
  } catch (_) {
    // Try ORDS-style "dd-MMM-yyyy" (e.g. "27-oct-2025")
    try {
      final fmt = DateFormat('dd-MMM-yyyy');
      return fmt.parse(trimmed);
    } catch (_) {
      return null;
    }
  }
}

/// Emergency contact information
class EmergencyContact extends Equatable {
  const EmergencyContact({
    required this.name,
    required this.relationship,
    required this.phoneNumber,
    this.alternatePhone,
    this.address,
  });

  final String name;
  final String relationship;
  final String phoneNumber;
  final String? alternatePhone;
  final String? address;

  Map<String, dynamic> toJson() => {
    'name': name,
    'relationship': relationship,
    'phone_number': phoneNumber,
    'alternate_phone': alternatePhone,
    'address': address,
  };

  factory EmergencyContact.fromJson(Map<String, dynamic> json) {
    return EmergencyContact(
      name: json['name'] as String,
      relationship: json['relationship'] as String,
      phoneNumber: json['phone_number'] as String,
      alternatePhone: json['alternate_phone'] as String?,
      address: json['address'] as String?,
    );
  }

  @override
  List<Object?> get props => [
    name,
    relationship,
    phoneNumber,
    alternatePhone,
    address,
  ];
}

/// Home address
class Address extends Equatable {
  const Address({
    required this.line1,
    this.line2,
    required this.city,
    required this.state,
    required this.country,
    this.postalCode,
  });

  final String line1;
  final String? line2;
  final String city;
  final String state;
  final String country;
  final String? postalCode;

  String get fullAddress {
    final parts = [line1];
    if (line2 != null && line2!.isNotEmpty) parts.add(line2!);
    parts.add(city);
    parts.add(state);
    parts.add(country);
    if (postalCode != null && postalCode!.isNotEmpty) parts.add(postalCode!);
    return parts.join(', ');
  }

  Map<String, dynamic> toJson() => {
    'line1': line1,
    'line2': line2,
    'city': city,
    'state': state,
    'country': country,
    'postal_code': postalCode,
  };

  factory Address.fromJson(Map<String, dynamic> json) {
    return Address(
      line1: json['line1'] as String,
      line2: json['line2'] as String?,
      city: json['city'] as String,
      state: json['state'] as String,
      country: json['country'] as String,
      postalCode: json['postal_code'] as String?,
    );
  }

  @override
  List<Object?> get props => [line1, line2, city, state, country, postalCode];
}

/// Reporting manager information
class ReportingManager extends Equatable {
  const ReportingManager({
    required this.id,
    required this.name,
    required this.designation,
    this.phoneNumber,
    this.email,
  });

  final String id;
  final String name;
  final String designation;
  final String? phoneNumber;
  final String? email;

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'designation': designation,
    'phone_number': phoneNumber,
    'email': email,
  };

  factory ReportingManager.fromJson(Map<String, dynamic> json) {
    return ReportingManager(
      id: json['id'] as String,
      name: json['name'] as String,
      designation: json['designation'] as String,
      phoneNumber: json['phone_number'] as String?,
      email: json['email'] as String?,
    );
  }

  @override
  List<Object?> get props => [id, name, designation, phoneNumber, email];
}

/// Work schedule configuration
class WorkSchedule extends Equatable {
  const WorkSchedule({
    required this.weeklyOffDays,
    this.shiftStartTime,
    this.shiftEndTime,
    this.flexibleTiming = false,
    this.graceMinutes = 10,
  });

  /// Days of week that are off (1=Monday, 7=Sunday)
  final List<int> weeklyOffDays;

  /// Standard shift start time (e.g., '09:00')
  final String? shiftStartTime;

  /// Standard shift end time (e.g., '18:00')
  final String? shiftEndTime;

  /// Whether flexible timing is allowed
  final bool flexibleTiming;

  /// Grace period in minutes for late arrival
  final int graceMinutes;

  DayType getDayType(int weekday) {
    if (weeklyOffDays.contains(weekday)) {
      return DayType.rest;
    }
    return DayType.general;
  }

  Map<String, dynamic> toJson() => {
    'weekly_off_days': weeklyOffDays,
    'shift_start_time': shiftStartTime,
    'shift_end_time': shiftEndTime,
    'flexible_timing': flexibleTiming,
    'grace_minutes': graceMinutes,
  };

  factory WorkSchedule.fromJson(Map<String, dynamic> json) {
    return WorkSchedule(
      weeklyOffDays: (json['weekly_off_days'] as List<dynamic>).cast<int>(),
      shiftStartTime: json['shift_start_time'] as String?,
      shiftEndTime: json['shift_end_time'] as String?,
      flexibleTiming: json['flexible_timing'] as bool? ?? false,
      graceMinutes: json['grace_minutes'] as int? ?? 10,
    );
  }

  /// Builds a schedule from an HRMS profile payload.
  ///
  /// The employee's real roster comes from the HRMS web side, which exposes it
  /// under several different key names (and sometimes nested under
  /// `work_schedule` / `schedule` / `shift`). Anything missing falls back to
  /// [defaultSchedule], and `null` is returned when the payload carries no
  /// schedule information at all so the caller can decide what to show.
  static WorkSchedule? fromApi(Map<String, dynamic> json) {
    final nested = (json['work_schedule'] ??
        json['schedule'] ??
        json['shift'] ??
        json['roster']);
    final Map<String, dynamic> src = nested is Map<String, dynamic>
        ? {...json, ...nested}
        : json;

    String? pick(List<String> keys) {
      for (final key in keys) {
        final value = src[key];
        if (value == null) continue;
        final text = value.toString().trim();
        if (text.isNotEmpty && text != '-' && text.toLowerCase() != 'null') {
          return text;
        }
      }
      return null;
    }

    final start = pick([
      'shift_start_time',
      'shift_start',
      'shift_in_time',
      'time_in',
      'start_time',
      'in_time',
      'duty_start',
    ]);
    final end = pick([
      'shift_end_time',
      'shift_end',
      'shift_out_time',
      'time_out',
      'end_time',
      'out_time',
      'duty_end',
    ]);
    final graceText = pick([
      'grace_minutes',
      'grace_time',
      'grace_period',
      'grace',
    ]);
    final flexibleText = pick([
      'flexible_timing',
      'is_flexible',
      'flexi_timing',
      'flexible',
    ]);
    final offDays = _parseWeeklyOffDays(
      src['weekly_off_days'] ??
          src['weekly_off'] ??
          src['off_days'] ??
          src['rest_days'] ??
          src['weekly_holidays'],
    );

    if (start == null &&
        end == null &&
        graceText == null &&
        flexibleText == null &&
        offDays == null) {
      return null;
    }

    return WorkSchedule(
      weeklyOffDays: offDays ?? defaultSchedule.weeklyOffDays,
      shiftStartTime: start ?? defaultSchedule.shiftStartTime,
      shiftEndTime: end ?? defaultSchedule.shiftEndTime,
      flexibleTiming:
          flexibleText != null && _truthy(flexibleText),
      graceMinutes: graceText != null
          ? (int.tryParse(graceText.replaceAll(RegExp(r'[^0-9]'), '')) ??
              defaultSchedule.graceMinutes)
          : defaultSchedule.graceMinutes,
    );
  }

  static bool _truthy(String value) {
    final v = value.toLowerCase();
    return v == 'true' || v == 'y' || v == 'yes' || v == '1';
  }

  /// Accepts a list of ints, a list/CSV of day names, or ISO weekday numbers.
  static List<int>? _parseWeeklyOffDays(dynamic raw) {
    if (raw == null) return null;
    final parts = raw is List
        ? raw.map((e) => e.toString())
        : raw.toString().split(RegExp(r'[,;|]'));
    const names = {
      'mon': 1, 'monday': 1,
      'tue': 2, 'tues': 2, 'tuesday': 2,
      'wed': 3, 'weds': 3, 'wednesday': 3,
      'thu': 4, 'thur': 4, 'thurs': 4, 'thursday': 4,
      'fri': 5, 'friday': 5,
      'sat': 6, 'saturday': 6,
      'sun': 7, 'sunday': 7,
    };
    final days = <int>{};
    for (final part in parts) {
      final text = part.trim().toLowerCase();
      if (text.isEmpty) continue;
      final asInt = int.tryParse(text);
      if (asInt != null && asInt >= 1 && asInt <= 7) {
        days.add(asInt);
        continue;
      }
      final mapped = names[text];
      if (mapped != null) days.add(mapped);
    }
    if (days.isEmpty) return null;
    final sorted = days.toList()..sort();
    return sorted;
  }

  /// Default schedule (Saturday, Sunday off)
  static const WorkSchedule defaultSchedule = WorkSchedule(
    weeklyOffDays: [6, 7], // Saturday, Sunday
    shiftStartTime: '09:30', // 09:30 AM
    shiftEndTime: '18:00', // 06:00 PM
    graceMinutes: 10, // 10 minutes grace period
  );

  @override
  List<Object?> get props => [
    weeklyOffDays,
    shiftStartTime,
    shiftEndTime,
    flexibleTiming,
    graceMinutes,
  ];
}

/// Day type classification
enum DayType {
  /// General working day (G)
  general,

  /// Rest day / Weekly off (R)
  rest,

  /// Holiday (H)
  holiday,
}

extension DayTypeExtension on DayType {
  String get code {
    switch (this) {
      case DayType.general:
        return 'G';
      case DayType.rest:
        return 'R';
      case DayType.holiday:
        return 'H';
    }
  }

  String get displayName {
    switch (this) {
      case DayType.general:
        return 'General';
      case DayType.rest:
        return 'Rest';
      case DayType.holiday:
        return 'Holiday';
    }
  }
}
