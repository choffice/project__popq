//개발용

import 'dart:convert';
import 'dart:js_interop';
import 'package:flutter/material.dart';
import 'package:web/web.dart' as web;

import '../permissions/customer_permission_gateway.dart';
import 'store_discovery_repository.dart';
import 'kakao_store_map.dart';

class KakaoStoreMapWeb extends StatefulWidget {
  const KakaoStoreMapWeb({
    this.controller,
    required this.stores,
    required this.currentLocation,
    required this.searchCenter,
    required this.onStoreSelected,
    required this.selectedStoreId,
    required this.favoriteStoreIds,
    required this.onViewportIdle,
    super.key,
  });

  final KakaoStoreMapController? controller;
  final List<CustomerStore> stores;
  final CustomerLocation? currentLocation;
  final CustomerLocation? searchCenter;
  final ValueChanged<CustomerStore> onStoreSelected;
  final int? selectedStoreId;
  final Set<int> favoriteStoreIds;
  final ValueChanged<KakaoMapViewport>? onViewportIdle;

  @override
  State<KakaoStoreMapWeb> createState() =>
      _KakaoStoreMapWebState();
  }

  class _KakaoStoreMapWebState
    extends State<KakaoStoreMapWeb> {

    static const String _kakaoMapKey =
    String.fromEnvironment('KAKAO_MAP_JS_KEY');

    static const double _busanLatitude = 35.157778;
    static const double _busanLongitude = 129.059167;

  web.HTMLIFrameElement? _iframe;

  List<CustomerStore> get stores => widget.stores;
  CustomerLocation? get currentLocation => widget.currentLocation;
  CustomerLocation? get searchCenter => widget.searchCenter;
  int? get selectedStoreId => widget.selectedStoreId;
  Set<int> get favoriteStoreIds => widget.favoriteStoreIds;
  ValueChanged<CustomerStore> get onStoreSelected =>
      widget.onStoreSelected;
  ValueChanged<KakaoMapViewport>? get onViewportIdle =>
      widget.onViewportIdle;

    Future<void> _focusStoreLocation(
        CustomerLocation location,
        ) async {
      final iframe = _iframe;

      if (iframe == null) {
        return;
      }

      iframe.setAttribute(
        'data-focus-latitude',
        location.latitude.toString(),
      );

      iframe.setAttribute(
        'data-focus-longitude',
        location.longitude.toString(),
      );

      iframe.dispatchEvent(
        web.Event('popq-focus-location'),
      );
    }

  List<Map<String, Object?>> _buildMarkerData() {
    return stores
        .where(
          (store) =>
      store.latitude != null &&
          store.longitude != null,
    )
        .map(
          (store) => {
        'storeId': store.storeId,
        'name': store.name,
        'storeType': store.storeType,
        'businessStatus': store.businessStatus,
        'latitude': store.latitude,
        'longitude': store.longitude,
        'selected':
        store.storeId == selectedStoreId,
        'favorite':
        favoriteStoreIds.contains(store.storeId),
      },
    )
        .toList();
  }

  void _sendMapUpdate({
    required bool moveToSearchCenter,
  }) {
    final iframe = _iframe;

    if (iframe == null) {
      return;
    }

    final payload = jsonEncode({
      'stores': _buildMarkerData(),
      'currentLocation': currentLocation == null
          ? null
          : {
        'latitude': currentLocation!.latitude,
        'longitude': currentLocation!.longitude,
      },
      'searchCenter': searchCenter == null
          ? null
          : {
        'latitude': searchCenter!.latitude,
        'longitude': searchCenter!.longitude,
      },
      'moveToSearchCenter': moveToSearchCenter,
    });

    iframe.setAttribute(
      'data-map-payload',
      payload,
    );

    iframe.dispatchEvent(
      web.Event('popq-map-update'),
    );
  }

  @override
  void didUpdateWidget(
      KakaoStoreMapWeb oldWidget,
      ) {
    super.didUpdateWidget(oldWidget);

    if (!identical(
      oldWidget.controller,
      widget.controller,
    )) {
      oldWidget.controller?.bindFocusStoreLocation(
        null,
      );

      widget.controller?.bindFocusStoreLocation(
        _focusStoreLocation,
      );
    }

    final searchCenterChanged =
        oldWidget.searchCenter?.latitude !=
            widget.searchCenter?.latitude ||
            oldWidget.searchCenter?.longitude !=
                widget.searchCenter?.longitude;

    _sendMapUpdate(
      moveToSearchCenter: searchCenterChanged,
    );
  }

    @override
    void initState() {
      super.initState();

      widget.controller?.bindFocusStoreLocation(
        _focusStoreLocation,
      );
    }

    @override
    void dispose() {
      widget.controller?.bindFocusStoreLocation(
        null,
      );

      super.dispose();
    }

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

    final markerData = _buildMarkerData();

    // final signature = Object.hash(
    //   center.latitude,
    //   center.longitude,
    //   jsonEncode(markerData),
    // );

    return HtmlElementView.fromTagName(
      // key: ValueKey(signature),
      key: const ValueKey('popq-kakao-map-web'),
      tagName: 'iframe',
      onElementCreated: (element) {
        final iframe = element as web.HTMLIFrameElement;
        _iframe = iframe;

        iframe.addEventListener(
          'popq-store-selected',
          ((web.Event _) {
            final rawStoreId =
            iframe.getAttribute('data-store-id');

            final storeId =
            int.tryParse(rawStoreId ?? '');

            if (storeId == null) {
              return;
            }

            for (final store in stores) {
              if (store.storeId == storeId) {
                onStoreSelected(store);
                return;
              }
            }
          }).toJS,
        );

        iframe.addEventListener(
          'popq-map-viewport-idle',
          ((web.Event _) {
            final callback = onViewportIdle;

            if (callback == null) {
              return;
            }

            final latitude = double.tryParse(
              iframe.getAttribute('data-viewport-latitude') ?? '',
            );

            final longitude = double.tryParse(
              iframe.getAttribute('data-viewport-longitude') ?? '',
            );

            final radiusKm = double.tryParse(
              iframe.getAttribute('data-viewport-radius-km') ?? '',
            );

            if (latitude == null ||
                longitude == null ||
                radiusKm == null ||
                radiusKm <= 0) {
              return;
            }

            callback(
              KakaoMapViewport(
                center: CustomerLocation(
                  latitude: latitude,
                  longitude: longitude,
                ),
                radiusKm: radiusKm,
              ),
            );
          }).toJS,
        );

        iframe
          ..srcdoc = _buildHtml(
            center: center,
            markerData: markerData,
            currentLocation: currentLocation,
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
    required CustomerLocation? currentLocation,
  }) {
    final markersJson = jsonEncode(markerData);

    final currentLocationJson = jsonEncode(
      currentLocation == null
          ? null
          : {
        'latitude': currentLocation.latitude,
        'longitude': currentLocation.longitude,
      },
    );
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
      
      let userChangedViewport = false;

kakao.maps.event.addListener(
  map,
  'dragstart',
  function () {
    userChangedViewport = true;
  }
);

kakao.maps.event.addListener(
  map,
  'zoom_start',
  function () {
    userChangedViewport = true;
  }
);

kakao.maps.event.addListener(
  map,
  'idle',
  function () {
    if (!userChangedViewport) {
      return;
    }

    userChangedViewport = false;

    reportViewport();
  }
);

    let storeOverlays = [];
    let currentLocationOverlay = null;

const stores = $markersJson;

function renderStores(nextStores) {
  storeOverlays.forEach(function (overlay) {
    overlay.setMap(null);
  });

  storeOverlays = [];

  nextStores.forEach(function (store) {
  const position = new kakao.maps.LatLng(
    store.latitude,
    store.longitude
  );

  const button = document.createElement('button');

  button.type = 'button';

  button.style.position = 'relative';
  button.style.display = 'inline-flex';
  button.style.alignItems = 'center';
  button.style.gap = '6px';
  button.style.padding = '8px 12px';
  button.style.border = '0';
  button.style.borderRadius = '999px';
if (
  store.businessStatus === 'PRE_OPEN' &&
  store.selected === true
) {
  button.style.background = '#d9e6c0';
  button.style.color = '#465044';
  button.style.opacity = '0.94';
  button.style.transform = 'scale(1.06)';
} else if (
  store.businessStatus === 'PRE_OPEN'
) {
  button.style.background = '#858c88';
  button.style.color = 'rgba(255, 255, 255, 0.82)';
  button.style.opacity = '0.76';
} else if (
  store.selected === true
) {
  button.style.background = '#b7ff00';
  button.style.color = '#08110e';
  button.style.transform = 'scale(1.06)';
} else {
  button.style.background = '#08110e';
  button.style.color = '#ffffff';
}
  button.style.fontSize = '12px';
  button.style.fontWeight = '800';
  button.style.whiteSpace = 'nowrap';
  button.style.boxShadow =
      '0 3px 9px rgba(0, 0, 0, 0.28)';

  const icon =
      store.storeType === 'EVENT_COMMERCE'
          ? '🎇'
          : '🏪';

  button.textContent =
    icon + ' ' + store.name;

if (store.favorite === true) {
  const favoriteBadge =
      document.createElement('span');

  favoriteBadge.textContent = '♥';

  favoriteBadge.style.position = 'absolute';
  favoriteBadge.style.top = '-7px';
  favoriteBadge.style.right = '-7px';
  favoriteBadge.style.display = 'flex';
  favoriteBadge.style.alignItems = 'center';
  favoriteBadge.style.justifyContent = 'center';
  favoriteBadge.style.width = '22px';
  favoriteBadge.style.height = '22px';
  favoriteBadge.style.border = '2px solid white';
  favoriteBadge.style.borderRadius = '50%';
  favoriteBadge.style.background = '#ffffff';
  favoriteBadge.style.color = '#ff4057';
  favoriteBadge.style.fontSize = '14px';
  favoriteBadge.style.lineHeight = '1';
  favoriteBadge.style.boxShadow =
      '0 2px 6px rgba(0, 0, 0, 0.28)';

  button.appendChild(favoriteBadge);
}

button.addEventListener(
  'click',
  function () {
    const frame = window.frameElement;

    if (frame === null) {
      return;
    }

    frame.setAttribute(
      'data-store-id',
      String(store.storeId)
    );

    frame.dispatchEvent(
      new Event('popq-store-selected')
    );
  }
);

const overlay =
    new kakao.maps.CustomOverlay({
      map: map,
      position: position,
      content: button,
      yAnchor: 1.15
    });

storeOverlays.push(overlay);
  });
}

renderStores(stores);

function renderCurrentLocation(location) {
  if (currentLocationOverlay !== null) {
    currentLocationOverlay.setMap(null);
    currentLocationOverlay = null;
  }

  if (location === null) {
    return;
  }

  const dot = document.createElement('div');

  dot.style.width = '16px';
  dot.style.height = '16px';
  dot.style.borderRadius = '50%';
  dot.style.background = '#2f80ed';
  dot.style.border = '3px solid white';
  dot.style.boxShadow =
      '0 2px 8px rgba(0, 0, 0, 0.32)';

  currentLocationOverlay =
      new kakao.maps.CustomOverlay({
        map: map,
        position: new kakao.maps.LatLng(
          location.latitude,
          location.longitude
        ),
        content: dot,
        yAnchor: 0.5,
        xAnchor: 0.5
      });
}

const initialCurrentLocation =
    $currentLocationJson;

renderCurrentLocation(
  initialCurrentLocation
);

const frame = window.frameElement;

if (frame !== null) {
 // 매장 위치 버튼 등에서 지정 좌표로 지도 이동
  frame.addEventListener(
  'popq-focus-location',
  function () {
    const latitude = Number(
      frame.getAttribute(
        'data-focus-latitude'
      )
    );

    const longitude = Number(
      frame.getAttribute(
        'data-focus-longitude'
      )
    );

    if (
      !Number.isFinite(latitude) ||
      !Number.isFinite(longitude)
    ) {
      return;
    }

    map.panTo(
      new kakao.maps.LatLng(
        latitude,
        longitude
      )
    );
  }
);

  frame.addEventListener(
    'popq-map-update',
    function () {
      const rawPayload =
          frame.getAttribute('data-map-payload');

      if (rawPayload === null) {
        return;
      }

      const payload =
          JSON.parse(rawPayload);

      console.log(
        '[POPQ Map] update',
        payload
      );
      
      renderStores(
        payload.stores ?? []
      );

      renderCurrentLocation(
        payload.currentLocation ?? null
      );

      if (
        payload.moveToSearchCenter === true &&
        payload.searchCenter !== null
      ) {
        map.setCenter(
          new kakao.maps.LatLng(
            payload.searchCenter.latitude,
            payload.searchCenter.longitude
          )
        );
      }
    }
  );
  
  frame.dispatchEvent(
  new Event('popq-map-update')
  );
}

function toRadians(value) {
  return value * Math.PI / 180;
}

function distanceKm(
  latitude1,
  longitude1,
  latitude2,
  longitude2
) {
  const earthRadiusKm = 6371;

  const latitudeDifference =
      toRadians(latitude2 - latitude1);

  const longitudeDifference =
      toRadians(longitude2 - longitude1);

  const firstLatitude =
      toRadians(latitude1);

  const secondLatitude =
      toRadians(latitude2);

  const value =
      Math.sin(latitudeDifference / 2) *
      Math.sin(latitudeDifference / 2) +
      Math.cos(firstLatitude) *
      Math.cos(secondLatitude) *
      Math.sin(longitudeDifference / 2) *
      Math.sin(longitudeDifference / 2);

  return earthRadiusKm *
      2 *
      Math.atan2(
        Math.sqrt(value),
        Math.sqrt(1 - value)
      );
}

function reportViewport() {
  const center = map.getCenter();
  const bounds = map.getBounds();

  const southWest =
      bounds.getSouthWest();

  const northEast =
      bounds.getNorthEast();

  const latitude =
      center.getLat();

  const longitude =
      center.getLng();

  const corners = [
    [
      southWest.getLat(),
      southWest.getLng()
    ],
    [
      southWest.getLat(),
      northEast.getLng()
    ],
    [
      northEast.getLat(),
      southWest.getLng()
    ],
    [
      northEast.getLat(),
      northEast.getLng()
    ]
  ];

  let radiusKm = 0.5;

  corners.forEach(function (corner) {
    radiusKm = Math.max(
      radiusKm,
      distanceKm(
        latitude,
        longitude,
        corner[0],
        corner[1]
      )
    );
  });

  const frame =
      window.frameElement;

  if (frame === null) {
    return;
  }

  frame.setAttribute(
    'data-viewport-latitude',
    String(latitude)
  );

  frame.setAttribute(
    'data-viewport-longitude',
    String(longitude)
  );

  frame.setAttribute(
    'data-viewport-radius-km',
    String(radiusKm)
  );

  frame.dispatchEvent(
    new Event(
      'popq-map-viewport-idle'
    )
  );
}

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