#Requires AutoHotkey v2.0
; Gamepad.ahk - Gamepad support module for Radial Menu
; Provides gamepad detection, button mapping, and input handling

; ===GAMEPAD GLOBAL VARIABLES===
global GamepadEnabled := false
global GamepadMenuButton := "RB"
global GamepadMenuButtonDDLValue := ""
global OCRGamepadButton := ""
global OCRGamepadButtonDDLValue := "[Input]"
global OCRHoldStartTick := 0
global OCRTriggered := false
global GamepadConnected := false
global GamepadType := "Xbox"
global GamepadNavigationStick := "Right"
global GamepadJoyID := 0

; Input backend:
; XInput is preferred because it is independent of the foreground window.
; Joy is kept as a fallback for DirectInput / legacy controllers.
global GamepadBackend := "None"
global GamepadBackendMode := "Auto"
global GamepadDebugMode := false
global GamepadXInputUser := -1
global GamepadXInputDLL := ""
global GamepadXInputAvailable := false
global GamepadTriggerThreshold := 30
global GamepadStickDeadzone := 0.15

global GamepadButtonNames := Map(
    "Xbox", ["A", "B", "X", "Y", "LB", "RB", "LT", "RT", "Back", "Start", "LS", "RS", "DPadUp", "DPadDown", "DPadLeft", "DPadRight"],
    "PlayStation", ["Cross", "Circle", "Square", "Triangle", "L1", "R1", "L2", "R2", "Select", "Start", "L3", "R3", "DPadUp", "DPadDown", "DPadLeft", "DPadRight"]
)

global GamepadButtonNumbers := Map(
    "A", 1, "B", 2, "X", 3, "Y", 4, "LB", 5, "RB", 6,
    "Back", 7, "Start", 8, "LS", 9, "RS", 10,
    "LT", "TriggerL", "RT", "TriggerR",
    "DPadUp", "POV0", "DPadDown", "POV180", "DPadLeft", "POV270", "DPadRight", "POV90"
)

global PSButtonToXbox := Map(
    "Cross", "A", "Circle", "B", "Square", "X", "Triangle", "Y",
    "L1", "LB", "R1", "RB", "L2", "LT", "R2", "RT",
    "Select", "Back", "Start", "Start", "L3", "LS", "R3", "RS"
)

; XInput XINPUT_GAMEPAD button masks
global XI_DPAD_UP := 0x0001
global XI_DPAD_DOWN := 0x0002
global XI_DPAD_LEFT := 0x0004
global XI_DPAD_RIGHT := 0x0008
global XI_START := 0x0010
global XI_BACK := 0x0020
global XI_LS := 0x0040
global XI_RS := 0x0080
global XI_LB := 0x0100
global XI_RB := 0x0200
global XI_A := 0x1000
global XI_B := 0x2000
global XI_X := 0x4000
global XI_Y := 0x8000

; ===GAMEPAD INITIALIZATION / BACKEND===
InitGamepad() {
    global GamepadConnected, GamepadBackend, GamepadXInputAvailable, GamepadJoyID

    GamepadConnected := false
    GamepadBackend := "None"
    GamepadJoyID := 0

    GamepadXInputAvailable := InitXInput()

    if (GamepadBackendMode != "DirectInput") {
        if (GamepadXInputAvailable && FindXInputController()) {
            GamepadBackend := "XInput"
            GamepadConnected := true
        }
    }

    ; Auto mode (and a failed XInput detection) falls back to DirectInput.
    if (!GamepadConnected && GamepadBackendMode != "XInput") {
        if (CheckLegacyJoystickConnection()) {
            GamepadBackend := "Joy"
            GamepadConnected := true
        }
    }

    UpdateGamepadStatusText()
}

InitXInput() {
    global GamepadXInputDLL

    for dllName in ["xinput1_4", "xinput1_3", "xinput9_1_0", "xinput1_2", "xinput1_1"] {
        try {
            h := DllCall("LoadLibrary", "Str", dllName ".dll", "Ptr")
            if (!h)
                continue
            addr := DllCall("GetProcAddress", "Ptr", h, "AStr", "XInputGetState", "Ptr")
            if (!addr)
                continue
            GamepadXInputDLL := dllName
            return true
        } catch {
        }
    }

    GamepadXInputDLL := ""
    return false
}

FindXInputController() {
    global GamepadXInputDLL, GamepadXInputUser

    if (GamepadXInputDLL = "")
        return false

    Loop 4 {
        user := A_Index - 1
        state := Buffer(20, 0)
        try {
            result := DllCall(GamepadXInputDLL "\XInputGetState", "UInt", user, "Ptr", state.Ptr, "UInt")
            if (result = 0) {
                GamepadXInputUser := user
                return true
            }
        } catch {
        }
    }

    GamepadXInputUser := -1
    return false
}

; ===GAMEPAD CONNECTION CHECK===
CheckGamepadConnection(*) {
    global GamepadConnected, GamepadJoyID, GamepadBackend

    oldBackend := GamepadBackend
    oldConnected := GamepadConnected

    ; Do not clear the current source before testing alternatives. Bluetooth
    ; DirectInput devices can briefly fail enumeration while still accepting
    ; button input. Losing the ID here used to make the next poll impossible.
    previousJoyID := GamepadJoyID
    previousBackend := GamepadBackend
    previousConnected := GamepadConnected

    detected := false
    if (GamepadBackendMode != "DirectInput") {
        if (FindXInputController()) {
            GamepadBackend := "XInput"
            GamepadConnected := true
            GamepadJoyID := 0
            detected := true
        }
    }

    if (!detected && GamepadBackendMode != "XInput") {
        if (CheckLegacyJoystickConnection()) {
            GamepadBackend := "Joy"
            GamepadConnected := true
            detected := true
        }
    }

    if (!detected && previousBackend = "Joy" && previousJoyID > 0) {
        ; Preserve a previously working Bluetooth DirectInput source.
        GamepadJoyID := previousJoyID
        GamepadBackend := "Joy"
        GamepadConnected := previousConnected || true
    } else if (!detected) {
        GamepadConnected := false
        GamepadBackend := "None"
    }

    if (oldBackend != GamepadBackend || oldConnected != GamepadConnected)
        UpdateGamepadStatusText()
    else
        try UpdateGamepadStatusText()
}

CheckLegacyJoystickConnection() {
    global GamepadJoyID

    ; Keep an already acquired Joy ID. Some Bluetooth DirectInput devices
    ; temporarily return an empty Name even though their input is still valid.
    if (GamepadJoyID > 0)
        return true

    ; First try the normal device-name enumeration.
    Loop 16 {
        joyName := ""
        try joyName := GetKeyState("Joy" A_Index, "Name")
        if (joyName != "" && joyName != "Error") {
            GamepadJoyID := A_Index
            return true
        }
    }

    ; Do NOT use GetKeyState("JoyN", "P") as a connection test: an
    ; unpressed button returns 0, so it cannot prove that the device exists.
    ; Actual button presses are detected by GetPressedGamepadButton().
    return false
}

; Try to discover a DirectInput device from an actual button press.
; This is intentionally independent of the connection/status flag because
; some Bluetooth HID/DInput devices expose their buttons before AHK exposes
; a usable device name.
AcquireLegacyJoystickFromInput() {
    global GamepadJoyID, GamepadBackend, GamepadConnected

    buttonMap := Map(1,"A", 2,"B", 3,"X", 4,"Y", 5,"LB", 6,"RB", 7,"Back", 8,"Start", 9,"LS", 10,"RS")

    Loop 16 {
        joyID := A_Index
        Loop 32 {
            btnNum := A_Index
            try {
                if (GetKeyState(joyID . "Joy" . btnNum, "P")) {
                    GamepadJoyID := joyID
                    GamepadBackend := "Joy"
                    GamepadConnected := true
                    return buttonMap.Has(btnNum) ? buttonMap[btnNum] : "Joy" . btnNum
                }
            }
        }

        ; Check POV as well.
        try {
            pov := GetKeyState(joyID . "JoyPOV", "P")
            if (pov != "" && pov >= 0) {
                GamepadJoyID := joyID
                GamepadBackend := "Joy"
                GamepadConnected := true
                if (pov < 4500 || pov > 31500)
                    return "DPadUp"
                if (pov < 13500)
                    return "DPadRight"
                if (pov < 22500)
                    return "DPadDown"
                return "DPadLeft"
            }
        }
    }

    return ""
}

EnsureGamepadInputSource() {
    global GamepadBackendMode, GamepadBackend, GamepadConnected
    global GamepadXInputAvailable

    ; Do not let a stale/disconnected status prevent actual input detection.
    if (GamepadBackendMode != "DirectInput") {
        if (!GamepadXInputAvailable)
            GamepadXInputAvailable := InitXInput()
        if (FindXInputController()) {
            GamepadBackend := "XInput"
            GamepadConnected := true
            return true
        }
    }

    if (GamepadBackendMode != "XInput") {
        if (CheckLegacyJoystickConnection()) {
            GamepadBackend := "Joy"
            GamepadConnected := true
            return true
        }
    }

    return false
}

UpdateGamepadStatusText() {
    global GamepadConnected, GamepadEnabled, gamepadStatusText
    if (!IsSet(gamepadStatusText) || !gamepadStatusText)
        return

    if (!GamepadEnabled) {
        gamepadStatusText.Opt("c808080")
        gamepadStatusText.Value := Lang.Get("gamepad_disabled")
    } else if (GamepadConnected) {
        gamepadStatusText.Opt("c00FF00")
        gamepadStatusText.Value := Lang.Get("gamepad_connected")
    } else {
        gamepadStatusText.Opt("cFF0000")
        gamepadStatusText.Value := Lang.Get("gamepad_disconnected")
    }
}

; ===UNIFIED GAMEPAD STATE===
GetXInputState() {
    global GamepadXInputDLL, GamepadXInputUser

    if (GamepadXInputDLL = "" || GamepadXInputUser < 0)
        return 0

    state := Buffer(20, 0)
    try {
        result := DllCall(GamepadXInputDLL "\XInputGetState", "UInt", GamepadXInputUser, "Ptr", state.Ptr, "UInt")
        if (result != 0) {
            GamepadXInputUser := -1
            return 0
        }
        return state
    } catch {
        GamepadXInputUser := -1
        return 0
    }
}

NormalizeStick(value) {
    global GamepadStickDeadzone
    n := value / 32767.0
    if (Abs(n) < GamepadStickDeadzone)
        return 50
    sign := n < 0 ? -1 : 1
    magnitude := (Abs(n) - GamepadStickDeadzone) / (1.0 - GamepadStickDeadzone)
    magnitude := Min(1.0, magnitude)
    return Round(50 + sign * magnitude * 50)
}

ReadXInputState() {
    global XI_DPAD_UP, XI_DPAD_DOWN, XI_DPAD_LEFT, XI_DPAD_RIGHT
    global XI_START, XI_BACK, XI_LS, XI_RS, XI_LB, XI_RB, XI_A, XI_B, XI_X, XI_Y
    global GamepadTriggerThreshold

    state := GetXInputState()
    if (!state)
        return 0

    buttons := NumGet(state, 4, "UShort")
    return Map(
        "A", !!(buttons & XI_A),
        "B", !!(buttons & XI_B),
        "X", !!(buttons & XI_X),
        "Y", !!(buttons & XI_Y),
        "LB", !!(buttons & XI_LB),
        "RB", !!(buttons & XI_RB),
        "Back", !!(buttons & XI_BACK),
        "Start", !!(buttons & XI_START),
        "LS", !!(buttons & XI_LS),
        "RS", !!(buttons & XI_RS),
        "LT", NumGet(state, 6, "UChar") >= GamepadTriggerThreshold,
        "RT", NumGet(state, 7, "UChar") >= GamepadTriggerThreshold,
        "DPadUp", !!(buttons & XI_DPAD_UP),
        "DPadDown", !!(buttons & XI_DPAD_DOWN),
        "DPadLeft", !!(buttons & XI_DPAD_LEFT),
        "DPadRight", !!(buttons & XI_DPAD_RIGHT),
        "LeftX", NormalizeStick(NumGet(state, 8, "Short")),
        "LeftY", NormalizeStick(-NumGet(state, 10, "Short")),
        "RightX", NormalizeStick(NumGet(state, 12, "Short")),
        "RightY", NormalizeStick(-NumGet(state, 14, "Short"))
    )
}

NormalizeButtonName(buttonName) {
    global GamepadType, PSButtonToXbox
    if (GamepadType = "PlayStation" && PSButtonToXbox.Has(buttonName))
        return PSButtonToXbox[buttonName]
    return buttonName
}

GetLegacyJoyState(buttonName) {
    global GamepadButtonNumbers, GamepadJoyID

    if (GamepadJoyID <= 0)
        return false

    if (InStr(buttonName, "Joy") = 1) {
        buttonNum := SubStr(buttonName, 4)
        try return !!GetKeyState(GamepadJoyID . "Joy" . buttonNum, "P")
        return false
    }

    if (!GamepadButtonNumbers.Has(buttonName))
        return false
    code := GamepadButtonNumbers[buttonName]

    if (code = "TriggerL" || code = "TriggerR") {
        try {
            z := GetKeyState(GamepadJoyID . "JoyZ", "P")
            if (z = "")
                return false
            return code = "TriggerL" ? z > 60 : z < 40
        } catch {
            return false
        }
    }

    if (InStr(code, "POV") = 1) {
        try {
            pov := GetKeyState(GamepadJoyID . "JoyPOV", "P")
            if (pov = "" || pov < 0)
                return false
            wanted := Integer(SubStr(code, 4))
            if (wanted = 0)
                return pov < 4500 || pov > 31500
            return pov >= wanted * 100 - 4500 && pov < wanted * 100 + 4500
        } catch {
            return false
        }
    }

    try return !!GetKeyState(GamepadJoyID . "Joy" . code, "P")
    return false
}

; ===GAMEPAD BUTTON CHECK===
IsGamepadButtonPressed(buttonName) {
    global GamepadBackend
    normalized := NormalizeButtonName(buttonName)

    if (GamepadBackend = "XInput") {
        state := ReadXInputState()
        if (state && state.Has(normalized))
            return state[normalized]
        ; XInput disappeared or is not the right backend. Fall through.
    }

    if (GamepadBackend != "Joy")
        EnsureGamepadInputSource()

    if (GamepadBackend = "XInput") {
        state := ReadXInputState()
        if (state && state.Has(normalized))
            return state[normalized]
    }

    return GetLegacyJoyState(buttonName)
}

WaitGamepadButtonRelease(buttonName) {
    while (IsGamepadButtonPressed(buttonName))
        Sleep(10)
}

GetPressedGamepadButton() {
    global GamepadBackend, GamepadJoyID, GamepadConnected

    ; Capture must not depend on the status label. Try to acquire an input
    ; source every time the user presses a button.
    if (GamepadBackend = "XInput") {
        state := ReadXInputState()
        if (state) {
            for name in ["A", "B", "X", "Y", "LB", "RB", "Back", "Start", "LS", "RS", "LT", "RT", "DPadUp", "DPadDown", "DPadLeft", "DPadRight"] {
                if (state[name])
                    return name
            }
            return ""
        }
    }

    if (GamepadBackend != "Joy")
        EnsureGamepadInputSource()

    if (GamepadBackend = "XInput") {
        state := ReadXInputState()
        if (state) {
            for name in ["A", "B", "X", "Y", "LB", "RB", "Back", "Start", "LS", "RS", "LT", "RT", "DPadUp", "DPadDown", "DPadLeft", "DPadRight"] {
                if (state[name])
                    return name
            }
        }
    }

    if (GamepadJoyID <= 0)
        CheckLegacyJoystickConnection()

    ; If AHK cannot enumerate the Bluetooth DInput device, discover it from
    ; the actual button press instead. This reproduces the useful behavior
    ; of the original version without requiring a Connected status first.
    if (GamepadJoyID <= 0)
        return AcquireLegacyJoystickFromInput()

    buttonMap := Map(1,"A", 2,"B", 3,"X", 4,"Y", 5,"LB", 6,"RB", 7,"Back", 8,"Start", 9,"LS", 10,"RS")
    Loop 32 {
        btnNum := A_Index
        try {
            if (GetKeyState(GamepadJoyID . "Joy" . btnNum, "P"))
                return buttonMap.Has(btnNum) ? buttonMap[btnNum] : "Joy" . btnNum
        }
    }

    try {
        z := GetKeyState(GamepadJoyID . "JoyZ", "P")
        if (z != "") {
            if (z > 60)
                return "LT"
            if (z < 40)
                return "RT"
        }
    }

    try {
        pov := GetKeyState(GamepadJoyID . "JoyPOV", "P")
        if (pov != "" && pov >= 0) {
            if (pov < 4500 || pov > 31500)
                return "DPadUp"
            if (pov < 13500)
                return "DPadRight"
            if (pov < 22500)
                return "DPadDown"
            if (pov < 31500)
                return "DPadLeft"
        }
    }
    return ""
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
            ToolTip(Lang.Get("tooltip_scrambler_no_stratagems"), 5, 5)
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
        ToolTip(Lang.Get("tooltip_no_stratagems_profile"), 5, 5)
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
    global radialGui, GamepadNavigationStick, GamepadBackend, GamepadJoyID
    global OCRScramblerBypassEnabled, ScramblerRadialMode

    if (!IsMenuVisible)
        return

    if (OCRScramblerBypassEnabled && ScramblerRadialMode) {
        if Icon_GetCapturedCount() = 0
            return
    } else if (ActiveStratagems.Length = 0) {
        return
    }

    joyX := 50
    joyY := 50

    if (GamepadBackend = "XInput") {
        state := ReadXInputState()
        if (state) {
            if (GamepadNavigationStick = "DPad") {
                if (state["DPadUp"])
                    joyY := 0
                else if (state["DPadDown"])
                    joyY := 100
                if (state["DPadLeft"])
                    joyX := 0
                else if (state["DPadRight"])
                    joyX := 100
            } else if (GamepadNavigationStick = "Right") {
                joyX := state["RightX"]
                joyY := state["RightY"]
            } else {
                joyX := state["LeftX"]
                joyY := state["LeftY"]
            }
        }
    } else {
        try {
            if (GamepadNavigationStick = "DPad") {
                pov := GetKeyState(GamepadJoyID . "JoyPOV", "P")
                if (pov != "" && pov >= 0) {
                    angleRad := pov * 3.14159 / 18000
                    joyX := 50 + Round(50 * Sin(angleRad))
                    joyY := 50 - Round(50 * Cos(angleRad))
                }
            } else if (GamepadNavigationStick = "Right") {
                joyX := Integer(GetKeyState(GamepadJoyID . "JoyU", "P"))
                joyY := Integer(GetKeyState(GamepadJoyID . "JoyR", "P"))
            } else {
                joyX := Integer(GetKeyState(GamepadJoyID . "JoyX", "P"))
                joyY := Integer(GetKeyState(GamepadJoyID . "JoyY", "P"))
            }
        } catch {
            joyX := 50
            joyY := 50
        }
    }

    centerX := ScreenCX
    centerY := ScreenCY
    halfSize := MenuSize // 2
    mx := centerX + ((joyX - 50) * halfSize // 50)
    my := centerY + ((joyY - 50) * halfSize // 50)

    dx := mx - ScreenCX
    dy := my - ScreenCY
    dist := Sqrt(dx**2 + dy**2)

    count := (OCRScramblerBypassEnabled && ScramblerRadialMode) ? Icon_GetCapturedCount() : ActiveStratagems.Length
    sectorAngle := 360 / count
    newSector := 0
    if (dist > InnerRadius) {
        angle := DllCall("msvcrt\atan2", "Double", dy, "Double", dx, "CDECL Double") * 180 / 3.14159
        angle := Mod(angle + 360 + (sectorAngle/2) + 90, 360)
        newSector := Floor(angle / sectorAngle) + 1
        if (newSector > count || newSector < 1)
            newSector := 1
    }

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
    SetTimer(UpdateGamepadDebugOverlay, 0)
    UpdateGamepadDebugOverlay()
    
    ; When gamepad is enabled, use polling.
    if (!GamepadEnabled)
        return

    SetTimer(CheckGamepadPolling, 50)
    SetTimer(UpdateGamepadDebugOverlay, 100)
}

; Check D-Pad and Triggers for menu activation (polling)
CheckGamepadPolling() {
    global GamepadEnabled, GamepadMenuButton, IsMenuVisible
    static statusTick := 0
    
    if (!GamepadEnabled || IsMenuVisible)
        return

    ; A controller can still send input even when Windows/AHK failed to
    ; classify it correctly. Never block gameplay input because the status
    ; text says "Disconnected".
    if (!GamepadConnected || GamepadBackend = "None")
        EnsureGamepadInputSource()

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
    global GamepadBackendMode, GamepadDebugMode
    global OCRGamepadButton, OCRUseHold, OCRHoldMs, BypassGamepadButton
    global BypassUseHold, BypassHoldMs
    
    try {
        GamepadEnabled := IniRead(IniPath, "Gamepad", "Enabled", "0") = "1" ? true : false
        GamepadMenuButton := IniRead(IniPath, "Gamepad", "MenuButton", "RB")
        GamepadType := IniRead(IniPath, "Gamepad", "ControllerType", "Xbox")
        GamepadNavigationStick := IniRead(IniPath, "Gamepad", "NavigationStick", "Right")
        GamepadBackendMode := IniRead(IniPath, "Gamepad", "Backend", "Auto")
        if (GamepadBackendMode != "Auto" && GamepadBackendMode != "XInput" && GamepadBackendMode != "DirectInput")
            GamepadBackendMode := "Auto"
        GamepadDebugMode := IniRead(IniPath, "Gamepad", "DebugMode", "0") = "1"
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
        GamepadBackendMode := "Auto"
        GamepadDebugMode := false
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
    captureGui := Gui("-Caption +LastFound +AlwaysOnTop", Lang.Get("capture_ocr_gamepad_button"))
    captureGui.BackColor := "202020"
    captureGui.SetFont("s10 cC4C4C4", "Segoe UI")
    captureGui.MarginX := Scale(5)
    captureGui.MarginY := Scale(5)

    captureGui.SetFont("cFFFFFF s12")
    captureGui.Add("Text", "x0 y0 w" Scale(280) " h" Scale(35) " Background2A2A2A Border +Center", Lang.Get("capture_ocr_gamepad_button")).OnEvent("Click", (*) => PostMessage(0xA1, 2,,, "A"))
    captureGui.Add("Button", "x+5 y0 w" Scale(35) " h" Scale(35), "X").OnEvent("Click", (*) => captureGui.Destroy())
    captureGui.SetFont("s11 cC4C4C4")

    captureGui.Add("Text", "x" Scale(20) " y" Scale(50) " w" Scale(280) " Center", Lang.Get("press_gamepad_button"))
    global ocrGamepadCaptureDisplay := captureGui.Add("Text", "x" Scale(20) " y+10 w" Scale(280) " h" Scale(40) " Center cFFD700 Background333333", OCRGamepadButton = "" ? "[Not set]" : OCRGamepadButton)
    captureGui.Add("Button", "x" Scale(110) " y+25 w" Scale(100) " h" Scale(30), Lang.Get("cancel")).OnEvent("Click", (*) => captureGui.Destroy())
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
        if (GetPressedGamepadButton() != "")
            return
        ocrGamepadCaptureWaiting := false
        return
    }

    buttonName := GetPressedGamepadButton()
    if (buttonName = "")
        return

    CaptureOCRGamepadButtonPopupFound(buttonName)
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

    captureGui := Gui("-Caption +LastFound +AlwaysOnTop", Lang.Get("capture_bypass_button"))
    captureGui.BackColor := "202020"
    captureGui.SetFont("s10 cC4C4C4", "Segoe UI")
    captureGui.MarginX := Scale(5)
    captureGui.MarginY := Scale(5)

    captureGui.SetFont("cFFFFFF s12")
    captureGui.Add("Text", "x0 y0 w" Scale(280) " h" Scale(35) " Background2A2A2A Border +Center", Lang.Get("capture_bypass_button")).OnEvent("Click", (*) => PostMessage(0xA1, 2,,, "A"))
    captureGui.Add("Button", "x+5 y0 w" Scale(35) " h" Scale(35), "X").OnEvent("Click", (*) => captureGui.Destroy())
    captureGui.SetFont("s11 cC4C4C4")

    captureGui.Add("Text", "x" Scale(20) " y" Scale(50) " w" Scale(280) " Center", Lang.Get("press_gamepad_button"))
    global bypassGamepadCaptureDisplay := captureGui.Add("Text", "x" Scale(20) " y+10 w" Scale(280) " h" Scale(40) " Center cFFD700 Background333333", BypassGamepadButton = "" ? "[Not set]" : BypassGamepadButton)
    captureGui.Add("Button", "x" Scale(110) " y+25 w" Scale(100) " h" Scale(30), Lang.Get("cancel")).OnEvent("Click", (*) => captureGui.Destroy())
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
        if (GetPressedGamepadButton() != "")
            return
        bypassGamepadCaptureWaiting := false
        return
    }

    buttonName := GetPressedGamepadButton()
    if (buttonName = "")
        return

    CaptureBypassGamepadButtonPopupFound(buttonName)
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


; ===GAMEPAD SETTINGS WINDOW===
ShowGamepadSettings(*) {
    global GamepadBackendMode, GamepadDebugMode, IniPath

    settingsGui := Gui("-Caption +AlwaysOnTop +ToolWindow", "Gamepad Settings")
    settingsGui.BackColor := "202020"
    settingsGui.SetFont("s10 cC4C4C4", "Segoe UI")
    settingsGui.MarginX := Scale(10)
    settingsGui.MarginY := Scale(10)

    title := settingsGui.Add("Text", "x0 y0 w" Scale(335) " h" Scale(36) " Background2A2A2A Border +Center", "Gamepad Settings")
    title.OnEvent("Click", (*) => PostMessage(0xA1, 2,,, "A"))
    settingsGui.Add("Button", "x+5 y0 w" Scale(36) " h" Scale(36), "X").OnEvent("Click", (*) => settingsGui.Destroy())

    settingsGui.Add("Text", "x" Scale(15) " y" Scale(55) " w" Scale(100), "Input Backend:")
    backendDDL := settingsGui.Add("DropDownList", "x+" Scale(10) " yp-4 w" Scale(120), ["Auto", "XInput", "DirectInput"])
    backendDDL.Choose(GamepadBackendMode = "XInput" ? 2 : (GamepadBackendMode = "DirectInput" ? 3 : 1))

    debugCheckbox := settingsGui.Add("CheckBox", "x" Scale(15) " y+20", "Gamepad Debug Mode")
    debugCheckbox.Value := GamepadDebugMode
    settingsGui.Add("Text", "x" Scale(15) " y+8 w" Scale(330) " c808080", "Shows live backend, controller, buttons and stick values.")

    saveBtn := settingsGui.Add("Button", "x" Scale(115) " y+15 w" Scale(110) " h" Scale(32), "Save")
    saveBtn.OnEvent("Click", (*) => SaveGamepadSettingsWindow(settingsGui, backendDDL, debugCheckbox))
    settingsGui.OnEvent("Escape", (*) => settingsGui.Destroy())
    settingsGui.Show("w" Scale(380) " h" Scale(190))
}

SaveGamepadSettingsWindow(settingsGui, backendDDL, debugCheckbox) {
    global GamepadBackendMode, GamepadDebugMode, IniPath

    GamepadBackendMode := backendDDL.Text
    GamepadDebugMode := !!debugCheckbox.Value
    IniWrite(GamepadBackendMode, IniPath, "Gamepad", "Backend")
    IniWrite(GamepadDebugMode ? "1" : "0", IniPath, "Gamepad", "DebugMode")

    InitGamepad()
    SetGamepadHotkey()
    settingsGui.Destroy()
}

; ===GAMEPAD DEBUG OVERLAY===
UpdateGamepadDebugOverlay() {
    global GamepadDebugMode, GamepadEnabled, GamepadConnected, GamepadBackend
    global GamepadXInputUser, GamepadJoyID, GamepadBackendMode, GamepadType
    global GamepadNavigationStick
    static debugGui := 0
    static debugText := 0

    if (!GamepadDebugMode) {
        if (debugGui) {
            try debugGui.Destroy()
            debugGui := 0
            debugText := 0
        }
        return
    }

    if (!debugGui) {
        debugGui := Gui("-Caption +AlwaysOnTop +ToolWindow +E0x20", "Gamepad Debug")
        debugGui.BackColor := "101010"
        debugGui.SetFont("s9 cFFFFFF", "Consolas")
        debugText := debugGui.Add("Text", "x8 y8 w" Scale(330) " h" Scale(190))
        debugGui.Show("x" (A_ScreenWidth - Scale(350)) " y" Scale(80) " w" Scale(350) " h" Scale(210) " NoActivate")
    }

    text := "Gamepad Debug`n"
    text .= "Enabled: " (GamepadEnabled ? "Yes" : "No") "`n"
    text .= "Requested: " GamepadBackendMode "`n"
    text .= "Backend: " GamepadBackend "`n"
    text .= "Connected: " (GamepadConnected ? "Yes" : "No") "`n"
    text .= "Type: " GamepadType "`n"
    if (GamepadBackend = "XInput")
        text .= "XInput User: " (GamepadXInputUser + 1) "`n"
    else
        text .= "Joy ID: " GamepadJoyID "`n"

    if (GamepadConnected) {
        state := GamepadBackend = "XInput" ? ReadXInputState() : 0
        if (state) {
            text .= "A B X Y: " (state["A"]?"1":"0") " " (state["B"]?"1":"0") " " (state["X"]?"1":"0") " " (state["Y"]?"1":"0") "`n"
            text .= "LB RB LT RT: " (state["LB"]?"1":"0") " " (state["RB"]?"1":"0") " " (state["LT"]?"1":"0") " " (state["RT"]?"1":"0") "`n"
            text .= "DPad U/D/L/R: " (state["DPadUp"]?"1":"0") " " (state["DPadDown"]?"1":"0") " " (state["DPadLeft"]?"1":"0") " " (state["DPadRight"]?"1":"0") "`n"
            text .= "Left Stick: " state["LeftX"] ", " state["LeftY"] "`n"
            text .= "Right Stick: " state["RightX"] ", " state["RightY"]
        } else if (GamepadBackend = "Joy") {
            text .= "Menu: " (IsGamepadButtonPressed(GamepadMenuButton)?"PRESSED":"released") "`n"
            text .= "Navigation: " GamepadNavigationStick "`n"
            try {
                if (GamepadNavigationStick = "Right")
                    text .= "Right Stick: " Integer(GetKeyState(GamepadJoyID . "JoyU", "P")) ", " Integer(GetKeyState(GamepadJoyID . "JoyR", "P"))
                else if (GamepadNavigationStick = "Left")
                    text .= "Left Stick: " Integer(GetKeyState(GamepadJoyID . "JoyX", "P")) ", " Integer(GetKeyState(GamepadJoyID . "JoyY", "P"))
                else
                    text .= "DPad POV: " GetKeyState(GamepadJoyID . "JoyPOV", "P")
            }
        }
    }
    debugText.Value := text
}

; ===GAMEPAD BUTTON CAPTURE POPUP===
ShowGamepadCapturePopup(*) {
    global GamepadMenuButton, GamepadType, GamepadButtonNames
    
    ; Create capture popup
    captureGui := Gui("-Caption +LastFound +AlwaysOnTop", Lang.Get("capture_gamepad_button"))
    captureGui.BackColor := "202020"
    captureGui.SetFont("s10 cC4C4C4", "Segoe UI")
    captureGui.MarginX := Scale(5)
    captureGui.MarginY := Scale(5)
    
    ; Title bar
    captureGui.SetFont("cFFFFFF s12")
    captureGui.Add("Text", "x0 y0 w" Scale(280) " h" Scale(35) " Background2A2A2A Border +Center", Lang.Get("capture_gamepad_button")).OnEvent("Click", (*) => PostMessage(0xA1, 2,,, "A"))
    captureGui.Add("Button", "x+5 y0 w" Scale(35) " h" Scale(35), "X").OnEvent("Click", (*) => captureGui.Destroy())
    captureGui.SetFont("s11 cC4C4C4")
    
    captureGui.Add("Text", "x" Scale(20) " y" Scale(50) " w" Scale(280) " Center", Lang.Get("press_gamepad_button"))
    
    ; Current button display
    global gamepadCaptureDisplay := captureGui.Add("Text", "x" Scale(20) " y+10 w" Scale(280) " h" Scale(40) " Center cFFD700 Background333333", GamepadMenuButton)
    
    ; Cancel button
    captureGui.Add("Button", "x" Scale(110) " y+25 w" Scale(100) " h" Scale(30), Lang.Get("cancel")).OnEvent("Click", (*) => captureGui.Destroy())
    
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
    global gamepadCaptureTimer, gamepadCaptureGui, gamepadCaptureWaiting

    if (!gamepadCaptureTimer)
        return

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

    if (gamepadCaptureWaiting) {
        if (GetPressedGamepadButton() != "")
            return
        gamepadCaptureWaiting := false
        return
    }

    buttonName := GetPressedGamepadButton()
    if (buttonName = "")
        return

    CaptureGamepadButtonPopupFound(buttonName)
}

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