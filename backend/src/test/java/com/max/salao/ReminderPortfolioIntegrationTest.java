package com.max.salao;

import static org.assertj.core.api.Assertions.assertThat;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.delete;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.multipart;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.put;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.header;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

import java.awt.image.BufferedImage;
import java.io.ByteArrayOutputStream;
import java.time.LocalDate;
import java.util.ArrayList;
import java.util.List;
import java.util.Map;
import java.util.UUID;

import javax.imageio.ImageIO;

import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.databind.ObjectMapper;
import com.max.salao.plan.PlatformSettings;
import com.max.salao.reminder.ReminderJob;
import com.max.salao.reminder.StaffReminderJob;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.autoconfigure.web.servlet.AutoConfigureMockMvc;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.http.MediaType;
import org.springframework.mock.web.MockMultipartFile;
import org.springframework.test.web.servlet.MockMvc;
import org.springframework.test.web.servlet.ResultMatcher;
import org.springframework.test.web.servlet.request.MockHttpServletRequestBuilder;
import org.springframework.test.web.servlet.request.MockMultipartHttpServletRequestBuilder;

/** Lembretes de confirmação (link público, lista do salão, aviso diário) e portfólio de fotos. */
@SpringBootTest(properties = {
        "spring.datasource.url=${TEST_DB_URL:jdbc:postgresql://localhost:5432/salao_test}",
        "app.media.storage-path=${java.io.tmpdir}/salao-max-test-media/${random.uuid}",
        "app.releases.public-base-url=https://salao.test"})
@AutoConfigureMockMvc
class ReminderPortfolioIntegrationTest {

    @Autowired
    MockMvc mvc;

    @Autowired
    ObjectMapper json;

    @Autowired
    ReminderJob reminderJob;

    @Autowired
    PlatformSettings platformSettings;

    @Autowired
    StaffReminderJob staffReminderJob;

    private final LocalDate tomorrow = LocalDate.now().plusDays(1);
    private final LocalDate inTwoDays = LocalDate.now().plusDays(2);

    @Test
    void customerConfirmsFromReminderLink() throws Exception {
        Tenant salon = register();
        openEveryDay(salon, "BOTH");
        long service = createService(salon, "Corte");
        String base = "/api/public/salons/" + salon.slug;

        String a = book(base, service, tomorrow + "T10:00:00", "Maria Souza", "(11) 98888-0001");
        String b = book(base, service, inTwoDays + "T11:00:00", "João", "11988880002");
        String c = book(base, service, tomorrow + "T15:00:00", "Ana", "11988880003");

        JsonNode booking = call(null, get(base + "/bookings/" + a), null, status().isOk());
        assertThat(booking.get("confirmable").asBoolean()).isTrue();
        assertThat(booking.get("reminderDays").toString()).isEqualTo("[1,2]");
        assertThat(call(null, get(base), null, status().isOk()).get("reminderDays").toString()).isEqualTo("[1,2]");

        // lista do salão: amanhã e depois de amanhã, com mensagem e link prontos
        JsonNode reminders = call(salon, get("/api/reminders"), null, status().isOk());
        assertThat(reminders.get("mode").asText()).isEqualTo("BOTH");
        assertThat(reminders.get("items")).hasSize(3);
        JsonNode first = reminders.get("items").get(0);
        assertThat(first.get("daysBefore").asInt()).isEqualTo(1);
        assertThat(first.get("confirmUrl").asText()).isEqualTo("https://salao.test/s/" + salon.slug + "/agendamento/" + a);
        assertThat(first.get("message").asText()).contains("Olá, Maria!").contains("amanhã").contains("10:00");
        assertThat(first.get("whatsappUrl").asText()).startsWith("https://wa.me/5511988880001?text=Ol%C3%A1");

        // cliente confirma pelo link (repetir não dá erro)
        JsonNode confirmed = call(null, post(base + "/bookings/" + a + "/confirm"), null, status().isOk());
        assertThat(confirmed.get("status").asText()).isEqualTo("CONFIRMED");
        assertThat(confirmed.get("confirmable").asBoolean()).isFalse();
        call(null, post(base + "/bookings/" + a + "/confirm"), null, status().isOk());
        call(null, post(base + "/bookings/inexistente/confirm"), null, status().isNotFound());

        // salão vê na agenda e no sino
        JsonNode agenda = call(salon, get("/api/appointments?from=" + tomorrow), null, status().isOk());
        assertThat(agenda.get(0).get("status").asText()).isEqualTo("CONFIRMED");
        assertThat(agenda.get(0).get("customerConfirmedAt").isNull()).isFalse();
        JsonNode inbox = call(salon, get("/api/notifications"), null, status().isOk());
        assertThat(inbox.get("items").get(0).get("type").asText()).isEqualTo("CONFIRMED");

        // salão mandou o WhatsApp para o João
        long joao = findReminder(call(salon, get("/api/reminders"), null, status().isOk()), "João")
                .get("appointmentId").asLong();
        call(salon, post("/api/reminders/" + joao + "/sent"), null, status().isNoContent());
        assertThat(findReminder(call(salon, get("/api/reminders"), null, status().isOk()), "João")
                .get("reminderSentAt").isNull()).isFalse();

        // cancelado não confirma
        call(null, post(base + "/bookings/" + b + "/cancel"), null, status().isOk());
        call(null, post(base + "/bookings/" + b + "/confirm"), null, status().isUnprocessableEntity());

        // aviso diário: só a Ana ainda falta (uma vez por dia)
        reminderJob.run();
        reminderJob.run();
        List<JsonNode> daily = new ArrayList<>();
        call(salon, get("/api/notifications"), null, status().isOk()).get("items").forEach(n -> {
            if (n.get("type").asText().equals("REMINDERS")) {
                daily.add(n);
            }
        });
        assertThat(daily).hasSize(1);
        assertThat(daily.get(0).get("title").asText()).isEqualTo("1 cliente para lembrar");
        assertThat(c).isNotBlank();
    }

    @Test
    void remindersCanBeTurnedOff() throws Exception {
        Tenant salon = register();
        openEveryDay(salon, "OFF");
        long service = createService(salon, "Escova");
        String base = "/api/public/salons/" + salon.slug;
        book(base, service, tomorrow + "T10:00:00", "Bia", "11977770001");

        JsonNode reminders = call(salon, get("/api/reminders"), null, status().isOk());
        assertThat(reminders.get("items")).isEmpty();
        assertThat(reminders.get("days")).isEmpty();
        assertThat(call(salon, get("/api/salon"), null, status().isOk()).get("reminderMode").asText()).isEqualTo("OFF");

        // apps antigos mandam o salão sem reminderMode: mantém o que estava
        JsonNode s = call(salon, get("/api/salon"), null, status().isOk());
        call(salon, put("/api/salon"), Map.of("name", s.get("name").asText(), "hours", json.convertValue(s.get("hours"), List.class),
                "slotMinutes", 30), status().isOk());
        assertThat(call(salon, get("/api/salon"), null, status().isOk()).get("reminderMode").asText()).isEqualTo("OFF");
    }

    @Test
    void portfolioUploadListOrderAndDelete() throws Exception {
        Tenant salon = register();
        Tenant other = register();
        long service = createService(salon, "Luzes");

        JsonNode p1 = upload(salon, png(2400, 1200), Map.of("caption", "Luzes loiras", "serviceId", String.valueOf(service)),
                status().isCreated());
        assertThat(p1.get("width").asInt()).isEqualTo(1600);
        assertThat(p1.get("height").asInt()).isEqualTo(800);
        assertThat(p1.get("serviceName").asText()).isEqualTo("Luzes");
        String url = p1.get("url").asText();
        assertThat(url).startsWith("https://salao.test/api/public/media/salons/").endsWith(".jpg");

        // arquivo servido publicamente (sem R2 nos testes: disco local)
        mvc.perform(get(url.substring("https://salao.test".length()))).andExpect(status().isOk())
                .andExpect(header().string("Content-Type", "image/jpeg"));

        JsonNode p2 = upload(salon, png(300, 300), Map.of(), status().isCreated());
        // a mais nova vem primeiro
        JsonNode list = call(salon, get("/api/portfolio"), null, status().isOk());
        assertThat(list.get(0).get("id").asLong()).isEqualTo(p2.get("id").asLong());

        call(salon, put("/api/portfolio/order"), Map.of("ids", List.of(p1.get("id").asLong(), p2.get("id").asLong())),
                status().isOk());
        assertThat(call(salon, get("/api/portfolio"), null, status().isOk()).get(0).get("id").asLong())
                .isEqualTo(p1.get("id").asLong());

        // página pública e filtro por serviço
        String base = "/api/public/salons/" + salon.slug;
        assertThat(call(null, get(base + "/portfolio"), null, status().isOk())).hasSize(2);
        assertThat(call(null, get(base + "/portfolio?serviceId=" + service), null, status().isOk())).hasSize(1);

        // outro salão não vê nem apaga
        assertThat(call(other, get("/api/portfolio"), null, status().isOk())).isEmpty();
        call(other, delete("/api/portfolio/" + p1.get("id").asLong()), null, status().isNotFound());

        // tipo inválido
        upload(salon, "olá".getBytes(), Map.of(), status().isUnprocessableEntity());

        call(salon, delete("/api/portfolio/" + p1.get("id").asLong()), null, status().isNoContent());
        assertThat(call(salon, get("/api/portfolio"), null, status().isOk())).hasSize(1);
        mvc.perform(get(url.substring("https://salao.test".length()))).andExpect(status().isNotFound());
    }

    @Test
    void trialHasPhotoLimit() throws Exception {
        PlatformSettings.Values original = platformSettings.get();
        try {
            platformSettings.save(new PlatformSettings.Values(original.trialDays(), original.maxProfessionals(),
                    original.maxServices(), original.maxCustomers(), original.contactWhatsapp(),
                    original.contactEmail(), 1, original.maxPhotosPaid(), original.billingEnabled(), original.playProductId()));
            Tenant salon = register();
            upload(salon, png(100, 100), Map.of(), status().isCreated());
            JsonNode error = upload(salon, png(100, 100), Map.of(), status().isUnprocessableEntity());
            assertThat(error.get("detail").asText()).contains("limite é de 1 fotos");
            JsonNode plan = call(salon, get("/api/salon/plan"), null, status().isOk());
            assertThat(plan.get("photos").get("used").asInt()).isEqualTo(1);
        } finally {
            platformSettings.save(original);
        }
    }

    @Test
    void staffChoosesOwnAppointmentReminders() throws Exception {
        Tenant owner = register();
        openEveryDay(owner, "ONE_DAY");
        long service = createService(owner, "Corte");
        long ana = call(owner, get("/api/professionals"), null, status().isOk()).get(0).get("id").asLong();
        long bruno = call(owner, post("/api/professionals"), Map.of("name", "Bruno", "commissionPercent", 0, "active", true),
                status().isCreated()).get("id").asLong();
        long customer = call(owner, post("/api/customers"), Map.of("name", "Lia Prado", "phone", "11966660001"),
                status().isCreated()).get("id").asLong();

        // regras inválidas
        call(owner, put("/api/me/reminders"), Map.of("rules", List.of(Map.of("daysBefore", 1))),
                status().isUnprocessableEntity());
        List<Map<String, Object>> six = new ArrayList<>();
        for (int i = 0; i < 6; i++) {
            six.add(Map.of("minutesBefore", 30 + i));
        }
        call(owner, put("/api/me/reminders"), Map.of("rules", six), status().isUnprocessableEntity());

        // "1 dia antes às 19h" e "65 minutos antes", só da agenda da Ana
        JsonNode saved = call(owner, put("/api/me/reminders"), Map.of("professionalId", ana, "rules", List.of(
                Map.of("daysBefore", 1, "atTime", "19:00"), Map.of("minutesBefore", 65))), status().isOk());
        assertThat(saved.get("rules")).hasSize(2);
        assertThat(call(owner, get("/api/me/reminders"), null, status().isOk()).get("professionalId").asLong())
                .isEqualTo(ana);

        java.time.LocalDateTime soon = java.time.LocalDateTime.now().withSecond(0).withNano(0).plusHours(1);
        LocalDate later = LocalDate.now().plusDays(3);
        appointment(owner, customer, ana, service, soon.toString());
        appointment(owner, customer, ana, service, later + "T10:00:00");
        appointment(owner, customer, bruno, service, later + "T11:00:00");

        // próximos avisos para o app agendar no aparelho (o de 65 min antes de "soon" já venceu)
        JsonNode upcoming = call(owner, get("/api/me/reminders/upcoming?days=7"), null, status().isOk());
        List<String> at = new ArrayList<>();
        upcoming.forEach(u -> at.add(u.get("remindAt").asText()));
        assertThat(at).contains(later.minusDays(1) + "T19:00:00", later + "T08:55:00");
        upcoming.forEach(u -> assertThat(u.get("message").asText()).doesNotContain("Bruno"));

        // job: grava no sino só do dono (uma vez), a equipe não vê
        String email = "staff-" + UUID.randomUUID() + "@teste.com";
        call(owner, post("/api/users"), Map.of("name", "Recepção", "email", email, "password", "123456",
                "role", "STAFF"), status().isCreated());
        Tenant staff = new Tenant(owner.slug, call(null, post("/api/auth/login"),
                Map.of("email", email, "password", "123456"), status().isOk()).get("token").asText());

        staffReminderJob.run();
        staffReminderJob.run();
        List<JsonNode> mine = new ArrayList<>();
        call(owner, get("/api/notifications"), null, status().isOk()).get("items").forEach(n -> {
            if (n.get("type").asText().equals("STAFF_REMINDER")) {
                mine.add(n);
            }
        });
        assertThat(mine).hasSize(1);
        assertThat(mine.get(0).get("title").asText()).startsWith("Atendimento às").endsWith("Lia Prado");
        call(staff, get("/api/notifications"), null, status().isOk()).get("items")
                .forEach(n -> assertThat(n.get("type").asText()).isNotEqualTo("STAFF_REMINDER"));

        // ler tudo no dono não marca os avisos da equipe que ele não vê... e vice-versa
        call(staff, post("/api/notifications/read"), null, status().isNoContent());
        assertThat(call(owner, get("/api/notifications"), null, status().isOk()).get("unread").asLong()).isEqualTo(1);
    }

    private void appointment(Tenant salon, long customer, long professional, long service, String startAt)
            throws Exception {
        call(salon, post("/api/appointments"), Map.of("customerId", customer, "professionalId", professional,
                "serviceId", service, "startAt", startAt, "force", true), status().isCreated());
    }

    // ---------------- helpers ----------------

    private record Tenant(String slug, String token) {
    }

    private Tenant register() throws Exception {
        String slug = "salao-" + UUID.randomUUID().toString().substring(0, 8);
        JsonNode res = call(null, post("/api/auth/register"), Map.of("salonName", "Salão Teste", "slug", slug,
                "ownerName", "Dona", "email", slug + "@teste.com", "password", "123456"), status().isCreated());
        return new Tenant(slug, res.get("token").asText());
    }

    /** Abre todos os dias das 8h às 20h (amanhã sempre disponível) e define o lembrete. */
    private void openEveryDay(Tenant salon, String reminderMode) throws Exception {
        List<Map<String, Object>> hours = new ArrayList<>();
        for (int d = 1; d <= 7; d++) {
            hours.add(Map.of("dayOfWeek", d, "openTime", "08:00", "closeTime", "20:00"));
        }
        call(salon, put("/api/salon"), Map.of("name", "Salão Teste", "hours", hours, "slotMinutes", 30,
                "reminderMode", reminderMode), status().isOk());
    }

    private long createService(Tenant salon, String name) throws Exception {
        call(salon, post("/api/professionals"), Map.of("name", "Ana", "commissionPercent", 0, "active", true),
                status().isCreated());
        return call(salon, post("/api/services"),
                Map.of("name", name, "durationMinutes", 60, "price", 80, "cost", 0, "active", true),
                status().isCreated()).get("id").asLong();
    }

    private String book(String base, long service, String startAt, String name, String phone) throws Exception {
        return call(null, post(base + "/bookings"), Map.of("serviceId", service, "startAt", startAt, "name", name,
                "phone", phone), status().isCreated()).get("token").asText();
    }

    private static JsonNode findReminder(JsonNode reminders, String customer) {
        for (JsonNode item : reminders.get("items")) {
            if (item.get("customerName").asText().equals(customer)) {
                return item;
            }
        }
        throw new AssertionError("sem lembrete para " + customer);
    }

    private JsonNode upload(Tenant tenant, byte[] content, Map<String, String> params, ResultMatcher expected)
            throws Exception {
        MockMultipartHttpServletRequestBuilder req = multipart("/api/portfolio")
                .file(new MockMultipartFile("file", "foto.png", "image/png", content));
        params.forEach(req::param);
        req.header("Authorization", "Bearer " + tenant.token);
        String body = mvc.perform(req).andExpect(expected).andReturn().getResponse().getContentAsString();
        return body.isEmpty() ? null : json.readTree(body);
    }

    private static byte[] png(int w, int h) throws Exception {
        ByteArrayOutputStream out = new ByteArrayOutputStream();
        ImageIO.write(new BufferedImage(w, h, BufferedImage.TYPE_INT_RGB), "png", out);
        return out.toByteArray();
    }

    private JsonNode call(Tenant tenant, MockHttpServletRequestBuilder req, Object body, ResultMatcher expected)
            throws Exception {
        if (tenant != null) {
            req.header("Authorization", "Bearer " + tenant.token);
        }
        if (body != null) {
            req.contentType(MediaType.APPLICATION_JSON).content(json.writeValueAsBytes(body));
        }
        String content = mvc.perform(req).andExpect(expected).andReturn().getResponse().getContentAsString();
        return content.isEmpty() ? null : json.readTree(content);
    }
}
