package com.max.salao.booking;

import java.util.ArrayList;
import java.util.Comparator;
import java.util.List;

import com.max.salao.booking.PublicBookingController.BookingResponse;
import com.max.salao.booking.PublicBookingController.LookupRequest;
import com.max.salao.customer.Customer;
import com.max.salao.shared.TenantContext;
import jakarta.servlet.http.HttpServletRequest;
import jakarta.validation.Valid;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RestController;

/**
 * "Entrar" do app do cliente: com o mesmo nome e WhatsApp usados ao agendar, lista os horários
 * em todos os salões (não bloqueados) onde a pessoa já agendou. Não existe senha: é o mesmo
 * critério do "Meus horários" de cada salão, com o mesmo limite de tentativas.
 */
@RestController
public class PublicCustomerController {

    public record SalonBooking(String salonSlug, String salonName, BookingResponse booking) {
    }

    private record SalonRef(Long id, String slug, String name) {
    }

    private final PublicBookingService service;
    private final LookupRateLimiter rateLimiter;
    private final JdbcTemplate jdbc;

    public PublicCustomerController(PublicBookingService service, LookupRateLimiter rateLimiter, JdbcTemplate jdbc) {
        this.service = service;
        this.rateLimiter = rateLimiter;
        this.jdbc = jdbc;
    }

    @PostMapping("/api/public/my-bookings")
    public List<SalonBooking> myBookings(@Valid @RequestBody LookupRequest req, HttpServletRequest http) {
        String phone = Customer.normalizePhone(req.phone());
        rateLimiter.check("ip:" + PublicBookingController.clientIp(http));
        rateLimiter.check("tel:" + phone);

        // único ponto que olha vários salões: só descobre onde o telefone tem cadastro;
        // a busca em si roda dentro de cada salão, como na página pública dele
        List<SalonRef> salons = jdbc.query("""
                select s.id, s.slug, s.name from customer c join salon s on s.id = c.tenant_id
                where c.phone = ? and s.blocked = false""",
                (rs, i) -> new SalonRef(rs.getLong(1), rs.getString(2), rs.getString(3)), phone);

        List<SalonBooking> result = new ArrayList<>();
        try {
            for (SalonRef salon : salons) {
                TenantContext.set(salon.id());
                List<Integer> reminderDays = service.salon().getReminderMode().days();
                service.lookup(req.name(), req.phone()).forEach(a -> result.add(
                        new SalonBooking(salon.slug(), salon.name(), BookingResponse.of(a, service, reminderDays))));
            }
        } finally {
            TenantContext.clear();
        }
        result.sort(Comparator.comparing((SalonBooking b) -> b.booking().startAt()).reversed());
        return result;
    }
}
