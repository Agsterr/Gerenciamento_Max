package com.max.salao.customer;

import java.util.List;
import java.util.Optional;

import org.springframework.data.domain.Limit;
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
}
