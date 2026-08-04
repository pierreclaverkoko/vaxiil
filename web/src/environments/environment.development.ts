export const environment = {
  production: false,
  apiBaseUrl: 'http://localhost:9091/api/v1/',
  managementAdminUrl: 'http://localhost:9091/vx-mgmt/',
  supportEmail: 'info@bapimagine.com',
  supportPhone: '+1-555-0100',
  turnstileSiteKey: '0x4AAAAAAD9kzYulPy5lqUue',
  /**
   * Origin for Sumsub success/reject redirects (no trailing slash).
   * Change for tunnels / remote devices during local KYC testing.
   */
  kycRedirectOrigin: 'https://vaxiiltropbien.com',
  featureFlags: {
    messagesEnabled: true,
  },
};
