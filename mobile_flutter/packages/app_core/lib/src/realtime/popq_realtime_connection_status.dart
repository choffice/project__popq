enum PopqRealtimeConnectionStatus {
  disconnected,
  connecting,
  connected,
  reconnecting,
  failed;

  bool get isConnected {
    return this == PopqRealtimeConnectionStatus.connected;
  }

  bool get isConnecting {
    return this == PopqRealtimeConnectionStatus.connecting ||
        this == PopqRealtimeConnectionStatus.reconnecting;
  }

  bool get isDisconnected {
    return this == PopqRealtimeConnectionStatus.disconnected ||
        this == PopqRealtimeConnectionStatus.failed;
  }

  bool get shouldUseRestFallback {
    return this != PopqRealtimeConnectionStatus.connected;
  }
}