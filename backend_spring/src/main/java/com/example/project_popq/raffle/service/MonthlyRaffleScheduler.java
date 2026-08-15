package com.example.project_popq.raffle.service;

import lombok.RequiredArgsConstructor;
import org.springframework.scheduling.annotation.Scheduled;
import org.springframework.stereotype.Component;

@Component
@RequiredArgsConstructor
public class MonthlyRaffleScheduler {

    private final MonthlyRaffleService raffleService;

    @Scheduled(cron = "0 5 0 10 * *", zone = "Asia/Seoul")
    public void drawMonthlyRaffle() {
        raffleService.drawCurrentMonth();
    }
}
