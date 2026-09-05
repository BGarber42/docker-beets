# Contributing to docker-beets (BGarber42 fork)

This repository only packages containers. Application changes belong in
[BGarber42/beets](https://github.com/BGarber42/beets).

## Layout

| Path | Purpose |
| --- | --- |
| `Dockerfile` | Multi-arch image build (Buildx) |
| `root/entrypoint.sh` | PUID/PGID/TZ, config seeding, default `beet web` |
| `root/defaults/` | Seeded `config.yaml` and ingest `beets.sh` |
| `.github/workflows/container-publish.yaml` | GHCR publish + smoke tests |
| `README.md` | Hand-maintained usage and tag contract |
| `CLAUDE.md` | Maintenance notes for the drop-in contract and aliases |

## Guidelines

- Preserve the LinuxServer compose drop-in contract (`PUID`/`PGID`/`TZ`,
  `/config` `/music` `/downloads`, port `8337`, default web UI).
- Prefer BuildKit cache mounts and GHA `type=gha` cache for faster rebuilds.
- Add short branch aliases in the workflow `sanitize_branch` function and
  document them in `README.md` / `CLAUDE.md`.
- Do not reintroduce Jenkins/LinuxServer generator coupling unless there is a
  clear reason to restore it.
