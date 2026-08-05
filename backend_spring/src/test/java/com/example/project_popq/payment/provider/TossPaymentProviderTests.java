package com.example.project_popq.payment.provider;

import static org.assertj.core.api.Assertions.assertThat;

import com.example.project_popq.payment.config.TossPaymentProperties;
import com.sun.net.httpserver.HttpServer;
import java.io.IOException;
import java.net.InetSocketAddress;
import java.nio.charset.StandardCharsets;
import java.util.concurrent.atomic.AtomicReference;
import org.junit.jupiter.api.AfterEach;
import org.junit.jupiter.api.Test;

class TossPaymentProviderTests {

    private HttpServer server;

    @AfterEach
    void stopServer() {
        if (server != null) {
            server.stop(0);
        }
    }

    @Test
    void forwardsThePopqIdempotencyKeyToTossApproval() throws IOException {
        AtomicReference<String> idempotencyHeader = new AtomicReference<>();
        AtomicReference<String> requestBody = new AtomicReference<>();
        server = HttpServer.create(new InetSocketAddress(0), 0);
        server.createContext("/v1/payments/confirm", exchange -> {
            idempotencyHeader.set(
                    exchange.getRequestHeaders().getFirst("Idempotency-Key")
            );
            requestBody.set(new String(
                    exchange.getRequestBody().readAllBytes(),
                    StandardCharsets.UTF_8
            ));
            byte[] response = """
                    {"paymentKey":"provider-payment-key","totalAmount":6800}
                    """.getBytes(StandardCharsets.UTF_8);
            exchange.getResponseHeaders().set(
                    "Content-Type",
                    "application/json"
            );
            exchange.sendResponseHeaders(200, response.length);
            exchange.getResponseBody().write(response);
            exchange.close();
        });
        server.start();

        TossPaymentProvider provider = new TossPaymentProvider(
                new TossPaymentProperties(
                        "http://127.0.0.1:" + server.getAddress().getPort(),
                        "test-secret-key"
                )
        );

        PaymentApprovalResult result = provider.approve(
                new PaymentApprovalCommand(
                        "order-123456",
                        6800,
                        "client-payment-key",
                        "payment-idempotency-key",
                        false
                )
        );

        assertThat(result.success()).isTrue();
        assertThat(result.providerPaymentKey()).isEqualTo("provider-payment-key");
        assertThat(result.approvedAmount()).isEqualTo(6800);
        assertThat(idempotencyHeader.get())
                .isEqualTo("payment-idempotency-key");
        assertThat(requestBody.get())
                .contains("\"paymentKey\":\"client-payment-key\"")
                .contains("\"orderId\":\"order-123456\"")
                .contains("\"amount\":6800");
    }
}
