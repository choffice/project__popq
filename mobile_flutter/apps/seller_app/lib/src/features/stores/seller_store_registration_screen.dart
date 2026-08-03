import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:popq_design_system/popq_design_system.dart';

import 'seller_store_repository.dart';
import 'seller_store_selection_controller.dart';

class SellerStoreRegistrationScreen extends StatefulWidget {
  const SellerStoreRegistrationScreen({
    required this.repository,
    required this.selectionController,
    super.key,
  });

  final SellerStoreRepository repository;
  final SellerStoreSelectionController selectionController;

  @override
  State<SellerStoreRegistrationScreen> createState() =>
      _SellerStoreRegistrationScreenState();
}

class _SellerStoreRegistrationScreenState
    extends State<SellerStoreRegistrationScreen> {
  static const List<String> _categories = [
    '카페',
    '디저트',
    '베이커리',
    '한식',
    '중식',
    '일식',
    '양식',
    '분식',
    '치킨',
    '피자',
    '패스트푸드',
    '주점',
    '푸드트럭',
    '팝업·행사',
    '기타',
  ];

  static const Map<String, String> _days = {
    'MONDAY': '월',
    'TUESDAY': '화',
    'WEDNESDAY': '수',
    'THURSDAY': '목',
    'FRIDAY': '금',
    'SATURDAY': '토',
    'SUNDAY': '일',
  };

  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();

  final TextEditingController _nameController =
  TextEditingController();

  final TextEditingController _addressController =
  TextEditingController();

  final TextEditingController _detailAddressController =
  TextEditingController();

  final TextEditingController _phoneController =
  TextEditingController();

  final TextEditingController _descriptionController =
  TextEditingController();

  final TextEditingController _imageUrlController =
  TextEditingController();

  final TextEditingController _tagController =
  TextEditingController();

  String _storeType = 'LOCAL_STORE';
  String? _representativeCategory;

  TimeOfDay? _openTime;
  TimeOfDay? _closeTime;

  final Set<String> _closedDays = <String>{};
  final List<String> _tags = <String>[];

  bool _takeoutAvailable = true;
  bool _dineInAvailable = true;
  bool _orderAcceptingEnabled = true;

  bool _submitting = false;
  bool _registrationCompleted = false;

  @override
  void dispose() {
    _nameController.dispose();
    _addressController.dispose();
    _detailAddressController.dispose();
    _phoneController.dispose();
    _descriptionController.dispose();
    _imageUrlController.dispose();
    _tagController.dispose();

    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return PopScope<Object?>(
      canPop: !_submitting || _registrationCompleted,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('새 사업장 등록'),
        ),
        body: Form(
          key: _formKey,
          autovalidateMode:
          AutovalidateMode.onUserInteraction,
          child: ListView(
            padding: const EdgeInsets.all(
              PopqSpacing.lg,
            ),
            children: [
              Text(
                '사업장 기본 정보',
                style: Theme.of(context)
                    .textTheme
                    .headlineSmall,
              ),
              const SizedBox(
                height: PopqSpacing.sm,
              ),
              Text(
                '고객에게 공개될 사업장 정보를 입력해 주세요.',
                style: Theme.of(context)
                    .textTheme
                    .bodySmall,
              ),
              const SizedBox(
                height: PopqSpacing.lg,
              ),
              _buildBasicInformationCard(context),
              const SizedBox(
                height: PopqSpacing.md,
              ),
              _buildOperatingHoursCard(context),
              const SizedBox(
                height: PopqSpacing.md,
              ),
              _buildOrderPolicyCard(context),
              const SizedBox(
                height: PopqSpacing.md,
              ),
              _buildTagCard(context),
              const SizedBox(
                height: PopqSpacing.xl,
              ),
              FilledButton.icon(
                key: const Key(
                  'submit-store-registration',
                ),
                onPressed:
                _submitting ? null : _submit,
                icon: _submitting
                    ? const SizedBox.square(
                  dimension: 20,
                  child:
                  CircularProgressIndicator(
                    strokeWidth: 2,
                  ),
                )
                    : const Icon(
                  Icons.add_business_rounded,
                ),
                label: Text(
                  _submitting
                      ? '등록 요청 중...'
                      : '사업장 등록',
                ),
              ),
              const SizedBox(
                height: PopqSpacing.lg,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBasicInformationCard(
      BuildContext context,
      ) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(
          PopqSpacing.md,
        ),
        child: Column(
          crossAxisAlignment:
          CrossAxisAlignment.start,
          children: [
            Text(
              '기본 정보',
              style: Theme.of(context)
                  .textTheme
                  .titleLarge,
            ),
            const SizedBox(
              height: PopqSpacing.md,
            ),
            DropdownButtonFormField<String>(
              initialValue: _storeType,
              decoration: const InputDecoration(
                labelText: '사업장 유형',
                prefixIcon: Icon(
                  Icons.category_outlined,
                ),
              ),
              items: const [
                DropdownMenuItem<String>(
                  value: 'LOCAL_STORE',
                  child: Text('일반 매장'),
                ),
                DropdownMenuItem<String>(
                  value: 'EVENT_COMMERCE',
                  child: Text('행사·팝업 판매점'),
                ),
              ],
              onChanged: _submitting
                  ? null
                  : (String? value) {
                if (value == null) {
                  return;
                }

                setState(() {
                  _storeType = value;
                });
              },
            ),
            const SizedBox(
              height: PopqSpacing.md,
            ),
            TextFormField(
              key: const Key('store-name'),
              controller: _nameController,
              enabled: !_submitting,
              maxLength: 150,
              textInputAction:
              TextInputAction.next,
              decoration: const InputDecoration(
                labelText: '사업장명',
                hintText: '예: 서면 포포분식',
                prefixIcon: Icon(
                  Icons.storefront_outlined,
                ),
              ),
              validator: (String? value) {
                if (value == null ||
                    value.trim().isEmpty) {
                  return '사업장명을 입력해 주세요.';
                }

                return null;
              },
            ),
            const SizedBox(
              height: PopqSpacing.sm,
            ),
            DropdownButtonFormField<String>(
              initialValue:
              _representativeCategory,
              decoration: const InputDecoration(
                labelText: '대표 카테고리',
                prefixIcon: Icon(
                  Icons.restaurant_menu_rounded,
                ),
              ),
              items: _categories
                  .map(
                    (String category) =>
                    DropdownMenuItem<String>(
                      value: category,
                      child: Text(category),
                    ),
              )
                  .toList(),
              validator: (String? value) {
                if (value == null ||
                    value.isEmpty) {
                  return '대표 카테고리를 선택해 주세요.';
                }

                return null;
              },
              onChanged: _submitting
                  ? null
                  : (String? value) {
                setState(() {
                  _representativeCategory =
                      value;
                });
              },
            ),
            const SizedBox(
              height: PopqSpacing.md,
            ),
            TextFormField(
              controller: _addressController,
              enabled: !_submitting,
              maxLength: 255,
              textInputAction:
              TextInputAction.next,
              decoration: const InputDecoration(
                labelText: '주소',
                hintText:
                '예: 부산광역시 부산진구 중앙대로 123',
                prefixIcon: Icon(
                  Icons.location_on_outlined,
                ),
              ),
              validator: (String? value) {
                if (value == null ||
                    value.trim().isEmpty) {
                  return '주소를 입력해 주세요.';
                }

                return null;
              },
            ),
            const SizedBox(
              height: PopqSpacing.sm,
            ),
            TextFormField(
              controller:
              _detailAddressController,
              enabled: !_submitting,
              maxLength: 255,
              textInputAction:
              TextInputAction.next,
              decoration: const InputDecoration(
                labelText: '상세 주소',
                hintText:
                '예: 포포빌딩 1층 101호',
                prefixIcon: Icon(
                  Icons.maps_home_work_outlined,
                ),
              ),
              validator: (String? value) {
                if (value == null ||
                    value.trim().isEmpty) {
                  return '상세 주소를 입력해 주세요.';
                }

                return null;
              },
            ),
            const SizedBox(
              height: PopqSpacing.sm,
            ),
            TextFormField(
              controller: _phoneController,
              enabled: !_submitting,
              maxLength: 30,
              keyboardType:
              TextInputType.phone,
              textInputAction:
              TextInputAction.next,
              decoration: const InputDecoration(
                labelText: '사업장 연락처',
                hintText: '예: 051-123-4567',
                prefixIcon: Icon(
                  Icons.phone_outlined,
                ),
              ),
              validator: (String? value) {
                final String phone =
                    value?.trim() ?? '';

                if (phone.isEmpty) {
                  return '사업장 연락처를 입력해 주세요.';
                }

                final RegExp validCharacters =
                RegExp(
                  r'^[0-9+\-()\s]+$',
                );

                if (!validCharacters
                    .hasMatch(phone)) {
                  return '연락처 형식을 확인해 주세요.';
                }

                return null;
              },
            ),
            const SizedBox(
              height: PopqSpacing.sm,
            ),
            TextFormField(
              controller:
              _descriptionController,
              enabled: !_submitting,
              maxLength: 1000,
              minLines: 3,
              maxLines: 5,
              textInputAction:
              TextInputAction.newline,
              decoration: const InputDecoration(
                labelText: '사업장 설명',
                hintText:
                '사업장의 특징과 주요 판매 상품을 소개해 주세요.',
                alignLabelWithHint: true,
                prefixIcon: Icon(
                  Icons.description_outlined,
                ),
              ),
            ),
            const SizedBox(
              height: PopqSpacing.sm,
            ),
            TextFormField(
              controller:
              _imageUrlController,
              enabled: !_submitting,
              maxLength: 1000,
              keyboardType:
              TextInputType.url,
              textInputAction:
              TextInputAction.next,
              decoration: const InputDecoration(
                labelText: '대표 이미지 URL',
                hintText:
                'https://example.com/store.jpg',
                prefixIcon: Icon(
                  Icons.image_outlined,
                ),
                helperText:
                '이미지 업로드 API 연결 전까지 URL로 등록합니다.',
              ),
              validator: (String? value) {
                final String imageUrl =
                    value?.trim() ?? '';

                if (imageUrl.isEmpty) {
                  return null;
                }

                final Uri? uri =
                Uri.tryParse(imageUrl);

                final bool validScheme =
                    uri?.scheme == 'http' ||
                        uri?.scheme == 'https';

                if (uri == null ||
                    !validScheme ||
                    uri.host.isEmpty) {
                  return '올바른 이미지 URL을 입력해 주세요.';
                }

                return null;
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOperatingHoursCard(
      BuildContext context,
      ) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(
          PopqSpacing.md,
        ),
        child: Column(
          crossAxisAlignment:
          CrossAxisAlignment.start,
          children: [
            Text(
              '영업 정보',
              style: Theme.of(context)
                  .textTheme
                  .titleLarge,
            ),
            const SizedBox(
              height: PopqSpacing.sm,
            ),
            Text(
              '야간 영업처럼 종료 시간이 다음 날이어도 등록할 수 있습니다.',
              style: Theme.of(context)
                  .textTheme
                  .bodySmall,
            ),
            const SizedBox(
              height: PopqSpacing.md,
            ),
            Row(
              children: [
                Expanded(
                  child:
                  OutlinedButton.icon(
                    onPressed: _submitting
                        ? null
                        : () {
                      _selectTime(
                        isOpenTime:
                        true,
                      );
                    },
                    icon: const Icon(
                      Icons.schedule_rounded,
                    ),
                    label: Text(
                      _openTime == null
                          ? '시작 시간'
                          : _formatTime(
                        _openTime!,
                      ),
                    ),
                  ),
                ),
                const SizedBox(
                  width: PopqSpacing.sm,
                ),
                Expanded(
                  child:
                  OutlinedButton.icon(
                    onPressed: _submitting
                        ? null
                        : () {
                      _selectTime(
                        isOpenTime:
                        false,
                      );
                    },
                    icon: const Icon(
                      Icons.schedule_rounded,
                    ),
                    label: Text(
                      _closeTime == null
                          ? '종료 시간'
                          : _formatTime(
                        _closeTime!,
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(
              height: PopqSpacing.lg,
            ),
            Text(
              '정기 휴무일',
              style: Theme.of(context)
                  .textTheme
                  .titleMedium,
            ),
            const SizedBox(
              height: PopqSpacing.sm,
            ),
            Wrap(
              spacing: PopqSpacing.sm,
              runSpacing: PopqSpacing.sm,
              children: _days.entries.map(
                    (
                    MapEntry<String, String>
                    entry,
                    ) {
                  final bool selected =
                  _closedDays.contains(
                    entry.key,
                  );

                  return FilterChip(
                    label: Text(entry.value),
                    selected: selected,
                    onSelected: _submitting
                        ? null
                        : (bool value) {
                      setState(() {
                        if (value) {
                          _closedDays.add(
                            entry.key,
                          );
                        } else {
                          _closedDays
                              .remove(
                            entry.key,
                          );
                        }
                      });
                    },
                  );
                },
              ).toList(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOrderPolicyCard(
      BuildContext context,
      ) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(
          PopqSpacing.md,
        ),
        child: Column(
          crossAxisAlignment:
          CrossAxisAlignment.start,
          children: [
            Text(
              '주문 운영 설정',
              style: Theme.of(context)
                  .textTheme
                  .titleLarge,
            ),
            const SizedBox(
              height: PopqSpacing.sm,
            ),
            SwitchListTile(
              contentPadding:
              EdgeInsets.zero,
              title: const Text('포장 가능'),
              subtitle: const Text(
                '고객이 포장 주문을 선택할 수 있습니다.',
              ),
              value: _takeoutAvailable,
              onChanged: _submitting
                  ? null
                  : (bool value) {
                setState(() {
                  _takeoutAvailable =
                      value;
                });
              },
            ),
            SwitchListTile(
              contentPadding:
              EdgeInsets.zero,
              title:
              const Text('매장 식사 가능'),
              subtitle: const Text(
                '고객이 매장 식사를 선택할 수 있습니다.',
              ),
              value: _dineInAvailable,
              onChanged: _submitting
                  ? null
                  : (bool value) {
                setState(() {
                  _dineInAvailable =
                      value;
                });
              },
            ),
            SwitchListTile(
              contentPadding:
              EdgeInsets.zero,
              title:
              const Text('주문 접수 가능'),
              subtitle: const Text(
                '등록 직후 주문을 받을 수 있도록 설정합니다.',
              ),
              value:
              _orderAcceptingEnabled,
              onChanged: _submitting
                  ? null
                  : (bool value) {
                setState(() {
                  _orderAcceptingEnabled =
                      value;
                });
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTagCard(
      BuildContext context,
      ) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(
          PopqSpacing.md,
        ),
        child: Column(
          crossAxisAlignment:
          CrossAxisAlignment.start,
          children: [
            Text(
              '검색 키워드',
              style: Theme.of(context)
                  .textTheme
                  .titleLarge,
            ),
            const SizedBox(
              height: PopqSpacing.sm,
            ),
            Text(
              '고객이 사업장을 찾기 쉽도록 최대 8개까지 등록할 수 있습니다.',
              style: Theme.of(context)
                  .textTheme
                  .bodySmall,
            ),
            const SizedBox(
              height: PopqSpacing.md,
            ),
            Row(
              crossAxisAlignment:
              CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: TextField(
                    controller:
                    _tagController,
                    enabled: !_submitting &&
                        _tags.length < 8,
                    maxLength: 30,
                    textInputAction:
                    TextInputAction.done,
                    decoration:
                    const InputDecoration(
                      labelText: '키워드',
                      hintText: '예: 떡볶이',
                      prefixIcon: Icon(
                        Icons.tag_rounded,
                      ),
                    ),
                    onSubmitted:
                        (String _) {
                      _addTag();
                    },
                  ),
                ),
                const SizedBox(
                  width: PopqSpacing.sm,
                ),
                IconButton.filled(
                  tooltip: '키워드 추가',
                  onPressed: _submitting ||
                      _tags.length >= 8
                      ? null
                      : _addTag,
                  icon: const Icon(
                    Icons.add_rounded,
                  ),
                ),
              ],
            ),
            if (_tags.isNotEmpty) ...[
              const SizedBox(
                height: PopqSpacing.sm,
              ),
              Wrap(
                spacing: PopqSpacing.sm,
                runSpacing: PopqSpacing.sm,
                children: _tags.map(
                      (String tag) {
                    return InputChip(
                      label: Text('#$tag'),
                      onDeleted: _submitting
                          ? null
                          : () {
                        setState(() {
                          _tags.remove(
                            tag,
                          );
                        });
                      },
                    );
                  },
                ).toList(),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Future<void> _selectTime({
    required bool isOpenTime,
  }) async {
    final TimeOfDay? currentValue =
    isOpenTime
        ? _openTime
        : _closeTime;

    final TimeOfDay? selected =
    await showTimePicker(
      context: context,
      initialTime:
      currentValue ?? TimeOfDay.now(),
      helpText: isOpenTime
          ? '영업 시작 시간'
          : '영업 종료 시간',
    );

    if (selected == null || !mounted) {
      return;
    }

    setState(() {
      if (isOpenTime) {
        _openTime = selected;
      } else {
        _closeTime = selected;
      }
    });
  }

  void _addTag() {
    if (_submitting) {
      return;
    }

    if (_tags.length >= 8) {
      _showMessage(
        '검색 키워드는 최대 8개까지 등록할 수 있어요.',
      );

      return;
    }

    final String tag = _tagController.text
        .trim()
        .replaceFirst(
      RegExp(r'^#+'),
      '',
    )
        .trim();

    if (tag.isEmpty) {
      _showMessage(
        '추가할 검색 키워드를 입력해 주세요.',
      );

      return;
    }

    if (tag.length > 30) {
      _showMessage(
        '검색 키워드는 30자 이하로 입력해 주세요.',
      );

      return;
    }

    final bool duplicated = _tags.any(
          (String existing) =>
      existing.toLowerCase() ==
          tag.toLowerCase(),
    );

    if (duplicated) {
      _showMessage(
        '이미 추가한 검색 키워드예요.',
      );

      return;
    }

    setState(() {
      _tags.add(tag);
      _tagController.clear();
    });
  }

  Future<void> _submit() async {
    if (_submitting) {
      return;
    }

    final bool valid =
        _formKey.currentState?.validate() ??
            false;

    if (!valid) {
      _showMessage(
        '필수 입력 항목을 확인해 주세요.',
      );

      return;
    }

    if (_openTime == null ||
        _closeTime == null) {
      _showMessage(
        '영업 시작 시간과 종료 시간을 선택해 주세요.',
      );

      return;
    }

    if (!_takeoutAvailable &&
        !_dineInAvailable) {
      _showMessage(
        '포장 또는 매장 식사 중 하나는 가능해야 해요.',
      );

      return;
    }

    setState(() {
      _submitting = true;
    });

    try {
      final SellerStore created =
      await widget.repository.create(
        storeType: _storeType,
        name: _nameController.text.trim(),
        description: _emptyToNull(
          _descriptionController.text,
        ),
        address:
        _addressController.text.trim(),
        detailAddress:
        _detailAddressController.text
            .trim(),
        representativeCategory:
        _representativeCategory,
        imageUrl: _emptyToNull(
          _imageUrlController.text,
        ),
        phone:
        _phoneController.text.trim(),
        openTime: _toApiTime(
          _openTime!,
        ),
        closeTime: _toApiTime(
          _closeTime!,
        ),
        closedDays: _days.keys
            .where(
          _closedDays.contains,
        )
            .toList(
          growable: false,
        ),
        takeoutAvailable:
        _takeoutAvailable,
        dineInAvailable:
        _dineInAvailable,
        orderAcceptingEnabled:
        _orderAcceptingEnabled,
        tags: List<String>.unmodifiable(
          _tags,
        ),
      );

      await widget.selectionController
          .select(
        created.storeId,
      );

      if (!mounted) {
        return;
      }

      setState(() {
        _registrationCompleted = true;
      });

      WidgetsBinding.instance
          .addPostFrameCallback(
            (Duration _) {
          if (!mounted) {
            return;
          }

          context.pop<SellerStore>(
            created,
          );
        },
      );
    } catch (_) {
      if (!mounted) {
        return;
      }

      setState(() {
        _submitting = false;
      });

      _showMessage(
        '사업장을 등록하지 못했습니다. 잠시 후 다시 시도해 주세요.',
      );
    }
  }

  String _formatTime(
      TimeOfDay time,
      ) {
    return MaterialLocalizations.of(
      context,
    ).formatTimeOfDay(
      time,
      alwaysUse24HourFormat: true,
    );
  }

  String _toApiTime(
      TimeOfDay time,
      ) {
    final String hour = time.hour
        .toString()
        .padLeft(2, '0');

    final String minute = time.minute
        .toString()
        .padLeft(2, '0');

    return '$hour:$minute';
  }

  String? _emptyToNull(
      String value,
      ) {
    final String normalized =
    value.trim();

    return normalized.isEmpty
        ? null
        : normalized;
  }

  void _showMessage(
      String message,
      ) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(message),
        ),
      );
  }
}