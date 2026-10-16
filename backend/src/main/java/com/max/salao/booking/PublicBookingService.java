package com.max.salao.booking;

import java.time.Clock;
import java.time.LocalDate;
import java.time.LocalDateTime;
import java.util.List;

import com.max.salao.appointment.Appointment;
import com.max.salao.appointment.AppointmentRepository;
import com.max.salao.appointment.AppointmentService;
import com.max.salao.appointment.AppointmentService.BookCommand;
import com.max.salao.appointment.AvailabilityService;
import com.max.salao.appointment.AvailabilityService.Slot;
import com.max.salao.booking.PublicBookingController.BookingRequest;
import com.max.salao.catalog.ServiceItem;
import com.max.salao.catalog.ServiceItemRepository;
import com.max.salao.customer.Customer;
import com.max.salao.customer.CustomerRepository;
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

    private final SalonService salonService;
    private final ServiceItemRepository services;
    private final ProfessionalRepository professionals;
    private final CustomerRepository customers;
    private final AppointmentRepository appointments;
    private final AppointmentService appointmentService;
    private final AvailabilityService availabilityService;
    private final Clock clock;

    public PublicBookingService(SalonService salonService, ServiceItemRepository services,
                                ProfessionalRepository professionals, CustomerRepository customers,
                                AppointmentRepository appointments, AppointmentService appointmentService,
                                AvailabilityService availabilityService, Clock clock) {
        this.salonService = salonService;
        this.services = services;
        this.professionals = professionals;
        this.customers = customers;
        this.appointments = appointments;
        this.appointmentService = appointmentService;
        this.availabilityService = availabilityService;
        this.clock = clock;
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
                .toList();
        return availabilityService.slots(salon(), service, candidates, date);
    }

    @Transactional
    public Appointment book(BookingRequest req) {
        String phone = Customer.normalizePhone(req.phone());
        Customer customer = customers.findByPhone(phone).orElseGet(() -> {
            Customer c = new Customer();
            c.setPhone(phone);
            c.setName(req.name().trim());
            c.setEmail(req.email());
            return customers.save(c);
        });
        return appointmentService.book(new BookCommand(customer, req.professionalId(), req.serviceId(),
                req.startAt(), req.notes(), Appointment.Source.ONLINE));
    }

    @Transactional(readOnly = true)
    public Appointment find(String token) {
        return appointments.findByPublicToken(token).orElseThrow(() -> new NotFoundException("Agendamento não encontrado"));
    }

    @Transactional
    public Appointment cancel(String token) {
        Appointment a = find(token);
        if (a.getStartAt().isBefore(LocalDateTime.now(clock).plusHours(CANCEL_MIN_HOURS))) {
            throw new BusinessException("Cancelamento online só até " + CANCEL_MIN_HOURS
                    + "h antes. Entre em contato com o salão.");
        }
        a.cancel();
        return a;
    }
}
