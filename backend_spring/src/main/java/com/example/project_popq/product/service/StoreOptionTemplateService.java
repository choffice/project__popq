package com.example.project_popq.product.service;

import com.example.project_popq.common.error.BusinessException;
import com.example.project_popq.common.error.ErrorCode;
import com.example.project_popq.product.domain.ProductOptionGroup;
import com.example.project_popq.product.domain.StoreOptionGroupTemplate;
import com.example.project_popq.product.domain.StoreOptionTemplateOption;
import com.example.project_popq.product.dto.BulkApplyStoreOptionTemplateRequest;
import com.example.project_popq.product.dto.StoreOptionTemplateRequest;
import com.example.project_popq.product.dto.StoreOptionTemplateResponse;
import com.example.project_popq.product.dto.StoreOptionTemplateUsageResponse;
import com.example.project_popq.product.dto.StoreOptionTemplateUsageResponse.ProductUsage;
import com.example.project_popq.product.repository.ProductOptionGroupRepository;
import com.example.project_popq.product.repository.StoreOptionGroupTemplateRepository;
import com.example.project_popq.store.domain.Store;
import com.example.project_popq.store.domain.StoreRole;
import com.example.project_popq.store.repository.StoreRepository;
import com.example.project_popq.store.service.StoreAuthorizationService;
import com.example.project_popq.user.domain.User;
import java.util.HashSet;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Locale;
import java.util.Map;
import java.util.Set;
import lombok.RequiredArgsConstructor;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

@Service
@RequiredArgsConstructor
public class StoreOptionTemplateService {

    private final StoreOptionGroupTemplateRepository templateRepository;
    private final ProductOptionGroupRepository optionGroupRepository;
    private final StoreRepository storeRepository;
    private final StoreAuthorizationService storeAuthorizationService;

    @Transactional(readOnly = true)
    public List<StoreOptionTemplateResponse> findAll(User user, Long storeId) {
        requireManager(user, storeId);
        return templateRepository.findAllByStoreIdOrderByNameAsc(storeId)
                .stream()
                .map(StoreOptionTemplateResponse::from)
                .toList();
    }

    @Transactional(readOnly = true)
    public StoreOptionTemplateResponse findOne(
            User user,
            Long storeId,
            Long templateId
    ) {
        requireManager(user, storeId);
        return StoreOptionTemplateResponse.from(
                getTemplate(storeId, templateId)
        );
    }

    @Transactional
    public StoreOptionTemplateResponse create(
            User user,
            Long storeId,
            StoreOptionTemplateRequest request
    ) {
        requireManager(user, storeId);
        validate(
                request.name(), request.minSelect(), request.maxSelect(),
                request.required(), request.options().stream()
                        .map(option -> new OptionValue(
                                option.name(),
                                option.additionalPrice(),
                                option.displayOrder()
                        ))
                        .toList()
        );
        String name = request.name().trim();
        if (templateRepository.findByStoreIdAndNameIgnoreCase(storeId, name)
                .isPresent()) {
            throw new BusinessException(ErrorCode.INVALID_PRODUCT_OPTION);
        }
        Store store = storeRepository.findById(storeId)
                .orElseThrow(() -> new BusinessException(ErrorCode.STORE_NOT_FOUND));
        StoreOptionGroupTemplate template = StoreOptionGroupTemplate.create(
                store,
                name,
                request.minSelect(),
                request.maxSelect(),
                request.required()
        );
        request.options().forEach(option -> template.addOption(
                option.name().trim(),
                option.additionalPrice(),
                option.displayOrder()
        ));
        return StoreOptionTemplateResponse.from(templateRepository.save(template));
    }

    @Transactional(readOnly = true)
    public StoreOptionTemplateUsageResponse findUsage(
            User user,
            Long storeId,
            Long templateId
    ) {
        requireManager(user, storeId);
        getTemplate(storeId, templateId);
        Map<Long, ProductUsage> productsById = new LinkedHashMap<>();
        optionGroupRepository
                .findAllByStoreOptionGroupTemplateIdOrderByProductIdAsc(templateId)
                .forEach(group -> productsById.putIfAbsent(
                        group.getProduct().getId(),
                        new ProductUsage(
                                group.getProduct().getId(),
                                group.getProduct().getName()
                        )
                ));
        List<ProductUsage> products = List.copyOf(productsById.values());
        return new StoreOptionTemplateUsageResponse(
                templateId, products.size(), products
        );
    }

    @Transactional
    public StoreOptionTemplateResponse applyToAll(
            User user,
            Long storeId,
            Long templateId,
            BulkApplyStoreOptionTemplateRequest request
    ) {
        requireManager(user, storeId);
        List<OptionValue> options = request.options().stream()
                .map(option -> new OptionValue(
                        option.name(),
                        option.additionalPrice(),
                        option.displayOrder()
                ))
                .toList();
        validate(
                request.name(), request.minSelect(), request.maxSelect(),
                request.required(), options
        );

        StoreOptionGroupTemplate template = templateRepository
                .findLockedByIdAndStoreId(templateId, storeId)
                .orElseThrow(() -> new BusinessException(
                        ErrorCode.RESOURCE_NOT_FOUND
                ));
        ProductOptionGroup source = optionGroupRepository
                .findByIdAndProductIdAndStoreOptionGroupTemplateId(
                        request.sourceOptionGroupId(),
                        request.sourceProductId(),
                        templateId
                )
                .orElseThrow(() -> new BusinessException(
                        ErrorCode.INVALID_PRODUCT_OPTION
                ));
        if (!source.getProduct().getStore().getId().equals(storeId)) {
            throw new BusinessException(ErrorCode.STORE_ACCESS_DENIED);
        }

        List<StoreOptionTemplateOption.Value> values = options.stream()
                .map(option -> new StoreOptionTemplateOption.Value(
                        option.name().trim(),
                        option.additionalPrice(),
                        option.displayOrder()
                ))
                .toList();
        template.updateFrom(
                request.name().trim(),
                request.minSelect(),
                request.maxSelect(),
                request.required(),
                values
        );
        long newVersion = template.getVersion();
        List<ProductOptionGroup> groups = optionGroupRepository
                .findAllByStoreOptionGroupTemplateIdOrderByProductIdAsc(templateId);
        groups.forEach(group -> group.applyTemplateValues(
                request.name().trim(),
                request.minSelect(),
                request.maxSelect(),
                request.required(),
                newVersion,
                values
        ));
        optionGroupRepository.flush();
        return StoreOptionTemplateResponse.from(template);
    }

    @Transactional
    public void deleteIfUnused(User user, Long storeId, Long templateId) {
        requireManager(user, storeId);
        StoreOptionGroupTemplate template = templateRepository
                .findLockedByIdAndStoreId(templateId, storeId)
                .orElseThrow(() -> new BusinessException(
                        ErrorCode.RESOURCE_NOT_FOUND
                ));
        if (optionGroupRepository.countByStoreOptionGroupTemplateId(templateId) > 0) {
            throw new BusinessException(ErrorCode.INVALID_PRODUCT_OPTION);
        }
        templateRepository.delete(template);
    }

    private StoreOptionGroupTemplate getTemplate(Long storeId, Long templateId) {
        return templateRepository.findByIdAndStoreId(templateId, storeId)
                .orElseThrow(() -> new BusinessException(
                        ErrorCode.RESOURCE_NOT_FOUND
                ));
    }

    private void validate(
            String name,
            int minSelect,
            int maxSelect,
            boolean required,
            List<OptionValue> options
    ) {
        if (name == null || name.isBlank()
                || options.isEmpty()
                || maxSelect < minSelect
                || maxSelect > options.size()
                || (required && minSelect == 0)) {
            throw new BusinessException(ErrorCode.INVALID_PRODUCT_OPTION);
        }
        Set<String> optionNames = new HashSet<>();
        for (OptionValue option : options) {
            if (option.name() == null || option.name().isBlank()
                    || !optionNames.add(option.name().trim().toLowerCase(Locale.ROOT))) {
                throw new BusinessException(ErrorCode.INVALID_PRODUCT_OPTION);
            }
        }
    }

    private void requireManager(User user, Long storeId) {
        storeAuthorizationService.requireAnyRole(
                user.getId(), storeId, StoreRole.OWNER, StoreRole.MANAGER
        );
    }

    private record OptionValue(
            String name,
            long additionalPrice,
            int displayOrder
    ) {
    }
}
