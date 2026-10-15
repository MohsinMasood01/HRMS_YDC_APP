import 'package:equatable/equatable.dart';

/// Represents detailed location information for attendance marking
///
/// Contains:
/// - GPS coordinates (latitude, longitude)
/// - Address components (street, city, country)
/// - Nearest landmark/famous place
/// - Accuracy and timestamp
class LocationInfo extends Equatable {
  const LocationInfo({
    required this.latitude,
    required this.longitude,
    required this.accuracy,
    required this.timestamp,
    this.address,
    this.streetAddress,
    this.locality,
    this.subLocality,
    this.postalCode,
    this.country,
    this.nearestLandmark,
    this.famousPlace,
    this.distanceToLandmark,
    this.formattedAddress,
  });

  /// GPS latitude coordinate
  final double latitude;

  /// GPS longitude coordinate
  final double longitude;

  /// GPS accuracy in meters
  final double accuracy;

  /// Timestamp when location was captured
  final DateTime timestamp;

  /// Full address string
  final String? address;

  /// Street name and number
  final String? streetAddress;

  /// City/town name
  final String? locality;

  /// Neighborhood/area name
  final String? subLocality;

  /// Postal/ZIP code
  final String? postalCode;

  /// Country name
  final String? country;

  /// Nearest notable landmark
  final String? nearestLandmark;

  /// Famous place nearby (if any)
  final String? famousPlace;

  /// Distance to the nearest landmark in meters
  final double? distanceToLandmark;

  /// Human-readable formatted address
  final String? formattedAddress;

  /// Returns a short location description for display
  String get shortDescription {
    if (nearestLandmark != null && nearestLandmark!.isNotEmpty) {
      return 'Near $nearestLandmark';
    }
    if (subLocality != null && subLocality!.isNotEmpty) {
      return subLocality!;
    }
    if (locality != null && locality!.isNotEmpty) {
      return locality!;
    }
    return '${latitude.toStringAsFixed(6)}, ${longitude.toStringAsFixed(6)}';
  }

  /// Returns the full display address
  String get displayAddress {
    if (formattedAddress != null && formattedAddress!.isNotEmpty) {
      return formattedAddress!;
    }

    final parts = <String>[];
    if (streetAddress != null && streetAddress!.isNotEmpty) {
      parts.add(streetAddress!);
    }
    if (subLocality != null && subLocality!.isNotEmpty) {
      parts.add(subLocality!);
    }
    if (locality != null && locality!.isNotEmpty) {
      parts.add(locality!);
    }
    if (country != null && country!.isNotEmpty) {
      parts.add(country!);
    }

    return parts.isNotEmpty ? parts.join(', ') : shortDescription;
  }

  /// Creates an empty LocationInfo with just coordinates
  factory LocationInfo.coordinates({
    required double latitude,
    required double longitude,
    required double accuracy,
  }) {
    return LocationInfo(
      latitude: latitude,
      longitude: longitude,
      accuracy: accuracy,
      timestamp: DateTime.now(),
    );
  }

  /// Creates a copy with updated fields
  LocationInfo copyWith({
    double? latitude,
    double? longitude,
    double? accuracy,
    DateTime? timestamp,
    String? address,
    String? streetAddress,
    String? locality,
    String? subLocality,
    String? postalCode,
    String? country,
    String? nearestLandmark,
    String? famousPlace,
    double? distanceToLandmark,
    String? formattedAddress,
  }) {
    return LocationInfo(
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      accuracy: accuracy ?? this.accuracy,
      timestamp: timestamp ?? this.timestamp,
      address: address ?? this.address,
      streetAddress: streetAddress ?? this.streetAddress,
      locality: locality ?? this.locality,
      subLocality: subLocality ?? this.subLocality,
      postalCode: postalCode ?? this.postalCode,
      country: country ?? this.country,
      nearestLandmark: nearestLandmark ?? this.nearestLandmark,
      famousPlace: famousPlace ?? this.famousPlace,
      distanceToLandmark: distanceToLandmark ?? this.distanceToLandmark,
      formattedAddress: formattedAddress ?? this.formattedAddress,
    );
  }

  /// Convert to JSON for API requests
  Map<String, dynamic> toJson() {
    return {
      'latitude': latitude,
      'longitude': longitude,
      'accuracy': accuracy,
      'timestamp': timestamp.toIso8601String(),
      'address': address,
      'street_address': streetAddress,
      'locality': locality,
      'sub_locality': subLocality,
      'postal_code': postalCode,
      'country': country,
      'nearest_landmark': nearestLandmark,
      'famous_place': famousPlace,
      'distance_to_landmark': distanceToLandmark,
      'formatted_address': formattedAddress,
    };
  }

  /// Create from JSON response
  factory LocationInfo.fromJson(Map<String, dynamic> json) {
    return LocationInfo(
      latitude: (json['latitude'] as num).toDouble(),
      longitude: (json['longitude'] as num).toDouble(),
      accuracy: (json['accuracy'] as num?)?.toDouble() ?? 0,
      timestamp: json['timestamp'] != null
          ? DateTime.parse(json['timestamp'] as String)
          : DateTime.now(),
      address: json['address'] as String?,
      streetAddress: json['street_address'] as String?,
      locality: json['locality'] as String?,
      subLocality: json['sub_locality'] as String?,
      postalCode: json['postal_code'] as String?,
      country: json['country'] as String?,
      nearestLandmark: json['nearest_landmark'] as String?,
      famousPlace: json['famous_place'] as String?,
      distanceToLandmark: (json['distance_to_landmark'] as num?)?.toDouble(),
      formattedAddress: json['formatted_address'] as String?,
    );
  }

  @override
  List<Object?> get props => [
    latitude,
    longitude,
    accuracy,
    timestamp,
    address,
    streetAddress,
    locality,
    subLocality,
    postalCode,
    country,
    nearestLandmark,
    famousPlace,
    distanceToLandmark,
    formattedAddress,
  ];

  @override
  String toString() {
    return 'LocationInfo('
        'lat: ${latitude.toStringAsFixed(6)}, '
        'lng: ${longitude.toStringAsFixed(6)}, '
        'accuracy: ${accuracy.toStringAsFixed(1)}m, '
        'landmark: $nearestLandmark, '
        'address: $displayAddress)';
  }
}
