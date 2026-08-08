import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

class PendingPayment {
  const PendingPayment({
    required this.orderPublicId,
    required this.paymentKey,
    required this.idempotencyKey,
    required this.amount,
    required this.savedAt,
  });

  factory PendingPayment.fromJson(Map<String, Object?> json) {
    final orderPublicId = json['orderPublicId'];
    final paymentKey = json['paymentKey'];
    final idempotencyKey = json['idempotencyKey'];
    final amount = json['amount'];
    final savedAt = json['savedAt'];

    if (orderPublicId is! String ||
        orderPublicId.isEmpty ||
        paymentKey is! String ||
        paymentKey.isEmpty ||
        idempotencyKey is! String ||
        idempotencyKey.isEmpty ||
        amount is! num ||
        savedAt is! String) {
      throw const FormatException('저장된 결제 복구 정보가 올바르지 않습니다.');
    }

    final parsedSavedAt = DateTime.tryParse(savedAt);

    if (parsedSavedAt == null) {
      throw const FormatException('저장된 결제 복구 시간이 올바르지 않습니다.');
    }

    return PendingPayment(
      orderPublicId: orderPublicId,
      paymentKey: paymentKey,
      idempotencyKey: idempotencyKey,
      amount: amount.toInt(),
      savedAt: parsedSavedAt,
    );
  }

  final String orderPublicId;
  final String paymentKey;
  final String idempotencyKey;
  final int amount;
  final DateTime savedAt;

  Map<String, Object?> toJson() {
    return {
      'orderPublicId': orderPublicId,
      'paymentKey': paymentKey,
      'idempotencyKey': idempotencyKey,
      'amount': amount,
      'savedAt': savedAt.toUtc().toIso8601String(),
    };
  }

  bool matches({required String orderPublicId, required String paymentKey}) {
    return this.orderPublicId == orderPublicId && this.paymentKey == paymentKey;
  }
}

class PendingPaymentStore {
  static const String _storageKey = 'popq.pending_payment.v1';

  Future<PendingPayment?> load() async {
    final preferences = await SharedPreferences.getInstance();
    final raw = preferences.getString(_storageKey);

    if (raw == null || raw.trim().isEmpty) {
      return null;
    }

    try {
      final decoded = jsonDecode(raw);

      if (decoded is! Map) {
        throw const FormatException();
      }

      return PendingPayment.fromJson(Map<String, Object?>.from(decoded));
    } on FormatException {
      await preferences.remove(_storageKey);
      return null;
    } on TypeError {
      await preferences.remove(_storageKey);
      return null;
    }
  }

  Future<void> save(PendingPayment payment) async {
    final preferences = await SharedPreferences.getInstance();

    await preferences.setString(_storageKey, jsonEncode(payment.toJson()));
  }

  Future<void> clear() async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.remove(_storageKey);
  }

  Future<void> clearIfMatches({
    required String orderPublicId,
    required String paymentKey,
  }) async {
    final current = await load();

    if (current == null ||
        !current.matches(
          orderPublicId: orderPublicId,
          paymentKey: paymentKey,
        )) {
      return;
    }

    await clear();
  }
}
