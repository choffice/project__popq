import 'package:flutter/material.dart';
import 'package:popq_app_core/popq_app_core.dart';
import 'package:popq_design_system/popq_design_system.dart';

import 'customer_engagement_repository.dart';

class CustomerNotificationSettingsScreen extends StatefulWidget {
  const CustomerNotificationSettingsScreen({
    required this.repository,
    super.key,
  });

  final CustomerEngagementRepository repository;

  @override
  State<CustomerNotificationSettingsScreen> createState() =>
      _CustomerNotificationSettingsScreenState();
}

class _CustomerNotificationSettingsScreenState
    extends State<CustomerNotificationSettingsScreen> {
  late Future<NotificationPreference> _preference;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _preference = widget.repository.getNotificationPreferences();
  }

  Future<void> _updatePreference({
    required bool pushNotificationEnabled,
    required bool marketingOptIn,
  }) async {
    if (_saving) return;

    setState(() => _saving = true);
    try {
      final updated = await widget.repository.updateNotificationPreferences(
        pushNotificationEnabled: pushNotificationEnabled,
        marketingOptIn: marketingOptIn,
      );
      if (!mounted) return;
      setState(() => _preference = Future.value(updated));
    } on PopqFailure catch (failure) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(failure.message)));
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(content: Text('알림 설정을 변경하지 못했어요. ($error)')),
        );
    } finally {
      if (mounted) {
        setState(() => _saving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('알림 설정')),
      body: FutureBuilder<NotificationPreference>(
        future: _preference,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const PopqLoadingView(message: '알림 설정을 불러오고 있어요.');
          }

          if (snapshot.hasError || !snapshot.hasData) {
            return PopqErrorView(
              message: '알림 설정을 불러오지 못했어요.',
              onRetry: () {
                setState(() {
                  _preference = widget.repository.getNotificationPreferences();
                });
              },
            );
          }

          final preference = snapshot.requireData;

          return ListView(
            padding: const EdgeInsets.all(PopqSpacing.lg),
            children: [
              Card(
                clipBehavior: Clip.antiAlias,
                child: Column(
                  children: [
                    SwitchListTile(
                      title: const Text('푸시 알림'),
                      subtitle: const Text('주문, 예약 등 중요한 알림을 받아요'),
                      value: preference.pushNotificationEnabled,
                      onChanged: _saving
                          ? null
                          : (value) {
                              _updatePreference(
                                pushNotificationEnabled: value,
                                marketingOptIn: preference.marketingOptIn,
                              );
                            },
                    ),
                    const Divider(height: 1),
                    SwitchListTile(
                      title: const Text('마케팅 정보 수신'),
                      subtitle: const Text('이벤트, 혜택 등 마케팅 알림을 받아요'),
                      value: preference.marketingOptIn,
                      onChanged: _saving
                          ? null
                          : (value) {
                              _updatePreference(
                                pushNotificationEnabled:
                                    preference.pushNotificationEnabled,
                                marketingOptIn: value,
                              );
                            },
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
