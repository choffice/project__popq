package com.example.project_popq.raffle.service;

import com.example.project_popq.common.error.BusinessException;
import com.example.project_popq.common.error.ErrorCode;
import com.example.project_popq.point.service.CustomerPointService;
import com.example.project_popq.raffle.domain.MonthlyRaffleEntry;
import com.example.project_popq.raffle.domain.MonthlyRaffleRound;
import com.example.project_popq.raffle.domain.MonthlyRaffleStatus;
import com.example.project_popq.raffle.dto.MonthlyRaffleStatusResponse;
import com.example.project_popq.raffle.repository.MonthlyRaffleEntryRepository;
import com.example.project_popq.raffle.repository.MonthlyRaffleRoundRepository;
import com.example.project_popq.user.domain.User;
import com.example.project_popq.user.repository.UserRepository;
import jakarta.persistence.EntityManager;
import java.security.SecureRandom;
import java.time.Instant;
import java.time.LocalDate;
import java.time.YearMonth;
import java.time.ZoneId;
import java.util.List;
import lombok.RequiredArgsConstructor;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

@Service
@RequiredArgsConstructor
public class MonthlyRaffleService {

    public static final long TICKET_PRICE = 1000L;
    private static final int DRAW_DAY = 10;
    private static final ZoneId BUSINESS_ZONE = ZoneId.of("Asia/Seoul");
    private static final SecureRandom RANDOM = new SecureRandom();

    private final MonthlyRaffleRoundRepository roundRepository;
    private final MonthlyRaffleEntryRepository entryRepository;
    private final UserRepository userRepository;
    private final CustomerPointService pointService;
    private final EntityManager entityManager;

    @Transactional
    public MonthlyRaffleStatusResponse getStatus(User user) {
        Instant now = Instant.now();
        drawIfDue(now);
        return status(user.getId(), now);
    }

    @Transactional
    public MonthlyRaffleStatusResponse purchaseTicket(User currentUser) {
        Instant now = Instant.now();
        drawIfDue(now);

        User user = userRepository.findForUpdateById(currentUser.getId())
                .orElseThrow(() -> new BusinessException(ErrorCode.USER_NOT_FOUND));
        if (pointService.getBalance(user.getId()) < TICKET_PRICE) {
            throw new BusinessException(ErrorCode.INSUFFICIENT_POINTS);
        }

        YearMonth purchaseMonth = purchaseMonth(now);
        MonthlyRaffleRound round = getOrCreateRound(purchaseMonth);
        MonthlyRaffleEntry entry = entryRepository.saveAndFlush(
                MonthlyRaffleEntry.purchase(round, user, now)
        );
        pointService.spendRaffleTicket(
                user,
                entry.getId(),
                purchaseMonth.toString(),
                TICKET_PRICE,
                now
        );
        entityManager.flush();
        return status(user.getId(), now);
    }

    @Transactional
    public void drawCurrentMonth() {
        draw(YearMonth.now(BUSINESS_ZONE), Instant.now());
    }

    private void drawIfDue(Instant now) {
        LocalDate today = now.atZone(BUSINESS_ZONE).toLocalDate();
        if (today.getDayOfMonth() >= DRAW_DAY) {
            draw(YearMonth.from(today), now);
        }
    }

    private void draw(YearMonth month, Instant drawnAt) {
        MonthlyRaffleRound round = getOrCreateRound(month);
        if (round.getStatus() == MonthlyRaffleStatus.DRAWN) {
            return;
        }

        List<MonthlyRaffleEntry> entries = entryRepository
                .findAllForUpdateByRoundId(round.getId());
        Long winnerEntryId = entries.isEmpty()
                ? null
                : entries.get(RANDOM.nextInt(entries.size())).getId();
        if (winnerEntryId == null) {
            round.closeWithoutEntries(drawnAt);
        } else {
            round.draw(winnerEntryId, drawnAt);
        }
    }

    private MonthlyRaffleRound getOrCreateRound(YearMonth month) {
        LocalDate roundMonth = month.atDay(1);
        roundRepository.insertOpenRoundIfAbsent(roundMonth, Instant.now());
        return roundRepository.findForUpdateByRoundMonth(roundMonth)
                .orElseThrow(() -> new BusinessException(ErrorCode.INTERNAL_ERROR));
    }

    private MonthlyRaffleStatusResponse status(Long userId, Instant now) {
        YearMonth purchaseMonth = purchaseMonth(now);
        MonthlyRaffleRound purchaseRound = roundRepository
                .findByRoundMonth(purchaseMonth.atDay(1))
                .orElse(null);
        long ticketCount = purchaseRound == null
                ? 0L
                : entryRepository.countByRoundIdAndUserId(
                        purchaseRound.getId(), userId
                );

        List<MonthlyRaffleEntry> resultEntries = entryRepository
                .findDrawnEntriesByUserId(userId, MonthlyRaffleStatus.DRAWN);
        String resultRound = null;
        String result = null;
        if (!resultEntries.isEmpty()) {
            MonthlyRaffleRound resultRaffleRound = resultEntries.get(0).getRound();
            resultRound = resultRaffleRound.getYearMonth().toString();
            boolean won = resultEntries.stream()
                    .filter(entry -> entry.getRound().getId().equals(
                            resultRaffleRound.getId()
                    ))
                    .anyMatch(entry -> entry.getId().equals(
                            resultRaffleRound.getWinnerEntryId()
                    ));
            result = won ? "WON" : "NOT_WON";
        }

        long balance = pointService.getBalance(userId);
        return new MonthlyRaffleStatusResponse(
                balance,
                TICKET_PRICE,
                purchaseMonth.toString(),
                purchaseMonth.atDay(DRAW_DAY),
                ticketCount,
                balance >= TICKET_PRICE,
                resultRound,
                result
        );
    }

    private YearMonth purchaseMonth(Instant now) {
        LocalDate today = now.atZone(BUSINESS_ZONE).toLocalDate();
        YearMonth currentMonth = YearMonth.from(today);
        return today.getDayOfMonth() < DRAW_DAY
                ? currentMonth
                : currentMonth.plusMonths(1);
    }
}
