import { Client } from "@stomp/stompjs";
import type {
  OrderChatEvent,
  OrderRealtimeEvent,
  SellerConnection,
  SupportTicketRealtimeEvent,
} from "../types";

function websocketUrl() {
  const protocol = window.location.protocol === "https:" ? "wss:" : "ws:";
  return `${protocol}//${window.location.host}/ws`;
}

export type SellerChatRealtimeSession = {
  disconnect: () => void;
  markRead: (orderPublicId: string, lastReadMessageId: number) => boolean;
};

export function connectSellerChatRealtime(
  connection: SellerConnection,
  onEvent: (event: OrderChatEvent) => void,
  onConnected?: () => void,
  onDisconnected?: () => void,
): SellerChatRealtimeSession {
  const client = new Client({
    brokerURL: websocketUrl(),
    connectHeaders: {
      Authorization: `Bearer ${connection.accessToken}`,
    },
    reconnectDelay: 3_000,
    heartbeatIncoming: 10_000,
    heartbeatOutgoing: 10_000,
    onConnect: () => {
      onConnected?.();
      client.subscribe(`/topic/stores/${connection.storeId}/chat`, (message) =>
        onEvent(JSON.parse(message.body) as OrderChatEvent),
      );
    },
    onWebSocketClose: () => onDisconnected?.(),
    onStompError: () => onDisconnected?.(),
  });

  client.activate();
  return {
    disconnect: () => {
      void client.deactivate();
    },
    markRead: (orderPublicId, lastReadMessageId) => {
      if (!client.connected) return false;
      client.publish({
        destination: `/app/orders/${orderPublicId}/chat/read`,
        headers: { "content-type": "application/json" },
        body: JSON.stringify({ lastReadMessageId }),
      });
      return true;
    },
  };
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
      onConnected();
      client.subscribe(
        `/topic/stores/${connection.storeId}/orders`,
        (message) => {
          onEvent(JSON.parse(message.body) as OrderRealtimeEvent);
        },
      );
    },
    onWebSocketClose: onDisconnected,
    onStompError: onDisconnected,
  });

  client.activate();
  return () => {
    void client.deactivate();
  };
}
export function connectAdminSupportRealtime(
  connection: SellerConnection,
  onEvent: (event: SupportTicketRealtimeEvent) => void,
  onConnected?: () => void,
  onDisconnected?: () => void,
): () => void {
  const client = new Client({
    brokerURL: websocketUrl(),
    connectHeaders: {
      Authorization: `Bearer ${connection.accessToken}`,
    },
    reconnectDelay: 3_000,
    heartbeatIncoming: 10_000,
    heartbeatOutgoing: 10_000,
    onConnect: () => {
      onConnected?.();

      client.subscribe("/topic/admin/support/tickets", (message) => {
        onEvent(JSON.parse(message.body) as SupportTicketRealtimeEvent);
      });
    },
    onWebSocketClose: () => onDisconnected?.(),
    onStompError: () => onDisconnected?.(),
  });

  client.activate();

  return () => {
    void client.deactivate();
  };
}
