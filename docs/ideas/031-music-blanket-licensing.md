# Idea 031: Blanket Licensing Agreements with Music Rights Organizations

**Status:** Raw idea
**Date:** 2026-04-10

## Summary

Gleisner must secure blanket licensing agreements (包括的利用許諾契約) with music rights organizations (JASRAC, NexTone) before opening the platform beyond Phase 0. As a musician-focused platform, cover performance uploads will be disproportionately high compared to general SNS, making this a critical legal prerequisite for public launch.

## Notes

### Problem

- Major platforms (YouTube, X/Twitter, Instagram, TikTok) have blanket agreements with JASRAC/NexTone, making user-uploaded cover performances legal without individual permission
- Without such agreements, Gleisner as a platform operator bears copyright infringement liability for cover videos uploaded by users
- ADR 018 covers post-hoc DMCA takedown procedures; blanket licensing is the **preventive** complement — ensuring cover performances are not infringement in the first place

### Scope of blanket licensing

| Covered | Not covered |
|---------|-------------|
| Performance rights (演奏権) — playing/singing a song | Master recording rights (原盤権) — using the actual CD/streaming audio |
| Public transmission rights (公衆送信権) — streaming a cover | Synchronization rights — using music in video productions |
| "Played it" / "Sang it" videos (弾いてみた/歌ってみた) | Karaoke tracks from commercial sources |

- **Key distinction**: blanket licensing only covers performing someone else's composition. Using the original recording (CD audio, Spotify rip) as BGM requires separate rights clearance from the record label, which blanket agreements do not provide.

### Phase relationship

- **Phase 0 (family lifelog)**: Not a practical concern — private use among family members
- **SNS public launch**: Blanket licensing becomes a **hard prerequisite**
- **Interim measure**: Phase 0 Terms of Service should state "original content only" to establish the boundary

### Contract types to investigate

1. **JASRAC**: "Interactive transmission" (インタラクティブ配信) blanket agreement — covers streaming/on-demand of managed works
2. **NexTone**: Similar blanket agreement for NexTone-managed catalog (growing share of J-pop)
3. **Fee structure**: Typically revenue-based or flat rate for small platforms — needs research on startup-friendly terms
4. **Both are required**: JASRAC and NexTone have separate catalogs; missing either leaves gaps

### International expansion considerations

- Each country has its own rights organizations: ASCAP/BMI/SESAC (US), PRS (UK), GEMA (Germany), SACEM (France), etc.
- Blanket agreements would need to be secured per-market as Gleisner expands
- Some organizations have reciprocal agreements that may simplify multi-territory licensing

### Gleisner-specific advantages

- User DID + contentHash provides transparent tracking of which compositions are performed — this data could simplify royalty reporting to rights organizations
- Structured post metadata (mediaType, track categorization) enables accurate classification of cover vs. original content
- This transparency could be a negotiation advantage when approaching JASRAC/NexTone

### Open questions

| # | Question | Status |
|---|----------|--------|
| OQ-1 | What are the actual costs of JASRAC/NexTone blanket agreements for a startup-scale platform? | Needs research |
| OQ-2 | Can Gleisner's metadata/provenance features reduce reporting burden and earn favorable terms? | Needs research |
| OQ-3 | Should users self-declare "this is a cover of [song]" at upload time to enable accurate royalty reporting? | Design decision |
| OQ-4 | How do other small music platforms (e.g., nana, Piapro) handle blanket licensing? | Needs research |
| OQ-5 | Timeline: when exactly in the SNS launch roadmap should contract negotiation begin? (likely 3-6 months before public launch) | Planning decision |

## Related

- Idea 011 — Copyright Protection (broad research; mentions music licensing as "voluntary/business strategy" but lacks JASRAC/NexTone specifics)
- ADR 018 — Copyright Protection (DMCA post-hoc framework; this idea covers the preventive complement)
- Idea 016 — Monetization Strategy (licensing fees need a revenue source — alignment required)
