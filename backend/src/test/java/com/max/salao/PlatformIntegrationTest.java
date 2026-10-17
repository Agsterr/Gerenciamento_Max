package com.max.salao;

import static org.assertj.core.api.Assertions.assertThat;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.multipart;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.put;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.content;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.header;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

import java.nio.charset.StandardCharsets;
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
import org.springframework.mock.web.MockMultipartFile;
import org.springframework.test.web.servlet.MockMvc;
import org.springframework.test.web.servlet.ResultMatcher;
import org.springframework.test.web.servlet.request.MockHttpServletRequestBuilder;
import org.springframework.test.web.servlet.request.MockMultipartHttpServletRequestBuilder;

/** Administrador da plataforma, bloqueio de salões/usuários e publicação de APKs (PostgreSQL real). */
@SpringBootTest(properties = {
        "spring.datasource.url=${TEST_DB_URL:jdbc:postgresql://localhost:5432/salao_test}",
        "app.platform-admin.email=" + PlatformIntegrationTest.ADMIN_EMAIL,
        "app.platform-admin.password=" + PlatformIntegrationTest.ADMIN_PASSWORD,
        "app.releases.deploy-token=" + PlatformIntegrationTest.DEPLOY_TOKEN,
        "app.releases.max-retained=2",
        "app.releases.storage-path=${java.io.tmpdir}/salao-max-test-releases/${random.uuid}",
        "app.releases.public-base-url=https://salao.test/"})
@AutoConfigureMockMvc
class PlatformIntegrationTest {

    static final String ADMIN_EMAIL = "plataforma@salaomax.test";
    static final String ADMIN_PASSWORD = "senha-da-plataforma";
    static final String DEPLOY_TOKEN = "token-de-deploy-de-teste";

    @Autowired
    MockMvc mvc;

    @Autowired
    ObjectMapper json;

    @Autowired
    JdbcTemplate jdbc;

    // ---------------- teste grátis / plano ----------------

    @Test
    void trialHasLimitsAndExpiredSalonIsReadOnlyUntilAdminActivates() throws Exception {
        String admin = login(ADMIN_EMAIL, ADMIN_PASSWORD);
        Salon salon = register();

        JsonNode plan = call(salon.token, get("/api/salon/plan"), null, status().isOk());
        assertThat(plan.get("status").asText()).isEqualTo("TRIAL");
        assertThat(plan.get("daysLeft").asLong()).isEqualTo(14);
        assertThat(plan.get("professionals").get("max").asInt()).isEqualTo(2);

        // limite de profissionais no teste
        for (int i = 0; i < 2; i++) {
            call(salon.token, post("/api/professionals"), Map.of("name", "P" + i, "commissionPercent", 0, "active", true),
                    status().isCreated());
        }
        JsonNode limit = call(salon.token, post("/api/professionals"),
                Map.of("name", "P3", "commissionPercent", 0, "active", true), status().isUnprocessableEntity());
        assertThat(limit.get("detail").asText()).contains("limite é de 2 profissionais").contains("ative o plano");
        // app das lojas: sem mandar assinar por fora (regra de pagamentos da Play/App Store)
        JsonNode storeLimit = call(salon.token, post("/api/professionals").header("X-App-Channel", "play"),
                Map.of("name", "P3", "commissionPercent", 0, "active", true), status().isUnprocessableEntity());
        assertThat(storeLimit.get("detail").asText()).contains("limite é de 2 profissionais")
                .doesNotContain("plano").doesNotContain("Salão Max");
        long service = call(salon.token, post("/api/services"),
                Map.of("name", "Corte", "durationMinutes", 30, "price", 50, "cost", 0, "active", true),
                status().isCreated()).get("id").asLong();

        // teste venceu: consulta liberada, alterações e agendamento online barrados
        jdbc.update("update salon set trial_ends_at = now() - interval '1 hour' where id = ?", salon.id);
        call(salon.token, get("/api/customers"), null, status().isOk());
        JsonNode expired = call(salon.token, post("/api/customers"), Map.of("name", "Ana", "phone", "11911112222"),
                status().isPaymentRequired());
        assertThat(expired.get("code").asText()).isEqualTo("PLAN_EXPIRED");
        assertThat(expired.get("detail").asText()).contains("ative seu plano");
        JsonNode storeExpired = call(salon.token, post("/api/customers").header("X-App-Channel", "play"),
                Map.of("name", "Ana", "phone", "11911112222"), status().isPaymentRequired());
        assertThat(storeExpired.get("code").asText()).isEqualTo("PLAN_EXPIRED");
        assertThat(storeExpired.get("detail").asText()).doesNotContain("plano").doesNotContain("Salão Max");
        call(null, post("/api/public/salons/" + salon.slug + "/bookings"), Map.of("serviceId", service,
                "startAt", java.time.LocalDate.now().plusDays(9) + "T10:00:00", "name", "Bia", "phone", "11922223333"),
                status().isPaymentRequired());
        assertThat(call(salon.token, get("/api/salon/plan"), null, status().isOk()).get("status").asText())
                .isEqualTo("EXPIRED");

        // admin ativa o plano pago: volta tudo, sem limites
        JsonNode listed = call(admin, post("/api/platform/salons/" + salon.id + "/plan"), Map.of("plan", "PAID"),
                status().isOk());
        assertThat(listed.get("planStatus").asText()).isEqualTo("ACTIVE");
        call(salon.token, post("/api/professionals"), Map.of("name", "P3", "commissionPercent", 0, "active", true),
                status().isCreated());
        call(salon.token, post("/api/customers"), Map.of("name", "Ana", "phone", "11911112222"), status().isCreated());

        // pago com vencimento no passado também vence
        call(admin, post("/api/platform/salons/" + salon.id + "/plan"),
                Map.of("plan", "PAID", "paidUntil", java.time.LocalDate.now().minusDays(1).toString()), status().isOk());
        call(salon.token, post("/api/customers"), Map.of("name", "Lia", "phone", "11933334444"),
                status().isPaymentRequired());
    }

    @Test
    void adminConfiguresTrialAndPublicTermsFollow() throws Exception {
        String admin = login(ADMIN_EMAIL, ADMIN_PASSWORD);
        JsonNode original = call(admin, get("/api/platform/settings"), null, status().isOk());
        try {
            call(admin, put("/api/platform/settings"), Map.of("trialDays", 7, "maxProfessionals", 1, "maxServices", 5,
                    "maxCustomers", 20, "contactWhatsapp", "(11) 98888-7777", "contactEmail", "vendas@salaomax.test"),
                    status().isOk());
            JsonNode terms = call(null, get("/api/public/plan"), null, status().isOk());
            assertThat(terms.get("trialDays").asInt()).isEqualTo(7);
            assertThat(terms.get("contactWhatsapp").asText()).isEqualTo("11988887777");
            Salon salon = register();
            assertThat(call(salon.token, get("/api/salon/plan"), null, status().isOk()).get("daysLeft").asLong())
                    .isEqualTo(7);
            // só o admin da plataforma mexe nisso
            call(salon.token, get("/api/platform/settings"), null, status().isForbidden());
        } finally {
            call(admin, put("/api/platform/settings"), json.convertValue(original, Map.class), status().isOk());
        }
    }

    // ---------------- bloqueio ----------------

    @Test
    void blockedSalonIsRejectedEvenWithIssuedTokens() throws Exception {
        String admin = login(ADMIN_EMAIL, ADMIN_PASSWORD);
        Salon a = register();
        Salon b = register();
        String staffEmail = "staff-" + UUID.randomUUID() + "@teste.com";
        call(a.token, post("/api/users"), Map.of("name", "Recepção", "email", staffEmail, "password", "123456",
                "role", "STAFF"), status().isCreated());
        String staff = login(staffEmail, "123456");

        call(admin, post("/api/platform/salons/" + a.id + "/block"), Map.of("reason", "Mensalidade em atraso"),
                status().isOk());

        // tokens emitidos antes do bloqueio deixam de valer na hora
        JsonNode problem = call(a.token, get("/api/customers"), null, status().isForbidden());
        assertThat(problem.get("code").asText()).isEqualTo("ACCOUNT_BLOCKED");
        assertThat(problem.get("detail").asText()).isEqualTo("Mensalidade em atraso");
        assertThat(call(staff, get("/api/me"), null, status().isForbidden()).get("code").asText())
                .isEqualTo("ACCOUNT_BLOCKED");

        // login também é barrado, com o mesmo formato
        JsonNode loginProblem = call(null, post("/api/auth/login"), Map.of("email", a.slug + "@teste.com",
                "password", "123456"), status().isForbidden());
        assertThat(loginProblem.get("code").asText()).isEqualTo("ACCOUNT_BLOCKED");
        assertThat(loginProblem.get("detail").asText()).isEqualTo("Mensalidade em atraso");
        // senha errada continua 401 (não revela o bloqueio)
        call(null, post("/api/auth/login"), Map.of("email", a.slug + "@teste.com", "password", "errada"),
                status().isUnauthorized());

        // some das rotas públicas
        call(null, get("/api/public/salons/" + a.slug), null, status().isNotFound());
        assertThat(call(null, get("/api/public/salons?q=" + a.slug), null, status().isOk())).isEmpty();

        // outro salão segue normal
        call(b.token, get("/api/customers"), null, status().isOk());
        call(null, get("/api/public/salons/" + b.slug), null, status().isOk());

        JsonNode listed = call(admin, get("/api/platform/salons?q=" + a.slug), null, status().isOk());
        assertThat(listed).hasSize(1);
        assertThat(listed.get(0).get("blocked").asBoolean()).isTrue();
        assertThat(listed.get(0).get("userCount").asLong()).isEqualTo(2);

        call(admin, post("/api/platform/salons/" + a.id + "/unblock"), null, status().isOk());
        call(a.token, get("/api/customers"), null, status().isOk());
        call(staff, get("/api/appointments?from=2030-01-01"), null, status().isOk());
        call(null, get("/api/public/salons/" + a.slug), null, status().isOk());
    }

    @Test
    void blockedUserIsRejectedButRestOfSalonWorks() throws Exception {
        String admin = login(ADMIN_EMAIL, ADMIN_PASSWORD);
        Salon salon = register();
        String staffEmail = "staff-" + UUID.randomUUID() + "@teste.com";
        long staffId = call(salon.token, post("/api/users"), Map.of("name", "Recepção", "email", staffEmail,
                "password", "123456", "role", "STAFF"), status().isCreated()).get("id").asLong();
        String staff = login(staffEmail, "123456");

        JsonNode users = call(admin, get("/api/platform/salons/" + salon.id + "/users"), null, status().isOk());
        assertThat(users).hasSize(2);

        call(admin, post("/api/platform/users/" + staffId + "/block"), Map.of("reason", "Saiu da equipe"),
                status().isOk());
        JsonNode problem = call(staff, get("/api/customers"), null, status().isForbidden());
        assertThat(problem.get("code").asText()).isEqualTo("ACCOUNT_BLOCKED");
        assertThat(problem.get("detail").asText()).isEqualTo("Saiu da equipe");
        call(null, post("/api/auth/login"), Map.of("email", staffEmail, "password", "123456"),
                status().isForbidden());
        call(salon.token, get("/api/customers"), null, status().isOk());

        call(admin, post("/api/platform/users/" + staffId + "/unblock"), null, status().isOk());
        call(staff, get("/api/customers"), null, status().isOk());
    }

    @Test
    void platformAdminIsSeparateFromTenants() throws Exception {
        String admin = login(ADMIN_EMAIL, ADMIN_PASSWORD);
        Salon salon = register();

        JsonNode me = call(admin, get("/api/me"), null, status().isOk());
        assertThat(me.get("role").asText()).isEqualTo("PLATFORM_ADMIN");
        assertThat(me.get("salonId").isNull()).isTrue();

        // admin não entra nas rotas de salão; salão não entra nas rotas da plataforma
        call(admin, get("/api/customers"), null, status().isForbidden());
        call(salon.token, get("/api/platform/salons"), null, status().isForbidden());
        call(null, get("/api/platform/salons"), null, status().isUnauthorized());

        // dono não consegue criar um admin da plataforma
        call(salon.token, post("/api/users"), Map.of("name", "X", "email", "x-" + UUID.randomUUID() + "@teste.com",
                "password", "123456", "role", "PLATFORM_ADMIN"), status().isUnprocessableEntity());

        long adminId = me.get("id").asLong();
        call(admin, post("/api/platform/users/" + adminId + "/block"), Map.of("reason", "x"),
                status().isUnprocessableEntity());
        call(admin, post("/api/platform/salons/" + salon.id + "/block"), Map.of("reason", ""),
                status().isBadRequest());
    }

    // ---------------- releases ----------------

    @Test
    void deployRequiresTokenAndKeepsOnlyLatestPerApp() throws Exception {
        jdbc.update("DELETE FROM app_release");
        call(null, get("/api/app/version?app=gestao"), null, status().isNotFound());
        call(null, get("/api/app/version?app=outro"), null, status().isBadRequest());

        deploy(null, "gestao", 1, apk("v1"), status().isForbidden());
        deploy("errado", "gestao", 1, apk("v1"), status().isForbidden());
        deploy(DEPLOY_TOKEN, "gestao", 1, new MockMultipartFile("file", "app.apk", null, "nao-e-zip".getBytes()),
                status().isBadRequest());

        deploy(DEPLOY_TOKEN, "gestao", 1, apk("v1"), status().isCreated());
        deploy(DEPLOY_TOKEN, "gestao", 1, apk("v1"), status().isConflict());
        deploy(DEPLOY_TOKEN, "cliente", 1, apk("cliente-v1"), status().isCreated());
        deploy(DEPLOY_TOKEN, "gestao", 2, apk("v2"), status().isCreated());
        JsonNode v3 = deploy(DEPLOY_TOKEN, "gestao", 3, apk("v3"), status().isCreated());

        // JSON compacto: o workflow de release confere com grep
        String raw = mvc.perform(get("/api/app/version?app=gestao")).andExpect(status().isOk())
                .andReturn().getResponse().getContentAsString();
        assertThat(raw).contains("\"versionCode\":3");
        JsonNode version = json.readTree(raw);
        assertThat(version.get("versionName").asText()).isEqualTo("1.0.3");
        assertThat(version.get("downloadUrl").asText())
                .isEqualTo("https://salao.test/api/app/download/" + v3.get("id").asLong());
        assertThat(version.get("sha256").asText()).isEqualTo(v3.get("sha256").asText()).hasSize(64);
        assertThat(version.get("forceUpdate").asBoolean()).isFalse();

        mvc.perform(get("/api/app/download/latest?app=gestao"))
                .andExpect(status().isOk())
                .andExpect(header().string("Content-Type", "application/vnd.android.package-archive"))
                .andExpect(content().bytes(apk("v3").getBytes()));
        mvc.perform(get("/api/app/download/latest?app=cliente"))
                .andExpect(content().bytes(apk("cliente-v1").getBytes()));

        // só as 2 últimas de cada app ficam
        String admin = login(ADMIN_EMAIL, ADMIN_PASSWORD);
        JsonNode gestao = call(admin, get("/api/platform/releases?app=gestao"), null, status().isOk());
        assertThat(gestao).extracting(r -> r.get("versionCode").asInt()).containsExactly(3, 2);
        assertThat(call(admin, get("/api/platform/releases?app=cliente"), null, status().isOk())).hasSize(1);
        assertThat(call(admin, get("/api/platform/releases"), null, status().isOk())).hasSize(3);

        // forceUpdate pelo painel
        call(admin, put("/api/platform/releases/" + v3.get("id").asLong() + "/force-update"),
                Map.of("forceUpdate", true), status().isOk());
        assertThat(call(null, get("/api/app/version?app=gestao"), null, status().isOk())
                .get("forceUpdate").asBoolean()).isTrue();
        // e a próxima versão herda a obrigatoriedade
        MockMultipartHttpServletRequestBuilder upload = multipart("/api/platform/releases").file(apk("v4"));
        upload.param("app", "gestao").param("versionName", "1.0.4").param("versionCode", "4");
        call(admin, upload, null, status().isCreated());
        JsonNode latest = call(null, get("/api/app/version?app=gestao"), null, status().isOk());
        assertThat(latest.get("versionCode").asInt()).isEqualTo(4);
        assertThat(latest.get("forceUpdate").asBoolean()).isTrue();
        mvc.perform(get("/api/app/download/" + v3.get("id").asLong()))
                .andExpect(content().bytes(apk("v3").getBytes()));

        // salão não publica APK
        Salon salon = register();
        call(salon.token, get("/api/platform/releases"), null, status().isForbidden());
    }

    // ---------------- helpers ----------------

    private record Salon(long id, String slug, String token) {
    }

    private Salon register() throws Exception {
        String slug = "salao-" + UUID.randomUUID().toString().substring(0, 8);
        JsonNode res = call(null, post("/api/auth/register"), Map.of("salonName", "Salão Teste", "slug", slug,
                "ownerName", "Dona", "email", slug + "@teste.com", "password", "123456"), status().isCreated());
        return new Salon(res.at("/user/salonId").asLong(), slug, res.get("token").asText());
    }

    private String login(String email, String password) throws Exception {
        return call(null, post("/api/auth/login"), Map.of("email", email, "password", password), status().isOk())
                .get("token").asText();
    }

    private static MockMultipartFile apk(String content) {
        return new MockMultipartFile("file", "app-direct-release.apk", "application/vnd.android.package-archive",
                ("PK" + content).getBytes(StandardCharsets.UTF_8));
    }

    private JsonNode deploy(String token, String app, int code, MockMultipartFile file, ResultMatcher expected)
            throws Exception {
        MockMultipartHttpServletRequestBuilder req = multipart("/api/app/releases/deploy").file(file);
        req.param("app", app).param("versionName", "1.0." + code).param("versionCode", String.valueOf(code))
                .param("releaseNotes", "Notas " + code);
        if (token != null) {
            req.header("X-Deploy-Token", token);
        }
        return call(null, req, null, expected);
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
