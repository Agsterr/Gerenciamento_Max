package com.max.salao;

import static org.assertj.core.api.Assertions.assertThat;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.put;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

import java.time.DayOfWeek;
import java.time.LocalDate;
import java.time.temporal.TemporalAdjusters;
import java.util.List;
import java.util.Map;
import java.util.UUID;

import com.fasterxml.jackson.databind.JsonNode;
import com.max.salao.shared.TenantContext;
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
 * Fluxo ponta a ponta contra um PostgreSQL real (padrão: localhost:5432/salao_test,
 * configurável via TEST_DB_URL / DB_USER / DB_PASSWORD).
 */
@SpringBootTest(properties = "spring.datasource.url=${TEST_DB_URL:jdbc:postgresql://localhost:5432/salao_test}")
@AutoConfigureMockMvc
class SalonFlowIntegrationTest {

    @Autowired
    MockMvc mvc;

    @Autowired
    ObjectMapper json;

    @Autowired
    java.time.Clock clock;

    @org.springframework.test.context.bean.override.mockito.MockitoBean
    com.max.salao.push.PushSender push;

    @Autowired
    com.max.salao.push.PromotionPushService pushService;

    /** Uma terça-feira futura (dia de funcionamento padrão). */
    private final LocalDate day = LocalDate.now().plusDays(7).with(TemporalAdjusters.next(DayOfWeek.TUESDAY));

    @Test
    void ownerManagesSalonAndCustomerBooksOnline() throws Exception {
        Tenant salon = register();
        long professional = id(call(salon, post("/api/professionals"),
                Map.of("name", "Ana", "commissionPercent", 40, "active", true), status().isCreated()));
        long service = id(call(salon, post("/api/services"),
                Map.of("name", "Corte", "durationMinutes", 60, "price", 100, "cost", 10, "active", true),
                status().isCreated()));
        long product = id(call(salon, post("/api/products"),
                Map.of("name", "Shampoo", "costPrice", 5, "salePrice", 30, "minStock", 2, "unit", "un",
                        "active", true),
                status().isCreated()));
        call(salon, post("/api/products/" + product + "/movements"),
                Map.of("type", "IN", "quantity", 5, "unitValue", 6), status().isCreated());

        // --- versão do cliente (sem login) ---
        String base = "/api/public/salons/" + salon.slug;
        JsonNode info = call(null, get(base), null, status().isOk());
        assertThat(info.get("services")).hasSize(1);

        JsonNode slots = call(null, get(base + "/availability?serviceId=" + service + "&date=" + day), null,
                status().isOk());
        assertThat(slots.get(0).get("time").asText()).isEqualTo("09:00:00");

        var booking = Map.of("serviceId", service, "startAt", day + "T10:00:00", "name", "Maria",
                "phone", "(11) 99999-0000");
        JsonNode booked = call(null, post(base + "/bookings"), booking, status().isCreated());
        assertThat(booked.get("professionalName").asText()).isEqualTo("Ana");

        // mesmo horário de novo: profissional ocupado
        call(null, post(base + "/bookings"), booking, status().isUnprocessableEntity());
        call(null, get(base + "/bookings/" + booked.get("token").asText()), null, status().isOk());

        // --- versão do salão ---
        JsonNode agenda = call(salon, get("/api/appointments?from=" + day), null, status().isOk());
        assertThat(agenda).hasSize(1);
        long appointment = agenda.get(0).get("id").asLong();
        assertThat(agenda.get(0).get("source").asText()).isEqualTo("ONLINE");

        call(salon, post("/api/appointments/" + appointment + "/start"), null, status().isOk());
        JsonNode finished = call(salon, post("/api/appointments/" + appointment + "/finish"),
                Map.of("price", 120,
                        "usedProducts", new Object[] {Map.of("productId", product, "quantity", 1)},
                        "soldProducts", new Object[] {Map.of("productId", product, "quantity", 1)}),
                status().isOk());
        assertThat(finished.get("status").asText()).isEqualTo("DONE");
        assertThat(finished.get("commissionAmount").decimalValue()).isEqualByComparingTo("48");

        JsonNode summary = call(salon, get("/api/reports/summary?from=" + day + "&to=" + day), null,
                status().isOk());
        assertThat(summary.get("servicesRevenue").decimalValue()).isEqualByComparingTo("120");
        assertThat(summary.get("appointmentsDone").asLong()).isEqualTo(1);
        assertThat(summary.get("onlineBookings").asLong()).isEqualTo(1);

        JsonNode products = call(salon, get("/api/products"), null, status().isOk());
        assertThat(products.get(0).get("stock").decimalValue()).isEqualByComparingTo("3");
    }

    @Test
    void tenantsAreIsolated() throws Exception {
        Tenant a = register();
        Tenant b = register();
        long customer = id(call(a, post("/api/customers"), Map.of("name", "Joana", "phone", "11988887777"),
                status().isCreated()));

        call(b, get("/api/customers/" + customer), null, status().isNotFound());
        assertThat(call(b, get("/api/customers"), null, status().isOk())).isEmpty();
        assertThat(call(a, get("/api/customers"), null, status().isOk())).hasSize(1);
    }

    @Test
    void staffCannotSeeFinancials() throws Exception {
        Tenant owner = register();
        String email = "staff-" + UUID.randomUUID() + "@teste.com";
        call(owner, post("/api/users"), Map.of("name", "Recepção", "email", email, "password", "123456",
                "role", "STAFF"), status().isCreated());
        JsonNode login = call(null, post("/api/auth/login"), Map.of("email", email, "password", "123456"),
                status().isOk());
        Tenant staff = new Tenant(owner.slug, login.get("token").asText());

        call(staff, get("/api/appointments?from=" + day), null, status().isOk());
        call(staff, get("/api/reports/summary?from=" + day + "&to=" + day), null, status().isForbidden());
    }

    @Test
    void manualBookingAllowsAnyTimeAndForcedFit() throws Exception {
        Tenant salon = register();
        long pro = id(call(salon, post("/api/professionals"),
                Map.of("name", "Ana", "commissionPercent", 0, "active", true), status().isCreated()));
        long service = id(call(salon, post("/api/services"),
                Map.of("name", "Corte", "durationMinutes", 60, "price", 80, "cost", 0, "active", true),
                status().isCreated()));
        long customer = id(call(salon, post("/api/customers"), Map.of("name", "Lia", "phone", "11911112222"),
                status().isCreated()));

        // horário fora da grade (10:10) e duração manual de 45 min
        JsonNode first = call(salon, post("/api/appointments"), Map.of("customerId", customer, "professionalId", pro,
                "serviceId", service, "startAt", day + "T10:10:00", "durationMinutes", 45), status().isCreated());
        assertThat(first.get("endAt").asText()).endsWith("10:55:00");
        assertThat(first.get("estimatedMinutes").asInt()).isEqualTo(45);

        var overlapping = Map.<String, Object>of("customerId", customer, "professionalId", pro,
                "serviceId", service, "startAt", day + "T10:30:00");
        call(salon, post("/api/appointments"), overlapping, status().isUnprocessableEntity());

        var forced = new java.util.HashMap<>(overlapping);
        forced.put("force", true);
        call(salon, post("/api/appointments"), forced, status().isCreated());
    }

    @Test
    void ownerCanDeleteAccountAndSalon() throws Exception {
        Tenant salon = register();
        assertThat(call(null, get("/api/public/salons?q=" + salon.slug), null, status().isOk())).hasSize(1);

        call(salon, post("/api/me/delete"), Map.of("password", "errada"), status().isUnauthorized());
        JsonNode res = call(salon, post("/api/me/delete"), Map.of("password", "123456"), status().isOk());
        assertThat(res.get("salonDeleted").asBoolean()).isTrue();

        call(null, get("/api/public/salons/" + salon.slug), null, status().isNotFound());
        call(null, post("/api/auth/login"), Map.of("email", salon.slug + "@teste.com", "password", "123456"),
                status().isUnauthorized());
    }

    @Test
    void pricingSuggestsPriceFromCostsCommissionAndMargin() throws Exception {
        Tenant salon = register();
        call(salon, post("/api/professionals"), Map.of("name", "Ana", "commissionPercent", 40, "active", true),
                status().isCreated());
        long service = id(call(salon, post("/api/services"),
                Map.of("name", "Corte", "durationMinutes", 60, "price", 100, "cost", 10, "active", true),
                status().isCreated()));
        // 10h/dia × 5 dias × 4,33 semanas × 1 profissional × 70% = 151,7 h vendáveis → R$ 10,00/h
        call(salon, put("/api/pricing/settings"), Map.of("cardFeePercent", 4, "targetMarginPercent", 20,
                "occupancyPercent", 70, "fixedMonthlyCost", 1516.67), status().isOk());

        JsonNode res = call(salon, get("/api/pricing"), null, status().isOk());
        assertThat(res.at("/basis/fixedCostPerHour").decimalValue()).isEqualByComparingTo("10.00");
        JsonNode corte = res.get("services").get(0);
        assertThat(corte.get("serviceId").asLong()).isEqualTo(service);
        assertThat(corte.get("directCost").decimalValue()).isEqualByComparingTo("20.00");      // 10 material + 10 fixo
        assertThat(corte.get("breakEvenPrice").decimalValue()).isEqualByComparingTo("35.72");  // 20 / (1 - 0,44)
        assertThat(corte.get("suggestedPrice").decimalValue()).isEqualByComparingTo("60.00");  // 20 / 0,36 = 55,56 → 60
        assertThat(corte.get("currentProfit").decimalValue()).isEqualByComparingTo("36.00");   // 100 - 20 - 44
        assertThat(corte.get("health").asText()).isEqualTo("HEALTHY");
    }

    @Test
    void eachDayHasItsOwnHoursAndLunchBreak() throws Exception {
        Tenant salon = register();
        call(salon, put("/api/salon"), Map.of("name", "Salão", "slotMinutes", 30, "hours", List.of(
                Map.of("dayOfWeek", 2, "openTime", "08:00", "closeTime", "18:00", "breakStart", "12:00", "breakEnd", "13:00"),
                Map.of("dayOfWeek", 6, "openTime", "08:00", "closeTime", "14:00"))), status().isOk());
        long pro = id(call(salon, post("/api/professionals"), Map.of("name", "Ana", "commissionPercent", 0, "active", true),
                status().isCreated()));
        long service = id(call(salon, post("/api/services"),
                Map.of("name", "Corte", "durationMinutes", 60, "price", 50, "cost", 0, "active", true), status().isCreated()));
        String base = "/api/public/salons/" + salon.slug;

        // terça: sem horários que encostam no almoço (12h–13h)
        JsonNode tuesday = call(null, get(base + "/availability?serviceId=" + service + "&date=" + day), null, status().isOk());
        List<String> times = new java.util.ArrayList<>();
        tuesday.forEach(s -> times.add(s.get("time").asText().substring(0, 5)));
        assertThat(times).contains("08:00", "11:00", "13:00", "17:00").doesNotContain("11:30", "12:00", "12:30", "17:30");

        // sábado: horário reduzido, último às 13h
        LocalDate saturday = day.with(TemporalAdjusters.next(DayOfWeek.SATURDAY));
        JsonNode sat = call(null, get(base + "/availability?serviceId=" + service + "&date=" + saturday), null, status().isOk());
        assertThat(sat.get(sat.size() - 1).get("time").asText()).startsWith("13:00");

        // segunda: fechado
        LocalDate monday = day.with(TemporalAdjusters.next(DayOfWeek.MONDAY));
        assertThat(call(null, get(base + "/availability?serviceId=" + service + "&date=" + monday), null, status().isOk())).isEmpty();

        // marcar no almoço só com encaixe
        long customer = id(call(salon, post("/api/customers"), Map.of("name", "Lia", "phone", "11911113333"), status().isCreated()));
        var lunch = new java.util.HashMap<String, Object>(Map.of("customerId", customer, "professionalId", pro,
                "serviceId", service, "startAt", day + "T12:00:00"));
        call(salon, post("/api/appointments"), lunch, status().isUnprocessableEntity());
        lunch.put("force", true);
        call(salon, post("/api/appointments"), lunch, status().isCreated());

        // pausa fora do expediente é recusada
        call(salon, put("/api/salon"), Map.of("name", "Salão", "slotMinutes", 30, "hours", List.of(
                Map.of("dayOfWeek", 2, "openTime", "08:00", "closeTime", "12:00", "breakStart", "11:00", "breakEnd", "13:00"))),
                status().isUnprocessableEntity());
        JsonNode info = call(null, get(base), null, status().isOk());
        assertThat(info.get("workDays").asText()).isEqualTo("2,6");
    }

    @Autowired
    org.springframework.jdbc.core.JdbcTemplate jdbc;

    @Test
    void databaseStoresTheSalonLocalTimeAsIs() throws Exception {
        Tenant salon = register();
        call(salon, put("/api/salon"), Map.of("name", "Salão", "slotMinutes", 30, "hours", List.of(
                Map.of("dayOfWeek", 2, "openTime", "08:00", "closeTime", "18:00", "breakStart", "12:00", "breakEnd", "13:00"))),
                status().isOk());
        long pro = id(call(salon, post("/api/professionals"), Map.of("name", "Ana", "commissionPercent", 0, "active", true),
                status().isCreated()));
        long service = id(call(salon, post("/api/services"),
                Map.of("name", "Corte", "durationMinutes", 60, "price", 50, "cost", 0, "active", true), status().isCreated()));
        long customer = id(call(salon, post("/api/customers"), Map.of("name", "Lia", "phone", "11922223333"), status().isCreated()));
        long appointment = id(call(salon, post("/api/appointments"), Map.of("customerId", customer, "professionalId", pro,
                "serviceId", service, "startAt", day + "T10:00:00"), status().isCreated()));

        // o que o usuário digitou é exatamente o que fica no banco (sem deslocamento de fuso)
        assertThat(jdbc.queryForObject("select to_char(start_at, 'HH24:MI') from appointment where id = ?", String.class,
                appointment)).isEqualTo("10:00");
        Long salonId = jdbc.queryForObject("select id from salon where slug = ?", Long.class, salon.slug);
        assertThat(jdbc.queryForObject("select to_char(open_time, 'HH24:MI') || '-' || to_char(break_start, 'HH24:MI') "
                + "from opening_hours where salon_id = ?", String.class, salonId)).isEqualTo("08:00-12:00");

        // datas automáticas (Java e banco) usam a hora do salão, não UTC
        var now = java.time.LocalDateTime.now(java.time.ZoneId.of("America/Sao_Paulo"));
        var javaSide = jdbc.queryForObject("select created_at from customer where id = ?", java.time.LocalDateTime.class, customer);
        var dbSide = jdbc.queryForObject("select created_at from salon where id = ?", java.time.LocalDateTime.class, salonId);
        assertThat(java.time.Duration.between(javaSide, now).abs().toMinutes()).isLessThan(2);
        assertThat(java.time.Duration.between(dbSide, now).abs().toMinutes()).isLessThan(2);
    }

    @Test
    void customerFindsReschedulesAndSalonGetsNotified() throws Exception {
        Tenant salon = register();
        call(salon, post("/api/professionals"), Map.of("name", "Ana", "commissionPercent", 0, "active", true),
                status().isCreated());
        long service = id(call(salon, post("/api/services"),
                Map.of("name", "Luzes", "durationMinutes", 60, "price", 200, "cost", 0, "active", true),
                status().isCreated()));
        String base = "/api/public/salons/" + salon.slug;
        JsonNode booked = call(null, post(base + "/bookings"), Map.of("serviceId", service, "startAt", day + "T10:00:00",
                "name", "Márcia Souza", "phone", "(11) 97777-6666"), status().isCreated());
        String token = booked.get("token").asText();
        assertThat(booked.get("cancelable").asBoolean()).isTrue();

        // consulta só com nome + telefone (acento e sobrenome não importam; o primeiro nome precisa conferir)
        String ip = UUID.randomUUID().toString();
        JsonNode mine = call(null, post(base + "/my-bookings").header("X-Forwarded-For", ip),
                Map.of("name", "marcia", "phone", "11977776666"), status().isOk());
        assertThat(mine).hasSize(1);
        assertThat(mine.get(0).get("token").asText()).isEqualTo(token);
        assertThat(call(null, post(base + "/my-bookings").header("X-Forwarded-For", ip),
                Map.of("name", "Joana", "phone", "11977776666"), status().isOk())).isEmpty();

        // anotação interna do profissional não aparece para o cliente
        long appointment = id(call(salon, get("/api/appointments?from=" + day), null, status().isOk()).get(0));
        call(salon, put("/api/appointments/" + appointment + "/service-notes"),
                Map.of("serviceNotes", "Tinta 7.1 + ox 20 vol"), status().isOk());
        JsonNode pub = call(null, get(base + "/bookings/" + token), null, status().isOk());
        assertThat(pub.has("serviceNotes")).isFalse();

        // remarca para um horário livre; horário fora do expediente é recusado
        JsonNode moved = call(null, post(base + "/bookings/" + token + "/reschedule"),
                Map.of("startAt", day + "T14:00:00"), status().isOk());
        assertThat(moved.get("startAt").asText()).isEqualTo(day + "T14:00:00");
        assertThat(moved.get("endAt").asText()).isEqualTo(day + "T15:00:00");
        call(null, post(base + "/bookings/" + token + "/reschedule"), Map.of("startAt", day + "T22:00:00"),
                status().isUnprocessableEntity());

        JsonNode inside = call(salon, get("/api/appointments?from=" + day), null, status().isOk()).get(0);
        assertThat(inside.get("serviceNotes").asText()).isEqualTo("Tinta 7.1 + ox 20 vol");

        call(null, post(base + "/bookings/" + token + "/cancel"), null, status().isOk());

        JsonNode inbox = call(salon, get("/api/notifications"), null, status().isOk());
        assertThat(inbox.get("unread").asLong()).isEqualTo(3);
        assertThat(inbox.get("items").get(0).get("type").asText()).isEqualTo("CANCELED");
        assertThat(inbox.get("items").get(1).get("type").asText()).isEqualTo("RESCHEDULED");
        call(salon, post("/api/notifications/read"), null, status().isNoContent());
        assertThat(call(salon, get("/api/notifications"), null, status().isOk()).get("unread").asLong()).isZero();
    }

    @Test
    void customerCancelFreesTheSlotOnlyWhenSalonAllows() throws Exception {
        Tenant salon = register();
        call(salon, post("/api/professionals"), Map.of("name", "Ana", "commissionPercent", 0, "active", true),
                status().isCreated());
        long service = id(call(salon, post("/api/services"),
                Map.of("name", "Corte", "durationMinutes", 60, "price", 80, "cost", 0, "active", true),
                status().isCreated()));
        String bookings = "/api/public/salons/" + salon.slug + "/bookings";
        Map<String, Object> at10 = Map.of("serviceId", service, "startAt", day + "T10:00:00",
                "name", "Márcia Souza", "phone", "(11) 97777-6666");
        Map<String, Object> at12 = Map.of("serviceId", service, "startAt", day + "T12:00:00",
                "name", "Márcia Souza", "phone", "(11) 97777-6666");

        // padrão: cancelou, a vaga volta e outra pessoa marca o mesmo horário
        assertThat(call(salon, get("/api/salon"), null, status().isOk()).get("releaseSlotOnCancel").asBoolean()).isTrue();
        String first = call(null, post(bookings), at10, status().isCreated()).get("token").asText();
        call(null, post(bookings + "/" + first + "/cancel"), null, status().isOk());
        call(null, post(bookings), at10, status().isCreated());

        // salão não libera: cancelou, o horário continua bloqueado e o salão só recebe o aviso
        JsonNode current = call(salon, get("/api/salon"), null, status().isOk());
        Map<String, Object> body = new java.util.HashMap<>(Map.of("name", "Salão", "slotMinutes", 30,
                "hours", json.convertValue(current.get("hours"), List.class)));
        body.put("releaseSlotOnCancel", false);
        assertThat(call(salon, put("/api/salon"), body, status().isOk()).get("releaseSlotOnCancel").asBoolean()).isFalse();
        String held = call(null, post(bookings), at12, status().isCreated()).get("token").asText();
        call(null, post(bookings + "/" + held + "/cancel"), null, status().isOk());
        call(null, post(bookings), at12, status().isUnprocessableEntity());
        assertThat(call(salon, get("/api/notifications"), null, status().isOk()).get("items").get(0).get("type").asText())
                .isEqualTo("CANCELED");
    }

    @Test
    void lookupIsRateLimited() throws Exception {
        Tenant salon = register();
        String base = "/api/public/salons/" + salon.slug;
        String ip = UUID.randomUUID().toString();
        for (int i = 0; i < 10; i++) {
            call(null, post(base + "/my-bookings").header("X-Forwarded-For", ip),
                    Map.of("name", "Ana", "phone", "119000000" + (10 + i)), status().isOk());
        }
        call(null, post(base + "/my-bookings").header("X-Forwarded-For", ip),
                Map.of("name", "Ana", "phone", "11900000099"), status().isTooManyRequests());
    }

    @Test
    void customerSignsInWithNameAndPhoneAcrossSalons() throws Exception {
        String phone = "119" + String.format("%08d", java.util.concurrent.ThreadLocalRandom.current().nextInt(100_000_000));
        for (Tenant salon : List.of(register(), register())) {
            call(salon, post("/api/professionals"), Map.of("name", "Ana", "commissionPercent", 0, "active", true),
                    status().isCreated());
            long service = id(call(salon, post("/api/services"),
                    Map.of("name", "Corte", "durationMinutes", 30, "price", 50, "cost", 0, "active", true),
                    status().isCreated()));
            call(null, post("/api/public/salons/" + salon.slug + "/bookings"), Map.of("serviceId", service,
                    "startAt", day + "T11:00:00", "name", "Bianca Lopes", "phone", phone), status().isCreated());
        }
        String ip = UUID.randomUUID().toString();
        JsonNode all = call(null, post("/api/public/my-bookings").header("X-Forwarded-For", ip),
                Map.of("name", "Bianca", "phone", phone), status().isOk());
        assertThat(all).hasSize(2);
        assertThat(all.get(0).get("salonSlug").asText()).isNotEqualTo(all.get(1).get("salonSlug").asText());
        assertThat(all.get(0).get("booking").get("cancelable").asBoolean()).isTrue();
        assertThat(call(null, post("/api/public/my-bookings").header("X-Forwarded-For", ip),
                Map.of("name", "Outra", "phone", phone), status().isOk())).isEmpty();
    }

    @Test
    void loggedUserRenewsTokenToStaySignedIn() throws Exception {
        Tenant salon = register();
        JsonNode renewed = call(salon, post("/api/me/token"), null, status().isOk());
        Tenant again = new Tenant(salon.slug, renewed.get("token").asText());
        assertThat(call(again, get("/api/me"), null, status().isOk()).get("salonSlug").asText()).isEqualTo(salon.slug);
        call(null, post("/api/me/token"), null, status().isUnauthorized());
    }

    @Test
    void servicesHaveCategoryAndOnlyTheirProfessionalsCanBeBooked() throws Exception {
        Tenant salon = register();
        long hairdresser = id(call(salon, post("/api/professionals"),
                Map.of("name", "Bia", "commissionPercent", 30, "active", true), status().isCreated()));
        long manicure = id(call(salon, post("/api/professionals"),
                Map.of("name", "Nina", "commissionPercent", 30, "active", true), status().isCreated()));
        long nails = id(call(salon, post("/api/services"),
                Map.of("name", "Esmaltação", "durationMinutes", 60, "price", 40, "cost", 2, "active", true,
                        "category", "Unhas", "professionalIds", List.of(manicure)), status().isCreated()));
        long cut = id(call(salon, post("/api/services"),
                Map.of("name", "Corte", "durationMinutes", 60, "price", 80, "cost", 0, "active", true,
                        "category", "Cabelo"), status().isCreated()));

        String base = "/api/public/salons/" + salon.slug;
        JsonNode info = call(null, get(base), null, status().isOk());
        JsonNode nailsInfo = info.get("services").get(0).get("name").asText().equals("Esmaltação")
                ? info.get("services").get(0) : info.get("services").get(1);
        assertThat(nailsInfo.get("category").asText()).isEqualTo("Unhas");
        assertThat(nailsInfo.get("professionalIds")).hasSize(1);

        // horários de unhas só da manicure; corte (sem restrição) qualquer uma
        JsonNode slots = call(null, get(base + "/availability?serviceId=" + nails + "&date=" + day), null, status().isOk());
        assertThat(slots.get(0).get("professionalIds")).extracting(JsonNode::asLong).containsExactly(manicure);
        JsonNode cutSlots = call(null, get(base + "/availability?serviceId=" + cut + "&date=" + day), null, status().isOk());
        assertThat(cutSlots.get(0).get("professionalIds")).hasSize(2);

        var wrong = Map.of("serviceId", nails, "professionalId", hairdresser, "startAt", day + "T10:00:00",
                "name", "Maria", "phone", "(11) 99999-0000");
        call(null, post(base + "/bookings"), wrong, status().isUnprocessableEntity());

        // "qualquer profissional": o app escolhe quem faz
        var any = Map.of("serviceId", nails, "startAt", day + "T10:00:00", "name", "Maria", "phone", "(11) 99999-0000");
        assertThat(call(null, post(base + "/bookings"), any, status().isCreated()).get("professionalName").asText())
                .isEqualTo("Nina");
    }

    @Test
    void professionalSpecialtyDecidesWhichServicesTheyDo() throws Exception {
        Tenant salon = register();
        long hair = id(call(salon, post("/api/professionals"),
                Map.of("name", "Bia", "commissionPercent", 30, "active", true, "categories", List.of("Cabelo")),
                status().isCreated()));
        long nails = id(call(salon, post("/api/professionals"),
                Map.of("name", "Nina", "commissionPercent", 30, "active", true, "categories", List.of("Unhas")),
                status().isCreated()));
        long polish = id(call(salon, post("/api/services"),
                Map.of("name", "Esmaltação", "durationMinutes", 60, "price", 40, "cost", 2, "active", true,
                        "category", "Unhas"), status().isCreated()));
        long cut = id(call(salon, post("/api/services"),
                Map.of("name", "Corte", "durationMinutes", 60, "price", 80, "cost", 0, "active", true,
                        "category", "cabelo"), status().isCreated()));
        long other = id(call(salon, post("/api/services"),
                Map.of("name", "Avaliação", "durationMinutes", 30, "price", 0, "cost", 0, "active", true),
                status().isCreated()));

        String base = "/api/public/salons/" + salon.slug;
        JsonNode info = call(null, get(base), null, status().isOk());
        for (JsonNode s : info.get("services")) {
            String name = s.get("name").asText();
            if (name.equals("Esmaltação")) {
                assertThat(s.get("professionalIds")).extracting(JsonNode::asLong).containsExactly(nails);
            } else if (name.equals("Corte")) {
                assertThat(s.get("professionalIds")).extracting(JsonNode::asLong).containsExactly(hair);
            } else {
                assertThat(s.get("professionalIds")).isEmpty(); // sem categoria: qualquer um
            }
        }

        var wrong = Map.of("serviceId", polish, "professionalId", hair, "startAt", day + "T10:00:00",
                "name", "Maria", "phone", "(11) 99999-0000");
        call(null, post(base + "/bookings"), wrong, status().isUnprocessableEntity());
        var any = Map.of("serviceId", cut, "startAt", day + "T10:00:00", "name", "Maria", "phone", "(11) 99999-0000");
        assertThat(call(null, post(base + "/bookings"), any, status().isCreated()).get("professionalName").asText())
                .isEqualTo("Bia");

        // lista explícita no serviço manda sobre a especialidade
        call(salon, put("/api/services/" + other), Map.of("name", "Avaliação", "durationMinutes", 30, "price", 0,
                "cost", 0, "active", true, "category", "Unhas", "professionalIds", List.of(hair)), status().isOk());
        JsonNode again = call(null, get(base), null, status().isOk());
        for (JsonNode s : again.get("services")) {
            if (s.get("name").asText().equals("Avaliação")) {
                assertThat(s.get("professionalIds")).extracting(JsonNode::asLong).containsExactly(hair);
            }
        }
    }

    @Test
    void reportSeparatesFixedAndVariableExpensesReworksAndProducts() throws Exception {
        Tenant salon = register();
        long pro = id(call(salon, post("/api/professionals"),
                Map.of("name", "Ana", "commissionPercent", 40, "active", true), status().isCreated()));
        long service = id(call(salon, post("/api/services"),
                Map.of("name", "Escova", "durationMinutes", 60, "price", 70, "cost", 8, "active", true),
                status().isCreated()));
        long product = id(call(salon, post("/api/products"),
                Map.of("name", "Esmalte", "costPrice", 10, "salePrice", 15, "markupPercent", 50, "minStock", 1,
                        "unit", "un", "active", true), status().isCreated()));
        call(salon, post("/api/products/" + product + "/movements"),
                Map.of("type", "IN", "quantity", 10, "unitValue", 10), status().isCreated());
        long customer = id(call(salon, post("/api/customers"), Map.of("name", "Rita", "phone", "11977776666"),
                status().isCreated()));

        // cliente voltou para refazer: não paga, mas o material e o produto usado contam como custo
        long redo = id(call(salon, post("/api/appointments"), Map.of("customerId", customer, "professionalId", pro,
                "serviceId", service, "startAt", day + "T10:00:00"), status().isCreated()));
        JsonNode finished = call(salon, post("/api/appointments/" + redo + "/finish"), Map.of("rework", true,
                "usedProducts", new Object[] {Map.of("productId", product, "quantity", 1)}), status().isOk());
        assertThat(finished.get("price").decimalValue()).isEqualByComparingTo("0");
        assertThat(finished.get("commissionAmount").decimalValue()).isEqualByComparingTo("0");
        assertThat(finished.get("rework").asBoolean()).isTrue();

        call(salon, post("/api/products/" + product + "/movements"), Map.of("type", "SALE", "quantity", 2),
                status().isCreated());
        LocalDate today = LocalDate.now();
        call(salon, post("/api/expenses"), Map.of("description", "Aluguel da sala", "category", "Aluguel",
                "amount", 1500, "date", today.toString()), status().isCreated());
        call(salon, post("/api/expenses"), Map.of("description", "Café e biscoitos", "category",
                "Cortesias (café, água, lanches)", "amount", 40, "date", today.toString()), status().isCreated());

        JsonNode s = call(salon, get("/api/reports/summary?from=" + today + "&to=" + day), null, status().isOk());
        assertThat(s.get("fixedExpenses").decimalValue()).isEqualByComparingTo("1500");
        assertThat(s.get("variableExpenses").decimalValue()).isEqualByComparingTo("40");
        assertThat(s.get("fixedByCategory").get("Aluguel").decimalValue()).isEqualByComparingTo("1500");
        assertThat(s.get("rework").get("count").asLong()).isEqualTo(1);
        assertThat(s.get("rework").get("totalCost").decimalValue()).isEqualByComparingTo("18"); // 8 material + 10 esmalte
        assertThat(s.get("averageTicket").decimalValue()).isEqualByComparingTo("0");
        JsonNode p = s.get("products").get(0);
        assertThat(p.get("soldQuantity").decimalValue()).isEqualByComparingTo("2");
        assertThat(p.get("salesProfit").decimalValue()).isEqualByComparingTo("10");
        assertThat(p.get("usedCost").decimalValue()).isEqualByComparingTo("10");
        assertThat(p.get("stockValue").decimalValue()).isEqualByComparingTo("70");
        assertThat(p.get("markupPercent").decimalValue()).isEqualByComparingTo("50");

        // despesas fixas do mês passado viram as deste mês, sem duplicar
        java.time.YearMonth next = java.time.YearMonth.from(today).plusMonths(1);
        Map<String, Object> month = Map.of("month", next.toString());
        assertThat(call(salon, post("/api/expenses/repeat-fixed"), month, status().isOk()).get("created").asInt())
                .isEqualTo(1);
        assertThat(call(salon, post("/api/expenses/repeat-fixed"), month, status().isOk()).get("created").asInt())
                .isEqualTo(0);
    }

    @Test
    void kitsAndPromotionsChangeThePriceAndShowUpForTheCustomer() throws Exception {
        Tenant salon = register();
        call(salon, post("/api/professionals"), Map.of("name", "Ana", "commissionPercent", 0, "active", true),
                status().isCreated());
        long cut = id(call(salon, post("/api/services"), Map.of("name", "Corte", "durationMinutes", 60, "price", 100,
                "cost", 10, "active", true), status().isCreated()));
        long brush = id(call(salon, post("/api/services"), Map.of("name", "Escova", "durationMinutes", 30, "price", 50,
                "cost", 5, "active", true), status().isCreated()));
        JsonNode kit = call(salon, post("/api/services"), Map.of("name", "Corte + escova", "durationMinutes", 90,
                "price", 0, "cost", 0, "active", true, "kitServiceIds", List.of(cut, brush), "kitDiscountPercent", 20),
                status().isCreated());
        assertThat(kit.get("price").decimalValue()).isEqualByComparingTo("120"); // (100 + 50) − 20%
        assertThat(kit.get("durationMinutes").asInt()).isEqualTo(90);
        assertThat(kit.get("kitFullPrice").decimalValue()).isEqualByComparingTo("150");
        assertThat(kit.get("category").asText()).isEqualTo("Pacotes");

        // corte subiu: o pacote acompanha
        call(salon, put("/api/services/" + cut), Map.of("name", "Corte", "durationMinutes", 60, "price", 110,
                "cost", 10, "active", true), status().isOk());
        JsonNode all = call(salon, get("/api/services"), null, status().isOk());
        for (JsonNode x : all) {
            if (x.get("id").asLong() == kit.get("id").asLong()) {
                assertThat(x.get("price").decimalValue()).isEqualByComparingTo("128");
            }
        }

        LocalDate today = LocalDate.now();
        call(salon, post("/api/promotions"), Map.of("name", "Semana do corte", "discountPercent", 30,
                "startsOn", today.toString(), "endsOn", day.toString(), "active", true, "serviceIds", List.of(cut)),
                status().isCreated());

        String base = "/api/public/salons/" + salon.slug;
        JsonNode info = call(null, get(base), null, status().isOk());
        assertThat(info.get("promotions")).hasSize(1);
        for (JsonNode x : info.get("services")) {
            switch (x.get("name").asText()) {
                case "Corte" -> {
                    assertThat(x.get("promoPrice").decimalValue()).isEqualByComparingTo("77");
                    assertThat(x.get("promoName").asText()).isEqualTo("Semana do corte");
                }
                case "Corte + escova" -> {
                    assertThat(x.get("kitItems")).hasSize(2);
                    assertThat(x.get("promoPrice").isNull()).isTrue();
                }
                default -> assertThat(x.get("promoPrice").isNull()).isTrue();
            }
        }

        JsonNode booked = call(null, post(base + "/bookings"), Map.of("serviceId", cut, "startAt", day + "T10:00:00",
                "name", "Maria", "phone", "(11) 99999-0000"), status().isCreated());
        assertThat(booked.get("price").decimalValue()).isEqualByComparingTo("77");
        // depois do fim da promoção volta ao preço normal
        JsonNode later = call(null, post(base + "/bookings"), Map.of("serviceId", cut,
                "startAt", day.plusDays(7) + "T10:00:00", "name", "Maria", "phone", "(11) 99999-0000"),
                status().isCreated());
        assertThat(later.get("price").decimalValue()).isEqualByComparingTo("110");

        JsonNode agenda = call(salon, get("/api/appointments?from=" + day), null, status().isOk());
        long appointment = agenda.get(0).get("id").asLong();
        assertThat(agenda.get(0).get("promotionName").asText()).isEqualTo("Semana do corte");
        call(salon, post("/api/appointments/" + appointment + "/finish"), Map.of(), status().isOk());
        JsonNode s = call(salon, get("/api/reports/summary?from=" + day + "&to=" + day), null, status().isOk());
        assertThat(s.get("promotions").get("discounts").decimalValue()).isEqualByComparingTo("33");
        assertThat(s.get("servicesProfit").decimalValue()).isEqualByComparingTo("67"); // 77 − 10 de material
        assertThat(s.get("operatingProfit").decimalValue()).isEqualByComparingTo("67");
    }

    @Test
    void customerVisitAndPromoChoiceShowUpForTheSalon() throws Exception {
        Tenant salon = register();
        call(salon, post("/api/professionals"), Map.of("name", "Ana", "commissionPercent", 0, "active", true),
                status().isCreated());
        long cut = id(call(salon, post("/api/services"), Map.of("name", "Corte", "durationMinutes", 60, "price", 100,
                "cost", 0, "active", true), status().isCreated()));
        String base = "/api/public/salons/" + salon.slug;
        JsonNode booked = call(null, post(base + "/bookings"), Map.of("serviceId", cut, "startAt", day + "T10:00:00",
                "name", "Maria Souza", "phone", "(11) 98888-1111"), status().isCreated());

        // ainda não abriu o app: sem visita e sem escolha
        JsonNode before = call(salon, get("/api/customers"), null, status().isOk()).get(0);
        assertThat(before.get("lastSeenAt").isNull()).isTrue();
        assertThat(before.get("promoNotifications").isNull()).isTrue();

        // abriu o salão no app e desligou os avisos (identificado pelo código do agendamento)
        call(null, post(base + "/presence"), Map.of("token", booked.get("token").asText(), "promoNotifications", false),
                status().isNoContent());
        JsonNode after = call(salon, get("/api/customers"), null, status().isOk()).get(0);
        assertThat(after.get("lastSeenAt").isNull()).isFalse();
        assertThat(after.get("promoNotifications").asBoolean()).isFalse();

        // por nome + WhatsApp também; nome errado não mexe em nada
        call(null, post(base + "/presence"), Map.of("name", "Outra", "phone", "11988881111", "promoNotifications", true),
                status().isNoContent());
        assertThat(call(salon, get("/api/customers"), null, status().isOk()).get(0).get("promoNotifications").asBoolean())
                .isFalse();
        call(null, post(base + "/presence"), Map.of("name", "maria", "phone", "11988881111", "promoNotifications", true),
                status().isNoContent());
        assertThat(call(salon, get("/api/customers"), null, status().isOk()).get(0).get("promoNotifications").asBoolean())
                .isTrue();

        // promoção sem aviso no celular
        call(salon, post("/api/promotions"), Map.of("name", "Silenciosa", "discountPercent", 10,
                "startsOn", LocalDate.now().toString(), "endsOn", day.toString(), "active", true,
                "notifyCustomers", false), status().isCreated());
        assertThat(call(null, get(base), null, status().isOk()).get("promotions").get(0).get("notifyCustomers").asBoolean())
                .isFalse();
    }

    @Test
    void startedPromotionIsPushedOnceToDevicesThatAcceptIt() throws Exception {
        Tenant salon = register();
        call(salon, post("/api/professionals"), Map.of("name", "Ana", "commissionPercent", 0, "active", true),
                status().isCreated());
        long cut = id(call(salon, post("/api/services"), Map.of("name", "Corte", "durationMinutes", 60, "price", 100,
                "cost", 0, "active", true), status().isCreated()));
        String base = "/api/public/salons/" + salon.slug;
        // dois celulares abriram o salão; um desligou os avisos
        call(null, post(base + "/presence"), Map.of("pushToken", "cel-sim", "promoNotifications", true), status().isNoContent());
        call(null, post(base + "/presence"), Map.of("pushToken", "cel-nao", "promoNotifications", false), status().isNoContent());
        call(salon, post("/api/promotions"), Map.of("name", "Semana do corte", "discountPercent", 20,
                "startsOn", LocalDate.now().toString(), "endsOn", day.toString(), "active", true,
                "serviceIds", List.of(cut)), status().isCreated());

        var sent = new java.util.ArrayList<String>();
        org.mockito.Mockito.when(push.send(org.mockito.ArgumentMatchers.anyString(), org.mockito.ArgumentMatchers.anyString(),
                org.mockito.ArgumentMatchers.anyString(), org.mockito.ArgumentMatchers.anyMap())).thenAnswer(inv -> {
            sent.add(inv.getArgument(0) + " | " + inv.getArgument(2) + " | " + ((Map<?, ?>) inv.getArgument(3)).get("serviceId"));
            return com.max.salao.push.PushSender.Result.SENT;
        });
        Long tenant = jdbc.queryForObject("select id from salon where slug = ?", Long.class, salon.slug);
        try {
            com.max.salao.shared.TenantContext.set(tenant);
            assertThat(pushService.sendDue()).isEqualTo(1);
            assertThat(pushService.sendDue()).isEqualTo(0); // não repete
        } finally {
            com.max.salao.shared.TenantContext.clear();
        }
        assertThat(sent).singleElement().asString()
                .startsWith("cel-sim | Corte de R$ 100,00 por R$ 80,00 · até ")
                .endsWith(" | " + cut);
    }

    @Test
    void dashboardCountsAppointmentsByStatusProfessionalAndPeriod() throws Exception {
        Tenant salon = register();
        long ana = id(call(salon, post("/api/professionals"), Map.of("name", "Ana", "commissionPercent", 0, "active", true),
                status().isCreated()));
        long service = id(call(salon, post("/api/services"), Map.of("name", "Corte", "durationMinutes", 30, "price", 50,
                "cost", 0, "active", true), status().isCreated()));
        long maria = id(call(salon, post("/api/customers"), Map.of("name", "Maria", "phone", "11911112222"), status().isCreated()));
        long rita = id(call(salon, post("/api/customers"), Map.of("name", "Rita", "phone", "11933334444"), status().isCreated()));

        LocalDate today = LocalDate.now();
        // semana que vem, segunda e terça: 2 concluídos (1 refação), 1 cancelado, 1 falta, 1 ainda marcado
        LocalDate monday = today.plusDays(14).with(TemporalAdjusters.nextOrSame(DayOfWeek.MONDAY));
        java.util.function.BiFunction<LocalDate, String, Long> book = (d, time) -> {
            try {
                return id(call(salon, post("/api/appointments"), Map.of("customerId", maria, "professionalId", ana,
                        "serviceId", service, "startAt", d + "T" + time + ":00", "force", true), status().isCreated()));
            } catch (Exception e) {
                throw new IllegalStateException(e);
            }
        };
        long a1 = book.apply(monday, "09:00");
        long a2 = book.apply(monday, "10:00");
        long a3 = book.apply(monday, "11:00");
        long a4 = book.apply(monday.plusDays(1), "09:00");
        book.apply(monday.plusDays(1), "10:00");
        call(salon, post("/api/appointments/" + a1 + "/finish"), Map.of(), status().isOk());
        call(salon, post("/api/appointments/" + a2 + "/finish"), Map.of("rework", true), status().isOk());
        call(salon, post("/api/appointments/" + a3 + "/cancel"), Map.of(), status().isOk());
        call(salon, post("/api/appointments/" + a4 + "/no-show"), Map.of(), status().isOk());

        String q = "/api/reports/dashboard?from=" + monday + "&to=" + monday.plusDays(6);
        JsonNode week = call(salon, get(q + "&group=DAY"), null, status().isOk());
        JsonNode t = week.get("totals");
        assertThat(t.get("total").asInt()).isEqualTo(5);
        assertThat(t.get("done").asInt()).isEqualTo(2);
        assertThat(t.get("canceled").asInt()).isEqualTo(1);
        assertThat(t.get("noShow").asInt()).isEqualTo(1);
        assertThat(t.get("scheduled").asInt()).isEqualTo(1);
        assertThat(t.get("rework").asInt()).isEqualTo(1);
        assertThat(t.get("uniqueCustomers").asInt()).isEqualTo(1); // cancelado não conta; só a Maria
        assertThat(week.get("series")).hasSize(7);
        assertThat(week.get("series").get(0).get("done").asInt()).isEqualTo(2);
        assertThat(week.get("series").get(1).get("noShow").asInt()).isEqualTo(1);
        assertThat(week.get("byProfessional").get(0).get("name").asText()).isEqualTo("Ana");
        assertThat(week.get("byProfessional").get(0).get("done").asInt()).isEqualTo(2);
        assertThat(week.get("previousFrom").asText()).isEqualTo(monday.minusDays(7).toString());

        // por semana e por mês: uma linha por semana/mês do período
        assertThat(call(salon, get("/api/reports/dashboard?from=" + monday.withDayOfMonth(1) + "&to="
                + monday.plusMonths(2).withDayOfMonth(1) + "&group=MONTH"), null, status().isOk()).get("series")).hasSize(3);
        assertThat(call(salon, get(q + "&group=WEEK"), null, status().isOk()).get("series")).hasSize(1);

        // cliente que voltou: a Rita foi atendida na semana seguinte e a Maria já tinha atendimento antes
        long b = id(call(salon, post("/api/appointments"), Map.of("customerId", maria, "professionalId", ana,
                "serviceId", service, "startAt", monday.plusDays(7) + "T09:00:00", "force", true), status().isCreated()));
        long c = id(call(salon, post("/api/appointments"), Map.of("customerId", rita, "professionalId", ana,
                "serviceId", service, "startAt", monday.plusDays(7) + "T10:00:00", "force", true), status().isCreated()));
        call(salon, post("/api/appointments/" + b + "/finish"), Map.of(), status().isOk());
        call(salon, post("/api/appointments/" + c + "/finish"), Map.of(), status().isOk());
        JsonNode next = call(salon, get("/api/reports/dashboard?from=" + monday.plusDays(7) + "&to=" + monday.plusDays(13)
                + "&group=DAY"), null, status().isOk()).get("totals");
        assertThat(next.get("returningCustomers").asInt()).isEqualTo(1);
        assertThat(next.get("uniqueCustomers").asInt()).isEqualTo(2);
        assertThat(next.get("done").asInt()).isEqualTo(2);

    }

    @Test
    void onlineBookingWaitsForTheSalonToAcceptWhileSalonBookingsAreAcceptedAtOnce() throws Exception {
        Tenant salon = register();
        long ana = id(call(salon, post("/api/professionals"), Map.of("name", "Ana", "commissionPercent", 0, "active", true),
                status().isCreated()));
        long cut = id(call(salon, post("/api/services"), Map.of("name", "Corte", "durationMinutes", 30, "price", 50,
                "cost", 0, "active", true), status().isCreated()));
        long maria = id(call(salon, post("/api/customers"), Map.of("name", "Maria", "phone", "11911112222"), status().isCreated()));
        String base = "/api/public/salons/" + salon.slug;

        JsonNode online = call(null, post(base + "/bookings"), Map.of("serviceId", cut, "startAt", day + "T10:00:00",
                "name", "Joana", "phone", "(11) 98888-7777"), status().isCreated());
        String token = online.get("token").asText();
        assertThat(online.get("salonConfirmed").asBoolean()).isFalse(); // aguardando confirmação do salão

        // marcado pelo próprio salão: já nasce aceito
        long byStaff = id(call(salon, post("/api/appointments"), Map.of("customerId", maria, "professionalId", ana,
                "serviceId", cut, "startAt", day + "T11:00:00"), status().isCreated()));

        JsonNode list = call(salon, get("/api/appointments?from=" + day), null, status().isOk());
        long pendingId = 0;
        for (JsonNode a : list) {
            if (a.get("id").asLong() == byStaff) {
                assertThat(a.get("pendingAcceptance").asBoolean()).isFalse();
            } else {
                assertThat(a.get("pendingAcceptance").asBoolean()).isTrue();
                pendingId = a.get("id").asLong();
            }
        }

        // o salão aceita: o cliente passa a ver "confirmado pelo salão", sem perder o botão de confirmar presença
        JsonNode accepted = call(salon, post("/api/appointments/" + pendingId + "/accept"), Map.of(), status().isOk());
        assertThat(accepted.get("pendingAcceptance").asBoolean()).isFalse();
        JsonNode seen = call(null, get(base + "/bookings/" + token), null, status().isOk());
        assertThat(seen.get("salonConfirmed").asBoolean()).isTrue();
        assertThat(seen.get("confirmable").asBoolean()).isTrue();

        // cliente remarcou: precisa ser aceito de novo
        JsonNode moved = call(null, post(base + "/bookings/" + token + "/reschedule"),
                Map.of("startAt", day + "T15:00:00"), status().isOk());
        assertThat(moved.get("salonConfirmed").asBoolean()).isFalse();
    }

    @Test
    void salonClockFollowsTheSalonTimezone() throws Exception {
        Tenant salon = register();
        assertThat(call(salon, get("/api/salon"), null, status().isOk()).get("timezone").asText())
                .isEqualTo("America/Sao_Paulo");

        Map<String, Object> body = new java.util.HashMap<>(Map.of("name", "Salão", "slotMinutes", 30, "hours", List.of(
                Map.of("dayOfWeek", 2, "openTime", "08:00", "closeTime", "18:00"))));
        body.put("timezone", "Europe/London");
        call(salon, put("/api/salon"), body, status().isUnprocessableEntity());
        body.put("timezone", "America/Rio_Branco");
        assertThat(call(salon, put("/api/salon"), body, status().isOk()).get("timezone").asText())
                .isEqualTo("America/Rio_Branco");
        // app antigo (sem o campo) não troca o fuso
        body.remove("timezone");
        assertThat(call(salon, put("/api/salon"), body, status().isOk()).get("timezone").asText())
                .isEqualTo("America/Rio_Branco");

        Long salonId = jdbc.queryForObject("select id from salon where slug = ?", Long.class, salon.slug);
        TenantContext.set(salonId);
        try {
            var acre = java.time.LocalDateTime.now(java.time.ZoneId.of("America/Rio_Branco"));
            assertThat(java.time.Duration.between(java.time.LocalDateTime.now(clock), acre).abs().toMinutes()).isLessThan(2);
        } finally {
            TenantContext.clear();
        }
        // fora de um salão, o padrão é Brasília
        var sp = java.time.LocalDateTime.now(java.time.ZoneId.of("America/Sao_Paulo"));
        assertThat(java.time.Duration.between(java.time.LocalDateTime.now(clock), sp).abs().toMinutes()).isLessThan(2);
    }

    private record Tenant(String slug, String token) {
    }

    private Tenant register() throws Exception {
        String slug = "salao-" + UUID.randomUUID().toString().substring(0, 8);
        JsonNode res = call(null, post("/api/auth/register"), Map.of("salonName", "Salão Teste", "slug", slug,
                "ownerName", "Dona", "email", slug + "@teste.com", "password", "123456"), status().isCreated());
        return new Tenant(slug, res.get("token").asText());
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

    private static long id(JsonNode node) {
        return node.get("id").asLong();
    }
}
