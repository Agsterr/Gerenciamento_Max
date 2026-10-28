package com.max.salao.billing;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;

import java.net.InetSocketAddress;
import java.nio.charset.StandardCharsets;
import java.time.Clock;
import java.time.Instant;
import java.time.ZoneOffset;
import java.util.ArrayList;
import java.util.List;

import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.databind.ObjectMapper;
import com.max.salao.salon.Salon;
import com.max.salao.shared.BusinessException;
import com.sun.net.httpserver.HttpServer;
import org.junit.jupiter.api.AfterEach;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;

/** Conversa com o Asaas contra um servidor falso: cliente, assinatura mensal, link da cobrança e cancelamento. */
class AsaasWebBillingTest {

    private final ObjectMapper json = new ObjectMapper();
    private final List<String> requests = new ArrayList<>();
    private HttpServer server;
    private AsaasWebBilling client;

    @BeforeEach
    void start() throws Exception {
        server = HttpServer.create(new InetSocketAddress("127.0.0.1", 0), 0);
        server.createContext("/v3", ex -> {
            String body = new String(ex.getRequestBody().readAllBytes(), StandardCharsets.UTF_8);
            String path = ex.getRequestURI().getPath();
            requests.add(ex.getRequestMethod() + " " + path + " key=" + ex.getRequestHeaders().getFirst("access_token")
                    + " ua=" + ex.getRequestHeaders().getFirst("User-Agent") + " " + body);
            String res;
            int status = 200;
            if (path.equals("/v3/customers") && ex.getRequestMethod().equals("POST")) {
                if (body.contains("\"cpfCnpj\":\"00000000000\"")) {
                    res = "{\"errors\":[{\"code\":\"invalid_object\",\"description\":\"CPF/CNPJ inválido\"}]}";
                    status = 400;
                } else {
                    res = "{\"id\":\"cus_9\"}";
                }
            } else if (path.equals("/v3/subscriptions") && ex.getRequestMethod().equals("POST")) {
                res = "{\"id\":\"sub_9\"}";
            } else if (path.equals("/v3/subscriptions/sub_9/payments")) {
                res = "{\"data\":[{\"id\":\"pay_1\",\"status\":\"PENDING\",\"invoiceUrl\":\"https://www.asaas.com/i/abc\"}]}";
            } else if (path.equals("/v3/subscriptions/sub_paga/payments")) {
                res = "{\"data\":[{\"id\":\"pay_2\",\"status\":\"RECEIVED\",\"invoiceUrl\":\"https://www.asaas.com/i/paga\"}]}";
            } else if (path.equals("/v3/subscriptions/sub_1")) {
                res = "{\"deleted\":true,\"id\":\"sub_1\"}";
            } else {
                res = "{}";
                status = 404;
            }
            byte[] bytes = res.getBytes(StandardCharsets.UTF_8);
            ex.getResponseHeaders().add("Content-Type", "application/json");
            ex.sendResponseHeaders(status, bytes.length);
            ex.getResponseBody().write(bytes);
            ex.close();
        });
        server.start();
        client = new AsaasWebBilling(new AsaasProperties("chave-secreta", "token", "http://127.0.0.1:" + server.getAddress().getPort() + "/v3",
                4990, "https://salao.test"), json, Clock.fixed(Instant.parse("2026-10-28T12:00:00Z"), ZoneOffset.UTC));
    }

    @AfterEach
    void stop() {
        server.stop(0);
    }

    private static Salon salon() {
        Salon salon = new Salon();
        salon.setName("Studio Bella");
        salon.setSlug("bella");
        return salon;
    }

    @Test
    void createsCustomerAndMonthlySubscriptionAndReturnsTheFirstInvoiceUrl() throws Exception {
        WebBilling.Subscribed s = client.subscribe(salon(), "Maria", "maria@teste.com", "123.456.789-09");
        assertThat(s.customerId()).isEqualTo("cus_9");
        assertThat(s.subscriptionId()).isEqualTo("sub_9");
        assertThat(s.url()).isEqualTo("https://www.asaas.com/i/abc");

        String customer = requests.get(0);
        assertThat(customer).startsWith("POST /v3/customers key=chave-secreta ua=SalaoMax");
        JsonNode c = json.readTree(customer.substring(customer.indexOf('{')));
        assertThat(c.get("cpfCnpj").asText()).isEqualTo("12345678909");
        assertThat(c.get("email").asText()).isEqualTo("maria@teste.com");

        String subscription = requests.get(1);
        JsonNode body = json.readTree(subscription.substring(subscription.indexOf('{')));
        assertThat(body.get("customer").asText()).isEqualTo("cus_9");
        assertThat(body.get("billingType").asText()).isEqualTo("UNDEFINED");
        assertThat(body.get("cycle").asText()).isEqualTo("MONTHLY");
        assertThat(body.get("value").decimalValue()).isEqualByComparingTo("49.90");
        assertThat(body.get("nextDueDate").asText()).isEqualTo("2026-10-29");
    }

    @Test
    void reusesAnExistingCustomerAndRefusesWithoutADocument() {
        Salon known = salon();
        known.setAsaasCustomerId("cus_existente");
        client.subscribe(known, "Maria", "maria@teste.com", null);
        assertThat(requests).noneMatch(r -> r.startsWith("POST /v3/customers"));

        assertThatThrownBy(() -> client.subscribe(salon(), "Maria", "maria@teste.com", "123"))
                .isInstanceOf(BusinessException.class).hasMessageContaining("CPF ou CNPJ");
        // o Asaas recusou o documento: a mensagem dele chega para a pessoa
        assertThatThrownBy(() -> client.subscribe(salon(), "Maria", "maria@teste.com", "000.000.000-00"))
                .isInstanceOf(BusinessException.class).hasMessage("CPF/CNPJ inválido");
    }

    @Test
    void findsOnlyAnOpenInvoiceAndCancelsSubscriptions() {
        assertThat(client.openPaymentUrl("sub_9")).contains("https://www.asaas.com/i/abc");
        assertThat(client.openPaymentUrl("sub_paga")).isEmpty(); // já paga: não há cobrança em aberto
        assertThat(client.openPaymentUrl("sub_apagada")).isEmpty();
        client.cancelSubscription("sub_1");
        client.cancelSubscription("sub_inexistente"); // já não existe: nada a fazer
        assertThat(requests).anyMatch(r -> r.startsWith("DELETE /v3/subscriptions/sub_1 "));
    }

    @Test
    void refusesWhenNotConfigured() {
        AsaasWebBilling off = new AsaasWebBilling(new AsaasProperties("", "", null, null, ""), json, Clock.systemUTC());
        assertThatThrownBy(() -> off.subscribe(salon(), "Maria", "m@t.com", "12345678909"))
                .isInstanceOf(BusinessException.class).hasMessageContaining("configurado");
    }
}
