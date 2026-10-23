package com.max.salao;

import static org.assertj.core.api.Assertions.assertThat;
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

/**
 * Produção quebrou em dois pontos com dados reais: a busca de agendamentos (promoção carregada tarde demais) e o
 * relatório (pacote de serviços). Aqui há agendamento em promoção e agendamento de pacote, finalizados, e todas as
 * telas que listam agendamentos precisam responder.
 */
@SpringBootTest(properties = "spring.datasource.url=${TEST_DB_URL:jdbc:postgresql://localhost:5432/salao_test}")
@AutoConfigureMockMvc
class KitAndPromotionRegressionTest {

    @Autowired
    MockMvc mvc;

    @Autowired
    ObjectMapper json;

    @Test
    void listsSearchAndReportWorkWithPromotionAndKitAppointments() throws Exception {
        String token = register();
        long pro = call(token, post("/api/professionals"), Map.of("name", "Ana", "commissionPercent", 10, "active", true),
                status().isCreated()).get("id").asLong();
        long cut = service(token, "Corte", 110);
        long brush = service(token, "Escova", 60);
        long kit = call(token, post("/api/services"), Map.of("name", "Corte + escova", "durationMinutes", 30, "price", 1,
                "cost", 0, "active", true, "kitServiceIds", List.of(cut, brush), "kitDiscountPercent", 10),
                status().isCreated()).get("id").asLong();
        long customer = call(token, post("/api/customers"), Map.of("name", "Maria Souza", "phone", "11911112222"),
                status().isCreated()).get("id").asLong();

        LocalDate today = LocalDate.now();
        LocalDate day = today.plusDays(1);
        call(token, post("/api/promotions"), Map.of("name", "Semana do corte", "discountPercent", 30,
                "startsOn", today.toString(), "endsOn", day.plusDays(5).toString(), "active", true,
                "serviceIds", List.of(cut)), status().isCreated());

        long promoted = appointment(token, customer, pro, cut, day + "T10:00:00");
        long pack = appointment(token, customer, pro, kit, day + "T14:00:00");
        for (long id : new long[] {promoted, pack}) {
            call(token, post("/api/appointments/" + id + "/finish"), Map.of(), status().isOk());
        }

        // agenda do dia, busca/histórico e relatório
        JsonNode agenda = call(token, get("/api/appointments?from=" + day), null, status().isOk());
        assertThat(agenda).hasSize(2);

        JsonNode search = call(token, get("/api/appointments/search?status=DONE&size=10"), null, status().isOk());
        assertThat(search.get("total").asInt()).isEqualTo(2);
        boolean sawPromotion = false;
        for (JsonNode item : search.get("items")) {
            sawPromotion |= !item.get("promotionName").isNull() && item.get("promotionName").asText().equals("Semana do corte");
        }
        assertThat(sawPromotion).as("a busca mostra o nome da promoção").isTrue();
        assertThat(call(token, get("/api/appointments/search?q=corte"), null, status().isOk()).get("total").asInt()).isEqualTo(2);

        JsonNode summary = call(token, get("/api/reports/summary?from=" + day + "&to=" + day), null, status().isOk());
        assertThat(summary.get("promotions").get("appointments").asInt()).isEqualTo(1);
        assertThat(summary.get("promotions").get("kitsSold").asInt()).isEqualTo(1);

        // de novo, depois de tudo carregado: não pode depender de estado de sessão
        call(token, get("/api/reports/summary?from=" + day + "&to=" + day), null, status().isOk());
        call(token, get("/api/services?page=0"), null, status().isOk());
    }

    private long service(String token, String name, int price) throws Exception {
        return call(token, post("/api/services"), Map.of("name", name, "durationMinutes", 30, "price", price, "cost", 5,
                "active", true), status().isCreated()).get("id").asLong();
    }

    private long appointment(String token, long customer, long pro, long service, String startAt) throws Exception {
        return call(token, post("/api/appointments"), Map.of("customerId", customer, "professionalId", pro,
                "serviceId", service, "startAt", startAt, "force", true), status().isCreated()).get("id").asLong();
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
