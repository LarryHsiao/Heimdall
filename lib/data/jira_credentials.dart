class JiraCredentials {
  final String baseUrl;
  final String email;
  final String apiToken;

  const JiraCredentials({
    required this.baseUrl,
    required this.email,
    required this.apiToken,
  });

  Map<String, dynamic> toJson() => {
        'baseUrl': baseUrl,
        'email': email,
        'apiToken': apiToken,
      };

  factory JiraCredentials.fromJson(Map<String, dynamic> json) =>
      JiraCredentials(
        baseUrl: json['baseUrl'] as String,
        email: json['email'] as String,
        apiToken: json['apiToken'] as String,
      );
}
