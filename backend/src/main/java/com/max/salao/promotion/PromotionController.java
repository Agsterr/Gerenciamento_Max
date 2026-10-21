package com.max.salao.promotion;

import java.math.BigDecimal;
import java.time.LocalDate;
import java.util.List;

import com.max.salao.catalog.ServiceItem;
import com.max.salao.catalog.ServiceItemRepository;
import com.max.salao.shared.BusinessException;
import com.max.salao.shared.NotFoundException;
import jakarta.validation.Valid;
import jakarta.validation.constraints.DecimalMax;
import jakarta.validation.constraints.DecimalMin;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotNull;
import jakarta.validation.constraints.Size;
import org.springframework.http.HttpStatus;
import org.springframework.web.bind.annotation.DeleteMapping;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.PutMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.ResponseStatus;
import org.springframework.web.bind.annotation.RestController;

@RestController
@RequestMapping("/api/promotions")
public class PromotionController {

    public record PromotionRequest(
            @NotBlank @Size(max = 80) String name,
            @Size(max = 300) String description,
            @NotNull @DecimalMin("1") @DecimalMax("90") BigDecimal discountPercent,
            @NotNull LocalDate startsOn,
            @NotNull LocalDate endsOn,
            boolean active,
            List<Long> serviceIds) {
    }

    public record PromotionResponse(Long id, String name, String description, BigDecimal discountPercent,
                                    LocalDate startsOn, LocalDate endsOn, boolean active, List<Long> serviceIds,
                                    List<String> serviceNames) {
    }

    private final PromotionRepository repository;
    private final ServiceItemRepository services;

    public PromotionController(PromotionRepository repository, ServiceItemRepository services) {
        this.repository = repository;
        this.services = services;
    }

    @GetMapping
    public List<PromotionResponse> list() {
        return repository.findAllByOrderByStartsOnDesc().stream().map(this::toResponse).toList();
    }

    @PostMapping
    @ResponseStatus(HttpStatus.CREATED)
    public PromotionResponse create(@Valid @RequestBody PromotionRequest req) {
        return toResponse(repository.save(apply(new Promotion(), req)));
    }

    @PutMapping("/{id}")
    public PromotionResponse update(@PathVariable Long id, @Valid @RequestBody PromotionRequest req) {
        return toResponse(repository.save(apply(find(id), req)));
    }

    @DeleteMapping("/{id}")
    @ResponseStatus(HttpStatus.NO_CONTENT)
    public void delete(@PathVariable Long id) {
        repository.delete(find(id));
    }

    private Promotion find(Long id) {
        return repository.findById(id).orElseThrow(() -> new NotFoundException("Promoção não encontrada"));
    }

    private Promotion apply(Promotion p, PromotionRequest req) {
        if (req.endsOn().isBefore(req.startsOn())) {
            throw new BusinessException("A data final deve ser igual ou depois da inicial");
        }
        p.setName(req.name().trim());
        p.setDescription(req.description() == null || req.description().isBlank() ? null : req.description().trim());
        p.setDiscountPercent(req.discountPercent());
        p.setStartsOn(req.startsOn());
        p.setEndsOn(req.endsOn());
        p.setActive(req.active());
        p.getServiceIds().clear();
        if (req.serviceIds() != null && !req.serviceIds().isEmpty()) {
            services.findAllById(req.serviceIds()).stream().map(ServiceItem::getId).forEach(p.getServiceIds()::add);
        }
        return p;
    }

    private PromotionResponse toResponse(Promotion p) {
        List<String> names = p.getServiceIds().isEmpty() ? List.of()
                : services.findAllById(p.getServiceIds()).stream().map(ServiceItem::getName).sorted().toList();
        return new PromotionResponse(p.getId(), p.getName(), p.getDescription(), p.getDiscountPercent(),
                p.getStartsOn(), p.getEndsOn(), p.isActive(), p.getServiceIds().stream().sorted().toList(), names);
    }
}
