# AppAssociator

AppAssociator — a small utility for Windows 11 (including 24H2 LTSC) that redirects calls to the classic Paint (`mspaint.exe` / ProgID `PBrush`) to **XnView**.  
In other words, it makes Windows launch **XnView** instead of the built-in Microsoft Paint whenever Paint would normally be started.

In the future the program may be extended to support redirection to other image viewers/editors.

## What the program does

The utility modifies two key registry locations under  
`HKEY_CURRENT_USER\Software\Classes` to intercept Paint invocations:

1. **ProgID PBrush**  
   - Path: `Software\Classes\PBrush\shell\open\command`  
   - Changes the launch command to:  
     `"path_to_XnView.exe" "%1"`

2. **Application mspaint.exe**  
   - Path: `Software\Classes\Applications\mspaint.exe\shell\open\command`  
   - Also redirects to XnView

### Additional actions

- Sets the XnView icon for these associations
- Calls `SHChangeNotify` so Windows immediately refreshes the shell associations (no restart required)

## Result

Images will open in **XnView** instead of classic Paint in the following situations:

- Double-clicking a .jpg, .png, etc. file whose default app is Paint
- Starting “Paint” via Start menu, Windows Search or running `mspaint` command
- Using context menu → **Open with** → Paint

## Important notes

- Works **only for the current user** (HKEY_CURRENT_USER)  
  → **does not require administrator rights**
- You must correctly specify the path to XnView in the constant `XNVIEW_PATH`
- If after a Windows update / restart the associations revert to Paint —  
  **images will still open in XnView** anyway  
  (the interception happens at the ProgID + executable level)
- The program **does not change** global file associations (*.jpg, *.png etc.) —  
  it only intercepts calls that were going to Paint

## Usage

1. Make sure XnView is installed  
   → check / correct the path in the constant `XNVIEW_PATH` if needed
2. Compile the program:

   ```bash
   # console version
   nim c -d:release AppAssociator.nim

   # GUI version (no console window)
   nim c -d:release --app:gui AppAssociator.nim