# Ethereal Glass Lockscreen

Самостоятельный плагин **`ethereal.lock`** для Omarchy 4 / Quickshell:
стеклянная карточка Ethereal, `HI, USERNAME`, часы, английская дата,
маскированное поле пароля и Light Trail при вводе.

Основа — штатный `omarchy.lock`. Его PAM, Wayland session lock, поддержка
отпечатков, кэширование обоев, DPMS и восстановление сохранены. `clonedFrom:
omarchy.lock` обеспечивает штатное переключение и возврат оригинала.
Системные файлы Omarchy и PAM не меняются.

## Состав

- `plugin/` — устанавливаемый плагин, manifest и пояснения по сопровождению.
- `test.qml`, `compile.qml`, `tests/` — QML-тесты, безопасная компиляция сервиса
  без его создания и изолированные тесты установщика.
- `install.py`, `rollback.sh`, `verify.sh` — установка/обновление, откат и проверки.
- `upstream/` — исходный штатный lock-плагин, версии и контрольные суммы для сравнения.
- `reports/` — отчёт по проверкам, review и снимок настоящего preview.

В репозитории нет системной конфигурации пользователя, паролей или истории
сторонних проектов. Сгенерированные журналы и ссылки на установленные системные
QML-модули создаются локально и исключены из Git.

## Требования и проверка

Используются уже установленные Omarchy, Quickshell, Qt Quick/QtTest,
Qt 6 qmllint, Python 3, Bash и dbus-monitor. Для шрифта используется
JetBrainsMono Nerd Font, при отсутствии — monospace. Новые зависимости не нужны.
Проверенный baseline указан в `upstream/baseline.json`.

В терминале текущей Wayland-сессии, из корня репозитория:

```sh
bash ./verify.sh
```

Проверка установщика использует временный HOME и подставные IPC/менеджер; настоящая
блокировка и PAM не вызываются. QML-тесты работают в отдельном offscreen-окне
с фиктивными строками. Полный Service.qml компилируется без создания экземпляра.
Результаты последнего запуска — `.local/reports/`.

## Установка и обновление

Только в разблокированной сессии, после успешного verify:

```sh
python3 ./install.py
omarchy-shell lock preview
omarchy-shell lock hidePreview
omarchy-shell lock status
```

Установщик проверяет состояние сессии и доступность PAM, валидирует manifest,
подготавливает полную копию до переключения и выбирает штатный lockscreen перед
заменой файлов. Устанавливает в `~/.config/omarchy/plugins/ethereal.lock/`, обновляет
обнаружение и включает плагин штатным менеджером. Повторный запуск обновляет его.
Пользовательские файлы прежней версии и shell.json сохраняются в отдельный каталог
под `~/.local/state/omarchy/backups/ethereal-glass-lockscreen/`.

Редактируемый Git checkout и установленная копия разделены: сохранение исходников
не меняет активный lockscreen. Установка отказывается перезаписывать symlink или
чужой каталог. При ошибке переключения остаётся штатный экран; если сессия успела
заблокироваться, установщик прекращает изменения и не трогает lock-клиент.
Shell не перезапускается. Штатный hot reload применяется только после отключения
обновляемого клона в подтверждённо разблокированной сессии.

## Настройка и откат

Параметры в `plugin/Ethereal.qml`: `peach`, `background`, `secondary`, `clock`,
`error` — цвета; `cardOpacity`, `cardBorderOpacity`, `backgroundDimOpacity` —
прозрачность; `trailDuration`, `trailLength`, `trailPeakOpacity` — импульс;
`entryDuration`, `errorShakeDuration`, `errorColorReturnDuration` — переходы.
Палитра Ethereal не меняется вслед за общей темой. Анимации учитывают Style.duration.
После правок выполнить verify и установку заново, только в разблокированной сессии.

```sh
bash ./rollback.sh
```

Откат проверяет состояние сессии, отключает `ethereal.lock` и включает
`omarchy.lock`, не удаляя файлы установленного плагина. Вернуть проверенную копию:
`omarchy plugin enable ethereal.lock` — также только при unlocked-состоянии.

## Сопровождение

Штатный исходник: [Omarchy](https://github.com/omacom/omarchy).
Плагин использует [официальный контракт shell-плагинов](https://omarchy.org/manual/shell-plugins/).
Автор исходного механизма блокировки — Omarchy; собственные изменения представлены
в интерфейсе и двух привязках userName в Service.qml.

Копия переживает обновления Omarchy, но не получает исправления backend автоматически.
После обновления сравнить `/usr/share/omarchy/shell/plugins/lock/` с `upstream/omarchy-lock/`,
перенести нужные исправления в baseline и плагин, сохранив отображение, и повторить
проверки до установки. Не заменять backend или перезапускать shell во время блокировки.

[Отчёт по тестам](reports/tests.md) · [Review](reports/review.md) · [Preview](reports/preview.png)

Настоящие пароль, idle/suspend/DPMS и физический hotplug требуют ручной приёмки
владельца. Автотесты и preview не доказывают успешную PAM-разблокировку.
