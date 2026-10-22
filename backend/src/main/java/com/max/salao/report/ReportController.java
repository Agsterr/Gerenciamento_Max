package com.max.salao.report;

import java.time.LocalDate;

import org.springframework.format.annotation.DateTimeFormat;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RestController;

@RestController
public class ReportController {

    private final ReportService service;
    private final DashboardService dashboard;

    public ReportController(ReportService service, DashboardService dashboard) {
        this.service = service;
        this.dashboard = dashboard;
    }

    @GetMapping("/api/reports/summary")
    public ReportService.Summary summary(@RequestParam @DateTimeFormat(iso = DateTimeFormat.ISO.DATE) LocalDate from,
                                         @RequestParam @DateTimeFormat(iso = DateTimeFormat.ISO.DATE) LocalDate to) {
        return service.summary(from, to);
    }

    /** Painel de atendimentos: totais, por profissional e série por dia/semana/mês (group = DAY, WEEK ou MONTH). */
    @GetMapping("/api/reports/dashboard")
    public DashboardService.Dashboard dashboard(
            @RequestParam @DateTimeFormat(iso = DateTimeFormat.ISO.DATE) LocalDate from,
            @RequestParam @DateTimeFormat(iso = DateTimeFormat.ISO.DATE) LocalDate to,
            @RequestParam(defaultValue = "DAY") DashboardService.Group group) {
        return dashboard.dashboard(from, to, group);
    }
}
