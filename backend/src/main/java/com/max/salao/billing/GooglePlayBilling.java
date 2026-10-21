package com.max.salao.billing;

import java.io.IOException;
import java.net.URI;
import java.net.URLEncoder;
import java.net.http.HttpClient;
import java.net.http.HttpRequest;
import java.net.http.HttpResponse;
import java.nio.charset.StandardCharsets;
import java.security.KeyFactory;
import java.security.interfaces.RSAPrivateKey;
import java.security.spec.PKCS8EncodedKeySpec;
import java.time.Duration;
import java.time.Instant;
import java.util.Base64;
import java.util.Date;

import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.databind.ObjectMapper;
import com.max.salao.shared.BusinessException;
import com.nimbusds.jose.JWSAlgorithm;
import com.nimbusds.jose.JWSHeader;
import com.nimbusds.jose.crypto.RSASSASigner;
import com.nimbusds.jwt.JWTClaimsSet;
import com.nimbusds.jwt.SignedJWT;
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

    private volatile String accessToken;
    private volatile Instant accessExpiry = Instant.EPOCH;

    @org.springframework.beans.factory.annotation.Autowired
    GooglePlayBilling(BillingProperties props, ObjectMapper json) {
        this(props, json, DEFAULT_API);
    }

    /** Endereço da API configurável só para os testes (servidor falso). */
    GooglePlayBilling(BillingProperties props, ObjectMapper json, String api) {
        this.props = props;
        this.json = json;
        this.api = api;
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

    private synchronized String accessToken() throws IOException, InterruptedException {
        if (accessToken != null && Instant.now().isBefore(accessExpiry.minusSeconds(60))) {
            return accessToken;
        }
        JsonNode account = json.readTree(props.serviceAccountJson());
        String tokenUri = account.path("token_uri").asText("https://oauth2.googleapis.com/token");
        try {
            Instant now = Instant.now();
            JWTClaimsSet claims = new JWTClaimsSet.Builder()
                    .issuer(account.path("client_email").asText())
                    .claim("scope", SCOPE)
                    .audience(tokenUri)
                    .issueTime(Date.from(now))
                    .expirationTime(Date.from(now.plusSeconds(3600)))
                    .build();
            SignedJWT jwt = new SignedJWT(new JWSHeader(JWSAlgorithm.RS256), claims);
            jwt.sign(new RSASSASigner(privateKey(account.path("private_key").asText())));
            String form = "grant_type=" + encode("urn:ietf:params:oauth:grant-type:jwt-bearer") + "&assertion=" + encode(jwt.serialize());
            HttpResponse<String> res = http.send(HttpRequest.newBuilder(URI.create(tokenUri)).timeout(Duration.ofSeconds(15))
                    .header("Content-Type", "application/x-www-form-urlencoded")
                    .POST(HttpRequest.BodyPublishers.ofString(form)).build(), HttpResponse.BodyHandlers.ofString());
            if (res.statusCode() / 100 != 2) {
                throw new IllegalStateException("Google recusou a conta de serviço (" + res.statusCode() + "): " + res.body());
            }
            JsonNode token = json.readTree(res.body());
            accessToken = token.path("access_token").asText();
            accessExpiry = now.plusSeconds(token.path("expires_in").asLong(3600));
            return accessToken;
        } catch (java.security.GeneralSecurityException | com.nimbusds.jose.JOSEException e) {
            throw new IllegalStateException("Chave da conta de serviço inválida", e);
        }
    }

    private static RSAPrivateKey privateKey(String pem) throws java.security.GeneralSecurityException {
        String body = pem.replace("-----BEGIN PRIVATE KEY-----", "").replace("-----END PRIVATE KEY-----", "").replaceAll("\\s", "");
        return (RSAPrivateKey) KeyFactory.getInstance("RSA")
                .generatePrivate(new PKCS8EncodedKeySpec(Base64.getDecoder().decode(body)));
    }

    private static String encode(String v) {
        return URLEncoder.encode(v, StandardCharsets.UTF_8);
    }
}
