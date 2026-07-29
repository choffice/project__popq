import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:popq_design_system/popq_design_system.dart';

import '../permissions/customer_permission_gateway.dart';
import '../../routing/customer_router.dart';
import 'store_discovery_controller.dart';
import 'store_discovery_repository.dart';

class StoreDiscoveryScreen extends StatefulWidget {
  const StoreDiscoveryScreen({
    required this.repository,
    required this.permissionGateway,
    super.key,
  });

  final StoreDiscoveryRepository repository;
  final CustomerPermissionGateway permissionGateway;

  @override
  State<StoreDiscoveryScreen> createState() => _StoreDiscoveryScreenState();
}

class _StoreDiscoveryScreenState extends State<StoreDiscoveryScreen> {
  static const _tags = ['coffee', 'dessert', 'event', 'local'];

  late final StoreDiscoveryController _controller;
  final _queryController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _controller = StoreDiscoveryController(
      repository: widget.repository,
      permissionGateway: widget.permissionGateway,
    )..addListener(_onChanged);
    _controller.search();
  }

  @override
  void dispose() {
    _controller
      ..removeListener(_onChanged)
      ..dispose();
    _queryController.dispose();
    super.dispose();
  }

  void _onChanged() => setState(() {});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(
            PopqSpacing.md,
            PopqSpacing.sm,
            PopqSpacing.md,
            0,
          ),
          child: Column(
            children: [
              SearchBar(
                controller: _queryController,
                hintText: '스토어 이름, 설명, 주소 검색',
                leading: const Icon(Icons.search_rounded),
                trailing: [
                  IconButton(
                    tooltip: '현재 위치 사용',
                    onPressed: _useCurrentLocation,
                    icon: Icon(
                      _controller.location == null
                          ? Icons.near_me_outlined
                          : Icons.near_me_rounded,
                    ),
                  ),
                ],
                onSubmitted: (value) => _controller.search(query: value),
              ),
              const SizedBox(height: PopqSpacing.sm),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: _tags.map((tag) {
                    return Padding(
                      padding: const EdgeInsets.only(right: PopqSpacing.sm),
                      child: FilterChip(
                        label: Text('#$tag'),
                        selected: _controller.selectedTag == tag,
                        onSelected: (_) => _controller.selectTag(
                          tag,
                          query: _queryController.text,
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ),
              if (_controller.location != null)
                const Align(
                  alignment: Alignment.centerLeft,
                  child: Padding(
                    padding: EdgeInsets.only(top: PopqSpacing.xs),
                    child: Text('현재 위치 기준 10km 이내 · 가까운 순'),
                  ),
                ),
            ],
          ),
        ),
        Expanded(child: _buildResults()),
      ],
    );
  }

  Widget _buildResults() {
    return switch (_controller.status) {
      DiscoveryStatus.loading => const PopqLoadingView(
        message: '가까운 스토어를 찾고 있어요.',
      ),
      DiscoveryStatus.failure => PopqErrorView(
        message: '스토어 목록을 불러오지 못했습니다.',
        onRetry: () => _controller.search(query: _queryController.text),
      ),
      DiscoveryStatus.empty => const PopqEmptyView(
        icon: Icons.storefront_outlined,
        title: '조건에 맞는 스토어가 없어요.',
        description: '검색어나 태그를 바꾸어 다시 찾아보세요.',
      ),
      DiscoveryStatus.data => RefreshIndicator(
        onRefresh: () => _controller.search(query: _queryController.text),
        child: ListView.separated(
          padding: const EdgeInsets.all(PopqSpacing.md),
          itemCount: _controller.stores.length,
          separatorBuilder: (_, _) => const SizedBox(height: PopqSpacing.sm),
          itemBuilder: (context, index) {
            return _StoreCard(store: _controller.stores[index]);
          },
        ),
      ),
    };
  }

  Future<void> _useCurrentLocation() async {
    final decision = await _controller.useCurrentLocation(
      query: _queryController.text,
    );
    if (!mounted || decision == PermissionDecision.granted) return;
    final message = switch (decision) {
      PermissionDecision.denied => '위치 권한을 허용하면 가까운 순서로 볼 수 있어요.',
      PermissionDecision.permanentlyDenied => '기기 설정에서 위치 권한을 허용해 주세요.',
      PermissionDecision.serviceDisabled => '기기의 위치 서비스를 켜 주세요.',
      PermissionDecision.granted => '',
    };
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        action: decision == PermissionDecision.permanentlyDenied
            ? SnackBarAction(
                label: '설정',
                onPressed: widget.permissionGateway.openSettings,
              )
            : null,
      ),
    );
  }
}

class _StoreCard extends StatelessWidget {
  const _StoreCard({required this.store});

  final CustomerStore store;

  @override
  Widget build(BuildContext context) {
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => context.push('${CustomerRoutes.stores}/${store.storeId}'),
        child: Padding(
          padding: const EdgeInsets.all(PopqSpacing.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      store.name,
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                  ),
                  if (store.distanceMeters != null)
                    Text(_formatDistance(store.distanceMeters!)),
                ],
              ),
              if (store.description != null) ...[
                const SizedBox(height: PopqSpacing.xs),
                Text(
                  store.description!,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
              if (store.address != null) ...[
                const SizedBox(height: PopqSpacing.sm),
                Row(
                  children: [
                    const Icon(Icons.place_outlined, size: 18),
                    const SizedBox(width: PopqSpacing.xs),
                    Expanded(child: Text(store.address!)),
                  ],
                ),
              ],
              if (store.tags.isNotEmpty) ...[
                const SizedBox(height: PopqSpacing.sm),
                Wrap(
                  spacing: PopqSpacing.xs,
                  children: store.tags
                      .map((tag) => Chip(label: Text('#$tag')))
                      .toList(),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  String _formatDistance(int meters) {
    if (meters < 1000) return '${meters}m';
    return '${(meters / 1000).toStringAsFixed(1)}km';
  }
}
