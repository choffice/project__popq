package com.example.project_popq.store.repository;

import com.example.project_popq.store.domain.StoreTag;
import java.util.Collection;
import java.util.List;
import org.springframework.data.jpa.repository.EntityGraph;
import org.springframework.data.jpa.repository.JpaRepository;

public interface StoreTagRepository extends JpaRepository<StoreTag, Long> {

    @EntityGraph(attributePaths = "tag")
    List<StoreTag> findAllByStoreIdIn(Collection<Long> storeIds);

    @EntityGraph(attributePaths = "tag")
    List<StoreTag> findAllByStoreId(Long storeId);
}
