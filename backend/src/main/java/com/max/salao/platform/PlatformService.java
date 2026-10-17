package com.max.salao.platform;

import java.time.Clock;
import java.time.LocalDateTime;
import java.util.List;
import java.util.Map;
import java.util.stream.Collectors;

import com.max.salao.auth.AppUser;
import com.max.salao.auth.AppUserRepository;
import com.max.salao.auth.Role;
import com.max.salao.platform.PlatformDtos.PlatformUser;
import com.max.salao.platform.PlatformDtos.SalonSummary;
import com.max.salao.salon.Salon;
import com.max.salao.salon.SalonRepository;
import com.max.salao.security.AccountStatusService;
import com.max.salao.shared.BusinessException;
import com.max.salao.shared.NotFoundException;
import org.springframework.data.domain.Limit;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

/** Ações do administrador da plataforma sobre salões e usuários (fora do isolamento por tenant). */
@Service
public class PlatformService {

    private static final int MAX_SALONS = 200;

    private final SalonRepository salons;
    private final AppUserRepository users;
    private final AccountStatusService statuses;
    private final Clock clock;

    public PlatformService(SalonRepository salons, AppUserRepository users, AccountStatusService statuses,
                           Clock clock) {
        this.salons = salons;
        this.users = users;
        this.statuses = statuses;
        this.clock = clock;
    }

    @Transactional(readOnly = true)
    public List<SalonSummary> listSalons(String q) {
        List<Salon> found = salons.searchAll(q == null ? "" : q.trim(), Limit.of(MAX_SALONS));
        Map<Long, Long> counts = found.isEmpty() ? Map.of()
                : users.countBySalon(found.stream().map(Salon::getId).toList()).stream()
                        .collect(Collectors.toMap(r -> (Long) r[0], r -> (Long) r[1]));
        return found.stream().map(s -> toSummary(s, counts.getOrDefault(s.getId(), 0L))).toList();
    }

    @Transactional
    public SalonSummary blockSalon(Long id, String reason) {
        Salon salon = salon(id);
        salon.setBlocked(true);
        salon.setBlockedReason(reason.trim());
        salon.setBlockedAt(LocalDateTime.now(clock));
        statuses.evictAll();
        return toSummary(salon, users.findBySalonIdOrderByName(id).size());
    }

    @Transactional
    public SalonSummary unblockSalon(Long id) {
        Salon salon = salon(id);
        salon.setBlocked(false);
        salon.setBlockedReason(null);
        salon.setBlockedAt(null);
        statuses.evictAll();
        return toSummary(salon, users.findBySalonIdOrderByName(id).size());
    }

    @Transactional(readOnly = true)
    public List<PlatformUser> listUsers(Long salonId) {
        salon(salonId);
        return users.findBySalonIdOrderByName(salonId).stream().map(PlatformService::toUser).toList();
    }

    @Transactional
    public PlatformUser blockUser(Long id, String reason) {
        AppUser user = user(id);
        user.setBlocked(true);
        user.setBlockedReason(reason.trim());
        user.setBlockedAt(LocalDateTime.now(clock));
        statuses.evictAll();
        return toUser(user);
    }

    @Transactional
    public PlatformUser unblockUser(Long id) {
        AppUser user = user(id);
        user.setBlocked(false);
        user.setBlockedReason(null);
        user.setBlockedAt(null);
        statuses.evictAll();
        return toUser(user);
    }

    private Salon salon(Long id) {
        return salons.findById(id).orElseThrow(() -> new NotFoundException("Salão não encontrado"));
    }

    private AppUser user(Long id) {
        AppUser user = users.findById(id).orElseThrow(() -> new NotFoundException("Usuário não encontrado"));
        if (user.getRole() == Role.PLATFORM_ADMIN) {
            throw new BusinessException("O administrador da plataforma não pode ser bloqueado");
        }
        return user;
    }

    private static SalonSummary toSummary(Salon s, long userCount) {
        return new SalonSummary(s.getId(), s.getName(), s.getSlug(), s.getPhone(), s.getAddress(), s.getCreatedAt(),
                userCount, s.isBlocked(), s.getBlockedReason(), s.getBlockedAt());
    }

    private static PlatformUser toUser(AppUser u) {
        return new PlatformUser(u.getId(), u.getName(), u.getEmail(), u.getRole(), u.isActive(), u.isBlocked(),
                u.getBlockedReason(), u.getBlockedAt());
    }
}
