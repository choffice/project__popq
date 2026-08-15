package com.example.project_popq.raffle.repository;

import com.example.project_popq.raffle.domain.MonthlyRaffleRound;
import jakarta.persistence.LockModeType;
import java.time.LocalDate;
import java.time.Instant;
import java.util.Optional;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Lock;
import org.springframework.data.jpa.repository.Modifying;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;

public interface MonthlyRaffleRoundRepository
        extends JpaRepository<MonthlyRaffleRound, Long> {

    Optional<MonthlyRaffleRound> findByRoundMonth(LocalDate roundMonth);

    @Lock(LockModeType.PESSIMISTIC_WRITE)
    @Query("select raffleRound from MonthlyRaffleRound raffleRound "
            + "where raffleRound.roundMonth = :roundMonth")
    Optional<MonthlyRaffleRound> findForUpdateByRoundMonth(
            @Param("roundMonth") LocalDate roundMonth
    );

    @Modifying
    @Query(value = """
            INSERT IGNORE INTO monthly_raffle_rounds (
                round_month, status, created_at, updated_at
            ) VALUES (:roundMonth, 'OPEN', :now, :now)
            """, nativeQuery = true)
    int insertOpenRoundIfAbsent(
            @Param("roundMonth") LocalDate roundMonth,
            @Param("now") Instant now
    );
}
