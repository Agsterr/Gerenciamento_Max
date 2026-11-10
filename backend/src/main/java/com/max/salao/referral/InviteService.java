package com.max.salao.referral;

import java.sql.Timestamp;
import java.time.Clock;
import java.time.LocalDateTime;
import java.util.List;
import java.util.Locale;

import com.max.salao.shared.BusinessException;
import com.max.salao.shared.NotFoundException;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

/**
 * Convite de um representante para um salão que já existe. O salão aceita ou recusa. Se o salão já foi indicado por outro
 * representante, o convite fica aceito mas em espera e sem comissão: só vale se o salão parar de pagar e voltar a assinar
 * (ver {@link ReferralService#recordPayment}). Sem representante, o convite aceito vale na hora.
 */
@Service
public class InviteService {

    /** Convite como o representante vê. */
    public record RepInvite(Long id, String salonName, String status, boolean blockedByOther, String message,
                            LocalDateTime createdAt) {
    }

    /** Convite como o salão vê. */
    public record SalonInvite(Long id, String representativeName, String status, boolean replacesCurrent, LocalDateTime createdAt) {
    }

    private final JdbcTemplate jdbc;
    private final Clock clock;

    public InviteService(JdbcTemplate jdbc, Clock clock) {
        this.jdbc = jdbc;
        this.clock = clock;
    }

    /** Aceita o link da página de agendamento ({@code .../s/slug}), só o {@code slug} ou o e-mail do dono. */
    @Transactional
    public RepInvite invite(long repId, String target) {
        String t = target == null ? "" : target.trim();
        if (t.isEmpty()) {
            throw new BusinessException("Informe o link do salão ou o e-mail do dono.");
        }
        Long salonId = resolve(t);
        if (salonId == null) {
            throw new NotFoundException("Não encontramos esse salão. Confira o link de agendamento ou o e-mail do dono.");
        }
        Long current = jdbc.queryForObject("select referrer_id from salon where id = ?", Long.class, salonId);
        if (current != null && current == repId) {
            throw new BusinessException("Esta cabeleireira já é sua.");
        }
        Integer open = jdbc.queryForObject("select count(*) from representative_invite where representative_id = ? and salon_id = ? and status in ('PENDING','WAITING')",
                Integer.class, repId, salonId);
        if (open != null && open > 0) {
            throw new BusinessException("Você já convidou este salão. Aguarde ela aceitar.");
        }
        jdbc.update("insert into representative_invite (representative_id, salon_id) values (?, ?)", repId, salonId);
        return list(repId).stream().filter(i -> i.status().equals("PENDING")).findFirst().orElseThrow();
    }

    @Transactional(readOnly = true)
    public List<RepInvite> list(long repId) {
        return jdbc.query("select i.id, i.status, i.created_at, s.name, s.referrer_id from representative_invite i join salon s on s.id = i.salon_id "
                + "where i.representative_id = ? and i.status <> 'CANCELED' order by i.created_at desc, i.id desc", (rs, n) -> {
            Long referrer = (Long) rs.getObject("referrer_id");
            boolean blocked = referrer != null && referrer != repId;
            String status = rs.getString("status");
            return new RepInvite(rs.getLong("id"), rs.getString("name"), status, blocked && !status.equals("ACTIVE"),
                    message(status, blocked), rs.getTimestamp("created_at").toLocalDateTime());
        }, repId);
    }

    private static String message(String status, boolean blocked) {
        return switch (status) {
            case "PENDING" -> blocked
                    ? "Esta cabeleireira já foi indicada por outro fornecedor. Seu convite fica pendente e você não ganha comissão por ela."
                    : "Aguardando a cabeleireira aceitar.";
            case "WAITING" -> "Aceito pela cabeleireira. Você só passa a ganhar a comissão se ela parar de pagar e voltar a assinar.";
            case "ACTIVE" -> "Você é o representante dela.";
            case "DECLINED" -> "A cabeleireira recusou o convite.";
            case "REPLACED" -> "Outro fornecedor ficou com essa cabeleireira.";
            default -> "";
        };
    }

    @Transactional
    public void cancel(long repId, long inviteId) {
        int n = jdbc.update("update representative_invite set status = 'CANCELED', responded_at = ? where id = ? and representative_id = ? and status in ('PENDING','WAITING')",
                Timestamp.valueOf(LocalDateTime.now(clock)), inviteId, repId);
        if (n == 0) {
            throw new NotFoundException("Convite não encontrado");
        }
    }

    // ---- lado do salão ----

    @Transactional(readOnly = true)
    public List<SalonInvite> forSalon(long salonId) {
        Long current = jdbc.queryForObject("select referrer_id from salon where id = ?", Long.class, salonId);
        return jdbc.query("select i.id, i.status, i.created_at, i.representative_id, u.name from representative_invite i "
                + "join representative r on r.id = i.representative_id join app_user u on u.id = r.user_id "
                + "where i.salon_id = ? and i.status in ('PENDING','WAITING') order by i.created_at desc",
                (rs, n) -> new SalonInvite(rs.getLong("id"), rs.getString("name"), rs.getString("status"),
                        current != null && current != rs.getLong("representative_id"), rs.getTimestamp("created_at").toLocalDateTime()), salonId);
    }

    @Transactional
    public SalonInvite accept(long salonId, long inviteId) {
        List<Object[]> rows = jdbc.query("select representative_id from representative_invite where id = ? and salon_id = ? and status = 'PENDING'",
                (rs, n) -> new Object[] {rs.getLong(1)}, inviteId, salonId);
        if (rows.isEmpty()) {
            throw new NotFoundException("Convite não encontrado");
        }
        long repId = (Long) rows.get(0)[0];
        Long current = jdbc.queryForObject("select referrer_id from salon where id = ?", Long.class, salonId);
        Timestamp now = Timestamp.valueOf(LocalDateTime.now(clock));
        if (current == null) {
            jdbc.update("update salon set referrer_id = ? where id = ?", repId, salonId);
            jdbc.update("update representative_invite set status = 'ACTIVE', responded_at = ? where id = ?", now, inviteId);
        } else {
            // outro representante é o titular: fica em espera, sem comissão
            jdbc.update("update representative_invite set status = 'WAITING', responded_at = ? where id = ?", now, inviteId);
        }
        return forSalonAny(salonId, inviteId);
    }

    @Transactional
    public void decline(long salonId, long inviteId) {
        int n = jdbc.update("update representative_invite set status = 'DECLINED', responded_at = ? where id = ? and salon_id = ? and status = 'PENDING'",
                Timestamp.valueOf(LocalDateTime.now(clock)), inviteId, salonId);
        if (n == 0) {
            throw new NotFoundException("Convite não encontrado");
        }
    }

    private SalonInvite forSalonAny(long salonId, long inviteId) {
        return jdbc.query("select i.id, i.status, i.created_at, u.name from representative_invite i join representative r on r.id = i.representative_id "
                + "join app_user u on u.id = r.user_id where i.id = ? and i.salon_id = ?",
                (rs, n) -> new SalonInvite(rs.getLong("id"), rs.getString("name"), rs.getString("status"), false, rs.getTimestamp("created_at").toLocalDateTime()),
                inviteId, salonId).get(0);
    }

    /**
     * O salão voltou a pagar depois de parar: o convite aceito mais recente passa a ser o titular (e ganha a comissão
     * deste pagamento). Os outros convites em espera e o do titular anterior são encerrados.
     *
     * @return o novo representante titular, ou {@code null} se não havia convite em espera
     */
    @Transactional
    public Long claimWaiting(long salonId) {
        List<Long> waiting = jdbc.queryForList("select representative_id from representative_invite where salon_id = ? and status = 'WAITING' "
                + "order by responded_at desc, id desc limit 1", Long.class, salonId);
        if (waiting.isEmpty()) {
            return null;
        }
        long repId = waiting.get(0);
        Timestamp now = Timestamp.valueOf(LocalDateTime.now(clock));
        jdbc.update("update representative_invite set status = 'ACTIVE', responded_at = ? where salon_id = ? and representative_id = ? and status = 'WAITING'", now, salonId, repId);
        jdbc.update("update representative_invite set status = 'REPLACED', responded_at = ? where salon_id = ? and representative_id <> ? and status in ('WAITING','ACTIVE','PENDING')", now, salonId, repId);
        jdbc.update("update salon set referrer_id = ? where id = ?", repId, salonId);
        return repId;
    }

    private Long resolve(String target) {
        String t = target.trim();
        String lower = t.toLowerCase(Locale.ROOT);
        int at = lower.indexOf("/s/");
        String slug = null;
        if (at >= 0) {
            slug = lower.substring(at + 3).split("[/?#\\s]")[0];
        } else if (lower.contains("@")) {
            List<Long> l = jdbc.queryForList("select salon_id from app_user where lower(email) = ? and role = 'OWNER' and salon_id is not null", Long.class, lower);
            return l.isEmpty() ? null : l.get(0);
        } else {
            slug = lower.replaceAll("^/+|/+$", "");
        }
        List<Long> l = jdbc.queryForList("select id from salon where slug = ?", Long.class, slug);
        return l.isEmpty() ? null : l.get(0);
    }
}
