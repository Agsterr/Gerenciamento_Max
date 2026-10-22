package com.max.salao.push;

import java.util.HashMap;
import java.util.List;
import java.util.Map;
import java.util.Set;
import java.util.stream.Collectors;

import com.max.salao.appointment.Appointment;
import com.max.salao.auth.AppUser;
import com.max.salao.auth.AppUserRepository;
import com.max.salao.auth.Role;
import com.max.salao.salon.SalonService;
import com.max.salao.shared.TenantContext;
import org.springframework.stereotype.Service;

/**
 * Coloca na fila os avisos para os celulares: da equipe (o cliente agendou, cancelou, remarcou...) e
 * do cliente (o salão aceitou, cancelou ou mudou o horário). A entrega é do {@link PushOutboxWorker}.
 * Sem Firebase configurado nada entra na fila.
 */
@Service
public class PushNotifier {

    public static final String STAFF = "STAFF";
    public static final String CLIENT = "CLIENT";

    private final PushOutbox outbox;
    private final PushDeviceRepository devices;
    private final AppUserRepository users;
    private final SalonService salons;
    private final PushProperties props;

    public PushNotifier(PushOutbox outbox, PushDeviceRepository devices, AppUserRepository users, SalonService salons,
                        PushProperties props) {
        this.outbox = outbox;
        this.devices = devices;
        this.users = users;
        this.salons = salons;
        this.props = props;
    }

    /**
     * Avisa a equipe sobre um horário: o dono sempre; funcionário que acompanha um profissional só do dele
     * (funcionário sem profissional definido recebe tudo). {@code event} identifica o aviso (não repete).
     */
    public int toStaff(Appointment a, String event, String title, String body) {
        if (!props.configured()) {
            return 0;
        }
        List<PushDevice> staffDevices = devices.findByApp(STAFF);
        if (staffDevices.isEmpty()) {
            return 0;
        }
        Set<Long> userIds = staffDevices.stream().map(PushDevice::getUserId).filter(java.util.Objects::nonNull)
                .collect(Collectors.toSet());
        Set<Long> eligible = users.findAllById(userIds).stream()
                .filter(u -> u.isActive() && !u.isBlocked() && receives(u, a))
                .map(AppUser::getId).collect(Collectors.toSet());
        Map<String, String> data = new HashMap<>();
        data.put("type", "staff");
        data.put("appointmentId", String.valueOf(a.getId()));
        int queued = 0;
        for (PushDevice d : staffDevices) {
            if (d.getUserId() != null && eligible.contains(d.getUserId())
                    && outbox.enqueue(TenantContext.get(), d.getId(), d.getToken(), title, body, data,
                            event + ":" + a.getId() + ":" + d.getId())) {
                queued++;
            }
        }
        return queued;
    }

    private static boolean receives(AppUser u, Appointment a) {
        return u.getRole() == Role.OWNER || u.getProfessionalId() == null
                || u.getProfessionalId().equals(a.getProfessional().getId());
    }

    /** Avisa o cliente (celulares do app dele ligados a este cliente) sobre o horário dele. */
    public int toCustomer(Appointment a, String event, String title, String body) {
        if (!props.configured()) {
            return 0;
        }
        Map<String, String> data = new HashMap<>();
        data.put("type", "booking");
        data.put("slug", salons.current().getSlug());
        data.put("token", a.getPublicToken());
        int queued = 0;
        for (PushDevice d : devices.findByAppAndCustomerId(CLIENT, a.getCustomer().getId())) {
            if (outbox.enqueue(TenantContext.get(), d.getId(), d.getToken(), title, body, data,
                    event + ":" + a.getId() + ":" + d.getId())) {
                queued++;
            }
        }
        return queued;
    }

    /** Promoção: todos os celulares do app do cliente que aceitam promoções. */
    public int promotion(String event, String title, String body, Map<String, String> data) {
        if (!props.configured()) {
            return 0;
        }
        int queued = 0;
        for (PushDevice d : devices.findByAppAndPromoNotificationsTrue(CLIENT)) {
            if (outbox.enqueue(TenantContext.get(), d.getId(), d.getToken(), title, body, data, event + ":" + d.getId())) {
                queued++;
            }
        }
        return queued;
    }
}
