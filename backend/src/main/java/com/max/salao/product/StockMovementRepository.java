package com.max.salao.product;

import java.time.LocalDateTime;
import java.util.List;

import org.springframework.data.jpa.repository.EntityGraph;
import org.springframework.data.jpa.repository.JpaRepository;

public interface StockMovementRepository extends JpaRepository<StockMovement, Long> {

    @EntityGraph(attributePaths = "product")
    List<StockMovement> findByCreatedAtBetweenOrderByCreatedAtDesc(LocalDateTime from, LocalDateTime to);

    @EntityGraph(attributePaths = "product")
    List<StockMovement> findTop50ByProductIdOrderByCreatedAtDesc(Long productId);

    @EntityGraph(attributePaths = "product")
    List<StockMovement> findByAppointmentId(Long appointmentId);
}
