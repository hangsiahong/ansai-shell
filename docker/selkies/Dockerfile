# ansai shell in a browser, streamed as H.264 video over one HTTP port by Selkies (CPU encoding; a GPU is used when /dev/dri is passed in).
# Xvfb (Selkies) → niri nested in it (winit) → the shell. Only the repo is copied here, so a code change rebuilds in seconds:
#   docker build -f docker/selkies/Dockerfile -t ansai-web .     run: docker run -p 8080:8080 -e GATE_PASSWORD=… ansai-web
ARG BASE=ansai-web-base:selkies-1
FROM ${BASE}
# Started by run.sh, not the base's s6 /init, so it runs as any user (KOOMPI Cloud picks a non-root one).
RUN chmod 666 /etc/passwd && chmod 1777 /config \
    && rm -rf /usr/share/selkies/web && cp -a /usr/share/selkies/selkies-dashboard /usr/share/selkies/web \
    && cp /usr/share/selkies/www/icon.png /usr/share/selkies/web/favicon.ico && cp /usr/share/selkies/www/icon.png /usr/share/selkies/web/icon.png
# ansai (the agent control room), latest upstream main: this layer rebuilds only when main moves.
ADD --chown=abc:abc https://github.com/hangsiahong/ansai.git#main /opt/ansai
RUN cd /opt/ansai && s6-setuidgid abc bun install --frozen-lockfile && chown -R abc:abc /opt/ansai
COPY --chown=abc:abc . /opt/ansai-shell
COPY docker/selkies/startwm.sh /defaults/startwm.sh
COPY docker/selkies/run.sh /usr/local/bin/ansai-web
ENV TITLE="ansai shell" TZ=Asia/Phnom_Penh QS_ICON_THEME=Papirus GSK_RENDERER=cairo \
    SELKIES_ENABLE_RESIZE=true SELKIES_USE_CSS_SCALING="true|locked" SELKIES_VIDEO_CRF=20 SELKIES_ENCODER=h264enc \
    SELKIES_FRAMERATE=30 SELKIES_AUDIO_ENABLED=false SELKIES_ENABLE_CLIPBOARD=in \
    SELKIES_GAMEPAD_ENABLED=false SELKIES_FILE_TRANSFERS="" SELKIES_COMMAND_ENABLED=false \
    SELKIES_UI_SIDEBAR_SHOW_FILES=false SELKIES_UI_SIDEBAR_SHOW_APPS=false SELKIES_UI_SIDEBAR_SHOW_GAMEPADS=false
EXPOSE 8080
ENTRYPOINT ["/usr/local/bin/ansai-web"]
