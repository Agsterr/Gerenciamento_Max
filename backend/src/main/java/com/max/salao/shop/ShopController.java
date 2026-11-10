package com.max.salao.shop;

import java.util.List;
import java.util.Map;

import com.max.salao.shared.TenantContext;
import jakarta.validation.Valid;
import jakarta.validation.constraints.NotBlank;
import org.springframework.http.HttpStatus;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.security.oauth2.jwt.Jwt;
import org.springframework.web.bind.annotation.DeleteMapping;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.PutMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.ResponseStatus;
import org.springframework.web.bind.annotation.RestController;
import org.springframework.web.multipart.MultipartFile;

/** Loja do representante: painel dele (/api/representative/shop) e a compra pelo salão (/api/shop, só o dono). */
@RestController
public class ShopController {

    public record StatusRequest(@NotBlank String status) {
    }

    public record PaymentRequest(int amountCents, String method, String note) {
    }

    public record VisibleRequest(boolean visible) {
    }

    private final ShopService shop;

    public ShopController(ShopService shop) {
        this.shop = shop;
    }

    private long rep(Jwt jwt) {
        return shop.representativeOf(Long.parseLong(jwt.getSubject()));
    }

    // ---- representante

    @GetMapping("/api/representative/shop/products")
    public List<ShopService.ProductView> products(@AuthenticationPrincipal Jwt jwt) {
        return shop.products(rep(jwt));
    }

    @PostMapping("/api/representative/shop/products")
    @ResponseStatus(HttpStatus.CREATED)
    public ShopService.ProductView create(@AuthenticationPrincipal Jwt jwt, @RequestBody ShopService.ProductRequest req) {
        return shop.saveProduct(rep(jwt), null, req);
    }

    @PutMapping("/api/representative/shop/products/{id}")
    public ShopService.ProductView update(@AuthenticationPrincipal Jwt jwt, @PathVariable Long id, @RequestBody ShopService.ProductRequest req) {
        return shop.saveProduct(rep(jwt), id, req);
    }

    @DeleteMapping("/api/representative/shop/products/{id}")
    @ResponseStatus(HttpStatus.NO_CONTENT)
    public void delete(@AuthenticationPrincipal Jwt jwt, @PathVariable Long id) {
        shop.deleteProduct(rep(jwt), id);
    }

    @PostMapping("/api/representative/shop/products/{id}/photo")
    public ShopService.ProductView photo(@AuthenticationPrincipal Jwt jwt, @PathVariable Long id, @RequestParam("file") MultipartFile file) {
        return shop.uploadPhoto(rep(jwt), id, file);
    }

    @GetMapping("/api/representative/shop/orders")
    public List<ShopService.OrderView> orders(@AuthenticationPrincipal Jwt jwt, @RequestParam(required = false) String status) {
        return shop.repOrders(rep(jwt), status);
    }

    @GetMapping("/api/representative/shop/summary")
    public ShopService.Summary summary(@AuthenticationPrincipal Jwt jwt) {
        return shop.summary(rep(jwt));
    }

    @PutMapping("/api/representative/shop/orders/{id}/status")
    public ShopService.OrderView status(@AuthenticationPrincipal Jwt jwt, @PathVariable Long id, @Valid @RequestBody StatusRequest req) {
        return shop.setStatus(rep(jwt), id, req.status());
    }

    @PostMapping("/api/representative/shop/orders/{id}/payments")
    @ResponseStatus(HttpStatus.CREATED)
    public ShopService.OrderView pay(@AuthenticationPrincipal Jwt jwt, @PathVariable Long id, @RequestBody PaymentRequest req) {
        return shop.addPayment(rep(jwt), id, req.amountCents(), req.method(), req.note());
    }

    // ---- salão (dono)

    @GetMapping("/api/shop/catalog")
    public ShopService.Catalog catalog() {
        return shop.catalog(TenantContext.get());
    }

    @PutMapping("/api/shop/products/{id}/visible")
    @ResponseStatus(HttpStatus.NO_CONTENT)
    public void visible(@PathVariable Long id, @RequestBody VisibleRequest req) {
        shop.setVisible(TenantContext.get(), id, req.visible());
    }

    @GetMapping("/api/shop/address")
    public Map<String, Object> address() {
        return shop.salonAddress(TenantContext.get());
    }

    @PostMapping("/api/shop/orders")
    @ResponseStatus(HttpStatus.CREATED)
    public ShopService.OrderView order(@RequestBody ShopService.OrderRequest req) {
        return shop.placeOrder(TenantContext.get(), req);
    }

    @GetMapping("/api/shop/orders")
    public List<ShopService.OrderView> myOrders() {
        return shop.salonOrders(TenantContext.get());
    }

    @PostMapping("/api/shop/orders/{id}/received")
    public ShopService.OrderView received(@PathVariable Long id) {
        return shop.confirmReceipt(TenantContext.get(), id);
    }

    @PostMapping("/api/shop/orders/{id}/cancel")
    public ShopService.OrderView cancel(@PathVariable Long id) {
        return shop.cancelOwn(TenantContext.get(), id);
    }

    @GetMapping("/api/shop/balance")
    public Map<String, Object> balance() {
        return shop.salonBalance(TenantContext.get());
    }
}
