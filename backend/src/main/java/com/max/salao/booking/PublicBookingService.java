package com.max.salao.booking;

import com.max.salao.plan.PlanService;
import java.text.Normalizer;
import java.time.Clock;
import java.time.LocalDate;
import java.time.LocalDateTime;
import java.util.List;
import java.util.Locale;

import com.max.salao.appointment.Appointment;
import com.max.salao.appointment.AppointmentRepository;
import com.max.salao.appointment.AppointmentService;
import com.max.salao.appointment.AppointmentStatus;
import com.max.salao.appointment.AppointmentService.BookCommand;
import com.max.salao.appointment.AvailabilityService;
import com.max.salao.appointment.AvailabilityService.Slot;
import com.max.salao.booking.PublicBookingController.BookingRequest;
import com.max.salao.catalog.ServiceItem;
import com.max.salao.catalog.ServiceItemRepository;
import com.max.salao.customer.Customer;
import com.max.salao.customer.CustomerRepository;
import com.max.salao.notification.Notification;
import com.max.salao.notification.NotificationService;
import com.max.salao.professional.Professional;
import com.max.salao.professional.ProfessionalRepository;
import com.max.salao.salon.Salon;
import com.max.salao.salon.SalonService;
import com.max.salao.shared.BusinessException;
import com.max.salao.shared.NotFoundException;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

@Service
public class PublicBookingService {

    /** Antecedência mínima para o cliente cancelar sozinho. */
    private static final int CANCEL_MIN_HOURS = 2;

    /** Quantos dias de histórico a consulta "meus agendamentos" mostra. */
    private static final int LOOKUP_HISTORY_DAYS = 60;

    private final SalonService salonService;
    private final ServiceItemRepository services;
    private final ProfessionalRepository professionals;
    private final CustomerRepository customers;
    private final AppointmentRepository appointments;
    private final AppointmentService appointmentService;
    private final AvailabilityService availabilityService;
    private final Clock clock;
    private final NotificationService notifications;
    private final PlanService plans;

    public PublicBookingService(SalonService salonService, ServiceItemRepository services,
                                ProfessionalRepository professionals, CustomerRepository customers,
                                AppointmentRepository appointments, AppointmentService appointmentService,
                                AvailabilityService availabilityService, Clock clock, NotificationService notifications, PlanService plans) {
        this.plans = plans;
        this.salonService = salonService;
        this.services = services;
        this.professionals = professionals;
        this.customers = customers;
        this.appointments = appointments;
        this.appointmentService = appointmentService;
        this.availabilityService = availabilityService;
        this.clock = clock;
        this.notifications = notifications;
    }

    public Salon salon() {
        return salonService.current();
    }

    public List<ServiceItem> activeServices() {
        return services.findByActiveTrueOrderByName();
    }

    public List<Professional> activeProfessionals() {
        return professionals.findByActiveTrueOrderByName();
    }

    @Transactional(readOnly = true)
    public List<Slot> availability(Long serviceId, LocalDate date, Long professionalId) {
        ServiceItem service = services.findById(serviceId)
                .filter(ServiceItem::isActive)
                .orElseThrow(() -> new NotFoundException("Serviço não encontrado"));
        List<Professional> candidates = activeProfessionals().stream()
                .filter(p -> professionalId == null || p.getId().equals(professionalId))
                .filter(p -> service.canBeDoneBy(p))
                .toList();
        return availabilityService.slots(salon(), service, candidates, date);
    }

    @Transactional
    public Appointment book(BookingRequest req) {
        String phone = Customer.normalizePhone(req.phone());
        Customer customer = customers.findByPhone(phone).orElseGet(() -> {
            try {
                plans.checkLimit(PlanService.Resource.CUSTOMERS);
            } catch (BusinessException e) {
                throw new BusinessException("Agendamento online indisponível no momento. Fale direto com o salão.");
            }
            Customer c = new Customer();
            c.setPhone(phone);
            c.setName(req.name().trim());
            c.setEmail(req.email());
            return customers.save(c);
        });
        Appointment a = appointmentService.book(BookCommand.online(customer, req.professionalId(), req.serviceId(),
                req.startAt(), req.notes()));
        notifications.notifySalon(Notification.Type.BOOKED, a);
        return a;
    }

    /**
     * "Meus agendamentos": o cliente informa o mesmo nome e WhatsApp usados ao agendar.
     * O primeiro nome precisa conferir com o cadastro, para um telefone sozinho não bastar.
     * Sem correspondência, devolve lista vazia (não revela se o telefone existe).
     */
    @Transactional(readOnly = true)
    public List<Appointment> lookup(String name, String phone) {
        return customers.findByPhone(Customer.normalizePhone(phone))
                .filter(c -> firstName(c.getName()).equals(firstName(name)))
                .map(c -> {
                    LocalDateTime since = LocalDate.now(clock).minusDays(LOOKUP_HISTORY_DAYS).atStartOfDay();
                    return appointments.findTop50ByCustomerIdOrderByStartAtDesc(c.getId()).stream()
                            .filter(a -> !a.getStartAt().isBefore(since))
                            .toList();
                })
                .orElse(List.of());
    }

    static String firstName(String name) {
        String plain = Normalizer.normalize(name == null ? "" : name.trim(), Normalizer.Form.NFD)
                .replaceAll("\\p{M}", "")
                .toLowerCase(Locale.ROOT);
        int space = plain.indexOf(' ');
        return space < 0 ? plain : plain.substring(0, space);
    }

    @Transactional
    public Appointment reschedule(String token, LocalDateTime startAt, Long professionalId) {
        Appointment a = find(token);
        requireChangeWindow(a, "Remarcação");
        appointmentService.rescheduleByCustomer(a, startAt, professionalId);
        notifications.notifySalon(Notification.Type.RESCHEDULED, a);
        return a;
    }

    @Transactional(readOnly = true)
    public Appointment find(String token) {
        return appointments.findByPublicToken(token).orElseThrow(() -> new NotFoundException("Agendamento não encontrado"));
    }

    @Transactional
    public Appointment cancel(String token) {
        Appointment a = find(token);
        requireChangeWindow(a, "Cancelamento");
        a.cancel();
        notifications.notifySalon(Notification.Type.CANCELED, a);
        return a;
    }

    /**
     * Cliente confirma a presença pelo link do lembrete (ou pelo app). Vale até o horário marcado;
     * confirmar de novo só devolve o agendamento.
     */
    @Transactional
    public Appointment confirm(String token) {
        Appointment a = find(token);
        if (a.getStatus() == AppointmentStatus.CONFIRMED && a.getCustomerConfirmedAt() != null) {
            return a;
        }
        if (!a.getStatus().isOpen() || !a.getStartAt().isAfter(LocalDateTime.now(clock))) {
            throw new BusinessException("Este agendamento não pode mais ser confirmado");
        }
        a.confirmByCustomer(LocalDateTime.now(clock));
        notifications.notifySalon(Notification.Type.CONFIRMED, a);
        return a;
    }

    /** Ainda falta o cliente confirmar (mostra o botão "Confirmar presença"). */
    public boolean canConfirm(Appointment a) {
        return a.getStatus() == AppointmentStatus.SCHEDULED && a.getStartAt().isAfter(LocalDateTime.now(clock));
    }

    /** O cliente só cancela ou remarca sozinho até {@value #CANCEL_MIN_HOURS} h antes do horário marcado. */
    public boolean canChange(Appointment a) {
        return a.getStatus().isOpen() && !a.getStartAt().isBefore(LocalDateTime.now(clock).plusHours(CANCEL_MIN_HOURS));
    }

    private void requireChangeWindow(Appointment a, String action) {
        if (!a.getStatus().isOpen()) {
            throw new BusinessException("Este agendamento não pode mais ser alterado");
        }
        if (!canChange(a)) {
            throw new BusinessException(action + " online só até " + CANCEL_MIN_HOURS
                    + "h antes. Entre em contato com o salão.");
        }
    }
}
