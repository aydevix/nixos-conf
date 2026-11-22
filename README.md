NixOS-конфигурация для этого ноутбука

Железо: **AMD Ryzen 5 5600H · NVIDIA GTX 1650 Mobile + AMD iGPU (Cezanne) ·
13 ГБ RAM · NVMe 1 ТБ · Wi-Fi MT7921 · экран 1920×1080@120**.

Всё ПО собирается из **готовых бинарников** бинарного кэша
`cache.nixos.org` (закреплённая ревизия `nixpkgs-unstable`
`9996594bd380…` — на ней проверено наличие всех пакетов), без локальной
компиляции.

Состав

| Компонент | Как реализован |
|---|---|
| niri 26.04 | `programs.niri.enable` (порталы, gnome-keyring, сессия по умолчанию) |
| Noctalia 5.5.0 | пакет + автозапуск `spawn-at-startup "noctalia"` в конфиге niri; конфиги в `/etc/niri/` и `/etc/xdg/noctalia/` |
| SDDM + тема astronaut | `services.displayManager.sddm` (`wayland.enable`, `theme = "sddm-astronaut-theme"`), пакет `sddm-astronaut` |
| NVIDIA PRIME offload | `hardware.nvidia.prime.offload` (AMD `PCI:5@0:0:0`, NVIDIA `PCI:1@0:0:0`), open-модули, `modesetting` |
| Telegram, Firefox, Vim, mpv, OBS, Ghostty, Dolphin, ffmpeg, btop | пакеты из канала |
| Freesm Launcher | официальный AppImage 2.2.1 + `appimageTools.wrapType2` (распаковка, не сборка) |

Про CUDA / NVENC (важно)

Глобальный флаг `nixpkgs.config.cudaSupport = true` **не включался**:
он пересобирает `obs-studio` и `ffmpeg` локально (их бинарников в кэше
тогда не будет). Аппаратное кодирование NVENC при этом **работает**:

- `ffmpeg` собран с `--enable-nvenc`/`--enable-nvdec` (динамическая
  линковка `nv-codec-headers`, CUDA не нужна);
- `obs-studio` собран с `nv-codec-headers-12` и прогоняет
  `addDriverRunpath` по своим `.so` — кодировщики NVIDIA в OBS доступны;
- `hardware.nvidia.videoAcceleration = true` подключает
  `nvidia-vaapi-driver`, плюс VAAPI AMD (radeonsi) для встроенного
  видео в браузере.

Если когда-нибудь понадобится настоящий CUDA — придётся добавить
`nixpkgs.config.cudaSupport = true` и смириться с локальной сборкой
нужных пакетов.

Файлы

```
nixos-config/
├── flake.nix                  # пин nixpkgs, nixosConfigurations.cachy
├── configuration.nix          # весь соф t и сервисы
├── hardware-configuration.nix # диски (UUID), initrd, микрокод
├── niri/
│   ├── config.kdl             # ваш текущий конфиг niri (перенесён как есть)
│   └── noctalia.kdl           # его часть с цветами (включается через include)
└── noctalia/
    └── config.toml            # ваш текущий конфиг Noctalia
```

Системные конфиги кладутся в `/etc/niri/` и `/etc/xdg/noctalia/` — это
fallback: если в `~/.config/niri/` и `~/.config/noctalia/` уже есть
файлы (домашняя папка сохраняется), используются они.

Установка

1. **Отключи Secure Boot** в BIOS (иначе загрузчик не подпишется) и
   скачай NixOS Minimal ISO (x86_64) с <https://nixos.org/download>,
   запиши на флешку.
2. Загрузись с флешки, подключи сеть (`iwctl` или `nmtui`).
3. **Разметка** — два варианта:

   **A. Стереть CachyOS** (корень — p2, 401 ГБ):
   ```bash
   mkfs.ext4 -L nixos /dev/nvme0n1p2      # ⚠ стирает данные CachyOS
   mount /dev/nvme0n1p2 /mnt
   mount --mkdir /dev/nvme0n1p1 /boot      # EFI общий, не трогаем
   ```

   **B. Поставить NixOS на пустой раздел p3 (200 ГБ), CachyOS сохранить:**
   ```bash
   mkfs.ext4 -L nixos /dev/nvme0n1p3
   mount /dev/nvme0n1p3 /mnt
   mount --mkdir /dev/nvme0n1p1 /boot
   ```
   В варианте B UUID корня будет **новым** — сгенерируй
   `hardware-configuration.nix` сам:
   ```bash
   nixos-generate-config --root /mnt
   ```

4. **Скопируй этот каталог** (`flake.nix`, `configuration.nix`,
   `hardware-configuration.nix`, `niri/`, `noctalia/`) в `/mnt/etc/nixos/`
   (на флешке, через `git clone` и т.п.). В варианте B оставь
   сгенерированный `hardware-configuration.nix`, остальное замени.
5. Установка:
   ```bash
   nixos-install --flake /mnt/etc/nixos#cachy
   ```
   Затем задай пароль пользователя (root-пароль спросит установщик):
   ```bash
   nixos-enter --root /mnt -c 'passwd ayone'
   ```
6. Перезагрузка, сними флешку.

После установки

```bash
sudo nixos-rebuild switch --flake /etc/nixos#cachy   # применение изменений
```

Проверка, что всё скачивается, а не собирается:

```bash
nix build --dry-run /etc/nixos#nixosConfigurations.cachy.config.system.build.toplevel
```

в выводе не должно быть строк `will be built` для пакетов из списка
(допустимо `will be built` только для самого замка системы/`buildEnv`
и для FHS-обёртки Freesm — они не компилируют исходники).

Что обычно захочется поменять

- Часовой пояс — `time.timeZone` в `configuration.nix`.
- Раскладка — `input.keyboard.xkb` в `niri/config.kdl`
  (сейчас `us,ru` + переключение Win+Space).
- Разрешение/частота экрана — блок `output "eDP-1"` в `niri/config.kdl`.
- Обои/панель — `noctalia/config.toml` (папка обоев:
  `~/.config/niri/wallpapers`).
- Загрузчик — сейчас systemd-boot; для Limine (как в CachyOS):
  ```nix
  boot.loader.systemd-boot.enable = false;
  boot.loader.limine.enable = true;
  ```
 
