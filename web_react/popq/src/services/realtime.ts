import { Client } from '@stomp/stompjs'
import type { OrderRealtimeEvent } from '../types'

export function connectOrderRealtime(
  orderPublicId: string,
  onEvent: (event: OrderRealtimeEvent) => void,
  onConnectionChange: (connected: boolean) => void,
): () => void {
  const protocol = window.location.protocol === 'https:' ? 'wss' : 'ws'
  const client = new Client({
    brokerURL: `${protocol}://${window.location.host}/ws`,
    reconnectDelay: 3000,
    heartbeatIncoming: 10000,
    heartbeatOutgoing: 10000,
    onConnect: () => {
      onConnectionChange(true)
      client.subscribe(
        `/user/queue/orders/${orderPublicId}`,
        (message) => onEvent(JSON.parse(message.body) as OrderRealtimeEvent),
      )
    },
    onWebSocketClose: () => onConnectionChange(false),
    onStompError: () => onConnectionChange(false),
  })
  client.activate()
  return () => void client.deactivate()
}
