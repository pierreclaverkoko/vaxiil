import 'package:equatable/equatable.dart';

/// API shape from DRF [ChoiceEnumField]: `{ value, title, css }`.
class ChoiceEnumData extends Equatable {
  const ChoiceEnumData({
    required this.value,
    required this.title,
    this.css,
  });

  final String value;
  final String title;

  /// Bootstrap-style token: default, primary, secondary, success, warning, danger, info.
  final String? css;

  static ChoiceEnumData? parse(dynamic raw) {
    if (raw == null) return null;
    if (raw is Map) {
      final m = Map<String, dynamic>.from(raw);
      final v = m['value']?.toString() ?? '';
      final t = m['title']?.toString() ?? v;
      return ChoiceEnumData(
        value: v,
        title: t,
        css: m['css'] as String?,
      );
    }
    if (raw is String) {
      return ChoiceEnumData(value: raw, title: raw, css: null);
    }
    return null;
  }

  @override
  List<Object?> get props => [value, title, css];
}
