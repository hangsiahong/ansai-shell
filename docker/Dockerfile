# ansai shell in a browser: Xvfb (software screen) → niri (nested, winit) → the shell, streamed with x11vnc + noVNC.
# No GPU: everything draws with Mesa llvmpipe. Only the repo is copied here, so a code change rebuilds in seconds:
#   docker build -f docker/Dockerfile -t ansai-web .
ARG BASE=ansai-web-base:1
FROM ${BASE}
COPY --chown=ansai:ansai . /opt/ansai-shell
COPY docker/start.sh /usr/local/bin/ansai-web
USER ansai
ENV HOME=/home/ansai XDG_RUNTIME_DIR=/tmp/xdg PORT=8080 GEOMETRY=1280x800 TZ=Asia/Phnom_Penh \
    QS_ICON_THEME=Papirus GSK_RENDERER=cairo
RUN cd /opt/ansai-shell && ./install.sh >/dev/null && rm -f ~/.config/niri/ansai-outputs.kdl \
    && printf '%s\n' '{"wallpaper": "/opt/ansai-shell/quickshell/assets/wallpapers/drift-dark.jpg", "style": "material", "accent": "purple", "barStats": false, "widgets": ["clock", "calendar", "weather"], "pinned": ["org.gnome.Nautilus", "org.gnome.TextEditor", "org.gnome.Calculator", "org.gnome.Loupe"]}' > ~/.config/ansai-shell/settings.json
EXPOSE 8080
CMD ["/usr/local/bin/ansai-web"]
