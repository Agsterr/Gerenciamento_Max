package com.max.salao.shared;

/** Regra de negócio violada (ex.: horário ocupado). Vira HTTP 422. */
public class BusinessException extends RuntimeException {

    public BusinessException(String message) {
        super(message);
    }
}
