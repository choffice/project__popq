import 'package:popq_app_core/popq_app_core.dart';

import 'customer_order_repository.dart';
import 'pending_payment_store.dart';

enum PendingPaymentRecoveryKind {
  none,
  paid,
  retryAllowed,
  pending,
  manualReview,
  inconsistent,
  unavailable,
}

class PendingPaymentRecoveryOutcome {
  const PendingPaymentRecoveryOutcome({
    required this.kind,
    this.orderPublicId,
    this.message,
  });

  const PendingPaymentRecoveryOutcome.none()
    : kind = PendingPaymentRecoveryKind.none,
      orderPublicId = null,
      message = null;

  final PendingPaymentRecoveryKind kind;
  final String? orderPublicId;
  final String? message;

  bool get isPaid => kind == PendingPaymentRecoveryKind.paid;

  bool get canRetry => kind == PendingPaymentRecoveryKind.retryAllowed;
}

class PendingPaymentRecoveryService {
  PendingPaymentRecoveryService({
    required CustomerOrderRepository repository,
    PendingPaymentStore? store,
  }) : _repository = repository,
       _store = store ?? PendingPaymentStore();

  final CustomerOrderRepository _repository;
  final PendingPaymentStore _store;

  Future<PendingPaymentRecoveryOutcome> recover() async {
    final pending = await _store.load();

    if (pending == null) {
      return const PendingPaymentRecoveryOutcome.none();
    }

    try {
      final recovery = await _repository.recoverPayment(pending.orderPublicId);

      return _interpretRecovery(pending, recovery);
    } on ApiRequestFailure catch (error) {
      /*
       * 토스 인증 성공 직후 앱이 종료되어 Spring Boot 승인 API가
       * 한 번도 호출되지 않았다면 Payment 행 자체가 없을 수 있습니다.
       *
       * 이 경우 SharedPreferences에 저장해 둔 동일한
       * orderPublicId + paymentKey + idempotencyKey를 사용해
       * 원래 승인 요청을 그대로 이어서 실행합니다.
       */
      if (error.code == 'PAYMENT_NOT_FOUND') {
        return _resumeBeforeBackendApproval(pending);
      }

      return PendingPaymentRecoveryOutcome(
        kind: PendingPaymentRecoveryKind.unavailable,
        orderPublicId: pending.orderPublicId,
        message: error.message,
      );
    } on AuthenticationFailure catch (error) {
      return PendingPaymentRecoveryOutcome(
        kind: PendingPaymentRecoveryKind.unavailable,
        orderPublicId: pending.orderPublicId,
        message: error.message,
      );
    } on NetworkFailure catch (error) {
      return PendingPaymentRecoveryOutcome(
        kind: PendingPaymentRecoveryKind.unavailable,
        orderPublicId: pending.orderPublicId,
        message: error.message,
      );
    } on InvalidResponseFailure catch (error) {
      return PendingPaymentRecoveryOutcome(
        kind: PendingPaymentRecoveryKind.unavailable,
        orderPublicId: pending.orderPublicId,
        message: error.message,
      );
    }
  }

  Future<PendingPaymentRecoveryOutcome> _resumeBeforeBackendApproval(
    PendingPayment pending,
  ) async {
    try {
      final order = await _repository.findOne(pending.orderPublicId);

      if (order.totalAmount != pending.amount) {
        return PendingPaymentRecoveryOutcome(
          kind: PendingPaymentRecoveryKind.inconsistent,
          orderPublicId: pending.orderPublicId,
          message:
              '저장된 결제 금액과 서버 주문 금액이 다릅니다. '
              '새 결제를 진행하지 않고 결제 내역을 확인해주세요.',
        );
      }

      /*
       * 이미 주문 상태가 CREATED를 벗어났는데 Payment를 찾지 못했다면
       * 서버 데이터가 서로 맞지 않는 상태이므로 새 승인을 자동 실행하지
       * 않습니다.
       */
      if (order.status != 'CREATED') {
        return PendingPaymentRecoveryOutcome(
          kind: PendingPaymentRecoveryKind.inconsistent,
          orderPublicId: pending.orderPublicId,
          message:
              '주문과 결제 상태가 일치하지 않습니다. '
              '새 결제를 진행하지 말고 주문 내역을 확인해주세요.',
        );
      }

      await _repository.confirmPayment(
        order,
        idempotencyKey: pending.idempotencyKey,
        paymentKey: pending.paymentKey,
      );

      await _clearPending(pending);

      return PendingPaymentRecoveryOutcome(
        kind: PendingPaymentRecoveryKind.paid,
        orderPublicId: pending.orderPublicId,
        message: '결제 승인이 완료되었습니다.',
      );
    } on ApiRequestFailure {
      /*
       * 승인 요청이 실패 응답을 반환했더라도 실제 Provider 처리 결과와
       * HTTP 응답 시점이 엇갈렸을 수 있으므로 한 번 더 서버 복구 상태를
       * 확인합니다.
       */
      return _recoverAfterResumeAttempt(pending);
    } on NetworkFailure catch (error) {
      return PendingPaymentRecoveryOutcome(
        kind: PendingPaymentRecoveryKind.unavailable,
        orderPublicId: pending.orderPublicId,
        message: error.message,
      );
    } on AuthenticationFailure catch (error) {
      return PendingPaymentRecoveryOutcome(
        kind: PendingPaymentRecoveryKind.unavailable,
        orderPublicId: pending.orderPublicId,
        message: error.message,
      );
    } on InvalidResponseFailure catch (error) {
      return PendingPaymentRecoveryOutcome(
        kind: PendingPaymentRecoveryKind.unavailable,
        orderPublicId: pending.orderPublicId,
        message: error.message,
      );
    }
  }

  Future<PendingPaymentRecoveryOutcome> _recoverAfterResumeAttempt(
    PendingPayment pending,
  ) async {
    try {
      final recovery = await _repository.recoverPayment(pending.orderPublicId);

      return _interpretRecovery(pending, recovery);
    } on PopqFailure catch (error) {
      return PendingPaymentRecoveryOutcome(
        kind: PendingPaymentRecoveryKind.unavailable,
        orderPublicId: pending.orderPublicId,
        message: error.message,
      );
    }
  }

  Future<PendingPaymentRecoveryOutcome> _interpretRecovery(
    PendingPayment pending,
    CustomerPaymentRecovery recovery,
  ) async {
    if (recovery.orderPublicId != pending.orderPublicId) {
      return PendingPaymentRecoveryOutcome(
        kind: PendingPaymentRecoveryKind.inconsistent,
        orderPublicId: pending.orderPublicId,
        message:
            '복구된 결제의 주문 번호가 일치하지 않습니다. '
            '새 결제를 진행하지 말고 결제 내역을 확인해주세요.',
      );
    }

    if (recovery.requestedAmount != pending.amount) {
      return PendingPaymentRecoveryOutcome(
        kind: PendingPaymentRecoveryKind.inconsistent,
        orderPublicId: pending.orderPublicId,
        message:
            '복구된 결제 금액이 저장된 주문 금액과 다릅니다. '
            '새 결제를 진행하지 말고 결제 내역을 확인해주세요.',
      );
    }

    final providerPaymentKey = recovery.providerPaymentKey;

    if (providerPaymentKey != null &&
        providerPaymentKey.isNotEmpty &&
        providerPaymentKey != pending.paymentKey) {
      return PendingPaymentRecoveryOutcome(
        kind: PendingPaymentRecoveryKind.inconsistent,
        orderPublicId: pending.orderPublicId,
        message:
            '복구된 결제 키가 이전 결제 정보와 일치하지 않습니다. '
            '새 결제를 진행하지 말고 결제 내역을 확인해주세요.',
      );
    }

    if (recovery.isPaid) {
      final approvedAmount = recovery.approvedAmount;

      if (approvedAmount != null && approvedAmount != pending.amount) {
        return PendingPaymentRecoveryOutcome(
          kind: PendingPaymentRecoveryKind.inconsistent,
          orderPublicId: pending.orderPublicId,
          message:
              '승인된 결제 금액이 주문 금액과 일치하지 않습니다. '
              '결제 내역을 확인해주세요.',
        );
      }

      await _clearPending(pending);

      return PendingPaymentRecoveryOutcome(
        kind: PendingPaymentRecoveryKind.paid,
        orderPublicId: pending.orderPublicId,
        message: '결제가 정상적으로 확인되었습니다.',
      );
    }

    if (recovery.isTerminalFailure) {
      await _clearPending(pending);

      return PendingPaymentRecoveryOutcome(
        kind: PendingPaymentRecoveryKind.retryAllowed,
        orderPublicId: pending.orderPublicId,
        message: recovery.failureMessage ?? '이전 결제는 완료되지 않았습니다. 다시 결제할 수 있습니다.',
      );
    }

    if (recovery.requiresManualReview) {
      return PendingPaymentRecoveryOutcome(
        kind: PendingPaymentRecoveryKind.manualReview,
        orderPublicId: pending.orderPublicId,
        message:
            recovery.failureMessage ??
            '결제가 일부 또는 전부 취소된 상태입니다. '
                '결제 내역을 확인해주세요.',
      );
    }

    return PendingPaymentRecoveryOutcome(
      kind: PendingPaymentRecoveryKind.pending,
      orderPublicId: pending.orderPublicId,
      message:
          recovery.failureMessage ??
          '결제 승인 결과를 아직 확인하고 있습니다. '
              '새 결제를 진행하지 말고 잠시 후 다시 확인해주세요.',
    );
  }

  Future<void> _clearPending(PendingPayment pending) {
    return _store.clearIfMatches(
      orderPublicId: pending.orderPublicId,
      paymentKey: pending.paymentKey,
    );
  }
}
