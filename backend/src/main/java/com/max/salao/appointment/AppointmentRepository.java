package com.max.salao.appointment;

import java.time.LocalDateTime;
import java.util.Collection;
import java.util.List;
import java.util.Optional;

import org.springframework.data.jpa.repository.EntityGraph;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;

public interface AppointmentRepository extends JpaRepository<Appointment, Long> {

    @EntityGraph(attributePaths = {"customer", "professional", "service"})
    List<Appointment> findByStartAtGreaterThanEqualAndStartAtLessThanOrderByStartAt(LocalDateTime from,
                                                                                    LocalDateTime to);

    @EntityGraph(attributePaths = {"customer", "professional", "service"})
    List<Appointment> findTop50ByCustomerIdOrderByStartAtDesc(Long customerId);

    @EntityGraph(attributePaths = {"customer", "professional", "service"})
    Optional<Appointment> findWithDetailsById(Long id);

    @EntityGraph(attributePaths = {"customer", "professional", "service"})
    Optional<Appointment> findByPublicToken(String token);

    /** Agendamentos que ocupam a agenda e cruzam o intervalo [from, to). */
    @Query("""
            select a from Appointment a
            where a.status not in :freeing and a.startAt < :to and a.endAt > :from""")
    List<Appointment> findBusy(LocalDateTime from, LocalDateTime to, Collection<AppointmentStatus> freeing);
}
