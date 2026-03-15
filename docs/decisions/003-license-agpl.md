# ADR 003: License — AGPL v3

## Status

Accepted

## Context

Gleisner is a decentralized platform where artist ownership and autonomy are core values. The license choice must:

1. Ensure the core protocol and platform remain open and forkable
2. Prevent proprietary lock-in by third parties who deploy the software as a service
3. Align with the project's philosophical commitment to user freedom and resistance to centralized control
4. Support a sustainable open-core business model

## Decision

License the project under the **GNU Affero General Public License v3.0 (AGPL v3)**.

### Why AGPL v3 over alternatives?

| License | Network use clause | Concern |
|---------|-------------------|---------|
| MIT/Apache | No copyleft | A third party could fork, add proprietary features, and offer a competing closed service — undermining the decentralization goal |
| GPL v3 | No network clause | A SaaS provider could modify the code and serve it without sharing changes |
| **AGPL v3** | **Yes** | Anyone who modifies and deploys the software as a network service must share their changes under the same license |

The AGPL v3's network-use clause (Section 13) is critical for a platform that will primarily be accessed over the network. It ensures that the community benefits from all improvements, even those made by hosted service providers.

### Relationship to open-core model

The AGPL v3 covers the **core platform** (protocol, APIs, base UI). Premium or managed-service features can be offered separately under different terms, as long as the AGPL-licensed core remains open. See ADR 005 for details.

## Consequences

- All contributors must agree to the AGPL v3 terms.
- Third parties can freely use, modify, and deploy the software, but must share modifications when serving users over a network.
- Some organizations with strict copyleft policies may hesitate to contribute; this is an acceptable trade-off for protecting the project's openness.
- A Contributor License Agreement (CLA) may be needed in the future to maintain licensing flexibility for the open-core model.
