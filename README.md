# PowerShell Automation Portfolio

This repository contains sanitized PowerShell examples drawn from real-world infrastructure, IAM, and workflow automation patterns. The scripts are written to be safe to share publicly: company names, internal domains, server names, and private endpoints have been removed or replaced with parameters and placeholders.

## Focus Areas

- Identity and access automation
- Service account governance
- Secure credential handling
- RBAC and dynamic group validation
- Provisioning workflows
- Microsoft infrastructure automation
- API and OAuth integrations

## Included Scripts

### `scripts/Set-AdAccountOwner.ps1`
Updates a custom ownership attribute on an Active Directory account based on the employee number of a designated owner. Useful for service account governance and accountability.

### `scripts/Get-VaultCredentialByName.ps1`
Retrieves a named secret from a generic secret-management API and returns a reusable `PSCredential` object for downstream automation.

### `scripts/Get-LocalAdministratorsAudit.ps1`
Audits local Administrators group membership on one or more Windows servers and highlights non-approved members.

### `scripts/Test-DynamicGroupConfiguration.ps1`
Evaluates dynamic group definitions for risky configuration patterns such as default search bases, empty filters, and oversized membership results. Can export findings and optionally submit a ticket payload to a workflow endpoint.

### `scripts/Invoke-NewHireMailboxProvision.ps1`
Example onboarding workflow that finds newly created user accounts, checks for mail alias conflicts, enables mailboxes, and writes a summary report.

### `scripts/Invoke-GooglePhotosAppCleanup.ps1`
Demonstrates OAuth PKCE, encrypted token storage, resilient API calls, and paginated cleanup of app-created Google Photos content.

## Notes

- These examples are designed as portfolio samples and starting points, not drop-in production scripts.
- Replace placeholder URLs, OUs, policies, and API endpoints with your own environment values.
- Review authentication, logging, and error handling requirements before production use.

## Skills Demonstrated

- PowerShell automation design
- Active Directory administration
- IAM governance patterns
- Secure secret usage
- REST API integration
- OAuth and token handling
- Operational reporting and remediation workflows
