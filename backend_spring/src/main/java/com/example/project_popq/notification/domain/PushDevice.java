package com.example.project_popq.notification.domain;

import com.example.project_popq.common.domain.BaseTimeEntity;
import com.example.project_popq.user.domain.User;
import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.EnumType;
import jakarta.persistence.Enumerated;
import jakarta.persistence.FetchType;
import jakarta.persistence.GeneratedValue;
import jakarta.persistence.GenerationType;
import jakarta.persistence.Id;
import jakarta.persistence.JoinColumn;
import jakarta.persistence.ManyToOne;
import jakarta.persistence.Table;
import lombok.AccessLevel;
import lombok.Getter;
import lombok.NoArgsConstructor;

@Getter
@Entity
@Table(name = "push_devices")
@NoArgsConstructor(access = AccessLevel.PROTECTED)
public class PushDevice extends BaseTimeEntity {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    @Column(name = "push_device_id")
    private Long id;

    @ManyToOne(fetch = FetchType.LAZY, optional = false)
    @JoinColumn(name = "user_id", nullable = false)
    private User user;

    @Column(name = "token", nullable = false, length = 512, unique = true)
    private String token;

    @Enumerated(EnumType.STRING)
    @Column(name = "platform", nullable = false, length = 20)
    private DevicePlatform platform;

    private PushDevice(
            User user,
            String token,
            DevicePlatform platform
    ) {
        this.user = user;
        this.token = token;
        this.platform = platform;
    }

    public static PushDevice create(
            User user,
            String token,
            DevicePlatform platform
    ) {
        return new PushDevice(user, token, platform);
    }

    public void registerTo(User user, DevicePlatform platform) {
        this.user = user;
        this.platform = platform;
    }

    public boolean belongsTo(Long userId) {
        return user.getId().equals(userId);
    }
}
