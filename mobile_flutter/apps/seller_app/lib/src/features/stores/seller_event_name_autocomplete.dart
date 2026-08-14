import 'package:flutter/material.dart';
import 'package:popq_design_system/popq_design_system.dart';

import 'seller_store_repository.dart';

class SellerEventNameAutocomplete extends StatelessWidget {
  const SellerEventNameAutocomplete({
    required this.controller,
    required this.focusNode,
    required this.suggestions,
    required this.enabled,
    required this.loading,
    required this.validator,
    this.errorMessage,
    super.key,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final List<SellerNearbyEventSuggestion> suggestions;
  final bool enabled;
  final bool loading;
  final String? Function(String?) validator;
  final String? errorMessage;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        RawAutocomplete<SellerNearbyEventSuggestion>(
          textEditingController: controller,
          focusNode: focusNode,
          displayStringForOption: (SellerNearbyEventSuggestion option) =>
              option.eventName,
          optionsBuilder: (TextEditingValue value) {
            final String query = value.text.trim().toLowerCase();
            if (suggestions.isEmpty) {
              return const Iterable<SellerNearbyEventSuggestion>.empty();
            }
            if (query.isEmpty) {
              return suggestions;
            }
            return suggestions.where(
              (SellerNearbyEventSuggestion option) =>
                  option.eventName.toLowerCase().contains(query),
            );
          },
          fieldViewBuilder:
              (
                BuildContext context,
                TextEditingController textController,
                FocusNode fieldFocusNode,
                VoidCallback onFieldSubmitted,
              ) {
                return TextFormField(
                  key: const Key('seller-event-name-field'),
                  controller: textController,
                  focusNode: fieldFocusNode,
                  enabled: enabled,
                  maxLength: 150,
                  textInputAction: TextInputAction.next,
                  decoration: InputDecoration(
                    labelText: '행사명 *',
                    hintText: '행사명을 입력하거나 인근 행사를 선택해 주세요.',
                    prefixIcon: const Icon(Icons.celebration_outlined),
                    suffixIcon: loading
                        ? const Padding(
                            padding: EdgeInsets.all(14),
                            child: SizedBox.square(
                              dimension: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            ),
                          )
                        : null,
                  ),
                  validator: validator,
                  onFieldSubmitted: (_) => onFieldSubmitted(),
                );
              },
          optionsViewBuilder:
              (
                BuildContext context,
                AutocompleteOnSelected<SellerNearbyEventSuggestion> onSelected,
                Iterable<SellerNearbyEventSuggestion> options,
              ) {
                final List<SellerNearbyEventSuggestion> visible = options
                    .toList();
                return Align(
                  alignment: Alignment.topLeft,
                  child: Material(
                    elevation: 6,
                    borderRadius: BorderRadius.circular(12),
                    clipBehavior: Clip.antiAlias,
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(
                        minWidth: 280,
                        maxWidth: 520,
                        maxHeight: 280,
                      ),
                      child: ListView.separated(
                        padding: EdgeInsets.zero,
                        shrinkWrap: true,
                        itemCount: visible.length,
                        separatorBuilder: (_, _) => const Divider(height: 1),
                        itemBuilder: (BuildContext context, int index) {
                          final SellerNearbyEventSuggestion option =
                              visible[index];
                          return ListTile(
                            key: Key(
                              'seller-event-suggestion-${option.eventName}',
                            ),
                            title: Text(option.eventName),
                            subtitle: Text(
                              '인근 등록 스토어 ${option.activeStoreCount}곳',
                            ),
                            onTap: () => onSelected(option),
                          );
                        },
                      ),
                    ),
                  ),
                );
              },
        ),
        if (errorMessage != null) ...<Widget>[
          const SizedBox(height: PopqSpacing.xs),
          Text(
            errorMessage!,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Theme.of(context).colorScheme.error,
            ),
          ),
        ],
      ],
    );
  }
}
