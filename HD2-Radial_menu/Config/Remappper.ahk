; Remappper.ahk - Remap Master module for HD2 Radial Menu

; --- Path settings ---
global RemapIniFile := A_ScriptDir "\Config\remapper.ini"
global RemapFile    := A_ScriptDir "\Config\MyRemap.ahk"

; Live remap state shared with the generated hotkeys (#HotIf RemapActiveState)
global RemapActiveState := (IniRead(RemapIniFile, "Remap", "Active", "0") = "1")

; Popup control references (created on demand by ShowRemapMasterPopup)
global remapPopupGui := 0
global remapPopupModInput := 0
global remapPopupBehaviorDDL := 0
global remapPopupInKeys := []
global remapPopupOutKeys := []
global remapPopupToggle := 0
global remapPopupStatus := 0

; Create the remap file if it does not exist yet, so it is always present
if !FileExist(RemapFile)
    FileAppend("", RemapFile, "UTF-16")

; --- MAIN GUI BUTTON HELPERS ---

; Updates the REMAP ON/OFF button on the main settings GUI
UpdateRemapButton() {
    global RemapActiveState, remapToggleBtn
    if (!IsSet(remapToggleBtn) || !remapToggleBtn)
        return
    remapToggleBtn.Text := RemapActiveState ? "REMAP: ON" : "REMAP: OFF"
    try remapToggleBtn.Opt("Background" (RemapActiveState ? "Green" : "Red"))
    try remapToggleBtn.SetFont("cWhite s" Scale(9) " Bold")
}

; Toggles the remap state from the main GUI button
Remap_ToggleFromMain(*) {
    global RemapActiveState
    RemapActiveState := !RemapActiveState
    IniWrite(RemapActiveState ? "1" : "0", RemapIniFile, "Remap", "Active")
    UpdateRemapButton()
    Remap_UpdatePopupState()
}

; --- POPUP STATE HELPERS ---

; Keeps the Remap Master popup controls in sync with the current state
Remap_UpdatePopupState() {
    global RemapActiveState, remapPopupGui, remapPopupToggle, remapPopupStatus
    ; Skip if the popup is not open (references are cleared on close)
    if (!IsSet(remapPopupGui) || !remapPopupGui)
        return
    try {
        remapPopupToggle.Text := RemapActiveState ? "REMAP: ON" : "REMAP: OFF"
        remapPopupToggle.Opt("Background" (RemapActiveState ? "Green" : "Red"))
        remapPopupToggle.SetFont("cWhite s" Scale(10) " Bold")
    }
    try {
        remapPopupStatus.Text := RemapActiveState ? "Status: Active" : "Status: Inactive"
        remapPopupStatus.SetFont("c" (RemapActiveState ? "Green" : "Red"))
    }
}

; Destroys the Remap Master popup and clears all control references
Remap_ClosePopup(*) {
    global remapPopupGui, remapPopupModInput, remapPopupBehaviorDDL
    global remapPopupInKeys, remapPopupOutKeys, remapPopupToggle, remapPopupStatus
    if (IsSet(remapPopupGui) && remapPopupGui) {
        try remapPopupGui.Destroy()
    }
    remapPopupGui := 0
    remapPopupModInput := 0
    remapPopupBehaviorDDL := 0
    remapPopupInKeys := []
    remapPopupOutKeys := []
    remapPopupToggle := 0
    remapPopupStatus := 0
}

; Toggles the remap state from the popup
Remap_ToggleFromPopup(*) {
    global RemapActiveState
    RemapActiveState := !RemapActiveState
    IniWrite(RemapActiveState ? "1" : "0", RemapIniFile, "Remap", "Active")
    UpdateRemapButton()
    Remap_UpdatePopupState()
}

; --- REMAP MASTER POPUP ---
ShowRemapMasterPopup(*) {
    global RemapIniFile, RemapFile, RemapActiveState
    global remapPopupGui, remapPopupModInput, remapPopupBehaviorDDL
    global remapPopupInKeys, remapPopupOutKeys, remapPopupToggle, remapPopupStatus

    ; Create the remap file if it does not exist yet
    if !FileExist(RemapFile)
        FileAppend("", RemapFile, "UTF-16")

    ; Only one popup instance at a time
    if (remapPopupGui) {
        Remap_ClosePopup()
    }

    rGui := Gui("-Caption +AlwaysOnTop +ToolWindow", "Remap Master")
    rGui.BackColor := "202020"
    rGui.SetFont("s" Scale(10) " cC4C4C4", "Segoe UI")
    rGui.MarginX := Scale(5)
    rGui.MarginY := Scale(5)
    rGui.OnEvent("Escape", Remap_ClosePopup)
    rGui.OnEvent("Close", Remap_ClosePopup)

    ; Custom title bar
    rGui.SetFont("cFFFFFF s" Scale(12))
    rGui.Add("Text", "x0 y0 w" Scale(200) " h" Scale(35) " Background2A2A2A Border +Center", "Remap Master").OnEvent("Click", (*) => PostMessage(0xA1, 2,,, "A"))
    rGui.Add("Button", "x+" Scale(5) " y0 w" Scale(35) " h" Scale(35), "X").OnEvent("Click", Remap_ClosePopup)
    rGui.SetFont("s" Scale(10) " cC4C4C4")

    ; Modifier key group
    rGui.Add("GroupBox", "x" Scale(10) " y" Scale(45) " w" Scale(230) " h" Scale(110), "Modifier key")
    SavedMod := IniRead(RemapIniFile, "Remap", "Modifier", "LControl")
    remapPopupModInput := HotkeyInput(rGui, 20, 68, "", {value: SavedMod, hasWildcard: false})

    ; Modifier behavior: Hold = active while held, Toggle = press to switch on/off
    SavedBehavior := IniRead(RemapIniFile, "Remap", "ModifierBehavior", "Hold")
    remapPopupBehaviorDDL := rGui.Add("DropDownList", "w" Scale(100) " x" Scale(20) " y+3 Background2f2f2f", ["Hold", "Toggle"])
    remapPopupBehaviorDDL.Choose(SavedBehavior = "Toggle" ? 2 : 1)

    ; Key remapping group
    rGui.Add("GroupBox", "x" Scale(10) " y+" Scale(20) " w" Scale(230) " h" Scale(150), "Key remapping")
    remapPopupInKeys := []
    remapPopupOutKeys := []
    Loop 4 {
        yPos := (A_Index = 1) ? "yp+" Scale(25) : "yp+" Scale(30)
        defIn := (A_Index = 1 ? "w" : A_Index = 2 ? "a" : A_Index = 3 ? "s" : "d")
        defOut := (A_Index = 1 ? "Up" : A_Index = 2 ? "Left" : A_Index = 3 ? "Down" : "Right")

        valIn := IniRead(RemapIniFile, "Remap Keys", "In" A_Index, defIn)
        valOut := IniRead(RemapIniFile, "Remap Keys", "Out" A_Index, defOut)

        ; Switch to English keyboard layout when editing the remap fields
        inCtrl := rGui.Add("Hotkey", "x" Scale(20) " " yPos " w" Scale(90), valIn)
        inCtrl.OnEvent("Change", (*) => SwitchToEnglishLayout())
        remapPopupInKeys.Push(inCtrl)

        outCtrl := rGui.Add("Hotkey", "x+" Scale(20) " w" Scale(90), valOut)
        outCtrl.OnEvent("Change", (*) => SwitchToEnglishLayout())
        remapPopupOutKeys.Push(outCtrl)
    }

    ; Apply and Reload
    btnSave := rGui.Add("Button", "x" Scale(10) " y+" Scale(20) " w" Scale(230) " h" Scale(40) " Default", "APPLY AND RELOAD")
    btnSave.OnEvent("Click", Remap_ApplyAndReload)

    ; Toggle button (clickable Text)
    remapPopupToggle := rGui.Add("Text", "x" Scale(65) " y+" Scale(10) " w" Scale(120) " h" Scale(24) " Center Border", "REMAP: OFF")
    remapPopupToggle.OnEvent("Click", Remap_ToggleFromPopup)

    ; Status text
    remapPopupStatus := rGui.Add("Text", "x" Scale(10) " y+" Scale(10) " w" Scale(230), "")

    remapPopupGui := rGui
    Remap_UpdatePopupState()
    rGui.Show("AutoSize")
}

; --- APPLY AND RELOAD ---
Remap_ApplyAndReload(*) {
    global RemapIniFile, RemapFile
    global remapPopupModInput, remapPopupBehaviorDDL, remapPopupInKeys, remapPopupOutKeys

    ; 1. Save to INI
    IniWrite(remapPopupModInput.GetValue(), RemapIniFile, "Remap", "Modifier")
    IniWrite(remapPopupBehaviorDDL.Text, RemapIniFile, "Remap", "ModifierBehavior")
    Loop 4 {
        IniWrite(remapPopupInKeys[A_Index].Value, RemapIniFile, "Remap Keys", "In" A_Index)
        IniWrite(remapPopupOutKeys[A_Index].Value, RemapIniFile, "Remap Keys", "Out" A_Index)
    }

    ; 2. Generate code to the external file.
    ; Note: the generated code references the global RemapActiveState variable
    modKey := remapPopupModInput.GetValue()
    Code := "; Generated remap file`n"
    if (remapPopupBehaviorDDL.Text = "Toggle" && modKey != "") {
        ; Toggle mode: press the modifier key to switch the remap on/off
        Code .= "Global RemapToggle := false`n`n"
        Code .= "#HotIf RemapActiveState`n"
        Code .= "*" modKey ":: {`n"
        Code .= "    global RemapToggle`n"
        Code .= "    RemapToggle := !RemapToggle`n"
        Code .= "    ToolTip(RemapToggle ? 'Remap ON' : 'Remap OFF', 5, 5)`n"
        Code .= "    SetTimer(() => ToolTip(), -1000)`n"
        Code .= "}`n"
        Code .= "#HotIf`n`n"
        Code .= "#HotIf RemapActiveState && RemapToggle`n"
    } else if (modKey != "") {
        Code .= "#HotIf RemapActiveState && GetKeyState('" modKey "', 'P')`n"
    } else {
        Code .= "#HotIf RemapActiveState`n"
    }

    Loop 4 {
        IK := remapPopupInKeys[A_Index].Value
        OK := remapPopupOutKeys[A_Index].Value
        if (IK != "" && OK != "")
            Code .= IK "::" OK "`n"
    }
    Code .= "#HotIf"

    try FileDelete(RemapFile)
    FileAppend(Code, RemapFile, "UTF-16")

    ; 3. Reload the main script to re-apply the generated #Include
    Reload()
}

; --- INCLUDE GENERATED FILE ---
#Include *i MyRemap.ahk