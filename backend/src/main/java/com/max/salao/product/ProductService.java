package com.max.salao.product;

import java.math.BigDecimal;

import com.max.salao.shared.BusinessException;
import com.max.salao.shared.NotFoundException;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

@Service
public class ProductService {

    private final ProductRepository products;
    private final StockMovementRepository movements;

    public ProductService(ProductRepository products, StockMovementRepository movements) {
        this.products = products;
        this.movements = movements;
    }

    public Product find(Long id) {
        return products.findById(id).orElseThrow(() -> new NotFoundException("Produto não encontrado"));
    }

    /**
     * Registra uma movimentação e atualiza o estoque.
     *
     * @param unitValue custo unitário (entrada) ou preço unitário (venda); se nulo usa o cadastro do produto
     */
    @Transactional
    public StockMovement move(Long productId, StockMovement.Type type, BigDecimal quantity, BigDecimal unitValue,
                              Long appointmentId) {
        if (quantity == null || quantity.signum() <= 0) {
            throw new BusinessException("Quantidade deve ser maior que zero");
        }
        Product product = find(productId);

        StockMovement m = new StockMovement();
        m.setProduct(product);
        m.setType(type);
        m.setQuantity(quantity);
        m.setAppointmentId(appointmentId);

        if (type == StockMovement.Type.IN) {
            BigDecimal cost = unitValue != null ? unitValue : product.getCostPrice();
            m.setUnitCost(cost);
            product.setCostPrice(cost);
            product.setStock(product.getStock().add(quantity));
        } else {
            if (product.getStock().compareTo(quantity) < 0) {
                throw new BusinessException("Estoque insuficiente de " + product.getName());
            }
            m.setUnitCost(product.getCostPrice());
            if (type == StockMovement.Type.SALE) {
                m.setUnitPrice(unitValue != null ? unitValue : product.getSalePrice());
            }
            product.setStock(product.getStock().subtract(quantity));
        }
        return movements.save(m);
    }
}
