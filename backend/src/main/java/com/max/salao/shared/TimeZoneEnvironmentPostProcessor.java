package com.max.salao.shared;

import java.util.TimeZone;

import org.springframework.boot.SpringApplication;
import org.springframework.boot.env.EnvironmentPostProcessor;
import org.springframework.core.env.ConfigurableEnvironment;

/**
 * Faz a aplicação inteira rodar no fuso do salão ({@code app.timezone}, ex.: America/Sao_Paulo),
 * antes de abrir qualquer conexão com o banco.
 *
 * <p>Assim {@code LocalDateTime.now()}, o {@code now()} do PostgreSQL e o que é gravado nas colunas
 * {@code timestamp}/{@code time} são sempre a hora local do salão, sem conversões. O servidor pode estar
 * em UTC (padrão dos contêineres) sem afetar nada.
 */
public class TimeZoneEnvironmentPostProcessor implements EnvironmentPostProcessor {

    @Override
    public void postProcessEnvironment(ConfigurableEnvironment environment, SpringApplication application) {
        String zone = environment.getProperty("app.timezone", "America/Sao_Paulo");
        TimeZone.setDefault(TimeZone.getTimeZone(zone));
    }
}
