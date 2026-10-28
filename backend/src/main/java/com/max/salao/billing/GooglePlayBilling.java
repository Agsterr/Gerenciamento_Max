package com.max.salao.billing;

import java.io.IOException;
import java.net.URI;
import java.net.URLEncoder;
import java.net.http.HttpClient;
import java.net.http.HttpRequest;
import java.net.http.HttpResponse;
import java.nio.charset.StandardCharsets;
import java.time.Duration;
import java.time.Instant;

import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.databind.ObjectMapper;
import com.max.salao.shared.BusinessException;
import com.max.salao.shared.GoogleAccessToken;
import org.springframework.stereotype.Component;

/** Android Publisher API v3, autenticada com a conta de serviço (OAuth2 por JWT assinado). */
@Component
class GooglePlayBilling implements PlayBilling {

    private static final String SCOPE = "https://www.googleapis.com/auth/androidpublisher";
    private static final String DEFAULT_API = "https://androidpublisher.googleapis.com/androidpublisher/v3/applications/";

    private final String api;
    private final BillingProperties props;
    private final ObjectMapper json;
    private final HttpClient http = HttpClient.newBuilder().connectTimeout(Duration.ofSeconds(5)).build();

    private final GoogleAccessToken tokens;

    @org.springframework.beans.factory.annotation.Autowired
    GooglePlayBilling(BillingProperties props, ObjectMapper json) {
        this(props, json, DEFAULT_API);
    }

    /** Endereço da API configurável só para os testes (servidor falso). */
    GooglePlayBilling(BillingProperties props, ObjectMapper json, String api) {
        this.props = props;
        this.json = json;
        this.api = api;
        this.tokens = new GoogleAccessToken(json, props::serviceAccountJson, SCOPE, http);
    }

    @Override
    public PlaySubscription lookup(String purchaseToken) {
        JsonNode n = call("GET", api + props.playPackage() + "/purchases/subscriptionsv2/tokens/" + encode(purchaseToken), null);
        JsonNode item = n.path("lineItems").path(0);
        String expiry = item.path("expiryTime").asText("");
        return new PlaySubscription(
                n.path("subscriptionState").asText(""),
                item.path("productId").asText(""),
                expiry.isEmpty() ? null : Instant.parse(expiry),
                "ACKNOWLEDGEMENT_STATE_ACKNOWLEDGED".equals(n.path("acknowledgementState").asText()),
                n.path("latestOrderId").asText(""));
    }

    @Override
    public java.util.List<String> voidedOrderIds(Instant since) {
        JsonNode n = call("GET", api + props.playPackage() + "/purchases/voidedpurchases?type=1&startTime=" + since.toEpochMilli(), null);
        java.util.List<String> ids = new java.util.ArrayList<>();
        for (JsonNode v : n.path("voidedPurchases")) {
            String id = v.path("orderId").asText("");
            if (!id.isBlank()) {
                ids.add(id);
            }
        }
        return ids;
    }

    @Override
    public void acknowledge(String productId, String purchaseToken) {
        call("POST", api + props.playPackage() + "/purchases/subscriptions/" + encode(productId) + "/tokens/"
                + encode(purchaseToken) + ":acknowledge", "{}");
    }

    private JsonNode call(String method, String url, String body) {
        if (!props.configured()) {
            throw new BusinessException("A assinatura pela loja ainda não está configurada no servidor.");
        }
        try {
            HttpRequest.Builder req = HttpRequest.newBuilder(URI.create(url)).timeout(Duration.ofSeconds(15))
                    .header("Authorization", "Bearer " + accessToken())
                    .header("Content-Type", "application/json");
            HttpResponse<String> res = http.send(
                    req.method(method, body == null ? HttpRequest.BodyPublishers.noBody() : HttpRequest.BodyPublishers.ofString(body)).build(),
                    HttpResponse.BodyHandlers.ofString());
            int status = res.statusCode();
            if (status == 400 || status == 404 || status == 410) {
                throw new BusinessException("Compra não encontrada na Google Play. Tente restaurar a assinatura.");
            }
            if (status / 100 != 2) {
                throw new IllegalStateException("Google Play respondeu " + status + ": " + res.body());
            }
            return res.body().isBlank() ? json.createObjectNode() : json.readTree(res.body());
        } catch (IOException e) {
            throw new IllegalStateException("Falha ao falar com a Google Play", e);
        } catch (InterruptedException e) {
            Thread.currentThread().interrupt();
            throw new IllegalStateException("Consulta à Google Play interrompida", e);
        }
    }

    private String accessToken() throws IOException, InterruptedException {
        return tokens.get();
    }

    private static String encode(String v) {
        return URLEncoder.encode(v, StandardCharsets.UTF_8);
    }
}
