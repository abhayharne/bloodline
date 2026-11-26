import 'dart:async';
import 'dart:convert';

import 'package:bloodline/core/api_client.dart';
import 'package:bloodline/core/models/user.dart';
import 'package:bloodline/core/providers/auth_provider.dart';
import 'package:bloodline/core/providers/connection_provider.dart';
import 'package:bloodline/features/auth/connection_gate.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

const user = User(id: 'udemo', name: 'Demo donor', role: 'donor');

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('a hosting wake-up HTML page does not count as a healthy API', () async {
    final api = HttpApiClient(httpClient: MockClient(
      (_) async => http.Response('<html>Starting service</html>', 200),
    ));
    expect(await api.checkHealth(), isFalse);
  });

  test(
    'sleeping service retries health GETs without replaying actions',
    () async {
      final requests = <http.Request>[];
      final api = HttpApiClient(
        httpClient: MockClient((request) async {
          requests.add(request);
          return http.Response(
            requests.length < 3 ? 'Starting' : '{"status":"ok"}',
            requests.length < 3 ? 503 : 200,
          );
        }),
      );
      final connection = ConnectionProvider(
        apiClient: api,
        retryInterval: const Duration(milliseconds: 1),
      );
      addTearDown(connection.dispose);
      await Future.wait([connection.connect(), connection.connect()]);
      expect(connection.ready, isTrue);
      expect(connection.connecting, isFalse);
      expect(requests, hasLength(3));
      expect(
        requests.every((r) => r.method == 'GET' && r.url.path == '/health'),
        isTrue,
      );
      await connection.connect();
      expect(requests, hasLength(3));
    },
  );

  test('hung health request reaches deadline and can be retried', () async {
    var healthy = false;
    final pending = Completer<http.Response>();
    final api = HttpApiClient(
      httpClient: MockClient(
        (_) async =>
            healthy ? http.Response('{"status":"ok"}', 200) : pending.future,
      ),
    );
    final connection = ConnectionProvider(
      apiClient: api,
      maxWait: const Duration(milliseconds: 30),
      retryInterval: const Duration(milliseconds: 1),
    );
    addTearDown(connection.dispose);
    await connection.connect();
    expect(connection.ready, isFalse);
    expect(connection.connecting, isFalse);
    healthy = true;
    await connection.connect();
    expect(connection.ready, isTrue);
    pending.complete(http.Response('Starting', 503));
  });

  test('disposing during health check does not notify or start app', () async {
    final pending = Completer<http.Response>();
    final connection = ConnectionProvider(
      apiClient: HttpApiClient(httpClient: MockClient((_) => pending.future)),
    );
    final work = connection.connect();
    connection.dispose();
    pending.complete(http.Response('{"status":"ok"}', 200));
    await work;
    expect(connection.ready, isFalse);
  });

  for (final status in [401, 404]) {
    test('profile $status clears saved session after reset', () async {
      SharedPreferences.setMockInitialValues({
        'bloodline_user_v1': jsonEncode(user.toJson()),
        'bloodline_jwt_token_v1': 'old-token',
      });
      final api = HttpApiClient(
        httpClient: MockClient((r) async {
          expect(r.url.path, '/me');
          return http.Response('{"error":"user not found"}', status);
        }),
      );
      final auth = AuthProvider(apiClient: api);
      addTearDown(auth.dispose);
      await auth.init();
      expect(auth.isAuthenticated, isFalse);
      expect(auth.isRestoring, isFalse);
      expect(api.authToken, isNull);
      expect(
        auth.sessionNotice,
        contains(status == 404 ? 'register again' : 'sign in again'),
      );
      final prefs = await SharedPreferences.getInstance();
      for (final key in [
        'bloodline_user_v1',
        'bloodline_jwt_token_v1',
        'bloodline_nexconn_token_v1',
      ]) {
        expect(prefs.getString(key), isNull);
      }
    });
  }

  test('temporary profile failure preserves saved session', () async {
    SharedPreferences.setMockInitialValues({
      'bloodline_user_v1': jsonEncode(user.toJson()),
      'bloodline_jwt_token_v1': 'valid-token',
    });
    final auth = AuthProvider(
      apiClient: HttpApiClient(
        httpClient: MockClient(
          (_) async =>
              http.Response('{"error":"temporarily unavailable"}', 503),
        ),
      ),
    );
    addTearDown(auth.dispose);
    await auth.init();
    expect(auth.isAuthenticated, isTrue);
    expect(auth.sessionNotice, isNull);
  });

  test('delayed old-session failure preserves newer login', () async {
    final pending = Completer<http.Response>();
    final auth = AuthProvider(
      apiClient: HttpApiClient(httpClient: MockClient((_) => pending.future)),
    );
    addTearDown(auth.dispose);
    auth.setCurrentUserForTesting(user, token: 'old-token');
    final work = auth.fetchMe();
    auth.setCurrentUserForTesting(user, token: 'new-token');
    pending.complete(http.Response('{"error":"user not found"}', 404));
    await work;
    expect(auth.token, 'new-token');
    expect(auth.sessionNotice, isNull);
  });

  testWidgets('startup shows progress then opens app', (tester) async {
    final pending = Completer<http.Response>();
    final api = HttpApiClient(httpClient: MockClient((_) => pending.future));
    var prepared = 0;
    await tester.pumpWidget(
      ConnectionGate(
        apiClient: api,
        prepareApp: () async {
          prepared++;
          return const MaterialApp(home: Scaffold(body: Text('Connected app')));
        },
      ),
    );
    expect(find.text('Connecting to BloodLine'), findsOneWidget);
    expect(find.byType(LinearProgressIndicator), findsOneWidget);
    expect(prepared, 0);
    pending.complete(http.Response('{"status":"ok"}', 200));
    await tester.pumpAndSettle();
    expect(find.text('Connected app'), findsOneWidget);
    expect(prepared, 1);
  });

  testWidgets('failed app preparation offers working retry', (tester) async {
    var attempts = 0;
    await tester.pumpWidget(
      ConnectionGate(
        apiClient: MockApiClient(),
        prepareApp: () async {
          if (++attempts == 1) throw StateError('Native initialization failed');
          return const MaterialApp(home: Scaffold(body: Text('Connected app')));
        },
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Try again'), findsOneWidget);
    await tester.tap(find.text('Try again'));
    await tester.pumpAndSettle();
    expect(find.text('Connected app'), findsOneWidget);
    expect(attempts, 2);
  });

  testWidgets('unavailable service offers recovery without starting app', (
    tester,
  ) async {
    final api = MockApiClient();
    final connection = ConnectionProvider(
      apiClient: api,
      maxWait: Duration.zero,
    );
    addTearDown(connection.dispose);
    await tester.pumpWidget(
      ConnectionGate(
        apiClient: api,
        connection: connection,
        prepareApp: () async => throw StateError('Must not run'),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Unable to connect'), findsOneWidget);
    expect(find.text('Try again'), findsOneWidget);
    expect(find.byType(LinearProgressIndicator), findsNothing);
  });
}
