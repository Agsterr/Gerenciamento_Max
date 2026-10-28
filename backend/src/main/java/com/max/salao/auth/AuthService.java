package com.max.salao.auth;

import com.max.salao.plan.PlanService;
import com.max.salao.referral.ReferralService;
import java.util.List;

import com.max.salao.auth.AuthDtos.CreateUserRequest;
import com.max.salao.auth.AuthDtos.LoginRequest;
import com.max.salao.auth.AuthDtos.RegisterRequest;
import com.max.salao.auth.AuthDtos.TokenResponse;
import com.max.salao.auth.AuthDtos.UserResponse;
import com.max.salao.salon.Salon;
import com.max.salao.salon.SalonRepository;
import com.max.salao.security.JwtService;
import com.max.salao.shared.AccountBlockedException;
import com.max.salao.shared.BusinessException;
import com.max.salao.shared.NotFoundException;
import com.max.salao.shared.TenantContext;
import org.springframework.security.authentication.BadCredentialsException;
import org.springframework.security.crypto.password.PasswordEncoder;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

@Service
public class AuthService {

    private final AppUserRepository users;
    private final SalonRepository salons;
    private final PasswordEncoder passwordEncoder;
    private final JwtService jwtService;
    private final PlanService plans;
    private final ReferralService referrals;

    public AuthService(AppUserRepository users, SalonRepository salons, PasswordEncoder passwordEncoder,
                       JwtService jwtService, PlanService plans, ReferralService referrals) {
        this.plans = plans;
        this.referrals = referrals;
        this.users = users;
        this.salons = salons;
        this.passwordEncoder = passwordEncoder;
        this.jwtService = jwtService;
    }

    /** Cria um novo salão (tenant) com seu usuário dono. */
    @Transactional
    public TokenResponse register(RegisterRequest req) {
        if (salons.existsBySlug(req.slug())) {
            throw new BusinessException("Endereço (slug) já em uso");
        }
        ensureEmailFree(req.email());

        Salon salon = new Salon();
        salon.setName(req.salonName());
        salon.setSlug(req.slug());
        plans.startTrial(salon);
        // indicação por um representante (link com código): vale só no cadastro; código desconhecido é ignorado
        referrals.findIdByCode(req.referralCode()).ifPresent(salon::setReferrerId);
        salon = salons.save(salon);

        AppUser owner = newUser(salon.getId(), req.ownerName(), req.email(), req.password(), Role.OWNER);
        return token(owner, salon);
    }

    @Transactional(readOnly = true)
    public TokenResponse login(LoginRequest req) {
        AppUser user = users.findByEmailIgnoreCase(req.email())
                .filter(AppUser::isActive)
                .filter(u -> passwordEncoder.matches(req.password(), u.getPasswordHash()))
                .orElseThrow(() -> new BadCredentialsException("E-mail ou senha inválidos"));
        Salon salon = salonOf(user);
        if (user.isBlocked()) {
            throw new AccountBlockedException(user.getBlockedReason());
        }
        if (salon != null && salon.isBlocked()) {
            throw new AccountBlockedException(salon.getBlockedReason());
        }
        return token(user, salon);
    }

    @Transactional(readOnly = true)
    public UserResponse me(Long userId) {
        AppUser user = users.findById(userId).orElseThrow(() -> new NotFoundException("Usuário não encontrado"));
        return toResponse(user, salonOf(user));
    }

    /** Renova o token de quem já está logado (sessão deslizante: quem usa o app não precisa entrar de novo). */
    @Transactional(readOnly = true)
    public TokenResponse refresh(Long userId) {
        AppUser user = users.findById(userId).filter(AppUser::isActive)
                .orElseThrow(() -> new BadCredentialsException("Sessão inválida. Entre novamente."));
        return token(user, salonOf(user));
    }

    /** Nulo para o admin da plataforma. */
    private Salon salonOf(AppUser user) {
        return user.getSalonId() == null ? null : salons.findById(user.getSalonId()).orElseThrow();
    }

    @Transactional(readOnly = true)
    public List<UserResponse> listUsers() {
        Salon salon = salons.getReferenceById(TenantContext.get());
        return users.findBySalonIdOrderByName(TenantContext.get()).stream().map(u -> toResponse(u, salon)).toList();
    }

    @Transactional
    public UserResponse createUser(CreateUserRequest req) {
        if (req.role() == Role.PLATFORM_ADMIN || req.role() == Role.REPRESENTATIVE) {
            throw new BusinessException("Papel inválido");
        }
        ensureEmailFree(req.email());
        AppUser user = newUser(TenantContext.get(), req.name(), req.email(), req.password(), req.role());
        return toResponse(user, salons.getReferenceById(user.getSalonId()));
    }

    private void ensureEmailFree(String email) {
        if (users.existsByEmailIgnoreCase(email)) {
            throw new BusinessException("E-mail já cadastrado");
        }
    }

    private AppUser newUser(Long salonId, String name, String email, String password, Role role) {
        AppUser user = new AppUser();
        user.setSalonId(salonId);
        user.setName(name);
        user.setEmail(email.toLowerCase());
        user.setPasswordHash(passwordEncoder.encode(password));
        user.setRole(role);
        return users.save(user);
    }

    private TokenResponse token(AppUser user, Salon salon) {
        return new TokenResponse(jwtService.issue(user), toResponse(user, salon));
    }

    private static UserResponse toResponse(AppUser u, Salon salon) {
        return new UserResponse(u.getId(), u.getName(), u.getEmail(), u.getRole(),
                salon == null ? null : salon.getId(), salon == null ? null : salon.getSlug());
    }
}
