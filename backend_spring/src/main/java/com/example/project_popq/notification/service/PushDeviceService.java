package com.example.project_popq.notification.service;

import com.example.project_popq.common.error.BusinessException;
import com.example.project_popq.common.error.ErrorCode;
import com.example.project_popq.notification.domain.PushDevice;
import com.example.project_popq.notification.dto.PushDeviceResponse;
import com.example.project_popq.notification.dto.RegisterPushDeviceRequest;
import com.example.project_popq.notification.repository.PushDeviceRepository;
import com.example.project_popq.user.domain.PlatformRole;
import com.example.project_popq.user.domain.User;
import java.util.List;
import lombok.RequiredArgsConstructor;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

@Service
@RequiredArgsConstructor
public class PushDeviceService {

    private final PushDeviceRepository pushDeviceRepository;

    @Transactional
    public PushDeviceResponse register(
            User user,
            RegisterPushDeviceRequest request
    ) {
        requireCustomer(user);
        String token = request.token().trim();
        PushDevice device = pushDeviceRepository.findByToken(token)
                .orElseGet(() -> PushDevice.create(
                        user,
                        token,
                        request.platform()
                ));
        device.registerTo(user, request.platform());
        pushDeviceRepository.save(device);
        pushDeviceRepository.flush();
        return PushDeviceResponse.from(device);
    }

    @Transactional(readOnly = true)
    public List<PushDeviceResponse> findMine(User user) {
        requireCustomer(user);
        return pushDeviceRepository
                .findAllByUserIdOrderByCreatedAtDesc(user.getId())
                .stream()
                .map(PushDeviceResponse::from)
                .toList();
    }

    @Transactional
    public PushDeviceResponse unregister(User user, Long deviceId) {
        requireCustomer(user);
        PushDevice device = pushDeviceRepository
                .findByIdAndUserId(deviceId, user.getId())
                .orElseThrow(() -> new BusinessException(
                        ErrorCode.PUSH_DEVICE_NOT_FOUND
                ));
        PushDeviceResponse response = PushDeviceResponse.from(device);
        pushDeviceRepository.delete(device);
        return response;
    }

    private void requireCustomer(User user) {
        if (user.getRole() != PlatformRole.CUSTOMER) {
            throw new BusinessException(ErrorCode.ACCESS_DENIED);
        }
    }
}
