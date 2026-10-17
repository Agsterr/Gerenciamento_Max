package com.max.salao.booking;

import java.time.Clock;
import java.time.Duration;
import java.time.Instant;
import java.util.ArrayDeque;
import java.util.Deque;
import java.util.Map;
import java.util.concurrent.ConcurrentHashMap;

import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Component;
import org.springframework.web.server.ResponseStatusException;

/**
 * Limita as consultas "meus agendamentos" por origem (IP), para ninguém testar telefones em massa.
 * Em memória: simples e suficiente para uma única instância da API.
 */
@Component
public class LookupRateLimiter {

    static final int MAX_ATTEMPTS = 10;
    static final Duration WINDOW = Duration.ofMinutes(10);

    private final Map<String, Deque<Instant>> attempts = new ConcurrentHashMap<>();
    private final Clock clock;

    public LookupRateLimiter(Clock clock) {
        this.clock = clock;
    }

    public void check(String key) {
        Instant now = clock.instant();
        Deque<Instant> list = attempts.computeIfAbsent(key, k -> new ArrayDeque<>());
        synchronized (list) {
            while (!list.isEmpty() && list.peekFirst().isBefore(now.minus(WINDOW))) {
                list.pollFirst();
            }
            if (list.size() >= MAX_ATTEMPTS) {
                throw new ResponseStatusException(HttpStatus.TOO_MANY_REQUESTS,
                        "Muitas tentativas. Aguarde alguns minutos e tente de novo.");
            }
            list.addLast(now);
        }
        if (attempts.size() > 10_000) {
            attempts.entrySet().removeIf(e -> e.getValue().isEmpty());
        }
    }
}
