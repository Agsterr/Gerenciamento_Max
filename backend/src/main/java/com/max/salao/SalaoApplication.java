package com.max.salao;

import org.springframework.boot.SpringApplication;
import org.springframework.boot.autoconfigure.SpringBootApplication;
import org.springframework.boot.context.properties.ConfigurationPropertiesScan;

@SpringBootApplication
@ConfigurationPropertiesScan
public class SalaoApplication {

    public static void main(String[] args) {
        SpringApplication.run(SalaoApplication.class, args);
    }
}
