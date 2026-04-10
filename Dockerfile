# ---- Stage 1: Get OneDrive binary from official image ----
FROM driveone/onedrive:edge AS onedrive-src

# ---- Stage 2: Main image ----
FROM ubuntu:24.04

# Global environment -- inherited by all s6 services
ENV DEBIAN_FRONTEND=noninteractive \
    DISPLAY=:99 \
    PUID=1000 \
    PGID=1000

# ---- System packages ----
RUN apt-get update && apt-get install -y --no-install-recommends \
    xvfb \
    libgtk-3-0 \
    libnss3 \
    libxss1 \
    libasound2t64 \
    libgbm1 \
    libsecret-1-0 \
    libdrm2 \
    wget \
    ca-certificates \
    xz-utils \
    jq \
    gosu \
    procps \
    && rm -rf /var/lib/apt/lists/*

# ---- Verify gosu works ----
RUN gosu nobody true

# ---- s6-overlay v3 ----
ARG S6_OVERLAY_VERSION=3.2.0.2
ADD https://github.com/just-containers/s6-overlay/releases/download/v${S6_OVERLAY_VERSION}/s6-overlay-noarch.tar.xz /tmp
ADD https://github.com/just-containers/s6-overlay/releases/download/v${S6_OVERLAY_VERSION}/s6-overlay-x86_64.tar.xz /tmp
RUN tar -C / -Jxpf /tmp/s6-overlay-noarch.tar.xz \
    && tar -C / -Jxpf /tmp/s6-overlay-x86_64.tar.xz \
    && rm /tmp/s6-overlay-*.tar.xz

# ---- Obsidian AppImage ----
# NOTE: Update OBSIDIAN_VERSION and OBSIDIAN_SHA256 when upgrading
# To get the SHA256: wget the AppImage, then run sha256sum on it
ARG OBSIDIAN_VERSION=1.12.7
ARG OBSIDIAN_SHA256=TO_BE_COMPUTED_ON_FIRST_BUILD
RUN wget -q "https://github.com/obsidianmd/obsidian-releases/releases/download/v${OBSIDIAN_VERSION}/Obsidian-${OBSIDIAN_VERSION}.AppImage" \
        -O /tmp/obsidian.AppImage \
    && if [ "${OBSIDIAN_SHA256}" != "TO_BE_COMPUTED_ON_FIRST_BUILD" ]; then \
        echo "${OBSIDIAN_SHA256}  /tmp/obsidian.AppImage" | sha256sum -c -; \
    fi \
    && chmod +x /tmp/obsidian.AppImage \
    && cd /tmp && ./obsidian.AppImage --appimage-extract \
    && mv /tmp/squashfs-root /opt/obsidian \
    && chmod -R o+rX /opt/obsidian \
    && ln -s /opt/obsidian/obsidian /usr/local/bin/obsidian \
    && rm -f /tmp/obsidian.AppImage

# ---- OneDrive client (copied from official Docker image) ----
COPY --from=onedrive-src /usr/local/bin/onedrive /usr/local/bin/onedrive
# Copy required runtime libraries from onedrive image
RUN apt-get update \
    && apt-get install -y --no-install-recommends \
        libcurl4 \
        libsqlite3-0 \
        libgcc-s1 \
    && rm -rf /var/lib/apt/lists/*

# ---- Create user and directories ----
# Handle case where UID/GID 1000 already exists (e.g., ubuntu user)
RUN if getent group 1000 >/dev/null; then groupmod -n obsidian $(getent group 1000 | cut -d: -f1); \
    else groupadd -g 1000 obsidian; fi \
    && if getent passwd 1000 >/dev/null; then \
        usermod -l obsidian -d /home/obsidian -m -s /bin/bash $(getent passwd 1000 | cut -d: -f1); \
    else useradd -u 1000 -g 1000 -m -s /bin/bash obsidian; fi \
    && mkdir -p /vault /onedrive-conf /home/obsidian/.config/obsidian

# ---- Copy s6 service definitions ----
COPY s6-overlay/s6-rc.d /etc/s6-overlay/s6-rc.d

# ---- Copy scripts and set permissions ----
COPY scripts/entrypoint.sh /scripts/entrypoint.sh
COPY scripts/healthcheck.sh /scripts/healthcheck.sh
RUN chmod +x /scripts/entrypoint.sh /scripts/healthcheck.sh \
    && chmod +x /etc/s6-overlay/s6-rc.d/svc-xvfb/run \
    && chmod +x /etc/s6-overlay/s6-rc.d/svc-xvfb/finish \
    && chmod +x /etc/s6-overlay/s6-rc.d/svc-obsidian/run \
    && chmod +x /etc/s6-overlay/s6-rc.d/svc-obsidian/finish \
    && chmod +x /etc/s6-overlay/s6-rc.d/svc-onedrive/run \
    && chmod +x /etc/s6-overlay/s6-rc.d/svc-onedrive/finish

# ---- Copy config templates ----
COPY config/ /defaults/config/
COPY claude-md/CLAUDE.md /defaults/CLAUDE.md

# ---- Healthcheck ----
HEALTHCHECK --interval=60s --timeout=10s --retries=3 --start-period=60s \
    CMD /scripts/healthcheck.sh

# ---- s6-overlay entrypoint ----
ENTRYPOINT ["/init"]
