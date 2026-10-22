package com.max.salao.push;

import java.time.Clock;
import java.time.LocalDateTime;

import jakarta.validation.Valid;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.Size;
import org.springframework.http.HttpStatus;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.security.oauth2.jwt.Jwt;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.ResponseStatus;
import org.springframework.web.bind.annotation.RestController;

/** Cadastro do celular do usuário do salão (app de gestão) e confirmação de recebimento dos avisos. */
@RestController
public class PushController {

    public record TokenRequest(@NotBlank @Size(max = 512) String token) {
    }

    public record AckRequest(@NotBlank @Size(max = 64) String id, @NotBlank @Size(max = 512) String token) {
    }

    private final PushDeviceRepository devices;
    private final PushOutbox outbox;
    private final Clock clock;

    public PushController(PushDeviceRepository devices, PushOutbox outbox, Clock clock) {
        this.devices = devices;
        this.outbox = outbox;
        this.clock = clock;
    }

    /** O app de gestão entrou (ou o código do celular mudou): este celular passa a receber os avisos do usuário. */
    @PostMapping("/api/me/push-token")
    @ResponseStatus(HttpStatus.NO_CONTENT)
    @Transactional
    public void register(@AuthenticationPrincipal Jwt jwt, @Valid @RequestBody TokenRequest req) {
        PushDevice d = devices.findByToken(req.token()).orElseGet(PushDevice::new);
        d.setToken(req.token());
        d.setApp(PushNotifier.STAFF);
        d.setUserId(Long.valueOf(jwt.getSubject()));
        d.setCustomerId(null);
        d.setUpdatedAt(LocalDateTime.now(clock));
        devices.save(d);
    }

    /** O usuário saiu do app: este celular deixa de receber os avisos dele. */
    @PostMapping("/api/me/push-token/remove")
    @ResponseStatus(HttpStatus.NO_CONTENT)
    @Transactional
    public void unregister(@AuthenticationPrincipal Jwt jwt, @Valid @RequestBody TokenRequest req) {
        devices.findByToken(req.token())
                .filter(d -> Long.valueOf(jwt.getSubject()).equals(d.getUserId()))
                .ifPresent(devices::delete);
    }

    /**
     * Confirmação de recebimento: o app devolve o código do aviso e o do celular. Aberta (o app pode estar
     * em segundo plano, sem login), mas só vale com os dois códigos que o servidor mandou.
     */
    @PostMapping("/api/push/ack")
    @ResponseStatus(HttpStatus.NO_CONTENT)
    public void ack(@Valid @RequestBody AckRequest req) {
        outbox.ack(req.id(), req.token(), LocalDateTime.now(clock));
    }
}
