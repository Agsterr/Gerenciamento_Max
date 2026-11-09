package com.max.salao.notification;

import java.time.Clock;
import java.time.LocalDateTime;
import java.time.format.DateTimeFormatter;
import java.util.List;
import java.util.Locale;

import com.max.salao.appointment.Appointment;
import org.springframework.data.domain.PageRequest;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

@Service
public class NotificationService {

    private static final DateTimeFormatter WHEN =
            DateTimeFormatter.ofPattern("EEE dd/MM 'às' HH:mm", Locale.forLanguageTag("pt-BR"));

    public record NotificationResponse(Long id, Notification.Type type, Long appointmentId, String title, String message,
                                       LocalDateTime createdAt, boolean read) {

        static NotificationResponse from(Notification n) {
            return new NotificationResponse(n.getId(), n.getType(), n.getAppointmentId(), n.getTitle(), n.getMessage(),
                    n.getCreatedAt(), n.getReadAt() != null);
        }
    }

    public record Inbox(long unread, List<NotificationResponse> items) {
    }

    /** Uma página do histórico (com filtros) e quantos avisos ainda não foram vistos. */
    public record History(List<NotificationResponse> items, int page, int size, long total, boolean hasMore, long unread) {
    }

    private final NotificationRepository repository;
    private final Clock clock;
    private final com.max.salao.push.PushNotifier push;

    public NotificationService(NotificationRepository repository, Clock clock, com.max.salao.push.PushNotifier push) {
        this.push = push;
        this.repository = repository;
        this.clock = clock;
    }

    /** Registra um aviso para o salão sobre algo que o cliente fez. */
    @Transactional
    public void notifySalon(Notification.Type type, Appointment a) {
        String title = switch (type) {
            case BOOKED -> "Novo agendamento online";
            case CANCELED -> "Agendamento cancelado pelo cliente";
            case RESCHEDULED -> "Cliente remarcou o horário";
            case CONFIRMED -> "Cliente confirmou presença";
            case REMINDERS, STAFF_REMINDER -> throw new IllegalArgumentException("aviso sem título fixo");
        };
        Notification n = new Notification();
        n.setType(type);
        n.setAppointmentId(a.getId());
        n.setTitle(title);
        n.setMessage(describe(a));
        n.setCreatedAt(LocalDateTime.now(clock));
        repository.save(n);
        // além do sino: notificação no celular da equipe (fila com tentativas e confirmação)
        push.toStaff(a, type.name().toLowerCase() + ":" + a.getStartAt(), title, describe(a));
    }

    /**
     * Aviso diário (job de lembretes): quantos clientes o salão tem para lembrar. Um por dia, no máximo.
     * Retorna false se o aviso de hoje já existia.
     */
    @Transactional
    public boolean notifyReminders(long count, String when) {
        LocalDateTime today = LocalDateTime.now(clock).toLocalDate().atStartOfDay();
        if (count == 0 || repository.existsByTypeAndCreatedAtGreaterThanEqual(Notification.Type.REMINDERS, today)) {
            return false;
        }
        Notification n = new Notification();
        n.setType(Notification.Type.REMINDERS);
        n.setTitle(count == 1 ? "1 cliente para lembrar" : count + " clientes para lembrar");
        n.setMessage("Horários " + when + " ainda sem confirmação. Abra Lembretes e mande a mensagem pelo WhatsApp.");
        n.setCreatedAt(LocalDateTime.now(clock));
        repository.save(n);
        return true;
    }

    /** Lembrete de atendimento para um usuário do salão; a chave impede repetir o mesmo aviso. */
    @Transactional
    public boolean notifyUser(Long userId, String dedupKey, Appointment a, String title) {
        if (repository.existsByDedupKey(dedupKey)) {
            return false;
        }
        Notification n = new Notification();
        n.setType(Notification.Type.STAFF_REMINDER);
        n.setUserId(userId);
        n.setDedupKey(dedupKey);
        n.setAppointmentId(a.getId());
        n.setTitle(title);
        n.setMessage(describe(a));
        n.setCreatedAt(LocalDateTime.now(clock));
        repository.save(n);
        return true;
    }

    public static String describe(Appointment a) {
        return "%s · %s · %s com %s".formatted(a.getCustomer().getName(), a.getService().getName(),
                WHEN.format(a.getStartAt()), a.getProfessional().getName());
    }

    @Transactional(readOnly = true)
    public Inbox inbox(Long userId) {
        return new Inbox(repository.countUnread(userId),
                repository.findVisible(userId, PageRequest.of(0, 50)).stream().map(NotificationResponse::from).toList());
    }

    @Transactional
    public void markAllRead(Long userId) {
        repository.markAllRead(userId, LocalDateTime.now(clock));
    }

    /**
     * Histórico para a tela de avisos: filtro por situação (todos, não lidos, lidos) e por período (datas inclusive).
     * Sem datas, traz tudo o que ainda não foi limpo.
     */
    @Transactional(readOnly = true)
    public History history(Long userId, String status, java.time.LocalDate from, java.time.LocalDate to, Integer page, Integer size) {
        String st = switch (status == null ? "all" : status) {
            case "unread", "read" -> status;
            default -> "all";
        };
        LocalDateTime start = from == null ? LocalDateTime.of(2000, 1, 1, 0, 0) : from.atStartOfDay();
        LocalDateTime end = to == null ? LocalDateTime.of(2999, 1, 1, 0, 0) : to.plusDays(1).atStartOfDay();
        var result = repository.history(userId, st, start, end, com.max.salao.shared.PageResponse.request(page, size));
        return new History(result.getContent().stream().map(NotificationResponse::from).toList(), result.getNumber(),
                result.getSize(), result.getTotalElements(), result.hasNext(), repository.countUnread(userId));
    }

    /** Apaga um aviso já lido. Falha se ainda não foi lido ou se não existe. */
    @Transactional
    public void deleteRead(Long userId, Long id) {
        if (repository.deleteReadById(userId, id) == 0) {
            throw new com.max.salao.shared.BusinessException("Só é possível apagar avisos que já foram lidos.");
        }
    }

    /** Apaga os avisos lidos (todos, ou só os anteriores a uma data). Retorna quantos foram apagados. */
    @Transactional
    public int clearRead(Long userId, java.time.LocalDate before) {
        LocalDateTime limit = before == null ? LocalDateTime.now(clock).plusDays(1) : before.atStartOfDay();
        return repository.deleteReadBefore(userId, limit);
    }
}
