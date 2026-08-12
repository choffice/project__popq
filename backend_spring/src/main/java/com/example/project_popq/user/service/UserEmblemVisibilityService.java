package com.example.project_popq.user.service;

import com.example.project_popq.common.error.BusinessException;
import com.example.project_popq.common.error.ErrorCode;
import com.example.project_popq.user.domain.User;
import com.example.project_popq.user.dto.EmblemVisibilityResponse;
import com.example.project_popq.user.repository.UserRepository;
import lombok.RequiredArgsConstructor;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

@Service
@RequiredArgsConstructor
public class UserEmblemVisibilityService {

    private final UserRepository userRepository;

    @Transactional
    public EmblemVisibilityResponse update(Long userId, boolean emblemVisible) {
        User user = userRepository.findById(userId)
                .orElseThrow(() -> new BusinessException(ErrorCode.USER_NOT_FOUND));
        user.changeEmblemVisibility(emblemVisible);
        return new EmblemVisibilityResponse(emblemVisible);
    }
}
