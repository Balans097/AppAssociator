################################################################
#       ПРИЛОЖЕНИЕ ДЛЯ СОХРАНЕНИЯ ФАЙЛОВЫХ АССОЦИАЦИЙ
#               В WINDOWS 11 24H2 LTSC
# 
# Версия:   1.0
# Дата:     2026-02-01
# Автор:    github.com/Balans097
################################################################


# 1.0 — рефакторинг: вынесены registerXnview и registerNotepadpp (2026-02-01)
# 0.9 — приложение начало работать (2026-02-01)
# 0.1 — начальная реализация приложения (2026-01-31)



# nim c -d:release AppAssociator.nim
# nim c -d:release --app:gui --out:AppAssociatorNoCmd AppAssociator.nim


# AppAssociator.nim
# Перехват файловых ассоциаций для предотвращения их сброса на Windows 11 24H2 LTSC


import std/[winlean, os, strformat]

const
  # Путь к XnView — поправьте при необходимости
  XNVIEW_PATH = r"D:\Software\XnView\xnview.exe"
  # Путь к Notepad++ — поправьте при необходимости
  NOTEPADPP_PATH = r"C:\Program Files\Notepad++\notepad++.exe"

type
  HKEY = int
  LSTATUS = int32
  REGSAM = int32

const
  HKEY_CURRENT_USER = 0x80000001
  KEY_SET_VALUE = 0x0002
  KEY_CREATE_SUB_KEY = 0x0004
  KEY_WRITE = 0x20006
  REG_SZ = 1
  ERROR_SUCCESS = 0

# WinAPI
proc RegCreateKeyExA(hKey: HKEY, lpSubKey: cstring, Reserved: int32,
                     lpClass: cstring, dwOptions: int32, samDesired: REGSAM,
                     lpSecurityAttributes: pointer, phkResult: ptr HKEY,
                     lpdwDisposition: ptr int32): LSTATUS
  {.stdcall, dynlib: "advapi32", importc.}

proc RegSetValueExA(hKey: HKEY, lpValueName: cstring, Reserved: int32,
                    dwType: int32, lpData: pointer, cbData: int32): LSTATUS
  {.stdcall, dynlib: "advapi32", importc.}

proc RegCloseKey(hKey: HKEY): LSTATUS
  {.stdcall, dynlib: "advapi32", importc.}

proc SHChangeNotify(wEventId: int32, uFlags: int32, dwItem1: pointer, dwItem2: pointer)
  {.stdcall, dynlib: "shell32", importc.}

const
  SHCNE_ASSOCCHANGED = 0x08000000'i32
  SHCNF_IDLIST = 0x0000

# ═══════════════════════════════════════════════════════════
# ВСПОМОГАТЕЛЬНЫЕ ФУНКЦИИ
# ═══════════════════════════════════════════════════════════

proc setRegistryValue(rootKey: HKEY, path: string, valueName: string, value: string): bool =
  ## Устанавливает значение в реестре Windows
  var hKey: HKEY
  var disposition: int32

  let status = RegCreateKeyExA(
    rootKey,
    path.cstring,
    0,
    nil,
    0,
    KEY_SET_VALUE or KEY_CREATE_SUB_KEY or KEY_WRITE,
    nil,
    addr hKey,
    addr disposition
  )
  if status != ERROR_SUCCESS:
    return false

  defer: discard RegCloseKey(hKey)

  var dataToWrite = value
  let setStatus = RegSetValueExA(
    hKey,
    valueName.cstring,
    0,
    REG_SZ,
    if dataToWrite.len > 0: unsafeAddr dataToWrite[0] else: nil,
    value.len.int32 + 1
  )
  setStatus == ERROR_SUCCESS

proc verifyProgramExists(programPath: string, programName: string): bool =
  ## Проверяет существование программы по указанному пути
  if not fileExists(programPath):
    echo &"ОШИБКА: {programName} не найден по пути: {programPath}"
    return false
  true

proc notifySystemAssocChanged() =
  ## Уведомляет систему об изменении файловых ассоциаций
  echo ""
  echo "Уведомляю систему об изменении ассоциаций..."
  SHChangeNotify(SHCNE_ASSOCCHANGED, SHCNF_IDLIST, nil, nil)
  echo "✓ Explorer уведомлён"
  echo ""

# ═══════════════════════════════════════════════════════════
# ФУНКЦИЯ РЕГИСТРАЦИИ XNVIEW
# ═══════════════════════════════════════════════════════════

proc registerXnview(xnviewPath: string): bool =
  ## Перехватывает ассоциации графических файлов для XnView
  ## Перенаправляет вызовы Paint (PBrush/mspaint.exe) на XnView
  ## 
  ## Параметры:
  ##   xnviewPath - полный путь к исполняемому файлу XnView
  ## 
  ## Возвращает:
  ##   true при успешной регистрации, false при ошибках
  
  echo "═══════════════════════════════════════════════════════════"
  echo "  Регистрация XnView"
  echo "═══════════════════════════════════════════════════════════"
  
  if not verifyProgramExists(xnviewPath, "XnView"):
    return false

  var ok = true

  # Перехват ProgID PBrush
  echo "Перехватываю ProgID PBrush → XnView"
  let pbrushBase = r"Software\Classes\PBrush"
  let pbrushCommandPath = pbrushBase & r"\shell\open\command"
  let pbrushCommand = &"\"{xnviewPath}\" \"%1\""
  
  if not setRegistryValue(HKEY_CURRENT_USER, pbrushCommandPath, "", pbrushCommand):
    echo "  ✗ Не удалось записать команду для PBrush"
    ok = false
  else:
    let pbrushIconPath = pbrushBase & r"\DefaultIcon"
    let pbrushIcon = &"\"{xnviewPath}\",0"
    discard setRegistryValue(HKEY_CURRENT_USER, pbrushIconPath, "", pbrushIcon)
    echo "  ✓ PBrush теперь запускает XnView"

  # Перехват Applications\mspaint.exe
  echo "Перехватываю Applications\\mspaint.exe → XnView"
  let mspaintBase = r"Software\Classes\Applications\mspaint.exe"
  let mspaintCommandPath = mspaintBase & r"\shell\open\command"
  let mspaintCommand = &"\"{xnviewPath}\" \"%1\""
  
  if not setRegistryValue(HKEY_CURRENT_USER, mspaintCommandPath, "", mspaintCommand):
    echo "  ✗ Не удалось записать команду для mspaint.exe"
    ok = false
  else:
    let mspaintIconPath = mspaintBase & r"\DefaultIcon"
    let mspaintIcon = &"\"{xnviewPath}\",0"
    discard setRegistryValue(HKEY_CURRENT_USER, mspaintIconPath, "", mspaintIcon)
    echo "  ✓ mspaint.exe теперь запускает XnView"

  if ok:
    echo ""
    echo "✓ XnView успешно зарегистрирован"
    echo "  Любые вызовы Paint (PBrush/mspaint.exe) теперь открывают XnView"

  return ok

# ═══════════════════════════════════════════════════════════
# ФУНКЦИЯ РЕГИСТРАЦИИ NOTEPAD++
# ═══════════════════════════════════════════════════════════

proc registerNotepadpp(notepadppPath: string): bool =
  ## Создаёт ассоциации файлов .txt и .log с Notepad++
  ## Заменяет стандартный notepad.exe Windows
  ## 
  ## Параметры:
  ##   notepadppPath - полный путь к исполняемому файлу Notepad++
  ## 
  ## Возвращает:
  ##   true при успешной регистрации, false при ошибках
  
  echo "═══════════════════════════════════════════════════════════"
  echo "  Регистрация Notepad++"
  echo "═══════════════════════════════════════════════════════════"
  
  if not verifyProgramExists(notepadppPath, "Notepad++"):
    return false

  var ok = true

  # Создаём собственный ProgID для Notepad++
  let progId = "Notepadpp.TextFile"
  let progIdBase = &r"Software\Classes\{progId}"
  
  echo "Создаю ProgID для Notepad++"
  if not setRegistryValue(HKEY_CURRENT_USER, progIdBase, "", "Text Document (Notepad++)"):
    echo "  ✗ Не удалось создать ProgID"
    ok = false
  else:
    # Команда открытия
    let commandPath = progIdBase & r"\shell\open\command"
    let command = &"\"{notepadppPath}\" \"%1\""
    if not setRegistryValue(HKEY_CURRENT_USER, commandPath, "", command):
      echo "  ✗ Не удалось записать команду открытия"
      ok = false
    
    # Иконка
    let iconPath = progIdBase & r"\DefaultIcon"
    let icon = &"\"{notepadppPath}\",0"
    discard setRegistryValue(HKEY_CURRENT_USER, iconPath, "", icon)
    
    echo "  ✓ ProgID создан"

  # Ассоциация для .txt файлов
  echo "Ассоциирую расширение .txt с Notepad++"
  let txtPath = r"Software\Classes\.txt"
  if not setRegistryValue(HKEY_CURRENT_USER, txtPath, "", progId):
    echo "  ✗ Не удалось ассоциировать .txt"
    ok = false
  else:
    echo "  ✓ .txt ассоциирован с Notepad++"

  # Ассоциация для .log файлов
  echo "Ассоциирую расширение .log с Notepad++"
  let logPath = r"Software\Classes\.log"
  if not setRegistryValue(HKEY_CURRENT_USER, logPath, "", progId):
    echo "  ✗ Не удалось ассоциировать .log"
    ok = false
  else:
    echo "  ✓ .log ассоциирован с Notepad++"

  # Перехват notepad.exe (опционально)
  echo "Перехватываю Applications\\notepad.exe → Notepad++"
  let notepadBase = r"Software\Classes\Applications\notepad.exe"
  let notepadCommandPath = notepadBase & r"\shell\open\command"
  let notepadCommand = &"\"{notepadppPath}\" \"%1\""
  
  if not setRegistryValue(HKEY_CURRENT_USER, notepadCommandPath, "", notepadCommand):
    echo "  ✗ Не удалось перехватить notepad.exe"
    # Не критично для основной функциональности
  else:
    let notepadIconPath = notepadBase & r"\DefaultIcon"
    let notepadIcon = &"\"{notepadppPath}\",0"
    discard setRegistryValue(HKEY_CURRENT_USER, notepadIconPath, "", notepadIcon)
    echo "  ✓ notepad.exe теперь запускает Notepad++"

  if ok:
    echo ""
    echo "✓ Notepad++ успешно зарегистрирован"
    echo "  Файлы .txt и .log теперь открываются в Notepad++"

  return ok

# ═══════════════════════════════════════════════════════════
# ГЛАВНАЯ ФУНКЦИЯ
# ═══════════════════════════════════════════════════════════

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

  # Уведомление системы
  notifySystemAssocChanged()

  # Итоговое сообщение
  if allOk:
    echo "═══════════════════════════════════════════════════════════"
    echo "✓ ВСЕ АССОЦИАЦИИ УСПЕШНО ЗАРЕГИСТРИРОВАНЫ"
    echo "═══════════════════════════════════════════════════════════"
    echo ""
    echo "XnView:"
    echo "  • Графические файлы через Paint → XnView"
    echo ""
    echo "Notepad++:"
    echo "  • .txt и .log файлы → Notepad++"
    echo "  • Вызовы notepad.exe → Notepad++"
    echo ""
    echo "Если после перезагрузки ассоциации снова сбросятся,"
    echo "фактически программы всё равно откроются правильно."
  else:
    echo "═══════════════════════════════════════════════════════════"
    echo "⚠ БЫЛИ ОШИБКИ ПРИ РЕГИСТРАЦИИ"
    echo "═══════════════════════════════════════════════════════════"
    echo ""
    echo "Возможные причины:"
    echo "  • Неверные пути к программам (проверь константы)"
    echo "  • Недостаточно прав (попробуй запустить от администратора)"
    echo "  • Блокировка UAC или антивирусом"

when isMainModule:
  main()