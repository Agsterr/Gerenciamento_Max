package com.max.salao.catalog;

import java.util.List;

import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;

public interface ServiceItemRepository extends JpaRepository<ServiceItem, Long> {

    List<ServiceItem> findAllByOrderByName();

    List<ServiceItem> findByActiveTrueOrderByName();

    /** Pacotes que têm este serviço (para recalcular o preço quando ele muda). */
    @Query("select k from ServiceItem k join k.kitItems i where i.id = :serviceId")
    List<ServiceItem> findKitsContaining(Long serviceId);
}
