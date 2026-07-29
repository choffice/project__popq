package com.example.project_popq.store.service;

import com.example.project_popq.common.error.BusinessException;
import com.example.project_popq.common.error.ErrorCode;
import com.example.project_popq.store.domain.StoreMember;
import com.example.project_popq.store.domain.StoreMemberStatus;
import com.example.project_popq.store.domain.StoreRole;
import com.example.project_popq.store.repository.StoreMemberRepository;
import java.util.Arrays;
import java.util.EnumSet;
import lombok.RequiredArgsConstructor;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

@Service
@RequiredArgsConstructor
public class StoreAuthorizationService {

    private final StoreMemberRepository storeMemberRepository;

    @Transactional(readOnly = true)
    public StoreMember requireAnyRole(
            Long userId,
            Long storeId,
            StoreRole... allowedRoles
    ) {
        StoreMember member = storeMemberRepository
                .findByStoreIdAndUserIdAndStatus(
                        storeId,
                        userId,
                        StoreMemberStatus.ACTIVE
                )
                .orElseThrow(() -> new BusinessException(ErrorCode.STORE_ACCESS_DENIED));

        EnumSet<StoreRole> allowed = EnumSet.noneOf(StoreRole.class);
        allowed.addAll(Arrays.asList(allowedRoles));
        if (!allowed.contains(member.getRole())) {
            throw new BusinessException(ErrorCode.STORE_ACCESS_DENIED);
        }
        return member;
    }
}

