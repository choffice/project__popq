package com.example.project_popq.raffle.domain;

import com.example.project_popq.common.domain.BaseTimeEntity;
import com.example.project_popq.user.domain.User;
import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.FetchType;
import jakarta.persistence.GeneratedValue;
import jakarta.persistence.GenerationType;
import jakarta.persistence.Id;
import jakarta.persistence.JoinColumn;
import jakarta.persistence.ManyToOne;
import jakarta.persistence.Table;
import java.time.Instant;
import lombok.AccessLevel;
import lombok.Getter;
import lombok.NoArgsConstructor;

@Getter
@Entity
@Table(name = "monthly_raffle_entries")
@NoArgsConstructor(access = AccessLevel.PROTECTED)
public class MonthlyRaffleEntry extends BaseTimeEntity {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    @Column(name = "monthly_raffle_entry_id")
    private Long id;

    @ManyToOne(fetch = FetchType.LAZY, optional = false)
    @JoinColumn(name = "round_id", nullable = false)
    private MonthlyRaffleRound round;

    @ManyToOne(fetch = FetchType.LAZY, optional = false)
    @JoinColumn(name = "user_id", nullable = false)
    private User user;

    @Column(name = "purchased_at", nullable = false)
    private Instant purchasedAt;

    private MonthlyRaffleEntry(
            MonthlyRaffleRound round,
            User user,
            Instant purchasedAt
    ) {
        this.round = round;
        this.user = user;
        this.purchasedAt = purchasedAt;
    }

    public static MonthlyRaffleEntry purchase(
            MonthlyRaffleRound round,
            User user,
            Instant purchasedAt
    ) {
        return new MonthlyRaffleEntry(round, user, purchasedAt);
    }
}
