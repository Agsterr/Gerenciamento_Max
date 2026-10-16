package com.max.salao.security;

import java.io.IOException;

import com.fasterxml.jackson.databind.ObjectMapper;
import com.max.salao.shared.AccountBlockedException;
import jakarta.servlet.FilterChain;
import jakarta.servlet.ServletException;
import jakarta.servlet.http.HttpServletRequest;
import jakarta.servlet.http.HttpServletResponse;
import org.springframework.http.HttpStatus;
import org.springframework.http.MediaType;
import org.springframework.http.ProblemDetail;
import org.springframework.security.core.context.SecurityContextHolder;
import org.springframework.security.oauth2.server.resource.authentication.JwtAuthenticationToken;
import org.springframework.web.filter.OncePerRequestFilter;

/**
 * Barra tokens de usuários bloqueados (ou de salões bloqueados) e de contas que não existem mais,
 * mesmo que o JWT ainda esteja válido. Rotas públicas passam direto.
 */
class AccountStatusFilter extends OncePerRequestFilter {

    private final AccountStatusService statuses;
    private final ObjectMapper json;

    AccountStatusFilter(AccountStatusService statuses, ObjectMapper json) {
        this.statuses = statuses;
        this.json = json;
    }

    @Override
    protected boolean shouldNotFilter(HttpServletRequest request) {
        String path = request.getRequestURI().substring(request.getContextPath().length());
        return path.startsWith("/api/auth/") || path.startsWith("/api/public/") || path.startsWith("/api/app/");
    }

    @Override
    protected void doFilterInternal(HttpServletRequest request, HttpServletResponse response, FilterChain chain)
            throws ServletException, IOException {
        if (SecurityContextHolder.getContext().getAuthentication() instanceof JwtAuthenticationToken token) {
            AccountStatusService.Status status = statuses.of(Long.valueOf(token.getToken().getSubject()));
            if (!status.exists()) {
                write(response, ProblemDetail.forStatusAndDetail(HttpStatus.UNAUTHORIZED, "Sessão inválida. Entre novamente."));
                return;
            }
            if (status.blocked()) {
                write(response, new AccountBlockedException(status.blockedReason()).toProblem());
                return;
            }
        }
        chain.doFilter(request, response);
    }

    private void write(HttpServletResponse response, ProblemDetail problem) throws IOException {
        SecurityContextHolder.clearContext();
        response.setStatus(problem.getStatus());
        response.setContentType(MediaType.APPLICATION_PROBLEM_JSON_VALUE);
        response.setCharacterEncoding("UTF-8");
        json.writeValue(response.getOutputStream(), problem);
    }
}
