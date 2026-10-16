package com.max.salao.shared;

import java.time.Clock;
import java.time.ZoneId;

import org.springframework.beans.factory.annotation.Value;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;

@Configuration
public class ClockConfig {

    /** Horários são guardados no fuso local do salão (ex.: America/Sao_Paulo). */
    @Bean
    Clock clock(@Value("${app.timezone}") String zone) {
        return Clock.system(ZoneId.of(zone));
    }
}
