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
- `/lsiopy` is a symlink to `/opt/beets` (venv used by `beet`)
- `INSTALL_PIP_PACKAGES` (`|` / comma / whitespace separated; PyPI or
  `git+https://...`) installs into that venv at container start via `uv pip`
  (root only; before dropping to `abc`)
- `DOCKER_MODS` is intentionally unsupported

Internals may differ (no Alpine/s6 requirement).

## Base image

- `python:3.13-slim-trixie` (Debian 13) for current PyGObject / `girepository-2.0`
- Builder uses `libgirepository-2.0-dev`; runtime uses `libgirepository-2.0-0`
- `libchromaprint-tools` provides `fpcalc` (not Ubuntu's `chromaprint-tools`)
- Default seeded config uses `replaygain.backend: ffmpeg` (Debian has no `mp3gain`);
  GStreamer + PyGObject remain installed so users can switch backends/plugins

## Size expectations

The image is **intentionally larger** than `lscr.io/linuxserver/beets` (~223 MB
compressed on Alpine). We ship a full plugin/tooling stack on Debian Trixie
(ffmpeg, ImageMagick, GStreamer, chromaprint, mp3val, web/Discogs/chroma deps,
beetcamp, extrafiles). Do not strip those for size unless introducing a separate
slim tag; drop-in users may enable any of the seeded plugins.

Safe size wins already applied (no feature loss):

- Avoid Debian `python3-gi` / `python3-gst-1.0` (they pull a second system Python
  into the official `python` image). Use venv `PyGObject` + GIR typelibs instead.
- Drop runtime `gobject-introspection` tooling package; keep `libgirepository` +
  `gir1.2-gstreamer*` typelibs.
- Remove `pip` / `setuptools` / `wheel` from the runtime venv after install.

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

Why builds still feel slow even when "nothing changed":

1. **Publish always builds `linux/arm64` under QEMU** — that dominates wall time and
   is inherently slower than amd64, even with warm caches.
2. **`BEETS_REF` is a commit SHA** — the beets install layer must rebuild when the
   source SHA changes (nightly/branch). Heavy deps (PyGObject, apt) are layered
   above that so they stay cached.
3. **Test + publish are separate jobs** — publish reuses GHA/registry cache, but
   still performs a full multi-arch build; it does not reuse the smoke-test local
   image.
4. **Frequent pushes cancel in-flight runs** — warm caches help the next attempt,
   but cancelled publishes waste partial work.

Dockerfile layering (stable → volatile):

- builder apt/uv → mp3val → third-party Python deps → beets git SHA install
- runtime apt → copy venv → entrypoint → **LABEL/ARG metadata last**

Actions cache:

- Shared GHA scope `beets` for test + publish
- Registry cache tag `ghcr.io/bgarber42/beets:buildcache`
- Builder: `--mount=type=cache,target=/root/.cache/uv`
