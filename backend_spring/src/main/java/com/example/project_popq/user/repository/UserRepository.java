package com.example.project_popq.user.repository;

import com.example.project_popq.user.domain.User;
import java.util.Optional;
import jakarta.persistence.LockModeType;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Lock;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;

public interface UserRepository extends JpaRepository<User, Long> {

    @Lock(LockModeType.PESSIMISTIC_WRITE)
    @Query("select user from User user where user.id = :userId")
    Optional<User> findForUpdateById(@Param("userId") Long userId);

    Optional<User> findByEmailIgnoreCase(String email);

    boolean existsByEmailIgnoreCase(String email);

    boolean existsByPhone(String phone);

    boolean existsByIdAndPushNotificationEnabledTrue(Long id);

    boolean existsByPhoneAndIdNot(String phone, Long id);

    Optional<User> findByNameAndPhone(String name, String phone);

    Optional<User> findByEmailIgnoreCaseAndPhone(String email, String phone);
}

