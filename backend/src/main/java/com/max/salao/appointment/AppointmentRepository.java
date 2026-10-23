package com.max.salao.appointment;

import java.time.LocalDateTime;
import java.util.Collection;
import java.util.List;
import java.util.Optional;

import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;
import org.springframework.data.jpa.repository.EntityGraph;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;

public interface AppointmentRepository extends JpaRepository<Appointment, Long> {

    @EntityGraph(attributePaths = {"customer", "professional", "service", "promotion"})
    List<Appointment> findByStartAtGreaterThanEqualAndStartAtLessThanOrderByStartAt(LocalDateTime from,
                                                                                    LocalDateTime to);

    @EntityGraph(attributePaths = {"customer", "professional", "service", "promotion"})
    List<Appointment> findTop50ByCustomerIdOrderByStartAtDesc(Long customerId);

    @EntityGraph(attributePaths = {"customer", "professional", "service", "promotion"})
    Optional<Appointment> findWithDetailsById(Long id);

    @EntityGraph(attributePaths = {"customer", "professional", "service", "promotion"})
    Optional<Appointment> findByPublicToken(String token);

    /** Clientes (entre os dados) que já tiveram atendimento concluído antes de {@code before}. */
    @Query("""
            select distinct a.customer.id from Appointment a
            where a.status = com.max.salao.appointment.AppointmentStatus.DONE and a.startAt < :before
              and a.customer.id in :ids""")
    List<Long> customersWithDoneBefore(LocalDateTime before, Collection<Long> ids);

    /**
     * Busca paginada de agendamentos: nome ou telefone do cliente, serviço ou profissional (q vazio = todos),
     * status e período. A ordem (startAt) vem do Pageable.
     */
    @Query(value = """
            select a from Appointment a join a.customer c join a.service s join a.professional p
            where a.status in :statuses and a.startAt >= :from and a.startAt < :to
              and (:q = '' or lower(c.name) like lower(concat('%', :q, '%'))
                   or (:digits <> '' and c.phone like concat('%', :digits, '%'))
                   or lower(s.name) like lower(concat('%', :q, '%'))
                   or lower(p.name) like lower(concat('%', :q, '%')))""",
            countQuery = """
            select count(a) from Appointment a join a.customer c join a.service s join a.professional p
            where a.status in :statuses and a.startAt >= :from and a.startAt < :to
              and (:q = '' or lower(c.name) like lower(concat('%', :q, '%'))
                   or (:digits <> '' and c.phone like concat('%', :digits, '%'))
                   or lower(s.name) like lower(concat('%', :q, '%'))
                   or lower(p.name) like lower(concat('%', :q, '%')))""")
    @EntityGraph(attributePaths = {"customer", "professional", "service"})
    Page<Appointment> search(String q, String digits, Collection<AppointmentStatus> statuses, LocalDateTime from,
                             LocalDateTime to, Pageable pageable);

    /** Agendamentos que ocupam a agenda e cruzam o intervalo [from, to). */
    @Query("""
            select a from Appointment a
            where (a.status not in :freeing or a.slotHeld = true) and a.startAt < :to and a.endAt > :from""")
    List<Appointment> findBusy(LocalDateTime from, LocalDateTime to, Collection<AppointmentStatus> freeing);
}
