package com.max.salao.reminder;

import org.springframework.http.HttpStatus;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.ResponseStatus;
import org.springframework.web.bind.annotation.RestController;

/** "Lembretes de amanhã/depois de amanhã" no painel e no app de gestão. */
@RestController
@RequestMapping("/api/reminders")
public class ReminderController {

    private final ReminderService service;

    public ReminderController(ReminderService service) {
        this.service = service;
    }

    @GetMapping
    public ReminderService.Reminders list() {
        return service.list();
    }

    @PostMapping("/{appointmentId}/sent")
    @ResponseStatus(HttpStatus.NO_CONTENT)
    public void sent(@PathVariable Long appointmentId) {
        service.markSent(appointmentId);
    }
}
