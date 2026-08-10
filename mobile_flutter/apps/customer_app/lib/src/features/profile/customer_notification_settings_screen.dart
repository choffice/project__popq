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
      setState(() {
        _preference = Future.value(updated);
      });
    } on PopqFailure catch (failure) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
        ..hideCurrentTopSnackBar()
        ..showTopSnackBar(SnackBar(content: Text(failure.message)));
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
        ..hideCurrentTopSnackBar()
        ..showTopSnackBar(
          SnackBar(content: Text('?뚮┝ ?ㅼ젙??蹂寃쏀븯吏 紐삵뻽?댁슂. ($error)')),
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
      appBar: AppBar(title: const Text('?뚮┝ ?ㅼ젙')),
      body: FutureBuilder<NotificationPreference>(
        future: _preference,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const PopqLoadingView(message: '?뚮┝ ?ㅼ젙??遺덈윭?ㅺ퀬 ?덉뼱??');
          }

          if (snapshot.hasError || !snapshot.hasData) {
            return PopqErrorView(
              message: '?뚮┝ ?ㅼ젙??遺덈윭?ㅼ? 紐삵뻽?댁슂.',
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
                      title: const Text('?몄떆 ?뚮┝'),
                      subtitle: const Text('二쇰Ц, ?덉빟 ??以묒슂???뚮┝??諛쏆븘??),
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
                      title: const Text('留덉????뺣낫 ?섏떊'),
                      subtitle: const Text('?대깽?? ?쒗깮 ??留덉????뚮┝??諛쏆븘??),
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

