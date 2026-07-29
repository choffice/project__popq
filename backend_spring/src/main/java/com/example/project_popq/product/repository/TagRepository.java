package com.example.project_popq.product.repository;

import com.example.project_popq.product.domain.Tag;
import com.example.project_popq.product.domain.TagType;
import java.util.Optional;
import org.springframework.data.jpa.repository.JpaRepository;

public interface TagRepository extends JpaRepository<Tag, Long> {

    Optional<Tag> findByNameIgnoreCaseAndTagType(String name, TagType tagType);
}

