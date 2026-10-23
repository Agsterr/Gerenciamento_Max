package com.max.salao.customer;

import com.max.salao.plan.PlanService;
import com.max.salao.shared.PageResponse;
import java.time.LocalDateTime;
import java.util.List;

import com.max.salao.shared.BusinessException;
import com.max.salao.shared.NotFoundException;
import jakarta.validation.Valid;
import jakarta.validation.constraints.Email;
import jakarta.validation.constraints.NotBlank;
import org.springframework.data.domain.Limit;
import org.springframework.http.HttpStatus;
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
@RequestMapping("/api/customers")
public class CustomerController {

    public record CustomerRequest(@NotBlank String name, @NotBlank String phone, @Email String email, String notes) {
    }

    /** lastSeenAt: última visita à página do salão pelo app; promoNotifications: nulo = não escolheu (ligado). */
    public record CustomerResponse(Long id, String name, String phone, String email, String notes,
                                   LocalDateTime createdAt, LocalDateTime lastSeenAt, Boolean promoNotifications) {

        public static CustomerResponse from(Customer c) {
            return new CustomerResponse(c.getId(), c.getName(), c.getPhone(), c.getEmail(), c.getNotes(),
                    c.getCreatedAt(), c.getLastSeenAt(), c.getPromoNotifications());
        }
    }

    private static final Limit MAX_RESULTS = Limit.of(100);

    private final CustomerRepository repository;
    private final PlanService plans;

    public CustomerController(CustomerRepository repository, PlanService plans) {
        this.plans = plans;
        this.repository = repository;
    }

    /**
     * Sem {@code page}: lista simples de até 100 (apps antigos). Com {@code page} (e opcionalmente
     * {@code size}, {@code q}): página com total e "tem mais", em ordem alfabética.
     */
    @GetMapping
    public Object list(@RequestParam(required = false) String q, @RequestParam(required = false) Integer page,
                       @RequestParam(required = false) Integer size) {
        if (page != null) {
            String term = q == null ? "" : q.trim();
            String digits = Customer.normalizePhone(term);
            return PageResponse.of(repository.findPage(term, digits == null ? "" : digits, PageResponse.request(page, size)),
                    CustomerResponse::from);
        }
        List<Customer> result = q == null || q.isBlank()
                ? repository.findAllByOrderByName(MAX_RESULTS)
                : repository.search(q.trim(), MAX_RESULTS);
        return result.stream().map(CustomerResponse::from).toList();
    }

    @GetMapping("/{id}")
    public CustomerResponse get(@PathVariable Long id) {
        return CustomerResponse.from(find(id));
    }

    @PostMapping
    @ResponseStatus(HttpStatus.CREATED)
    public CustomerResponse create(@Valid @RequestBody CustomerRequest req) {
        plans.checkLimit(PlanService.Resource.CUSTOMERS);
        String phone = Customer.normalizePhone(req.phone());
        if (repository.findByPhone(phone).isPresent()) {
            throw new BusinessException("Já existe cliente com esse telefone");
        }
        return CustomerResponse.from(repository.save(apply(new Customer(), req)));
    }

    @PutMapping("/{id}")
    public CustomerResponse update(@PathVariable Long id, @Valid @RequestBody CustomerRequest req) {
        return CustomerResponse.from(repository.save(apply(find(id), req)));
    }

    private Customer find(Long id) {
        return repository.findById(id).orElseThrow(() -> new NotFoundException("Cliente não encontrado"));
    }

    private static Customer apply(Customer c, CustomerRequest req) {
        c.setName(req.name());
        c.setPhone(Customer.normalizePhone(req.phone()));
        c.setEmail(req.email());
        c.setNotes(req.notes());
        return c;
    }
}
