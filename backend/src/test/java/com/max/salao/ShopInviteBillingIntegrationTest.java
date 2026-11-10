package com.max.salao;

import static org.assertj.core.api.Assertions.assertThat;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.anyInt;
import static org.mockito.ArgumentMatchers.anyString;
import static org.mockito.ArgumentMatchers.eq;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.delete;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.put;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

import java.time.LocalDate;
import java.time.LocalDateTime;
import java.util.HashMap;
import java.util.List;
import java.util.Map;
import java.util.UUID;

import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.databind.ObjectMapper;
import com.max.salao.billing.PlayBilling;
import com.max.salao.billing.WebBilling;
import com.max.salao.referral.ReferralService;
import com.max.salao.salon.SalonRepository;
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

/** Convites entre representantes e salões (comissão só se o salão parar e voltar) e a assinatura da loja pelo Asaas. */
@SpringBootTest(properties = {
        "spring.datasource.url=${TEST_DB_URL:jdbc:postgresql://localhost:5432/salao_test}",
        "app.asaas.api-key=chave-de-teste",
        "app.asaas.webhook-token=token-do-webhook-de-teste-123456789"})
@AutoConfigureMockMvc
class ShopInviteBillingIntegrationTest {

    @Autowired
    MockMvc mvc;
    @Autowired
    ObjectMapper json;
    @Autowired
    JdbcTemplate jdbc;
    @Autowired
    ReferralService referrals;
    @Autowired
    SalonRepository salons;

    @MockitoBean
    PlayBilling play;
    @MockitoBean
    WebBilling web;

    private record Rep(String token, String code, long id) {
    }

    private record Salon(String token, String slug, long id, String email) {
    }

    @Test
    void secondRepresentativeInviteWaitsWithoutCommissionUntilTheSalonLapsesAndReturns() throws Exception {
        Rep a = representative("Ana Fornecedora");
        Rep b = representative("Beto Fornecedor");
        Salon salon = salon(a.code());
        Salon free = salon(null);

        // salão já indicado por A: o convite de B fica pendente com aviso e sem comissão
        JsonNode invite = call(b.token(), post("/api/representative/invites"), Map.of("salon", "https://salaomax.focodev.com.br/s/" + salon.slug() + "?x=1"), status().isCreated());
        assertThat(invite.get("status").asText()).isEqualTo("PENDING");
        assertThat(invite.get("blockedByOther").asBoolean()).isTrue();
        assertThat(invite.get("message").asText()).contains("outro fornecedor").contains("não ganha comissão");
        call(b.token(), post("/api/representative/invites"), Map.of("salon", salon.slug()), status().isUnprocessableEntity());
        call(a.token(), post("/api/representative/invites"), Map.of("salon", salon.slug()), status().isUnprocessableEntity());
        call(b.token(), post("/api/representative/invites"), Map.of("salon", "nao-existe-" + UUID.randomUUID()), status().isNotFound());

        // o salão vê o convite e aceita: fica em espera, quem ganha continua sendo A
        JsonNode mine = call(salon.token(), get("/api/shop/invites"), null, status().isOk());
        assertThat(mine).hasSize(1);
        assertThat(mine.get(0).get("replacesCurrent").asBoolean()).isTrue();
        long inviteId = mine.get(0).get("id").asLong();
        assertThat(call(salon.token(), post("/api/shop/invites/" + inviteId + "/accept"), null, status().isOk()).get("status").asText()).isEqualTo("WAITING");
        assertThat(referrerOf(salon.id())).isEqualTo(a.id());
        assertThat(call(b.token(), get("/api/representative/invites"), null, status().isOk()).get(0).get("status").asText()).isEqualTo("WAITING");

        // salão com plano em dia paga: a comissão é de A
        jdbc.update("update salon set plan = 'PAID', paid_until = ? where id = ?", java.sql.Date.valueOf(LocalDate.now().plusDays(10)), salon.id());
        referrals.recordPayment(salons.findById(salon.id()).orElseThrow(), "ASAAS", "pay_" + UUID.randomUUID(), "ref", 4990, LocalDate.now().plusMonths(1), LocalDateTime.now());
        assertThat(commissionReps(salon.id())).containsExactly(a.id());
        assertThat(referrerOf(salon.id())).isEqualTo(a.id());

        // parou de pagar (venceu) e voltou: o convite de B passa a valer e ele ganha esta comissão
        jdbc.update("update salon set paid_until = ? where id = ?", java.sql.Date.valueOf(LocalDate.now().minusDays(5)), salon.id());
        referrals.recordPayment(salons.findById(salon.id()).orElseThrow(), "ASAAS", "pay_" + UUID.randomUUID(), "ref", 4990, LocalDate.now().plusMonths(1), LocalDateTime.now());
        assertThat(referrerOf(salon.id())).isEqualTo(b.id());
        assertThat(commissionReps(salon.id())).containsExactlyInAnyOrder(a.id(), b.id());
        assertThat(call(b.token(), get("/api/representative/invites"), null, status().isOk()).get(0).get("status").asText()).isEqualTo("ACTIVE");

        // salão sem representante: convite aceito vale na hora; recusar e cancelar
        JsonNode inv2 = call(b.token(), post("/api/representative/invites"), Map.of("salon", free.email()), status().isCreated());
        assertThat(inv2.get("blockedByOther").asBoolean()).isFalse();
        call(free.token(), post("/api/shop/invites/" + inv2.get("id").asLong() + "/accept"), null, status().isOk());
        assertThat(referrerOf(free.id())).isEqualTo(b.id());
        Salon third = salon(null);
        long inv3 = call(a.token(), post("/api/representative/invites"), Map.of("salon", third.slug()), status().isCreated()).get("id").asLong();
        call(third.token(), post("/api/shop/invites/" + inv3 + "/decline"), null, status().isNoContent());
        assertThat(referrerOf(third.id())).isNull();
        long inv4 = call(a.token(), post("/api/representative/invites"), Map.of("salon", third.slug()), status().isCreated()).get("id").asLong();
        call(a.token(), delete("/api/representative/invites/" + inv4), null, status().isNoContent());
        call(third.token(), post("/api/shop/invites/" + inv4 + "/accept"), null, status().isNotFound());
        // convite de outro salão não é visível nem aceitável
        call(third.token(), post("/api/shop/invites/" + inviteId + "/accept"), null, status().isNotFound());
    }

    @Test
    void shopSubscriptionTrialPaymentAndPausedStorefront() throws Exception {
        Rep rep = representative("Carla Loja");
        Salon salon = salon(rep.code());
        Map<String, Object> product = Map.of("name", "Shampoo", "costCents", 3000, "suggestedCents", 4500, "active", true);

        // abrir a assinatura inicia o teste grátis de 7 dias
        JsonNode plan = call(rep.token(), get("/api/representative/shop/plan"), null, status().isOk());
        assertThat(plan.get("status").asText()).isEqualTo("TRIAL");
        assertThat(plan.get("priceCents").asInt()).isEqualTo(4990);
        assertThat(plan.get("daysLeft").asLong()).isBetween(6L, 7L);
        long productId = call(rep.token(), post("/api/representative/shop/products"), product, status().isCreated()).get("id").asLong();
        call(salon.token(), put("/api/shop/products/" + productId + "/showcase"), Map.of("on", true), status().isNoContent());

        // teste vencido sem pagar: não cadastra nem recebe pedido; a vitrine pausa; o que já existe continua visível
        jdbc.update("update representative set shop_trial_ends = ? where id = ?", java.sql.Timestamp.valueOf(LocalDateTime.now().minusDays(1)), rep.id());
        assertThat(call(rep.token(), get("/api/representative/shop/plan"), null, status().isOk()).get("status").asText()).isEqualTo("EXPIRED");
        call(rep.token(), post("/api/representative/shop/products"), product, status().isUnprocessableEntity());
        call(rep.token(), org.springframework.test.web.servlet.request.MockMvcRequestBuilders.put("/api/representative/shop/products/" + productId), product, status().isUnprocessableEntity());
        assertThat(call(rep.token(), get("/api/representative/shop/products"), null, status().isOk())).hasSize(1);
        call(rep.token(), get("/api/representative/shop/orders"), null, status().isOk());
        JsonNode paused = call(salon.token(), get("/api/shop/catalog"), null, status().isOk());
        assertThat(paused.at("/vendors/0/paused").asBoolean()).isTrue();
        assertThat(paused.at("/vendors/0/products")).isEmpty();
        call(salon.token(), post("/api/shop/orders"), Map.of("items", List.of(Map.of("productId", productId, "quantity", 1)), "contactName", "Rita", "neighborhood", "Centro"), status().isUnprocessableEntity());
        assertThat(call(null, get("/api/public/salons/" + salon.slug() + "/shop-products"), null, status().isOk())).isEmpty();

        // assinar: abre a cobrança no Asaas (mock) e guarda os códigos
        when(web.subscribeCustom(any(), anyString(), anyString(), any(), eq(4990), anyString(), eq("rep:" + rep.id())))
                .thenReturn(new WebBilling.Subscribed("cus_rep_" + rep.id(), "sub_rep_" + rep.id(), "https://pagamento.test/fatura"));
        JsonNode checkout = call(rep.token(), post("/api/representative/shop/plan/checkout"), Map.of("cpfCnpj", "529.982.247-25"), status().isOk());
        assertThat(checkout.get("url").asText()).isEqualTo("https://pagamento.test/fatura");
        assertThat(call(rep.token(), get("/api/representative/shop/plan"), null, status().isOk()).get("hasSubscription").asBoolean()).isTrue();

        // pagamento confirmado (webhook, repetido não duplica): loja liberada de novo
        Map<String, Object> pay = new HashMap<>(Map.of("id", "pay_rep_" + rep.id(), "subscription", "sub_rep_" + rep.id(), "customer", "cus_rep_" + rep.id(),
                "status", "RECEIVED", "value", 49.90, "dueDate", LocalDate.now().toString(), "paymentDate", LocalDate.now().toString()));
        send("PAYMENT_CONFIRMED", pay);
        send("PAYMENT_RECEIVED", pay);
        assertThat(jdbc.queryForObject("select count(*) from shop_subscription_payment where representative_id = ?", Integer.class, rep.id())).isEqualTo(1);
        JsonNode active = call(rep.token(), get("/api/representative/shop/plan"), null, status().isOk());
        assertThat(active.get("status").asText()).isEqualTo("ACTIVE");
        call(rep.token(), post("/api/representative/shop/products"), product, status().isCreated());
        assertThat(call(salon.token(), get("/api/shop/catalog"), null, status().isOk()).at("/vendors/0/paused").asBoolean()).isFalse();
        call(salon.token(), post("/api/shop/orders"), Map.of("items", List.of(Map.of("productId", productId, "quantity", 1)), "contactName", "Rita", "neighborhood", "Centro"), status().isCreated());
        // não é mensalidade de salão: não mexe em plano nem comissão
        assertThat(jdbc.queryForObject("select count(*) from subscription_payment where salon_name like ?", Integer.class, "%" + salon.slug() + "%")).isZero();
        // já ativo: não abre outra cobrança
        call(rep.token(), post("/api/representative/shop/plan/checkout"), Map.of(), status().isUnprocessableEntity());

        // estorno tira o acesso pago
        send("PAYMENT_REFUNDED", pay);
        assertThat(call(rep.token(), get("/api/representative/shop/plan"), null, status().isOk()).get("status").asText()).isEqualTo("EXPIRED");

        // cancelar a cobrança mensal
        call(rep.token(), post("/api/representative/shop/plan/cancel"), null, status().isOk());
        verify(web).cancelSubscription("sub_rep_" + rep.id());
        assertThat(call(rep.token(), get("/api/representative/shop/plan"), null, status().isOk()).get("hasSubscription").asBoolean()).isFalse();
        call(rep.token(), post("/api/representative/shop/plan/cancel"), null, status().isUnprocessableEntity());
        // papéis: o salão não acessa a assinatura do representante
        call(salon.token(), get("/api/representative/shop/plan"), null, status().isForbidden());
    }

    @Test
    void salonBuysFromSeveralVendorsAndOrdersStaySeparatedByVendor() throws Exception {
        Rep a = representative("Ana Fornecedora");
        Rep b = representative("Beto Fornecedor");
        Rep c = representative("Cida Fornecedora");
        Salon salon = salon(a.code());
        Map<String, Object> pa = Map.of("name", "Produto da Ana", "costCents", 1000, "suggestedCents", 2000, "active", true);
        Map<String, Object> pb = Map.of("name", "Produto do Beto", "costCents", 3000, "suggestedCents", 5000, "active", true);
        long idA = call(a.token(), post("/api/representative/shop/products"), pa, status().isCreated()).get("id").asLong();
        long idB = call(b.token(), post("/api/representative/shop/products"), pb, status().isCreated()).get("id").asLong();
        long idC = call(c.token(), post("/api/representative/shop/products"), pa, status().isCreated()).get("id").asLong();

        // só o titular é vendedor; convite pendente (ainda não aceito) não dá acesso
        long inviteB = call(b.token(), post("/api/representative/invites"), Map.of("salon", salon.slug()), status().isCreated()).get("id").asLong();
        call(c.token(), post("/api/representative/invites"), Map.of("salon", salon.slug()), status().isCreated());
        assertThat(call(salon.token(), get("/api/shop/catalog"), null, status().isOk()).get("vendors")).hasSize(1);
        call(salon.token(), post("/api/shop/orders"), orderOf(idB), status().isUnprocessableEntity());
        call(salon.token(), put("/api/shop/products/" + idB + "/showcase"), Map.of("on", true), status().isNotFound());

        // aceitou o convite do Beto: ele passa a ser um vendedor do salão (mesmo em espera para a comissão)
        call(salon.token(), post("/api/shop/invites/" + inviteB + "/accept"), null, status().isOk());
        JsonNode catalog = call(salon.token(), get("/api/shop/catalog"), null, status().isOk());
        assertThat(catalog.get("vendors")).hasSize(2);
        assertThat(catalog.at("/vendors/0/name").asText()).isEqualTo("Ana");
        assertThat(catalog.at("/vendors/1/name").asText()).isEqualTo("Beto");
        assertThat(catalog.at("/vendors/0/products/0/vendorId").asLong()).isEqualTo(a.id());
        assertThat(catalog.at("/vendors/1/products/0/vendorId").asLong()).isEqualTo(b.id());

        // um carrinho com produtos dos dois vira dois pedidos, cada um só com os itens do seu vendedor
        JsonNode orders = call(salon.token(), post("/api/shop/orders"), Map.of("items", List.of(Map.of("productId", idA, "quantity", 2),
                Map.of("productId", idB, "quantity", 1)), "contactName", "Rita", "neighborhood", "Centro"), status().isCreated());
        assertThat(orders).hasSize(2);
        assertThat(orders.findValuesAsText("vendorName")).containsExactlyInAnyOrder("Ana", "Beto");
        JsonNode ordersA = call(a.token(), get("/api/representative/shop/orders"), null, status().isOk());
        JsonNode ordersB = call(b.token(), get("/api/representative/shop/orders"), null, status().isOk());
        assertThat(ordersA).hasSize(1);
        assertThat(ordersB).hasSize(1);
        assertThat(ordersA.get(0).get("totalCents").asLong()).isEqualTo(2000);
        assertThat(ordersA.get(0).get("items").findValuesAsText("name")).containsExactly("Produto da Ana");
        assertThat(ordersB.get(0).get("totalCents").asLong()).isEqualTo(3000);
        assertThat(ordersB.get(0).get("items").findValuesAsText("name")).containsExactly("Produto do Beto");
        // produto de quem não é vendedor do salão não entra
        call(salon.token(), post("/api/shop/orders"), orderOf(idC), status().isUnprocessableEntity());

        // "minhas compras" traz o nome do vendedor em cada pedido e o que deve a cada um
        JsonNode mine = call(salon.token(), get("/api/shop/orders"), null, status().isOk());
        assertThat(mine).hasSize(2);
        assertThat(mine.findValuesAsText("vendorName")).containsExactlyInAnyOrder("Ana", "Beto");
        JsonNode balance = call(salon.token(), get("/api/shop/balance"), null, status().isOk());
        assertThat(balance.get("owedCents").asLong()).isEqualTo(5000);
        assertThat(balance.get("vendors")).hasSize(2);

        // vitrine pública: produtos dos dois com o nome do vendedor; o pedido da cliente também se divide por vendedor
        call(salon.token(), put("/api/shop/products/" + idA + "/showcase"), Map.of("on", true), status().isNoContent());
        call(salon.token(), put("/api/shop/products/" + idB + "/showcase"), Map.of("on", true), status().isNoContent());
        JsonNode shown = call(null, get("/api/public/salons/" + salon.slug() + "/shop-products"), null, status().isOk());
        assertThat(shown).hasSize(2);
        assertThat(shown.findValuesAsText("vendorName")).containsExactlyInAnyOrder("Ana", "Beto");
        JsonNode receipt = call(null, post("/api/public/salons/" + salon.slug() + "/shop-orders"), Map.of("items", List.of(Map.of("productId", idA, "quantity", 1),
                Map.of("productId", idB, "quantity", 1)), "name", "Ana Cliente", "phone", "11988887777", "neighborhood", "Vila Nova"), status().isCreated());
        assertThat(receipt.get("ids")).hasSize(2);
        assertThat(receipt.get("totalCents").asLong()).isEqualTo(2000 + 5000);
        assertThat(call(a.token(), get("/api/representative/shop/orders"), null, status().isOk())).hasSize(2);
        assertThat(call(b.token(), get("/api/representative/shop/orders"), null, status().isOk())).hasSize(2);
        assertThat(call(salon.token(), get("/api/shop/customer-orders"), null, status().isOk())).hasSize(2);
        // as compras do salão continuam só as dele
        assertThat(call(salon.token(), get("/api/shop/orders"), null, status().isOk())).hasSize(2);
    }

    private Map<String, Object> orderOf(long productId) {
        return Map.of("items", List.of(Map.of("productId", productId, "quantity", 1)), "contactName", "Rita", "neighborhood", "Centro");
    }

    private Long referrerOf(long salonId) {
        return jdbc.queryForObject("select referrer_id from salon where id = ?", Long.class, salonId);
    }

    private List<Long> commissionReps(long salonId) {
        return jdbc.queryForList("select representative_id from commission where salon_id = ?", Long.class, salonId);
    }

    private void send(String event, Map<String, Object> payment) throws Exception {
        mvc.perform(post("/api/asaas/webhook").contentType(MediaType.APPLICATION_JSON)
                .content(json.writeValueAsString(Map.of("id", "evt_" + UUID.randomUUID(), "event", event, "payment", payment)))
                .header("asaas-access-token", "token-do-webhook-de-teste-123456789")).andExpect(status().isOk());
    }

    private Rep representative(String name) throws Exception {
        JsonNode res = call(null, post("/api/auth/register-representative"), Map.of("name", name, "email", "rep-" + UUID.randomUUID() + "@teste.com",
                "password", "123456"), status().isCreated());
        String token = res.get("token").asText();
        String code = call(token, get("/api/representative/me"), null, status().isOk()).get("code").asText();
        return new Rep(token, code, jdbc.queryForObject("select id from representative where code = ?", Long.class, code));
    }

    private Salon salon(String code) throws Exception {
        String slug = "salao-" + UUID.randomUUID().toString().substring(0, 8);
        Map<String, Object> body = new HashMap<>(Map.of("salonName", "Salão " + slug, "slug", slug, "ownerName", "Dona",
                "email", slug + "@teste.com", "password", "123456"));
        if (code != null) {
            body.put("referralCode", code);
        }
        JsonNode res = call(null, post("/api/auth/register"), body, status().isCreated());
        return new Salon(res.get("token").asText(), slug, res.at("/user/salonId").asLong(), slug + "@teste.com");
    }

    private JsonNode call(String token, MockHttpServletRequestBuilder req, Object body, ResultMatcher expected) throws Exception {
        if (token != null) {
            req.header("Authorization", "Bearer " + token);
        }
        if (body != null) {
            req.contentType(MediaType.APPLICATION_JSON).content(json.writeValueAsString(body));
        }
        String content = mvc.perform(req).andExpect(expected).andReturn().getResponse().getContentAsString();
        return content.isEmpty() ? null : json.readTree(content);
    }
}
