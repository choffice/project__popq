package com.example.project_popq.admin.repository;

import com.example.project_popq.admin.domain.AdminAuditLog;
import org.springframework.data.jpa.repository.JpaRepository;

public interface AdminAuditLogRepository extends JpaRepository<AdminAuditLog, Long> {
}
