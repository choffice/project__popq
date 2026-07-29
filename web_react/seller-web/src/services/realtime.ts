import { Client } from '@stomp/stompjs'
import type { OrderRealtimeEvent, SellerConnection } from '../types'

function websocketUrl() {
  const protocol = window.location.protocol === 'https:' ? 'wss:' : 'ws:'
  return `${protocol}//${window.location.host}/ws`
}

export function connectSellerRealtime(
  connection: SellerConnection,
  onEvent: (event: OrderRealtimeEvent) => void,
  onConnected: () => void,
  onDisconnected: () => void,
) {
  const client = new Client({
    brokerURL: websocketUrl(),
    connectHeaders: {
      Authorization: `Bearer ${connection.accessToken}`,
    },
    reconnectDelay: 3_000,
    heartbeatIncoming: 10_000,
    heartbeatOutgoing: 10_000,
    onConnect: () => {
      onConnected()
      client.subscribe(
        `/topic/stores/${connection.storeId}/orders`,
        (message) => {
          onEvent(JSON.parse(message.body) as OrderRealtimeEvent)
        },
      )
    },
    onWebSocketClose: onDisconnected,
    onStompError: onDisconnected,
  })

  client.activate()
  return () => {
    void client.deactivate()
  }
}
