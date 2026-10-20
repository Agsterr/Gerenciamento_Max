package com.max.salao.portfolio;

import java.util.List;

import org.springframework.data.jpa.repository.EntityGraph;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;

public interface PortfolioPhotoRepository extends JpaRepository<PortfolioPhoto, Long> {

    @EntityGraph(attributePaths = {"service", "professional"})
    List<PortfolioPhoto> findAllByOrderByPositionAscIdDesc();

    @EntityGraph(attributePaths = {"service", "professional"})
    List<PortfolioPhoto> findByServiceIdOrderByPositionAscIdDesc(Long serviceId);

    @Query("select coalesce(min(p.position), 0) from PortfolioPhoto p")
    int minPosition();
}
