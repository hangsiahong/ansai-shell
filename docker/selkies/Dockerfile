# ansai shell in a browser, streamed as H.264 video over one HTTP port by Selkies (CPU encoding; a GPU is used when /dev/dri is passed in).
# Xvfb (Selkies) → niri nested in it (winit) → the shell. Only the repo is copied here, so a code change rebuilds in seconds:
#   docker build -f docker/selkies/Dockerfile -t ansai-web .     run: docker run -p 8080:3000 ansai-web
ARG BASE=ansai-web-base:selkies-1
FROM ${BASE}
COPY --chown=abc:abc . /opt/ansai-shell
COPY docker/selkies/startwm.sh /defaults/startwm.sh
ENV TITLE="ansai shell" TZ=Asia/Phnom_Penh QS_ICON_THEME=Papirus GSK_RENDERER=cairo \
    SELKIES_ENABLE_RESIZE=true SELKIES_VIDEO_CRF=20 \
    SELKIES_FRAMERATE=30 SELKIES_AUDIO_ENABLED=false SELKIES_ENABLE_CLIPBOARD=in \
    HARDEN_DESKTOP=true NO_GAMEPAD=true NO_WEBCAM=true
EXPOSE 3000
