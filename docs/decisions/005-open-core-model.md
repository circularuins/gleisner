# ADR 005: Open-Core Business Model

## Status

Accepted

## Context

Gleisner needs a sustainable business model that:

1. Keeps the core platform open and forkable (aligned with AGPL v3, see ADR 003)
2. Generates revenue to fund ongoing development
3. Does not compromise the project's commitment to artist ownership and decentralization
4. Avoids the trap of making the open-source version deliberately crippled

## Decision

Adopt an **open-core model** with a clear boundary between the open-source core and premium offerings.

### What is open (AGPL v3)

The **core protocol and platform** — everything needed for an artist to run their own Gleisner instance:

- Federation/decentralization protocol
- Core API (content publishing, timeline, tracks)
- Base UI (multi-track timeline viewer and editor)
- Identity and authentication
- Data import/export
- Self-hosting documentation and tooling

### What is premium (separate terms)

**Value-added services** that make the experience easier or more powerful, but are not required:

- **Managed hosting** — "Gleisner Cloud" for artists who don't want to self-host
- **Analytics and insights** — Audience engagement metrics, trend analysis
- **Advanced customization** — Premium themes, custom domain support with managed SSL
- **Priority support** — Dedicated support channels for paying users
- **Collaboration tools** — Multi-artist features, guest appearances on timelines

### The bright line

The test for whether something belongs in the open core:

> **"Can an artist fully own and control their creative presence without this feature?"**
>
> - If **yes** → it's a premium convenience feature
> - If **no** → it must be in the open core

This ensures the open-source version is never deliberately crippled. An artist running their own instance has full creative sovereignty.

## Consequences

- Revenue comes from convenience and scale, not from gatekeeping core functionality.
- The open-core boundary must be maintained as the project grows — resist the temptation to move core features behind a paywall.
- Self-hosting must remain a genuinely viable option, not just a theoretical one.
- Pricing and premium feature specifics will be decided as the project matures.
- A CLA may be needed to allow dual-licensing of the premium components (see ADR 003).
