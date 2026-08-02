import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:popq_app_core/popq_app_core.dart';
import 'package:popq_design_system/popq_design_system.dart';

import '../../routing/customer_router.dart';
import 'customer_engagement_repository.dart';

typedef ProfileSnapshot = ({
CustomerProfile profile,
List<InterestedStore> interests,
List<CustomerReview> reviews,
});

class CustomerProfileScreen extends StatefulWidget {
  const CustomerProfileScreen({
    required this.repository,
    required this.onSignOut,
    this.themeController,
    super.key,
  });

  final CustomerEngagementRepository repository;
  final Future<void> Function() onSignOut;
  final PopqThemeController? themeController;

  @override
  State<CustomerProfileScreen> createState() =>
      _CustomerProfileScreenState();
}

class _CustomerProfileScreenState
    extends State<CustomerProfileScreen> {
  late Future<ProfileSnapshot> _snapshot;

  @override
  void initState() {
    super.initState();
    _snapshot = _load();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<ProfileSnapshot>(
      future: _snapshot,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const PopqLoadingView(
            message: '마이페이지를 불러오고 있어요.',
          );
        }

        if (snapshot.hasError || !snapshot.hasData) {
          return PopqErrorView(
            message: '마이페이지를 불러오지 못했어요.',
            onRetry: _reload,
          );
        }

        final data = snapshot.requireData;

        return RefreshIndicator(
          onRefresh: () async => _reload(),
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(
              PopqSpacing.lg,
            ),
            children: [
              _ProfileHeader(
                profile: data.profile,
              ),
              const SizedBox(
                height: PopqSpacing.lg,
              ),
              _ProfileCounts(
                profile: data.profile,
              ),

              const SizedBox(
                height: PopqSpacing.xl,
              ),
              Text(
                '내 활동',
                style: Theme.of(context)
                    .textTheme
                    .titleLarge,
              ),
              const SizedBox(
                height: PopqSpacing.sm,
              ),
              Card(
                child: ListTile(
                  leading: const Icon(
                    Icons.receipt_long_rounded,
                  ),
                  title: const Text(
                    '주문 내역',
                  ),
                  subtitle: Text(
                    data.profile.orderCount > 0
                        ? '지금까지 주문 ${data.profile.orderCount}건을 확인할 수 있어요.'
                        : '첫 주문을 시작하면 여기에 기록이 모여요.',
                  ),
                  trailing: const Icon(
                    Icons.chevron_right_rounded,
                  ),
                  onTap: () {
                    context.go(
                      CustomerRoutes.orders,
                    );
                  },
                ),
              ),

              if (widget.themeController != null) ...[
                const SizedBox(
                  height: PopqSpacing.xl,
                ),
                Text(
                  '화면 설정',
                  style: Theme.of(context)
                      .textTheme
                      .titleLarge,
                ),
                const SizedBox(
                  height: PopqSpacing.sm,
                ),
                _ThemeSettingsCard(
                  controller:
                  widget.themeController!,
                  onChanged: _changeTheme,
                ),
              ],

              const SizedBox(
                height: PopqSpacing.xl,
              ),
              Text(
                '관심 스토어',
                style: Theme.of(context)
                    .textTheme
                    .titleLarge,
              ),
              const SizedBox(
                height: PopqSpacing.sm,
              ),

              if (data.interests.isEmpty)
                const _EmptySection(
                  message:
                  '아직 관심 스토어가 없어요.',
                )
              else
                for (final store
                in data.interests)
                  Padding(
                    padding:
                    const EdgeInsets.only(
                      bottom: PopqSpacing.sm,
                    ),
                    child: Card(
                      child: ListTile(
                        leading: const Icon(
                          Icons.favorite_rounded,
                        ),
                        title: Text(
                          store.name,
                        ),
                        subtitle: Text(
                          store.address ??
                              '주소 정보 없음',
                        ),
                        trailing: const Icon(
                          Icons
                              .chevron_right_rounded,
                        ),
                        onTap: () {
                          context.push(
                            '${CustomerRoutes.stores}/${store.storeId}',
                          );
                        },
                      ),
                    ),
                  ),

              const SizedBox(
                height: PopqSpacing.xl,
              ),
              Text(
                '내 리뷰',
                style: Theme.of(context)
                    .textTheme
                    .titleLarge,
              ),
              const SizedBox(
                height: PopqSpacing.sm,
              ),

              if (data.reviews
                  .where(
                    (review) =>
                review.isActive,
              )
                  .isEmpty)
                const _EmptySection(
                  message:
                  '작성한 리뷰가 없어요.',
                )
              else
                for (final review
                in data.reviews.where(
                      (review) => review.isActive,
                ))
                  Padding(
                    padding:
                    const EdgeInsets.only(
                      bottom: PopqSpacing.sm,
                    ),
                    child: _ReviewCard(
                      review: review,
                      onEdit: () {
                        _editReview(review);
                      },
                      onDelete: () {
                        _deleteReview(review);
                      },
                    ),
                  ),

              const SizedBox(
                height: PopqSpacing.xl,
              ),
              OutlinedButton.icon(
                onPressed: _signOut,
                icon: const Icon(
                  Icons.logout_rounded,
                ),
                label: const Text(
                  '로그아웃',
                ),
              ),
              const SizedBox(
                height: PopqSpacing.xl,
              ),
            ],
          ),
        );
      },
    );
  }

  Future<ProfileSnapshot> _load() async {
    final results = await Future.wait<Object>(
      [
        widget.repository.getProfile(),
        widget.repository.findInterests(),
        widget.repository.findMyReviews(),
      ],
    );

    return (
    profile:
    results[0] as CustomerProfile,
    interests:
    results[1] as List<InterestedStore>,
    reviews:
    results[2] as List<CustomerReview>,
    );
  }

  void _reload() {
    setState(() {
      _snapshot = _load();
    });
  }

  Future<void> _changeTheme(
      PopqThemePreference preference,
      ) async {
    final controller =
        widget.themeController;

    if (controller == null) {
      return;
    }

    try {
      await controller.setPreference(
        preference,
      );
    } catch (_) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context)
          .showSnackBar(
        const SnackBar(
          content: Text(
            '화면 설정을 저장하지 못했어요.',
          ),
        ),
      );
    }
  }

  Future<void> _editReview(
      CustomerReview review,
      ) async {
    final controller =
    TextEditingController(
      text: review.content ?? '',
    );

    var rating = review.rating;
    var saving = false;

    final updated =
    await showDialog<CustomerReview>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder:
              (context, setDialogState) {
            return AlertDialog(
              title: Text(
                '${review.storeName} 리뷰 수정',
              ),
              content: Column(
                mainAxisSize:
                MainAxisSize.min,
                children: [
                  DropdownButtonFormField<int>(
                    initialValue: rating,
                    decoration:
                    const InputDecoration(
                      labelText: '별점',
                    ),
                    items: [
                      for (var value = 1;
                      value <= 5;
                      value++)
                        DropdownMenuItem(
                          value: value,
                          child: Text(
                            '별 $value개',
                          ),
                        ),
                    ],
                    onChanged: saving
                        ? null
                        : (value) {
                      if (value ==
                          null) {
                        return;
                      }

                      setDialogState(
                            () {
                          rating =
                              value;
                        },
                      );
                    },
                  ),
                  const SizedBox(
                    height:
                    PopqSpacing.md,
                  ),
                  TextField(
                    controller: controller,
                    maxLength: 1000,
                    maxLines: 4,
                    decoration:
                    const InputDecoration(
                      labelText: '리뷰 내용',
                      alignLabelWithHint:
                      true,
                    ),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: saving
                      ? null
                      : () {
                    Navigator.of(
                      dialogContext,
                    ).pop();
                  },
                  child: const Text(
                    '취소',
                  ),
                ),
                FilledButton(
                  onPressed: saving
                      ? null
                      : () async {
                    setDialogState(
                          () {
                        saving = true;
                      },
                    );

                    try {
                      final result =
                      await widget
                          .repository
                          .updateReview(
                        reviewId:
                        review
                            .reviewId,
                        rating: rating,
                        content:
                        controller
                            .text
                            .trim(),
                      );

                      if (dialogContext
                          .mounted) {
                        Navigator.of(
                          dialogContext,
                        ).pop(
                          result,
                        );
                      }
                    } catch (_) {
                      if (!dialogContext
                          .mounted) {
                        return;
                      }

                      setDialogState(
                            () {
                          saving =
                          false;
                        },
                      );

                      ScaffoldMessenger
                          .of(
                        dialogContext,
                      ).showSnackBar(
                        const SnackBar(
                          content: Text(
                            '리뷰를 수정하지 못했어요.',
                          ),
                        ),
                      );
                    }
                  },
                  child: Text(
                    saving
                        ? '저장 중...'
                        : '저장',
                  ),
                ),
              ],
            );
          },
        );
      },
    );

    controller.dispose();

    if (updated != null && mounted) {
      _reload();
    }
  }

  Future<void> _deleteReview(
      CustomerReview review,
      ) async {
    final confirmed =
    await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text(
            '리뷰를 삭제할까요?',
          ),
          content: const Text(
            '삭제한 리뷰는 스토어에 더 이상 노출되지 않아요.',
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(
                  dialogContext,
                ).pop(false);
              },
              child: const Text(
                '취소',
              ),
            ),
            FilledButton(
              onPressed: () {
                Navigator.of(
                  dialogContext,
                ).pop(true);
              },
              child: const Text(
                '삭제',
              ),
            ),
          ],
        );
      },
    );

    if (confirmed != true) {
      return;
    }

    try {
      await widget.repository.deleteReview(
        review.reviewId,
      );

      if (mounted) {
        _reload();
      }
    } catch (_) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context)
          .showSnackBar(
        const SnackBar(
          content: Text(
            '리뷰를 삭제하지 못했어요.',
          ),
        ),
      );
    }
  }

  Future<void> _signOut() async {
    await widget.onSignOut();

    if (mounted) {
      context.go(
        CustomerRoutes.home,
      );
    }
  }
}

class _ThemeSettingsCard
    extends StatelessWidget {
  const _ThemeSettingsCard({
    required this.controller,
    required this.onChanged,
  });

  final PopqThemeController controller;
  final Future<void> Function(
      PopqThemePreference preference,
      ) onChanged;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (context, child) {
        return Card(
          child: Padding(
            padding: const EdgeInsets.all(
              PopqSpacing.md,
            ),
            child: Column(
              crossAxisAlignment:
              CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    CircleAvatar(
                      backgroundColor:
                      Theme.of(context)
                          .colorScheme
                          .primaryContainer,
                      foregroundColor:
                      Theme.of(context)
                          .colorScheme
                          .onPrimaryContainer,
                      child: Icon(
                        controller.isDarkMode
                            ? Icons
                            .dark_mode_rounded
                            : Icons
                            .light_mode_rounded,
                      ),
                    ),
                    const SizedBox(
                      width: PopqSpacing.md,
                    ),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment:
                        CrossAxisAlignment
                            .start,
                        children: [
                          Text(
                            '앱 테마',
                            style: TextStyle(
                              fontWeight:
                              FontWeight
                                  .w800,
                            ),
                          ),
                          SizedBox(
                            height:
                            PopqSpacing.xs,
                          ),
                          Text(
                            '원하는 화면 모드를 선택하세요.',
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(
                  height: PopqSpacing.md,
                ),
                SizedBox(
                  width: double.infinity,
                  child: SegmentedButton<
                      PopqThemePreference>(
                    segments: const [
                      ButtonSegment(
                        value:
                        PopqThemePreference
                            .light,
                        icon: Icon(
                          Icons
                              .light_mode_rounded,
                        ),
                        label: Text(
                          '기본 모드',
                        ),
                      ),
                      ButtonSegment(
                        value:
                        PopqThemePreference
                            .dark,
                        icon: Icon(
                          Icons
                              .dark_mode_rounded,
                        ),
                        label: Text(
                          '다크 모드',
                        ),
                      ),
                    ],
                    selected: {
                      controller.preference,
                    },
                    showSelectedIcon: false,
                    onSelectionChanged:
                        (selection) {
                      if (selection.isEmpty) {
                        return;
                      }

                      onChanged(
                        selection.first,
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _ProfileHeader extends StatelessWidget {
  const _ProfileHeader({
    required this.profile,
  });

  final CustomerProfile profile;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const CircleAvatar(
          radius: 30,
          child: Icon(
            Icons.person_rounded,
            size: 32,
          ),
        ),
        const SizedBox(
          width: PopqSpacing.md,
        ),
        Expanded(
          child: Column(
            crossAxisAlignment:
            CrossAxisAlignment.start,
            children: [
              Text(
                profile.name,
                style: Theme.of(context)
                    .textTheme
                    .titleLarge,
              ),
              Text(
                profile.email,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _ProfileCounts extends StatelessWidget {
  const _ProfileCounts({
    required this.profile,
  });

  final CustomerProfile profile;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        _CountItem(
          label: '주문',
          value: profile.orderCount,
        ),
        const SizedBox(
          width: PopqSpacing.sm,
        ),
        _CountItem(
          label: '관심',
          value: profile.interestCount,
        ),
        const SizedBox(
          width: PopqSpacing.sm,
        ),
        _CountItem(
          label: '리뷰',
          value: profile.reviewCount,
        ),
      ],
    );
  }
}

class _CountItem extends StatelessWidget {
  const _CountItem({
    required this.label,
    required this.value,
  });

  final String label;
  final int value;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Card(
        child: Padding(
          padding:
          const EdgeInsets.symmetric(
            vertical: PopqSpacing.md,
          ),
          child: Column(
            children: [
              Text(
                '$value',
                style: Theme.of(context)
                    .textTheme
                    .titleLarge,
              ),
              Text(
                label,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ReviewCard extends StatelessWidget {
  const _ReviewCard({
    required this.review,
    required this.onEdit,
    required this.onDelete,
  });

  final CustomerReview review;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(
          PopqSpacing.md,
        ),
        child: Column(
          crossAxisAlignment:
          CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    review.storeName,
                    style: Theme.of(
                      context,
                    )
                        .textTheme
                        .titleMedium,
                  ),
                ),
                Text(
                  List.filled(
                    review.rating,
                    '★',
                  ).join(),
                ),
              ],
            ),
            if (review.content
                ?.isNotEmpty ??
                false) ...[
              const SizedBox(
                height: PopqSpacing.sm,
              ),
              Text(
                review.content!,
              ),
            ],
            Row(
              mainAxisAlignment:
              MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: onEdit,
                  child: const Text(
                    '수정',
                  ),
                ),
                TextButton(
                  onPressed: onDelete,
                  child: const Text(
                    '삭제',
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptySection extends StatelessWidget {
  const _EmptySection({
    required this.message,
  });

  final String message;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(
          PopqSpacing.lg,
        ),
        child: Text(
          message,
          textAlign: TextAlign.center,
        ),
      ),
    );
  }
}