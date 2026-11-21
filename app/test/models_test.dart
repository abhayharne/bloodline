import 'package:flutter_test/flutter_test.dart';
import 'package:bloodline/core/models/user.dart';
import 'package:bloodline/core/models/auth_response.dart';
import 'package:bloodline/core/models/blood_request.dart';
import 'package:bloodline/core/models/blood_request_response.dart';
import 'package:bloodline/core/models/blood_stock.dart';
import 'package:bloodline/core/models/app_config.dart';

void main() {
  group('JSON Models Ignore Unknown Fields', () {
    test('User.fromJson safely ignores unknown fields', () {
      final json = {
        'id': 'u100',
        'name': 'Test User',
        'role': 'donor',
        'blood_group': 'O+',
        'lat': 21.1458,
        'lng': 79.0882,
        'phone': '+919999999999',
        'age': 25,
        'weight': 65.5,
        'height': 175.0,
        'sex': 'male',
        'donated_before': true,
        // Unknown fields from backend
        'unexpected_backend_token': 'secret123',
        'reputation_score': 99.4,
        'nested_metadata': {'a': 1, 'b': 2},
      };

      final user = User.fromJson(json);
      expect(user.id, 'u100');
      expect(user.name, 'Test User');
      expect(user.role, 'donor');
      expect(user.bloodGroup, 'O+');
      expect(user.age, 25);
      expect(user.donatedBefore, isTrue);
    });

    test('AuthResponse.fromJson safely ignores unknown fields', () {
      final json = {
        'user': {
          'id': 'u101',
          'name': 'Asha',
          'role': 'donor',
          'blood_group': 'O+',
          'extra_field': 'ignore_me',
        },
        'token': 'jwt_abc_123',
        'nexconn_token': 'chat_xyz_456',
        'server_timestamp': 1718000000,
        'rate_limit': 100,
      };

      final auth = AuthResponse.fromJson(json);
      expect(auth.user.name, 'Asha');
      expect(auth.token, 'jwt_abc_123');
      expect(auth.nexconnToken, 'chat_xyz_456');
    });

    test('BloodRequest.fromJson safely ignores unknown fields', () {
      final json = {
        'id': 'r99',
        'blood_group': 'O-',
        'units': 2,
        'hospital': 'City Hospital',
        'urgency': 'critical',
        'status': 'open',
        'channel_id': 'reqr99',
        'distance_km': 3.2,
        'requester_name': 'Ravi',
        'joined': false,
        // Extra unknown fields
        'hospital_accreditation': 'NABH',
        'doctor_notes': 'Urgent requirement',
        'priority_score': 9.8,
      };

      final req = BloodRequest.fromJson(json);
      expect(req.id, 'r99');
      expect(req.bloodGroup, 'O-');
      expect(req.units, 2);
      expect(req.hospital, 'City Hospital');
      expect(req.urgency, 'critical');
      expect(req.channelId, 'reqr99');
      expect(req.isOpen, isTrue);
      expect(req.isFulfilled, isFalse);
    });

    test('BloodRequestResponse.fromJson safely ignores unknown fields', () {
      final json = {
        'request': {
          'id': 'r10',
          'blood_group': 'A+',
          'units': 1,
          'hospital': 'Metro Hospital',
          'urgency': 'high',
          'status': 'open',
          'channel_id': 'reqr10',
        },
        'matches': {
          'banks': 2,
          'donors': 5,
          'extra_match_field': 99,
        },
        'broadcast_id': 'b123',
      };

      final resp = BloodRequestResponse.fromJson(json);
      expect(resp.request.id, 'r10');
      expect(resp.matches.banks, 2);
      expect(resp.matches.donors, 5);
    });

    test('BloodStockItem.fromJson safely ignores unknown fields', () {
      final json = {
        'blood_group': 'AB+',
        'units': 7,
        'last_audited_by': 'Admin',
        'storage_fridge_id': 'F12',
      };

      final stock = BloodStockItem.fromJson(json);
      expect(stock.bloodGroup, 'AB+');
      expect(stock.units, 7);
    });

    test('AppConfig.fromJson safely ignores unknown fields', () {
      final json = {
        'app_name': 'BloodLine Live',
        'enable_ai_summary': true,
        'enable_in_app_banner': true,
        'default_match_radius_km': 15.0,
        'features': {'voice_call': false},
        'experimental_backend_mode': true,
      };

      final config = AppConfig.fromJson(json);
      expect(config.appName, 'BloodLine Live');
      expect(config.enableAiSummary, isTrue);
      expect(config.defaultMatchRadiusKm, 15.0);
    });
  });
}
