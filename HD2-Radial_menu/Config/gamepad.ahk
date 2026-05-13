#Requires AutoHotkey v2.0
; Gamepad.ahk - Gamepad support module for Radial Menu
; Provides gamepad detection, button mapping, and input handling

; ===GAMEPAD GLOBAL VARIABLES===
global GamepadEnabled := false
global GamepadMenuButton := "RB"  ; Default to RB button (Xbox layout)
global GamepadMenuButtonDDLValue := ""  ; Stores "[Input]" or button name from DDL selection
global OCRGamepadButton := ""  ; Empty = disabled
global OCRGamepadButtonDDLValue := "[Input]"
global OCRHoldStartTick := 0
global OCRTriggered := false
global GamepadConnected := false
global GamepadType := "Xbox"  ; "Xbox" or "PlayStation"
global GamepadNavigationStick := "Right"  ; "Left" or "Right" stick for radial menu navigation
global GamepadJoyID := 1  ; Joystick ID (1-16)

; Gamepad button names mapping
global GamepadButtonNames := Map(
    "Xbox", ["A", "B", "X", "Y", "LB", "RB", "LT", "RT", "Back", "Start", "LS", "RS", "DPadUp", "DPadDown", "DPadLeft", "DPadRight"],
    "PlayStation", ["Cross", "Circle", "Square", "Triangle", "L1", "R1", "L2", "R2", "Select", "Start", "L3", "R3", "DPadUp", "DPadDown", "DPadLeft", "DPadRight"]
)

; Joystick button numbers (1-based, standard DirectInput mapping)
; Xbox controller: A=1, B=2, X=3, Y=4, LB=5, RB=6, Back=7, Start=8, LS=9, RS=10
; LT and RT are triggers (axes) - handled separately via JoyZ
global GamepadButtonNumbers := Map(
    "A", 1,
    "B", 2,
    "X", 3,
    "Y", 4,
    "LB", 5,
    "RB", 6,
    "Back", 7,
    "Start", 8,
    "LS", 9,
    "RS", 10,
    "LT", "TriggerL",  ; Left trigger - uses JoyZ axis
    "RT", "TriggerR",  ; Right trigger - uses JoyZ axis
    ; D-Pad is handled as POV hat
    "DPadUp", "POV0",
    "DPadDown", "POV180",
    "DPadLeft", "POV270",
    "DPadRight", "POV90"
)

; PlayStation controller button names to Xbox equivalents
global PSButtonToXbox := Map(
    "Cross", "A",
    "Circle", "B",
    "Square", "X",
    "Triangle", "Y",
    "L1", "LB",
    "R1", "RB",
    "L2", "LT",
    "R2", "RT",
    "Select", "Back",
    "Start", "Start",
    "L3", "LS",
    "R3", "RS"
)

; ===GAMEPAD INITIALIZATION===
InitGamepad() {
    global GamepadEnabled, GamepadConnected
    
    ; Check initial connection status
    CheckGamepadConnection()
}

; ===GAMEPAD CONNECTION CHECK===
CheckGamepadConnection(*) {
    global GamepadConnected, GamepadJoyID
    
    ; Reset
    GamepadConnected := false
    GamepadJoyID := 0
    
    ; Check which joystick is connected (1-16)
    try {
        Loop 16 {
            ; GetJoyName returns the name of the joystick if connected
            joyName := GetKeyState("Joy" A_Index, "Name")
            if (joyName != "" && joyName != "Error") {
                GamepadConnected := true
                GamepadJoyID := A_Index
                break
            }
        }
        
        ; Fallback: check if any buttons work
        if (!GamepadConnected) {
            Loop 16 {
                if (GetKeyState("Joy" A_Index, "P") != "") {
                    GamepadConnected := true
                    GamepadJoyID := A_Index
                    break
                }
            }
        }
    } catch {
        GamepadConnected := false
        GamepadJoyID := 0
    }
    
    ; Update status text if GUI is created
    try {
        UpdateGamepadStatusText()
    }
}

; Update gamepad status text in GUI
UpdateGamepadStatusText() {
    global GamepadConnected, GamepadEnabled, gamepadStatusText
    
    if (!IsSet(gamepadStatusText) || !gamepadStatusText)
        return
    
    if (!GamepadEnabled) {
        gamepadStatusText.Opt("c808080")  ; Gray
        gamepadStatusText.Value := "○ Disabled"
    } else if (GamepadConnected) {
        gamepadStatusText.Opt("c00FF00")  ; Green
        gamepadStatusText.Value := "● Connected"
    } else {
        gamepadStatusText.Opt("cFF0000")  ; Red
        gamepadStatusText.Value := "○ Disconnected"
    }
}

; ===GAMEPAD BUTTON CHECK===
; Returns true if the specified gamepad button is pressed
IsGamepadButtonPressed(buttonName) {
    global GamepadButtonNumbers, GamepadType
    
    ; Handle direct JoyN format (e.g., "Joy11", "Joy12", etc.)
    if (InStr(buttonName, "Joy") = 1) {
        buttonNum := SubStr(buttonName, 4)
        try {
            return GetKeyState("Joy" . buttonNum, "P")
        }
        return false
    }
    
    ; Normalize button name for PlayStation controllers
    if (GamepadType = "PlayStation" && PSButtonToXbox.Has(buttonName))
        buttonName := PSButtonToXbox[buttonName]
    
    if (!GamepadButtonNumbers.Has(buttonName))
        return false
    
    buttonCode := GamepadButtonNumbers[buttonName]
    
    ; Handle triggers (LT/RT) - use JoyZ axis
    if (buttonCode = "TriggerL") {
        try {
            ; LT uses upper half of JoyZ (50-100 when pressed)
            joyZ := GetKeyState("JoyZ", "P")
            return (joyZ != "" && joyZ > 60)
        }
        return false
    }
    if (buttonCode = "TriggerR") {
        try {
            ; RT uses lower half of JoyZ (0-50 when pressed)
            joyZ := GetKeyState("JoyZ", "P")
            return (joyZ != "" && joyZ < 40)
        }
        return false
    }
    
    ; Handle D-Pad (POV hat)
    if (InStr(buttonCode, "POV") = 1) {
        povValue := SubStr(buttonCode, 4)
        try {
            currentPOV := GetKeyState("JoyPOV", "P")
            if (currentPOV = "")
                return false
            
            ; POV returns -1 (centered) or 0-35900 (hundredths of degrees)
            if (povValue = "0" && (currentPOV >= 0 && currentPOV < 4500 || currentPOV > 31500))
                return true
            if (povValue = "90" && currentPOV >= 4500 && currentPOV < 13500)
                return true
            if (povValue = "180" && currentPOV >= 13500 && currentPOV < 22500)
                return true
            if (povValue = "270" && currentPOV >= 22500 && currentPOV < 31500)
                return true
        }
        return false
    }
    
    ; Handle regular buttons
    try {
        return GetKeyState("Joy" buttonCode, "P")
    }
    
    return false
}

; Wait for gamepad button release
WaitGamepadButtonRelease(buttonName) {
    global GamepadButtonNumbers, GamepadType, PSButtonToXbox
    
    ; Handle direct JoyN format (e.g., "Joy11", "Joy12", etc.)
    if (InStr(buttonName, "Joy") = 1) {
        buttonNum := SubStr(buttonName, 4)
        try {
            while (GetKeyState("Joy" . buttonNum, "P")) {
                Sleep(10)
            }
        }
        return
    }
    
    ; Normalize button name for PlayStation controllers
    if (GamepadType = "PlayStation" && PSButtonToXbox.Has(buttonName))
        buttonName := PSButtonToXbox[buttonName]
    
    if (!GamepadButtonNumbers.Has(buttonName))
        return
    
    buttonCode := GamepadButtonNumbers[buttonName]
    
    ; Handle triggers (LT/RT)
    if (buttonCode = "TriggerL" || buttonCode = "TriggerR") {
        while (IsGamepadButtonPressed(buttonName)) {
            Sleep(10)
        }
        return
    }
    
    ; Handle D-Pad
    if (InStr(buttonCode, "POV") = 1) {
        while (IsGamepadButtonPressed(buttonName)) {
            Sleep(10)
        }
        return
    }
    
    ; Handle regular buttons
    try {
        while (GetKeyState("Joy" buttonCode, "P")) {
            Sleep(10)
        }
    }
}

; ===GAMEPAD INPUT HANDLER===
; Handler for gamepad menu button press
GamepadMenuHandler(*) {
    global GamepadMenuButton, IsMenuVisible, IsExecutingMacro, BlockCameraBypass
    global radialGui, SelectedSector, ForceRadialRedraw, ActiveStratagems, RadialMenuKey
    global ScreenCX, ScreenCY, OCRScramblerBypassEnabled, ScramblerRadialMode
    global StratagemMenuKey, MenuInputType, PostMenuDelay, MenuOpenDelay
    
    ; Prevent re-entry
    if (IsMenuVisible)
        return
    
    if (IsExecutingMacro)
        return
    
    ; === SCRAMBLER BYPASS MODE ===
    ; When enabled, capture actual icon screenshots from in-game stratagem menu
    if (OCRScramblerBypassEnabled) {
        
        ; Open stratagem menu first
        menuWasOpened := false
        if (StratagemMenuKey != "") {
            ExecuteKeyInput(StratagemMenuKey, MenuInputType, "down")
            menuWasOpened := true
            ; Wait for menu to fully open
            Sleep(MenuOpenDelay)
        }

        ; Capture icons from screen (actual bitmap screenshots)
        capturedCount := Icon_CaptureAllIcons()

        ; Close the stratagem menu after capturing only if camera bypass is active
        ; (otherwise keep it open so RunScramblerMacro doesn't need to reopen it)
        if (menuWasOpened && BlockCameraBypass) {
            if (MenuInputType = 5)
                ExecuteKeyInput(StratagemMenuKey, MenuInputType, "up")
            else {
                Sleep(25)
                ExecuteKeyInput(StratagemMenuKey, MenuInputType, "down")
                Sleep(25)
                ExecuteKeyInput(StratagemMenuKey, MenuInputType, "up")
            }
        }

        if (capturedCount = 0) {
            ; Close the menu if it was left open when bypass is not active
            if (menuWasOpened && !BlockCameraBypass) {
                if (MenuInputType = 5)
                    ExecuteKeyInput(StratagemMenuKey, MenuInputType, "up")
                else {
                    Sleep(25)
                    ExecuteKeyInput(StratagemMenuKey, MenuInputType, "down")
                    Sleep(25)
                    ExecuteKeyInput(StratagemMenuKey, MenuInputType, "up")
                }
            }
            ToolTip("Scrambler: No stratagems detected!", A_ScreenWidth - 200, A_ScreenHeight - 50)
            SetTimer(RemoveToolTip, -2000)
            return
        }

        ; Set scrambler mode flag for radial menu drawing
        global ScramblerRadialMode := true
        ForceRadialRedraw := true
    }
    
    ; In scrambler mode, use captured count; otherwise use ActiveStratagems
    displayCount := OCRScramblerBypassEnabled ? Icon_GetCapturedCount() : ActiveStratagems.Length

    if (displayCount = 0) {
        ToolTip("No stratagems in active profile!", A_ScreenWidth - 200, A_ScreenHeight - 50)
        SetTimer(RemoveToolTip, -2000)
        if (OCRScramblerBypassEnabled) {
            global ScramblerRadialMode
            ScramblerRadialMode := false
            Icon_DisposeCapturedIcons()
        }
        return
    }
    
    ; Switch profile hotkeys to blocking mode
    SetProfileSwitchHotkeys(false)
    
    ; Set flag immediately
    IsMenuVisible := true
    SelectedSector := 0
    ForceRadialRedraw := true
    
    ; Lock camera if enabled (skip RMB for gamepad)
    if (BlockCameraBypass) {
        StartCameraBypass(true)
    }
    
    ShowCursor(false)
    DllCall("mouse_event", "UInt", 0x8001, "UInt", 32768, "UInt", 32768, "UInt", 0, "UPtr", 0)
    DllCall("SetCursorPos", "Int", ScreenCX, "Int", ScreenCY)
    ClipCursor(true, ScreenCX-MenuSize//2, ScreenCY-MenuSize//2, ScreenCX+MenuSize//2, ScreenCY+MenuSize//2)
    
    ; Destroy any existing radialGui
    if (IsSet(radialGui) && radialGui) {
        try radialGui.Destroy()
        radialGui := 0
    }
    
    radialGui := Gui("-Caption +E0x80000 +AlwaysOnTop +ToolWindow")
    if !IsObject(radialGui) {
        IsMenuVisible := false
        ShowCursor(true), ClipCursor(false)
        if (BlockCameraBypass) {
            EndCameraBypass()
        }
        if (OCRScramblerBypassEnabled) {
            Icon_DisposeCapturedIcons()
            global ScramblerRadialMode
            ScramblerRadialMode := false
        }
        return
    }
    radialGui.Show("Na")
    
    ; Use gamepad-specific watcher
    SetTimer(WatchGamepad, 10)
    
    ; Wait for button release
    WaitGamepadButtonRelease(GamepadMenuButton)
    
    ; Close menu and execute
    SetTimer(WatchGamepad, 0)
    ShowCursor(true), ClipCursor(false)
    
    choice := SelectedSector
    
    if (IsSet(radialGui) && radialGui) {
        radialGui.Destroy()
        radialGui := 0
    }
    
    ; Release camera lock (skip RMB for gamepad)
    if (BlockCameraBypass) {
        EndCameraBypass(true)
    }
    
    ; Switch profile hotkeys back
    SetProfileSwitchHotkeys(true)
    
    IsMenuVisible := false
    
    ; Execute selected stratagem
    if (choice > 0) {
        ; In Scrambler Bypass mode, execute using the slot position
        if (OCRScramblerBypassEnabled) {
            ; Get the slot number for the selected index
            slot := Icon_GetSlotByIndex(choice)
            if (slot > 0) {
                ; Execute the arrow sequence for this slot
                RunScramblerMacro(slot)
            }
            
            ; Dispose captured icons after execution
            Icon_DisposeCapturedIcons()
            global ScramblerRadialMode
            ScramblerRadialMode := false
            
            ; Close stratagem menu if it was left open (no camera bypass)
            if (!BlockCameraBypass && StratagemMenuKey != "") {
                Sleep(25)
                if (MenuInputType = 5)
                    ExecuteKeyInput(StratagemMenuKey, MenuInputType, "up")
                else
                    ExecuteKeyInput(StratagemMenuKey, MenuInputType, "down")
                Sleep(25)
            }
        } else if (ActiveStratagems.Length > 0 && choice <= ActiveStratagems.Length) {
            ; Normal mode
            RunMacro(ActiveStratagems[choice])
        }
    } else if (OCRScramblerBypassEnabled) {
        ; No choice made - dispose captured icons
        Icon_DisposeCapturedIcons()
        global ScramblerRadialMode
        ScramblerRadialMode := false
        
        ; Close stratagem menu if it was left open (no camera bypass)
        if (!BlockCameraBypass && StratagemMenuKey != "") {
            Sleep(25)
            if (MenuInputType = 5)
                ExecuteKeyInput(StratagemMenuKey, MenuInputType, "up")
            else
                ExecuteKeyInput(StratagemMenuKey, MenuInputType, "down")
            Sleep(25)
        }
    }
}

; Watch gamepad input for radial menu selection
WatchGamepad() {
    global SelectedSector, LastDrawnSector, LastDrawnMX, LastDrawnMY, ForceRadialRedraw
    global IsMenuVisible, ActiveStratagems, ScreenCX, ScreenCY, MenuSize, InnerRadius
    global radialGui, GamepadNavigationStick
    global OCRScramblerBypassEnabled, ScramblerRadialMode
    
    if (!IsMenuVisible)
        return
    
    ; In scrambler mode, check captured count
    if (OCRScramblerBypassEnabled && ScramblerRadialMode) {
        if Icon_GetCapturedCount() = 0
            return
    } else {
        if ActiveStratagems.Length = 0
            return
    }
    
    ; Get thumbstick position for selection based on selected stick
    ; Left thumbstick: JoyX/JoyY, Right thumbstick: JoyR/U (0-100, center ~50)
    ; D-Pad uses POV hat (returns angle in hundredths of degrees, -1 when centered)
    try {
        if (GamepadNavigationStick = "DPad") {
            ; D-Pad uses POV hat
            pov := GetKeyState("JoyPOV", "P")
            if (pov = "" || pov < 0) {
                ; Centered - no direction
                joyX := 50
                joyY := 50
            } else {
            ; POV returns 0-35999 (hundredths of degrees)
                ; 0 = Up, 9000 = Right, 18000 = Down, 27000 = Left
                ; Convert angle to X/Y coordinates (0-100 range, 50 = center)
                angleRad := pov * 3.14159 / 18000  ; Convert to radians
                ; X: sin(angle) -> 0=left, 100=right
                ; Y: -cos(angle) -> 0=up, 100=down
                joyX := 50 + Round(50 * Sin(angleRad))
                joyY := 50 - Round(50 * Cos(angleRad))
            }
        } else if (GamepadNavigationStick = "Right") {
            ; Right stick: JoyU is X-axis, JoyR is Y-axis (swapped compared to left stick)
            joyX := Integer(GetKeyState("JoyU", "P"))
            joyY := Integer(GetKeyState("JoyR", "P"))
        } else {
            ; Left stick uses JoyX and JoyY
            joyX := Integer(GetKeyState("JoyX", "P"))
            joyY := Integer(GetKeyState("JoyY", "P"))
        }
    } catch {
        joyX := 50
        joyY := 50
    }
    
    ; Convert to screen coordinates centered on screen
    centerX := ScreenCX
    centerY := ScreenCY
    halfSize := MenuSize // 2
    
    ; Map joystick position to screen position
    ; JoyX/JoyY: 0 = left/up, 50 = center, 100 = right/down
    ; Convert from 0-100 range to screen coordinates
    mx := centerX + ((joyX - 50) * halfSize // 50)
    my := centerY + ((joyY - 50) * halfSize // 50)
    
    ; Calculate distance and angle from center
    dx := mx - ScreenCX
    dy := my - ScreenCY
    dist := Sqrt(dx**2 + dy**2)
    
    ; Get count based on mode
    count := (OCRScramblerBypassEnabled && ScramblerRadialMode) ? Icon_GetCapturedCount() : ActiveStratagems.Length
    sectorAngle := 360 / count
    
    newSector := 0
    if dist > InnerRadius {
        angle := DllCall("msvcrt\atan2", "Double", dy, "Double", dx, "CDECL Double") * 180 / 3.14159
        angle := Mod(angle + 360 + (sectorAngle/2) + 90, 360)
        newSector := Floor(angle / sectorAngle) + 1
        if newSector > count || newSector < 1
            newSector := 1
    }
    
    ; Redraw if needed
    if (ForceRadialRedraw || newSector != LastDrawnSector || Abs(mx - LastDrawnMX) > 3 || Abs(my - LastDrawnMY) > 3) {
        if (IsSet(radialGui))
            DrawRadial(ScreenCX, ScreenCY, mx, my, newSector)
        LastDrawnSector := newSector
        LastDrawnMX := mx
        LastDrawnMY := my
        ForceRadialRedraw := false
    }
    
    SelectedSector := newSector
}

; ===GAMEPAD HOTKEY SETUP===
SetGamepadHotkey() {
    global GamepadEnabled
    
    ; Stop any polling timers first
    SetTimer(CheckGamepadPolling, 0)
    
    ; When gamepad is enabled, use polling.
    if (!GamepadEnabled)
        return

    SetTimer(CheckGamepadPolling, 50)
}

; Check D-Pad and Triggers for menu activation (polling)
CheckGamepadPolling() {
    global GamepadEnabled, GamepadMenuButton, IsMenuVisible
    static statusTick := 0
    
    if (!GamepadEnabled || IsMenuVisible)
        return

    ; Refresh connection/status periodically while polling is active (about once per second)
    statusTick++
    if (statusTick >= 20) {
        statusTick := 0
        CheckGamepadConnection()
    }

    ; OCR trigger by gamepad hold
    CheckOCRGamepadTrigger()
    
    ; Scrambler Bypass toggle by gamepad button
    CheckBypassGamepadTrigger()
    
    if (IsGamepadButtonPressed(GamepadMenuButton)) {
        GamepadMenuHandler()
    }
}

; Check if bypass gamepad button is pressed (supports hold mode)
CheckBypassGamepadTrigger() {
    global BypassGamepadButton, GamepadEnabled, IsMenuVisible, IsExecutingMacro
    global BypassUseHold, BypassHoldMs
    static bypassTriggered := false
    static bypassHoldStartTick := 0
    
    if (!GamepadEnabled || BypassGamepadButton = "" || IsMenuVisible || IsExecutingMacro)
        return
    
    isPressed := IsGamepadButtonPressed(BypassGamepadButton)
    
    if (isPressed) {
        ; No hold mode: trigger once on press
        if (!BypassUseHold) {
            if (!bypassTriggered) {
                bypassTriggered := true
                try ToggleOCRScramblerBypass()
            }
            return
        }
        
        ; Hold mode
        if (bypassHoldStartTick = 0) {
            bypassHoldStartTick := A_TickCount
            bypassTriggered := false
        }
        
        if (!bypassTriggered && (A_TickCount - bypassHoldStartTick >= BypassHoldMs)) {
            bypassTriggered := true
            try ToggleOCRScramblerBypass()
        }
    } else {
        bypassHoldStartTick := 0
        bypassTriggered := false
    }
}

CheckOCRGamepadTrigger() {
    global OCRGamepadButton, OCRUseHold, OCRHoldMs, OCRHoldStartTick, OCRTriggered
    global GamepadEnabled, IsMenuVisible, IsExecutingMacro

    if (!GamepadEnabled || OCRGamepadButton = "" || IsMenuVisible || IsExecutingMacro)
        return

    isPressed := IsGamepadButtonPressed(OCRGamepadButton)

    if (isPressed) {
        ; No hold mode: trigger once on press
        if (!OCRUseHold) {
            if (!OCRTriggered) {
                OCRTriggered := true
                try OCRAnalyzeAndSwitchProfile()
            }
            return
        }

        ; Hold mode
        if (OCRHoldStartTick = 0) {
            OCRHoldStartTick := A_TickCount
            OCRTriggered := false
        }

        if (!OCRTriggered && (A_TickCount - OCRHoldStartTick >= OCRHoldMs)) {
            OCRTriggered := true
            try OCRAnalyzeAndSwitchProfile()
        }
    } else {
        OCRHoldStartTick := 0
        OCRTriggered := false
    }
}

; ===SAVE/LOAD GAMEPAD SETTINGS===
LoadGamepadSettings() {
    global IniPath, GamepadEnabled, GamepadMenuButton, GamepadType, GamepadNavigationStick
    global OCRGamepadButton, OCRUseHold, OCRHoldMs, BypassGamepadButton
    global BypassUseHold, BypassHoldMs
    
    try {
        GamepadEnabled := IniRead(IniPath, "Gamepad", "Enabled", "0") = "1" ? true : false
        GamepadMenuButton := IniRead(IniPath, "Gamepad", "MenuButton", "RB")
        GamepadType := IniRead(IniPath, "Gamepad", "ControllerType", "Xbox")
        GamepadNavigationStick := IniRead(IniPath, "Gamepad", "NavigationStick", "Right")
        OCRGamepadButton := IniRead(IniPath, "OCR", "GamepadButton", "")
        OCRUseHold := IniRead(IniPath, "OCR", "OCRUseHold", "0") = "1"
        OCRHoldMs := Integer(IniRead(IniPath, "OCR", "OCRHoldMs", "700"))
        BypassGamepadButton := IniRead(IniPath, "OCR", "BypassGamepadButton", "")
        BypassUseHold := IniRead(IniPath, "OCR", "BypassUseHold", "0") = "1"
        BypassHoldMs := Integer(IniRead(IniPath, "OCR", "BypassHoldMs", "700"))
    } catch {
        ; Use defaults
        GamepadEnabled := false
        GamepadMenuButton := "RB"
        GamepadType := "Xbox"
        GamepadNavigationStick := "Right"
        OCRGamepadButton := ""
        OCRUseHold := false
        OCRHoldMs := 700
        BypassGamepadButton := ""
        BypassUseHold := false
        BypassHoldMs := 700
    }
}

; Set the dropdown selection based on current GamepadMenuButton
SetGamepadMenuButtonDDL() {
    global gamepadMenuButtonDDL, GamepadMenuButton, GamepadButtonNames, GamepadType, GamepadMenuButtonDDLValue
    
    ; Check if current button is in the standard list
    buttons := GamepadButtonNames[GamepadType]
    found := false
    
    for i, btn in buttons {
        if (btn = GamepadMenuButton) {
            ; Button is in standard list - select it (index + 1 because [Input] is at index 1)
            gamepadMenuButtonDDL.Choose(i + 1)
            GamepadMenuButtonDDLValue := GamepadMenuButton
            found := true
            break
        }
    }
    
    if (!found) {
        ; Button is not in standard list - select [Input]
        gamepadMenuButtonDDL.Choose(1)
        GamepadMenuButtonDDLValue := "[Input]"
    }
}

; Handle dropdown change
OnGamepadMenuButtonDDLChange(*) {
    global gamepadMenuButtonDDL, GamepadMenuButton, GamepadMenuButtonDDLValue, IniPath
    
    selection := gamepadMenuButtonDDL.Text
    
    if (selection = "[Input]") {
        ; User selected [Input] - keep current button, just update DDL tracking
        GamepadMenuButtonDDLValue := "[Input]"
    } else {
        ; User selected a standard button
        GamepadMenuButton := selection
        GamepadMenuButtonDDLValue := selection
        IniWrite(GamepadMenuButton, IniPath, "Gamepad", "MenuButton")
        
        ; Re-register hotkey with new button
        SetGamepadHotkey()
    }
}

; ===GAMEPAD SETTINGS UPDATE HANDLERS===
ToggleGamepadEnabled(*) {
    global GamepadEnabled, gamepadEnabledCheckbox, IniPath
    
    GamepadEnabled := gamepadEnabledCheckbox.Value
    IniWrite(GamepadEnabled ? "1" : "0", IniPath, "Gamepad", "Enabled")
    
    if (GamepadEnabled) {
        InitGamepad()
        SetGamepadHotkey()
    } else {
        SetTimer(CheckGamepadPolling, 0)
    }
    
    UpdateGamepadStatusText()
}

UpdateGamepadType(*) {
    global GamepadType, gamepadTypeDDL, gamepadMenuButtonDDL, IniPath
    
    GamepadType := gamepadTypeDDL.Value = 1 ? "Xbox" : "PlayStation"
    IniWrite(GamepadType, IniPath, "Gamepad", "ControllerType")
    
    ; Update button dropdown with appropriate names
    UpdateGamepadButtonDropdown()
}

UpdateGamepadButtonDropdown() {
    global gamepadMenuButtonDDL, GamepadType, GamepadMenuButton, GamepadButtonNames, GamepadMenuButtonDDLValue
    
    ; Get current selection
    currentButton := GamepadMenuButton
    
    ; Update dropdown list with [Input] at the beginning
    gamepadMenuButtonDDL.Delete()
    gamepadMenuButtonDDL.Add(["[Input]"])
    buttons := GamepadButtonNames[GamepadType]
    gamepadMenuButtonDDL.Add(buttons)
    
    ; Try to select the same button (convert between Xbox/PS names)
    if (GamepadType = "PlayStation") {
        ; Convert Xbox button to PS button name
        xboxToPS := Map(
            "A", "Cross",
            "B", "Circle",
            "X", "Square",
            "Y", "Triangle",
            "LB", "L1",
            "RB", "R1",
            "Back", "Select",
            "Start", "Start",
            "LS", "L3",
            "RS", "R3"
        )
        if (xboxToPS.Has(currentButton))
            currentButton := xboxToPS[currentButton]
    } else {
        ; Convert PS button to Xbox button name
        psToXbox := Map(
            "Cross", "A",
            "Circle", "B",
            "Square", "X",
            "Triangle", "Y",
            "L1", "LB",
            "R1", "RB",
            "Select", "Back",
            "L3", "LS",
            "R3", "RS"
        )
        if (psToXbox.Has(currentButton))
            currentButton := psToXbox[currentButton]
    }
    
    ; Select the button in dropdown (index + 1 because [Input] is at index 1)
    for i, btn in buttons {
        if (btn = currentButton) {
            gamepadMenuButtonDDL.Choose(i + 1)
            GamepadMenuButtonDDLValue := currentButton
            break
        }
    }
}

UpdateGamepadNavigationStick(*) {
    global GamepadNavigationStick, gamepadNavigationStickDDL, IniPath
    
    GamepadNavigationStick := gamepadNavigationStickDDL.Value = 1 ? "Right" : (gamepadNavigationStickDDL.Value = 2 ? "Left" : "DPad")
    IniWrite(GamepadNavigationStick, IniPath, "Gamepad", "NavigationStick")
}

; OCR gamepad button helpers
SetOCRGamepadButtonDDL() {
    global ocrGamepadButtonDDL, OCRGamepadButton, GamepadButtonNames, GamepadType, OCRGamepadButtonDDLValue

    buttons := GamepadButtonNames[GamepadType]
    found := false

    for i, btn in buttons {
        if (btn = OCRGamepadButton) {
            ocrGamepadButtonDDL.Choose(i + 1)
            OCRGamepadButtonDDLValue := OCRGamepadButton
            found := true
            break
        }
    }

    if (!found) {
        ocrGamepadButtonDDL.Choose(1)
        OCRGamepadButtonDDLValue := "[Input]"
    }
}

OnOCRGamepadButtonDDLChange(*) {
    global ocrGamepadButtonDDL, OCRGamepadButton, OCRGamepadButtonDDLValue, IniPath

    selection := ocrGamepadButtonDDL.Text
    if (selection = "[Input]") {
        OCRGamepadButtonDDLValue := "[Input]"
        return
    }

    OCRGamepadButton := selection
    OCRGamepadButtonDDLValue := selection
    IniWrite(OCRGamepadButton, IniPath, "OCR", "GamepadButton")
}

UpdateOCRGamepadButtonDropdown() {
    global ocrGamepadButtonDDL, GamepadType, OCRGamepadButton, GamepadButtonNames, OCRGamepadButtonDDLValue

    if (!IsSet(ocrGamepadButtonDDL) || !ocrGamepadButtonDDL)
        return

    currentButton := OCRGamepadButton

    ocrGamepadButtonDDL.Delete()
    ocrGamepadButtonDDL.Add(["[Input]"])
    buttons := GamepadButtonNames[GamepadType]
    ocrGamepadButtonDDL.Add(buttons)

    if (GamepadType = "PlayStation") {
        xboxToPS := Map(
            "A", "Cross", "B", "Circle", "X", "Square", "Y", "Triangle",
            "LB", "L1", "RB", "R1", "Back", "Select", "Start", "Start",
            "LS", "L3", "RS", "R3"
        )
        if (xboxToPS.Has(currentButton))
            currentButton := xboxToPS[currentButton]
    } else {
        psToXbox := Map(
            "Cross", "A", "Circle", "B", "Square", "X", "Triangle", "Y",
            "L1", "LB", "R1", "RB", "Select", "Back", "L3", "LS", "R3", "RS"
        )
        if (psToXbox.Has(currentButton))
            currentButton := psToXbox[currentButton]
    }

    for i, btn in buttons {
        if (btn = currentButton) {
            ocrGamepadButtonDDL.Choose(i + 1)
            OCRGamepadButtonDDLValue := currentButton
            return
        }
    }

    ocrGamepadButtonDDL.Choose(1)
    OCRGamepadButtonDDLValue := "[Input]"
}

UpdateOCRHoldMs(*) {
    global OCRHoldMs, ocrHoldEdit, IniPath

    OCRHoldMs := (ocrHoldEdit.Value = "") ? 0 : Integer(ocrHoldEdit.Value)
    needsUpdate := false
    if (OCRHoldMs < 0) {
        OCRHoldMs := 0
        needsUpdate := true
    }
    if (OCRHoldMs > 5000) {
        OCRHoldMs := 5000
        needsUpdate := true
    }

    if (needsUpdate)
        ocrHoldEdit.Value := OCRHoldMs
    IniWrite(OCRHoldMs, IniPath, "OCR", "OCRHoldMs")
}

UpdateOCRUseHold(*) {
    global OCRUseHold, ocrHoldCheckbox, ocrHoldEdit, IniPath

    OCRUseHold := ocrHoldCheckbox.Value
    IniWrite(OCRUseHold ? "1" : "0", IniPath, "OCR", "OCRUseHold")

    try ocrHoldEdit.Enabled := OCRUseHold
    
    ; Re-register OCR keyboard hotkey so hold mode takes effect immediately
    try SetOCRHotkey()
}

UpdateBypassHoldMs(*) {
    global BypassHoldMs, bypassHoldEdit, IniPath

    BypassHoldMs := (bypassHoldEdit.Value = "") ? 0 : Integer(bypassHoldEdit.Value)
    needsUpdate := false
    if (BypassHoldMs < 0) {
        BypassHoldMs := 0
        needsUpdate := true
    }
    if (BypassHoldMs > 5000) {
        BypassHoldMs := 5000
        needsUpdate := true
    }

    if (needsUpdate)
        bypassHoldEdit.Value := BypassHoldMs
    IniWrite(BypassHoldMs, IniPath, "OCR", "BypassHoldMs")
}

UpdateBypassUseHold(*) {
    global BypassUseHold, bypassHoldCheckbox, bypassHoldEdit, IniPath

    BypassUseHold := bypassHoldCheckbox.Value
    IniWrite(BypassUseHold ? "1" : "0", IniPath, "OCR", "BypassUseHold")

    try bypassHoldEdit.Enabled := BypassUseHold
    
    ; Re-register bypass keyboard hotkey so hold mode takes effect immediately
    try SetOCRBypassToggleHotkey()
}

ShowOCRGamepadCapturePopup(*) {
    global OCRGamepadButton, gamepadCaptureGui, gamepadCaptureTimer, gamepadCaptureWaiting

    ; Reuse capture popup logic from menu button capture,
    ; but write result to OCRGamepadButton.
    captureGui := Gui("-Caption +LastFound +AlwaysOnTop", "Capture OCR Gamepad Button")
    captureGui.BackColor := "202020"
    captureGui.SetFont("s10 cC4C4C4", "Segoe UI")
    captureGui.MarginX := Scale(5)
    captureGui.MarginY := Scale(5)

    captureGui.SetFont("cFFFFFF s12")
    captureGui.Add("Text", "x0 y0 w" Scale(280) " h" Scale(35) " Background2A2A2A Border +Center", "Capture OCR Gamepad Button").OnEvent("Click", (*) => PostMessage(0xA1, 2,,, "A"))
    captureGui.Add("Button", "x+5 y0 w" Scale(35) " h" Scale(35), "X").OnEvent("Click", (*) => captureGui.Destroy())
    captureGui.SetFont("s11 cC4C4C4")

    captureGui.Add("Text", "x" Scale(20) " y" Scale(50) " w" Scale(280) " Center", "Press a button on your gamepad...")
    global ocrGamepadCaptureDisplay := captureGui.Add("Text", "x" Scale(20) " y+10 w" Scale(280) " h" Scale(40) " Center cFFD700 Background333333", OCRGamepadButton = "" ? "[Not set]" : OCRGamepadButton)
    captureGui.Add("Button", "x" Scale(110) " y+25 w" Scale(100) " h" Scale(30), "Cancel").OnEvent("Click", (*) => captureGui.Destroy())
    captureGui.OnEvent("Escape", (*) => captureGui.Destroy())

    global ocrGamepadCaptureGui := captureGui
    global ocrGamepadCaptureTimer := true
    global ocrGamepadCaptureWaiting := true
    SetTimer(CaptureOCRGamepadButtonPopup, 50)

    captureGui.Show("w" Scale(320) " h" Scale(200))
}

CaptureOCRGamepadButtonPopup() {
    global ocrGamepadCaptureTimer, ocrGamepadCaptureGui, ocrGamepadCaptureWaiting

    if (!ocrGamepadCaptureTimer)
        return

    try {
        if (!IsSet(ocrGamepadCaptureGui) || !ocrGamepadCaptureGui || !WinExist("ahk_id " ocrGamepadCaptureGui.Hwnd)) {
            ocrGamepadCaptureTimer := false
            SetTimer(CaptureOCRGamepadButtonPopup, 0)
            return
        }
    } catch {
        ocrGamepadCaptureTimer := false
        SetTimer(CaptureOCRGamepadButtonPopup, 0)
        return
    }

    if (ocrGamepadCaptureWaiting) {
        anyPressed := false
        Loop 16 {
            joyID := A_Index
            Loop 32 {
                try {
                    if (GetKeyState(joyID . "Joy" . A_Index, "P")) {
                        anyPressed := true
                        break
                    }
                }
            }
            if (anyPressed)
                break
        }

        if (!anyPressed) {
            Loop 16 {
                joyID := A_Index
                try {
                    joyZ := GetKeyState(joyID . "JoyZ", "P")
                    if (joyZ != "" && (joyZ > 60 || joyZ < 40)) {
                        anyPressed := true
                        break
                    }
                }
                try {
                    pov := GetKeyState(joyID . "JoyPOV", "P")
                    if (pov != "" && pov >= 0) {
                        anyPressed := true
                        break
                    }
                }
            }
        }

        if (anyPressed)
            return

        ocrGamepadCaptureWaiting := false
        return
    }

    try {
        Loop 16 {
            joyID := A_Index
            Loop 32 {
                btnNum := A_Index
                try {
                    if (GetKeyState(joyID . "Joy" . btnNum, "P")) {
                        buttonMap := Map(1,"A", 2,"B", 3,"X", 4,"Y", 5,"LB", 6,"RB", 7,"Back", 8,"Start", 9,"LS", 10,"RS")
                        if (buttonMap.Has(btnNum)) {
                            CaptureOCRGamepadButtonPopupFound(buttonMap[btnNum])
                            return
                        }
                        CaptureOCRGamepadButtonPopupFound("Joy" . btnNum)
                        return
                    }
                }
            }

            try {
                joyZ := GetKeyState(joyID . "JoyZ", "P")
                if (joyZ != "") {
                    if (joyZ > 60) {
                        CaptureOCRGamepadButtonPopupFound("LT")
                        return
                    }
                    if (joyZ < 40) {
                        CaptureOCRGamepadButtonPopupFound("RT")
                        return
                    }
                }
            }

            try {
                pov := GetKeyState(joyID . "JoyPOV", "P")
                if (pov != "" && pov >= 0) {
                    if (pov >= 0 && pov < 4500 || pov > 31500) {
                        CaptureOCRGamepadButtonPopupFound("DPadUp")
                        return
                    }
                    if (pov >= 4500 && pov < 13500) {
                        CaptureOCRGamepadButtonPopupFound("DPadRight")
                        return
                    }
                    if (pov >= 13500 && pov < 22500) {
                        CaptureOCRGamepadButtonPopupFound("DPadDown")
                        return
                    }
                    if (pov >= 22500 && pov < 31500) {
                        CaptureOCRGamepadButtonPopupFound("DPadLeft")
                        return
                    }
                }
            }
        }
    }
}

CaptureOCRGamepadButtonPopupFound(buttonName) {
    global ocrGamepadCaptureTimer, ocrGamepadCaptureGui, ocrGamepadCaptureDisplay
    global OCRGamepadButton, IniPath

    ocrGamepadCaptureTimer := false
    SetTimer(CaptureOCRGamepadButtonPopup, 0)
    ocrGamepadCaptureDisplay.Value := buttonName

    OCRGamepadButton := buttonName
    IniWrite(OCRGamepadButton, IniPath, "OCR", "GamepadButton")

    SetTimer(() => (IsSet(ocrGamepadCaptureGui) && ocrGamepadCaptureGui ? ocrGamepadCaptureGui.Destroy() : 0), -500)
}

; ===BYPASS GAMEPAD BUTTON CAPTURE POPUP===
ShowBypassGamepadCapturePopup(*) {
    global BypassGamepadButton

    captureGui := Gui("-Caption +LastFound +AlwaysOnTop", "Capture Bypass Button")
    captureGui.BackColor := "202020"
    captureGui.SetFont("s10 cC4C4C4", "Segoe UI")
    captureGui.MarginX := Scale(5)
    captureGui.MarginY := Scale(5)

    captureGui.SetFont("cFFFFFF s12")
    captureGui.Add("Text", "x0 y0 w" Scale(280) " h" Scale(35) " Background2A2A2A Border +Center", "Capture Bypass Button").OnEvent("Click", (*) => PostMessage(0xA1, 2,,, "A"))
    captureGui.Add("Button", "x+5 y0 w" Scale(35) " h" Scale(35), "X").OnEvent("Click", (*) => captureGui.Destroy())
    captureGui.SetFont("s11 cC4C4C4")

    captureGui.Add("Text", "x" Scale(20) " y" Scale(50) " w" Scale(280) " Center", "Press a button on your gamepad...")
    global bypassGamepadCaptureDisplay := captureGui.Add("Text", "x" Scale(20) " y+10 w" Scale(280) " h" Scale(40) " Center cFFD700 Background333333", BypassGamepadButton = "" ? "[Not set]" : BypassGamepadButton)
    captureGui.Add("Button", "x" Scale(110) " y+25 w" Scale(100) " h" Scale(30), "Cancel").OnEvent("Click", (*) => captureGui.Destroy())
    captureGui.OnEvent("Escape", (*) => captureGui.Destroy())

    global bypassGamepadCaptureGui := captureGui
    global bypassGamepadCaptureTimer := true
    global bypassGamepadCaptureWaiting := true
    SetTimer(CaptureBypassGamepadButtonPopup, 50)

    captureGui.Show("w" Scale(320) " h" Scale(200))
}

CaptureBypassGamepadButtonPopup() {
    global bypassGamepadCaptureTimer, bypassGamepadCaptureGui, bypassGamepadCaptureWaiting

    if (!bypassGamepadCaptureTimer)
        return

    try {
        if (!IsSet(bypassGamepadCaptureGui) || !bypassGamepadCaptureGui || !WinExist("ahk_id " bypassGamepadCaptureGui.Hwnd)) {
            bypassGamepadCaptureTimer := false
            SetTimer(CaptureBypassGamepadButtonPopup, 0)
            return
        }
    } catch {
        bypassGamepadCaptureTimer := false
        SetTimer(CaptureBypassGamepadButtonPopup, 0)
        return
    }

    if (bypassGamepadCaptureWaiting) {
        anyPressed := false
        Loop 16 {
            joyID := A_Index
            Loop 32 {
                try {
                    if (GetKeyState(joyID . "Joy" . A_Index, "P")) {
                        anyPressed := true
                        break
                    }
                }
            }
            if (anyPressed)
                break
        }

        if (!anyPressed) {
            Loop 16 {
                joyID := A_Index
                try {
                    joyZ := GetKeyState(joyID . "JoyZ", "P")
                    if (joyZ != "" && (joyZ > 60 || joyZ < 40)) {
                        anyPressed := true
                        break
                    }
                }
                try {
                    pov := GetKeyState(joyID . "JoyPOV", "P")
                    if (pov != "" && pov >= 0) {
                        anyPressed := true
                        break
                    }
                }
            }
        }

        if (anyPressed)
            return

        bypassGamepadCaptureWaiting := false
        return
    }

    try {
        Loop 16 {
            joyID := A_Index
            Loop 32 {
                btnNum := A_Index
                try {
                    if (GetKeyState(joyID . "Joy" . btnNum, "P")) {
                        buttonMap := Map(1,"A", 2,"B", 3,"X", 4,"Y", 5,"LB", 6,"RB", 7,"Back", 8,"Start", 9,"LS", 10,"RS")
                        if (buttonMap.Has(btnNum)) {
                            CaptureBypassGamepadButtonPopupFound(buttonMap[btnNum])
                            return
                        }
                        CaptureBypassGamepadButtonPopupFound("Joy" . btnNum)
                        return
                    }
                }
            }

            try {
                joyZ := GetKeyState(joyID . "JoyZ", "P")
                if (joyZ != "") {
                    if (joyZ > 60) {
                        CaptureBypassGamepadButtonPopupFound("LT")
                        return
                    }
                    if (joyZ < 40) {
                        CaptureBypassGamepadButtonPopupFound("RT")
                        return
                    }
                }
            }

            try {
                pov := GetKeyState(joyID . "JoyPOV", "P")
                if (pov != "" && pov >= 0) {
                    if (pov >= 0 && pov < 4500 || pov > 31500) {
                        CaptureBypassGamepadButtonPopupFound("DPadUp")
                        return
                    }
                    if (pov >= 4500 && pov < 13500) {
                        CaptureBypassGamepadButtonPopupFound("DPadRight")
                        return
                    }
                    if (pov >= 13500 && pov < 22500) {
                        CaptureBypassGamepadButtonPopupFound("DPadDown")
                        return
                    }
                    if (pov >= 22500 && pov < 31500) {
                        CaptureBypassGamepadButtonPopupFound("DPadLeft")
                        return
                    }
                }
            }
        }
    }
}

CaptureBypassGamepadButtonPopupFound(buttonName) {
    global bypassGamepadCaptureTimer, bypassGamepadCaptureGui, bypassGamepadCaptureDisplay
    global BypassGamepadButton, IniPath

    bypassGamepadCaptureTimer := false
    SetTimer(CaptureBypassGamepadButtonPopup, 0)
    bypassGamepadCaptureDisplay.Value := buttonName

    BypassGamepadButton := buttonName
    IniWrite(BypassGamepadButton, IniPath, "OCR", "BypassGamepadButton")

    SetTimer(() => (IsSet(bypassGamepadCaptureGui) && bypassGamepadCaptureGui ? bypassGamepadCaptureGui.Destroy() : 0), -500)
}

; ===GAMEPAD BUTTON CAPTURE POPUP===
ShowGamepadCapturePopup(*) {
    global GamepadMenuButton, GamepadType, GamepadButtonNames
    
    ; Create capture popup
    captureGui := Gui("-Caption +LastFound +AlwaysOnTop", "Capture Gamepad Button")
    captureGui.BackColor := "202020"
    captureGui.SetFont("s10 cC4C4C4", "Segoe UI")
    captureGui.MarginX := Scale(5)
    captureGui.MarginY := Scale(5)
    
    ; Title bar
    captureGui.SetFont("cFFFFFF s12")
    captureGui.Add("Text", "x0 y0 w" Scale(280) " h" Scale(35) " Background2A2A2A Border +Center", "Capture Gamepad Button").OnEvent("Click", (*) => PostMessage(0xA1, 2,,, "A"))
    captureGui.Add("Button", "x+5 y0 w" Scale(35) " h" Scale(35), "X").OnEvent("Click", (*) => captureGui.Destroy())
    captureGui.SetFont("s11 cC4C4C4")
    
    captureGui.Add("Text", "x" Scale(20) " y" Scale(50) " w" Scale(280) " Center", "Press a button on your gamepad...")
    
    ; Current button display
    global gamepadCaptureDisplay := captureGui.Add("Text", "x" Scale(20) " y+10 w" Scale(280) " h" Scale(40) " Center cFFD700 Background333333", GamepadMenuButton)
    
    ; Cancel button
    captureGui.Add("Button", "x" Scale(110) " y+25 w" Scale(100) " h" Scale(30), "Cancel").OnEvent("Click", (*) => captureGui.Destroy())
    
    captureGui.OnEvent("Escape", (*) => captureGui.Destroy())
    
    ; Start capturing
    global gamepadCaptureGui := captureGui
    global gamepadCaptureTimer := true
    global gamepadCaptureWaiting := true  ; Wait for all buttons to be released first
    SetTimer(CaptureGamepadButtonPopup, 50)
    
    captureGui.Show("w" Scale(320) " h" Scale(200))
}

; Poll for gamepad button presses in popup
CaptureGamepadButtonPopup() {
    global gamepadCaptureTimer, gamepadCaptureGui, gamepadCaptureDisplay, gamepadCaptureWaiting
    global GamepadMenuButton, gamepadMenuButtonDDL, GamepadButtonNames, GamepadType, IniPath
    
    if (!gamepadCaptureTimer)
        return
    
    ; Check if popup is still visible
    try {
        if (!IsSet(gamepadCaptureGui) || !gamepadCaptureGui || !WinExist("ahk_id " gamepadCaptureGui.Hwnd)) {
            gamepadCaptureTimer := false
            SetTimer(CaptureGamepadButtonPopup, 0)
            return
        }
    } catch {
        gamepadCaptureTimer := false
        SetTimer(CaptureGamepadButtonPopup, 0)
        return
    }
    
    ; First, wait for all buttons to be released
    if (gamepadCaptureWaiting) {
        anyPressed := false
        
        ; Check all joysticks (1-16) for any button press
        Loop 16 {
            joyID := A_Index
            Loop 32 {
                try {
                    if (GetKeyState(joyID . "Joy" . A_Index, "P")) {
                        anyPressed := true
                        break
                    }
                }
            }
            if (anyPressed)
                break
        }
        
        ; Also check triggers and D-Pad on all joysticks
        if (!anyPressed) {
            Loop 16 {
                joyID := A_Index
                try {
                    joyZ := GetKeyState(joyID . "JoyZ", "P")
                    if (joyZ != "" && (joyZ > 60 || joyZ < 40)) {
                        anyPressed := true
                        break
                    }
                }
                try {
                    pov := GetKeyState(joyID . "JoyPOV", "P")
                    if (pov != "" && pov >= 0) {
                        anyPressed := true
                        break
                    }
                }
            }
        }
        
        if (anyPressed)
            return  ; Still waiting for release
        
        ; All buttons released, now ready to capture
        gamepadCaptureWaiting := false
        return
    }
    
    ; Now check for button presses on all joysticks
    try {
        Loop 16 {
            joyID := A_Index
            
            ; Check all buttons (1-32) on this joystick
            Loop 32 {
                btnNum := A_Index
                try {
                    if (GetKeyState(joyID . "Joy" . btnNum, "P")) {
                        ; Find button name for this index
                        buttonMap := Map(1,"A", 2,"B", 3,"X", 4,"Y", 5,"LB", 6,"RB", 7,"Back", 8,"Start", 9,"LS", 10,"RS")
                        if (buttonMap.Has(btnNum)) {
                            CaptureGamepadButtonPopupFound(buttonMap[btnNum])
                            return
                        }
                        ; Button not in standard map - use JoyN format
                        CaptureGamepadButtonPopupFound("Joy" . btnNum)
                        return
                    }
                }
            }
            
            ; Check triggers (LT/RT) on this joystick
            try {
                joyZ := GetKeyState(joyID . "JoyZ", "P")
                if (joyZ != "") {
                    if (joyZ > 60) {
                        CaptureGamepadButtonPopupFound("LT")
                        return
                    }
                    if (joyZ < 40) {
                        CaptureGamepadButtonPopupFound("RT")
                        return
                    }
                }
            }
            
            ; Check D-Pad on this joystick
            try {
                pov := GetKeyState(joyID . "JoyPOV", "P")
                if (pov != "" && pov >= 0) {
                    if (pov >= 0 && pov < 4500 || pov > 31500) {
                        CaptureGamepadButtonPopupFound("DPadUp")
                        return
                    }
                    if (pov >= 4500 && pov < 13500) {
                        CaptureGamepadButtonPopupFound("DPadRight")
                        return
                    }
                    if (pov >= 13500 && pov < 22500) {
                        CaptureGamepadButtonPopupFound("DPadDown")
                        return
                    }
                    if (pov >= 22500 && pov < 31500) {
                        CaptureGamepadButtonPopupFound("DPadLeft")
                        return
                    }
                }
            }
        }
    }
}

; Handle captured button from popup
CaptureGamepadButtonPopupFound(buttonName) {
    global gamepadCaptureTimer, gamepadCaptureGui, gamepadCaptureDisplay
    global GamepadMenuButton, gamepadMenuButtonDDL, GamepadButtonNames, GamepadType, IniPath, GamepadMenuButtonDDLValue
    
    ; Stop capturing
    gamepadCaptureTimer := false
    SetTimer(CaptureGamepadButtonPopup, 0)
    
    ; Update display
    gamepadCaptureDisplay.Value := buttonName
    
    ; Try to find button in standard list
    buttons := GamepadButtonNames[GamepadType]
    found := false
    for i, btn in buttons {
        if (btn = buttonName) {
            gamepadMenuButtonDDL.Choose(i + 1)
            found := true
            break
        }
    }
    
    ; If button not in standard list, select [Input]
    if (!found) {
        gamepadMenuButtonDDL.Choose(1)  ; Select [Input]
    }
    
    ; Save the new button
    GamepadMenuButton := buttonName
    GamepadMenuButtonDDLValue := buttonName
    IniWrite(GamepadMenuButton, IniPath, "Gamepad", "MenuButton")
    
    ; Re-register hotkey with new button
    SetGamepadHotkey()
    
    ; Close popup after short delay
    SetTimer(() => (IsSet(gamepadCaptureGui) && gamepadCaptureGui ? gamepadCaptureGui.Destroy() : 0), -500)
}