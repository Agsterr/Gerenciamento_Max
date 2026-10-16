package com.max.salao.security;

import java.time.Duration;
import java.util.List;
import java.util.Map;
import java.util.concurrent.ConcurrentHashMap;

import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.stereotype.Service;
import org.springframework.transaction.support.TransactionSynchronization;
import org.springframework.transaction.support.TransactionSynchronizationManager;

/**
 * Estado atual (ativo/bloqueado) do usuário e do salão, consultado a cada requisição autenticada
 * para que bloqueios valham também para tokens JWT já emitidos. Cache curto em memória; bloquear
 * ou desbloquear limpa o cache na hora.
 */
@Service
public class AccountStatusService {

    /** {@code blockedReason} só faz sentido quando {@code blocked}. */
    public record Status(boolean exists, boolean blocked, String blockedReason) {

        static final Status MISSING = new Status(false, false, null);
        static final Status OK = new Status(true, false, null);
    }

    private record Cached(Status status, long expiresAt) {
    }

    private static final Duration TTL = Duration.ofSeconds(10);
    private static final int MAX_ENTRIES = 5_000;

    private final JdbcTemplate jdbc;
    private final Map<Long, Cached> cache = new ConcurrentHashMap<>();

    public AccountStatusService(JdbcTemplate jdbc) {
        this.jdbc = jdbc;
    }

    public Status of(Long userId) {
        long now = System.currentTimeMillis();
        Cached cached = cache.get(userId);
        if (cached != null && cached.expiresAt > now) {
            return cached.status;
        }
        Status status = load(userId);
        if (cache.size() >= MAX_ENTRIES) {
            cache.clear();
        }
        cache.put(userId, new Cached(status, now + TTL.toMillis()));
        return status;
    }

    /** Limpa agora e de novo após o commit, para não recachear o estado antigo nesse intervalo. */
    public void evictAll() {
        cache.clear();
        if (TransactionSynchronizationManager.isSynchronizationActive()) {
            TransactionSynchronizationManager.registerSynchronization(new TransactionSynchronization() {
                @Override
                public void afterCommit() {
                    cache.clear();
                }
            });
        }
    }

    private Status load(Long userId) {
        List<Status> rows = jdbc.query("""
                SELECT u.active, u.blocked, u.blocked_reason, s.blocked AS salon_blocked, s.blocked_reason AS salon_reason
                FROM app_user u LEFT JOIN salon s ON s.id = u.salon_id
                WHERE u.id = ?""", (rs, i) -> {
            if (!rs.getBoolean("active")) {
                return Status.MISSING;
            }
            if (rs.getBoolean("blocked")) {
                return new Status(true, true, rs.getString("blocked_reason"));
            }
            if (rs.getBoolean("salon_blocked")) {
                return new Status(true, true, rs.getString("salon_reason"));
            }
            return Status.OK;
        }, userId);
        return rows.isEmpty() ? Status.MISSING : rows.get(0);
    }
}
