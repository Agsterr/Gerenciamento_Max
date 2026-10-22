package com.max.salao.portfolio;

import java.time.LocalDateTime;

import com.max.salao.catalog.ServiceItem;
import com.max.salao.professional.Professional;
import com.max.salao.shared.TenantEntity;
import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.FetchType;
import jakarta.persistence.JoinColumn;
import jakarta.persistence.ManyToOne;
import lombok.Getter;
import lombok.Setter;

/** Foto de um trabalho do salão (portfólio), opcionalmente ligada a um serviço e/ou profissional. */
@Getter
@Setter
@Entity
public class PortfolioPhoto extends TenantEntity {

    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "service_id")
    private ServiceItem service;

    @ManyToOne(fetch = FetchType.LAZY)
    private Professional professional;

    /** Foto de um produto (não entra na galeria de trabalhos). */
    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "product_id")
    private com.max.salao.product.Product product;

    private String caption;

    @Column(nullable = false, updatable = false)
    private String imageKey;

    @Column(nullable = false, updatable = false)
    private String thumbKey;

    @Column(nullable = false, updatable = false)
    private String imageUrl;

    @Column(nullable = false, updatable = false)
    private String thumbUrl;

    @Column(nullable = false, updatable = false)
    private int width;

    @Column(nullable = false, updatable = false)
    private int height;

    @Column(nullable = false, updatable = false)
    private long sizeBytes;

    @Column(nullable = false)
    private int position;

    @Column(nullable = false, updatable = false)
    private LocalDateTime createdAt = LocalDateTime.now();
}
