#Requires AutoHotkey v2.0
#Include Gdip_All.ahk ; Ensure you have the AHK v2 compatible version of Gdip

; --- GDI+ Initialization ---
if !pToken := Gdip_Startup() {
    MsgBox "Critical Error: GDI+ failed to start. Please check if the library is present."
    ExitApp
}

; --- Menu Configuration ---
menuSize := 400
innerRadius := 50
outerRadius := 180
menuColor := 0xAA222222 ; Background color (ARGB - Semi-transparent Dark Grey)
borderColor := 0xFFFFFFFF ; Border color (ARGB - Solid White)
centerX := A_ScreenWidth // 2
centerY := A_ScreenHeight // 2

; --- GUI Creation ---
; +E0x80000 is WS_EX_LAYERED, required for UpdateLayeredWindow to work
radialGui := Gui("-Caption +E0x80000 +AlwaysOnTop +ToolWindow +OwnDialogs")
radialGui.Show("NA")

; Hotkey Trigger
$5:: {
    ; Redraw the menu while the key is physically held down
    while GetKeyState("5", "P") {
        DrawEmptyRadial()
        Sleep(16) ; Target ~60 FPS to reduce CPU load
    }
    ; Clear the graphics once the key is released
    ClearRadial()
}

DrawEmptyRadial() {
    global pToken, radialGui, menuSize, centerX, centerY, menuColor, borderColor, innerRadius
    
    ; Prepare drawing context: DIB Section -> HDC -> Graphics Object
    hbm := CreateDIBSection(menuSize, menuSize)
    hdc := CreateCompatibleDC()
    obm := SelectObject(hdc, hbm)
    pGraphics := Gdip_GraphicsFromHDC(hdc)
    
    ; Enable Anti-aliasing for smooth edges
    Gdip_SetSmoothingMode(pGraphics, 4) 

    ; 1. Draw the main circle (Background fill)
    pBrush := Gdip_BrushCreateSolid(menuColor)
    Gdip_FillEllipse(pGraphics, pBrush, 0, 0, menuSize, menuSize)
    Gdip_DeleteBrush(pBrush)

    ; 2. Draw the outer border (Pen)
    pPen := Gdip_CreatePen(borderColor, 3)
    Gdip_DrawEllipse(pGraphics, pPen, 1, 1, menuSize-2, menuSize-2)
    Gdip_DeletePen(pPen)

    ; 3. Cut out the center hole (Donut effect)
    ; Set CompositingMode to SourceCopy (1) to replace existing pixels with transparency
    Gdip_SetCompositingMode(pGraphics, 1) 
    pBrushClear := Gdip_BrushCreateSolid(0x00000000) ; Fully transparent brush
    mid := menuSize // 2
    Gdip_FillEllipse(pGraphics, pBrushClear, mid - innerRadius, mid - innerRadius, innerRadius * 2, innerRadius * 2)
    Gdip_DeleteBrush(pBrushClear)

    ; Update the Layered Window with the newly drawn HDC
    UpdateLayeredWindow(radialGui.Hwnd, hdc, centerX - mid, centerY - mid, menuSize, menuSize)

    ; Clean up GDI+ resources to prevent memory leaks
    SelectObject(hdc, obm)
    DeleteObject(hbm)
    DeleteDC(hdc)
    Gdip_DeleteGraphics(pGraphics)
}

ClearRadial() {
    global radialGui, menuSize
    ; Clear the window by updating it with an empty/transparent DC
    hdc := CreateCompatibleDC()
    hbm := CreateDIBSection(menuSize, menuSize)
    obm := SelectObject(hdc, hbm)
    UpdateLayeredWindow(radialGui.Hwnd, hdc)
    
    SelectObject(hdc, obm)
    DeleteObject(hbm)
    DeleteDC(hdc)
}

; Cleanup GDI+ on script exit
OnExit ExitFunc
ExitFunc(*) {
    global pToken
    Gdip_Shutdown(pToken)
}