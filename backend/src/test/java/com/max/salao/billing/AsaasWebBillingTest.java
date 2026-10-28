package com.max.salao.billing;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;

import java.net.InetSocketAddress;
import java.nio.charset.StandardCharsets;
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

/** Conversa com o Asaas contra um servidor falso: cabeçalhos, corpo do link recorrente, reaproveitar e cancelar. */
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
            requests.add(ex.getRequestMethod() + " " + ex.getRequestURI().getPath() + " key=" + ex.getRequestHeaders().getFirst("access_token")
                    + " ua=" + ex.getRequestHeaders().getFirst("User-Agent") + " " + body);
            String path = ex.getRequestURI().getPath();
            String res;
            int status = 200;
            if (path.equals("/v3/paymentLinks") && ex.getRequestMethod().equals("POST")) {
                res = "{\"id\":\"link_9\",\"url\":\"https://www.asaas.com/c/xyz\"}";
            } else if (path.equals("/v3/paymentLinks/link_9")) {
                res = "{\"id\":\"link_9\",\"url\":\"https://www.asaas.com/c/xyz\",\"active\":true,\"deleted\":false}";
            } else if (path.equals("/v3/paymentLinks/link_gone")) {
                res = "{\"errors\":[{\"description\":\"não encontrado\"}]}";
                status = 404;
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
                4990, "https://salao.test"), json);
    }

    @AfterEach
    void stop() {
        server.stop(0);
    }

    @Test
    void createsARecurringMonthlyLinkWithTheSalonPrice() throws Exception {
        Salon salon = new Salon();
        salon.setName("Studio Bella");
        salon.setSlug("bella");
        WebBilling.Link link = client.createLink(salon);
        assertThat(link.id()).isEqualTo("link_9");
        assertThat(link.url()).isEqualTo("https://www.asaas.com/c/xyz");
        String sent = requests.get(0);
        assertThat(sent).startsWith("POST /v3/paymentLinks key=chave-secreta ua=SalaoMax");
        JsonNode body = json.readTree(sent.substring(sent.indexOf('{')));
        assertThat(body.get("chargeType").asText()).isEqualTo("RECURRENT");
        assertThat(body.get("subscriptionCycle").asText()).isEqualTo("MONTHLY");
        assertThat(body.get("billingType").asText()).isEqualTo("UNDEFINED");
        assertThat(body.get("value").decimalValue()).isEqualByComparingTo("49.90");
        assertThat(body.at("/callback/successUrl").asText()).isEqualTo("https://salao.test/painel/assinatura?assinatura=ok");
    }

    @Test
    void reusesAnExistingLinkAndCancelsSubscriptions() {
        assertThat(client.findLink("link_9")).hasValueSatisfying(l -> assertThat(l.url()).isEqualTo("https://www.asaas.com/c/xyz"));
        assertThat(client.findLink("link_gone")).isEmpty();
        client.cancelSubscription("sub_1");
        client.cancelSubscription("sub_inexistente"); // já não existe: nada a fazer
        assertThat(requests).anyMatch(r -> r.startsWith("DELETE /v3/subscriptions/sub_1 "));
    }

    @Test
    void refusesWhenNotConfigured() {
        AsaasWebBilling off = new AsaasWebBilling(new AsaasProperties("", "", null, null, ""), json);
        assertThatThrownBy(() -> off.createLink(new Salon())).isInstanceOf(BusinessException.class).hasMessageContaining("configurado");
    }
}
