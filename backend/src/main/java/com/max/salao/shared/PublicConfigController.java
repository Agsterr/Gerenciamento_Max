package com.max.salao.shared;

import java.util.Map;

import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RestController;

/** Configuração pública que o site precisa conhecer em tempo de execução (hoje, a chave do captcha). */
@RestController
public class PublicConfigController {

    private final TurnstileVerifier turnstile;

    public PublicConfigController(TurnstileVerifier turnstile) {
        this.turnstile = turnstile;
    }

    @GetMapping("/api/public/config")
    public Map<String, String> config() {
        return Map.of("turnstileSiteKey", turnstile.siteKey());
    }
}
