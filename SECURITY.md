# Security Policy

## Reporting a Vulnerability

If you discover a security vulnerability in Gleisner, please report it responsibly.

**Do NOT open a public GitHub issue for security vulnerabilities.**

### How to report

Email: **security@gleisner.app** (or create a private GitHub Security Advisory)

To create a private advisory:
1. Go to the [Security tab](../../security/advisories) of this repository
2. Click "New draft security advisory"
3. Fill in the details

### What to include

- Description of the vulnerability
- Steps to reproduce
- Potential impact
- Suggested fix (if any)

### Response timeline

- **Acknowledgment**: within 48 hours
- **Initial assessment**: within 1 week
- **Fix timeline**: depends on severity, but we aim for:
  - Critical: 24-48 hours
  - High: 1 week
  - Medium: 2 weeks
  - Low: next release

### Scope

The following are in scope:
- Authentication and authorization bypasses
- Cryptographic key management issues (Ed25519, JWT)
- Data leakage (PII, private keys, password hashes)
- GraphQL injection or abuse
- Cross-site scripting (XSS) or CSRF
- Dependency vulnerabilities

### Out of scope

- Social engineering attacks against users
- Denial of service via rate limiting (known limitation, see ADR 020)
- Vulnerabilities in third-party services (report to them directly)

## Security Architecture

See [ADR 020: Security Architecture and Threat Mitigation](docs/decisions/020-security-architecture.md) for our security design, threat model, and remediation roadmap.

## Supported Versions

| Version | Supported |
|---------|-----------|
| main branch | ✅ |
| Other branches | ❌ |

Gleisner is pre-release software. Only the `main` branch receives security updates.
