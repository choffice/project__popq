package com.example.project_popq.engagement.service;

import com.example.project_popq.common.error.BusinessException;
import com.example.project_popq.common.error.ErrorCode;
import com.example.project_popq.engagement.domain.StoreInterest;
import com.example.project_popq.engagement.dto.InterestStateResponse;
import com.example.project_popq.engagement.dto.StoreInterestResponse;
import com.example.project_popq.engagement.repository.StoreInterestRepository;
import com.example.project_popq.store.domain.Store;
import com.example.project_popq.store.repository.StoreRepository;
import com.example.project_popq.user.domain.PlatformRole;
import com.example.project_popq.user.domain.User;
import java.util.List;
import lombok.RequiredArgsConstructor;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

@Service
@RequiredArgsConstructor
public class StoreInterestService {

    private final StoreInterestRepository storeInterestRepository;
    private final StoreRepository storeRepository;

    @Transactional(readOnly = true)
    public List<StoreInterestResponse> findAll(User user) {
        requireCustomer(user);
        return storeInterestRepository
                .findAllByUserIdOrderByCreatedAtDesc(user.getId())
                .stream()
                .map(StoreInterestResponse::from)
                .toList();
    }

    @Transactional(readOnly = true)
    public InterestStateResponse getState(User user, Long storeId) {
        requireCustomer(user);
        return new InterestStateResponse(
                storeId,
                storeInterestRepository.existsByUserIdAndStoreId(
                        user.getId(),
                        storeId
                )
        );
    }

    @Transactional
    public InterestStateResponse add(User user, Long storeId) {
        requireCustomer(user);
        if (storeInterestRepository.existsByUserIdAndStoreId(
                user.getId(),
                storeId
        )) {
            return new InterestStateResponse(storeId, true);
        }
        Store store = storeRepository.findById(storeId)
                .orElseThrow(() -> new BusinessException(ErrorCode.STORE_NOT_FOUND));
        if (!store.isOpen()) {
            throw new BusinessException(ErrorCode.STORE_NOT_FOUND);
        }
        storeInterestRepository.save(StoreInterest.create(user, store));
        return new InterestStateResponse(storeId, true);
    }

    @Transactional
    public InterestStateResponse remove(User user, Long storeId) {
        requireCustomer(user);
        storeInterestRepository.findByUserIdAndStoreId(user.getId(), storeId)
                .ifPresent(storeInterestRepository::delete);
        return new InterestStateResponse(storeId, false);
    }

    private void requireCustomer(User user) {
        if (user.getRole() != PlatformRole.CUSTOMER) {
            throw new BusinessException(ErrorCode.ACCESS_DENIED);
        }
    }
}
