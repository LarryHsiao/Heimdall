class JiraAttachment {
  final String id;
  final String filename;
  final String mimeType;
  final String contentUrl;
  final String thumbnailUrl;
  final int size;

  const JiraAttachment({
    required this.id,
    this.filename = '',
    this.mimeType = '',
    this.contentUrl = '',
    this.thumbnailUrl = '',
    this.size = 0,
  });

  JiraAttachment.fromJson(Map<String, dynamic> json)
      : id = (json['id'] as String?) ?? '',
        filename = (json['filename'] as String?) ?? '',
        mimeType = (json['mimeType'] as String?) ?? '',
        contentUrl = (json['content'] as String?) ?? '',
        thumbnailUrl = (json['thumbnail'] as String?) ?? '',
        size = (json['size'] as int?) ?? 0;

  bool get isImage => mimeType.startsWith('image/');
}
