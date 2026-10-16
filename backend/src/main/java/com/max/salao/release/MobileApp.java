package com.max.salao.release;

import java.util.Arrays;

import org.springframework.http.HttpStatus;
import org.springframework.web.server.ResponseStatusException;

/** Apps distribuídos fora da loja. O id é o valor do parâmetro {@code app} e da coluna {@code app_release.app}. */
public enum MobileApp {
    /** App do salão (dono e equipe). */
    GESTAO("gestao"),
    /** App dos clientes. */
    CLIENTE("cliente");

    private final String id;

    MobileApp(String id) {
        this.id = id;
    }

    public String id() {
        return id;
    }

    public static MobileApp parse(String raw) {
        String value = raw == null ? "" : raw.trim().toLowerCase();
        return Arrays.stream(values())
                .filter(a -> a.id.equals(value))
                .findFirst()
                .orElseThrow(() -> new ResponseStatusException(HttpStatus.BAD_REQUEST,
                        "app inválido: use gestao ou cliente"));
    }
}
