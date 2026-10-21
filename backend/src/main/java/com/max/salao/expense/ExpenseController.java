package com.max.salao.expense;

import java.math.BigDecimal;
import java.time.LocalDate;
import java.time.YearMonth;
import java.util.ArrayList;
import java.util.List;

import com.max.salao.shared.NotFoundException;
import jakarta.validation.Valid;
import jakarta.validation.constraints.DecimalMin;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotNull;
import org.springframework.format.annotation.DateTimeFormat;
import org.springframework.http.HttpStatus;
import org.springframework.transaction.annotation.Transactional;
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
@RequestMapping("/api/expenses")
public class ExpenseController {

    public record ExpenseRequest(
            @NotBlank String description,
            @NotBlank String category,
            @NotNull @DecimalMin("0.01") BigDecimal amount,
            @NotNull LocalDate date) {
    }

    /** fixed: aluguel, água, luz... (se repetem todo mês). */
    public record ExpenseResponse(Long id, String description, String category, BigDecimal amount, LocalDate date,
                                  boolean fixed) {

        static ExpenseResponse from(Expense e) {
            return new ExpenseResponse(e.getId(), e.getDescription(), e.getCategory(), e.getAmount(), e.getDate(),
                    ExpenseCategories.isFixed(e.getCategory()));
        }
    }

    public record Categories(List<String> fixed, List<String> variable) {
    }

    public record RepeatRequest(@NotNull YearMonth month) {
    }

    public record RepeatResponse(int created) {
    }

    private final ExpenseRepository repository;

    public ExpenseController(ExpenseRepository repository) {
        this.repository = repository;
    }

    @GetMapping
    public List<ExpenseResponse> list(@RequestParam @DateTimeFormat(iso = DateTimeFormat.ISO.DATE) LocalDate from,
                                      @RequestParam @DateTimeFormat(iso = DateTimeFormat.ISO.DATE) LocalDate to) {
        return repository.findByDateBetweenOrderByDateDesc(from, to).stream().map(ExpenseResponse::from).toList();
    }

    @GetMapping("/categories")
    public Categories categories() {
        return new Categories(ExpenseCategories.FIXED, ExpenseCategories.VARIABLE);
    }

    /**
     * Copia as despesas fixas do mês anterior (aluguel, água, luz...) para {@code month}, no mesmo dia.
     * Não duplica: pula o que já foi lançado no mês com a mesma descrição e categoria.
     */
    @PostMapping("/repeat-fixed")
    @Transactional
    public RepeatResponse repeatFixed(@Valid @RequestBody RepeatRequest req) {
        YearMonth previous = req.month().minusMonths(1);
        List<Expense> existing = new ArrayList<>(
                repository.findByDateBetweenOrderByDateDesc(req.month().atDay(1), req.month().atEndOfMonth()));
        int created = 0;
        for (Expense e : repository.findByDateBetweenOrderByDateDesc(previous.atDay(1), previous.atEndOfMonth())) {
            boolean already = existing.stream().anyMatch(x -> x.getCategory().equalsIgnoreCase(e.getCategory())
                    && x.getDescription().equalsIgnoreCase(e.getDescription()));
            if (!ExpenseCategories.isFixed(e.getCategory()) || already) {
                continue;
            }
            Expense copy = new Expense();
            copy.setDescription(e.getDescription());
            copy.setCategory(e.getCategory());
            copy.setAmount(e.getAmount());
            copy.setDate(req.month().atDay(Math.min(e.getDate().getDayOfMonth(), req.month().lengthOfMonth())));
            repository.save(copy);
            existing.add(copy);
            created++;
        }
        return new RepeatResponse(created);
    }

    @PostMapping
    @ResponseStatus(HttpStatus.CREATED)
    public ExpenseResponse create(@Valid @RequestBody ExpenseRequest req) {
        return ExpenseResponse.from(repository.save(apply(new Expense(), req)));
    }

    @PutMapping("/{id}")
    public ExpenseResponse update(@PathVariable Long id, @Valid @RequestBody ExpenseRequest req) {
        return ExpenseResponse.from(repository.save(apply(find(id), req)));
    }

    @DeleteMapping("/{id}")
    @ResponseStatus(HttpStatus.NO_CONTENT)
    public void delete(@PathVariable Long id) {
        repository.delete(find(id));
    }

    private Expense find(Long id) {
        return repository.findById(id).orElseThrow(() -> new NotFoundException("Despesa não encontrada"));
    }

    private static Expense apply(Expense e, ExpenseRequest req) {
        e.setDescription(req.description());
        e.setCategory(req.category());
        e.setAmount(req.amount());
        e.setDate(req.date());
        return e;
    }
}
