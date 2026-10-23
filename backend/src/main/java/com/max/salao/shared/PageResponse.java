package com.max.salao.shared;

import java.util.List;
import java.util.function.Function;

import org.springframework.data.domain.Page;
import org.springframework.data.domain.PageRequest;
import org.springframework.data.domain.Sort;

/**
 * Resposta paginada das listas que podem crescer (clientes, serviços, histórico de agendamentos).
 * {@code page} começa em 0; {@code hasMore} diz se vale pedir a próxima página (rolagem infinita).
 */
public record PageResponse<T>(List<T> items, int page, int size, long total, boolean hasMore) {

    public static final int DEFAULT_SIZE = 20;
    public static final int MAX_SIZE = 100;

    public static <E, T> PageResponse<T> of(Page<E> page, Function<E, T> mapper) {
        return new PageResponse<>(page.getContent().stream().map(mapper).toList(), page.getNumber(), page.getSize(),
                page.getTotalElements(), page.hasNext());
    }

    /** Página pedida, com tamanho limitado (evita alguém pedir a tabela inteira de uma vez). */
    public static PageRequest request(Integer page, Integer size, Sort sort) {
        int s = size == null || size < 1 ? DEFAULT_SIZE : Math.min(size, MAX_SIZE);
        return PageRequest.of(Math.max(0, page == null ? 0 : page), s, sort);
    }

    public static PageRequest request(Integer page, Integer size) {
        return request(page, size, Sort.unsorted());
    }
}
