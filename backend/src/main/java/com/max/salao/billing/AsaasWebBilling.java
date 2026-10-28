package com.max.salao.billing;

import java.io.IOException;
import java.math.BigDecimal;
import java.net.URI;
import java.net.http.HttpClient;
import java.net.http.HttpRequest;
import java.net.http.HttpResponse;
import java.time.Clock;
import java.time.Duration;
import java.time.LocalDate;
import java.util.LinkedHashMap;
import java.util.Map;
import java.util.Optional;

import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.databind.ObjectMapper;
import com.max.salao.salon.Salon;
import com.max.salao.shared.BusinessException;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.stereotype.Component;

/**
 * API v3 do Asaas por HTTP, no mesmo desenho do sistema de estoque (já em uso): cliente (com CPF/CNPJ), assinatura mensal
 * com {@code billingType UNDEFINED} (a pessoa escolhe Pix, boleto ou cartão na página da cobrança) e a {@code invoiceUrl}
 * da primeira cobrança. Cartão renova sozinho; Pix e boleto chegam por e-mail todo mês.
 */
@Component
class AsaasWebBilling implements WebBilling {

    private static final Logger log = LoggerFactory.getLogger(AsaasWebBilling.class);
    /** CPF de teste do sandbox quando ninguém informou documento (só vale se a URL for do sandbox). */
    private static final String SANDBOX_CPF = "24971563792";

    private final AsaasProperties props;
    private final ObjectMapper json;
    private final Clock clock;
    private final HttpClient http = HttpClient.newBuilder().connectTimeout(Duration.ofSeconds(5)).build();

    AsaasWebBilling(AsaasProperties props, ObjectMapper json, Clock clock) {
        this.props = props;
        this.json = json;
        this.clock = clock;
    }

    @Override
    public Subscribed subscribe(Salon salon, String ownerName, String ownerEmail, String cpfCnpj) {
        String customerId = salon.getAsaasCustomerId() != null ? salon.getAsaasCustomerId()
                : createCustomer(salon, ownerName, ownerEmail, cpfCnpj);

        Map<String, Object> body = new LinkedHashMap<>();
        body.put("customer", customerId);
        body.put("billingType", "UNDEFINED");
        body.put("value", BigDecimal.valueOf(props.priceCents(), 2));
        body.put("nextDueDate", LocalDate.now(clock).plusDays(1).toString());
        body.put("cycle", "MONTHLY");
        body.put("description", "Mensalidade Salão Max - " + salon.getName());
        body.put("externalReference", "salon:" + salon.getId());
        JsonNode subscription = call("POST", "/subscriptions", body);
        String subscriptionId = subscription.path("id").asText("");
        if (subscriptionId.isBlank()) {
            log.warn("Asaas não devolveu o id da assinatura: {}", subscription);
            throw new BusinessException("Não foi possível abrir o pagamento agora. Tente de novo em instantes.");
        }
        // a primeira cobrança é gerada logo depois de criar a assinatura
        for (int attempt = 0; attempt < 6; attempt++) {
            Optional<String> url = firstPaymentUrl(subscriptionId, false);
            if (url.isPresent()) {
                return new Subscribed(customerId, subscriptionId, url.get());
            }
            sleep(400);
        }
        throw new BusinessException("O pagamento ainda está sendo preparado. Tente de novo em instantes.");
    }

    @Override
    public Optional<String> openPaymentUrl(String subscriptionId) {
        try {
            return firstPaymentUrl(subscriptionId, true);
        } catch (BusinessException e) {
            return Optional.empty(); // assinatura apagada ou fora do ar: cria uma nova
        }
    }

    @Override
    public void cancelSubscription(String subscriptionId) {
        call("DELETE", "/subscriptions/" + subscriptionId, null);
    }

    private String createCustomer(Salon salon, String ownerName, String ownerEmail, String cpfCnpj) {
        String document = cpfCnpj == null ? "" : cpfCnpj.replaceAll("\\D", "");
        if (document.isEmpty() && props.baseUrl().contains("sandbox")) {
            document = SANDBOX_CPF;
        }
        if (document.length() != 11 && document.length() != 14) {
            throw new BusinessException("Informe o CPF ou CNPJ do titular da assinatura.");
        }
        Map<String, Object> body = new LinkedHashMap<>();
        body.put("name", ownerName == null || ownerName.isBlank() ? salon.getName() : ownerName);
        body.put("email", ownerEmail);
        body.put("cpfCnpj", document);
        body.put("externalReference", "salon:" + salon.getId());
        JsonNode customer = call("POST", "/customers", body);
        String id = customer.path("id").asText("");
        if (id.isBlank()) {
            log.warn("Asaas não devolveu o id do cliente: {}", customer);
            throw new BusinessException("Não foi possível abrir o pagamento agora. Tente de novo em instantes.");
        }
        return id;
    }

    /** Primeira cobrança da assinatura (ou, com {@code onlyOpen}, só se estiver pendente/vencida). */
    private Optional<String> firstPaymentUrl(String subscriptionId, boolean onlyOpen) {
        JsonNode list = call("GET", "/subscriptions/" + subscriptionId + "/payments", null);
        for (JsonNode payment : list.path("data")) {
            String status = payment.path("status").asText("");
            if (onlyOpen && !status.equals("PENDING") && !status.equals("OVERDUE")) {
                continue;
            }
            String url = payment.path("invoiceUrl").asText("");
            if (url.isBlank()) {
                url = payment.path("bankSlipUrl").asText("");
            }
            if (!url.isBlank()) {
                return Optional.of(url);
            }
        }
        return Optional.empty();
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
                throw new BusinessException(describe(res.body()));
            }
            return res.body().isBlank() ? json.createObjectNode() : json.readTree(res.body());
        } catch (IOException e) {
            throw new IllegalStateException("Falha ao falar com o Asaas", e);
        } catch (InterruptedException e) {
            Thread.currentThread().interrupt();
            throw new IllegalStateException("Consulta ao Asaas interrompida", e);
        }
    }

    /** Mensagem do próprio Asaas (ex.: "CPF/CNPJ inválido") quando houver; senão uma genérica. */
    private String describe(String responseBody) {
        try {
            String description = json.readTree(responseBody).path("errors").path(0).path("description").asText("");
            if (!description.isBlank()) {
                return description;
            }
        } catch (IOException ignored) {
            // corpo que não é JSON: usa a mensagem genérica
        }
        return "Não foi possível falar com o serviço de pagamento agora. Tente de novo em instantes.";
    }

    private static void sleep(long millis) {
        try {
            Thread.sleep(millis);
        } catch (InterruptedException e) {
            Thread.currentThread().interrupt();
        }
    }
}
