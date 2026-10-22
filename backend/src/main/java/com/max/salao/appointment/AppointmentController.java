package com.max.salao.appointment;

import java.time.LocalDate;
import java.util.List;

import com.max.salao.appointment.AppointmentDtos.AppointmentRequest;
import com.max.salao.appointment.AppointmentDtos.AppointmentResponse;
import com.max.salao.appointment.AppointmentDtos.FinishRequest;
import com.max.salao.appointment.AppointmentDtos.ServiceNotesRequest;
import com.max.salao.appointment.AvailabilityService.Slot;
import com.max.salao.catalog.ServiceItemRepository;
import com.max.salao.professional.ProfessionalRepository;
import com.max.salao.salon.SalonService;
import com.max.salao.shared.NotFoundException;
import jakarta.validation.Valid;
import org.springframework.format.annotation.DateTimeFormat;
import org.springframework.http.HttpStatus;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.PutMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.ResponseStatus;
import org.springframework.web.bind.annotation.RestController;

@RestController
@RequestMapping("/api")
public class AppointmentController {

    private final AppointmentService service;
    private final AvailabilityService availability;
    private final SalonService salonService;
    private final ServiceItemRepository services;
    private final ProfessionalRepository professionals;

    public AppointmentController(AppointmentService service, AvailabilityService availability,
                                 SalonService salonService, ServiceItemRepository services,
                                 ProfessionalRepository professionals) {
        this.service = service;
        this.availability = availability;
        this.salonService = salonService;
        this.services = services;
        this.professionals = professionals;
    }

    @GetMapping("/appointments")
    public List<AppointmentResponse> list(
            @RequestParam @DateTimeFormat(iso = DateTimeFormat.ISO.DATE) LocalDate from,
            @RequestParam(required = false) @DateTimeFormat(iso = DateTimeFormat.ISO.DATE) LocalDate to) {
        return toResponse(service.list(from, to != null ? to : from));
    }

    @GetMapping("/customers/{customerId}/appointments")
    public List<AppointmentResponse> history(@PathVariable Long customerId) {
        return toResponse(service.history(customerId));
    }

    @GetMapping("/appointments/availability")
    public List<Slot> availability(@RequestParam Long serviceId,
                                   @RequestParam @DateTimeFormat(iso = DateTimeFormat.ISO.DATE) LocalDate date,
                                   @RequestParam(required = false) Long professionalId) {
        var serviceItem = services.findById(serviceId).orElseThrow(() -> new NotFoundException("Serviço não encontrado"));
        var candidates = professionals.findByActiveTrueOrderByName().stream()
                .filter(p -> professionalId == null || p.getId().equals(professionalId))
                .filter(p -> serviceItem.canBeDoneBy(p))
                .toList();
        return availability.slots(salonService.current(), serviceItem, candidates, date);
    }

    @PostMapping("/appointments")
    @ResponseStatus(HttpStatus.CREATED)
    public AppointmentResponse create(@Valid @RequestBody AppointmentRequest req) {
        return AppointmentResponse.from(service.create(req));
    }

    @PutMapping("/appointments/{id}")
    public AppointmentResponse reschedule(@PathVariable Long id, @Valid @RequestBody AppointmentRequest req) {
        return AppointmentResponse.from(service.reschedule(id, req));
    }

    @PutMapping("/appointments/{id}/service-notes")
    public AppointmentResponse serviceNotes(@PathVariable Long id, @Valid @RequestBody ServiceNotesRequest req) {
        return AppointmentResponse.from(service.updateServiceNotes(id, req.serviceNotes()));
    }

    /** O salão aceita o agendamento feito pelo cliente (ele deixa de estar "aguardando confirmação"). */
    @PostMapping("/appointments/{id}/accept")
    public AppointmentResponse accept(@PathVariable Long id) {
        return AppointmentResponse.from(service.accept(id));
    }

    @PostMapping("/appointments/{id}/confirm")
    public AppointmentResponse confirm(@PathVariable Long id) {
        return AppointmentResponse.from(service.changeStatus(id, Appointment::confirm));
    }

    @PostMapping("/appointments/{id}/start")
    public AppointmentResponse start(@PathVariable Long id) {
        return AppointmentResponse.from(service.start(id));
    }

    @PostMapping("/appointments/{id}/finish")
    public AppointmentResponse finish(@PathVariable Long id, @Valid @RequestBody FinishRequest req) {
        return AppointmentResponse.from(service.finish(id, req));
    }

    @PostMapping("/appointments/{id}/cancel")
    public AppointmentResponse cancel(@PathVariable Long id) {
        return AppointmentResponse.from(service.changeStatus(id, Appointment::cancel));
    }

    @PostMapping("/appointments/{id}/no-show")
    public AppointmentResponse noShow(@PathVariable Long id) {
        return AppointmentResponse.from(service.changeStatus(id, Appointment::noShow));
    }

    private static List<AppointmentResponse> toResponse(List<Appointment> list) {
        return list.stream().map(AppointmentResponse::from).toList();
    }
}
