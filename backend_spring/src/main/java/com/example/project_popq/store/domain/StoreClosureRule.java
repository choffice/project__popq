package com.example.project_popq.store.domain;

import com.example.project_popq.common.domain.BaseTimeEntity;
import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.EnumType;
import jakarta.persistence.Enumerated;
import jakarta.persistence.FetchType;
import jakarta.persistence.GeneratedValue;
import jakarta.persistence.GenerationType;
import jakarta.persistence.Id;
import jakarta.persistence.JoinColumn;
import jakarta.persistence.ManyToOne;
import jakarta.persistence.Table;
import java.time.DayOfWeek;
import lombok.AccessLevel;
import lombok.Getter;
import lombok.NoArgsConstructor;

@Getter
@Entity
@Table(name = "store_closure_rules")
@NoArgsConstructor(access = AccessLevel.PROTECTED)
public class StoreClosureRule extends BaseTimeEntity {
    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    @Column(name = "store_closure_rule_id")
    private Long id;

    @ManyToOne(fetch = FetchType.LAZY, optional = false)
    @JoinColumn(name = "store_id", nullable = false)
    private Store store;

    @Enumerated(EnumType.STRING)
    @Column(name = "rule_type", nullable = false, length = 30)
    private StoreClosureRuleType ruleType;

    @Column(name = "week_of_month")
    private Integer weekOfMonth;

    @Enumerated(EnumType.STRING)
    @Column(name = "day_of_week", length = 20)
    private DayOfWeek dayOfWeek;

    public static StoreClosureRule create(
            Store store,
            StoreClosureRuleType ruleType,
            Integer weekOfMonth,
            DayOfWeek dayOfWeek
    ) {
        StoreClosureRule value = new StoreClosureRule();
        value.store = store;
        value.ruleType = ruleType;
        value.weekOfMonth = weekOfMonth;
        value.dayOfWeek = dayOfWeek;
        return value;
    }
}
