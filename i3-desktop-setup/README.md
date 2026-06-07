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

## Удаление

```bash
~/.local/share/jubilant-doodle/i3-desktop-setup/uninstall.sh          # вернуть конфиги, снять автологин
~/.local/share/jubilant-doodle/i3-desktop-setup/uninstall.sh --purge  # ещё и apt purge пакетов
```

Claude Code (`~/.local/bin/claude`) при удалении остаётся на месте.
