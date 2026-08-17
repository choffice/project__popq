package com.example.project_popq.auth.repository;

import com.example.project_popq.auth.domain.EmailVerificationChallenge;
import com.example.project_popq.auth.domain.EmailVerificationPurpose;
import jakarta.persistence.LockModeType;
import java.util.Optional;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Lock;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;

public interface EmailVerificationChallengeRepository
        extends JpaRepository<EmailVerificationChallenge, Long> {

    @Lock(LockModeType.PESSIMISTIC_WRITE)
    @Query("select challenge from EmailVerificationChallenge challenge "
            + "where challenge.email = :email and challenge.purpose = :purpose")
    Optional<EmailVerificationChallenge> findForUpdate(
            @Param("email") String email,
            @Param("purpose") EmailVerificationPurpose purpose
    );
}
