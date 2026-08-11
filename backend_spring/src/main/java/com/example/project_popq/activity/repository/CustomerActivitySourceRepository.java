package com.example.project_popq.activity.repository;

import com.example.project_popq.activity.domain.CustomerActivitySource;
import com.example.project_popq.activity.domain.CustomerActivitySourceType;
import java.util.Optional;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;

public interface CustomerActivitySourceRepository
        extends JpaRepository<CustomerActivitySource, Long> {

    Optional<CustomerActivitySource> findBySourceTypeAndSourceKey(
            CustomerActivitySourceType sourceType,
            String sourceKey
    );

    @Query(
            value = """
                    select count(*)
                    from (
                        select activity_type, store_id, activity_date
                        from customer_activity_sources
                        where user_id = :userId
                          and active = true
                        group by activity_type, store_id, activity_date
                    ) counted_activities
                    """,
            nativeQuery = true
    )
    long countQualifiedActivities(@Param("userId") Long userId);
}
