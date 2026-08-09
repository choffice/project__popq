package com.example.project_popq.user.service;

import com.example.project_popq.common.error.BusinessException;
import com.example.project_popq.common.error.ErrorCode;
import com.example.project_popq.user.domain.User;
import com.example.project_popq.user.dto.NotificationPreferenceResponse;
import com.example.project_popq.user.repository.UserRepository;
import lombok.RequiredArgsConstructor;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

@Service
@RequiredArgsConstructor
public class UserNotificationPreferenceService {

    private final UserRepository userRepository;

    @Transactional(readOnly = true)
    public NotificationPreferenceResponse get(Long userId) {
        User user = userRepository.findById(userId)
                .orElseThrow(() -> new BusinessException(ErrorCode.USER_NOT_FOUND));
        return new NotificationPreferenceResponse(
                user.isPushNotificationEnabled(),
                user.isMarketingOptIn()
        );
    }

    @Transactional
    public NotificationPreferenceResponse update(
            Long userId,
            boolean pushNotificationEnabled,
            boolean marketingOptIn
    ) {
        User user = userRepository.findById(userId)
                .orElseThrow(() -> new BusinessException(ErrorCode.USER_NOT_FOUND));
        user.changeNotificationPreferences(pushNotificationEnabled, marketingOptIn);
        return new NotificationPreferenceResponse(pushNotificationEnabled, marketingOptIn);
    }
}
