package com.max.salao.booking;

import java.util.List;

import com.max.salao.salon.SalonRepository;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RestController;

/** Busca de salões para o app do cliente. */
@RestController
public class PublicSalonSearchController {

    public record SalonSummary(String name, String slug, String address) {
    }

    private final SalonRepository salons;

    public PublicSalonSearchController(SalonRepository salons) {
        this.salons = salons;
    }

    @GetMapping("/api/public/salons")
    public List<SalonSummary> search(@RequestParam String q) {
        String term = q.trim();
        if (term.length() < 2) {
            return List.of();
        }
        return salons.findTop20ByNameContainingIgnoreCaseOrSlugContainingIgnoreCaseOrderByName(term, term).stream()
                .map(s -> new SalonSummary(s.getName(), s.getSlug(), s.getAddress()))
                .toList();
    }
}
