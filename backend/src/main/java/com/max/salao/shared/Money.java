package com.max.salao.shared;

import java.math.BigDecimal;
import java.text.NumberFormat;
import java.util.Locale;

/** Valor em reais para textos (notificações): "R$ 1.234,50". */
public final class Money {

    private Money() {
    }

    public static String format(BigDecimal value) {
        // NumberFormat usa espaço fino/não separável; troca por espaço comum
        return NumberFormat.getCurrencyInstance(Locale.of("pt", "BR")).format(value).replace(' ', ' ');
    }
}
