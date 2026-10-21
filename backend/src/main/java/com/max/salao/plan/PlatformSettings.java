package com.max.salao.plan;

import java.util.HashMap;
import java.util.Map;

import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

/**
 * Configurações do teste grátis, editáveis pelo administrador da plataforma (sem novo deploy).
 * Guardadas em platform_setting; valor ausente usa o padrão abaixo.
 */
@Service
public class PlatformSettings {

    /** maxPhotos: fotos do portfólio no teste grátis; maxPhotosPaid: no plano pago. */
    public record Values(int trialDays, int maxProfessionals, int maxServices, int maxCustomers,
                         String contactWhatsapp, String contactEmail, int maxPhotos, int maxPhotosPaid,
                         boolean billingEnabled, String playProductId) {
    }

    /** billingEnabled = "Cobrança na loja": enquanto desligada, o app não mostra o botão Assinar a ninguém. */
    static final Values DEFAULTS = new Values(14, 2, 10, 50, "", "", 20, 300, false, "salao_max_mensal");

    private final JdbcTemplate jdbc;

    public PlatformSettings(JdbcTemplate jdbc) {
        this.jdbc = jdbc;
    }

    @Transactional(readOnly = true)
    public Values get() {
        Map<String, String> m = new HashMap<>();
        jdbc.query("select name, value from platform_setting", rs -> {
            m.put(rs.getString(1), rs.getString(2));
        });
        return new Values(
                integer(m, "trial_days", DEFAULTS.trialDays()),
                integer(m, "max_professionals", DEFAULTS.maxProfessionals()),
                integer(m, "max_services", DEFAULTS.maxServices()),
                integer(m, "max_customers", DEFAULTS.maxCustomers()),
                m.getOrDefault("contact_whatsapp", DEFAULTS.contactWhatsapp()),
                m.getOrDefault("contact_email", DEFAULTS.contactEmail()),
                integer(m, "max_photos", DEFAULTS.maxPhotos()),
                integer(m, "max_photos_paid", DEFAULTS.maxPhotosPaid()),
                Boolean.parseBoolean(m.getOrDefault("billing_enabled", String.valueOf(DEFAULTS.billingEnabled()))),
                m.getOrDefault("play_product_id", DEFAULTS.playProductId()));
    }

    @Transactional
    public Values save(Values v) {
        put("trial_days", v.trialDays());
        put("max_professionals", v.maxProfessionals());
        put("max_services", v.maxServices());
        put("max_customers", v.maxCustomers());
        put("contact_whatsapp", v.contactWhatsapp() == null ? "" : v.contactWhatsapp().replaceAll("\\D", ""));
        put("contact_email", v.contactEmail() == null ? "" : v.contactEmail().trim());
        put("max_photos", v.maxPhotos());
        put("max_photos_paid", v.maxPhotosPaid());
        put("billing_enabled", v.billingEnabled());
        put("play_product_id", v.playProductId() == null || v.playProductId().isBlank()
                ? DEFAULTS.playProductId() : v.playProductId().trim());
        return get();
    }

    private void put(String name, Object value) {
        jdbc.update("""
                insert into platform_setting (name, value) values (?, ?)
                on conflict (name) do update set value = excluded.value""", name, String.valueOf(value));
    }

    private static int integer(Map<String, String> m, String key, int fallback) {
        try {
            return m.containsKey(key) ? Integer.parseInt(m.get(key)) : fallback;
        } catch (NumberFormatException e) {
            return fallback;
        }
    }
}
