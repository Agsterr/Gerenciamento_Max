package com.max.salao.expense;

import java.util.List;
import java.util.Set;

/**
 * Categorias de despesa sugeridas. As fixas se repetem todo mês (aluguel, água, luz...);
 * qualquer outra, inclusive as digitadas pelo salão, conta como variável.
 */
public final class ExpenseCategories {

    public static final List<String> FIXED = List.of(
            "Aluguel", "Água", "Luz", "Internet e telefone", "Salários", "Contador", "Sistemas e assinaturas");

    public static final List<String> VARIABLE = List.of(
            "Produtos e materiais", "Cortesias (café, água, lanches)", "Marketing", "Manutenção",
            "Impostos e taxas", "Outros");

    /** Nomes antigos que também são fixos. */
    private static final Set<String> LEGACY_FIXED = Set.of("energia/água");

    private ExpenseCategories() {
    }

    public static boolean isFixed(String category) {
        if (category == null) {
            return false;
        }
        String c = category.trim().toLowerCase();
        return LEGACY_FIXED.contains(c) || FIXED.stream().anyMatch(f -> f.toLowerCase().equals(c));
    }
}
