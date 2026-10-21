package com.max.salao.billing;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;

import java.net.InetSocketAddress;
import java.nio.charset.StandardCharsets;
import java.security.KeyPair;
import java.security.KeyPairGenerator;
import java.time.Instant;
import java.util.Base64;
import java.util.List;
import java.util.concurrent.CopyOnWriteArrayList;

import com.fasterxml.jackson.databind.ObjectMapper;
import com.max.salao.shared.BusinessException;
import com.nimbusds.jwt.SignedJWT;
import com.sun.net.httpserver.HttpServer;
import org.junit.jupiter.api.AfterEach;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;

/** Conversa com um servidor falso que imita o OAuth e a Android Publisher API da Google. */
class GooglePlayBillingTest {

    private final ObjectMapper json = new ObjectMapper();
    private final List<String> requests = new CopyOnWriteArrayList<>();
    private HttpServer server;
    private String base;
    private volatile int purchaseStatus = 200;

    @BeforeEach
    void start() throws Exception {
        server = HttpServer.create(new InetSocketAddress("127.0.0.1", 0), 0);
        server.createContext("/token", ex -> {
            requests.add("token " + new String(ex.getRequestBody().readAllBytes(), StandardCharsets.UTF_8));
            reply(ex, 200, "{\"access_token\":\"acesso-123\",\"expires_in\":3600}");
        });
        server.createContext("/v3/applications/", ex -> {
            requests.add(ex.getRequestMethod() + " " + ex.getRequestURI().getRawPath() + " auth=" + ex.getRequestHeaders().getFirst("Authorization"));
            if (ex.getRequestURI().getPath().endsWith(":acknowledge")) {
                reply(ex, 200, "");
            } else {
                reply(ex, purchaseStatus, """
                        {"subscriptionState":"SUBSCRIPTION_STATE_ACTIVE","acknowledgementState":"ACKNOWLEDGEMENT_STATE_PENDING",
                         "latestOrderId":"GPA.1234","lineItems":[{"productId":"salao_max_mensal","expiryTime":"2030-01-15T12:00:00.123Z"}]}""");
            }
        });
        server.start();
        base = "http://127.0.0.1:" + server.getAddress().getPort();
    }

    @AfterEach
    void stop() {
        server.stop(0);
    }

    private GooglePlayBilling client() throws Exception {
        KeyPairGenerator gen = KeyPairGenerator.getInstance("RSA");
        gen.initialize(2048);
        KeyPair pair = gen.generateKeyPair();
        String pem = "-----BEGIN PRIVATE KEY-----\n"
                + Base64.getMimeEncoder(64, "\n".getBytes()).encodeToString(pair.getPrivate().getEncoded())
                + "\n-----END PRIVATE KEY-----\n";
        String account = json.writeValueAsString(java.util.Map.of("client_email", "robo@projeto.iam.gserviceaccount.com",
                "private_key", pem, "token_uri", base + "/token"));
        String b64 = Base64.getEncoder().encodeToString(account.getBytes(StandardCharsets.UTF_8));
        return new GooglePlayBilling(new BillingProperties("io.github.agsterr.salaomax.gestao", b64), json, base + "/v3/applications/");
    }

    @Test
    void readsTheSubscriptionAndAcknowledgesItWithASignedToken() throws Exception {
        GooglePlayBilling play = client();

        PlaySubscription sub = play.lookup("meu+token/1");
        assertThat(sub.state()).isEqualTo("SUBSCRIPTION_STATE_ACTIVE");
        assertThat(sub.productId()).isEqualTo("salao_max_mensal");
        assertThat(sub.expiry()).isEqualTo(Instant.parse("2030-01-15T12:00:00.123Z"));
        assertThat(sub.acknowledged()).isFalse();
        assertThat(sub.entitled(Instant.now())).isTrue();

        play.acknowledge("salao_max_mensal", "meu+token/1");

        // o JWT enviado à Google foi assinado e tem quem, o quê e para quem
        String tokenCall = requests.stream().filter(r -> r.startsWith("token ")).findFirst().orElseThrow();
        String assertion = java.net.URLDecoder.decode(tokenCall.replaceAll(".*assertion=", ""), StandardCharsets.UTF_8);
        SignedJWT jwt = SignedJWT.parse(assertion);
        assertThat(jwt.getJWTClaimsSet().getIssuer()).isEqualTo("robo@projeto.iam.gserviceaccount.com");
        assertThat(jwt.getJWTClaimsSet().getStringClaim("scope")).isEqualTo("https://www.googleapis.com/auth/androidpublisher");
        assertThat(jwt.getJWTClaimsSet().getAudience()).containsExactly(base + "/token");
        assertThat(tokenCall).contains("grant_type=urn%3Aietf%3Aparams%3Aoauth%3Agrant-type%3Ajwt-bearer");

        // as chamadas usam o token de acesso; o token da compra vai codificado no caminho
        assertThat(requests).anyMatch(r -> r.startsWith("GET /v3/applications/io.github.agsterr.salaomax.gestao/purchases/subscriptionsv2/tokens/meu%2Btoken%2F1 auth=Bearer acesso-123"));
        assertThat(requests).anyMatch(r -> r.startsWith("POST /v3/applications/io.github.agsterr.salaomax.gestao/purchases/subscriptions/salao_max_mensal/tokens/meu%2Btoken%2F1:acknowledge auth=Bearer acesso-123"));
        // o token de acesso é reaproveitado (uma só ida ao OAuth)
        assertThat(requests.stream().filter(r -> r.startsWith("token ")).count()).isEqualTo(1);
    }

    @Test
    void unknownPurchaseBecomesAFriendlyError() throws Exception {
        purchaseStatus = 410;
        assertThatThrownBy(() -> client().lookup("velho")).isInstanceOf(BusinessException.class)
                .hasMessageContaining("Compra não encontrada");
    }

    @Test
    void withoutCredentialsTheBillingIsOff() {
        GooglePlayBilling off = new GooglePlayBilling(new BillingProperties("pkg", ""), json, base + "/v3/applications/");
        assertThatThrownBy(() -> off.lookup("x")).isInstanceOf(BusinessException.class).hasMessageContaining("não está configurada");
    }

    @Test
    void entitlementRules() {
        Instant now = Instant.now();
        Instant future = now.plusSeconds(3600);
        Instant past = now.minusSeconds(3600);
        assertThat(new PlaySubscription("SUBSCRIPTION_STATE_IN_GRACE_PERIOD", "p", past, true, "o").entitled(now)).isTrue();
        assertThat(new PlaySubscription("SUBSCRIPTION_STATE_CANCELED", "p", future, true, "o").entitled(now)).isTrue();
        assertThat(new PlaySubscription("SUBSCRIPTION_STATE_CANCELED", "p", past, true, "o").entitled(now)).isFalse();
        assertThat(new PlaySubscription("SUBSCRIPTION_STATE_ON_HOLD", "p", future, true, "o").entitled(now)).isFalse();
        assertThat(new PlaySubscription("SUBSCRIPTION_STATE_PENDING", "p", null, false, "o").entitled(now)).isFalse();
    }

    private static void reply(com.sun.net.httpserver.HttpExchange ex, int status, String body) throws java.io.IOException {
        byte[] bytes = body.getBytes(StandardCharsets.UTF_8);
        ex.getResponseHeaders().add("Content-Type", "application/json");
        ex.sendResponseHeaders(status, bytes.length == 0 ? -1 : bytes.length);
        if (bytes.length > 0) {
            ex.getResponseBody().write(bytes);
        }
        ex.close();
    }
}
