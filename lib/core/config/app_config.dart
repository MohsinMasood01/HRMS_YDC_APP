class AppConfig {
  const AppConfig({
    // this.baseUrl = 'http://lms.yousufdewan.com:8080/ords/ws_tms/empdata/',
    // NOTE: Use PC LAN IP (not 127.0.0.1) — physical devices can't reach localhost.
    // Run `ipconfig` on Windows to find your IPv4 Address, e.g. 10.0.0.120
    // Emulator only: you can use http://10.0.2.2:8000 (maps to host 127.0.0.1)
    // this.baseUrl = 'http://10.0.0.120:8001',
    // this.baseUrl = 'http://apps.d-tech.com.pk:8001',
    // this.faceAuthBaseUrl = 'http://apps.d-tech.com.pk:8002',
    // Public entry point: Apache (443) → Next.js → /api/* rewrite → backend 8001.
    // Ports 8001/8002 are NOT reachable from the internet (firewall drops them),
    // so the raw IP only works on the server itself / same LAN.
    // this.baseUrl = 'http://169.58.96.211:8001',
    this.baseUrl = 'https://hrms.d-tech.com.pk/api',
    // Real InsightFace service (port 8002) behind TLS on its own host.
    // Do NOT point this at /api — 8001's /face/* endpoints are stubs that
    // identify the first enrolled employee regardless of the frames sent.
    // this.faceAuthBaseUrl = 'http://169.58.96.211:8002',
    this.faceAuthBaseUrl = 'https://hrms.d-tech.com.pk',
    this.appName = 'LMS',
    this.useMockData = false,
    this.defaultGeoLatitude = 24.85851,
    this.defaultGeoLongitude = 67.05,
    this.geoFenceRadiusMeters = 200,
    this.geoFenceMonitoringIntervalSeconds = 20,
    this.geoFenceMaxAccuracyMeters = 30.0,
    this.enableGeoFenceAntiSpoofing = true,
  });
    
  final String baseUrl;
  final String faceAuthBaseUrl;
  final String appName;
  final bool useMockData;

  // Geofence Configuration
  final double defaultGeoLatitude;
  final double defaultGeoLongitude;
  final int geoFenceRadiusMeters;

  /// Interval for periodic geofence checks in seconds
  final int geoFenceMonitoringIntervalSeconds;

  /// Maximum acceptable GPS accuracy in meters
  /// Readings with worse accuracy will be filtered
  final double geoFenceMaxAccuracyMeters;

  /// Whether to enable mock location detection
  final bool enableGeoFenceAntiSpoofing;
}
