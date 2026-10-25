class QuickChatPhrase {
  const QuickChatPhrase({required this.id, required this.en, required this.ar});
  final String id, en, ar;
  String label(String language) => language == 'ar' ? ar : en;
  factory QuickChatPhrase.fromJson(Map<String, dynamic> json) =>
      QuickChatPhrase(
        id: json['id'] as String,
        en: json['en'] as String,
        ar: json['ar'] as String,
      );
}

class QuickChatCatalog {
  const QuickChatCatalog({this.revision = 0, this.items = const []});
  final int revision;
  final List<QuickChatPhrase> items;
  factory QuickChatCatalog.fromJson(Map<String, dynamic> json) =>
      QuickChatCatalog(
        revision: json['revision'] as int? ?? 0,
        items: (json['items'] as List? ?? const [])
            .map(
              (e) =>
                  QuickChatPhrase.fromJson(Map<String, dynamic>.from(e as Map)),
            )
            .toList(),
      );
}

class TableChatPolicy {
  const TableChatPolicy({
    this.canType = false,
    this.available = false,
    this.catalog = const QuickChatCatalog(),
  });
  final bool canType, available;
  final QuickChatCatalog catalog;
  factory TableChatPolicy.fromJson(Map<String, dynamic> json) =>
      TableChatPolicy(
        canType: json['canType'] == true,
        available: true,
        catalog: QuickChatCatalog.fromJson(json),
      );
}
