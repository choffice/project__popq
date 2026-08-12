package com.example.project_popq.admin.domain;

import com.example.project_popq.common.domain.BaseTimeEntity;
import com.example.project_popq.user.domain.User;
import jakarta.persistence.Column;
import jakarta.persistence.Entity;
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
@Table(name = "admin_audit_logs")
@NoArgsConstructor(access = AccessLevel.PROTECTED)
public class AdminAuditLog extends BaseTimeEntity {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    @Column(name = "admin_audit_log_id")
    private Long id;

    @ManyToOne(fetch = FetchType.LAZY, optional = false)
    @JoinColumn(name = "admin_user_id", nullable = false)
    private User adminUser;

    @Column(name = "target_type", nullable = false, length = 50)
    private String targetType;

    @Column(name = "target_id", nullable = false)
    private Long targetId;

    @Column(name = "action", nullable = false, length = 50)
    private String action;

    @Column(name = "before_value", length = 100)
    private String beforeValue;

    @Column(name = "after_value", length = 100)
    private String afterValue;

    @Column(name = "reason", length = 500)
    private String reason;

    private AdminAuditLog(
            User adminUser,
            String targetType,
            Long targetId,
            String action,
            String beforeValue,
            String afterValue,
            String reason
    ) {
        this.adminUser = adminUser;
        this.targetType = targetType;
        this.targetId = targetId;
        this.action = action;
        this.beforeValue = beforeValue;
        this.afterValue = afterValue;
        this.reason = reason;
    }

    public static AdminAuditLog create(
            User adminUser,
            String targetType,
            Long targetId,
            String action,
            Object beforeValue,
            Object afterValue,
            String reason
    ) {
        return new AdminAuditLog(
                adminUser,
                targetType,
                targetId,
                action,
                beforeValue == null ? null : beforeValue.toString(),
                afterValue == null ? null : afterValue.toString(),
                reason == null || reason.isBlank() ? "관리자 상태 변경" : reason.trim()
        );
    }
}
