/// 肠安通 API 基址。开发：Android 模拟器用 10.0.2.2，真机用局域网 IP。
class ApiConfig {
  ApiConfig({required this.baseUrl});

  final String baseUrl;

  static const defaultBaseUrl = String.fromEnvironment(
    'IBD_API_BASE',
    defaultValue: 'http://10.0.2.2:3000',
  );

  factory ApiConfig.dev() => ApiConfig(baseUrl: defaultBaseUrl);

  Uri uri(String path, [Map<String, String>? query]) {
    final normalized = path.startsWith('/') ? path : '/$path';
    return Uri.parse(baseUrl).replace(
      path: normalized,
      queryParameters: query,
    );
  }
}
