package com.max.salao.salon;

import java.util.List;
import java.util.Optional;

import org.springframework.data.jpa.repository.JpaRepository;

public interface SalonRepository extends JpaRepository<Salon, Long> {

    Optional<Salon> findBySlug(String slug);

    boolean existsBySlug(String slug);

    List<Salon> findTop20ByNameContainingIgnoreCaseOrSlugContainingIgnoreCaseOrderByName(String name, String slug);
}
