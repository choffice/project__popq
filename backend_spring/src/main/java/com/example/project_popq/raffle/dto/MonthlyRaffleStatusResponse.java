package com.example.project_popq.raffle.dto;

import java.time.LocalDate;

public record MonthlyRaffleStatusResponse(
        long pointBalance,
        long ticketPrice,
        String purchaseRound,
        LocalDate nextDrawDate,
        long purchasedTicketCount,
        boolean canPurchase,
        String resultRound,
        String result
) {
}
