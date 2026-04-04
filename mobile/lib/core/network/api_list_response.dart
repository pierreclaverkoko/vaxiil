/// Helpers for list-shaped API payloads.
///
/// Django REST Framework [page-number pagination](https://www.django-rest-framework.org/api-guide/pagination/#pagenumberpagination)
/// returns `{"count", "next", "previous", "results": [...]}`. Some endpoints
/// return a bare JSON array instead. These utilities accept both shapes.
library api_list_response;

/// Raw JSON list rows from a GET response body (DRF paginated or plain array).
List<dynamic> jsonListFromResponse(dynamic data) {
  if (data == null) return [];
  if (data is List) return List<dynamic>.from(data);
  if (data is Map) {
    final results = data['results'];
    if (results is List) return List<dynamic>.from(results);
  }
  return [];
}

Map<String, dynamic> _asJsonMap(Object? element) {
  if (element is Map<String, dynamic>) return element;
  if (element is Map) return Map<String, dynamic>.from(element);
  throw FormatException(
    'Expected JSON object in list, got ${element.runtimeType}',
  );
}

/// Parses [responseData] with [jsonListFromResponse] and maps each object with
/// [fromJson].
List<T> parseJsonList<T>(
  dynamic responseData,
  T Function(Map<String, dynamic> json) fromJson,
) {
  final rows = jsonListFromResponse(responseData);
  return rows.map((e) => fromJson(_asJsonMap(e))).toList();
}
