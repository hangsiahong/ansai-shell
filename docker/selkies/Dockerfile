# ansai shell in a browser, streamed as H.264 video over one HTTP port by Selkies (CPU encoding; a GPU is used when /dev/dri is passed in).
# Xvfb (Selkies) → niri nested in it (winit) → the shell. Only the repo is copied here, so a code change rebuilds in seconds:
#   docker build -f docker/selkies/Dockerfile -t ansai-web .     run: docker run -p 8080:8080 -e GATE_PASSWORD=… ansai-web
ARG BASE=ansai-web-base:selkies-1
FROM ${BASE}
# Sign-in gate on :8080 (docker/selkies/gate.mjs) in front of Selkies' :3000; publish 8080.
RUN d=/etc/s6-overlay/s6-rc.d/svc-gate && mkdir -p $d/dependencies.d && echo longrun > $d/type && touch $d/dependencies.d/init-services \
    && printf '#!/usr/bin/with-contenv bash\nexec s6-setuidgid abc node /opt/ansai-shell/docker/selkies/gate.mjs\n' > $d/run && chmod +x $d/run \
    && touch /etc/s6-overlay/s6-rc.d/user/contents.d/svc-gate
# ansai (the agent control room), latest upstream main: this layer rebuilds only when main moves.
ADD --chown=abc:abc https://github.com/hangsiahong/ansai.git#main /opt/ansai
RUN cd /opt/ansai && s6-setuidgid abc bun install --frozen-lockfile && chown -R abc:abc /opt/ansai
COPY --chown=abc:abc . /opt/ansai-shell
COPY docker/selkies/startwm.sh /defaults/startwm.sh
ENV TITLE="ansai shell" TZ=Asia/Phnom_Penh QS_ICON_THEME=Papirus GSK_RENDERER=cairo \
    SELKIES_ENABLE_RESIZE=true SELKIES_VIDEO_CRF=20 \
    SELKIES_FRAMERATE=30 SELKIES_AUDIO_ENABLED=false SELKIES_ENABLE_CLIPBOARD=in \
    HARDEN_DESKTOP=true NO_GAMEPAD=true NO_WEBCAM=true
EXPOSE 8080
