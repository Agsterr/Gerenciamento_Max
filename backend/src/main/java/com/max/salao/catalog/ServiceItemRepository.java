package com.max.salao.catalog;

import java.util.List;

import org.springframework.data.jpa.repository.JpaRepository;

public interface ServiceItemRepository extends JpaRepository<ServiceItem, Long> {

    List<ServiceItem> findAllByOrderByName();

    List<ServiceItem> findByActiveTrueOrderByName();
}
