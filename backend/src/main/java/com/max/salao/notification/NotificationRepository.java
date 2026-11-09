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

    /**
     * Histórico com filtros: {@code status} = all | unread | read e período [from, to). O período vem sempre preenchido
     * (o serviço usa limites muito largos quando a pessoa não filtra).
     */
    @Query("""
            select n from Notification n
            where (n.userId is null or n.userId = :userId)
              and (:status = 'all' or (:status = 'unread' and n.readAt is null) or (:status = 'read' and n.readAt is not null))
              and n.createdAt >= :from and n.createdAt < :to
            order by n.createdAt desc, n.id desc""")
    org.springframework.data.domain.Page<Notification> history(Long userId, String status, LocalDateTime from, LocalDateTime to,
                                                               Pageable page);

    /** Só apaga o que já foi lido (o que ninguém viu ainda fica). */
    @Modifying
    @Query("delete from Notification n where n.id = :id and n.readAt is not null and (n.userId is null or n.userId = :userId)")
    int deleteReadById(Long userId, Long id);

    @Modifying
    @Query("delete from Notification n where n.readAt is not null and n.createdAt < :before and (n.userId is null or n.userId = :userId)")
    int deleteReadBefore(Long userId, LocalDateTime before);
}
