#Requires AutoHotkey v2.0
#Include Gdip_All.ahk

; 1. Initialize GDI+
if !pToken := Gdip_Startup() {
    MsgBox "GDI+ failed to start."
    ExitApp
}

; 2. Resolutions
BaseW := 2560
BaseH := 1440
CurrentW := A_ScreenWidth
CurrentH := A_ScreenHeight

; 3. Coordinates
BaseX := 168
BaseY := 222

; 4. Calculation
TargetX := Round(BaseX * (CurrentW / BaseW))
TargetY := Round(BaseY * (CurrentH / BaseH))

; Function to show a red dot at the capture point
VisualConfirm(x, y) {
    static DebugGui := 0
    if DebugGui
        DebugGui.Destroy()
    
    ; Create a small 5x5 red window
    DebugGui := Gui("+AlwaysOnTop -Caption +ToolWindow")
    DebugGui.BackColor := "Red"
    ; Center the 5x5 dot over the target pixel
    DebugGui.Show("x" (x-2) " y" (y-2) " w5 h5 NoActivate")
    
    ; Hide the dot after 5 seconds
    SetTimer (*) => DebugGui.Destroy(), -5000
}

GetColorAtPos(x, y) {
    ; We call visual confirmation
    VisualConfirm(x, y)
    
    pBitmap := Gdip_BitmapFromScreen()
    ARGB := Gdip_GetPixel(pBitmap, x, y)
    Gdip_DisposeImage(pBitmap)
    
    return Format("{:06X}", ARGB & 0xFFFFFF)
}

F5:: {
    hexColor := GetColorAtPos(TargetX, TargetY)
    
    MsgBox(
        "Current Resolution: " CurrentW "x" CurrentH "`n" .
        "Target Point: X:" TargetX " Y:" TargetY "`n" .
        "Detected Color: 0x" hexColor
    )
}

OnExit (*) => Gdip_Shutdown(pToken)