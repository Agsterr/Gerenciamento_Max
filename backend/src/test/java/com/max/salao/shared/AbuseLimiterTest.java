package com.max.salao.shared;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;

import java.time.Clock;
import java.time.Duration;
import java.time.Instant;
import java.time.ZoneOffset;

import org.junit.jupiter.api.Test;
import org.springframework.http.HttpStatus;
import org.springframework.web.server.ResponseStatusException;

class AbuseLimiterTest {

    static final class MutableClock extends Clock {
        Instant now = Instant.parse("2026-11-05T12:00:00Z");

        @Override
        public java.time.ZoneId getZone() {
            return ZoneOffset.UTC;
        }

        @Override
        public Clock withZone(java.time.ZoneId zone) {
            return this;
        }

        @Override
        public Instant instant() {
            return now;
        }
    }

    @Test
    void bloqueiaDepoisDoMaximoEPermiteDeNovoDepoisDaJanela() {
        var clock = new MutableClock();
        var limiter = new AbuseLimiter(clock, true);
        var window = Duration.ofMinutes(10);

        for (int i = 0; i < 3; i++) {
            limiter.check("login-ip:1.2.3.4", 3, window);
        }
        assertThatThrownBy(() -> limiter.check("login-ip:1.2.3.4", 3, window))
                .isInstanceOfSatisfying(ResponseStatusException.class,
                        e -> assertThat(e.getStatusCode()).isEqualTo(HttpStatus.TOO_MANY_REQUESTS));

        clock.now = clock.now.plus(Duration.ofMinutes(11));
        limiter.check("login-ip:1.2.3.4", 3, window);
    }

    @Test
    void chavesDiferentesNaoSeAfetam() {
        var limiter = new AbuseLimiter(new MutableClock(), true);
        var window = Duration.ofMinutes(10);

        limiter.check("book-ip:1.1.1.1", 1, window);
        limiter.check("book-ip:2.2.2.2", 1, window);
        assertThatThrownBy(() -> limiter.check("book-ip:1.1.1.1", 1, window))
                .isInstanceOf(ResponseStatusException.class);
    }

    @Test
    void desligadoNaoLimitaNada() {
        var limiter = new AbuseLimiter(new MutableClock(), false);
        for (int i = 0; i < 100; i++) {
            limiter.check("register-ip:1.1.1.1", 1, Duration.ofHours(1));
        }
    }
}
