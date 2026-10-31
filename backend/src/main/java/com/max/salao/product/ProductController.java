package com.max.salao.product;

import java.math.BigDecimal;
import java.time.LocalDateTime;
import java.util.List;

import jakarta.validation.Valid;
import jakarta.validation.constraints.DecimalMin;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotNull;
import org.springframework.http.HttpStatus;
import org.springframework.web.bind.annotation.DeleteMapping;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.PutMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.ResponseStatus;
import org.springframework.web.bind.annotation.RestController;

@RestController
@RequestMapping("/api/products")
public class ProductController {

    public record ProductRequest(
            @NotBlank String name,
            @NotNull @DecimalMin("0") BigDecimal costPrice,
            @NotNull @DecimalMin("0") BigDecimal salePrice,
            @NotNull @DecimalMin("0") BigDecimal minStock,
            @NotBlank String unit,
            boolean active,
            @DecimalMin("0") BigDecimal markupPercent,
            Boolean showcase) {
    }

    public record ProductResponse(Long id, String name, BigDecimal costPrice, BigDecimal salePrice, BigDecimal stock,
                                  BigDecimal minStock, String unit, boolean active, boolean lowStock,
                                  BigDecimal markupPercent, String photoUrl, boolean showcase) {

        public static ProductResponse from(Product p) {
            return from(p, null);
        }

        public static ProductResponse from(Product p, String photoUrl) {
            return new ProductResponse(p.getId(), p.getName(), p.getCostPrice(), p.getSalePrice(), p.getStock(),
                    p.getMinStock(), p.getUnit(), p.isActive(), p.isLowStock(), p.getMarkupPercent(), photoUrl, p.isShowcase());
        }
    }

    public record MovementRequest(@NotNull StockMovement.Type type, @NotNull BigDecimal quantity, BigDecimal unitValue) {
    }

    public record MovementResponse(Long id, Long productId, String productName, StockMovement.Type type,
                                   BigDecimal quantity, BigDecimal unitCost, BigDecimal unitPrice,
                                   Long appointmentId, LocalDateTime createdAt) {

        public static MovementResponse from(StockMovement m) {
            return new MovementResponse(m.getId(), m.getProduct().getId(), m.getProduct().getName(), m.getType(),
                    m.getQuantity(), m.getUnitCost(), m.getUnitPrice(), m.getAppointmentId(), m.getCreatedAt());
        }
    }

    private final ProductRepository repository;
    private final StockMovementRepository movements;
    private final ProductService service;
    private final com.max.salao.portfolio.PortfolioPhotoRepository photos;
    private final com.max.salao.portfolio.PortfolioService portfolio;

    public ProductController(ProductRepository repository, StockMovementRepository movements, ProductService service,
                             com.max.salao.portfolio.PortfolioPhotoRepository photos,
                             com.max.salao.portfolio.PortfolioService portfolio) {
        this.portfolio = portfolio;
        this.photos = photos;
        this.repository = repository;
        this.movements = movements;
        this.service = service;
    }

    @GetMapping
    public List<ProductResponse> list() {
        // miniatura = primeira foto de cada produto
        java.util.Map<Long, String> thumbs = new java.util.HashMap<>();
        for (Object[] row : photos.productThumbs()) {
            thumbs.putIfAbsent((Long) row[0], (String) row[1]);
        }
        return repository.findAllByOrderByName().stream().map(p -> ProductResponse.from(p, thumbs.get(p.getId()))).toList();
    }

    @PostMapping
    @ResponseStatus(HttpStatus.CREATED)
    public ProductResponse create(@Valid @RequestBody ProductRequest req) {
        return ProductResponse.from(repository.save(apply(new Product(), req)));
    }

    @PutMapping("/{id}")
    public ProductResponse update(@PathVariable Long id, @Valid @RequestBody ProductRequest req) {
        return ProductResponse.from(repository.save(apply(service.find(id), req)));
    }

    /** Exclui o produto sem movimentação de estoque; com histórico o caminho é desativar (Editar, desmarcar Ativo). */
    @DeleteMapping("/{id}")
    @ResponseStatus(HttpStatus.NO_CONTENT)
    @org.springframework.transaction.annotation.Transactional
    public void delete(@PathVariable Long id) {
        Product p = service.find(id);
        var files = portfolio.removeRows(portfolio.photosOfProduct(id));
        try {
            repository.delete(p);
            repository.flush();
        } catch (org.springframework.dao.DataIntegrityViolationException e) {
            throw new com.max.salao.shared.BusinessException("Este produto já tem movimentações de estoque e não pode ser apagado. "
                    + "Para tirá-lo da lista, edite e desmarque \"Ativo\".");
        }
        portfolio.deleteFiles(files);
    }

    @GetMapping("/{id}/movements")
    public List<MovementResponse> movements(@PathVariable Long id) {
        return movements.findTop50ByProductIdOrderByCreatedAtDesc(id).stream().map(MovementResponse::from).toList();
    }

    @PostMapping("/{id}/movements")
    @ResponseStatus(HttpStatus.CREATED)
    public MovementResponse move(@PathVariable Long id, @Valid @RequestBody MovementRequest req) {
        return MovementResponse.from(service.move(id, req.type(), req.quantity(), req.unitValue(), null));
    }

    private static Product apply(Product p, ProductRequest req) {
        p.setName(req.name());
        p.setCostPrice(req.costPrice());
        p.setSalePrice(req.salePrice());
        p.setMinStock(req.minStock());
        p.setUnit(req.unit());
        p.setActive(req.active());
        p.setMarkupPercent(req.markupPercent());
        p.setShowcase(req.showcase() == null || req.showcase());
        return p;
    }
}
