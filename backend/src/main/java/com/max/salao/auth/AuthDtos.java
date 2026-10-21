package com.max.salao.auth;

import jakarta.validation.constraints.Email;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotNull;
import jakarta.validation.constraints.Pattern;
import jakarta.validation.constraints.Size;

public final class AuthDtos {

    private AuthDtos() {
    }

    public record RegisterRequest(
            @NotBlank String salonName,
            @NotBlank @Pattern(regexp = "[a-z0-9-]{3,60}", message = "use letras minúsculas, números e hífen") String slug,
            @NotBlank String ownerName,
            @NotBlank @Email String email,
            @NotBlank @Size(min = 6) String password) {
    }

    public record LoginRequest(@NotBlank String email, @NotBlank String password) {
    }

    public record CreateUserRequest(
            @NotBlank String name,
            @NotBlank @Email String email,
            @NotBlank @Size(min = 6) String password,
            @NotNull Role role) {
    }

    public record ForgotPasswordRequest(@NotBlank @Email String email) {
    }

    public record ResetPasswordRequest(@NotBlank String token, @NotBlank @Size(min = 6, max = 100) String password) {
    }

    public record TokenResponse(String token, UserResponse user) {
    }

    public record UserResponse(Long id, String name, String email, Role role, Long salonId, String salonSlug) {
    }
}
