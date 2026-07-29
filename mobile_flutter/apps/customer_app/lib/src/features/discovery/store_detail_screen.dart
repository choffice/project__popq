import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:popq_design_system/popq_design_system.dart';

import '../../routing/customer_router.dart';
import 'store_discovery_repository.dart';

class StoreDetailScreen extends StatefulWidget {
  const StoreDetailScreen({
    required this.storeId,
    required this.repository,
    super.key,
  });

  final int storeId;
  final StoreDiscoveryRepository repository;

  @override
  State<StoreDetailScreen> createState() => _StoreDetailScreenState();
}

class _StoreDetailScreenState extends State<StoreDetailScreen> {
  late Future<CustomerStore> _store;

  @override
  void initState() {
    super.initState();
    _store = widget.repository.findDetail(widget.storeId);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('스토어 상세')),
      body: FutureBuilder<CustomerStore>(
        future: _store,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const PopqLoadingView(message: '스토어 정보를 불러오고 있어요.');
          }
          if (snapshot.hasError || !snapshot.hasData) {
            return PopqErrorView(
              message: '스토어 상세 정보를 불러오지 못했습니다.',
              onRetry: () => setState(() {
                _store = widget.repository.findDetail(widget.storeId);
              }),
            );
          }
          final store = snapshot.requireData;
          return ListView(
            padding: const EdgeInsets.all(PopqSpacing.lg),
            children: [
              Container(
                height: 180,
                decoration: BoxDecoration(
                  color: PopqPalette.forest,
                  borderRadius: BorderRadius.circular(28),
                ),
                child: const Icon(
                  Icons.storefront_rounded,
                  size: 76,
                  color: PopqPalette.lime,
                ),
              ),
              const SizedBox(height: PopqSpacing.lg),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      store.name,
                      style: Theme.of(context).textTheme.headlineMedium,
                    ),
                  ),
                  const Chip(label: Text('영업 중')),
                ],
              ),
              if (store.description != null) ...[
                const SizedBox(height: PopqSpacing.sm),
                Text(
                  store.description!,
                  style: Theme.of(context).textTheme.bodyLarge,
                ),
              ],
              if (store.address != null) ...[
                const SizedBox(height: PopqSpacing.lg),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.place_rounded),
                  title: const Text('위치'),
                  subtitle: Text(store.address!),
                ),
              ],
              if (store.tags.isNotEmpty) ...[
                const SizedBox(height: PopqSpacing.md),
                Wrap(
                  spacing: PopqSpacing.sm,
                  runSpacing: PopqSpacing.xs,
                  children: store.tags
                      .map((tag) => Chip(label: Text('#$tag')))
                      .toList(),
                ),
              ],
              const SizedBox(height: PopqSpacing.xl),
              FilledButton.icon(
                onPressed: () => context.push(
                  '${CustomerRoutes.stores}/${store.storeId}/products',
                ),
                icon: const Icon(Icons.shopping_bag_outlined),
                label: const Text('상품 보기'),
              ),
            ],
          );
        },
      ),
    );
  }
}
