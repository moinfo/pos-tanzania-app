import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';

/// GPS coordinates + best-effort reverse-geocoded administrative labels for
/// one sale. The coordinates are the source of truth; city/district/ward/
/// street come from the device's native geocoder and can be null/sparse,
/// especially at ward/street level in Tanzania.
class SaleLocation {
  final double? lat;
  final double? lng;
  final String? city;
  final String? district;
  final String? ward;
  final String? street;

  const SaleLocation({this.lat, this.lng, this.city, this.district, this.ward, this.street});

  static const empty = SaleLocation();

  bool get hasCoordinates => lat != null && lng != null;
}

/// Captures the device's current location for a sale, best-effort: never
/// throws, never blocks checkout for more than a few seconds. Any failure
/// (permission denied, GPS off, timeout, no geocoding result) just means
/// the sale saves with less location detail, not a failed sale.
class SaleLocationService {
  static Future<SaleLocation> capture() async {
    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) return SaleLocation.empty;

      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied || permission == LocationPermission.deniedForever) {
        return SaleLocation.empty;
      }

      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 8),
        ),
      );

      String? city;
      String? district;
      String? ward;
      String? street;

      try {
        final placemarks = await placemarkFromCoordinates(position.latitude, position.longitude)
            .timeout(const Duration(seconds: 6));
        if (placemarks.isNotEmpty) {
          final p = placemarks.first;
          // Tanzania's native-geocoder placemark fields don't map 1:1 to
          // City/District/Ward/Street - administrativeArea is the region
          // (closest to "city" for Dar es Salaam etc.), subAdministrativeArea
          // is the district, locality/subLocality are the closest available
          // stand-ins for ward, and street/thoroughfare for street. Any of
          // these can come back empty outside major urban areas.
          city = _clean(p.administrativeArea);
          district = _clean(p.subAdministrativeArea);
          ward = _clean(p.subLocality) ?? _clean(p.locality);
          street = _clean(p.thoroughfare) ?? _clean(p.street);
        }
      } catch (_) {
        // Reverse geocoding failed/timed out - keep the coordinates anyway.
      }

      return SaleLocation(
        lat: position.latitude,
        lng: position.longitude,
        city: city,
        district: district,
        ward: ward,
        street: street,
      );
    } catch (_) {
      return SaleLocation.empty;
    }
  }

  static String? _clean(String? value) {
    if (value == null) return null;
    final trimmed = value.trim();
    return trimmed.isEmpty ? null : trimmed;
  }
}
