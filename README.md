# AppAssociator

AppAssociator — утилита для Windows 11 (в т.ч. 24H2 LTSC), решающая проблему "слетания" файловых ассоциаций на стандартные приложения Windows.

Программа перенаправляет запуск стандартных приложений Windows на более функциональные сторонние альтернативы:
- **Paint** (`mspaint.exe`) → **XnView** (просмотрщик/редактор изображений)
- **Блокнот** (`notepad.exe`) → **Notepad++** (текстовый редактор)

## Что делает программа

### 1. Перехват Paint → XnView

Программа изменяет две ключевые ветки реестра в разделе  
`HKEY_CURRENT_USER\Software\Classes`, чтобы перехватить вызовы Paint:

- **ProgID PBrush**  
  - Путь: `Software\Classes\PBrush\shell\open\command`  
  - Изменяет команду запуска на: `"путь_к_XnView.exe" "%1"`

- **Приложение mspaint.exe**  
  - Путь: `Software\Classes\Applications\mspaint.exe\shell\open\command`  
  - Также перенаправляет на XnView

### 2. Ассоциация текстовых файлов → Notepad++

Программа создаёт ассоциации для текстовых файлов с Notepad++:

- Создаёт собственный ProgID `Notepadpp.TextFile`
- Ассоциирует расширения `.txt` и `.log` с Notepad++
- Перехватывает вызовы `notepad.exe` на Notepad++
- Устанавливает иконки и команды открытия

### Дополнительно

- Устанавливает иконки для всех ассоциаций
- Вызывает `SHChangeNotify`, чтобы Windows сразу обновила ассоциации (без перезагрузки)

## Результат

### Графические файлы → XnView

Файлы будут открываться в **XnView** вместо стандартного Paint в следующих случаях:

- Двойной клик по файлу .jpg, .png и др., для которых по умолчанию стоит Paint
- Запуск «Paint» через меню «Пуск», поиск Windows или команду `mspaint`
- Открытие изображения через контекстное меню → **«Открыть с помощью» → Paint**

### Текстовые файлы → Notepad++

Файлы `.txt` и `.log` будут открываться в **Notepad++**:

- Двойной клик по текстовым файлам
- Открытие через контекстное меню
- Запуск `notepad.exe` автоматически откроет Notepad++

## Важные замечания

- Работает **только для текущего пользователя** (HKEY_CURRENT_USER)  
  → **не требует прав администратора**
- Требует правильного указания путей к программам в константах:
  - `XNVIEW_PATH` (по умолчанию: `D:\Software\XnView\xnview.exe`)
  - `NOTEPADPP_PATH` (по умолчанию: `C:\Program Files\Notepad++\notepad++.exe`)
- Если после перезагрузки / обновления Windows ассоциации «слетают» обратно →  
  при следующем запуске файлы **всё равно откроются в правильных программах**  
  (перехват происходит на уровне ProgID и exe-приложений)
- **Не меняет** глобальные ассоциации файлов — только вызовы стандартных приложений Windows

## Архитектура программы

Код организован в виде отдельных функций для каждой программы:

- `registerXnview(xnviewPath: string)` — регистрация XnView для графических файлов
- `registerNotepadpp(notepadppPath: string)` — регистрация Notepad++ для текстовых файлов
- Вспомогательные функции для работы с реестром и проверки файлов

Это позволяет легко добавлять поддержку новых приложений в будущем.

## Использование

1. **Проверьте пути к программам**  
   Откройте исходный код и убедитесь, что константы указывают на правильные пути:
   ```nim
   const
     XNVIEW_PATH = r"D:\Software\XnView\xnview.exe"
     NOTEPADPP_PATH = r"C:\Program Files\Notepad++\notepad++.exe"
   ```

2. **Скомпилируйте программу:**

   ```bash
   # консольная версия
   nim c -d:release AppAssociator.nim

   # версия без консоли (GUI)
   nim c -d:release --app:gui AppAssociator.nim
   ```

3. **Запустите** полученный исполняемый файл  
   (права администратора не требуются, работает от имени текущего пользователя)

4. **Результат:**  
   Программа выведет подробный отчёт о регистрации каждой ассоциации

## Решаемая проблема

На Windows 11 24H2 LTSC (и других версиях) наблюдается проблема автоматического сброса пользовательских файловых ассоциаций на стандартные приложения Windows после обновлений или перезагрузок. AppAssociator решает эту проблему, перехватывая вызовы стандартных приложений на уровне реестра, что делает замену постоянной и устойчивой к сбросам.

## История версий

- **v1.0** (2026-02-01) — Рефакторинг: добавлена функция `registerNotepadpp()`, код XnView вынесен в `registerXnview()`
- **v0.9** (2026-02-01) — Приложение начало работать
- **v0.1** (2026-01-31) — Начальная реализация

## Добавление поддержки новых приложений

Если вы хотите добавить поддержку других приложений, следуйте этой структуре:

### Шаблон функции `registerNewapp()`

```nim
proc registerNewapp(newappPath: string): bool =
  ## Описание: что делает функция, какие ассоциации создаёт
  ## 
  ## Параметры:
  ##   newappPath - полный путь к исполняемому файлу программы
  ## 
  ## Возвращает:
  ##   true при успешной регистрации, false при ошибках
  
  echo "═══════════════════════════════════════════════════════════"
  echo "  Регистрация NewApp"
  echo "═══════════════════════════════════════════════════════════"
  
  # 1. Проверка существования программы
  if not verifyProgramExists(newappPath, "NewApp"):
    return false

  var ok = true

  # 2. Создание ProgID (если требуется)
  let progId = "NewApp.FileType"
  let progIdBase = &r"Software\Classes\{progId}"
  
  echo "Создаю ProgID для NewApp"
  if not setRegistryValue(HKEY_CURRENT_USER, progIdBase, "", "Описание типа файла"):
    echo "  ✗ Не удалось создать ProgID"
    ok = false
  else:
    # Команда открытия
    let commandPath = progIdBase & r"\shell\open\command"
    let command = &"\"{newappPath}\" \"%1\""
    if not setRegistryValue(HKEY_CURRENT_USER, commandPath, "", command):
      echo "  ✗ Не удалось записать команду открытия"
      ok = false
    
    # Иконка
    let iconPath = progIdBase & r"\DefaultIcon"
    let icon = &"\"{newappPath}\",0"
    discard setRegistryValue(HKEY_CURRENT_USER, iconPath, "", icon)
    
    echo "  ✓ ProgID создан"

  # 3. Ассоциация расширений файлов
  echo "Ассоциирую расширение .ext с NewApp"
  let extPath = r"Software\Classes\.ext"
  if not setRegistryValue(HKEY_CURRENT_USER, extPath, "", progId):
    echo "  ✗ Не удалось ассоциировать .ext"
    ok = false
  else:
    echo "  ✓ .ext ассоциирован с NewApp"

  # 4. Перехват стандартного приложения (опционально)
  echo "Перехватываю Applications\\oldapp.exe → NewApp"
  let oldappBase = r"Software\Classes\Applications\oldapp.exe"
  let oldappCommandPath = oldappBase & r"\shell\open\command"
  let oldappCommand = &"\"{newappPath}\" \"%1\""
  
  if not setRegistryValue(HKEY_CURRENT_USER, oldappCommandPath, "", oldappCommand):
    echo "  ✗ Не удалось перехватить oldapp.exe"
  else:
    let oldappIconPath = oldappBase & r"\DefaultIcon"
    let oldappIcon = &"\"{newappPath}\",0"
    discard setRegistryValue(HKEY_CURRENT_USER, oldappIconPath, "", oldappIcon)
    echo "  ✓ oldapp.exe теперь запускает NewApp"

  # 5. Итоговое сообщение
  if ok:
    echo ""
    echo "✓ NewApp успешно зарегистрирован"
    echo "  Описание результата работы"

  return ok
```

### Интеграция в main()

После создания функции добавьте её вызов в процедуру `main()`:

```nim
proc main() =
  echo "═══════════════════════════════════════════════════════════"
  echo "  AppAssociator v1.0"
  echo "  Защита файловых ассоциаций на Windows 11 24H2 LTSC"
  echo "═══════════════════════════════════════════════════════════"
  echo ""

  var allOk = true

  # Регистрация XnView
  if not registerXnview(XNVIEW_PATH):
    allOk = false
  
  echo ""
  
  # Регистрация Notepad++
  if not registerNotepadpp(NOTEPADPP_PATH):
    allOk = false

  echo ""
  
  # Регистрация нового приложения
  if not registerNewapp(NEWAPP_PATH):
    allOk = false

  # Уведомление системы
  notifySystemAssocChanged()

  # ... остальной код main()
```

### Не забудьте:

1. Добавить константу с путём к программе:
   ```nim
   const
     NEWAPP_PATH = r"C:\Path\To\newapp.exe"
   ```

2. Обновить итоговое сообщение в `main()` с информацией о новом приложении

3. Протестировать на своей системе перед использованием

## Лицензия

Открытый исходный код. Используйте свободно.

## Автор

[github.com/Balans097](https://github.com/Balans097)
