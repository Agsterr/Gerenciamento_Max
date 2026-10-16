package com.max.salao.professional;

import java.math.BigDecimal;
import java.util.List;

import com.max.salao.shared.NotFoundException;
import jakarta.validation.Valid;
import jakarta.validation.constraints.DecimalMax;
import jakarta.validation.constraints.DecimalMin;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotNull;
import org.springframework.http.HttpStatus;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.PutMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.ResponseStatus;
import org.springframework.web.bind.annotation.RestController;

@RestController
@RequestMapping("/api/professionals")
public class ProfessionalController {

    public record ProfessionalRequest(
            @NotBlank String name,
            String phone,
            @NotNull @DecimalMin("0") @DecimalMax("100") BigDecimal commissionPercent,
            boolean active) {
    }

    public record ProfessionalResponse(Long id, String name, String phone, BigDecimal commissionPercent, boolean active) {

        static ProfessionalResponse from(Professional p) {
            return new ProfessionalResponse(p.getId(), p.getName(), p.getPhone(), p.getCommissionPercent(), p.isActive());
        }
    }

    private final ProfessionalRepository repository;

    public ProfessionalController(ProfessionalRepository repository) {
        this.repository = repository;
    }

    @GetMapping
    public List<ProfessionalResponse> list() {
        return repository.findAllByOrderByName().stream().map(ProfessionalResponse::from).toList();
    }

    @PostMapping
    @ResponseStatus(HttpStatus.CREATED)
    public ProfessionalResponse create(@Valid @RequestBody ProfessionalRequest req) {
        return ProfessionalResponse.from(repository.save(apply(new Professional(), req)));
    }

    @PutMapping("/{id}")
    public ProfessionalResponse update(@PathVariable Long id, @Valid @RequestBody ProfessionalRequest req) {
        Professional p = repository.findById(id).orElseThrow(() -> new NotFoundException("Profissional não encontrado"));
        return ProfessionalResponse.from(repository.save(apply(p, req)));
    }

    private static Professional apply(Professional p, ProfessionalRequest req) {
        p.setName(req.name());
        p.setPhone(req.phone());
        p.setCommissionPercent(req.commissionPercent());
        p.setActive(req.active());
        return p;
    }
}
