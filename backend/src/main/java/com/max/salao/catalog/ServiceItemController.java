package com.max.salao.catalog;

import com.max.salao.plan.PlanService;
import java.math.BigDecimal;
import java.util.List;

import com.max.salao.shared.NotFoundException;
import jakarta.validation.Valid;
import jakarta.validation.constraints.DecimalMin;
import jakarta.validation.constraints.Max;
import jakarta.validation.constraints.Min;
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
@RequestMapping("/api/services")
public class ServiceItemController {

    public record ServiceRequest(
            @NotBlank String name,
            String description,
            @Min(5) @Max(600) int durationMinutes,
            @NotNull @DecimalMin("0") BigDecimal price,
            @NotNull @DecimalMin("0") BigDecimal cost,
            boolean active) {
    }

    public record ServiceResponse(Long id, String name, String description, int durationMinutes,
                                  BigDecimal price, BigDecimal cost, boolean active) {

        public static ServiceResponse from(ServiceItem s) {
            return new ServiceResponse(s.getId(), s.getName(), s.getDescription(), s.getDurationMinutes(),
                    s.getPrice(), s.getCost(), s.isActive());
        }
    }

    private final ServiceItemRepository repository;
    private final PlanService plans;

    public ServiceItemController(ServiceItemRepository repository, PlanService plans) {
        this.plans = plans;
        this.repository = repository;
    }

    @GetMapping
    public List<ServiceResponse> list() {
        return repository.findAllByOrderByName().stream().map(ServiceResponse::from).toList();
    }

    @PostMapping
    @ResponseStatus(HttpStatus.CREATED)
    public ServiceResponse create(@Valid @RequestBody ServiceRequest req) {
        plans.checkLimit(PlanService.Resource.SERVICES);
        return ServiceResponse.from(repository.save(apply(new ServiceItem(), req)));
    }

    @PutMapping("/{id}")
    public ServiceResponse update(@PathVariable Long id, @Valid @RequestBody ServiceRequest req) {
        ServiceItem s = repository.findById(id).orElseThrow(() -> new NotFoundException("Serviço não encontrado"));
        return ServiceResponse.from(repository.save(apply(s, req)));
    }

    private static ServiceItem apply(ServiceItem s, ServiceRequest req) {
        s.setName(req.name());
        s.setDescription(req.description());
        s.setDurationMinutes(req.durationMinutes());
        s.setPrice(req.price());
        s.setCost(req.cost());
        s.setActive(req.active());
        return s;
    }
}
