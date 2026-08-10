//개발용

import 'dart:convert';
import 'dart:js_interop';
import 'package:flutter/material.dart';
import 'package:web/web.dart' as web;

import '../permissions/customer_permission_gateway.dart';
import 'store_discovery_repository.dart';

class KakaoStoreMapWeb extends StatelessWidget {
  const KakaoStoreMapWeb({
    required this.stores,
    required this.currentLocation,
    required this.searchCenter,
    super.key,
  });

  static const String _kakaoMapKey =
  String.fromEnvironment('KAKAO_MAP_JS_KEY');

  static const double _busanLatitude = 35.157778;
  static const double _busanLongitude = 129.059167;

  final List<CustomerStore> stores;
  final CustomerLocation? currentLocation;
  final CustomerLocation? searchCenter;

  @override
  Widget build(BuildContext context) {
    final center =
        searchCenter ??
            currentLocation ??
            _firstStoreLocation() ??
            const CustomerLocation(
              latitude: _busanLatitude,
              longitude: _busanLongitude,
            );

    final markerData = stores
        .where(
          (store) =>
      store.latitude != null &&
          store.longitude != null,
    )
        .map(
          (store) => {
        'storeId': store.storeId,
        'latitude': store.latitude,
        'longitude': store.longitude,
      },
    )
        .toList();

    final signature = Object.hash(
      center.latitude,
      center.longitude,
      jsonEncode(markerData),
    );

    return HtmlElementView.fromTagName(
      key: ValueKey(signature),
      tagName: 'iframe',
      onElementCreated: (element) {
        final iframe = element as web.HTMLIFrameElement;

        iframe
          ..srcdoc = _buildHtml(
            center: center,
            markerData: markerData,
          ).toJS
          ..style.border = '0'
          ..style.width = '100%'
          ..style.height = '100%';
      },
    );
  }

  CustomerLocation? _firstStoreLocation() {
    for (final store in stores) {
      final latitude = store.latitude;
      final longitude = store.longitude;

      if (latitude != null && longitude != null) {
        return CustomerLocation(
          latitude: latitude,
          longitude: longitude,
        );
      }
    }

    return null;
  }

  String _buildHtml({
    required CustomerLocation center,
    required List<Map<String, Object?>> markerData,
  }) {
    final markersJson = jsonEncode(markerData);

    return '''
<!DOCTYPE html>
<html lang="ko">
<head>
  <meta charset="UTF-8">

  <meta
    name="viewport"
    content="width=device-width, initial-scale=1.0"
  >

  <style>
    html,
    body,
    #map {
      width: 100%;
      height: 100%;
      margin: 0;
      padding: 0;
      overflow: hidden;
    }
  </style>
</head>

<body>
  <div id="map"></div>

  <script>
  const script = document.createElement('script');

  script.src =
      'https://dapi.kakao.com/v2/maps/sdk.js'
      + '?appkey=$_kakaoMapKey'
      + '&autoload=false';

  script.onload = function () {
    if (window.kakao === undefined) {
      document.getElementById('map').innerHTML =
          '<div style="padding:20px;">카카오 지도 SDK를 불러오지 못했습니다.</div>';
      return;
    }

    kakao.maps.load(function () {
      const center = new kakao.maps.LatLng(
        ${center.latitude},
        ${center.longitude}
      );

      const map = new kakao.maps.Map(
        document.getElementById('map'),
        {
          center: center,
          level: 4
        }
      );

      const stores = $markersJson;

      stores.forEach(function (store) {
        new kakao.maps.Marker({
          map: map,
          position: new kakao.maps.LatLng(
            store.latitude,
            store.longitude
          )
        });
      });
    });
  };

  script.onerror = function () {
    document.getElementById('map').innerHTML =
        '<div style="padding:20px;">카카오 지도 SDK 로드에 실패했습니다.</div>';
  };

  document.head.appendChild(script);
</script>
</body>
</html>
''';
  }
}