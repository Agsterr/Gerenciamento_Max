package com.max.salao.push;

import java.util.List;
import java.util.Optional;

import org.springframework.data.jpa.repository.JpaRepository;

public interface PushDeviceRepository extends JpaRepository<PushDevice, Long> {

    Optional<PushDevice> findByToken(String token);

    /** Celulares do app do cliente que aceitam promoções. */
    List<PushDevice> findByAppAndPromoNotificationsTrue(String app);

    List<PushDevice> findByApp(String app);

    List<PushDevice> findByAppAndCustomerId(String app, Long customerId);

    void deleteByUserId(Long userId);
}
