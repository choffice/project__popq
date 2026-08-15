package com.example.project_popq.engagement.service;

import com.example.project_popq.activity.service.CustomerActivityService;
import com.example.project_popq.auth.dto.AuthUserResponse;
import com.example.project_popq.common.error.BusinessException;
import com.example.project_popq.common.error.ErrorCode;
import com.example.project_popq.engagement.domain.ReviewStatus;
import com.example.project_popq.engagement.dto.CustomerProfileResponse;
import com.example.project_popq.engagement.repository.ReviewRepository;
import com.example.project_popq.engagement.repository.StoreInterestRepository;
import com.example.project_popq.order.repository.OrderRepository;
import com.example.project_popq.user.domain.PlatformRole;
import com.example.project_popq.user.domain.User;
import lombok.RequiredArgsConstructor;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

@Service
@RequiredArgsConstructor
public class CustomerProfileService {

    private final StoreInterestRepository storeInterestRepository;
    private final ReviewRepository reviewRepository;
    private final OrderRepository orderRepository;
    private final CustomerActivityService customerActivityService;

    @Transactional(readOnly = true)
    public CustomerProfileResponse get(User user) {
        if (!user.hasRole(PlatformRole.CUSTOMER)) {
            throw new BusinessException(ErrorCode.ACCESS_DENIED);
        }
        return new CustomerProfileResponse(
                AuthUserResponse.from(user),
                storeInterestRepository.countByUserId(user.getId()),
                reviewRepository.countByUserIdAndStatus(
                        user.getId(),
                        ReviewStatus.ACTIVE
                ),
                orderRepository.countByUserId(user.getId()),
                customerActivityService.getSummary(user),
                user.isEmblemVisible()
        );
    }
}
