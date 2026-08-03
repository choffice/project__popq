package com.example.project_popq.user.domain;

import com.example.project_popq.common.domain.BaseTimeEntity;
import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.EnumType;
import jakarta.persistence.Enumerated;
import jakarta.persistence.GeneratedValue;
import jakarta.persistence.GenerationType;
import jakarta.persistence.Id;
import jakarta.persistence.Table;
import lombok.AccessLevel;
import lombok.Getter;
import lombok.NoArgsConstructor;

@Getter
@Entity
@Table(name = "users")
@NoArgsConstructor(access = AccessLevel.PROTECTED)
public class User extends BaseTimeEntity {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    @Column(name = "user_id")
    private Long id;

    @Column(name = "email", length = 255, unique = true)
    private String email;

    @Column(name = "name", nullable = false, length = 100)
    private String name;

    @Column(name = "phone", length = 30)
    private String phone;

    @Enumerated(EnumType.STRING)
    @Column(name = "role", nullable = false, length = 30)
    private PlatformRole role;

    @Enumerated(EnumType.STRING)
    @Column(name = "status", nullable = false, length = 30)
    private UserStatus status;

    @Column(name = "password_hash", length = 255)
    private String passwordHash;

    private User(String email, String name, String phone, PlatformRole role, String passwordHash) {
        this.email = email;
        this.name = name;
        this.phone = phone;
        this.role = role;
        this.status = UserStatus.ACTIVE;
        this.passwordHash = passwordHash;
    }

    public static User create(String email, String name, PlatformRole role) {
        return new User(email, name, null, role, null);
    }

    public static User createWithPassword(
            String email,
            String name,
            String phone,
            PlatformRole role,
            String passwordHash
    ) {
        return new User(email, name, phone, role, passwordHash);
    }

    public boolean isActive() {
        return status == UserStatus.ACTIVE;
    }

    public void changeStatus(UserStatus status) {
        this.status = status;
    }

    public void changePasswordHash(String passwordHash) {
        this.passwordHash = passwordHash;
    }
}
