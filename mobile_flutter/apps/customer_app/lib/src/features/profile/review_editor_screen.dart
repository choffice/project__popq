import 'package:flutter/material.dart';
import 'package:popq_design_system/popq_design_system.dart';

import 'customer_engagement_repository.dart';

class ReviewEditorScreen extends StatefulWidget {
  const ReviewEditorScreen({
    required this.orderPublicId,
    required this.repository,
    super.key,
  });

  final String orderPublicId;
  final CustomerEngagementRepository repository;

  @override
  State<ReviewEditorScreen> createState() => _ReviewEditorScreenState();
}

class _ReviewEditorScreenState extends State<ReviewEditorScreen> {
  final _contentController = TextEditingController();
  var _rating = 5;
  var _saving = false;

  @override
  void dispose() {
    _contentController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('由щ럭 ?묒꽦')),
      body: ListView(
        padding: const EdgeInsets.all(PopqSpacing.lg),
        children: [
          Text('二쇰Ц? ?대뼚?⑤굹??', style: Theme.of(context).textTheme.headlineSmall),
          const SizedBox(height: PopqSpacing.sm),
          const Text('?꾨즺??二쇰Ц?먮뒗 由щ럭瑜???踰덈쭔 ?묒꽦?????덉뼱??'),
          const SizedBox(height: PopqSpacing.xl),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              for (var value = 1; value <= 5; value++)
                IconButton(
                  tooltip: '蹂?$value媛?,
                  onPressed: _saving
                      ? null
                      : () => setState(() => _rating = value),
                  iconSize: 40,
                  color: PopqPalette.forest,
                  icon: Icon(
                    value <= _rating
                        ? Icons.star_rounded
                        : Icons.star_outline_rounded,
                  ),
                ),
            ],
          ),
          const SizedBox(height: PopqSpacing.lg),
          TextField(
            controller: _contentController,
            enabled: !_saving,
            maxLength: 1000,
            maxLines: 7,
            decoration: const InputDecoration(
              labelText: '由щ럭 ?댁슜',
              hintText: '醫뗭븯???먭낵 ?꾩돩?좊뜕 ?먯쓣 ?④꺼二쇱꽭??',
              alignLabelWithHint: true,
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: PopqSpacing.lg),
          FilledButton.icon(
            onPressed: _saving ? null : _save,
            icon: const Icon(Icons.rate_review_rounded),
            label: Text(_saving ? '?깅줉 以?..' : '由щ럭 ?깅줉'),
          ),
        ],
      ),
    );
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      await widget.repository.createReview(
        orderPublicId: widget.orderPublicId,
        rating: _rating,
        content: _contentController.text.trim(),
      );
      if (mounted) Navigator.of(context).pop(true);
    } catch (_) {
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(
        context,
      ).showTopSnackBar(const SnackBar(content: Text('由щ럭瑜??깅줉?섏? 紐삵뻽?댁슂.')));
    }
  }
}

