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

## Caching

- Dockerfile builder stage: `--mount=type=cache,target=/root/.cache/uv`
- Actions: `cache-from` / `cache-to` `type=gha` scopes `beets-amd64` and `beets-multi`

## Debian package gotchas

- Use `libchromaprint-tools` (not Ubuntu's `chromaprint-tools`) for `fpcalc`.
- `mp3gain` is not in Debian bookworm; default config uses `replaygain.backend: ffmpeg`.
