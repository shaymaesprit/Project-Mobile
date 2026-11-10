/// Un PDF rattaché à un cours.
class CourseDocument {
  const CourseDocument({
    required this.id,
    required this.title,
    required this.createdAt,
    this.courseId,
    this.sizeBytes,
    this.pageCount,
    this.status = 'ready',
    this.textChunks = 0,
  });

  final String id;
  final String? courseId;
  final String title;
  final int? sizeBytes;
  final int? pageCount;
  final String status;

  /// Morceaux de texte extraits : 0 = PDF scanné (image), inutilisable par l'IA.
  final int textChunks;
  final DateTime createdAt;

  bool get hasText => textChunks > 0;

  String get sizeLabel {
    final bytes = sizeBytes;
    if (bytes == null) return '';
    if (bytes < 1024) return '$bytes o';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(0)} Ko';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1).replaceAll('.', ',')} Mo';
  }

  factory CourseDocument.fromJson(Map<String, dynamic> json) => CourseDocument(
        id: json['id'] as String,
        courseId: json['course_id'] as String?,
        title: json['title'] as String? ?? 'Document PDF',
        sizeBytes: (json['file_size_bytes'] as num?)?.toInt(),
        pageCount: (json['page_count'] as num?)?.toInt(),
        status: json['processing_status'] as String? ?? 'ready',
        textChunks: (json['text_chunks'] as num?)?.toInt() ?? 0,
        createdAt: DateTime.tryParse(json['created_at'] as String? ?? '')?.toLocal() ??
            DateTime.now(),
      );
}
