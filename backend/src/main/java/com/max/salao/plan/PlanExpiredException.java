package com.max.salao.plan;

import org.springframework.http.HttpStatus;
import org.springframework.http.ProblemDetail;

/** Teste grátis (ou plano) vencido: o salão só consulta, não cria nem altera. HTTP 402, code PLAN_EXPIRED. */
public class PlanExpiredException extends RuntimeException {

    public static final String CODE = "PLAN_EXPIRED";

    public PlanExpiredException(String message) {
        super(message);
    }

    public ProblemDetail toProblem() {
        ProblemDetail problem = ProblemDetail.forStatusAndDetail(HttpStatus.PAYMENT_REQUIRED, getMessage());
        problem.setTitle("Plano vencido");
        problem.setProperty("code", CODE);
        return problem;
    }
}
