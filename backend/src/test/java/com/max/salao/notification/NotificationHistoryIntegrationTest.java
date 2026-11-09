package com.max.salao.notification;

import static org.assertj.core.api.Assertions.assertThat;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.delete;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

import java.time.DayOfWeek;
import java.time.LocalDate;
import java.util.Map;
import java.util.UUID;

import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.databind.ObjectMapper;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.autoconfigure.web.servlet.AutoConfigureMockMvc;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.http.MediaType;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.test.web.servlet.MockMvc;
import org.springframework.test.web.servlet.ResultMatcher;
import org.springframework.test.web.servlet.request.MockHttpServletRequestBuilder;

/** Histórico de avisos (status e período), apagar só o que já foi lido, limpar lidos e a limpeza automática. */
@SpringBootTest(properties = "spring.datasource.url=${TEST_DB_URL:jdbc:postgresql://localhost:5432/salao_test}")
@AutoConfigureMockMvc
class NotificationHistoryIntegrationTest {

    @Autowired
    MockMvc mvc;
    @Autowired
    ObjectMapper json;
    @Autowired
    JdbcTemplate jdbc;
    @Autowired
    NotificationCleanupJob cleanup;

    private record Salon(String slug, String token, long pro, long service) {
    }

    @Test
    void filtersByStatusAndPeriodAndDeletesOnlyWhatWasRead() throws Exception {
        Salon a = salon();
        Salon other = salon();
        for (int i = 0; i < 3; i++) {
            book(a, 10 + i);
        }
        book(other, 10);

        JsonNode all = call(a.token, get("/api/notifications/history"), null, status().isOk());
        assertThat(all.get("items")).hasSize(3);
        assertThat(all.get("unread").asLong()).isEqualTo(3);
        assertThat(call(a.token, get("/api/notifications/history?status=read"), null, status().isOk()).get("items")).isEmpty();
        assertThat(call(a.token, get("/api/notifications/history?status=unread"), null, status().isOk()).get("items")).hasSize(3);

        // aviso ainda não lido não se apaga
        long firstId = all.at("/items/0/id").asLong();
        JsonNode refused = call(a.token, delete("/api/notifications/" + firstId), null, status().isUnprocessableEntity());
        assertThat(refused.get("detail").asText()).contains("lidos");

        call(a.token, post("/api/notifications/read"), null, status().isNoContent());
        assertThat(call(a.token, get("/api/notifications/history?status=unread"), null, status().isOk()).get("items")).isEmpty();
        assertThat(call(a.token, get("/api/notifications/history?status=read"), null, status().isOk()).get("items")).hasSize(3);

        // períodos: um aviso de 40 dias atrás e outro de 100 dias atrás
        var ids = all.get("items");
        long recent = ids.get(0).get("id").asLong();
        long forty = ids.get(1).get("id").asLong();
        long hundred = ids.get(2).get("id").asLong();
        jdbc.update("update notification set created_at = now() - interval '40 days' where id = ?", forty);
        jdbc.update("update notification set created_at = now() - interval '100 days' where id = ?", hundred);
        LocalDate today = LocalDate.now();
        assertThat(call(a.token, get("/api/notifications/history?from=" + today + "&to=" + today), null, status().isOk()).get("items"))
                .hasSize(1);
        JsonNode old = call(a.token, get("/api/notifications/history?to=" + today.minusDays(50)), null, status().isOk());
        assertThat(old.get("items")).hasSize(1);
        assertThat(old.at("/items/0/id").asLong()).isEqualTo(hundred);
        // paginação
        JsonNode page = call(a.token, get("/api/notifications/history?size=2&page=0"), null, status().isOk());
        assertThat(page.get("items")).hasSize(2);
        assertThat(page.get("hasMore").asBoolean()).isTrue();
        assertThat(page.get("total").asLong()).isEqualTo(3);

        // outro salão não vê nem apaga os avisos deste
        assertThat(call(other.token, get("/api/notifications/history"), null, status().isOk()).get("items")).hasSize(1);
        call(other.token, delete("/api/notifications/" + recent), null, status().isUnprocessableEntity());

        // apagar um lido; repetir falha; "limpar lidos" só os anteriores à data
        call(a.token, delete("/api/notifications/" + recent), null, status().isNoContent());
        call(a.token, delete("/api/notifications/" + recent), null, status().isUnprocessableEntity());
        JsonNode cleared = call(a.token, post("/api/notifications/clear-read?before=" + today.minusDays(60)), null, status().isOk());
        assertThat(cleared.get("deleted").asInt()).isEqualTo(1); // o de 100 dias
        assertThat(call(a.token, get("/api/notifications/history"), null, status().isOk()).get("items")).hasSize(1);
        cleared = call(a.token, post("/api/notifications/clear-read"), null, status().isOk());
        assertThat(cleared.get("deleted").asInt()).isEqualTo(1); // o de 40 dias
        assertThat(call(a.token, get("/api/notifications/history"), null, status().isOk()).get("items")).isEmpty();
        // o do outro salão continua lá
        assertThat(call(other.token, get("/api/notifications/history"), null, status().isOk()).get("items")).hasSize(1);
    }

    @Test
    void nightlyCleanupRemovesOldReadAndVeryOldNotifications() throws Exception {
        Salon s = salon();
        for (int i = 0; i < 4; i++) {
            book(s, 10 + i);
        }
        JsonNode items = call(s.token, get("/api/notifications/history"), null, status().isOk()).get("items");
        long readOld = items.get(0).get("id").asLong();
        long readRecent = items.get(1).get("id").asLong();
        long unreadOld = items.get(2).get("id").asLong();
        long unreadVeryOld = items.get(3).get("id").asLong();
        jdbc.update("update notification set read_at = now() - interval '40 days', created_at = now() - interval '40 days' where id = ?", readOld);
        jdbc.update("update notification set read_at = now() where id = ?", readRecent);
        jdbc.update("update notification set created_at = now() - interval '40 days' where id = ?", unreadOld);
        jdbc.update("update notification set created_at = now() - interval '120 days' where id = ?", unreadVeryOld);

        cleanup.cleanup();

        var left = jdbc.queryForList("select id from notification where id in (?, ?, ?, ?)", Long.class, readOld, readRecent, unreadOld, unreadVeryOld);
        // lido há mais de 30 dias e qualquer um com mais de 90 dias saem; lido recente e não lido de 40 dias ficam
        assertThat(left).containsExactlyInAnyOrder(readRecent, unreadOld);
    }

    // ---------------- apoio ----------------

    private Salon salon() throws Exception {
        String slug = "salao-" + UUID.randomUUID().toString().substring(0, 8);
        JsonNode reg = call(null, post("/api/auth/register"), Map.of("salonName", "Salão " + slug, "slug", slug, "ownerName", "Dona",
                "email", slug + "@teste.com", "password", "123456"), status().isCreated());
        String token = reg.get("token").asText();
        long pro = call(token, post("/api/professionals"), Map.of("name", "Ana", "commissionPercent", 10, "active", true), status().isCreated())
                .get("id").asLong();
        long service = call(token, post("/api/services"), Map.of("name", "Corte", "durationMinutes", 30, "price", 80, "cost", 0, "active", true),
                status().isCreated()).get("id").asLong();
        return new Salon(slug, token, pro, service);
    }

    /** Agendamento online às {@code hour}h numa quarta-feira futura: gera o aviso "Novo agendamento online". */
    private void book(Salon s, int hour) throws Exception {
        LocalDate day = LocalDate.now().plusDays(2);
        while (day.getDayOfWeek() != DayOfWeek.WEDNESDAY) {
            day = day.plusDays(1);
        }
        call(null, post("/api/public/salons/" + s.slug + "/bookings"), Map.of("serviceId", s.service, "professionalId", s.pro,
                "startAt", day + "T" + hour + ":00:00", "name", "Cliente " + hour, "phone", "1191111" + (1000 + hour)), status().isCreated());
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
