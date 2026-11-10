package com.max.salao.referral;

import java.time.Duration;
import java.util.List;

import com.max.salao.shared.AbuseLimiter;
import com.max.salao.shared.TenantContext;
import jakarta.validation.Valid;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.Size;
import org.springframework.http.HttpStatus;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.security.oauth2.jwt.Jwt;
import org.springframework.web.bind.annotation.DeleteMapping;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.ResponseStatus;
import org.springframework.web.bind.annotation.RestController;

/** Convites do representante para salões que já existem (painel dele) e a resposta do salão (só o dono). */
@RestController
public class InviteController {

    public record InviteRequest(@NotBlank @Size(max = 300) String salon) {
    }

    private final InviteService invites;
    private final com.max.salao.shop.ShopService shop;
    private final AbuseLimiter abuse;

    public InviteController(InviteService invites, com.max.salao.shop.ShopService shop, AbuseLimiter abuse) {
        this.invites = invites;
        this.shop = shop;
        this.abuse = abuse;
    }

    private long rep(Jwt jwt) {
        return shop.representativeOf(Long.parseLong(jwt.getSubject()));
    }

    @GetMapping("/api/representative/invites")
    public List<InviteService.RepInvite> list(@AuthenticationPrincipal Jwt jwt) {
        return invites.list(rep(jwt));
    }

    @PostMapping("/api/representative/invites")
    @ResponseStatus(HttpStatus.CREATED)
    public InviteService.RepInvite invite(@AuthenticationPrincipal Jwt jwt, @Valid @RequestBody InviteRequest req) {
        long rep = rep(jwt);
        abuse.check("rep-invite:" + rep, 30, Duration.ofHours(1));
        return invites.invite(rep, req.salon());
    }

    @DeleteMapping("/api/representative/invites/{id}")
    @ResponseStatus(HttpStatus.NO_CONTENT)
    public void cancel(@AuthenticationPrincipal Jwt jwt, @PathVariable Long id) {
        invites.cancel(rep(jwt), id);
    }

    @GetMapping("/api/shop/invites")
    public List<InviteService.SalonInvite> forSalon() {
        return invites.forSalon(TenantContext.get());
    }

    @PostMapping("/api/shop/invites/{id}/accept")
    public InviteService.SalonInvite accept(@PathVariable Long id) {
        return invites.accept(TenantContext.get(), id);
    }

    @PostMapping("/api/shop/invites/{id}/decline")
    @ResponseStatus(HttpStatus.NO_CONTENT)
    public void decline(@PathVariable Long id) {
        invites.decline(TenantContext.get(), id);
    }
}
