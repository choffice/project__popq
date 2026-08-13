package com.example.project_popq.product;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertThrows;
import static org.mockito.Mockito.never;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

import com.example.project_popq.common.error.BusinessException;
import com.example.project_popq.product.domain.Product;
import com.example.project_popq.product.domain.ProductOptionGroup;
import com.example.project_popq.product.domain.StoreOptionGroupTemplate;
import com.example.project_popq.product.dto.BulkApplyStoreOptionTemplateRequest;
import com.example.project_popq.product.dto.BulkApplyStoreOptionTemplateRequest.OptionRequest;
import com.example.project_popq.product.repository.ProductOptionGroupRepository;
import com.example.project_popq.product.repository.StoreOptionGroupTemplateRepository;
import com.example.project_popq.product.service.StoreOptionTemplateService;
import com.example.project_popq.store.domain.Store;
import com.example.project_popq.store.repository.StoreRepository;
import com.example.project_popq.store.service.StoreAuthorizationService;
import com.example.project_popq.user.domain.User;
import java.util.List;
import java.util.Optional;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;

@ExtendWith(MockitoExtension.class)
class StoreOptionTemplateServiceTests {

    @Mock
    private StoreOptionGroupTemplateRepository templateRepository;
    @Mock
    private ProductOptionGroupRepository optionGroupRepository;
    @Mock
    private StoreRepository storeRepository;
    @Mock
    private StoreAuthorizationService storeAuthorizationService;
    @Mock
    private User user;
    @Mock
    private Store store;
    @Mock
    private Product sourceProduct;
    @Mock
    private Product otherProduct;

    private StoreOptionTemplateService service;

    @BeforeEach
    void setUp() {
        service = new StoreOptionTemplateService(
                templateRepository,
                optionGroupRepository,
                storeRepository,
                storeAuthorizationService
        );
        when(user.getId()).thenReturn(7L);
    }

    @Test
    void explicitBulkApplyUpdatesOnlyGroupsLinkedToTheTemplate() {
        long storeId = 10L;
        long templateId = 20L;
        StoreOptionGroupTemplate template = StoreOptionGroupTemplate.create(
                store, "온도", 1, 1, true
        );
        template.addOption("HOT", 0L, 0);
        template.addOption("ICE", 0L, 1);
        when(sourceProduct.getStore()).thenReturn(store);
        when(store.getId()).thenReturn(storeId);

        ProductOptionGroup sourceGroup = ProductOptionGroup.createFromTemplate(
                sourceProduct, "온도", 1, 1, true, 0, template, 1L
        );
        sourceGroup.addOption("HOT", 0L, 0);
        sourceGroup.addOption("ICE", 500L, 1);
        ProductOptionGroup otherGroup = ProductOptionGroup.createFromTemplate(
                otherProduct, "온도", 1, 1, true, 0, template, 1L
        );
        otherGroup.addOption("HOT", 0L, 0);
        otherGroup.addOption("ICE", 0L, 1);

        when(templateRepository.findLockedByIdAndStoreId(templateId, storeId))
                .thenReturn(Optional.of(template));
        when(optionGroupRepository
                .findByIdAndProductIdAndStoreOptionGroupTemplateId(
                        30L, 40L, templateId
                ))
                .thenReturn(Optional.of(sourceGroup));
        when(optionGroupRepository
                .findAllByStoreOptionGroupTemplateIdOrderByProductIdAsc(templateId))
                .thenReturn(List.of(sourceGroup, otherGroup));

        service.applyToAll(
                user,
                storeId,
                templateId,
                new BulkApplyStoreOptionTemplateRequest(
                        40L,
                        30L,
                        "온도",
                        1,
                        1,
                        true,
                        List.of(
                                new OptionRequest("HOT", 0L, 0),
                                new OptionRequest("ICE", 500L, 1)
                        )
                )
        );

        assertEquals(2L, template.getVersion());
        assertEquals(2L, sourceGroup.getAppliedTemplateVersion());
        assertEquals(2L, otherGroup.getAppliedTemplateVersion());
        assertEquals(500L, otherGroup.getOptions().get(1).getAdditionalPrice());
        verify(optionGroupRepository).flush();
    }

    @Test
    void deletingATemplateStillInUseIsRejectedInsideTheServiceTransaction() {
        long storeId = 10L;
        long templateId = 20L;
        StoreOptionGroupTemplate template = StoreOptionGroupTemplate.create(
                store, "온도", 1, 1, true
        );
        when(templateRepository.findLockedByIdAndStoreId(templateId, storeId))
                .thenReturn(Optional.of(template));
        when(optionGroupRepository.countByStoreOptionGroupTemplateId(templateId))
                .thenReturn(1L);

        assertThrows(
                BusinessException.class,
                () -> service.deleteIfUnused(user, storeId, templateId)
        );

        verify(templateRepository, never()).delete(template);
    }
}
