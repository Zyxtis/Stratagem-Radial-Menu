#Requires AutoHotkey v2.0
#Include Config\config.ahk

; Paths
global IniPath := A_ScriptDir "\Config\settings.ini"
global ProfilesIniPath := A_ScriptDir "\Config\profiles.ini"
global OCRProfileIniPath := A_ScriptDir "\Config\ocr.ini"

; Load GUI Scale from settings.ini
LoadGUIScale()

; Load language settings
LoadLanguage()

OnExit(GdiShutdownRoutine)

GdiShutdownRoutine(*) {
    global pToken
    if pToken
        Gdip_Shutdown(pToken)
}

; --- ImageList for Stratagem Icons ---
IL_ID := 0
LoadStratagemsData()
IL_ID := InitIconImageList()

; --- MAIN GUI ---
editorGui := Gui("-Caption +LastFound", Lang.Get("editor_title"))
editorGui.BackColor := ThemeBackColor
baseFontSize := Scale(10)
editorGui.SetFont("s" baseFontSize " c" ThemeTextColor, "Segoe UI")
editorGui.MarginX := Scale(5)
editorGui.MarginY := Scale(5)

; Title Bar
titleFontSize := Scale(12)
editorGui.SetFont("c" ThemeTitleTextColor " s" titleFontSize)
editorGui.Add("Text", "x0 y0 w" Scale(330) " h" Scale(30) " Background" ThemeTitleColor " Border +Center", Lang.Get("editor_title")).OnEvent("Click", StartMove)
editorGui.Add("Button", "x+5 y0 w" Scale(30) " h" Scale(30), "X").OnEvent("Click", (*) => ExitApp())
editorGui.SetFont("s" baseFontSize " c" ThemeTextColor)

; Search
editorGui.Add("Text", "x" Scale(10) " y" Scale(40) " w" Scale(200), Lang.Get("search"))
searchEdit := editorGui.Add("Edit", "w" Scale(350) " x" Scale(10) " y+5 vSearchBox Background" ThemeControlColor)
searchEdit.OnEvent("Change", FilterAvailableList)

; ListView
iconSizeScaled := Scale(32)
lbAvailable := editorGui.Add("ListView", "x" Scale(10) " y+10 r20 w" Scale(350) " Multi vAvailableList Background" ThemeListColor, [Lang.Get("icon"), Lang.Get("name"), "ID", Lang.Get("type")])
lbAvailable.SetImageList(IL_ID, 1)
lbAvailable.ModifyCol(1, iconSizeScaled + Scale(8))
lbAvailable.ModifyCol(2, Scale(200))
lbAvailable.ModifyCol(3, Scale(80))
lbAvailable.ModifyCol(4, 0)
PopulateAvailableList()

; Buttons
btnNew := editorGui.Add("Button", "w" Scale(80) " x" Scale(10) " y+10", Lang.Get("new_stratagem"))
btnNew.OnEvent("Click", NewStratagem)
btnEdit := editorGui.Add("Button", "w" Scale(80) " x+" Scale(5) " yp", Lang.Get("edit_stratagem"))
btnEdit.OnEvent("Click", EditSelectedStratagem)
btnDelete := editorGui.Add("Button", "w" Scale(80) " +" Scale(5) " yp", Lang.Get("delete_stratagem"))
btnDelete.OnEvent("Click", DeleteSelectedStratagem)
btnUpSel := editorGui.Add("Button", "w" Scale(45) " h" Scale(30) " +" Scale(5) " yp", "▲")
btnUpSel.OnEvent("Click", MoveStratagemUp)
btnDownSel := editorGui.Add("Button", "w" Scale(45) " h" Scale(30) " +" Scale(5) " yp", "▼")
btnDownSel.OnEvent("Click", MoveStratagemDown)

editorGui.Show()

; --- FUNCTIONS ---
PopulateAvailableList() {
    FilterAvailableList()
}

FilterAvailableList(*) {
    searchText := StrLower(searchEdit.Value)
    lbAvailable.Delete()
    lbAvailable.Opt("-Redraw")
    
    ; First pass: identify categories with matches
    categoriesWithMatches := Map()
    if (searchText != "") {
        currentCategory := ""
        for id in OrderedIDs {
            if InStr(id, "category_") = 1 {
                currentCategory := id
                categoriesWithMatches[currentCategory] := false
            } else if InStr(id, "separator_") = 1 {
                continue
            } else if (currentCategory != "") {
                if InStr(StrLower(StratagemNames[id]), searchText)
                    categoriesWithMatches[currentCategory] := true
            }
        }
    }
    
    ; Second pass: build list
    currentCategory := ""
    for id in OrderedIDs {
        name := StratagemNames[id]
        
        if InStr(id, "category_") = 1 {
            currentCategory := id
            if (searchText != "") && (!categoriesWithMatches.Has(currentCategory) || !categoriesWithMatches[currentCategory])
                continue
            lbAvailable.Add("Icon1", "", name, "", "CATEGORY")
            continue
        }
        
        if InStr(id, "separator_") = 1 || name = " "
            continue
        if (searchText != "" && !InStr(StrLower(name), searchText))
            continue
        
        idx := IconIndexMap.Has(id) ? IconIndexMap[id] : 0
        if (idx > 0)
            lbAvailable.Add("Icon" . idx, "", name, id, "")
        else
            lbAvailable.Add("", "[?]", name, id, "")
    }
    lbAvailable.Opt("+Redraw")
}

; --- STRATAGEM ACTIONS ---
EditSelectedStratagem(*) {
    row := lbAvailable.GetNext()
    if !row {
        MsgBox(Lang.Get("select_to_edit"))
        return
    }
    
    id := lbAvailable.GetText(row, 3)
    type := lbAvailable.GetText(row, 4)
    
    if type = "CATEGORY" || id = "" {
        MsgBox(Lang.Get("cannot_edit_categories"))
        return
    }
    
    if !Stratagems.Has(id) {
        MsgBox(Lang.Get("stratagem_not_found"))
        return
    }
    
    ShowStratagemEditor(id)
}

NewStratagem(*) {
    ShowStratagemEditor("")
}

DeleteSelectedStratagem(*) {
    row := lbAvailable.GetNext()
    if !row {
        MsgBox(Lang.Get("select_to_delete"))
        return
    }
    
    id := lbAvailable.GetText(row, 3)
    type := lbAvailable.GetText(row, 4)
    name := lbAvailable.GetText(row, 2)
    
    if type = "CATEGORY" || id = "" {
        MsgBox(Lang.Get("cannot_edit_categories"))
        return
    }
    
    if MsgBox(Lang.Get("delete_confirm_msg") name "'?", Lang.Get("confirm_delete"), 0x24) = "No"
        return
    
    section := StratagemSections.Has(id) ? StratagemSections[id] : "Defensive Stratagems"
    DeleteStratagemFromFile(id, section)
    ReloadAllData()
}

MoveStratagemUp(*) {
    row := lbAvailable.GetNext()
    if !row {
        MsgBox(Lang.Get("select_to_edit"))
        return
    }
    
    id := lbAvailable.GetText(row, 3)
    type := lbAvailable.GetText(row, 4)
    
    if type = "CATEGORY" || id = "" {
        MsgBox(Lang.Get("cannot_edit_categories"))
        return
    }
    
    idx := 0
    for i, storedId in OrderedIDs {
        if (storedId = id) {
            idx := i
            break
        }
    }
    
    if idx <= 1
        return
    
    prevId := OrderedIDs[idx - 1]
    if InStr(prevId, "category_") = 1
        return
    
    OrderedIDs[idx] := prevId
    OrderedIDs[idx - 1] := id
    SaveStratagemOrder()
    PopulateAvailableList()
    lbAvailable.Modify(row - 1, "Select Vis")
}

MoveStratagemDown(*) {
    row := lbAvailable.GetNext()
    if !row {
        MsgBox(Lang.Get("select_to_edit"))
        return
    }
    
    id := lbAvailable.GetText(row, 3)
    type := lbAvailable.GetText(row, 4)
    
    if type = "CATEGORY" || id = "" {
        MsgBox(Lang.Get("cannot_edit_categories"))
        return
    }
    
    idx := 0
    for i, storedId in OrderedIDs {
        if (storedId = id) {
            idx := i
            break
        }
    }
    
    if idx = 0 || idx >= OrderedIDs.Length
        return
    
    nextId := OrderedIDs[idx + 1]
    if InStr(nextId, "category_") = 1 || InStr(nextId, "separator_") = 1
        return
    
    OrderedIDs[idx] := nextId
    OrderedIDs[idx + 1] := id
    SaveStratagemOrder()
    PopulateAvailableList()
    lbAvailable.Modify(row + 1, "Select Vis")
}


; --- EDITOR DIALOG ---
ShowStratagemEditor(editId) {
    isEdit := (editId != "")
    global editorIdEdit, editorNameEdit, editorCategoryDDL, editorSeqDisplay, editorSeqArray
    
    editDlg := Gui("-Caption +LastFound", isEdit ? Lang.Get("edit_stratagem") : Lang.Get("new_stratagem"))
    editDlg.BackColor := ThemeBackColor
    dlgBaseFontSize := Scale(10)
    editDlg.SetFont("s" dlgBaseFontSize " c" ThemeTextColor, "Segoe UI")
    editDlg.MarginX := Scale(5)
    editDlg.MarginY := Scale(5)
    
    ; Title Bar
    dlgTitleFontSize := Scale(12)
    editDlg.SetFont("c" ThemeTitleTextColor " s" dlgTitleFontSize)
    editDlg.Add("Text", "x0 y0 w" Scale(330) " h" Scale(30) " Background" ThemeTitleColor " Border +Center", isEdit ? Lang.Get("edit_stratagem") : Lang.Get("new_stratagem")).OnEvent("Click", StartMoveEdit)
    editDlg.Add("Button", "x+5 y0 w" Scale(30) " h" Scale(30), "X").OnEvent("Click", (*) => editDlg.Destroy())
    editDlg.SetFont("s" dlgBaseFontSize " c" ThemeTextColor)
    
    ; Fields
    editDlg.Add("Text", "x" Scale(15) " y" Scale(40) " w" Scale(70), Lang.Get("id_label"))
    editorIdEdit := editDlg.Add("Edit", "x+5 w" Scale(240) " Background" ThemeControlColor)
    if isEdit
        editorIdEdit.Value := editId
    
    editDlg.Add("Text", "x" Scale(15) " y+15 w" Scale(70), Lang.Get("name_label"))
    editorNameEdit := editDlg.Add("Edit", "x+5 w" Scale(240) " Background" ThemeControlColor)
    if isEdit
        editorNameEdit.Value := StratagemNames[editId]
    
    editDlg.Add("Text", "x" Scale(15) " y+15 w" Scale(70), Lang.Get("category_label"))
    editorCategoryDDL := editDlg.Add("DropDownList", "x+5 w" Scale(240) " Background" ThemeControlColor, [Lang.Get("cat_offensive"), Lang.Get("cat_supply"), Lang.Get("cat_defensive"), Lang.Get("cat_mission")])
    
    if isEdit && StratagemSections.Has(editId) {
        categories := [Lang.Get("cat_offensive"), Lang.Get("cat_supply"), Lang.Get("cat_defensive"), Lang.Get("cat_mission")]
        for idx, cat in categories {
            if (cat = StratagemSections[editId]) {
                editorCategoryDDL.Choose(idx)
                break
            }
        }
    } else {
        editorCategoryDDL.Choose(1)
    }
    
    editDlg.Add("Text", "x" Scale(15) " y+15 w" Scale(70), Lang.Get("sequence_label"))
    editDlg.SetFont("s" Scale(16))
    editorSeqDisplay := editDlg.Add("Text", "x+5 w" Scale(240) " h" Scale(30) " Background" ThemeControlColor " Border +0x200", "")
    editDlg.SetFont("s" dlgBaseFontSize)
    global editorSeqArray
    editorSeqArray := []
    if isEdit && Stratagems.Has(editId) {
        seq := Stratagems[editId]
        for i, dir in seq {
            editorSeqArray.Push(dir)
        }
        UpdateSequenceDisplay()
    }
    
    ; Arrow buttons for sequence input
    btnUp := editDlg.Add("Button", "x" Scale(90) " y+10 w" Scale(35) " h" Scale(35), "🡅")
    btnUp.OnEvent("Click", (*) => AppendToSequence("Up"))
    btnDown := editDlg.Add("Button", "x+5 yp w" Scale(35) " h" Scale(35), "🡇")
    btnDown.OnEvent("Click", (*) => AppendToSequence("Down"))
    btnLeft := editDlg.Add("Button", "x+5 yp w" Scale(35) " h" Scale(35), "🡄")
    btnLeft.OnEvent("Click", (*) => AppendToSequence("Left"))
    btnRight := editDlg.Add("Button", "x+5 yp w" Scale(35) " h" Scale(35), "🡆")
    btnRight.OnEvent("Click", (*) => AppendToSequence("Right"))
    btnBack := editDlg.Add("Button", "x+10 yp w" Scale(35) " h" Scale(35), "⌫")
    btnBack.OnEvent("Click", (*) => RemoveLastFromSequence())
    btnClear := editDlg.Add("Button", "x+5 yp w" Scale(35) " h" Scale(35), "✕")
    btnClear.OnEvent("Click", (*) => ClearSequence())
    
    ; Buttons
    btnSave := editDlg.Add("Button", "x" Scale(100) " y+15 w" Scale(80) " Default", Lang.Get("save"))
    btnSave.OnEvent("Click", (*) => SaveStratagemFromEditor(editDlg, editId))
    btnCancel := editDlg.Add("Button", "x+10 yp w" Scale(80), Lang.Get("cancel"))
    btnCancel.OnEvent("Click", (*) => editDlg.Destroy())
    
    editDlg.OnEvent("Escape", (*) => editDlg.Destroy())
    editDlg.Show()
}

UpdateSequenceDisplay() {
    global editorSeqArray, editorSeqDisplay
    displayStr := ""
    dirSymbols := Map("Up", "🡅", "Down", "🡇", "Left", "🡄", "Right", "🡆")
    for i, dir in editorSeqArray {
        if (i > 1)
            displayStr .= " "
        displayStr .= dirSymbols.Has(dir) ? dirSymbols[dir] : dir
    }
    editorSeqDisplay.Value := displayStr
}

AppendToSequence(direction) {
    global editorSeqArray
    editorSeqArray.Push(direction)
    UpdateSequenceDisplay()
}

RemoveLastFromSequence() {
    global editorSeqArray
    if (editorSeqArray.Length > 0) {
        editorSeqArray.Pop()
        UpdateSequenceDisplay()
    }
}

ClearSequence() {
    global editorSeqArray
    editorSeqArray := []
    UpdateSequenceDisplay()
}

SaveStratagemFromEditor(editDlg, originalId) {
    global editorIdEdit, editorNameEdit, editorSeqArray, editorCategoryDDL
    id := Trim(editorIdEdit.Value)
    name := Trim(editorNameEdit.Value)
    category := editorCategoryDDL.Text
    
    if id = "" || name = "" || editorSeqArray.Length = 0 {
        MsgBox(Lang.Get("all_fields_required"))
        return
    }
    
    if (originalId = "" || originalId != id) && Stratagems.Has(id) {
        MsgBox(Lang.Get("id_already_exists"))
        return
    }
    
    ; Use the array directly
    seq := []
    for dir in editorSeqArray {
        seq.Push(dir)
    }
    
    if seq.Length = 0 {
        MsgBox(Lang.Get("invalid_sequence"))
        return
    }
    
    ; Handle ID/section changes
    oldSection := originalId != "" && StratagemSections.Has(originalId) ? StratagemSections[originalId] : ""
    
    if (originalId != "" && originalId = id && oldSection != "" && oldSection != category)
        DeleteStratagemFromFile(originalId, oldSection)
    
    if (originalId != "" && originalId != id) {
        if (oldSection != "")
            DeleteStratagemFromFile(originalId, oldSection)
        Stratagems.Delete(originalId)
        StratagemNames.Delete(originalId)
        StratagemSections.Delete(originalId)
        for i, storedId in OrderedIDs {
            if (storedId = originalId) {
                OrderedIDs.RemoveAt(i)
                break
            }
        }
    }
    
    ; Update data
    Stratagems[id] := seq
    StratagemNames[id] := name
    StratagemSections[id] := category
    if (originalId = "" || originalId != id)
        OrderedIDs.Push(id)
    
    SaveStratagemToIni(id, name, seq, category)
    ReloadAllData(id)
    editDlg.Destroy()
}

ReloadAllData(selectId := "") {
    global IL_ID, IconIndexMap
    
    Stratagems := Map(), StratagemNames := Map(), OrderedIDs := []
    StratagemSections := Map()
    IconIndexMap := Map()
    LoadStratagemsData()
    
    ; Rebuild ImageList with new data
    iconSizeScaled := Scale(32)
    IL_ID := InitIconImageList()
    lbAvailable.SetImageList(IL_ID, 1)
    
    PopulateAvailableList()
    
    if (selectId != "") {
        Loop lbAvailable.GetCount() {
            if (lbAvailable.GetText(A_Index, 3) = selectId) {
                lbAvailable.Modify(A_Index, "Select Vis")
                break
            }
        }
    }
}

; --- FILE OPERATIONS ---
SaveStratagemToIni(id, name, seq, section := "Defensive Stratagems") {
    seqStr := ""
    for i, dir in seq {
        seqStr .= dir
        if (i < seq.Length)
            seqStr .= ","
    }
    entryLine := id "=" name "|" seqStr
    
    try fileContent := FileRead(StratagemsIniPath, "UTF-8")
    catch {
        FileOpen(StratagemsIniPath, "w", "UTF-8").Write("[" section "]`n" entryLine "`n")
        return
    }
    
    ; Replace existing entry
    needle := "m)^" id "\s*=\s*.*$"
    if RegExMatch(fileContent, needle) {
        FileOpen(StratagemsIniPath, "w", "UTF-8").Write(RegExReplace(fileContent, needle, entryLine))
        return
    }
    
    ; Add new entry to section
    sections := Map()
    currentSection := ""
    
    for line in StrSplit(fileContent, "`n", "`r") {
        trimmedLine := Trim(line)
        if (trimmedLine = "")
            continue
        if (SubStr(trimmedLine, 1, 1) = "[" && SubStr(trimmedLine, -1) = "]") {
            currentSection := SubStr(trimmedLine, 2, -1)
            if !sections.Has(currentSection)
                sections[currentSection] := []
            sections[currentSection].Push(trimmedLine)
            continue
        }
        if (currentSection != "" && sections.Has(currentSection))
            sections[currentSection].Push(trimmedLine)
    }
    
    if !sections.Has(section) {
        sections[section] := []
        sections[section].Push("[" section "]")
    }
    sections[section].Push(entryLine)
    
    ; Rebuild file with language-appropriate section names
    lang := (IsSet(CurrentLanguage) && CurrentLanguage = "ru") ? "ru" : "en"
    if (lang = "ru") {
        sectionOrder := ["Стратагемы Наступления", "Стратагемы Снабжения", "Стратагемы Обороны", "Стратагемы Задания"]
    } else {
        sectionOrder := ["Offensive Stratagems", "Supply Stratagems", "Defensive Stratagems", "Mission Stratagems"]
    }
    finalContent := ""
    firstSection := true
    
    for sectionName in sectionOrder {
        if sections.Has(sectionName) {
            if !firstSection
                finalContent .= "`n"
            firstSection := false
            for line in sections[sectionName]
                finalContent .= line "`n"
        }
    }
    
    try FileOpen(StratagemsIniPath, "w", "UTF-8").Write(finalContent)
}

DeleteStratagemFromFile(id, section) {
    try fileContent := FileRead(StratagemsIniPath, "UTF-8")
    catch
        return false
    
    newContent := ""
    currentSection := ""
    
    for line in StrSplit(fileContent, "`n", "`r") {
        trimmedLine := Trim(line)
        
        if (SubStr(trimmedLine, 1, 1) = "[" && SubStr(trimmedLine, -1) = "]") {
            currentSection := SubStr(trimmedLine, 2, -1)
            newContent .= line "`n"
            continue
        }
        
        eqPos := InStr(trimmedLine, "=")
        if eqPos > 0 && Trim(SubStr(trimmedLine, 1, eqPos - 1)) = id
            continue
        
        newContent .= line "`n"
    }
    
    try {
        FileOpen(StratagemsIniPath, "w", "UTF-8").Write(newContent)
        return true
    } catch {
        return false
    }
}

SaveStratagemOrder() {
    sections := Map()
    currentSection := ""
    
    try fileContent := FileRead(StratagemsIniPath, "UTF-8")
    catch
        return
    
    for line in StrSplit(fileContent, "`n", "`r") {
        trimmedLine := Trim(line)
        if (trimmedLine = "")
            continue
        if (SubStr(trimmedLine, 1, 1) = "[" && SubStr(trimmedLine, -1) = "]") {
            currentSection := SubStr(trimmedLine, 2, -1)
            sections[currentSection] := []
            continue
        }
        if (currentSection != "" && SubStr(trimmedLine, 1, 1) != ";") {
            if sections.Has(currentSection)
                sections[currentSection].Push(trimmedLine)
        }
    }
    
    ; Use language-specific section names for output
    lang := (IsSet(CurrentLanguage) && CurrentLanguage = "ru") ? "ru" : "en"
    if (lang = "ru") {
        sectionOrder := ["Стратагемы Наступления", "Стратагемы Снабжения", "Стратагемы Обороны", "Стратагемы Задания"]
    } else {
        sectionOrder := ["Offensive Stratagems", "Supply Stratagems", "Defensive Stratagems", "Mission Stratagems"]
    }
    
    for sectionName in sectionOrder {
        if !sections.Has(sectionName)
            continue
        
        newContent .= "[" sectionName "]`n"
        
        for entry in sections[sectionName] {
            if InStr(entry, "category_") = 1 || InStr(entry, "separator_") = 1
                newContent .= entry "`n"
        }
        
        for id in OrderedIDs {
            if StratagemSections.Has(id) && StratagemSections[id] = sectionName {
                for entry in sections[sectionName] {
                    eqPos := InStr(entry, "=")
                    if eqPos > 0 && Trim(SubStr(entry, 1, eqPos - 1)) = id {
                        newContent .= entry "`n"
                        break
                    }
                }
            }
        }
        newContent .= "`n"
    }
    
    try FileOpen(StratagemsIniPath, "w", "UTF-8").Write(newContent)
}