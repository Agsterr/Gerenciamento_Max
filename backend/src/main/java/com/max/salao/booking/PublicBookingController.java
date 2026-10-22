package com.max.salao.booking;

import java.math.BigDecimal;
import java.time.LocalDate;
import java.time.LocalDateTime;
import java.util.List;

import com.max.salao.appointment.Appointment;
import com.max.salao.appointment.AppointmentStatus;
import com.max.salao.appointment.AvailabilityService.Slot;
import com.max.salao.catalog.ServiceItem;
import com.max.salao.customer.Customer;
import com.max.salao.professional.Professional;
import com.max.salao.promotion.Promotion;
import com.max.salao.salon.Salon;
import com.max.salao.salon.SalonDtos;
import jakarta.servlet.http.HttpServletRequest;
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

    /** professionalIds vazio = qualquer profissional faz o serviço. */
    public record PublicService(Long id, String name, String description, int durationMinutes, BigDecimal price,
                                String category, List<Long> professionalIds,
                                // pacote: serviços incluídos e o preço somado sem desconto
                                List<String> kitItems, BigDecimal kitFullPrice,
                                // promoção que vale hoje (o preço final é o do dia do horário)
                                BigDecimal promoPrice, Long promotionId, String promoName, BigDecimal promoPercent,
                                java.time.LocalDate promoStartsOn, java.time.LocalDate promoEndsOn) {
    }

    /** Promoção em andamento ou que ainda vai começar; serviceIds vazio = vale para todos. */
    /** notifyCustomers: o salão quer que o app avise os clientes desta promoção. */
    public record PublicPromotion(Long id, String name, String description, BigDecimal discountPercent,
                                  java.time.LocalDate startsOn, java.time.LocalDate endsOn, List<Long> serviceIds,
                                  boolean notifyCustomers) {
    }

    /**
     * O app do cliente abriu a página do salão: identifica pelo código de um agendamento ou pelo
     * nome + WhatsApp (o mesmo critério de "Meus agendamentos"). promoNotifications nulo = não mudou.
     */
    public record PresenceRequest(@Size(max = 64) String token, @Size(max = 120) String name,
                                  @Size(max = 30) String phone, Boolean promoNotifications,
                                  // celular para push (Firebase); visit=false só atualiza a escolha, sem contar visita
                                  @Size(max = 512) String pushToken, Boolean visit) {
    }

    public record PublicProfessional(Long id, String name) {
    }

    /** reminderDays: dias antes do horário em que o app do cliente avisa para confirmar (vazio = desligado). */
    public record SalonInfo(String name, String slug, String phone, String address, String workDays,
                            List<SalonDtos.DayHoursDto> hours, List<PublicService> services,
                            List<PublicProfessional> professionals, List<Integer> reminderDays,
                            List<PublicPromotion> promotions) {
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

    public record LookupRequest(@NotBlank @Size(max = 120) String name,
                                @NotBlank @Size(min = 8, max = 30) String phone) {
    }

    public record RescheduleRequest(@NotNull LocalDateTime startAt, Long professionalId) {
    }

    /** Visão do cliente. Não inclui as anotações internas do salão (tinta usada, etc.). */
    public record BookingResponse(String token, LocalDateTime startAt, LocalDateTime endAt, AppointmentStatus status,
                                  Long serviceId, String serviceName, Long professionalId, String professionalName,
                                  BigDecimal price, String customerName, boolean cancelable,
                                  boolean confirmable, List<Integer> reminderDays,
                                  // false = o salão ainda não aceitou ("aguardando confirmação do salão")
                                  boolean salonConfirmed) {

        static BookingResponse of(Appointment a, PublicBookingService service, List<Integer> reminderDays) {
            return new BookingResponse(a.getPublicToken(), a.getStartAt(), a.getEndAt(), a.getStatus(),
                    a.getService().getId(), a.getService().getName(),
                    a.getProfessional().getId(), a.getProfessional().getName(), a.getPrice(),
                    a.getCustomer().getName(), service.canChange(a), service.canConfirm(a), reminderDays,
                    a.getSalonConfirmedAt() != null);
        }
    }

    private final PublicBookingService service;
    private final LookupRateLimiter rateLimiter;

    public PublicBookingController(PublicBookingService service, LookupRateLimiter rateLimiter) {
        this.service = service;
        this.rateLimiter = rateLimiter;
    }

    private BookingResponse toResponse(Appointment a) {
        return BookingResponse.of(a, service, service.salon().getReminderMode().days());
    }

    /** Profissionais ativos que fazem o serviço (lista explícita ou especialidade); vazio = todos fazem. */
    private static List<Long> whoDoes(ServiceItem item, List<Professional> active) {
        var eligible = active.stream().filter(item::canBeDoneBy).map(Professional::getId).sorted().toList();
        return eligible.size() == active.size() ? List.of() : eligible;
    }

    @GetMapping
    public SalonInfo info() {
        Salon s = service.salon();
        var active = service.activeProfessionals();
        var today = service.today();
        var promos = service.promotions();
        return new SalonInfo(s.getName(), s.getSlug(), s.getPhone(), s.getAddress(), s.workDays(),
                SalonDtos.hours(s),
                service.activeServices().stream()
                        // serviço que nenhum profissional ativo faz não aparece para o cliente
                        .filter(x -> active.isEmpty() || active.stream().anyMatch(x::canBeDoneBy))
                        .map(x -> publicService(x, active, promos, today))
                        .toList(),
                active.stream().map(p -> new PublicProfessional(p.getId(), p.getName()))
                        .toList(),
                s.getReminderMode().days(),
                promos.stream().map(p -> new PublicPromotion(p.getId(), p.getName(), p.getDescription(),
                        p.getDiscountPercent(), p.getStartsOn(), p.getEndsOn(),
                        p.getServiceIds().stream().sorted().toList(), p.isNotifyCustomers())).toList());
    }

    private PublicService publicService(ServiceItem x, List<Professional> active, List<Promotion> promos,
                                        java.time.LocalDate today) {
        // promoção de hoje ou, se ainda não começou, a próxima (o cliente vê a data em que vale)
        var promo = promos.stream()
                .filter(p -> p.covers(x))
                .min(java.util.Comparator.comparing((Promotion p) -> p.getStartsOn().isAfter(today))
                        .thenComparing(p -> p.getDiscountPercent().negate()));
        return new PublicService(x.getId(), x.getName(), x.getDescription(), x.getDurationMinutes(), x.getPrice(),
                x.getCategory(), whoDoes(x, active),
                x.getKitItems().stream().map(ServiceItem::getName).sorted().toList(),
                x.isKit() ? x.kitFullPrice() : null,
                promo.map(p -> p.apply(x.getPrice())).orElse(null),
                promo.map(Promotion::getId).orElse(null),
                promo.map(Promotion::getName).orElse(null),
                promo.map(Promotion::getDiscountPercent).orElse(null),
                promo.map(Promotion::getStartsOn).orElse(null),
                promo.map(Promotion::getEndsOn).orElse(null));
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
        return toResponse(service.book(req));
    }

    @GetMapping("/bookings/{token}")
    public BookingResponse get(@PathVariable String token) {
        return toResponse(service.find(token));
    }

    @PostMapping("/bookings/{token}/cancel")
    public BookingResponse cancel(@PathVariable String token) {
        return toResponse(service.cancel(token));
    }

    /** Link do lembrete: o cliente confirma que vai. */
    @PostMapping("/bookings/{token}/confirm")
    public BookingResponse confirm(@PathVariable String token) {
        return toResponse(service.confirm(token));
    }

    @PostMapping("/bookings/{token}/reschedule")
    public BookingResponse reschedule(@PathVariable String token, @Valid @RequestBody RescheduleRequest req) {
        return toResponse(service.reschedule(token, req.startAt(), req.professionalId()));
    }

    /** Produto da vitrine (só para ver; a compra é no salão). */
    public record PublicProduct(Long id, String name, BigDecimal price, boolean available, String thumbUrl,
                                String imageUrl) {
    }

    /** Vitrine: produtos ativos, com preço de venda e liberados pelo salão (sem mostrar o estoque). */
    @GetMapping("/products")
    public List<PublicProduct> products() {
        return service.showcase();
    }

    /** Registra a visita (e a escolha de avisos de promoção). Sempre 204: não revela se o cliente existe. */
    @PostMapping("/presence")
    @ResponseStatus(HttpStatus.NO_CONTENT)
    public void presence(@Valid @RequestBody PresenceRequest req) {
        service.presence(req.token(), req.name(), req.phone(), req.promoNotifications(), req.pushToken(),
                !Boolean.FALSE.equals(req.visit()));
    }

    /** "Meus agendamentos": consulta pelo mesmo nome e WhatsApp usados ao agendar. */
    @PostMapping("/my-bookings")
    public List<BookingResponse> myBookings(@Valid @RequestBody LookupRequest req, HttpServletRequest http) {
        rateLimiter.check("ip:" + clientIp(http));
        rateLimiter.check("tel:" + Customer.normalizePhone(req.phone()));
        List<Integer> reminderDays = service.salon().getReminderMode().days();
        return service.lookup(req.name(), req.phone()).stream()
                .map(a -> BookingResponse.of(a, service, reminderDays)).toList();
    }

    /** IP real do visitante atrás do Cloudflare/nginx. */
    public static String clientIp(HttpServletRequest http) {
        String cf = http.getHeader("CF-Connecting-IP");
        if (cf != null && !cf.isBlank()) {
            return cf.trim();
        }
        String xff = http.getHeader("X-Forwarded-For");
        if (xff != null && !xff.isBlank()) {
            return xff.split(",")[0].trim();
        }
        return http.getRemoteAddr();
    }
}
