import { parseOrganization, teamMemberDisplayName, parseTeamMember } from './organization';

describe('organization parsers', () => {
  it('parses organization with nested country', () => {
    const org = parseOrganization({
      id: '1',
      name: 'Sage',
      type: 't',
      email: 'a@b.c',
      address: '1',
      city: 'NYC',
      postal_code: '10001',
      country: { id: 'c', name: 'United States', iso_code2: 'US' },
      verification_status: { value: 'V', title: 'Verified', css: 'success' },
    });
    expect(org.country).toBe('United States');
    expect(org.countryId).toBe('c');
    expect(org.verificationStatus?.css).toBe('success');
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
