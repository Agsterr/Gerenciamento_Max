package com.max.salao.professional;

import java.util.List;
import java.util.Optional;

import jakarta.persistence.LockModeType;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Lock;
import org.springframework.data.jpa.repository.Query;

public interface ProfessionalRepository extends JpaRepository<Professional, Long> {

    List<Professional> findAllByOrderByName();

    List<Professional> findByActiveTrueOrderByName();

    /** Trava a linha do profissional para evitar dois agendamentos simultâneos no mesmo horário. */
    @Lock(LockModeType.PESSIMISTIC_WRITE)
    @Query("select p from Professional p where p.id = :id")
    Optional<Professional> findByIdForUpdate(Long id);
}
