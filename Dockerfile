# syntax=docker/dockerfile:1

ARG PYTHON_VERSION=3.13

FROM python:${PYTHON_VERSION}-slim-trixie AS builder

ARG BEETS_REPO=https://github.com/BGarber42/beets.git
ARG BEETS_REF=master

ENV UV_COMPILE_BYTECODE=1 \
    UV_LINK_MODE=copy \
    UV_PROJECT_ENVIRONMENT=/opt/beets \
    PATH="/opt/beets/bin:${PATH}"

RUN apt-get update \
 && apt-get install -y --no-install-recommends \
      build-essential \
      ca-certificates \
      curl \
      git \
      gobject-introspection \
      libcairo2-dev \
      libffi-dev \
      libgirepository-2.0-dev \
      make \
      pkg-config \
      python3-dev \
 && rm -rf /var/lib/apt/lists/* \
 && pip install --no-cache-dir "uv>=0.8,<0.10" \
 && install -m 0755 "$(command -v uv)" /uv

WORKDIR /src

RUN --mount=type=cache,target=/root/.cache/uv \
    git clone --filter=blob:none "${BEETS_REPO}" /src/beets \
 && git -C /src/beets fetch --tags --force \
 && git -C /src/beets checkout -f "${BEETS_REF}" \
 && uv venv /opt/beets \
 && uv pip install --python /opt/beets/bin/python \
      "/src/beets[chroma,discogs,embedart,fetchart,import,lastgenre,lyrics,replaygain,web]" \
      beautifulsoup4 \
      beets-extrafiles \
      beetcamp \
      flask \
      flask-cors \
      pyacoustid \
      pylast \
      PyGObject \
      python3-discogs-client \
      requests \
      requests_oauthlib \
      typing-extensions \
      unidecode \
 && uv pip uninstall --python /opt/beets/bin/python pip setuptools wheel \
 && mkdir -p /tmp/mp3val-src \
 && curl -fsSL -o /tmp/mp3val-src/mp3val.tar.gz \
      https://downloads.sourceforge.net/mp3val/mp3val-0.1.8-src.tar.gz \
 && tar xzf /tmp/mp3val-src/mp3val.tar.gz -C /tmp/mp3val-src --strip-components=1 \
 && make -C /tmp/mp3val-src -f Makefile.linux \
 && install -m 0755 /tmp/mp3val-src/mp3val /usr/local/bin/mp3val \
 && rm -rf /src /tmp/mp3val-src

FROM python:${PYTHON_VERSION}-slim-trixie AS runtime

ARG BUILD_DATE
ARG VERSION=dev
ARG VCS_REF
ARG BEETS_REPO=https://github.com/BGarber42/beets.git
ARG BEETS_REF=master

LABEL org.opencontainers.image.title="beets" \
      org.opencontainers.image.description="Behavioral drop-in replacement for linuxserver/beets, built from BGarber42/beets" \
      org.opencontainers.image.url="https://beets.io/" \
      org.opencontainers.image.source="https://github.com/BGarber42/docker-beets" \
      org.opencontainers.image.documentation="https://github.com/BGarber42/docker-beets" \
      org.opencontainers.image.licenses="GPL-3.0-only" \
      org.opencontainers.image.version="${VERSION}" \
      org.opencontainers.image.revision="${VCS_REF}" \
      org.opencontainers.image.created="${BUILD_DATE}" \
      beets.repo="${BEETS_REPO}" \
      beets.ref="${BEETS_REF}"

ENV BEETSDIR=/config \
    HOME=/config \
    EDITOR=nano \
    PUID=1000 \
    PGID=1000 \
    TZ=Etc/UTC \
    PATH="/opt/beets/bin:/lsiopy/bin:${PATH}"

RUN apt-get update \
 && apt-get install -y --no-install-recommends \
      ca-certificates \
      ffmpeg \
      flac \
      gir1.2-gstreamer-1.0 \
      gir1.2-gst-plugins-base-1.0 \
      gosu \
      gstreamer1.0-plugins-base \
      gstreamer1.0-plugins-good \
      imagemagick \
      libcairo2 \
      libchromaprint-tools \
      libgirepository-2.0-0 \
      nano \
      tzdata \
 && rm -rf /var/lib/apt/lists/* \
 && groupadd --gid 1000 abc \
 && useradd --uid 1000 --gid 1000 --home-dir /config --create-home \
      --shell /usr/sbin/nologin abc \
 && mkdir -p /music /downloads \
 && chown -R abc:abc /config /music /downloads

COPY --from=builder /uv /usr/local/bin/uv
COPY --from=builder /opt/beets /opt/beets
COPY --from=builder /usr/local/bin/mp3val /usr/local/bin/mp3val
COPY root/ /

RUN ln -sfn /opt/beets /lsiopy \
 && chmod +x /entrypoint.sh /defaults/beets.sh \
 && /opt/beets/bin/python -c "import gi; gi.require_version('Gst', '1.0'); from gi.repository import Gst; Gst.init(None)"

WORKDIR /config
EXPOSE 8337
VOLUME ["/config"]

HEALTHCHECK --interval=30s --timeout=5s --start-period=20s --retries=3 \
  CMD beet version >/dev/null || exit 1

ENTRYPOINT ["/entrypoint.sh"]
CMD ["web"]
