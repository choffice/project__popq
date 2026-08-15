package com.example.project_popq.point.service;

import com.example.project_popq.common.error.BusinessException;
import com.example.project_popq.common.error.ErrorCode;
import com.example.project_popq.order.domain.Order;
import com.example.project_popq.payment.domain.Payment;
import com.example.project_popq.payment.domain.Refund;
import com.example.project_popq.payment.domain.RefundStatus;
import com.example.project_popq.point.domain.CustomerPointTransaction;
import com.example.project_popq.point.dto.CustomerPointHistoryResponse;
import com.example.project_popq.point.dto.CustomerPointSummaryResponse;
import com.example.project_popq.point.repository.CustomerPointTransactionRepository;
import com.example.project_popq.user.domain.PlatformRole;
import com.example.project_popq.user.domain.User;
import java.time.Instant;
import java.util.List;
import lombok.RequiredArgsConstructor;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

@Service
@RequiredArgsConstructor
public class CustomerPointService {

    private static final long WON_PER_POINT = 40L;
    private static final double REWARD_RATE_PERCENT = 2.5;

    private final CustomerPointTransactionRepository pointTransactionRepository;

    @Transactional(readOnly = true)
    public CustomerPointSummaryResponse getSummary(User user) {
        if (!user.hasRole(PlatformRole.CUSTOMER)) {
            throw new BusinessException(ErrorCode.ACCESS_DENIED);
        }

        List<CustomerPointHistoryResponse> histories = pointTransactionRepository
                .findAllByUserIdOrderByOccurredAtDescIdDesc(user.getId())
                .stream()
                .map(CustomerPointHistoryResponse::from)
                .toList();

        return new CustomerPointSummaryResponse(
                pointTransactionRepository.findBalanceByUserId(user.getId()),
                REWARD_RATE_PERCENT,
                histories
        );
    }

    public void rewardPayment(Payment payment, Instant occurredAt) {
        Order order = payment.getOrder();
        User user = order.getUser();
        Long approvedAmount = payment.getApprovedAmount();

        if (user == null || approvedAmount == null) {
            return;
        }

        String sourceKey = "PAYMENT:" + payment.getId();
        if (pointTransactionRepository.existsBySourceKey(sourceKey)) {
            return;
        }

        long points = pointsFor(approvedAmount);
        if (points <= 0) {
            return;
        }

        pointTransactionRepository.save(
                CustomerPointTransaction.paymentReward(
                        user,
                        payment.getId(),
                        order.getOrderPublicId(),
                        order.getStore().getName(),
                        approvedAmount,
                        points,
                        occurredAt
                )
        );
    }

    public void reclaimRefund(Payment payment, Refund refund, Instant occurredAt) {
        Order order = payment.getOrder();
        User user = order.getUser();
        Long approvedAmount = payment.getApprovedAmount();

        if (user == null || approvedAmount == null) {
            return;
        }

        String refundSourceKey = "REFUND:" + payment.getId()
                + ":" + refund.getRequestedAt();
        if (pointTransactionRepository.existsBySourceKey(refundSourceKey)
                || pointTransactionRepository.findBySourceKey(
                        "PAYMENT:" + payment.getId()
                ).isEmpty()) {
            return;
        }

        long refundedAmount = payment.getRefunds()
                .stream()
                .filter(item -> item.getStatus() == RefundStatus.SUCCEEDED)
                .mapToLong(Refund::getAmount)
                .sum();
        long remainingPaymentAmount = Math.max(0L, approvedAmount - refundedAmount);
        long desiredPoints = pointsFor(remainingPaymentAmount);
        long currentOrderPoints = pointTransactionRepository
                .findBalanceByUserIdAndOrderPublicId(
                        user.getId(),
                        order.getOrderPublicId()
                );
        long reclaimedPoints = Math.max(0L, currentOrderPoints - desiredPoints);

        if (reclaimedPoints <= 0) {
            return;
        }

        pointTransactionRepository.save(
                CustomerPointTransaction.refundReclaim(
                        user,
                        refundSourceKey,
                        order.getOrderPublicId(),
                        order.getStore().getName(),
                        refund.getAmount(),
                        reclaimedPoints,
                        occurredAt
                )
        );
    }

    public long getBalance(Long userId) {
        return pointTransactionRepository.findBalanceByUserId(userId);
    }

    public void spendRaffleTicket(
            User user,
            Long entryId,
            String roundMonth,
            long pointCost,
            Instant occurredAt
    ) {
        pointTransactionRepository.save(
                CustomerPointTransaction.raffleTicketPurchase(
                        user,
                        entryId,
                        roundMonth,
                        pointCost,
                        occurredAt
                )
        );
    }

    private long pointsFor(long paymentAmount) {
        return paymentAmount / WON_PER_POINT;
    }
}
