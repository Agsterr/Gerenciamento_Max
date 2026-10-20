package com.max.salao.notification;

import java.time.LocalDateTime;
import java.util.List;

import org.springframework.data.domain.Pageable;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Modifying;
import org.springframework.data.jpa.repository.Query;

public interface NotificationRepository extends JpaRepository<Notification, Long> {

    /** Avisos da equipe toda mais os só deste usuário. */
    @Query("select n from Notification n where n.userId is null or n.userId = :userId order by n.createdAt desc, n.id desc")
    List<Notification> findVisible(Long userId, Pageable page);

    @Query("select count(n) from Notification n where n.readAt is null and (n.userId is null or n.userId = :userId)")
    long countUnread(Long userId);

    boolean existsByTypeAndCreatedAtGreaterThanEqual(Notification.Type type, LocalDateTime since);

    boolean existsByDedupKey(String dedupKey);

    @Modifying
    @Query("update Notification n set n.readAt = :now where n.readAt is null and (n.userId is null or n.userId = :userId)")
    int markAllRead(Long userId, LocalDateTime now);
}
