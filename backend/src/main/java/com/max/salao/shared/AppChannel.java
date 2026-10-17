package com.max.salao.shared;

import org.springframework.web.context.request.RequestContextHolder;
import org.springframework.web.context.request.ServletRequestAttributes;

/**
 * Canal do app que fez a requisição (header {@code X-App-Channel}, mandado pelos apps Flutter).
 * Na versão das lojas (Google Play / App Store) as mensagens não podem mandar o usuário assinar por
 * fora da loja — regra de pagamentos das duas lojas.
 */
public final class AppChannel {

    public static final String HEADER = "X-App-Channel";

    private AppChannel() {
    }

    public static boolean isStoreApp() {
        if (RequestContextHolder.getRequestAttributes() instanceof ServletRequestAttributes attrs) {
            return "play".equalsIgnoreCase(attrs.getRequest().getHeader(HEADER));
        }
        return false;
    }
}
