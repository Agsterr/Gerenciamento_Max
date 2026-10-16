package com.max.salao.booking;

import java.math.BigDecimal;
import java.time.LocalDate;
import java.time.LocalDateTime;
import java.time.LocalTime;
import java.util.List;

import com.max.salao.appointment.Appointment;
import com.max.salao.appointment.AppointmentStatus;
import com.max.salao.appointment.AvailabilityService.Slot;
import com.max.salao.salon.Salon;
import jakarta.validation.Valid;
import jakarta.validation.constraints.Email;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotNull;
import jakarta.validation.constraints.Size;
import org.springframework.format.annotation.DateTimeFormat;
import org.springframework.http.HttpStatus;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.ResponseStatus;
import org.springframework.web.bind.annotation.RestController;

/** Versão do cliente: agendamento online sem cadastro, só nome e telefone. */
@RestController
@RequestMapping("/api/public/salons/{slug}")
public class PublicBookingController {

    public record PublicService(Long id, String name, String description, int durationMinutes, BigDecimal price) {
    }

    public record PublicProfessional(Long id, String name) {
    }

    public record SalonInfo(String name, String slug, String phone, String address, LocalTime openTime,
                            LocalTime closeTime, String workDays, List<PublicService> services,
                            List<PublicProfessional> professionals) {
    }

    public record BookingRequest(
            @NotNull Long serviceId,
            Long professionalId,
            @NotNull LocalDateTime startAt,
            @NotBlank @Size(max = 120) String name,
            @NotBlank @Size(min = 8, max = 30) String phone,
            @Email String email,
            @Size(max = 300) String notes) {
    }

    public record BookingResponse(String token, LocalDateTime startAt, LocalDateTime endAt, AppointmentStatus status,
                                  String serviceName, String professionalName, BigDecimal price,
                                  String customerName, boolean cancelable) {

        static BookingResponse from(Appointment a) {
            return new BookingResponse(a.getPublicToken(), a.getStartAt(), a.getEndAt(), a.getStatus(),
                    a.getService().getName(), a.getProfessional().getName(), a.getPrice(),
                    a.getCustomer().getName(), a.getStatus().isOpen());
        }
    }

    private final PublicBookingService service;

    public PublicBookingController(PublicBookingService service) {
        this.service = service;
    }

    @GetMapping
    public SalonInfo info() {
        Salon s = service.salon();
        return new SalonInfo(s.getName(), s.getSlug(), s.getPhone(), s.getAddress(), s.getOpenTime(),
                s.getCloseTime(), s.getWorkDays(),
                service.activeServices().stream()
                        .map(x -> new PublicService(x.getId(), x.getName(), x.getDescription(),
                                x.getDurationMinutes(), x.getPrice()))
                        .toList(),
                service.activeProfessionals().stream().map(p -> new PublicProfessional(p.getId(), p.getName()))
                        .toList());
    }

    @GetMapping("/availability")
    public List<Slot> availability(@RequestParam Long serviceId,
                                   @RequestParam @DateTimeFormat(iso = DateTimeFormat.ISO.DATE) LocalDate date,
                                   @RequestParam(required = false) Long professionalId) {
        return service.availability(serviceId, date, professionalId);
    }

    @PostMapping("/bookings")
    @ResponseStatus(HttpStatus.CREATED)
    public BookingResponse book(@Valid @RequestBody BookingRequest req) {
        return BookingResponse.from(service.book(req));
    }

    @GetMapping("/bookings/{token}")
    public BookingResponse get(@PathVariable String token) {
        return BookingResponse.from(service.find(token));
    }

    @PostMapping("/bookings/{token}/cancel")
    public BookingResponse cancel(@PathVariable String token) {
        return BookingResponse.from(service.cancel(token));
    }
}
