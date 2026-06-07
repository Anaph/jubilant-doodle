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
curl -fsSL https://raw.githubusercontent.com/Anaph/jubilant-doodle/claude/focused-mayer-hwNfz/i3-desktop-setup/bootstrap.sh | bash
```

По умолчанию: вход через **LightDM**, тема **Tokyo Night**, с установкой Claude Code.

### С опциями

Чтобы передать флаги через pipe, используйте форму `bash -s --`:

```bash
# Автологин в консоль + startx вместо LightDM, тема Nord, без Claude Code:
curl -fsSL https://raw.githubusercontent.com/Anaph/jubilant-doodle/claude/focused-mayer-hwNfz/i3-desktop-setup/bootstrap.sh \
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
| `Super+Shift+q` | закрыть окно |
| `Super+1..0` | переключение рабочих столов |
| `Super+r` | режим изменения размера |
| `Super+Shift+x` | блокировка экрана |
| `Super+Shift+e` | выход из i3 |

Полный список — в `~/.config/i3/config`.

### Claude Code

Откройте **новый** терминал (чтобы подхватился `PATH`) и выполните `claude` для
входа в аккаунт. Если команда не найдена: `source ~/.profile`.

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

## Смена темы позже

```bash
~/.local/share/jubilant-doodle/i3-desktop-setup/install.sh --theme=catppuccin_mocha
```

Это перезапишет тему Alacritty и палитру i3 (для курируемого набора). Затем в i3:
`Super+Shift+r` (перезапуск i3) — изменения применятся.

## ClockworkPi uConsole (CM5)

Для uConsole есть опциональный модуль с правками под железо. Установка с виджетом
4G-сигнала и кастомным адресом донгла:

```bash
curl -fsSL https://raw.githubusercontent.com/Anaph/jubilant-doodle/claude/focused-mayer-hwNfz/i3-desktop-setup/bootstrap.sh \
  | bash -s -- --uconsole-signal --modem-ip=192.168.98.1
```

Флаги: `--uconsole` (без виджета), `--uconsole-signal` (с виджетом 4G),
`--modem-ip=IP` (адрес HiLink-донгла, по умолч. `192.168.98.1`),
`--rotate=right|left|normal|inverted|skip` (поворот панели, по умолч. `right`).

**Что делает модуль (безопасная, десктопная часть):**
- поворот DSI-панели в landscape (автоопределение выхода `DSI-*`; меняется `--rotate`);
- батарея (AXP228) в строке состояния; при `--uconsole-signal` — бар на **i3blocks**
  с виджетом 4G-сигнала, читающим HTTP-API донгла;
- **Bluetooth** (`bluez` + `blueman`, апплет в трее);
- **USB HiLink-модем** (Huawei E3372h): `usb-modeswitch` + udev-правило, чтобы
  ModemManager не перехватывал донгл (он подключается как обычная сетевая карта,
  NetworkManager поднимает DHCP сам);
- энергосбережение: `tlp` (с отключённым USB-autosuspend, чтобы не отрубать донгл),
  сжатый swap `zram`, диагностический `powertop`;
- увеличенные шрифты под 5″/720p.

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

## Удаление

```bash
~/.local/share/jubilant-doodle/i3-desktop-setup/uninstall.sh          # вернуть конфиги, снять автологин
~/.local/share/jubilant-doodle/i3-desktop-setup/uninstall.sh --purge  # ещё и apt purge пакетов
```

Claude Code (`~/.local/bin/claude`) при удалении остаётся на месте.
