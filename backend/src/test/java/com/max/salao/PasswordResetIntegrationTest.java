package com.max.salao;

import static org.assertj.core.api.Assertions.assertThat;
import static org.mockito.ArgumentMatchers.anyString;
import static org.mockito.ArgumentMatchers.eq;
import static org.mockito.Mockito.never;
import static org.mockito.Mockito.verify;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

import java.util.Map;
import java.util.UUID;
import java.util.regex.Matcher;
import java.util.regex.Pattern;

import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.databind.ObjectMapper;
import com.max.salao.mail.MailSender;
import org.junit.jupiter.api.Test;
import org.mockito.ArgumentCaptor;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.autoconfigure.web.servlet.AutoConfigureMockMvc;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.http.MediaType;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.test.context.bean.override.mockito.MockitoBean;
import org.springframework.test.web.servlet.MockMvc;
import org.springframework.test.web.servlet.ResultMatcher;

@SpringBootTest(properties = "spring.datasource.url=${TEST_DB_URL:jdbc:postgresql://localhost:5432/salao_test}")
@AutoConfigureMockMvc
class PasswordResetIntegrationTest {

    @Autowired
    MockMvc mvc;

    @Autowired
    ObjectMapper json;

    @Autowired
    JdbcTemplate jdbc;

    @MockitoBean
    MailSender mail;

    @Test
    void forgotPasswordSendsOneUseLinkAndResetChangesThePassword() throws Exception {
        String email = register();

        call(post("/api/auth/forgot-password"), Map.of("email", email.toUpperCase()), status().isNoContent());
        String token = lastToken(email);

        // o link só funciona uma vez, e a senha antiga deixa de valer
        call(post("/api/auth/reset-password"), Map.of("token", token, "password", "novaSenha1"), status().isNoContent());
        call(post("/api/auth/login"), Map.of("email", email, "password", "novaSenha1"), status().isOk());
        call(post("/api/auth/login"), Map.of("email", email, "password", "123456"), status().isUnauthorized());
        call(post("/api/auth/reset-password"), Map.of("token", token, "password", "outraSenha2"), status().isUnprocessableEntity());
    }

    @Test
    void unknownEmailGetsTheSameAnswerAndNoMail() throws Exception {
        call(post("/api/auth/forgot-password"), Map.of("email", "ninguem-" + UUID.randomUUID() + "@teste.com"),
                status().isNoContent());
        verify(mail, never()).send(anyString(), anyString(), anyString(), anyString());
    }

    @Test
    void invalidOrExpiredLinksAreRejected() throws Exception {
        call(post("/api/auth/reset-password"), Map.of("token", "inventado", "password", "novaSenha1"),
                status().isUnprocessableEntity());

        String email = register();
        call(post("/api/auth/forgot-password"), Map.of("email", email), status().isNoContent());
        String token = lastToken(email);
        jdbc.update("update password_reset set expires_at = now() - interval '1 minute'");
        call(post("/api/auth/reset-password"), Map.of("token", token, "password", "novaSenha1"),
                status().isUnprocessableEntity());
        // nada mudou: a senha original continua valendo
        call(post("/api/auth/login"), Map.of("email", email, "password", "123456"), status().isOk());
    }

    @Test
    void newRequestInvalidatesThePreviousLink() throws Exception {
        String email = register();
        call(post("/api/auth/forgot-password"), Map.of("email", email), status().isNoContent());
        String first = lastToken(email);
        call(post("/api/auth/forgot-password"), Map.of("email", email), status().isNoContent());
        call(post("/api/auth/reset-password"), Map.of("token", first, "password", "novaSenha1"),
                status().isUnprocessableEntity());
    }

    /** Token do último e-mail enviado para o endereço. */
    private String lastToken(String email) {
        ArgumentCaptor<String> text = ArgumentCaptor.forClass(String.class);
        verify(mail, org.mockito.Mockito.atLeastOnce()).send(eq(email), anyString(), anyString(), text.capture());
        Matcher m = Pattern.compile("/redefinir-senha\\?token=([A-Za-z0-9_-]+)").matcher(text.getValue());
        assertThat(m.find()).as("link no e-mail").isTrue();
        return m.group(1);
    }

    private String register() throws Exception {
        String slug = "salao-" + UUID.randomUUID().toString().substring(0, 8);
        String email = slug + "@teste.com";
        call(post("/api/auth/register"), Map.of("salonName", "Salão Teste", "slug", slug, "ownerName", "Dona Maria",
                "email", email, "password", "123456"), status().isCreated());
        return email;
    }

    private JsonNode call(org.springframework.test.web.servlet.request.MockHttpServletRequestBuilder req, Object body,
                          ResultMatcher expected) throws Exception {
        req.contentType(MediaType.APPLICATION_JSON).content(json.writeValueAsBytes(body));
        String content = mvc.perform(req).andExpect(expected).andReturn().getResponse().getContentAsString();
        return content.isEmpty() ? null : json.readTree(content);
    }
}
