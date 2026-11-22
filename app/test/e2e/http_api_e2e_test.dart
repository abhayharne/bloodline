@Timeout(Duration(minutes: 5))
library;

import 'dart:io';

import 'package:bloodline/core/api_client.dart';
import 'package:bloodline/core/models/user.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late Directory sandbox;
  Process? server;
  late String baseUrl;
  String? skipReason;
  try {
    Process.runSync('go', ['version']);
  } on ProcessException {
    skipReason =
        'Go is missing from PATH. Install Go to run the HTTP e2e tests.';
  }

  setUpAll(() async {
    sandbox = await Directory.systemTemp.createTemp('bloodline-e2e-');
    addTearDown(() async {
      server?.kill();
      await server?.exitCode;
      await sandbox.delete(recursive: true);
    });
    final binary = '${sandbox.path}/server';
    final result = await Process.run('go', [
      'build',
      '-o',
      binary,
      './cmd/server',
    ], workingDirectory: '../api');
    expect(result.exitCode, 0, reason: result.stderr.toString());

    final socket = await ServerSocket.bind(InternetAddress.loopbackIPv4, 0);
    final port = socket.port;
    await socket.close();
    baseUrl = 'http://127.0.0.1:$port';
    server = await Process.start(
      binary,
      [],
      workingDirectory: sandbox.path,
      environment: {
        'PORT': '$port',
        'DB_PATH': '${sandbox.path}/e2e.db',
        'JWT_SECRET': 'local-http-e2e-only',
        'NEXCONN_FAKE': '1',
        'DEV': '1',
        'DEMO_OTP': '123456',
        'MATCH_RADIUS_KM': '10',
        'FEATURES': '',
      },
    );
    server!.stdout.drain<void>();
    server!.stderr.drain<void>();
    final client = HttpApiClient(baseUrl: baseUrl);
    for (var attempt = 0; attempt < 100; attempt++) {
      if (await client.checkHealth()) return;
      await Future<void>.delayed(const Duration(milliseconds: 50));
    }
    fail('The isolated Go API did not become ready.');
  });

  test(
    'real HTTP profile and request lifecycle',
    () async {
      const phone = '+919900100001';
      const otp = '123456';
      final requester = HttpApiClient(baseUrl: baseUrl);
      final donor = HttpApiClient(baseUrl: baseUrl);
      expect((await requester.sendOtp(phone))['sent'], true);
      await expectLater(
        requester.verifyOtp(phone, otp),
        throwsA(isA<ApiException>().having((e) => e.statusCode, 'status', 404)),
      );
      final account = await requester.signup(
        name: 'E2E Requester',
        role: 'requester',
        phone: phone,
        otp: otp,
        bloodGroup: 'O+',
        lat: 21,
        lng: 79,
        sex: 'female',
        age: 28,
        weight: 70,
        height: 170,
        donatedBefore: true,
        lastDonationDate: DateTime(2025),
        consent: true,
      );
      expect(account.user.weight, 70.0);
      expect(account.user.height, 170.0);
      expect(account.user.lat, 21.0);
      expect(account.user.lng, 79.0);
      expect(
        (await requester.verifyOtp(phone, otp))['user']['id'],
        account.user.id,
      );
      final saved = await requester.updateMe({
        'weight_kg': 79,
        'height_cm': 171,
      });
      expect(User.fromJson(saved['user'] as Map<String, dynamic>).weight, 79.0);

      await donor.signup(
        name: 'E2E Donor',
        role: 'donor',
        phone: '+919900100002',
        otp: otp,
        bloodGroup: 'O+',
        lat: 21,
        lng: 79,
      );
      const urgencies = {
        'low': 'low',
        'medium': 'medium',
        'high': 'high',
        'critical': 'critical',
        'planned': 'low',
        'med': 'medium',
        'urgent': 'high',
      };
      final ids = <String>[];
      for (final urgency in urgencies.entries) {
        final response = await requester.createRequest(
          bloodGroup: 'O+',
          units: 2,
          hospital: 'E2E Hospital',
          urgency: urgency.key,
          lat: 21,
          lng: 79,
          component: 'whole_blood',
        );
        expect(response.request.urgency, urgency.value);
        ids.add(response.request.id);
      }
      expect(
        (await requester.getRequests()).map((r) => r.id),
        unorderedEquals(ids),
      );
      final id = ids.first;
      expect(await donor.acceptRequest(id), 'req$id');
      expect(
        (await donor.getRequests()).singleWhere((r) => r.id == id).joined,
        true,
      );
      expect((await donor.recordDonation(id))['donation_count'], 1);
      await expectLater(
        requester.recordDonation(id),
        throwsA(
          isA<ApiException>()
              .having((e) => e.statusCode, 'status', 403)
              .having((e) => e.message, 'message', 'role not allowed'),
        ),
      );
      expect((await requester.fulfillRequest(id)).isFulfilled, true);
    },
    skip: skipReason,
    timeout: const Timeout(Duration(minutes: 3)),
  );

  test('real HTTP accepts the component sent by the broadcast form', () async {
    final requester = HttpApiClient(baseUrl: baseUrl);
    await requester.signup(
      name: 'E2E Broadcast',
      role: 'requester',
      phone: '+919900100003',
      bloodGroup: 'O+',
      lat: 21,
      lng: 79,
    );
    final created = await requester.createRequest(
      bloodGroup: 'O+',
      units: 2,
      hospital: 'E2E Broadcast Hospital',
      urgency: 'critical',
      lat: 21,
      lng: 79,
      component: 'Whole blood',
    );
    expect((await requester.getRequests()).single.id, created.request.id);
  }, skip: skipReason);
}
