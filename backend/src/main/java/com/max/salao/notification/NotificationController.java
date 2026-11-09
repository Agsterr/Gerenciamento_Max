package com.max.salao.notification;

import com.max.salao.notification.NotificationService.Inbox;
import org.springframework.http.HttpStatus;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.security.oauth2.jwt.Jwt;
import java.time.LocalDate;

import org.springframework.format.annotation.DateTimeFormat;
import org.springframework.web.bind.annotation.DeleteMapping;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.ResponseStatus;
import org.springframework.web.bind.annotation.RestController;

/** Avisos do salão (sino no painel e no app de gestão). */
@RestController
@RequestMapping("/api/notifications")
public class NotificationController {

    private final NotificationService service;

    public NotificationController(NotificationService service) {
        this.service = service;
    }

    @GetMapping
    public Inbox inbox(@AuthenticationPrincipal Jwt jwt) {
        return service.inbox(Long.valueOf(jwt.getSubject()));
    }

    @PostMapping("/read")
    @ResponseStatus(HttpStatus.NO_CONTENT)
    public void markAllRead(@AuthenticationPrincipal Jwt jwt) {
        service.markAllRead(Long.valueOf(jwt.getSubject()));
    }

    /** Histórico paginado com filtros: status (all, unread, read) e período (from/to, yyyy-MM-dd, inclusive). */
    @GetMapping("/history")
    public NotificationService.History history(@AuthenticationPrincipal Jwt jwt,
                                               @RequestParam(defaultValue = "all") String status,
                                               @RequestParam(required = false) @DateTimeFormat(iso = DateTimeFormat.ISO.DATE) LocalDate from,
                                               @RequestParam(required = false) @DateTimeFormat(iso = DateTimeFormat.ISO.DATE) LocalDate to,
                                               @RequestParam(required = false) Integer page,
                                               @RequestParam(required = false) Integer size) {
        return service.history(Long.valueOf(jwt.getSubject()), status, from, to, page, size);
    }

    public record Cleared(int deleted) {
    }

    /** Apaga os avisos já lidos (opcionalmente só os anteriores à data). */
    @PostMapping("/clear-read")
    public Cleared clearRead(@AuthenticationPrincipal Jwt jwt,
                             @RequestParam(required = false) @DateTimeFormat(iso = DateTimeFormat.ISO.DATE) LocalDate before) {
        return new Cleared(service.clearRead(Long.valueOf(jwt.getSubject()), before));
    }

    /** Apaga um aviso já lido. */
    @DeleteMapping("/{id}")
    @ResponseStatus(HttpStatus.NO_CONTENT)
    public void delete(@AuthenticationPrincipal Jwt jwt, @PathVariable Long id) {
        service.deleteRead(Long.valueOf(jwt.getSubject()), id);
    }
}
