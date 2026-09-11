import 'package:flutter/material.dart';

import '../../../core/formatters.dart';
import '../../../data/models/card.dart';
import '../../../l10n/gen/app_localizations.dart';

/// docs/06_MOBILE_SPEC.md §Renderers — `generic`: "title/subtitle/insight + key-value grid of
/// `data` scalars (**never crash on unknown cards**)".
///
/// This is the safety net for every card type the app does not draw specially. It only shows
/// scalars; nested lists/maps are summarised, never rendered blindly.
class GenericRenderer extends StatelessWidget {
  const GenericRenderer({super.key, required this.card});

  final HomeCard card;

  @override
  Widget build(BuildContext context) => DataKeyValueGrid(data: card.data);
}

/// Two-column key/value grid over the scalar entries of a `data` map.
class DataKeyValueGrid extends StatelessWidget {
  const DataKeyValueGrid({super.key, required this.data, this.maxEntries = 8});

  final Map<String, dynamic> data;
  final int maxEntries;

  /// Renders `num`/`String`/`bool` directly; a list or map becomes "3 items" / "5 fields" so a
  /// deeply nested payload still produces something readable instead of a stack trace.
  static String? describe(Object? value, L l) {
    if (value == null) return null;
    if (value is bool) return value ? l.yes : l.no;
    if (value is num) return Fmt.num1(value);
    if (value is String) {
      if (value.isEmpty) return null;
      // ISO timestamps read much better as a time.
      if (RegExp(r'^\d{4}-\d{2}-\d{2}T').hasMatch(value)) return Fmt.dateTime(value);
      if (RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(value)) return Fmt.dayLong(value);
      return value;
    }
    if (value is List) return value.isEmpty ? null : l.itemsCount(value.length);
    if (value is Map) return value.isEmpty ? null : l.fieldsCount(value.length);
    return value.toString();
  }

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    final theme = Theme.of(context);
    final entries = <MapEntry<String, String>>[];
    for (final entry in data.entries) {
      if (entries.length >= maxEntries) break;
      final described = describe(entry.value, l);
      if (described == null) continue;
      entries.add(MapEntry(Fmt.humanize(entry.key), described));
    }

    if (entries.isEmpty) {
      return Text(
        l.noFurtherDetail,
        style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth >= 420 ? 3 : 2;
        final width = (constraints.maxWidth - (columns - 1) * 12) / columns;
        return Wrap(
          spacing: 12,
          runSpacing: 10,
          children: [
            for (final entry in entries)
              SizedBox(
                width: width,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      entry.key,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.labelSmall
                          ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                    ),
                    Text(
                      entry.value,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodyMedium,
                    ),
                  ],
                ),
              ),
          ],
        );
      },
    );
  }
}
