#Requires AutoHotkey v2.0
#Include Gdip_All.ahk
#Include config.ahk

; Load GUI Scale from settings.ini
LoadGUIScale()

; ===GLOBAL VARIABLES===
; Input Settings
global StratagemMenuKey := "LControl", RadialMenuKey := "MButton", PostMenuDelay := 25, RealKeyDelay := 25, InputLayout := "Arrows"
global CustomUpKey := "w", CustomDownKey := "s", CustomLeftKey := "a", CustomRightKey := "d"
global MenuInputType := 5  ; 1=Tap, 2=Double Tap, 3=Press, 4=Long Press, 5=Hold
global SuspendHotkey := "Insert", ExitHotkey := "End", DisplayToggleHotkey := "F1"
global RadialMenuKeyWildcard := false

; Radial Menu UI
global MenuSize := 500, InnerRadius := 70, IconSize := 48, TextSize := 9, ShowText := true
global ScreenCX := A_ScreenWidth // 2, ScreenCY := A_ScreenHeight // 2

; State Tracking
global IsMenuVisible := false, SelectedSector := 0, IsExecutingMacro := false
global IniPath := A_ScriptDir "\settings.ini", radialGui := 0

; Game Check
global AutoPauseActive := false, AutoCloseActive := false, AutoCloseCountdownActive := false
global GameCheckTimerInterval := 500, GameTarget := "HELLDIVERS™ 2", GameProcessName := "helldivers2.exe"
global ScriptSuspended := false, IsAutoPaused := false, StatusText := 0

; Camera Bypass
global BlockCameraBypass := false, OpenMapKey := "Tab", MapInputType := 1, CameraBypassActive := false

; Profiles
global ActiveProfile := "Default", DefaultProfile := "Default", ProfileDDL := 0
global ProfileNextHotkey := "PgUp", ProfilePrevHotkey := "PgDn"
global ActiveStratagems := []

; Favorites
global FavoriteStratagems := Map(), ShowFavoritesOnly := false

; Alt Keys for DropDownList
AltKeys := ["LControl", "RControl", "LShift", "RShift", "LAlt", "RAlt", "LWin", "RWin", "Tab", "XButton1", "XButton2", "MButton"]
AltChoiceList := ["[Input]"]
for key in AltKeys
    AltChoiceList.Push(key)

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

; GDI+ Startup
global pToken := Gdip_Startup()
if !pToken {
    MsgBox("GDI+ Error. Please check if Gdip_All.ahk exists.")
    ExitApp()
}
OnExit(ExitRoutine)

LoadStratagemsData()
LoadSettings()
LoadFavorites()

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

mainTab := settingsGui.Add("Tab2", "x" Scale(10) " y" Scale(35) " w" Scale(400) " h" Scale(600), ["Radial Menu", "Settings"])
mainTab.OnEvent("Change", ClearTabFocus)

; ---Tab 1: Radial Menu---
mainTab.UseTab(1)

; Profile Section
settingsGui.Add("Text", "x" Scale(25) " y" Scale(65) " w" Scale(200), "📂 Profile:")
ProfileDDL := settingsGui.Add("DropDownList", "x" Scale(25) " y+" Scale(5) " w" Scale(370) " vProfileDDL Background2f2f2f", GetProfilesList())
ProfileDDL.OnEvent("Change", SwitchProfile)
SetProfileDDL()

btnNewProf := settingsGui.Add("Button", "w" Scale(180) " h" Scale(30) " x" Scale(25) " y+" Scale(5), "➕ New Profile")
btnNewProf.OnEvent("Click", CreateProfile)

btnDelProf := settingsGui.Add("Button", "w" Scale(180) " h" Scale(30) " x+" Scale(10) " yp", "❌ Delete Profile")
btnDelProf.OnEvent("Click", DeleteProfile)

; Active Stratagems Section and ListView
settingsGui.Add("Text", "x" Scale(25) " y+" Scale(15) " w" Scale(200), "Active Stratagems:")

lbActive := settingsGui.Add("ListView", "x" Scale(25) " y+" Scale(5) " r12 w" Scale(370) " h" Scale(350) " vActiveList Multi Background000000", ["Icon", "Name", "Category"])
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
settingsGui.Add("Text", "x" Scale(25) " y+" Scale(5) " cGray", "Run stratagem_editor.ahk to edit stratagems")
UpdateHelpText()

; ---Tab 2: Settings---
mainTab.UseTab(2)

settingsGui.Add("Text", "x" Scale(25) " y" Scale(65) " w" Scale(200), "Radial Menu Key:")
radialMenuKeyChoiceDDL := settingsGui.Add("DropDownList", "w" Scale(100) " x" Scale(25) " y+" Scale(5) " Background2f2f2f", AltChoiceList)
radialMenuKeyChoiceDDL.OnEvent("Change", SyncRadialMenuKeyInputs)
radialMenuKeyWildcardCheckbox := settingsGui.Add("CheckBox", "x+5 yp", "*")
radialMenuKeyWildcardCheckbox.Value := RadialMenuKeyWildcard
radialMenuKeyWildcardCheckbox.OnEvent("Click", (*) => UpdateRadialMenuKeyWildcard())
radialMenuKeyInput := settingsGui.Add("Hotkey", "w" Scale(100) " x" Scale(25) " y+" Scale(10), RadialMenuKey)
radialMenuKeyInput.OnEvent("Change", SyncRadialMenuKeyInputs)
SetAltChoice(RadialMenuKey, radialMenuKeyChoiceDDL)


settingsGui.Add("Text", "x" Scale(25) " y+" Scale(5) " w" Scale(200), "Stratagem Menu:")
stratagemMenuKeyChoiceDDL := settingsGui.Add("DropDownList", "w" Scale(100) " x" Scale(25) " y+" Scale(5) " Background2f2f2f", AltChoiceList)
stratagemMenuKeyChoiceDDL.OnEvent("Change", SyncStratagemMenuKeyInputs)
stratagemMenuKeyInput := settingsGui.Add("Hotkey", "w" Scale(100) " x" Scale(25) " y+" Scale(5), StratagemMenuKey)
stratagemMenuKeyInput.OnEvent("Change", SyncStratagemMenuKeyInputs)
SetAltChoice(StratagemMenuKey, stratagemMenuKeyChoiceDDL)

settingsGui.Add("Text", "x" Scale(25) " y+" Scale(5) " w" Scale(200), "Menu Input Type:")
menuInputTypeDDL := settingsGui.Add("DropDownList", "w" Scale(100) " x" Scale(25) " y+" Scale(5) " Background2f2f2f", ["Tap", "Double Tap", "Press", "Long Press", "Hold"])
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
settingsGui.Add("Text", "x" Scale(25) " y+" Scale(20) " w" Scale(200), "Profile Switch Hotkeys:")

profileNextHotkeyInput := settingsGui.Add("Hotkey", "w" Scale(100) " x" Scale(25) " y+" Scale(5), ProfileNextHotkey)
settingsGui.Add("Text", "x+5 w" Scale(85), "(Next Profile)")
profileNextHotkeyInput.OnEvent("Change", (*) => UpdateProfileNextHotkey())

profilePrevHotkeyInput := settingsGui.Add("Hotkey", "w" Scale(100) " x" Scale(25) " y+" Scale(10), ProfilePrevHotkey)
settingsGui.Add("Text", "x+5 w" Scale(85), "(Prev Profile)")
profilePrevHotkeyInput.OnEvent("Change", (*) => UpdateProfilePrevHotkey())

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
OpenMapKeyChoiceDDL := settingsGui.Add("DropDownList", "w" Scale(100) " x" Scale(265) " y+" Scale(5) " Background2f2f2f", AltChoiceList)
OpenMapKeyChoiceDDL.OnEvent("Change", SyncOpenMapKeyInputs)
OpenMapKeyInput := settingsGui.Add("Hotkey", "w" Scale(100) " x" Scale(265) " y+" Scale(5), OpenMapKey)
OpenMapKeyInput.OnEvent("Change", SyncOpenMapKeyInputs)
SetAltChoice(OpenMapKey, OpenMapKeyChoiceDDL)

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
    global ShowFavoritesOnly
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
    global selectionGui
    ; Disable the Ctrl+A hotkey when closing the popup
    Hotkey("~^a", SelectAllAvailable, "Off")
    selectionGui.Hide()
}

AddSelected(*) {
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
    IniWrite(RTrim(str, ","), IniPath, section, "ActiveList")
    
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
    
    ; Save Camera Bypass settings
    IniWrite(OpenMapKey, IniPath, "Radial_Menu", "OpenMapKey")
    IniWrite(MapInputType, IniPath, "Radial_Menu", "MapInputType")
}

LoadSettings() {
    global StratagemMenuKey, RadialMenuKey, RadialMenuKeyWildcard, InputType, InputLayout, PostMenuDelay, RealKeyDelay
    global SuspendHotkey, ExitHotkey, MenuSize, InnerRadius, IconSize, TextSize, ShowText, ScreenCX, ScreenCY, ActiveProfile, GUIScale
    global ProfileNextHotkey, ProfilePrevHotkey, DisplayToggleHotkey
    global AutoPauseActive, AutoCloseActive, GameCheckTimerInterval, BlockCameraBypass, OpenMapKey, MapInputType
    global CustomUpKey, CustomDownKey, CustomLeftKey, CustomRightKey
    
    try {
        ; Load active profile first
        ActiveProfile := IniRead(IniPath, "Settings", "ActiveProfile", "Default")
        
        ; Load profile-specific stratagems
        section := "Profile_" . ActiveProfile
        data := IniRead(IniPath, section, "ActiveList", "")
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
        
        ; Load GUI Scale
        GUIScale := Float(IniRead(IniPath, "Settings", "GUIScale", "1.0"))
        if (GUIScale < 1.0)
            GUIScale := 1.0
        if (GUIScale > 2.0)
            GUIScale := 2.0
        
        ScreenCX := A_ScreenWidth // 2
        ScreenCY := A_ScreenHeight // 2
    } catch as err {
    }
}

; --- PROFILE FUNCTIONS ---
GetProfilesList() {
    global IniPath
    profiles := []
    
    ; Always include Default profile first
    profiles.Push("Default")
    
    ; Scan INI for profile sections
    if FileExist(IniPath) {
        try {
            fileContent := FileRead(IniPath, "UTF-8")
            for line in StrSplit(fileContent, "`n", "`r") {
                line := Trim(line)
                if RegExMatch(line, "^\[Profile_(.+)\]$", &m) {
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

SetProfileDDL() {
    global ActiveProfile, ProfileDDL
    ; Find and select the active profile in dropdown
    ; Get the list of profiles and find the matching index
    profiles := GetProfilesList()
    for index, name in profiles {
        if (name = ActiveProfile) {
            ProfileDDL.Choose(index)
            break
        }
    }
}

SwitchProfile(*) {
    global ActiveProfile, ProfileDDL, ActiveStratagems
    
    ; Save current profile before switching
    SaveProfiles()
    
    ; Get selected profile name
    selectedProfile := ProfileDDL.Text
    
    if (selectedProfile = "" || selectedProfile = ActiveProfile)
        return
    
    ; Switch to new profile
    ActiveProfile := selectedProfile
    
    ; Clear and load new profile's stratagems
    ActiveStratagems := []
    section := "Profile_" . ActiveProfile
    
    try {
        data := IniRead(IniPath, section, "ActiveList", "")
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
    
    ; Update the UI
    UpdateActiveList()
    InvalidateRadialCache()
    
    ; Show tooltip notification
    ToolTip("Profile: " . ActiveProfile, A_ScreenWidth - 200, A_ScreenHeight - 50)
    SetTimer(RemoveToolTip, -1000)
}

CreateProfile(*) {
    global ActiveProfile, ProfileDDL, ActiveStratagems
    
    ; Prompt for new profile name
    IB := InputBox("Enter a name for the new profile:", "New Profile")
    if (IB.Result = "Cancel" || IB.Value = "")
        return
    
    newProfileName := Trim(IB.Value)
    if (newProfileName = "")
        return
    
    ; Save current profile first
    SaveProfiles()
    
    ; Switch to new profile
    ActiveProfile := newProfileName
    
    ; Clear stratagems for new profile
    ActiveStratagems := []
    
    ; Save to INI (creates the section with empty list)
    IniWrite("", IniPath, "Profile_" . ActiveProfile, "ActiveList")
    IniWrite(ActiveProfile, IniPath, "Settings", "ActiveProfile")
    
    ; Refresh the dropdown and list
    ProfileDDL.Delete()
    ProfileDDL.Add(GetProfilesList())
    SetProfileDDL()
    UpdateActiveList()
    
    MsgBox("Created profile: " . ActiveProfile, "Profile Created", 0x40)
}

DeleteProfile(*) {
    global ActiveProfile, ProfileDDL, ActiveStratagems, DefaultProfile
    
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
        IniDelete(IniPath, "Profile_" . ActiveProfile)
    } catch {
    }
    
    ; Switch to Default profile
    ActiveProfile := DefaultProfile
    IniWrite(ActiveProfile, IniPath, "Settings", "ActiveProfile")
    
    ; Load Default profile's stratagems
    ActiveStratagems := []
    try {
        data := IniRead(IniPath, "Profile_Default", "ActiveList", "")
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
    ProfileDDL.Add(GetProfilesList())
    SetProfileDDL()
    UpdateActiveList()
    
    MsgBox("Profile deleted. Switched to: " . ActiveProfile, "Profile Deleted", 0x40)
}

RemoveToolTip() {
    ToolTip()
}

SyncStratagemMenuKeyInputs(ctrl, *) {
    if (ctrl = stratagemMenuKeyInput) {
        if (stratagemMenuKeyInput.Value != "") {
            stratagemMenuKeyChoiceDDL.Choose(1)
        }
    }
    else if (ctrl = stratagemMenuKeyChoiceDDL) {
        if (stratagemMenuKeyChoiceDDL.Value != 1) {
            stratagemMenuKeyInput.Value := ""
        }
    }
    UpdateStratagemMenuKey()
}

UpdateStratagemMenuKey(*) {
    global StratagemMenuKey
    if (stratagemMenuKeyChoiceDDL.Value != 1) {
        StratagemMenuKey := AltChoiceList[stratagemMenuKeyChoiceDDL.Value]
    } else {
        StratagemMenuKey := stratagemMenuKeyInput.Value
    }
    SaveSettings()
}

SyncRadialMenuKeyInputs(ctrl, *) {
    global RadialMenuKey
    if (ctrl = radialMenuKeyInput) {
        hotkeyVal := radialMenuKeyInput.Value
        if (hotkeyVal != "") {
            ; Check if it's a key combination (contains modifiers ^ ! + #)
            if RegExMatch(hotkeyVal, "[\^!+#]") {
                ; Auto-strip modifiers - keep only the base key
                baseKey := RegExReplace(hotkeyVal, "[\^!+#]", "")
                radialMenuKeyInput.Value := baseKey
                hotkeyVal := baseKey
            }
            radialMenuKeyChoiceDDL.Choose(1)
        }
    }
    else if (ctrl = radialMenuKeyChoiceDDL) {
        if (radialMenuKeyChoiceDDL.Value != 1) {
            radialMenuKeyInput.Value := ""
        }
    }
    UpdateRadialMenuKey()
}

UpdateRadialMenuKey(*) {
    global RadialMenuKey
    if (radialMenuKeyChoiceDDL.Value != 1) {
        RadialMenuKey := AltChoiceList[radialMenuKeyChoiceDDL.Value]
    } else {
        RadialMenuKey := radialMenuKeyInput.Value
    }
    SetRadialMenuHotkey()
    SaveSettings()
    UpdateHelpText()
}

UpdateRadialMenuKeyWildcard(*) {
    global RadialMenuKeyWildcard
    RadialMenuKeyWildcard := radialMenuKeyWildcardCheckbox.Value
    SetRadialMenuHotkey()
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

UpdateProfileNextHotkey(*) {
    global ProfileNextHotkey
    ProfileNextHotkey := profileNextHotkeyInput.Value
    SetProfileSwitchHotkeys()
    SaveSettings()
}

UpdateProfilePrevHotkey(*) {
    global ProfilePrevHotkey
    ProfilePrevHotkey := profilePrevHotkeyInput.Value
    SetProfileSwitchHotkeys()
    SaveSettings()
}

SetProfileSwitchHotkeys() {
    global ProfileNextHotkey, ProfilePrevHotkey
    static prevNextHotkey := ""
    static prevPrevHotkey := ""
    
    try {
        ; Disable previous hotkeys
        if prevNextHotkey != "" {
            try Hotkey(prevNextHotkey, (*) => 0, "Off")
        }
        if prevPrevHotkey != "" {
            try Hotkey(prevPrevHotkey, (*) => 0, "Off")
        }
        
        ; Enable new hotkeys
        if ProfileNextHotkey != "" {
            prevNextHotkey := ProfileNextHotkey
            Hotkey(ProfileNextHotkey, CycleProfileNext, "On")
        }
        if ProfilePrevHotkey != "" {
            prevPrevHotkey := ProfilePrevHotkey
            Hotkey(ProfilePrevHotkey, CycleProfilePrev, "On")
        }
    } catch as err {
        ; Silent fail for hotkey errors
    }
}

CycleProfileNext(*) {
    global ActiveProfile, ActiveStratagems
    
    profiles := GetProfilesList()
    if (profiles.Length <= 1)
        return
    
    ; Find current index
    currentIndex := 0
    for index, name in profiles {
        if (name = ActiveProfile) {
            currentIndex := index
            break
        }
    }
    
    ; Calculate next index (wrap around)
    nextIndex := currentIndex + 1
    if (nextIndex > profiles.Length)
        nextIndex := 1
    
    ; Switch to next profile
    CycleToProfile(profiles[nextIndex])
}

CycleProfilePrev(*) {
    global ActiveProfile, ActiveStratagems
    
    profiles := GetProfilesList()
    if (profiles.Length <= 1)
        return
    
    ; Find current index
    currentIndex := 0
    for index, name in profiles {
        if (name = ActiveProfile) {
            currentIndex := index
            break
        }
    }
    
    ; Calculate previous index (wrap around)
    prevIndex := currentIndex - 1
    if (prevIndex < 1)
        prevIndex := profiles.Length
    
    ; Switch to previous profile
    CycleToProfile(profiles[prevIndex])
}

CycleToProfile(newProfile) {
    global ActiveProfile, ActiveStratagems
    
    if (newProfile = "" || newProfile = ActiveProfile)
        return
    
    ; Save current profile
    SaveProfiles()
    
    ; Switch to new profile
    ActiveProfile := newProfile
    
    ; Clear and load new profile's stratagems
    ActiveStratagems := []
    section := "Profile_" . ActiveProfile
    
    try {
        data := IniRead(IniPath, section, "ActiveList", "")
        if data != "" {
            for id in StrSplit(data, ",") {
                id := Trim(id)
                if id != "" && Stratagems.Has(id)
                    ActiveStratagems.Push(id)
            }
        }
    } catch {
    }
    
    ; Save the active profile setting
    IniWrite(ActiveProfile, IniPath, "Settings", "ActiveProfile")
    
    ; Invalidate cache for new profile
    InvalidateRadialCache()
    
    ; Update UI
    try {
        UpdateActiveList()
        SetProfileDDL()
    } catch {
    }
    
    ; Show tooltip notification
    ToolTip("Profile: " . ActiveProfile, A_ScreenWidth - 200, A_ScreenHeight - 50)
    SetTimer(RemoveToolTip, -1000)
}

SetSuspendHotkey() {
    global SuspendHotkey
    static CurrentActiveSuspendHotkey := ""
    
    ; Add * prefix to make hotkey work regardless of modifiers (Ctrl, Alt, Shift, Win)
    HotkeyToActivate := SuspendHotkey
    if (HotkeyToActivate != "" && SubStr(HotkeyToActivate, 1, 1) != "*") {
        HotkeyToActivate := "*" . HotkeyToActivate
    }
    
    ; Disable previous hotkey if it was active and valid
    if (CurrentActiveSuspendHotkey != "" && RegExMatch(CurrentActiveSuspendHotkey, "^\S+$")) {
        try Hotkey(CurrentActiveSuspendHotkey, ToggleSuspend, "Off")
    }
    
    ; Set new hotkey if valid - use SuspendExempt (S option) to allow hotkey to work when suspended
    if (HotkeyToActivate != "" && RegExMatch(HotkeyToActivate, "^\S+$")) {
        try {
            Hotkey(HotkeyToActivate, ToggleSuspend, "On S")
            CurrentActiveSuspendHotkey := HotkeyToActivate
        }
    } else {
        CurrentActiveSuspendHotkey := ""
    }
}

SetExitHotkey() {
    global ExitHotkey
    static CurrentActiveExitHotkey := ""
    
    ; Add * prefix to make hotkey work regardless of modifiers (Ctrl, Alt, Shift, Win)
    HotkeyToActivate := ExitHotkey
    if (HotkeyToActivate != "" && SubStr(HotkeyToActivate, 1, 1) != "*") {
        HotkeyToActivate := "*" . HotkeyToActivate
    }
    
    ; Disable previous hotkey if it was active and valid
    if (CurrentActiveExitHotkey != "" && RegExMatch(CurrentActiveExitHotkey, "^\S+$")) {
        try Hotkey(CurrentActiveExitHotkey, (*) => ExitApp(), "Off")
    }
    
    ; Set new hotkey if valid - use SuspendExempt (S option) to allow hotkey to work when suspended
    if (HotkeyToActivate != "" && RegExMatch(HotkeyToActivate, "^\S+$")) {
        try {
            Hotkey(HotkeyToActivate, (*) => ExitApp(), "On S")
            CurrentActiveExitHotkey := HotkeyToActivate
        }
    } else {
        CurrentActiveExitHotkey := ""
    }
}

SetRadialMenuHotkey() {
    global RadialMenuKeyWildcard
    static prevHotkey := ""
    try {
        ; Disable previous hotkey
        if prevHotkey != "" {
            try Hotkey(prevHotkey, (*) => 0, "Off")
        }
        
        ; Enable new hotkey
        if RadialMenuKey != "" {
            ; Apply wildcard prefix if enabled
            hotkeyBase := RadialMenuKey
            if (RadialMenuKeyWildcard && SubStr(hotkeyBase, 1, 1) != "*")
                hotkeyToSet := "*" . hotkeyBase
            else
                hotkeyToSet := hotkeyBase
            
            prevHotkey := hotkeyToSet
            Hotkey(hotkeyToSet, RadialMenuDown, "On")
        }
    } catch as err {
    }
}

RadialMenuDown(*) {
    global RadialMenuKey, IsMenuVisible, IsExecutingMacro, BlockCameraBypass, radialGui, SelectedSector, ForceRadialRedraw
    global ScreenCX, ScreenCY, ActiveStratagems
    
    ; Prevent re-entry - if menu is already visible, ignore additional presses
    if (IsMenuVisible)
        return
    
    if IsExecutingMacro
        return
    if ActiveStratagems.Length == 0 {
        ToolTip("No stratagems in active profile!", A_ScreenWidth - 200, A_ScreenHeight - 50)
        SetTimer(RemoveToolTip, -2000)
        return
    }
    
    ; Set flag immediately to prevent re-entry
    IsMenuVisible := true
    SelectedSector := 0
    ForceRadialRedraw := true
    
    ; Lock camera if enabled (opens map + holds RMB to prevent camera movement)
    if (BlockCameraBypass) {
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
        return
    }
    radialGui.Show("Na")
    
    SetTimer(WatchMouse, 10)
    
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
    if (BlockCameraBypass) {
        EndCameraBypass()
    }

    IsMenuVisible := false

    ; Only run if we have stratagems and choice is valid
    if (choice > 0 && ActiveStratagems.Length > 0 && choice <= ActiveStratagems.Length)
        RunMacro(ActiveStratagems[choice])
}

; --- MENU LOGIC (HOTKEYS) ---
SetDisplayToggleHotkey() {
    global DisplayToggleHotkey
    static CurrentActiveDisplayToggleHotkey := ""
    
    ; Add * prefix to make hotkey work regardless of modifiers (Ctrl, Alt, Shift, Win)
    HotkeyToActivate := DisplayToggleHotkey
    if (HotkeyToActivate != "" && SubStr(HotkeyToActivate, 1, 1) != "*") {
        HotkeyToActivate := "*" . HotkeyToActivate
    }
    
    ; Disable previous hotkey if it was active and valid
    if (CurrentActiveDisplayToggleHotkey != "" && RegExMatch(CurrentActiveDisplayToggleHotkey, "^\S+$")) {
        try Hotkey(CurrentActiveDisplayToggleHotkey, ToggleSettingsGui, "Off")
    }
    
    ; Set new hotkey if valid - use SuspendExempt (S option) to allow hotkey to work when suspended
    if (HotkeyToActivate != "" && RegExMatch(HotkeyToActivate, "^\S+$")) {
        try {
            Hotkey(HotkeyToActivate, ToggleSettingsGui, "On S")
            CurrentActiveDisplayToggleHotkey := HotkeyToActivate
        }
    } else {
        CurrentActiveDisplayToggleHotkey := ""
    }
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

WatchMouse() {
    global SelectedSector, LastDrawnSector, LastDrawnMX, LastDrawnMY, ForceRadialRedraw
    if !IsMenuVisible
        return
    if ActiveStratagems.Length = 0
        return
    CoordMode("Mouse", "Screen")
    MouseGetPos(&mx, &my)
    dx := mx - ScreenCX, dy := my - ScreenCY
    dist := Sqrt(dx**2 + dy**2)
    
    count := ActiveStratagems.Length
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
    global radialGui
    if !IsSet(radialGui) || !radialGui
        return

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

RunMacro(id) {
    global IsExecutingMacro, StratagemMenuKey, MenuInputType, PostMenuDelay
    
    if !Stratagems.Has(id) 
        return
    
    sequence := Stratagems[id]
    if !IsObject(sequence) || sequence.Length = 0
        return
    
    IsExecutingMacro := true
    
    ; Use universal ExecuteKeyInput function
    if (MenuInputType = 5) {  ; Hold - keep key down during sequence
        ExecuteKeyInput(StratagemMenuKey, MenuInputType, "down")
        Sleep(PostMenuDelay)
        ExecuteSequence(sequence)
        ; Always release the key
        ExecuteKeyInput(StratagemMenuKey, MenuInputType, "up")
    }
    else {
        ; All other types - press and release before sequence
        ExecuteKeyInput(StratagemMenuKey, MenuInputType, "down")
        Sleep(PostMenuDelay)
        ExecuteSequence(sequence)
    }
    
    IsExecutingMacro := false
}

ShowCursor(b) => DllCall("ShowCursor", "Int", b)
ClipCursor(c, x1:=0, y1:=0, x2:=0, y2:=0) {
    if !c 
        return DllCall("ClipCursor", "Ptr", 0)
    rect := Buffer(16), NumPut("Int",x1,rect,0), NumPut("Int",y1,rect,4), NumPut("Int",x2,rect,8), NumPut("Int",y2,rect,12)
    DllCall("ClipCursor", "Ptr", rect)
}
ExitRoutine(*) {
    global RadialMenuKey, BlockCameraBypass, OpenMapKey, IsMenuVisible
    
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
    try Gdip_Shutdown(pToken)
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

GameCheck() {
    global GameTarget, GameProcessName, IsAutoPaused, ScriptSuspended, AutoPauseActive, AutoCloseActive, AutoCloseCountdownActive
    
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
            if (!IsAutoPaused && !A_IsSuspended) {
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
    global StatusText, IsAutoPaused
    
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
}

; --- CAMERA BYPASS FUNCTIONS ---
SyncOpenMapKeyInputs(ctrl, *) {
    if (ctrl = OpenMapKeyInput) {
        if (OpenMapKeyInput.Value != "") {
            OpenMapKeyChoiceDDL.Choose(1)
        }
    }
    else if (ctrl = OpenMapKeyChoiceDDL) {
        if (OpenMapKeyChoiceDDL.Value != 1) {
            OpenMapKeyInput.Value := ""
        }
    }
    UpdateOpenMapKey()
}

UpdateOpenMapKey(*) {
    global OpenMapKey
    if (OpenMapKeyChoiceDDL.Value != 1) {
        OpenMapKey := AltChoiceList[OpenMapKeyChoiceDDL.Value]
    } else {
        OpenMapKey := OpenMapKeyInput.Value
    }
    SaveSettings()
}

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

StartCameraBypass() {
    global OpenMapKey, MapInputType, CameraBypassActive
    
    ; Prevent re-entry - if already active, don't run again
    if (CameraBypassActive)
        return
    
    CameraBypassActive := true
    
    ; Open map using universal function
    ExecuteKeyInput(OpenMapKey, MapInputType, "down")
    
    Sleep(25)
    SendInput("{RButton Down}")
}

EndCameraBypass() {
    global OpenMapKey, MapInputType, CameraBypassActive
    
    ; Only run if camera bypass is actually active
    if (!CameraBypassActive)
        return
    
    SendInput("{RButton Up}")
    
    ; Close map - for Hold type release the key, for others tap to close
    if (MapInputType = 5) {  ; Hold - release the key
        ExecuteKeyInput(OpenMapKey, MapInputType, "up")
    }
    else {  ; All other types - tap to close
        ExecuteKeyInput(OpenMapKey, MapInputType, "down")
    }
    
    CameraBypassActive := false
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