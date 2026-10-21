package com.max.salao.shared;

import java.time.Clock;
import java.time.Instant;
import java.time.ZoneId;

import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;

@Configuration
public class ClockConfig {

    /**
     * Relógio que acompanha o fuso do salão da requisição: {@code LocalDateTime.now(clock)} devolve a hora
     * local do salão (Manaus, Acre...). Fora de um salão usa o fuso padrão.
     */
    @Bean
    Clock clock(SalonZones zones) {
        return new SalonClock(zones);
    }

    static final class SalonClock extends Clock {

        private final SalonZones zones;

        SalonClock(SalonZones zones) {
            this.zones = zones;
        }

        @Override
        public ZoneId getZone() {
            return zones.current();
        }

        @Override
        public Clock withZone(ZoneId zone) {
            return Clock.system(zone);
        }

        @Override
        public Instant instant() {
            return Instant.now();
        }
    }
}
