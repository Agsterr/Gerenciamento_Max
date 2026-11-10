package com.max.salao.shop;

import java.sql.Date;
import java.sql.ResultSet;
import java.sql.SQLException;
import java.sql.Statement;
import java.sql.Timestamp;
import java.time.Clock;
import java.time.LocalDate;
import java.time.LocalDateTime;
import java.util.ArrayList;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;
import java.util.Set;
import java.util.stream.Collectors;

import com.max.salao.portfolio.ShopPhotos;
import com.max.salao.shared.BusinessException;
import com.max.salao.shared.NotFoundException;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.jdbc.support.GeneratedKeyHolder;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.web.multipart.MultipartFile;

/**
 * Loja do representante: ele cadastra produtos e equipamentos (valor dele + preço sugerido de venda); os salões que ele
 * indicou pedem, acompanham o status e confirmam o recebimento. O app só registra: o pagamento é combinado fora e o
 * representante dá baixa. Valores em centavos.
 */
@Service
public class ShopService {

    static final Set<String> KINDS = Set.of("PRODUCT", "EQUIPMENT");
    static final int NEW_DAYS = 30;

    public record ProductRequest(String name, String description, String kind, String category, int costCents,
                                 int suggestedCents, Integer promoCents, LocalDate promoUntil, boolean active) {
    }

    /** Produto como o representante vê (todos os campos) e como o salão vê (sem o que é só do representante). */
    public record ProductView(Long id, String name, String description, String kind, String category, int costCents,
                              int suggestedCents, Integer promoCents, LocalDate promoUntil, int priceCents,
                              int gainCents, boolean onPromo, boolean isNew, List<String> tags, String imageUrl,
                              String thumbUrl, boolean active, boolean hidden, boolean showcase) {
    }

    public record Catalog(boolean available, String representativeName, List<ProductView> products,
                          List<String> categories) {
    }

    public record ItemRequest(Long productId, int quantity) {
    }

    public record OrderRequest(List<ItemRequest> items, String contactName, String phone, String address,
                               String neighborhood, String city, String note) {
    }

    public record ItemView(Long productId, String name, int quantity, int unitCents, int suggestedCents) {
    }

    public record PaymentView(Long id, int amountCents, String method, String note, LocalDateTime createdAt) {
    }

    public record OrderView(Long id, String origin, String status, long totalCents, long paidCents, long balanceCents,
                            long gainCents, long commissionCents, boolean commissionSettled, long netCents, LocalDateTime createdAt, LocalDateTime updatedAt, Long salonId,
                            String salonName, String contactName, String phone, String address, String neighborhood,
                            String city, String note, List<ItemView> items, List<PaymentView> payments) {
    }

    public record Delivery(String neighborhood, String city, int orders, long totalCents) {
    }

    public record Summary(long toReceiveCents, long receivedCents, int openOrders, int pendingOrders,
                          long commissionOwedCents, List<Delivery> deliveries) {
    }

    /** Produto na vitrine pública do salão: o preço é o sugerido (o que a cliente paga). */
    public record PublicShopProduct(Long id, String name, String description, String category, int priceCents,
                                    List<String> tags, String imageUrl, String thumbUrl) {
    }

    public record CustomerOrderRequest(List<ItemRequest> items, String name, String phone, String address,
                                       String neighborhood, String city, String note) {
    }

    public record CustomerOrderReceipt(Long id, long totalCents, String representativeName) {
    }

    private final JdbcTemplate jdbc;
    private final ShopPhotos photos;
    private final Clock clock;

    public ShopService(JdbcTemplate jdbc, ShopPhotos photos, Clock clock) {
        this.jdbc = jdbc;
        this.photos = photos;
        this.clock = clock;
    }

    // ---------------------------------------------------------------- representante

    public long representativeOf(long userId) {
        List<Long> ids = jdbc.queryForList("select id from representative where user_id = ?", Long.class, userId);
        if (ids.isEmpty()) {
            throw new NotFoundException("Representante não encontrado");
        }
        return ids.get(0);
    }

    @Transactional(readOnly = true)
    public List<ProductView> products(long repId) {
        return jdbc.query("select * from shop_product where representative_id = ? order by created_at desc, id desc",
                (rs, i) -> product(rs, false), repId);
    }

    @Transactional
    public ProductView saveProduct(long repId, Long id, ProductRequest r) {
        String name = r.name() == null ? "" : r.name().trim();
        if (name.isEmpty()) {
            throw new BusinessException("Informe o nome do produto");
        }
        String kind = r.kind() == null ? "PRODUCT" : r.kind();
        if (!KINDS.contains(kind)) {
            throw new BusinessException("Tipo inválido");
        }
        if (r.costCents() < 0 || r.suggestedCents() < 0 || (r.promoCents() != null && r.promoCents() < 0)) {
            throw new BusinessException("Os valores não podem ser negativos");
        }
        if (r.promoCents() != null && r.promoCents() >= r.costCents()) {
            throw new BusinessException("O valor da promoção tem de ser menor que o valor normal");
        }
        String category = blank(r.category());
        Integer promo = r.promoCents();
        LocalDate promoUntil = promo == null ? null : r.promoUntil();
        if (id == null) {
            GeneratedKeyHolder keys = new GeneratedKeyHolder();
            jdbc.update(con -> {
                var ps = con.prepareStatement("insert into shop_product (representative_id, name, description, kind, category, "
                        + "cost_cents, suggested_cents, promo_cents, promo_until, active) values (?,?,?,?,?,?,?,?,?,?)",
                        Statement.RETURN_GENERATED_KEYS);
                ps.setLong(1, repId);
                ps.setString(2, name);
                ps.setString(3, blank(r.description()));
                ps.setString(4, kind);
                ps.setString(5, category);
                ps.setInt(6, r.costCents());
                ps.setInt(7, r.suggestedCents());
                ps.setObject(8, promo);
                ps.setObject(9, promoUntil == null ? null : Date.valueOf(promoUntil));
                ps.setBoolean(10, r.active());
                return ps;
            }, keys);
            id = ((Number) keys.getKeys().get("id")).longValue();
        } else {
            int n = jdbc.update("update shop_product set name=?, description=?, kind=?, category=?, cost_cents=?, suggested_cents=?, "
                            + "promo_cents=?, promo_until=?, active=? where id=? and representative_id=?",
                    name, blank(r.description()), kind, category, r.costCents(), r.suggestedCents(), promo,
                    promoUntil == null ? null : Date.valueOf(promoUntil), r.active(), id, repId);
            if (n == 0) {
                throw new NotFoundException("Produto não encontrado");
            }
        }
        return one(repId, id);
    }

    @Transactional
    public void deleteProduct(long repId, long id) {
        if (jdbc.update("delete from shop_product where id = ? and representative_id = ?", id, repId) == 0) {
            throw new NotFoundException("Produto não encontrado");
        }
    }

    public ProductView uploadPhoto(long repId, long id, MultipartFile file) {
        one(repId, id);
        ShopPhotos.Stored s = photos.store(file, repId);
        jdbc.update("update shop_product set image_url = ?, thumb_url = ? where id = ?", s.imageUrl(), s.thumbUrl(), id);
        return one(repId, id);
    }

    private ProductView one(long repId, long id) {
        List<ProductView> l = jdbc.query("select * from shop_product where id = ? and representative_id = ?",
                (rs, i) -> product(rs, false), id, repId);
        if (l.isEmpty()) {
            throw new NotFoundException("Produto não encontrado");
        }
        return l.get(0);
    }

    @Transactional(readOnly = true)
    public List<OrderView> repOrders(long repId, String status) {
        List<OrderView> all = orders("o.representative_id = ?" + (status == null || status.isBlank() ? "" : " and o.status = ?"),
                status == null || status.isBlank() ? new Object[] {repId} : new Object[] {repId, status});
        // entregas do mesmo bairro ficam juntas
        return all.stream().sorted(java.util.Comparator
                .comparing((OrderView o) -> nz(o.neighborhood()).toLowerCase())
                .thenComparing(o -> nz(o.city()).toLowerCase())
                .thenComparing(OrderView::createdAt, java.util.Comparator.reverseOrder())).toList();
    }

    @Transactional(readOnly = true)
    public Summary summary(long repId) {
        List<OrderView> all = orders("o.representative_id = ?", new Object[] {repId});
        long toReceive = 0, received = 0, commissionOwed = 0;
        int open = 0, pending = 0;
        Map<String, long[]> groups = new LinkedHashMap<>();
        Map<String, String[]> names = new LinkedHashMap<>();
        for (OrderView o : all) {
            if ("CANCELED".equals(o.status())) {
                continue;
            }
            toReceive += o.balanceCents();
            received += o.paidCents();
            if ("CUSTOMER".equals(o.origin()) && "DELIVERED".equals(o.status()) && !o.commissionSettled()) {
                commissionOwed += o.commissionCents();
            }
            if ("PENDING".equals(o.status())) {
                pending++;
            }
            if (Set.of("PENDING", "PREPARING", "SHIPPED").contains(o.status())) {
                open++;
                String key = (nz(o.neighborhood()).toLowerCase() + "|" + nz(o.city()).toLowerCase());
                groups.computeIfAbsent(key, k -> new long[2])[0]++;
                groups.get(key)[1] += o.totalCents();
                names.putIfAbsent(key, new String[] {blankToDash(o.neighborhood()), nz(o.city())});
            }
        }
        List<Delivery> deliveries = groups.entrySet().stream()
                .map(e -> new Delivery(names.get(e.getKey())[0], names.get(e.getKey())[1], (int) e.getValue()[0], e.getValue()[1]))
                .sorted(java.util.Comparator.comparing(d -> d.neighborhood().toLowerCase()))
                .toList();
        return new Summary(toReceive, received, open, pending, commissionOwed, deliveries);
    }

    @Transactional
    public OrderView setStatus(long repId, long orderId, String status) {
        OrderView o = ownOrder(repId, orderId);
        String current = o.status();
        boolean ok = switch (status) {
            case "PREPARING" -> current.equals("PENDING");
            case "SHIPPED" -> current.equals("PENDING") || current.equals("PREPARING");
            // pedido de cliente do salão: quem recebe é a cliente, então o representante marca a entrega
            case "DELIVERED" -> "CUSTOMER".equals(o.origin()) && current.equals("SHIPPED");
            case "CANCELED" -> !current.equals("DELIVERED") && !current.equals("CANCELED");
            default -> false;
        };
        if (!ok) {
            throw new BusinessException("Não dá para mudar este pedido de " + label(current) + " para " + label(status));
        }
        jdbc.update("update shop_order set status = ?, updated_at = ? where id = ?", status, now(), orderId);
        return ownOrder(repId, orderId);
    }

    @Transactional
    public OrderView addPayment(long repId, long orderId, int amountCents, String method, String note) {
        OrderView o = ownOrder(repId, orderId);
        if ("CANCELED".equals(o.status())) {
            throw new BusinessException("Pedido cancelado não recebe pagamento");
        }
        if (amountCents <= 0) {
            throw new BusinessException("Informe o valor pago");
        }
        if (amountCents > o.balanceCents()) {
            throw new BusinessException("O valor passa do que falta pagar");
        }
        String m = blank(method) == null ? "Outro" : method.trim();
        jdbc.update("insert into shop_payment (order_id, amount_cents, method, note) values (?,?,?,?)", orderId, amountCents, m, blank(note));
        jdbc.update("update shop_order set updated_at = ? where id = ?", now(), orderId);
        return ownOrder(repId, orderId);
    }

    /** Registra que o representante repassou a comissão do pedido ao salão (ou descontou do que ele deve). */
    @Transactional
    public OrderView settleCommission(long repId, long orderId) {
        OrderView o = ownOrder(repId, orderId);
        if (!"CUSTOMER".equals(o.origin()) || !"DELIVERED".equals(o.status())) {
            throw new BusinessException("A comissão só é repassada depois que o pedido de cliente foi entregue");
        }
        if (o.commissionSettled()) {
            throw new BusinessException("Esta comissão já foi repassada");
        }
        jdbc.update("update shop_order set commission_settled = true, updated_at = ? where id = ?", now(), orderId);
        return ownOrder(repId, orderId);
    }

    private OrderView ownOrder(long repId, long orderId) {
        List<OrderView> l = orders("o.id = ? and o.representative_id = ?", new Object[] {orderId, repId});
        if (l.isEmpty()) {
            throw new NotFoundException("Pedido não encontrado");
        }
        return l.get(0);
    }

    // ---------------------------------------------------------------- salão

    private Long referrerOf(long salonId) {
        List<Long> l = jdbc.query("select referrer_id from salon where id = ?", (rs, i) -> (Long) rs.getObject(1), salonId);
        return l.isEmpty() ? null : l.get(0);
    }

    @Transactional(readOnly = true)
    public Catalog catalog(long salonId) {
        Long rep = referrerOf(salonId);
        if (rep == null) {
            return new Catalog(false, null, List.of(), List.of());
        }
        String name = jdbc.queryForObject("select u.name from representative r join app_user u on u.id = r.user_id where r.id = ?", String.class, rep);
        List<ProductView> products = jdbc.query("select p.*, (h.product_id is not null) as hidden, (sc.product_id is not null) as showcase from shop_product p "
                + "left join shop_hidden h on h.product_id = p.id and h.salon_id = ? "
                + "left join shop_showcase sc on sc.product_id = p.id and sc.salon_id = ? "
                + "where p.representative_id = ? and p.active order by p.created_at desc, p.id desc",
                (rs, i) -> product(rs, true), salonId, salonId, rep);
        List<String> categories = products.stream().map(ProductView::category).filter(c -> c != null && !c.isBlank())
                .distinct().sorted(String.CASE_INSENSITIVE_ORDER).toList();
        return new Catalog(true, firstName(name), products, categories);
    }

    @Transactional
    public void setVisible(long salonId, long productId, boolean visible) {
        Long rep = referrerOf(salonId);
        Integer ok = rep == null ? 0 : jdbc.queryForObject("select count(*) from shop_product where id = ? and representative_id = ?", Integer.class, productId, rep);
        if (ok == null || ok == 0) {
            throw new NotFoundException("Produto não encontrado");
        }
        if (visible) {
            jdbc.update("delete from shop_hidden where salon_id = ? and product_id = ?", salonId, productId);
        } else {
            jdbc.update("insert into shop_hidden (salon_id, product_id) values (?, ?) on conflict do nothing", salonId, productId);
        }
    }

    /** Marca (ou desmarca) um produto do representante para as clientes do salão verem na página de agendamento. */
    @Transactional
    public void setShowcase(long salonId, long productId, boolean on) {
        Long rep = referrerOf(salonId);
        Integer ok = rep == null ? 0 : jdbc.queryForObject("select count(*) from shop_product where id = ? and representative_id = ? and active", Integer.class, productId, rep);
        if (ok == null || ok == 0) {
            throw new NotFoundException("Produto não encontrado");
        }
        if (on) {
            jdbc.update("insert into shop_showcase (salon_id, product_id) values (?, ?) on conflict do nothing", salonId, productId);
        } else {
            jdbc.update("delete from shop_showcase where salon_id = ? and product_id = ?", salonId, productId);
        }
    }

    /** Vitrine pública: o que o salão marcou, ativo e que ele não ocultou. */
    @Transactional(readOnly = true)
    public List<PublicShopProduct> publicShowcase(long salonId) {
        Long rep = referrerOf(salonId);
        if (rep == null) {
            return List.of();
        }
        return jdbc.query("select p.* from shop_product p join shop_showcase sc on sc.product_id = p.id and sc.salon_id = ? "
                + "where p.representative_id = ? and p.active and p.suggested_cents > 0 "
                + "and not exists (select 1 from shop_hidden h where h.product_id = p.id and h.salon_id = ?) "
                + "order by p.created_at desc, p.id desc", (rs, i) -> {
            ProductView p = product(rs, false);
            return new PublicShopProduct(p.id(), p.name(), p.description(), p.category(), p.suggestedCents(),
                    p.tags().stream().filter(t -> !t.equals("PROMOCAO")).toList(), p.imageUrl(), p.thumbUrl());
        }, salonId, rep, salonId);
    }

    /** Pedido de uma cliente do salão: vai direto para o representante; o salão ganha a comissão. */
    @Transactional
    public CustomerOrderReceipt placeCustomerOrder(long salonId, CustomerOrderRequest r) {
        Long rep = referrerOf(salonId);
        if (rep == null) {
            throw new NotFoundException("Produto não encontrado");
        }
        if (r.items() == null || r.items().isEmpty()) {
            throw new BusinessException("Escolha pelo menos um produto");
        }
        String name = r.name() == null ? "" : r.name().trim();
        String phone = blank(r.phone());
        String neighborhood = blank(r.neighborhood());
        if (name.isEmpty() || phone == null || neighborhood == null) {
            throw new BusinessException("Informe seu nome, WhatsApp e bairro para a entrega");
        }
        Map<Long, Integer> qty = new LinkedHashMap<>();
        for (ItemRequest it : r.items()) {
            if (it.productId() == null || it.quantity() <= 0 || it.quantity() > 99) {
                throw new BusinessException("Quantidade inválida");
            }
            qty.merge(it.productId(), it.quantity(), Integer::sum);
        }
        Map<Long, PublicShopProduct> offered = publicShowcase(salonId).stream().collect(Collectors.toMap(PublicShopProduct::id, p -> p));
        String salonName = jdbc.queryForObject("select name from salon where id = ?", String.class, salonId);
        List<ItemView> items = new ArrayList<>();
        long total = 0, commission = 0;
        for (Map.Entry<Long, Integer> e : qty.entrySet()) {
            PublicShopProduct offer = offered.get(e.getKey());
            if (offer == null) {
                throw new BusinessException("Um dos produtos não está mais disponível.");
            }
            ProductView p = one(rep, e.getKey());
            items.add(new ItemView(p.id(), p.name(), e.getValue(), p.suggestedCents(), p.suggestedCents()));
            total += (long) p.suggestedCents() * e.getValue();
            commission += (long) (p.suggestedCents() - p.priceCents()) * e.getValue();
        }
        GeneratedKeyHolder keys = new GeneratedKeyHolder();
        long totalCents = total, commissionCents = commission;
        jdbc.update(con -> {
            var ps = con.prepareStatement("insert into shop_order (representative_id, salon_id, salon_name, contact_name, phone, "
                    + "address, neighborhood, city, note, total_cents, origin, commission_cents) values (?,?,?,?,?,?,?,?,?,?,'CUSTOMER',?)",
                    Statement.RETURN_GENERATED_KEYS);
            ps.setLong(1, rep);
            ps.setLong(2, salonId);
            ps.setString(3, salonName);
            ps.setString(4, name);
            ps.setString(5, phone);
            ps.setString(6, blank(r.address()));
            ps.setString(7, neighborhood);
            ps.setString(8, blank(r.city()));
            ps.setString(9, blank(r.note()));
            ps.setLong(10, totalCents);
            ps.setLong(11, commissionCents);
            return ps;
        }, keys);
        long orderId = ((Number) keys.getKeys().get("id")).longValue();
        for (ItemView it : items) {
            jdbc.update("insert into shop_order_item (order_id, product_id, name, quantity, unit_cents, suggested_cents) values (?,?,?,?,?,?)",
                    orderId, it.productId(), it.name(), it.quantity(), it.unitCents(), it.suggestedCents());
        }
        String repName = jdbc.queryForObject("select u.name from representative r join app_user u on u.id = r.user_id where r.id = ?", String.class, rep);
        return new CustomerOrderReceipt(orderId, totalCents, firstName(repName));
    }

    @Transactional
    public OrderView placeOrder(long salonId, OrderRequest r) {
        Long rep = referrerOf(salonId);
        if (rep == null) {
            throw new BusinessException("Seu salão não tem representante: a loja não está disponível.");
        }
        if (r.items() == null || r.items().isEmpty()) {
            throw new BusinessException("Escolha pelo menos um produto");
        }
        String contact = r.contactName() == null ? "" : r.contactName().trim();
        if (contact.isEmpty()) {
            throw new BusinessException("Informe o nome de quem recebe");
        }
        String neighborhood = blank(r.neighborhood());
        if (neighborhood == null) {
            throw new BusinessException("Informe o bairro para a entrega");
        }
        Map<Long, Integer> qty = new LinkedHashMap<>();
        for (ItemRequest it : r.items()) {
            if (it.productId() == null || it.quantity() <= 0 || it.quantity() > 999) {
                throw new BusinessException("Quantidade inválida");
            }
            qty.merge(it.productId(), it.quantity(), Integer::sum);
        }
        String salonName = jdbc.queryForObject("select name from salon where id = ?", String.class, salonId);
        List<ItemView> items = new ArrayList<>();
        long total = 0;
        for (Map.Entry<Long, Integer> e : qty.entrySet()) {
            List<ProductView> found = jdbc.query("select * from shop_product where id = ? and representative_id = ? and active",
                    (rs, i) -> product(rs, false), e.getKey(), rep);
            if (found.isEmpty()) {
                throw new BusinessException("Um dos produtos não está mais disponível. Atualize a loja.");
            }
            ProductView p = found.get(0);
            items.add(new ItemView(p.id(), p.name(), e.getValue(), p.priceCents(), p.suggestedCents()));
            total += (long) p.priceCents() * e.getValue();
        }
        GeneratedKeyHolder keys = new GeneratedKeyHolder();
        long totalCents = total;
        jdbc.update(con -> {
            var ps = con.prepareStatement("insert into shop_order (representative_id, salon_id, salon_name, contact_name, phone, "
                    + "address, neighborhood, city, note, total_cents) values (?,?,?,?,?,?,?,?,?,?)", Statement.RETURN_GENERATED_KEYS);
            ps.setLong(1, rep);
            ps.setLong(2, salonId);
            ps.setString(3, salonName);
            ps.setString(4, contact);
            ps.setString(5, blank(r.phone()));
            ps.setString(6, blank(r.address()));
            ps.setString(7, neighborhood);
            ps.setString(8, blank(r.city()));
            ps.setString(9, blank(r.note()));
            ps.setLong(10, totalCents);
            return ps;
        }, keys);
        long orderId = ((Number) keys.getKeys().get("id")).longValue();
        for (ItemView it : items) {
            jdbc.update("insert into shop_order_item (order_id, product_id, name, quantity, unit_cents, suggested_cents) values (?,?,?,?,?,?)",
                    orderId, it.productId(), it.name(), it.quantity(), it.unitCents(), it.suggestedCents());
        }
        // o endereço fica guardado no salão para o próximo pedido
        jdbc.update("update salon set address = coalesce(?, address), neighborhood = ?, city = coalesce(?, city) where id = ?",
                blank(r.address()), neighborhood, blank(r.city()), salonId);
        return ownSalonOrder(salonId, orderId);
    }

    @Transactional(readOnly = true)
    public List<OrderView> salonOrders(long salonId) {
        return orders("o.salon_id = ? and o.origin = 'SALON'", new Object[] {salonId});
    }

    /** Vendas feitas às clientes do salão pela vitrine pública (o pedido vai direto ao representante). */
    @Transactional(readOnly = true)
    public List<OrderView> salonCustomerOrders(long salonId) {
        return orders("o.salon_id = ? and o.origin = 'CUSTOMER'", new Object[] {salonId});
    }

    /** Endereço que o salão já informou, para preencher o pedido. */
    @Transactional(readOnly = true)
    public Map<String, Object> salonAddress(long salonId) {
        return jdbc.queryForMap("select name as \"salonName\", phone, address, neighborhood, city from salon where id = ?", salonId);
    }

    @Transactional
    public OrderView confirmReceipt(long salonId, long orderId) {
        OrderView o = ownSalonOrder(salonId, orderId);
        if (!"SHIPPED".equals(o.status())) {
            throw new BusinessException("Só dá para confirmar o recebimento de um pedido que foi enviado");
        }
        jdbc.update("update shop_order set status = 'DELIVERED', updated_at = ? where id = ?", now(), orderId);
        return ownSalonOrder(salonId, orderId);
    }

    @Transactional
    public OrderView cancelOwn(long salonId, long orderId) {
        OrderView o = ownSalonOrder(salonId, orderId);
        if (!"PENDING".equals(o.status())) {
            throw new BusinessException("Só dá para cancelar enquanto o pedido está pendente. Fale com o representante.");
        }
        jdbc.update("update shop_order set status = 'CANCELED', updated_at = ? where id = ?", now(), orderId);
        return ownSalonOrder(salonId, orderId);
    }

    /** Quanto o salão deve ao representante (pedidos não cancelados menos o que já pagou). */
    @Transactional(readOnly = true)
    public Map<String, Object> salonBalance(long salonId) {
        long owed = 0, paid = 0;
        for (OrderView o : salonOrders(salonId)) {
            if (!"CANCELED".equals(o.status())) {
                owed += o.balanceCents();
                paid += o.paidCents();
            }
        }
        return Map.of("owedCents", owed, "paidCents", paid);
    }

    private OrderView ownSalonOrder(long salonId, long orderId) {
        List<OrderView> l = orders("o.id = ? and o.salon_id = ? and o.origin = 'SALON'", new Object[] {orderId, salonId});
        if (l.isEmpty()) {
            throw new NotFoundException("Pedido não encontrado");
        }
        return l.get(0);
    }

    // ---------------------------------------------------------------- comum

    private List<OrderView> orders(String where, Object[] args) {
        List<Map<String, Object>> rows = jdbc.queryForList("select o.* from shop_order o where " + where + " order by o.created_at desc, o.id desc", args);
        if (rows.isEmpty()) {
            return List.of();
        }
        List<Long> ids = rows.stream().map(r -> ((Number) r.get("id")).longValue()).toList();
        String in = ids.stream().map(x -> "?").collect(Collectors.joining(","));
        Map<Long, List<ItemView>> items = new LinkedHashMap<>();
        jdbc.query("select * from shop_order_item where order_id in (" + in + ") order by id", rs -> {
            items.computeIfAbsent(rs.getLong("order_id"), k -> new ArrayList<>()).add(new ItemView((Long) rs.getObject("product_id"),
                    rs.getString("name"), rs.getInt("quantity"), rs.getInt("unit_cents"), rs.getInt("suggested_cents")));
        }, ids.toArray());
        Map<Long, List<PaymentView>> pays = new LinkedHashMap<>();
        jdbc.query("select * from shop_payment where order_id in (" + in + ") order by id", rs -> {
            pays.computeIfAbsent(rs.getLong("order_id"), k -> new ArrayList<>()).add(new PaymentView(rs.getLong("id"),
                    rs.getInt("amount_cents"), rs.getString("method"), rs.getString("note"), rs.getTimestamp("created_at").toLocalDateTime()));
        }, ids.toArray());
        List<OrderView> out = new ArrayList<>();
        for (Map<String, Object> r : rows) {
            long id = ((Number) r.get("id")).longValue();
            List<ItemView> its = items.getOrDefault(id, List.of());
            List<PaymentView> ps = pays.getOrDefault(id, List.of());
            long total = ((Number) r.get("total_cents")).longValue();
            long paid = ps.stream().mapToLong(PaymentView::amountCents).sum();
            long gain = its.stream().mapToLong(i -> (long) (i.suggestedCents() - i.unitCents()) * i.quantity()).sum();
            long commission = ((Number) r.get("commission_cents")).longValue();
            out.add(new OrderView(id, (String) r.get("origin"), (String) r.get("status"), total, paid, total - paid, gain,
                    commission, (Boolean) r.get("commission_settled"), total - commission,
                    ((Timestamp) r.get("created_at")).toLocalDateTime(), ((Timestamp) r.get("updated_at")).toLocalDateTime(),
                    ((Number) r.get("salon_id")).longValue(), (String) r.get("salon_name"), (String) r.get("contact_name"),
                    (String) r.get("phone"), (String) r.get("address"), (String) r.get("neighborhood"), (String) r.get("city"),
                    (String) r.get("note"), its, ps));
        }
        return out;
    }

    private ProductView product(ResultSet rs, boolean withHidden) throws SQLException {
        int cost = rs.getInt("cost_cents");
        int suggested = rs.getInt("suggested_cents");
        Integer promo = (Integer) rs.getObject("promo_cents");
        Date until = rs.getDate("promo_until");
        LocalDate today = LocalDate.now(clock);
        boolean onPromo = promo != null && (until == null || !until.toLocalDate().isBefore(today));
        int price = onPromo ? promo : cost;
        boolean isNew = rs.getTimestamp("created_at").toLocalDateTime().isAfter(LocalDateTime.now(clock).minusDays(NEW_DAYS));
        List<String> tags = new ArrayList<>();
        if (onPromo) {
            tags.add("PROMOCAO");
        }
        if (isNew) {
            tags.add("NOVO");
        }
        String kind = rs.getString("kind");
        if ("EQUIPMENT".equals(kind)) {
            tags.add("EQUIPAMENTO");
        }
        return new ProductView(rs.getLong("id"), rs.getString("name"), rs.getString("description"), kind, rs.getString("category"),
                cost, suggested, promo, until == null ? null : until.toLocalDate(), price, suggested - price, onPromo, isNew, tags,
                rs.getString("image_url"), rs.getString("thumb_url"), rs.getBoolean("active"), withHidden && rs.getBoolean("hidden"),
                withHidden && rs.getBoolean("showcase"));
    }

    private LocalDateTime now() {
        return LocalDateTime.now(clock);
    }

    private static String blank(String s) {
        return s == null || s.trim().isEmpty() ? null : s.trim();
    }

    private static String nz(String s) {
        return s == null ? "" : s;
    }

    private static String blankToDash(String s) {
        return s == null || s.isBlank() ? "Sem bairro" : s;
    }

    private static String firstName(String name) {
        return name == null ? "" : name.trim().split("\\s+")[0];
    }

    static String label(String status) {
        return switch (status) {
            case "PENDING" -> "pendente";
            case "PREPARING" -> "em preparação";
            case "SHIPPED" -> "enviado";
            case "DELIVERED" -> "entregue";
            case "CANCELED" -> "cancelado";
            default -> status;
        };
    }
}
