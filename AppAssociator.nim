################################################################
#       ПРИЛОЖЕНИЕ ДЛЯ СОХРАНЕНИЯ ФАЙЛОВЫХ АССОЦИАЦИЙ
#               В WINDOWS 11 24H2 LTSC
# 
# Версия:   0.9
# Дата:     2026-01-02
# Автор:    github.com/Balans097
################################################################


# 0.9 — приложение начало работать (2026-02-01)
# 0.1 — начальная реализация приложения (2026-01-31)



# nim c -d:release AppAssociator.nim
# nim c -d:release --app:gui AppAssociator.nim


# AppAssociator.nim
# Перехват Paint (PBrush/mspaint.exe) и перенаправление на XnView


import std/[winlean, os, strformat]

const
  # Путь к XnView — поправьте при необходимости
  XNVIEW_PATH = r"D:\Software\XnView\xnview.exe"

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

proc setRegistryValue(rootKey: HKEY, path: string, valueName: string, value: string): bool =
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

proc verifyXnViewExists(): bool =
  if not fileExists(XNVIEW_PATH):
    echo "ОШИБКА: XnView не найден по пути: ", XNVIEW_PATH
    return false
  true

proc hijackPBrush(): bool =
  echo "Перехватываю ProgID PBrush → XnView"
  let base = r"Software\Classes\PBrush"

  let commandPath = base & r"\shell\open\command"
  let command = &"\"{XNVIEW_PATH}\" \"%1\""
  if not setRegistryValue(HKEY_CURRENT_USER, commandPath, "", command):
    echo "  ✗ Не удалось записать команду для PBrush"
    return false

  let iconPath = base & r"\DefaultIcon"
  let icon = &"\"{XNVIEW_PATH}\",0"
  discard setRegistryValue(HKEY_CURRENT_USER, iconPath, "", icon)

  echo "  ✓ PBrush теперь запускает XnView"
  true

proc hijackMsPaintApp(): bool =
  echo "Перехватываю Applications\\mspaint.exe → XnView"
  let base = r"Software\Classes\Applications\mspaint.exe"

  let commandPath = base & r"\shell\open\command"
  let command = &"\"{XNVIEW_PATH}\" \"%1\""
  if not setRegistryValue(HKEY_CURRENT_USER, commandPath, "", command):
    echo "  ✗ Не удалось записать команду для mspaint.exe"
    return false

  let iconPath = base & r"\DefaultIcon"
  let icon = &"\"{XNVIEW_PATH}\",0"
  discard setRegistryValue(HKEY_CURRENT_USER, iconPath, "", icon)

  echo "  ✓ mspaint.exe теперь запускает XnView"
  true

proc main() =
  echo "═══════════════════════════════════════════════════════════"
  echo "  AppAssociator: перехват Paint → XnView"
  echo "═══════════════════════════════════════════════════════════"
  echo ""

  if not verifyXnViewExists():
    echo "Исправь XNVIEW_PATH в исходнике и пересобери."
    quit(1)

  var ok = true
  if not hijackPBrush():
    ok = false
  if not hijackMsPaintApp():
    ok = false

  echo ""
  echo "Уведомляю систему об изменении ассоциаций..."
  SHChangeNotify(SHCNE_ASSOCCHANGED, SHCNF_IDLIST, nil, nil)
  echo "✓ Explorer уведомлён"
  echo ""

  if ok:
    echo "Готово: любые вызовы Paint (PBrush/mspaint.exe) теперь открывают XnView."
    echo "Если после перезагрузки .jpg/.png снова уйдут на Paint — фактически всё равно откроется XnView."
  else:
    echo "Были ошибки при записи в реестр. Попробуй запустить от имени текущего пользователя без UAC-блокировок."

when isMainModule:
  main()
