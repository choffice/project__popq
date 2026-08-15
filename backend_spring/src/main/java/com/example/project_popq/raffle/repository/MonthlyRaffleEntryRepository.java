package com.example.project_popq.raffle.repository;

import com.example.project_popq.raffle.domain.MonthlyRaffleEntry;
import com.example.project_popq.raffle.domain.MonthlyRaffleStatus;
import java.util.List;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Lock;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;
import jakarta.persistence.LockModeType;

public interface MonthlyRaffleEntryRepository
        extends JpaRepository<MonthlyRaffleEntry, Long> {

    List<MonthlyRaffleEntry> findAllByRoundIdOrderByIdAsc(Long roundId);

    @Lock(LockModeType.PESSIMISTIC_WRITE)
    @Query("select entry from MonthlyRaffleEntry entry "
            + "where entry.round.id = :roundId order by entry.id asc")
    List<MonthlyRaffleEntry> findAllForUpdateByRoundId(
            @Param("roundId") Long roundId
    );

    long countByRoundIdAndUserId(Long roundId, Long userId);

    @Query("""
            select entry
            from MonthlyRaffleEntry entry
            where entry.user.id = :userId
              and entry.round.status = :status
            order by entry.round.roundMonth desc, entry.id asc
            """)
    List<MonthlyRaffleEntry> findDrawnEntriesByUserId(
            @Param("userId") Long userId,
            @Param("status") MonthlyRaffleStatus status
    );

}
