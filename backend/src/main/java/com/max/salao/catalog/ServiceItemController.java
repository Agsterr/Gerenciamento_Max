package com.max.salao.catalog;

import com.max.salao.plan.PlanService;
import com.max.salao.shared.PageResponse;
import java.math.BigDecimal;
import java.util.List;

import com.max.salao.professional.Professional;
import com.max.salao.professional.ProfessionalRepository;
import com.max.salao.shared.BusinessException;
import com.max.salao.shared.NotFoundException;
import org.springframework.transaction.annotation.Transactional;
import java.util.HashSet;
import jakarta.validation.Valid;
import jakarta.validation.constraints.DecimalMax;
import jakarta.validation.constraints.DecimalMin;
import jakarta.validation.constraints.Max;
import jakarta.validation.constraints.Min;
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
import org.springframework.web.bind.annotation.RequestParam;
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
            boolean active,
            @Size(max = 40) String category,
            List<Long> professionalIds,
            List<Long> kitServiceIds,
            @DecimalMin("0") @DecimalMax("90") BigDecimal kitDiscountPercent) {
    }

    public record ServiceResponse(Long id, String name, String description, int durationMinutes,
                                  BigDecimal price, BigDecimal cost, boolean active, String category,
                                  List<Long> professionalIds, List<Long> kitServiceIds, BigDecimal kitDiscountPercent,
                                  BigDecimal kitFullPrice) {

        public static ServiceResponse from(ServiceItem s) {
            return new ServiceResponse(s.getId(), s.getName(), s.getDescription(), s.getDurationMinutes(),
                    s.getPrice(), s.getCost(), s.isActive(), s.getCategory(),
                    s.getProfessionalIds().stream().sorted().toList(),
                    s.getKitItems().stream().map(ServiceItem::getId).sorted().toList(),
                    s.isKit() ? s.getKitDiscountPercent() : null, s.isKit() ? s.kitFullPrice() : null);
        }
    }

    private final ServiceItemRepository repository;
    private final PlanService plans;
    private final ProfessionalRepository professionals;
    private final com.max.salao.portfolio.PortfolioService portfolio;

    public ServiceItemController(ServiceItemRepository repository, PlanService plans, ProfessionalRepository professionals,
                                 com.max.salao.portfolio.PortfolioService portfolio) {
        this.portfolio = portfolio;
        this.professionals = professionals;
        this.plans = plans;
        this.repository = repository;
    }

    /** Sem {@code page}: todos (os apps usam para escolher o serviço). Com {@code page}: página com busca {@code q}. */
    @GetMapping
    public Object list(@RequestParam(required = false) String q, @RequestParam(required = false) Boolean active,
                       @RequestParam(required = false) Integer page, @RequestParam(required = false) Integer size) {
        if (page != null) {
            String term = q == null ? "" : q.trim();
            return PageResponse.of(repository.findPage(term, Boolean.TRUE.equals(active), PageResponse.request(page, size)),
                    ServiceResponse::from);
        }
        return repository.findAllByOrderByName().stream().map(ServiceResponse::from).toList();
    }

    @PostMapping
    @ResponseStatus(HttpStatus.CREATED)
    public ServiceResponse create(@Valid @RequestBody ServiceRequest req) {
        plans.checkLimit(PlanService.Resource.SERVICES);
        return ServiceResponse.from(repository.save(apply(new ServiceItem(), req)));
    }

    @PutMapping("/{id}")
    @Transactional
    public ServiceResponse update(@PathVariable Long id, @Valid @RequestBody ServiceRequest req) {
        ServiceItem s = repository.findById(id).orElseThrow(() -> new NotFoundException("Serviço não encontrado"));
        ServiceItem saved = repository.save(apply(s, req));
        // pacotes que usam este serviço acompanham o novo preço/duração
        for (ServiceItem kit : repository.findKitsContaining(saved.getId())) {
            kit.recomputeKit();
        }
        return ServiceResponse.from(saved);
    }

    /**
     * Exclui o serviço (ou pacote) que nunca foi usado. Com atendimentos no histórico ou dentro de um pacote não dá
     * para apagar: o histórico e o financeiro dependem dele; nesse caso o caminho é desativar (Editar, desmarcar Ativo).
     */
    @DeleteMapping("/{id}")
    @ResponseStatus(HttpStatus.NO_CONTENT)
    @Transactional
    public void delete(@PathVariable Long id) {
        ServiceItem s = repository.findById(id).orElseThrow(() -> new NotFoundException("Serviço não encontrado"));
        if (!s.isKit() && !repository.findKitsContaining(id).isEmpty()) {
            throw new BusinessException("Este serviço faz parte de um pacote. Tire-o do pacote (ou apague o pacote) antes de excluir.");
        }
        var files = portfolio.removeRows(portfolio.photosOfService(id));
        try {
            repository.delete(s);
            repository.flush();
        } catch (org.springframework.dao.DataIntegrityViolationException e) {
            throw new BusinessException("Este serviço já tem atendimentos no histórico e não pode ser apagado. "
                    + "Para tirá-lo do agendamento, edite e desmarque \"Ativo\".");
        }
        portfolio.deleteFiles(files);
    }

    private ServiceItem apply(ServiceItem s, ServiceRequest req) {
        s.setName(req.name());
        s.setDescription(req.description());
        s.setDurationMinutes(req.durationMinutes());
        s.setPrice(req.price());
        s.setCost(req.cost());
        s.setActive(req.active());
        s.setCategory(req.category() == null || req.category().isBlank() ? null : req.category().trim());
        // só profissionais deste salão (a consulta já filtra pelo tenant)
        s.getProfessionalIds().clear();
        if (req.professionalIds() != null && !req.professionalIds().isEmpty()) {
            professionals.findAllById(req.professionalIds()).stream().map(Professional::getId).forEach(s.getProfessionalIds()::add);
        }
        s.getKitItems().clear();
        if (req.kitServiceIds() != null && !req.kitServiceIds().isEmpty()) {
            // pacote só de serviços comuns (sem pacote dentro de pacote)
            repository.findAllById(req.kitServiceIds()).stream()
                    .filter(i -> !i.isKit() && !i.getId().equals(s.getId()))
                    .forEach(s.getKitItems()::add);
            if (s.getKitItems().size() < 2) {
                throw new BusinessException("Um pacote precisa de pelo menos 2 serviços");
            }
            s.setKitDiscountPercent(req.kitDiscountPercent() == null ? BigDecimal.ZERO : req.kitDiscountPercent());
            if (s.getCategory() == null) {
                s.setCategory("Pacotes");
            }
            s.recomputeKit();
        } else {
            s.setKitDiscountPercent(null);
        }
        return s;
    }
}
