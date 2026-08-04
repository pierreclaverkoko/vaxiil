import 'package:flutter/material.dart';
import 'package:vaxiil_mobile/features/business/data/organization_models.dart';
import 'package:vaxiil_mobile/l10n/app_localizations.dart';

/// Searchable country dropdown bound to the shared country scope.
class CountryScopePicker extends StatelessWidget {
  const CountryScopePicker({
    required this.countries,
    required this.valueId,
    required this.onChanged,
    super.key,
  });

  final List<CountryBriefModel> countries;
  final String? valueId;
  final ValueChanged<CountryBriefModel> onChanged;

  Future<void> _openPicker(BuildContext context) async {
    final l10n = AppLocalizations.of(context);
    final selected = await showModalBottomSheet<CountryBriefModel>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (ctx) {
        var query = '';
        return StatefulBuilder(
          builder: (context, setModalState) {
            final filtered = countries.where((c) {
              final q = query.trim().toLowerCase();
              if (q.isEmpty) return true;
              return c.name.toLowerCase().contains(q) ||
                  c.isoCode2.toLowerCase().contains(q);
            }).toList();
            return SafeArea(
              child: Padding(
                padding: EdgeInsets.only(
                  left: 16,
                  right: 16,
                  bottom: MediaQuery.viewInsetsOf(context).bottom + 16,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      l10n.countryFilterLabel,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      autofocus: true,
                      decoration: InputDecoration(
                        hintText: l10n.countrySearchHint,
                        prefixIcon: const Icon(Icons.search),
                        border: const OutlineInputBorder(),
                        isDense: true,
                      ),
                      onChanged: (v) => setModalState(() => query = v),
                    ),
                    const SizedBox(height: 8),
                    SizedBox(
                      height: MediaQuery.sizeOf(context).height * 0.45,
                      child: ListView.builder(
                        itemCount: filtered.length,
                        itemBuilder: (context, index) {
                          final c = filtered[index];
                          final selected = c.id == valueId;
                          return ListTile(
                            selected: selected,
                            title: Text(c.name),
                            trailing: Text(
                              c.isoCode2.toUpperCase(),
                              style: Theme.of(context).textTheme.labelLarge,
                            ),
                            onTap: () => Navigator.of(context).pop(c),
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
      },
    );
    if (selected != null) {
      onChanged(selected);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    CountryBriefModel? current;
    for (final c in countries) {
      if (c.id == valueId) {
        current = c;
        break;
      }
    }
    current ??= countries.isNotEmpty ? countries.first : null;
    final label = current == null
        ? l10n.countryFilterLabel
        : '${current.isoCode2.toUpperCase()} · ${current.name}';

    return OutlinedButton.icon(
      onPressed: countries.isEmpty ? null : () => _openPicker(context),
      icon: const Icon(Icons.public, size: 18),
      label: Text(label, overflow: TextOverflow.ellipsis),
    );
  }
}
