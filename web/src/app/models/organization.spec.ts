import {
  parseOrganization,
  teamMemberDisplayName,
  parseTeamMember,
  parseCityBrief,
  parseCountryBrief,
} from './organization';

describe('organization parsers', () => {
  it('parses country brief with flag', () => {
    const country = parseCountryBrief({
      id: 'c1',
      iso_code2: 'gb',
      name: 'United Kingdom',
      flag: 'https://cdn.example/gb.svg',
      phone_code: '44',
    });
    expect(country.id).toBe('c1');
    expect(country.isoCode2).toBe('gb');
    expect(country.flag).toBe('https://cdn.example/gb.svg');
    expect(country.phoneCode).toBe('44');
  });

  it('parses country brief without flag as null', () => {
    const country = parseCountryBrief({
      id: 'c2',
      iso_code2: 'US',
      name: 'United States',
      flag: '',
    });
    expect(country.flag).toBeNull();
    expect(country.phoneCode).toBeNull();
  });

  it('parses organization with nested country and city', () => {
    const org = parseOrganization({
      id: '1',
      name: 'Sage',
      type: 't',
      email: 'a@b.c',
      address: '1',
      city: { id: 42, name: 'NYC', name_std: 'New York' },
      postal_code: '10001',
      country: { id: 'c', name: 'United States', iso_code2: 'US' },
      verification_status: { value: 'V', title: 'Verified', css: 'success' },
      addresses: [
        {
          id: 'a1',
          label: 'Main',
          is_primary: true,
          address: '1 St',
          city: { id: 42, name: 'NYC' },
          postal_code: '10001',
          country: { id: 'c', name: 'United States' },
        },
      ],
    });
    expect(org.country).toBe('United States');
    expect(org.countryId).toBe('c');
    expect(org.city).toBe('NYC');
    expect(org.cityId).toBe('42');
    expect(org.verificationStatus?.css).toBe('success');
    expect(org.acceptedLocationTypes).toEqual([]);
    expect(org.addresses).toHaveLength(1);
    expect(org.addresses[0].isPrimary).toBe(true);
    expect(org.addresses[0].cityId).toBe('42');
  });

  it('parses accepted location types', () => {
    const org = parseOrganization({
      id: '1',
      name: 'Sage',
      type: 't',
      email: 'a@b.c',
      address: '1',
      city: { id: 1, name: 'NYC' },
      postal_code: '10001',
      accepted_location_types: ['O', 'v', 'X'],
    });
    expect(org.acceptedLocationTypes).toEqual(['O', 'V']);
  });

  it('parses city brief', () => {
    const city = parseCityBrief({ id: 9, name: 'Seattle', name_std: 'Seattle', timezone: 'US/Pacific' });
    expect(city.id).toBe('9');
    expect(city.name).toBe('Seattle');
  });

  it('formats team member display name', () => {
    const m = parseTeamMember({
      id: 'u',
      email: 'x@y.z',
      first_name: 'Ada',
      last_name: 'Lovelace',
    });
    expect(teamMemberDisplayName(m)).toBe('Ada Lovelace');
  });
});
