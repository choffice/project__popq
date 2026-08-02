import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';

import '../permissions/customer_permission_gateway.dart';
import 'store_discovery_repository.dart';

/*
 * 사용자가 지도 이동이나 확대·축소를 끝냈을 때
 * Flutter로 전달되는 현재 지도 영역 정보입니다.
 */
class KakaoMapViewport {
  const KakaoMapViewport({required this.center, required this.radiusKm});

  final CustomerLocation center;
  final double radiusKm;
}

class KakaoStoreMap extends StatefulWidget {
  const KakaoStoreMap({
    required this.stores,
    required this.currentLocation,
    required this.selectedStoreId,
    required this.onStoreSelected,
    this.searchCenter,
    this.onViewportIdle,
    super.key,
  });

  /*
   * 현재 검색 결과에 포함된 POPQ 매장입니다.
   */
  final List<CustomerStore> stores;

  /*
   * 실제 GPS 위치입니다.
   *
   * 지도에서 파란 점을 표시하는 용도이며,
   * 사용자가 지도를 이동해도 이 값은 바뀌지 않습니다.
   */
  final CustomerLocation? currentLocation;

  /*
   * Controller가 현재 업체 검색 기준으로 사용하는 좌표입니다.
   *
   * 다음 단계에서 StoreDiscoveryScreen이
   * controller.searchCenter를 전달하게 됩니다.
   */
  final CustomerLocation? searchCenter;

  final int? selectedStoreId;

  final ValueChanged<CustomerStore> onStoreSelected;

  /*
   * 사용자가 지도를 직접 이동하거나 확대·축소한 뒤
   * 조작이 끝났을 때 호출됩니다.
   *
   * 아직 Screen과 연결하지 않았으므로 nullable로 둡니다.
   */
  final ValueChanged<KakaoMapViewport>? onViewportIdle;

  @override
  State<KakaoStoreMap> createState() => _KakaoStoreMapState();
}

class _KakaoStoreMapState extends State<KakaoStoreMap> {
  static const _kakaoMapKey = String.fromEnvironment('KAKAO_MAP_JS_KEY');

  /*
   * 지도와 검색 결과가 모두 없을 때 사용할
   * 부산 기본 중심 좌표입니다.
   */
  static const double _busanLatitude = 35.1796;
  static const double _busanLongitude = 129.0756;

  late final WebViewController _webViewController;

  bool _loading = true;
  bool _mapReady = false;

  bool _pendingSync = false;
  bool _pendingMoveToSearchCenter = false;

  String? _errorMessage;

  @override
  void initState() {
    super.initState();

    _webViewController = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(const Color(0xFFE7E6DF))
      ..addJavaScriptChannel(
        'StoreMarker',
        onMessageReceived: _handleStoreMarkerMessage,
      )
      ..addJavaScriptChannel(
        'MapViewport',
        onMessageReceived: _handleMapViewportMessage,
      )
      ..addJavaScriptChannel(
        'MapReady',
        onMessageReceived: (_) {
          if (!mounted) {
            return;
          }

          setState(() {
            _loading = false;
            _mapReady = true;
            _errorMessage = null;
          });

          if (_pendingSync) {
            final moveToSearchCenter = _pendingMoveToSearchCenter;

            _pendingSync = false;
            _pendingMoveToSearchCenter = false;

            _syncMapData(moveToSearchCenter: moveToSearchCenter);
          }
        },
      )
      ..addJavaScriptChannel(
        'MapError',
        onMessageReceived: (message) {
          if (!mounted) {
            return;
          }

          setState(() {
            _loading = false;
            _mapReady = false;
            _errorMessage = message.message;
          });
        },
      )
      ..addJavaScriptChannel(
        'MapDebug',
        onMessageReceived: (message) {
          debugPrint('[KakaoMap] ${message.message}');
        },
      )
      ..setNavigationDelegate(
        NavigationDelegate(
          onWebResourceError: (error) {
            debugPrint(
              '[KakaoWebResourceError] '
                  'main=${error.isForMainFrame} '
                  'code=${error.errorCode} '
                  'type=${error.errorType} '
                  'url=${error.url} '
                  'description=${error.description}',
            );

            if (!mounted ||
                error.isForMainFrame != true) {
              return;
            }

            setState(() {
              _loading = false;
              _mapReady = false;
              _errorMessage = error.description;
            });
          },
        ),
      );

    _loadMap();
  }

  @override
  void didUpdateWidget(covariant KakaoStoreMap oldWidget) {
    super.didUpdateWidget(oldWidget);

    final storesChanged =
        _storeSignature(oldWidget.stores) != _storeSignature(widget.stores);

    final currentLocationChanged = _locationChanged(
      oldWidget.currentLocation,
      widget.currentLocation,
    );

    final searchCenterChanged = _locationChanged(
      oldWidget.searchCenter,
      widget.searchCenter,
    );

    final selectionChanged =
        oldWidget.selectedStoreId != widget.selectedStoreId;

    if (!storesChanged &&
        !currentLocationChanged &&
        !searchCenterChanged &&
        !selectionChanged) {
      return;
    }

    /*
     * GPS 버튼이나 부산 기본 위치 복귀 등으로
     * 검색 중심이 바뀐 경우에만 지도의 중심도 옮깁니다.
     *
     * 단순 핀 선택이나 업체 결과 변경만으로는
     * 사용자가 보고 있던 지도 위치를 바꾸지 않습니다.
     */
    _syncMapData(moveToSearchCenter: searchCenterChanged);
  }

  bool _locationChanged(CustomerLocation? before, CustomerLocation? after) {
    return before?.latitude != after?.latitude ||
        before?.longitude != after?.longitude;
  }

  void _handleStoreMarkerMessage(JavaScriptMessage message) {
    final storeId = int.tryParse(message.message);

    if (storeId == null) {
      return;
    }

    for (final store in widget.stores) {
      if (store.storeId == storeId) {
        widget.onStoreSelected(store);
        return;
      }
    }
  }

  void _handleMapViewportMessage(JavaScriptMessage message) {
    final callback = widget.onViewportIdle;

    if (callback == null) {
      return;
    }

    try {
      final decoded = jsonDecode(message.message);

      if (decoded is! Map<String, dynamic>) {
        return;
      }

      final latitude = (decoded['latitude'] as num?)?.toDouble();

      final longitude = (decoded['longitude'] as num?)?.toDouble();

      final radiusKm = (decoded['radiusKm'] as num?)?.toDouble();

      if (latitude == null ||
          longitude == null ||
          radiusKm == null ||
          radiusKm <= 0) {
        return;
      }

      callback(
        KakaoMapViewport(
          center: CustomerLocation(latitude: latitude, longitude: longitude),
          radiusKm: radiusKm,
        ),
      );
    } catch (_) {
      /*
       * WebView에서 잘못된 메시지가 전달된 경우
       * 지도 화면을 중단하지 않고 무시합니다.
       */
    }
  }

  Future<void> _loadMap() async {
    if (_kakaoMapKey.isEmpty) {
      if (!mounted) {
        return;
      }

      setState(() {
        _loading = false;
        _mapReady = false;
        _errorMessage =
            '카카오맵 JavaScript 키가 없습니다.\\n'
            'KAKAO_MAP_JS_KEY를 설정한 뒤 '
            '다시 실행해 주세요.';
      });

      return;
    }

    if (mounted) {
      setState(() {
        _loading = true;
        _mapReady = false;
        _errorMessage = null;
      });
    }

    await _webViewController.loadHtmlString(
      _buildMapHtml(),
      baseUrl: 'http://localhost/',
    );
  }

  /*
   * 기존 구현은 stores나 selectedStoreId가 바뀔 때마다
   * HTML 전체를 다시 로딩했습니다.
   *
   * 그러면 사용자가 이동한 지도 위치가 초기화되므로,
   * 이제 JavaScript 함수로 핀 데이터만 갱신합니다.
   */
  Future<void> _syncMapData({required bool moveToSearchCenter}) async {
    if (!_mapReady) {
      _pendingSync = true;

      _pendingMoveToSearchCenter =
          _pendingMoveToSearchCenter || moveToSearchCenter;

      return;
    }

    final payload = _buildMapPayload(moveToSearchCenter: moveToSearchCenter);

    try {
      await _webViewController.runJavaScript(
        'window.updateMapData('
        '${_safeJson(payload)}'
        ');',
      );
    } catch (caught) {
      if (!mounted) {
        return;
      }

      setState(() {
        _errorMessage =
            '지도 정보를 갱신하지 못했습니다.\\n'
            '$caught';
      });
    }
  }

  Map<String, Object?> _buildMapPayload({required bool moveToSearchCenter}) {
    final stores = widget.stores
        .where((store) => store.latitude != null && store.longitude != null)
        .map(
          (store) => {
            'storeId': store.storeId,
            'name': store.name,
            'storeType': store.storeType,
            'latitude': store.latitude,
            'longitude': store.longitude,
          },
        )
        .toList();

    return {
      'stores': stores,
      'selectedStoreId': widget.selectedStoreId,
      'currentLocation': widget.currentLocation == null
          ? null
          : {
              'latitude': widget.currentLocation!.latitude,
              'longitude': widget.currentLocation!.longitude,
            },
      'searchCenter': widget.searchCenter == null
          ? null
          : {
              'latitude': widget.searchCenter!.latitude,
              'longitude': widget.searchCenter!.longitude,
            },
      'moveToSearchCenter': moveToSearchCenter,
    };
  }

  Map<String, double> _resolveInitialCenter() {
    if (widget.searchCenter != null) {
      return {
        'latitude': widget.searchCenter!.latitude,
        'longitude': widget.searchCenter!.longitude,
      };
    }

    if (widget.currentLocation != null) {
      return {
        'latitude': widget.currentLocation!.latitude,
        'longitude': widget.currentLocation!.longitude,
      };
    }

    for (final store in widget.stores) {
      if (store.latitude != null && store.longitude != null) {
        return {'latitude': store.latitude!, 'longitude': store.longitude!};
      }
    }

    return const {'latitude': _busanLatitude, 'longitude': _busanLongitude};
  }

  String _buildMapHtml() {
    final encodedKey = Uri.encodeQueryComponent(_kakaoMapKey);

    final initialCenterJson = _safeJson(_resolveInitialCenter());

    final initialDataJson = _safeJson(
      _buildMapPayload(moveToSearchCenter: false),
    );

    return '''
<!DOCTYPE html>
<html lang="ko">
<head>
  <meta charset="UTF-8">

  <meta name="viewport" content="width=device-width, initial-scale=1.0, maximum-scale=1.0, user-scalable=no">

  <style>
    html,
    body,
    #map {
      width: 100%;
      height: 100%;
      margin: 0;
      padding: 0;
      overflow: hidden;
      background: #e7e6df;
    }

    .store-label {
      max-width: 160px;
      padding: 8px 12px;
      border: 0;
      border-radius: 999px;
      background: #08110e;
      color: white;
      font-size: 12px;
      font-weight: 800;
      white-space: nowrap;
      overflow: hidden;
      text-overflow: ellipsis;
      box-shadow:
        0 3px 9px rgba(0, 0, 0, 0.28);
    }

    .store-label.selected {
      background: #b7ff00;
      color: #08110e;
      transform: scale(1.06);
    }

    .current-location {
      width: 18px;
      height: 18px;
      border: 4px solid white;
      border-radius: 50%;
      background: #287cff;
      box-shadow:
        0 2px 8px rgba(0, 0, 0, 0.35);
    }
  </style>

  <script>
  window.onerror = function(window.onerror = function(
  message,
  source,
  line,
  column
) {
  const errorMessage =
    '지도 JavaScript 오류: '
    + String(message)
    + ' / line='
    + String(line)
    + ' / column='
    + String(column);

  if (window.MapDebug) {
    MapDebug.postMessage(errorMessage);
  }

  if (window.MapError) {
    MapError.postMessage(errorMessage);
  }
};
</script>
</head>

<body>
  <div id="map"></div>

  <script>
    const initialCenter =
      $initialCenterJson;

    const initialData =
      $initialDataJson;

    let map = null;

    let storeOverlays = [];

    let currentLocationOverlay = null;

    /*
     * 초기 로딩이나 Flutter가 실행한 setCenter로는
     * 업체 재검색을 발생시키지 않습니다.
     *
     * 사용자가 직접 드래그하거나 확대·축소한 경우에만
     * 다음 idle 이벤트에서 Flutter로 영역을 보냅니다.
     */
    let userChangedViewport = false;

    let readyPosted = false;

    function clearStoreOverlays() {
      storeOverlays.forEach(function(overlay) {
        overlay.setMap(null);
      });

      storeOverlays = [];
    }

    function clearCurrentLocationOverlay() {
      if (currentLocationOverlay !== null) {
        currentLocationOverlay.setMap(null);
        currentLocationOverlay = null;
      }
    }

    function renderStores(
      stores,
      selectedStoreId
    ) {
      clearStoreOverlays();

      stores.forEach(function(store) {
        const position =
          new kakao.maps.LatLng(
            store.latitude,
            store.longitude
          );

        const button =
          document.createElement('button');

        button.type = 'button';

        button.className =
          store.storeId === selectedStoreId
            ? 'store-label selected'
            : 'store-label';

        button.textContent = store.name;

        button.addEventListener(
          'click',
          function() {
            StoreMarker.postMessage(
              String(store.storeId)
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

    function renderCurrentLocation(
      currentLocation
    ) {
      clearCurrentLocationOverlay();

      if (currentLocation === null) {
        return;
      }

      const marker =
        document.createElement('div');

      marker.className =
        'current-location';

      currentLocationOverlay =
        new kakao.maps.CustomOverlay({
          map: map,
          position:
            new kakao.maps.LatLng(
              currentLocation.latitude,
              currentLocation.longitude
            ),
          content: marker,
          yAnchor: 0.5
        });
    }

    /*
     * Flutter가 업체 목록이나 선택 상태를 변경할 때
     * 호출하는 함수입니다.
     *
     * WebView나 지도 자체를 다시 생성하지 않고
     * 오버레이만 교체합니다.
     */
    window.updateMapData =
      function(payload) {
        if (map === null || payload === null) {
          return;
        }

        renderStores(
          payload.stores || [],
          payload.selectedStoreId
        );

        renderCurrentLocation(
          payload.currentLocation || null
        );

        if (
          payload.moveToSearchCenter === true &&
          payload.searchCenter !== null
        ) {
          userChangedViewport = false;

          map.setCenter(
            new kakao.maps.LatLng(
              payload.searchCenter.latitude,
              payload.searchCenter.longitude
            )
          );
        }
      };

    function toRadians(value) {
      return value * Math.PI / 180;
    }

    /*
     * 두 위도·경도 간 거리를 km로 계산합니다.
     */
    function distanceKm(
      latitude1,
      longitude1,
      latitude2,
      longitude2
    ) {
      const earthRadiusKm = 6371;

      const latitudeDifference =
        toRadians(
          latitude2 - latitude1
        );

      const longitudeDifference =
        toRadians(
          longitude2 - longitude1
        );

      const firstLatitude =
        toRadians(latitude1);

      const secondLatitude =
        toRadians(latitude2);

      const value =
        Math.sin(
          latitudeDifference / 2
        ) *
        Math.sin(
          latitudeDifference / 2
        ) +
        Math.cos(firstLatitude) *
        Math.cos(secondLatitude) *
        Math.sin(
          longitudeDifference / 2
        ) *
        Math.sin(
          longitudeDifference / 2
        );

      return earthRadiusKm *
        2 *
        Math.atan2(
          Math.sqrt(value),
          Math.sqrt(1 - value)
        );
    }

    /*
     * 현재 지도 사각형의 네 모서리까지 거리 중
     * 가장 큰 값을 검색 반경으로 사용합니다.
     *
     * 따라서 원형 반경 조회를 사용하더라도
     * 현재 화면의 네 모서리를 모두 포함합니다.
     */
    function reportViewport() {
      if (
        map === null ||
        !window.MapViewport
      ) {
        return;
      }

      const center = map.getCenter();

      const bounds = map.getBounds();

      const southWest =
        bounds.getSouthWest();

      const northEast =
        bounds.getNorthEast();

      const centerLatitude =
        center.getLat();

      const centerLongitude =
        center.getLng();

      const cornerCoordinates = [
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

      cornerCoordinates.forEach(
        function(corner) {
          radiusKm = Math.max(
            radiusKm,
            distanceKm(
              centerLatitude,
              centerLongitude,
              corner[0],
              corner[1]
            )
          );
        }
      );

      MapViewport.postMessage(
        JSON.stringify({
          latitude: centerLatitude,
          longitude: centerLongitude,
          radiusKm: radiusKm
        })
      );
    }

    function postReady() {
      if (readyPosted) {
        return;
      }

      readyPosted = true;

      MapReady.postMessage('ready');
    }

        let sdkLoadAttempt = 0;

    const maxSdkLoadAttempts = 3;

    function reportDebug(message) {
      if (window.MapDebug) {
        MapDebug.postMessage(
          String(message)
        );
      }
    }

    function reportMapError(message) {
      if (window.MapError) {
        MapError.postMessage(
          String(message)
        );
      }
    }

    function initializeKakaoMap() {
      if (
        !window.kakao ||
        !window.kakao.maps
      ) {
        reportMapError(
        '카카오 지도 SDK 응답은 받았지만 '
        + 'kakao.maps 객체가 없습니다. '
        + 'JavaScript 키와 JavaScript SDK 도메인을 '
        + '확인해 주세요.'
        );

        return;
      }

      window.kakao.maps.load(function() {
        const mapContainer =
          document.getElementById('map');

        map = new window.kakao.maps.Map(
          mapContainer,
          {
            center:
              new window.kakao.maps.LatLng(
                initialCenter.latitude,
                initialCenter.longitude
              ),
            level: 7
          }
        );

        window.kakao.maps.event.addListener(
          map,
          'dragstart',
          function() {
            userChangedViewport = true;
          }
        );

        window.kakao.maps.event.addListener(
          map,
          'zoom_start',
          function() {
            userChangedViewport = true;
          }
        );

        window.kakao.maps.event.addListener(
          map,
          'idle',
          function() {
            if (!userChangedViewport) {
              return;
            }

            userChangedViewport = false;

            reportViewport();
          }
        );

        window.kakao.maps.event.addListener(
          map,
          'tilesloaded',
          postReady
        );

        window.updateMapData(
          initialData
        );

        /*
         * 지도 타일 이벤트가 늦어지는 경우에도
         * WebView의 로딩 화면을 종료하기 위한 안전장치입니다.
         */
        window.setTimeout(
          postReady,
          2000
        );

        reportDebug(
          'map-initialized'
        );
      });
    }

    function loadKakaoSdk() {
      sdkLoadAttempt += 1;

      reportDebug(
        'sdk-load-start:'
        + String(sdkLoadAttempt)
      );

      const previousScript =
        document.getElementById(
          'kakao-map-sdk'
        );

      if (previousScript !== null) {
        previousScript.remove();
      }

      const script =
        document.createElement('script');

      script.id = 'kakao-map-sdk';
      script.type = 'text/javascript';

      script.src =
        'https://dapi.kakao.com/v2/maps/sdk.js'
        + '?appkey=$encodedKey'
        + '&autoload=false';

      let requestFinished = false;

      const timeoutTimer =
        window.setTimeout(
          function() {
            handleSdkFailure(
              '카카오 지도 SDK 응답 시간이 '
              + '초과되었습니다.'
            );
          },
          8000
        );

      function handleSdkFailure(message) {
        if (requestFinished) {
          return;
        }

        requestFinished = true;

        window.clearTimeout(
          timeoutTimer
        );

        script.remove();

        if (
          sdkLoadAttempt <
          maxSdkLoadAttempts
        ) {
          reportDebug(
            'sdk-load-retry:'
            + String(sdkLoadAttempt)
            + ':'
            + message
          );

          window.setTimeout(
            loadKakaoSdk,
            1000
          );

          return;
        }

        reportMapError(
        message
        + ' 세 번 다시 시도했지만 '
        + '지도를 불러오지 못했습니다. '
        + '네트워크 상태와 JavaScript 키, '
        + 'JavaScript SDK 도메인을 확인해 주세요.'
        );
      }

      script.onload = function() {
        if (requestFinished) {
          return;
        }

        window.clearTimeout(
          timeoutTimer
        );

        if (
          !window.kakao ||
          !window.kakao.maps
        ) {
          handleSdkFailure(
            'SDK 파일은 로드됐지만 '
            + 'kakao.maps 객체가 생성되지 않았습니다.'
          );

          return;
        }

        requestFinished = true;

        reportDebug(
          'sdk-load-success:'
          + String(sdkLoadAttempt)
        );

        initializeKakaoMap();
      };

      script.onerror = function() {
        handleSdkFailure(
          '카카오 지도 SDK 파일을 '
          + '다운로드하지 못했습니다.'
        );
      };

      document.head.appendChild(
        script
      );
    }

    loadKakaoSdk();
  </script>
</body>
</html>
''';
  }

  String _safeJson(Object? value) {
    return jsonEncode(value).replaceAll('</script', r'<\/script');
  }

  String _storeSignature(List<CustomerStore> stores) {
    return jsonEncode(
      stores
          .map(
            (store) => [
              store.storeId,
              store.name,
              store.storeType,
              store.latitude,
              store.longitude,
            ],
          )
          .toList(),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        WebViewWidget(controller: _webViewController),

        if (_loading)
          const ColoredBox(
            color: Color(0x88FFFFFF),
            child: Center(child: CircularProgressIndicator()),
          ),

        if (_errorMessage != null)
          ColoredBox(
            color: Theme.of(context).colorScheme.surface,
            child: Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.map_outlined, size: 52),
                    const SizedBox(height: 16),
                    const Text(
                      '카카오맵을 불러오지 못했습니다.',
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(_errorMessage!, textAlign: TextAlign.center),
                    const SizedBox(height: 18),
                    FilledButton.icon(
                      onPressed: _loadMap,
                      icon: const Icon(Icons.refresh_rounded),
                      label: const Text('다시 시도'),
                    ),
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }
}
