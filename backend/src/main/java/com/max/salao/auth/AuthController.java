package com.max.salao.auth;

import java.util.List;

import com.max.salao.auth.AuthDtos.CreateUserRequest;
import com.max.salao.auth.AuthDtos.LoginRequest;
import com.max.salao.auth.AuthDtos.RegisterRequest;
import com.max.salao.auth.AuthDtos.TokenResponse;
import com.max.salao.auth.AuthDtos.UserResponse;
import com.max.salao.booking.LookupRateLimiter;
import com.max.salao.booking.PublicBookingController;
import jakarta.servlet.http.HttpServletRequest;
import jakarta.validation.Valid;
import jakarta.validation.constraints.NotBlank;
import org.springframework.http.HttpStatus;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.security.oauth2.jwt.Jwt;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.ResponseStatus;
import org.springframework.web.bind.annotation.RestController;

@RestController
public class AuthController {

    public record DeleteAccountRequest(@NotBlank String password) {
    }

    public record DeleteAccountResponse(boolean salonDeleted) {
    }

    private final AuthService service;
    private final AccountDeletionService deletionService;
    private final PasswordResetService passwordReset;
    private final LookupRateLimiter rateLimiter;

    public AuthController(AuthService service, AccountDeletionService deletionService,
                          PasswordResetService passwordReset, LookupRateLimiter rateLimiter) {
        this.service = service;
        this.deletionService = deletionService;
        this.passwordReset = passwordReset;
        this.rateLimiter = rateLimiter;
    }

    @PostMapping("/api/auth/register")
    @ResponseStatus(HttpStatus.CREATED)
    public TokenResponse register(@Valid @RequestBody RegisterRequest req) {
        return service.register(req);
    }

    @PostMapping("/api/auth/login")
    public TokenResponse login(@Valid @RequestBody LoginRequest req) {
        return service.login(req);
    }

    /** Sempre 204, exista ou não a conta; com limite de tentativas por IP e por e-mail. */
    @PostMapping("/api/auth/forgot-password")
    @ResponseStatus(HttpStatus.NO_CONTENT)
    public void forgotPassword(@Valid @RequestBody AuthDtos.ForgotPasswordRequest req, HttpServletRequest http) {
        rateLimiter.check("reset-ip:" + PublicBookingController.clientIp(http));
        rateLimiter.check("reset-mail:" + req.email().trim().toLowerCase());
        passwordReset.request(req.email());
    }

    @PostMapping("/api/auth/reset-password")
    @ResponseStatus(HttpStatus.NO_CONTENT)
    public void resetPassword(@Valid @RequestBody AuthDtos.ResetPasswordRequest req, HttpServletRequest http) {
        rateLimiter.check("reset-ip:" + PublicBookingController.clientIp(http));
        passwordReset.reset(req.token(), req.password());
    }

    @GetMapping("/api/me")
    public UserResponse me(@AuthenticationPrincipal Jwt jwt) {
        return service.me(Long.valueOf(jwt.getSubject()));
    }

    /** Token novo com validade renovada; os apps chamam ao abrir para manter o login. */
    @PostMapping("/api/me/token")
    public TokenResponse refresh(@AuthenticationPrincipal Jwt jwt) {
        return service.refresh(Long.valueOf(jwt.getSubject()));
    }

    /** Exclui a conta do usuário logado (e o salão, se for o último dono). */
    @PostMapping("/api/me/delete")
    public DeleteAccountResponse deleteMe(@AuthenticationPrincipal Jwt jwt, @Valid @RequestBody DeleteAccountRequest req) {
        return new DeleteAccountResponse(deletionService.delete(Long.valueOf(jwt.getSubject()), req.password()));
    }

    @GetMapping("/api/users")
    public List<UserResponse> users() {
        return service.listUsers();
    }

    @PostMapping("/api/users")
    @ResponseStatus(HttpStatus.CREATED)
    public UserResponse createUser(@Valid @RequestBody CreateUserRequest req) {
        return service.createUser(req);
    }
}
