# App Store Connect API 完整端点参考

本文档提供 App Store Connect API 所有端点的快速参考。

## Base URL

```
https://api.appstoreconnect.apple.com/v1
https://api.appstoreconnect.apple.com/v2
```

## Apps and App Metadata

| Method | Endpoint | Description |
|--------|----------|-------------|
| GET | `/v1/apps` | List apps |
| GET | `/v1/apps/{id}` | Read app information |
| PATCH | `/v1/apps/{id}` | Modify an app |
| GET | `/v1/apps/{id}/appStoreVersions` | List all App Store versions for an app |
| GET | `/v1/apps/{id}/builds` | List all builds of an app |
| GET | `/v1/apps/{id}/betaGroups` | List all beta groups for an app |
| GET | `/v1/apps/{id}/betaAppLocalizations` | List all beta app localizations |
| GET | `/v1/apps/{id}/inAppPurchasesV2` | List all in-app purchases |
| GET | `/v1/apps/{id}/customerReviews` | List all customer reviews |

## App Store Versions

| Method | Endpoint | Description |
|--------|----------|-------------|
| GET | `/v1/appStoreVersions` | List App Store versions |
| GET | `/v1/appStoreVersions/{id}` | Read App Store version information |
| POST | `/v1/appStoreVersions` | Create an App Store version |
| PATCH | `/v1/appStoreVersions/{id}` | Modify an App Store version |
| DELETE | `/v1/appStoreVersions/{id}` | Delete an App Store version |
| GET | `/v1/appStoreVersions/{id}/appStoreVersionLocalizations` | List all localizations |
| GET | `/v1/appStoreVersions/{id}/appStoreVersionSubmission` | Read version submission |
| GET | `/v1/appStoreVersions/{id}/build` | Read build for version |

## App Store Version Submissions

| Method | Endpoint | Description |
|--------|----------|-------------|
| POST | `/v1/appStoreVersionSubmissions` | Submit for review |
| DELETE | `/v1/appStoreVersionSubmissions/{id}` | Delete a submission |

## App Store Version Phased Releases

| Method | Endpoint | Description |
|--------|----------|-------------|
| POST | `/v1/appStoreVersionPhasedReleases` | Create a phased release |
| GET | `/v1/appStoreVersionPhasedReleases/{id}` | Read phased release information |
| PATCH | `/v1/appStoreVersionPhasedReleases/{id}` | Update phased release state |
| DELETE | `/v1/appStoreVersionPhasedReleases/{id}` | Delete a phased release |

## App Store Version Localizations

| Method | Endpoint | Description |
|--------|----------|-------------|
| GET | `/v1/appStoreVersionLocalizations` | List all localizations |
| GET | `/v1/appStoreVersionLocalizations/{id}` | Read localization information |
| POST | `/v1/appStoreVersionLocalizations` | Create a localization |
| PATCH | `/v1/appStoreVersionLocalizations/{id}` | Modify a localization |
| DELETE | `/v1/appStoreVersionLocalizations/{id}` | Delete a localization |

## App Screenshots

| Method | Endpoint | Description |
|--------|----------|-------------|
| GET | `/v1/appScreenshotSets` | List screenshot sets |
| POST | `/v1/appScreenshotSets` | Create a screenshot set |
| DELETE | `/v1/appScreenshotSets/{id}` | Delete a screenshot set |
| GET | `/v1/appScreenshots` | List screenshots |
| POST | `/v1/appScreenshots` | Upload a screenshot |
| GET | `/v1/appScreenshots/{id}` | Read screenshot information |
| DELETE | `/v1/appScreenshots/{id}` | Delete a screenshot |

## Builds

| Method | Endpoint | Description |
|--------|----------|-------------|
| GET | `/v1/builds` | List builds |
| GET | `/v1/builds/{id}` | Read build information |
| PATCH | `/v1/builds/{id}` | Modify build information |

## Beta Testers

| Method | Endpoint | Description |
|--------|----------|-------------|
| GET | `/v1/betaTesters` | List beta testers |
| GET | `/v1/betaTesters/{id}` | Read beta tester information |
| POST | `/v1/betaTesters` | Invite a beta tester |
| DELETE | `/v1/betaTesters/{id}` | Remove a beta tester |

## Beta Groups

| Method | Endpoint | Description |
|--------|----------|-------------|
| GET | `/v1/betaGroups` | List beta groups |
| GET | `/v1/betaGroups/{id}` | Read beta group information |
| POST | `/v1/betaGroups` | Create a beta group |
| PATCH | `/v1/betaGroups/{id}` | Modify a beta group |
| DELETE | `/v1/betaGroups/{id}` | Delete a beta group |
| POST | `/v1/betaGroups/{id}/relationships/betaTesters` | Add testers to group |
| DELETE | `/v1/betaGroups/{id}/relationships/betaTesters` | Remove testers from group |
| POST | `/v1/betaGroups/{id}/relationships/builds` | Add build to group |

## Beta App Localizations

| Method | Endpoint | Description |
|--------|----------|-------------|
| GET | `/v1/betaAppLocalizations` | List beta app localizations |
| GET | `/v1/betaAppLocalizations/{id}` | Read localization information |
| POST | `/v1/betaAppLocalizations` | Create a localization |
| PATCH | `/v1/betaAppLocalizations/{id}` | Modify a localization |
| DELETE | `/v1/betaAppLocalizations/{id}` | Delete a localization |

## Users

| Method | Endpoint | Description |
|--------|----------|-------------|
| GET | `/v1/users` | List users |
| GET | `/v1/users/{id}` | Read user information |
| PATCH | `/v1/users/{id}` | Modify user permissions |
| DELETE | `/v1/users/{id}` | Remove a user |

## User Invitations

| Method | Endpoint | Description |
|--------|----------|-------------|
| GET | `/v1/userInvitations` | List invitations |
| GET | `/v1/userInvitations/{id}` | Read invitation information |
| POST | `/v1/userInvitations` | Invite a user |
| DELETE | `/v1/userInvitations/{id}` | Cancel an invitation |

## In-App Purchases (v2)

| Method | Endpoint | Description |
|--------|----------|-------------|
| GET | `/v2/inAppPurchases` | List in-app purchases |
| GET | `/v2/inAppPurchases/{id}` | Read in-app purchase information |
| POST | `/v2/inAppPurchases` | Create an in-app purchase |
| PATCH | `/v2/inAppPurchases/{id}` | Modify an in-app purchase |
| DELETE | `/v2/inAppPurchases/{id}` | Delete an in-app purchase |

## Bundle IDs

| Method | Endpoint | Description |
|--------|----------|-------------|
| GET | `/v1/bundleIds` | List bundle IDs |
| GET | `/v1/bundleIds/{id}` | Read bundle ID information |
| POST | `/v1/bundleIds` | Register a bundle ID |
| PATCH | `/v1/bundleIds/{id}` | Modify a bundle ID |
| DELETE | `/v1/bundleIds/{id}` | Delete a bundle ID |

## Certificates

| Method | Endpoint | Description |
|--------|----------|-------------|
| GET | `/v1/certificates` | List certificates |
| GET | `/v1/certificates/{id}` | Read certificate information |
| POST | `/v1/certificates` | Create a certificate |
| DELETE | `/v1/certificates/{id}` | Revoke a certificate |

## Devices

| Method | Endpoint | Description |
|--------|----------|-------------|
| GET | `/v1/devices` | List devices |
| GET | `/v1/devices/{id}` | Read device information |
| POST | `/v1/devices` | Register a device |
| PATCH | `/v1/devices/{id}` | Modify a device |

## Profiles

| Method | Endpoint | Description |
|--------|----------|-------------|
| GET | `/v1/profiles` | List provisioning profiles |
| GET | `/v1/profiles/{id}` | Read profile information |
| POST | `/v1/profiles` | Create a profile |
| DELETE | `/v1/profiles/{id}` | Delete a profile |

## Common Query Parameters

### Pagination
```
?limit=50
?cursor=eyJvZmZzZXQiOiI1MCJ9
```

### Filtering
```
?filter[app]=123456789
?filter[bundleId]=com.example.app
?filter[platform]=IOS
?filter[locale]=en-US,zh-Hans
```

### Sorting
```
?sort=name
?sort=-createdDate
?sort=-bundleId,name
```

### Field Selection
```
?fields[apps]=name,bundleId
?fields[appStoreVersions]=versionString,platform
```

### Include Relationships
```
?include=appStoreVersions,builds
?include=app,betaGroups
```

## HTTP Status Codes

| Code | Description |
|------|-------------|
| 200 | OK - Request succeeded |
| 201 | Created - Resource created successfully |
| 204 | No Content - Deletion succeeded |
| 400 | Bad Request - Invalid request |
| 401 | Unauthorized - Missing or invalid authentication |
| 403 | Forbidden - Insufficient permissions |
| 404 | Not Found - Resource not found |
| 409 | Conflict - Resource conflict |
| 422 | Unprocessable Entity - Validation failed |
| 429 | Too Many Requests - Rate limit exceeded |

## Related Documentation

- [API Reference Overview](api-reference.md)
- [Authentication](authentication.md)
- [Official Apple Documentation](https://developer.apple.com/documentation/appstoreconnectapi)
