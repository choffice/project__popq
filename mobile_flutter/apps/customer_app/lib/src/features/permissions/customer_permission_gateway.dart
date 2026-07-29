import 'package:geolocator/geolocator.dart';
import 'package:permission_handler/permission_handler.dart' as permissions;

enum PermissionDecision { granted, denied, permanentlyDenied, serviceDisabled }

final class CustomerLocation {
  const CustomerLocation({required this.latitude, required this.longitude});

  final double latitude;
  final double longitude;
}

final class LocationRequestResult {
  const LocationRequestResult({required this.decision, this.location});

  final PermissionDecision decision;
  final CustomerLocation? location;
}

abstract interface class CustomerPermissionGateway {
  Future<LocationRequestResult> requestLocation();

  Future<PermissionDecision> requestNotifications();

  Future<bool> openSettings();
}

class DeviceCustomerPermissionGateway implements CustomerPermissionGateway {
  @override
  Future<LocationRequestResult> requestLocation() async {
    if (!await Geolocator.isLocationServiceEnabled()) {
      return const LocationRequestResult(
        decision: PermissionDecision.serviceDisabled,
      );
    }
    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.deniedForever) {
      return const LocationRequestResult(
        decision: PermissionDecision.permanentlyDenied,
      );
    }
    if (permission == LocationPermission.denied) {
      return const LocationRequestResult(decision: PermissionDecision.denied);
    }
    final position = await Geolocator.getCurrentPosition(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.medium,
        timeLimit: Duration(seconds: 10),
      ),
    );
    return LocationRequestResult(
      decision: PermissionDecision.granted,
      location: CustomerLocation(
        latitude: position.latitude,
        longitude: position.longitude,
      ),
    );
  }

  @override
  Future<PermissionDecision> requestNotifications() async {
    final status = await permissions.Permission.notification.request();
    if (status.isGranted || status.isProvisional) {
      return PermissionDecision.granted;
    }
    if (status.isPermanentlyDenied) {
      return PermissionDecision.permanentlyDenied;
    }
    return PermissionDecision.denied;
  }

  @override
  Future<bool> openSettings() => permissions.openAppSettings();
}

class MemoryCustomerPermissionGateway implements CustomerPermissionGateway {
  MemoryCustomerPermissionGateway({
    this.locationDecision = PermissionDecision.granted,
    this.notificationDecision = PermissionDecision.granted,
    this.location = const CustomerLocation(
      latitude: 37.5444,
      longitude: 127.0559,
    ),
  });

  final PermissionDecision locationDecision;
  final PermissionDecision notificationDecision;
  final CustomerLocation location;

  @override
  Future<bool> openSettings() async => true;

  @override
  Future<LocationRequestResult> requestLocation() async {
    return LocationRequestResult(
      decision: locationDecision,
      location: locationDecision == PermissionDecision.granted
          ? location
          : null,
    );
  }

  @override
  Future<PermissionDecision> requestNotifications() async {
    return notificationDecision;
  }
}
