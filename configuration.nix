NixOS-конфигурация для ноутбука:
  CPU: AMD Ryzen 5 5600H (Cezanne, 6C/12T)
  GPU0: NVIDIA GTX 1650 Mobile (TU117, 01:00.0) — только рендер (PRIME offload)
  GPU1: AMD Cezanne Vega  (05:00.0) — ведущий драйвер отображения (eDP-1, HDMI-A-1)
  Экран: 1920x1080@120, Wi-Fi MT7921, Realtek RTL8111, NVMe 1 ТБ

Подход: всё из готовых бинарников (cache.nixos.org), никакой локальной
компиляции. См. README.md.
{ config, pkgs, lib, ... }:
  freesm-launcher = pkgs.appimageTools.wrapType2 {
    pname = "freesm-launcher";
    version = "2.2.1";
    src = pkgs.fetchurl {
      url = "https://github.com/FreesmTeam/FreesmLauncher/releases/download/2.2.1/FreesmLauncher-Linux-x86_64.AppImage";
      hash = "sha256-C9LnuT+3b8Ot1bjViNeVghdFi5ZBwOXWwiagTNpxDcI=";
    };
  };
in
{
  imports = [ ./hardware-configuration.nix ];

  # ===================== Nix =====================
  nix.settings = {
    experimental-features = [ "nix-command" "flakes" ];
    auto-optimise-store = true;
  };
  nixpkgs.config.allowUnfree = true;
  services.udisks2.enable = true;
  security.polkit.enable = true;
  # ===================== Загрузчик =====================
  # В CachyOS стоял Limine; для NixOS — стандартный systemd-boot.
  # (Если захочешь Limine: boot.loader.limine.enable = true вместо строк ниже.)
  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;
  boot.loader.systemd-boot.configurationLimit = 2; # в меню только 2 последних поколения

  # ===================== Своп =====================
  zramSwap.enable = true;
  zramSwap.memoryPercent = 100;

  # ===================== Локаль и время =====================
  time.timeZone = "Europe/Moscow";
  i18n.defaultLocale = "ru_RU.UTF-8";
  i18n.extraLocaleSettings = {
    LC_ADDRESS = "ru_RU.UTF-8";
    LC_IDENTIFICATION = "ru_RU.UTF-8";
    LC_MEASUREMENT = "ru_RU.UTF-8";
    LC_MONETARY = "ru_RU.UTF-8";
    LC_NAME = "ru_RU.UTF-8";
    LC_NUMERIC = "ru_RU.UTF-8";
    LC_PAPER = "ru_RU.UTF-8";
    LC_TELEPHONE = "ru_RU.UTF-8";
    LC_TIME = "ru_RU.UTF-8";
  };
  console.keyMap = "us";

  # ===================== Сеть и Bluetooth =====================
  networking.hostName = "cachy";
  networking.networkmanager.enable = true;
  hardware.bluetooth.enable = true;
  hardware.bluetooth.powerOnBoot = true;

  # ===================== Сервисы, нужные Noctalia =====================
  services.power-profiles-daemon.enable = true;
  services.upower.enable = true;

  # ===================== Аудио =====================
  services.pipewire = {
    enable = true;
    alsa.enable = true;
    pulse.enable = true; # совместимость со старыми приложениями (PulseAudio API)
  };
  security.rtkit.enable = true;
  # services.pipewire.alsa.support32Bit намеренно НЕ включаем:
  # 32-битные пакеты не нужны, это увело бы сборки под i686.

  # ===================== Графика =====================
  # AMD iGPU (05:00.0) рисует на экран, NVIDIA (01:00.0) — рендер по запросу.
  services.xserver.videoDrivers = [ "nvidia" ]; # включает модуль hardware.nvidia

  hardware.nvidia = {
    modesetting.enable = true;
    open = true; # open-модули обязательны для драйвера >= 560; GTX 1650 (Turing) поддерживает
    powerManagement.enable = true; # корректное выключение GPU на ноутбуке
    videoAcceleration = true; # добавляет nvidia-vaapi-driver (аппаратное декодирование)
    nvidiaSettings = false;
    prime = {
      offload.enable = true;
      offload.enableOffloadCmd = true; # команда `nvidia-offload <программа>`
      amdgpuBusId = "PCI:5@0:0:0"; # 05:00.0 — AMD Cezanne Vega
      nvidiaBusId = "PCI:1@0:0:0"; # 01:00.0 — NVIDIA GTX 1650
    };
  };

  hardware.graphics.enable = true; # OpenGL/Vulkan (mesa + NVIDIA)

  # ===================== Дисплейный менеджер =====================
  services.displayManager.sddm = {
    enable = true;
    wayland.enable = true; # без него срабатывает assertion модуля sddm
    theme = "sddm-astronaut-theme"; # тема из пакета sddm-astronaut (см. ниже)
  };

  # ===================== niri + XWayland =====================
  programs.niri.enable = true; # сессия niri + xdg-порталы + gnome-keyring
  programs.xwayland.enable = true;

  # Системные конфиги niri и Noctalia (fallback).
  # Пользовательские ~/.config/niri и ~/.config/noctalia имеют приоритет.
  environment.etc = {
    "niri/config.kdl".source = ./niri/config.kdl;
    "niri/noctalia.kdl".source = ./niri/noctalia.kdl;
    "xdg/noctalia/config.toml".source = ./noctalia/config.toml;
  };

  # ===================== Шрифты =====================
  fonts.packages = with pkgs; [
    noto-fonts
    noto-fonts-lgc-plus # латиница/кириллица/греческий
    noto-fonts-cjk-sans
    noto-fonts-color-emoji
    adwaita-fonts # шрифт "Adwaita Sans" из конфига Noctalia
  ];

  # ===================== Пакеты =====================
  environment.systemPackages = with pkgs; [
    # --- из списка задачи ---
    noctalia # панель/оболочка (запускается из конфига niri)
    sddm-astronaut # тема SDDM (имя темы: sddm-astronaut-theme)
    firefox
    telegram-desktop
    vim
    mpv
    (obs-studio.override { cudaSupport = true; }) # NVENC: патчит runpath у obs-nvenc-test (nixpkgs #382666)
    ghostty
    kdePackages.dolphin
    ffmpeg # NVENC/VAAPI включены по умолчанию; CUDA не требуется
    btop
    freesm-launcher # AppImage, оборачивается локально (без компиляции)
    fastfetch
    # --- Java для Freesm Launcher / Minecraft ---
    jdk21
    opencode
    # --- используются в конфигах niri/noctalia ---
    git # нужен для работы с flake
    xwayland-satellite # X11-приложения под niri (spawn-at-startup)
    playerctl # мультимедиа-клавиши (binds в niri)
    brightnessctl # яркость экрана (binds в niri)
    wl-clipboard # буфер обмена Wayland (Super+V у Noctalia)
    grim # скриншоты
    slurp # выбор области для скриншотов
    mpvpaper # плагин Noctalia noctalia/mpvpaper (видео-обои)
    xdg-utils
    desktop-file-utils
    libnotify # уведомления
  ];

  # ===================== Прочее =====================
  # Telegram и другие Electron-приложения в Wayland-режиме
  environment.sessionVariables.NIXOS_OZONE_WL = "1";

  services.fstrim.enable = true; # TRIM для NVMe
  programs.dconf.enable = true;

  # ===================== Пользователь =====================
  users.users.ayone = {
    isNormalUser = true;
    description = "ayone";
    extraGroups = [ "wheel" "networkmanager" "video" "audio" "input" ];
  };

  system.stateVersion = "26.05";
}
