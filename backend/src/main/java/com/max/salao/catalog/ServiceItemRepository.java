package com.max.salao.catalog;

import java.util.List;

import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;

public interface ServiceItemRepository extends JpaRepository<ServiceItem, Long> {

    List<ServiceItem> findAllByOrderByName();

    List<ServiceItem> findByActiveTrueOrderByName();

    /** Busca paginada por nome ou categoria; activeOnly esconde os desativados. */
    @Query(value = """
            select s from ServiceItem s
            where (:q = '' or lower(s.name) like lower(concat('%', :q, '%'))
                   or lower(coalesce(s.category, '')) like lower(concat('%', :q, '%')))
              and (:activeOnly = false or s.active = true)
            order by lower(s.name), s.id""",
            countQuery = """
            select count(s) from ServiceItem s
            where (:q = '' or lower(s.name) like lower(concat('%', :q, '%'))
                   or lower(coalesce(s.category, '')) like lower(concat('%', :q, '%')))
              and (:activeOnly = false or s.active = true)""")
    Page<ServiceItem> findPage(String q, boolean activeOnly, Pageable pageable);

    /** Pacotes que têm este serviço (para recalcular o preço quando ele muda). */
    @Query("select k from ServiceItem k join k.kitItems i where i.id = :serviceId")
    List<ServiceItem> findKitsContaining(Long serviceId);
}
