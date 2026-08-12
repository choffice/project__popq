package com.example.project_popq.raffle.domain;

import com.example.project_popq.common.domain.BaseTimeEntity;
import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.EnumType;
import jakarta.persistence.Enumerated;
import jakarta.persistence.GeneratedValue;
import jakarta.persistence.GenerationType;
import jakarta.persistence.Id;
import jakarta.persistence.Table;
import java.time.Instant;
import java.time.LocalDate;
import java.time.YearMonth;
import lombok.AccessLevel;
import lombok.Getter;
import lombok.NoArgsConstructor;

@Getter
@Entity
@Table(name = "monthly_raffle_rounds")
@NoArgsConstructor(access = AccessLevel.PROTECTED)
public class MonthlyRaffleRound extends BaseTimeEntity {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    @Column(name = "monthly_raffle_round_id")
    private Long id;

    @Column(name = "round_month", nullable = false, unique = true)
    private LocalDate roundMonth;

    @Enumerated(EnumType.STRING)
    @Column(name = "status", nullable = false, length = 20)
    private MonthlyRaffleStatus status;

    @Column(name = "winner_entry_id")
    private Long winnerEntryId;

    @Column(name = "drawn_at")
    private Instant drawnAt;

    private MonthlyRaffleRound(YearMonth roundMonth) {
        this.roundMonth = roundMonth.atDay(1);
        this.status = MonthlyRaffleStatus.OPEN;
    }

    public static MonthlyRaffleRound open(YearMonth roundMonth) {
        return new MonthlyRaffleRound(roundMonth);
    }

    public void draw(Long winnerEntryId, Instant drawnAt) {
        if (status == MonthlyRaffleStatus.DRAWN) {
            return;
        }
        this.winnerEntryId = winnerEntryId;
        this.drawnAt = drawnAt;
        this.status = MonthlyRaffleStatus.DRAWN;
    }

    public void closeWithoutEntries(Instant drawnAt) {
        this.drawnAt = drawnAt;
        this.status = MonthlyRaffleStatus.DRAWN;
    }

    public YearMonth getYearMonth() {
        return YearMonth.from(roundMonth);
    }
}
