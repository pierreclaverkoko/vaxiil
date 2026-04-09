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
