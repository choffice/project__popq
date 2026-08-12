package com.example.project_popq.user.repository;

import com.example.project_popq.user.domain.User;
import java.util.Optional;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.JpaSpecificationExecutor;

public interface UserRepository extends JpaRepository<User, Long>, JpaSpecificationExecutor<User> {

    Optional<User> findByEmailIgnoreCase(String email);

    boolean existsByEmailIgnoreCase(String email);

    boolean existsByPhone(String phone);

    boolean existsByIdAndPushNotificationEnabledTrue(Long id);

    boolean existsByPhoneAndIdNot(String phone, Long id);

    Optional<User> findByNameAndPhone(String name, String phone);

    Optional<User> findByEmailIgnoreCaseAndPhone(String email, String phone);

    long countByStatus(com.example.project_popq.user.domain.UserStatus status);
}

