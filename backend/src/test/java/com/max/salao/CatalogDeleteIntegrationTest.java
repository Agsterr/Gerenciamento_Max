package com.max.salao;

import static org.assertj.core.api.Assertions.assertThat;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.delete;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;
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

/** Excluir serviço, pacote e produto: só o dono; o que tem histórico não apaga (desativar). */
@SpringBootTest(properties = "spring.datasource.url=${TEST_DB_URL:jdbc:postgresql://localhost:5432/salao_test}")
@AutoConfigureMockMvc
class CatalogDeleteIntegrationTest {

    @Autowired
    MockMvc mvc;

    @Autowired
    ObjectMapper json;

    @Test
    void servicesAndProductsCanBeDeletedUnlessTheyHaveHistory() throws Exception {
        String token = register();
        long pro = call(token, post("/api/professionals"), Map.of("name", "Ana", "commissionPercent", 10, "active", true),
                status().isCreated()).get("id").asLong();
        long cut = service(token, "Corte", 110);
        long brush = service(token, "Escova", 60);
        long unused = service(token, "Hidratação", 90);
        long kit = call(token, post("/api/services"), Map.of("name", "Corte + escova", "durationMinutes", 30, "price", 1,
                "cost", 0, "active", true, "kitServiceIds", List.of(cut, brush), "kitDiscountPercent", 10),
                status().isCreated()).get("id").asLong();
        long customer = call(token, post("/api/customers"), Map.of("name", "Maria Souza", "phone", "11911112222"),
                status().isCreated()).get("id").asLong();

        // serviço sem uso: apaga e some da lista
        call(token, delete("/api/services/" + unused), null, status().isNoContent());
        assertThat(call(token, get("/api/services"), null, status().isOk()).findValuesAsText("id")).doesNotContain(String.valueOf(unused));
        call(token, delete("/api/services/" + unused), null, status().isNotFound());

        // serviço dentro de um pacote: a mensagem manda tirar do pacote
        JsonNode inKit = call(token, delete("/api/services/" + cut), null, status().isUnprocessableEntity());
        assertThat(inKit.get("detail").asText()).contains("pacote");

        // com atendimento no histórico: não apaga, manda desativar
        call(token, post("/api/appointments"), Map.of("customerId", customer, "professionalId", pro, "serviceId", kit,
                "startAt", LocalDate.now().plusDays(1) + "T10:00:00", "force", true), status().isCreated());
        JsonNode used = call(token, delete("/api/services/" + kit), null, status().isUnprocessableEntity());
        assertThat(used.get("detail").asText()).contains("histórico").contains("Ativo");
        // o serviço continua lá, intacto
        assertThat(call(token, get("/api/services"), null, status().isOk()).findValuesAsText("id")).contains(String.valueOf(kit));

        // produto sem movimentação apaga; com movimentação não
        long free = product(token, "Shampoo");
        long moved = product(token, "Máscara");
        call(token, post("/api/products/" + moved + "/movements"), Map.of("type", "IN", "quantity", 5, "unitValue", 5), status().isCreated());
        call(token, delete("/api/products/" + free), null, status().isNoContent());
        JsonNode blocked = call(token, delete("/api/products/" + moved), null, status().isUnprocessableEntity());
        assertThat(blocked.get("detail").asText()).contains("movimentações");
        assertThat(call(token, get("/api/products"), null, status().isOk()).findValuesAsText("id"))
                .contains(String.valueOf(moved)).doesNotContain(String.valueOf(free));
    }

    @Test
    void onlyTheOwnerCanDelete() throws Exception {
        String owner = register();
        long cut = service(owner, "Corte", 110);
        long item = product(owner, "Shampoo");
        String email = "staff-" + UUID.randomUUID() + "@teste.com";
        call(owner, post("/api/users"), Map.of("name", "Recepção", "email", email, "password", "123456", "role", "STAFF"),
                status().isCreated());
        String staff = call(null, post("/api/auth/login"), Map.of("email", email, "password", "123456"), status().isOk())
                .get("token").asText();
        call(staff, delete("/api/services/" + cut), null, status().isForbidden());
        call(staff, delete("/api/products/" + item), null, status().isForbidden());
    }

    private long service(String token, String name, int price) throws Exception {
        return call(token, post("/api/services"), Map.of("name", name, "durationMinutes", 30, "price", price, "cost", 0,
                "active", true), status().isCreated()).get("id").asLong();
    }

    private long product(String token, String name) throws Exception {
        return call(token, post("/api/products"), Map.of("name", name, "costPrice", 5, "salePrice", 30, "minStock", 2,
                "unit", "un", "active", true), status().isCreated()).get("id").asLong();
    }

    private String register() throws Exception {
        String slug = "salao-" + UUID.randomUUID().toString().substring(0, 8);
        return call(null, post("/api/auth/register"), Map.of("salonName", "Salão Teste", "slug", slug,
                "ownerName", "Dona", "email", slug + "@teste.com", "password", "123456"), status().isCreated())
                .get("token").asText();
    }

    private JsonNode call(String token, MockHttpServletRequestBuilder req, Object body, ResultMatcher expected) throws Exception {
        if (token != null) {
            req.header("Authorization", "Bearer " + token);
        }
        if (body != null) {
            req.contentType(MediaType.APPLICATION_JSON).content(json.writeValueAsBytes(body));
        }
        String content = mvc.perform(req).andExpect(expected).andReturn().getResponse().getContentAsString();
        return content.isEmpty() ? null : json.readTree(content);
    }
}
