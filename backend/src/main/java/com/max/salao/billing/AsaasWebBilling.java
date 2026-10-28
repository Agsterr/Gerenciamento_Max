package com.max.salao.billing;

import java.io.IOException;
import java.math.BigDecimal;
import java.net.URI;
import java.net.http.HttpClient;
import java.net.http.HttpRequest;
import java.net.http.HttpResponse;
import java.time.Duration;
import java.util.LinkedHashMap;
import java.util.Map;

import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.databind.ObjectMapper;
import com.max.salao.salon.Salon;
import com.max.salao.shared.BusinessException;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.stereotype.Component;

/**
 * API v3 do Asaas por HTTP. A mensalidade é um link de pagamento recorrente mensal: a própria página do Asaas pede os
 * dados da pessoa e deixa escolher Pix, boleto ou cartão (cartão renova sozinho; Pix e boleto chegam por e-mail todo mês).
 */
@Component
class AsaasWebBilling implements WebBilling {

    private static final Logger log = LoggerFactory.getLogger(AsaasWebBilling.class);

    private final AsaasProperties props;
    private final ObjectMapper json;
    private final HttpClient http = HttpClient.newBuilder().connectTimeout(Duration.ofSeconds(5)).build();

    AsaasWebBilling(AsaasProperties props, ObjectMapper json) {
        this.props = props;
        this.json = json;
    }

    @Override
    public Link createLink(Salon salon) {
        Map<String, Object> body = new LinkedHashMap<>();
        body.put("name", "Salão Max - mensalidade (" + salon.getSlug() + ")");
        body.put("description", "Mensalidade do Salão Max para " + salon.getName());
        body.put("billingType", "UNDEFINED");
        body.put("chargeType", "RECURRENT");
        body.put("subscriptionCycle", "MONTHLY");
        body.put("value", BigDecimal.valueOf(props.priceCents(), 2));
        body.put("dueDateLimitDays", 5);
        body.put("notificationEnabled", true);
        body.put("callback", Map.of("successUrl", props.siteUrl() + "/painel/assinatura?assinatura=ok", "autoRedirect", true));
        JsonNode res = call("POST", "/paymentLinks", body);
        String id = res.path("id").asText("");
        String url = res.path("url").asText("");
        if (id.isBlank() || url.isBlank()) {
            log.warn("Asaas não devolveu o link de pagamento: {}", res);
            throw new BusinessException("Não foi possível abrir o pagamento agora. Tente de novo em instantes.");
        }
        return new Link(id, url);
    }

    @Override
    public java.util.Optional<Link> findLink(String linkId) {
        try {
            JsonNode res = call("GET", "/paymentLinks/" + linkId, null);
            String url = res.path("url").asText("");
            boolean usable = !url.isBlank() && !res.path("deleted").asBoolean(false) && res.path("active").asBoolean(true);
            return usable ? java.util.Optional.of(new Link(linkId, url)) : java.util.Optional.empty();
        } catch (BusinessException e) {
            return java.util.Optional.empty();
        }
    }

    @Override
    public void cancelSubscription(String subscriptionId) {
        call("DELETE", "/subscriptions/" + subscriptionId, null);
    }

    private JsonNode call(String method, String path, Object body) {
        if (!props.configured()) {
            throw new BusinessException("O pagamento pelo site ainda não está configurado.");
        }
        try {
            HttpRequest.Builder req = HttpRequest.newBuilder(URI.create(props.baseUrl() + path)).timeout(Duration.ofSeconds(20))
                    .header("access_token", props.apiKey())
                    .header("User-Agent", "SalaoMax")
                    .header("Content-Type", "application/json");
            HttpRequest.BodyPublisher publisher = body == null ? HttpRequest.BodyPublishers.noBody()
                    : HttpRequest.BodyPublishers.ofString(json.writeValueAsString(body));
            HttpResponse<String> res = http.send(req.method(method, publisher).build(), HttpResponse.BodyHandlers.ofString());
            if (res.statusCode() == 404 && "DELETE".equals(method)) {
                return json.createObjectNode(); // assinatura já não existe: o objetivo (cancelada) está cumprido
            }
            if (res.statusCode() / 100 != 2) {
                log.warn("Asaas respondeu {} em {} {}: {}", res.statusCode(), method, path, res.body());
                throw new BusinessException("Não foi possível falar com o serviço de pagamento agora. Tente de novo em instantes.");
            }
            return res.body().isBlank() ? json.createObjectNode() : json.readTree(res.body());
        } catch (IOException e) {
            throw new IllegalStateException("Falha ao falar com o Asaas", e);
        } catch (InterruptedException e) {
            Thread.currentThread().interrupt();
            throw new IllegalStateException("Consulta ao Asaas interrompida", e);
        }
    }
}
