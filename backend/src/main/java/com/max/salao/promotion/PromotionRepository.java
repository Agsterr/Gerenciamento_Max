package com.max.salao.promotion;

import java.time.LocalDate;
import java.util.List;

import org.springframework.data.jpa.repository.JpaRepository;

public interface PromotionRepository extends JpaRepository<Promotion, Long> {

    List<Promotion> findAllByOrderByStartsOnDesc();

    /** Promoções ativas que ainda não terminaram. */
    List<Promotion> findByActiveTrueAndEndsOnGreaterThanEqualOrderByEndsOn(LocalDate day);
}
