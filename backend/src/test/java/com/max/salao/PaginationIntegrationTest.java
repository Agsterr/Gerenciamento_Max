package com.max.salao;

import static org.assertj.core.api.Assertions.assertThat;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

import java.time.LocalDate;
import java.util.ArrayList;
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

/** Busca e paginação de clientes, serviços e agendamentos (listas que crescem com o uso). */
@SpringBootTest(properties = "spring.datasource.url=${TEST_DB_URL:jdbc:postgresql://localhost:5432/salao_test}")
@AutoConfigureMockMvc
class PaginationIntegrationTest {

    @Autowired
    MockMvc mvc;

    @Autowired
    ObjectMapper json;

    @Test
    void customersArePagedAndSearchableByNameOrPhone() throws Exception {
        String token = register();
        for (int i = 0; i < 25; i++) {
            call(token, post("/api/customers"), Map.of("name", String.format("Cliente %02d", i),
                    "phone", String.format("1190000%04d", i)), status().isCreated());
        }
        call(token, post("/api/customers"), Map.of("name", "Zélia Prado", "phone", "11955554444"), status().isCreated());

        JsonNode first = call(token, get("/api/customers?page=0&size=10"), null, status().isOk());
        assertThat(first.get("items")).hasSize(10);
        assertThat(first.get("total").asInt()).isEqualTo(26);
        assertThat(first.get("hasMore").asBoolean()).isTrue();
        assertThat(first.get("items").get(0).get("name").asText()).isEqualTo("Cliente 00");

        JsonNode last = call(token, get("/api/customers?page=2&size=10"), null, status().isOk());
        assertThat(last.get("items")).hasSize(6);
        assertThat(last.get("hasMore").asBoolean()).isFalse();
        assertThat(last.get("items").get(5).get("name").asText()).isEqualTo("Zélia Prado");

        // busca por nome (sem diferenciar maiúsculas) e por pedaço do telefone, mesmo digitado com máscara
        assertThat(call(token, get("/api/customers?page=0&q=zélia"), null, status().isOk()).get("total").asInt()).isEqualTo(1);
        JsonNode byPhone = call(token, get("/api/customers?page=0&q=(11) 95555"), null, status().isOk());
        assertThat(byPhone.get("total").asInt()).isEqualTo(1);
        assertThat(byPhone.get("items").get(0).get("name").asText()).isEqualTo("Zélia Prado");
        assertThat(call(token, get("/api/customers?page=0&q=inexistente"), null, status().isOk()).get("items")).isEmpty();

        // tamanho é limitado e aceita valores ruins
        assertThat(call(token, get("/api/customers?page=0&size=100000"), null, status().isOk()).get("size").asInt()).isEqualTo(100);
        assertThat(call(token, get("/api/customers?page=-3&size=0"), null, status().isOk()).get("page").asInt()).isZero();

        // apps antigos: sem "page" continua a lista simples
        assertThat(call(token, get("/api/customers"), null, status().isOk()).isArray()).isTrue();
    }

    @Test
    void servicesCanBePagedAndFiltered() throws Exception {
        String token = register();
        call(token, post("/api/professionals"), Map.of("name", "Ana", "commissionPercent", 0, "active", true), status().isCreated());
        for (int i = 0; i < 10; i++) { // o teste grátis permite 10 serviços
            call(token, post("/api/services"), Map.of("name", String.format("Serviço %02d", i), "durationMinutes", 30,
                    "price", 50, "cost", 0, "active", i % 2 == 0, "category", i < 5 ? "Cabelo" : "Unhas"), status().isCreated());
        }
        JsonNode page = call(token, get("/api/services?page=0&size=5"), null, status().isOk());
        assertThat(page.get("items")).hasSize(5);
        assertThat(page.get("total").asInt()).isEqualTo(10);
        assertThat(page.get("hasMore").asBoolean()).isTrue();

        assertThat(call(token, get("/api/services?page=0&active=true"), null, status().isOk()).get("total").asInt()).isEqualTo(5);
        // a busca olha nome e categoria
        assertThat(call(token, get("/api/services?page=0&q=unhas"), null, status().isOk()).get("total").asInt()).isEqualTo(5);
        assertThat(call(token, get("/api/services?page=0&q=Serviço 03"), null, status().isOk()).get("total").asInt()).isEqualTo(1);
        // sem page: todos, como antes
        assertThat(call(token, get("/api/services"), null, status().isOk())).hasSize(10);
    }

    @Test
    void appointmentsSearchByStatusTextAndOrderWithTenantIsolation() throws Exception {
        String token = register();
        String other = register();
        long pro = call(token, post("/api/professionals"), Map.of("name", "Ana", "commissionPercent", 0, "active", true),
                status().isCreated()).get("id").asLong();
        long service = call(token, post("/api/services"), Map.of("name", "Corte", "durationMinutes", 30, "price", 80,
                "cost", 0, "active", true), status().isCreated()).get("id").asLong();
        long maria = call(token, post("/api/customers"), Map.of("name", "Maria Souza", "phone", "11911112222"),
                status().isCreated()).get("id").asLong();
        long joao = call(token, post("/api/customers"), Map.of("name", "João Lima", "phone", "11933334444"),
                status().isCreated()).get("id").asLong();

        LocalDate base = LocalDate.now().plusDays(10);
        List<Long> ids = new ArrayList<>();
        for (int i = 0; i < 6; i++) {
            long customer = i % 2 == 0 ? maria : joao;
            ids.add(call(token, post("/api/appointments"), Map.of("customerId", customer, "professionalId", pro,
                    "serviceId", service, "startAt", base.plusDays(i) + "T10:00:00", "force", true),
                    status().isCreated()).get("id").asLong());
        }
        call(token, post("/api/appointments/" + ids.get(0) + "/cancel"), null, status().isOk());
        call(token, post("/api/appointments/" + ids.get(1) + "/no-show"), null, status().isOk());

        JsonNode all = call(token, get("/api/appointments/search?size=4"), null, status().isOk());
        assertThat(all.get("total").asInt()).isEqualTo(6);
        assertThat(all.get("items")).hasSize(4);
        assertThat(all.get("hasMore").asBoolean()).isTrue();
        // mais recentes primeiro (padrão)
        assertThat(all.get("items").get(0).get("startAt").asText()).startsWith(base.plusDays(5).toString());

        JsonNode asc = call(token, get("/api/appointments/search?order=asc&size=2"), null, status().isOk());
        assertThat(asc.get("items").get(0).get("startAt").asText()).startsWith(base.toString());

        assertThat(call(token, get("/api/appointments/search?status=CANCELED"), null, status().isOk()).get("total").asInt()).isEqualTo(1);
        assertThat(call(token, get("/api/appointments/search?status=canceled,no_show"), null, status().isOk()).get("total").asInt()).isEqualTo(2);
        assertThat(call(token, get("/api/appointments/search?q=maria"), null, status().isOk()).get("total").asInt()).isEqualTo(3);
        assertThat(call(token, get("/api/appointments/search?q=33334444"), null, status().isOk()).get("total").asInt()).isEqualTo(3);
        assertThat(call(token, get("/api/appointments/search?q=corte&status=SCHEDULED"), null, status().isOk()).get("total").asInt()).isEqualTo(4);
        assertThat(call(token, get("/api/appointments/search?from=" + base.plusDays(4) + "&to=" + base.plusDays(5)),
                null, status().isOk()).get("total").asInt()).isEqualTo(2);
        call(token, get("/api/appointments/search?status=NADA"), null, status().isUnprocessableEntity());

        // outro salão não enxerga nada
        assertThat(call(other, get("/api/appointments/search"), null, status().isOk()).get("total").asInt()).isZero();
    }

    private String register() throws Exception {
        String slug = "salao-" + UUID.randomUUID().toString().substring(0, 8);
        return call(null, post("/api/auth/register"), Map.of("salonName", "Salão Teste", "slug", slug,
                "ownerName", "Dona", "email", slug + "@teste.com", "password", "123456"), status().isCreated())
                .get("token").asText();
    }

    private JsonNode call(String token, MockHttpServletRequestBuilder req, Object body, ResultMatcher expected)
            throws Exception {
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
