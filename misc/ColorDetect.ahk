#Requires AutoHotkey v2.0
#Include Gdip_All.ahk

; 1. Initialize GDI+
if !pToken := Gdip_Startup() {
    MsgBox "GDI+ failed to start."
    ExitApp
}

; 2. Base resolution
BaseW := 2560
BaseH := 1440

; Use MonitorGetPrimary() to get the index of the primary monitor
primaryMod := MonitorGetPrimary()
MonitorGet(primaryMod, &Left, &Top, &Right, &Bottom)

; Calculate current dimensions of the primary monitor
CurrentW := Right - Left
CurrentH := Bottom - Top

; 3. Base coordinates (Relative to 2560x1440)
BaseX := 168
BaseY := 222

; 4. Target calculation (Scaling the point based on the primary monitor's resolution)
TargetX := Round(BaseX * (CurrentW / BaseW))
TargetY := Round(BaseY * (CurrentH / BaseH))

; --- Functions ---

; Displays a red dot at the target coordinates for visual verification
VisualConfirm(x, y) {
    static DebugGui := 0
    if DebugGui
        DebugGui.Destroy()
    
    ; Create a small 5x5 red window
    DebugGui := Gui("+AlwaysOnTop -Caption +ToolWindow")
    DebugGui.BackColor := "Red"
    
    ; Show the dot centered over the target pixel
    DebugGui.Show("x" (x-2) " y" (y-2) " w5 h5 NoActivate")
    
    ; Auto-destroy the dot after 5 seconds
    SetTimer (*) => (IsObject(DebugGui) ? DebugGui.Destroy() : ""), -5000
}

; Captures the pixel color at the specified global screen coordinates
GetColorAtPos(x, y) {
    VisualConfirm(x, y)
    
    ; Retrieve virtual screen metrics (covering all monitors)
    vScreenX := SysGet(76) ; SM_XVIRTUALSCREEN (Leftmost coordinate)
    vScreenY := SysGet(77) ; SM_YVIRTUALSCREEN (Topmost coordinate)
    vScreenW := SysGet(78) ; SM_CXVIRTUALSCREEN (Total width)
    vScreenH := SysGet(79) ; SM_CYVIRTUALSCREEN (Total height)
    
    ; Capture the entire virtual desktop area
    ; Format: "X|Y|Width|Height"
    pBitmap := Gdip_BitmapFromScreen(vScreenX "|" vScreenY "|" vScreenW "|" vScreenH)
    
    ; Since the bitmap starts at vScreenX/vScreenY, we must offset our target coordinates
    ; to correctly sample the pixel from the resulting image.
    ARGB := Gdip_GetPixel(pBitmap, x - vScreenX, y - vScreenY)
    
    ; Clean up the bitmap from memory
    Gdip_DisposeImage(pBitmap)
    
    ; Return the color in HEX format (RRGGBB)
    return Format("{:06X}", ARGB & 0xFFFFFF)
}

F5:: {
    hexColor := GetColorAtPos(TargetX, TargetY)
    
    MsgBox(
        "Screen: " CurrentW "x" CurrentH "`n" .
        "Target Point: X:" TargetX " Y:" TargetY "`n" .
        "Detected Color: 0x" hexColor
    )
}

; Ensure GDI+ is shut down properly when exiting the script
OnExit (*) => Gdip_Shutdown(pToken)
