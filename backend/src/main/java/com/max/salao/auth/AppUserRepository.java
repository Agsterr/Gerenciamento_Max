package com.max.salao.auth;

import java.util.Collection;
import java.util.List;
import java.util.Optional;

import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;

public interface AppUserRepository extends JpaRepository<AppUser, Long> {

    Optional<AppUser> findByEmailIgnoreCase(String email);

    boolean existsByEmailIgnoreCase(String email);

    List<AppUser> findBySalonIdOrderByName(Long salonId);

    /** Pares [salonId, quantidade de usuários]. */
    @Query("SELECT u.salonId, COUNT(u) FROM AppUser u WHERE u.salonId IN :salonIds GROUP BY u.salonId")
    List<Object[]> countBySalon(@Param("salonIds") Collection<Long> salonIds);
}
