package com.max.salao.expense;

import java.math.BigDecimal;
import java.time.LocalDate;
import java.util.List;

import com.max.salao.shared.NotFoundException;
import jakarta.validation.Valid;
import jakarta.validation.constraints.DecimalMin;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotNull;
import org.springframework.format.annotation.DateTimeFormat;
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
@RequestMapping("/api/expenses")
public class ExpenseController {

    public record ExpenseRequest(
            @NotBlank String description,
            @NotBlank String category,
            @NotNull @DecimalMin("0.01") BigDecimal amount,
            @NotNull LocalDate date) {
    }

    public record ExpenseResponse(Long id, String description, String category, BigDecimal amount, LocalDate date) {

        static ExpenseResponse from(Expense e) {
            return new ExpenseResponse(e.getId(), e.getDescription(), e.getCategory(), e.getAmount(), e.getDate());
        }
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
