package com.max.salao.salon;

import java.time.DayOfWeek;
import java.time.format.TextStyle;
import java.util.ArrayList;
import java.util.Comparator;
import java.util.HashSet;
import java.util.List;
import java.util.Locale;
import java.util.Set;

import com.max.salao.shared.BusinessException;
import com.max.salao.shared.NotFoundException;
import com.max.salao.shared.SalonZones;
import com.max.salao.shared.TenantContext;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

@Service
public class SalonService {

    private static final Locale PT_BR = Locale.forLanguageTag("pt-BR");

    private final SalonRepository salons;
    private final SalonZones zones;

    public SalonService(SalonRepository salons, SalonZones zones) {
        this.salons = salons;
        this.zones = zones;
    }

    /** Salão da requisição atual (tenant). */
    @Transactional(readOnly = true)
    public Salon current() {
        return salons.findById(TenantContext.get()).orElseThrow(() -> new NotFoundException("Salão não encontrado"));
    }

    @Transactional
    public Salon update(SalonDtos.SalonRequest req) {
        Salon salon = current();
        salon.setName(req.name());
        salon.setPhone(req.phone());
        salon.setAddress(req.address());
        salon.getHours().clear();
        salon.getHours().addAll(validHours(req.hours()));
        salon.setSlotMinutes(req.slotMinutes());
        if (req.reminderMode() != null) {
            salon.setReminderMode(req.reminderMode());
        }
        if (req.timezone() != null && !req.timezone().equals(salon.getTimezone())) {
            if (!SalonZones.isAllowed(req.timezone())) {
                throw new BusinessException("Fuso horário inválido");
            }
            salon.setTimezone(req.timezone());
            zones.evict(salon.getId());
        }
        return salons.save(salon);
    }

    /** Valida a grade semanal: um registro por dia, fechamento após abertura e pausa dentro do expediente. */
    static List<DayHours> validHours(List<SalonDtos.DayHoursDto> days) {
        Set<Integer> seen = new HashSet<>();
        List<DayHours> result = new ArrayList<>();
        for (SalonDtos.DayHoursDto d : days) {
            String day = DayOfWeek.of(d.dayOfWeek()).getDisplayName(TextStyle.FULL, PT_BR);
            if (!seen.add(d.dayOfWeek())) {
                throw new BusinessException("Dia repetido: " + day);
            }
            if (!d.closeTime().isAfter(d.openTime())) {
                throw new BusinessException("Em " + day + ", o fechamento deve ser depois da abertura");
            }
            boolean hasBreakStart = d.breakStart() != null, hasBreakEnd = d.breakEnd() != null;
            if (hasBreakStart != hasBreakEnd) {
                throw new BusinessException("Em " + day + ", informe início e fim da pausa");
            }
            if (hasBreakStart && (!d.breakEnd().isAfter(d.breakStart()) || d.breakStart().isBefore(d.openTime())
                    || d.breakEnd().isAfter(d.closeTime()))) {
                throw new BusinessException("Em " + day + ", a pausa deve ficar dentro do horário de funcionamento");
            }
            result.add(d.toEntity());
        }
        result.sort(Comparator.comparingInt(DayHours::getDayOfWeek));
        return result;
    }
}
