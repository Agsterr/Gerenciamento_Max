package com.max.salao.auth;

import java.util.List;

import com.max.salao.auth.AuthDtos.CreateUserRequest;
import com.max.salao.auth.AuthDtos.LoginRequest;
import com.max.salao.auth.AuthDtos.RegisterRequest;
import com.max.salao.auth.AuthDtos.TokenResponse;
import com.max.salao.auth.AuthDtos.UserResponse;
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

    public AuthController(AuthService service, AccountDeletionService deletionService) {
        this.service = service;
        this.deletionService = deletionService;
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
