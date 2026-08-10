import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:popq_design_system/popq_design_system.dart';
import 'package:webview_flutter/webview_flutter.dart';

class SellerMapLocationPickResult {
  const SellerMapLocationPickResult({
    required this.latitude,
    required this.longitude,
  });

  final double latitude;
  final double longitude;
}

class SellerStoreLocationPickerScreen
    extends StatefulWidget {
  const SellerStoreLocationPickerScreen({
    required this.initialLatitude,
    required this.initialLongitude,
    this.currentLatitude,
    this.currentLongitude,
    this.addressLabel,
    super.key,
  });

  final double initialLatitude;
  final double initialLongitude;

  /// ?ㅼ젣 湲곌린??GPS ?꾩튂.
  /// 吏???꾩뿉 ?뚮? ?먯쑝濡쒕쭔 ?쒖떆?쒕떎.
  final double? currentLatitude;
  final double? currentLongitude;

  /// ?깅줉?쇱뿉 ?낅젰??二쇱냼瑜??붾㈃ ?곷떒???쒖떆?쒕떎.
  final String? addressLabel;

  @override
  State<SellerStoreLocationPickerScreen>
  createState() =>
      _SellerStoreLocationPickerScreenState();
}

class _SellerStoreLocationPickerScreenState
    extends State<SellerStoreLocationPickerScreen> {
  static const String _kakaoMapKey =
  String.fromEnvironment(
    'KAKAO_MAP_JS_KEY',
  );

  late final WebViewController
  _webViewController;

  late double _selectedLatitude;
  late double _selectedLongitude;

  bool _loading = true;
  bool _mapReady = false;

  String? _errorMessage;

  @override
  void initState() {
    super.initState();

    _selectedLatitude =
        widget.initialLatitude;

    _selectedLongitude =
        widget.initialLongitude;

    _webViewController = WebViewController()
      ..setJavaScriptMode(
        JavaScriptMode.unrestricted,
      )
      ..setBackgroundColor(
        const Color(0xFFE7E6DF),
      )
      ..addJavaScriptChannel(
        'MapCenter',
        onMessageReceived:
        _handleMapCenterMessage,
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
        },
      )
      ..addJavaScriptChannel(
        'MapError',
        onMessageReceived: (
            JavaScriptMessage message,
            ) {
          if (!mounted) {
            return;
          }

          setState(() {
            _loading = false;
            _mapReady = false;
            _errorMessage =
                message.message;
          });
        },
      )
      ..addJavaScriptChannel(
        'MapDebug',
        onMessageReceived: (
            JavaScriptMessage message,
            ) {
          debugPrint(
            '[SellerLocationMap] '
                '${message.message}',
          );
        },
      )
      ..setNavigationDelegate(
        NavigationDelegate(
          onWebResourceError: (
              WebResourceError error,
              ) {
            if (!mounted ||
                error.isForMainFrame !=
                    true) {
              return;
            }

            setState(() {
              _loading = false;
              _mapReady = false;
              _errorMessage =
                  error.description;
            });
          },
        ),
      );

    _loadMap();
  }

  void _handleMapCenterMessage(
      JavaScriptMessage message,
      ) {
    try {
      final Object? decoded =
      jsonDecode(message.message);

      if (decoded is! Map) {
        return;
      }

      final Object? latitudeValue =
      decoded['latitude'];

      final Object? longitudeValue =
      decoded['longitude'];

      if (latitudeValue is! num ||
          longitudeValue is! num) {
        return;
      }

      if (!mounted) {
        return;
      }

      setState(() {
        _selectedLatitude =
            latitudeValue.toDouble();

        _selectedLongitude =
            longitudeValue.toDouble();
      });
    } catch (_) {
      // ?섎せ??WebView 硫붿떆吏??臾댁떆?쒕떎.
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
        '移댁뭅?ㅻ㏊ JavaScript ?ㅺ? ?놁뒿?덈떎.\n'
            'KAKAO_MAP_JS_KEY瑜??ㅼ젙??二쇱꽭??';
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

  Future<void>
  _moveToCurrentLocation() async {
    final double? latitude =
        widget.currentLatitude;

    final double? longitude =
        widget.currentLongitude;

    if (!_mapReady ||
        latitude == null ||
        longitude == null) {
      return;
    }

    try {
      await _webViewController
          .runJavaScript(
        'window.moveCenter('
            '$latitude,'
            '$longitude'
            ');',
      );
    } catch (_) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context)
          .showTopSnackBar(
        const SnackBar(
          content: Text(
            '?꾩옱 ?꾩튂濡?吏?꾨? ?대룞?섏? 紐삵뻽?듬땲??',
          ),
        ),
      );
    }
  }

  void _confirmLocation() {
    Navigator.of(context).pop(
      SellerMapLocationPickResult(
        latitude: _selectedLatitude,
        longitude: _selectedLongitude,
      ),
    );
  }

  String _buildMapHtml() {
    final String encodedKey =
    Uri.encodeQueryComponent(
      _kakaoMapKey,
    );

    final String initialCenterJson =
    _safeJson(
      <String, double>{
        'latitude':
        widget.initialLatitude,
        'longitude':
        widget.initialLongitude,
      },
    );

    final Map<String, double>?
    currentLocation =
    widget.currentLatitude != null &&
        widget.currentLongitude !=
            null
        ? <String, double>{
      'latitude':
      widget.currentLatitude!,
      'longitude':
      widget.currentLongitude!,
    }
        : null;

    final String currentLocationJson =
    _safeJson(currentLocation);

    return '''
<!DOCTYPE html>
<html lang="ko">
<head>
  <meta charset="UTF-8">

  <meta
    name="viewport"
    content="width=device-width,
             initial-scale=1.0,
             maximum-scale=1.0,
             user-scalable=no">

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
    window.onerror = function(
      message,
      source,
      line,
      column
    ) {
      const errorMessage =
        '吏??JavaScript ?ㅻ쪟: '
        + String(message)
        + ' / line='
        + String(line)
        + ' / column='
        + String(column);

      if (window.MapDebug) {
        MapDebug.postMessage(
          errorMessage
        );
      }

      if (window.MapError) {
        MapError.postMessage(
          errorMessage
        );
      }
    };
  </script>
</head>

<body>
  <div id="map"></div>

  <script>
    const initialCenter =
      $initialCenterJson;

    const currentLocation =
      $currentLocationJson;

    let map = null;

    let currentLocationOverlay =
      null;

    let readyPosted = false;

    function reportDebug(message) {
      if (window.MapDebug) {
        MapDebug.postMessage(
          String(message)
        );
      }
    }

    function reportError(message) {
      if (window.MapError) {
        MapError.postMessage(
          String(message)
        );
      }
    }

    function postReady() {
      if (readyPosted) {
        return;
      }

      readyPosted = true;

      if (window.MapReady) {
        MapReady.postMessage(
          'ready'
        );
      }
    }

    function postCenter() {
      if (
        map === null ||
        !window.MapCenter
      ) {
        return;
      }

      const center =
        map.getCenter();

      MapCenter.postMessage(
        JSON.stringify({
          latitude:
            center.getLat(),
          longitude:
            center.getLng()
        })
      );
    }

    function renderCurrentLocation() {
      if (
        map === null ||
        currentLocation === null
      ) {
        return;
      }

      const marker =
        document.createElement(
          'div'
        );

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

    window.moveCenter =
      function(
        latitude,
        longitude
      ) {
        if (map === null) {
          return;
        }

        map.setCenter(
          new kakao.maps.LatLng(
            latitude,
            longitude
          )
        );

        window.setTimeout(
          postCenter,
          100
        );
      };

    function initializeKakaoMap() {
      if (
        !window.kakao ||
        !window.kakao.maps
      ) {
        reportError(
          '移댁뭅??吏??媛앹껜媛 ?놁뒿?덈떎. '
          + 'JavaScript ?ㅼ? SDK ?꾨찓?몄쓣 '
          + '?뺤씤??二쇱꽭??'
        );

        return;
      }

      window.kakao.maps.load(
        function() {
          const mapContainer =
            document.getElementById(
              'map'
            );

          map =
            new window.kakao.maps.Map(
              mapContainer,
              {
                center:
                  new window.kakao.maps.LatLng(
                    initialCenter.latitude,
                    initialCenter.longitude
                  ),
                level: 3
              }
            );

          renderCurrentLocation();

          /*
           * 吏???대룞?대굹 ?뺣?쨌異뺤냼媛 ?앸궃 ??
           * 以묒떖 醫뚰몴瑜?Flutter???꾨떖?쒕떎.
           */
          window.kakao.maps.event
            .addListener(
              map,
              'idle',
              postCenter
            );

          window.kakao.maps.event
            .addListener(
              map,
              'tilesloaded',
              function() {
                postCenter();
                postReady();
              }
            );

          window.setTimeout(
            function() {
              postCenter();
              postReady();
            },
            2000
          );

          reportDebug(
            'map-initialized'
          );
        }
      );
    }

    const script =
      document.createElement(
        'script'
      );

    script.id =
      'kakao-map-sdk';

    script.type =
      'text/javascript';

    script.src =
      'https://dapi.kakao.com'
      + '/v2/maps/sdk.js'
      + '?appkey=$encodedKey'
      + '&autoload=false';

    script.onload =
      function() {
        initializeKakaoMap();
      };

    script.onerror =
      function() {
        reportError(
          '移댁뭅??吏??SDK瑜?'
          + '?ㅼ슫濡쒕뱶?섏? 紐삵뻽?듬땲??'
        );
      };

    document.head.appendChild(
      script
    );
  </script>
</body>
</html>
''';
  }

  String _safeJson(
      Object? value,
      ) {
    return jsonEncode(value).replaceAll(
      '</script',
      r'<\/script',
    );
  }

  @override
  Widget build(
      BuildContext context,
      ) {
    final String address =
        widget.addressLabel?.trim() ??
            '';

    final bool hasCurrentLocation =
        widget.currentLatitude != null &&
            widget.currentLongitude != null;

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          '吏?꾩뿉???꾩튂 ?좏깮',
        ),
      ),
      body: Stack(
        fit: StackFit.expand,
        children: [
          WebViewWidget(
            controller:
            _webViewController,
          ),

          /*
           * 吏??以묒떖??怨좎젙???먮뒗 ??대떎.
           * ?ъ슜?먮뒗 ?????린?????
           * 吏???먯껜瑜??吏곸씤??
           */
          const IgnorePointer(
            child: Center(
              child: Padding(
                padding: EdgeInsets.only(
                  bottom: 44,
                ),
                child: Icon(
                  Icons.location_pin,
                  size: 54,
                  color: Colors.red,
                  shadows: <Shadow>[
                    Shadow(
                      blurRadius: 8,
                      color: Colors.black38,
                      offset: Offset(0, 3),
                    ),
                  ],
                ),
              ),
            ),
          ),

          if (address.isNotEmpty)
            Positioned(
              top: 16,
              left: 16,
              right: 16,
              child: SafeArea(
                bottom: false,
                child: Card(
                  child: Padding(
                    padding:
                    const EdgeInsets.all(
                      12,
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.storefront_outlined,
                        ),
                        const SizedBox(
                          width: 8,
                        ),
                        Expanded(
                          child: Text(
                            address,
                            maxLines: 2,
                            overflow:
                            TextOverflow
                                .ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),

          if (hasCurrentLocation)
            Positioned(
              right: 16,
              bottom: 174,
              child: SafeArea(
                top: false,
                child: FloatingActionButton.small(
                  heroTag:
                  'seller-map-current-location',
                  onPressed:
                  _mapReady
                      ? _moveToCurrentLocation
                      : null,
                  tooltip:
                  '?꾩옱 ?꾩튂濡??대룞',
                  child: const Icon(
                    Icons.my_location_rounded,
                  ),
                ),
              ),
            ),

          Positioned(
            left: 16,
            right: 16,
            bottom: 16,
            child: SafeArea(
              top: false,
              child: Card(
                child: Padding(
                  padding:
                  const EdgeInsets.all(
                    16,
                  ),
                  child: Column(
                    mainAxisSize:
                    MainAxisSize.min,
                    crossAxisAlignment:
                    CrossAxisAlignment
                        .start,
                    children: [
                      const Text(
                        '媛?대뜲 ????ъ뾽???꾩튂???ㅻ룄濡?'
                            '吏?꾨? ?吏곸뿬 二쇱꽭??',
                      ),
                      const SizedBox(
                        height: 8,
                      ),
                      Text(
                        '?꾨룄 '
                            '${_selectedLatitude.toStringAsFixed(6)}'
                            ' 쨌 寃쎈룄 '
                            '${_selectedLongitude.toStringAsFixed(6)}',
                        style: Theme.of(context)
                            .textTheme
                            .bodySmall,
                      ),
                      const SizedBox(
                        height: 12,
                      ),
                      SizedBox(
                        width:
                        double.infinity,
                        child:
                        FilledButton.icon(
                          onPressed:
                          _mapReady
                              ? _confirmLocation
                              : null,
                          icon: const Icon(
                            Icons.check_rounded,
                          ),
                          label: const Text(
                            '???꾩튂濡??좏깮',
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),

          if (_loading)
            const ColoredBox(
              color: Color(
                0x88FFFFFF,
              ),
              child: Center(
                child:
                CircularProgressIndicator(),
              ),
            ),

          if (_errorMessage != null)
            ColoredBox(
              color: Theme.of(context)
                  .colorScheme
                  .surface,
              child: Center(
                child: Padding(
                  padding:
                  const EdgeInsets.all(
                    24,
                  ),
                  child: Column(
                    mainAxisSize:
                    MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.map_outlined,
                        size: 52,
                      ),
                      const SizedBox(
                        height: 16,
                      ),
                      const Text(
                        '移댁뭅?ㅻ㏊??遺덈윭?ㅼ? 紐삵뻽?듬땲??',
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight:
                          FontWeight.w800,
                        ),
                      ),
                      const SizedBox(
                        height: 8,
                      ),
                      Text(
                        _errorMessage!,
                        textAlign:
                        TextAlign.center,
                      ),
                      const SizedBox(
                        height: 18,
                      ),
                      FilledButton.icon(
                        onPressed: _loadMap,
                        icon: const Icon(
                          Icons.refresh_rounded,
                        ),
                        label: const Text(
                          '?ㅼ떆 ?쒕룄',
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
