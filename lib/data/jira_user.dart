class JiraUser {
  final String accountId;
  final String displayName;
  final String emailAddress;
  final String avatarUrl;

  const JiraUser({
    required this.accountId,
    this.displayName = '',
    this.emailAddress = '',
    this.avatarUrl = '',
  });

  JiraUser.fromJson(Map<String, dynamic> json)
      : accountId = (json['accountId'] as String?) ?? '',
        displayName = (json['displayName'] as String?) ?? '',
        emailAddress = (json['emailAddress'] as String?) ?? '',
        avatarUrl = _avatar(json['avatarUrls']);

  static String _avatar(dynamic raw) {
    if (raw is! Map) return '';
    final map = raw.cast<String, dynamic>();
    return (map['48x48'] as String?) ??
        (map['32x32'] as String?) ??
        (map['24x24'] as String?) ??
        (map['16x16'] as String?) ??
        '';
  }
}
