package com.max.salao.customer;

import java.util.List;
import java.util.Optional;

import org.springframework.data.domain.Limit;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;

public interface CustomerRepository extends JpaRepository<Customer, Long> {

    Optional<Customer> findByPhone(String phone);

    @Query("""
            select c from Customer c
            where lower(c.name) like lower(concat('%', :q, '%')) or c.phone like concat('%', :q, '%')
            order by c.name""")
    List<Customer> search(String q, Limit limit);

    List<Customer> findAllByOrderByName(Limit limit);

    /** Busca paginada por nome ou telefone (q e digits vazios = todos), em ordem alfabética. */
    @Query(value = """
            select c from Customer c
            where (:q = '' or lower(c.name) like lower(concat('%', :q, '%'))
                   or (:digits <> '' and c.phone like concat('%', :digits, '%')))
            order by lower(c.name), c.id""",
            countQuery = """
            select count(c) from Customer c
            where (:q = '' or lower(c.name) like lower(concat('%', :q, '%'))
                   or (:digits <> '' and c.phone like concat('%', :digits, '%')))""")
    Page<Customer> findPage(String q, String digits, Pageable pageable);

    long countByCreatedAtGreaterThanEqualAndCreatedAtLessThan(java.time.LocalDateTime from, java.time.LocalDateTime to);
}
