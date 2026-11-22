import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:bloodline/core/models/blood_request.dart';
import 'package:bloodline/core/providers/bank_stock_provider.dart';
import 'package:bloodline/core/providers/requests_provider.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:bloodline/core/api_client.dart';
import 'package:bloodline/core/features.dart';
import 'package:bloodline/core/slots.dart';
import 'package:bloodline/core/providers/notifications_provider.dart';

void main() {
  test('stock editor reads and saves only whole blood', () async {
    final api = HttpApiClient(httpClient: MockClient((request) async {
      if (request.method == 'PUT') {
        final rows = jsonDecode(request.body)['stock'] as List;
        expect(rows, hasLength(8));
        expect(rows.every((row) => row['component'] == 'whole_blood'), isTrue);
        expect(rows.singleWhere((row) => row['blood_group'] == 'O+')['units'], 4);
      }
      return http.Response(jsonEncode({
        'stock': [
          {'blood_group': 'O+', 'component': 'whole_blood', 'units': 4},
          {'blood_group': 'O+', 'component': 'plasma', 'units': 9},
        ],
      }), 200);
    }));
    final provider = BankStockProvider(apiClient: api);
    addTearDown(provider.dispose);

    await provider.loadStock();
    expect(provider.stock.singleWhere((row) => row.bloodGroup == 'O+').units, 4);
    expect(await provider.saveStock(), isTrue);
    expect(provider.stock, hasLength(8));
    expect(provider.stock.singleWhere((row) => row.bloodGroup == 'O+').units, 4);
  });

  test('reset discards an in-flight request feed from the previous session', () async {
    final api = _PendingRequestsApi();
    final provider = RequestsProvider(apiClient: api);
    addTearDown(provider.dispose);
    final load = provider.loadRequests();
    provider.reset();
    api.pending.complete(await MockApiClient().getRequests());
    await load;
    expect(provider.requests, isEmpty);
  });

  test('live hospital lookup surfaces HTTP failures', () async {
    final api = HttpApiClient(httpClient: MockClient(
      (_) async => http.Response('{"error":"directory unavailable"}', 503),
    ));
    await expectLater(
      api.getHospitals(),
      throwsA(isA<ApiException>().having((e) => e.statusCode, 'status', 503)),
    );
  });

  test('HTTP logs status and bounded errors without bearer tokens or OTPs', () async {
    final logs = <String>[];
    final previousPrint = debugPrint;
    debugPrint = (message, {wrapWidth}) => logs.add(message ?? '');
    addTearDown(() => debugPrint = previousPrint);

    const token = 'opaque-test-token';
    const otp = '879013';
    final api = HttpApiClient(authToken: token, httpClient: MockClient((request) async {
      if (request.url.path == '/auth/verify') {
        return http.Response(jsonEncode({'error': 'rejected $otp'}), 401);
      }
      return http.Response(jsonEncode({'error': 'Bearer $token $otp ${'a' * 400}'}), 403);
    }));
    await expectLater(api.verifyOtp('+919900000001', otp), throwsA(isA<ApiException>()));
    await expectLater(api.recordDonation('r1'), throwsA(isA<ApiException>()));

    expect(logs, hasLength(2));
    expect(logs.first, startsWith('[HTTP] POST /auth/verify 401 '));
    const prefix = '[HTTP] POST /requests/r1/donated 403 ';
    expect(logs.last, startsWith(prefix));
    expect(logs.last.length, prefix.length + 300);
    expect(logs.join(), isNot(contains(token)));
    expect(logs.join(), isNot(contains(otp)));
  });

  group('ApiClient Factory & Architecture', () {
    test('Factory creates MockApiClient when mockMode is true', () {
      final client = ApiClient(mockMode: true);
      expect(client, isA<MockApiClient>());
      expect(client.mockMode, isTrue);
    });

    test('Factory creates HttpApiClient when mockMode is false', () {
      final client = ApiClient(mockMode: false);
      expect(client, isA<HttpApiClient>());
      expect(client.mockMode, isFalse);
    });

    test('HttpApiClient respects configurable baseUrl and authToken', () {
      final client = HttpApiClient(
        baseUrl: 'http://api.bloodline.local:8080',
        authToken: 'jwt_sample_123',
      );
      expect(client.baseUrl, 'http://api.bloodline.local:8080');
      expect(client.authToken, 'jwt_sample_123');
    });

    test('Features.load correctly fetches and queries config features', () async {
      final client = MockApiClient();
      final features = await Features.load(client);
      expect(features.hasRanks, isTrue);
      expect(features.hasReminders, isTrue);
      expect(features.isEnabled('ranks'), isTrue);
      expect(features.isEnabled('unknown_feature'), isFalse);
      expect(features.demoMode, isTrue);
    });

    test('SlotRegistry works from slots.dart export', () {
      SlotRegistry.instance.clear();
      expect(SlotRegistry.instance.homeCards, isEmpty);
      expect(SlotRegistry.instance.profileSections, isEmpty);
      expect(SlotRegistry.instance.roomHeaderBadges, isEmpty);
    });
  });

  group('ApiClient Mock Mode', () {
    late ApiClient client;

    setUp(() {
      client = ApiClient(mockMode: true);
    });

    test('Mock login returns valid AuthResponse', () async {
      final resp = await client.login(name: 'Asha', role: 'donor');
      expect(resp.user.name, 'Asha');
      expect(resp.user.role, 'donor');
      expect(resp.token, isNotEmpty);
      expect(resp.nexconnToken, isNotEmpty);
      expect(client.authToken, resp.token);
    });

    test('Mock signup creates user and generates tokens', () async {
      final resp = await client.signup(
        name: 'Ravi',
        role: 'requester',
        bloodGroup: 'O-',
        lat: 21.1458,
        lng: 79.0882,
        phone: '+91 98765 00000',
        age: 30,
        weight: 72.0,
        height: 178.0,
        sex: 'male',
        donatedBefore: false,
      );

      expect(resp.user.name, 'Ravi');
      expect(resp.user.role, 'requester');
      expect(resp.user.bloodGroup, 'O-');
      expect(resp.user.age, 30);
      expect(resp.user.donatedBefore, isFalse);
    });

    test('Mock bank stock retrieval and update for 8 blood groups', () async {
      final stock = await client.getStock();
      expect(stock.length, 8);

      final updated = stock.map((s) {
        if (s.bloodGroup == 'O+') return s.copyWith(units: 25);
        return s;
      }).toList();

      final saved = await client.updateStock(updated);
      final oPlus = saved.firstWhere((s) => s.bloodGroup == 'O+');
      expect(oPlus.units, 25);
    });

    test('Mock blood request creation, listing, acceptance, and fulfillment', () async {
      final created = await client.createRequest(
        bloodGroup: 'B+',
        units: 2,
        hospital: 'Central Hospital',
        urgency: 'critical',
        lat: 21.1400,
        lng: 79.0800,
      );

      expect(created.request.bloodGroup, 'B+');
      expect(created.request.units, 2);
      expect(created.request.hospital, 'Central Hospital');
      expect(created.request.status, 'open');
      expect(created.matches.banks, greaterThan(0));

      final requests = await client.getRequests(status: 'open');
      expect(requests.any((r) => r.id == created.request.id), isTrue);

      // Accept request
      final channelId = await client.acceptRequest(created.request.id);
      expect(channelId, created.request.channelId);

      // Fulfill request
      final fulfilled = await client.fulfillRequest(created.request.id);
      expect(fulfilled.status, 'fulfilled');
      expect(fulfilled.isFulfilled, isTrue);
    });

    test('Notifications API and NotificationsProvider polling', () async {
      MockApiClient.resetMockNotifications();
      final notifications = await client.getNotifications();
      expect(notifications.length, 3);
      expect(notifications.first['id'], 'n1');
      expect(notifications.first['title'], 'Ready to save lives again?');
      expect(notifications.first['read'], isFalse);

      final provider = NotificationsProvider(apiClient: client);
      await provider.fetchNotifications();
      expect(provider.notifications.length, 3);
      expect(provider.unreadCount, 2);
      expect(provider.hasUnread, isTrue);
      expect(provider.activeBanner?.title, 'Ready to save lives again?');

      // Dismiss banner
      provider.dismissBanner();
      expect(provider.activeBanner, isNull);

      // Mark read
      await provider.markAsRead('n1');
      expect(provider.unreadCount, 1);
      await provider.markAllAsRead();
      expect(provider.unreadCount, 0);
      expect(provider.hasUnread, isFalse);

      provider.dispose();
    });
  });
}


class _PendingRequestsApi extends MockApiClient {
  final pending = Completer<List<BloodRequest>>();

  @override
  Future<List<BloodRequest>> getRequests({String status = 'open'}) {
    return pending.future;
  }
}
