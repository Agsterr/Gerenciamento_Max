package com.max.salao.notification;

import java.time.LocalDateTime;
import java.util.List;

import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Modifying;
import org.springframework.data.jpa.repository.Query;

public interface NotificationRepository extends JpaRepository<Notification, Long> {

    List<Notification> findTop50ByOrderByCreatedAtDesc();

    long countByReadAtIsNull();

    @Modifying
    @Query("update Notification n set n.readAt = :now where n.readAt is null")
    int markAllRead(LocalDateTime now);
}
