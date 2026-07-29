package com.example.project_popq.store.service;

import com.example.project_popq.common.error.BusinessException;
import com.example.project_popq.common.error.ErrorCode;
import com.example.project_popq.store.domain.Store;
import com.example.project_popq.store.domain.StoreMember;
import com.example.project_popq.store.domain.StoreMemberStatus;
import com.example.project_popq.store.domain.StoreRole;
import com.example.project_popq.store.domain.StoreTable;
import com.example.project_popq.store.domain.StoreTag;
import com.example.project_popq.store.domain.StoreType;
import com.example.project_popq.product.domain.Tag;
import com.example.project_popq.product.domain.TagType;
import com.example.project_popq.product.repository.TagRepository;
import com.example.project_popq.store.dto.ChangeBusinessStatusRequest;
import com.example.project_popq.store.dto.CreateStoreRequest;
import com.example.project_popq.store.dto.CreateStoreTableRequest;
import com.example.project_popq.store.dto.SellerStoreDetailResponse;
import com.example.project_popq.store.dto.StoreSummaryResponse;
import com.example.project_popq.store.dto.StoreTableResponse;
import com.example.project_popq.store.dto.UpdateStoreRequest;
import com.example.project_popq.store.repository.StoreMemberRepository;
import com.example.project_popq.store.repository.StoreRepository;
import com.example.project_popq.store.repository.StoreTableRepository;
import com.example.project_popq.store.repository.StoreTagRepository;
import com.example.project_popq.user.domain.PlatformRole;
import com.example.project_popq.user.domain.User;
import java.util.List;
import lombok.RequiredArgsConstructor;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

@Service
@RequiredArgsConstructor
public class StoreApplicationService {

    private final StoreRepository storeRepository;
    private final StoreMemberRepository storeMemberRepository;
    private final StoreTableRepository storeTableRepository;
    private final StoreTagRepository storeTagRepository;
    private final TagRepository tagRepository;
    private final StoreAuthorizationService storeAuthorizationService;

    @Transactional
    public StoreSummaryResponse create(User currentUser, CreateStoreRequest request) {
        if (currentUser.getRole() != PlatformRole.SELLER
                && currentUser.getRole() != PlatformRole.ADMIN) {
            throw new BusinessException(ErrorCode.ACCESS_DENIED);
        }

        Store store = Store.create(
                request.storeType(),
                request.name().trim(),
                normalizeDescription(request.description())
        );
        validateLocation(request.latitude(), request.longitude());
        store.updateDiscoveryProfile(
                normalizeDescription(request.address()),
                request.latitude(),
                request.longitude()
        );
        storeRepository.save(store);
        saveTags(store, request.tags());

        StoreMember owner = StoreMember.create(store, currentUser, StoreRole.OWNER);
        storeMemberRepository.save(owner);
        return StoreSummaryResponse.of(store, owner.getRole());
    }

    @Transactional(readOnly = true)
    public List<StoreSummaryResponse> findMyStores(User currentUser) {
        return storeMemberRepository
                .findAllByUserIdAndStatusOrderByIdAsc(
                        currentUser.getId(),
                        StoreMemberStatus.ACTIVE
                )
                .stream()
                .map(member -> StoreSummaryResponse.of(
                        member.getStore(),
                        member.getRole()
                ))
                .toList();
    }

    @Transactional(readOnly = true)
    public SellerStoreDetailResponse findOne(User currentUser, Long storeId) {
        StoreMember member = storeAuthorizationService.requireAnyRole(
                currentUser.getId(),
                storeId,
                StoreRole.OWNER,
                StoreRole.MANAGER,
                StoreRole.STAFF
        );
        return detail(member);
    }

    @Transactional
    public SellerStoreDetailResponse update(
            User currentUser,
            Long storeId,
            UpdateStoreRequest request
    ) {
        StoreMember member = storeAuthorizationService.requireAnyRole(
                currentUser.getId(),
                storeId,
                StoreRole.OWNER,
                StoreRole.MANAGER
        );
        validateLocation(request.latitude(), request.longitude());
        Store store = member.getStore();
        store.updateSellerProfile(
                request.name().trim(),
                normalizeDescription(request.description()),
                normalizeDescription(request.address()),
                request.latitude(),
                request.longitude()
        );
        storeTagRepository.deleteAllByStoreId(storeId);
        storeTagRepository.flush();
        saveTags(store, request.tags());
        return detail(member);
    }

    @Transactional
    public StoreSummaryResponse changeBusinessStatus(
            User currentUser,
            Long storeId,
            ChangeBusinessStatusRequest request
    ) {
        StoreMember member = storeAuthorizationService.requireAnyRole(
                currentUser.getId(),
                storeId,
                StoreRole.OWNER,
                StoreRole.MANAGER
        );
        Store store = member.getStore();
        store.changeBusinessStatus(request.businessStatus());
        return StoreSummaryResponse.of(store, member.getRole());
    }

    @Transactional
    public StoreTableResponse createTable(
            User currentUser,
            Long storeId,
            CreateStoreTableRequest request
    ) {
        storeAuthorizationService.requireAnyRole(
                currentUser.getId(),
                storeId,
                StoreRole.OWNER,
                StoreRole.MANAGER
        );
        Store store = storeRepository.findById(storeId)
                .orElseThrow(() -> new BusinessException(ErrorCode.STORE_NOT_FOUND));
        if (store.getStoreType() != StoreType.LOCAL_STORE) {
            throw new BusinessException(ErrorCode.STORE_TABLE_NOT_ALLOWED);
        }

        String tableCode = request.tableCode().trim().toUpperCase();
        if (storeTableRepository.existsByStoreIdAndTableCodeIgnoreCase(
                storeId,
                tableCode
        )) {
            throw new BusinessException(ErrorCode.DUPLICATE_STORE_TABLE);
        }
        StoreTable table = storeTableRepository.save(
                StoreTable.create(store, tableCode, request.name().trim())
        );
        return StoreTableResponse.from(table);
    }

    @Transactional(readOnly = true)
    public List<StoreTableResponse> findTables(User currentUser, Long storeId) {
        storeAuthorizationService.requireAnyRole(
                currentUser.getId(),
                storeId,
                StoreRole.OWNER,
                StoreRole.MANAGER,
                StoreRole.STAFF
        );
        return storeTableRepository.findAllByStoreIdOrderByIdAsc(storeId)
                .stream()
                .map(StoreTableResponse::from)
                .toList();
    }

    private String normalizeDescription(String description) {
        if (description == null || description.isBlank()) {
            return null;
        }
        return description.trim();
    }

    private void validateLocation(
            java.math.BigDecimal latitude,
            java.math.BigDecimal longitude
    ) {
        if ((latitude == null) != (longitude == null)) {
            throw new BusinessException(ErrorCode.INVALID_REQUEST);
        }
    }

    private void saveTags(Store store, List<String> requestedTags) {
        if (requestedTags == null || requestedTags.isEmpty()) {
            return;
        }
        requestedTags.stream()
                .map(String::trim)
                .filter(value -> !value.isBlank())
                .map(String::toLowerCase)
                .distinct()
                .map(name -> tagRepository
                        .findByNameIgnoreCaseAndTagType(name, TagType.STORE)
                        .orElseGet(() -> tagRepository.save(
                                Tag.create(name, TagType.STORE)
                        )))
                .map(tag -> StoreTag.create(store, tag))
                .forEach(storeTagRepository::save);
    }

    private SellerStoreDetailResponse detail(StoreMember member) {
        List<String> tags = storeTagRepository
                .findAllByStoreId(member.getStore().getId())
                .stream()
                .map(storeTag -> storeTag.getTag().getName())
                .toList();
        return SellerStoreDetailResponse.of(
                member.getStore(),
                member.getRole(),
                tags
        );
    }
}
