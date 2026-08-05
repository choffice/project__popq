package com.example.project_popq.admin.service;

import com.example.project_popq.admin.dto.AdminOverviewResponse;
import com.example.project_popq.admin.dto.AdminSellerResponse;
import com.example.project_popq.admin.dto.AdminStoreResponse;
import com.example.project_popq.admin.dto.AdminUserResponse;
import com.example.project_popq.common.error.BusinessException;
import com.example.project_popq.common.error.ErrorCode;
import com.example.project_popq.seller.domain.SellerProfile;
import com.example.project_popq.seller.domain.SellerVerificationStatus;
import com.example.project_popq.seller.repository.SellerProfileRepository;
import com.example.project_popq.store.domain.Store;
import com.example.project_popq.store.domain.StoreStatus;
import com.example.project_popq.store.repository.StoreRepository;
import com.example.project_popq.user.domain.PlatformRole;
import com.example.project_popq.user.domain.User;
import com.example.project_popq.user.domain.UserStatus;
import com.example.project_popq.user.repository.UserRepository;
import java.util.List;
import lombok.RequiredArgsConstructor;
import org.springframework.data.domain.Sort;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

@Service
@RequiredArgsConstructor
public class AdminOperationsService {

    private static final Sort ID_ASC = Sort.by(Sort.Direction.ASC, "id");

    private final UserRepository userRepository;
    private final SellerProfileRepository sellerProfileRepository;
    private final StoreRepository storeRepository;

    @Transactional(readOnly = true)
    public AdminOverviewResponse overview(User currentUser) {
        requireAdmin(currentUser);
        List<User> users = userRepository.findAll();
        List<SellerProfile> sellers = sellerProfileRepository.findAll();
        List<Store> stores = storeRepository.findAll();
        return new AdminOverviewResponse(
                users.size(),
                users.stream().filter(User::isActive).count(),
                sellers.size(),
                sellers.stream()
                        .filter(seller -> seller.getVerificationStatus()
                                == SellerVerificationStatus.PENDING)
                        .count(),
                stores.size(),
                stores.stream().filter(Store::isActive).count(),
                stores.stream()
                        .filter(store -> store.getStatus() == StoreStatus.SUSPENDED)
                        .count()
        );
    }

    @Transactional(readOnly = true)
    public List<AdminUserResponse> users(User currentUser) {
        requireAdmin(currentUser);
        return userRepository.findAll(ID_ASC).stream()
                .map(AdminUserResponse::from)
                .toList();
    }

    @Transactional(readOnly = true)
    public List<AdminSellerResponse> sellers(User currentUser) {
        requireAdmin(currentUser);
        return sellerProfileRepository.findAll(ID_ASC).stream()
                .map(AdminSellerResponse::from)
                .toList();
    }

    @Transactional(readOnly = true)
    public List<AdminStoreResponse> stores(User currentUser) {
        requireAdmin(currentUser);
        return storeRepository.findAll(ID_ASC).stream()
                .map(AdminStoreResponse::from)
                .toList();
    }

    @Transactional
    public AdminUserResponse changeUserStatus(
            User currentUser,
            Long userId,
            UserStatus status
    ) {
        requireAdmin(currentUser);
        if (currentUser.getId().equals(userId) && status != UserStatus.ACTIVE) {
            throw new BusinessException(
                    ErrorCode.INVALID_REQUEST,
                    "현재 관리자 자신의 계정은 정지하거나 탈퇴 처리할 수 없습니다."
            );
        }
        User user = userRepository.findById(userId)
                .orElseThrow(() -> new BusinessException(ErrorCode.USER_NOT_FOUND));
        user.changeStatus(status);
        return AdminUserResponse.from(user);
    }

    @Transactional
    public AdminSellerResponse changeSellerVerification(
            User currentUser,
            Long sellerProfileId,
            SellerVerificationStatus status
    ) {
        requireAdmin(currentUser);
        SellerProfile profile = sellerProfileRepository.findById(sellerProfileId)
                .orElseThrow(() -> new BusinessException(
                        ErrorCode.SELLER_PROFILE_NOT_FOUND
                ));
        profile.changeVerificationStatus(status);
        return AdminSellerResponse.from(profile);
    }

    @Transactional
    public AdminStoreResponse changeStoreStatus(
            User currentUser,
            Long storeId,
            StoreStatus status
    ) {
        requireAdmin(currentUser);
        Store store = storeRepository.findById(storeId)
                .orElseThrow(() -> new BusinessException(ErrorCode.STORE_NOT_FOUND));
        store.changeStatus(status);
        return AdminStoreResponse.from(store);
    }

    private void requireAdmin(User currentUser) {
        if (!currentUser.hasRole(PlatformRole.ADMIN)) {
            throw new BusinessException(ErrorCode.ACCESS_DENIED);
        }
    }
}
