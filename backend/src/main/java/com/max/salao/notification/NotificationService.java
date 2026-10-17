package com.max.salao.notification;

import java.time.Clock;
import java.time.LocalDateTime;
import java.time.format.DateTimeFormatter;
import java.util.List;
import java.util.Locale;

import com.max.salao.appointment.Appointment;
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
        };
        Notification n = new Notification();
        n.setType(type);
        n.setAppointmentId(a.getId());
        n.setTitle(title);
        n.setMessage(describe(a));
        repository.save(n);
    }

    static String describe(Appointment a) {
        return "%s · %s · %s com %s".formatted(a.getCustomer().getName(), a.getService().getName(),
                WHEN.format(a.getStartAt()), a.getProfessional().getName());
    }

    @Transactional(readOnly = true)
    public Inbox inbox() {
        return new Inbox(repository.countByReadAtIsNull(),
                repository.findTop50ByOrderByCreatedAtDesc().stream().map(NotificationResponse::from).toList());
    }

    @Transactional
    public void markAllRead() {
        repository.markAllRead(LocalDateTime.now(clock));
    }
}
