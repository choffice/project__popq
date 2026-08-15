package com.example.project_popq.admin.service;

import com.example.project_popq.admin.dto.AdminOverviewResponse;
import com.example.project_popq.admin.dto.AdminSellerResponse;
import com.example.project_popq.admin.dto.AdminStoreResponse;
import com.example.project_popq.admin.dto.AdminUserResponse;
import com.example.project_popq.admin.domain.AdminAuditLog;
import com.example.project_popq.admin.repository.AdminAuditLogRepository;
import com.example.project_popq.common.api.PageResponse;
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
import org.springframework.data.domain.Page;
import org.springframework.data.domain.PageRequest;
import org.springframework.data.domain.Sort;
import org.springframework.data.jpa.domain.Specification;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

@Service
@RequiredArgsConstructor
public class AdminOperationsService {

    private static final Sort ID_ASC = Sort.by(Sort.Direction.ASC, "id");

    private final UserRepository userRepository;
    private final SellerProfileRepository sellerProfileRepository;
    private final StoreRepository storeRepository;
    private final AdminAuditLogRepository adminAuditLogRepository;

    @Transactional(readOnly = true)
    public AdminOverviewResponse overview(User currentUser) {
        requireAdmin(currentUser);
        return new AdminOverviewResponse(
                userRepository.count(),
                userRepository.countByStatus(UserStatus.ACTIVE),
                sellerProfileRepository.count(),
                sellerProfileRepository.countByVerificationStatus(
                        SellerVerificationStatus.PENDING
                ),
                storeRepository.count(),
                storeRepository.countByStatus(StoreStatus.ACTIVE),
                storeRepository.countByStatus(StoreStatus.SUSPENDED)
        );
    }

    @Transactional(readOnly = true)
    public List<AdminUserResponse> users(User currentUser) {
        return users(currentUser, 0, 100, null, null, null, "asc").content();
    }

    @Transactional(readOnly = true)
    public PageResponse<AdminUserResponse> users(
            User currentUser,
            int page,
            int size,
            String query,
            PlatformRole role,
            UserStatus status,
            String sort
    ) {
        requireAdmin(currentUser);
        String search = normalizeQuery(query);
        Specification<User> specification = (root, criteriaQuery, builder) -> {
            var predicate = builder.conjunction();
            if (search != null) {
                String pattern = "%" + search.toLowerCase() + "%";
                predicate = builder.and(predicate, builder.or(
                        builder.like(builder.lower(root.get("name")), pattern),
                        builder.like(
                                builder.lower(builder.coalesce(root.get("email"), "")),
                                pattern
                        )
                ));
            }
            if (status != null) {
                predicate = builder.and(
                        predicate,
                        builder.equal(root.get("status"), status)
                );
            }
            if (role != null) {
                criteriaQuery.distinct(true);
                var roles = root.joinSet("roles", jakarta.persistence.criteria.JoinType.LEFT);
                predicate = builder.and(predicate, builder.or(
                        builder.equal(root.get("role"), role),
                        builder.equal(roles, role)
                ));
            }
            return predicate;
        };
        Page<AdminUserResponse> result = userRepository
                .findAll(specification, pageRequest(page, size, sort))
                .map(AdminUserResponse::from);
        return PageResponse.from(result);
    }

    @Transactional(readOnly = true)
    public List<AdminSellerResponse> sellers(User currentUser) {
        return sellers(currentUser, 0, 100, null, null, null, "asc").content();
    }

    @Transactional(readOnly = true)
    public PageResponse<AdminSellerResponse> sellers(
            User currentUser,
            int page,
            int size,
            String query,
            SellerVerificationStatus verificationStatus,
            UserStatus userStatus,
            String sort
    ) {
        requireAdmin(currentUser);
        String search = normalizeQuery(query);
        Specification<SellerProfile> specification = (root, ignored, builder) -> {
            var predicate = builder.conjunction();
            if (search != null) {
                String pattern = "%" + search.toLowerCase() + "%";
                predicate = builder.and(predicate, builder.or(
                        builder.like(builder.lower(root.get("user").get("name")), pattern),
                        builder.like(
                                builder.lower(builder.coalesce(root.get("user").get("email"), "")),
                                pattern
                        ),
                        builder.like(
                                builder.lower(builder.coalesce(root.get("businessName"), "")),
                                pattern
                        ),
                        builder.like(
                                builder.lower(builder.coalesce(root.get("businessRegistrationNumber"), "")),
                                pattern
                        )
                ));
            }
            if (verificationStatus != null) {
                predicate = builder.and(
                        predicate,
                        builder.equal(root.get("verificationStatus"), verificationStatus)
                );
            }
            if (userStatus != null) {
                predicate = builder.and(
                        predicate,
                        builder.equal(root.get("user").get("status"), userStatus)
                );
            }
            return predicate;
        };
        Page<AdminSellerResponse> result = sellerProfileRepository
                .findAll(specification, pageRequest(page, size, sort))
                .map(AdminSellerResponse::from);
        return PageResponse.from(result);
    }

    @Transactional(readOnly = true)
    public List<AdminStoreResponse> stores(User currentUser) {
        return stores(currentUser, 0, 100, null, null, "asc").content();
    }

    @Transactional(readOnly = true)
    public PageResponse<AdminStoreResponse> stores(
            User currentUser,
            int page,
            int size,
            String query,
            StoreStatus status,
            String sort
    ) {
        requireAdmin(currentUser);
        String search = normalizeQuery(query);
        Specification<Store> specification = (root, ignored, builder) -> {
            var predicate = builder.conjunction();
            if (search != null) {
                String pattern = "%" + search.toLowerCase() + "%";
                predicate = builder.and(
                        predicate,
                        builder.like(builder.lower(root.get("name")), pattern)
                );
            }
            if (status != null) {
                predicate = builder.and(
                        predicate,
                        builder.equal(root.get("status"), status)
                );
            }
            return predicate;
        };
        Page<AdminStoreResponse> result = storeRepository
                .findAll(specification, pageRequest(page, size, sort))
                .map(AdminStoreResponse::from);
        return PageResponse.from(result);
    }

    @Transactional
    public AdminUserResponse changeUserStatus(
            User currentUser,
            Long userId,
            UserStatus status
    ) {
        return changeUserStatus(currentUser, userId, status, null);
    }

    @Transactional
    public AdminUserResponse changeUserStatus(
            User currentUser,
            Long userId,
            UserStatus status,
            String reason
    ) {
        requireAdmin(currentUser);
        if (status != UserStatus.ACTIVE && status != UserStatus.SUSPENDED) {
            throw new BusinessException(
                    ErrorCode.INVALID_REQUEST,
                    "관리자는 사용자를 활성 또는 이용정지 상태로만 변경할 수 있습니다."
            );
        }
        if (currentUser.getId().equals(userId) && status != UserStatus.ACTIVE) {
            throw new BusinessException(
                    ErrorCode.INVALID_REQUEST,
                    "현재 관리자 자신의 계정은 정지하거나 탈퇴 처리할 수 없습니다."
            );
        }
        User user = userRepository.findById(userId)
                .orElseThrow(() -> new BusinessException(ErrorCode.USER_NOT_FOUND));
        UserStatus before = user.getStatus();
        user.changeStatus(status);
        adminAuditLogRepository.save(AdminAuditLog.create(
                currentUser,
                "USER",
                userId,
                "CHANGE_STATUS",
                before,
                status,
                reason
        ));
        return AdminUserResponse.from(user);
    }

    @Transactional
    public AdminSellerResponse changeSellerVerification(
            User currentUser,
            Long sellerProfileId,
            SellerVerificationStatus status
    ) {
        return changeSellerVerification(currentUser, sellerProfileId, status, null);
    }

    @Transactional
    public AdminSellerResponse changeSellerVerification(
            User currentUser,
            Long sellerProfileId,
            SellerVerificationStatus status,
            String reason
    ) {
        requireAdmin(currentUser);
        SellerProfile profile = sellerProfileRepository.findById(sellerProfileId)
                .orElseThrow(() -> new BusinessException(
                        ErrorCode.SELLER_PROFILE_NOT_FOUND
                ));
        SellerVerificationStatus before = profile.getVerificationStatus();
        profile.changeVerificationStatus(status);
        adminAuditLogRepository.save(AdminAuditLog.create(
                currentUser,
                "SELLER_PROFILE",
                sellerProfileId,
                "CHANGE_VERIFICATION",
                before,
                status,
                reason
        ));
        return AdminSellerResponse.from(profile);
    }

    @Transactional
    public AdminStoreResponse changeStoreStatus(
            User currentUser,
            Long storeId,
            StoreStatus status
    ) {
        return changeStoreStatus(currentUser, storeId, status, null);
    }

    @Transactional
    public AdminStoreResponse changeStoreStatus(
            User currentUser,
            Long storeId,
            StoreStatus status,
            String reason
    ) {
        requireAdmin(currentUser);
        if (status != StoreStatus.ACTIVE && status != StoreStatus.SUSPENDED) {
            throw new BusinessException(
                    ErrorCode.INVALID_REQUEST,
                    "관리자는 스토어를 활성 또는 운영정지 상태로만 변경할 수 있습니다."
            );
        }
        Store store = storeRepository.findById(storeId)
                .orElseThrow(() -> new BusinessException(ErrorCode.STORE_NOT_FOUND));
        StoreStatus before = store.getStatus();
        store.changeStatus(status);
        adminAuditLogRepository.save(AdminAuditLog.create(
                currentUser,
                "STORE",
                storeId,
                "CHANGE_STATUS",
                before,
                status,
                reason
        ));
        return AdminStoreResponse.from(store);
    }

    private PageRequest pageRequest(int page, int size, String sort) {
        int safePage = Math.max(page, 0);
        int safeSize = Math.max(1, Math.min(size, 100));
        Sort.Direction direction = "asc".equalsIgnoreCase(sort)
                ? Sort.Direction.ASC
                : Sort.Direction.DESC;
        return PageRequest.of(safePage, safeSize, Sort.by(direction, "id"));
    }

    private String normalizeQuery(String query) {
        if (query == null || query.isBlank()) {
            return null;
        }
        return query.trim();
    }

    private void requireAdmin(User currentUser) {
        if (!currentUser.hasRole(PlatformRole.ADMIN)) {
            throw new BusinessException(ErrorCode.ACCESS_DENIED);
        }
    }
}
