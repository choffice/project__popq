package com.example.project_popq.user.repository;

import com.example.project_popq.user.domain.User;
import java.util.Optional;
import org.springframework.data.jpa.repository.JpaRepository;

public interface UserRepository extends JpaRepository<User, Long> {

    Optional<User> findByEmailIgnoreCase(String email);

    boolean existsByEmailIgnoreCase(String email);

    boolean existsByPhone(String phone);

    boolean existsByPhoneAndIdNot(String phone, Long id);

    Optional<User> findByNameAndPhone(String name, String phone);

    Optional<User> findByEmailIgnoreCaseAndPhone(String email, String phone);
}

