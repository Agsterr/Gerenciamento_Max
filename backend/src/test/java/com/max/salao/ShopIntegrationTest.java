package com.max.salao;

import static org.assertj.core.api.Assertions.assertThat;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.delete;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.put;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

import java.time.LocalDate;
import java.util.List;
import java.util.Map;
import java.util.UUID;

import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.databind.ObjectMapper;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.autoconfigure.web.servlet.AutoConfigureMockMvc;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.http.MediaType;
import org.springframework.test.web.servlet.MockMvc;
import org.springframework.test.web.servlet.ResultMatcher;
import org.springframework.test.web.servlet.request.MockHttpServletRequestBuilder;

/** Loja do representante: catálogo, vitrine do salão, pedidos, status, confirmação de recebimento e baixas (PostgreSQL real). */
@SpringBootTest(properties = "spring.datasource.url=${TEST_DB_URL:jdbc:postgresql://localhost:5432/salao_test}")
@AutoConfigureMockMvc
class ShopIntegrationTest {

    @Autowired
    MockMvc mvc;
    @Autowired
    ObjectMapper json;

    private record Rep(String token, String code) {
    }

    private record Salon(String token, String slug) {
    }

    @Test
    void catalogOrdersStatusReceiptAndPayments() throws Exception {
        Rep rep = representative("Paulo Vendas");
        Rep other = representative("Outra Vendedora");
        Salon salon = salon(rep.code());
        Salon stranger = salon(null);

        // produtos: valor dele, preço sugerido, promoção e foto opcional
        JsonNode shampoo = call(rep.token(), post("/api/representative/shop/products"), Map.of("name", "Shampoo Pro 1L", "kind", "PRODUCT",
                "category", "Cabelo", "costCents", 3000, "suggestedCents", 4500, "active", true), status().isCreated());
        assertThat(shampoo.get("priceCents").asInt()).isEqualTo(3000);
        assertThat(shampoo.get("gainCents").asInt()).isEqualTo(1500);
        assertThat(shampoo.get("tags").toString()).contains("NOVO");
        JsonNode dryer = call(rep.token(), post("/api/representative/shop/products"), Map.of("name", "Secador 2000W", "kind", "EQUIPMENT",
                "category", "Equipamentos", "costCents", 20000, "suggestedCents", 30000, "promoCents", 18000,
                "promoUntil", LocalDate.now().plusDays(5).toString(), "active", true), status().isCreated());
        assertThat(dryer.get("onPromo").asBoolean()).isTrue();
        assertThat(dryer.get("priceCents").asInt()).isEqualTo(18000);
        assertThat(dryer.get("tags").toString()).contains("PROMOCAO", "EQUIPAMENTO");
        // promoção vencida volta ao valor normal
        JsonNode expired = call(rep.token(), post("/api/representative/shop/products"), Map.of("name", "Chapinha", "kind", "EQUIPMENT",
                "costCents", 15000, "suggestedCents", 22000, "promoCents", 12000,
                "promoUntil", LocalDate.now().minusDays(1).toString(), "active", true), status().isCreated());
        assertThat(expired.get("onPromo").asBoolean()).isFalse();
        assertThat(expired.get("priceCents").asInt()).isEqualTo(15000);
        call(rep.token(), post("/api/representative/shop/products"), Map.of("name", "Escondido", "costCents", 100, "suggestedCents", 200,
                "active", false), status().isCreated());
        // validações
        call(rep.token(), post("/api/representative/shop/products"), Map.of("name", "", "costCents", 1, "suggestedCents", 2), status().isUnprocessableEntity());
        call(rep.token(), post("/api/representative/shop/products"), Map.of("name", "X", "costCents", 100, "suggestedCents", 200,
                "promoCents", 100), status().isUnprocessableEntity());

        // o salão vê só os produtos ativos do representante dele; quem não tem representante não tem loja
        JsonNode catalog = call(salon.token(), get("/api/shop/catalog"), null, status().isOk());
        assertThat(catalog.get("available").asBoolean()).isTrue();
        assertThat(catalog.get("representativeName").asText()).isEqualTo("Paulo");
        assertThat(catalog.get("products")).hasSize(3);
        assertThat(catalog.get("categories").toString()).contains("Cabelo", "Equipamentos");
        assertThat(call(stranger.token(), get("/api/shop/catalog"), null, status().isOk()).get("available").asBoolean()).isFalse();
        call(stranger.token(), post("/api/shop/orders"), order(shampoo.get("id").asLong(), 1, "Centro"), status().isUnprocessableEntity());

        // escolher o que mostra na vitrine
        call(salon.token(), put("/api/shop/products/" + expired.get("id").asLong() + "/visible"), Map.of("visible", false), status().isNoContent());
        JsonNode hidden = call(salon.token(), get("/api/shop/catalog"), null, status().isOk());
        assertThat(hidden.get("products").findValues("hidden").stream().filter(JsonNode::asBoolean).count()).isEqualTo(1);
        call(stranger.token(), put("/api/shop/products/" + expired.get("id").asLong() + "/visible"), Map.of("visible", false), status().isNotFound());

        // pedido: preço da promoção, total e ganho do salão se vender pelo sugerido
        call(salon.token(), post("/api/shop/orders"), Map.of("items", List.of(Map.of("productId", shampoo.get("id").asLong(), "quantity", 4),
                Map.of("productId", dryer.get("id").asLong(), "quantity", 1)), "contactName", "", "neighborhood", "Centro"), status().isUnprocessableEntity());
        call(salon.token(), post("/api/shop/orders"), order(shampoo.get("id").asLong(), 1, ""), status().isUnprocessableEntity());
        JsonNode created = call(salon.token(), post("/api/shop/orders"), Map.of("items", List.of(
                Map.of("productId", shampoo.get("id").asLong(), "quantity", 4), Map.of("productId", dryer.get("id").asLong(), "quantity", 1)),
                "contactName", "Dona Rita", "phone", "11999990000", "address", "Rua A, 10", "neighborhood", "Jardim das Flores",
                "city", "Santos", "note", "Entregar de manhã"), status().isCreated());
        long orderId = created.get("id").asLong();
        assertThat(created.get("status").asText()).isEqualTo("PENDING");
        assertThat(created.get("totalCents").asLong()).isEqualTo(4 * 3000 + 18000);
        assertThat(created.get("gainCents").asLong()).isEqualTo(4 * 1500 + 12000);
        assertThat(created.get("items")).hasSize(2);
        // o endereço fica guardado no salão para o próximo pedido
        assertThat(call(salon.token(), get("/api/shop/address"), null, status().isOk()).get("neighborhood").asText()).isEqualTo("Jardim das Flores");
        // produto de outro representante / inativo não entra no pedido
        long outroProduto = call(other.token(), post("/api/representative/shop/products"), Map.of("name", "Alheio", "costCents", 10,
                "suggestedCents", 20, "active", true), status().isCreated()).get("id").asLong();
        call(salon.token(), post("/api/shop/orders"), order(outroProduto, 1, "Centro"), status().isUnprocessableEntity());

        // segundo pedido em outro bairro; o representante vê tudo agrupado por bairro e o que tem a receber
        call(salon.token(), post("/api/shop/orders"), order(shampoo.get("id").asLong(), 2, "Boqueirão"), status().isCreated());
        JsonNode orders = call(rep.token(), get("/api/representative/shop/orders"), null, status().isOk());
        assertThat(orders).hasSize(2);
        assertThat(orders.get(0).get("neighborhood").asText()).isEqualTo("Boqueirão");
        JsonNode summary = call(rep.token(), get("/api/representative/shop/summary"), null, status().isOk());
        assertThat(summary.get("toReceiveCents").asLong()).isEqualTo(30000 + 6000);
        assertThat(summary.get("openOrders").asInt()).isEqualTo(2);
        assertThat(summary.get("deliveries")).hasSize(2);
        // outro representante não vê nem mexe
        assertThat(call(other.token(), get("/api/representative/shop/orders"), null, status().isOk())).isEmpty();
        call(other.token(), put("/api/representative/shop/orders/" + orderId + "/status"), Map.of("status", "PREPARING"), status().isNotFound());

        // fluxo de status: pendente → em preparação → enviado → (salão confirma) entregue
        call(salon.token(), post("/api/shop/orders/" + orderId + "/received"), null, status().isUnprocessableEntity());
        call(rep.token(), put("/api/representative/shop/orders/" + orderId + "/status"), Map.of("status", "DELIVERED"), status().isUnprocessableEntity());
        assertThat(call(rep.token(), put("/api/representative/shop/orders/" + orderId + "/status"), Map.of("status", "PREPARING"), status().isOk())
                .get("status").asText()).isEqualTo("PREPARING");
        call(salon.token(), post("/api/shop/orders/" + orderId + "/cancel"), null, status().isUnprocessableEntity());
        call(rep.token(), put("/api/representative/shop/orders/" + orderId + "/status"), Map.of("status", "SHIPPED"), status().isOk());
        assertThat(call(salon.token(), post("/api/shop/orders/" + orderId + "/received"), null, status().isOk())
                .get("status").asText()).isEqualTo("DELIVERED");
        call(stranger.token(), post("/api/shop/orders/" + orderId + "/received"), null, status().isNotFound());

        // baixas: parcial, depois o resto; não passa do que falta
        call(rep.token(), post("/api/representative/shop/orders/" + orderId + "/payments"), Map.of("amountCents", 40000, "method", "Pix"), status().isUnprocessableEntity());
        JsonNode half = call(rep.token(), post("/api/representative/shop/orders/" + orderId + "/payments"),
                Map.of("amountCents", 10000, "method", "Pix", "note", "sinal"), status().isCreated());
        assertThat(half.get("paidCents").asLong()).isEqualTo(10000);
        assertThat(half.get("balanceCents").asLong()).isEqualTo(20000);
        assertThat(call(salon.token(), get("/api/shop/balance"), null, status().isOk()).get("owedCents").asLong()).isEqualTo(20000 + 6000);

        // cancelar o pendente pelo próprio salão tira da conta
        long second = call(salon.token(), get("/api/shop/orders"), null, status().isOk()).get(0).get("id").asLong();
        call(salon.token(), post("/api/shop/orders/" + second + "/cancel"), null, status().isOk());
        assertThat(call(salon.token(), get("/api/shop/balance"), null, status().isOk()).get("owedCents").asLong()).isEqualTo(20000);
        call(rep.token(), post("/api/representative/shop/orders/" + second + "/payments"), Map.of("amountCents", 100, "method", "Pix"), status().isUnprocessableEntity());

        // editar e apagar produto
        call(rep.token(), put("/api/representative/shop/products/" + shampoo.get("id").asLong()), Map.of("name", "Shampoo Pro 1L", "kind", "PRODUCT",
                "costCents", 3200, "suggestedCents", 4800, "active", true), status().isOk());
        call(rep.token(), delete("/api/representative/shop/products/" + dryer.get("id").asLong()), null, status().isNoContent());
        assertThat(call(rep.token(), get("/api/representative/shop/orders"), null, status().isOk()).findValuesAsText("name").toString()).contains("Secador 2000W");

        // papéis: representante não acessa a loja do salão e o salão não acessa a do representante
        call(rep.token(), get("/api/shop/catalog"), null, status().isForbidden());
        call(salon.token(), get("/api/representative/shop/products"), null, status().isForbidden());
    }

    @Test
    void customersOfTheSalonOrderRepresentativeProductsAndSalonEarnsCommission() throws Exception {
        Rep rep = representative("Marcos Vendas");
        Salon salon = salon(rep.code());
        Salon stranger = salon(null);
        long shampoo = call(rep.token(), post("/api/representative/shop/products"), Map.of("name", "Shampoo Pro", "costCents", 3000,
                "suggestedCents", 4500, "active", true), status().isCreated()).get("id").asLong();
        long mask = call(rep.token(), post("/api/representative/shop/products"), Map.of("name", "Máscara", "costCents", 4000,
                "suggestedCents", 6000, "promoCents", 3500, "promoUntil", LocalDate.now().plusDays(3).toString(), "active", true),
                status().isCreated()).get("id").asLong();
        long other = call(rep.token(), post("/api/representative/shop/products"), Map.of("name", "Não marcado", "costCents", 100,
                "suggestedCents", 200, "active", true), status().isCreated()).get("id").asLong();

        // só o que o salão marcou aparece para as clientes, pelo preço sugerido; quem não tem representante não tem vitrine
        String base = "/api/public/salons/" + salon.slug();
        assertThat(call(null, get(base + "/shop-products"), null, status().isOk())).isEmpty();
        call(salon.token(), put("/api/shop/products/" + shampoo + "/showcase"), Map.of("on", true), status().isNoContent());
        call(salon.token(), put("/api/shop/products/" + mask + "/showcase"), Map.of("on", true), status().isNoContent());
        call(stranger.token(), put("/api/shop/products/" + shampoo + "/showcase"), Map.of("on", true), status().isNotFound());
        JsonNode shown = call(null, get(base + "/shop-products"), null, status().isOk());
        assertThat(shown).hasSize(2);
        assertThat(shown.findValuesAsText("name")).containsExactlyInAnyOrder("Shampoo Pro", "Máscara");
        assertThat(shown.toString()).contains("4500", "6000").doesNotContain("costCents");
        assertThat(call(null, get("/api/public/salons/" + stranger.slug() + "/shop-products"), null, status().isOk())).isEmpty();

        // a cliente pede: valida dados, produto marcado e quantidade
        Map<String, Object> ok = Map.of("items", List.of(Map.of("productId", shampoo, "quantity", 2), Map.of("productId", mask, "quantity", 1)),
                "name", "Ana Cliente", "phone", "11988887777", "address", "Rua B, 5", "neighborhood", "Vila Nova", "city", "Santos");
        call(null, post(base + "/shop-orders"), Map.of("items", List.of(Map.of("productId", shampoo, "quantity", 1)), "name", "Ana"), status().isUnprocessableEntity());
        call(null, post(base + "/shop-orders"), Map.of("items", List.of(Map.of("productId", other, "quantity", 1)), "name", "Ana",
                "phone", "11988887777", "neighborhood", "Vila Nova"), status().isUnprocessableEntity());
        call(null, post("/api/public/salons/" + stranger.slug() + "/shop-orders"), ok, status().isNotFound());
        JsonNode receipt = call(null, post(base + "/shop-orders"), ok, status().isCreated());
        long orderId = receipt.get("id").asLong();
        assertThat(receipt.get("totalCents").asLong()).isEqualTo(2 * 4500 + 6000);
        assertThat(receipt.get("representativeName").asText()).isEqualTo("Marcos");

        // vai direto ao representante, com a comissão do salão (preço sugerido menos o valor do salão, com a promoção)
        JsonNode orders = call(rep.token(), get("/api/representative/shop/orders"), null, status().isOk());
        assertThat(orders).hasSize(1);
        JsonNode o = orders.get(0);
        assertThat(o.get("origin").asText()).isEqualTo("CUSTOMER");
        assertThat(o.get("contactName").asText()).isEqualTo("Ana Cliente");
        assertThat(o.get("neighborhood").asText()).isEqualTo("Vila Nova");
        assertThat(o.get("commissionCents").asLong()).isEqualTo(2 * 1500 + 2500);
        assertThat(o.get("netCents").asLong()).isEqualTo(15000 - 5500);

        // não entra nas compras do salão nem na dívida dele; aparece nas vendas às clientes
        assertThat(call(salon.token(), get("/api/shop/orders"), null, status().isOk())).isEmpty();
        assertThat(call(salon.token(), get("/api/shop/balance"), null, status().isOk()).get("owedCents").asLong()).isZero();
        assertThat(call(salon.token(), get("/api/shop/customer-orders"), null, status().isOk())).hasSize(1);
        call(salon.token(), post("/api/shop/orders/" + orderId + "/cancel"), null, status().isNotFound());

        // o representante entrega; a comissão só é devida depois da entrega e é repassada uma vez
        call(rep.token(), post("/api/representative/shop/orders/" + orderId + "/commission"), null, status().isUnprocessableEntity());
        call(rep.token(), put("/api/representative/shop/orders/" + orderId + "/status"), Map.of("status", "DELIVERED"), status().isUnprocessableEntity());
        call(rep.token(), put("/api/representative/shop/orders/" + orderId + "/status"), Map.of("status", "SHIPPED"), status().isOk());
        assertThat(call(rep.token(), get("/api/representative/shop/summary"), null, status().isOk()).get("commissionOwedCents").asLong()).isZero();
        assertThat(call(rep.token(), put("/api/representative/shop/orders/" + orderId + "/status"), Map.of("status", "DELIVERED"), status().isOk())
                .get("status").asText()).isEqualTo("DELIVERED");
        assertThat(call(rep.token(), get("/api/representative/shop/summary"), null, status().isOk()).get("commissionOwedCents").asLong()).isEqualTo(5500);
        assertThat(call(rep.token(), post("/api/representative/shop/orders/" + orderId + "/commission"), null, status().isOk())
                .get("commissionSettled").asBoolean()).isTrue();
        call(rep.token(), post("/api/representative/shop/orders/" + orderId + "/commission"), null, status().isUnprocessableEntity());
        assertThat(call(rep.token(), get("/api/representative/shop/summary"), null, status().isOk()).get("commissionOwedCents").asLong()).isZero();

        // desmarcar tira da vitrine
        call(salon.token(), put("/api/shop/products/" + shampoo + "/showcase"), Map.of("on", false), status().isNoContent());
        assertThat(call(null, get(base + "/shop-products"), null, status().isOk())).hasSize(1);
    }

    private Map<String, Object> order(long productId, int qty, String neighborhood) {
        return Map.of("items", List.of(Map.of("productId", productId, "quantity", qty)), "contactName", "Dona Rita", "neighborhood", neighborhood);
    }

    private Rep representative(String name) throws Exception {
        JsonNode res = call(null, post("/api/auth/register-representative"), Map.of("name", name, "email", "rep-" + UUID.randomUUID() + "@teste.com",
                "password", "123456"), status().isCreated());
        String token = res.get("token").asText();
        return new Rep(token, call(token, get("/api/representative/me"), null, status().isOk()).get("code").asText());
    }

    private Salon salon(String code) throws Exception {
        String slug = "salao-" + UUID.randomUUID().toString().substring(0, 8);
        Map<String, Object> body = new java.util.HashMap<>(Map.of("salonName", "Salão " + slug, "slug", slug, "ownerName", "Dona",
                "email", slug + "@teste.com", "password", "123456"));
        if (code != null) {
            body.put("referralCode", code);
        }
        return new Salon(call(null, post("/api/auth/register"), body, status().isCreated()).get("token").asText(), slug);
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
