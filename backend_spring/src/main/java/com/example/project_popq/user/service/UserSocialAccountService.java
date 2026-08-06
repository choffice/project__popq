package com.example.project_popq.user.service;

import com.example.project_popq.user.dto.LinkedSocialAccountsResponse;
import com.example.project_popq.user.repository.SocialAccountRepository;
import java.util.List;
import lombok.RequiredArgsConstructor;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

@Service
@RequiredArgsConstructor
public class UserSocialAccountService {

    private final SocialAccountRepository socialAccountRepository;

    @Transactional(readOnly = true)
    public LinkedSocialAccountsResponse list(Long userId) {
        List<String> providers = socialAccountRepository.findAllByUserId(userId).stream()
                .map(account -> account.getProvider().name())
                .distinct()
                .toList();
        return new LinkedSocialAccountsResponse(providers);
    }
}
