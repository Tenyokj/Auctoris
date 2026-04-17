# Auctoris Asset Metadata Spec

## Purpose

This document defines the recommended metadata structure for **Auctoris v1** assets.

The smart contracts only require a `metadataURI`, but the product needs a stable JSON shape so:

1. The future frontend can render assets consistently
2. Partner platforms can parse assets without guesswork
3. Creators know which fields they must provide
4. License tiers can be displayed against a clear canonical asset record

## Scope

This spec is designed for the Auctoris v1 market:

**commercial licensing for creator audio assets**

That includes:

1. `background_track`
2. `podcast_pack`
3. `beat_pack`
4. `sample_pack`
5. `audio_loop_pack`

## Format

The metadata document should be a JSON object stored behind the asset's `metadataURI`.

Recommended storage:

1. IPFS for production-grade decentralized distribution
2. HTTPS only for temporary development or migration paths

## Required fields

These fields should exist for every v1 Auctoris asset.

| Field | Type | Description |
| --- | --- | --- |
| `spec_version` | `string` | Metadata format version, for example `1.0.0` |
| `protocol` | `string` | Protocol identity, recommended value: `Auctoris Licensing Authority` |
| `asset_type` | `string` | One of the approved v1 asset categories |
| `title` | `string` | Human-readable asset title |
| `creator_name` | `string` | Public creator or catalog name |
| `description` | `string` | Short product description |
| `cover_image` | `string` | URL or IPFS URI for visual artwork |
| `preview_audio_url` | `string` | URL or IPFS URI for preview playback |
| `rights_summary` | `string` | One-sentence rights summary shown in product cards |
| `legal_terms_url` | `string` | URL or IPFS URI pointing to the human-readable legal terms |

## Strongly recommended fields

These fields are not strictly required for the contract, but they should be present for a production-facing catalog.

| Field | Type | Description |
| --- | --- | --- |
| `slug` | `string` | SEO and frontend-friendly identifier |
| `creator_id` | `string` | Internal or platform-level creator identifier |
| `duration_seconds` | `number` | Audio duration in seconds |
| `bpm` | `number` | Beats per minute, when relevant |
| `genre` | `string` | Primary genre |
| `mood` | `string[]` | Mood descriptors |
| `tags` | `string[]` | Search and discovery tags |
| `language` | `string` | Language code if vocals or spoken phrases exist |
| `isrc` | `string` | Optional recording identifier if relevant |
| `release_date` | `string` | ISO date string |
| `waveform_image` | `string` | Optional waveform preview image |
| `license_tier_refs` | `string[]` | Product-facing tier references such as `creator`, `commercial`, `agency`, `enterprise` |

## Optional pack-specific fields

For packs rather than single tracks, these fields are useful:

| Field | Type | Description |
| --- | --- | --- |
| `item_count` | `number` | Number of files or stems in the pack |
| `includes_stems` | `boolean` | Whether stems are included |
| `includes_wav` | `boolean` | Whether WAV source files are included |
| `includes_mp3` | `boolean` | Whether MP3 files are included |
| `sample_rate_hz` | `number` | Audio sample rate |
| `bit_depth` | `number` | Audio bit depth |
| `loop_lengths` | `string[]` | For loop packs, a list such as `4bar`, `8bar`, `16bar` |

## Recommended `asset_type` values

For v1, keep the asset taxonomy small and disciplined.

Supported values:

1. `background_track`
2. `podcast_pack`
3. `beat_pack`
4. `sample_pack`
5. `audio_loop_pack`

Avoid inventing many custom categories early.

## JSON example: single track

```json
{
  "spec_version": "1.0.0",
  "protocol": "Auctoris Licensing Authority",
  "asset_type": "background_track",
  "slug": "midnight-pulse",
  "title": "Midnight Pulse",
  "creator_name": "Auctoris Studio",
  "creator_id": "creator_auctoris_studio",
  "description": "Cinematic electronic background track for podcasts, creator videos, trailers, and branded content.",
  "cover_image": "ipfs://bafy.../cover.png",
  "preview_audio_url": "ipfs://bafy.../preview.mp3",
  "waveform_image": "ipfs://bafy.../waveform.png",
  "duration_seconds": 94,
  "bpm": 118,
  "genre": "electronic",
  "mood": ["cinematic", "modern", "driving"],
  "tags": ["podcast", "youtube", "commercial", "brand"],
  "language": "zxx",
  "release_date": "2026-04-17",
  "rights_summary": "Commercial-use creator audio asset licensed through Auctoris.",
  "legal_terms_url": "ipfs://bafy.../terms.md",
  "license_tier_refs": ["creator", "commercial", "agency", "enterprise"]
}
```

## JSON example: pack

```json
{
  "spec_version": "1.0.0",
  "protocol": "Auctoris Licensing Authority",
  "asset_type": "sample_pack",
  "slug": "solar-echo-sample-pack-vol-1",
  "title": "Solar Echo Sample Pack Vol. 1",
  "creator_name": "Auctoris Sound Lab",
  "creator_id": "creator_sound_lab",
  "description": "Commercial-ready sample pack for short-form creator content, podcasts, and brand campaigns.",
  "cover_image": "ipfs://bafy.../cover.png",
  "preview_audio_url": "ipfs://bafy.../preview.mp3",
  "item_count": 48,
  "includes_stems": false,
  "includes_wav": true,
  "includes_mp3": false,
  "sample_rate_hz": 48000,
  "bit_depth": 24,
  "genre": "hybrid",
  "mood": ["clean", "bright", "energetic"],
  "tags": ["sample-pack", "creator-audio", "short-form", "commercial"],
  "rights_summary": "Commercial licensing for creator-focused audio pack assets through Auctoris.",
  "legal_terms_url": "ipfs://bafy.../terms.md",
  "license_tier_refs": ["creator", "commercial", "agency", "enterprise"]
}
```

## Display priorities for the future frontend

The future frontend should prioritize these fields visually:

1. `title`
2. `asset_type`
3. `creator_name`
4. `cover_image`
5. `preview_audio_url`
6. `description`
7. `duration_seconds` or `item_count`
8. `genre`
9. `mood`
10. `license_tier_refs`

## Validation rules

At the product layer, the following validation is recommended:

1. `title` must not be empty
2. `asset_type` must be one of the supported v1 categories
3. `cover_image` should be a valid URI
4. `preview_audio_url` should be a valid URI
5. `rights_summary` should be short enough for card display
6. `legal_terms_url` should always exist in production

## Product guidance

Do not overload the metadata with legal prose.

Keep:

1. Asset metadata in the metadata JSON
2. Human-readable legal terms in a separate file referenced by `legal_terms_url`
3. Commercial tier meaning in the license matrix and frontend UI
