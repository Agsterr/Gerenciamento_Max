package com.max.salao.shared;

import org.springframework.http.HttpStatus;
import org.springframework.http.ProblemDetail;

/**
 * Usuário ou salão bloqueado pela plataforma. Vira HTTP 403 com {@code "code": "ACCOUNT_BLOCKED"}
 * (os apps dependem exatamente desse código) e o motivo em {@code detail}.
 */
public class AccountBlockedException extends RuntimeException {

    public static final String CODE = "ACCOUNT_BLOCKED";

    private static final String DEFAULT_REASON = "Acesso bloqueado. Entre em contato com o suporte do Salão Max.";

    public AccountBlockedException(String reason) {
        super(reason == null || reason.isBlank() ? DEFAULT_REASON : reason);
    }

    public ProblemDetail toProblem() {
        ProblemDetail problem = ProblemDetail.forStatusAndDetail(HttpStatus.FORBIDDEN, getMessage());
        problem.setTitle("Conta bloqueada");
        problem.setProperty("code", CODE);
        return problem;
    }
}
