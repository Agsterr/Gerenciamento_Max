package com.max.salao.platform;

import java.time.LocalDateTime;

import com.max.salao.auth.Role;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.Size;

public final class PlatformDtos {

    private PlatformDtos() {
    }

    public record SalonSummary(
            Long id,
            String name,
            String slug,
            String phone,
            String address,
            LocalDateTime createdAt,
            long userCount,
            boolean blocked,
            String blockedReason,
            LocalDateTime blockedAt) {
    }

    public record PlatformUser(
            Long id,
            String name,
            String email,
            Role role,
            boolean active,
            boolean blocked,
            String blockedReason,
            LocalDateTime blockedAt) {
    }

    public record BlockRequest(@NotBlank @Size(max = 300) String reason) {
    }
}
