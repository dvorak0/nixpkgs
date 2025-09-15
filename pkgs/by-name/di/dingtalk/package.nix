{
  fetchurl,
  stdenv,
  autoPatchelfHook,
  makeWrapper,
  lib,
  alsa-lib,
  apr,
  aprutil,
  at-spi2-atk,
  at-spi2-core,
  cups,
  gtk3,
  libpulseaudio,
  gnome2,
  mesa,
  nspr,
  nss,
  qt5,
  xorg,
  dpkg,
  libsForQt5,
  imagemagick,
  gtk2-x11,
  gdk-pixbuf,
  cairo,
  curl,
  dbus,
  e2fsprogs,
  fontconfig,
  freetype,
  fribidi,
  glib,
  gnutls,
  graphite2,
  harfbuzz,
  icu63,
  krb5,
  libdrm,
  libgcrypt,
  libGLU,
  libglvnd,
  libidn2,
  libinput,
  libjpeg,
  libpng,
  libpsl,
  libssh2,
  libthai,
  libxcrypt-legacy,
  libxkbcommon,
  mtdev,
  nghttp2,
  openldap,
  pango,
  pcre2,
  rtmpdump,
  udev,
  util-linux,
  gst_all_1,
}:
stdenv.mkDerivation (finalAttrs: {
  pname = "dingtalk";
  version = "7.6.45.5062501";

  src =
    let
      selectSystem =
        attrs:
        attrs.${stdenv.hostPlatform.system}
          or (throw "dingtalk: ${stdenv.hostPlatform.system} is not supported");
      arch = selectSystem {
        x86_64-linux = "amd64";
        aarch64-linux = "arm64";
      };
    in
    fetchurl {
      url = "https://dtapp-pub.dingtalk.com/dingtalk-desktop/xc_dingtalk_update/linux_deb/Release/com.alibabainc.dingtalk_${finalAttrs.version}_${arch}.deb";
      hash = selectSystem {
        x86_64-linux = "sha256-49pmBducAxUy7ZqQg+tdDquFeR+lJczpcF8m+VvhIo8=";
        aarch64-linux = "sha256-ebIKFfJ8s3w0yGXapTWYtPSz8QgLsN6ujj2k9mQFR2k=";
      };
    };

  nativeBuildInputs = [
    autoPatchelfHook
    makeWrapper
    qt5.wrapQtAppsHook
    dpkg
    imagemagick
  ];
  # IMPORTANT: autoPatchelfHook searches buildInputs for required SONAMEs.
  # Put all the needed libs here so patching succeeds.
  buildInputs = [
    # Audio / desktop basics
    alsa-lib
    libpulseaudio
    nss
    nspr
    cups
    at-spi2-core
    at-spi2-atk
    gtk3
    gtk2-x11
    gdk-pixbuf
    cairo
    pango
    fribidi
    graphite2
    harfbuzz
    fontconfig
    freetype
    glib

    # Curl & TLS deps (DingTalk bundle expects these backends present)
    curl
    gnutls
    krb5
    libidn2
    libpsl
    libssh2
    nghttp2
    openldap       # provides libldap_r-2.4.so.2 and liblber-2.4.so.2
    rtmpdump       # provides librtmp.so.1

    # Low-level bits
    e2fsprogs.out  # provides libcom_err.so.2 (not in e2fsprogs default output)
    libxcrypt-legacy  # provides libcrypt.so.1
    libgcrypt         # provides libgcrypt.so.20

    # GL / X11 stack including gtkglext deps
    mesa
    libglvnd
    libGLU            # provides libGLU.so.1
    xorg.libXmu       # provides libXmu.so.6
    gnome2.gtkglext
    xorg.libICE xorg.libSM xorg.libX11 xorg.libxcb
    xorg.libXcomposite xorg.libXcursor xorg.libXdamage xorg.libXext
    xorg.libXfixes xorg.libXi xorg.libXinerama xorg.libXrandr xorg.libXrender
    xorg.libXScrnSaver xorg.libXt xorg.libXtst
    xorg.xcbutilimage xorg.xcbutilkeysyms xorg.xcbutilrenderutil xorg.xcbutilwm

    # PangoX compatibility for old gtkglext consumers
    pangox-compat     # provides libpangox-1.0.so.0

    # Misc used in wrapper
    icu63
    libjpeg
    libpng
    libthai
    libinput
    mtdev
    util-linux
    udev
    pcre2
    dbus
    libdrm
  ]
  ++ lib.optionals stdenv.hostPlatform.isAarch64 [
    gst_all_1.gstreamer
    gst_all_1.gst-plugins-base
    gst_all_1.gst-plugins-good
    gst_all_1.gst-plugins-bad
    gst_all_1.gst-libav
  ];

  dontWrapQtApps = true;

  installPhase = ''
    runHook preInstall
    mkdir -p $out/app $out/share/pixmaps
    cp -r opt/apps/com.alibabainc.dingtalk/files/*-Release.* $out/app/dingtalk
    rm -f $out/app/dingtalk/{dingtalk_crash_report,dingtalk_updater}
    rm -f $out/app/dingtalk/*.a $out/app/dingtalk/*.la
    rm -rf $out/app/dingtalk/Resources/i18n/tool/*.exe
    rm -f $out/app/dingtalk/libstdc++.so.*
    install -Dm644 usr/share/applications/com.alibabainc.dingtalk.desktop $out/share/applications/dingtalk.desktop
    magick "opt/apps/com.alibabainc.dingtalk/files/logo.ico" $out/share/pixmaps/dingtalk.png
    substituteInPlace $out/share/applications/dingtalk.desktop \
      --replace-fail "/opt/apps/com.alibabainc.dingtalk/files/Elevator.sh" "dingtalk" \
      --replace-fail "/opt/apps/com.alibabainc.dingtalk/files/logo.ico" "dingtalk"
    cp -r opt/apps/com.alibabainc.dingtalk/files/doc $out/share/doc
    runHook postInstall
  '';

  preFixup = ''
    makeWrapper $out/app/dingtalk/com.alibabainc.dingtalk $out/bin/dingtalk \
      ''${qtWrapperArgs[@]} \
      --argv0 com.alibabainc.dingtalk \
      --chdir $out/app/dingtalk \
      --set QT_QPA_PLATFORM "wayland;xcb" \
      --set QT_AUTO_SCREEN_SCALE_FACTOR 1 \
      --prefix LD_PRELOAD : $out/app/dingtalk/plugins/dtwebview/libcef.so \
      --prefix LD_LIBRARY_PATH : ${
        lib.makeLibraryPath [
          (lib.getLib stdenv.cc.cc)
          mesa
          apr
          aprutil
          libsForQt5.qtmultimedia
          libsForQt5.qtbase
          libsForQt5.qtx11extras
          libsForQt5.qtsvg
          gdk-pixbuf
          alsa-lib
          at-spi2-atk
          at-spi2-core
          cairo
          cups
          curl
          dbus
          e2fsprogs
          fontconfig
          freetype
          fribidi
          glib
          gnutls
          graphite2
          gtk3
          harfbuzz
          icu63
          krb5
          libdrm
          libgcrypt
          libGLU
          libglvnd
          libidn2
          libinput
          libjpeg
          libpng
          libpsl
          libpulseaudio
          libssh2
          gnome2.gtkglext
          libthai
          libxcrypt-legacy
          libxkbcommon
          mtdev
          nghttp2
          nspr
          nss
          openldap
          pango
          pcre2
          rtmpdump
          udev
          util-linux
          xorg.libICE
          xorg.libSM
          xorg.libX11
          xorg.libxcb
          xorg.libXcomposite
          xorg.libXcursor
          xorg.libXdamage
          xorg.libXext
          xorg.libXfixes
          xorg.libXi
          xorg.libXinerama
          xorg.libXmu
          xorg.libXrandr
          xorg.libXrender
          xorg.libXScrnSaver
          xorg.libXt
          xorg.libXtst
          xorg.xcbutilimage
          xorg.xcbutilkeysyms
          xorg.xcbutilrenderutil
          xorg.xcbutilwm
        ]
      }
  '';

  meta = {
    description = "Alibaba Enterprise Communication Collaboration Platform";
    homepage = "https://www.dingtalk.com";
    license = lib.licenses.unfree;
    platforms = [
      "x86_64-linux"
      "aarch64-linux"
    ];
    sourceProvenance = with lib.sourceTypes; [ binaryNativeCode ];
    maintainers = with lib.maintainers; [ nyxvectar ];
    mainProgram = "dingtalk";
  };
})
