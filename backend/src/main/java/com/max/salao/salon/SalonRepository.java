package com.max.salao.salon;

import java.util.List;
import java.util.Optional;

import org.springframework.data.domain.Limit;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;

public interface SalonRepository extends JpaRepository<Salon, Long> {

    Optional<Salon> findBySlug(String slug);

    Optional<Salon> findByPlayPurchaseToken(String token);

    /** Salões com assinatura da Play que vencem até a data (ou sem vencimento): a rotina diária reconfere. */
    @Query("select s from Salon s where s.playPurchaseToken is not null and (s.paidUntil is null or s.paidUntil <= :limit)")
    List<Salon> playSubscribersDueUntil(@Param("limit") java.time.LocalDate limit);

    Optional<Salon> findByStripeCustomerId(String customerId);

    List<Salon> findByReferrerIdOrderByCreatedAtDesc(Long referrerId);

    boolean existsBySlug(String slug);

    /** Busca pública: ignora salões bloqueados. */
    @Query("""
            SELECT s FROM Salon s
            WHERE s.blocked = false
              AND (LOWER(s.name) LIKE LOWER(CONCAT('%', :term, '%')) OR LOWER(s.slug) LIKE LOWER(CONCAT('%', :term, '%')))
            ORDER BY s.name""")
    List<Salon> searchPublic(@Param("term") String term, Limit limit);

    /** Busca do admin da plataforma (inclui bloqueados). */
    @Query("""
            SELECT s FROM Salon s
            WHERE :term = '' OR LOWER(s.name) LIKE LOWER(CONCAT('%', :term, '%'))
               OR LOWER(s.slug) LIKE LOWER(CONCAT('%', :term, '%'))
            ORDER BY s.name""")
    List<Salon> searchAll(@Param("term") String term, Limit limit);
}
