# CLAUDE.md — docker-beets maintenance notes

## Purpose

Standalone container repo for `ghcr.io/bgarber42/beets`. Keeps Docker packaging
out of `BGarber42/beets` so upstream PRs stay source-focused.

## Drop-in contract (do not break)

Compose-facing behavior must remain compatible with `lscr.io/linuxserver/beets`:

- Env: `PUID`, `PGID`, `TZ`, `BEETSDIR=/config`, `HOME=/config`
- Volumes: `/config`, `/music`, `/downloads`
- Port: `8337`
- Default command runs `beet web`
- Seed `/config/config.yaml` and executable `/config/beets.sh` when absent
- Runtime user name `abc` (for `docker exec -u abc ...` muscle memory)
- `/lsiopy/bin/beet` symlink retained for older helper scripts

Internals may differ (no Alpine/s6 requirement).

## Base image

- `python:3.13-slim-trixie` (Debian 13) for current PyGObject / `girepository-2.0`
- Builder uses `libgirepository-2.0-dev`; runtime uses `libgirepository-2.0-0`
- `libchromaprint-tools` provides `fpcalc` (not Ubuntu's `chromaprint-tools`)
- No `mp3gain` in Debian; default config uses `replaygain.backend: ffmpeg`

## Source resolution

Dockerfile build-args:

- `BEETS_REPO` default `https://github.com/BGarber42/beets.git`
- `BEETS_REF` commit SHA / branch / tag

Workflow channels in `.github/workflows/container-publish.yaml`:

| Channel | Beets ref | Image tags |
| --- | --- | --- |
| `nightly` | `master` SHA | `nightly`, `nightly-<sha7>` |
| `latest` | latest GitHub release tag | `latest`, `<version>`, `<major>.<minor>` |
| `branch` | dispatch `beets_ref` | sanitized tag + `<tag>-<sha7>` |

Branch alias map (extend in the workflow `sanitize_branch` function):

- `fix/manual-id-proposal-candidates` → `import-proposals`

## CI gating

1. **test** job: amd64 build + smoke test (`beet version`, web on `:8337`, seeded files)
2. **publish** job: `needs: test` and only runs when test succeeds and event is not a PR

Broken images must not be pushed; publish never runs in parallel with an unfinished or failed test.

## Caching

- Dockerfile builder stage: `--mount=type=cache,target=/root/.cache/uv`
- Actions: `cache-from` / `cache-to` `type=gha` scopes `beets-amd64` and `beets-multi`
