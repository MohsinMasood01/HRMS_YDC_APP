import 'dart:math' as math;

import 'package:dio/dio.dart';
import 'package:geolocator/geolocator.dart';

import '../../features/attendance/domain/entities/location_info.dart';
import 'location_service.dart';

/// Service for reverse geocoding - converting coordinates to addresses and landmarks
/// 
/// This service provides:
/// - Reverse geocoding (coordinates to address)
/// - Nearby landmark/place detection
/// - Address formatting
/// 
/// Uses OpenStreetMap's Nominatim API (free, no API key required)
class GeocodingService {
  GeocodingService(this._locationService) : _dio = Dio();

  final LocationService _locationService;
  final Dio _dio;

  // Nominatim API base URL
  static const String _nominatimBaseUrl = 'https://nominatim.openstreetmap.org';

  /// Get complete location info including address and nearby landmarks
  Future<LocationInfo> getLocationInfo() async {
    // Get current position
    final position = await _locationService.currentPosition();
    
    // Create base location info
    var locationInfo = LocationInfo.coordinates(
      latitude: position.latitude,
      longitude: position.longitude,
      accuracy: position.accuracy,
    );

    // Get address details via reverse geocoding
    try {
      final addressDetails = await reverseGeocode(
        position.latitude, 
        position.longitude,
      );
      
      locationInfo = locationInfo.copyWith(
        address: addressDetails['display_name'] as String?,
        formattedAddress: addressDetails['display_name'] as String?,
        streetAddress: _extractStreetAddress(addressDetails),
        locality: addressDetails['address']?['city'] as String? ?? 
                 addressDetails['address']?['town'] as String? ??
                 addressDetails['address']?['village'] as String?,
        subLocality: addressDetails['address']?['suburb'] as String? ??
                    addressDetails['address']?['neighbourhood'] as String?,
        postalCode: addressDetails['address']?['postcode'] as String?,
        country: addressDetails['address']?['country'] as String?,
      );
    } catch (e) {
      // Continue with coordinates only if geocoding fails
    }

    // Get nearby landmarks
    try {
      final landmarks = await getNearbyLandmarks(
        position.latitude,
        position.longitude,
      );
      
      if (landmarks.isNotEmpty) {
        final nearest = landmarks.first;
        locationInfo = locationInfo.copyWith(
          nearestLandmark: nearest['name'] as String?,
          famousPlace: _findFamousPlace(landmarks),
          distanceToLandmark: nearest['distance'] as double?,
        );
      }
    } catch (e) {
      // Continue without landmarks if search fails
    }

    return locationInfo;
  }

  /// Reverse geocode coordinates to get address details
  Future<Map<String, dynamic>> reverseGeocode(
    double latitude, 
    double longitude,
  ) async {
    try {
      final response = await _dio.get(
        '$_nominatimBaseUrl/reverse',
        queryParameters: {
          'lat': latitude,
          'lon': longitude,
          'format': 'json',
          'addressdetails': 1,
          'zoom': 18,
        },
        options: Options(
          headers: {
            'User-Agent': 'LMS_APP/1.0',
            'Accept-Language': 'en',
          },
        ),
      );

      if (response.statusCode == 200) {
        return response.data as Map<String, dynamic>;
      }
      
      throw GeocodingException('Failed to reverse geocode: ${response.statusCode}');
    } on DioException catch (e) {
      throw GeocodingException('Network error during geocoding: ${e.message}');
    }
  }

  /// Get nearby landmarks and points of interest
  Future<List<Map<String, dynamic>>> getNearbyLandmarks(
    double latitude,
    double longitude, {
    int radiusMeters = 500,
    int limit = 5,
  }) async {
    try {
      // Calculate bounding box for search
      final bbox = _calculateBoundingBox(latitude, longitude, radiusMeters);
      
      // Search for nearby POIs using Nominatim
      final response = await _dio.get(
        '$_nominatimBaseUrl/search',
        queryParameters: {
          'q': '*',
          'viewbox': bbox,
          'bounded': 1,
          'format': 'json',
          'limit': limit * 2, // Request more to filter
          'addressdetails': 1,
          'extratags': 1,
        },
        options: Options(
          headers: {
            'User-Agent': 'LMS_APP/1.0',
            'Accept-Language': 'en',
          },
        ),
      );

      if (response.statusCode == 200) {
        final results = response.data as List<dynamic>;
        
        // Filter and sort by distance
        final landmarks = results
            .map((item) => _processLandmark(item as Map<String, dynamic>, latitude, longitude))
            .where((item) => item['name'] != null && (item['name'] as String).isNotEmpty)
            .toList();
        
        // Sort by distance
        landmarks.sort((a, b) => 
            (a['distance'] as double).compareTo(b['distance'] as double));
        
        return landmarks.take(limit).toList();
      }
      
      return [];
    } on DioException {
      // Fallback to alternative landmark search
      return _getFallbackLandmarks(latitude, longitude);
    }
  }

  /// Search for specific types of places nearby
  Future<List<Map<String, dynamic>>> searchNearbyPlaces(
    double latitude,
    double longitude,
    String placeType, {
    int radiusMeters = 1000,
  }) async {
    try {
      final response = await _dio.get(
        '$_nominatimBaseUrl/search',
        queryParameters: {
          'q': placeType,
          'lat': latitude,
          'lon': longitude,
          'format': 'json',
          'limit': 10,
          'addressdetails': 1,
        },
        options: Options(
          headers: {
            'User-Agent': 'LMS_APP/1.0',
            'Accept-Language': 'en',
          },
        ),
      );

      if (response.statusCode == 200) {
        final results = response.data as List<dynamic>;
        return results
            .map((item) => _processLandmark(item as Map<String, dynamic>, latitude, longitude))
            .where((item) => (item['distance'] as double) <= radiusMeters)
            .toList();
      }
      
      return [];
    } catch (e) {
      return [];
    }
  }

  /// Format address for display
  String formatAddress(Map<String, dynamic> addressDetails) {
    final parts = <String>[];
    final address = addressDetails['address'] as Map<String, dynamic>?;
    
    if (address == null) {
      return addressDetails['display_name'] as String? ?? 'Unknown location';
    }

    // Add street
    final street = address['road'] ?? address['street'];
    if (street != null) {
      final houseNumber = address['house_number'];
      parts.add(houseNumber != null ? '$houseNumber $street' : street as String);
    }

    // Add neighborhood/suburb
    final suburb = address['suburb'] ?? address['neighbourhood'];
    if (suburb != null) parts.add(suburb as String);

    // Add city
    final city = address['city'] ?? address['town'] ?? address['village'];
    if (city != null) parts.add(city as String);

    // Add postal code
    final postcode = address['postcode'];
    if (postcode != null) parts.add(postcode as String);

    // Add country
    final country = address['country'];
    if (country != null) parts.add(country as String);

    return parts.join(', ');
  }

  /// Get a short location description
  String getShortDescription(Map<String, dynamic> addressDetails) {
    final address = addressDetails['address'] as Map<String, dynamic>?;
    if (address == null) return 'Unknown location';

    // Try different combinations for a short description
    final suburb = address['suburb'] ?? address['neighbourhood'];
    final city = address['city'] ?? address['town'] ?? address['village'];
    
    if (suburb != null && city != null) {
      return '$suburb, $city';
    }
    if (city != null) return city as String;
    if (suburb != null) return suburb as String;
    
    return addressDetails['display_name'] as String? ?? 'Unknown location';
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // PRIVATE HELPER METHODS
  // ═══════════════════════════════════════════════════════════════════════════

  String? _extractStreetAddress(Map<String, dynamic> details) {
    final address = details['address'] as Map<String, dynamic>?;
    if (address == null) return null;

    final road = address['road'] ?? address['street'];
    final houseNumber = address['house_number'];

    if (road != null) {
      return houseNumber != null ? '$houseNumber $road' : road as String;
    }
    return null;
  }

  String? _findFamousPlace(List<Map<String, dynamic>> landmarks) {
    // Look for tourism, historic, or notable places
    const famousCategories = ['tourism', 'historic', 'amenity'];
    
    for (final landmark in landmarks) {
      final category = landmark['category'] as String?;
      if (category != null && famousCategories.contains(category)) {
        return landmark['name'] as String?;
      }
    }
    
    return null;
  }

  String _calculateBoundingBox(double lat, double lon, int radiusMeters) {
    // Approximate degrees per meter at given latitude
    const metersPerDegLat = 111320.0;
    final metersPerDegLon = 111320.0 * math.cos(lat * math.pi / 180);

    final deltaLat = radiusMeters / metersPerDegLat;
    final deltaLon = radiusMeters / metersPerDegLon;

    // viewbox format: left,top,right,bottom (min_lon,max_lat,max_lon,min_lat)
    return '${lon - deltaLon},${lat + deltaLat},${lon + deltaLon},${lat - deltaLat}';
  }

  Map<String, dynamic> _processLandmark(
    Map<String, dynamic> item, 
    double userLat, 
    double userLon,
  ) {
    final lat = double.tryParse(item['lat']?.toString() ?? '') ?? 0;
    final lon = double.tryParse(item['lon']?.toString() ?? '') ?? 0;
    
    final distance = Geolocator.distanceBetween(userLat, userLon, lat, lon);

    return {
      'name': item['display_name']?.toString().split(',').first ?? item['name'],
      'full_name': item['display_name'],
      'category': item['category'] ?? item['type'],
      'type': item['type'],
      'latitude': lat,
      'longitude': lon,
      'distance': distance,
      'address': item['address'],
    };
  }

  List<Map<String, dynamic>> _getFallbackLandmarks(double lat, double lon) {
    // Return empty list as fallback - could be enhanced with cached/local data
    return [];
  }
}

/// Exception for geocoding errors
class GeocodingException implements Exception {
  final String message;

  GeocodingException(this.message);

  @override
  String toString() => 'GeocodingException: $message';
}

