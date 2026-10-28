package com.max.salao.billing;

import java.io.IOException;
import java.net.URI;
import java.net.URLEncoder;
import java.net.http.HttpClient;
import java.net.http.HttpRequest;
import java.net.http.HttpResponse;
import java.nio.charset.StandardCharsets;
import java.time.Duration;
import java.util.Base64;
import java.util.LinkedHashMap;
import java.util.Map;
import java.util.stream.Collectors;

import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.databind.ObjectMapper;
import com.max.salao.salon.Salon;
import com.max.salao.shared.BusinessException;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.stereotype.Component;

/** API do Stripe por HTTP (sem SDK): Checkout Session de assinatura e portal do cliente. */
@Component
class StripeWebBilling implements WebBilling {

    private static final Logger log = LoggerFactory.getLogger(StripeWebBilling.class);
    private static final String DEFAULT_API = "https://api.stripe.com/v1";

    private final StripeProperties props;
    private final ObjectMapper json;
    private final String api;
    private final HttpClient http = HttpClient.newBuilder().connectTimeout(Duration.ofSeconds(5)).build();

    @org.springframework.beans.factory.annotation.Autowired
    StripeWebBilling(StripeProperties props, ObjectMapper json) {
        this(props, json, DEFAULT_API);
    }

    /** Endereço da API configurável só para os testes (servidor falso). */
    StripeWebBilling(StripeProperties props, ObjectMapper json, String api) {
        this.props = props;
        this.json = json;
        this.api = api;
    }

    @Override
    public String checkoutUrl(Salon salon, String ownerEmail) {
        Map<String, String> form = new LinkedHashMap<>();
        form.put("mode", "subscription");
        form.put("line_items[0][price]", props.priceId());
        form.put("line_items[0][quantity]", "1");
        form.put("client_reference_id", String.valueOf(salon.getId()));
        form.put("metadata[salon_id]", String.valueOf(salon.getId()));
        form.put("subscription_data[metadata][salon_id]", String.valueOf(salon.getId()));
        form.put("locale", "pt-BR");
        if (salon.getStripeCustomerId() != null) {
            form.put("customer", salon.getStripeCustomerId());
        } else if (ownerEmail != null && !ownerEmail.isBlank()) {
            form.put("customer_email", ownerEmail);
        }
        form.put("success_url", props.siteUrl() + "/painel/assinatura?assinatura=ok");
        form.put("cancel_url", props.siteUrl() + "/painel/assinatura?assinatura=cancelada");
        return post("/checkout/sessions", form).path("url").asText();
    }

    @Override
    public String portalUrl(String customerId) {
        return post("/billing_portal/sessions", Map.of("customer", customerId,
                "return_url", props.siteUrl() + "/painel/assinatura")).path("url").asText();
    }

    private JsonNode post(String path, Map<String, String> form) {
        if (!props.configured()) {
            throw new BusinessException("O pagamento pelo site ainda não está configurado.");
        }
        String body = form.entrySet().stream()
                .map(e -> URLEncoder.encode(e.getKey(), StandardCharsets.UTF_8) + "=" + URLEncoder.encode(e.getValue(), StandardCharsets.UTF_8))
                .collect(Collectors.joining("&"));
        try {
            HttpRequest req = HttpRequest.newBuilder(URI.create(api + path)).timeout(Duration.ofSeconds(20))
                    .header("Authorization", "Basic " + Base64.getEncoder()
                            .encodeToString((props.secretKey() + ":").getBytes(StandardCharsets.UTF_8)))
                    .header("Content-Type", "application/x-www-form-urlencoded")
                    .POST(HttpRequest.BodyPublishers.ofString(body)).build();
            HttpResponse<String> res = http.send(req, HttpResponse.BodyHandlers.ofString());
            if (res.statusCode() / 100 != 2) {
                log.warn("Stripe respondeu {} em {}: {}", res.statusCode(), path, res.body());
                throw new BusinessException("Não foi possível abrir o pagamento agora. Tente de novo em instantes.");
            }
            return json.readTree(res.body());
        } catch (IOException e) {
            throw new IllegalStateException("Falha ao falar com o Stripe", e);
        } catch (InterruptedException e) {
            Thread.currentThread().interrupt();
            throw new IllegalStateException("Consulta ao Stripe interrompida", e);
        }
    }
}
