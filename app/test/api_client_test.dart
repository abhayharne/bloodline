import 'package:flutter_test/flutter_test.dart';
import 'package:bloodline/core/api_client.dart';

void main() {
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
  });
}
