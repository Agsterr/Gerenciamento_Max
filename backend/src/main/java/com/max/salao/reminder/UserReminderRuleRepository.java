package com.max.salao.reminder;

import java.util.List;

import org.springframework.data.jpa.repository.JpaRepository;

public interface UserReminderRuleRepository extends JpaRepository<UserReminderRule, Long> {

    List<UserReminderRule> findByUserIdOrderById(Long userId);

    List<UserReminderRule> findAllByOrderByUserIdAscIdAsc();

    void deleteByUserId(Long userId);
}
