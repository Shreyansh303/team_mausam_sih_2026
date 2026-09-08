import 'package:dio/dio.dart';

import '../core/config.dart';

/// Normalised failure surfaced to repositories/UI. docs/04 preamble defines the error body as
/// `{"error": {"code", "message"}}`.
class ApiException implements Exception {
  ApiException(this.message, {this.code, this.statusCode, this.isNetwork = false});

  final String message;
  final String? code;
  final int? statusCode;
  final bool isNetwork;

  bool get isAuth => statusCode == 401;

  @override
  String toString() => 'ApiException($statusCode $code): $message';
}

/// docs/06_MOBILE_SPEC.md §Layout `data/api_client.dart` —
/// Dio + auth interceptor + lang header + error mapping.
class ApiClient {
  ApiClient({Dio? dio, String? baseUrl})
      : _dio = dio ?? Dio(),
        _baseUrl = baseUrl ?? AppConfig.defaultBackendUrl {
    _dio.options
      ..connectTimeout = AppConfig.connectTimeout
      ..receiveTimeout = AppConfig.receiveTimeout
      ..responseType = ResponseType.json
      ..headers['Accept'] = 'application/json';
    _dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) {
          final t = token;
          if (t != null && t.isNotEmpty) {
            options.headers['Authorization'] = 'Bearer $t';
          }
          // docs/04: language via `?lang=` or Accept-Language. We send both so a backend
          // that honours only one of them still gets it.
          options.headers['Accept-Language'] = lang;
          options.queryParameters = <String, dynamic>{
            'lang': lang,
            ...options.queryParameters,
          };
          handler.next(options);
        },
      ),
    );
  }

  final Dio _dio;
  String _baseUrl;

  /// Bearer token from `POST /auth/guest` / `POST /auth/verify-otp`.
  String? token;

  /// Sent as both `?lang=` and `Accept-Language` (docs/04 preamble).
  String lang = 'en';

  String get baseUrl => _baseUrl;

  set baseUrl(String value) => _baseUrl = _normalizeBase(value);

  static String _normalizeBase(String value) {
    var v = value.trim();
    while (v.endsWith('/')) {
      v = v.substring(0, v.length - 1);
    }
    return v;
  }

  /// `{BACKEND}/api/v1{path}` (docs/04 base URL).
  String url(String path) =>
      '${_normalizeBase(_baseUrl)}${AppConfig.apiPrefix}${path.startsWith('/') ? path : '/$path'}';

  Future<Map<String, dynamic>> getJson(
    String path, {
    Map<String, dynamic>? query,
    CancelToken? cancelToken,
  }) async {
    final res = await _send(() => _dio.get<dynamic>(
          url(path),
          queryParameters: _clean(query),
          cancelToken: cancelToken,
        ));
    return _asMap(res.data);
  }

  Future<List<dynamic>> getList(
    String path, {
    Map<String, dynamic>? query,
    CancelToken? cancelToken,
  }) async {
    final res = await _send(() => _dio.get<dynamic>(
          url(path),
          queryParameters: _clean(query),
          cancelToken: cancelToken,
        ));
    final data = res.data;
    return data is List ? data : const <dynamic>[];
  }

  Future<Map<String, dynamic>> postJson(
    String path, {
    Object? body,
    Map<String, dynamic>? query,
    CancelToken? cancelToken,
  }) async {
    final res = await _send(() => _dio.post<dynamic>(
          url(path),
          data: body,
          queryParameters: _clean(query),
          cancelToken: cancelToken,
        ));
    return _asMap(res.data);
  }

  Future<Map<String, dynamic>> putJson(
    String path, {
    Object? body,
    CancelToken? cancelToken,
  }) async {
    final res = await _send(() => _dio.put<dynamic>(
          url(path),
          data: body,
          cancelToken: cancelToken,
        ));
    return _asMap(res.data);
  }

  Future<Map<String, dynamic>> deleteJson(
    String path, {
    Map<String, dynamic>? query,
    CancelToken? cancelToken,
  }) async {
    final res = await _send(() => _dio.delete<dynamic>(
          url(path),
          queryParameters: _clean(query),
          cancelToken: cancelToken,
        ));
    return _asMap(res.data);
  }

  Future<Response<dynamic>> _send(Future<Response<dynamic>> Function() run) async {
    try {
      return await run();
    } on DioException catch (e) {
      throw _map(e);
    }
  }

  static Map<String, dynamic> _asMap(Object? data) {
    if (data is Map) return Map<String, dynamic>.from(data);
    return <String, dynamic>{};
  }

  static Map<String, dynamic>? _clean(Map<String, dynamic>? query) {
    if (query == null) return null;
    final out = <String, dynamic>{};
    query.forEach((k, v) {
      if (v != null) out[k] = v;
    });
    return out;
  }

  static ApiException _map(DioException e) {
    switch (e.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
        return ApiException('The backend did not respond in time.',
            code: 'timeout', isNetwork: true);
      case DioExceptionType.connectionError:
      case DioExceptionType.unknown:
        return ApiException('Cannot reach the backend.',
            code: 'unreachable', isNetwork: true);
      case DioExceptionType.cancel:
        return ApiException('Request cancelled.', code: 'cancelled');
      case DioExceptionType.badCertificate:
        return ApiException('TLS certificate rejected.', code: 'bad_certificate');
      case DioExceptionType.badResponse:
        final status = e.response?.statusCode;
        final body = e.response?.data;
        String? code;
        String? message;
        if (body is Map && body['error'] is Map) {
          final err = Map<String, dynamic>.from(body['error'] as Map);
          code = err['code']?.toString();
          message = err['message']?.toString();
        }
        return ApiException(
          message ?? 'Backend returned HTTP $status.',
          code: code ?? 'http_$status',
          statusCode: status,
        );
      // `transformTimeout`, and anything Dio adds in a future minor: a client-side stall,
      // so it behaves like the other timeouts rather than a server error.
      default:
        return ApiException('The request could not be completed.',
            code: e.type.name, isNetwork: true);
    }
  }
}
