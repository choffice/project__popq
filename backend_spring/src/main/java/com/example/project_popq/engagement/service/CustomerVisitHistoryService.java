package com.example.project_popq.engagement.service;

import com.example.project_popq.order.dto.VisitedStoreResponse;
import com.example.project_popq.order.repository.OrderRepository;
import com.example.project_popq.payment.domain.PaymentStatus;
import com.example.project_popq.user.domain.User;
import java.util.List;
import lombok.RequiredArgsConstructor;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

@Service
@RequiredArgsConstructor
public class CustomerVisitHistoryService {

    private final OrderRepository orderRepository;

    @Transactional(readOnly = true)
    public List<VisitedStoreResponse> findVisitedStores(User user) {
        return orderRepository.findVisitedStoresByUserId(
                user.getId(),
                PaymentStatus.PAID
        );
    }
}
