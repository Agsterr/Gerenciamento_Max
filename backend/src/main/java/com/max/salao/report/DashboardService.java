package com.max.salao.report;

import java.time.DayOfWeek;
import java.time.LocalDate;
import java.time.temporal.ChronoUnit;
import java.time.temporal.TemporalAdjusters;
import java.util.ArrayList;
import java.util.Comparator;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;
import java.util.Set;
import java.util.stream.Collectors;

import com.max.salao.appointment.Appointment;
import com.max.salao.appointment.AppointmentRepository;
import com.max.salao.appointment.AppointmentStatus;
import com.max.salao.customer.CustomerRepository;
import com.max.salao.shared.BusinessException;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

/**
 * Painel de atendimentos: quantidades (concluídos, cancelados, faltas, refações), clientes novos e que
 * voltaram, por profissional e ao longo do tempo (dia, semana ou mês), com a comparação com o período anterior.
 */
@Service
public class DashboardService {

    public enum Group { DAY, WEEK, MONTH }

    public record Counts(long total, long scheduled, long done, long canceled, long noShow, long rework,
                         long online, long newCustomers, long returningCustomers, long uniqueCustomers) {
    }

    public record ProfessionalCounts(String name, long total, long done, long canceled, long noShow, long rework,
                                     long scheduled) {
    }

    /** Um ponto da série: início do dia/semana/mês e as quantidades dele. */
    public record Bucket(LocalDate start, LocalDate end, long done, long canceled, long noShow, long scheduled) {
    }

    public record Dashboard(LocalDate from, LocalDate to, Group group, Counts totals, Counts previous,
                            LocalDate previousFrom, LocalDate previousTo,
                            List<ProfessionalCounts> byProfessional, List<Bucket> series) {
    }

    private static final long MAX_DAYS = 800;

    private final AppointmentRepository appointments;
    private final CustomerRepository customers;

    public DashboardService(AppointmentRepository appointments, CustomerRepository customers) {
        this.appointments = appointments;
        this.customers = customers;
    }

    @Transactional(readOnly = true)
    public Dashboard dashboard(LocalDate from, LocalDate to, Group group) {
        if (to.isBefore(from)) {
            throw new BusinessException("A data final deve ser igual ou depois da inicial");
        }
        long days = ChronoUnit.DAYS.between(from, to) + 1;
        if (days > MAX_DAYS) {
            throw new BusinessException("Escolha um período de até " + MAX_DAYS + " dias");
        }
        LocalDate prevTo = from.minusDays(1);
        LocalDate prevFrom = prevTo.minusDays(days - 1);

        List<Appointment> current = load(from, to);
        List<Appointment> previous = load(prevFrom, prevTo);
        return new Dashboard(from, to, group, counts(current, from, to), counts(previous, prevFrom, prevTo),
                prevFrom, prevTo, byProfessional(current), series(current, from, to, group));
    }

    private List<Appointment> load(LocalDate from, LocalDate to) {
        return appointments.findByStartAtGreaterThanEqualAndStartAtLessThanOrderByStartAt(
                from.atStartOfDay(), to.plusDays(1).atStartOfDay());
    }

    private Counts counts(List<Appointment> list, LocalDate from, LocalDate to) {
        long done = count(list, AppointmentStatus.DONE);
        long scheduled = list.stream().filter(a -> isPending(a.getStatus())).count();
        Set<Long> doneCustomers = list.stream().filter(a -> a.getStatus() == AppointmentStatus.DONE)
                .map(a -> a.getCustomer().getId()).collect(Collectors.toSet());
        // "voltou": atendido no período e já tinha atendimento concluído antes dele
        long returning = doneCustomers.isEmpty() ? 0
                : appointments.customersWithDoneBefore(from.atStartOfDay(), doneCustomers).size();
        long unique = list.stream().filter(a -> a.getStatus() != AppointmentStatus.CANCELED)
                .map(a -> a.getCustomer().getId()).distinct().count();
        return new Counts(list.size(), scheduled, done, count(list, AppointmentStatus.CANCELED),
                count(list, AppointmentStatus.NO_SHOW), list.stream().filter(Appointment::isRework).count(),
                list.stream().filter(a -> a.getSource() == Appointment.Source.ONLINE).count(),
                customers.countByCreatedAtGreaterThanEqualAndCreatedAtLessThan(from.atStartOfDay(), to.plusDays(1).atStartOfDay()),
                returning, unique);
    }

    private static boolean isPending(AppointmentStatus s) {
        return s == AppointmentStatus.SCHEDULED || s == AppointmentStatus.CONFIRMED || s == AppointmentStatus.IN_PROGRESS;
    }

    private static long count(List<Appointment> list, AppointmentStatus status) {
        return list.stream().filter(a -> a.getStatus() == status).count();
    }

    private static List<ProfessionalCounts> byProfessional(List<Appointment> list) {
        return list.stream().collect(Collectors.groupingBy(a -> a.getProfessional().getName())).entrySet().stream()
                .map(e -> new ProfessionalCounts(e.getKey(), e.getValue().size(), count(e.getValue(), AppointmentStatus.DONE),
                        count(e.getValue(), AppointmentStatus.CANCELED), count(e.getValue(), AppointmentStatus.NO_SHOW),
                        e.getValue().stream().filter(Appointment::isRework).count(),
                        e.getValue().stream().filter(a -> isPending(a.getStatus())).count()))
                .sorted(Comparator.comparingLong(ProfessionalCounts::done).reversed()
                        .thenComparing(ProfessionalCounts::name))
                .toList();
    }

    /** Pontos de dia, semana (segunda a domingo) ou mês, cortados nos limites do período escolhido. */
    private static List<Bucket> series(List<Appointment> list, LocalDate from, LocalDate to, Group group) {
        Map<LocalDate, long[]> sums = new LinkedHashMap<>();
        List<LocalDate[]> ranges = new ArrayList<>();
        LocalDate cursor = from;
        while (!cursor.isAfter(to)) {
            LocalDate end = switch (group) {
                case DAY -> cursor;
                case WEEK -> cursor.with(TemporalAdjusters.nextOrSame(DayOfWeek.SUNDAY));
                case MONTH -> cursor.with(TemporalAdjusters.lastDayOfMonth());
            };
            if (end.isAfter(to)) {
                end = to;
            }
            ranges.add(new LocalDate[] {cursor, end});
            sums.put(cursor, new long[4]);
            cursor = end.plusDays(1);
        }
        for (Appointment a : list) {
            LocalDate day = a.getStartAt().toLocalDate();
            LocalDate key = ranges.stream().filter(r -> !day.isBefore(r[0]) && !day.isAfter(r[1])).findFirst()
                    .map(r -> r[0]).orElse(null);
            if (key == null) {
                continue;
            }
            long[] s = sums.get(key);
            switch (a.getStatus()) {
                case DONE -> s[0]++;
                case CANCELED -> s[1]++;
                case NO_SHOW -> s[2]++;
                default -> s[3]++;
            }
        }
        return ranges.stream().map(r -> {
            long[] s = sums.get(r[0]);
            return new Bucket(r[0], r[1], s[0], s[1], s[2], s[3]);
        }).toList();
    }
}
