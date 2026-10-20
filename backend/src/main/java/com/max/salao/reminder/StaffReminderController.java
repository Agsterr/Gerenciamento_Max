package com.max.salao.reminder;

import java.util.List;

import com.max.salao.reminder.StaffReminderService.RuleDto;
import com.max.salao.reminder.StaffReminderService.Settings;
import com.max.salao.reminder.StaffReminderService.Upcoming;
import jakarta.validation.Valid;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.security.oauth2.jwt.Jwt;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PutMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RestController;

/** "Meus lembretes": antecedência e horário dos avisos de atendimento de cada usuário. */
@RestController
@RequestMapping("/api/me/reminders")
public class StaffReminderController {

    public record SettingsRequest(Long professionalId, List<@Valid RuleDto> rules) {
    }

    private final StaffReminderService service;

    public StaffReminderController(StaffReminderService service) {
        this.service = service;
    }

    @GetMapping
    public Settings get(@AuthenticationPrincipal Jwt jwt) {
        return service.get(userId(jwt));
    }

    @PutMapping
    public Settings save(@AuthenticationPrincipal Jwt jwt, @Valid @RequestBody SettingsRequest req) {
        return service.save(userId(jwt), new Settings(req.professionalId(), req.rules()));
    }

    /** Lembretes dos próximos dias, para o app agendar notificações no aparelho. */
    @GetMapping("/upcoming")
    public List<Upcoming> upcoming(@AuthenticationPrincipal Jwt jwt, @RequestParam(defaultValue = "7") int days) {
        return service.upcoming(userId(jwt), Math.max(1, Math.min(days, 14)));
    }

    private static Long userId(Jwt jwt) {
        return Long.valueOf(jwt.getSubject());
    }
}
