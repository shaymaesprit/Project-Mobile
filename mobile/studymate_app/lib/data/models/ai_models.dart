class AiConsent {
  const AiConsent({required this.granted, this.grantedAt});

  final bool granted;
  final DateTime? grantedAt;

  factory AiConsent.fromJson(Map<String, dynamic> json) => AiConsent(
        granted: json['granted'] == true,
        grantedAt: json['granted_at'] is String
            ? DateTime.tryParse(json['granted_at'] as String)
            : null,
      );
}

class AiRecommendation {
  const AiRecommendation({
    required this.id,
    required this.title,
    required this.description,
    required this.category,
    required this.priority,
    required this.status,
    required this.source,
    required this.aiGenerated,
    required this.notice,
    this.reason,
    this.suggestedAction,
  });

  final String id;
  final String title;
  final String description;
  final String category;
  final String priority;
  final String status;
  final String source;
  final bool aiGenerated;
  final String notice;
  final String? reason;
  final String? suggestedAction;

  bool get isPending => status == 'pending';

  factory AiRecommendation.fromJson(Map<String, dynamic> json) =>
      AiRecommendation(
        id: json['id'] as String,
        title: json['title'] as String,
        description: json['description'] as String,
        category: json['category'] as String? ?? 'other',
        priority: json['priority'] as String? ?? 'medium',
        status: json['status'] as String? ?? 'pending',
        source: json['source'] as String? ?? 'rules',
        aiGenerated: json['ai_generated'] == true,
        notice: json['notice'] as String? ?? '',
        reason: json['reason'] as String?,
        suggestedAction: json['suggested_action'] as String?,
      );
}

class AiInsight {
  const AiInsight({
    required this.id,
    required this.title,
    required this.body,
    required this.aiGenerated,
    required this.notice,
    this.generatedAt,
  });

  final String id;
  final String title;
  final String body;
  final bool aiGenerated;
  final String notice;
  final DateTime? generatedAt;

  factory AiInsight.fromJson(Map<String, dynamic> json) => AiInsight(
        id: json['id'] as String,
        title: json['title'] as String,
        body: json['body'] as String,
        aiGenerated: json['ai_generated'] == true,
        notice: json['notice'] as String? ?? '',
        generatedAt: json['generated_at'] is String
            ? DateTime.tryParse(json['generated_at'] as String)
            : null,
      );
}

/// Raw results of the explainable ML endpoints (M1-M4).
class MlOverview {
  const MlOverview({
    required this.profile,
    required this.behavior,
    required this.performance,
    required this.recommendations,
  });

  final Map<String, dynamic> profile;
  final Map<String, dynamic> behavior;
  final Map<String, dynamic> performance;
  final Map<String, dynamic> recommendations;

  bool get performanceAvailable => performance['status'] == 'ok';
  bool get behaviorAvailable => behavior['status'] == 'ok';
  bool get coldStart => recommendations['cold_start'] == true;

  List<String> stringList(Map<String, dynamic> source, String key) {
    final value = source[key];
    return value is List ? value.whereType<String>().toList() : const [];
  }
}
