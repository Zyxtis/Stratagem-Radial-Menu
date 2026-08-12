; === Weapon Assistant ===
; === Variables ===
global WeaponAssistantActive := false
global WeaponAssistantShowInList := true
global WeaponAssistHotkey := "XButton1"
global WeaponAssistHotkeyWildcard := false
global CurrentWeaponMode := 1 ; 1=Arc-Thrower | 2=Purifier | 3=Railgun (Unsafe) | 4=Epoch | 5=Power Throw
global ToggleWeaponHotkey := ""
global ToggleWeaponHotkeyWildcard := false
global CycleWeaponModeHotkey := ""
global CycleWeaponModeHotkeyWildcard := false
global SafetyEnabled := false
global SafetyHotkey := ""
global SafetyPassThrough := true
global RegisteredSafetyHotkey := ""
global RegisteredCycleHotkey := ""

; Function to get weapon mode name in current language (dynamic translation)
GetWeaponModeName(mode) {
    static modeKeys := ["weapon_mode_arc_thrower", "weapon_mode_purifier", "weapon_mode_railgun", "weapon_mode_epoch", "weapon_mode_power_throw"]
    if (mode >= 1 && mode <= modeKeys.Length)
        return Lang.Get(modeKeys[mode])
    return "Unknown"
}

; Function to get all weapon mode names in current language (for dropdowns)
GetWeaponModeNames() {
    return [GetWeaponModeName(1), GetWeaponModeName(2), GetWeaponModeName(3), GetWeaponModeName(4), GetWeaponModeName(5)]
}

global WP_ReloadKey := "r"
global WP_InteractKey := "e"

; Charge/throw timing variables (in milliseconds)
global WP_ArcThrowerCharge := 1100  ; Arc-Thrower max charge
global WP_PurifierCharge := 1100    ; Purifier max charge
global WP_RailgunCharge := 3150     ; Railgun (Unsafe) max charge
global WP_EpochCharge := 2700       ; Epoch max charge
global WP_ThrowDelay := 250         ; Power Throw delay before interact

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
    global WeaponAssistantActive, wpStatusText, CurrentWeaponMode
    
    WeaponAssistantActive := !WeaponAssistantActive
    
    if (WeaponAssistantActive) {
        wpStatusText.Value := Lang.Get("status_on")
        wpStatusText.Opt("c00FF00")
        ToolTip(Lang.Get("weapon_assistant_on") . "`n" . Lang.Get("weapon_mode") . " " . GetWeaponModeName(CurrentWeaponMode), 5, 5)
    } else {
        wpStatusText.Value := Lang.Get("status_off")
        wpStatusText.Opt("cFF0000")
        ToolTip(Lang.Get("weapon_assistant_off"), 5, 5)
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
    
    if (CurrentWeaponMode = 1) { ; Arc-Thrower - continuous fire (keeps firing while key is held)
        while GetKeyState(cleanHotkey, "P") {
            ; Start charging
            Send("{LButton down}")
            
            ; Charge at 50ms intervals up to max charge time, checking for key release
            chargeStep := 50
            maxChargeSteps := WP_ArcThrowerCharge // chargeStep
            Loop maxChargeSteps {
                if !GetKeyState(cleanHotkey, "P")
                    break  ; User released early - exit loop
                Sleep(chargeStep)
            }
            
            ; Release the shot
            Send("{LButton up}")
            Sleep(25)
        }
    } else if (CurrentWeaponMode = 2) { ; Purifier - single shot only (fires once even if key is held)
        ; Start charging
        Send("{LButton down}")
        
        ; Charge at 50ms intervals up to max charge time, checking for key release
        chargeStep := 50
        maxChargeSteps := WP_PurifierCharge // chargeStep
        Loop maxChargeSteps {
            if !GetKeyState(cleanHotkey, "P")
                break  ; User released early - exit loop
            Sleep(chargeStep)
        }
        
        ; Release the shot
        Send("{LButton up}")
        Sleep(25)
    } else if (CurrentWeaponMode = 3) { ; Railgun (Unsafe) - auto-charge to max, release on key release
        ; Start charging - LButton down begins the charge
        Send("{LButton down}")
        
        ; Charge at 50ms intervals up to max charge time, checking for key release
        chargeStep := 50
        maxChargeSteps := WP_RailgunCharge // chargeStep
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
        
    } else if (CurrentWeaponMode = 4) { ; Epoch
        ; Start charging
        Send("{LButton down}")
        
        ; Charge at 50ms intervals up to max charge time, checking for key release
        chargeStep := 50
        maxChargeSteps := WP_EpochCharge // chargeStep
        Loop maxChargeSteps {
            if !GetKeyState(cleanHotkey, "P")
                break  ; User released early - exit loop
            Sleep(chargeStep)
        }
        
        ; Release the shot
        Send("{LButton up}")
        Sleep(25)
    } else if (CurrentWeaponMode = 5) { ; Power Throw
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
    
    wpSettingsGui := Gui("+Owner" . settingsGui.Hwnd, Lang.Get("weapon_assistant_title"))
    wpSettingsGui.BackColor := "202020"
    wpSettingsGui.SetFont("s10 cC4C4C4", "Segoe UI")
    wpSettingsGui.MarginX := Scale(10)
    wpSettingsGui.MarginY := Scale(10)
    
    ; ===== Column 1: Macro Fire Button, Reload Key, Weapon Mode =====
    ; Macro Fire Button Hotkey
    wpSettingsGui.Add("Text", "x" Scale(10) " y" Scale(15) " w" Scale(140), Lang.Get("macro_fire_button"))
    global wpFireInput := HotkeyInput(wpSettingsGui, 10, 0, "", {value: WeaponAssistHotkey, wildcard: WeaponAssistHotkeyWildcard, hasWildcard: true, excludeKeys: ["WheelUp", "WheelDown"]})
    
    ; Reload Key (used by Railgun mode)
    wpSettingsGui.Add("Text", "x" Scale(10) " y+" Scale(15) " w" Scale(140), Lang.Get("reload_key"))
    global wpReloadInput := HotkeyInput(wpSettingsGui, 10, 0, "", {value: WP_ReloadKey, hasWildcard: false, excludeKeys: ["WheelUp", "WheelDown"]})
    
    ; Cycle Mode Hotkey
    wpSettingsGui.Add("Text", "x" Scale(10) " y+" Scale(15) " w" Scale(140), Lang.Get("cycle_mode"))
    global wpCycleInput := HotkeyInput(wpSettingsGui, 10, 0, "", {value: CycleWeaponModeHotkey, wildcard: CycleWeaponModeHotkeyWildcard, hasWildcard: true, excludeKeys: ["WheelUp", "WheelDown"]})
    
    ; ===== Column 2: Safety Catch, Interact Key, Cycle Mode =====
    ; Safety Catch
    wpSettingsGui.Add("Text", "x" Scale(160) " y" Scale(15), Lang.Get("safety_catch"))
    global wpSafetyEnabledCb := wpSettingsGui.Add("CheckBox", "x+5 yp vWPSafetyEnabled")
    wpSafetyEnabledCb.Value := SafetyEnabled
    wpSafetyEnabledCb.OnEvent("Click", OnWPSafetyEnabledChange)
    
    ; Safety hotkey input (only enabled if safety catch is enabled)
    global wpSafetyInput := HotkeyInput(wpSettingsGui, 160, 0, "", {value: SafetyHotkey, hasWildcard: false, excludeKeys: ["WheelUp", "WheelDown"]})
    ; Set initial enabled state based on checkbox
    try wpSafetyInput.controls.ddl.Enabled := SafetyEnabled
    try wpSafetyInput.controls.hotkey.Enabled := SafetyEnabled
    ; Pass-through checkbox
    wpSafetyInput.controls.ddl.GetPos(&ddlX, &ddlY, &ddlW, &ddlH)
    global wpSafetyPassThroughCb := wpSettingsGui.Add("CheckBox", "x" (ddlX + ddlW + 5) " y" ddlY " vWPSafetyPassThrough", "~")
    wpSafetyPassThroughCb.Value := SafetyPassThrough
    wpSafetyPassThroughCb.Enabled := SafetyEnabled
    
    ; Interact Key (used by Power Throw mode)
    wpSafetyInput.controls.hotkey.GetPos(&hkX, &hkY, &hkW, &hkH)
    wpSettingsGui.Add("Text", "x" Scale(160) " y" (hkY + hkH + Scale(15)) " w" Scale(140), Lang.Get("interact_key"))
    global wpInteractInput := HotkeyInput(wpSettingsGui, 160, 0, "", {value: WP_InteractKey, hasWildcard: false, excludeKeys: ["WheelUp", "WheelDown"]})
    
    ; Weapon Mode Dropdown
    wpSettingsGui.Add("Text", "x" Scale(160) " y+" Scale(15), Lang.Get("weapon_mode"))
    global wpModeDDL := wpSettingsGui.Add("DropDownList", "x" Scale(160) " y+5 w" Scale(120) " Background2f2f2f", GetWeaponModeNames())
    wpModeDDL.Choose(CurrentWeaponMode)
    
    ; ===== Timing inputs =====
    wpSettingsGui.Add("Text", "x" Scale(10) " y+" Scale(40) " w" Scale(280) " cGray", Lang.Get("timings_ms"))
    
    ; Arc-Thrower charge time
    wpSettingsGui.Add("Text", "x" Scale(10) " y+" Scale(5) " w" Scale(100), Lang.Get("arc_thrower_charge"))
    global wpArcThrowerCharge := wpSettingsGui.Add("Edit", "x+" Scale(5) " yp-3 w" Scale(60) " Background2f2f2f Number", WP_ArcThrowerCharge)
    
    ; Purifier charge time
    wpSettingsGui.Add("Text", "x" Scale(10) " y+" Scale(5) " w" Scale(100), Lang.Get("purifier_charge"))
    global wpPurifierCharge := wpSettingsGui.Add("Edit", "x+" Scale(5) " yp-3 w" Scale(60) " Background2f2f2f Number", WP_PurifierCharge)
    
    ; Railgun charge time
    wpSettingsGui.Add("Text", "x" Scale(10) " y+" Scale(5) " w" Scale(100), Lang.Get("railgun_charge"))
    global wpRailgunCharge := wpSettingsGui.Add("Edit", "x+" Scale(5) " yp-3 w" Scale(60) " Background2f2f2f Number", WP_RailgunCharge)
    
    ; Epoch charge time
    wpSettingsGui.Add("Text", "x" Scale(10) " y+" Scale(5) " w" Scale(100), Lang.Get("epoch_charge"))
    global wpEpochCharge := wpSettingsGui.Add("Edit", "x+" Scale(5) " yp-3 w" Scale(60) " Background2f2f2f Number", WP_EpochCharge)
    
    ; Power Throw delay
    wpSettingsGui.Add("Text", "x" Scale(10) " y+" Scale(5) " w" Scale(100), Lang.Get("throw_delay"))
    global wpThrowDelay := wpSettingsGui.Add("Edit", "x+" Scale(5) " yp-3 w" Scale(60) " Background2f2f2f Number", WP_ThrowDelay)
    
    ; Show in floating list checkbox
    global wpShowInListCb := wpSettingsGui.Add("CheckBox", "x" Scale(10) " y+" Scale(15) " vWPShowInList", Lang.Get("show_in_list"))
    wpShowInListCb.Value := WeaponAssistantShowInList
    
    ; Save button
    btnWPSave := wpSettingsGui.Add("Button", "x" Scale(10) " y+" Scale(10) " w" Scale(280) " h" Scale(30) " Default", Lang.Get("save_settings"))
    btnWPSave.OnEvent("Click", SaveWeaponAssistantSettingsPopup)
    
    wpSettingsGui.OnEvent("Escape", (*) => wpSettingsGui.Destroy())
    wpSettingsGui.Show("w" Scale(300))
}

; Register cycle mode hotkey
SetWeaponCycleHotkey() {
    global CycleWeaponModeHotkey, CycleWeaponModeHotkeyWildcard, RegisteredCycleHotkey
    opts := CycleWeaponModeHotkeyWildcard ? "W" : ""
    RegisterSimpleHotkey(CycleWeaponModeHotkey, CycleWeaponModeFunc, "WeaponCycle", opts)
    
    ; Track the FULL registered hotkey (including * prefix if wildcard) for proper cleanup when assistant turns off
    if (CycleWeaponModeHotkey != "") {
        fullHK := CycleWeaponModeHotkey
        if (CycleWeaponModeHotkeyWildcard && SubStr(fullHK, 1, 1) != "*")
            fullHK := "*" . fullHK
        RegisteredCycleHotkey := fullHK
    } else {
        RegisteredCycleHotkey := ""
    }
}

; Cycle through weapon modes 1→2→3→4→5→1
CycleWeaponModeFunc(*) {
    global CurrentWeaponMode, wpModeDDL, wpStatusText, WeaponAssistantActive
    
    ; Cycle through modes 1-2-3-4-5-1 (Arc-Thrower, Purifier, Railgun Unsafe, Epoch, Power Throw)
    CurrentWeaponMode := (CurrentWeaponMode >= 5) ? 1 : CurrentWeaponMode + 1
    
    modeName := GetWeaponModeName(CurrentWeaponMode)
    if (WeaponAssistantActive) {
        wpStatusText.Value := Lang.Get("status_on")
        wpStatusText.Opt("c00FF00")
    }
    
    ToolTip(Lang.Get("tooltip_weapon_mode") . " " . modeName, 5, 5)
    SetTimer(RemoveToolTip, -1000)
    RefreshKeybindListIfVisible()
}

; Save from popup
SaveWeaponAssistantSettingsPopup(*) {
    global wpSettingsGui, IniPath
    global wpModeDDL, wpFireInput, wpSafetyEnabledCb, wpSafetyInput, wpSafetyPassThroughCb, wpCycleInput
    global wpReloadInput, wpInteractInput
    global wpArcThrowerCharge, wpPurifierCharge, wpRailgunCharge, wpEpochCharge, wpThrowDelay
    global CurrentWeaponMode, WeaponAssistHotkey, WeaponAssistHotkeyWildcard
    global SafetyEnabled, SafetyHotkey, SafetyPassThrough, CycleWeaponModeHotkey, CycleWeaponModeHotkeyWildcard
    global WP_ReloadKey, WP_InteractKey
    global WP_ArcThrowerCharge, WP_PurifierCharge, WP_RailgunCharge, WP_EpochCharge, WP_ThrowDelay
    global ToggleWeaponHotkey, ToggleWeaponHotkeyWildcard
    global WeaponAssistantShowInList, wpShowInListCb
    
    ; Read values from GUI controls
    CurrentWeaponMode := wpModeDDL.Value
    WeaponAssistHotkey := wpFireInput.GetValue()
    WeaponAssistHotkeyWildcard := wpFireInput.GetWildcard()
    SafetyEnabled := wpSafetyEnabledCb.Value
    SafetyHotkey := wpSafetyInput.GetValue()
    SafetyPassThrough := wpSafetyPassThroughCb.Value
    CycleWeaponModeHotkey := wpCycleInput.GetValue()
    CycleWeaponModeHotkeyWildcard := wpCycleInput.GetWildcard()
    WP_ReloadKey := wpReloadInput.GetValue() != "" ? wpReloadInput.GetValue() : "r"
    WP_InteractKey := wpInteractInput.GetValue() != "" ? wpInteractInput.GetValue() : "e"
    WP_ArcThrowerCharge := Integer(wpArcThrowerCharge.Value) > 0 ? Integer(wpArcThrowerCharge.Value) : 1100
    WP_PurifierCharge := Integer(wpPurifierCharge.Value) > 0 ? Integer(wpPurifierCharge.Value) : 1100
    WP_RailgunCharge := Integer(wpRailgunCharge.Value) > 0 ? Integer(wpRailgunCharge.Value) : 3150
    WP_EpochCharge := Integer(wpEpochCharge.Value) > 0 ? Integer(wpEpochCharge.Value) : 2700
    WP_ThrowDelay := Integer(wpThrowDelay.Value) > 0 ? Integer(wpThrowDelay.Value) : 250
    WeaponAssistantShowInList := wpShowInListCb.Value
    
    ; Save all settings to INI
    IniWrite(ToggleWeaponHotkey, IniPath, "WeaponAssistant", "ToggleHotkey")
    IniWrite(ToggleWeaponHotkeyWildcard ? "1" : "0", IniPath, "WeaponAssistant", "ToggleHotkeyWildcard")
    IniWrite(WeaponAssistHotkey, IniPath, "WeaponAssistant", "FireHotkey")
    IniWrite(WeaponAssistHotkeyWildcard ? "1" : "0", IniPath, "WeaponAssistant", "FireHotkeyWildcard")
    IniWrite(CycleWeaponModeHotkey, IniPath, "WeaponAssistant", "CycleHotkey")
    IniWrite(CycleWeaponModeHotkeyWildcard ? "1" : "0", IniPath, "WeaponAssistant", "CycleHotkeyWildcard")
    IniWrite(CurrentWeaponMode, IniPath, "WeaponAssistant", "CurrentMode")
    IniWrite(SafetyEnabled ? "1" : "0", IniPath, "WeaponAssistant", "SafetyEnabled")
    IniWrite(SafetyHotkey, IniPath, "WeaponAssistant", "SafetyHotkey")
    IniWrite(SafetyPassThrough ? "1" : "0", IniPath, "WeaponAssistant", "SafetyPassThrough")
    IniWrite(WP_ReloadKey, IniPath, "WeaponAssistant", "ReloadKey")
    IniWrite(WP_InteractKey, IniPath, "WeaponAssistant", "InteractKey")
    IniWrite(WP_ArcThrowerCharge, IniPath, "WeaponAssistant", "ArcThrowerCharge")
    IniWrite(WP_PurifierCharge, IniPath, "WeaponAssistant", "PurifierCharge")
    IniWrite(WP_RailgunCharge, IniPath, "WeaponAssistant", "RailgunCharge")
    IniWrite(WP_EpochCharge, IniPath, "WeaponAssistant", "EpochCharge")
    IniWrite(WP_ThrowDelay, IniPath, "WeaponAssistant", "ThrowDelay")
    IniWrite(WeaponAssistantShowInList ? "1" : "0", IniPath, "WeaponAssistant", "ShowInList")
    
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
    global ToggleWeaponHotkey, ToggleWeaponHotkeyWildcard, WeaponAssistHotkey, WeaponAssistHotkeyWildcard, CycleWeaponModeHotkey, CycleWeaponModeHotkeyWildcard
    global CurrentWeaponMode, SafetyEnabled, SafetyHotkey, SafetyPassThrough, IniPath
    global WP_ReloadKey, WP_InteractKey
    global WP_ArcThrowerCharge, WP_PurifierCharge, WP_RailgunCharge, WP_EpochCharge, WP_ThrowDelay
    
    IniWrite(ToggleWeaponHotkey, IniPath, "WeaponAssistant", "ToggleHotkey")
    IniWrite(ToggleWeaponHotkeyWildcard ? "1" : "0", IniPath, "WeaponAssistant", "ToggleHotkeyWildcard")
    IniWrite(WeaponAssistHotkey, IniPath, "WeaponAssistant", "FireHotkey")
    IniWrite(WeaponAssistHotkeyWildcard ? "1" : "0", IniPath, "WeaponAssistant", "FireHotkeyWildcard")
    IniWrite(CycleWeaponModeHotkey, IniPath, "WeaponAssistant", "CycleHotkey")
    IniWrite(CycleWeaponModeHotkeyWildcard ? "1" : "0", IniPath, "WeaponAssistant", "CycleHotkeyWildcard")
    IniWrite(CurrentWeaponMode, IniPath, "WeaponAssistant", "CurrentMode")
    IniWrite(SafetyEnabled ? "1" : "0", IniPath, "WeaponAssistant", "SafetyEnabled")
    IniWrite(SafetyHotkey, IniPath, "WeaponAssistant", "SafetyHotkey")
    IniWrite(SafetyPassThrough ? "1" : "0", IniPath, "WeaponAssistant", "SafetyPassThrough")
    IniWrite(WP_ReloadKey, IniPath, "WeaponAssistant", "ReloadKey")
    IniWrite(WP_InteractKey, IniPath, "WeaponAssistant", "InteractKey")
    IniWrite(WP_ArcThrowerCharge, IniPath, "WeaponAssistant", "ArcThrowerCharge")
    IniWrite(WP_PurifierCharge, IniPath, "WeaponAssistant", "PurifierCharge")
    IniWrite(WP_RailgunCharge, IniPath, "WeaponAssistant", "RailgunCharge")
    IniWrite(WP_EpochCharge, IniPath, "WeaponAssistant", "EpochCharge")
    IniWrite(WP_ThrowDelay, IniPath, "WeaponAssistant", "ThrowDelay")
    IniWrite(WeaponAssistantShowInList ? "1" : "0", IniPath, "WeaponAssistant", "ShowInList")
}

; Load settings from INI
LoadWeaponAssistantSettings() {
    global ToggleWeaponHotkey, ToggleWeaponHotkeyWildcard, WeaponAssistHotkey, WeaponAssistHotkeyWildcard, CycleWeaponModeHotkey, CycleWeaponModeHotkeyWildcard
    global CurrentWeaponMode, SafetyEnabled, SafetyHotkey, SafetyPassThrough, IniPath
    global WP_ReloadKey, WP_InteractKey
    global WP_ArcThrowerCharge, WP_PurifierCharge, WP_RailgunCharge, WP_EpochCharge, WP_ThrowDelay
    global WeaponAssistantShowInList
    
    try {
        ToggleWeaponHotkey := IniRead(IniPath, "WeaponAssistant", "ToggleHotkey", "")
        ToggleWeaponHotkeyWildcard := IniRead(IniPath, "WeaponAssistant", "ToggleHotkeyWildcard", "0") = "1" ? true : false
        WeaponAssistHotkey := IniRead(IniPath, "WeaponAssistant", "FireHotkey", "XButton1")
        WeaponAssistHotkeyWildcard := IniRead(IniPath, "WeaponAssistant", "FireHotkeyWildcard", "0") = "1" ? true : false
        CycleWeaponModeHotkey := IniRead(IniPath, "WeaponAssistant", "CycleHotkey", "")
        CycleWeaponModeHotkeyWildcard := IniRead(IniPath, "WeaponAssistant", "CycleHotkeyWildcard", "0") = "1" ? true : false
        CurrentWeaponMode := Integer(IniRead(IniPath, "WeaponAssistant", "CurrentMode", "1"))
        SafetyEnabled := IniRead(IniPath, "WeaponAssistant", "SafetyEnabled", "0") = "1" ? true : false
        SafetyHotkey := IniRead(IniPath, "WeaponAssistant", "SafetyHotkey", "")
        SafetyPassThrough := IniRead(IniPath, "WeaponAssistant", "SafetyPassThrough", "1") = "1" ? true : false
        WP_ReloadKey := IniRead(IniPath, "WeaponAssistant", "ReloadKey", "r")
        WP_InteractKey := IniRead(IniPath, "WeaponAssistant", "InteractKey", "e")
        WP_ArcThrowerCharge := Integer(IniRead(IniPath, "WeaponAssistant", "ArcThrowerCharge", "1100"))
        WP_PurifierCharge := Integer(IniRead(IniPath, "WeaponAssistant", "PurifierCharge", "1100"))
        WP_RailgunCharge := Integer(IniRead(IniPath, "WeaponAssistant", "RailgunCharge", "3150"))
        WP_EpochCharge := Integer(IniRead(IniPath, "WeaponAssistant", "EpochCharge", "2700"))
        WP_ThrowDelay := Integer(IniRead(IniPath, "WeaponAssistant", "ThrowDelay", "250"))
        WeaponAssistantShowInList := IniRead(IniPath, "WeaponAssistant", "ShowInList", "1") = "1" ? true : false
    } catch {
        ; Defaults are already set in global variables
    }
}

; === Driver Assistant ===
; === Variables ===
global DriverAssistantActive := false
global DriverAssistantShowInList := true
global ToggleDriverHotkey := ""
global ToggleDriverHotkeyWildcard := false
global DADriverLastKey := ""
global DA_Forward_Key := "w"
global DA_Backward_Key := "s"
global DA_Exit_Key := "e"
global DA_Swap_Key := "c"
global DA_GearUp_Key := "Shift"
global DA_GearDown_Key := "Ctrl"
global DA_StratagemCallEnabled := false
global DA_ForwardGearMode := 1 ; 1=1st gear, 2=2nd gear, 3=D gear
global DA_ForwardGearModeNames := ["1st Gear", "2nd Gear", "D Gear"]
global DA_EnhancedGearSwitch := false ; if true, press forward after reverse shifts directly to chosen gear
global DA_Handbrake_Key := "Space"
global DA_HandbrakeOnExit := false ; if true, hold handbrake key when exiting vehicle
global DA_KeyPressDelay := 25 ; delay between key down/up in ms
global DA_EnterVehicleKey := "e"
global DA_EnterVehicleOnToggle := false ; if true, press enter vehicle key when toggling assistant on

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
    global DA_EnterVehicleKey, DA_EnterVehicleOnToggle, DA_KeyPressDelay
    
    DriverAssistantActive := !DriverAssistantActive
    
    if (DriverAssistantActive) {
        daStatusText.Value := Lang.Get("status_on")
        daStatusText.Opt("c00FF00")
        ToolTip(Lang.Get("driver_assistant_on"), 5, 5)
        
        ; If enabled, press the enter vehicle key when toggling on
        if (DA_EnterVehicleOnToggle && DA_EnterVehicleKey != "") {
            SendInput("{" DA_EnterVehicleKey " down}")
            Sleep DA_KeyPressDelay
            SendInput("{" DA_EnterVehicleKey " up}")
        }
    } else {
        daStatusText.Value := Lang.Get("status_off")
        daStatusText.Opt("cFF0000")
        ToolTip(Lang.Get("driver_assistant_off"), 5, 5)
    }
    
    SetTimer(RemoveToolTip, -1200)
    UpdateDriverAssistantStatus()
    RefreshKeybindListIfVisible()
}

; Update driver maco hotkeys based on active/suspended state
UpdateDriverAssistantStatus() {
    global DriverAssistantActive, ScriptSuspended
    global DA_Forward_Key, DA_Backward_Key, DA_Exit_Key, DADriverLastKey, DA_HandbrakeOnExit
    
    if (DriverAssistantActive && !ScriptSuspended) {
        ; Activate the W, S and E hotkeys only when the assistant is active and not suspended
        if (DA_Forward_Key != "")
            RegisterSimpleHotkey("~*" . DA_Forward_Key, DriverMacroWFunc, "DriverMacroW", "SW")
        if (DA_Backward_Key != "")
            RegisterSimpleHotkey("~*" . DA_Backward_Key, DriverMacroSFunc, "DriverMacroS", "SW")
        if (DA_Exit_Key != "") {
            ; If handbrake on exit is enabled, don't use pass-through (~) so we can
            ; hold the handbrake first, then send the exit key manually
            ePrefix := DA_HandbrakeOnExit ? "*" : "~*"
            RegisterSimpleHotkey(ePrefix . DA_Exit_Key, DriverMacroEFunc, "DriverMacroE", "SW")
        }
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
    global DriverAssistantActive, ScriptSuspended, DADriverLastKey, DA_Forward_Key, DA_Backward_Key
    global DA_GearUp_Key, DA_GearDown_Key, DA_ForwardGearMode, DA_EnhancedGearSwitch
    global DA_KeyPressDelay
    
    if (!DriverAssistantActive || ScriptSuspended)
        return
    
    ; Check if the last key pressed was the same key (prevent repeat)
    If (DADriverLastKey = DA_Forward_Key) {
        Return
    }
    
    ; Save whether we came from reverse before updating DADriverLastKey
    cameFromReverse := DA_EnhancedGearSwitch && (DADriverLastKey = DA_Backward_Key)
    DADriverLastKey := DA_Forward_Key
    
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
            Sleep DA_KeyPressDelay
            SendInput("{" DA_GearUp_Key " up}")
            Sleep DA_KeyPressDelay
        }
    } else {
        ; Original behavior: shift up 4 times to top, then shift down to selected gear
        Loop 4
        {
            SendInput("{" DA_GearUp_Key " down}")
            Sleep DA_KeyPressDelay
            SendInput("{" DA_GearUp_Key " up}")
            Sleep DA_KeyPressDelay
        }
        
        ; Shift down based on selected gear mode
        if (DA_ForwardGearMode = 1) { ; 1st Gear - one gear down from top
            SendInput("{" DA_GearDown_Key " down}")
            Sleep DA_KeyPressDelay
            SendInput("{" DA_GearDown_Key " up}")
            Sleep DA_KeyPressDelay
        } else if (DA_ForwardGearMode = 3) { ; D Gear - two gear downs from top
            SendInput("{" DA_GearDown_Key " down}")
            Sleep DA_KeyPressDelay
            SendInput("{" DA_GearDown_Key " up}")
            Sleep DA_KeyPressDelay
            SendInput("{" DA_GearDown_Key " down}")
            Sleep DA_KeyPressDelay
            SendInput("{" DA_GearDown_Key " up}")
            Sleep DA_KeyPressDelay
        }
        ; Mode 2 (2nd Gear): no gear downs needed
    }
    
    KeyWait(DA_Forward_Key)
}

; --- Macro for configurable backward key ---
DriverMacroSFunc(*) {
    global DriverAssistantActive, ScriptSuspended, DADriverLastKey, DA_Backward_Key
    global DA_KeyPressDelay
    
    if (!DriverAssistantActive || ScriptSuspended)
        return
    
    ; Check if the last key pressed was the same key (prevent repeat)
    If (DADriverLastKey = DA_Backward_Key) {
        Return
    }
    DADriverLastKey := DA_Backward_Key
    
    Loop 4
    {
        SendInput("{" DA_GearDown_Key " down}")
        Sleep DA_KeyPressDelay
        SendInput("{" DA_GearDown_Key " up}")
        Sleep DA_KeyPressDelay
    }
    KeyWait(DA_Backward_Key)
}

; --- Macro for configurable exit key ---
DriverMacroEFunc(*) {
    global DriverAssistantActive, DA_Handbrake_Key, DA_HandbrakeOnExit, DA_Exit_Key
    global DA_KeyPressDelay
    
    if (!DriverAssistantActive)
        return
    
    if (DA_HandbrakeOnExit && DA_Handbrake_Key != "") {
        ; Hold the handbrake key first
        SendInput("{" DA_Handbrake_Key " down}")
        Sleep DA_KeyPressDelay
        
        ; Send the exit key manually (since it's not in pass-through mode)
        if (DA_Exit_Key != "") {
            SendInput("{" DA_Exit_Key " down}")
            Sleep DA_KeyPressDelay
            SendInput("{" DA_Exit_Key " up}")
        }
    }
    ; When handbrake on exit is disabled, the exit key is in pass-through mode (~*),
    ; so the game receives the key press naturally - no manual send needed
    
    ; Deactivate the driver assistant when the exit key is pressed
    DriverAssistantActive := false
    UpdateDriverAssistantStatus()
    if (IsSet(daStatusText) && daStatusText) {
        daStatusText.Value := Lang.Get("status_off")
        daStatusText.Opt("cFF0000")
    }
    ToolTip(Lang.Get("driver_assistant_off"), 5, 5)
    SetTimer(RemoveToolTip, -1200)
    RefreshKeybindListIfVisible()
    
    ; Wait for the vehicle to exit
    if (DA_HandbrakeOnExit && DA_Handbrake_Key != "") {
        Sleep 1000
        
        ; Release the handbrake key
        SendInput("{" DA_Handbrake_Key " up}")
    }
}

; Show Driver Assistant Settings popup
ShowDriverAssistantSettings(*) {
    global daSettingsGui, settingsGui, IniPath
    global DA_Forward_Key, DA_Backward_Key, DA_Exit_Key, DA_GearUp_Key, DA_GearDown_Key
    
    ; Switch to English keyboard layout when opening popup
    SwitchToEnglishLayout()
    
    ; Destroy existing settings GUI if it exists
    if (IsSet(daSettingsGui) && daSettingsGui) {
        try daSettingsGui.Destroy()
    }
    
    daSettingsGui := Gui("+Owner" . settingsGui.Hwnd, Lang.Get("driver_assistant_title"))
    daSettingsGui.BackColor := "202020"
    daSettingsGui.SetFont("s10 cC4C4C4", "Segoe UI")
    daSettingsGui.MarginX := Scale(10)
    daSettingsGui.MarginY := Scale(10)
    
    ; Column 1: Forward, Enter Vehicle, Gear Up, Handbrake, Forward Gear Mode
    daSettingsGui.Add("Text", "x" Scale(10) " y" Scale(15) " w" Scale(140), Lang.Get("forward_key"))
    global daWInput := HotkeyInput(daSettingsGui, 10, 0, "", {value: DA_Forward_Key, hasWildcard: false})

    daSettingsGui.Add("Text", "x" Scale(10) " y+" Scale(15) " w" Scale(140), Lang.Get("enter_vehicle_key"))
    global daEnterVehicleInput := HotkeyInput(daSettingsGui, 10, 0, "", {value: DA_EnterVehicleKey, hasWildcard: false})

    daSettingsGui.Add("Text", "x" Scale(10) " y+" Scale(15) " w" Scale(140), Lang.Get("gear_up_key"))
    global daGearUpInput := HotkeyInput(daSettingsGui, 10, 0, "", {value: DA_GearUp_Key, hasWildcard: false})

    daSettingsGui.Add("Text", "x" Scale(10) " y+" Scale(15) " w" Scale(140), Lang.Get("handbrake_key"))
    global daHandbrakeInput := HotkeyInput(daSettingsGui, 10, 0, "", {value: DA_Handbrake_Key, hasWildcard: false})

    daSettingsGui.Add("Text", "x" Scale(10) " y+" Scale(15) " w" Scale(140), Lang.Get("forward_gear"))
    global daGearModeDDL := daSettingsGui.Add("DropDownList", "x" Scale(10) " y+" Scale(5) " w" Scale(100) " Background2f2f2f", DA_ForwardGearModeNames)
    daGearModeDDL.Choose(DA_ForwardGearMode)

    ; Column 2: Backward, Exit, Gear Down, Swap Seats, Key Press Delay
    daSettingsGui.Add("Text", "x" Scale(150) " y" Scale(15) " w" Scale(140), Lang.Get("backward_key"))
    global daSInput := HotkeyInput(daSettingsGui, 150, 0, "", {value: DA_Backward_Key, hasWildcard: false})

    daSettingsGui.Add("Text", "x" Scale(150) " y+" Scale(15) " w" Scale(140), Lang.Get("exit_vehicle_key"))
    global daEInput := HotkeyInput(daSettingsGui, 150, 0, "", {value: DA_Exit_Key, hasWildcard: false})

    daSettingsGui.Add("Text", "x" Scale(150) " y+" Scale(15) " w" Scale(140), Lang.Get("gear_down_key"))
    global daGearDownInput := HotkeyInput(daSettingsGui, 150, 0, "", {value: DA_GearDown_Key, hasWildcard: false})

    daSettingsGui.Add("Text", "x" Scale(150) " y+" Scale(15) " w" Scale(140), Lang.Get("swap_seats_key"))
    global daCInput := HotkeyInput(daSettingsGui, 150, 0, "", {value: DA_Swap_Key, hasWildcard: false})

    daSettingsGui.Add("Text", "x" Scale(150) " y+" Scale(15) " w" Scale(160), Lang.Get("key_press_delay_da"))
    global daKeyPressDelayEdit := daSettingsGui.Add("Edit", "x" Scale(150) " y+" Scale(5) " w" Scale(100) " Background2f2f2f Number", DA_KeyPressDelay)
    
    ; Enhanced Gear Switch checkbox
    global daEnhancedCb := daSettingsGui.Add("CheckBox", "x" Scale(10) " y+" Scale(20) " vDA_EnhancedGearSwitch", Lang.Get("enhanced_gear_switch"))
    daEnhancedCb.Value := DA_EnhancedGearSwitch
    
    ; Enter Vehicle on Toggle checkbox
    global daEnterVehicleOnToggleCb := daSettingsGui.Add("CheckBox", "x" Scale(10) " y+" Scale(10) " vDA_EnterVehicleOnToggle", Lang.Get("enter_vehicle_on_toggle"))
    daEnterVehicleOnToggleCb.Value := DA_EnterVehicleOnToggle

    ; Handbrake on Exit checkbox
    global daHandbrakeOnExitCb := daSettingsGui.Add("CheckBox", "x" Scale(10) " y+" Scale(10) " vDA_HandbrakeOnExit", Lang.Get("handbrake_on_exit"))
    daHandbrakeOnExitCb.Value := DA_HandbrakeOnExit

    ; Driver Stratagem Call checkbox
    global daStratagemCallCb := daSettingsGui.Add("CheckBox", "x" Scale(10) " y+" Scale(10) " vDA_StratagemCallEnabled", Lang.Get("driver_stratagem_call"))
    daStratagemCallCb.Value := DA_StratagemCallEnabled
    
    ; Show in floating list checkbox
    global daShowInListCb := daSettingsGui.Add("CheckBox", "x" Scale(10) " y+" Scale(10) " vDAShowInList", Lang.Get("show_in_list"))
    daShowInListCb.Value := DriverAssistantShowInList
    
    ; Save button
    btnDASave := daSettingsGui.Add("Button", "x" Scale(10) " y+" Scale(10) " w" Scale(280) " h" Scale(30) " Default", Lang.Get("save_settings"))
    btnDASave.OnEvent("Click", SaveDriverAssistantSettingsPopup)
    
    daSettingsGui.OnEvent("Escape", (*) => daSettingsGui.Destroy())
    daSettingsGui.Show("w" Scale(300))
}

; Save from popup
SaveDriverAssistantSettingsPopup(*) {
    global daSettingsGui, IniPath
    global DA_Forward_Key, DA_Backward_Key, DA_Exit_Key, DA_Swap_Key, DA_GearUp_Key, DA_GearDown_Key, DA_StratagemCallEnabled
    global daWInput, daSInput, daEInput, daCInput, daGearUpInput, daGearDownInput, daStratagemCallCb
    global DA_ForwardGearMode, daGearModeDDL, DA_EnhancedGearSwitch, daEnhancedCb
    global DriverAssistantShowInList, daShowInListCb
    global DA_Handbrake_Key, DA_HandbrakeOnExit, daHandbrakeInput, daHandbrakeOnExitCb
    global DA_KeyPressDelay, daKeyPressDelayEdit
    global DA_EnterVehicleKey, DA_EnterVehicleOnToggle, daEnterVehicleInput, daEnterVehicleOnToggleCb
    
    ; Read values from inputs
    DA_Forward_Key := daWInput.GetValue() != "" ? daWInput.GetValue() : "w"
    DA_Backward_Key := daSInput.GetValue() != "" ? daSInput.GetValue() : "s"
    DA_Exit_Key := daEInput.GetValue() != "" ? daEInput.GetValue() : "e"
    DA_Swap_Key := daCInput.GetValue() != "" ? daCInput.GetValue() : "c"
    DA_GearUp_Key := daGearUpInput.GetValue() != "" ? daGearUpInput.GetValue() : "Shift"
    DA_GearDown_Key := daGearDownInput.GetValue() != "" ? daGearDownInput.GetValue() : "Ctrl"
    DA_StratagemCallEnabled := daStratagemCallCb.Value
    DA_ForwardGearMode := daGearModeDDL.Value
    DA_EnhancedGearSwitch := daEnhancedCb.Value
    DA_Handbrake_Key := daHandbrakeInput.GetValue() != "" ? daHandbrakeInput.GetValue() : "Space"
    DA_HandbrakeOnExit := daHandbrakeOnExitCb.Value
    DA_KeyPressDelay := Integer(daKeyPressDelayEdit.Value) > 0 ? Integer(daKeyPressDelayEdit.Value) : 25
    DA_EnterVehicleKey := daEnterVehicleInput.GetValue() != "" ? daEnterVehicleInput.GetValue() : "e"
    DA_EnterVehicleOnToggle := daEnterVehicleOnToggleCb.Value
    DriverAssistantShowInList := daShowInListCb.Value
    
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
    global DA_Swap_Key, DA_StratagemCallEnabled, DriverAssistantActive
    global DA_KeyPressDelay
    
    if (!DriverAssistantActive || !DA_StratagemCallEnabled)
        return false  ; Not executed
    
    ; 1. Swap seats (press the configured swap seats key)
    if (DA_Swap_Key != "") {
        SendInput("{" DA_Swap_Key " down}")
        Sleep DA_KeyPressDelay
        SendInput("{" DA_Swap_Key " up}")
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
    global DA_Swap_Key, DA_KeyPressDelay
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
    if (lmbPressed && DA_Swap_Key != "") {
        SendInput("{" DA_Swap_Key " down}")
        Sleep DA_KeyPressDelay
        SendInput("{" DA_Swap_Key " up}")
    }
}

; Save driver assistant settings
SaveDriverAssistantSettings() {
    global IniPath, ToggleDriverHotkey, ToggleDriverHotkeyWildcard
    global DA_Forward_Key, DA_Backward_Key, DA_Exit_Key, DA_Swap_Key, DA_GearUp_Key, DA_GearDown_Key
    global DA_StratagemCallEnabled, DA_ForwardGearMode, DA_EnhancedGearSwitch
    global DA_Handbrake_Key, DA_HandbrakeOnExit, DA_KeyPressDelay
    global DA_EnterVehicleKey, DA_EnterVehicleOnToggle
    
    IniWrite(ToggleDriverHotkey, IniPath, "DriverAssistant", "ToggleHotkey")
    IniWrite(ToggleDriverHotkeyWildcard ? "1" : "0", IniPath, "DriverAssistant", "ToggleHotkeyWildcard")
    IniWrite(DA_Forward_Key, IniPath, "DriverAssistant", "DA_Forward_Key")
    IniWrite(DA_Backward_Key, IniPath, "DriverAssistant", "DA_Backward_Key")
    IniWrite(DA_Exit_Key, IniPath, "DriverAssistant", "DA_Exit_Key")
    IniWrite(DA_Swap_Key, IniPath, "DriverAssistant", "DA_Swap_Key")
    IniWrite(DA_GearUp_Key, IniPath, "DriverAssistant", "DA_GearUp_Key")
    IniWrite(DA_GearDown_Key, IniPath, "DriverAssistant", "DA_GearDown_Key")
    IniWrite(DA_StratagemCallEnabled ? "1" : "0", IniPath, "DriverAssistant", "DA_StratagemCallEnabled")
    IniWrite(DA_ForwardGearMode, IniPath, "DriverAssistant", "DA_ForwardGearMode")
    IniWrite(DA_EnhancedGearSwitch ? "1" : "0", IniPath, "DriverAssistant", "DA_EnhancedGearSwitch")
    IniWrite(DA_Handbrake_Key, IniPath, "DriverAssistant", "DA_Handbrake_Key")
    IniWrite(DA_HandbrakeOnExit ? "1" : "0", IniPath, "DriverAssistant", "DA_HandbrakeOnExit")
    IniWrite(DA_KeyPressDelay, IniPath, "DriverAssistant", "DA_KeyPressDelay")
    IniWrite(DA_EnterVehicleKey, IniPath, "DriverAssistant", "DA_EnterVehicleKey")
    IniWrite(DA_EnterVehicleOnToggle ? "1" : "0", IniPath, "DriverAssistant", "DA_EnterVehicleOnToggle")
    IniWrite(DriverAssistantShowInList ? "1" : "0", IniPath, "DriverAssistant", "ShowInList")
}

; Load settings from INI
LoadDriverAssistantSettings() {
    global IniPath, ToggleDriverHotkey, ToggleDriverHotkeyWildcard
    global DA_Forward_Key, DA_Backward_Key, DA_Exit_Key, DA_Swap_Key, DA_GearUp_Key, DA_GearDown_Key
    global DA_StratagemCallEnabled, DA_ForwardGearMode, DA_EnhancedGearSwitch
    global DA_Handbrake_Key, DA_HandbrakeOnExit, DA_KeyPressDelay
    global DA_EnterVehicleKey, DA_EnterVehicleOnToggle
    global DriverAssistantShowInList
    
    try {
        ToggleDriverHotkey := IniRead(IniPath, "DriverAssistant", "ToggleHotkey", "")
        ToggleDriverHotkeyWildcard := IniRead(IniPath, "DriverAssistant", "ToggleHotkeyWildcard", "0") = "1" ? true : false
        DA_Forward_Key := IniRead(IniPath, "DriverAssistant", "DA_Forward_Key", "w")
        DA_Backward_Key := IniRead(IniPath, "DriverAssistant", "DA_Backward_Key", "s")
        DA_Exit_Key := IniRead(IniPath, "DriverAssistant", "DA_Exit_Key", "e")
        DA_Swap_Key := IniRead(IniPath, "DriverAssistant", "DA_Swap_Key", "c")
        DA_GearUp_Key := IniRead(IniPath, "DriverAssistant", "DA_GearUp_Key", "Shift")
        DA_GearDown_Key := IniRead(IniPath, "DriverAssistant", "DA_GearDown_Key", "Ctrl")
        DA_StratagemCallEnabled := IniRead(IniPath, "DriverAssistant", "DA_StratagemCallEnabled", "0") = "1" ? true : false
        DA_ForwardGearMode := Integer(IniRead(IniPath, "DriverAssistant", "DA_ForwardGearMode", "1"))
        DA_EnhancedGearSwitch := IniRead(IniPath, "DriverAssistant", "DA_EnhancedGearSwitch", "0") = "1" ? true : false
        DA_Handbrake_Key := IniRead(IniPath, "DriverAssistant", "DA_Handbrake_Key", "Space")
        DA_HandbrakeOnExit := IniRead(IniPath, "DriverAssistant", "DA_HandbrakeOnExit", "0") = "1" ? true : false
        DA_KeyPressDelay := Integer(IniRead(IniPath, "DriverAssistant", "DA_KeyPressDelay", "25"))
        DA_EnterVehicleKey := IniRead(IniPath, "DriverAssistant", "DA_EnterVehicleKey", "e")
        DA_EnterVehicleOnToggle := IniRead(IniPath, "DriverAssistant", "DA_EnterVehicleOnToggle", "0") = "1" ? true : false
        DriverAssistantShowInList := IniRead(IniPath, "DriverAssistant", "ShowInList", "1") = "1" ? true : false
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
global IM_InventoryKey := "x"
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
        imStatusText.Value := Lang.Get("status_on")
        imStatusText.Opt("c00FF00")
    } else {
        imStatusText.Value := Lang.Get("status_off")
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
            imStatusText.Value := Lang.Get("status_on")
            imStatusText.Opt("c00FF00")
        } else {
            imStatusText.Value := Lang.Get("status_off")
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
    global InventoryManagerActive, ScriptSuspended, IM_SleepDelay, IM_SleepDelay2, IM_InventoryKey
    
    if (!InventoryManagerActive || ScriptSuspended)
        return
    
    ; Drop Backpack (up-left)
    Send("{" IM_InventoryKey " down}")
    Sleep(IM_SleepDelay)
    PerformIMMouseMove(-300, -300)
    Sleep(IM_SleepDelay2)
    Send("{" IM_InventoryKey " up}")
}

IMButton2Func(*) {
    global InventoryManagerActive, ScriptSuspended, IM_SleepDelay, IM_SleepDelay2, IM_InventoryKey
    
    if (!InventoryManagerActive || ScriptSuspended)
        return
    
    ; Drop Weapon (up-right)
    Send("{" IM_InventoryKey " down}")
    Sleep(IM_SleepDelay)
    PerformIMMouseMove(300, -300)
    Sleep(IM_SleepDelay2)
    Send("{" IM_InventoryKey " up}")
}

IMButton3Func(*) {
    global InventoryManagerActive, ScriptSuspended, IM_SleepDelay, IM_SleepDelay2, IM_InventoryKey
    
    if (!InventoryManagerActive || ScriptSuspended)
        return
    
    ; Drop Suitcase (down-left)
    Send("{" IM_InventoryKey " down}")
    Sleep(IM_SleepDelay)
    PerformIMMouseMove(-300, 300)
    Sleep(IM_SleepDelay2)
    Send("{" IM_InventoryKey " up}")
}

IMButton4Func(*) {
    global InventoryManagerActive, ScriptSuspended, IM_SleepDelay, IM_SleepDelay2, IM_InventoryKey
    
    if (!InventoryManagerActive || ScriptSuspended)
        return
    
    ; Drop Samples (down-right)
    Send("{" IM_InventoryKey " down}")
    Sleep(IM_SleepDelay)
    PerformIMMouseMove(300, 300)
    Sleep(IM_SleepDelay2)
    Send("{" IM_InventoryKey " up}")
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
    global IM_InventoryKey, IM_SleepDelay, IM_SleepDelay2
    
    ; Switch to English keyboard layout when opening popup
    SwitchToEnglishLayout()
    
    ; Destroy existing settings GUI if it exists
    if (IsSet(imSettingsGui) && imSettingsGui) {
        try imSettingsGui.Destroy()
    }
    
    imSettingsGui := Gui("+Owner" . settingsGui.Hwnd, Lang.Get("inventory_manager_title"))
    imSettingsGui.BackColor := "202020"
    imSettingsGui.SetFont("s10 cC4C4C4", "Segoe UI")
    imSettingsGui.MarginX := Scale(10)
    imSettingsGui.MarginY := Scale(10)
    
    ; ===== Column: Drop Weapon, Drop Samples =====
    ; Drop Weapon (up-right)
    imSettingsGui.Add("Text", "x" Scale(160) " y" Scale(15) " w" Scale(140), Lang.Get("drop_weapon"))
    global imInput2 := HotkeyInput(imSettingsGui, 160, 0, "", {value: IM_Button2Hotkey, wildcard: IM_Button2Wildcard, hasWildcard: true})
    
    ; Drop Samples (down-right)
    imSettingsGui.Add("Text", "x" Scale(160) " y+" Scale(15) " w" Scale(140), Lang.Get("drop_samples"))
    global imInput4 := HotkeyInput(imSettingsGui, 160, 0, "", {value: IM_Button4Hotkey, wildcard: IM_Button4Wildcard, hasWildcard: true})

    ; ===== Column: Drop Backpack, Drop Suitcase, Drop key =====
    ; Drop Backpack (up-left)
    imSettingsGui.Add("Text", "x" Scale(10) " y" Scale(15) " w" Scale(140), Lang.Get("drop_backpack"))
    global imInput1 := HotkeyInput(imSettingsGui, 10, 0, "", {value: IM_Button1Hotkey, wildcard: IM_Button1Wildcard, hasWildcard: true})
    
    ; Drop Suitcase (down-left)
    imSettingsGui.Add("Text", "x" Scale(10) " y+" Scale(15) " w" Scale(140), Lang.Get("drop_suitcase"))
    global imInput3 := HotkeyInput(imSettingsGui, 10, 0, "", {value: IM_Button3Hotkey, wildcard: IM_Button3Wildcard, hasWildcard: true})
    
    ; Inventory Key
    imSettingsGui.Add("Text", "x" Scale(10) " y+" Scale(15) " w" Scale(140), Lang.Get("inventory_key"))
    global imInventoryKeyInput := HotkeyInput(imSettingsGui, 10, 0, "", {value: IM_InventoryKey, hasWildcard: false})
    
    ; Delay inputs
    imSettingsGui.Add("Text", "x" Scale(10) " y+" Scale(10) " w" Scale(200) " cGray", Lang.Get("timings_ms"))
    imSettingsGui.Add("Text", "x" Scale(10) " y+" Scale(5) " w" Scale(80), Lang.Get("hold_key"))
    global imSleepDelayEdit := imSettingsGui.Add("Edit", "x+" Scale(5) " yp-3 w" Scale(40) " Background2f2f2f Number", IM_SleepDelay)
    
    imSettingsGui.Add("Text", "x" Scale(10) " y+" Scale(5) " w" Scale(80), Lang.Get("release_key"))
    global imSleepDelay2Edit := imSettingsGui.Add("Edit", "x+" Scale(5) " yp-3 w" Scale(40) " Background2f2f2f Number", IM_SleepDelay2)
    
    ; Sensitivity multiplier
    imSettingsGui.Add("Text", "x" Scale(10) " y+" Scale(10) " w" Scale(200) " cGray", Lang.Get("mouse_sensitivity"))
    imSettingsGui.Add("Text", "x" Scale(10) " y+" Scale(5) " w" Scale(80), Lang.Get("multiplier"))
    global imSensitivityEdit := imSettingsGui.Add("Edit", "x+" Scale(5) " yp-3 w" Scale(40) " Background2f2f2f", IM_SensitivityMultiplier)
    
    ; Save button
    btnIMSave := imSettingsGui.Add("Button", "x" Scale(10) " y+" Scale(25) " w" Scale(280) " h" Scale(30) " Default", Lang.Get("save_settings"))
    btnIMSave.OnEvent("Click", SaveInventoryManagerSettingsPopup)
    
    imSettingsGui.OnEvent("Escape", (*) => imSettingsGui.Destroy())
    imSettingsGui.Show("w" Scale(300))
}

; Save from popup
SaveInventoryManagerSettingsPopup(*) {
    global imSettingsGui, IniPath
    global IM_Button1Hotkey, IM_Button2Hotkey, IM_Button3Hotkey, IM_Button4Hotkey
    global IM_Button1Wildcard, IM_Button2Wildcard, IM_Button3Wildcard, IM_Button4Wildcard
    global IM_InventoryKey, IM_SleepDelay, IM_SleepDelay2, IM_SensitivityMultiplier
    
    ; Read values from GUI controls
    IM_Button1Hotkey := imInput1.GetValue()
    IM_Button1Wildcard := imInput1.GetWildcard()
    IM_Button2Hotkey := imInput2.GetValue()
    IM_Button2Wildcard := imInput2.GetWildcard()
    IM_Button3Hotkey := imInput3.GetValue()
    IM_Button3Wildcard := imInput3.GetWildcard()
    IM_Button4Hotkey := imInput4.GetValue()
    IM_Button4Wildcard := imInput4.GetWildcard()
    IM_InventoryKey := imInventoryKeyInput.GetValue() != "" ? imInventoryKeyInput.GetValue() : "x"
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
    global IM_InventoryKey, IM_SleepDelay, IM_SleepDelay2, IM_SensitivityMultiplier
    
    IniWrite(IM_Button1Hotkey, IniPath, "InventoryManager", "Button1Hotkey")
    IniWrite(IM_InventoryKey, IniPath, "InventoryManager", "InventoryKey")
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
    global IM_InventoryKey, IM_SleepDelay, IM_SleepDelay2, IM_SensitivityMultiplier
    
    try {
        InventoryManagerActive := IniRead(IniPath, "InventoryManager", "Active", "0") = "1" ? true : false
        IM_InventoryKey := IniRead(IniPath, "InventoryManager", "InventoryKey", "x")
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
        qsStatusText.Value := Lang.Get("status_on")
        qsStatusText.Opt("c00FF00")
    } else {
        qsStatusText.Value := Lang.Get("status_off")
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
            qsStatusText.Value := Lang.Get("status_on")
            qsStatusText.Opt("c00FF00")
        } else {
            qsStatusText.Value := Lang.Get("status_off")
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
    
    qsSettingsGui := Gui("+Owner" . settingsGui.Hwnd, Lang.Get("weapon_swap_title"))
    qsSettingsGui.BackColor := "202020"
    qsSettingsGui.SetFont("s10 cC4C4C4", "Segoe UI")
    qsSettingsGui.MarginX := Scale(10)
    qsSettingsGui.MarginY := Scale(10)
    
    ; Slot tracking - each slot has a checkbox and a hotkey input
    qsSettingsGui.Add("Text", "x" Scale(10) " y" Scale(15) " w" Scale(250), Lang.Get("track_weapon_slots"))
    
    ; ===== Column: Slot 2, Slot 4 =====
    global qsSlot2Cb := qsSettingsGui.Add("CheckBox", "x" Scale(150) " y+5 vQSSlot2 Section", Lang.Get("slot_label") . " 2:")
    qsSlot2Cb.Value := QS_Slot2
    global qsSlot2KeyInput := HotkeyInput(qsSettingsGui, 150, 0, "", {value: QS_Slot2Key, hasWildcard: false})
    
    global qsSlot4Cb := qsSettingsGui.Add("CheckBox", "x" Scale(150) " y+" Scale(10) " vQSSlot4", Lang.Get("slot_label") . " 4:")
    qsSlot4Cb.Value := QS_Slot4
    global qsSlot4KeyInput := HotkeyInput(qsSettingsGui, 150, 0, "", {value: QS_Slot4Key, hasWildcard: false})

    ; ===== Column: Slot 1, Slot 3, Switch hotkey =====
    global qsSlot1Cb := qsSettingsGui.Add("CheckBox", "x" Scale(10) " ys vQSSlot1", Lang.Get("slot_label") . " 1:")
    qsSlot1Cb.Value := QS_Slot1
    global qsSlot1KeyInput := HotkeyInput(qsSettingsGui, 10, 0, "", {value: QS_Slot1Key, hasWildcard: false})
    
    global qsSlot3Cb := qsSettingsGui.Add("CheckBox", "x" Scale(10) " y+" Scale(10) " vQSSlot3", Lang.Get("slot_label") . " 3:")
    qsSlot3Cb.Value := QS_Slot3
    global qsSlot3KeyInput := HotkeyInput(qsSettingsGui, 10, 0, "", {value: QS_Slot3Key, hasWildcard: false})
    
    ; Switch hotkey
    qsSettingsGui.Add("Text", "x" Scale(10) " y+" Scale(15) " w" Scale(140), Lang.Get("quick_switch_key"))
    global qsHotkeyInput := HotkeyInput(qsSettingsGui, 10, 0, "", {value: QS_Hotkey, wildcard: QS_Wildcard, hasWildcard: true})
    
    ; Info text
    qsSettingsGui.Add("Text", "x" Scale(10) " y+" Scale(15) " w" Scale(250) " cGray", Lang.Get("switch_info"))
    
    ; Save button
    btnQSSave := qsSettingsGui.Add("Button", "x" Scale(10) " y+" Scale(15) " w" Scale(280) " h" Scale(30) " Default", Lang.Get("save_settings"))
    btnQSSave.OnEvent("Click", SaveWeaponQuickSwitchSettingsPopup)
    
    qsSettingsGui.OnEvent("Escape", (*) => qsSettingsGui.Destroy())
    qsSettingsGui.Show("w" Scale(300))
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
