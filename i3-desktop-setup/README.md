# i3-desktop-setup

Установка лёгкого рабочего стола на базе **i3** поверх минимального консольного
**Debian Trixie** на **Raspberry Pi CM5** (arm64) — одной командой.

В комплекте:

- **i3** (оконный менеджер) с единой темой: цвета окон, бордюров и панели;
  аккуратные gaps и тонкие бордюры;
- терминал **Alacritty** + весь набор тем из
  [`alacritty/alacritty-theme`](https://github.com/alacritty/alacritty-theme)
  (по умолчанию — **Tokyo Night**);
- «готовый» десктоп: панель (i3status), лаунчер (rofi), композитор (picom),
  обои (feh/xsetroot), звук (PipeWire), сеть (NetworkManager + апплет), шрифты,
  скриншоты (maim), блокировка (i3lock), файловый менеджер (Thunar), темы GTK;
- **Claude Code** (официальный нативный установщик).

## Установка одной командой

> Запускайте **от обычного пользователя**, **без `sudo`** перед `curl`. Скрипт
> сам запросит права `sudo`, когда они понадобятся.

```bash
curl -fsSL https://raw.githubusercontent.com/Anaph/jubilant-doodle/main/i3-desktop-setup/bootstrap.sh | bash
```

По умолчанию: вход через **LightDM**, тема **Tokyo Night**, с установкой Claude Code.

### С опциями

Чтобы передать флаги через pipe, используйте форму `bash -s --`:

```bash
# Автологин в консоль + startx вместо LightDM, тема Nord, без Claude Code:
curl -fsSL https://raw.githubusercontent.com/Anaph/jubilant-doodle/main/i3-desktop-setup/bootstrap.sh \
  | bash -s -- --boot=startx --theme=nord --no-claude
```

| Флаг | Назначение | По умолчанию |
|------|------------|--------------|
| `--boot=lightdm\|startx` | Как запускается рабочий стол: графический вход (LightDM) или автологин в tty1 → `startx` → i3 | `lightdm` |
| `--theme=NAME` | Тема Alacritty. Имена `tokyo_night`, `catppuccin_mocha`, `gruvbox_dark`, `nord` темизируют **и сам i3** | `tokyo_night` |
| `--no-claude` | Не устанавливать Claude Code | (ставится) |
| `--minimal` | Пропустить «необязательные» компоненты (picom, dunst, thunar, скриншоты и т.д.) | (полный) |
| `--yes` | Не задавать вопросов | — |

## Что происходит при установке

`bootstrap.sh` ставит `git`/`curl` (если их нет), клонирует репозиторий в
`~/.local/share/jubilant-doodle` и запускает `install.sh`, который выполняет шаги
по порядку: проверки → apt-пакеты → Claude Code → темы Alacritty → раскладка
конфигов и темизация i3 → способ запуска → итог.

Повторный запуск **безопасен** (идемпотентность): пакеты apt не переустанавливаются
лишний раз, репозитории тем обновляются, строки в профиле не дублируются, а ваши
существующие конфиги сохраняются в `*.bak.<дата>` перед перезаписью.

## После установки

- **LightDM:** перезагрузитесь (`sudo reboot`) → на экране входа выберите сессию
  **i3** и войдите. Или запустите сразу: `sudo systemctl start lightdm`.
- **startx:** перезагрузитесь — вход в tty1 произойдёт автоматически и запустит i3.
  Или на tty1 выполните `startx`.

Базовые горячие клавиши (`Super` = клавиша Win):

| Клавиши | Действие |
|---------|----------|
| `Super+Return` | Alacritty (`Super+Shift+Return` — запасной xterm) |
| `Super+d` | лаунчер приложений (rofi) |
| `Super+Shift+b` | браузер (firefox-esr / x-www-browser) |
| `Super+Shift+q` | закрыть окно |
| `Super+1..0` | переключение рабочих столов |
| `Super+r` | режим изменения размера |
| `Super+Shift+x` | блокировка экрана |
| `Super+Shift+e` | выход из i3 |

Полный список — в `~/.config/i3/config`.

### Claude Code

Откройте **новый** терминал (чтобы подхватился `PATH`) и выполните `claude` для
входа в аккаунт. Если команда не найдена: `source ~/.profile`.

Установщик сначала пробует официальный нативный установщик, а если тот не дал
рабочий `claude` — автоматически ставит его через npm (`@anthropic-ai/claude-code`,
бинарь в `/usr/local/bin`). Отдельных действий не требуется.

## Устранение проблем

**Alacritty показывает чёрное окно или ошибку GL/EGL на Pi.**
GPU-контекст VideoCore иногда не создаётся. Раскомментируйте строку в
`~/.xsessionrc` (для LightDM) или `~/.xinitrc` (для startx):

```sh
export LIBGL_ALWAYS_SOFTWARE=1
```

и перезапустите сессию. До исправления используйте запасной терминал
`Super+Shift+Return` (xterm).

**Нужно отключить автологин/startx.** Переключитесь на другой VT
(`Ctrl+Alt+F2`), войдите и удалите
`/etc/systemd/system/getty@tty1.service.d/override.conf`, затем
`sudo systemctl daemon-reload`.

**Ошибка `dpkg`/`update-initramfs` (часто из-за Plymouth) на Pi/uConsole.**
Установщик чинит это сам: preflight обнаруживает «битое» состояние dpkg и, если
виноват Plymouth (загрузочная заставка, для десктопа не нужна), аккуратно удаляет
его и пересобирает initramfs — отдельных команд вводить не нужно, просто запустите
установку ещё раз. Если падение из-за нехватки места в `/boot/firmware` — в логе
будет `No space left`; помогает `sudo apt-get autoremove --purge`.

## Смена темы позже

```bash
~/.local/share/jubilant-doodle/i3-desktop-setup/install.sh --theme=catppuccin_mocha
```

Это перезапишет тему Alacritty и палитру i3 (для курируемого набора). Затем в i3:
`Super+Shift+r` (перезапуск i3) — изменения применятся.

## ClockworkPi uConsole (CM5)

Для uConsole есть опциональный модуль с правками под железо:

```bash
curl -fsSL https://raw.githubusercontent.com/Anaph/jubilant-doodle/main/i3-desktop-setup/bootstrap.sh \
  | bash -s -- --uconsole
```

Флаги: `--uconsole` (или алиас `--uconsole-signal`),
`--rotate=right|left|normal|inverted|skip` (поворот панели, по умолч. `right`).

**Что делает модуль (безопасная, десктопная часть):**
- поворот DSI-панели в landscape — и **на экране входа LightDM**, и в сессии i3
  (автоопределение выхода `DSI-*`; меняется `--rotate`);
- строка состояния на **i3blocks** (светлый текст на жёстко-тёмном баре): заряд
  батареи (AXP228), уровень 4G-сигнала донгла, CPU-график, диск, память, время;
  состояние сети — в трее (иконка nm-applet справа);
- **USB HiLink-модем** (Huawei E3372h): `usb-modeswitch` + udev-правило, чтобы
  ModemManager не перехватывал донгл (он подключается как обычная сетевая карта,
  NetworkManager поднимает DHCP сам);
- **энергосбережение** (подсветка — главный потребитель):
  - **кнопка питания → «сон»**: короткое нажатие гасит подсветку (бинд
    `XF86PowerOff` в i3 → `uconsole-bl-toggle` через `brightnessctl`), повторное
    нажатие — будит. DPMS на DSI-панели подсветку не гасит, поэтому используется
    `brightnessctl`. Долгое нажатие → выключение (`HandlePowerKeyLongPress`);
  - стартовая **яркость 60%** (клавиши яркости `XF86MonBrightness*` забиндены);
  - **CPU governor** `schedutil` закреплён сервисом `uconsole-cpufreq` (правится в
    `/usr/local/bin/uconsole-cpufreq` — можно `powersave` или потолок частоты);
  - **Bluetooth выключен** по умолчанию (`rfkill` + сервис), `bluez`/`blueman`
    остаются — включить: `sudo rfkill unblock bluetooth && sudo systemctl start bluetooth`;
  - `tlp` (USB-autosuspend off, чтобы не отрубать донгл), `zram`, `powertop`;
- увеличенные шрифты под 5″/720p.

> Сон по кнопке начинает работать **после перезагрузки** (logind перечитывает
> конфиг на старте) и нужен пользователь в группе `video` (добавляется
> установщиком). Блокировки при «сне» нет — это переключатель подсветки; если
> нужна блокировка-при-сне, скажи (сделаю отдельным демоном кнопки).

**AIO v2 (HackerGadgets) — флаг `--aio`.** Ставит **базовый пакет платы**
`hackergadgets-uconsole-aio-board` (GPIO/rails/RTC/`pinctrl`; если его apt-репо
не подключён — установщик предупредит) и клиент **`aiov2_ctl`** (из исходников
`github.com/hackergadgets/aiov2_ctl`): тумблеры GPS/LoRa/SDR/USB, телеметрия
питания, GUI-трей (автозапуск в i3), CLI (`aiov2_ctl --status`,
`aiov2_ctl <FEATURE> on|off`).

**Энергосбережение вручную** (firmware/железо — не автоматизирую):
- андерклок в `/boot/firmware/config.txt` — умеренно `arm_freq=1800 gpu_freq=500`,
  агрессивно `arm_freq=1000 arm_freq_min=500`;
- калибровка индикатора батареи:
  `echo 1 | sudo tee /sys/class/power_supply/axp20x-battery/calibrate`, затем
  полный разряд→заряд.

**4G-донгл E3372h-153 (HiLink).** Это не serial-модем, а USB-сетевая карта:
воткнул → `usb0`/`enx…` → NetworkManager даёт DHCP. APN/PIN/сигнал настраиваются в
браузере по адресу донгла (`http://192.168.98.1`). Этот же адрес нужно задать в
веб-морде донгла (Настройки → DHCP/домашняя сеть), чтобы он совпал с `--modem-ip`.

**Что нужно сделать вручную (прошивка — не автоматизируется во избежание «кирпича»):**
- подключить APT-репозиторий ClockworkPi и поставить `clockworkpi-kernel`,
  `clockworkpi-cm-firmware` (драйверы панели/клавиатуры/батареи);
- в `/boot/firmware/config.txt`: `dtoverlay=clockworkpi-uconsole-cm5`,
  `dtoverlay=vc4-kms-v3d-pi5,cma-384`, `dtparam=pciex1=off`, `dtparam=ant2`;
- обновить загрузчик CM5: `sudo apt install rpi-eeprom && sudo rpi-eeprom-update -a`.

Если экран встал боком — поменяй `--rotate` (`right`↔`left`) и перезапусти i3
(`Super+Shift+r`). Если образ ClockworkPi уже крутит панель на уровне KMS —
ставь `--rotate=skip`.

## Дополнительные пакеты и Neovim (`--extras`)

Флаг `--extras` ставит кураторские наборы пакетов и настраивает **Neovim + NvChad**:

```bash
curl -fsSL https://raw.githubusercontent.com/Anaph/jubilant-doodle/main/i3-desktop-setup/bootstrap.sh \
  | bash -s -- --uconsole-signal --extras
```

Наборы (полный список — в `packages-extra.txt`):
- **Наладонник/cyberdeck:** qutebrowser, zathura, mpv, copyq, redshift, lm-sensors,
  s-tui, syncthing, xfce4-power-manager, fastfetch, cava;
- **CLI/dev:** neovim, git-delta, tig, eza, zoxide, bat, fd-find, fzf, ripgrep,
  pipx, tealdeer, shellcheck, btop, ncdu, rsync;
- **Сеть/удалёнка:** mosh, openssh-server, nmap, mtr-tiny, iperf3, tcpdump,
  wireguard-tools, rclone, remmina, ufw.

Установка терпима к отсутствию пакета: если какой-то недоступен в репозитории, он
пропускается, остальные ставятся. `ufw` ставится, но **не включается** (чтобы не
отрезать SSH).

### Neovim + NvChad

`--extras` (или отдельный `--neovim`) разворачивает Neovim с NvChad:
- клонирует официальный **NvChad starter** в `~/.config/nvim`, а **ядро** NvChad
  через lazy указывает на твой форк **`Anaph/NvChad`** (ветка `v2.5`); сменить —
  `--nvchad-repo=URL`, пропустить nvim — `--no-nvim`;
- кладёт `~/.config/nvim/lua/plugins/dev.lua` с базовыми плагинами:
  - **Claude Code** — `coder/claudecode.nvim` (нужен `claude` в PATH); клавиши:
    `<leader>ac` — тоггл, `<leader>af` — фокус, `<leader>as` — отправить выделение;
  - **git** — `vim-fugitive` + `diffview.nvim` (плюс gitsigns из NvChad);
  - **C/C++** — LSP `clangd` и форматтер **clang-format** через conform;
  - **CMake** — `cmake-tools.nvim` (configure/build/run) и опц. LSP
    `cmake-language-server` (ставится через pipx, если он есть);
  - парсеры treesitter для c/cpp/cmake/make.
- ставит тулчейн: `clang clangd clang-format clang-tidy cmake ripgrep fd-find`.

Плагины подтянутся при **первом запуске** `nvim` (lazy.nvim). Можно заранее:
```bash
nvim --headless "+Lazy! sync" +qa
```

## Удаление

```bash
~/.local/share/jubilant-doodle/i3-desktop-setup/uninstall.sh          # вернуть конфиги, снять автологин
~/.local/share/jubilant-doodle/i3-desktop-setup/uninstall.sh --purge  # ещё и apt purge пакетов
```

Claude Code (`~/.local/bin/claude`) при удалении остаётся на месте.
