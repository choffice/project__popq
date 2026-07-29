package com.example.project_popq.order.domain;

import com.example.project_popq.common.domain.BaseTimeEntity;
import com.example.project_popq.product.domain.ProductOption;
import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.FetchType;
import jakarta.persistence.GeneratedValue;
import jakarta.persistence.GenerationType;
import jakarta.persistence.Id;
import jakarta.persistence.JoinColumn;
import jakarta.persistence.ManyToOne;
import jakarta.persistence.Table;
import lombok.AccessLevel;
import lombok.Getter;
import lombok.NoArgsConstructor;

@Getter
@Entity
@Table(name = "order_item_options")
@NoArgsConstructor(access = AccessLevel.PROTECTED)
public class OrderItemOption extends BaseTimeEntity {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    @Column(name = "order_item_option_id")
    private Long id;

    @ManyToOne(fetch = FetchType.LAZY, optional = false)
    @JoinColumn(name = "order_item_id", nullable = false)
    private OrderItem orderItem;

    @ManyToOne(fetch = FetchType.LAZY, optional = false)
    @JoinColumn(name = "product_option_id", nullable = false)
    private ProductOption productOption;

    @Column(name = "option_group_name_snapshot", nullable = false, length = 100)
    private String optionGroupNameSnapshot;

    @Column(name = "option_name_snapshot", nullable = false, length = 100)
    private String optionNameSnapshot;

    @Column(name = "option_price_snapshot", nullable = false)
    private long optionPriceSnapshot;

    private OrderItemOption(OrderItem orderItem, ProductOption productOption) {
        this.orderItem = orderItem;
        this.productOption = productOption;
        this.optionGroupNameSnapshot = productOption.getOptionGroup().getName();
        this.optionNameSnapshot = productOption.getName();
        this.optionPriceSnapshot = productOption.getAdditionalPrice();
    }

    public static OrderItemOption create(
            OrderItem orderItem,
            ProductOption productOption
    ) {
        return new OrderItemOption(orderItem, productOption);
    }
}

