; config.ahk - Shared configuration and functions
#Include Gdip_All.ahk

; ---GDI+ INITIALIZATION---
global pToken := Gdip_Startup()

; ---GUI SCALE---
global GUIScale := 1.0

; Scale helper function - scales a value by GUIScale and rounds to integer
Scale(value) {
    global GUIScale
    return Round(value * GUIScale)
}

; Load GUIScale from settings.ini
LoadGUIScale() {
    global GUIScale
    try {
        GUIScale := Float(IniRead(A_ScriptDir "\Config\settings.ini", "Settings", "GUIScale", "1.0"))
        if (GUIScale < 1.0)
            GUIScale := 1.0
        if (GUIScale > 2.0)
            GUIScale := 2.0
    } catch {
        GUIScale := 1.0
    }
}

; ---THEME---
global ThemeBackColor      := "202020"
global ThemeTitleColor     := "2A2A2A"
global ThemeControlColor   := "2f2f2f"
global ThemeTextColor      := "C4C4C4"
global ThemeTitleTextColor := "FFFFFF"
global ThemeListColor      := "000000"

; ---PATHS---
global StratagemsIniPath := A_ScriptDir "\Config\stratagems.ini"

; ---DATA STORAGE---
global Stratagems        := Map()
global StratagemNames    := Map()
global OrderedIDs        := []
global StratagemSections := Map()
global IconIndexMap      := Map()

; ---ICON FUNCTIONS---
FindIconPath(id) {
    static iconCache := Map()
    
    if iconCache.Has(id)
        return iconCache[id]
    
    ; Try exact match
    iconPath := A_ScriptDir "\Config\icons\" id ".png"
    if FileExist(iconPath) {
        iconCache[id] := iconPath
        return iconPath
    }
    
    ; Try with spaces instead of underscores/dashes
    normalizedName := StrReplace(StrReplace(id, "_", " "), "-", " ")
    iconPath := A_ScriptDir "\Config\icons\" normalizedName ".png"
    if FileExist(iconPath) {
        iconCache[id] := iconPath
        return iconPath
    }
    
    ; Scan folder for normalized match
    normalizedID := StrLower(StrReplace(StrReplace(StrReplace(id, "_", ""), "-", ""), " ", ""))
    try {
        Loop Files A_ScriptDir "\Config\icons\*.png" {
            baseName := SubStr(A_LoopFileName, 1, -4)
            normalizedBase := StrLower(StrReplace(StrReplace(StrReplace(baseName, "_", ""), "-", ""), " ", ""))
            if (normalizedBase = normalizedID) {
                iconCache[id] := A_LoopFileFullPath
                return A_LoopFileFullPath
            }
        }
    }
    
    iconCache[id] := ""
    return ""
}

CreateBlankIcon() {
    blankPath := A_ScriptDir "\Config\icons\blank.png"
    if !FileExist(blankPath) {
        DirCreate(A_ScriptDir "\Config\icons")
        hex := "89504E470D0A1A0A0000000D49484452000000010000000108060000001F15C4890000000A49444154789C63000100000500010D0A2DB40000000049454E44AE426082"
        buf := Buffer(StrLen(hex)//2)
        Loop StrLen(hex)//2
            NumPut("UChar", Integer("0x" SubStr(hex, 2*A_Index-1, 2)), buf, A_Index-1)
        FileOpen(blankPath, "w").RawWrite(buf)
    }
    return blankPath
}

InitIconImageList() {
    ; Use scaled icon size (base 32px)
    iconSizeScaled := Scale(32)
    ; Use ILC_COLOR32 (0x20) only - proper alpha channel support for PNG
    IL_ID := DllCall("Comctl32.dll\ImageList_Create", "Int", iconSizeScaled, "Int", iconSizeScaled, "UInt", 0x20, "Int", OrderedIDs.Length + 2, "Int", 5, "Ptr")
    
    blankPath := CreateBlankIcon()
    if FileExist(blankPath) {
        hBitmap := LoadPngAsHBitmap(blankPath, iconSizeScaled)
        if hBitmap {
            DllCall("Comctl32.dll\ImageList_Add", "Ptr", IL_ID, "Ptr", hBitmap, "Ptr", 0)
            DllCall("DeleteObject", "Ptr", hBitmap)
        }
    }
    
    for id in OrderedIDs {
        if InStr(id, "category_") = 1
            continue
        iconPath := FindIconPath(id)
        if (iconPath != "") {
            hBitmap := LoadPngAsHBitmap(iconPath, iconSizeScaled)
            if hBitmap {
                idx := DllCall("Comctl32.dll\ImageList_Add", "Ptr", IL_ID, "Ptr", hBitmap, "Ptr", 0) + 1
                IconIndexMap[id] := idx
                DllCall("DeleteObject", "Ptr", hBitmap)
            } else {
                IconIndexMap[id] := 1
            }
        } else {
            IconIndexMap[id] := 1
        }
    }
    return IL_ID
}

; Load PNG file and convert to HBITMAP with proper alpha channel using GDI+
LoadPngAsHBitmap(pngPath, targetSize) {
    ; Load PNG using GDI+ (Gdip_All.ahk wrapper)
    pBitmap := Gdip_CreateBitmapFromFile(pngPath)
    if !pBitmap
        return 0
    
    ; Get original dimensions
    origW := Gdip_GetImageWidth(pBitmap)
    origH := Gdip_GetImageHeight(pBitmap)
    
    ; Create destination bitmap with 32-bit PARGB format
    pBitmapDest := Gdip_CreateBitmap(targetSize, targetSize)
    pGraphics := Gdip_GraphicsFromImage(pBitmapDest)
    
    ; Set interpolation quality (0-7)
    Gdip_SetInterpolationMode(pGraphics, 5)
    
    ; Calculate scaling to fit while preserving aspect ratio
    scale := Min(targetSize / origW, targetSize / origH)
    newW := Round(origW * scale)
    newH := Round(origH * scale)
    offsetX := (targetSize - newW) // 2
    offsetY := (targetSize - newH) // 2
    
    ; Draw resized image centered with proper alpha handling
    Gdip_DrawImage(pGraphics, pBitmap, offsetX, offsetY, newW, newH)
    
    ; Convert to HBITMAP with proper alpha (background color = fully transparent)
    hBitmap := Gdip_CreateHBITMAPFromBitmap(pBitmapDest, 0x00000000)
    
    ; Cleanup GDI+ objects
    Gdip_DeleteGraphics(pGraphics)
    Gdip_DisposeImage(pBitmap)
    Gdip_DisposeImage(pBitmapDest)
    
    return hBitmap
}

; ---DATA LOADING---
LoadStratagemsData() {
    global Stratagems, StratagemNames, OrderedIDs, StratagemSections
    
    Stratagems := Map()
    StratagemNames := Map()
    OrderedIDs := []
    StratagemSections := Map()
    
    if !FileExist(StratagemsIniPath)
        return

    try fileContent := FileRead(StratagemsIniPath, "UTF-8")
    catch
        return

    currentSection := ""
    targetSections := "Defensive Stratagems|Offensive Stratagems|Supply Stratagems|Mission Stratagems"
    
    for line in StrSplit(fileContent, "`n", "`r") {
        line := Trim(line)
        if (line = "" || SubStr(line, 1, 1) = ";")
            continue
        if (SubStr(line, 1, 1) = "[" && SubStr(line, -1) = "]") {
            currentSection := SubStr(line, 2, -1)
            continue
        }
        if (currentSection = "" || !InStr(targetSections, currentSection))
            continue

        eqPos := InStr(line, "=")
        if (eqPos = 0)
            continue
            
        id := Trim(SubStr(line, 1, eqPos - 1))
        val := Trim(SubStr(line, eqPos + 1))
        if (id = "" || val = "")
            continue

        ; Handle categories and separators
        if (InStr(id, "category_") = 1 || InStr(id, "separator_") = 1) {
            Stratagems[id] := []
            StratagemNames[id] := (InStr(id, "separator_") = 1) ? " " : val
            OrderedIDs.Push(id)
            continue
        }

        ; Parse name|sequence
        pipePos := InStr(val, "|")
        if (pipePos = 0)
            continue
            
        name := SubStr(val, 1, pipePos - 1)
        seqStr := SubStr(val, pipePos + 1)
        
        seq := []
        for dir in StrSplit(seqStr, ",") {
            dir := Trim(dir)
            if (dir ~= "i)^up$")
                seq.Push("Up")
            else if (dir ~= "i)^down$")
                seq.Push("Down")
            else if (dir ~= "i)^left$")
                seq.Push("Left")
            else if (dir ~= "i)^right$")
                seq.Push("Right")
        }
        
        Stratagems[id] := seq
        StratagemNames[id] := name
        StratagemSections[id] := currentSection
        OrderedIDs.Push(id)
    }
}

; ---GUI HELPERS---
StartMove(*)     => PostMessage(0xA1, 2,,, "A")
StartMoveSel(*)  => PostMessage(0xA1, 2,,, "A")
StartMoveEdit(*) => PostMessage(0xA1, 2,,, "A")