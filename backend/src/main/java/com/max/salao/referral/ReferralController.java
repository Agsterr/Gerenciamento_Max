package com.max.salao.referral;

import com.max.salao.auth.AuthDtos.TokenResponse;
import com.max.salao.booking.LookupRateLimiter;
import com.max.salao.booking.PublicBookingController;
import jakarta.servlet.http.HttpServletRequest;
import jakarta.validation.Valid;
import jakarta.validation.constraints.Email;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.Size;
import org.springframework.http.HttpStatus;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.security.oauth2.jwt.Jwt;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.PutMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.ResponseStatus;
import org.springframework.web.bind.annotation.RestController;

/** Cadastro público do representante e o painel dele (papel REPRESENTATIVE, ver SecurityConfig). */
@RestController
public class ReferralController {

    public record RegisterRepresentative(@NotBlank @Size(max = 120) String name, @NotBlank @Email String email,
                                         @NotBlank @Size(min = 6, max = 100) String password,
                                         @Size(max = 120) String pixKey) {
    }

    public record PixRequest(@Size(max = 120) String pixKey) {
    }

    public record CodeInfo(boolean valid, String name) {
    }

    private final ReferralService service;
    private final LookupRateLimiter rateLimiter;

    public ReferralController(ReferralService service, LookupRateLimiter rateLimiter) {
        this.service = service;
        this.rateLimiter = rateLimiter;
    }

    @PostMapping("/api/auth/register-representative")
    @ResponseStatus(HttpStatus.CREATED)
    public TokenResponse register(@Valid @RequestBody RegisterRepresentative req, HttpServletRequest http) {
        rateLimiter.check("rep-register:" + PublicBookingController.clientIp(http));
        return service.register(req.name(), req.email(), req.password(), req.pixKey());
    }

    /** A página de cadastro do salão mostra "Indicado por Maria" quando o código existe. */
    @GetMapping("/api/public/referral/{code}")
    public CodeInfo code(@PathVariable String code) {
        return service.publicName(code).map(n -> new CodeInfo(true, n)).orElse(new CodeInfo(false, null));
    }

    @GetMapping("/api/representative/me")
    public ReferralService.Dashboard me(@AuthenticationPrincipal Jwt jwt) {
        return service.dashboard(Long.valueOf(jwt.getSubject()));
    }

    @PutMapping("/api/representative/pix")
    @ResponseStatus(HttpStatus.NO_CONTENT)
    public void pix(@AuthenticationPrincipal Jwt jwt, @Valid @RequestBody PixRequest req) {
        service.updatePix(Long.valueOf(jwt.getSubject()), req.pixKey());
    }
}
