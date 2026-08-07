import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:stomp_dart_client/stomp_dart_client.dart';

import '../network/popq_api_client.dart';
import 'popq_realtime_connection_status.dart';
import 'popq_realtime_event.dart';

typedef PopqRealtimeEventCallback = void Function(PopqRealtimeEvent event);

typedef PopqOrderRealtimeEventCallback =
    void Function(PopqOrderRealtimeEvent event);

typedef _PopqRealtimeJsonCallback = void Function(Map<String, Object?> json);

typedef PopqRealtimeErrorCallback = void Function(Object error);

class PopqRealtimeSubscription {
  PopqRealtimeSubscription._({required VoidCallback onCancel})
    : _onCancel = onCancel;

  VoidCallback? _onCancel;

  bool get isCancelled => _onCancel == null;

  void cancel() {
    final onCancel = _onCancel;

    if (onCancel == null) {
      return;
    }

    _onCancel = null;
    onCancel();
  }
}

class PopqRealtimeClient extends ChangeNotifier {
  PopqRealtimeClient({
    required Uri webSocketUri,
    required AccessTokenReader accessTokenReader,
    this.enableLogs = false,
    this.connectionTimeout = const Duration(seconds: 10),
    this.heartbeatInterval = const Duration(seconds: 10),
  }) : _webSocketUri = webSocketUri,
       _accessTokenReader = accessTokenReader;

  final Uri _webSocketUri;
  final AccessTokenReader _accessTokenReader;

  final bool enableLogs;
  final Duration connectionTimeout;
  final Duration heartbeatInterval;

  final Map<String, _DestinationSubscription> _destinationSubscriptions =
      <String, _DestinationSubscription>{};

  StompClient? _stompClient;
  Timer? _reconnectTimer;

  PopqRealtimeConnectionStatus _status =
      PopqRealtimeConnectionStatus.disconnected;

  Object? _lastError;

  bool _shouldStayConnected = false;
  bool _connectionAttemptInProgress = false;
  bool _disposed = false;

  int _clientGeneration = 0;
  int _nextListenerId = 0;
  int _reconnectAttempt = 0;
  int _connectionEpoch = 0;

  PopqRealtimeConnectionStatus get status => _status;

  Object? get lastError => _lastError;

  String? get lastErrorMessage {
    final error = _lastError;

    if (error == null) {
      return null;
    }

    return error.toString();
  }

  bool get isConnected {
    return _status.isConnected && (_stompClient?.connected ?? false);
  }

  bool get shouldUseRestFallback {
    return !isConnected;
  }

  /**
   * STOMP 연결에 성공할 때마다 증가합니다.
   *
   * 첫 연결 성공: 1
   * 재연결 성공: 2 이상
   *
   * 채팅 화면은 이 값이 변경된 것을 확인한 뒤
   * REST로 최신 메시지를 한 번 동기화할 수 있습니다.
   */
  int get connectionEpoch => _connectionEpoch;

  Uri get webSocketUri => _webSocketUri;

  Future<void> connect() async {
    _checkNotDisposed();

    _shouldStayConnected = true;

    if (isConnected ||
        _connectionAttemptInProgress ||
        _reconnectTimer != null) {
      return;
    }

    _reconnectAttempt = 0;

    await _startConnection(reconnecting: _connectionEpoch > 0);
  }

  /**
   * 앱이 백그라운드로 이동할 때 사용합니다.
   *
   * 등록된 구독 listener는 유지하므로,
   * 포그라운드 복귀 후 connect()를 호출하면
   * 기존 주문 채널을 다시 구독합니다.
   */
  void suspend() {
    if (_disposed) {
      return;
    }

    _shouldStayConnected = false;
    _reconnectTimer?.cancel();
    _reconnectTimer = null;

    _stopCurrentClient();
    _setStatus(PopqRealtimeConnectionStatus.disconnected);
  }

  /**
   * 로그아웃이나 앱 종료 시 사용합니다.
   *
   * clearSubscriptions가 true이면 등록된 모든
   * 주문·사업장·구매자 채널 listener도 삭제합니다.
   */
  void disconnect({bool clearSubscriptions = true}) {
    if (_disposed) {
      return;
    }

    _shouldStayConnected = false;
    _reconnectTimer?.cancel();
    _reconnectTimer = null;

    _unsubscribeAllUnderlyingSubscriptions();
    _stopCurrentClient();

    if (clearSubscriptions) {
      _destinationSubscriptions.clear();
    }

    _lastError = null;

    _setStatus(PopqRealtimeConnectionStatus.disconnected);
  }

  PopqRealtimeSubscription subscribeToOrderChat({
    required String orderPublicId,
    required PopqRealtimeEventCallback onEvent,
    PopqRealtimeErrorCallback? onError,
  }) {
    final normalizedOrderPublicId = _requireNonEmptyValue(
      orderPublicId,
      'orderPublicId',
    );

    return _subscribe(
      destination: '/topic/orders/$normalizedOrderPublicId/chat',
      onJson: (Map<String, Object?> json) {
        onEvent(PopqRealtimeEvent.fromJson(json));
      },
      onError: onError,
    );
  }

  PopqRealtimeSubscription subscribeToCustomerChat({
    required PopqRealtimeEventCallback onEvent,
    PopqRealtimeErrorCallback? onError,
  }) {
    return _subscribe(
      destination: '/user/queue/chat',
      onJson: (Map<String, Object?> json) {
        onEvent(PopqRealtimeEvent.fromJson(json));
      },
      onError: onError,
    );
  }

  PopqRealtimeSubscription subscribeToStoreChat({
    required int storeId,
    required PopqRealtimeEventCallback onEvent,
    PopqRealtimeErrorCallback? onError,
  }) {
    if (storeId <= 0) {
      throw ArgumentError.value(storeId, 'storeId', 'storeId는 1 이상이어야 합니다.');
    }

    return _subscribe(
      destination: '/topic/stores/$storeId/chat',
      onJson: (Map<String, Object?> json) {
        onEvent(PopqRealtimeEvent.fromJson(json));
      },
      onError: onError,
    );
  }

  PopqRealtimeSubscription subscribeToCustomerOrders({
    required PopqOrderRealtimeEventCallback onEvent,
    PopqRealtimeErrorCallback? onError,
  }) {
    return _subscribe(
      destination: '/user/queue/orders',
      onJson: (Map<String, Object?> json) {
        onEvent(PopqOrderRealtimeEvent.fromJson(json));
      },
      onError: onError,
    );
  }

  PopqRealtimeSubscription subscribeToStoreOrders({
    required int storeId,
    required PopqOrderRealtimeEventCallback onEvent,
    PopqRealtimeErrorCallback? onError,
  }) {
    if (storeId <= 0) {
      throw ArgumentError.value(storeId, 'storeId', 'storeId는 1 이상이어야 합니다.');
    }

    return _subscribe(
      destination: '/topic/stores/$storeId/orders',
      onJson: (Map<String, Object?> json) {
        onEvent(PopqOrderRealtimeEvent.fromJson(json));
      },
      onError: onError,
    );
  }

  /**
   * WebSocket 메시지 전송을 시도합니다.
   *
   * true:
   * STOMP SEND 요청을 정상적으로 전달함
   *
   * false:
   * WebSocket이 연결되지 않았거나 전송 도중 실패함
   *
   * false이면 채팅 Repository에서 기존 REST 전송 API를
   * fallback으로 사용하게 됩니다.
   */
  bool sendChatMessage({
    required String orderPublicId,
    required String content,
    required String clientMessageId,
  }) {
    final normalizedOrderPublicId = _requireNonEmptyValue(
      orderPublicId,
      'orderPublicId',
    );

    final normalizedContent = _requireNonEmptyValue(content, 'content');

    final normalizedClientMessageId = _requireNonEmptyValue(
      clientMessageId,
      'clientMessageId',
    );

    return _sendJson(
      destination: '/app/orders/$normalizedOrderPublicId/chat/messages',
      body: <String, Object?>{
        'content': normalizedContent,
        'clientMessageId': normalizedClientMessageId,
      },
    );
  }

  /**
   * 사용자가 실제 화면에서 확인한 마지막 상대 메시지까지만
   * 읽음 처리합니다.
   */
  bool markChatMessagesAsRead({
    required String orderPublicId,
    required int lastReadMessageId,
  }) {
    final normalizedOrderPublicId = _requireNonEmptyValue(
      orderPublicId,
      'orderPublicId',
    );

    if (lastReadMessageId <= 0) {
      throw ArgumentError.value(
        lastReadMessageId,
        'lastReadMessageId',
        'lastReadMessageId는 1 이상이어야 합니다.',
      );
    }

    return _sendJson(
      destination: '/app/orders/$normalizedOrderPublicId/chat/read',
      body: <String, Object?>{'lastReadMessageId': lastReadMessageId},
    );
  }

  Future<void> _startConnection({required bool reconnecting}) async {
    if (_disposed || !_shouldStayConnected || _connectionAttemptInProgress) {
      return;
    }

    _reconnectTimer?.cancel();
    _reconnectTimer = null;
    _connectionAttemptInProgress = true;

    _setStatus(
      reconnecting
          ? PopqRealtimeConnectionStatus.reconnecting
          : PopqRealtimeConnectionStatus.connecting,
    );

    String? accessToken;

    try {
      accessToken = (await _accessTokenReader())?.trim();
    } on Object catch (error) {
      _connectionAttemptInProgress = false;
      _lastError = error;
      _scheduleReconnect();
      return;
    }

    if (_disposed || !_shouldStayConnected) {
      _connectionAttemptInProgress = false;
      return;
    }

    if (accessToken == null || accessToken.isEmpty) {
      _connectionAttemptInProgress = false;
      _lastError = StateError('WebSocket 연결에 필요한 로그인 토큰이 없습니다.');

      _setStatus(PopqRealtimeConnectionStatus.failed);

      return;
    }

    _stopCurrentClient();

    final generation = ++_clientGeneration;

    late final StompClient client;

    client = StompClient(
      config: StompConfig(
        url: _webSocketUri.toString(),
        reconnectDelay: Duration.zero,
        connectionTimeout: connectionTimeout,
        heartbeatIncoming: heartbeatInterval,
        heartbeatOutgoing: heartbeatInterval,
        stompConnectHeaders: <String, String>{
          'Authorization': 'Bearer $accessToken',
        },
        onConnect: (StompFrame frame) {
          _handleConnected(generation);
        },
        onDisconnect: (StompFrame frame) {
          _handleConnectionLost(generation, StateError('STOMP 연결이 종료되었습니다.'));
        },
        onStompError: (StompFrame frame) {
          _handleConnectionLost(
            generation,
            StateError(
              frame.body?.trim().isNotEmpty == true
                  ? frame.body!.trim()
                  : 'STOMP 서버 오류가 발생했습니다.',
            ),
          );
        },
        onWebSocketError: (dynamic error) {
          _handleConnectionLost(
            generation,
            error is Object ? error : StateError('WebSocket 연결 오류가 발생했습니다.'),
          );
        },
        onWebSocketDone: () {
          _handleConnectionLost(
            generation,
            StateError('WebSocket 연결이 종료되었습니다.'),
          );
        },
        onDebugMessage: enableLogs
            ? (String message) {
                debugPrint('[POPQ STOMP] $message');
              }
            : (String message) {},
      ),
    );

    _stompClient = client;

    try {
      client.activate();
    } on Object catch (error) {
      _handleConnectionLost(generation, error);
    }
  }

  void _handleConnected(int generation) {
    if (_disposed || generation != _clientGeneration) {
      return;
    }

    if (!_shouldStayConnected) {
      _stopCurrentClient();
      return;
    }

    _connectionAttemptInProgress = false;
    _reconnectAttempt = 0;
    _lastError = null;
    _connectionEpoch++;

    _clearUnderlyingSubscriptionHandles();

    _setStatus(PopqRealtimeConnectionStatus.connected);

    _activateAllSubscriptions();
  }

  void _handleConnectionLost(int generation, Object error) {
    if (_disposed || generation != _clientGeneration) {
      return;
    }

    _lastError = error;
    _connectionAttemptInProgress = false;

    _stopCurrentClient();

    if (!_shouldStayConnected) {
      _setStatus(PopqRealtimeConnectionStatus.disconnected);

      return;
    }

    _scheduleReconnect();
  }

  void _scheduleReconnect() {
    if (_disposed || !_shouldStayConnected) {
      return;
    }

    if (_reconnectTimer != null) {
      return;
    }

    final delay = _reconnectDelayForAttempt(_reconnectAttempt);

    _reconnectAttempt++;

    _setStatus(PopqRealtimeConnectionStatus.reconnecting);

    _log('재연결 예정: ${delay.inSeconds}초 후');

    _reconnectTimer = Timer(delay, () {
      _reconnectTimer = null;

      unawaited(_startConnection(reconnecting: true));
    });
  }

  Duration _reconnectDelayForAttempt(int attempt) {
    const delaysInSeconds = <int>[2, 4, 8, 16, 30];

    final index = attempt < delaysInSeconds.length
        ? attempt
        : delaysInSeconds.length - 1;

    return Duration(seconds: delaysInSeconds[index]);
  }

  PopqRealtimeSubscription _subscribe({
    required String destination,
    required _PopqRealtimeJsonCallback onJson,
    PopqRealtimeErrorCallback? onError,
  }) {
    _checkNotDisposed();

    final listenerId = ++_nextListenerId;

    final subscription = _destinationSubscriptions.putIfAbsent(
      destination,
      () => _DestinationSubscription(destination: destination),
    );

    subscription.listeners[listenerId] = _RealtimeListener(
      onJson: onJson,
      onError: onError,
    );

    if (isConnected) {
      _activateSubscription(subscription);
    }

    return PopqRealtimeSubscription._(
      onCancel: () {
        _removeListener(destination: destination, listenerId: listenerId);
      },
    );
  }

  void _removeListener({required String destination, required int listenerId}) {
    final subscription = _destinationSubscriptions[destination];

    if (subscription == null) {
      return;
    }

    subscription.listeners.remove(listenerId);

    if (subscription.listeners.isNotEmpty) {
      return;
    }

    final unsubscribe = subscription.stompUnsubscribe;

    subscription.stompUnsubscribe = null;

    if (unsubscribe != null) {
      try {
        unsubscribe();
      } on Object catch (error) {
        _log('구독 해제 중 오류: $destination / $error');
      }
    }

    _destinationSubscriptions.remove(destination);
  }

  void _activateAllSubscriptions() {
    for (final subscription in _destinationSubscriptions.values) {
      _activateSubscription(subscription);
    }
  }

  void _activateSubscription(_DestinationSubscription subscription) {
    if (_disposed ||
        !isConnected ||
        subscription.listeners.isEmpty ||
        subscription.stompUnsubscribe != null) {
      return;
    }

    final client = _stompClient;

    if (client == null || !client.connected) {
      return;
    }

    try {
      subscription.stompUnsubscribe = client.subscribe(
        destination: subscription.destination,
        callback: (StompFrame frame) {
          _handleSubscriptionFrame(subscription.destination, frame);
        },
      );

      _log('구독 성공: ${subscription.destination}');
    } on Object catch (error) {
      _notifySubscriptionError(subscription, error);

      _handleConnectionLost(_clientGeneration, error);
    }
  }

  void _handleSubscriptionFrame(String destination, StompFrame frame) {
    final subscription = _destinationSubscriptions[destination];

    if (subscription == null || subscription.listeners.isEmpty) {
      return;
    }

    final body = frame.body;

    if (body == null || body.trim().isEmpty) {
      _notifySubscriptionError(
        subscription,
        const FormatException('실시간 이벤트 본문이 비어 있습니다.'),
      );

      return;
    }

    try {
      final decoded = jsonDecode(body);

      if (decoded is! Map) {
        throw const FormatException('실시간 이벤트는 JSON 객체여야 합니다.');
      }

      final json = Map<String, Object?>.from(decoded);
      final listeners = List<_RealtimeListener>.of(
        subscription.listeners.values,
      );

      for (final listener in listeners) {
        try {
          listener.onJson(json);
        } on Object catch (error) {
          listener.onError?.call(error);
        }
      }
    } on Object catch (error) {
      _notifySubscriptionError(subscription, error);
    }
  }

  void _notifySubscriptionError(
    _DestinationSubscription subscription,
    Object error,
  ) {
    _log(
      '실시간 구독 오류: '
      '${subscription.destination} / $error',
    );

    final listeners = List<_RealtimeListener>.of(subscription.listeners.values);

    for (final listener in listeners) {
      listener.onError?.call(error);
    }
  }

  bool _sendJson({
    required String destination,
    required Map<String, Object?> body,
  }) {
    if (_disposed || !isConnected) {
      return false;
    }

    final client = _stompClient;

    if (client == null || !client.connected) {
      return false;
    }

    try {
      client.send(
        destination: destination,
        headers: const <String, String>{'content-type': 'application/json'},
        body: jsonEncode(body),
      );

      return true;
    } on Object catch (error) {
      _handleConnectionLost(_clientGeneration, error);

      return false;
    }
  }

  void _unsubscribeAllUnderlyingSubscriptions() {
    for (final subscription in _destinationSubscriptions.values) {
      final unsubscribe = subscription.stompUnsubscribe;

      subscription.stompUnsubscribe = null;

      if (unsubscribe == null) {
        continue;
      }

      try {
        unsubscribe();
      } on Object catch (error) {
        _log(
          '구독 해제 오류: '
          '${subscription.destination} / $error',
        );
      }
    }
  }

  void _clearUnderlyingSubscriptionHandles() {
    for (final subscription in _destinationSubscriptions.values) {
      subscription.stompUnsubscribe = null;
    }
  }

  void _stopCurrentClient() {
    final client = _stompClient;

    _stompClient = null;
    _connectionAttemptInProgress = false;

    /*
     * 기존 클라이언트에서 늦게 도착하는 callback을
     * 무시하도록 generation을 증가시킵니다.
     */
    _clientGeneration++;

    _clearUnderlyingSubscriptionHandles();

    if (client == null) {
      return;
    }

    try {
      client.deactivate();
    } on Object catch (error) {
      _log('STOMP 연결 종료 중 오류: $error');
    }
  }

  void _setStatus(PopqRealtimeConnectionStatus nextStatus) {
    if (_status == nextStatus) {
      return;
    }

    _status = nextStatus;

    if (!_disposed) {
      notifyListeners();
    }
  }

  String _requireNonEmptyValue(String value, String fieldName) {
    final normalized = value.trim();

    if (normalized.isEmpty) {
      throw ArgumentError.value(
        value,
        fieldName,
        '$fieldName 값은 비어 있을 수 없습니다.',
      );
    }

    return normalized;
  }

  void _checkNotDisposed() {
    if (_disposed) {
      throw StateError('이미 dispose된 PopqRealtimeClient입니다.');
    }
  }

  void _log(String message) {
    if (!enableLogs) {
      return;
    }

    debugPrint('[POPQ Realtime] $message');
  }

  @override
  void dispose() {
    if (_disposed) {
      return;
    }

    _shouldStayConnected = false;
    _reconnectTimer?.cancel();
    _reconnectTimer = null;

    _unsubscribeAllUnderlyingSubscriptions();
    _stopCurrentClient();

    _destinationSubscriptions.clear();
    _disposed = true;

    super.dispose();
  }
}

class _DestinationSubscription {
  _DestinationSubscription({required this.destination});

  final String destination;

  final Map<int, _RealtimeListener> listeners = <int, _RealtimeListener>{};

  StompUnsubscribe? stompUnsubscribe;
}

class _RealtimeListener {
  const _RealtimeListener({required this.onJson, required this.onError});

  final _PopqRealtimeJsonCallback onJson;
  final PopqRealtimeErrorCallback? onError;
}
