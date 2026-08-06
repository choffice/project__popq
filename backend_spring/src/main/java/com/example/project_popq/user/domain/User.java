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
import jakarta.persistence.CollectionTable;
import jakarta.persistence.ElementCollection;
import jakarta.persistence.FetchType;
import jakarta.persistence.JoinColumn;
import java.time.Duration;
import java.time.Instant;
import java.util.HashSet;
import java.util.Set;


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

    @ElementCollection(fetch = FetchType.EAGER)
    @CollectionTable(
        name = "user_roles",
        joinColumns = @JoinColumn(name = "user_id")
    )
    @Enumerated(EnumType.STRING)
    @Column(name = "role", nullable = false, length = 30)
    private Set<PlatformRole> roles = new HashSet<>();

    @Enumerated(EnumType.STRING)
    @Column(name = "status", nullable = false, length = 30)
    private UserStatus status;

    @Column(name = "password_hash", length = 255)
    private String passwordHash;

    @Column(name = "withdrawal_requested_at")
    private Instant withdrawalRequestedAt;

    @Column(name = "withdrawal_effective_at")
    private Instant withdrawalEffectiveAt;

    @Column(name = "token_valid_after")
    private Instant tokenValidAfter;

    @Column(name = "profile_image_url", length = 500)
    private String profileImageUrl;

    @Column(name = "push_notification_enabled", nullable = false)
    private boolean pushNotificationEnabled = true;

    @Column(name = "marketing_opt_in", nullable = false)
    private boolean marketingOptIn = false;

    private static final Duration WITHDRAWAL_GRACE_PERIOD = Duration.ofDays(7);
    private static final String WITHDRAWN_NAME_PLACEHOLDER = "탈퇴한 회원";

    private User(String email, String name, String phone, PlatformRole role, String passwordHash) {
        this.email = email;
        this.name = name;
        this.phone = phone;
        this.role = role;
        this.roles.add(role);
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

    public void changeProfileImageUrl(String profileImageUrl) {
        this.profileImageUrl = profileImageUrl;
    }

    public void changePhone(String phone) {
        this.phone = phone;
    }

    public void changeNotificationPreferences(
            boolean pushNotificationEnabled,
            boolean marketingOptIn
    ) {
        this.pushNotificationEnabled = pushNotificationEnabled;
        this.marketingOptIn = marketingOptIn;
    }
    public boolean hasRole(PlatformRole role) {
        return roles.contains(role);
    }

    public void addRole(PlatformRole role) {
        roles.add(role);
    }

    public boolean isTokenValid(Instant issuedAt) {
        return tokenValidAfter == null || !issuedAt.isBefore(tokenValidAfter);
    }

    public boolean matchesWithdrawalConfirmationPhrase(String phrase) {
        return phrase != null
                && phrase.trim().equals(name + " / 탈퇴하겠습니다");
    }

    /**
     * 탈퇴를 접수합니다. 이 시점부터 기존에 발급된 토큰은 즉시 무효화되고,
     * {@link #WITHDRAWAL_GRACE_PERIOD} 안에 다시 로그인하지 않으면 확정 탈퇴됩니다.
     */
    public void requestWithdrawal(Instant now) {
        this.status = UserStatus.WITHDRAWAL_PENDING;
        this.withdrawalRequestedAt = now;
        this.withdrawalEffectiveAt = now.plus(WITHDRAWAL_GRACE_PERIOD);
        this.tokenValidAfter = now;
    }

    public void finalizeWithdrawal() {
        this.status = UserStatus.WITHDRAWN;
        this.name = WITHDRAWN_NAME_PLACEHOLDER;
        this.phone = null;
        this.email = null;
        this.passwordHash = null;
        this.roles.clear();
    }

    /**
     * 탈퇴 대기 상태에서 로그인이 성공했을 때 호출합니다. 유예기간이 지났으면
     * 그 시점에 확정 탈퇴 처리하고, 아직 유예기간 안이면 탈퇴 요청을 취소합니다.
     */
    public void reconcileWithdrawalState(Instant now) {
        if (status != UserStatus.WITHDRAWAL_PENDING) {
            return;
        }
        if (!now.isBefore(withdrawalEffectiveAt)) {
            finalizeWithdrawal();
            return;
        }
        this.status = UserStatus.ACTIVE;
        this.withdrawalRequestedAt = null;
        this.withdrawalEffectiveAt = null;
    }
}
