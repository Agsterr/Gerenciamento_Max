package com.max.salao.salon;

import com.max.salao.shared.BusinessException;
import com.max.salao.shared.NotFoundException;
import com.max.salao.shared.TenantContext;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

@Service
public class SalonService {

    private final SalonRepository salons;

    public SalonService(SalonRepository salons) {
        this.salons = salons;
    }

    /** Salão da requisição atual (tenant). */
    @Transactional(readOnly = true)
    public Salon current() {
        return salons.findById(TenantContext.get()).orElseThrow(() -> new NotFoundException("Salão não encontrado"));
    }

    @Transactional
    public Salon update(SalonDtos.SalonRequest req) {
        Salon salon = current();
        if (!req.closeTime().isAfter(req.openTime())) {
            throw new BusinessException("Horário de fechamento deve ser após a abertura");
        }
        salon.setName(req.name());
        salon.setPhone(req.phone());
        salon.setAddress(req.address());
        salon.setOpenTime(req.openTime());
        salon.setCloseTime(req.closeTime());
        salon.setWorkDays(req.workDays());
        salon.setSlotMinutes(req.slotMinutes());
        return salons.save(salon);
    }
}
