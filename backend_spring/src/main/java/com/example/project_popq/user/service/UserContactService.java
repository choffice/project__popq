package com.example.project_popq.user.service;

import com.example.project_popq.common.error.BusinessException;
import com.example.project_popq.common.error.ErrorCode;
import com.example.project_popq.user.domain.User;
import com.example.project_popq.user.repository.UserRepository;
import lombok.RequiredArgsConstructor;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

@Service
@RequiredArgsConstructor
public class UserContactService {

    private final UserRepository userRepository;

    @Transactional
    public void updatePhone(Long userId, String phone) {
        String normalizedPhone = phone.trim().replaceAll("-", "");

        if (userRepository.existsByPhoneAndIdNot(normalizedPhone, userId)) {
            throw new BusinessException(ErrorCode.DUPLICATE_PHONE);
        }

        User user = userRepository.findById(userId)
                .orElseThrow(() -> new BusinessException(ErrorCode.USER_NOT_FOUND));
        user.changePhone(normalizedPhone);
    }
}
