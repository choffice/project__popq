import 'dart:async';

import 'package:geolocator/geolocator.dart';
import 'package:permission_handler/permission_handler.dart'
as permissions;

enum PermissionDecision {
  granted,
  denied,
  permanentlyDenied,
  serviceDisabled,
  timeout,
}

final class CustomerLocation {
  const CustomerLocation({
    required this.latitude,
    required this.longitude,
  });

  final double latitude;
  final double longitude;
}

final class LocationRequestResult {
  const LocationRequestResult({
    required this.decision,
    this.location,
  });

  final PermissionDecision decision;
  final CustomerLocation? location;
}

abstract interface class CustomerPermissionGateway {
  Future<LocationRequestResult> requestLocation();

  Future<PermissionDecision> requestNotifications();

  Future<bool> openSettings();
}

class DeviceCustomerPermissionGateway
    implements CustomerPermissionGateway {
  @override
  Future<LocationRequestResult> requestLocation() async {
    if (!await Geolocator.isLocationServiceEnabled()) {
      return const LocationRequestResult(
        decision: PermissionDecision.serviceDisabled,
      );
    }

    var permission =
    await Geolocator.checkPermission();

    if (permission == LocationPermission.denied) {
      permission =
      await Geolocator.requestPermission();
    }

    if (permission ==
        LocationPermission.deniedForever) {
      return const LocationRequestResult(
        decision:
        PermissionDecision.permanentlyDenied,
      );
    }

    if (permission == LocationPermission.denied) {
      return const LocationRequestResult(
        decision: PermissionDecision.denied,
      );
    }

    try {
      final position =
      await Geolocator.getCurrentPosition(
        locationSettings:
        const LocationSettings(
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
    } on TimeoutException {
      /*
       * 10초 안에 현재 위치를 확보하지 못한 경우입니다.
       *
       * 예외를 화면까지 던지지 않고 timeout 결과를 반환해
       * 부산 기본 위치로 계속 진행할 수 있도록 합니다.
       */
      return const LocationRequestResult(
        decision: PermissionDecision.timeout,
      );
    } on LocationServiceDisabledException {
      /*
       * 위치 요청 도중 사용자가 위치 서비스를 끈 경우를
       * 별도로 처리합니다.
       */
      return const LocationRequestResult(
        decision:
        PermissionDecision.serviceDisabled,
      );
    }
  }

  @override
  Future<PermissionDecision>
  requestNotifications() async {
    final status =
    await permissions.Permission.notification
        .request();

    if (status.isGranted ||
        status.isProvisional) {
      return PermissionDecision.granted;
    }

    if (status.isPermanentlyDenied) {
      return PermissionDecision.permanentlyDenied;
    }

    return PermissionDecision.denied;
  }

  @override
  Future<bool> openSettings() {
    return permissions.openAppSettings();
  }
}

class MemoryCustomerPermissionGateway
    implements CustomerPermissionGateway {
  MemoryCustomerPermissionGateway({
    this.locationDecision =
        PermissionDecision.granted,
    this.notificationDecision =
        PermissionDecision.granted,
    this.location = const CustomerLocation(
      latitude: 35.157778,
      longitude: 129.059167,
    ),
  });

  final PermissionDecision locationDecision;
  final PermissionDecision
  notificationDecision;
  final CustomerLocation location;

  @override
  Future<bool> openSettings() async => true;

  @override
  Future<LocationRequestResult>
  requestLocation() async {
    return LocationRequestResult(
      decision: locationDecision,
      location:
      locationDecision ==
          PermissionDecision.granted
          ? location
          : null,
    );
  }

  @override
  Future<PermissionDecision>
  requestNotifications() async {
    return notificationDecision;
  }
}