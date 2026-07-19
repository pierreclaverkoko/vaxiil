import 'package:flutter_test/flutter_test.dart';
import 'package:vaxiil_mobile/features/business/data/organization_models.dart';
import 'package:vaxiil_mobile/shared/models/choice_enum_data.dart';

void main() {
  group('OrganizationModel.isVerified', () {
    test('is true when verification_status value is V', () {
      final o = OrganizationModel(
        id: '1',
        name: 'Test',
        typeId: 't',
        email: 'a@b.c',
        address: '',
        city: '',
        postalCode: '',
        country: '',
        verificationStatus: const ChoiceEnumData(
          value: 'V',
          title: 'Verified',
          css: 'success',
        ),
      );
      expect(o.isVerified, isTrue);
    });

    test('is false when verification_status is not V', () {
      final o = OrganizationModel(
        id: '1',
        name: 'Test',
        typeId: 't',
        email: 'a@b.c',
        address: '',
        city: '',
        postalCode: '',
        country: '',
        verificationStatus: const ChoiceEnumData(
          value: 'P',
          title: 'Pending',
          css: 'warning',
        ),
      );
      expect(o.isVerified, isFalse);
    });

    test('is false when verification_status is null', () {
      final o = OrganizationModel(
        id: '1',
        name: 'Test',
        typeId: 't',
        email: 'a@b.c',
        address: '',
        city: '',
        postalCode: '',
        country: '',
      );
      expect(o.isVerified, isFalse);
    });
  });

  group('OrganizationMineSummaryModel', () {
    test('fromJson maps mine-summary payload', () {
      final m = OrganizationMineSummaryModel.fromJson({
        'organization_count': 3,
        'collective_beneficiaries': 14200,
      });
      expect(m.organizationCount, 3);
      expect(m.collectiveBeneficiaries, 14200);
    });
  });

  group('OrganizationModel.fromJson', () {
    test('parses latitude, longitude, and updated_at', () {
      final o = OrganizationModel.fromJson({
        'id': 'a1b2c3d4-e5f6-7890-abcd-ef1234567890',
        'name': 'Co',
        'type': 't1',
        'email': 'a@b.c',
        'address': '1 St',
        'city': 'Town',
        'postal_code': '12345',
        'country': {'id': 'c1', 'name': 'United States', 'iso_code2': 'US'},
        'latitude': '45.52306',
        'longitude': '-122.67648',
        'updated_at': '2026-04-15T12:00:00Z',
        'require_client_name': false,
      });
      expect(o.latitude, closeTo(45.52306, 0.0001));
      expect(o.longitude, closeTo(-122.67648, 0.0001));
      expect(o.updatedAt?.toUtc().year, 2026);
      expect(o.requireClientName, isFalse);
    });

    test('parses platform_fees read-only object', () {
      final o = OrganizationModel.fromJson({
        'id': 'o1',
        'name': 'Co',
        'type': 't1',
        'email': 'a@b.c',
        'address': '1 St',
        'city': 'Town',
        'postal_code': '12345',
        'country': {'id': 'c1', 'name': 'United States', 'iso_code2': 'US'},
        'platform_fees': {
          'platform_fee_rate': '1.50',
          'platform_fee_payer': {
            'value': 'C',
            'title': 'Client',
            'css': 'info',
          },
          'platform_fee_source': {
            'value': 'O',
            'title': 'Organization',
            'css': 'primary',
          },
          'has_organization_override': true,
          'note': 'Category-specific rates may apply.',
        },
      });
      expect(o.platformFees?.platformFeeRate, '1.50');
      expect(o.platformFees?.platformFeePayer?.value, 'C');
      expect(o.platformFees?.hasOrganizationOverride, isTrue);
    });
  });

  group('OrganizationAnalyticsModel', () {
    test('parses gross, platform, and net revenue', () {
      final analytics = OrganizationAnalyticsModel.fromJson({
        'organization_id': 'o1',
        'total_bookings': 10,
        'confirmed_bookings': 3,
        'completed_bookings': 5,
        'cancelled_bookings': 2,
        'revenue': '120.00',
        'gross_revenue': '120.00',
        'platform_fees': '2.40',
        'net_revenue': '117.60',
        'currency': 'USD',
      });
      expect(analytics.grossRevenue, '120.00');
      expect(analytics.platformFees, '2.40');
      expect(analytics.netRevenue, '117.60');
    });

    test('parses live booking aggregates', () {
      final analytics = OrganizationAnalyticsModel.fromJson({
        'organization_id': 'o1',
        'total_bookings': 10,
        'confirmed_bookings': 3,
        'completed_bookings': 5,
        'cancelled_bookings': 2,
        'revenue': '120.00',
        'currency': 'USD',
      });
      expect(analytics.confirmedBookings, 3);
      expect(analytics.completedBookings, 5);
      expect(analytics.cancelledBookings, 2);
    });
  });

  group('OrganizationDiscoveryModel', () {
    test('fromJson maps discovery payload', () {
      final m = OrganizationDiscoveryModel.fromJson({
        'id': 'a1b2c3d4-e5f6-7890-abcd-ef1234567890',
        'name': 'The Sage Sanctuary',
        'description': 'Holistic Therapy',
        'city': 'Brooklyn',
        'logo': 'https://example.com/logo.png',
      });
      expect(m.name, 'The Sage Sanctuary');
      expect(m.city, 'Brooklyn');
      expect(m.description, 'Holistic Therapy');
      expect(m.logoUrl, 'https://example.com/logo.png');
    });
  });
}
