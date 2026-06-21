; === Weapon Assistant ===
; === Variables ===
global WeaponAssistantActive := false
global WeaponAssistHotkey := "XButton1"
global WeaponAssistHotkeyWildcard := false
global CurrentWeaponMode := 1 ; 1=Purifier/Arc-Thrower | 2=Railgun (Unsafe) | 3=Epoch | 4=Power Throw
global ToggleWeaponHotkey := ""
global ToggleWeaponHotkeyWildcard := false
global CycleWeaponModeHotkey := ""
global SafetyEnabled := false
global SafetyHotkey := ""
global SafetyPassThrough := true
global RegisteredSafetyHotkey := ""
global RegisteredCycleHotkey := ""

global WeaponModeNames := ["Purifier/Arc-Thrower", "Railgun (Unsafe)", "Epoch", "Power Throw"]

global WP_ReloadKey := "r"
global WP_InteractKey := "e"

; Charge/throw timing variables (in milliseconds)
global WP_ChargeTime1 := 1100  ; Purifier/Arc-Thrower max charge
global WP_ChargeTime2 := 3150  ; Railgun (Unsafe) max charge
global WP_ChargeTime3 := 2700  ; Epoch max charge
global WP_ThrowDelay := 250    ; Power Throw delay before interact

global wpSettingsGui := 0

; === Toggle hotkey change handler ===
OnWPToggleChange() {
    global ToggleWeaponHotkey, wpToggleInput
    ToggleWeaponHotkey := wpToggleInput.GetValue()
    SetWeaponAssistantHotkey()
    SaveWeaponAssistantSettings()
    RefreshKeybindListIfVisible()
}

; Wildcard checkbox change handler
OnWPToggleWildcardChange() {
    global ToggleWeaponHotkeyWildcard, wpToggleInput
    ToggleWeaponHotkeyWildcard := wpToggleInput.GetWildcard()
    SetWeaponAssistantHotkey()
    SaveWeaponAssistantSettings()
    RefreshKeybindListIfVisible()
}

; Register toggle hotkey
SetWeaponAssistantHotkey() {
    global ToggleWeaponHotkey, ToggleWeaponHotkeyWildcard
    opts := ToggleWeaponHotkeyWildcard ? "W" : ""
    RegisterSimpleHotkey(ToggleWeaponHotkey, ToggleWeaponAssistantFunc, "WeaponToggle", opts)
}

; Safety catch checkbox change handler (live toggles controls)
OnWPSafetyEnabledChange(*) {
    global wpSafetyEnabledCb, wpSafetyInput, wpSafetyPassThroughCb
    
    isEnabled := wpSafetyEnabledCb.Value
    
    ; Disable/enable safety input controls based on checkbox state (live toggle for UX)
    if (IsSet(wpSafetyInput) && IsObject(wpSafetyInput) && wpSafetyInput.HasOwnProp("controls")) {
        try wpSafetyInput.controls.ddl.Enabled := isEnabled
        try wpSafetyInput.controls.hotkey.Enabled := isEnabled
    }
    if (IsSet(wpSafetyPassThroughCb) && IsObject(wpSafetyPassThroughCb)) {
        try wpSafetyPassThroughCb.Enabled := isEnabled
    }
}

; Safety hotkey change handler
OnWPSafetyChange() {
    global wpSafetyInput, SafetyHotkey
    SafetyHotkey := wpSafetyInput.GetValue()
    SetWeaponSafetyHotkey()
    UpdateWeaponAssistantStatus()
}

; Safety pass-through checkbox change handler
OnWPSafetyPassThroughChange(*) {
    global wpSafetyPassThroughCb, SafetyPassThrough
    SafetyPassThrough := wpSafetyPassThroughCb.Value
    SetWeaponSafetyHotkey()
}

; Register safety catch hotkey
; When safety key is HELD -> enable the fire macro hotkey
; When safety key is RELEASED -> disable the fire macro hotkey
SetWeaponSafetyHotkey() {
    global SafetyEnabled, SafetyHotkey, SafetyPassThrough, RegisteredSafetyHotkey
    
    ; Always turn off the old safety hotkey if exists
    if (RegisteredSafetyHotkey != "") {
        try Hotkey(RegisteredSafetyHotkey, WPSafetyHoldFunc, "Off")
    }
    RegisteredSafetyHotkey := ""
    
    if (!SafetyEnabled || SafetyHotkey = "")
        return
    
    ; Build prefix: ~ if pass-through, * always (wildcard)
    prefix := SafetyPassThrough ? "~*" : "*"
    
    ; Register the safety key
    try {
        hk := prefix . SafetyHotkey
        Hotkey(hk, WPSafetyHoldFunc, "On")
        RegisteredSafetyHotkey := hk
    }
}

; Safety hold handler: enables fire hotkey while held, disables on release
WPSafetyHoldFunc(*) {
    global WeaponAssistantActive, ScriptSuspended
    
    ; Only proceed if assistant is active
    if (!WeaponAssistantActive || ScriptSuspended)
        return
    
    ; Get the raw safety key name (strip * and ~ prefixes)
    safetyKey := SafetyHotkey
    while (SubStr(safetyKey, 1, 1) = "*" || SubStr(safetyKey, 1, 1) = "~")
        safetyKey := SubStr(safetyKey, 2)
    if (safetyKey = "")
        return
    
    ; Use GetFireHotkey() to respect wildcard setting
    fireHK := GetFireHotkey()
    
    ; Enable the fire hotkey while safety key is held
    if (fireHK != "") {
        try Hotkey(fireHK, LButtonMacroFunc, "On")
    }
    
    ; Wait for the safety key to be released
    KeyWait(safetyKey)
    
    ; Disable the fire hotkey when safety key is released
    if (fireHK != "") {
        try Hotkey(fireHK, LButtonMacroFunc, "Off")
    }
}

; Toggle weapon assistant on/off
ToggleWeaponAssistantFunc(*) {
    global WeaponAssistantActive, wpStatusText
    
    WeaponAssistantActive := !WeaponAssistantActive
    
    if (WeaponAssistantActive) {
        wpStatusText.Value := "● ON"
        wpStatusText.Opt("c00FF00")
        ToolTip("Weapon Assistant: ON", A_ScreenWidth - 200, A_ScreenHeight - 50)
    } else {
        wpStatusText.Value := "○ OFF"
        wpStatusText.Opt("cFF0000")
        ToolTip("Weapon Assistant: OFF", A_ScreenWidth - 200, A_ScreenHeight - 50)
    }
    
    SetTimer(RemoveToolTip, -1200)
    UpdateWeaponAssistantStatus()
    RefreshKeybindListIfVisible()
}

; Build the fire hotkey name with optional wildcard prefix
GetFireHotkey() {
    global WeaponAssistHotkey, WeaponAssistHotkeyWildcard
    if (WeaponAssistHotkey = "")
        return ""
    if (WeaponAssistHotkeyWildcard)
        return "*" . WeaponAssistHotkey
    return WeaponAssistHotkey
}

; Update fire button hotkey registration based on active/suspended state
UpdateWeaponAssistantStatus() {
    global WeaponAssistantActive, WeaponAssistHotkey, ScriptSuspended, SafetyEnabled
    global RegisteredSafetyHotkey, RegisteredCycleHotkey, CycleWeaponModeHotkey
    static OldFireHotkey := ""
    
    fireHK := GetFireHotkey()
    
    ; Always turn off the previous fire hotkey if it exists and is different from current
    if (OldFireHotkey != "" && OldFireHotkey != fireHK) {
        try Hotkey(OldFireHotkey, LButtonMacroFunc, "Off")
    }
    
    if (WeaponAssistantActive && !ScriptSuspended) {
        ; Assistant is ON and not suspended
        if (SafetyEnabled) {
            ; Safety catch is ON - explicitly turn off the fire hotkey
            if (fireHK != "") {
                try Hotkey(fireHK, LButtonMacroFunc, "Off")
            }
        } else {
            ; Safety catch is OFF - fire hotkey works normally
            if (fireHK != "") {
                try Hotkey(fireHK, LButtonMacroFunc, "On")
            }
        }
        ; Re-register safety hotkey to ensure it's active with the correct key
        SetWeaponSafetyHotkey()
        ; Re-register cycle hotkey
        SetWeaponCycleHotkey()
    } else {
        ; Assistant is OFF or suspended - turn everything off
        
        ; Unregister fire hotkey
        if (fireHK != "") {
            try Hotkey(fireHK, LButtonMacroFunc, "Off")
        }
        ; Unregister safety hotkey
        if (RegisteredSafetyHotkey != "") {
            try Hotkey(RegisteredSafetyHotkey, WPSafetyHoldFunc, "Off")
            RegisteredSafetyHotkey := ""
        }
        ; Unregister cycle hotkey
        if (RegisteredCycleHotkey != "") {
            try Hotkey(RegisteredCycleHotkey, CycleWeaponModeFunc, "Off")
            RegisteredCycleHotkey := ""
        }
    }
    
    ; Track the current hotkey for next time
    OldFireHotkey := fireHK
}

; Main weapon fire macro - handles all weapon modes
LButtonMacroFunc(ThisHotkey) {
    global WeaponAssistantActive, ScriptSuspended, CurrentWeaponMode, SafetyEnabled, SafetyHotkey
    
    if (!WeaponAssistantActive || ScriptSuspended)
        return
    
    ; If safety catch is enabled, check that the safety key is physically held down
    if (SafetyEnabled && SafetyHotkey != "") {
        ; Get the raw safety key name (strip * and ~ prefixes)
        safetyKey := SafetyHotkey
        while (SubStr(safetyKey, 1, 1) = "*" || SubStr(safetyKey, 1, 1) = "~")
            safetyKey := SubStr(safetyKey, 2)
        if (safetyKey = "" || !GetKeyState(safetyKey, "P"))
            return  ; Safety key not held - block the macro
    }
    
    ; Remove the asterisk, tilde, and dollar from the hotkey name if they exist
    cleanHotkey := RegExReplace(ThisHotkey, "[~*$]")
    
    if (CurrentWeaponMode = 1) { ; Purifier / Arc-Thrower
        while GetKeyState(cleanHotkey, "P") {
            ; Start charging
            Send("{LButton down}")
            
            ; Charge at 50ms intervals up to max charge time, checking for key release
            chargeStep := 50
            maxChargeSteps := WP_ChargeTime1 // chargeStep
            Loop maxChargeSteps {
                if !GetKeyState(cleanHotkey, "P")
                    break  ; User released early - exit loop
                Sleep(chargeStep)
            }
            
            ; Release the shot
            Send("{LButton up}")
            Sleep(25)
        }
    } else if (CurrentWeaponMode = 2) { ; Railgun (Unsafe) - auto-charge to max, release on key release
        ; Start charging - LButton down begins the charge
        Send("{LButton down}")
        
        ; Charge at 50ms intervals up to max charge time, checking for key release
        chargeStep := 50
        maxChargeSteps := WP_ChargeTime2 // chargeStep
        Loop maxChargeSteps {
            if !GetKeyState(cleanHotkey, "P")
                break  ; User released early - exit loop to trigger release
            Sleep(chargeStep)
        }
        
        ; Release the shot
        Send("{LButton up}")
        Sleep(10)
        
        ; Reload (press configured reload key)
        Send("{" WP_ReloadKey " down}")
        Sleep(25)
        Send("{" WP_ReloadKey " up}")
        
    } else if (CurrentWeaponMode = 3) { ; Epoch
        while GetKeyState(cleanHotkey, "P") {
            ; Start charging
            Send("{LButton down}")
            
            ; Charge at 50ms intervals up to max charge time, checking for key release
            chargeStep := 50
            maxChargeSteps := WP_ChargeTime3 // chargeStep
            Loop maxChargeSteps {
                if !GetKeyState(cleanHotkey, "P")
                    break  ; User released early - exit loop
                Sleep(chargeStep)
            }
            
            ; Release the shot
            Send("{LButton up}")
            Sleep(25)
        }
    } else if (CurrentWeaponMode = 4) { ; Power Throw
        Send("{LButton down}")
        Sleep 25
        Send("{LButton up}")
        Sleep WP_ThrowDelay
        Send("{" WP_InteractKey " down}")
        Sleep 25
        Send("{" WP_InteractKey " up}")
    }
}

; Show Weapon Assistant Settings popup
ShowWeaponAssistantSettings(*) {
    global wpSettingsGui, settingsGui, WeaponAssistHotkey, CurrentWeaponMode
    global WeaponModeNames, CycleWeaponModeHotkey, IniPath
    
    ; Switch to English keyboard layout when opening popup
    SwitchToEnglishLayout()
    
    ; Destroy existing settings GUI if it exists
    if (IsSet(wpSettingsGui) && wpSettingsGui) {
        try wpSettingsGui.Destroy()
    }
    
    wpSettingsGui := Gui("+Owner" . settingsGui.Hwnd, "Weapon Assistant")
    wpSettingsGui.BackColor := "202020"
    wpSettingsGui.SetFont("s10 cC4C4C4", "Segoe UI")
    wpSettingsGui.MarginX := Scale(10)
    wpSettingsGui.MarginY := Scale(10)
    
    ; Weapon Mode Dropdown
    wpSettingsGui.Add("Text", "x" Scale(10) " y" Scale(15) " w" Scale(100), "Weapon Mode:")
    global wpModeDDL := wpSettingsGui.Add("DropDownList", "x" Scale(10) " y+" Scale(5) " w" Scale(150) " Background2f2f2f", WeaponModeNames)
    wpModeDDL.Choose(CurrentWeaponMode)
    
    ; Cycle Mode Hotkey
    wpSettingsGui.Add("Text", "x" Scale(10) " y+" Scale(10) " w" Scale(100), "Cycle Mode:")
    global wpCycleInput := HotkeyInput(wpSettingsGui, 10, 0, "", {value: CycleWeaponModeHotkey, hasWildcard: false, excludeKeys: ["WheelUp", "WheelDown"]})
    
    ; Fire Button Hotkey
    wpSettingsGui.Add("Text", "x" Scale(10) " y+" Scale(15) " w" Scale(120), "Macro Fire Button:")
    global wpFireInput := HotkeyInput(wpSettingsGui, 10, 0, "", {value: WeaponAssistHotkey, wildcard: WeaponAssistHotkeyWildcard, hasWildcard: true, excludeKeys: ["WheelUp", "WheelDown"]})
    
    ; Safety Catch
    wpSettingsGui.Add("Text", "x" Scale(10) " y+" Scale(15) " w" Scale(80), "Safety Catch:")
    global wpSafetyEnabledCb := wpSettingsGui.Add("CheckBox", "x+" Scale(5) " yp vWPSafetyEnabled")
    wpSafetyEnabledCb.Value := SafetyEnabled
    wpSafetyEnabledCb.OnEvent("Click", OnWPSafetyEnabledChange)
    
    ; Safety hotkey input (only enabled if safety catch is enabled)
    global wpSafetyInput := HotkeyInput(wpSettingsGui, 10, 0, "", {value: SafetyHotkey, hasWildcard: false, excludeKeys: ["WheelUp", "WheelDown"]})
    ; Set initial enabled state based on checkbox
    try wpSafetyInput.controls.ddl.Enabled := SafetyEnabled
    try wpSafetyInput.controls.hotkey.Enabled := SafetyEnabled
    global wpSafetyPassThroughCb := wpSettingsGui.Add("CheckBox", "x+5 yp vWPSafetyPassThrough", "~")
    wpSafetyPassThroughCb.Value := SafetyPassThrough
    wpSafetyPassThroughCb.Enabled := SafetyEnabled
    wpSettingsGui.Add("Text", "x+2 yp w" Scale(38), "(Pass-thru)")
    
    ; Reload Key (used by Railgun mode)
    wpSettingsGui.Add("Text", "x" Scale(10) " y+" Scale(15) " w" Scale(100), "Reload Key:")
    global wpReloadInput := HotkeyInput(wpSettingsGui, 10, 0, "", {value: WP_ReloadKey, hasWildcard: false, excludeKeys: ["WheelUp", "WheelDown"]})
    
    ; Interact Key (used by Power Throw mode)
    wpSettingsGui.Add("Text", "x" Scale(10) " y+" Scale(10) " w" Scale(100), "Interact Key:")
    global wpInteractInput := HotkeyInput(wpSettingsGui, 10, 0, "", {value: WP_InteractKey, hasWildcard: false, excludeKeys: ["WheelUp", "WheelDown"]})
    
    ; ===== Timing inputs =====
    wpSettingsGui.Add("Text", "x" Scale(10) " y+" Scale(15) " w" Scale(230) " cGray", "Timings (ms):")
    
    ; Purifier charge time
    wpSettingsGui.Add("Text", "x" Scale(10) " y+" Scale(5) " w" Scale(100), "Purifier Charge:")
    global wpChargeTime1 := wpSettingsGui.Add("Edit", "x+" Scale(5) " yp-3 w" Scale(60) " Background2f2f2f Number", WP_ChargeTime1)
    
    ; Railgun charge time
    wpSettingsGui.Add("Text", "x" Scale(10) " y+" Scale(5) " w" Scale(100), "Railgun Charge:")
    global wpChargeTime2 := wpSettingsGui.Add("Edit", "x+" Scale(5) " yp-3 w" Scale(60) " Background2f2f2f Number", WP_ChargeTime2)
    
    ; Epoch charge time
    wpSettingsGui.Add("Text", "x" Scale(10) " y+" Scale(5) " w" Scale(100), "Epoch Charge:")
    global wpChargeTime3 := wpSettingsGui.Add("Edit", "x+" Scale(5) " yp-3 w" Scale(60) " Background2f2f2f Number", WP_ChargeTime3)
    
    ; Power Throw delay
    wpSettingsGui.Add("Text", "x" Scale(10) " y+" Scale(5) " w" Scale(100), "Throw Delay:")
    global wpThrowDelay := wpSettingsGui.Add("Edit", "x+" Scale(5) " yp-3 w" Scale(60) " Background2f2f2f Number", WP_ThrowDelay)
    
    ; Save button
    btnWPSave := wpSettingsGui.Add("Button", "x" Scale(10) " y+" Scale(25) " w" Scale(260) " h" Scale(30) " Default", "Save Settings")
    btnWPSave.OnEvent("Click", SaveWeaponAssistantSettingsPopup)
    
    wpSettingsGui.OnEvent("Escape", (*) => wpSettingsGui.Destroy())
    wpSettingsGui.Show("w" Scale(280))
}

; Register cycle mode hotkey
SetWeaponCycleHotkey() {
    global CycleWeaponModeHotkey, RegisteredCycleHotkey
    RegisterSimpleHotkey(CycleWeaponModeHotkey, CycleWeaponModeFunc, "WeaponCycle")
    
    ; Track the registered hotkey for cleanup when assistant turns off
    if (CycleWeaponModeHotkey != "")
        RegisteredCycleHotkey := CycleWeaponModeHotkey
    else
        RegisteredCycleHotkey := ""
}

; Cycle through weapon modes 1→2→3→4→1
CycleWeaponModeFunc(*) {
    global CurrentWeaponMode, wpModeDDL, wpStatusText, WeaponAssistantActive, WeaponModeNames
    
    ; Cycle through modes 1-2-3-4-1 (Purifier, Railgun Unsafe, Epoch, Power Throw)
    CurrentWeaponMode := (CurrentWeaponMode >= 4) ? 1 : CurrentWeaponMode + 1
    
    modeName := WeaponModeNames[CurrentWeaponMode]
    if (WeaponAssistantActive) {
        wpStatusText.Value := "● ON"
        wpStatusText.Opt("c00FF00")
    }
    
    ToolTip("Weapon Mode: " . modeName, A_ScreenWidth - 200, A_ScreenHeight - 50)
    SetTimer(RemoveToolTip, -1000)
    RefreshKeybindListIfVisible()
}

; Save from popup
SaveWeaponAssistantSettingsPopup(*) {
    global wpSettingsGui, IniPath
    global wpModeDDL, wpFireInput, wpSafetyEnabledCb, wpSafetyInput, wpSafetyPassThroughCb, wpCycleInput
    global wpReloadInput, wpInteractInput
    global wpChargeTime1, wpChargeTime2, wpChargeTime3, wpThrowDelay
    global CurrentWeaponMode, WeaponAssistHotkey, WeaponAssistHotkeyWildcard
    global SafetyEnabled, SafetyHotkey, SafetyPassThrough, CycleWeaponModeHotkey
    global WP_ReloadKey, WP_InteractKey
    global WP_ChargeTime1, WP_ChargeTime2, WP_ChargeTime3, WP_ThrowDelay
    global ToggleWeaponHotkey, ToggleWeaponHotkeyWildcard
    
    ; Read values from GUI controls
    CurrentWeaponMode := wpModeDDL.Value
    WeaponAssistHotkey := wpFireInput.GetValue()
    WeaponAssistHotkeyWildcard := wpFireInput.GetWildcard()
    SafetyEnabled := wpSafetyEnabledCb.Value
    SafetyHotkey := wpSafetyInput.GetValue()
    SafetyPassThrough := wpSafetyPassThroughCb.Value
    CycleWeaponModeHotkey := wpCycleInput.GetValue()
    WP_ReloadKey := wpReloadInput.GetValue() != "" ? wpReloadInput.GetValue() : "r"
    WP_InteractKey := wpInteractInput.GetValue() != "" ? wpInteractInput.GetValue() : "e"
    WP_ChargeTime1 := Integer(wpChargeTime1.Value) > 0 ? Integer(wpChargeTime1.Value) : 1100
    WP_ChargeTime2 := Integer(wpChargeTime2.Value) > 0 ? Integer(wpChargeTime2.Value) : 3150
    WP_ChargeTime3 := Integer(wpChargeTime3.Value) > 0 ? Integer(wpChargeTime3.Value) : 2700
    WP_ThrowDelay := Integer(wpThrowDelay.Value) > 0 ? Integer(wpThrowDelay.Value) : 250
    
    ; Save all settings to INI
    IniWrite(ToggleWeaponHotkey, IniPath, "WeaponAssistant", "ToggleHotkey")
    IniWrite(ToggleWeaponHotkeyWildcard ? "1" : "0", IniPath, "WeaponAssistant", "ToggleHotkeyWildcard")
    IniWrite(WeaponAssistHotkey, IniPath, "WeaponAssistant", "FireHotkey")
    IniWrite(WeaponAssistHotkeyWildcard ? "1" : "0", IniPath, "WeaponAssistant", "FireHotkeyWildcard")
    IniWrite(CycleWeaponModeHotkey, IniPath, "WeaponAssistant", "CycleHotkey")
    IniWrite(CurrentWeaponMode, IniPath, "WeaponAssistant", "CurrentMode")
    IniWrite(SafetyEnabled ? "1" : "0", IniPath, "WeaponAssistant", "SafetyEnabled")
    IniWrite(SafetyHotkey, IniPath, "WeaponAssistant", "SafetyHotkey")
    IniWrite(SafetyPassThrough ? "1" : "0", IniPath, "WeaponAssistant", "SafetyPassThrough")
    IniWrite(WP_ReloadKey, IniPath, "WeaponAssistant", "ReloadKey")
    IniWrite(WP_InteractKey, IniPath, "WeaponAssistant", "InteractKey")
    IniWrite(WP_ChargeTime1, IniPath, "WeaponAssistant", "ChargeTime1")
    IniWrite(WP_ChargeTime2, IniPath, "WeaponAssistant", "ChargeTime2")
    IniWrite(WP_ChargeTime3, IniPath, "WeaponAssistant", "ChargeTime3")
    IniWrite(WP_ThrowDelay, IniPath, "WeaponAssistant", "ThrowDelay")
    
    ; Register the safety hotkey
    SetWeaponSafetyHotkey()
    
    ; Register the cycle hotkey
    SetWeaponCycleHotkey()
    
    ; Update hotkey registration
    UpdateWeaponAssistantStatus()
    RefreshKeybindListIfVisible()

    wpSettingsGui.Destroy()
}

; Save weapon assistant settings
SaveWeaponAssistantSettings() {
    global ToggleWeaponHotkey, ToggleWeaponHotkeyWildcard, WeaponAssistHotkey, WeaponAssistHotkeyWildcard, CycleWeaponModeHotkey
    global CurrentWeaponMode, SafetyEnabled, SafetyHotkey, SafetyPassThrough, IniPath
    global WP_ReloadKey, WP_InteractKey
    global WP_ChargeTime1, WP_ChargeTime2, WP_ChargeTime3, WP_ThrowDelay
    
    IniWrite(ToggleWeaponHotkey, IniPath, "WeaponAssistant", "ToggleHotkey")
    IniWrite(ToggleWeaponHotkeyWildcard ? "1" : "0", IniPath, "WeaponAssistant", "ToggleHotkeyWildcard")
    IniWrite(WeaponAssistHotkey, IniPath, "WeaponAssistant", "FireHotkey")
    IniWrite(WeaponAssistHotkeyWildcard ? "1" : "0", IniPath, "WeaponAssistant", "FireHotkeyWildcard")
    IniWrite(CycleWeaponModeHotkey, IniPath, "WeaponAssistant", "CycleHotkey")
    IniWrite(CurrentWeaponMode, IniPath, "WeaponAssistant", "CurrentMode")
    IniWrite(SafetyEnabled ? "1" : "0", IniPath, "WeaponAssistant", "SafetyEnabled")
    IniWrite(SafetyHotkey, IniPath, "WeaponAssistant", "SafetyHotkey")
    IniWrite(SafetyPassThrough ? "1" : "0", IniPath, "WeaponAssistant", "SafetyPassThrough")
    IniWrite(WP_ReloadKey, IniPath, "WeaponAssistant", "ReloadKey")
    IniWrite(WP_InteractKey, IniPath, "WeaponAssistant", "InteractKey")
    IniWrite(WP_ChargeTime1, IniPath, "WeaponAssistant", "ChargeTime1")
    IniWrite(WP_ChargeTime2, IniPath, "WeaponAssistant", "ChargeTime2")
    IniWrite(WP_ChargeTime3, IniPath, "WeaponAssistant", "ChargeTime3")
    IniWrite(WP_ThrowDelay, IniPath, "WeaponAssistant", "ThrowDelay")
}

; Load settings from INI
LoadWeaponAssistantSettings() {
    global ToggleWeaponHotkey, ToggleWeaponHotkeyWildcard, WeaponAssistHotkey, WeaponAssistHotkeyWildcard, CycleWeaponModeHotkey
    global CurrentWeaponMode, SafetyEnabled, SafetyHotkey, SafetyPassThrough, IniPath
    global WP_ReloadKey, WP_InteractKey
    global WP_ChargeTime1, WP_ChargeTime2, WP_ChargeTime3, WP_ThrowDelay
    
    try {
        ToggleWeaponHotkey := IniRead(IniPath, "WeaponAssistant", "ToggleHotkey", "")
        ToggleWeaponHotkeyWildcard := IniRead(IniPath, "WeaponAssistant", "ToggleHotkeyWildcard", "0") = "1" ? true : false
        WeaponAssistHotkey := IniRead(IniPath, "WeaponAssistant", "FireHotkey", "XButton1")
        WeaponAssistHotkeyWildcard := IniRead(IniPath, "WeaponAssistant", "FireHotkeyWildcard", "0") = "1" ? true : false
        CycleWeaponModeHotkey := IniRead(IniPath, "WeaponAssistant", "CycleHotkey", "")
        CurrentWeaponMode := Integer(IniRead(IniPath, "WeaponAssistant", "CurrentMode", "1"))
        SafetyEnabled := IniRead(IniPath, "WeaponAssistant", "SafetyEnabled", "0") = "1" ? true : false
        SafetyHotkey := IniRead(IniPath, "WeaponAssistant", "SafetyHotkey", "")
        SafetyPassThrough := IniRead(IniPath, "WeaponAssistant", "SafetyPassThrough", "1") = "1" ? true : false
        WP_ReloadKey := IniRead(IniPath, "WeaponAssistant", "ReloadKey", "r")
        WP_InteractKey := IniRead(IniPath, "WeaponAssistant", "InteractKey", "e")
        WP_ChargeTime1 := Integer(IniRead(IniPath, "WeaponAssistant", "ChargeTime1", "1100"))
        WP_ChargeTime2 := Integer(IniRead(IniPath, "WeaponAssistant", "ChargeTime2", "3150"))
        WP_ChargeTime3 := Integer(IniRead(IniPath, "WeaponAssistant", "ChargeTime3", "2700"))
        WP_ThrowDelay := Integer(IniRead(IniPath, "WeaponAssistant", "ThrowDelay", "250"))
    } catch {
        ; Defaults are already set in global variables
    }
}

; === Driver Assistant ===
; === Variables ===
global DriverAssistantActive := false
global ToggleDriverHotkey := ""
global ToggleDriverHotkeyWildcard := false
global DADriverLastKey := ""
global DA_W_Key := "w"
global DA_S_Key := "s"
global DA_E_Key := "e"
global DA_C_Key := "c"
global DA_GearUp_Key := "Shift"
global DA_GearDown_Key := "Ctrl"
global DA_StratagemCallEnabled := false
global DA_ForwardGearMode := 1 ; 1=1st gear, 2=2nd gear, 3=D gear
global DA_ForwardGearModeNames := ["1st Gear", "2nd Gear", "D Gear"]
global DA_EnhancedGearSwitch := false ; if true, press forward after reverse shifts directly to chosen gear

global daStatusText := 0
global daSettingsGui := 0

; === Toggle hotkey change handler ===
OnDAToggleChange() {
    global ToggleDriverHotkey, daToggleInput
    ToggleDriverHotkey := daToggleInput.GetValue()
    SetDriverAssistantHotkey()
    SaveDriverAssistantSettings()
    RefreshKeybindListIfVisible()
}

OnDAToggleWildcardChange() {
    global ToggleDriverHotkeyWildcard, daToggleInput
    ToggleDriverHotkeyWildcard := daToggleInput.GetWildcard()
    SetDriverAssistantHotkey()
    SaveDriverAssistantSettings()
    RefreshKeybindListIfVisible()
}

; Register toggle hotkey
SetDriverAssistantHotkey() {
    global ToggleDriverHotkey, ToggleDriverHotkeyWildcard
    opts := ToggleDriverHotkeyWildcard ? "W" : ""
    RegisterSimpleHotkey(ToggleDriverHotkey, ToggleDriverAssistantFunc, "DriverToggle", opts)
}

; Toggle driver assistant on/off
ToggleDriverAssistantFunc(*) {
    global DriverAssistantActive, daStatusText
    
    DriverAssistantActive := !DriverAssistantActive
    
    if (DriverAssistantActive) {
        daStatusText.Value := "● ON"
        daStatusText.Opt("c00FF00")
        ToolTip("Driver Assistant: ON", A_ScreenWidth - 200, A_ScreenHeight - 50)
    } else {
        daStatusText.Value := "○ OFF"
        daStatusText.Opt("cFF0000")
        ToolTip("Driver Assistant: OFF", A_ScreenWidth - 200, A_ScreenHeight - 50)
    }
    
    SetTimer(RemoveToolTip, -1200)
    UpdateDriverAssistantStatus()
    RefreshKeybindListIfVisible()
}

; Update driver maco hotkeys based on active/suspended state
UpdateDriverAssistantStatus() {
    global DriverAssistantActive, ScriptSuspended
    global DA_W_Key, DA_S_Key, DA_E_Key, DADriverLastKey
    
    if (DriverAssistantActive && !ScriptSuspended) {
        ; Activate the W, S and E hotkeys only when the assistant is active and not suspended
        if (DA_W_Key != "")
            RegisterSimpleHotkey("~*" . DA_W_Key, DriverMacroWFunc, "DriverMacroW", "SW")
        if (DA_S_Key != "")
            RegisterSimpleHotkey("~*" . DA_S_Key, DriverMacroSFunc, "DriverMacroS", "SW")
        if (DA_E_Key != "")
            RegisterSimpleHotkey("~*" . DA_E_Key, DriverMacroEFunc, "DriverMacroE", "SW")
    } else {
        ; Deactivate the W, S and E hotkeys when the assistant is not active
        RegisterSimpleHotkey("", DriverMacroWFunc, "DriverMacroW")
        RegisterSimpleHotkey("", DriverMacroSFunc, "DriverMacroS")
        RegisterSimpleHotkey("", DriverMacroEFunc, "DriverMacroE")
        DADriverLastKey := ""
    }
}

; --- Macro for configurable forward key ---
; Gear modes:
;   1 = 1st Gear: 4 gear ups + 1 gear down (original), or 3 gear ups from reverse (enhanced)
;   2 = 2nd Gear: 4 gear ups + 0 gear downs (original), or 4 gear ups from reverse (enhanced)
;   3 = D Gear:   4 gear ups + 2 gear downs (original), or 2 gear ups from reverse (enhanced)
DriverMacroWFunc(*) {
    global DriverAssistantActive, ScriptSuspended, DADriverLastKey, DA_W_Key, DA_S_Key
    global DA_GearUp_Key, DA_GearDown_Key, DA_ForwardGearMode, DA_EnhancedGearSwitch
    
    if (!DriverAssistantActive || ScriptSuspended)
        return
    
    ; Check if the last key pressed was the same key (prevent repeat)
    If (DADriverLastKey = DA_W_Key) {
        Return
    }
    
    ; Save whether we came from reverse before updating DADriverLastKey
    cameFromReverse := DA_EnhancedGearSwitch && (DADriverLastKey = DA_S_Key)
    DADriverLastKey := DA_W_Key
    
    if (cameFromReverse) {
        ; Enhanced gear switch: coming from reverse, shift up directly to chosen gear
        ; Gear order: Reverse(2) -> Neutral(1) -> D -> 1st -> 2nd
        ; From reverse: D=2 ups, 1st=3 ups, 2nd=4 ups
        gearUpCount := 4 ; default to 2nd gear (4 ups)
        if (DA_ForwardGearMode = 3) ; D Gear - 2 gear ups from reverse
            gearUpCount := 2
        else if (DA_ForwardGearMode = 1) ; 1st Gear - 3 gear ups from reverse
            gearUpCount := 3
        ; Mode 2 (2nd Gear) stays at 4
        
        Loop gearUpCount
        {
            SendInput("{" DA_GearUp_Key " down}")
            Sleep 25
            SendInput("{" DA_GearUp_Key " up}")
            Sleep 25
        }
    } else {
        ; Original behavior: shift up 4 times to top, then shift down to selected gear
        Loop 4
        {
            SendInput("{" DA_GearUp_Key " down}")
            Sleep 25
            SendInput("{" DA_GearUp_Key " up}")
            Sleep 25
        }
        
        ; Shift down based on selected gear mode
        if (DA_ForwardGearMode = 1) { ; 1st Gear - one gear down from top
            SendInput("{" DA_GearDown_Key " down}")
            Sleep 25
            SendInput("{" DA_GearDown_Key " up}")
            Sleep 25
        } else if (DA_ForwardGearMode = 3) { ; D Gear - two gear downs from top
            SendInput("{" DA_GearDown_Key " down}")
            Sleep 25
            SendInput("{" DA_GearDown_Key " up}")
            Sleep 25
            SendInput("{" DA_GearDown_Key " down}")
            Sleep 25
            SendInput("{" DA_GearDown_Key " up}")
            Sleep 25
        }
        ; Mode 2 (2nd Gear): no gear downs needed
    }
    
    KeyWait(DA_W_Key)
}

; --- Macro for configurable backward key ---
DriverMacroSFunc(*) {
    global DriverAssistantActive, ScriptSuspended, DADriverLastKey, DA_S_Key
    
    if (!DriverAssistantActive || ScriptSuspended)
        return
    
    ; Check if the last key pressed was the same key (prevent repeat)
    If (DADriverLastKey = DA_S_Key) {
        Return
    }
    DADriverLastKey := DA_S_Key
    
    Loop 4
    {
        SendInput("{" DA_GearDown_Key " down}")
        Sleep 25
        SendInput("{" DA_GearDown_Key " up}")
        Sleep 25
    }
    KeyWait(DA_S_Key)
}

; --- Macro for configurable exit key ---
DriverMacroEFunc(*) {
    global DriverAssistantActive
    
    if (!DriverAssistantActive)
        return
    
    ; Deactivate the driver assistant when the exit key is pressed
    DriverAssistantActive := false
    UpdateDriverAssistantStatus()
    if (IsSet(daStatusText) && daStatusText) {
        daStatusText.Value := "○ OFF"
        daStatusText.Opt("cFF0000")
    }
    ToolTip("Driver Assistant: OFF", A_ScreenWidth - 200, A_ScreenHeight - 50)
    SetTimer(RemoveToolTip, -1200)
    RefreshKeybindListIfVisible()
}

; Show Driver Assistant Settings popup
ShowDriverAssistantSettings(*) {
    global daSettingsGui, settingsGui, IniPath
    global DA_W_Key, DA_S_Key, DA_E_Key, DA_GearUp_Key, DA_GearDown_Key
    
    ; Switch to English keyboard layout when opening popup
    SwitchToEnglishLayout()
    
    ; Destroy existing settings GUI if it exists
    if (IsSet(daSettingsGui) && daSettingsGui) {
        try daSettingsGui.Destroy()
    }
    
    daSettingsGui := Gui("+Owner" . settingsGui.Hwnd, "Driver Assistant")
    daSettingsGui.BackColor := "202020"
    daSettingsGui.SetFont("s10 cC4C4C4", "Segoe UI")
    daSettingsGui.MarginX := Scale(10)
    daSettingsGui.MarginY := Scale(10)
    
    ; Forward Key
    daSettingsGui.Add("Text", "x" Scale(10) " y" Scale(15) " w" Scale(100), "Forward Key:")
    global daWInput := HotkeyInput(daSettingsGui, 10, 0, "", {value: DA_W_Key, hasWildcard: false})
    
    ; Backward key
    daSettingsGui.Add("Text", "x" Scale(10) " y+" Scale(15) " w" Scale(100), "Backward Key:")
    global daSInput := HotkeyInput(daSettingsGui, 10, 0, "", {value: DA_S_Key, hasWildcard: false})
    
    ; Exit key
    daSettingsGui.Add("Text", "x" Scale(10) " y+" Scale(15) " w" Scale(100), "Exit Vehicle Key:")
    global daEInput := HotkeyInput(daSettingsGui, 10, 0, "", {value: DA_E_Key, hasWildcard: false})
    daSettingsGui.Add("Text", "x+5 yp w" Scale(120) " cGray", "(Turns off Assistant)")
    
    ; Swap Seats key
    daSettingsGui.Add("Text", "x" Scale(10) " y+" Scale(15) " w" Scale(100), "Swap Seats Key:")
    global daCInput := HotkeyInput(daSettingsGui, 10, 0, "", {value: DA_C_Key, hasWildcard: false})
    
    ; Gear Up key
    daSettingsGui.Add("Text", "x" Scale(10) " y+" Scale(15) " w" Scale(100), "Gear Up Key:")
    global daGearUpInput := HotkeyInput(daSettingsGui, 10, 0, "", {value: DA_GearUp_Key, hasWildcard: false})
    
    ; Gear Down key
    daSettingsGui.Add("Text", "x" Scale(10) " y+" Scale(15) " w" Scale(100), "Gear Down Key:")
    global daGearDownInput := HotkeyInput(daSettingsGui, 10, 0, "", {value: DA_GearDown_Key, hasWildcard: false})

    ; Forward Gear Mode dropdown
    daSettingsGui.Add("Text", "x" Scale(10) " y+" Scale(15) " w" Scale(100), "Forward Gear:")
    global daGearModeDDL := daSettingsGui.Add("DropDownList", "x" Scale(10) " y+" Scale(5) " w" Scale(100) " Background2f2f2f", DA_ForwardGearModeNames)
    daGearModeDDL.Choose(DA_ForwardGearMode)
    
    ; Enhanced Gear Switch checkbox
    global daEnhancedCb := daSettingsGui.Add("CheckBox", "x" Scale(10) " y+" Scale(20) " vDA_EnhancedGearSwitch", "Enhanced Gear Switch")
    daEnhancedCb.Value := DA_EnhancedGearSwitch
    
    ; Driver Stratagem Call checkbox
    global daStratagemCallCb := daSettingsGui.Add("CheckBox", "x" Scale(10) " y+" Scale(10) " vDA_StratagemCallEnabled", "Driver Stratagem Call")
    daStratagemCallCb.Value := DA_StratagemCallEnabled
    
    ; Save button
    btnDASave := daSettingsGui.Add("Button", "x" Scale(10) " y+" Scale(25) " w" Scale(260) " h" Scale(30) " Default", "Save Settings")
    btnDASave.OnEvent("Click", SaveDriverAssistantSettingsPopup)
    
    daSettingsGui.OnEvent("Escape", (*) => daSettingsGui.Destroy())
    daSettingsGui.Show("w" Scale(280))
}

; Save from popup
SaveDriverAssistantSettingsPopup(*) {
    global daSettingsGui, IniPath
    global DA_W_Key, DA_S_Key, DA_E_Key, DA_C_Key, DA_GearUp_Key, DA_GearDown_Key, DA_StratagemCallEnabled
    global daWInput, daSInput, daEInput, daCInput, daGearUpInput, daGearDownInput, daStratagemCallCb
    global DA_ForwardGearMode, daGearModeDDL, DA_EnhancedGearSwitch, daEnhancedCb
    
    ; Read values from inputs
    DA_W_Key := daWInput.GetValue() != "" ? daWInput.GetValue() : "w"
    DA_S_Key := daSInput.GetValue() != "" ? daSInput.GetValue() : "s"
    DA_E_Key := daEInput.GetValue() != "" ? daEInput.GetValue() : "e"
    DA_C_Key := daCInput.GetValue() != "" ? daCInput.GetValue() : "c"
    DA_GearUp_Key := daGearUpInput.GetValue() != "" ? daGearUpInput.GetValue() : "Shift"
    DA_GearDown_Key := daGearDownInput.GetValue() != "" ? daGearDownInput.GetValue() : "Ctrl"
    DA_StratagemCallEnabled := daStratagemCallCb.Value
    DA_ForwardGearMode := daGearModeDDL.Value
    DA_EnhancedGearSwitch := daEnhancedCb.Value
    
    ; Save all settings to INI
    SaveDriverAssistantSettings()
    
    ; Re-register hotkeys with new key names
    RegisterDriverMacroHotkeys()
    RefreshKeybindListIfVisible()
    
    daSettingsGui.Destroy()
}

; Register driver maco hotkeys (used after settings change)
RegisterDriverMacroHotkeys() {
    global DriverAssistantActive
    UpdateDriverAssistantStatus()
}

; === Driver Stratagem Call Integration ===
; Called from RunMacro in Radial_menu.ahk when DA_StratagemCallEnabled is true and DriverAssistantActive is true
PerformDriverStratagemCall(*) {
    global DA_C_Key, DA_StratagemCallEnabled, DriverAssistantActive
    
    if (!DriverAssistantActive || !DA_StratagemCallEnabled)
        return false  ; Not executed
    
    ; 1. Swap seats (press the configured swap seats key)
    if (DA_C_Key != "") {
        SendInput("{" DA_C_Key " down}")
        Sleep 25
        SendInput("{" DA_C_Key " up}")
    }
    
    ; 2. Wait 0.6 second for seat switch to complete
    Sleep 600
    
    ; 3. Hold RMB (right mouse button) to look around
    SendInput("{RButton down}")
    Sleep 75
    
    return true  ; Seat swap was executed
}

; Release RMB after stratagem macro completes.
; First ensures LMB is released, then waits for fresh LMB press with a 3-second timeout.
ReleaseDriverStratagemRMB(*) {
    global DA_C_Key
    static DA_ReleaseTimeout := 3000  ; 3 second timeout
    
    ; Wait for LMB to be released first (prevents stuck state)
    KeyWait("LButton")
    Sleep 50
    
    ; Wait for fresh LMB press with timeout
    startTime := A_TickCount
    lmbPressed := false
    Loop {
        if GetKeyState("LButton", "P") {
            lmbPressed := true
            break
        }
        if (A_TickCount - startTime >= DA_ReleaseTimeout)
            break
        Sleep(10)
    }
    
    Sleep 600
    SendInput("{RButton up}")
    
    ; Only swap back to driver seat if LMB was pressed within timeout
    if (lmbPressed && DA_C_Key != "") {
        SendInput("{" DA_C_Key " down}")
        Sleep 25
        SendInput("{" DA_C_Key " up}")
    }
}

; Save driver assistant settings
SaveDriverAssistantSettings() {
    global IniPath, ToggleDriverHotkey, ToggleDriverHotkeyWildcard
    global DA_W_Key, DA_S_Key, DA_E_Key, DA_C_Key, DA_GearUp_Key, DA_GearDown_Key
    global DA_StratagemCallEnabled, DA_ForwardGearMode, DA_EnhancedGearSwitch
    
    IniWrite(ToggleDriverHotkey, IniPath, "DriverAssistant", "ToggleHotkey")
    IniWrite(ToggleDriverHotkeyWildcard ? "1" : "0", IniPath, "DriverAssistant", "ToggleHotkeyWildcard")
    IniWrite(DA_W_Key, IniPath, "DriverAssistant", "DA_W_Key")
    IniWrite(DA_S_Key, IniPath, "DriverAssistant", "DA_S_Key")
    IniWrite(DA_E_Key, IniPath, "DriverAssistant", "DA_E_Key")
    IniWrite(DA_C_Key, IniPath, "DriverAssistant", "DA_C_Key")
    IniWrite(DA_GearUp_Key, IniPath, "DriverAssistant", "DA_GearUp_Key")
    IniWrite(DA_GearDown_Key, IniPath, "DriverAssistant", "DA_GearDown_Key")
    IniWrite(DA_StratagemCallEnabled ? "1" : "0", IniPath, "DriverAssistant", "DA_StratagemCallEnabled")
    IniWrite(DA_ForwardGearMode, IniPath, "DriverAssistant", "DA_ForwardGearMode")
    IniWrite(DA_EnhancedGearSwitch ? "1" : "0", IniPath, "DriverAssistant", "DA_EnhancedGearSwitch")
}

; Load settings from INI
LoadDriverAssistantSettings() {
    global IniPath, ToggleDriverHotkey, ToggleDriverHotkeyWildcard
    global DA_W_Key, DA_S_Key, DA_E_Key, DA_C_Key, DA_GearUp_Key, DA_GearDown_Key
    global DA_StratagemCallEnabled, DA_ForwardGearMode, DA_EnhancedGearSwitch
    
    try {
        ToggleDriverHotkey := IniRead(IniPath, "DriverAssistant", "ToggleHotkey", "")
        ToggleDriverHotkeyWildcard := IniRead(IniPath, "DriverAssistant", "ToggleHotkeyWildcard", "0") = "1" ? true : false
        DA_W_Key := IniRead(IniPath, "DriverAssistant", "DA_W_Key", "w")
        DA_S_Key := IniRead(IniPath, "DriverAssistant", "DA_S_Key", "s")
        DA_E_Key := IniRead(IniPath, "DriverAssistant", "DA_E_Key", "e")
        DA_C_Key := IniRead(IniPath, "DriverAssistant", "DA_C_Key", "c")
        DA_GearUp_Key := IniRead(IniPath, "DriverAssistant", "DA_GearUp_Key", "Shift")
        DA_GearDown_Key := IniRead(IniPath, "DriverAssistant", "DA_GearDown_Key", "Ctrl")
        DA_StratagemCallEnabled := IniRead(IniPath, "DriverAssistant", "DA_StratagemCallEnabled", "0") = "1" ? true : false
        DA_ForwardGearMode := Integer(IniRead(IniPath, "DriverAssistant", "DA_ForwardGearMode", "1"))
        DA_EnhancedGearSwitch := IniRead(IniPath, "DriverAssistant", "DA_EnhancedGearSwitch", "0") = "1" ? true : false
    } catch {
        ; Defaults are already set in global variables
    }
}

; === Inventory Manager ===
; === Variables ===
global InventoryManagerActive := false
global IM_Button1Hotkey := ""
global IM_Button2Hotkey := ""
global IM_Button3Hotkey := ""
global IM_Button4Hotkey := ""
global IM_Button1Wildcard := false
global IM_Button2Wildcard := false
global IM_Button3Wildcard := false
global IM_Button4Wildcard := false
global IM_DropKey := "x"
global IM_SleepDelay := 25
global IM_SleepDelay2 := 75
global IM_SensitivityMultiplier := 1.0

global imStatusText := 0
global imSettingsGui := 0

; Toggle inventory manager on/off (clickable status text)
ToggleInventoryManagerFunc(*) {
    global InventoryManagerActive, imStatusText, IniPath
    
    InventoryManagerActive := !InventoryManagerActive
    
    if (InventoryManagerActive) {
        imStatusText.Value := "● ON"
        imStatusText.Opt("c00FF00")
    } else {
        imStatusText.Value := "○ OFF"
        imStatusText.Opt("cFF0000")
    }
    
    IniWrite(InventoryManagerActive ? "1" : "0", IniPath, "InventoryManager", "Active")
    UpdateInventoryManagerStatus()
}

; Update IM hotkey registration based on active/suspended state
UpdateInventoryManagerStatus() {
    global InventoryManagerActive, ScriptSuspended, imStatusText
    global IM_Button1Hotkey, IM_Button2Hotkey, IM_Button3Hotkey, IM_Button4Hotkey
    global IM_Button1Wildcard, IM_Button2Wildcard, IM_Button3Wildcard, IM_Button4Wildcard
    
    ; Update status text if GUI control exists
    if (IsSet(imStatusText) && imStatusText && IsObject(imStatusText)) {
        if (InventoryManagerActive) {
            imStatusText.Value := "● ON"
            imStatusText.Opt("c00FF00")
        } else {
            imStatusText.Value := "○ OFF"
            imStatusText.Opt("cFF0000")
        }
    }
    
    if (InventoryManagerActive && !ScriptSuspended) {
        RegisterIMHotkey(IM_Button1Hotkey, IM_Button1Wildcard, IMButton1Func, "IMButton1")
        RegisterIMHotkey(IM_Button2Hotkey, IM_Button2Wildcard, IMButton2Func, "IMButton2")
        RegisterIMHotkey(IM_Button3Hotkey, IM_Button3Wildcard, IMButton3Func, "IMButton3")
        RegisterIMHotkey(IM_Button4Hotkey, IM_Button4Wildcard, IMButton4Func, "IMButton4")
    } else {
        RegisterIMHotkey("", false, IMButton1Func, "IMButton1")
        RegisterIMHotkey("", false, IMButton2Func, "IMButton2")
        RegisterIMHotkey("", false, IMButton3Func, "IMButton3")
        RegisterIMHotkey("", false, IMButton4Func, "IMButton4")
    }
}

; Register a single Inventory Manager hotkey
RegisterIMHotkey(hotkeyName, wildcard, callback, storageKey) {
    static activeHotkeys := Map()
    
    ; Unregister old hotkey if exists
    if (activeHotkeys.Has(storageKey) && activeHotkeys[storageKey] != "") {
        try Hotkey(activeHotkeys[storageKey], callback, "Off")
    }
    
    if (hotkeyName = "") {
        activeHotkeys[storageKey] := ""
        return
    }
    
    ; Build the full hotkey name with wildcard prefix
    fullHotkey := wildcard ? "*" . hotkeyName : hotkeyName
    try {
        Hotkey(fullHotkey, callback, "On")
        activeHotkeys[storageKey] := fullHotkey
    }
}

; === Inventory Manager Macro Functions ===
IMButton1Func(*) {
    global InventoryManagerActive, ScriptSuspended, IM_SleepDelay, IM_SleepDelay2, IM_DropKey
    
    if (!InventoryManagerActive || ScriptSuspended)
        return
    
    ; Drop Backpack (up-left)
    PerformIMMouseMove(-300, -300)
    Sleep(IM_SleepDelay)
    Send("{" IM_DropKey " down}")
    Sleep(IM_SleepDelay2)
    Send("{" IM_DropKey " up}")
    PerformIMMouseMove(300, 300)
}

IMButton2Func(*) {
    global InventoryManagerActive, ScriptSuspended, IM_SleepDelay, IM_SleepDelay2, IM_DropKey
    
    if (!InventoryManagerActive || ScriptSuspended)
        return
    
    ; Drop Weapon (up-right)
    PerformIMMouseMove(300, -300)
    Sleep(IM_SleepDelay)
    Send("{" IM_DropKey " down}")
    Sleep(IM_SleepDelay2)
    Send("{" IM_DropKey " up}")
    PerformIMMouseMove(-300, 300)
}

IMButton3Func(*) {
    global InventoryManagerActive, ScriptSuspended, IM_SleepDelay, IM_SleepDelay2, IM_DropKey
    
    if (!InventoryManagerActive || ScriptSuspended)
        return
    
    ; Drop Suitcase (down-left)
    PerformIMMouseMove(-300, 300)
    Sleep(IM_SleepDelay)
    Send("{" IM_DropKey " down}")
    Sleep(IM_SleepDelay2)
    Send("{" IM_DropKey " up}")
    PerformIMMouseMove(300, -300)
}

IMButton4Func(*) {
    global InventoryManagerActive, ScriptSuspended, IM_SleepDelay, IM_SleepDelay2, IM_DropKey
    
    if (!InventoryManagerActive || ScriptSuspended)
        return
    
    ; Drop Samples (down-right)
    PerformIMMouseMove(300, 300)
    Sleep(IM_SleepDelay)
    Send("{" IM_DropKey " down}")
    Sleep(IM_SleepDelay2)
    Send("{" IM_DropKey " up}")
    PerformIMMouseMove(-300, -300)
}

; Send relative mouse movement using mouse_event (works with raw input games like Helldivers 2)
SendRelativeMouseMove(dx, dy) {
    ; MOUSEEVENTF_MOVE = 0x0001
    ; mouse_event is the legacy API that many games still respond to
    DllCall("mouse_event", "UInt", 0x0001, "Int", dx, "Int", dy, "UInt", 0, "UInt", 0)
}

; Mouse movement helper with screen resolution scaling and sensitivity multiplier
PerformIMMouseMove(raw_move_x, raw_move_y) {
    global IM_SensitivityMultiplier
    local screen_width := A_ScreenWidth
    local screen_height := A_ScreenHeight
    local BASE_WIDTH := 1920
    local BASE_HEIGHT := 1080
    
    scale_x := screen_width / BASE_WIDTH
    scale_y := screen_height / BASE_HEIGHT
    
    scaled_move_x := Round(raw_move_x * scale_x * IM_SensitivityMultiplier)
    scaled_move_y := Round(raw_move_y * scale_y * IM_SensitivityMultiplier)
    
    ; Use relative mouse movement instead of absolute SetCursorPos
    ; This is required for raw input games (Helldivers 2) that ignore SetCursorPos
    SendRelativeMouseMove(scaled_move_x, scaled_move_y)
}

; Show Inventory Manager Settings popup
ShowInventoryManagerSettings(*) {
    global imSettingsGui, settingsGui, IniPath
    global IM_Button1Hotkey, IM_Button2Hotkey, IM_Button3Hotkey, IM_Button4Hotkey
    global IM_Button1Wildcard, IM_Button2Wildcard, IM_Button3Wildcard, IM_Button4Wildcard
    global IM_DropKey, IM_SleepDelay, IM_SleepDelay2
    
    ; Switch to English keyboard layout when opening popup
    SwitchToEnglishLayout()
    
    ; Destroy existing settings GUI if it exists
    if (IsSet(imSettingsGui) && imSettingsGui) {
        try imSettingsGui.Destroy()
    }
    
    imSettingsGui := Gui("+Owner" . settingsGui.Hwnd, "Inventory Manager")
    imSettingsGui.BackColor := "202020"
    imSettingsGui.SetFont("s10 cC4C4C4", "Segoe UI")
    imSettingsGui.MarginX := Scale(10)
    imSettingsGui.MarginY := Scale(10)
    
    ; Drop Backpack (up-left)
    imSettingsGui.Add("Text", "x" Scale(10) " y" Scale(15) " w" Scale(120), "Drop Backpack ↖:")
    global imInput1 := HotkeyInput(imSettingsGui, 10, 0, "", {value: IM_Button1Hotkey, wildcard: IM_Button1Wildcard, hasWildcard: true})
    
    ; Drop Weapon (up-right)
    imSettingsGui.Add("Text", "x" Scale(10) " y+" Scale(15) " w" Scale(120), "Drop Weapon ↗:")
    global imInput2 := HotkeyInput(imSettingsGui, 10, 0, "", {value: IM_Button2Hotkey, wildcard: IM_Button2Wildcard, hasWildcard: true})
    
    ; Drop Suitcase (down-left)
    imSettingsGui.Add("Text", "x" Scale(10) " y+" Scale(15) " w" Scale(120), "Drop Suitcase ↙:")
    global imInput3 := HotkeyInput(imSettingsGui, 10, 0, "", {value: IM_Button3Hotkey, wildcard: IM_Button3Wildcard, hasWildcard: true})
    
    ; Drop Samples (down-right)
    imSettingsGui.Add("Text", "x" Scale(10) " y+" Scale(15) " w" Scale(120), "Drop Samples ↘:")
    global imInput4 := HotkeyInput(imSettingsGui, 10, 0, "", {value: IM_Button4Hotkey, wildcard: IM_Button4Wildcard, hasWildcard: true})
    
    ; Drop key
    imSettingsGui.Add("Text", "x" Scale(10) " y+" Scale(15) " w" Scale(120), "Inventory Key:")
    global imDropKeyInput := HotkeyInput(imSettingsGui, 10, 0, "", {value: IM_DropKey, hasWildcard: false})
    
    ; Delay inputs
    imSettingsGui.Add("Text", "x" Scale(10) " y+" Scale(10) " w" Scale(200) " cGray", "Timings (ms):")
    imSettingsGui.Add("Text", "x" Scale(10) " y+" Scale(5) " w" Scale(70), "Press Delay:")
    global imSleepDelayEdit := imSettingsGui.Add("Edit", "x+" Scale(5) " yp-3 w" Scale(40) " Background2f2f2f Number", IM_SleepDelay)
    
    imSettingsGui.Add("Text", "x" Scale(10) " y+" Scale(5) " w" Scale(70), "Hold Delay:")
    global imSleepDelay2Edit := imSettingsGui.Add("Edit", "x+" Scale(5) " yp-3 w" Scale(40) " Background2f2f2f Number", IM_SleepDelay2)
    
    ; Sensitivity multiplier
    imSettingsGui.Add("Text", "x" Scale(10) " y+" Scale(10) " w" Scale(200) " cGray", "Mouse Sensitivity:")
    imSettingsGui.Add("Text", "x" Scale(10) " y+" Scale(5) " w" Scale(70), "Multiplier:")
    global imSensitivityEdit := imSettingsGui.Add("Edit", "x+" Scale(5) " yp-3 w" Scale(40) " Background2f2f2f", IM_SensitivityMultiplier)
    
    ; Save button
    btnIMSave := imSettingsGui.Add("Button", "x" Scale(10) " y+" Scale(25) " w" Scale(260) " h" Scale(30) " Default", "Save Settings")
    btnIMSave.OnEvent("Click", SaveInventoryManagerSettingsPopup)
    
    imSettingsGui.OnEvent("Escape", (*) => imSettingsGui.Destroy())
    imSettingsGui.Show("w" Scale(280))
}

; Save from popup
SaveInventoryManagerSettingsPopup(*) {
    global imSettingsGui, IniPath
    global IM_Button1Hotkey, IM_Button2Hotkey, IM_Button3Hotkey, IM_Button4Hotkey
    global IM_Button1Wildcard, IM_Button2Wildcard, IM_Button3Wildcard, IM_Button4Wildcard
    global IM_DropKey, IM_SleepDelay, IM_SleepDelay2, IM_SensitivityMultiplier
    
    ; Read values from GUI controls
    IM_Button1Hotkey := imInput1.GetValue()
    IM_Button1Wildcard := imInput1.GetWildcard()
    IM_Button2Hotkey := imInput2.GetValue()
    IM_Button2Wildcard := imInput2.GetWildcard()
    IM_Button3Hotkey := imInput3.GetValue()
    IM_Button3Wildcard := imInput3.GetWildcard()
    IM_Button4Hotkey := imInput4.GetValue()
    IM_Button4Wildcard := imInput4.GetWildcard()
    IM_DropKey := imDropKeyInput.GetValue() != "" ? imDropKeyInput.GetValue() : "x"
    IM_SleepDelay := Integer(imSleepDelayEdit.Value) > 0 ? Integer(imSleepDelayEdit.Value) : 25
    IM_SleepDelay2 := Integer(imSleepDelay2Edit.Value) > 0 ? Integer(imSleepDelay2Edit.Value) : 75
    IM_SensitivityMultiplier := Float(imSensitivityEdit.Value) > 0 ? Float(imSensitivityEdit.Value) : 1.0
    
    ; Save all settings to INI
    SaveInventoryManagerSettings()
    
    ; Re-register hotkeys
    UpdateInventoryManagerStatus()
    
    imSettingsGui.Destroy()
}

; Save inventory manager settings
SaveInventoryManagerSettings() {
    global IniPath
    global IM_Button1Hotkey, IM_Button2Hotkey, IM_Button3Hotkey, IM_Button4Hotkey
    global IM_Button1Wildcard, IM_Button2Wildcard, IM_Button3Wildcard, IM_Button4Wildcard
    global IM_DropKey, IM_SleepDelay, IM_SleepDelay2, IM_SensitivityMultiplier
    
    IniWrite(IM_Button1Hotkey, IniPath, "InventoryManager", "Button1Hotkey")
    IniWrite(IM_DropKey, IniPath, "InventoryManager", "DropKey")
    IniWrite(IM_Button1Wildcard ? "1" : "0", IniPath, "InventoryManager", "Button1Wildcard")
    IniWrite(IM_Button2Hotkey, IniPath, "InventoryManager", "Button2Hotkey")
    IniWrite(IM_Button2Wildcard ? "1" : "0", IniPath, "InventoryManager", "Button2Wildcard")
    IniWrite(IM_Button3Hotkey, IniPath, "InventoryManager", "Button3Hotkey")
    IniWrite(IM_Button3Wildcard ? "1" : "0", IniPath, "InventoryManager", "Button3Wildcard")
    IniWrite(IM_Button4Hotkey, IniPath, "InventoryManager", "Button4Hotkey")
    IniWrite(IM_Button4Wildcard ? "1" : "0", IniPath, "InventoryManager", "Button4Wildcard")
    IniWrite(IM_SleepDelay, IniPath, "InventoryManager", "SleepDelay")
    IniWrite(IM_SleepDelay2, IniPath, "InventoryManager", "SleepDelay2")
    IniWrite(IM_SensitivityMultiplier, IniPath, "InventoryManager", "SensitivityMultiplier")
}

; Load settings from INI
LoadInventoryManagerSettings() {
    global IniPath
    global InventoryManagerActive
    global IM_Button1Hotkey, IM_Button2Hotkey, IM_Button3Hotkey, IM_Button4Hotkey
    global IM_Button1Wildcard, IM_Button2Wildcard, IM_Button3Wildcard, IM_Button4Wildcard
    global IM_DropKey, IM_SleepDelay, IM_SleepDelay2, IM_SensitivityMultiplier
    
    try {
        InventoryManagerActive := IniRead(IniPath, "InventoryManager", "Active", "0") = "1" ? true : false
        IM_DropKey := IniRead(IniPath, "InventoryManager", "DropKey", "x")
        IM_SensitivityMultiplier := Float(IniRead(IniPath, "InventoryManager", "SensitivityMultiplier", "1.0"))
        if (IM_SensitivityMultiplier <= 0)
            IM_SensitivityMultiplier := 1.0
        if (IM_SensitivityMultiplier > 5.0)
            IM_SensitivityMultiplier := 5.0
        ; Read each key with wildcard parsing
        temp := IniRead(IniPath, "InventoryManager", "Button1Hotkey", "")
        if (SubStr(temp, 1, 1) = "*") {
            IM_Button1Hotkey := SubStr(temp, 2)
            IM_Button1Wildcard := true
        } else {
            IM_Button1Hotkey := temp
            IM_Button1Wildcard := false
        }
        
        temp := IniRead(IniPath, "InventoryManager", "Button2Hotkey", "")
        if (SubStr(temp, 1, 1) = "*") {
            IM_Button2Hotkey := SubStr(temp, 2)
            IM_Button2Wildcard := true
        } else {
            IM_Button2Hotkey := temp
            IM_Button2Wildcard := false
        }
        
        temp := IniRead(IniPath, "InventoryManager", "Button3Hotkey", "")
        if (SubStr(temp, 1, 1) = "*") {
            IM_Button3Hotkey := SubStr(temp, 2)
            IM_Button3Wildcard := true
        } else {
            IM_Button3Hotkey := temp
            IM_Button3Wildcard := false
        }
        
        temp := IniRead(IniPath, "InventoryManager", "Button4Hotkey", "")
        if (SubStr(temp, 1, 1) = "*") {
            IM_Button4Hotkey := SubStr(temp, 2)
            IM_Button4Wildcard := true
        } else {
            IM_Button4Hotkey := temp
            IM_Button4Wildcard := false
        }
        
        IM_SleepDelay := Integer(IniRead(IniPath, "InventoryManager", "SleepDelay", "25"))
        IM_SleepDelay2 := Integer(IniRead(IniPath, "InventoryManager", "SleepDelay2", "75"))
        
        ; Override wildcard states from ini
        IM_Button1Wildcard := IniRead(IniPath, "InventoryManager", "Button1Wildcard", "0") = "1" ? true : false
        IM_Button2Wildcard := IniRead(IniPath, "InventoryManager", "Button2Wildcard", "0") = "1" ? true : false
        IM_Button3Wildcard := IniRead(IniPath, "InventoryManager", "Button3Wildcard", "0") = "1" ? true : false
        IM_Button4Wildcard := IniRead(IniPath, "InventoryManager", "Button4Wildcard", "0") = "1" ? true : false
    } catch {
        ; Defaults are already set in global variables
    }
}

; === Weapon Quick Switch ===
; === Variables ===
global WeaponQuickSwitchActive := false
global QS_Hotkey := ""
global QS_Wildcard := false
global QS_Slot1 := true
global QS_Slot2 := true
global QS_Slot3 := true
global QS_Slot4 := false
global QS_Slot1Key := "1"
global QS_Slot2Key := "2"
global QS_Slot3Key := "3"
global QS_Slot4Key := "4"
global QS_CurrentSlot := 1
global QS_PreviousSlot := 2
global QS_CurrentSlotKey := "1"
global QS_PreviousSlotKey := "2"

global qsStatusText := 0
global qsSettingsGui := 0

; Toggle weapon quick switch on/off (clickable status text)
ToggleWeaponQuickSwitchFunc(*) {
    global WeaponQuickSwitchActive, qsStatusText, IniPath
    
    WeaponQuickSwitchActive := !WeaponQuickSwitchActive
    
    if (WeaponQuickSwitchActive) {
        qsStatusText.Value := "● ON"
        qsStatusText.Opt("c00FF00")
    } else {
        qsStatusText.Value := "○ OFF"
        qsStatusText.Opt("cFF0000")
    }
    
    IniWrite(WeaponQuickSwitchActive ? "1" : "0", IniPath, "WeaponQuickSwitch", "Active")
    UpdateWeaponQuickSwitchStatus()
}

; Update QS hotkey registration based on active/suspended state
UpdateWeaponQuickSwitchStatus() {
    global WeaponQuickSwitchActive, ScriptSuspended, qsStatusText
    global QS_Hotkey, QS_Wildcard
    global QS_Slot1, QS_Slot2, QS_Slot3, QS_Slot4
    global QS_Slot1Key, QS_Slot2Key, QS_Slot3Key, QS_Slot4Key
    
    ; Update status text if GUI control exists
    if (IsSet(qsStatusText) && qsStatusText && IsObject(qsStatusText)) {
        if (WeaponQuickSwitchActive) {
            qsStatusText.Value := "● ON"
            qsStatusText.Opt("c00FF00")
        } else {
            qsStatusText.Value := "○ OFF"
            qsStatusText.Opt("cFF0000")
        }
    }
    
    if (WeaponQuickSwitchActive && !ScriptSuspended) {
        ; Register the main switch hotkey
        if (QS_Hotkey != "") {
            fullHotkey := QS_Wildcard ? "*" . QS_Hotkey : QS_Hotkey
            try Hotkey(fullHotkey, QSPerformSwitch, "On")
        }
        ; Register slot tracking hotkeys with user-configured keys
        ; Use ~* prefix: ~ for pass-through, * to ignore modifier keys
        if (QS_Slot1 && QS_Slot1Key != "") {
            try Hotkey("~*" . QS_Slot1Key, QSHandleNumKeyPress, "On")
        }
        if (QS_Slot2 && QS_Slot2Key != "") {
            try Hotkey("~*" . QS_Slot2Key, QSHandleNumKeyPress, "On")
        }
        if (QS_Slot3 && QS_Slot3Key != "") {
            try Hotkey("~*" . QS_Slot3Key, QSHandleNumKeyPress, "On")
        }
        if (QS_Slot4 && QS_Slot4Key != "") {
            try Hotkey("~*" . QS_Slot4Key, QSHandleNumKeyPress, "On")
        }
    } else {
        ; Unregister all hotkeys
        if (QS_Hotkey != "") {
            fullHotkey := QS_Wildcard ? "*" . QS_Hotkey : QS_Hotkey
            try Hotkey(fullHotkey, QSPerformSwitch, "Off")
        }
        if (QS_Slot1Key != "") {
            try Hotkey("~*" . QS_Slot1Key, QSHandleNumKeyPress, "Off")
        }
        if (QS_Slot2Key != "") {
            try Hotkey("~*" . QS_Slot2Key, QSHandleNumKeyPress, "Off")
        }
        if (QS_Slot3Key != "") {
            try Hotkey("~*" . QS_Slot3Key, QSHandleNumKeyPress, "Off")
        }
        if (QS_Slot4Key != "") {
            try Hotkey("~*" . QS_Slot4Key, QSHandleNumKeyPress, "Off")
        }
    }
}

; Perform weapon quick switch (swap between current and previous slot)
QSPerformSwitch(*) {
    global WeaponQuickSwitchActive, QS_PreviousSlotKey
    
    if (!WeaponQuickSwitchActive)
        return
    
    Send("{" QS_PreviousSlotKey " down}")
    Sleep(25)
    Send("{" QS_PreviousSlotKey " up}")
    
    global QS_CurrentSlot, QS_PreviousSlot, QS_CurrentSlotKey, QS_PreviousSlotKey
    global QS_Slot1Key, QS_Slot2Key, QS_Slot3Key, QS_Slot4Key
    
    tmp := QS_CurrentSlot
    QS_CurrentSlot := QS_PreviousSlot
    QS_PreviousSlot := tmp
    
    tmpKey := QS_CurrentSlotKey
    QS_CurrentSlotKey := QS_PreviousSlotKey
    QS_PreviousSlotKey := tmpKey
}

; Track which slot the player is on via user-configured hotkey
QSHandleNumKeyPress(*) {
    global QS_CurrentSlot, QS_PreviousSlot
    global QS_CurrentSlotKey, QS_PreviousSlotKey
    global QS_Slot1Key, QS_Slot2Key, QS_Slot3Key, QS_Slot4Key
    
    ; Extract the actual key pressed (strip ~* prefixes, e.g. "~*1" -> "1")
    hk := A_ThisHotkey
    pressedKey := hk
    while (SubStr(pressedKey, 1, 1) = "~" || SubStr(pressedKey, 1, 1) = "*")
        pressedKey := SubStr(pressedKey, 2)
    
    ; Find which slot this key belongs to
    slotNum := 0
    if (pressedKey = QS_Slot1Key)
        slotNum := 1
    else if (pressedKey = QS_Slot2Key)
        slotNum := 2
    else if (pressedKey = QS_Slot3Key)
        slotNum := 3
    else if (pressedKey = QS_Slot4Key)
        slotNum := 4
    
    if (slotNum > 0 && slotNum != QS_CurrentSlot) {
        QS_PreviousSlot := QS_CurrentSlot
        QS_CurrentSlot := slotNum
        QS_PreviousSlotKey := QS_CurrentSlotKey
        ; Get the key for the new slot
        switch slotNum {
            case 1: QS_CurrentSlotKey := QS_Slot1Key
            case 2: QS_CurrentSlotKey := QS_Slot2Key
            case 3: QS_CurrentSlotKey := QS_Slot3Key
            case 4: QS_CurrentSlotKey := QS_Slot4Key
        }
    }
}

; Show Weapon Quick Switch Settings popup
ShowWeaponQuickSwitchSettings(*) {
    global qsSettingsGui, settingsGui, IniPath
    global QS_Hotkey, QS_Wildcard
    global QS_Slot1, QS_Slot2, QS_Slot3, QS_Slot4
    global QS_Slot1Key, QS_Slot2Key, QS_Slot3Key, QS_Slot4Key
    
    ; Switch to English keyboard layout when opening popup
    SwitchToEnglishLayout()
    
    ; Destroy existing settings GUI if it exists
    if (IsSet(qsSettingsGui) && qsSettingsGui) {
        try qsSettingsGui.Destroy()
    }
    
    qsSettingsGui := Gui("+Owner" . settingsGui.Hwnd, "Weapon Swap")
    qsSettingsGui.BackColor := "202020"
    qsSettingsGui.SetFont("s10 cC4C4C4", "Segoe UI")
    qsSettingsGui.MarginX := Scale(10)
    qsSettingsGui.MarginY := Scale(10)
    
    ; Switch hotkey
    qsSettingsGui.Add("Text", "x" Scale(10) " y" Scale(15) " w" Scale(100), "Quick Switch Key:")
    global qsHotkeyInput := HotkeyInput(qsSettingsGui, 10, 0, "", {value: QS_Hotkey, wildcard: QS_Wildcard, hasWildcard: true})
    
    ; Slot tracking - each slot has a checkbox and a hotkey input
    qsSettingsGui.Add("Text", "x" Scale(10) " y+" Scale(15) " w" Scale(250), "Track Weapon Slots:")
    
    global qsSlot1Cb := qsSettingsGui.Add("CheckBox", "x" Scale(10) " y+" Scale(5) " vQSSlot1", "Slot 1:")
    qsSlot1Cb.Value := QS_Slot1
    global qsSlot1KeyInput := HotkeyInput(qsSettingsGui, 10, 0, "", {value: QS_Slot1Key, hasWildcard: false})
    
    global qsSlot2Cb := qsSettingsGui.Add("CheckBox", "x" Scale(10) " y+" Scale(10) " vQSSlot2", "Slot 2:")
    qsSlot2Cb.Value := QS_Slot2
    global qsSlot2KeyInput := HotkeyInput(qsSettingsGui, 10, 0, "", {value: QS_Slot2Key, hasWildcard: false})
    
    global qsSlot3Cb := qsSettingsGui.Add("CheckBox", "x" Scale(10) " y+" Scale(10) " vQSSlot3", "Slot 3:")
    qsSlot3Cb.Value := QS_Slot3
    global qsSlot3KeyInput := HotkeyInput(qsSettingsGui, 10, 0, "", {value: QS_Slot3Key, hasWildcard: false})
    
    global qsSlot4Cb := qsSettingsGui.Add("CheckBox", "x" Scale(10) " y+" Scale(10) " vQSSlot4", "Slot 4:")
    qsSlot4Cb.Value := QS_Slot4
    global qsSlot4KeyInput := HotkeyInput(qsSettingsGui, 10, 0, "", {value: QS_Slot4Key, hasWildcard: false})
    
    ; Info text
    qsSettingsGui.Add("Text", "x" Scale(10) " y+" Scale(15) " w" Scale(250) " cGray", "The switch key swaps between current and last used weapon slot.")
    
    ; Save button
    btnQSSave := qsSettingsGui.Add("Button", "x" Scale(10) " y+" Scale(15) " w" Scale(260) " h" Scale(30) " Default", "Save Settings")
    btnQSSave.OnEvent("Click", SaveWeaponQuickSwitchSettingsPopup)
    
    qsSettingsGui.OnEvent("Escape", (*) => qsSettingsGui.Destroy())
    qsSettingsGui.Show("w" Scale(280))
}

; Save from popup
SaveWeaponQuickSwitchSettingsPopup(*) {
    global qsSettingsGui, IniPath
    global QS_Hotkey, QS_Wildcard
    global QS_Slot1, QS_Slot2, QS_Slot3, QS_Slot4
    global QS_Slot1Key, QS_Slot2Key, QS_Slot3Key, QS_Slot4Key
    
    ; Read values from GUI controls
    QS_Hotkey := qsHotkeyInput.GetValue()
    QS_Wildcard := qsHotkeyInput.GetWildcard()
    QS_Slot1 := qsSlot1Cb.Value
    QS_Slot2 := qsSlot2Cb.Value
    QS_Slot3 := qsSlot3Cb.Value
    QS_Slot4 := qsSlot4Cb.Value
    QS_Slot1Key := qsSlot1KeyInput.GetValue() != "" ? qsSlot1KeyInput.GetValue() : "1"
    QS_Slot2Key := qsSlot2KeyInput.GetValue() != "" ? qsSlot2KeyInput.GetValue() : "2"
    QS_Slot3Key := qsSlot3KeyInput.GetValue() != "" ? qsSlot3KeyInput.GetValue() : "3"
    QS_Slot4Key := qsSlot4KeyInput.GetValue() != "" ? qsSlot4KeyInput.GetValue() : "4"
    
    ; Save all settings to INI
    SaveWeaponQuickSwitchSettings()
    
    ; Re-register hotkeys
    UpdateWeaponQuickSwitchStatus()
    
    qsSettingsGui.Destroy()
}

; Save weapon quick switch settings
SaveWeaponQuickSwitchSettings() {
    global IniPath
    global QS_Hotkey, QS_Wildcard
    global QS_Slot1, QS_Slot2, QS_Slot3, QS_Slot4
    
    IniWrite(QS_Hotkey, IniPath, "WeaponQuickSwitch", "SwitchHotkey")
    IniWrite(QS_Wildcard ? "1" : "0", IniPath, "WeaponQuickSwitch", "Wildcard")
    IniWrite(QS_Slot1 ? "1" : "0", IniPath, "WeaponQuickSwitch", "Slot1")
    IniWrite(QS_Slot2 ? "1" : "0", IniPath, "WeaponQuickSwitch", "Slot2")
    IniWrite(QS_Slot3 ? "1" : "0", IniPath, "WeaponQuickSwitch", "Slot3")
    IniWrite(QS_Slot4 ? "1" : "0", IniPath, "WeaponQuickSwitch", "Slot4")
    IniWrite(QS_Slot1Key, IniPath, "WeaponQuickSwitch", "Slot1Key")
    IniWrite(QS_Slot2Key, IniPath, "WeaponQuickSwitch", "Slot2Key")
    IniWrite(QS_Slot3Key, IniPath, "WeaponQuickSwitch", "Slot3Key")
    IniWrite(QS_Slot4Key, IniPath, "WeaponQuickSwitch", "Slot4Key")
}

; Load settings from INI
LoadWeaponQuickSwitchSettings() {
    global IniPath
    global WeaponQuickSwitchActive
    global QS_Hotkey, QS_Wildcard
    global QS_Slot1, QS_Slot2, QS_Slot3, QS_Slot4
    global QS_Slot1Key, QS_Slot2Key, QS_Slot3Key, QS_Slot4Key
    global QS_CurrentSlot, QS_PreviousSlot
    global QS_CurrentSlotKey, QS_PreviousSlotKey
    
    try {
        WeaponQuickSwitchActive := IniRead(IniPath, "WeaponQuickSwitch", "Active", "0") = "1" ? true : false
        temp := IniRead(IniPath, "WeaponQuickSwitch", "SwitchHotkey", "")
        if (SubStr(temp, 1, 1) = "*") {
            QS_Hotkey := SubStr(temp, 2)
            QS_Wildcard := true
        } else {
            QS_Hotkey := temp
            QS_Wildcard := false
        }
        
        QS_Wildcard := IniRead(IniPath, "WeaponQuickSwitch", "Wildcard", "0") = "1" ? true : false
        QS_Slot1 := IniRead(IniPath, "WeaponQuickSwitch", "Slot1", "1") = "1" ? true : false
        QS_Slot2 := IniRead(IniPath, "WeaponQuickSwitch", "Slot2", "1") = "1" ? true : false
        QS_Slot3 := IniRead(IniPath, "WeaponQuickSwitch", "Slot3", "1") = "1" ? true : false
        QS_Slot4 := IniRead(IniPath, "WeaponQuickSwitch", "Slot4", "0") = "1" ? true : false
        QS_Slot1Key := IniRead(IniPath, "WeaponQuickSwitch", "Slot1Key", "1")
        QS_Slot2Key := IniRead(IniPath, "WeaponQuickSwitch", "Slot2Key", "2")
        QS_Slot3Key := IniRead(IniPath, "WeaponQuickSwitch", "Slot3Key", "3")
        QS_Slot4Key := IniRead(IniPath, "WeaponQuickSwitch", "Slot4Key", "4")
        
        ; Initialize current/previous slot keys from loaded settings
        switch QS_CurrentSlot {
            case 1: QS_CurrentSlotKey := QS_Slot1Key
            case 2: QS_CurrentSlotKey := QS_Slot2Key
            case 3: QS_CurrentSlotKey := QS_Slot3Key
            case 4: QS_CurrentSlotKey := QS_Slot4Key
        }
        switch QS_PreviousSlot {
            case 1: QS_PreviousSlotKey := QS_Slot1Key
            case 2: QS_PreviousSlotKey := QS_Slot2Key
            case 3: QS_PreviousSlotKey := QS_Slot3Key
            case 4: QS_PreviousSlotKey := QS_Slot4Key
        }
    } catch {
        ; Defaults are already set in global variables
    }
}
