package com.max.salao.shared;

import java.io.IOException;
import java.net.URI;
import java.net.URLEncoder;
import java.net.http.HttpClient;
import java.net.http.HttpRequest;
import java.net.http.HttpResponse;
import java.nio.charset.StandardCharsets;
import java.time.Duration;

import com.fasterxml.jackson.databind.ObjectMapper;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.stereotype.Component;

/**
 * Captcha do Cloudflare Turnstile para os cadastros públicos (salão e representante).
 * Sem TURNSTILE_SECRET e TURNSTILE_SITE_KEY o captcha fica desligado e nada muda.
 */
@Component
public class TurnstileVerifier {

    private static final Logger log = LoggerFactory.getLogger(TurnstileVerifier.class);
    private static final String VERIFY_URL = "https://challenges.cloudflare.com/turnstile/v0/siteverify";

    private final String secret;
    private final String siteKey;
    private final ObjectMapper json;
    private final HttpClient http = HttpClient.newBuilder().connectTimeout(Duration.ofSeconds(5)).build();

    public TurnstileVerifier(@Value("${app.turnstile.secret:}") String secret,
                             @Value("${app.turnstile.site-key:}") String siteKey, ObjectMapper json) {
        this.secret = secret == null ? "" : secret.trim();
        this.siteKey = siteKey == null ? "" : siteKey.trim();
        this.json = json;
    }

    public boolean enabled() {
        return !secret.isBlank() && !siteKey.isBlank();
    }

    /** Chave pública que o site usa para mostrar o captcha; vazia quando está desligado. */
    public String siteKey() {
        return enabled() ? siteKey : "";
    }

    /** Desligado: não faz nada. Ligado: exige o token do captcha e confirma com a Cloudflare. */
    public void verify(String token, String ip) {
        if (!enabled()) {
            return;
        }
        if (token == null || token.isBlank()) {
            throw new BusinessException("Confirme que você não é um robô e tente de novo.");
        }
        try {
            StringBuilder form = new StringBuilder("secret=").append(enc(secret)).append("&response=").append(enc(token));
            if (ip != null && !ip.isBlank()) {
                form.append("&remoteip=").append(enc(ip));
            }
            HttpRequest req = HttpRequest.newBuilder(URI.create(VERIFY_URL)).timeout(Duration.ofSeconds(10))
                    .header("Content-Type", "application/x-www-form-urlencoded")
                    .POST(HttpRequest.BodyPublishers.ofString(form.toString())).build();
            HttpResponse<String> res = http.send(req, HttpResponse.BodyHandlers.ofString());
            if (res.statusCode() / 100 != 2) {
                log.warn("Turnstile respondeu {}", res.statusCode());
                throw new BusinessException("Não foi possível confirmar a segurança agora. Tente de novo em instantes.");
            }
            if (!json.readTree(res.body()).path("success").asBoolean(false)) {
                throw new BusinessException("Confirmação de segurança inválida. Recarregue a página e tente de novo.");
            }
        } catch (IOException e) {
            log.warn("Falha ao falar com o Turnstile: {}", e.getMessage());
            throw new BusinessException("Não foi possível confirmar a segurança agora. Tente de novo em instantes.");
        } catch (InterruptedException e) {
            Thread.currentThread().interrupt();
            throw new BusinessException("Não foi possível confirmar a segurança agora. Tente de novo em instantes.");
        }
    }

    private static String enc(String value) {
        return URLEncoder.encode(value, StandardCharsets.UTF_8);
    }
}
