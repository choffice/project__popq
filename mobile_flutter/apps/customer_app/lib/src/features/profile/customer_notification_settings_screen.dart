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
  NotificationPreference? _currentPreference;
  bool _loading = true;
  bool _savingPush = false;
  bool _savingMarketing = false;

  @override
  void initState() {
    super.initState();
    _loadPreference();
  }

  Future<void> _loadPreference() async {
    try {
      final preference = await widget.repository.getNotificationPreferences();

      if (!mounted) return;

      setState(() {
        _currentPreference = preference;
        _loading = false;
      });
    } on PopqFailure catch (failure) {
      if (!mounted) return;

      setState(() {
        _loading = false;
      });

      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(failure.message)));
    } catch (error) {
      if (!mounted) return;

      setState(() {
        _loading = false;
      });

      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text('알림 설정을 불러오지 못했어요. ($error)')));
    }
  }

  Future<void> _updatePreference({
    required bool pushNotificationEnabled,
    required bool marketingOptIn,
    required bool updatingPush,
  }) async {
    final saving = updatingPush ? _savingPush : _savingMarketing;
    if (saving) return;

    final previousPreference = _currentPreference;

    setState(() {
      if (updatingPush) {
        _savingPush = true;
      } else {
        _savingMarketing = true;
      }

      _currentPreference = NotificationPreference(
          pushNotificationEnabled: pushNotificationEnabled,
          marketingOptIn: marketingOptIn);
    });
    try {
      final updated = await widget.repository.updateNotificationPreferences(
        pushNotificationEnabled: pushNotificationEnabled,
        marketingOptIn: marketingOptIn,
      );
      if (!mounted) return;

      setState(() {
        _currentPreference = updated;
      });
    } on PopqFailure catch (failure) {
      if (!mounted) return;

      setState(() {
        _currentPreference = previousPreference;
      });
      ScaffoldMessenger.of(context)
        ..hideCurrentTopSnackBar()
        ..showTopSnackBar(SnackBar(content: Text(failure.message)));
    } catch (error) {
      if (!mounted) return;

      setState(() {
        _currentPreference = previousPreference;
      });
      ScaffoldMessenger.of(context)
        ..hideCurrentTopSnackBar()
        ..showTopSnackBar(
          SnackBar(content: Text('알림 설정을 변경하지 못했어요. ($error)')),
        );
    } finally {
      if (mounted) {
        setState(() {
          if (updatingPush) {
            _savingPush = false;
          } else {
            _savingMarketing = false;
          }
        });
      }
    }
  }

  Widget _buildContent() {
    if (_loading) {
      return const PopqLoadingView(message: '알림 설정을 불러오고 있어요.');
    }

    final preference = _currentPreference;

    if (preference == null) {
      return PopqErrorView(
        message: '알림 설정을 불러오지 못했어요.',
        onRetry: () {
          setState(() {
            _loading = true;
          });
          _loadPreference();
        },
      );
    }

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
                thumbIcon: const WidgetStatePropertyAll<Icon?>(
                  Icon(null),
                ),
                inactiveThumbColor: const Color(0xFF616161),
                inactiveTrackColor: const Color(0xFFD1D5DB),
                onChanged: (value) {
                  _updatePreference(
                    pushNotificationEnabled: value,
                    marketingOptIn: preference.marketingOptIn,
                    updatingPush: true,
                  );
                },
              ),
              const Divider(height: 1),
              SwitchListTile(
                title: const Text('마케팅 정보 수신'),
                subtitle: const Text('이벤트, 혜택 등 마케팅 알림을 받아요'),
                value: preference.marketingOptIn,
                thumbIcon: const WidgetStatePropertyAll<Icon?>(
                  Icon(null),
                ),
                inactiveThumbColor: const Color(0xFF616161),
                inactiveTrackColor: const Color(0xFFD1D5DB),
                onChanged: (value) {
                  _updatePreference(
                    pushNotificationEnabled:
                    preference.pushNotificationEnabled,
                    marketingOptIn: value,
                    updatingPush: false,
                  );
                },
              ),
            ],
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('알림 설정')),
      body: _buildContent(),
    );
  }
}
