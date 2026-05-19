class MentionRange {
  final String accountId;
  final String displayName;
  final int start;
  final int length;

  const MentionRange({
    required this.accountId,
    required this.displayName,
    required this.start,
    required this.length,
  });

  int get end => start + length;
}
