package com.max.salao.shared;

import java.time.ZoneId;
import java.util.LinkedHashMap;
import java.util.Map;
import java.util.concurrent.ConcurrentHashMap;

import org.springframework.beans.factory.annotation.Value;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.stereotype.Component;

/**
 * Fuso de cada salão. O Brasil tem quatro fusos (sem horário de verão): Fernando de Noronha (-2),
 * Brasília (-3), Amazonas/MT/MS/RO/RR (-4) e Acre (-5). Todo horário do sistema é a hora local do salão.
 */
@Component
public class SalonZones {

    /** Fusos aceitos, com o nome mostrado ao usuário. */
    public static final Map<String, String> ALLOWED = new LinkedHashMap<>();

    static {
        ALLOWED.put("America/Sao_Paulo", "Brasília (maioria dos estados)");
        ALLOWED.put("America/Manaus", "Amazonas, Mato Grosso, Mato Grosso do Sul, Rondônia e Roraima (-1h)");
        ALLOWED.put("America/Rio_Branco", "Acre (-2h)");
        ALLOWED.put("America/Noronha", "Fernando de Noronha (+1h)");
    }

    private final ZoneId fallback;
    private final JdbcTemplate jdbc;
    private final Map<Long, ZoneId> cache = new ConcurrentHashMap<>();

    public SalonZones(@Value("${app.timezone}") String fallbackZone, JdbcTemplate jdbc) {
        this.fallback = ZoneId.of(fallbackZone);
        this.jdbc = jdbc;
    }

    public ZoneId fallback() {
        return fallback;
    }

    /** Fuso do salão da requisição atual (ou o padrão fora de uma requisição de salão, ex.: tarefas agendadas). */
    public ZoneId current() {
        Long id = TenantContext.get();
        if (TenantContext.NONE.equals(id)) {
            return fallback;
        }
        return cache.computeIfAbsent(id, this::load);
    }

    private ZoneId load(Long salonId) {
        return jdbc.query("select timezone from salon where id = ?", rs -> rs.next() ? ZoneId.of(rs.getString(1)) : fallback,
                salonId);
    }

    /** Chamado quando o salão troca de fuso. */
    public void evict(Long salonId) {
        cache.remove(salonId);
    }

    public static boolean isAllowed(String zone) {
        return zone != null && ALLOWED.containsKey(zone);
    }
}
