package com.max.salao;

import static org.assertj.core.api.Assertions.assertThat;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

import java.time.Instant;
import java.util.Map;
import java.util.UUID;

import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.databind.ObjectMapper;
import com.fasterxml.jackson.databind.node.ObjectNode;
import com.max.salao.billing.BillingService;
import com.max.salao.billing.PlayBilling;
import com.max.salao.billing.PlaySubscription;
import com.max.salao.billing.WebBilling;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.autoconfigure.web.servlet.AutoConfigureMockMvc;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.http.MediaType;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.test.context.bean.override.mockito.MockitoBean;
import org.springframework.test.web.servlet.MockMvc;
import org.springframework.test.web.servlet.ResultMatcher;
import org.springframework.test.web.servlet.request.MockHttpServletRequestBuilder;

/** Pagamento pelo site (Asaas), Play e comissões dos representantes (PostgreSQL real, Asaas e Play falsos). */
@SpringBootTest(properties = {
        "spring.datasource.url=${TEST_DB_URL:jdbc:postgresql://localhost:5432/salao_test}",
        "app.platform-admin.email=" + ReferralBillingIntegrationTest.ADMIN_EMAIL,
        "app.platform-admin.password=senha-da-plataforma",
        "app.asaas.api-key=chave-de-teste",
        "app.asaas.webhook-token=token-do-webhook-de-teste-123456789",
        "app.referral.hold-days=7"})
@AutoConfigureMockMvc
class ReferralBillingIntegrationTest {

    static final String ADMIN_EMAIL = "plataforma-ref@salaomax.test";

    @Autowired
    MockMvc mvc;
    @Autowired
    ObjectMapper json;
    @Autowired
    JdbcTemplate jdbc;
    @Autowired
    BillingService billing;

    @MockitoBean
    PlayBilling play;
    @MockitoBean
    WebBilling web;

    private record Salon(long id, String slug, String token) {
    }

    @Test
    void referredSalonPaymentsGenerateCommissionsAndRefundsTakeThemBack() throws Exception {
        String admin = login(ADMIN_EMAIL, "senha-da-plataforma");
        JsonNode rep = call(null, post("/api/auth/register-representative"), Map.of("name", "Márcia Souza",
                "email", "marcia-" + UUID.randomUUID() + "@teste.com", "password", "123456", "pixKey", "marcia@pix.com"),
                status().isCreated());
        String repToken = rep.get("token").asText();
        assertThat(rep.at("/user/role").asText()).isEqualTo("REPRESENTATIVE");
        JsonNode dash = call(repToken, get("/api/representative/me"), null, status().isOk());
        String code = dash.get("code").asText();
        assertThat(code).startsWith("MARC").hasSize(8);
        assertThat(dash.get("link").asText()).endsWith("/r/" + code);
        assertThat(dash.get("commissionCents").asInt()).isEqualTo(1500);

        // o link mostra quem indicou (com qualquer caixa); código desconhecido não vale
        JsonNode info = call(null, get("/api/public/referral/" + code.toLowerCase()), null, status().isOk());
        assertThat(info.get("valid").asBoolean()).isTrue();
        assertThat(info.get("name").asText()).isEqualTo("Márcia");
        assertThat(call(null, get("/api/public/referral/NAOEXISTE"), null, status().isOk()).get("valid").asBoolean()).isFalse();

        // representante não acessa as rotas do salão nem da plataforma; salão não acessa as do representante
        call(repToken, get("/api/appointments"), null, status().isForbidden());
        call(repToken, get("/api/platform/representatives"), null, status().isForbidden());

        Salon referred = register(code);
        Salon organic = register("CODIGOFALSO");
        call(referred.token, get("/api/representative/me"), null, status().isForbidden());
        dash = call(repToken, get("/api/representative/me"), null, status().isOk());
        assertThat(dash.get("salons")).hasSize(1);
        assertThat(dash.at("/salons/0/status").asText()).isEqualTo("TESTE");

        // pagamento pelo site: o dono pede a página de pagamento (a mesma se clicar de novo); a equipe não
        String run = UUID.randomUUID().toString().substring(0, 8);
        String link1 = "link_" + run;
        String linkOrg = "linkorg_" + run;
        String payOrg = "payorg_" + run;
        String subOrg = "suborg_" + run;
        String cusOrg = "cusorg_" + run;
        String pay3 = "pay3_" + run;
        org.mockito.Mockito.when(web.createLink(org.mockito.ArgumentMatchers.any()))
                .thenReturn(new WebBilling.Link(link1, "https://www.asaas.com/c/abc"));
        org.mockito.Mockito.when(web.findLink(link1))
                .thenReturn(java.util.Optional.of(new WebBilling.Link(link1, "https://www.asaas.com/c/abc")));
        assertThat(call(referred.token, get("/api/salon/plan"), null, status().isOk()).get("webBillingAvailable").asBoolean()).isTrue();
        assertThat(call(referred.token, post("/api/billing/web/checkout"), null, status().isOk()).get("url").asText())
                .isEqualTo("https://www.asaas.com/c/abc");
        assertThat(call(referred.token, post("/api/billing/web/checkout"), null, status().isOk()).get("url").asText())
                .isEqualTo("https://www.asaas.com/c/abc");
        org.mockito.Mockito.verify(web, org.mockito.Mockito.times(1)).createLink(org.mockito.ArgumentMatchers.any());
        call(referred.token, post("/api/billing/web/cancel"), null, status().isUnprocessableEntity()); // ainda sem assinatura

        // webhook: sem token ou com token errado é recusado
        call(null, post("/api/asaas/webhook"), "{}", status().isUnauthorized());
        call(null, post("/api/asaas/webhook").header("asaas-access-token", "errado"), "{}", status().isUnauthorized());

        // 1ª mensalidade (pelo link): plano ativo e comissão de R$ 15 em espera (prazo de estorno)
        String sub = "sub_" + UUID.randomUUID().toString().substring(0, 8);
        String cus = "cus_" + UUID.randomUUID().toString().substring(0, 8);
        String pay1 = "pay_" + UUID.randomUUID().toString().substring(0, 8);
        send("PAYMENT_CONFIRMED", payment(pay1, sub, cus, link1, 49.90, java.time.LocalDate.now()));
        assertThat(jdbc.queryForObject("select asaas_subscription_id from salon where id = ?", String.class, referred.id)).isEqualTo(sub);
        assertThat(call(referred.token, get("/api/salon/plan"), null, status().isOk()).get("status").asText()).isEqualTo("ACTIVE");
        dash = call(repToken, get("/api/representative/me"), null, status().isOk());
        assertThat(dash.at("/totals/releasingCents").asInt()).isEqualTo(1500);
        assertThat(dash.at("/salons/0/status").asText()).isEqualTo("PAGANDO");
        assertThat(dash.at("/salons/0/paidMonths").asInt()).isEqualTo(1);

        // o Asaas manda CONFIRMED e depois RECEIVED (e reenvia): conta uma vez só
        send("PAYMENT_RECEIVED", payment(pay1, sub, cus, link1, 49.90, java.time.LocalDate.now()));
        send("PAYMENT_RECEIVED", payment(pay1, sub, cus, link1, 49.90, java.time.LocalDate.now()));
        assertThat(call(repToken, get("/api/representative/me"), null, status().isOk()).at("/totals/releasingCents").asInt()).isEqualTo(1500);

        // 2ª mensalidade (Pix do mês seguinte, achada pela assinatura)
        String pay2 = "pay_" + UUID.randomUUID().toString().substring(0, 8);
        send("PAYMENT_RECEIVED", payment(pay2, sub, cus, null, 49.90, java.time.LocalDate.now().plusMonths(1)));
        assertThat(call(repToken, get("/api/representative/me"), null, status().isOk()).at("/totals/releasingCents").asInt()).isEqualTo(3000);

        // estorno da 1ª: perde só a comissão dela e o plano segue (a 2ª vale)
        send("PAYMENT_REFUNDED", payment(pay1, sub, cus, link1, 49.90, java.time.LocalDate.now()));
        dash = call(repToken, get("/api/representative/me"), null, status().isOk());
        assertThat(dash.at("/totals/reversedCents").asInt()).isEqualTo(1500);
        assertThat(dash.at("/totals/releasingCents").asInt()).isEqualTo(1500);
        assertThat(call(referred.token, get("/api/salon/plan"), null, status().isOk()).get("status").asText()).isEqualTo("ACTIVE");

        // contestação (chargeback) da 2ª: perde a comissão e o acesso daquele período
        send("PAYMENT_CHARGEBACK_REQUESTED", payment(pay2, sub, cus, null, 49.90, java.time.LocalDate.now().plusMonths(1)));
        dash = call(repToken, get("/api/representative/me"), null, status().isOk());
        assertThat(dash.at("/totals/reversedCents").asInt()).isEqualTo(3000);
        assertThat(dash.at("/totals/releasingCents").asInt()).isZero();
        assertThat(call(referred.token, get("/api/salon/plan"), null, status().isOk()).get("status").asText()).isEqualTo("EXPIRED");

        // aviso que não dá para ligar a nenhum salão não derruba o webhook (falhas seguidas pausariam a fila do Asaas)
        send("PAYMENT_RECEIVED", payment("pay_orfao", "sub_orfa", "cus_orfao", "link_orfao", 49.90, java.time.LocalDate.now()));

        // salão sem indicação paga e ninguém ganha comissão
        org.mockito.Mockito.when(web.createLink(org.mockito.ArgumentMatchers.any()))
                .thenReturn(new WebBilling.Link(linkOrg, "https://www.asaas.com/c/org"));
        call(organic.token, post("/api/billing/web/checkout"), null, status().isOk());
        send("PAYMENT_CONFIRMED", payment(payOrg, subOrg, cusOrg, linkOrg, 49.90, java.time.LocalDate.now()));
        assertThat(jdbc.queryForObject("select count(*) from commission where salon_id = ?", Integer.class, organic.id)).isZero();
        assertThat(call(organic.token, get("/api/salon/plan"), null, status().isOk()).get("status").asText()).isEqualTo("ACTIVE");

        // cancelar: pede ao Asaas, desliga a assinatura e o plano segue até o fim do período pago
        call(organic.token, post("/api/billing/web/cancel"), null, status().isOk());
        org.mockito.Mockito.verify(web).cancelSubscription(subOrg);
        assertThat(jdbc.queryForObject("select asaas_subscription_id from salon where id = ?", String.class, organic.id)).isNull();
        assertThat(call(organic.token, get("/api/salon/plan"), null, status().isOk()).get("status").asText()).isEqualTo("ACTIVE");

        // repasse: só o que passou do prazo de estorno; o admin vê e paga
        send("PAYMENT_RECEIVED", payment(pay3, sub, cus, null, 49.90, java.time.LocalDate.now().plusMonths(2)));
        JsonNode list = call(admin, get("/api/platform/representatives"), null, status().isOk());
        long repId = list.findValuesAsText("code").indexOf(code) >= 0 ? repIdOf(list, code) : -1;
        assertThat(repId).isPositive();
        assertThat(call(admin, post("/api/platform/representatives/" + repId + "/pay-out"), null, status().isOk()).get("paidCents").asLong()).isZero();
        jdbc.update("update commission set created_at = created_at - interval '8 days' where representative_id = ?", repId);
        assertThat(call(admin, post("/api/platform/representatives/" + repId + "/pay-out"), null, status().isOk()).get("paidCents").asLong()).isEqualTo(1500);
        dash = call(repToken, get("/api/representative/me"), null, status().isOk());
        assertThat(dash.at("/totals/paidCents").asInt()).isEqualTo(1500);
        assertThat(dash.at("/totals/availableCents").asInt()).isZero();
        assertThat(call(admin, post("/api/platform/representatives/" + repId + "/pay-out"), null, status().isOk()).get("paidCents").asLong()).isZero();

        // o representante troca a chave Pix
        call(repToken, org.springframework.test.web.servlet.request.MockMvcRequestBuilders.put("/api/representative/pix"),
                Map.of("pixKey", "11999998888"), status().isNoContent());
        assertThat(call(repToken, get("/api/representative/me"), null, status().isOk()).get("pixKey").asText()).isEqualTo("11999998888");
    }

    @Test
    void playRenewalsGenerateCommissionAndVoidedOrdersTakeItBack() throws Exception {
        String admin = login(ADMIN_EMAIL, "senha-da-plataforma");
        JsonNode rep = call(null, post("/api/auth/register-representative"), Map.of("name", "Paulo Lima",
                "email", "paulo-" + UUID.randomUUID() + "@teste.com", "password", "123456"), status().isCreated());
        String repToken = rep.get("token").asText();
        String code = call(repToken, get("/api/representative/me"), null, status().isOk()).get("code").asText();
        Salon salon = register(code);
        call(admin, post("/api/platform/salons/" + salon.id + "/plan"), Map.of("plan", "TRIAL",
                "trialEndsAt", java.time.LocalDate.now().plusDays(5) + "T23:59:00", "billingPreview", true), status().isOk());

        String token = "tok-" + salon.slug;
        String order = "GPA." + UUID.randomUUID();
        org.mockito.Mockito.when(play.lookup(token)).thenReturn(new PlaySubscription("SUBSCRIPTION_STATE_ACTIVE",
                "salao_max_mensal", Instant.now().plusSeconds(30L * 86400), true, order));
        call(salon.token, post("/api/billing/play/verify"), Map.of("productId", "salao_max_mensal", "purchaseToken", token),
                status().isOk());
        // reconferir sem renovação não duplica
        call(salon.token, post("/api/billing/play/sync"), null, status().isOk());
        JsonNode dash = call(repToken, get("/api/representative/me"), null, status().isOk());
        assertThat(dash.at("/totals/releasingCents").asInt()).isEqualTo(1500);
        assertThat(dash.at("/commissions")).hasSize(1);

        // a Google estorna o pedido: comissão perdida e acesso encerrado
        org.mockito.Mockito.when(play.voidedOrderIds(org.mockito.ArgumentMatchers.any())).thenReturn(java.util.List.of(order));
        assertThat(billing.reverseVoidedPlayOrders()).isEqualTo(1);
        assertThat(billing.reverseVoidedPlayOrders()).isZero();
        dash = call(repToken, get("/api/representative/me"), null, status().isOk());
        assertThat(dash.at("/totals/reversedCents").asInt()).isEqualTo(1500);
        assertThat(call(salon.token, get("/api/salon/plan"), null, status().isOk()).get("status").asText()).isEqualTo("EXPIRED");
    }

    // ---------------- apoio ----------------

    private long repIdOf(JsonNode list, String code) {
        for (JsonNode r : list) {
            if (r.get("code").asText().equals(code)) {
                return r.get("id").asLong();
            }
        }
        return -1;
    }

    private Map<String, Object> payment(String id, String subscription, String customer, String link, double value, java.time.LocalDate due) {
        Map<String, Object> p = new java.util.HashMap<>();
        p.put("id", id);
        p.put("subscription", subscription);
        p.put("customer", customer);
        p.put("paymentLink", link);
        p.put("value", value);
        p.put("dueDate", due.toString());
        p.put("paymentDate", java.time.LocalDate.now().toString());
        return p;
    }

    private void send(String event, Map<String, Object> payment) throws Exception {
        mvc.perform(post("/api/asaas/webhook").contentType(MediaType.APPLICATION_JSON)
                .content(json.writeValueAsString(Map.of("id", "evt_" + UUID.randomUUID(), "event", event, "payment", payment)))
                .header("asaas-access-token", "token-do-webhook-de-teste-123456789")).andExpect(status().isOk());
    }

    private Salon register(String referralCode) throws Exception {
        String slug = "salao-" + UUID.randomUUID().toString().substring(0, 8);
        JsonNode res = call(null, post("/api/auth/register"), Map.of("salonName", "Salão " + slug, "slug", slug,
                "ownerName", "Dona", "email", slug + "@teste.com", "password", "123456", "referralCode", referralCode),
                status().isCreated());
        return new Salon(res.at("/user/salonId").asLong(), slug, res.get("token").asText());
    }

    private String login(String email, String password) throws Exception {
        return call(null, post("/api/auth/login"), Map.of("email", email, "password", password), status().isOk())
                .get("token").asText();
    }

    private JsonNode call(String token, MockHttpServletRequestBuilder req, Object body, ResultMatcher expected) throws Exception {
        if (token != null) {
            req.header("Authorization", "Bearer " + token);
        }
        if (body != null) {
            req.contentType(MediaType.APPLICATION_JSON).content(body instanceof String s ? s : json.writeValueAsString(body));
        }
        String content = mvc.perform(req).andExpect(expected).andReturn().getResponse().getContentAsString();
        return content.isEmpty() ? null : json.readTree(content);
    }
}
