# Ambiente de teste do Lucerna: Arch + Hyprland + Quickshell.
# O Hyprland roda aninhado, como uma janela na sessão Wayland do host.

# O lucernad (o daemon do Lucerna), compilado na revisão de dev/lucernad.rev
# (o dev/run.sh e o dev/test.sh passam LUCERNAD_REV). Num estágio à parte,
# para a imagem final não levar a toolchain do Rust. O módulo de espectro liga
# na libpipewire (o bindgen dela precisa do clang e do pkgconf).
FROM archlinux:latest AS lucernad
ARG LUCERNAD_REV
RUN pacman -Syu --noconfirm --needed rustup git gcc libpipewire clang pkgconf
COPY lucernad.sh /tmp/
RUN bash /tmp/lucernad.sh "$LUCERNAD_REV" /opt/lucernad

FROM archlinux:latest

# mpv e mpv-mpris só servem para testar a aba Mídia (um player MPRIS). A
# libpipewire é do lucernad (o módulo de espectro). O ffmpeg e o Qt Multimedia
# (com o driver VA-API da Intel) são dos wallpapers em vídeo. O python-gobject
# é do logind falso (ci/logind-fake.py); o lua, dos testes da config Lua da
# sessão (session/hypr/tests).
RUN pacman -Syu --noconfirm --needed \
        hyprland quickshell \
        qt6-svg qt6-imageformats qt6-5compat \
        mesa vulkan-intel \
        qt6-multimedia qt6-multimedia-ffmpeg intel-media-driver libva-utils \
        dbus kitty foot htop grim libnotify wtype \
        libpipewire wireplumber hyprsunset wf-recorder \
        ttf-material-symbols-variable ttf-jetbrains-mono-nerd ttf-cascadia-code-nerd noto-fonts noto-fonts-emoji \
        mpv mpv-mpris ffmpeg \
        python-gobject lua \
        hicolor-icon-theme adwaita-icon-theme \
    && pacman -Scc --noconfirm

# A etiqueta diz de que revisão é o binário: o dev/run.sh e o dev/test.sh
# reconstroem a imagem quando ela difere de dev/lucernad.rev.
ARG LUCERNAD_REV
LABEL lucernad.rev=$LUCERNAD_REV
COPY --from=lucernad /opt/lucernad/bin/lucernad /opt/lucernad/bin/lucernad-selecao /usr/bin/

# Senha do usuário "dev" para testar a tela de bloqueio (PAM): lucerna
ARG UID=1000
ARG GID=1000
RUN groupadd -g "$GID" dev \
    && useradd -m -u "$UID" -g "$GID" -s /bin/bash dev \
    && echo 'dev:lucerna' | chpasswd \
    && install -d -m 0700 -o "$UID" -g "$GID" "/run/user/$UID" \
    && install -d -o "$UID" -g "$GID" /home/dev/.config/quickshell /home/dev/.config/hypr

USER dev
ENV USER=dev \
    XDG_RUNTIME_DIR=/run/user/1000 \
    XDG_SESSION_TYPE=wayland \
    QT_QPA_PLATFORM=wayland \
    LANG=pt_BR.UTF-8 \
    QS_ICON_THEME=Adwaita
WORKDIR /home/dev

CMD ["dbus-run-session", "start-hyprland"]

# O sha256 deste arquivo: o dev/run.sh e o dev/test.sh reconstroem a imagem
# quando ele difere (um pacote novo aqui chega sem o --build). No fim, para a
# etiqueta não invalidar o cache das camadas de cima.
ARG DOCKERFILE_SHA
LABEL dockerfile.sha=$DOCKERFILE_SHA
