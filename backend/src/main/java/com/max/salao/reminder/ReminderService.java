package com.max.salao.reminder;

import java.net.URLEncoder;
import java.nio.charset.StandardCharsets;
import java.time.Clock;
import java.time.LocalDate;
import java.time.LocalDateTime;
import java.time.format.DateTimeFormatter;
import java.util.ArrayList;
import java.util.List;
import java.util.Locale;

import com.max.salao.appointment.Appointment;
import com.max.salao.appointment.AppointmentRepository;
import com.max.salao.appointment.AppointmentStatus;
import com.max.salao.release.AppReleaseProperties;
import com.max.salao.salon.ReminderMode;
import com.max.salao.salon.Salon;
import com.max.salao.salon.SalonService;
import com.max.salao.shared.BusinessException;
import com.max.salao.shared.NotFoundException;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

/**
 * Lembretes para o cliente confirmar o horário, 1 e/ou 2 dias antes (conforme {@link ReminderMode}).
 * Sem WhatsApp pago: o salão abre o WhatsApp do cliente com a mensagem e o link de confirmação
 * prontos; o app do cliente também avisa sozinho (notificação local). Para envio automático no
 * futuro (WhatsApp Cloud API/SMS), basta um job que use {@link #message} e {@link #confirmUrl}.
 */
@Service
public class ReminderService {

    private static final Locale PT_BR = Locale.forLanguageTag("pt-BR");
    private static final DateTimeFormatter DAY = DateTimeFormatter.ofPattern("EEEE, dd/MM", PT_BR);
    private static final DateTimeFormatter TIME = DateTimeFormatter.ofPattern("HH:mm");

    public record ReminderItem(Long appointmentId, int daysBefore, LocalDateTime startAt, AppointmentStatus status,
                               String customerName, String customerPhone, String serviceName,
                               String professionalName, boolean customerConfirmed, LocalDateTime reminderSentAt,
                               String confirmUrl, String message, String whatsappUrl) {
    }

    public record Reminders(ReminderMode mode, List<Integer> days, List<ReminderItem> items) {
    }

    private final SalonService salons;
    private final AppointmentRepository appointments;
    private final AppReleaseProperties links;
    private final Clock clock;

    public ReminderService(SalonService salons, AppointmentRepository appointments, AppReleaseProperties links,
                           Clock clock) {
        this.salons = salons;
        this.appointments = appointments;
        this.links = links;
        this.clock = clock;
    }

    /** Horários de amanhã e/ou depois de amanhã (conforme o ajuste do salão) ainda de pé. */
    @Transactional(readOnly = true)
    public Reminders list() {
        Salon salon = salons.current();
        List<ReminderItem> items = new ArrayList<>();
        for (Appointment a : due(salon)) {
            int daysBefore = (int) java.time.temporal.ChronoUnit.DAYS.between(LocalDate.now(clock),
                    a.getStartAt().toLocalDate());
            String message = message(salon, a, daysBefore);
            items.add(new ReminderItem(a.getId(), daysBefore, a.getStartAt(), a.getStatus(), a.getCustomer().getName(),
                    a.getCustomer().getPhone(), a.getService().getName(), a.getProfessional().getName(),
                    a.getCustomerConfirmedAt() != null, a.getReminderSentAt(), confirmUrl(salon, a), message,
                    whatsappUrl(a.getCustomer().getPhone(), message)));
        }
        return new Reminders(salon.getReminderMode(), salon.getReminderMode().days(), items);
    }

    /** Agendamentos abertos nos dias de lembrete do salão. */
    @Transactional(readOnly = true)
    public List<Appointment> due(Salon salon) {
        List<Appointment> result = new ArrayList<>();
        LocalDate today = LocalDate.now(clock);
        for (int d : salon.getReminderMode().days()) {
            LocalDate day = today.plusDays(d);
            appointments.findByStartAtGreaterThanEqualAndStartAtLessThanOrderByStartAt(day.atStartOfDay(),
                            day.plusDays(1).atStartOfDay()).stream()
                    .filter(a -> a.getStatus().isOpen())
                    .forEach(result::add);
        }
        return result;
    }

    /** O salão abriu o WhatsApp com a mensagem: marca para não mandar duas vezes. */
    @Transactional
    public void markSent(Long appointmentId) {
        Appointment a = appointments.findById(appointmentId)
                .orElseThrow(() -> new NotFoundException("Agendamento não encontrado"));
        if (!a.getStatus().isOpen()) {
            throw new BusinessException("Este agendamento não está mais em aberto");
        }
        a.setReminderSentAt(LocalDateTime.now(clock));
    }

    public String confirmUrl(Salon salon, Appointment a) {
        return links.publicBaseUrl() + "/s/" + salon.getSlug() + "/agendamento/" + a.getPublicToken();
    }

    public String message(Salon salon, Appointment a, int daysBefore) {
        String when = switch (daysBefore) {
            case 0 -> "hoje";
            case 1 -> "amanhã";
            case 2 -> "depois de amanhã";
            default -> "em " + daysBefore + " dias";
        };
        String firstName = a.getCustomer().getName().trim().split("\\s+")[0];
        return """
                Olá, %s! Aqui é do %s. Lembrete do seu horário %s (%s) às %s: %s com %s.
                Confirme sua presença (ou remarque) por aqui: %s"""
                .formatted(firstName, salon.getName(), when, DAY.format(a.getStartAt()), TIME.format(a.getStartAt()),
                        a.getService().getName(), a.getProfessional().getName(), confirmUrl(salon, a));
    }

    /** Link "clique para conversar" do WhatsApp com a mensagem pronta (telefone brasileiro sem DDI ganha 55). */
    static String whatsappUrl(String phone, String message) {
        String digits = phone == null ? "" : phone.replaceAll("\\D", "");
        if (digits.length() == 10 || digits.length() == 11) {
            digits = "55" + digits;
        }
        return "https://wa.me/" + digits + "?text=" + URLEncoder.encode(message, StandardCharsets.UTF_8).replace("+", "%20");
    }
}
