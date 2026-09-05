# docker-beets (BGarber42 fork)

Behavioral drop-in replacement for [`lscr.io/linuxserver/beets`](https://github.com/linuxserver/docker-beets),
built from [`BGarber42/beets`](https://github.com/BGarber42/beets) and published to:

```text
ghcr.io/bgarber42/beets:<tag>
```

Existing LinuxServer-style Compose files keep working after changing only the
image name. `PUID`, `PGID`, `TZ`, `/config`, `/music`, `/downloads`, and port
`8337` behave the same.

## Drop-in Compose

```yaml
services:
  beets:
    image: ghcr.io/bgarber42/beets:nightly
    container_name: beets
    environment:
      - PUID=1000
      - PGID=1000
      - TZ=Etc/UTC
    volumes:
      - /path/to/beets/config:/config
      - /path/to/music/library:/music
      - /path/to/ingest:/downloads
    ports:
      - 8337:8337
    restart: unless-stopped
```

For the import-proposals worktree:

```yaml
image: ghcr.io/bgarber42/beets:import-proposals
```

## Tags

| Tag | Source |
| --- | --- |
| `latest`, `<version>`, `<major>.<minor>` | Latest (or selected) release tag in `BGarber42/beets` |
| `nightly`, `nightly-<sha>` | `BGarber42/beets` `master` |
| `<branch-tag>`, `<branch-tag>-<sha>` | Requested branch in `BGarber42/beets` |
| `import-proposals` | Alias for `fix/manual-id-proposal-candidates` |

Branch names are sanitized for Docker tags (lowercase, `/` → `-`, truncated).
Add more short aliases in `.github/workflows/container-publish.yaml`.

## Runtime contract

- Base: Debian Trixie (`python:3.13-slim-trixie`); larger than Alpine LSIO by design
- Default process: `beet web` on `0.0.0.0:8337`
- Seeds `/config/config.yaml` and `/config/beets.sh` when missing
- Default library DB: `/config/musiclibrary.blb`
- User `abc` with host `PUID`/`PGID` ownership on `/config`
- Compatibility symlink: `/lsiopy/bin/beet` → venv `beet`
- Full plugin tooling: ffmpeg, ImageMagick, GStreamer/PyGObject, chromaprint/`fpcalc`,
  mp3val, Discogs/web/chroma/lastgenre helpers, `beetcamp`, `beets-extrafiles`
  (seeded replaygain defaults to ffmpeg; GStreamer remains available)

## Publish workflow

GitHub Actions workflow [`.github/workflows/container-publish.yaml`](.github/workflows/container-publish.yaml):

- **test** job builds `linux/amd64`, runs smoke tests, and does not push
- **publish** job runs only after test succeeds (skipped on pull requests)
- Publishes `linux/amd64` + `linux/arm64` to GHCR with Buildx GHA layer cache
- `master` push + nightly schedule: publish `nightly`
- Manual dispatch:
  - `channel=nightly`
  - `channel=latest`
  - `channel=branch` with `beets_ref=fix/manual-id-proposal-candidates`

Example dispatch for the proposals branch:

```bash
gh workflow run container-publish.yaml \
  -R BGarber42/docker-beets \
  -f channel=branch \
  -f beets_ref=fix/manual-id-proposal-candidates
```

First GHCR package publish may be private. Set the `beets` package visibility to
public under the repo Packages settings for unauthenticated pulls.

## Local build

```bash
docker build \
  --build-arg BEETS_REPO=https://github.com/BGarber42/beets.git \
  --build-arg BEETS_REF=master \
  -t beets:local .

docker run --rm \
  -e PUID=1000 -e PGID=1000 -e TZ=Etc/UTC \
  -v "$PWD/config:/config" \
  -v "$PWD/music:/music" \
  -v "$PWD/downloads:/downloads" \
  -p 8337:8337 \
  beets:local
```

## Related repositories

- Application source: https://github.com/BGarber42/beets
- Upstream packaging inspiration: https://github.com/linuxserver/docker-beets
- Upstream application: https://github.com/beetbox/beets
