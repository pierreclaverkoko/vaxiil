import 'dart:async';

import 'package:flutter/material.dart';
import 'package:vaxiil_mobile/core/di/injection_container.dart';
import 'package:vaxiil_mobile/features/business/data/organization_models.dart';
import 'package:vaxiil_mobile/features/business/data/organization_repository.dart';
import 'package:vaxiil_mobile/l10n/app_localizations.dart';

/// Country-scoped city autocomplete selecting a cities.City id.
class CitySearchField extends StatefulWidget {
  const CitySearchField({
    required this.countryId,
    required this.onSelected,
    this.initialCityId,
    this.initialCityName,
    this.enabled = true,
    this.validator,
    super.key,
  });

  final String? countryId;
  final String? initialCityId;
  final String? initialCityName;
  final ValueChanged<CityBriefModel?> onSelected;
  final bool enabled;
  final FormFieldValidator<String>? validator;

  @override
  State<CitySearchField> createState() => _CitySearchFieldState();
}

class _CitySearchFieldState extends State<CitySearchField> {
  final _controller = TextEditingController();
  Timer? _debounce;
  List<CityBriefModel> _options = [];
  String? _selectedId;
  var _searching = false;

  @override
  void initState() {
    super.initState();
    _selectedId = widget.initialCityId;
    if (widget.initialCityName != null && widget.initialCityName!.isNotEmpty) {
      _controller.text = widget.initialCityName!;
    }
  }

  @override
  void didUpdateWidget(covariant CitySearchField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.countryId != widget.countryId) {
      _selectedId = null;
      _controller.clear();
      _options = [];
      widget.onSelected(null);
    } else if (oldWidget.initialCityId != widget.initialCityId ||
        oldWidget.initialCityName != widget.initialCityName) {
      _selectedId = widget.initialCityId;
      _controller.text = widget.initialCityName ?? '';
    }
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.dispose();
    super.dispose();
  }

  void _onQueryChanged(String value) {
    _selectedId = null;
    widget.onSelected(null);
    _debounce?.cancel();
    final countryId = widget.countryId;
    if (countryId == null || countryId.isEmpty || value.trim().length < 2) {
      setState(() => _options = []);
      return;
    }
    _debounce = Timer(const Duration(milliseconds: 300), () async {
      setState(() => _searching = true);
      try {
        final cities = await sl<OrganizationRepository>().listCities(
          countryId: countryId,
          query: value,
        );
        if (!mounted) return;
        setState(() {
          _options = cities;
          _searching = false;
        });
      } catch (_) {
        if (!mounted) return;
        setState(() {
          _options = [];
          _searching = false;
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final canSearch =
        widget.enabled && widget.countryId != null && widget.countryId!.isNotEmpty;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextFormField(
          controller: _controller,
          enabled: canSearch,
          decoration: InputDecoration(
            labelText: l10n.cityLabel,
            hintText: canSearch ? l10n.citySearchHint : l10n.citySelectCountryFirst,
            suffixIcon: _searching
                ? const Padding(
                    padding: EdgeInsets.all(12),
                    child: SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  )
                : const Icon(Icons.search),
          ),
          validator: widget.validator ??
              (v) {
                if (_selectedId == null || _selectedId!.isEmpty) {
                  return l10n.cityRequired;
                }
                return null;
              },
          onChanged: _onQueryChanged,
        ),
        if (_options.isNotEmpty) ...[
          const SizedBox(height: 4),
          Material(
            elevation: 1,
            borderRadius: BorderRadius.circular(8),
            child: ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _options.length.clamp(0, 8),
              separatorBuilder: (_, __) => const Divider(height: 1),
              itemBuilder: (context, index) {
                final city = _options[index];
                return ListTile(
                  dense: true,
                  title: Text(city.name),
                  onTap: () {
                    setState(() {
                      _selectedId = city.id;
                      _controller.text = city.name;
                      _options = [];
                    });
                    widget.onSelected(city);
                  },
                );
              },
            ),
          ),
        ],
      ],
    );
  }
}
