# AppAssociator

AppAssociator — a utility for Windows 11 (including 24H2 LTSC) that solves the problem of file associations being reset to default Windows applications.

The program redirects standard Windows applications to more powerful third-party alternatives:
- **Paint** (`mspaint.exe`) → **XnView** (image viewer/editor)
- **Notepad** (`notepad.exe`) → **Notepad++** (text editor)

## What the program does

### 1. Paint → XnView redirection

The utility modifies two key registry locations under  
`HKEY_CURRENT_USER\Software\Classes` to intercept Paint invocations:

- **ProgID PBrush**  
  - Path: `Software\Classes\PBrush\shell\open\command`  
  - Changes the launch command to: `"path_to_XnView.exe" "%1"`

- **Application mspaint.exe**  
  - Path: `Software\Classes\Applications\mspaint.exe\shell\open\command`  
  - Also redirects to XnView

### 2. Text files → Notepad++ association

The program creates associations for text files with Notepad++:

- Creates custom ProgID `Notepadpp.TextFile`
- Associates `.txt` and `.log` extensions with Notepad++
- Intercepts `notepad.exe` calls to Notepad++
- Sets icons and open commands

### Additional actions

- Sets icons for all associations
- Calls `SHChangeNotify` so Windows immediately refreshes the shell associations (no restart required)

## Result

### Image files → XnView

Images will open in **XnView** instead of classic Paint in the following situations:

- Double-clicking a .jpg, .png, etc. file whose default app is Paint
- Starting "Paint" via Start menu, Windows Search or running `mspaint` command
- Using context menu → **Open with** → Paint

### Text files → Notepad++

Files with `.txt` and `.log` extensions will open in **Notepad++**:

- Double-clicking text files
- Opening via context menu
- Running `notepad.exe` will automatically launch Notepad++

## Important notes

- Works **only for the current user** (HKEY_CURRENT_USER)  
  → **does not require administrator rights**
- You must correctly specify the paths to programs in constants:
  - `XNVIEW_PATH` (default: `D:\Software\XnView\xnview.exe`)
  - `NOTEPADPP_PATH` (default: `C:\Program Files\Notepad++\notepad++.exe`)
- If after a Windows update / restart the associations revert to defaults —  
  **files will still open in the correct programs** anyway  
  (the interception happens at the ProgID + executable level)
- The program **does not change** global file associations —  
  it only intercepts calls to standard Windows applications

## Program architecture

The code is organized into separate functions for each application:

- `registerXnview(xnviewPath: string)` — registers XnView for image files
- `registerNotepadpp(notepadppPath: string)` — registers Notepad++ for text files
- Helper functions for registry operations and file verification

This design makes it easy to add support for new applications in the future.

## Usage

1. **Check program paths**  
   Open the source code and ensure the constants point to correct paths:
   ```nim
   const
     XNVIEW_PATH = r"D:\Software\XnView\xnview.exe"
     NOTEPADPP_PATH = r"C:\Program Files\Notepad++\notepad++.exe"
   ```

2. **Compile the program:**

   ```bash
   # console version
   nim c -d:release AppAssociator.nim

   # GUI version (no console window)
   nim c -d:release --app:gui AppAssociator.nim
   ```

3. **Run** the generated executable  
   (administrator rights not required, works for current user)

4. **Result:**  
   The program will display a detailed report about each association registration

## Problem being solved

On Windows 11 24H2 LTSC (and other versions), there's a known issue where user-defined file associations are automatically reset to default Windows applications after updates or restarts. AppAssociator solves this problem by intercepting standard application calls at the registry level, making the replacement permanent and resistant to resets.

## Version history

- **v1.0** (2026-02-01) — Refactoring: added `registerNotepadpp()` function, XnView code extracted into `registerXnview()`
- **v0.9** (2026-02-01) — Application started working
- **v0.1** (2026-01-31) — Initial implementation

## Adding support for new applications

If you want to add support for other applications, follow this structure:

### Template for `registerNewapp()` function

```nim
proc registerNewapp(newappPath: string): bool =
  ## Description: what the function does, what associations it creates
  ## 
  ## Parameters:
  ##   newappPath - full path to the program executable
  ## 
  ## Returns:
  ##   true on successful registration, false on errors
  
  echo "═══════════════════════════════════════════════════════════"
  echo "  Registering NewApp"
  echo "═══════════════════════════════════════════════════════════"
  
  # 1. Check if program exists
  if not verifyProgramExists(newappPath, "NewApp"):
    return false

  var ok = true

  # 2. Create ProgID (if needed)
  let progId = "NewApp.FileType"
  let progIdBase = &r"Software\Classes\{progId}"
  
  echo "Creating ProgID for NewApp"
  if not setRegistryValue(HKEY_CURRENT_USER, progIdBase, "", "File type description"):
    echo "  ✗ Failed to create ProgID"
    ok = false
  else:
    # Open command
    let commandPath = progIdBase & r"\shell\open\command"
    let command = &"\"{newappPath}\" \"%1\""
    if not setRegistryValue(HKEY_CURRENT_USER, commandPath, "", command):
      echo "  ✗ Failed to set open command"
      ok = false
    
    # Icon
    let iconPath = progIdBase & r"\DefaultIcon"
    let icon = &"\"{newappPath}\",0"
    discard setRegistryValue(HKEY_CURRENT_USER, iconPath, "", icon)
    
    echo "  ✓ ProgID created"

  # 3. Associate file extensions
  echo "Associating .ext extension with NewApp"
  let extPath = r"Software\Classes\.ext"
  if not setRegistryValue(HKEY_CURRENT_USER, extPath, "", progId):
    echo "  ✗ Failed to associate .ext"
    ok = false
  else:
    echo "  ✓ .ext associated with NewApp"

  # 4. Intercept default application (optional)
  echo "Intercepting Applications\\oldapp.exe → NewApp"
  let oldappBase = r"Software\Classes\Applications\oldapp.exe"
  let oldappCommandPath = oldappBase & r"\shell\open\command"
  let oldappCommand = &"\"{newappPath}\" \"%1\""
  
  if not setRegistryValue(HKEY_CURRENT_USER, oldappCommandPath, "", oldappCommand):
    echo "  ✗ Failed to intercept oldapp.exe"
  else:
    let oldappIconPath = oldappBase & r"\DefaultIcon"
    let oldappIcon = &"\"{newappPath}\",0"
    discard setRegistryValue(HKEY_CURRENT_USER, oldappIconPath, "", oldappIcon)
    echo "  ✓ oldapp.exe now launches NewApp"

  # 5. Final message
  if ok:
    echo ""
    echo "✓ NewApp successfully registered"
    echo "  Description of what was done"

  return ok
```

### Integration into main()

After creating the function, add its call to the `main()` procedure:

```nim
proc main() =
  echo "═══════════════════════════════════════════════════════════"
  echo "  AppAssociator v1.0"
  echo "  File Association Protection for Windows 11 24H2 LTSC"
  echo "═══════════════════════════════════════════════════════════"
  echo ""

  var allOk = true

  # Register XnView
  if not registerXnview(XNVIEW_PATH):
    allOk = false
  
  echo ""
  
  # Register Notepad++
  if not registerNotepadpp(NOTEPADPP_PATH):
    allOk = false

  echo ""
  
  # Register new application
  if not registerNewapp(NEWAPP_PATH):
    allOk = false

  # Notify system
  notifySystemAssocChanged()

  # ... rest of main() code
```

### Don't forget to:

1. Add a constant with the program path:
   ```nim
   const
     NEWAPP_PATH = r"C:\Path\To\newapp.exe"
   ```

2. Update the final message in `main()` with information about the new application

3. Test on your system before deployment

## License

Open source. Use freely.

## Author

[github.com/Balans097](https://github.com/Balans097)
