package com.max.salao.appointment;

import java.time.Clock;
import java.time.LocalDate;
import java.time.LocalDateTime;
import java.util.List;
import java.util.function.Consumer;

import com.max.salao.appointment.AppointmentDtos.FinishRequest;
import com.max.salao.appointment.AppointmentDtos.ProductQuantity;
import com.max.salao.catalog.ServiceItem;
import com.max.salao.catalog.ServiceItemRepository;
import com.max.salao.customer.Customer;
import com.max.salao.customer.CustomerRepository;
import com.max.salao.product.ProductService;
import com.max.salao.product.StockMovement;
import com.max.salao.professional.Professional;
import com.max.salao.professional.ProfessionalRepository;
import com.max.salao.salon.Salon;
import com.max.salao.salon.SalonService;
import com.max.salao.shared.BusinessException;
import com.max.salao.shared.NotFoundException;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

@Service
public class AppointmentService {

    /** Dados necessários para marcar um horário (vindos do painel ou da página pública). */
    public record BookCommand(Customer customer, Long professionalId, Long serviceId, LocalDateTime startAt,
                              String notes, Appointment.Source source, Integer durationMinutes, boolean force) {

        /** Agendamento feito pelo cliente: sempre na duração do serviço e sem encaixe. */
        public static BookCommand online(Customer customer, Long professionalId, Long serviceId,
                                         LocalDateTime startAt, String notes) {
            return new BookCommand(customer, professionalId, serviceId, startAt, notes, Appointment.Source.ONLINE,
                    null, false);
        }
    }

    private final AppointmentRepository appointments;
    private final ProfessionalRepository professionals;
    private final ServiceItemRepository services;
    private final CustomerRepository customers;
    private final AvailabilityService availability;
    private final ProductService productService;
    private final SalonService salonService;
    private final Clock clock;

    public AppointmentService(AppointmentRepository appointments, ProfessionalRepository professionals,
                              ServiceItemRepository services, CustomerRepository customers,
                              AvailabilityService availability, ProductService productService,
                              SalonService salonService, Clock clock) {
        this.appointments = appointments;
        this.professionals = professionals;
        this.services = services;
        this.customers = customers;
        this.availability = availability;
        this.productService = productService;
        this.salonService = salonService;
        this.clock = clock;
    }

    @Transactional(readOnly = true)
    public List<Appointment> list(LocalDate from, LocalDate to) {
        return appointments.findByStartAtGreaterThanEqualAndStartAtLessThanOrderByStartAt(
                from.atStartOfDay(), to.plusDays(1).atStartOfDay());
    }

    @Transactional(readOnly = true)
    public List<Appointment> history(Long customerId) {
        return appointments.findTop50ByCustomerIdOrderByStartAtDesc(customerId);
    }

    @Transactional(readOnly = true)
    public Appointment get(Long id) {
        return appointments.findWithDetailsById(id).orElseThrow(() -> new NotFoundException("Agendamento não encontrado"));
    }

    @Transactional
    public Appointment create(AppointmentDtos.AppointmentRequest req) {
        Customer customer = customers.findById(req.customerId())
                .orElseThrow(() -> new NotFoundException("Cliente não encontrado"));
        return book(new BookCommand(customer, req.professionalId(), req.serviceId(), req.startAt(), req.notes(),
                Appointment.Source.ADMIN, req.durationMinutes(), req.force()));
    }

    @Transactional
    public Appointment book(BookCommand cmd) {
        Salon salon = salonService.current();
        ServiceItem service = services.findById(cmd.serviceId())
                .filter(ServiceItem::isActive)
                .orElseThrow(() -> new NotFoundException("Serviço não encontrado"));
        LocalDateTime start = cmd.startAt().withSecond(0).withNano(0);
        LocalDateTime end = start.plusMinutes(durationOf(service, cmd.durationMinutes()));
        if (start.isBefore(LocalDateTime.now(clock).minusMinutes(5)) && cmd.source() == Appointment.Source.ONLINE) {
            throw new BusinessException("Escolha um horário futuro");
        }

        if (cmd.force() && cmd.professionalId() == null) {
            throw new BusinessException("Escolha o profissional para fazer um encaixe");
        }
        Long professionalId = cmd.professionalId() != null
                ? cmd.professionalId()
                : pickFreeProfessional(salon, service, start, end);
        Professional professional = professionals.findByIdForUpdate(professionalId)
                .filter(Professional::isActive)
                .orElseThrow(() -> new NotFoundException("Profissional não encontrado"));
        if (!cmd.force()) {
            assertDoes(professional, service);
            availability.assertBookable(salon, professional.getId(), start, end, null);
        }

        Appointment a = new Appointment();
        a.setCustomer(cmd.customer());
        a.setProfessional(professional);
        a.setService(service);
        a.setStartAt(start);
        a.setEndAt(end);
        a.setPrice(service.getPrice());
        a.setNotes(cmd.notes());
        a.setSource(cmd.source());
        return appointments.save(a);
    }

    /** Remarca horário/profissional/serviço de um agendamento ainda aberto. */
    @Transactional
    public Appointment reschedule(Long id, AppointmentDtos.AppointmentRequest req) {
        Appointment a = get(id);
        if (!a.getStatus().isOpen()) {
            throw new BusinessException("Só é possível remarcar agendamentos em aberto");
        }
        ServiceItem service = services.findById(req.serviceId())
                .orElseThrow(() -> new NotFoundException("Serviço não encontrado"));
        Long professionalId = req.professionalId() != null ? req.professionalId() : a.getProfessional().getId();
        Professional professional = professionals.findByIdForUpdate(professionalId)
                .orElseThrow(() -> new NotFoundException("Profissional não encontrado"));
        LocalDateTime start = req.startAt().withSecond(0).withNano(0);
        LocalDateTime end = start.plusMinutes(durationOf(service, req.durationMinutes()));
        if (!req.force()) {
            assertDoes(professional, service);
            availability.assertBookable(salonService.current(), professional.getId(), start, end, a.getId());
        }

        a.setService(service);
        a.setProfessional(professional);
        a.setStartAt(start);
        a.setEndAt(end);
        a.setPrice(service.getPrice());
        a.setNotes(req.notes());
        return a;
    }

    @Transactional
    public Appointment changeStatus(Long id, Consumer<Appointment> action) {
        Appointment a = get(id);
        action.accept(a);
        return a;
    }

    @Transactional
    public Appointment start(Long id) {
        return changeStatus(id, a -> a.start(LocalDateTime.now(clock)));
    }

    /** Fecha o atendimento: registra valor final, comissão e baixa de produtos usados/vendidos. */
    @Transactional
    public Appointment finish(Long id, FinishRequest req) {
        Appointment a = get(id);
        a.finish(LocalDateTime.now(clock), req.price());
        if (req.serviceNotes() != null) {
            a.setServiceNotes(blankToNull(req.serviceNotes()));
        }
        moveAll(req.usedProducts(), StockMovement.Type.USE, a.getId());
        moveAll(req.soldProducts(), StockMovement.Type.SALE, a.getId());
        return a;
    }

    /** Anotações do profissional: podem ser editadas a qualquer momento (inclusive depois de finalizar). */
    @Transactional
    public Appointment updateServiceNotes(Long id, String serviceNotes) {
        Appointment a = get(id);
        a.setServiceNotes(blankToNull(serviceNotes));
        return a;
    }

    /**
     * Remarcação feita pelo cliente: mesmo serviço e duração, só em horário livre e dentro do expediente.
     * {@code professionalId} nulo mantém o profissional atual.
     */
    @Transactional
    public Appointment rescheduleByCustomer(Appointment a, LocalDateTime newStart, Long professionalId) {
        if (!a.getStatus().isOpen()) {
            throw new BusinessException("Este agendamento não pode mais ser remarcado");
        }
        LocalDateTime start = newStart.withSecond(0).withNano(0);
        if (start.isBefore(LocalDateTime.now(clock))) {
            throw new BusinessException("Escolha um horário futuro");
        }
        Long proId = professionalId != null ? professionalId : a.getProfessional().getId();
        Professional professional = professionals.findByIdForUpdate(proId)
                .filter(Professional::isActive)
                .orElseThrow(() -> new NotFoundException("Profissional não encontrado"));
        LocalDateTime end = start.plusMinutes(a.plannedMinutes());
        assertDoes(professional, a.getService());
        availability.assertBookable(salonService.current(), professional.getId(), start, end, a.getId());
        a.setProfessional(professional);
        a.setStartAt(start);
        a.setEndAt(end);
        return a;
    }

    private static String blankToNull(String s) {
        return s == null || s.isBlank() ? null : s.trim();
    }

    private void moveAll(List<ProductQuantity> items, StockMovement.Type type, Long appointmentId) {
        if (items == null) {
            return;
        }
        for (ProductQuantity item : items) {
            productService.move(item.productId(), type, item.quantity(), null, appointmentId);
        }
    }

    /** Primeiro profissional ativo sem conflito no intervalo (aceita qualquer minuto, não só a grade). */
    private Long pickFreeProfessional(Salon salon, ServiceItem service, LocalDateTime start, LocalDateTime end) {
        return professionals.findByActiveTrueOrderByName().stream()
                .filter(service::canBeDoneBy)
                .map(Professional::getId)
                .filter(id -> availability.isBookable(salon, id, start, end))
                .findFirst()
                .orElseThrow(() -> new BusinessException("Nenhum profissional livre nesse horário"));
    }

    private static void assertDoes(Professional professional, ServiceItem service) {
        if (!service.canBeDoneBy(professional)) {
            throw new BusinessException(professional.getName() + " não faz o serviço " + service.getName());
        }
    }

    private static int durationOf(ServiceItem service, Integer manualMinutes) {
        return manualMinutes != null ? manualMinutes : service.getDurationMinutes();
    }
}
