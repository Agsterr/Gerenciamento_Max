package com.max.salao.shared;

import java.time.Clock;
import java.time.Duration;
import java.time.Instant;
import java.util.ArrayDeque;
import java.util.Deque;
import java.util.Map;
import java.util.concurrent.ConcurrentHashMap;

import org.springframework.beans.factory.annotation.Value;
import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Component;
import org.springframework.web.server.ResponseStatusException;

/**
 * Limita quantas vezes uma origem (IP, e-mail, telefone) pode repetir uma ação pública: login, cadastro de salão
 * e criação de agendamento. Cada chamada informa o próprio máximo e a janela.
 * Em memória: simples e suficiente para uma única instância da API.
 */
@Component
public class AbuseLimiter {

    private static final Duration KEEP = Duration.ofHours(2);

    private final Map<String, Deque<Instant>> attempts = new ConcurrentHashMap<>();
    private final Clock clock;
    private final boolean enabled;

    public AbuseLimiter(Clock clock, @Value("${app.rate-limit.enabled:true}") boolean enabled) {
        this.clock = clock;
        this.enabled = enabled;
    }

    /** Conta a tentativa em {@code key}; passando de {@code max} dentro de {@code window}, responde 429. */
    public void check(String key, int max, Duration window) {
        if (!enabled) {
            return;
        }
        Instant now = clock.instant();
        Deque<Instant> list = attempts.computeIfAbsent(key, k -> new ArrayDeque<>());
        synchronized (list) {
            while (!list.isEmpty() && list.peekFirst().isBefore(now.minus(window))) {
                list.pollFirst();
            }
            if (list.size() >= max) {
                throw new ResponseStatusException(HttpStatus.TOO_MANY_REQUESTS,
                        "Muitas tentativas. Aguarde alguns minutos e tente de novo.");
            }
            list.addLast(now);
        }
        if (attempts.size() > 10_000) {
            attempts.entrySet().removeIf(e -> {
                synchronized (e.getValue()) {
                    return e.getValue().isEmpty() || e.getValue().peekLast().isBefore(now.minus(KEEP));
                }
            });
        }
    }
}
