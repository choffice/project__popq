package com.example.project_popq.activity.repository;

import com.example.project_popq.activity.domain.CustomerActivitySource;
import com.example.project_popq.activity.domain.CustomerActivitySourceType;
import com.example.project_popq.activity.domain.CustomerActivityType;
import java.time.Instant;
import java.time.LocalDate;
import java.util.List;
import java.util.Optional;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Modifying;
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

    @Modifying(clearAutomatically = true, flushAutomatically = true)
    @Query(
            value = """
                    insert ignore into customer_activity_sources (
                        user_id,
                        store_id,
                        activity_type,
                        source_type,
                        source_key,
                        activity_date,
                        active,
                        occurred_at,
                        revoked_at,
                        created_at,
                        updated_at
                    ) values (
                        :userId,
                        null,
                        'DAILY_ATTENDANCE',
                        'DAILY_ATTENDANCE',
                        :sourceKey,
                        :activityDate,
                        true,
                        :occurredAt,
                        null,
                        :occurredAt,
                        :occurredAt
                    )
                    """,
            nativeQuery = true
    )
    int insertDailyAttendance(
            @Param("userId") Long userId,
            @Param("sourceKey") String sourceKey,
            @Param("activityDate") LocalDate activityDate,
            @Param("occurredAt") Instant occurredAt
    );

    @Query("""
            select activity.activityDate
            from CustomerActivitySource activity
            where activity.user.id = :userId
              and activity.activityType = :activityType
              and activity.active = true
              and activity.activityDate between :startDate and :endDate
            order by activity.activityDate
            """)
    List<LocalDate> findActiveDates(
            @Param("userId") Long userId,
            @Param("activityType") CustomerActivityType activityType,
            @Param("startDate") LocalDate startDate,
            @Param("endDate") LocalDate endDate
    );
}
