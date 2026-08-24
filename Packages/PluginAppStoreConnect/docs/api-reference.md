# App Store Connect API Reference

## API Overview

- **Base URL**: `https://api.appstoreconnect.apple.com`
- **API Version**: v1
- **Authentication**: JWT (JSON Web Token)
- **Content Type**: `application/json`

## Documentation Structure

### Essentials
- [Authentication & Authorization](authentication.md) - API Keys, JWT Tokens, Rate Limits

### App Store APIs
- [Apps](apps.md) - Manage apps and app metadata
- [App Store Versions](app_store_versions.md) - Manage App Store version information
- [App Store Version Submissions](app_store_version_submissions.md) - Submit versions for review
- [App Store Version Release Requests](app_store_version_release_requests.md) - Manually release approved versions
- [App Store Version Phased Releases](app_store_version_phased_releases.md) - Manage phased releases
- [App Store Version Localizations](app_store_version_localizations.md) - Manage version localizations (description, keywords, etc.)

### TestFlight APIs
- [Builds](builds.md) - Build management
- [Beta Testers](beta_testers.md) - Beta tester management
- [Beta Groups](beta_groups.md) - Beta group management

### Content & Localization
- [App Screenshots](app_screenshots.md) - App Store screenshots and preview sets

### Users & Access
- [Users](users.md) - Team user management
- [User Invitations](user_invitations.md) - User invitation management

### Provisioning
- [Bundle IDs](bundle_ids.md) - Bundle identifier management
- [Certificates](certificates.md) - Signing certificate management
- [Devices](devices.md) - Device registration
- [Profiles](profiles.md) - Provisioning profile management

## Rate Limits

All API requests are subject to rate limiting:
- **Header**: `X-Rate-Limit`
- **Format**: `user-hour-lim:3500;user-hour-rem:500;`
- **Limit**: ~3,500 requests per hour per API key
- **Error Code**: `429` when rate limit exceeded

## Common Response Codes

| Code | Description |
|------|-------------|
| 200 | Success |
| 201 | Created |
| 204 | No Content (successful deletion) |
| 400 | Bad Request |
| 401 | Unauthorized (invalid or missing JWT) |
| 403 | Forbidden (insufficient permissions) |
| 404 | Not Found |
| 409 | Conflict |
| 422 | Unprocessable Entity |
| 429 | Rate Limit Exceeded |

## Pagination

List endpoints support pagination:
- **limit**: Number of resources per page (default varies, max varies)
- **cursor**: Opaque cursor for pagination
- **next**: Link to next page (if available)

Response structure:
```json
{
  "data": [...],
  "links": {
    "self": "...",
    "next": "..."
  },
  "meta": {
    "paging": {
      "total": 100,
      "limit": 50
    }
  }
}
```

## Filtering and Sorting

Most list endpoints support:
- **filter**: Filter results by field values
  - Example: `?filter[bundleId]=com.example.app`
- **sort**: Sort results by field
  - Example: `?sort=-createdDate` (descending)
- **fields**: Sparse fieldsets
  - Example: `?fields[apps]=name,bundleId`
- **include**: Include related resources
  - Example: `?include=appStoreVersions`

## Related Resources
- [Apple Developer Documentation](https://developer.apple.com/documentation/appstoreconnectapi)
- [OpenAPI Specification](https://developer.apple.com/documentation/appstoreconnectapi/openapi-specification)
- [Creating API Keys](https://developer.apple.com/documentation/appstoreconnectapi/creating-api-keys-for-app-store-connect-api)
- [Generating Tokens](https://developer.apple.com/documentation/appstoreconnectapi/generating-tokens-for-api-requests)
