# PowerShell Automation Portfolio

Sanitized PowerShell examples based on real-world work in infrastructure automation, identity governance, provisioning workflows, and API integrations.

This repo is intended to show the kinds of automation solutions I build:
- reducing manual admin work
- improving account governance and auditability
- standardizing onboarding and operational workflows
- integrating securely with APIs, vaults, and cloud services

## What This Portfolio Shows

- Identity and access automation
- Service account governance
- RBAC and dynamic group validation
- Secure secret handling
- Onboarding and provisioning workflows
- Windows and Microsoft ecosystem automation
- OAuth and REST API integrations

## Portfolio Scripts

### `scripts/Set-AdAccountOwner.ps1`
Demonstrates a practical IAM governance pattern by assigning ownership metadata to an account based on directory attributes from a designated owner.

### `scripts/Get-VaultCredentialByName.ps1`
Shows how to retrieve a named secret from a vault API and convert it into a reusable `PSCredential` object for secure downstream automation.

### `scripts/Get-LocalAdministratorsAudit.ps1`
Audits local Administrators group membership across Windows systems and highlights non-approved members for access review and least-privilege validation.

### `scripts/Test-DynamicGroupConfiguration.ps1`
Validates dynamic group definitions for risky patterns such as broad search bases, empty filters, default object selections, and oversized memberships.

### `scripts/Invoke-NewHireMailboxProvision.ps1`
Represents a provisioning workflow that finds newly created users, checks for alias conflicts, enables mailboxes, and produces an operational summary.

### `scripts/Invoke-GooglePhotosAppCleanup.ps1`
Demonstrates modern PowerShell API automation with OAuth PKCE, encrypted token storage, retry logic, pagination, and cleanup operations.

## Why The Repo Is Sanitized

These scripts are portfolio-safe examples. Internal names, domains, endpoints, and environment-specific details have been removed or replaced with parameters and placeholders so the code can be shared publicly without exposing private infrastructure.

## Typical Use Cases

- Service account ownership and lifecycle governance
- Access review support and local admin audits
- Dynamic group or RBAC rule validation
- New-hire onboarding and mailbox provisioning
- Secure credential retrieval for automation jobs
- API-based workflow automation for support teams, nonprofits, and operations teams

## Notes

- These are sample implementations and starting points, not drop-in production scripts.
- Replace placeholder values with your own environment-specific settings.
- Review authentication, logging, approval, and compliance requirements before production use.

## Core Skills Demonstrated

- PowerShell scripting and automation design
- Active Directory and IAM operations
- Governance and compliance-oriented automation
- Secret management integration
- REST API and OAuth implementation
- Reporting, validation, and remediation workflows
