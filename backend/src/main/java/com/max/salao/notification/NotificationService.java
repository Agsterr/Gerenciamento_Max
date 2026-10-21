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

    private final NotificationRepository repository;
    private final Clock clock;

    public NotificationService(NotificationRepository repository, Clock clock) {
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
}
