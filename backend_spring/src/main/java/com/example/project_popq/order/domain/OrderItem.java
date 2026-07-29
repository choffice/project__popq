package com.example.project_popq.order.domain;

import com.example.project_popq.common.domain.BaseTimeEntity;
import com.example.project_popq.product.domain.Product;
import jakarta.persistence.CascadeType;
import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.FetchType;
import jakarta.persistence.GeneratedValue;
import jakarta.persistence.GenerationType;
import jakarta.persistence.Id;
import jakarta.persistence.JoinColumn;
import jakarta.persistence.ManyToOne;
import jakarta.persistence.OneToMany;
import jakarta.persistence.OrderBy;
import jakarta.persistence.Table;
import java.util.ArrayList;
import java.util.List;
import lombok.AccessLevel;
import lombok.Getter;
import lombok.NoArgsConstructor;

@Getter
@Entity
@Table(name = "order_items")
@NoArgsConstructor(access = AccessLevel.PROTECTED)
public class OrderItem extends BaseTimeEntity {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    @Column(name = "order_item_id")
    private Long id;

    @ManyToOne(fetch = FetchType.LAZY, optional = false)
    @JoinColumn(name = "order_id", nullable = false)
    private Order order;

    @ManyToOne(fetch = FetchType.LAZY, optional = false)
    @JoinColumn(name = "product_id", nullable = false)
    private Product product;

    @Column(name = "product_name_snapshot", nullable = false, length = 150)
    private String productNameSnapshot;

    @Column(name = "product_image_url_snapshot", length = 1000)
    private String productImageUrlSnapshot;

    @Column(name = "unit_price_snapshot", nullable = false)
    private long unitPriceSnapshot;

    @Column(name = "quantity", nullable = false)
    private int quantity;

    @Column(name = "item_total_price", nullable = false)
    private long itemTotalPrice;

    @OneToMany(
            mappedBy = "orderItem",
            cascade = CascadeType.ALL,
            orphanRemoval = true
    )
    @OrderBy("id ASC")
    private List<OrderItemOption> options = new ArrayList<>();

    private OrderItem(Order order, Product product, int quantity) {
        this.order = order;
        this.product = product;
        this.productNameSnapshot = product.getName();
        this.productImageUrlSnapshot = product.getImageUrl();
        this.unitPriceSnapshot = product.getBasePrice();
        this.quantity = quantity;
    }

    public static OrderItem create(Order order, Product product, int quantity) {
        return new OrderItem(order, product, quantity);
    }

    public void addOption(OrderItemOption option) {
        options.add(option);
    }

    public void calculateTotal() {
        long optionPrice = options.stream()
                .mapToLong(OrderItemOption::getOptionPriceSnapshot)
                .reduce(0L, Math::addExact);
        itemTotalPrice = Math.multiplyExact(
                Math.addExact(unitPriceSnapshot, optionPrice),
                quantity
        );
    }
}

