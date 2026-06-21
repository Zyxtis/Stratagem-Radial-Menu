#Requires AutoHotkey v2.0
#Include Config\config.ahk
#Include Config\gamepad.ahk
#Include Config\OCR_GDI.ahk
#Include Config\assistants.ahk

; Load GUI Scale from settings.ini
LoadGUIScale()
OnExit(ExitRoutine)
OnError(ErrorHandler)

; ===GLOBAL VARIABLES===
; Input Settings
global StratagemMenuKey := "LControl", RadialMenuKey := "MButton", PostMenuDelay := 25, RealKeyDelay := 25, InputLayout := "Arrows"
global CustomUpKey := "w", CustomDownKey := "s", CustomLeftKey := "a", CustomRightKey := "d"
global MenuInputType := 5  ; 1=Tap, 2=Double Tap, 3=Press, 4=Long Press, 5=Hold
global SuspendHotkey := "Insert", ExitHotkey := "End", DisplayToggleHotkey := "F1"
global RadialMenuKeyWildcard := false
global RadialMenuKeyMode := "Hold"  ; "Hold" or "Toggle"

; Radial Menu UI
global MenuSize := 500, InnerRadius := 70, IconSize := 48, TextSize := 9, ShowText := true
global ScreenCX := A_ScreenWidth // 2, ScreenCY := A_ScreenHeight // 2

; State Tracking
global IsMenuVisible := false, SelectedSector := 0, IsExecutingMacro := false
global IniPath := A_ScriptDir "\Config\settings.ini", radialGui := 0
global ProfilesIniPath := A_ScriptDir "\Config\profiles.ini"
global OCRProfileIniPath := A_ScriptDir "\Config\ocr.ini"

; Game Check
global AutoPauseActive := false, AutoCloseActive := false, AutoCloseCountdownActive := false
global GameCheckTimerInterval := 500, GameTarget := "HELLDIVERS™ 2", GameProcessName := "helldivers2.exe"
global ScriptSuspended := false, IsAutoPaused := false, StatusText := 0

; Auto Language Switch
global AutoLanguageSwitch := false  ; Toggle for automatic language switch to English (off by default)
global AutoLanguageLayout := "00000409"  ; Keyboard layout code for automatic switch
global EnglishLayouts := Map(
    "00000409", "English (US)",
    "00000809", "English (UK)",
    "00001009", "English (Canada)",
    "00001809", "English (Ireland)",
    "00001409", "English (New Zealand)",
    "00004009", "English (India)",
    "00010407", "German (IBM)",
    "0000040c", "French (AZERTY)"
)
global EnglishLayoutCodes := ["00000409", "00000809", "00001009", "00001809", "00001409", "00004009", "00010407", "0000040c"]
global EnglishLayoutNames := ["English (US)", "English (UK)", "English (Canada)", "English (Ireland)", "English (New Zealand)", "English (India)", "German (IBM)", "French (AZERTY)"]

; Camera Bypass
global BlockCameraBypass := false, OpenMapKey := "Tab", MapInputType := 1, CameraBypassActive := false

; Profiles
global ActiveProfile := "Default", DefaultProfile := "Default", ProfileDDL := 0
global ProfileNextHotkey := "PgUp", ProfilePrevHotkey := "PgDn"
global ProfileNextHotkeyWildcard := false, ProfilePrevHotkeyWildcard := false
global ActiveStratagems := []

; Favorites
global FavoriteStratagems := Map(), ShowFavoritesOnly := false

; Keybinds
global StratagemKeybinds := Map()
global ActiveKeybindProfile := "Default"
global ActiveKeybindStratagems := []
global KeybindListVisibility := Map()

; Alt Keys for DropDownList
AltKeys := ["LControl", "RControl", "LShift", "RShift", "LAlt", "RAlt", "LWin", "RWin", "Tab", "XButton1", "XButton2", "MButton", "LButton", "RButton", "WheelUp", "WheelDown"]
AltChoiceList := ["[Input]"]
for key in AltKeys
    AltChoiceList.Push(key)

; Keybind List Overlay settings
global KeybindListHotkey := "F2"
global KeybindListTransparency := 200
global KeybindListGui := 0
global KeybindListHotkeyWildcard := false
global KeybindListDragDelay := 300
global KeybindListShowIcon := true
global KeybindListShowHotkey := true
global KeybindListShowName := true

; OCR
global OCRHotkey := "F3"
global OCRHotkeyWildcard := false
global OCRBypassToggleHotkey := "F4"
global OCRBypassToggleHotkeyWildcard := false
global OCRScramblerBypassEnabled := false
global ScramblerRadialMode := false
global OCRUseHold := false
global OCRHoldMs := 700

; Scrambler Bypass Settings
global BypassGamepadButton := ""
global BypassUseHold := false
global BypassHoldMs := 700

; Driver Stratagem Call state tracking for scrambler bypass
global scramblerDidSwap := false

; ===INITIALIZATION===
StripWildcard(hotkey) {
    if (SubStr(hotkey, 1, 1) = "*" || SubStr(hotkey, 1, 1) = "~")
        return SubStr(hotkey, 2)
    return hotkey
}

SetAltChoice(hotkeyValue, controlName) {
    hotkeyValue := StripWildcard(hotkeyValue)
    for i, key_name in AltChoiceList {
        if (key_name = hotkeyValue) {
            controlName.Choose(i)
            return
        }
    }
    controlName.Choose(1)
}

; Switch to English keyboard layout
SwitchToEnglishLayout() {
    global AutoLanguageSwitch, AutoLanguageLayout
    ; Only switch layout if automatic language switching is enabled
    if (!AutoLanguageSwitch)
        return
    ; Load and activate the selected English keyboard layout
    ; KLF_ACTIVATE = 1 - activates the layout for the current thread
    DllCall("LoadKeyboardLayout", "Str", AutoLanguageLayout, "UInt", 1, "Ptr")
}

; ===UNIVERSAL HOTKEY INPUT CLASS===
; Creates a hotkey input with dropdown and optional wildcard checkbox
class HotkeyInput {
    __New(gui, x, y, options := "", config := {}) {
        ; Switch to English keyboard layout when creating hotkey input
        SwitchToEnglishLayout()
        ; config fields: value, wildcard, hasWildcard, onChanged, onWildcardChanged, excludeKeys
        this.value := config.HasOwnProp("value") ? config.value : ""
        this.wildcard := config.HasOwnProp("wildcard") ? config.wildcard : false
        this.hasWildcard := config.HasOwnProp("hasWildcard") ? config.hasWildcard : true
        this.onChanged := config.HasOwnProp("onChanged") ? config.onChanged : ""
        this.onWildcardChanged := config.HasOwnProp("onWildcardChanged") ? config.onWildcardChanged : ""
        this.excludeKeys := config.HasOwnProp("excludeKeys") ? config.excludeKeys : []
        this.controls := {}
        
        ; Build position string - if y is 0, use relative positioning from previous control
        if (y = 0) {
            posDDL := "w" . Scale(100) . " x" . Scale(x) . " y+5 Background2f2f2f"
        } else {
            posDDL := "w" . Scale(100) . " x" . Scale(x) . " y" . Scale(y) . " Background2f2f2f"
        }
        
        ; Dropdown for predefined keys - filter out excluded keys
        filteredList := AltChoiceList.Clone()
        if (this.excludeKeys.Length > 0) {
            newFilteredList := []
            for item in filteredList {
                isExcluded := false
                for excludeKey in this.excludeKeys {
                    if (item = excludeKey) {
                        isExcluded := true
                        break
                    }
                }
                if !isExcluded
                    newFilteredList.Push(item)
            }
            filteredList := newFilteredList
        }
        this.controls.ddl := gui.Add("DropDownList", posDDL, filteredList)
        this.controls.ddl.OnEvent("Change", this.OnDDLChange.Bind(this))
        
        ; Wildcard checkbox (optional)
        if (this.hasWildcard) {
            this.controls.wildcardCb := gui.Add("CheckBox", "x+5 yp", "*")
            this.controls.wildcardCb.Value := this.wildcard
            this.controls.wildcardCb.OnEvent("Click", this.OnWildcardClick.Bind(this))
        }
        
        ; Hotkey input field - smaller gap if no wildcard checkbox
        hotkeyGap := this.hasWildcard ? 10 : 2
        this.controls.hotkey := gui.Add("Hotkey", "w" . Scale(100) . " x" . Scale(x) . " y+" . Scale(hotkeyGap), this.value)
        this.controls.hotkey.OnEvent("Change", this.OnHotkeyChange.Bind(this))
        
        ; Set initial DDL value
        SetAltChoice(this.value, this.controls.ddl)
    }
    
    OnDDLChange(*) {
        if (this.controls.ddl.Value != 1) {
            this.controls.hotkey.Value := ""
        }
        this.SyncValue()
    }
    
    OnHotkeyChange(*) {
        ; Switch to English keyboard layout when editing hotkey
        SwitchToEnglishLayout()
        hotkeyVal := this.controls.hotkey.Value
        if (hotkeyVal != "") {
            if RegExMatch(hotkeyVal, "[\^!+#]") {
                baseKey := RegExReplace(hotkeyVal, "[\^!+#]", "")
                this.controls.hotkey.Value := baseKey
            }
            this.controls.ddl.Choose(1)
        }
        this.SyncValue()
    }
    
    OnWildcardClick(*) {
        this.wildcard := this.controls.wildcardCb.Value
        if (this.onWildcardChanged != "")
            this.onWildcardChanged.Call()
    }
    
    SyncValue() {
        if (this.controls.ddl.Value != 1) {
            this.value := AltChoiceList[this.controls.ddl.Value]
        } else {
            this.value := this.controls.hotkey.Value
        }
        if (this.onChanged != "")
            this.onChanged.Call()
    }
    
    GetValue() => this.value
    GetWildcard() => this.wildcard
    
    SetValue(val) {
        this.value := val
        this.controls.hotkey.Value := val
        SetAltChoice(val, this.controls.ddl)
    }
    
    SetWildcard(val) {
        this.wildcard := val
        if (this.hasWildcard)
            this.controls.wildcardCb.Value := val
    }
}

LoadStratagemsData()
LoadSettings()
LoadWeaponAssistantSettings()
LoadDriverAssistantSettings()
LoadInventoryManagerSettings()
LoadWeaponQuickSwitchSettings()
LoadFavorites()
LoadGamepadSettings()

; Load keybind profile on startup (before GUI creation)
try {
    ActiveKeybindProfile := IniRead(IniPath, "Settings", "ActiveKeybindProfile", "Default")
} catch {
    ActiveKeybindProfile := "Default"
}

; ImageList for Icons - use shared function from config.ahk
global BitmapCache := Map()
IL_ID := InitIconImageList()
iconSizeScaled := Scale(32)

; ===MAIN GUI===
settingsGui := Gui("-Caption +LastFound", "Stratagem Radial Menu")
settingsGui.BackColor := "202020"
baseFontSize := Scale(10)
settingsGui.SetFont("s" baseFontSize " cC4C4C4", "Segoe UI")
settingsGui.MarginX := Scale(5)
settingsGui.MarginY := Scale(5)

; Custom Title Bar with Status Indicator
titleFontSize := Scale(12)
settingsGui.SetFont("cFFFFFF s" titleFontSize)
StatusText := settingsGui.Add("Text", "x0 y0 w" Scale(30) " h" Scale(30) " Background2A2A2A Border +Center c00FF00", "●")
StatusText.OnEvent("Click", ToggleSuspend)
settingsGui.Add("Text", "x+0 y0 w" Scale(315) " h" Scale(30) " Background2A2A2A Border +Center", "Stratagem Radial Menu").OnEvent("Click", StartMove)
settingsGui.Add("Button", "x+5 y0 w" Scale(30) " h" Scale(30), "—").OnEvent("Click", (*) => settingsGui.Hide())
settingsGui.Add("Button", "x+5 y0 w" Scale(30) " h" Scale(30), "X").OnEvent("Click", (*) => ExitApp())
settingsGui.SetFont("s" baseFontSize " cC4C4C4")

mainTab := settingsGui.Add("Tab2", "x" Scale(10) " y" Scale(35) " w" Scale(400) " h" Scale(640), ["Radial Menu", "Keybinds", "Settings", "Misc"])
mainTab.OnEvent("Change", ClearTabFocus)

; ---Tab 1: Radial Menu---
mainTab.UseTab(1)

; Profile Section
settingsGui.Add("Text", "x" Scale(25) " y" Scale(65) " w" Scale(200), "📂 Profile:")
ProfileDDL := settingsGui.Add("DropDownList", "x" Scale(25) " y+" Scale(5) " w" Scale(370) " vProfileDDL Background2f2f2f", GetProfilesList("radial"))
ProfileDDL.OnEvent("Change", SwitchProfileDDLHandler)
SetProfileDDL("radial")

btnNewProf := settingsGui.Add("Button", "w" Scale(180) " h" Scale(30) " x" Scale(25) " y+" Scale(5), "➕ New Profile")
btnNewProf.OnEvent("Click", CreateRadialProfileHandler)

btnDelProf := settingsGui.Add("Button", "w" Scale(180) " h" Scale(30) " x+" Scale(10) " yp", "❌ Delete Profile")
btnDelProf.OnEvent("Click", DeleteRadialProfileHandler)

; Active Stratagems Section and ListView
settingsGui.Add("Text", "x" Scale(25) " y+" Scale(15) " w" Scale(200), "Active Stratagems:")

lbActive := settingsGui.Add("ListView", "x" Scale(25) " y+" Scale(5) " r12 w" Scale(370) " h" Scale(380) " vActiveList Multi Background000000", ["Icon", "Name", "Category"])
lbActive.SetImageList(IL_ID, 1)
lbActive.ModifyCol(1, iconSizeScaled + Scale(4))  ; Icon column width = icon size + small padding
lbActive.ModifyCol(2, Scale(210))
lbActive.ModifyCol(3, Scale(80))
UpdateActiveList()

btnAdd := settingsGui.Add("Button", "w" Scale(40) " h" Scale(30) " x" Scale(25) " y+" Scale(10), "+")
btnAdd.OnEvent("Click", (*) => ShowSelectionGui())

btnRem := settingsGui.Add("Button", "w" Scale(40) " h" Scale(30) " x+" Scale(5) " yp", "-")
btnRem.OnEvent("Click", (*) => RemoveFromActive())

btnUp := settingsGui.Add("Button", "w" Scale(40) " h" Scale(30) " x+" Scale(200) " yp", "▲")
btnUp.OnEvent("Click", (*) => MoveItem(-1))

btnDown := settingsGui.Add("Button", "w" Scale(40) " h" Scale(30) " x+" Scale(5) " yp", "▼")
btnDown.OnEvent("Click", (*) => MoveItem(1))

global helpText1 := settingsGui.Add("Text", "x" Scale(25) " y+" Scale(10) " w" Scale(300) " cGray", "")

; Keybind selection popup controls
global keybindSelectionGui := 0
global lbKeybindAvailable := 0
global keybindSearchEdit := 0
global helpTextOCR := settingsGui.Add("Text", "x" Scale(25) " y+" Scale(5) " w" Scale(370) " cGray", "")
UpdateHelpText()
UpdateHelpTextOCR()

; ---Tab 2: Keybinds---
mainTab.UseTab(2)

; Profile Section for Keybinds
settingsGui.Add("Text", "x" Scale(25) " y" Scale(65) " w" Scale(200), "📂 Keybind Profile:")
keybindProfileDDL := settingsGui.Add("DropDownList", "x" Scale(25) " y+" Scale(5) " w" Scale(370) " vKeybindProfileDDL Background2f2f2f", GetProfilesList("keybind"))
keybindProfileDDL.OnEvent("Change", SwitchKeybindProfileDDLHandler)
SetProfileDDL("keybind")

btnNewKeybindProf := settingsGui.Add("Button", "w" Scale(180) " h" Scale(30) " x" Scale(25) " y+" Scale(5), "➕ New Profile")
btnNewKeybindProf.OnEvent("Click", CreateKeybindProfileHandler)

btnDelKeybindProf := settingsGui.Add("Button", "w" Scale(180) " h" Scale(30) " x+" Scale(10) " yp", "❌ Delete Profile")
btnDelKeybindProf.OnEvent("Click", DeleteKeybindProfileHandler)

; Active Keybinds Section
settingsGui.Add("Text", "x" Scale(25) " y+" Scale(15) " w" Scale(200), "Active Keybinds:")

lbKeybinds := settingsGui.Add("ListView", "x" Scale(25) " y+" Scale(5) " r12 w" Scale(370) " h" Scale(380) " vKeybindsList Multi Background000000", ["Icon", "Name", "Hotkey", "👁"])
lbKeybinds.SetImageList(IL_ID, 1)
lbKeybinds.ModifyCol(1, iconSizeScaled + Scale(4))
lbKeybinds.ModifyCol(2, Scale(190))
lbKeybinds.ModifyCol(3, Scale(80))
lbKeybinds.ModifyCol(4, Scale(30))
lbKeybinds.OnEvent("DoubleClick", ShowKeybindCapture)

btnAddKeybind := settingsGui.Add("Button", "w" Scale(40) " h" Scale(30) " x" Scale(25) " y+" Scale(10), "+")
btnAddKeybind.OnEvent("Click", (*) => ShowKeybindSelectionGui())

btnRemKeybind := settingsGui.Add("Button", "w" Scale(40) " h" Scale(30) " x+" Scale(5) " yp", "-")
btnRemKeybind.OnEvent("Click", (*) => RemoveFromKeybinds())

btnClearKeybind := settingsGui.Add("Button", "w" Scale(90) " h" Scale(30) " x+" Scale(5) " yp", "Clear Hotkey")
btnClearKeybind.OnEvent("Click", ClearSelectedKeybind)

btnToggleVisibility := settingsGui.Add("Button", "w" Scale(30) " h" Scale(30) " x+" Scale(70) " yp", "👁")
btnToggleVisibility.OnEvent("Click", ToggleKeybindVisibility)

btnKeyUp := settingsGui.Add("Button", "w" Scale(40) " h" Scale(30) " x+" Scale(5) " yp", "▲")
btnKeyUp.OnEvent("Click", (*) => MoveKeybindItem(-1))

btnKeyDown := settingsGui.Add("Button", "w" Scale(40) " h" Scale(30) " x+" Scale(5) " yp", "▼")
btnKeyDown.OnEvent("Click", (*) => MoveKeybindItem(1))

settingsGui.Add("Text", "x" Scale(25) " y+" Scale(10) " w" Scale(370) " cGray", "Double-click on a stratagem to set a hotkey.")

global helpText2 := settingsGui.Add("Text", "x" Scale(25) " y+" Scale(5) " w" Scale(370) " cGray", "")
UpdateHelpText2()

; ---Tab 3: Settings---
mainTab.UseTab(3)

settingsGui.Add("Text", "x" Scale(25) " y" Scale(65) " w" Scale(200), "Radial Menu Key:")
global radialMenuKeyInput := HotkeyInput(settingsGui, 25, 0, "", {value: RadialMenuKey, wildcard: RadialMenuKeyWildcard, hasWildcard: true, onChanged: OnRadialMenuKeyChange, onWildcardChanged: OnRadialMenuKeyWildcardChange, excludeKeys: ["WheelUp", "WheelDown"]})
global radialMenuKeyModeDDL := settingsGui.Add("DropDownList", "w" Scale(100) " x" Scale(25) " y+" Scale(2.5) " Background2f2f2f", ["Hold", "Toggle"])
if (RadialMenuKeyMode = "Toggle")
    radialMenuKeyModeDDL.Choose(2)
else
    radialMenuKeyModeDDL.Choose(1)
radialMenuKeyModeDDL.OnEvent("Change", OnRadialMenuKeyModeChange)

settingsGui.Add("Text", "x" Scale(25) " y+" Scale(5) " w" Scale(200), "Stratagem Menu:")
global stratagemMenuKeyInput := HotkeyInput(settingsGui, 25, 0, "", {value: StratagemMenuKey, hasWildcard: false, onChanged: OnStratagemMenuKeyChange})

menuInputTypeDDL := settingsGui.Add("DropDownList", "w" Scale(100) " x" Scale(25) " y+" Scale(2.5) " Background2f2f2f", ["Tap", "Double Tap", "Press", "Long Press", "Hold"])
menuInputTypeDDL.Choose(MenuInputType)
menuInputTypeDDL.OnEvent("Change", (*) => UpdateMenuInputType())

settingsGui.Add("Text", "x" Scale(25) " y+" Scale(5) " w" Scale(200), "Input Layout:")
inputLayoutDDL := settingsGui.Add("DropDownList", "w" Scale(100) " x" Scale(25) " y+" Scale(5) " Background2f2f2f", ["Arrows", "WASD", "[Custom]"])
if (InputLayout = "WASD")
    inputLayoutDDL.Choose(2)
else if (InputLayout = "Custom")
    inputLayoutDDL.Choose(3)
else
    inputLayoutDDL.Choose(1)
inputLayoutDDL.OnEvent("Change", (*) => UpdateInputLayout())

settingsGui.Add("Text", "x" Scale(25) " y+" Scale(10) " w" Scale(320), "Delays:")

postMenuDelayEdit := settingsGui.Add("Edit", "w" Scale(40) " x" Scale(25) " y+" Scale(5) " Number Background2f2f2f", PostMenuDelay)
settingsGui.Add("Text", "x+5 w" Scale(200), "Post Menu (ms)")
postMenuDelayEdit.OnEvent("Change", (*) => UpdatePostMenuDelay())

realKeyDelayEdit := settingsGui.Add("Edit", "w" Scale(40) " x" Scale(25) " y+" Scale(10) " Number Background2f2f2f", RealKeyDelay)
settingsGui.Add("Text", "x+5 w" Scale(200), "Key Press (ms)")
realKeyDelayEdit.OnEvent("Change", (*) => UpdateRealKeyDelay())

settingsGui.Add("Text", "x" Scale(25) " y+" Scale(15) " w" Scale(200), "General Hotkeys:")
displayToggleHotkeyInput := settingsGui.Add("Hotkey", "w" Scale(100) " x" Scale(25) " y+" Scale(5), DisplayToggleHotkey)
settingsGui.Add("Text", "x+5 w" Scale(200), "(GUI Toggle)")
displayToggleHotkeyInput.OnEvent("Change", (*) => UpdateDisplayToggleHotkey())

suspendHotkeyInput := settingsGui.Add("Hotkey", "w" Scale(100) " x" Scale(25) " y+" Scale(10), SuspendHotkey)
settingsGui.Add("Text", "x+5 w" Scale(200), "(Suspend)")
suspendHotkeyInput.OnEvent("Change", (*) => UpdateSuspendHotkey())

exitHotkeyInput := settingsGui.Add("Hotkey", "w" Scale(100) " x" Scale(25) " y+" Scale(10), ExitHotkey)
settingsGui.Add("Text", "x+5 w" Scale(200), "(Exit)")
exitHotkeyInput.OnEvent("Change", (*) => UpdateExitHotkey())

; Profile Switch Hotkeys
settingsGui.Add("Text", "x" Scale(25) " y+" Scale(15) " w" Scale(200), "Profile Switch Hotkeys:")

; Next Profile Hotkey
global profileNextHotkeyInput := HotkeyInput(settingsGui, 25, 0, "", {value: ProfileNextHotkey, wildcard: ProfileNextHotkeyWildcard, hasWildcard: true, onChanged: OnProfileNextHotkeyChange, onWildcardChanged: OnProfileNextHotkeyWildcardChange})
settingsGui.Add("Text", "x" Scale(130) " yp w" Scale(85), "(Next Profile)")

; Small spacer
settingsGui.Add("Text", "x" Scale(25) " y+" Scale(5) " w" Scale(1) " h" Scale(1), "")

; Prev Profile Hotkey
global profilePrevHotkeyInput := HotkeyInput(settingsGui, 25, 0, "", {value: ProfilePrevHotkey, wildcard: ProfilePrevHotkeyWildcard, hasWildcard: true, onChanged: OnProfilePrevHotkeyChange, onWildcardChanged: OnProfilePrevHotkeyWildcardChange})
settingsGui.Add("Text", "x" Scale(130) " yp w" Scale(85), "(Prev Profile)")

; GUI Scale - GroupBox
settingsGui.Add("GroupBox", "x" Scale(255) " y" Scale(65) " w" Scale(145) " h" Scale(70), "GUI Scale")
guiScaleDDL := settingsGui.Add("DropDownList", "w" Scale(55) " x" Scale(265) " y" Scale(85) " Background2f2f2f", ["1.0", "1.25", "1.5", "1.75", "2.0"])
settingsGui.Add("Text", "x+5 yp w" Scale(70), "(Scale Size)")
; Find and select current scale
scaleValues := [1.0, 1.25, 1.5, 1.75, 2.0]
selectedIndex := 1  ; Default to 1.0 (index 1)
for index, val in scaleValues {
    if (val = GUIScale) {
        selectedIndex := index
        break
    }
}
guiScaleDDL.Choose(selectedIndex)
guiScaleDDL.OnEvent("Change", (*) => UpdateGUIScale())
settingsGui.Add("Text", "x" Scale(265) " y+" Scale(10) " cGray", "Requires reload")

; Radial Menu UI - GroupBox
settingsGui.Add("GroupBox", "x" Scale(255) " y" Scale(140) " w" Scale(145) " h" Scale(155), "Radial Menu UI")
menuSizeEdit := settingsGui.Add("Edit", "w" Scale(40) " x" Scale(265) " y" Scale(160) " Number Background2f2f2f", MenuSize)
settingsGui.Add("Text", "x+5 yp w" Scale(85), "(Menu Size)")
menuSizeEdit.OnEvent("Change", (*) => UpdateMenuSize())

innerRadiusEdit := settingsGui.Add("Edit", "w" Scale(40) " x" Scale(265) " y+" Scale(10) " Number Background2f2f2f", InnerRadius)
settingsGui.Add("Text", "x+5 yp w" Scale(85), "(Inner Radius)")
innerRadiusEdit.OnEvent("Change", (*) => UpdateInnerRadius())

iconSizeEdit := settingsGui.Add("Edit", "w" Scale(40) " x" Scale(265) " y+" Scale(10) " Number Background2f2f2f", IconSize)
settingsGui.Add("Text", "x+5 yp w" Scale(85), "(Icon Size)")
iconSizeEdit.OnEvent("Change", (*) => UpdateIconSize())

textSizeEdit := settingsGui.Add("Edit", "w" Scale(40) " x" Scale(265) " y+" Scale(10) " Number Background2f2f2f", TextSize)
settingsGui.Add("Text", "x+5 yp w" Scale(85), "(Text Size)")
textSizeEdit.OnEvent("Change", (*) => UpdateTextSize())

settingsGui.Add("Text", "x" Scale(265) " y+" Scale(10) " w" Scale(65), "Show Text:")
showTextCheckbox := settingsGui.Add("CheckBox", "x+5 yp vShowText")
showTextCheckbox.Value := ShowText
showTextCheckbox.OnEvent("Click", (*) => UpdateShowText())

; Camera Lock Bypass - GroupBox
settingsGui.Add("GroupBox", "x" Scale(255) " y" Scale(300) " w" Scale(145) " h" Scale(185), "Camera Lock Bypass")
settingsGui.Add("Text", "x" Scale(265) " y" Scale(320) " w" Scale(65), "Lock Cam:")
blockCameraCheckbox := settingsGui.Add("CheckBox", "x+5 yp vBlockCameraBypass")
blockCameraCheckbox.Value := BlockCameraBypass
blockCameraCheckbox.OnEvent("Click", (*) => ToggleBlockCamera())

settingsGui.Add("Text", "x" Scale(265) " y+" Scale(5) " w" Scale(120), "Open Map Key:")
global openMapKeyInput := HotkeyInput(settingsGui, 265, 0, "", {value: OpenMapKey, hasWildcard: false, onChanged: OnOpenMapKeyChange})

settingsGui.Add("Text", "x" Scale(265) " y+" Scale(5) " w" Scale(120), "Map Key Type:")
mapInputTypeDDL := settingsGui.Add("DropDownList", "w" Scale(100) " x" Scale(265) " y+" Scale(5) " Background2f2f2f", ["Tap", "Double Tap", "Press", "Long Press", "Hold"])
mapInputTypeDDL.Choose(MapInputType)
mapInputTypeDDL.OnEvent("Change", (*) => UpdateMapInputType())

; Active Game Check - GroupBox
settingsGui.Add("GroupBox", "x" Scale(255) " y" Scale(490) " w" Scale(145) " h" Scale(105), "Active Game Check")
settingsGui.Add("Text", "x" Scale(265) " y" Scale(510) " w" Scale(70), "Auto-Pause:")
autoPauseCheckbox := settingsGui.Add("CheckBox", "x+5 yp vAutoPauseActive")
autoPauseCheckbox.Value := AutoPauseActive
autoPauseCheckbox.OnEvent("Click", (*) => ToggleAutoPause())

settingsGui.Add("Text", "x" Scale(265) " y+" Scale(8) " w" Scale(70), "Auto-Close:")
autoCloseCheckbox := settingsGui.Add("CheckBox", "x+5 yp vAutoCloseActive")
autoCloseCheckbox.Value := AutoCloseActive
autoCloseCheckbox.OnEvent("Click", (*) => ToggleAutoClose())

gameCheckTimerEdit := settingsGui.Add("Edit", "w" Scale(40) " x" Scale(265) " y+" Scale(5) " Number Background2f2f2f", GameCheckTimerInterval)
settingsGui.Add("Text", "x+5 yp w" Scale(80), "(ms) Interval")
gameCheckTimerEdit.OnEvent("Change", (*) => UpdateGameCheckTimer())

; Auto Language Switch - GroupBox
settingsGui.Add("GroupBox", "x" Scale(255) " y" Scale(600) " w" Scale(145) " h" Scale(70), "Auto Language Switch")
settingsGui.Add("Text", "x" Scale(265) " y" Scale(618) " w" Scale(70), "Auto Lang:")
autoLangCheckbox := settingsGui.Add("CheckBox", "x+5 yp vAutoLanguageSwitch")
autoLangCheckbox.Value := AutoLanguageSwitch
autoLangCheckbox.OnEvent("Click", (*) => ToggleAutoLanguageSwitch())

autoLangLayoutDDL := settingsGui.Add("DropDownList", "x" Scale(260) " y+" Scale(5) " w" Scale(135) " Background2f2f2f", EnglishLayoutNames)
; Find and select current layout
for idx, code in EnglishLayoutCodes {
    if (code = AutoLanguageLayout) {
        autoLangLayoutDDL.Choose(idx)
        break
    }
}
autoLangLayoutDDL.OnEvent("Change", UpdateAutoLanguageLayout)
; ---Tab 4: Misc---
mainTab.UseTab(4)

; Keybind List Overlay settings
settingsGui.Add("GroupBox", "x" Scale(25) " y" Scale(65) " w" Scale(170) " h" Scale(280), "Keybind List Overlay")

settingsGui.Add("Text", "x" Scale(35) " y" Scale(90) " w" Scale(120), "Toggle Hotkey:")
global keybindListHotkeyInput := HotkeyInput(settingsGui, 35, 0, "", {value: KeybindListHotkey, wildcard: KeybindListHotkeyWildcard, hasWildcard: true, onChanged: OnKeybindListHotkeyChange, onWildcardChanged: OnKeybindListHotkeyWildcardChange, excludeKeys: ["WheelUp", "WheelDown"]})

settingsGui.Add("Text", "x" Scale(35) " y+" Scale(10) " w" Scale(120), "Drag Delay (ms):")
keybindListDragDelayEdit := settingsGui.Add("Edit", "w" Scale(40) " x" Scale(35) " y+" Scale(5) " Number Background2f2f2f", KeybindListDragDelay)
settingsGui.Add("Text", "x+5 yp w" Scale(80), "(Hold time)")
keybindListDragDelayEdit.OnEvent("Change", (*) => UpdateKeybindListDragDelay())

; Show/hide fields checkboxes
settingsGui.Add("Text", "x" Scale(35) " y+" Scale(15) " w" Scale(120), "Show Fields:")
keybindListShowIconCb := settingsGui.Add("CheckBox", "x" Scale(35) " y+" Scale(5) " vKeybindListShowIcon", "Icon")
keybindListShowIconCb.Value := KeybindListShowIcon
keybindListShowIconCb.OnEvent("Click", (*) => UpdateKeybindListShowFields())

keybindListShowHotkeyCb := settingsGui.Add("CheckBox", "x+" Scale(2) " vKeybindListShowHotkey", "Key")
keybindListShowHotkeyCb.Value := KeybindListShowHotkey
keybindListShowHotkeyCb.OnEvent("Click", (*) => UpdateKeybindListShowFields())

keybindListShowNameCb := settingsGui.Add("CheckBox", "x+" Scale(2) " vKeybindListShowName", "Name")
keybindListShowNameCb.Value := KeybindListShowName
keybindListShowNameCb.OnEvent("Click", (*) => UpdateKeybindListShowFields())

; Transparency slider
settingsGui.Add("Text", "x" Scale(35) " y+" Scale(10) " w" Scale(120), "Transparency:")
keybindListTransparencySlider := settingsGui.Add("Slider", "x" Scale(35) " y+" Scale(5) " w" Scale(110) " Range15-255", KeybindListTransparency)
keybindListTransparencySlider.OnEvent("Change", (*) => UpdateKeybindListTransparency())
keybindListTransparencyText := settingsGui.Add("Text", "x+10 yp w" Scale(20), KeybindListTransparency)

; Assistants - GroupBox
settingsGui.Add("GroupBox", "x" Scale(25) " y" Scale(350) " w" Scale(170) " h" Scale(315), "Assistants")

; Weapon Assistant label
settingsGui.Add("Text", "x" Scale(35) " y" Scale(375) " w" Scale(150), "Weapon Assistant:")

; Toggle hotkey for weapon assistant on/off
global wpToggleInput := HotkeyInput(settingsGui, 35, 0, "", {value: ToggleWeaponHotkey, wildcard: ToggleWeaponHotkeyWildcard, hasWildcard: true, onChanged: OnWPToggleChange, onWildcardChanged: OnWPToggleWildcardChange})

; Status indicator text
global wpStatusText := settingsGui.Add("Text", "x+" Scale(5) " w" Scale(40) " Background2A2A2A", "○ OFF")

; Settings button
btnWPSettings := settingsGui.Add("Button", "x" Scale(35) " y+" Scale(10) " w" Scale(100) " h" Scale(24), "Settings")
btnWPSettings.OnEvent("Click", ShowWeaponAssistantSettings)

; Driver Assistant label
settingsGui.Add("Text", "x" Scale(35) " y+" Scale(10) " w" Scale(150), "Driver Assistant:")

; Toggle hotkey for driver assistant on/off
global daToggleInput := HotkeyInput(settingsGui, 35, 0, "", {value: ToggleDriverHotkey, wildcard: ToggleDriverHotkeyWildcard, hasWildcard: true, onChanged: OnDAToggleChange, onWildcardChanged: OnDAToggleWildcardChange})

; Status indicator text
global daStatusText := settingsGui.Add("Text", "x+" Scale(5) " w" Scale(40) " Background2A2A2A", "○ OFF")

; Settings button
btnDASettings := settingsGui.Add("Button", "x" Scale(35) " y+" Scale(10) " w" Scale(100) " h" Scale(24), "Settings")
btnDASettings.OnEvent("Click", ShowDriverAssistantSettings)

; Separator line before Inventory Manager and Weapon Quick Switch
settingsGui.Add("Text", "x" Scale(26) " y+" Scale(7.5) " w" Scale(168) " h1" " Backgroundffffff", "")

; Inventory Manager
btnIMSettings := settingsGui.Add("Button", "x" Scale(35) " y+" Scale(7.5) " w" Scale(100) " h" Scale(24), "Inventory")
btnIMSettings.OnEvent("Click", ShowInventoryManagerSettings)

; Status indicator text (clickable)
global imStatusText := settingsGui.Add("Text", "x+" Scale(5) " w" Scale(45) " Background2A2A2A Border +Center", "○ OFF")
imStatusText.OnEvent("Click", ToggleInventoryManagerFunc)

; Weapon Quick Switch
btnQSSettings := settingsGui.Add("Button", "x" Scale(35) " y+" Scale(10) " w" Scale(100) " h" Scale(24), "Quick Swap")
btnQSSettings.OnEvent("Click", ShowWeaponQuickSwitchSettings)

; Status indicator text (clickable)
global qsStatusText := settingsGui.Add("Text", "x+" Scale(5) " w" Scale(45) " Background2A2A2A Border +Center", "○ OFF")
qsStatusText.OnEvent("Click", ToggleWeaponQuickSwitchFunc)

; Gamepad Settings - GroupBox
settingsGui.Add("GroupBox", "x" Scale(205) " y" Scale(65) " w" Scale(190) " h" Scale(280), "Gamepad")

; Enable Gamepad checkbox
settingsGui.Add("Text", "x" Scale(215) " y" Scale(90) " w" Scale(110), "Enable Gamepad:")
global gamepadEnabledCheckbox := settingsGui.Add("CheckBox", "x+" Scale(5) " yp vGamepadEnabled")
gamepadEnabledCheckbox.Value := GamepadEnabled
gamepadEnabledCheckbox.OnEvent("Click", ToggleGamepadEnabled)

; Controller Type dropdown
settingsGui.Add("Text", "x" Scale(215) " y+" Scale(10) " w" Scale(120), "Controller Type:")
global gamepadTypeDDL := settingsGui.Add("DropDownList", "x" Scale(215) " y+" Scale(5) " w" Scale(100) " Background2f2f2f", ["Xbox", "PlayStation"])
gamepadTypeDDL.Choose(GamepadType = "PlayStation" ? 2 : 1)
gamepadTypeDDL.OnEvent("Change", UpdateGamepadType)

; Menu Button dropdown with input field
settingsGui.Add("Text", "x" Scale(215) " y+" Scale(10) " w" Scale(120), "Menu Button:")
; Build button list with [Input] at the beginning
global gamepadButtonChoiceList := ["[Input]"]
for btn in GamepadButtonNames[GamepadType]
    gamepadButtonChoiceList.Push(btn)
global gamepadMenuButtonDDL := settingsGui.Add("DropDownList", "x" Scale(215) " y+" Scale(5) " w" Scale(100) " Background2f2f2f", gamepadButtonChoiceList)
; Select current button (if custom input, select [Input], otherwise find in list)
SetGamepadMenuButtonDDL()
gamepadMenuButtonDDL.OnEvent("Change", OnGamepadMenuButtonDDLChange)

; Button to capture gamepad button
global gamepadCaptureBtn := settingsGui.Add("Button", "x+" Scale(5) " yp w" Scale(24) " h" Scale(24), "✎")
gamepadCaptureBtn.OnEvent("Click", ShowGamepadCapturePopup)

; Navigation Stick dropdown
settingsGui.Add("Text", "x" Scale(215) " y+" Scale(10) " w" Scale(120), "Navigation Stick:")
global gamepadNavigationStickDDL := settingsGui.Add("DropDownList", "x" Scale(215) " y+" Scale(5) " w" Scale(100) " Background2f2f2f", ["Right Stick", "Left Stick", "D-Pad"])
gamepadNavigationStickDDL.Choose(GamepadNavigationStick = "Right" ? 1 : (GamepadNavigationStick = "Left" ? 2 : 3))
gamepadNavigationStickDDL.OnEvent("Change", UpdateGamepadNavigationStick)

; Gamepad Status
settingsGui.Add("Text", "x" Scale(215) " y+" Scale(10) " w" Scale(120), "Status:")
global gamepadStatusText := settingsGui.Add("Text", "x" Scale(215) " y+" Scale(5) " w" Scale(170), "○ Disabled")

; OCR settings
settingsGui.Add("GroupBox", "x" Scale(205) " y" Scale(350) " w" Scale(190) " h" Scale(315), "OCR")
settingsGui.Add("Text", "x" Scale(215) " y" Scale(375) " w" Scale(110), "OCR Hotkey:")
global ocrHotkeyInput := HotkeyInput(settingsGui, 215, 0, "", {value: OCRHotkey, wildcard: OCRHotkeyWildcard, hasWildcard: true, onChanged: OnOCRHotkeyChange, onWildcardChanged: OnOCRHotkeyWildcardChange, excludeKeys: ["WheelUp", "WheelDown"]})
global ocrGamepadCaptureBtn := settingsGui.Add("Button", "x+" Scale(5) " yp w" Scale(24) " h" Scale(24), "🎮")
ocrGamepadCaptureBtn.OnEvent("Click", ShowOCRGamepadCapturePopup)

global ocrHoldEdit := settingsGui.Add("Edit", "x" Scale(215) " y+" Scale(8) " w" Scale(45) " Number Background2f2f2f", OCRHoldMs)
ocrHoldEdit.OnEvent("Change", UpdateOCRHoldMs)
ocrHoldEdit.Enabled := OCRUseHold

settingsGui.Add("Text", "x+" Scale(5) " yp w" Scale(40), "Hold(ms)")
global ocrHoldCheckbox := settingsGui.Add("CheckBox", "x+" Scale(5) " yp vOCRUseHold")
ocrHoldCheckbox.Value := OCRUseHold
ocrHoldCheckbox.OnEvent("Click", UpdateOCRUseHold)

settingsGui.Add("Text", "x" Scale(215) " y+" Scale(15) " w" Scale(170), "Scrambler Bypass:")
global ocrBypassHotkeyInput := HotkeyInput(settingsGui, 215, 0, "", {value: OCRBypassToggleHotkey, wildcard: OCRBypassToggleHotkeyWildcard, hasWildcard: true, onChanged: OnOCRBypassHotkeyChange, onWildcardChanged: OnOCRBypassHotkeyWildcardChange, excludeKeys: ["WheelUp", "WheelDown"]})

global bypassGamepadCaptureBtn := settingsGui.Add("Button", "x+" Scale(5) " yp w" Scale(24) " h" Scale(24), "🎮")
bypassGamepadCaptureBtn.OnEvent("Click", ShowBypassGamepadCapturePopup)

global bypassHoldEdit := settingsGui.Add("Edit", "x" Scale(215) " y+" Scale(8) " w" Scale(45) " Number Background2f2f2f", BypassHoldMs)
bypassHoldEdit.OnEvent("Change", UpdateBypassHoldMs)
bypassHoldEdit.Enabled := BypassUseHold

settingsGui.Add("Text", "x+" Scale(5) " yp w" Scale(40), "Hold(ms)")
global bypassHoldCheckbox := settingsGui.Add("CheckBox", "x+" Scale(5) " yp vBypassUseHold")
bypassHoldCheckbox.Value := BypassUseHold
bypassHoldCheckbox.OnEvent("Click", UpdateBypassUseHold)

btnOCRSettings := settingsGui.Add("Button", "x" Scale(215) " y+" Scale(20) " w" Scale(170) " h" Scale(28), "OCR Settings")
btnOCRSettings.OnEvent("Click", (*) => OCR_ShowSettingsWindow())

mainTab.UseTab()
settingsGui.Show()

; Start timer if auto-pause or auto-close is enabled in settings
if (AutoPauseActive || AutoCloseActive) {
    SetTimer(GameCheck, GameCheckTimerInterval)
}

SetSuspendHotkey()
SetExitHotkey()
SetDisplayToggleHotkey()
SetRadialMenuHotkey()
SetProfileSwitchHotkeys()
SetOCRHotkey()
SetOCRBypassToggleHotkey()
SetWeaponAssistantHotkey()
SetWeaponSafetyHotkey()
SetWeaponCycleHotkey()
UpdateWeaponAssistantStatus()
SetDriverAssistantHotkey()
UpdateDriverAssistantStatus()
UpdateInventoryManagerStatus()
UpdateWeaponQuickSwitchStatus()

; Initialize gamepad if enabled
if (GamepadEnabled) {
    InitGamepad()
    SetGamepadHotkey()
}

; Tray Menu
A_TrayMenu.Delete()
A_TrayMenu.Add("Show", (*) => (DllCall("IsWindowVisible", "Ptr", settingsGui.Hwnd) ? settingsGui.Hide() : settingsGui.Show()))
A_TrayMenu.Add("Suspend", (*) => ToggleSuspend())
A_TrayMenu.Add("Reload", (*) => Reload())
A_TrayMenu.Add("Exit", (*) => ExitApp())
A_TrayMenu.Default := "Show"

; Selection Popup
selectionGui := Gui("-Caption +LastFound", "Select Stratagem")
selectionGui.BackColor := "202020"
selBaseFontSize := Scale(10)
selectionGui.SetFont("s" selBaseFontSize " cC4C4C4", "Segoe UI")
selectionGui.MarginX := Scale(5)
selectionGui.MarginY := Scale(5)
selectionGui.OnEvent("Close", CloseSelectionGui)
selectionGui.OnEvent("Escape", CloseSelectionGui)

; Custom Title Bar for Selection GUI
selTitleFontSize := Scale(12)
selectionGui.SetFont("cFFFFFF s" selTitleFontSize)
selectionGui.Add("Text", "x0 y0 w" Scale(280) " h" Scale(30) " Background2A2A2A Border +Center", "Select Stratagem").OnEvent("Click", StartMoveSel)
selectionGui.Add("Button", "x+5 y0 w" Scale(30) " h" Scale(30), "X").OnEvent("Click", CloseSelectionGui)
selectionGui.SetFont("s" selBaseFontSize " cC4C4C4")

selectionGui.Add("Text", "x" Scale(10) " y" Scale(40) " w" Scale(200), "Search:")
searchEdit := selectionGui.Add("Edit", "w" Scale(265) " h" Scale(25) " x" Scale(10) " y+" Scale(5) " vSearchBox Background2f2f2f")
searchEdit.OnEvent("Change", FilterAvailableList)

btnFavorites := selectionGui.Add("Button", "w" Scale(30) " h" Scale(25) " x+" Scale(5) " yp", "★")
btnFavorites.OnEvent("Click", ToggleFavoritesFilter)

lbAvailable := selectionGui.Add("ListView", "x" Scale(10) " y+" Scale(10) " r16 w" Scale(300) " Multi vAvailableList Background000000", ["Icon", "Name", "ID", "Type", "★"])
lbAvailable.SetImageList(IL_ID, 1)
lbAvailable.ModifyCol(1, iconSizeScaled + Scale(8))   ; Icon column - with scaled size
lbAvailable.ModifyCol(2, Scale(200))  ; Name column
lbAvailable.ModifyCol(3, 0)    ; ID (hidden)
lbAvailable.ModifyCol(4, 0)    ; Type (hidden)
lbAvailable.ModifyCol(5, Scale(25))   ; Fav column
lbAvailable.OnEvent("DoubleClick", ToggleFavorite)
PopulateAvailableList()

btnAddSel := selectionGui.Add("Button", "w" Scale(300) " x" Scale(10) " y+" Scale(10), "Add Selected")
btnAddSel.OnEvent("Click", AddSelected)

selectionGui.Add("Text", "w" Scale(300) " x" Scale(10) " y+" Scale(5) " cYellow Center", "Double-click a stratagem to mark it as favorite (★)")

; --- Tab Focus Clear Function ---
ClearTabFocus(*) {
    ; Remove focus from any control by setting focus to the tab itself
    global settingsGui, mainTab
    try {
        ControlFocus(mainTab.Hwnd)
    }
}

; --- INTERFACE FUNCTIONS ---
ShowSelectionGui() {
    global ShowFavoritesOnly, isKeybindSelectionMode, btnAddSel
    
    ; Reset keybind mode flag for Radial Menu
    isKeybindSelectionMode := false
    btnAddSel.Text := "Add Selected"
    
    searchEdit.Value := ""
    ; Reset favorites filter when opening selection popup
    ShowFavoritesOnly := false
    PopulateAvailableList()
    selectionGui.Show()
    ; Set up Ctrl+A hotkey with ~ prefix to pass-through to other apps
    ; S = SuspendExempt (works when suspended)
    Hotkey("~^a", SelectAllAvailable, "On S")
}

CloseSelectionGui(*) {
    global selectionGui, ShowFavoritesOnly
    
    ; Reset favorites filter when closing the popup
    ShowFavoritesOnly := false
    
    ; Disable the Ctrl+A hotkey when closing the popup
    Hotkey("~^a", SelectAllAvailable, "Off")
    selectionGui.Hide()
}

AddSelected(*) {
    global isKeybindSelectionMode
    
    ; If in keybind mode, call the keybind function instead
    if (isKeybindSelectionMode) {
        AddSelectedToKeybinds()
        return
    }
    
    added := 0
    row := 0
    while (row := lbAvailable.GetNext(row)) {
        type := lbAvailable.GetText(row, 4)
        if type = "CATEGORY"
            continue
        
        id := lbAvailable.GetText(row, 3)
        if id != "" && Stratagems.Has(id) {
            ; Check if already in active stratagems (prevent duplicates)
            isDuplicate := false
            for existingId in ActiveStratagems {
                if (existingId = id) {
                    isDuplicate := true
                    break
                }
            }
            if !isDuplicate {
                ActiveStratagems.Push(id)
                added++
            }
        }
    }
    if added > 0 {
        UpdateActiveList()
        SaveProfiles()
        InvalidateRadialCache()
        CloseSelectionGui()
    }
}

RemoveFromActive(*) {
    selectedRows := []
    row := 0
    while (row := lbActive.GetNext(row)) {
        selectedRows.Push(row)
    }

    if (selectedRows.Length == 0)
        return

    i := selectedRows.Length
    while (i > 0) {
        idx := selectedRows[i]
        ActiveStratagems.RemoveAt(idx)
        i--
    }

    UpdateActiveList()
    SaveProfiles()
    InvalidateRadialCache()
}

MoveItem(dir) {
    idx := lbActive.GetNext()
    if (dir = -1 && idx > 1) || (dir = 1 && idx > 0 && idx < ActiveStratagems.Length) {
        item := ActiveStratagems.RemoveAt(idx)
        ActiveStratagems.InsertAt(idx + dir, item)
        UpdateActiveList(idx + dir)
        SaveProfiles()
        ; Invalidate cache to redraw with new order
        InvalidateRadialCache()
    }
}

InvalidateRadialCache() {
    global Radial_StaticBitmap, Radial_StaticCount
    if (Radial_StaticBitmap != 0) {
        Gdip_DisposeImage(Radial_StaticBitmap)
        Radial_StaticBitmap := 0
    }
    Radial_StaticCount := 0
}

; Clear bitmap cache when switching profiles to free memory
ClearBitmapCache() {
    global BitmapCache
    if IsSet(BitmapCache) && IsObject(BitmapCache) {
        for path, bitmap in BitmapCache {
            try Gdip_DisposeImage(bitmap)
        }
        BitmapCache := Map()
    }
}

UpdateActiveList(selectIdx := 0) {
    lbActive.Delete()
    lbActive.Opt("-Redraw")
    for id in ActiveStratagems {
        idx := (IconIndexMap.Has(id) && IconIndexMap[id] > 0) ? IconIndexMap[id] : 1
        category := StratagemSections.Has(id) ? StratagemSections[id] : ""
        ; Remove " Stratagems" suffix from category name for cleaner display
        category := StrReplace(category, " Stratagems", "")
        lbActive.Add("Icon" . idx, "", StratagemNames[id], category)
    }
    lbActive.Opt("+Redraw")
    
    if selectIdx {
        lbActive.Modify(selectIdx, "Select Vis")
    }
}

PopulateAvailableList() {
    FilterAvailableList()
}

FilterAvailableList(*) {
    global ShowFavoritesOnly
    searchText := StrLower(searchEdit.Value)
    showFavFilter := ShowFavoritesOnly
    lbAvailable.Delete()
    lbAvailable.Opt("-Redraw")
    
    ; First pass: identify categories with matching stratagems
    categoriesWithMatches := Map()
    if (searchText != "" || showFavFilter) {
        currentCategory := ""
        for id in OrderedIDs {
            if InStr(id, "category_") = 1 {
                currentCategory := id
                categoriesWithMatches[currentCategory] := false
            } else if InStr(id, "separator_") = 1 {
                continue
            } else if (currentCategory != "") {
                name := StratagemNames[id]
                matchesSearch := (searchText = "" || InStr(StrLower(name), searchText))
                matchesFavorites := (!showFavFilter || IsFavorite(id))
                if (matchesSearch && matchesFavorites) {
                    categoriesWithMatches[currentCategory] := true
                }
            }
        }
    }
    
    ; Second pass: build the list
    currentCategory := ""
    for id in OrderedIDs {
        name := StratagemNames[id]
        
        if InStr(id, "category_") = 1 {
            currentCategory := id
            ; When searching or filtering favorites, only show category if it has matching stratagems
            if (searchText != "" || showFavFilter) {
                if !categoriesWithMatches.Has(currentCategory) || !categoriesWithMatches[currentCategory]
                    continue
            }
            lbAvailable.Add("Icon1", "", name, "", "CATEGORY", "")
            continue
        }
        
        if InStr(id, "separator_") = 1 || name = " "
            continue
        
        ; When searching, only show stratagems that match
        if (searchText != "" && !InStr(StrLower(name), searchText))
            continue
        
        ; When filtering favorites, only show favorited stratagems
        if (showFavFilter && !IsFavorite(id))
            continue
        
        ; Determine favorite symbol
        favSymbol := IsFavorite(id) ? "★" : ""
        
        idx := IconIndexMap.Has(id) ? IconIndexMap[id] : 0
        if (idx > 0)
            lbAvailable.Add("Icon" . idx, "", name, id, "", favSymbol)
        else
            lbAvailable.Add("", "[?]", name, id, "", favSymbol)
    }
    lbAvailable.Opt("+Redraw")
}

; --- SAVE / LOAD (INI) ---
SaveProfiles() {
    global ActiveProfile, ActiveStratagems
    
    ; Save to profile-specific section
    section := "Profile_" . ActiveProfile
    str := ""
    for id in ActiveStratagems
        str .= id ","
    profileIniPath := GetRadialProfileIniPath(ActiveProfile)
    IniWrite(RTrim(str, ","), profileIniPath, section, "ActiveList")
    
    ; Save active profile setting
    IniWrite(ActiveProfile, IniPath, "Settings", "ActiveProfile")
}

SaveSettings() {

    ; Save global settings (Tab 2 - Settings page)
    IniWrite(StratagemMenuKey, IniPath, "Settings", "StratagemMenuKey")
    IniWrite(MenuInputType, IniPath, "Settings", "MenuInputType")
    IniWrite(InputLayout, IniPath, "Settings", "InputLayout")
    IniWrite(PostMenuDelay, IniPath, "Settings", "PostMenuDelay")
    IniWrite(RealKeyDelay, IniPath, "Settings", "RealKeyDelay")
    IniWrite(SuspendHotkey, IniPath, "Settings", "SuspendHotkey")
    IniWrite(ExitHotkey, IniPath, "Settings", "ExitHotkey")
    IniWrite(ProfileNextHotkey, IniPath, "Settings", "ProfileNextHotkey")
    IniWrite(ProfilePrevHotkey, IniPath, "Settings", "ProfilePrevHotkey")
    IniWrite(ProfileNextHotkeyWildcard ? "1" : "0", IniPath, "Settings", "ProfileNextHotkeyWildcard")
    IniWrite(ProfilePrevHotkeyWildcard ? "1" : "0", IniPath, "Settings", "ProfilePrevHotkeyWildcard")
    IniWrite(DisplayToggleHotkey, IniPath, "Settings", "DisplayToggleHotkey")
    IniWrite(GUIScale, IniPath, "Settings", "GUIScale")
    
    ; Save custom keys
    IniWrite(CustomUpKey, IniPath, "Settings", "CustomUpKey")
    IniWrite(CustomDownKey, IniPath, "Settings", "CustomDownKey")
    IniWrite(CustomLeftKey, IniPath, "Settings", "CustomLeftKey")
    IniWrite(CustomRightKey, IniPath, "Settings", "CustomRightKey")
    
    ; Save Radial Menu settings
    IniWrite(MenuSize, IniPath, "Radial_Menu", "MenuSize")
    IniWrite(InnerRadius, IniPath, "Radial_Menu", "InnerRadius")
    IniWrite(IconSize, IniPath, "Radial_Menu", "IconSize")
    IniWrite(TextSize, IniPath, "Radial_Menu", "TextSize")
    IniWrite(ShowText, IniPath, "Radial_Menu", "ShowText")
    IniWrite(RadialMenuKey, IniPath, "Radial_Menu", "RadialMenuKey")
    IniWrite(RadialMenuKeyWildcard, IniPath, "Radial_Menu", "RadialMenuKeyWildcard")
    IniWrite(RadialMenuKeyMode, IniPath, "Radial_Menu", "RadialMenuKeyMode")
    
    ; Save Keybind List settings
    IniWrite(KeybindListHotkey, IniPath, "KeybindList", "ListToggleHotkey")
    IniWrite(KeybindListHotkeyWildcard ? "1" : "0", IniPath, "KeybindList", "ListToggleHotkeyWildcard")
    IniWrite(KeybindListTransparency, IniPath, "KeybindList", "Transparency")

    ; Save OCR settings
    IniWrite(OCRHotkey, IniPath, "OCR", "Hotkey")
    IniWrite(OCRHotkeyWildcard ? "1" : "0", IniPath, "OCR", "HotkeyWildcard")
    IniWrite(OCRBypassToggleHotkey, IniPath, "OCR", "BypassToggleHotkey")
    IniWrite(OCRBypassToggleHotkeyWildcard ? "1" : "0", IniPath, "OCR", "BypassToggleHotkeyWildcard")
    
    ; Save Camera Bypass settings
    IniWrite(OpenMapKey, IniPath, "Radial_Menu", "OpenMapKey")
    IniWrite(MapInputType, IniPath, "Radial_Menu", "MapInputType")
}

LoadSettings() {
    global StratagemMenuKey, RadialMenuKey, RadialMenuKeyWildcard, RadialMenuKeyMode, MenuInputType, InputLayout, PostMenuDelay, RealKeyDelay
    global SuspendHotkey, ExitHotkey, MenuSize, InnerRadius, IconSize, TextSize, ShowText, ScreenCX, ScreenCY, ActiveProfile, GUIScale
    global ProfileNextHotkey, ProfilePrevHotkey, DisplayToggleHotkey
    global AutoPauseActive, AutoCloseActive, GameCheckTimerInterval, AutoLanguageSwitch, AutoLanguageLayout, BlockCameraBypass, OpenMapKey, MapInputType
    global CustomUpKey, CustomDownKey, CustomLeftKey, CustomRightKey
    global KeybindListHotkey, KeybindListHotkeyWildcard, KeybindListTransparency, KeybindListDragDelay, KeybindListShowIcon, KeybindListShowHotkey, KeybindListShowName
    global OCRHotkey, OCRHotkeyWildcard, OCRBypassToggleHotkey, OCRBypassToggleHotkeyWildcard
    
    try {
        ; Load active profile first
        ActiveProfile := IniRead(IniPath, "Settings", "ActiveProfile", "Default")
        
        ; Load profile-specific stratagems
        section := "Profile_" . ActiveProfile
        profileIniPath := GetRadialProfileIniPath(ActiveProfile)
        data := IniRead(profileIniPath, section, "ActiveList", "")
        if data != "" {
            for id in StrSplit(data, ",") {
                id := Trim(id)
                if id != "" && Stratagems.Has(id)
                    ActiveStratagems.Push(id)
            }
        }
        
        ; Load global settings
        StratagemMenuKey := IniRead(IniPath, "Settings", "StratagemMenuKey", "LControl")
        MenuInputType := Integer(IniRead(IniPath, "Settings", "MenuInputType", "5"))
        InputLayout := IniRead(IniPath, "Settings", "InputLayout", "Arrows")
        PostMenuDelay := Integer(IniRead(IniPath, "Settings", "PostMenuDelay", "25"))
        RealKeyDelay := Integer(IniRead(IniPath, "Settings", "RealKeyDelay", "25"))
        SuspendHotkey := IniRead(IniPath, "Settings", "SuspendHotkey", "Insert")
        ExitHotkey := IniRead(IniPath, "Settings", "ExitHotkey", "End")
        ProfileNextHotkey := IniRead(IniPath, "Settings", "ProfileNextHotkey", "PgUp")
        ProfilePrevHotkey := IniRead(IniPath, "Settings", "ProfilePrevHotkey", "PgDn")
        ProfileNextHotkeyWildcard := IniRead(IniPath, "Settings", "ProfileNextHotkeyWildcard", "0") = "1" ? true : false
        ProfilePrevHotkeyWildcard := IniRead(IniPath, "Settings", "ProfilePrevHotkeyWildcard", "0") = "1" ? true : false
        DisplayToggleHotkey := IniRead(IniPath, "Settings", "DisplayToggleHotkey", "F1")
        
        ; Load custom keys
        CustomUpKey := IniRead(IniPath, "Settings", "CustomUpKey", "w")
        CustomDownKey := IniRead(IniPath, "Settings", "CustomDownKey", "s")
        CustomLeftKey := IniRead(IniPath, "Settings", "CustomLeftKey", "a")
        CustomRightKey := IniRead(IniPath, "Settings", "CustomRightKey", "d")
        
        ; Load Game check settings (for auto-pause and auto-close)
        AutoPauseActive := IniRead(IniPath, "Settings", "AutoPauseActive", "0") = "1" ? true : false
        AutoCloseActive := IniRead(IniPath, "Settings", "AutoCloseActive", "0") = "1" ? true : false
        GameCheckTimerInterval := Integer(IniRead(IniPath, "Settings", "GameCheckTimerInterval", "500"))
        AutoLanguageSwitch := IniRead(IniPath, "Settings", "AutoLanguageSwitch", "0") = "1" ? true : false
        AutoLanguageLayout := IniRead(IniPath, "Settings", "AutoLanguageLayout", "00000409")
        
        ; Load Camera bypass settings
        BlockCameraBypass := IniRead(IniPath, "Radial_Menu", "BlockCameraBypass", "0") = "1" ? true : false
        OpenMapKey := IniRead(IniPath, "Radial_Menu", "OpenMapKey", "Tab")
        MapInputType := Integer(IniRead(IniPath, "Radial_Menu", "MapInputType", "1"))
        
        ; Load Radial Menu settings
        MenuSize := Integer(IniRead(IniPath, "Radial_Menu", "MenuSize", "500"))
        InnerRadius := Integer(IniRead(IniPath, "Radial_Menu", "InnerRadius", "70"))
        IconSize := Integer(IniRead(IniPath, "Radial_Menu", "IconSize", "48"))
        TextSize := Integer(IniRead(IniPath, "Radial_Menu", "TextSize", "9"))
        ShowText := IniRead(IniPath, "Radial_Menu", "ShowText", "1") = "1" ? true : false
        RadialMenuKey := IniRead(IniPath, "Radial_Menu", "RadialMenuKey", "MButton")
        RadialMenuKeyWildcard := IniRead(IniPath, "Radial_Menu", "RadialMenuKeyWildcard", "0") = "1" ? true : false
        RadialMenuKeyMode := IniRead(IniPath, "Radial_Menu", "RadialMenuKeyMode", "Hold")
        
        ; Load GUI Scale
        GUIScale := Float(IniRead(IniPath, "Settings", "GUIScale", "1.0"))
        if (GUIScale < 1.0)
            GUIScale := 1.0
        if (GUIScale > 2.0)
            GUIScale := 2.0
        
        ; Load Keybind List settings
        KeybindListHotkey := IniRead(IniPath, "KeybindList", "ListToggleHotkey", "F2")
        KeybindListHotkeyWildcard := IniRead(IniPath, "KeybindList", "ListToggleHotkeyWildcard", "0") = "1" ? true : false
        KeybindListTransparency := Integer(IniRead(IniPath, "KeybindList", "Transparency", "200"))
        KeybindListDragDelay := Integer(IniRead(IniPath, "KeybindList", "DragDelay", "300"))
        KeybindListShowIcon := IniRead(IniPath, "KeybindList", "ShowIcon", "1") = "1" ? true : false
        KeybindListShowHotkey := IniRead(IniPath, "KeybindList", "ShowHotkey", "1") = "1" ? true : false
        KeybindListShowName := IniRead(IniPath, "KeybindList", "ShowName", "1") = "1" ? true : false

        ; Load OCR settings
        OCRHotkey := IniRead(IniPath, "OCR", "Hotkey", "F3")
        OCRHotkeyWildcard := IniRead(IniPath, "OCR", "HotkeyWildcard", "0") = "1" ? true : false
        OCRBypassToggleHotkey := IniRead(IniPath, "OCR", "BypassToggleHotkey", "F4")
        OCRBypassToggleHotkeyWildcard := IniRead(IniPath, "OCR", "BypassToggleHotkeyWildcard", "0") = "1" ? true : false
        
        ScreenCX := A_ScreenWidth // 2
        ScreenCY := A_ScreenHeight // 2
    } catch as err {
    }
}

; --- UNIVERSAL PROFILE FUNCTIONS ---
; profileType: "radial" for Radial Menu profiles, "keybind" for Keybind profiles

GetProfilesList(profileType := "radial") {
    global ProfilesIniPath, OCRProfileIniPath
    profiles := []
    
    ; Always include Default profile first
    profiles.Push("Default")
    
    ; Determine section prefix based on profile type
    prefix := profileType = "keybind" ? "KeybindProfile_" : "Profile_"
    
    ; Scan INI files for profile sections
    iniFiles := [ProfilesIniPath]
    if (profileType = "radial")
        iniFiles.Push(OCRProfileIniPath)

    pattern := "^\[" . prefix . "(.+)\]$"
    for filePath in iniFiles {
        if !FileExist(filePath)
            continue

        try {
            fileContent := FileRead(filePath, "UTF-8")
            for line in StrSplit(fileContent, "`n", "`r") {
                line := Trim(line)
                if RegExMatch(line, pattern, &m) {
                    ; Only add if not already in list (avoid duplicates)
                    found := false
                    for name in profiles {
                        if (name = m[1]) {
                            found := true
                            break
                        }
                    }
                    if !found
                        profiles.Push(m[1])
                }
            }
        }
    }
    
    return profiles
}

SetProfileDDL(profileType := "radial", ddlControl := 0) {
    global ActiveProfile, ActiveKeybindProfile, ProfileDDL, keybindProfileDDL
    
    ; Determine which profile name to select based on profile type
    currentProfileName := profileType = "keybind" ? ActiveKeybindProfile : ActiveProfile
    if (ddlControl = 0)
        ddlControl := profileType = "keybind" ? keybindProfileDDL : ProfileDDL
    
    ; Find and select the active profile in dropdown
    profiles := GetProfilesList(profileType)
    for index, name in profiles {
        if (name = currentProfileName) {
            ddlControl.Choose(index)
            break
        }
    }
}

SwitchProfile(profileType := "radial", newProfile := "", forceReload := false) {
    global IniPath, ProfilesIniPath, Stratagems
    
    ; Get current state based on profile type
    if (profileType = "keybind") {
        global ActiveKeybindProfile, ActiveKeybindStratagems, StratagemKeybinds, keybindProfileDDL

        ; Get selected profile name from dropdown if not provided
        if (newProfile = "")
            newProfile := keybindProfileDDL.Text

        sameProfile := (newProfile = ActiveKeybindProfile)
        if (newProfile = "" || (!forceReload && sameProfile))
            return

        ; Save current profile before switching.
        ; For forced reload of the same profile, skip save to avoid overwriting externally updated data.
        if !(forceReload && sameProfile)
            SaveKeybindProfile()
        
        ; Unregister all current hotkeys
        for id in StratagemKeybinds
            UnregisterStratagemHotkey(id)
        
        ; Switch to new profile
        ActiveKeybindProfile := newProfile
        StratagemKeybinds := Map()
        ActiveKeybindStratagems := []
        
        ; Load profile data
        section := "KeybindProfile_" . ActiveKeybindProfile
        profileIniPath := ProfilesIniPath
        
        try {
            ; Load stratagems list
            data := IniRead(profileIniPath, section, "ActiveList", "")
            if data != "" {
                for id in StrSplit(data, ",") {
                    id := Trim(id)
                    if id != "" && Stratagems.Has(id)
                        ActiveKeybindStratagems.Push(id)
                }
            }
            
            ; Load hotkeys
            for id in ActiveKeybindStratagems {
                try {
                    hk := IniRead(profileIniPath, section, id, "")
                    if (hk != "") {
                        StratagemKeybinds[id] := hk
                        RegisterStratagemHotkey(id, hk)
                    }
                }
            }
        } catch {
        }
        
        ; Save the active profile setting
        IniWrite(ActiveKeybindProfile, IniPath, "Settings", "ActiveKeybindProfile")
        
        ; Update the UI
        UpdateKeybindsList()
        SetProfileDDL("keybind")
        
        ; Show tooltip notification
        ToolTip("Keybind Profile: " . ActiveKeybindProfile, A_ScreenWidth - 200, A_ScreenHeight - 50)
        SetTimer(RemoveToolTip, -1000)
    }
    else {
        ; Radial Menu profile
        global ActiveProfile, ActiveStratagems, ProfileDDL

        ; Get selected profile name from dropdown if not provided
        if (newProfile = "")
            newProfile := ProfileDDL.Text

        sameProfile := (newProfile = ActiveProfile)
        if (newProfile = "" || (!forceReload && sameProfile))
            return

        ; Save current profile before switching.
        ; For forced reload of the same profile, skip save to avoid overwriting externally updated data.
        if !(forceReload && sameProfile)
            SaveProfiles()
        
        ; Switch to new profile
        ActiveProfile := newProfile
        
        ; Clear and load new profile's stratagems
        ActiveStratagems := []
        section := "Profile_" . ActiveProfile
        profileIniPath := GetRadialProfileIniPath(ActiveProfile)
        
        try {
            data := IniRead(profileIniPath, section, "ActiveList", "")
            if data != "" {
                for id in StrSplit(data, ",") {
                    id := Trim(id)
                    if id != "" && Stratagems.Has(id)
                        ActiveStratagems.Push(id)
                }
            }
        } catch {
            ; Profile section doesn't exist yet
        }
        
        ; Save the active profile setting
        IniWrite(ActiveProfile, IniPath, "Settings", "ActiveProfile")
        
        ; Clear bitmap cache and invalidate radial cache for new profile
        ClearBitmapCache()
        InvalidateRadialCache()
        
        ; Update the UI
        UpdateActiveList()
        SetProfileDDL("radial")
        
        ; If radial menu is currently visible, force a full redraw
        if (IsMenuVisible) {
            global ForceRadialRedraw
            ForceRadialRedraw := true
        }
        
        ; Show tooltip notification
        ToolTip("Profile: " . ActiveProfile, A_ScreenWidth - 200, A_ScreenHeight - 50)
        SetTimer(RemoveToolTip, -1000)
    }
}

CreateProfile(profileType := "radial") {
    global IniPath, ProfilesIniPath, Stratagems, DefaultProfile
    
    ; Determine title based on profile type
    title := profileType = "keybind" ? "New Keybind Profile" : "New Profile"
    
    ; Prompt for new profile name
    IB := InputBox("Enter a name for the new profile:", title)
    if (IB.Result = "Cancel" || IB.Value = "")
        return
    
    newProfileName := Trim(IB.Value)
    if (newProfileName = "")
        return
    
    prefix := GetProfilePrefix(profileType)
    
    if (profileType = "keybind") {
        global ActiveKeybindProfile, ActiveKeybindStratagems, StratagemKeybinds, keybindProfileDDL
        
        ; Save current profile first
        SaveKeybindProfile()
        
        ; Unregister all hotkeys from current profile
        for id in StratagemKeybinds
            UnregisterStratagemHotkey(id)
        
        ; Switch to new profile
        ActiveKeybindProfile := newProfileName
        StratagemKeybinds := Map()
        ActiveKeybindStratagems := []
        
        ; Save to INI
        IniWrite("", ProfilesIniPath, prefix . ActiveKeybindProfile, "ActiveList")
        IniWrite(ActiveKeybindProfile, IniPath, "Settings", "ActiveKeybindProfile")
        
        ; Refresh the dropdown and list
        keybindProfileDDL.Delete()
        keybindProfileDDL.Add(GetProfilesList("keybind"))
        SetProfileDDL("keybind")
        UpdateKeybindsList()
        
        MsgBox("Created keybind profile: " . ActiveKeybindProfile, "Profile Created", 0x40)
    }
    else {
        global ActiveProfile, ActiveStratagems, ProfileDDL
        
        ; Save current profile first
        SaveProfiles()
        
        ; Switch to new profile
        ActiveProfile := newProfileName
        
        ; Clear stratagems for new profile
        ActiveStratagems := []
        
        ; Save to INI (creates the section with empty list)
        profileIniPath := GetRadialProfileIniPath(ActiveProfile)
        IniWrite("", profileIniPath, prefix . ActiveProfile, "ActiveList")
        IniWrite(ActiveProfile, IniPath, "Settings", "ActiveProfile")
        
        ; Refresh the dropdown and list
        ProfileDDL.Delete()
        ProfileDDL.Add(GetProfilesList("radial"))
        SetProfileDDL("radial")
        UpdateActiveList()
        
        MsgBox("Created profile: " . ActiveProfile, "Profile Created", 0x40)
    }
}

DeleteProfile(profileType := "radial") {
    global IniPath, ProfilesIniPath, Stratagems, DefaultProfile
    
    prefix := GetProfilePrefix(profileType)
    
    if (profileType = "keybind") {
        global ActiveKeybindProfile, ActiveKeybindStratagems, StratagemKeybinds, keybindProfileDDL
        
        if (ActiveKeybindProfile = DefaultProfile) {
            MsgBox("Cannot delete the Default profile!", "Error", 0x10)
            return
        }
        
        result := MsgBox("Delete keybind profile '" . ActiveKeybindProfile . "'?", "Confirm Delete", 0x24)
        if (result = "No")
            return
        
        ; Unregister all hotkeys
        for id in StratagemKeybinds
            UnregisterStratagemHotkey(id)
        
        ; Delete the profile section
        try {
            IniDelete(ProfilesIniPath, prefix . ActiveKeybindProfile)
        } catch {
        }
        
        ; Switch to Default profile
        ActiveKeybindProfile := DefaultProfile
        IniWrite(ActiveKeybindProfile, IniPath, "Settings", "ActiveKeybindProfile")
        
        ; Load Default profile's data
        StratagemKeybinds := Map()
        ActiveKeybindStratagems := []
        
        try {
            data := IniRead(ProfilesIniPath, prefix . DefaultProfile, "ActiveList", "")
            if data != "" {
                for id in StrSplit(data, ",") {
                    id := Trim(id)
                    if id != "" && Stratagems.Has(id)
                        ActiveKeybindStratagems.Push(id)
                }
            }
            
            ; Load hotkeys
            for id in ActiveKeybindStratagems {
                try {
                    hk := IniRead(ProfilesIniPath, prefix . DefaultProfile, id, "")
                    if (hk != "") {
                        StratagemKeybinds[id] := hk
                        RegisterStratagemHotkey(id, hk)
                    }
                }
            }
        } catch {
        }
        
        ; Refresh the dropdown and list
        keybindProfileDDL.Delete()
        keybindProfileDDL.Add(GetProfilesList("keybind"))
        SetProfileDDL("keybind")
        UpdateKeybindsList()
        
        MsgBox("Keybind profile deleted. Switched to: " . ActiveKeybindProfile, "Profile Deleted", 0x40)
    }
    else {
        global ActiveProfile, ActiveStratagems, ProfileDDL
        
        if (ActiveProfile = DefaultProfile) {
            MsgBox("Cannot delete the Default profile!", "Error", 0x10)
            return
        }
        
        ; Confirm deletion
        result := MsgBox("Delete profile '" . ActiveProfile . "'?", "Confirm Delete", 0x24)
        if (result = "No")
            return
        
        ; Delete the profile section
        try {
            profileIniPath := GetRadialProfileIniPath(ActiveProfile)
            IniDelete(profileIniPath, prefix . ActiveProfile)
        } catch {
        }
        
        ; Switch to Default profile
        ActiveProfile := DefaultProfile
        IniWrite(ActiveProfile, IniPath, "Settings", "ActiveProfile")
        
        ; Load Default profile's stratagems
        ActiveStratagems := []
        try {
            defaultProfileIniPath := GetRadialProfileIniPath(DefaultProfile)
            data := IniRead(defaultProfileIniPath, prefix . DefaultProfile, "ActiveList", "")
            if data != "" {
                for id in StrSplit(data, ",") {
                    id := Trim(id)
                    if id != "" && Stratagems.Has(id)
                        ActiveStratagems.Push(id)
                }
            }
        } catch {
        }
        
        ; Refresh the dropdown and list
        ProfileDDL.Delete()
        ProfileDDL.Add(GetProfilesList("radial"))
        SetProfileDDL("radial")
        UpdateActiveList()
        
        MsgBox("Profile deleted. Switched to: " . ActiveProfile, "Profile Deleted", 0x40)
    }
}

; Helper function for profile prefix
GetProfilePrefix(profileType) {
    return profileType = "keybind" ? "KeybindProfile_" : "Profile_"
}

GetRadialProfileIniPath(profileName) {
    global ProfilesIniPath, OCRProfileIniPath
    return (profileName = "OCR") ? OCRProfileIniPath : ProfilesIniPath
}

; Event handlers for GUI controls
SwitchProfileDDLHandler(*) => SwitchProfile("radial")
SwitchKeybindProfileDDLHandler(*) => SwitchProfile("keybind")
CreateRadialProfileHandler(*) => CreateProfile("radial")
CreateKeybindProfileHandler(*) => CreateProfile("keybind")
DeleteRadialProfileHandler(*) => DeleteProfile("radial")
DeleteKeybindProfileHandler(*) => DeleteProfile("keybind")

RemoveToolTip() {
    ToolTip()
}

OnRadialMenuKeyChange() {
    global RadialMenuKey, radialMenuKeyInput
    RadialMenuKey := radialMenuKeyInput.GetValue()
    SetRadialMenuHotkey()
    SaveSettings()
    UpdateHelpText()
}

OnRadialMenuKeyWildcardChange() {
    global RadialMenuKeyWildcard, radialMenuKeyInput
    RadialMenuKeyWildcard := radialMenuKeyInput.GetWildcard()
    SetRadialMenuHotkey()
    SaveSettings()
}

OnRadialMenuKeyModeChange(*) {
    global RadialMenuKeyMode, radialMenuKeyModeDDL
    if (radialMenuKeyModeDDL.Value = 2)
        RadialMenuKeyMode := "Toggle"
    else
        RadialMenuKeyMode := "Hold"
    SaveSettings()
}

OnStratagemMenuKeyChange() {
    global StratagemMenuKey, stratagemMenuKeyInput
    StratagemMenuKey := stratagemMenuKeyInput.GetValue()
    SaveSettings()
}

OnProfileNextHotkeyChange() {
    global ProfileNextHotkey, profileNextHotkeyInput
    ProfileNextHotkey := profileNextHotkeyInput.GetValue()
    SetProfileSwitchHotkeys()
    SaveSettings()
}

OnProfileNextHotkeyWildcardChange() {
    global ProfileNextHotkeyWildcard, profileNextHotkeyInput
    ProfileNextHotkeyWildcard := profileNextHotkeyInput.GetWildcard()
    SetProfileSwitchHotkeys()
    SaveSettings()
}

OnProfilePrevHotkeyChange() {
    global ProfilePrevHotkey, profilePrevHotkeyInput
    ProfilePrevHotkey := profilePrevHotkeyInput.GetValue()
    SetProfileSwitchHotkeys()
    SaveSettings()
}

OnProfilePrevHotkeyWildcardChange() {
    global ProfilePrevHotkeyWildcard, profilePrevHotkeyInput
    ProfilePrevHotkeyWildcard := profilePrevHotkeyInput.GetWildcard()
    SetProfileSwitchHotkeys()
    SaveSettings()
}

OnKeybindListHotkeyChange() {
    global KeybindListHotkey, keybindListHotkeyInput
    KeybindListHotkey := keybindListHotkeyInput.GetValue()
    IniWrite(KeybindListHotkey, IniPath, "KeybindList", "ListToggleHotkey")
    SetKeybindListHotkey()
    UpdateHelpText2()
}

OnKeybindListHotkeyWildcardChange() {
    global KeybindListHotkeyWildcard, keybindListHotkeyInput
    KeybindListHotkeyWildcard := keybindListHotkeyInput.GetWildcard()
    IniWrite(KeybindListHotkeyWildcard ? "1" : "0", IniPath, "KeybindList", "ListToggleHotkeyWildcard")
    SetKeybindListHotkey()
}

OnOCRHotkeyChange() {
    global OCRHotkey, ocrHotkeyInput
    OCRHotkey := ocrHotkeyInput.GetValue()
    SaveSettings()
    SetOCRHotkey()
    UpdateHelpTextOCR()
}

OnOCRHotkeyWildcardChange() {
    global OCRHotkeyWildcard, ocrHotkeyInput
    OCRHotkeyWildcard := ocrHotkeyInput.GetWildcard()
    SaveSettings()
    SetOCRHotkey()
}

OnOCRBypassHotkeyChange() {
    global OCRBypassToggleHotkey, ocrBypassHotkeyInput
    OCRBypassToggleHotkey := ocrBypassHotkeyInput.GetValue()
    SaveSettings()
    SetOCRBypassToggleHotkey()
    UpdateHelpTextOCR()
}

OnOCRBypassHotkeyWildcardChange() {
    global OCRBypassToggleHotkeyWildcard, ocrBypassHotkeyInput
    OCRBypassToggleHotkeyWildcard := ocrBypassHotkeyInput.GetWildcard()
    SaveSettings()
    SetOCRBypassToggleHotkey()
}

OnOpenMapKeyChange() {
    global OpenMapKey, openMapKeyInput
    OpenMapKey := openMapKeyInput.GetValue()
    SaveSettings()
}

UpdateMenuInputType(*) {
    global MenuInputType
    MenuInputType := menuInputTypeDDL.Value
    SaveSettings()
}

UpdateInputLayout(*) {
    global InputLayout
    if (inputLayoutDDL.Value = 1)
        InputLayout := "Arrows"
    else if (inputLayoutDDL.Value = 2)
        InputLayout := "WASD"
    else if (inputLayoutDDL.Value = 3) {
        InputLayout := "Custom"
        ShowCustomKeysPopup()
    }
    SaveSettings()
}

; --- CUSTOM KEYS POPUP ---
ShowCustomKeysPopup() {
    global CustomUpKey, CustomDownKey, CustomLeftKey, CustomRightKey
    
    customKeysGui := Gui("+Owner" . settingsGui.Hwnd, "Custom Keys")
    customKeysGui.SetFont("s10", "Segoe UI")
    
    customKeysGui.Add("Text", "x30 y20 w70", "Up Key:")
    customUpInput := customKeysGui.Add("Hotkey", "w100 x+10 yp", CustomUpKey)
    
    customKeysGui.Add("Text", "x30 y+15 w70", "Down Key:")
    customDownInput := customKeysGui.Add("Hotkey", "w100 x+10 yp", CustomDownKey)
    
    customKeysGui.Add("Text", "x30 y+15 w70", "Left Key:")
    customLeftInput := customKeysGui.Add("Hotkey", "w100 x+10 yp", CustomLeftKey)
    
    customKeysGui.Add("Text", "x30 y+15 w70", "Right Key:")
    customRightInput := customKeysGui.Add("Hotkey", "w100 x+10 yp", CustomRightKey)
    
    customKeysGui.Add("Button", "w85 h30 x30 y+20", "Save").OnEvent("Click", (*) => SaveCustomKeys(customUpInput, customDownInput, customLeftInput, customRightInput, customKeysGui))
    customKeysGui.Add("Button", "w85 h30 x+10 yp", "Cancel").OnEvent("Click", (*) => customKeysGui.Hide())
    
    customKeysGui.Show("w245")
}

SaveCustomKeys(upCtrl, downCtrl, leftCtrl, rightCtrl, guiCtrl) {
    global CustomUpKey, CustomDownKey, CustomLeftKey, CustomRightKey
    
    CustomUpKey := upCtrl.Value != "" ? upCtrl.Value : "w"
    CustomDownKey := downCtrl.Value != "" ? downCtrl.Value : "s"
    CustomLeftKey := leftCtrl.Value != "" ? leftCtrl.Value : "a"
    CustomRightKey := rightCtrl.Value != "" ? rightCtrl.Value : "d"
    
    SaveSettings()
    guiCtrl.Hide()
    MsgBox("Custom keys saved!`nUp: " CustomUpKey "`nDown: " CustomDownKey "`nLeft: " CustomLeftKey "`nRight: " CustomRightKey, "Custom Keys", 0x40)
}

UpdatePostMenuDelay(*) {
    global PostMenuDelay
    PostMenuDelay := (postMenuDelayEdit.Value = "") ? 0 : Integer(postMenuDelayEdit.Value)
    SaveSettings()
}

UpdateRealKeyDelay(*) {
    global RealKeyDelay
    RealKeyDelay := (realKeyDelayEdit.Value = "") ? 0 : Integer(realKeyDelayEdit.Value)
    SaveSettings()
}

UpdateSuspendHotkey(*) {
    global SuspendHotkey
    SuspendHotkey := suspendHotkeyInput.Value
    SetSuspendHotkey()
    SaveSettings()
}

UpdateExitHotkey(*) {
    global ExitHotkey
    ExitHotkey := exitHotkeyInput.Value
    SetExitHotkey()
    SaveSettings()
}

UpdateDisplayToggleHotkey(*) {
    global DisplayToggleHotkey
    DisplayToggleHotkey := displayToggleHotkeyInput.Value
    SetDisplayToggleHotkey()
    SaveSettings()
    UpdateHelpText()
}

UpdateHelpText() {
    global helpText1, RadialMenuKey, DisplayToggleHotkey
    radialKey := RadialMenuKey != "" ? RadialMenuKey : "Not Set"
    toggleKey := DisplayToggleHotkey != "" ? DisplayToggleHotkey : "Not Set"
    helpText1.Value := radialKey " - Radial Menu Key | " toggleKey " - Show/Hide GUI"
}

UpdateHelpText2() {
    global helpText2, KeybindListHotkey
    listKey := KeybindListHotkey != "" ? KeybindListHotkey : "Not Set"
    helpText2.Value := listKey " - Floating List Overlay (Hold to drag)"
}

UpdateHelpTextOCR() {
    global helpTextOCR, OCRHotkey, OCRBypassToggleHotkey
    ocrKey := OCRHotkey != "" ? OCRHotkey : "Not Set"
    bypassKey := OCRBypassToggleHotkey != "" ? OCRBypassToggleHotkey : "Not Set"
    helpTextOCR.Value := ocrKey " - OCR Stratagem Scan | " bypassKey " - Scrambler Bypass Toggle"
}

UpdateMenuSize(*) {
    global MenuSize
    MenuSize := (menuSizeEdit.Value = "") ? 0 : Integer(menuSizeEdit.Value)
    SaveSettings()
	InvalidateRadialCache()
}

UpdateInnerRadius(*) {
    global InnerRadius
    InnerRadius := (innerRadiusEdit.Value = "") ? 0 : Integer(innerRadiusEdit.Value)
    SaveSettings()
	InvalidateRadialCache()
}

UpdateIconSize(*) {
    global IconSize
    IconSize := (iconSizeEdit.Value = "") ? 0 : Integer(iconSizeEdit.Value)
    SaveSettings()
	InvalidateRadialCache()
}

UpdateTextSize(*) {
    global TextSize
    TextSize := (textSizeEdit.Value = "") ? 0 : Integer(textSizeEdit.Value)
    ; Recreate font with new size
    global Radial_hFont, Radial_hFamily
    if (Radial_hFont != 0) {
        Gdip_DeleteFont(Radial_hFont)
        Radial_hFont := Gdip_FontCreate(Radial_hFamily, TextSize, 1)
    }
    InvalidateRadialCache()
    SaveSettings()
}

UpdateShowText(*) {
    global ShowText
    ShowText := showTextCheckbox.Value
    InvalidateRadialCache()
    SaveSettings()
}

UpdateGUIScale(*) {
    global GUIScale, guiScaleDDL
    GUIScale := Float(guiScaleDDL.Text)
    SaveSettings()
    Reload()
}

; --- PROFILE SWITCH HOTKEYS ---
; Dynamically switches between pass-through and blocking modes for profile cycling hotkeys
SetProfileSwitchHotkeys(passThrough := true) {
    global ProfileNextHotkey, ProfilePrevHotkey, ProfileNextHotkeyWildcard, ProfilePrevHotkeyWildcard
    optsNext := ProfileNextHotkeyWildcard ? "W" : ""
    optsPrev := ProfilePrevHotkeyWildcard ? "W" : ""
    ; When passThrough=true, use ~ prefix so keys pass through to other apps
    ; When passThrough=false, block keys (for use when RadialMenu or ListOverlay key is held)
    if (passThrough) {
        RegisterSimpleHotkey("~" . ProfileNextHotkey, CycleProfileNext, "ProfileNext", optsNext)
        RegisterSimpleHotkey("~" . ProfilePrevHotkey, CycleProfilePrev, "ProfilePrev", optsPrev)
    } else {
        RegisterSimpleHotkey(ProfileNextHotkey, CycleProfileNext, "ProfileNext", optsNext)
        RegisterSimpleHotkey(ProfilePrevHotkey, CycleProfilePrev, "ProfilePrev", optsPrev)
    }
}

; Universal profile cycling function - handles both Radial Menu and Keybind profiles
CycleProfile(direction) {
    global KeybindListDragMode, RadialMenuKey
    
    if (!KeybindListDragMode) {
        ; Check if RadialMenuKey is being held - strip wildcard prefix if present
        checkKey := RadialMenuKey
        if (SubStr(checkKey, 1, 1) = "*")
            checkKey := SubStr(checkKey, 2)
        
        ; If RadialMenuKey is not set, only allow profile switching in drag mode (KeybindList)
        ; This prevents error when calling GetKeyState with empty key
        if (checkKey = "") {
            Sleep(150)
            return
        }
        
        ; Only allow profile switching when RadialMenuKey is held
        if !GetKeyState(checkKey, "P") {
            Sleep(150)
            return
        }
    }
    
    if (KeybindListDragMode) {
        ; Keybind mode - switch Keybind profiles
        global ActiveKeybindProfile
        profiles := GetProfilesList("keybind")
        if (profiles.Length <= 1)
            return
        
        currentIndex := 0
        for index, name in profiles {
            if (name = ActiveKeybindProfile) {
                currentIndex := index
                break
            }
        }
        
        newIndex := direction = 1 ? currentIndex + 1 : currentIndex - 1
        if (newIndex > profiles.Length)
            newIndex := 1
        if (newIndex < 1)
            newIndex := profiles.Length
        
        SwitchProfile("keybind", profiles[newIndex])
    } else {
        ; Radial Menu mode - switch Radial profiles
        global ActiveProfile
        profiles := GetProfilesList()
        if (profiles.Length <= 1)
            return
        
        currentIndex := 0
        for index, name in profiles {
            if (name = ActiveProfile) {
                currentIndex := index
                break
            }
        }
        
        newIndex := direction = 1 ? currentIndex + 1 : currentIndex - 1
        if (newIndex > profiles.Length)
            newIndex := 1
        if (newIndex < 1)
            newIndex := profiles.Length
        
        SwitchProfile("radial", profiles[newIndex])
    }
    
    ; Small delay to prevent rapid profile switching
    Sleep(50)
}

CycleProfileNext(*) => CycleProfile(1)
CycleProfilePrev(*) => CycleProfile(-1)

; ===UNIVERSAL HOTKEY REGISTRATION===
; Registers a hotkey with optional wildcard (*) prefix and suspend exempt (S) option
; Tracks previous hotkey in static map for automatic cleanup
; Options: "S" = SuspendExempt (default), "W" = apply wildcard prefix, "SW" = both
RegisterSimpleHotkey(hotkeyName, callback, storageKey, options := "S") {
    static activeHotkeys := Map()
    
    ; Disable previous hotkey if exists
    if activeHotkeys.Has(storageKey) {
        try Hotkey(activeHotkeys[storageKey], callback, "Off")
    }
    
    if (hotkeyName = "") {
        if activeHotkeys.Has(storageKey)
            activeHotkeys.Delete(storageKey)
        return
    }
    
    ; Build hotkey string - apply wildcard if "W" in options
    hotkeyToSet := hotkeyName
    if (InStr(options, "W") && SubStr(hotkeyToSet, 1, 1) != "*")
        hotkeyToSet := "*" . hotkeyToSet
    
    ; Build options string - always "On", add "S" if "S" in options (default)
    hotkeyOptions := "On"
    if (InStr(options, "S"))
        hotkeyOptions .= " S"
    
    try {
        Hotkey(hotkeyToSet, callback, hotkeyOptions)
        activeHotkeys[storageKey] := hotkeyToSet
    }
}

SetSuspendHotkey() {
    global SuspendHotkey
    RegisterSimpleHotkey(SuspendHotkey, ToggleSuspend, "Suspend")
}

SetExitHotkey() {
    global ExitHotkey
    RegisterSimpleHotkey(ExitHotkey, (*) => ExitApp(), "Exit")
}

SetRadialMenuHotkey() {
    global RadialMenuKey, RadialMenuKeyWildcard
    opts := RadialMenuKeyWildcard ? "W" : ""
    RegisterSimpleHotkey(RadialMenuKey, RadialMenuDown, "RadialMenu", opts)
}

RadialMenuDown(*) {
    global RadialMenuKey, IsMenuVisible, IsExecutingMacro, BlockCameraBypass, radialGui, SelectedSector, ForceRadialRedraw
    global ScreenCX, ScreenCY, ActiveStratagems, OCRScramblerBypassEnabled, StratagemMenuKey, MenuInputType, PostMenuDelay, MenuOpenDelay
    global RadialMenuKeyMode, RadialMenuToggleActive
    global scramblerDidSwap

    if IsExecutingMacro
        return

    ; === TOGGLE MODE: Second press confirms selection ===
    if (IsMenuVisible && RadialMenuKeyMode = "Toggle") {
        ; Second press in toggle mode - confirm and execute
        SetTimer(WatchMouse, 0)
        ShowCursor(true), ClipCursor(false)

        choice := SelectedSector

        if IsSet(radialGui) && radialGui {
            radialGui.Destroy()
            radialGui := 0
        }

        if (BlockCameraBypass && !scramblerDidSwap) {
            EndCameraBypass()
        }

        SetProfileSwitchHotkeys(true)
        IsMenuVisible := false
        RadialMenuToggleActive := false

        ; Execute selected stratagem
        if (choice > 0) {
            if (OCRScramblerBypassEnabled) {
                slot := Icon_GetSlotByIndex(choice)
                if (slot > 0) {
                    RunScramblerMacro(slot)
                }
                Icon_DisposeCapturedIcons()
                global ScramblerRadialMode
                ScramblerRadialMode := false
                if (!BlockCameraBypass && StratagemMenuKey != "" && MenuInputType = 5) {
                    Sleep(25)
                    ExecuteKeyInput(StratagemMenuKey, MenuInputType, "up")
                    Sleep(25)
                }
            } else if (ActiveStratagems.Length > 0 && choice <= ActiveStratagems.Length) {
                RunMacro(ActiveStratagems[choice])
            }
            
            ; If driver stratagem call did a seat swap, release RMB after execution
            if (scramblerDidSwap)
                ReleaseDriverStratagemRMB()
        } else if (OCRScramblerBypassEnabled) {
            Icon_DisposeCapturedIcons()
            global ScramblerRadialMode
            ScramblerRadialMode := false
            if (!BlockCameraBypass && StratagemMenuKey != "") {
                Sleep(25)
                if (MenuInputType = 5)
                    ExecuteKeyInput(StratagemMenuKey, MenuInputType, "up")
                else
                    ExecuteKeyInput(StratagemMenuKey, MenuInputType, "down")
                Sleep(25)
            }
            
            ; If driver stratagem call did a seat swap, release RMB immediately
            if (scramblerDidSwap) {
                SendInput("{RButton up}")
                scramblerDidSwap := false
            }
        }
        return
    }

    ; Prevent re-entry in hold mode
    if (IsMenuVisible)
        return

; === SCRAMBLER BYPASS MODE ===
    ; When enabled, capture actual icon screenshots from in-game stratagem menu
    if (OCRScramblerBypassEnabled) {
        
        ; If Driver Stratagem Call is enabled and Driver Assistant is active,
        ; perform swap seats + hold RMB before opening stratagem menu
        scramblerDidSwap := PerformDriverStratagemCall()
        
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
        ; and driver didn't already swap seats (driver already holds RMB)
        ; (otherwise keep it open so RunScramblerMacro doesn't need to reopen it)
        if (menuWasOpened && BlockCameraBypass && !scramblerDidSwap) {
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
            ; or when driver swapped (menu kept open intentionally)
            if (menuWasOpened && (!BlockCameraBypass || scramblerDidSwap)) {
                if (MenuInputType = 5)
                    ExecuteKeyInput(StratagemMenuKey, MenuInputType, "up")
                else {
                    Sleep(25)
                    ExecuteKeyInput(StratagemMenuKey, MenuInputType, "down")
                    Sleep(25)
                    ExecuteKeyInput(StratagemMenuKey, MenuInputType, "up")
                }
            }
            ; If driver stratagem call did a seat swap, release RMB immediately
            if (scramblerDidSwap) {
                SendInput("{RButton up}")
                scramblerDidSwap := false
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

    ; Switch profile hotkeys to blocking mode (no pass-through while menu is active)
    SetProfileSwitchHotkeys(false)

    ; Set flag immediately to prevent re-entry
    IsMenuVisible := true
    SelectedSector := 0
    ForceRadialRedraw := true

    ; Lock camera if enabled (opens map + holds RMB to prevent camera movement)
    ; Skip if driver already swapped seats (RMB already held)
    if (BlockCameraBypass && !scramblerDidSwap) {
        StartCameraBypass()
    }

    ShowCursor(false)
    DllCall("mouse_event", "UInt", 0x8001, "UInt", 32768, "UInt", 32768, "UInt", 0, "UPtr", 0)
    DllCall("SetCursorPos", "Int", ScreenCX, "Int", ScreenCY)
    ; Restrict mouse movement to match radial menu size (half of MenuSize in each direction)
    ClipCursor(true, ScreenCX-MenuSize//2, ScreenCY-MenuSize//2, ScreenCX+MenuSize//2, ScreenCY+MenuSize//2)

    ; Destroy any existing radialGui before creating new one
    if IsSet(radialGui) && radialGui {
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

    SetTimer(WatchMouse, 10)

    ; In toggle mode, return immediately - don't wait for key release
    ; The second press will trigger the confirm handler
    if (RadialMenuKeyMode = "Toggle") {
        return
    }

    ; Wait for key release
    KeyWait(RadialMenuKey)

    ; Close menu and execute
    SetTimer(WatchMouse, 0)
    ShowCursor(true), ClipCursor(false)

    choice := SelectedSector

    if IsSet(radialGui) && radialGui {
        radialGui.Destroy()
        radialGui := 0
    }

    ; Release camera lock if enabled
    ; Skip if driver already swapped seats (RMB managed by ReleaseDriverStratagemRMB)
    if (BlockCameraBypass && !scramblerDidSwap) {
        EndCameraBypass()
    }

    ; Switch profile hotkeys back to pass-through mode
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
                
                ; Only release the hold key if in hold mode.
                if (!BlockCameraBypass && StratagemMenuKey != "" && MenuInputType = 5) {
                    Sleep(25)
                    ExecuteKeyInput(StratagemMenuKey, MenuInputType, "up")
                    Sleep(25)
                }
                
            ; If driver stratagem call did a seat swap
            if (scramblerDidSwap)
                ReleaseDriverStratagemRMB()
            } else if (ActiveStratagems.Length > 0 && choice <= ActiveStratagems.Length) {
                ; Normal mode
                RunMacro(ActiveStratagems[choice])
            }
        } else if (OCRScramblerBypassEnabled) {
            ; No choice made - dispose captured icons
            Icon_DisposeCapturedIcons()
            global ScramblerRadialMode
            ScramblerRadialMode := false
            
            ; Close stratagem menu if it was left open (no camera bypass or driver swapped)
            if ((!BlockCameraBypass || scramblerDidSwap) && StratagemMenuKey != "") {
                Sleep(25)
                if (MenuInputType = 5)
                    ExecuteKeyInput(StratagemMenuKey, MenuInputType, "up")
                else
                    ExecuteKeyInput(StratagemMenuKey, MenuInputType, "down")
                Sleep(25)
            }
            
            ; If driver stratagem call did a seat swap, release RMB immediately
            if (scramblerDidSwap) {
                SendInput("{RButton up}")
                scramblerDidSwap := false
            }
        }
}

; Execute macro using scrambler bypass - reads sequence live from detected row
RunScramblerMacro(slot) {
    global IsExecutingMacro, StratagemMenuKey, MenuInputType, PostMenuDelay, RealKeyDelay, MenuOpenDelay
    global CustomUpKey, CustomDownKey, CustomLeftKey, CustomRightKey, InputLayout, BlockCameraBypass
    global scramblerDidSwap

    IsExecutingMacro := true

    try {
        ; Open stratagem menu first (only if camera bypass is active and driver didn't swap;
        ; otherwise it was kept open from the capture phase or driver manages it)
        if (StratagemMenuKey != "" && BlockCameraBypass && !scramblerDidSwap) {
            ExecuteKeyInput(StratagemMenuKey, MenuInputType, "down")
            ; Wait for menu to fully open
            Sleep(MenuOpenDelay)
        }

        ; Now read the sequence from the open menu
        sequence := Icon_GetSequenceBySlot(slot)

        if !IsObject(sequence) || sequence.Length = 0 {
            ; Try to get sequence from OCR function
            sequence := OCR_GetDirectionsByRow(slot)
        }

        if !IsObject(sequence) || sequence.Length = 0 {
            ToolTip("Scrambler: No sequence for slot " slot, A_ScreenWidth - 260, A_ScreenHeight - 50)
            SetTimer(RemoveToolTip, -1200)
            return
        }

        ; Set up key mapping based on input layout
        if (InputLayout = "WASD") {
            keyMap := Map("Down","s","Up","w","Left","a","Right","d")
        } else if (InputLayout = "Custom") {
            keyMap := Map("Down", CustomDownKey, "Up", CustomUpKey, "Left", CustomLeftKey, "Right", CustomRightKey)
        } else {
            keyMap := Map("Down","Down","Up","Up","Left","Left","Right","Right")
        }

        ; Execute the arrow sequence
        for dir in sequence {
            realKey := keyMap[dir]
            SendInput("{Blind}{" realKey " Down}")
            Sleep(RealKeyDelay)
            SendInput("{Blind}{" realKey " Up}")
            Sleep(RealKeyDelay)
        }

    } finally {
        ; Release the stratagem menu key if in hold mode (when BlockCameraBypass is enabled)
        if (MenuInputType = 5 && StratagemMenuKey != "" && BlockCameraBypass)
            ExecuteKeyInput(StratagemMenuKey, MenuInputType, "up")

        IsExecutingMacro := false
    }
}

; --- MENU LOGIC (HOTKEYS) ---
SetDisplayToggleHotkey() {
    global DisplayToggleHotkey
    RegisterSimpleHotkey(DisplayToggleHotkey, ToggleSettingsGui, "DisplayToggle")
}

SetOCRHotkey() {
    global OCRHotkey, OCRHotkeyWildcard, OCRUseHold
    opts := OCRHotkeyWildcard ? "W" : ""
    if (OCRUseHold) {
        RegisterSimpleHotkey(OCRHotkey, OCRKeyboardHoldHandler, "OCRScan", opts)
    } else {
        RegisterSimpleHotkey(OCRHotkey, OCRAnalyzeAndSwitchProfile, "OCRScan", opts)
    }
}

OCRKeyboardHoldHandler(*) {
    global OCRHotkey, OCRHoldMs
    
    keyName := OCRHotkey
    while (SubStr(keyName, 1, 1) = "*" || SubStr(keyName, 1, 1) = "~")
        keyName := SubStr(keyName, 2)
    
    if (keyName = "")
        return
    
    startTick := A_TickCount
    while (GetKeyState(keyName, "P")) {
        if (A_TickCount - startTick >= OCRHoldMs) {
            OCRAnalyzeAndSwitchProfile()
            return
        }
        Sleep(10)
    }
    ; Key released before hold time - do nothing
}

SetOCRBypassToggleHotkey() {
    global OCRBypassToggleHotkey, OCRBypassToggleHotkeyWildcard, BypassUseHold
    opts := OCRBypassToggleHotkeyWildcard ? "W" : ""
    if (BypassUseHold) {
        RegisterSimpleHotkey(OCRBypassToggleHotkey, BypassKeyboardHoldHandler, "OCRBypassToggle", opts)
    } else {
        RegisterSimpleHotkey(OCRBypassToggleHotkey, ToggleOCRScramblerBypass, "OCRBypassToggle", opts)
    }
}

BypassKeyboardHoldHandler(*) {
    global OCRBypassToggleHotkey, BypassHoldMs
    
    keyName := OCRBypassToggleHotkey
    while (SubStr(keyName, 1, 1) = "*" || SubStr(keyName, 1, 1) = "~")
        keyName := SubStr(keyName, 2)
    
    if (keyName = "")
        return
    
    startTick := A_TickCount
    while (GetKeyState(keyName, "P")) {
        if (A_TickCount - startTick >= BypassHoldMs) {
            ToggleOCRScramblerBypass()
            return
        }
        Sleep(10)
    }
    ; Key released before hold time - do nothing
}

ToggleOCRScramblerBypass(*) {
    global OCRScramblerBypassEnabled, ScramblerSuppressDebug
    OCRScramblerBypassEnabled := !OCRScramblerBypassEnabled
    ScramblerSuppressDebug := OCRScramblerBypassEnabled
    SaveSettings()
    ToolTip("OCR Scrambler Bypass: " (OCRScramblerBypassEnabled ? "ON" : "OFF"), A_ScreenWidth - 260, A_ScreenHeight - 50)
    SetTimer(RemoveToolTip, -1200)
}

OCRAnalyzeAndSwitchProfile(*) {
    global IniPath, OCRProfileIniPath, ProfileDDL
    global StratagemMenuKey, MenuInputType, MenuOpenDelay

    ; Open stratagem menu before OCR scan so arrows are visible
    if (StratagemMenuKey != "") {
        if (MenuInputType = 5) {
            ; Hold mode: keep menu key pressed during scan
            ExecuteKeyInput(StratagemMenuKey, MenuInputType, "down")
            ; Give UI enough time to actually open the stratagem panel
            Sleep(MenuOpenDelay)
        } else {
            ; Other input types: trigger configured opening behavior
            ExecuteKeyInput(StratagemMenuKey, MenuInputType, "down")
            ; Extra delay so OCR starts only after panel is visible
            Sleep(MenuOpenDelay)
        }
    }

    detectedCount := 0
    try {
        detectedCount := OCR_ScanToProfile(OCRProfileIniPath, "OCR")
    } finally {
        if (StratagemMenuKey != "") {
            if (MenuInputType = 5) {
                ; Hold mode: just release the key
                ExecuteKeyInput(StratagemMenuKey, MenuInputType, "up")
            } else {
                ; Non-hold modes: press again to close stratagem panel
                Sleep(25)
                ExecuteKeyInput(StratagemMenuKey, MenuInputType, "down")
                Sleep(25)
                ExecuteKeyInput(StratagemMenuKey, MenuInputType, "up")
            }
        }
    }

    if (detectedCount <= 0) {
        ToolTip("OCR: no stratagems found", A_ScreenWidth - 240, A_ScreenHeight - 50)
        SetTimer(RemoveToolTip, -1500)
        return
    }

    if (ProfileDDL) {
        ProfileDDL.Delete()
        ProfileDDL.Add(GetProfilesList("radial"))
    }

    ; Force reload so repeated OCR scans refresh the same OCR profile too
    SwitchProfile("radial", "OCR", true)
    ToolTip("OCR profile loaded: " detectedCount, A_ScreenWidth - 240, A_ScreenHeight - 50)
    SetTimer(RemoveToolTip, -1500)
}

ToggleSettingsGui(*) {
    global settingsGui
    if (DllCall("IsWindowVisible", "Ptr", settingsGui.Hwnd))
        settingsGui.Hide()
    else
        settingsGui.Show()
}

global LastDrawnSector := -1
global LastDrawnMX := 0
global LastDrawnMY := 0
global ForceRadialRedraw := false
global RadialMenuToggleActive := false ; Used for toggle mode

WatchMouse() {
    global SelectedSector, LastDrawnSector, LastDrawnMX, LastDrawnMY, ForceRadialRedraw
    global OCRScramblerBypassEnabled, ScramblerRadialMode
    
    if !IsMenuVisible
        return
    
    ; In scrambler mode, check captured count
    if (OCRScramblerBypassEnabled && ScramblerRadialMode) {
        if Icon_GetCapturedCount() = 0
            return
    } else {
        if ActiveStratagems.Length = 0
            return
    }
    
    CoordMode("Mouse", "Screen")
    MouseGetPos(&mx, &my)
    dx := mx - ScreenCX, dy := my - ScreenCY
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
    
    ; Redraw if forced, sector changed, or mouse moved significantly
    if (ForceRadialRedraw || newSector != LastDrawnSector || Abs(mx - LastDrawnMX) > 3 || Abs(my - LastDrawnMY) > 3) {
        if IsSet(radialGui)
            DrawRadial(ScreenCX, ScreenCY, mx, my, newSector)
        LastDrawnSector := newSector
        LastDrawnMX := mx
        LastDrawnMY := my
        ForceRadialRedraw := false
    }
    
    SelectedSector := newSector
}

; Cache for loaded bitmaps - load once and reuse
GetCachedBitmap(iconPath) {
    global BitmapCache
    static cacheKey := ""
    
    if (iconPath = "")
        return 0
    
    ; Check if we need to clear cache (different set of icons)
    if BitmapCache.Has(iconPath)
        return BitmapCache[iconPath]
    
    ; Load and cache the bitmap
    pBitmap := Gdip_CreateBitmapFromFile(iconPath)
    if pBitmap
        BitmapCache[iconPath] := pBitmap
    return pBitmap
}

; Pre-load all bitmaps for current stratagems
PreloadBitmaps() {
    global ActiveStratagems, BitmapCache
    
    for stratID in ActiveStratagems {
        iconPath := FindIconPath(stratID)
        if (iconPath != "" && !BitmapCache.Has(iconPath)) {
            pBitmap := Gdip_CreateBitmapFromFile(iconPath)
            if pBitmap
                BitmapCache[iconPath] := pBitmap
        }
    }
}

; Pre-rendered static background bitmap
global Radial_StaticBitmap := 0
global Radial_StaticCount := 0

; Static GDI+ objects for drawing (created once)
global Radial_pBrush := 0
global Radial_pBrushHighlight := 0
global Radial_pBrushText := 0
global Radial_pBrushCursor := 0
global Radial_pPenLine := 0
global Radial_hFamily := 0
global Radial_hFont := 0
global Radial_hFormat := 0
global Radial_LastCount := 0

InitRadialGraphics() {
    global Radial_pBrush, Radial_pBrushHighlight, Radial_pBrushText, Radial_pBrushCursor
    global Radial_pPenLine, Radial_hFamily, Radial_hFont, Radial_hFormat, TextSize
    
    if (Radial_pBrush = 0) {
        Radial_pBrush := Gdip_BrushCreateSolid(0xAA222222)
        Radial_pBrushHighlight := Gdip_BrushCreateSolid(0xDDFFD700)
        Radial_pBrushText := Gdip_BrushCreateSolid(0xFFFFFFFF)
        Radial_pBrushCursor := Gdip_BrushCreateSolid(0xFFFFFFFF)
        Radial_pPenLine := Gdip_CreatePen(0xFFFFFFFF, 3)
        Radial_hFamily := Gdip_FontFamilyCreate("Segoe UI")
        Radial_hFont := Gdip_FontCreate(Radial_hFamily, TextSize, 1)
        Radial_hFormat := Gdip_StringFormatCreate(0x4000)
        DllCall("gdiplus\GdipSetStringFormatAlign", "Ptr", Radial_hFormat, "Int", 1)
    }
}

; Pre-render the static background (sectors, icons, text) - called once when menu opens
CreateStaticBackground() {
    global Radial_StaticBitmap, Radial_StaticCount
    global Radial_pBrush, Radial_pBrushText, Radial_pBrushHighlight
    global Radial_hFont, Radial_hFormat, MenuSize, InnerRadius, IconSize
    
    count := ActiveStratagems.Length
    if (count == 0)
        return
    
    ; Clean up previous static bitmap if count changed
    if (Radial_StaticCount != count) {
        if (Radial_StaticBitmap != 0) {
            Gdip_DisposeImage(Radial_StaticBitmap)
            Radial_StaticBitmap := 0
        }
    }
    
    ; Already cached with same count
    if (Radial_StaticBitmap != 0 && Radial_StaticCount = count)
        return
    
    Radial_StaticCount := count
    sectorAngle := 360 / count
    mid := MenuSize // 2
    
    ; Create the static background bitmap with transparency
    Radial_StaticBitmap := Gdip_CreateBitmap(MenuSize, MenuSize)
    pGraphics := Gdip_GraphicsFromImage(Radial_StaticBitmap)
    Gdip_SetSmoothingMode(pGraphics, 4)
    Gdip_SetInterpolationMode(pGraphics, 7)
    
    ; Clear to transparent
    Gdip_GraphicsClear(pGraphics, 0x00000000)
    
    ; Pre-create alternate brush
    pBrushAlt := Gdip_BrushCreateSolid(0xAA333333)

    ; Draw static sectors (without highlight)
    Loop count {
        startA := -90 - (sectorAngle / 2) + (A_Index - 1) * sectorAngle
        
        ; Draw sector with base color (no highlight)
        if (Mod(A_Index, 2)) {
            Gdip_FillPie(pGraphics, Radial_pBrush, 0, 0, MenuSize, MenuSize, startA, sectorAngle)
        } else {
            Gdip_FillPie(pGraphics, pBrushAlt, 0, 0, MenuSize, MenuSize, startA, sectorAngle)
        }
        
        rad := (startA + sectorAngle/2) * 3.14159 / 180
        dist := mid * 0.7
        tx := mid + Cos(rad) * dist
        ty := mid + Sin(rad) * dist

        stratID := ActiveStratagems[A_Index]
        iconPath := FindIconPath(stratID)
        
        ; Draw cached bitmap
        if (iconPath != "") {
            pBitmap := GetCachedBitmap(iconPath)
            if pBitmap {
                origW := Gdip_GetImageWidth(pBitmap)
                origH := Gdip_GetImageHeight(pBitmap)
                scale := Min(IconSize / origW, IconSize / origH)
                iw := Round(origW * scale)
                ih := Round(origH * scale)
                Gdip_DrawImage(pGraphics, pBitmap, tx - (iw/2), ty - (ih/2) - 15, iw, ih)
            }
        }

        ; Draw text (if enabled)
        if (ShowText) {
            name := StratagemNames[stratID]
            RectF := Buffer(16)
            NumPut("Float", tx-60, "Float", ty+15, "Float", 120, "Float", 20, RectF)
            DllCall("gdiplus\GdipDrawString", "Ptr", pGraphics, "WStr", name, "Int", -1, "Ptr", Radial_hFont, "Ptr", RectF, "Ptr", Radial_hFormat, "Ptr", Radial_pBrushText)
        }
    }
    
    ; Draw center hole (transparent)
    Gdip_SetCompositingMode(pGraphics, 1)
    pBrushClear := Gdip_BrushCreateSolid(0x00000000)
    Gdip_FillEllipse(pGraphics, pBrushClear, mid-InnerRadius, mid-InnerRadius, InnerRadius*2, InnerRadius*2)
    Gdip_DeleteBrush(pBrushClear)
    
    Gdip_DeleteBrush(pBrushAlt)
    Gdip_DeleteGraphics(pGraphics)
}

DrawRadial(cx, cy, mx, my, current) {
    global radialGui, OCRScramblerBypassEnabled, ScramblerRadialMode
    if !IsSet(radialGui) || !radialGui
        return

    ; In scrambler mode, use captured icons drawing
    if (OCRScramblerBypassEnabled && ScramblerRadialMode) {
        DrawScramblerRadial(cx, cy, mx, my, current)
        return
    }

    count := ActiveStratagems.Length
    if (count == 0)
        return
    
    ; Initialize GDI+ objects once
    InitRadialGraphics()
    
    ; Pre-load bitmaps on first draw
    static lastPreloadCount := 0
    if (lastPreloadCount != count) {
        PreloadBitmaps()
        lastPreloadCount := count
    }
    
    ; Create static background (cached after first call)
    CreateStaticBackground()
    
    sectorAngle := 360 / count
    mid := MenuSize // 2
    
    ; Create fresh frame buffer
    hbm := CreateDIBSection(MenuSize, MenuSize), hdc := CreateCompatibleDC()
    obm := SelectObject(hdc, hbm), pGraphics := Gdip_GraphicsFromHDC(hdc)
    Gdip_SetSmoothingMode(pGraphics, 4)
    Gdip_SetInterpolationMode(pGraphics, 7)
    
    ; Copy static background to frame (fast operation)
    if (Radial_StaticBitmap != 0) {
        Gdip_DrawImage(pGraphics, Radial_StaticBitmap, 0, 0, MenuSize, MenuSize)
    }
    
    ; Draw only the highlight for current sector (single operation)
    if (current > 0 && current <= count) {
        startA := -90 - (sectorAngle / 2) + (current - 1) * sectorAngle
        Gdip_FillPie(pGraphics, Radial_pBrushHighlight, 0, 0, MenuSize, MenuSize, startA, sectorAngle)
        
        ; Redraw icon and text for highlighted sector
        rad := (startA + sectorAngle/2) * 3.14159 / 180
        dist := mid * 0.7
        tx := mid + Cos(rad) * dist
        ty := mid + Sin(rad) * dist

        stratID := ActiveStratagems[current]
        iconPath := FindIconPath(stratID)
        
        if (iconPath != "") {
            pBitmap := GetCachedBitmap(iconPath)
            if pBitmap {
                origW := Gdip_GetImageWidth(pBitmap)
                origH := Gdip_GetImageHeight(pBitmap)
                scale := Min(IconSize / origW, IconSize / origH)
                iw := Round(origW * scale)
                ih := Round(origH * scale)
                Gdip_DrawImage(pGraphics, pBitmap, tx - (iw/2), ty - (ih/2) - 15, iw, ih)
            }
        }

        ; Draw text for highlighted sector (if enabled)
        if (ShowText) {
            name := StratagemNames[stratID]
            RectF := Buffer(16)
            NumPut("Float", tx-60, "Float", ty+15, "Float", 120, "Float", 20, RectF)
            DllCall("gdiplus\GdipDrawString", "Ptr", pGraphics, "WStr", name, "Int", -1, "Ptr", Radial_hFont, "Ptr", RectF, "Ptr", Radial_hFormat, "Ptr", Radial_pBrushText)
        }
    }

    ; Draw cursor line and dot
    Gdip_DrawLine(pGraphics, Radial_pPenLine, mid, mid, mx-cx+mid, my-cy+mid)
    Gdip_FillEllipse(pGraphics, Radial_pBrushCursor, mx-cx+mid-5, my-cy+mid-5, 10, 10)

    try {
        if IsSet(radialGui) && radialGui
            UpdateLayeredWindow(radialGui.Hwnd, hdc, cx-mid, cy-mid, MenuSize, MenuSize)
    }
    
    SelectObject(hdc, obm), DeleteObject(hbm), DeleteDC(hdc), Gdip_DeleteGraphics(pGraphics)
}

; --- SCRAMBLER RADIAL MENU DRAWING ---
; Draws captured icon screenshots directly into the radial menu
DrawScramblerRadial(cx, cy, mx, my, current) {
    global radialGui, MenuSize, InnerRadius, IconSize
    global IconCapturedIcons, IconCapturedCount
    
    if !IsSet(radialGui) || !radialGui
        return
    
    count := IconCapturedCount
    if (count = 0)
        return
    
    ; Initialize GDI+ objects
    InitRadialGraphics()
    
    sectorAngle := 360 / count
    mid := MenuSize // 2
    
    ; Create frame buffer
    hbm := CreateDIBSection(MenuSize, MenuSize)
    hdc := CreateCompatibleDC()
    obm := SelectObject(hdc, hbm)
    pGraphics := Gdip_GraphicsFromHDC(hdc)
    Gdip_SetSmoothingMode(pGraphics, 4)
    Gdip_SetInterpolationMode(pGraphics, 7)
    
    ; Clear to transparent
    Gdip_GraphicsClear(pGraphics, 0x00000000)
    
    ; Pre-create brushes for sectors
    pBrushBase := Gdip_BrushCreateSolid(0xAA222222)
    pBrushAlt := Gdip_BrushCreateSolid(0xAA333333)
    
    ; Draw sectors
    Loop count {
        startA := -90 - (sectorAngle / 2) + (A_Index - 1) * sectorAngle
        
        ; Highlight current sector
        if (A_Index = current) {
            Gdip_FillPie(pGraphics, Radial_pBrushHighlight, 0, 0, MenuSize, MenuSize, startA, sectorAngle)
        } else {
            ; Alternate colors for non-selected sectors
            if (Mod(A_Index, 2))
                Gdip_FillPie(pGraphics, pBrushBase, 0, 0, MenuSize, MenuSize, startA, sectorAngle)
            else
                Gdip_FillPie(pGraphics, pBrushAlt, 0, 0, MenuSize, MenuSize, startA, sectorAngle)
        }
        
        ; Calculate icon position
        rad := (startA + sectorAngle/2) * 3.14159 / 180
        dist := mid * 0.65
        tx := mid + Cos(rad) * dist
        ty := mid + Sin(rad) * dist
        
        ; Get the captured icon bitmap
        iconBitmap := Icon_GetBitmapByIndex(A_Index)
        if (iconBitmap != 0) {
            ; Get original dimensions
            origW := Gdip_GetImageWidth(iconBitmap)
            origH := Gdip_GetImageHeight(iconBitmap)
            
            ; Scale to fit IconSize
            scale := Min(IconSize / origW, IconSize / origH)
            iw := Round(origW * scale)
            ih := Round(origH * scale)
            
            ; Draw the captured icon centered in sector
            Gdip_DrawImage(pGraphics, iconBitmap, tx - (iw/2), ty - (ih/2), iw, ih)
        }
    }
    
    ; Draw center hole (transparent)
    Gdip_SetCompositingMode(pGraphics, 1)
    pBrushClear := Gdip_BrushCreateSolid(0x00000000)
    Gdip_FillEllipse(pGraphics, pBrushClear, mid-InnerRadius, mid-InnerRadius, InnerRadius*2, InnerRadius*2)
    Gdip_DeleteBrush(pBrushClear)
    Gdip_SetCompositingMode(pGraphics, 0)
    
    ; Draw cursor line and dot
    Gdip_DrawLine(pGraphics, Radial_pPenLine, mid, mid, mx-cx+mid, my-cy+mid)
    Gdip_FillEllipse(pGraphics, Radial_pBrushCursor, mx-cx+mid-5, my-cy+mid-5, 10, 10)
    
    ; Cleanup brushes
    Gdip_DeleteBrush(pBrushBase)
    Gdip_DeleteBrush(pBrushAlt)
    
    ; Update the layered window
    try {
        if IsSet(radialGui) && radialGui
            UpdateLayeredWindow(radialGui.Hwnd, hdc, cx-mid, cy-mid, MenuSize, MenuSize)
    }
    
    ; Cleanup GDI objects
    SelectObject(hdc, obm)
    DeleteObject(hbm)
    DeleteDC(hdc)
    Gdip_DeleteGraphics(pGraphics)
}

; --- UNIVERSAL INPUT TYPE FUNCTION ---
; Parameters: keyName - The key to press, inputTypeVal - The input type(1-5), action - "down" to press key, "up" to release key, "full" for complete press cycle, Returns: true if key is being held 
ExecuteKeyInput(keyName, inputTypeVal, action := "full") {
    if (action = "down") {
        ; Press the key based on input type
        if (inputTypeVal = 1) {  ; Tap
            SendInput("{" keyName " Down}")
            Sleep(25)
            SendInput("{" keyName " Up}")
        }
        else if (inputTypeVal = 2) {  ; Double Tap
            SendInput("{" keyName " Down}")
            Sleep(25)
            SendInput("{" keyName " Up}")
            Sleep(25)
            SendInput("{" keyName " Down}")
            Sleep(25)
            SendInput("{" keyName " Up}")
        }
        else if (inputTypeVal = 3) {  ; Press
            SendInput("{" keyName " Down}")
            Sleep(25)
            SendInput("{" keyName " Up}")
        }
        else if (inputTypeVal = 4) {  ; Long Press
            SendInput("{" keyName " Down}")
            Sleep(300)
            SendInput("{" keyName " Up}")
        }
        else if (inputTypeVal = 5) {  ; Hold - keep key down
            SendInput("{" keyName " Down}")
            return true  ; Key is being held
        }
    }
    else if (action = "up") {
        ; Release key (primarily for Hold type)
        SendInput("{" keyName " Up}")
    }
    else if (action = "full") {
        ; Full cycle: press and release based on type
        if (inputTypeVal = 5) {  ; Hold - for full cycle, just do down/up
            SendInput("{" keyName " Down}")
            Sleep(25)
            SendInput("{" keyName " Up}")
        }
        else {
            ; All other types - just call down action (they handle their own release)
            ExecuteKeyInput(keyName, inputTypeVal, "down")
        }
    }
    return false
}

; --- MACRO AND DATABASE ---
ExecuteSequence(sequence) {
    global CustomUpKey, CustomDownKey, CustomLeftKey, CustomRightKey
    
    if (InputLayout = "WASD") {
        keyMap := Map("Down","s","Up","w","Left","a","Right","d")
    } else if (InputLayout = "Custom") {
        keyMap := Map("Down", CustomDownKey, "Up", CustomUpKey, "Left", CustomLeftKey, "Right", CustomRightKey)
    } else {
        keyMap := Map("Down","Down","Up","Up","Left","Left","Right","Right")
    }
    
    for dir in sequence {
        realKey := keyMap[dir]
        SendInput("{Blind}{" realKey " Down}")
        Sleep(RealKeyDelay)
        SendInput("{Blind}{" realKey " Up}")
        Sleep(RealKeyDelay)
    }
    return true
}

ResolveExecutionSequence(id) {
    global Stratagems

    if (id = "ocr_objective")
        return OCR_GetFirstDetectedDirections()

    return Stratagems[id]
}

ResolveBypassSequence(id) {
    global OCRScramblerBypassEnabled, OCR_DetectedRowsMap

    if (!OCRScramblerBypassEnabled)
        return ""

    if (!IsObject(OCR_DetectedRowsMap) || !OCR_DetectedRowsMap.Has(id))
        return ""

    row := OCR_DetectedRowsMap[id]
    if (row < 1)
        return ""

    return OCR_GetDirectionsByRow(row)
}

RunMacro(id) {
    global IsExecutingMacro, StratagemMenuKey, MenuInputType, PostMenuDelay, OCRScramblerBypassEnabled
    
    if !Stratagems.Has(id) 
        return

    if IsExecutingMacro
        return

    IsExecutingMacro := true

    try {
        sequence := ""
        menuWasOpened := false

        ; If Driver Stratagem Call is enabled and Driver Assistant is active,
        ; perform swap seats + hold RMB before opening stratagem menu
        didDriverSwap := PerformDriverStratagemCall()

        ; The OCR sequence is first read directly from the screen; then, the menu opens to execute the captured sequence.
        if (id = "ocr_objective") {
            sequence := ResolveExecutionSequence(id)
            if !IsObject(sequence) || sequence.Length = 0 {
                ToolTip("OCR objective: can't read sequence", A_ScreenWidth - 280, A_ScreenHeight - 50)
                SetTimer(RemoveToolTip, -1200)
                return
            }
        }

        ; Open stratagem menu first (needed for Scrambled Stratagems bypass live OCR read)
        if (MenuInputType = 5) {  ; Hold - keep key down during sequence
            ExecuteKeyInput(StratagemMenuKey, MenuInputType, "down")
            Sleep(PostMenuDelay)
        }
        else {
            ; All other types - press and release before sequence
            ExecuteKeyInput(StratagemMenuKey, MenuInputType, "down")
            Sleep(PostMenuDelay)
        }
        menuWasOpened := true

        if (id = "ocr_objective") {
            ; keep OCR objective sequence resolved above
        }
        else if (OCRScramblerBypassEnabled) {
            ; Bypass mode: must read live sequence from remembered OCR row.
            ; Give the stratagem menu time to appear before OCR reads the screen
            Sleep(PostMenuDelay)
            sequence := ResolveBypassSequence(id)
            if !IsObject(sequence) || sequence.Length = 0 {
                ToolTip("OCR bypass: can't read sequence", A_ScreenWidth - 260, A_ScreenHeight - 50)
                SetTimer(RemoveToolTip, -1200)
                return
            }
        } else {
            ; Normal mode
            sequence := ResolveExecutionSequence(id)
        }

        if !IsObject(sequence) || sequence.Length = 0
            return

        ExecuteSequence(sequence)
    } finally {
        ; Always release hold key
        if (menuWasOpened && MenuInputType = 5)
            ExecuteKeyInput(StratagemMenuKey, MenuInputType, "up")
        
        ; If driver stratagem call did a seat swap, release the RMB
        if (didDriverSwap)
            ReleaseDriverStratagemRMB()

        IsExecutingMacro := false
    }
}

ShowCursor(b) => DllCall("ShowCursor", "Int", b)
ClipCursor(c, x1:=0, y1:=0, x2:=0, y2:=0) {
    if !c 
        return DllCall("ClipCursor", "Ptr", 0)
    rect := Buffer(16), NumPut("Int",x1,rect,0), NumPut("Int",y1,rect,4), NumPut("Int",x2,rect,8), NumPut("Int",y2,rect,12)
    DllCall("ClipCursor", "Ptr", rect)
}

; Exit routine to clean up GUI and release keys on script exit
ExitRoutine(*) {
    global RadialMenuKey, BlockCameraBypass, OpenMapKey, IsMenuVisible, pToken, radialGui
    
    ; Destroy radial GUI if exists
    if (IsSet(radialGui) && radialGui) {
        try radialGui.Destroy()
        radialGui := 0
    }
    
    ; Safety: Only release keys if menu was visible
    if (IsMenuVisible) {
        ; Release radial menu key
        if (RadialMenuKey != "")
            SendInput("{" RadialMenuKey " Up}")
        
        ; If camera lock is enabled, release RMB and map key
        if (BlockCameraBypass) {
            SendInput("{RButton Up}")
            if (OpenMapKey != "")
                SendInput("{" OpenMapKey " Up}")
        }
    }
    
    ClipCursor(false), ShowCursor(true)
    if pToken
        Gdip_Shutdown(pToken)
}

; Error handler to clean up GUI and release keys if an error occurs while radial menu is open
ErrorHandler(e, mode) {
    global radialGui, IsMenuVisible, BlockCameraBypass, RadialMenuKey, OpenMapKey
    
    ; Destroy radial GUI if exists to prevent stuck overlay
    if (IsSet(radialGui) && radialGui) {
        try radialGui.Destroy()
        radialGui := 0
    }
    
    ; Reset menu state
    IsMenuVisible := false
    
    ; Release any held keys
    try {
        ClipCursor(false)
        ShowCursor(true)
        
        if (RadialMenuKey != "")
            SendInput("{" RadialMenuKey " Up}")
        
        if (BlockCameraBypass) {
            SendInput("{RButton Up}")
            if (OpenMapKey != "")
                SendInput("{" OpenMapKey " Up}")
        }
    }
    
    ; Return 0 to continue with default error handling (show error message)
    return 0
}

; --- GAME CHECK FUNCTIONS (for auto-pause and auto-close) ---
ToggleAutoPause(*) {
    global AutoPauseActive, GameCheckTimerInterval, IsAutoPaused, AutoCloseActive
    
    AutoPauseActive := autoPauseCheckbox.Value
    IniWrite(AutoPauseActive, IniPath, "Settings", "AutoPauseActive")
    
    ; Start timer if either auto-pause or auto-close is active
    if (AutoPauseActive || AutoCloseActive) {
        SetTimer(GameCheck, GameCheckTimerInterval)
    } else {
        SetTimer(GameCheck, 0)
        ; If currently auto-paused, resume
        if (IsAutoPaused) {
            IsAutoPaused := false
            Suspend(false)
        }
    }
    UpdateStatusIndicator()
}

ToggleAutoClose(*) {
    global AutoCloseActive, GameCheckTimerInterval, AutoPauseActive, AutoCloseCountdownActive
    
    AutoCloseActive := autoCloseCheckbox.Value
    IniWrite(AutoCloseActive, IniPath, "Settings", "AutoCloseActive")
    
    ; Cancel any active countdown when turning off auto-close
    if (!AutoCloseActive && AutoCloseCountdownActive) {
        AutoCloseCountdownActive := false
        ToolTip()
    }
    
    ; Start timer if either auto-pause or auto-close is active
    if (AutoPauseActive || AutoCloseActive) {
        SetTimer(GameCheck, GameCheckTimerInterval)
    } else {
        SetTimer(GameCheck, 0)
    }
}

ToggleAutoLanguageSwitch(*) {
    global AutoLanguageSwitch, autoLangCheckbox
    AutoLanguageSwitch := autoLangCheckbox.Value
    IniWrite(AutoLanguageSwitch ? "1" : "0", IniPath, "Settings", "AutoLanguageSwitch")
}

UpdateAutoLanguageLayout(*) {
    global AutoLanguageLayout, autoLangLayoutDDL, EnglishLayoutCodes
    selectedIdx := autoLangLayoutDDL.Value
    if (selectedIdx > 0 && selectedIdx <= EnglishLayoutCodes.Length) {
        AutoLanguageLayout := EnglishLayoutCodes[selectedIdx]
        IniWrite(AutoLanguageLayout, IniPath, "Settings", "AutoLanguageLayout")
    }
}

UpdateGameCheckTimer(*) {
    global GameCheckTimerInterval, AutoPauseActive, AutoCloseActive, gameCheckTimerEdit
    GameCheckTimerInterval := (gameCheckTimerEdit.Value = "") ? 0 : Integer(gameCheckTimerEdit.Value)
    if (GameCheckTimerInterval < 0 || GameCheckTimerInterval > 5000) {
        MsgBox("Interval should be between 0 and 5000ms.", "Error", 0x10)
        GameCheckTimerInterval := 500
        gameCheckTimerEdit.Value := 500
    }
    IniWrite(GameCheckTimerInterval, IniPath, "Settings", "GameCheckTimerInterval")
    
    ; Restart timer with new interval if active
    if (AutoPauseActive || AutoCloseActive) {
        SetTimer(GameCheck, 0)
        SetTimer(GameCheck, GameCheckTimerInterval)
    }
}

; Function to restore game focus after drag mode ends
RestoreGameFocus() {
    global GameProcessName, GameTarget
    ; Try to restore focus to the game window
    try {
        if WinExist("ahk_exe " GameProcessName) || WinExist(GameTarget) {
            WinActivate("ahk_exe " GameProcessName)
        }
    }
}

GameCheck() {
    global GameTarget, GameProcessName, IsAutoPaused, ScriptSuspended, AutoPauseActive, AutoCloseActive, AutoCloseCountdownActive
    global KeybindListDragMode
    
    ; Check if game process exists
    gameExists := GameProcessExist(GameProcessName)
    
    ; Auto-Pause: triggers when game is not active window OR game process doesn't exist
    if (AutoPauseActive) {
        if (gameExists && (WinActive("ahk_exe " GameProcessName) || WinActive(GameTarget))) {
            ; Game is active - if auto-paused, resume
            if (IsAutoPaused) {
                IsAutoPaused := false
                Suspend(false)
                UpdateStatusIndicator()
            }
        } else {
            ; Game is not active or doesn't exist - if not auto-paused, pause
            ; Skip pausing when dragging the floating keybind list to prevent drag interruption
            if (!IsAutoPaused && !A_IsSuspended && !KeybindListDragMode) {
                IsAutoPaused := true
                Suspend(true)
                UpdateStatusIndicator()
            }
        }
    }
    
    ; Auto-Close: triggers when game process doesn't exist
    if (AutoCloseActive && !gameExists) {
        ; Set countdown active flag
        AutoCloseCountdownActive := true
        
        ; Game process doesn't exist - start 3 second countdown
        Loop 3 {
            remaining := 3 - A_Index + 1
            ToolTip("Game closed. Exiting in " . remaining . "...", A_ScreenWidth - 200, A_ScreenHeight - 50)
            Sleep(1000)
            ; Check if countdown was cancelled (turned off auto-close)
            if !AutoCloseCountdownActive {
                ToolTip()
                return  ; Countdown cancelled
            }
            ; Check if game came back during countdown
            if GameProcessExist(GameProcessName) {
                AutoCloseCountdownActive := false
                ToolTip()
                return  ; Cancel countdown, game is back
            }
        }
        AutoCloseCountdownActive := false
        ToolTip()
        ExitApp()
    }
}

GameProcessExist(procName) {
    ; Check if game process exists
    try {
        DetectHiddenWindows(true)
        return WinExist("ahk_exe " procName)
    } catch {
        return false
    }
}

UpdateStatusIndicator() {
    global StatusText, IsAutoPaused, KeybindListGui, KeybindListWasVisibleBeforeSuspend
    
    wasActive := !(A_IsSuspended || IsAutoPaused)
    
    if (A_IsSuspended && !IsAutoPaused) {
        ; Manually suspended - RED
        StatusText.Opt("cFF0000")  ; Red
        StatusText.Value := "●"
        status := "Suspended"
    } else if (IsAutoPaused) {
        ; Auto-paused - YELLOW
        StatusText.Opt("cFFFF00")  ; Yellow
        StatusText.Value := "●"
        status := "AutoPaused"
    } else {
        ; Working normally - GREEN
        StatusText.Opt("c00FF00")  ; Green
        StatusText.Value := "●"
        status := "Active"
    }
    
    ; Handle Keybind List visibility based on status
    if (status = "Active") {
        ; Returning to Active - show list if it was visible before suspend
        if (KeybindListWasVisibleBeforeSuspend) {
            ShowKeybindList()
            KeybindListWasVisibleBeforeSuspend := false
        }
    } else {
        ; Going to Suspended/AutoPaused - hide list if visible and remember state
        if (IsSet(KeybindListGui) && KeybindListGui && WinExist("ahk_id " KeybindListGui.Hwnd) && DllCall("IsWindowVisible", "Ptr", KeybindListGui.Hwnd)) {
            KeybindListWasVisibleBeforeSuspend := true
            KeybindListGui.Hide()
        } else {
            KeybindListWasVisibleBeforeSuspend := false
        }
    }
    
    ; Show tooltip with current status
    ToolTip("Status: " . status, A_ScreenWidth - 200, A_ScreenHeight - 50)
    SetTimer(RemoveToolTip, -1500)
}

; Override ToggleSuspend to update status indicator
ToggleSuspend(*) {
    global ScriptSuspended, IsAutoPaused, AutoPauseActive
    
    ; If auto-pause is active and we're trying to manually toggle, disable auto-pause first
    if (AutoPauseActive && IsAutoPaused) {
        ; We're auto-paused, so manual suspend should just resume
        IsAutoPaused := false
        Suspend(false)
    } else {
        Suspend(-1) ; Toggle suspend state
    }
    
    ScriptSuspended := A_IsSuspended
    UpdateStatusIndicator()

    ; Re-register assistant hotkeys when unsuspending
    ; (Hotkeys get unregistered when saving settings while suspended, so we need to restore them)
    if !ScriptSuspended {
        UpdateWeaponAssistantStatus()
        UpdateDriverAssistantStatus()
        UpdateInventoryManagerStatus()
        UpdateWeaponQuickSwitchStatus()
    }
}

; --- CAMERA BYPASS FUNCTIONS ---
UpdateMapInputType(*) {
    global MapInputType
    MapInputType := mapInputTypeDDL.Value
    SaveSettings()
}

ToggleBlockCamera(*) {
    global BlockCameraBypass, OpenMapKey
    BlockCameraBypass := blockCameraCheckbox.Value
    IniWrite(BlockCameraBypass ? "1" : "0", IniPath, "Radial_Menu", "BlockCameraBypass")
}

StartCameraBypass(skipRMB := false) {
    global OpenMapKey, MapInputType, CameraBypassActive
    
    ; Prevent re-entry - if already active, don't run again
    if (CameraBypassActive)
        return
    
    CameraBypassActive := true
    
    ; Open map using universal function
    ExecuteKeyInput(OpenMapKey, MapInputType, "down")
    
    ; Only hold RMB if not skipped (for gamepad input)
    if (!skipRMB) {
        Sleep(25)
        SendInput("{RButton Down}")
    }
}

EndCameraBypass(skipRMB := false) {
    global OpenMapKey, MapInputType, CameraBypassActive
    
    ; Only run if camera bypass is actually active
    if (!CameraBypassActive)
        return
    
    ; Only release RMB if it was pressed (not skipped for gamepad)
    if (!skipRMB) {
        SendInput("{RButton Up}")
    }
    
    ; Close map - for Hold type release the key, for others tap to close
    if (MapInputType = 5) {  ; Hold - release the key
        ExecuteKeyInput(OpenMapKey, MapInputType, "up")
    }
    else {  ; All other types - tap to close
        ExecuteKeyInput(OpenMapKey, MapInputType, "down")
    }
    
    CameraBypassActive := false
    Sleep(100)
}

; --- FAVORITES FUNCTIONS ---
IsFavorite(id) => FavoriteStratagems.Has(id)

ToggleFavorite(*) {
    global lbAvailable, FavoriteStratagems
    
    row := lbAvailable.GetNext()
    if !row
        return
    
    id := lbAvailable.GetText(row, 3)  ; ID is in column 3
    if (id = "" || InStr(id, "category_") = 1)
        return
    
    ; Toggle favorite using Map operations (O(1))
    if FavoriteStratagems.Has(id)
        FavoriteStratagems.Delete(id)
    else
        FavoriteStratagems[id] := true
    
    ; Save and refresh list
    SaveFavorites()
    FilterAvailableList()
    
    ; Re-select the same item by finding it by ID
    Loop lbAvailable.GetCount() {
        if (lbAvailable.GetText(A_Index, 3) = id) {
            lbAvailable.Modify(A_Index, "Select Vis")
            break
        }
    }
}

ToggleFavoritesFilter(*) {
    global ShowFavoritesOnly
    ; Toggle favorites filter state
    ShowFavoritesOnly := !ShowFavoritesOnly
    FilterAvailableList()
}

SaveFavorites() {
    global FavoriteStratagems, IniPath
    
    str := ""
    for id in FavoriteStratagems
        str .= id ","
    IniWrite(RTrim(str, ","), IniPath, "Favorites", "List")
}

LoadFavorites() {
    global FavoriteStratagems, IniPath
    
    try {
        data := IniRead(IniPath, "Favorites", "List", "")
        if data != "" {
            for id in StrSplit(data, ",") {
                id := Trim(id)
                if id != ""
                    FavoriteStratagems[id] := true  ; Map key = id, value = true
            }
        }
    } catch {
    }
}

SelectAllAvailable(*) {
    global lbAvailable, selectionGui
    ; Only select all if selectionGui is active
    if !WinActive("ahk_id " selectionGui.Hwnd)
        return
    
    ; Select all visible stratagems
    Loop lbAvailable.GetCount() {
        type := lbAvailable.GetText(A_Index, 4)
        if (type != "CATEGORY") {
            lbAvailable.Modify(A_Index, "Select")
        }
    }
}

; --- KEYBIND SAVE/LOAD FUNCTIONS ---
; Note: Profile switching uses universal SwitchProfile("keybind"), CreateProfile("keybind"), DeleteProfile("keybind")

SaveKeybindProfile() {
    global ActiveKeybindProfile, ActiveKeybindStratagems, StratagemKeybinds, ProfilesIniPath
    
    section := "KeybindProfile_" . ActiveKeybindProfile
    
    ; Save stratagems list
    str := ""
    for id in ActiveKeybindStratagems
        str .= id ","
    IniWrite(RTrim(str, ","), ProfilesIniPath, section, "ActiveList")
    
    ; Save hotkeys as individual keys in the section
    for id, hk in StratagemKeybinds {
        if (hk != "")
            IniWrite(hk, ProfilesIniPath, section, id)
    }
}

LoadKeybindProfileData() {
    global ActiveKeybindProfile, ActiveKeybindStratagems, StratagemKeybinds, ProfilesIniPath
    
    section := "KeybindProfile_" . ActiveKeybindProfile
    
    try {
        ; Load stratagems list
        data := IniRead(ProfilesIniPath, section, "ActiveList", "")
        if data != "" {
            for id in StrSplit(data, ",") {
                id := Trim(id)
                if id != "" && Stratagems.Has(id)
                    ActiveKeybindStratagems.Push(id)
            }
        }
        
        ; Load hotkeys as individual keys from the section
        for id in ActiveKeybindStratagems {
            try {
                hk := IniRead(ProfilesIniPath, section, id, "")
                if (hk != "") {
                    StratagemKeybinds[id] := hk
                    RegisterStratagemHotkey(id, hk)
                }
            }
        }
    } catch {
    }
}

; Keybind Selection - reuse existing selectionGui
global isKeybindSelectionMode := false

ShowKeybindSelectionGui(*) {
    global isKeybindSelectionMode, selectionGui, searchEdit, lbAvailable, btnAddSel, ShowFavoritesOnly
    
    ; Set flag to indicate keybind selection mode
    isKeybindSelectionMode := true
    
    ; Reset search and filter
    searchEdit.Value := ""
    ShowFavoritesOnly := false
    PopulateAvailableList()
    
    ; Change button text (handler stays AddSelected which checks the flag)
    btnAddSel.Text := "Add to Keybinds"
    
    selectionGui.Show()
    Hotkey("~^a", SelectAllAvailable, "On S")
}


AddSelectedToKeybinds(*) {
    global lbAvailable, ActiveKeybindStratagems, isKeybindSelectionMode, ShowFavoritesOnly
    
    added := 0
    row := 0
    while (row := lbAvailable.GetNext(row)) {
        type := lbAvailable.GetText(row, 4)
        if type = "CATEGORY"
            continue
        
        id := lbAvailable.GetText(row, 3)
        if id != "" && Stratagems.Has(id) {
            ; Check for duplicates
            isDuplicate := false
            for existingId in ActiveKeybindStratagems {
                if (existingId = id) {
                    isDuplicate := true
                    break
                }
            }
            if !isDuplicate {
                ActiveKeybindStratagems.Push(id)
                added++
            }
        }
    }
    
    if added > 0 {
        SaveKeybindProfile()
        UpdateKeybindsList()
    }
    
    ; Reset flag and filter, then close
    isKeybindSelectionMode := false
    ShowFavoritesOnly := false
    
    Hotkey("~^a", SelectAllAvailable, "Off")
    selectionGui.Hide()
}

RemoveFromKeybinds(*) {
    global lbKeybinds, ActiveKeybindStratagems, StratagemKeybinds, ProfilesIniPath, ActiveKeybindProfile
    
    selectedRows := []
    row := 0
    while (row := lbKeybinds.GetNext(row)) {
        selectedRows.Push(row)
    }
    
    if (selectedRows.Length == 0)
        return
    
    section := "KeybindProfile_" . ActiveKeybindProfile
    
    ; Remove from end to preserve indices
    i := selectedRows.Length
    while (i > 0) {
        idx := selectedRows[i]
        if (idx <= ActiveKeybindStratagems.Length) {
            id := ActiveKeybindStratagems[idx]
            ; Unregister and remove hotkey
            UnregisterStratagemHotkey(id)
            if StratagemKeybinds.Has(id)
                StratagemKeybinds.Delete(id)
            ; Delete hotkey from INI
            try {
                IniDelete(ProfilesIniPath, section, id)
            }
            ActiveKeybindStratagems.RemoveAt(idx)
        }
        i--
    }
    
    SaveKeybindProfile()
    UpdateKeybindsList()
}

MoveKeybindItem(dir) {
    global lbKeybinds, ActiveKeybindStratagems
    
    idx := lbKeybinds.GetNext()
    if (dir = -1 && idx > 1) || (dir = 1 && idx > 0 && idx < ActiveKeybindStratagems.Length) {
        item := ActiveKeybindStratagems.RemoveAt(idx)
        ActiveKeybindStratagems.InsertAt(idx + dir, item)
        UpdateKeybindsList(idx + dir)
        SaveKeybindProfile()
    }
}

; Toggle visibility in floating list (star) - supports multiple selection
ToggleKeybindVisibility(*) {
    global lbKeybinds, ActiveKeybindStratagems, KeybindListVisibility, IniPath, ActiveKeybindProfile
    
    ; Collect all selected rows
    selectedRows := []
    row := 0
    while (row := lbKeybinds.GetNext(row)) {
        selectedRows.Push(row)
    }
    
    if (selectedRows.Length == 0)
        return
    
    ; Determine new visibility state based on first selected item
    firstStratID := ActiveKeybindStratagems[selectedRows[1]]
    makeVisible := KeybindListVisibility.Has(firstStratID)  ; If hidden, make visible; if visible, make hidden
    
    ; Process all selected rows
    for idx in selectedRows {
        if (idx > ActiveKeybindStratagems.Length)
            continue
        
        stratID := ActiveKeybindStratagems[idx]
        
        if (makeVisible) {
            ; Make visible - remove from visibility map
            if KeybindListVisibility.Has(stratID)
                KeybindListVisibility.Delete(stratID)
        } else {
            ; Make hidden - add to visibility map
            KeybindListVisibility[stratID] := true
        }
    }
    
    ; Save visibility setting
    SaveKeybindVisibility()
    UpdateKeybindsList()
}

SaveKeybindVisibility() {
    global KeybindListVisibility, ProfilesIniPath, ActiveKeybindProfile
    
    section := "KeybindProfile_" . ActiveKeybindProfile
    str := ""
    for id in KeybindListVisibility
        str .= id ","
    IniWrite(RTrim(str, ","), ProfilesIniPath, section, "Visibility")
}

LoadKeybindVisibility() {
    global KeybindListVisibility, ProfilesIniPath, ActiveKeybindProfile
    
    section := "KeybindProfile_" . ActiveKeybindProfile
    try {
        data := IniRead(ProfilesIniPath, section, "Visibility", "")
        if data != "" {
            for id in StrSplit(data, ",") {
                id := Trim(id)
                if id != ""
                    KeybindListVisibility[id] := true
            }
        }
    }
}

; Override UpdateKeybindsList to use ActiveKeybindStratagems
UpdateKeybindsList(selectIdx := 0) {
    global lbKeybinds, ActiveKeybindStratagems, StratagemKeybinds, IconIndexMap, StratagemNames, KeybindListVisibility
    
    lbKeybinds.Delete()
    lbKeybinds.Opt("-Redraw")
    
    for id in ActiveKeybindStratagems {
        name := StratagemNames.Has(id) ? StratagemNames[id] : id
        hotkey := StratagemKeybinds.Has(id) ? StratagemKeybinds[id] : ""
        ; Show eye if visible in floating list (default is visible = no entry in map = shown)
        eye := KeybindListVisibility.Has(id) ? "" : "👁"
        
        idx := (IconIndexMap.Has(id) && IconIndexMap[id] > 0) ? IconIndexMap[id] : 1
        lbKeybinds.Add("Icon" . idx, "", name, StrUpper(hotkey), eye)
    }
    
    lbKeybinds.Opt("+Redraw")
    
    if selectIdx {
        lbKeybinds.Modify(selectIdx, "Select Vis")
    }
    
    ; Refresh the floating keybind list overlay if visible
    RefreshKeybindListIfVisible()
}

; Keybind capture dialog
ShowKeybindCapture(*) {
    global lbKeybinds, ActiveKeybindStratagems, StratagemKeybinds
    
    ; Switch to English keyboard layout when opening popup
    SwitchToEnglishLayout()
    
    row := lbKeybinds.GetNext()
    if !row {
        MsgBox("Please select a stratagem.")
        return
    }
    
    if (row > ActiveKeybindStratagems.Length)
        return
    
    stratID := ActiveKeybindStratagems[row]
    name := StratagemNames.Has(stratID) ? StratagemNames[stratID] : stratID
    
    ; Create capture dialog
    captureGui := Gui("-Caption +LastFound", "Set Hotkey")
    captureGui.BackColor := "202020"
    captureGui.SetFont("s10 cC4C4C4", "Segoe UI")
    captureGui.MarginX := Scale(5)
    captureGui.MarginY := Scale(5)
    
    ; Title bar
    captureGui.SetFont("cFFFFFF s12")
    captureGui.Add("Text", "x0 y0 w" Scale(245) " h" Scale(26) " Background2A2A2A Border +Center", "Set Hotkey").OnEvent("Click", (*) => PostMessage(0xA1, 2,,, "A"))
    captureGui.Add("Button", "x+5 y0 w" Scale(26) " h" Scale(26), "X").OnEvent("Click", (*) => captureGui.Destroy())
    captureGui.SetFont("s12 cC4C4C4")
    
    captureGui.Add("Text", "x" Scale(10) " y" Scale(36) " w" Scale(260) " Center", "Press a key for:")
    captureGui.Add("Text", "x" Scale(10) " y+2 w" Scale(260) " Center cFFD700", name)
    
    currentHK := StratagemKeybinds.Has(stratID) ? StratagemKeybinds[stratID] : ""
    captureGui.Add("Text", "x" Scale(10) " y+10 w" Scale(260) " Center cGray", "Current: " (currentHK != "" ? currentHK : "None"))
    
    ; DropDownList for alternative keys with wildcard checkbox
    hkChoiceDDL := captureGui.Add("DropDownList", "x" Scale(80) " y+12 w" Scale(120) " Background2f2f2f", AltChoiceList)
    hkChoiceDDL.OnEvent("Change", (*) => SyncKeybindCaptureInputs("DDL", hkChoiceDDL, hkCtrl))
    
    ; Wildcard checkbox
    global hkWildcardCb
    hkWildcardCb := captureGui.Add("CheckBox", "x+5 yp vhkWildcardCb", "*")
    ; Check if current hotkey has wildcard prefix
    currentWildcard := false
    if (currentHK != "" && (SubStr(currentHK, 1, 1) = "*" || SubStr(currentHK, 1, 1) = "~")) {
        currentWildcard := true
        currentHK := SubStr(currentHK, 2)  ; Strip wildcard prefix for display
    }
    hkWildcardCb.Value := currentWildcard
    
    ; Hotkey control
    hkCtrl := captureGui.Add("Hotkey", "w" Scale(120) " x" Scale(80) " y+10 vHotkeyInput")
    if (currentHK != "")
        hkCtrl.Value := currentHK
    SetAltChoice(currentHK, hkChoiceDDL)
    hkCtrl.OnEvent("Change", (*) => SyncKeybindCaptureInputs("Hotkey", hkChoiceDDL, hkCtrl))
    hkCtrl.Focus()
    
    ; Save button
    btnSave := captureGui.Add("Button", "x" Scale(100) " y+15 w" Scale(80) " h" Scale(26) " Default", "Save")
    btnSave.OnEvent("Click", (*) => SaveHotkeyFromCapture(captureGui, hkChoiceDDL, hkCtrl, stratID))
    
    captureGui.OnEvent("Escape", (*) => captureGui.Destroy())
    
    captureGui.Show("w" Scale(280) " h" Scale(235))
}

; Sync function for keybind capture dialog
SyncKeybindCaptureInputs(source, choiceDDL, hkCtrl) {
    if (source = "Hotkey") {
        ; Hotkey control changed - if it has value, set DDL to "[Input]"
        if (hkCtrl.Value != "") {
            choiceDDL.Choose(1)
        }
    }
    else if (source = "DDL") {
        ; DropDownList changed - if not "[Input]", clear Hotkey control
        if (choiceDDL.Value != 1) {
            hkCtrl.Value := ""
        }
    }
}

SaveHotkeyFromCapture(guiCtrl, hkChoiceDDL, hkCtrl, stratID) {
    global StratagemKeybinds, ProfilesIniPath, ActiveKeybindProfile, hkWildcardCb
    
    ; Determine hotkey value: from DropDownList if not "[Input]", else from Hotkey control
    if (hkChoiceDDL.Value != 1) {
        newHK := AltChoiceList[hkChoiceDDL.Value]
    } else {
        newHK := hkCtrl.Value
    }
    
    ; Apply wildcard prefix if checkbox is checked
    if (newHK != "" && hkWildcardCb.Value) {
        newHK := "*" . newHK
    }
    
    ; Check if this hotkey is reserved (used in Settings or Misc tabs)
    reservedName := GetReservedHotkeyName(newHK)
    if (newHK != "" && reservedName != "") {
        MsgBox("Cannot use this hotkey!`n`n'" . newHK . "' is already used for: " . reservedName . "`n`nPlease choose a different hotkey.", "Hotkey Reserved", 0x10)
        return
    }
    
    section := "KeybindProfile_" . ActiveKeybindProfile
    
    ; Check if this hotkey is already used by another stratagem
    if (newHK != "") {
        for existingID, existingHK in StratagemKeybinds {
            if (existingHK = newHK && existingID != stratID) {
                ; Remove hotkey from the other stratagem
                UnregisterStratagemHotkey(existingID)
                StratagemKeybinds.Delete(existingID)
                try {
                    IniDelete(ProfilesIniPath, section, existingID)
                }
            }
        }
    }
    
    ; Unregister old hotkey if exists
    UnregisterStratagemHotkey(stratID)
    
    if (newHK != "") {
        StratagemKeybinds[stratID] := newHK
        RegisterStratagemHotkey(stratID, newHK)
    } else {
        ; Empty hotkey - remove from map and delete from INI
        if StratagemKeybinds.Has(stratID)
            StratagemKeybinds.Delete(stratID)
        ; Delete hotkey from INI (keep stratagem in ActiveList)
        try {
            IniDelete(ProfilesIniPath, section, stratID)
        }
    }
    
    SaveKeybindProfile()
    UpdateKeybindsList()
    guiCtrl.Destroy()
}

ClearSelectedKeybind(*) {
    global lbKeybinds, ActiveKeybindStratagems, StratagemKeybinds, ProfilesIniPath, ActiveKeybindProfile
    
    ; Collect all selected rows
    selectedRows := []
    row := 0
    while (row := lbKeybinds.GetNext(row)) {
        selectedRows.Push(row)
    }
    
    if (selectedRows.Length == 0)
        return
    
    section := "KeybindProfile_" . ActiveKeybindProfile
    clearedCount := 0
    
    ; Process from end to start to preserve indices
    for idx in selectedRows {
        if (idx > ActiveKeybindStratagems.Length)
            continue
        
        stratID := ActiveKeybindStratagems[idx]
        
        if StratagemKeybinds.Has(stratID) {
            UnregisterStratagemHotkey(stratID)
            StratagemKeybinds.Delete(stratID)
            ; Delete hotkey from INI (keep stratagem in ActiveList)
            try {
                IniDelete(ProfilesIniPath, section, stratID)
            }
            clearedCount++
        }
    }
    
    if (clearedCount > 0) {
        SaveKeybindProfile()
        UpdateKeybindsList()
    }
}

; Hotkey registration for stratagem keybinds
global RegisteredStratagemHotkeys := Map()

; Get the name of the reserved hotkey for error message
; Returns empty string if hotkey is not reserved
GetReservedHotkeyName(hotkeyStr) {
    global RadialMenuKey, DisplayToggleHotkey
    global SuspendHotkey, ExitHotkey, ProfileNextHotkey, ProfilePrevHotkey
    global KeybindListHotkey, OCRHotkey, OCRBypassToggleHotkey
    
    if (hotkeyStr = "")
        return ""
    
    ; Normalize hotkey for comparison (strip * and ~ prefixes)
    normalizedHK := hotkeyStr
    if (SubStr(normalizedHK, 1, 1) = "*" || SubStr(normalizedHK, 1, 1) = "~")
        normalizedHK := SubStr(normalizedHK, 2)
    
    ; Check each reserved hotkey and return its description
    reservedList := [
        [RadialMenuKey, "Radial Menu Key"],
        [DisplayToggleHotkey, "GUI Toggle"],
        [SuspendHotkey, "Suspend"],
        [ExitHotkey, "Exit"],
        [ProfileNextHotkey, "Next Profile"],
        [ProfilePrevHotkey, "Prev Profile"],
        [KeybindListHotkey, "Keybind List Overlay"],
        [OCRHotkey, "OCR Scan"],
        [OCRBypassToggleHotkey, "OCR Scrambler Bypass Toggle"]
    ]
    
    for item in reservedList {
        reservedHK := item[1]
        name := item[2]
        
        ; Normalize reserved hotkey for comparison
        normalizedReserved := reservedHK
        if (SubStr(normalizedReserved, 1, 1) = "*" || SubStr(normalizedReserved, 1, 1) = "~")
            normalizedReserved := SubStr(normalizedReserved, 2)
        
        if (StrLower(normalizedHK) = StrLower(normalizedReserved))
            return name
    }
    
    return ""
}

RegisterStratagemHotkey(id, hotkeyStr) {
    global RegisteredStratagemHotkeys
    
    ; Unregister previous hotkey if exists
    if RegisteredStratagemHotkeys.Has(id) {
        try Hotkey(RegisteredStratagemHotkeys[id], (*) => 0, "Off")
    }
    
    if (hotkeyStr = "")
        return
    
    try {
        Hotkey(hotkeyStr, (*) => ExecuteStratagemByKeybind(id), "On")
        RegisteredStratagemHotkeys[id] := hotkeyStr
    } catch {
        MsgBox("Invalid hotkey: " hotkeyStr, "Error", 0x10)
    }
}

UnregisterStratagemHotkey(id) {
    global RegisteredStratagemHotkeys
    
    if RegisteredStratagemHotkeys.Has(id) {
        try Hotkey(RegisteredStratagemHotkeys[id], (*) => 0, "Off")
        if RegisteredStratagemHotkeys.Has(id)
            RegisteredStratagemHotkeys.Delete(id)
    }
}

ExecuteStratagemByKeybind(id) {
    global Stratagems, IsExecutingMacro
    
    if !Stratagems.Has(id)
        return
    
    if IsExecutingMacro
        return

    RunMacro(id)
}

; Load keybind profile data on startup (after Stratagems data is loaded)
LoadKeybindProfileData()
LoadKeybindVisibility()

; Update keybinds list after GUI is created (called once on startup)
try {
    UpdateKeybindsList()
    SetProfileDDL("keybind")
} catch {
}

; --- KEYBIND LIST OVERLAY ---
global KeybindListDragMode := false
global KeybindListHoldTimer := false
global KeybindListHoldTriggered := false
global KeybindListWasVisibleBeforeSuspend := false
global KeybindListExecutingFromList := false

; --- Общая функция для обновления содержимого списка keybinds ---
; Возвращает объект с visibleCount, listWidth, listHeight, col1Width, col2Width, col3Width
UpdateKeybindListContent(lbControl) {
    global ActiveKeybindStratagems, StratagemKeybinds, StratagemNames, IconIndexMap, KeybindListVisibility
    global KeybindListShowIcon, KeybindListShowHotkey, KeybindListShowName
    global WeaponAssistantActive, DriverAssistantActive, CurrentWeaponMode, WeaponModeNames
    global ToggleWeaponHotkey, ToggleDriverHotkey, CycleWeaponModeHotkey, DA_E_Key
    
    ; Build list of assistant status rows when active
    assistantRows := []
    if (WeaponAssistantActive) {
        modeName := WeaponModeNames[CurrentWeaponMode]
        ; Show toggle hotkey / cycle hotkey
        wpHotkey := ""
        if (ToggleWeaponHotkey != "" && CycleWeaponModeHotkey != "")
            wpHotkey := StrUpper(ToggleWeaponHotkey) "/" StrUpper(CycleWeaponModeHotkey)
        else if (ToggleWeaponHotkey != "")
            wpHotkey := StrUpper(ToggleWeaponHotkey)
        else if (CycleWeaponModeHotkey != "")
            wpHotkey := StrUpper(CycleWeaponModeHotkey)
        assistantRows.Push({hotkey: wpHotkey, name: "Weapon: " modeName})
    }
    if (DriverAssistantActive) {
        ; Show toggle hotkey / exit vehicle key
        daHotkey := ""
        if (ToggleDriverHotkey != "" && DA_E_Key != "")
            daHotkey := StrUpper(ToggleDriverHotkey) "/" StrUpper(DA_E_Key)
        else if (ToggleDriverHotkey != "")
            daHotkey := StrUpper(ToggleDriverHotkey)
        else if (DA_E_Key != "")
            daHotkey := StrUpper(DA_E_Key)
        assistantRows.Push({hotkey: daHotkey, name: "Driver Assistant"})
    }
    
    ; Calculate column widths based on visible fields
    iconSizeScaled := Scale(32)
    col1Width := KeybindListShowIcon ? iconSizeScaled + Scale(6) : 0
    
    ; Calculate hotkey column width based on longest hotkey (including assistant rows)
    col2Width := 0
    if (KeybindListShowHotkey) {
        maxHotkeyLen := 0
        for id in ActiveKeybindStratagems {
            if KeybindListVisibility.Has(id)
                continue
            hotkey := StratagemKeybinds.Has(id) ? StrUpper(StratagemKeybinds[id]) : ""
            if (StrLen(hotkey) > maxHotkeyLen)
                maxHotkeyLen := StrLen(hotkey)
        }
        ; Check assistant row hotkeys too
        for row in assistantRows {
            if (StrLen(row.hotkey) > maxHotkeyLen)
                maxHotkeyLen := StrLen(row.hotkey)
        }
        ; Approximate width: ~8px per character + padding
        col2Width := Max(Scale(40), maxHotkeyLen * Scale(8) + Scale(10))
    }
    
    ; Calculate name column width based on longest name or assistant rows
    col3Width := 0
    if (KeybindListShowName) {
        maxNameLen := 0
        for id in ActiveKeybindStratagems {
            if KeybindListVisibility.Has(id)
                continue
            name := StratagemNames.Has(id) ? StratagemNames[id] : id
            if (StrLen(name) > maxNameLen)
                maxNameLen := StrLen(name)
        }
        ; Check assistant row names too
        for row in assistantRows {
            if (StrLen(row.name) > maxNameLen)
                maxNameLen := StrLen(row.name)
        }
        ; Approximate width: ~7px per character + padding
        col3Width := Max(Scale(80), maxNameLen * Scale(7) + Scale(15))
    }
    
    ; Total content width (sum of columns)
    contentWidth := col1Width + col2Width + col3Width
    if (contentWidth = 0)
        contentWidth := Scale(100) ; Minimum width if nothing selected
    
    ; Window width includes small padding
    listWidth := contentWidth + Scale(4)
    
    ; Update column widths
    lbControl.ModifyCol(1, col1Width)
    lbControl.ModifyCol(2, col2Width)
    lbControl.ModifyCol(3, col3Width)
    
    ; Populate the list with icons (only visible items - those WITHOUT entry in KeybindListVisibility)
    lbControl.Delete()
    lbControl.Opt("-Redraw")
    
    visibleCount := 0
    for id in ActiveKeybindStratagems {
        ; Skip if not visible (has entry in KeybindListVisibility = hidden)
        if KeybindListVisibility.Has(id)
            continue
        
        name := StratagemNames.Has(id) ? StratagemNames[id] : id
        hotkey := StratagemKeybinds.Has(id) ? StratagemKeybinds[id] : ""
        
        idx := (IconIndexMap.Has(id) && IconIndexMap[id] > 0) ? IconIndexMap[id] : 1
        ; Only show icon if setting is enabled
        iconOpt := KeybindListShowIcon ? "Icon" . idx : ""
        lbControl.Add(iconOpt, "", KeybindListShowHotkey ? StrUpper(hotkey) : "", KeybindListShowName ? name : "")
        visibleCount++
    }
    
    ; Add assistant status rows (each active assistant with green dot icon)
    if (assistantRows.Length > 0) {
        greenDotIdx := IconIndexMap.Has("__green_dot__") ? IconIndexMap["__green_dot__"] : 1
        for row in assistantRows {
            lbControl.Add("Icon" . greenDotIdx, "", KeybindListShowHotkey ? row.hotkey : "", KeybindListShowName ? row.name : "")
            visibleCount++
        }
    }
    
    ; Add "no bindings" message if list is empty
    if (visibleCount = 0) {
        lbControl.Add("", "", "", "No bindings")
        ; Center the "No bindings" text by adjusting column widths
        lbControl.ModifyCol(1, 0)
        lbControl.ModifyCol(2, 0)
        lbControl.ModifyCol(3, listWidth - Scale(4))
    }
    
    lbControl.Opt("+Redraw")
    
    ; Calculate height based on visible items
    if (visibleCount = 0) {
        listViewHeight := Scale(50)  ; Increased height for "No bindings" message
    } else {
        rowHeight := Scale(32) + Scale(4)
        listViewHeight := Max(Scale(50), visibleCount * rowHeight)  ; Ensure minimum height to prevent flattening
    }
    listHeight := Scale(25) + listViewHeight
    
    ; Return object with all calculated values
    return {visibleCount: visibleCount, listWidth: listWidth, listHeight: listHeight, 
            col1Width: col1Width, col2Width: col2Width, col3Width: col3Width, 
            listViewHeight: listViewHeight}
}

SetKeybindListHotkey() {
    global KeybindListHotkey, KeybindListHotkeyWildcard
    opts := KeybindListHotkeyWildcard ? "W" : ""
    RegisterSimpleHotkey(KeybindListHotkey, KeybindListHandler, "KeybindList", opts)
}

KeybindListHandler(*) {
    global KeybindListGui, KeybindListDragMode, KeybindListTransparency, KeybindListHotkey, IniPath, IsExecutingMacro
    global KeybindListExecutingFromList
    
    ; If macro is executing, just exit
    if (IsExecutingMacro)
        return
    
    ; If window is hidden - show it and exit
    if (!IsSet(KeybindListGui) || !KeybindListGui || !WinExist("ahk_id " KeybindListGui.Hwnd)) {
        ShowKeybindList()
        return
    }
    
    ; Window is visible - determine tap or hold
    KeybindListDragMode := false
    
    ; Start timer for drag mode activation
    SetTimer(ActivateDragMode, -KeybindListDragDelay)
    
    ; Wait for key release
    KeyWait(KeybindListHotkey)
    
    ; Cancel timer if still pending
    SetTimer(ActivateDragMode, 0)
    
    if (KeybindListDragMode) {
        ; Was in drag mode - restore transparency and save position
        KeybindListDragMode := false
        ; Switch profile hotkeys back to pass-through mode
        SetProfileSwitchHotkeys(true)
        if (IsSet(KeybindListGui) && KeybindListGui && WinExist("ahk_id " KeybindListGui.Hwnd)) {
            WinSetExStyle("+0x20", "ahk_id " KeybindListGui.Hwnd)
            WinSetTransparent(KeybindListTransparency, "ahk_id " KeybindListGui.Hwnd)
            
            try {
                WinGetPos(&x, &y,,, "ahk_id " KeybindListGui.Hwnd)
                IniWrite(x, IniPath, "KeybindList", "PosX")
                IniWrite(y, IniPath, "KeybindList", "PosY")
            }
        }
        ; Restore focus to game window after drag completes
        RestoreGameFocus()
    } else if (KeybindListExecutingFromList) {
        ; Stratagem was executed from list while key was released
        ; Switch profile hotkeys back to pass-through mode
        SetProfileSwitchHotkeys(true)
        KeybindListExecutingFromList := false
    } else {
        ; Quick tap - hide window
        KeybindListGui.Hide()
    }
}

ActivateDragMode() {
    global KeybindListGui, KeybindListDragMode
    
    KeybindListDragMode := true
    
    ; Switch profile hotkeys to blocking mode while in drag mode
    SetProfileSwitchHotkeys(false)
    
    if (IsSet(KeybindListGui) && KeybindListGui && WinExist("ahk_id " KeybindListGui.Hwnd)) {
        WinSetExStyle("-0x20", "ahk_id " KeybindListGui.Hwnd)
        WinSetTransparent(255, "ahk_id " KeybindListGui.Hwnd)
        
        ; Move cursor to title bar for dragging
        WinGetPos(&x, &y, &w,, "ahk_id " KeybindListGui.Hwnd)
        DllCall("SetCursorPos", "Int", x + (w // 2), "Int", y + Scale(12))
    }
}

ShowKeybindList(*) {
    global KeybindListGui, IL_ID, KeybindListTransparency, IniPath, ActiveKeybindProfile
    
    ; Create GUI if not exists
    if (!IsSet(KeybindListGui) || !KeybindListGui) {
        KeybindListGui := Gui("-Caption +LastFound +AlwaysOnTop +ToolWindow +E0x20", "Keybind List")
        KeybindListGui.BackColor := "202020"
        KeybindListGui.SetFont("s" Scale(10) " cC4C4C4", "Segoe UI")
        KeybindListGui.MarginX := Scale(5)
        KeybindListGui.MarginY := Scale(5)
        
        ; Title bar (draggable) - width will be updated dynamically
        KeybindListGui.SetFont("cFFFFFF s" Scale(11))
        titleText := KeybindListGui.Add("Text", "x0 y0 w100 h" Scale(25) " Background2A2A2A Border +Center", ActiveKeybindProfile)
        titleText.OnEvent("Click", (*) => PostMessage(0xA1, 2,,, "A"))
        KeybindListGui.SetFont("s" Scale(10) " cC4C4C4")
        
        ; ListView for keybinds with icons (height will be set dynamically)
        global lbKeybindList := KeybindListGui.Add("ListView", "x0 y" Scale(25) " w100 h1 Background000000 -Hdr -Multi -LV0x10", ["Icon", "Hotkey", "Name"])
        lbKeybindList.SetImageList(IL_ID, 1)
        lbKeybindList.OnEvent("DoubleClick", ExecuteStratagemFromList)
    }
    
    ; Use shared function to populate and calculate dimensions
    result := UpdateKeybindListContent(lbKeybindList)
    listWidth := result.listWidth
    listHeight := result.listHeight
    listViewHeight := result.listViewHeight
    
    ; Update title with current profile and resize
    try {
        for ctrl in KeybindListGui {
            if (ctrl.Type = "Text") {                
                ctrl.Move(,, listWidth, Scale(25))
                ctrl.Value := ActiveKeybindProfile
                break
            }
        }
    }
    
    ; Resize ListView
    lbKeybindList.Move(,, listWidth, listViewHeight)
    
    ; Show at saved position or center of screen
    try {
        savedX := IniRead(IniPath, "KeybindList", "PosX", "")
        savedY := IniRead(IniPath, "KeybindList", "PosY", "")
    } catch {
        savedX := ""
        savedY := ""
    }
    
    if (savedX != "" && savedY != "") {
        KeybindListGui.Show("Na x" savedX " y" savedY " w" listWidth " h" listHeight)
    } else {
        posX := (A_ScreenWidth - listWidth) // 2
        posY := (A_ScreenHeight - listHeight) // 2
        KeybindListGui.Show("Na x" posX " y" posY " w" listWidth " h" listHeight)
    }
    
    ; Set transparency after window is shown
    WinSetTransparent(KeybindListTransparency, "ahk_id " KeybindListGui.Hwnd)
    
    ; Ensure E0x20 style is set (click-through)
    WinSetExStyle("+0x20", "ahk_id " KeybindListGui.Hwnd)
}

; Refresh the keybind list overlay if it's visible
RefreshKeybindListIfVisible() {
    global KeybindListGui, lbKeybindList, KeybindListTransparency, KeybindListDragMode, ActiveKeybindProfile
    
    if (!IsSet(KeybindListGui) || !KeybindListGui || !WinExist("ahk_id " KeybindListGui.Hwnd))
        return
    
    ; Use shared function to populate and calculate dimensions
    result := UpdateKeybindListContent(lbKeybindList)
    listWidth := result.listWidth
    listHeight := result.listHeight
    listViewHeight := result.listViewHeight
    
    ; Update title with current profile and resize
    try {
        for ctrl in KeybindListGui {
            if (ctrl.Type = "Text") {                
                ctrl.Move(,, listWidth, Scale(25))
                ctrl.Value := ActiveKeybindProfile
                break
            }
        }
    }
    
    ; Resize ListView
    lbKeybindList.Move(,, listWidth, listViewHeight)
    
    ; Always resize window to fit content (NO activation - preserve game focus)
    WinGetPos(&x, &y,,, "ahk_id " KeybindListGui.Hwnd)
    KeybindListGui.Show("Na x" x " y" y " w" listWidth " h" listHeight)
    
    ; Show() resets transparency, so we need to set it again
    ; Use opaque (255) in drag mode, otherwise use configured transparency
    if (KeybindListDragMode) {
        WinSetTransparent(255, "ahk_id " KeybindListGui.Hwnd)
    } else {
        WinSetTransparent(KeybindListTransparency, "ahk_id " KeybindListGui.Hwnd)
    }
}

; Execute stratagem from floating list by double-click
ExecuteStratagemFromList(*) {
    global lbKeybindList, ActiveKeybindStratagems, KeybindListGui, KeybindListDragMode, KeybindListHotkey, KeybindListTransparency, KeybindListExecutingFromList
    
    row := lbKeybindList.GetNext()
    if !row
        return
    
    if (row > ActiveKeybindStratagems.Length)
        return
    
    stratID := ActiveKeybindStratagems[row]
    
    ; Set flag to indicate execution from list
    KeybindListExecutingFromList := true
    
    ; Reset drag mode
    KeybindListDragMode := false
    
    ; Hide list before execution
    if (IsSet(KeybindListGui) && KeybindListGui && WinExist("ahk_id " KeybindListGui.Hwnd)) {
        ; Save position before hiding
        try {
            WinGetPos(&x, &y,,, "ahk_id " KeybindListGui.Hwnd)
            IniWrite(x, IniPath, "KeybindList", "PosX")
            IniWrite(y, IniPath, "KeybindList", "PosY")
        }
        KeybindListGui.Hide()
    }
    
    ; Restore game focus before executing stratagem
    RestoreGameFocus()
    ; Execute the stratagem
    ExecuteStratagemByKeybind(stratID)
    
    ; Show list again after execution
    ShowKeybindList()
    
    ; Check if the keybind list hotkey is still being held
    if (GetKeyState(KeybindListHotkey, "P")) {
        ; Key is still held - activate drag mode
        KeybindListDragMode := true
        if (IsSet(KeybindListGui) && KeybindListGui && WinExist("ahk_id " KeybindListGui.Hwnd)) {
            ; Remove E0x20 style to make window clickable for dragging
            WinSetExStyle("-0x20", "ahk_id " KeybindListGui.Hwnd)
            ; Make window opaque for dragging
            WinSetTransparent(255, "ahk_id " KeybindListGui.Hwnd)
        }
    }
}

; Initialize keybind list hotkey on startup
SetKeybindListHotkey()

UpdateKeybindListTransparency(*) {
    global KeybindListTransparency, keybindListTransparencySlider, keybindListTransparencyText, KeybindListGui
    KeybindListTransparency := keybindListTransparencySlider.Value
    keybindListTransparencyText.Value := KeybindListTransparency
    IniWrite(KeybindListTransparency, IniPath, "KeybindList", "Transparency")
    
    ; Update transparency of visible window
    if (IsSet(KeybindListGui) && KeybindListGui && WinExist("ahk_id " KeybindListGui.Hwnd)) {
        WinSetTransparent(KeybindListTransparency, "ahk_id " KeybindListGui.Hwnd)
    }
}

UpdateKeybindListDragDelay(*) {
    global KeybindListDragDelay, keybindListDragDelayEdit
    KeybindListDragDelay := (keybindListDragDelayEdit.Value = "") ? 300 : Integer(keybindListDragDelayEdit.Value)
    if (KeybindListDragDelay < 50) {
        KeybindListDragDelay := 50
        keybindListDragDelayEdit.Value := 50
    }
    if (KeybindListDragDelay > 2000) {
        KeybindListDragDelay := 2000
        keybindListDragDelayEdit.Value := 2000
    }
    IniWrite(KeybindListDragDelay, IniPath, "KeybindList", "DragDelay")
}

UpdateKeybindListShowFields(*) {
    global KeybindListShowIcon, KeybindListShowHotkey, KeybindListShowName
    global keybindListShowIconCb, keybindListShowHotkeyCb, keybindListShowNameCb
    
    KeybindListShowIcon := keybindListShowIconCb.Value
    KeybindListShowHotkey := keybindListShowHotkeyCb.Value
    KeybindListShowName := keybindListShowNameCb.Value
    
    IniWrite(KeybindListShowIcon ? "1" : "0", IniPath, "KeybindList", "ShowIcon")
    IniWrite(KeybindListShowHotkey ? "1" : "0", IniPath, "KeybindList", "ShowHotkey")
    IniWrite(KeybindListShowName ? "1" : "0", IniPath, "KeybindList", "ShowName")
    
    RefreshKeybindListIfVisible()
}