#Requires AutoHotkey v2.0

; Include FindText library and arrow shape database
#Include FindText.ahk
#Include ocr_database.ini

; ============================================================================
; SETTINGS
; ============================================================================
; Base screen size (1440p)
global BaseWidth := 2560
global BaseHeight := 1440

; Arrow detection base values for 1440p
global ArrowStartX := 168
global ArrowStartY := 152
global ArrowStepX := 28.5
global ArrowStepY := 69.75
global ArrowCheckDistance := 8 ; Distance from center to edge for checking (pixels)
global ArrowEdgeStripSize := 12  ; Edge strip size (number of pixels)
global ArrowMinEdgeMatches := 4  ; Minimum matches to determine edge
global ArrowCenterStability := 1  ; Center stability radius (0 = 1 pixel, 1 = 3x3, 2 = 5x5, etc.)

; Arrow color and tolerance
global ArrowColor := 0xB8B59B      ; ARGB format (0xRRGGBB) - R=184, G=181, B=155
global ColorTolerance := 60        ; Color tolerance
global ArrowExtractedColorTolerance := 10  ; Tolerance for matching edges using extracted center color

; Detection method: 0 = Color Detection (default GDI), 1 = Shape Detection (FindText)
global OCR_DetectionMethod := 0

; Shape detection fault tolerance (percentage, default 20% = 0.20)
; Higher tolerance handles bright backgrounds (snow planets) where arrow
; contrast is reduced and grayscale matching needs more leeway
global OCR_ShapeFaultTolerance := 0.20

; Other settings
global MaxArrowsPerRow := 10       ; Maximum arrows per row
global MaxRows := 12               ; Number of stratagem rows
global DebugMode := false          ; Debug mode (show visualization)
global MenuOpenDelay := 200        ; Delay (ms) to wait for stratagem menu to fully open

; Scaled values (computed at startup)
global ScaleX := 1
global ScaleY := 1
global StartX := ArrowStartX
global StartY := ArrowStartY
global StepX := ArrowStepX
global StepY := ArrowStepY
global CheckDistance := ArrowCheckDistance ; Scaled distance for edge check
global EdgeStripSize := ArrowEdgeStripSize  ; Scaled edge strip size
global MinEdgeMatches := ArrowMinEdgeMatches    ; Minimum matches to determine edge
global CenterStability := ArrowCenterStability  ; Scaled center stability radius
global OCR_settingsGui := 0
global OCR_IniPath := A_ScriptDir "\\Config\\settings.ini"
global OCR_ExcludedStratagems := Map()
global OCR_excludeGui := 0
global OCR_DetectedRowsMap := Map()
global HUDScale := 0.90

; Custom Resolution settings
global OCR_UseCustomResolution := false
global OCR_CustomWidth := 2560
global OCR_CustomHeight := 1440
global OCR_ScreenWidth := A_ScreenWidth
global OCR_ScreenHeight := A_ScreenHeight

; Custom Shape Template settings
global OCR_UseCustomShapeTemplate := false
global OCR_CustomShapeTemplate := ""  ; "" means auto-detect, otherwise "1080p"/"1440p"/"2160p"

OCR_LoadSettingsFromIni() {
    global OCR_IniPath
    global ArrowStartX, ArrowStartY, ArrowStepX, ArrowStepY
    global ArrowCheckDistance, ArrowEdgeStripSize, ArrowCenterStability
    global ArrowColor, ColorTolerance, ArrowExtractedColorTolerance, MinEdgeMatches, MaxRows, MaxArrowsPerRow, DebugMode
    global IconSizeOCR, IconStartX, IconStartY, IconVerticalStep, MenuOpenDelay, HUDScale
    global OCR_DetectionMethod, OCR_ShapeFaultTolerance
    global OCR_UseGray2Two, OCR_UseGrayDiff2Two
    global OCR_UseCustomShapeTemplate, OCR_CustomShapeTemplate
    global OCR_UseCustomResolution, OCR_CustomWidth, OCR_CustomHeight
    global OCR_ScreenWidth, OCR_ScreenHeight

    section := "OCR_Detection"
    try {
        ArrowStartX := Number(IniRead(OCR_IniPath, section, "ArrowStartX", ArrowStartX))
        ArrowStartY := Number(IniRead(OCR_IniPath, section, "ArrowStartY", ArrowStartY))
        ArrowStepX := Number(IniRead(OCR_IniPath, section, "ArrowStepX", ArrowStepX))
        ArrowStepY := Number(IniRead(OCR_IniPath, section, "ArrowStepY", ArrowStepY))
        ArrowCheckDistance := Number(IniRead(OCR_IniPath, section, "ArrowCheckDistance", ArrowCheckDistance))
        ArrowEdgeStripSize := Number(IniRead(OCR_IniPath, section, "ArrowEdgeStripSize", ArrowEdgeStripSize))
        ArrowCenterStability := Number(IniRead(OCR_IniPath, section, "ArrowCenterStability", ArrowCenterStability))

        arrowColorRaw := IniRead(OCR_IniPath, section, "ArrowColor", Format("0x{:06X}", ArrowColor))
        ArrowColor := Integer(arrowColorRaw)

        ColorTolerance := Number(IniRead(OCR_IniPath, section, "ColorTolerance", ColorTolerance))
        ArrowExtractedColorTolerance := Number(IniRead(OCR_IniPath, section, "ArrowExtractedColorTolerance", ArrowExtractedColorTolerance))
        MinEdgeMatches := Number(IniRead(OCR_IniPath, section, "MinEdgeMatches", MinEdgeMatches))
        MaxRows := Number(IniRead(OCR_IniPath, section, "MaxRows", MaxRows))
        MaxArrowsPerRow := Number(IniRead(OCR_IniPath, section, "MaxArrowsPerRow", MaxArrowsPerRow))
        DebugMode := IniRead(OCR_IniPath, section, "DebugMode", DebugMode ? "1" : "0") = "1"
        MenuOpenDelay := Number(IniRead(OCR_IniPath, section, "MenuOpenDelay", MenuOpenDelay))
        HUDScale := Number(IniRead(OCR_IniPath, section, "HUDScale", HUDScale))
        OCR_DetectionMethod := Number(IniRead(OCR_IniPath, section, "DetectionMethod", OCR_DetectionMethod))
        OCR_ShapeFaultTolerance := Number(IniRead(OCR_IniPath, section, "ShapeFaultTolerance", OCR_ShapeFaultTolerance))
        
        ; Load icon capture settings
        IconSizeOCR := Number(IniRead(OCR_IniPath, section, "IconSizeOCR", IconSizeOCR))
        IconStartX := Number(IniRead(OCR_IniPath, section, "IconStartX", IconStartX))
        IconStartY := Number(IniRead(OCR_IniPath, section, "IconStartY", IconStartY))
        IconVerticalStep := Number(IniRead(OCR_IniPath, section, "IconVerticalStep", IconVerticalStep))
        
        ; Load pattern selection
        OCR_UseGray2Two := IniRead(OCR_IniPath, section, "UseGray2Two", "1") = "1"
        OCR_UseGrayDiff2Two := IniRead(OCR_IniPath, section, "UseGrayDiff2Two", "1") = "1"
        
        ; Load custom resolution settings
        OCR_UseCustomResolution := IniRead(OCR_IniPath, section, "UseCustomResolution", "0") = "1"
        OCR_CustomWidth := Number(IniRead(OCR_IniPath, section, "CustomWidth", OCR_CustomWidth))
        OCR_CustomHeight := Number(IniRead(OCR_IniPath, section, "CustomHeight", OCR_CustomHeight))
        
        ; Load custom shape template settings
        OCR_UseCustomShapeTemplate := IniRead(OCR_IniPath, section, "UseCustomShapeTemplate", "0") = "1"
        OCR_CustomShapeTemplate := IniRead(OCR_IniPath, section, "CustomShapeTemplate", "")
    } catch {
    }
}

OCR_SaveSettingsToIni() {
    global OCR_IniPath
    global ArrowStartX, ArrowStartY, ArrowStepX, ArrowStepY
    global ArrowCheckDistance, ArrowEdgeStripSize, ArrowCenterStability
    global ArrowColor, ColorTolerance, ArrowExtractedColorTolerance, MinEdgeMatches, MaxRows, MaxArrowsPerRow, DebugMode
    global IconSizeOCR, IconStartX, IconStartY, IconVerticalStep, MenuOpenDelay
    global OCR_DetectionMethod, OCR_ShapeFaultTolerance
    global OCR_UseCustomResolution, OCR_CustomWidth, OCR_CustomHeight
    global OCR_UseCustomShapeTemplate, OCR_CustomShapeTemplate
    global OCR_UseGray2Two, OCR_UseGrayDiff2Two

    section := "OCR_Detection"
    IniWrite(ArrowStartX, OCR_IniPath, section, "ArrowStartX")
    IniWrite(ArrowStartY, OCR_IniPath, section, "ArrowStartY")
    IniWrite(ArrowStepX, OCR_IniPath, section, "ArrowStepX")
    IniWrite(ArrowStepY, OCR_IniPath, section, "ArrowStepY")
    IniWrite(ArrowCheckDistance, OCR_IniPath, section, "ArrowCheckDistance")
    IniWrite(ArrowEdgeStripSize, OCR_IniPath, section, "ArrowEdgeStripSize")
    IniWrite(ArrowCenterStability, OCR_IniPath, section, "ArrowCenterStability")
    IniWrite(Format("0x{:06X}", ArrowColor), OCR_IniPath, section, "ArrowColor")
    IniWrite(ColorTolerance, OCR_IniPath, section, "ColorTolerance")
    IniWrite(ArrowExtractedColorTolerance, OCR_IniPath, section, "ArrowExtractedColorTolerance")
    IniWrite(MinEdgeMatches, OCR_IniPath, section, "MinEdgeMatches")
    IniWrite(MaxRows, OCR_IniPath, section, "MaxRows")
    IniWrite(MaxArrowsPerRow, OCR_IniPath, section, "MaxArrowsPerRow")
    IniWrite(DebugMode ? "1" : "0", OCR_IniPath, section, "DebugMode")
    IniWrite(MenuOpenDelay, OCR_IniPath, section, "MenuOpenDelay")
    IniWrite(Format("{:.2f}", HUDScale), OCR_IniPath, section, "HUDScale")
    IniWrite(OCR_DetectionMethod, OCR_IniPath, section, "DetectionMethod")
    IniWrite(Format("{:.2f}", OCR_ShapeFaultTolerance), OCR_IniPath, section, "ShapeFaultTolerance")
    
    ; Save icon capture settings
    IniWrite(IconSizeOCR, OCR_IniPath, section, "IconSizeOCR")
    IniWrite(IconStartX, OCR_IniPath, section, "IconStartX")
    IniWrite(IconStartY, OCR_IniPath, section, "IconStartY")
    IniWrite(IconVerticalStep, OCR_IniPath, section, "IconVerticalStep")
    
    ; Save pattern selection
    IniWrite(OCR_UseGray2Two ? "1" : "0", OCR_IniPath, section, "UseGray2Two")
    IniWrite(OCR_UseGrayDiff2Two ? "1" : "0", OCR_IniPath, section, "UseGrayDiff2Two")
    
    ; Save custom resolution settings
    IniWrite(OCR_UseCustomResolution ? "1" : "0", OCR_IniPath, section, "UseCustomResolution")
    IniWrite(OCR_CustomWidth, OCR_IniPath, section, "CustomWidth")
    IniWrite(OCR_CustomHeight, OCR_IniPath, section, "CustomHeight")
    
    ; Save custom shape template settings
    IniWrite(OCR_UseCustomShapeTemplate ? "1" : "0", OCR_IniPath, section, "UseCustomShapeTemplate")
    IniWrite(OCR_CustomShapeTemplate, OCR_IniPath, section, "CustomShapeTemplate")
}

OCR_LoadExcludedFromIni() {
    global OCR_IniPath, OCR_ExcludedStratagems
    OCR_ExcludedStratagems := Map()
    try {
        csv := IniRead(OCR_IniPath, "OCR_Detection", "ExcludedIDs", "")
        if (csv != "") {
            for id in StrSplit(csv, ",") {
                id := Trim(id)
                if (id != "")
                    OCR_ExcludedStratagems[id] := true
            }
        }
    } catch {
    }
}

OCR_SaveExcludedToIni() {
    global OCR_IniPath, OCR_ExcludedStratagems
    csv := ""
    for id in OCR_ExcludedStratagems {
        if (csv != "")
            csv .= ","
        csv .= id
    }
    IniWrite(csv, OCR_IniPath, "OCR_Detection", "ExcludedIDs")
}

OCR_IsExcluded(id) {
    global OCR_ExcludedStratagems
    return OCR_ExcludedStratagems.Has(id)
}

OCR_GetAllStratagemDefinitions() {
    defs := []
    iniPath := A_ScriptDir "\\Config\\stratagems.ini"
    try {
        content := FileRead(iniPath)
        Loop Parse, content, "`n", "`r" {
            line := Trim(A_LoopField)
            if (line = "" || SubStr(line, 1, 1) = ";" || SubStr(line, 1, 1) = "[")
                continue
            if (!InStr(line, "|") || !InStr(line, "="))
                continue

            parts := StrSplit(line, "|")
            if (parts.Length < 1)
                continue

            keyName := parts[1]
            eqPos := InStr(keyName, "=")
            if (!eqPos)
                continue

            id := Trim(SubStr(keyName, 1, eqPos - 1))
            name := Trim(SubStr(keyName, eqPos + 1))
            if (id != "" && name != "")
                defs.Push({id: id, name: name})
        }
    } catch {
    }
    return defs
}

OCR_ShowExcludeWindow() {
    global OCR_excludeGui, OCR_ExcludedStratagems

    defs := OCR_GetAllStratagemDefinitions()

    if (IsObject(OCR_excludeGui)) {
        try OCR_excludeGui.Destroy()
    }

    OCR_excludeGui := Gui(, "OCR Excluded Stratagems")
    OCR_excludeGui.MarginX := 12
    OCR_excludeGui.MarginY := 12
    OCR_excludeGui.OnEvent("Close", (*) => OCR_excludeGui.Hide())

    OCR_excludeGui.Add("Text", "x12 y10 w320", "Checked stratagems will be excluded from OCR profile updates")

    lv := OCR_excludeGui.Add("ListView", "x12 y35 w355 h360 Checked -Multi", ["Stratagem", "ID"])
    lv.ModifyCol(1, 180)
    lv.ModifyCol(2, 140)

    for item in defs {
        row := lv.Add("", item.name, item.id)
        if (OCR_ExcludedStratagems.Has(item.id))
            lv.Modify(row, "+Check")
    }

    btnSave := OCR_excludeGui.Add("Button", "x73 y405 w110", "Save")
    btnClear := OCR_excludeGui.Add("Button", "x+15 y405 w110", "Clear")

    btnSave.OnEvent("Click", (*) => OCR_SaveExclusionsFromList(lv))
    btnClear.OnEvent("Click", (*) => OCR_ClearExclusionsFromList(lv))

    OCR_excludeGui.OnEvent("Escape", (*) => OCR_excludeGui.Destroy())
    OCR_excludeGui.Show("w380 h445 Center")
}

OCR_SaveExclusionsFromList(lv) {
    global OCR_ExcludedStratagems
    OCR_ExcludedStratagems := Map()
    Loop lv.GetCount() {
        if (lv.GetNext(A_Index - 1, "C") = A_Index) {
            id := lv.GetText(A_Index, 2)
            if (id != "")
                OCR_ExcludedStratagems[id] := true
        }
    }
    OCR_SaveExcludedToIni()
    ToolTip("Exclusions saved", A_ScreenWidth/2, 50)
    SetTimer(() => ToolTip(), -1500)
}

OCR_ClearExclusionsFromList(lv) {
    global OCR_ExcludedStratagems
    OCR_ExcludedStratagems := Map()
    Loop lv.GetCount()
        lv.Modify(A_Index, "-Check")
    OCR_SaveExcludedToIni()
    ToolTip("Exclusions cleared", A_ScreenWidth/2, 50)
    SetTimer(() => ToolTip(), -1500)
}

; ============================================================================
; SCALING FUNCTION
; ============================================================================
OCR_Scale(value, dimension := "X") {
    global ScaleX, ScaleY
    if (dimension = "X")
        return Round(value * ScaleX)
    else
        return Round(value * ScaleY)
}

OCR_InitScaling() {
    global ScaleX, ScaleY, BaseWidth, BaseHeight
    global StartX, StartY, StepX, StepY, CheckDistance, EdgeStripSize, CenterStability
    global ArrowStartX, ArrowStartY, ArrowStepX, ArrowStepY, ArrowCheckDistance, ArrowEdgeStripSize, ArrowCenterStability
    global HUDScale
    global OCR_UseCustomResolution, OCR_CustomWidth, OCR_CustomHeight
    global OCR_ScreenWidth, OCR_ScreenHeight
    
    ; Determine effective screen dimensions (use custom resolution if enabled)
    if (OCR_UseCustomResolution && OCR_CustomWidth > 0 && OCR_CustomHeight > 0) {
        OCR_ScreenWidth := OCR_CustomWidth
        OCR_ScreenHeight := OCR_CustomHeight
    } else {
        OCR_ScreenWidth := A_ScreenWidth
        OCR_ScreenHeight := A_ScreenHeight
    }
    
    ; Possible ultra-wide screens fix: Limit effective width to 16:9 ratio to prevent excessive horizontal scaling
    effectiveWidth := Min(OCR_ScreenWidth, Round(OCR_ScreenHeight * 16 / 9))
    ScaleX := effectiveWidth / BaseWidth
    ScaleY := OCR_ScreenHeight / BaseHeight
    
    HUDScaleFactor := HUDScale / 0.90
    
    StartX := Round(ArrowStartX * ScaleX * HUDScaleFactor)
    StartY := Round(ArrowStartY * ScaleY * HUDScaleFactor)
    StepX := ArrowStepX * ScaleX * HUDScaleFactor
    StepY := ArrowStepY * ScaleY * HUDScaleFactor
    CheckDistance := Round(ArrowCheckDistance * ScaleY * HUDScaleFactor)
    EdgeStripSize := Max(2, Round(ArrowEdgeStripSize * ScaleY * HUDScaleFactor))  ; Minimum 2 pixels
    CenterStability := Max(0, Round(ArrowCenterStability * ScaleY * HUDScaleFactor))  ; Minimum 0
    
    ; Scaling initialized silently for debug mode
}

; ============================================================================
; MAIN SCANNING FUNCTION
; ============================================================================
ScanAllStratagems() {
    global pToken, StartX, StartY, StepX, StepY, MaxArrowsPerRow, MaxRows, OCR_ScreenWidth, OCR_ScreenHeight
    
    ; For shape detection: reset cache so FindText re-scans the screen
    ShapeResetCache()
    
    ; Get screen dimensions
    ScreenWidth := OCR_ScreenWidth
    ScreenHeight := OCR_ScreenHeight
    
    ; Create a screen bitmap
    hbm := CreateDIBSection(ScreenWidth, ScreenHeight)
    hdc := CreateCompatibleDC()
    obm := SelectObject(hdc, hbm)
    G := Gdip_GraphicsFromHDC(hdc)
    bitmap := Gdip_BitmapFromScreen()
    
    ; Array for found stratagems
    foundStratagems := []
    
    ; Scan each stratagem row
    Loop MaxRows {
        row := A_Index
        currentY := StartY + (row - 1) * StepY
        
        if (currentY > ScreenHeight - 30)
            break
        
        ; Scan arrows in the current row
        arrows := ScanArrowRow(bitmap, currentY, ScreenWidth)
        
        if (arrows.Length > 0) {
            ; Collect directions
            directions := []
            for arrow in arrows {
                directions.Push(arrow.direction)
            }
            
            ; Count valid (non-empty, non-ambiguous) detected directions
            validCount := 0
            for dir in directions {
                if (dir != "" && dir != "?")
                    validCount++
            }
            
            ; Require at least 3 valid arrow directions to identify a stratagem
            ; Rows with fewer arrows are likely false positives (UI elements, noise)
            if (validCount < 3) {
                foundStratagems.Push({
                    id: "unknown",
                    name: "Unknown",
                    row: row,
                    x: arrows[1].x,
                    y: arrows[1].y,
                    directions: ArrayToString(directions)
                })
                continue
            }
            
            ; Find matching stratagem
            stratagem := FindStratagem(directions)
            
        if (stratagem != "") {
            foundStratagems.Push({
                id: stratagem.id,
                name: stratagem.name,
                row: row,
                x: arrows[1].x,
                y: arrows[1].y,
                directions: ArrayToString(directions)
            })
        } else {
            ; If not found, store as unknown
            foundStratagems.Push({
                id: "unknown",
                name: "Unknown",
                row: row,
                x: arrows[1].x,
                y: arrows[1].y,
                directions: ArrayToString(directions)
            })
        }
        }
    }
    
    ; Clean up resources
    Gdip_DisposeImage(bitmap)
    Gdip_DeleteGraphics(G)
    SelectObject(hdc, obm)
    DeleteObject(hbm)
    DeleteDC(hdc)
    
    return foundStratagems
}

; Returns first detected arrow sequence from the screen (top-to-bottom scan order)
; Output: Array of directions, e.g. ["Down", "Left", "Up"]
OCR_GetFirstDetectedDirections() {
    global StartY, StepY, MaxRows, DebugMode, OCR_ScreenWidth, OCR_ScreenHeight

    ; Get screen dimensions
    ScreenWidth := OCR_ScreenWidth
    ScreenHeight := OCR_ScreenHeight

    ; Capture screen bitmap
    hbm := CreateDIBSection(ScreenWidth, ScreenHeight)
    hdc := CreateCompatibleDC()
    obm := SelectObject(hdc, hbm)
    G := Gdip_GraphicsFromHDC(hdc)
    bitmap := Gdip_BitmapFromScreen()

    firstDirections := []

    ; Scan rows from top to bottom and return the first valid arrow row
    ; Skip first two rows (Reinforce and Resupply) for OCR Objective
    Loop MaxRows {
        if (A_Index <= 2)
            continue
        currentY := StartY + (A_Index - 1) * StepY
        if (currentY > ScreenHeight - 30)
            break

        arrows := ScanArrowRow(bitmap, currentY, ScreenWidth)
        if (arrows.Length > 0) {
            for arrow in arrows
                firstDirections.Push(arrow.direction)
            break
        }
    }

    ; Clean up resources
    Gdip_DisposeImage(bitmap)
    Gdip_DeleteGraphics(G)
    SelectObject(hdc, obm)
    DeleteObject(hbm)
    DeleteDC(hdc)

    ; Auto-clear debug visualization after 3 seconds (for OCR Objective)
    if (DebugMode)
        SetTimer(ClearDebugVisualization, -3000)

    return firstDirections
}

; Returns arrow sequence from a specific OCR row (1-based)
; Filters out empty padding entries so the returned sequence contains
; only actual detected directions (safe to pass to key mapping functions)
OCR_GetDirectionsByRow(rowNumber) {
    global StartY, StepY, OCR_ScreenWidth, OCR_ScreenHeight

    if (rowNumber < 1)
        return []

    ScreenWidth := OCR_ScreenWidth
    ScreenHeight := OCR_ScreenHeight

    currentY := StartY + (rowNumber - 1) * StepY
    if (currentY > ScreenHeight - 30)
        return []

    hbm := CreateDIBSection(ScreenWidth, ScreenHeight)
    hdc := CreateCompatibleDC()
    obm := SelectObject(hdc, hbm)
    G := Gdip_GraphicsFromHDC(hdc)
    bitmap := Gdip_BitmapFromScreen()

    directions := []
    arrows := ScanArrowRow(bitmap, currentY, ScreenWidth)
    for arrow in arrows {
        ; Filter out empty padding AND "?" (ambiguous tie direction)
        ; Only pass valid directions (Up, Down, Left, Right) to key mapping
        if (arrow.direction != "" && arrow.direction != "?")
            directions.Push(arrow.direction)
    }

    Gdip_DisposeImage(bitmap)
    Gdip_DeleteGraphics(G)
    SelectObject(hdc, obm)
    DeleteObject(hbm)
    DeleteDC(hdc)

    return directions
}

; Scan a single arrow row
ScanArrowRow(bitmap, rowY, ScreenWidth) {
    global StartX, StepX, MaxArrowsPerRow, OCR_DetectionMethod
    
    arrows := []
    currentX := StartX
    foundArrow := false  ; Track if we've detected at least one real arrow
    
    Loop MaxArrowsPerRow {
        if (currentX > ScreenWidth - 20)
            break
        
        direction := DetectArrowDirection(bitmap, currentX, rowY)
        if (direction != "") {
            arrows.Push({x: currentX, y: rowY, direction: direction})
            foundArrow := true
        } else if (OCR_DetectionMethod = 0) {
            ; Color detection: arrows are sequential, so first miss = end of row
            break
        } else {
            ; Shape detection: always record every grid position to maintain
            ; proper sequence alignment. Undetected arrows at any position
            ; (start, middle, or end) become empty padding.
            arrows.Push({x: currentX, y: rowY, direction: ""})
        }
        currentX += StepX
    }
    
    ; Only return arrows if at least one real direction was found
    if (!foundArrow)
        return []
    
    return arrows
}

; ============================================================================
; ARROW DIRECTION DETECTION DISPATCHER
; ============================================================================
DetectArrowDirection(bitmap, centerX, centerY) {
    global OCR_DetectionMethod
    
    if (OCR_DetectionMethod = 1)
        return DetectArrowDirection_Shape(centerX, centerY)
    else
        return DetectArrowDirection_Color(bitmap, centerX, centerY)
}

; ============================================================================
; COLOR-BASED ARROW DIRECTION DETECTION (original method)
; ============================================================================
DetectArrowDirection_Color(bitmap, centerX, centerY) {
    global ArrowColor, ColorTolerance, ArrowExtractedColorTolerance, CheckDistance, DebugMode, EdgeStripSize, CenterStability, ScramblerSuppressDebug
    
    ; Check if debug should be suppressed (during Scrambler bypass)
    showDebug := DebugMode && !ScramblerSuppressDebug
    
    ; Multi-monitor fix: Offset coordinates by virtual screen origin
    VirtualScreenLeft := SysGet(76)  ; SM_XVIRTUALSCREEN
    VirtualScreenTop  := SysGet(77)  ; SM_YVIRTUALSCREEN
    bitmapX := centerX - VirtualScreenLeft
    bitmapY := centerY - VirtualScreenTop
    
    ; Check center stability (all pixels in area must match)
    if (!IsCenterStable(bitmap, bitmapX, bitmapY)) {
        ; Show a cross if center read fails — this means NO arrow at this position
        if (showDebug) {
            centerX_s := centerX
            centerY_s := centerY
            ; Draw visualization with empty direction (triggers cross/plus drawing)
            ShowDebugVisualization(centerX_s, centerY_s, [], [], [], [], "", 0, 0, 0, 0)
        }
        return ""    ; Empty = no arrow found, ScanArrowRow will stop
    }
    
    ; Center is stable — an arrow exists at this position.
    ; Extract the actual center pixel color to use for more precise edge matching
    extractedColor := 0
    try {
        centerPixel := Gdip_GetPixel(bitmap, bitmapX, bitmapY)
        ; Extract RGB from ARGB (0xAARRGGBB)
        r := (centerPixel >> 16) & 0xFF
        g := (centerPixel >> 8) & 0xFF
        b := centerPixel & 0xFF
        extractedColor := (r << 16) | (g << 8) | b
    } catch {
        ; Fall back to global ArrowColor if pixel read fails
        extractedColor := ArrowColor
    }
    
    ; Check 4 edges at CheckDistance from center
    ; Edge with most matches is opposite to arrow direction
    
    halfStrip := EdgeStripSize // 2  ; Half strip size for centering
    
    ; Top edge - check horizontal strip
    topMatches := 0
    topPixels := []
    Loop EdgeStripSize {
        offsetX := A_Index - halfStrip - 1
        px := bitmapX + offsetX
        py := bitmapY - CheckDistance
        match := IsColorMatch(bitmap, px, py, extractedColor, ArrowExtractedColorTolerance)
        if (match)
            topMatches++
        topPixels.Push({x: px, y: py, match: match})
    }
    
    ; Bottom edge - check horizontal strip
    bottomMatches := 0
    bottomPixels := []
    Loop EdgeStripSize {
        offsetX := A_Index - halfStrip - 1
        px := bitmapX + offsetX
        py := bitmapY + CheckDistance
        match := IsColorMatch(bitmap, px, py, extractedColor, ArrowExtractedColorTolerance)
        if (match)
            bottomMatches++
        bottomPixels.Push({x: px, y: py, match: match})
    }
    
    ; Left edge - check vertical strip
    leftMatches := 0
    leftPixels := []
    Loop EdgeStripSize {
        offsetY := A_Index - halfStrip - 1
        px := bitmapX - CheckDistance
        py := bitmapY + offsetY
        match := IsColorMatch(bitmap, px, py, extractedColor, ArrowExtractedColorTolerance)
        if (match)
            leftMatches++
        leftPixels.Push({x: px, y: py, match: match})
    }
    
    ; Right edge - check vertical strip
    rightMatches := 0
    rightPixels := []
    Loop EdgeStripSize {
        offsetY := A_Index - halfStrip - 1
        px := bitmapX + CheckDistance
        py := bitmapY + offsetY
        match := IsColorMatch(bitmap, px, py, extractedColor, ArrowExtractedColorTolerance)
        if (match)
            rightMatches++
        rightPixels.Push({x: px, y: py, match: match})
    }
    
    ; Determine direction by maximum matches
    ; Edge with most matches is OPPOSITE to arrow direction
    maxMatches := Max(topMatches, bottomMatches, leftMatches, rightMatches)
    
    ; If multiple edges tie for max matches, we can't determine direction reliably
    ; But the arrow IS there (center stable). Return "?" as unknown direction.
    tieCount := 0
    if (topMatches = maxMatches)
        tieCount++
    if (bottomMatches = maxMatches)
        tieCount++
    if (leftMatches = maxMatches)
        tieCount++
    if (rightMatches = maxMatches)
        tieCount++
    
    direction := ""
    if (tieCount = 1) {
        ; Single best-matching edge - determine direction normally
        if (topMatches = maxMatches)
            direction := "Down"       ; Top edge matched -> arrow points down
        else if (bottomMatches = maxMatches)
            direction := "Up"         ; Bottom edge matched -> arrow points up
        else if (leftMatches = maxMatches)
            direction := "Right"      ; Left edge matched -> arrow points right
        else if (rightMatches = maxMatches)
            direction := "Left"       ; Right edge matched -> arrow points left
    } else {
        ; Arrow exists but direction ambiguous — return "?" so caller can
        ; treat it as "unknown direction" rather than "no arrow here"
        direction := "?"
    }
    ; "?" is treated as wildcard by sequential filter, and as "arrow found"
    ; by ScanArrowRow (doesn't break the row scan)
    
    ; Debug visualization - always show aiming square, even if direction detection is incomplete
    if (showDebug) {
        ; Convert bitmap coordinates back to absolute screen coordinates for debug drawing
        Loop topPixels.Length {
            topPixels[A_Index].x += VirtualScreenLeft
            topPixels[A_Index].y += VirtualScreenTop
        }
        Loop bottomPixels.Length {
            bottomPixels[A_Index].x += VirtualScreenLeft
            bottomPixels[A_Index].y += VirtualScreenTop
        }
        Loop leftPixels.Length {
            leftPixels[A_Index].x += VirtualScreenLeft
            leftPixels[A_Index].y += VirtualScreenTop
        }
        Loop rightPixels.Length {
            rightPixels[A_Index].x += VirtualScreenLeft
            rightPixels[A_Index].y += VirtualScreenTop
        }
        ShowDebugVisualization(centerX, centerY, topPixels, bottomPixels, leftPixels, rightPixels, direction, topMatches, bottomMatches, leftMatches, rightMatches)
    }
    
    if (maxMatches < MinEdgeMatches) {  ; Minimum matches for confidence
        return ""
    }
    
    return direction
}

; ============================================================================
; SHAPE-BASED ARROW DIRECTION DETECTION (FindText method)
; ============================================================================
; Gets the appropriate FindText arrow strings based on effective screen resolution
; Uses OCR_ScreenWidth/Height (which already accounts for custom resolution settings)
; and picks the closest matching resolution tier from the database
; If OCR_UseCustomShapeTemplate is enabled uses that from ddl

OCR_GetShapeTemplateResolution() {
    global ArrowsDB, OCR_ScreenHeight
    global OCR_UseCustomShapeTemplate, OCR_CustomShapeTemplate

    ; If custom template is enabled and set, use it directly
    if (OCR_UseCustomShapeTemplate && OCR_CustomShapeTemplate != "") {
        if (ArrowsDB.Has(OCR_CustomShapeTemplate))
            return OCR_CustomShapeTemplate
    }

    ; Auto-detect based on screen height
    screenH := OCR_ScreenHeight
    resKey := "1080p"
    if (screenH > 1600)
        resKey := "2160p"
    else if (screenH > 1200)
        resKey := "1440p"

    ; Ensure the database has this resolution key
    if (!ArrowsDB.Has(resKey))
        return "1080p"

    ; The resolution exists - return it
    return resKey
}

GetArrowFindTextStrings() {
    global ArrowsDB
    
    ; Use the unified resolution selection function that handles custom template override
    resKey := OCR_GetShapeTemplateResolution()
    
    if (!ArrowsDB.Has(resKey))
        return ""
    
    ; Combine all direction and mode text strings into a single FindText query
    result := ""
    dirs := ["UP", "DOWN", "LEFT", "RIGHT"]
    for dir in dirs {
        if (ArrowsDB[resKey].Has(dir)) {
            for mode, textString in ArrowsDB[resKey][dir] {
                result .= textString
            }
        }
    }
    
    return result
}

; Pattern data selection: flags to choose which FindText patterns to use
global OCR_UseGray2Two := true
global OCR_UseGrayDiff2Two := true

; One pattern per direction
global ShapeArrowPatterns := Map()

ShapeInitPatterns() {
    global ArrowsDB, ShapeArrowPatterns
    global OCR_UseGray2Two, OCR_UseGrayDiff2Two
    
    ; Use the unified resolution selection function that handles custom template override
    resKey := OCR_GetShapeTemplateResolution()
    
    if (!ArrowsDB.Has(resKey))
        return false
    
    ; Build patterns based on user selection of Gray2Two and GrayDiff2Two
    ShapeArrowPatterns := Map()
    
    ShapeArrowPatterns["UP"] := ""
    if (OCR_UseGray2Two)
        ShapeArrowPatterns["UP"] .= ArrowsDB[resKey]["UP"]["Gray2Two"]
    if (OCR_UseGrayDiff2Two)
        ShapeArrowPatterns["UP"] .= ArrowsDB[resKey]["UP"]["GrayDiff2Two"]
    
    ShapeArrowPatterns["DOWN"] := ""
    if (OCR_UseGray2Two)
        ShapeArrowPatterns["DOWN"] .= ArrowsDB[resKey]["DOWN"]["Gray2Two"]
    if (OCR_UseGrayDiff2Two)
        ShapeArrowPatterns["DOWN"] .= ArrowsDB[resKey]["DOWN"]["GrayDiff2Two"]
    
    ShapeArrowPatterns["LEFT"] := ""
    if (OCR_UseGray2Two)
        ShapeArrowPatterns["LEFT"] .= ArrowsDB[resKey]["LEFT"]["Gray2Two"]
    if (OCR_UseGrayDiff2Two)
        ShapeArrowPatterns["LEFT"] .= ArrowsDB[resKey]["LEFT"]["GrayDiff2Two"]
    
    ShapeArrowPatterns["RIGHT"] := ""
    if (OCR_UseGray2Two)
        ShapeArrowPatterns["RIGHT"] .= ArrowsDB[resKey]["RIGHT"]["Gray2Two"]
    if (OCR_UseGrayDiff2Two)
        ShapeArrowPatterns["RIGHT"] .= ArrowsDB[resKey]["RIGHT"]["GrayDiff2Two"]
    
    ; Ensure at least one pattern was loaded
    if (ShapeArrowPatterns["UP"] = "" && ShapeArrowPatterns["DOWN"] = "" 
        && ShapeArrowPatterns["LEFT"] = "" && ShapeArrowPatterns["RIGHT"] = "")
        return false
    
    return true
}

; Cached results from one full scan across all 4 directions
global ShapeAllArrowsCache := []
global ShapeCacheScanned := false

; Do ONE scan across all directions (like pressing F1,F2,F3,F4), cache results
ShapeScanAllDirections() {
    global ShapeArrowPatterns, OCR_ShapeFaultTolerance, ShapeAllArrowsCache, ShapeCacheScanned
    global StartX, StartY, StepX, StepY, MaxRows, MaxArrowsPerRow, OCR_ScreenWidth, OCR_ScreenHeight
    
    ; Only scan once
    if (ShapeCacheScanned)
        return
    
    if (ShapeArrowPatterns.Count = 0)
        ShapeInitPatterns()
    if (ShapeArrowPatterns.Count = 0)
        return
    
    ; Calculate the arrow grid region (same as color detection uses)
    padding := 40
    lastRowY := StartY + (MaxRows - 1) * StepY
    lastColX := StartX + (MaxArrowsPerRow - 1) * StepX
    
    regionX1 := Max(0, Round(StartX) - padding)
    regionY1 := Max(0, Round(StartY) - padding)
    regionX2 := Min(OCR_ScreenWidth, Round(lastColX) + padding)
    regionY2 := Min(OCR_ScreenHeight, Round(lastRowY) + padding)
    
    local ftX, ftY
    ShapeAllArrowsCache := []
    
    ; Search each direction across the arrow grid
    dirs := [["UP", "Up"], ["DOWN", "Down"], ["LEFT", "Left"], ["RIGHT", "Right"]]
    for i, dirPair in dirs {
        dirKey := dirPair[1]
        dirName := dirPair[2]
        
        if (!ShapeArrowPatterns.Has(dirKey))
            continue
        
        ; First call captures screen, subsequent calls reuse it
        screenShot := (i = 1) ? 1 : 0
        
        result := FindText(&ftX, &ftY, regionX1, regionY1, regionX2, regionY2,
            OCR_ShapeFaultTolerance, OCR_ShapeFaultTolerance, ShapeArrowPatterns[dirKey], screenShot, 1)
        
        ; FindText returns ALL matches for this direction
        if (IsObject(result)) {
            for item in result {
                ShapeAllArrowsCache.Push({
                    x: item.x,
                    y: item.y,
                    direction: dirName
                })
            }
        }
    }
    
    ShapeCacheScanned := true
}

; Reset the cache so next scan re-searches the screen
; Also clears the "used" flags so arrows can be matched again on next scan
; Clears the pattern map so ShapeInitPatterns re-builds with current settings
ShapeResetCache() {
    global ShapeCacheScanned, ShapeAllArrowsCache, ShapeArrowPatterns
    
    ShapeCacheScanned := false
    
    ; Clear the pattern map so ShapeInitPatterns is forced to rebuild on next scan
    ; This ensures pattern selection (Gray2Two/GrayDiff2Two) takes effect immediately
    ShapeArrowPatterns := Map()
    
    ; Clear "used" flags on all cached arrows so they can be re-matched
    for arrow in ShapeAllArrowsCache {
        if (arrow.HasOwnProp("used"))
            arrow.DeleteProp("used")
    }
}

DetectArrowDirection_Shape(centerX, centerY) {
    global ShapeAllArrowsCache, DebugMode, ScramblerSuppressDebug, StepX, StepY
    
    showDebug := DebugMode && !ScramblerSuppressDebug
    
    ; Do one full scan of all directions and cache results
    ShapeScanAllDirections()
    
    if (ShapeAllArrowsCache.Length = 0)
        return ""
    
    ; Find closest unused cached arrow to this grid position
    ; Use a tight distance threshold proportional to arrow spacing to prevent
    ; the same arrow from matching multiple grid positions (phantom arrows)
    maxDist := Max(StepX * 0.6, 20)  ; Never exceed ~60% of horizontal step distance
    
    bestIdx := -1
    bestDist := maxDist + 1
    bestDir := ""
    
    for idx, arrow in ShapeAllArrowsCache {
        ; Skip already-consumed arrows (prevents phantom arrow duplicates)
        if (arrow.HasOwnProp("used") && arrow.used)
            continue
        
        dx := arrow.x - centerX
        dy := arrow.y - centerY
        dist := Sqrt(dx*dx + dy*dy)
        
        if (dist < bestDist) {
            bestDist := dist
            bestDir := arrow.direction
            bestIdx := idx
        }
    }
    
    if (bestDist <= maxDist && bestDir != "" && bestIdx > 0) {
        ; Mark arrow as used so it can't match another grid position
        ShapeAllArrowsCache[bestIdx].used := true
        
        if (showDebug)
            ShowDebugVisualization_Shape(centerX, centerY, bestDir)
        return bestDir
    }
    
    return ""
}

; ============================================================================
; DEBUG VISUALIZATION FOR SHAPE DETECTION
; ============================================================================
ShowDebugVisualization_Shape(centerX, centerY, direction) {
    overlay := Gui("+AlwaysOnTop -Caption +ToolWindow +E0x20 +E0x80000", "DbgShape")
    overlay.BackColor := "000001"
    overlay.Show("x0 y0 w" A_ScreenWidth " h" A_ScreenHeight " NA")
    WinSetTransColor("000001", overlay.Hwnd)
    
    hdc := DllCall("GetDC", "Ptr", overlay.Hwnd, "Ptr")
    G := Gdip_GraphicsFromHDC(hdc)
    Gdip_SetSmoothingMode(G, 2)
    
    ; Draw green center dot for successful detection
    brush := Gdip_BrushCreateSolid(0xFF00FF00)
    Gdip_FillEllipse(G, brush, centerX - 2, centerY - 2, 5, 5)
    Gdip_DeleteBrush(brush)
    
    ; Draw direction line from center outward
    penDir := Gdip_CreatePen(0xFF00FF00, 2)
    switch direction {
        case "Up":
            Gdip_DrawLine(G, penDir, centerX, centerY, centerX, centerY - 15)
        case "Down":
            Gdip_DrawLine(G, penDir, centerX, centerY, centerX, centerY + 15)
        case "Left":
            Gdip_DrawLine(G, penDir, centerX, centerY, centerX - 15, centerY)
        case "Right":
            Gdip_DrawLine(G, penDir, centerX, centerY, centerX + 15, centerY)
    }
    Gdip_DeletePen(penDir)
    
    Gdip_DeleteGraphics(G)
    DllCall("ReleaseDC", "Ptr", overlay.Hwnd, "Ptr", hdc)
    
    global debugGuiList
    debugGuiList.Push(overlay)
}

; ============================================================================
; PERSISTENT GRID OVERLAY - Always visible when DebugMode is ON
; ============================================================================
global debugGridOverlay := 0

; Show the persistent aiming grid overlay (stays until hidden)
ShowAimingGrid() {
    global StartX, StartY, StepX, StepY, MaxRows, MaxArrowsPerRow, CheckDistance, OCR_ScreenWidth, OCR_ScreenHeight
    global debugGridOverlay, ScramblerSuppressDebug
    global IconStartXScaled, IconStartYScaled, IconVerticalStepScaled, IconSizeScaled
    
    ; Destroy existing grid overlay if any
    HideAimingGrid()
    
    if (ScramblerSuppressDebug)
        return
    
    ; Create a single overlay GUI covering the full screen
    debugGridOverlay := Gui("+AlwaysOnTop -Caption +ToolWindow +E0x20 +E0x80000", "DbgGrid")
    debugGridOverlay.BackColor := "000001"
    debugGridOverlay.Show("x0 y0 w" A_ScreenWidth " h" A_ScreenHeight " NA")
    WinSetTransColor("000001", debugGridOverlay.Hwnd)
    
    hdc := DllCall("GetDC", "Ptr", debugGridOverlay.Hwnd, "Ptr")
    G := Gdip_GraphicsFromHDC(hdc)
    Gdip_SetSmoothingMode(G, 0)  ; No anti-aliasing for grid - ensures uniform 1px thickness
    
    squareOffset := CheckDistance + 3
    penGrid := Gdip_CreatePen(0x30FFFFFF, 1)  ; Very subtle white squares
    
    Loop MaxRows {
        row := A_Index
        currentY := StartY + (row - 1) * StepY
        
        if (currentY > OCR_ScreenHeight - 30)
            break
        
        Loop MaxArrowsPerRow {
            col := A_Index
            currentX := StartX + (col - 1) * StepX
            
            if (currentX > OCR_ScreenWidth - 20)
                break
            
            ; Draw small aiming square at this grid position (rounded to prevent variable thickness from subpixel rendering)
            Gdip_DrawRectangle(G, penGrid,
                Round(currentX) - squareOffset, Round(currentY) - squareOffset,
                squareOffset * 2, squareOffset * 2)
        }
    }
    
    Gdip_DeletePen(penGrid)
    
    ; ========================================================================
    ; Draw icon capture position boxes (Scrambler Bypass)
    ; Transparent cyan outline boxes showing where icons are extracted
    ; ========================================================================
    penIcon := Gdip_CreatePen(0x6000FFFF, 1)  ; Cyan outline (transparent, 1px)
    
    Loop MaxRows {
        row := A_Index
        iconY := IconStartYScaled + (row - 1) * IconVerticalStepScaled
        
        ; Check if within screen bounds
        if (iconY + IconSizeScaled > OCR_ScreenHeight || iconY < 0)
            continue
        
        ; Draw outline rectangle at icon capture position
        Gdip_DrawRectangle(G, penIcon,
            IconStartXScaled, iconY,
            IconSizeScaled, IconSizeScaled)
    }
    
    Gdip_DeletePen(penIcon)
    
    Gdip_DeleteGraphics(G)
    DllCall("ReleaseDC", "Ptr", debugGridOverlay.Hwnd, "Ptr", hdc)
}

; Hide the persistent aiming grid overlay
HideAimingGrid() {
    global debugGridOverlay
    
    if (IsObject(debugGridOverlay)) {
        try debugGridOverlay.Destroy()
    }
    debugGridOverlay := 0
}
    
; Toggle aiming grid on/off based on DebugMode
ToggleDebugGrid() {
    global DebugMode, ScramblerSuppressDebug
    
    if (DebugMode && !ScramblerSuppressDebug)
        ShowAimingGrid()
    else
        HideAimingGrid()
}

; ============================================================================
; DEBUG VISUALIZATION - Single overlay per scan with all markers
; ============================================================================
global debugGuiList := []

ShowDebugVisualization(centerX, centerY, topPixels, bottomPixels, leftPixels, rightPixels, direction, topMatches, bottomMatches, leftMatches, rightMatches) {
    global MinEdgeMatches, EdgeStripSize, CheckDistance
    
    maxMatches := Max(topMatches, bottomMatches, leftMatches, rightMatches)
    halfStrip := EdgeStripSize // 2
    
    ; Create single overlay GUI - full screen to simplify coordinate math
    overlay := Gui("+AlwaysOnTop -Caption +ToolWindow +E0x20 +E0x80000", "Dbg")
    overlay.BackColor := "000001"
    overlay.Show("x0 y0 w" A_ScreenWidth " h" A_ScreenHeight " NA")
    WinSetTransColor("000001", overlay.Hwnd)
    
    hdc := DllCall("GetDC", "Ptr", overlay.Hwnd, "Ptr")
    G := Gdip_GraphicsFromHDC(hdc)
    Gdip_SetSmoothingMode(G, 2)
    
    ; --- Draw center indicator ---
    if (direction = "") {
        ; Failed detection - draw red X using Gdip_Graphics draw methods
        ; Both lines drawn independently with their own pen
        penX1 := Gdip_CreatePen(0xFFFF0000, 3)
        penX2 := Gdip_CreatePen(0xFFFF0000, 3)
        Gdip_DrawLine(G, penX1, centerX - 6, centerY - 6, centerX + 6, centerY + 6)
        Gdip_DrawLine(G, penX2, centerX + 6, centerY - 6, centerX - 6, centerY + 6)
        Gdip_DeletePen(penX1)
        Gdip_DeletePen(penX2)
    } else {
        ; Success - draw green center dot
        brush := Gdip_BrushCreateSolid(0xFF00FF00)
        Gdip_FillEllipse(G, brush, centerX - 2, centerY - 2, 5, 5)
        Gdip_DeleteBrush(brush)
    }
    
    ; --- Draw edge strips ---
    isBestTop := (topMatches = maxMatches && maxMatches >= MinEdgeMatches)
    isBestBottom := (bottomMatches = maxMatches && bottomMatches >= MinEdgeMatches)
    isBestLeft := (leftMatches = maxMatches && leftMatches >= MinEdgeMatches)
    isBestRight := (rightMatches = maxMatches && rightMatches >= MinEdgeMatches)
    
    edgeColorBest := 0xFFFFFF00     ; Yellow = best-matching edge (arrow points opposite)
    edgeColorMatch := 0xFFFF0000    ; Red = has some matches but not best
    edgeColorNone := 0x40FFFFFF     ; Dim white = no matches but position shown
    
    ; Top edge
    color := topMatches >= MinEdgeMatches && isBestTop ? edgeColorBest : (topMatches > 0 ? edgeColorMatch : edgeColorNone)
    pen := Gdip_CreatePen(color, topMatches > 0 ? 3 : 1)
    Gdip_DrawLine(G, pen, centerX - halfStrip, centerY - CheckDistance, centerX + halfStrip, centerY - CheckDistance)
    Gdip_DeletePen(pen)
    
    ; Bottom edge
    color := bottomMatches >= MinEdgeMatches && isBestBottom ? edgeColorBest : (bottomMatches > 0 ? edgeColorMatch : edgeColorNone)
    pen := Gdip_CreatePen(color, bottomMatches > 0 ? 3 : 1)
    Gdip_DrawLine(G, pen, centerX - halfStrip, centerY + CheckDistance, centerX + halfStrip, centerY + CheckDistance)
    Gdip_DeletePen(pen)
    
    ; Left edge
    color := leftMatches >= MinEdgeMatches && isBestLeft ? edgeColorBest : (leftMatches > 0 ? edgeColorMatch : edgeColorNone)
    pen := Gdip_CreatePen(color, leftMatches > 0 ? 3 : 1)
    Gdip_DrawLine(G, pen, centerX - CheckDistance, centerY - halfStrip, centerX - CheckDistance, centerY + halfStrip)
    Gdip_DeletePen(pen)
    
    ; Right edge
    color := rightMatches >= MinEdgeMatches && isBestRight ? edgeColorBest : (rightMatches > 0 ? edgeColorMatch : edgeColorNone)
    pen := Gdip_CreatePen(color, rightMatches > 0 ? 3 : 1)
    Gdip_DrawLine(G, pen, centerX + CheckDistance, centerY - halfStrip, centerX + CheckDistance, centerY + halfStrip)
    Gdip_DeletePen(pen)
    
    ; --- Direction indicator (short green stub pointing arrow direction) ---
    if (direction != "") {
        penDir := Gdip_CreatePen(0xFF00FF00, 2)
        switch direction {
            case "Up":
                Gdip_DrawLine(G, penDir, centerX, centerY, centerX, centerY - CheckDistance - 4)
            case "Down":
                Gdip_DrawLine(G, penDir, centerX, centerY, centerX, centerY + CheckDistance + 4)
            case "Left":
                Gdip_DrawLine(G, penDir, centerX, centerY, centerX - CheckDistance - 4, centerY)
            case "Right":
                Gdip_DrawLine(G, penDir, centerX, centerY, centerX + CheckDistance + 4, centerY)
        }
        Gdip_DeletePen(penDir)
    }
    
    Gdip_DeleteGraphics(G)
    DllCall("ReleaseDC", "Ptr", overlay.Hwnd, "Ptr", hdc)
    
    debugGuiList.Push(overlay)
}

; ============================================================================
; CLEAR VISUALIZATION
; ============================================================================
ClearDebugVisualization() {
    global debugGuiList
    
    ; Close all debug overlay GUIs
    for overlay in debugGuiList {
        try {
            overlay.Destroy()
        } catch {
            ; Ignore errors
        }
    }
    
    ; Clear list
    debugGuiList := []
}

; ============================================================================
; COLOR MATCH CHECK
; ============================================================================
IsColorMatch(bitmap, x, y, customColor := "", customTolerance := "") {
    global ArrowColor, ColorTolerance, ArrowExtractedColorTolerance
    
    try {
        pixelColor := Gdip_GetPixel(bitmap, x, y)
        
        ; Gdip_GetPixel returns ARGB format (0xAARRGGBB)
        ; Extract RGB components
        r1 := (pixelColor >> 16) & 0xFF
        g1 := (pixelColor >> 8) & 0xFF
        b1 := pixelColor & 0xFF
        
        ; Determine which color and tolerance to use
        targetColor := (customColor = "") ? ArrowColor : customColor
        targetTolerance := (customTolerance = "") ? ColorTolerance : customTolerance
        
        r2 := (targetColor >> 16) & 0xFF
        g2 := (targetColor >> 8) & 0xFF
        b2 := targetColor & 0xFF
        
        ; Check tolerance per channel
        if (Abs(r1 - r2) <= targetTolerance 
            && Abs(g1 - g2) <= targetTolerance 
            && Abs(b1 - b2) <= targetTolerance)
            return true
            
        return false
    } catch {
        return false
    }
}

; ============================================================================
; CENTER STABILITY CHECK
; ============================================================================
IsCenterStable(bitmap, centerX, centerY) {
    global CenterStability
    
    ; If CenterStability = 0, check only one center pixel
    if (CenterStability = 0) {
        return IsColorMatch(bitmap, centerX, centerY)
    }
    
    ; Check square area (2*CenterStability+1) x (2*CenterStability+1)
    ; All pixels in area must match arrow color
    totalPixels := 0
    matchedPixels := 0
    
    Loop (2 * CenterStability + 1) {
        offsetY := A_Index - CenterStability - 1
        Loop (2 * CenterStability + 1) {
            offsetX := A_Index - CenterStability - 1
            px := centerX + offsetX
            py := centerY + offsetY
            totalPixels++
            if (IsColorMatch(bitmap, px, py)) {
                matchedPixels++
            }
        }
    }
    
    ; All pixels must match
    return (matchedPixels = totalPixels)
}

; ============================================================================
; STRATAGEM LOOKUP IN INI FILE
; ============================================================================
FindStratagem(directions) {
    global OCR_DetectionMethod
    if (directions.Length = 0)
        return ""
    
    ; Build direction string for lookup
    dirString := ""
    for index, dir in directions {
        if (index > 1)
            dirString .= ","
        dirString .= dir
    }
    
    ; Read stratagems.ini
    stratagemIniPath := A_ScriptDir "\\Config\\stratagems.ini"
    
    ; For color detection (0): filter sequentially until one remains
    ; For shape detection (1): use mismatch-based scoring
    if (OCR_DetectionMethod = 0) {
        ; --- Color method: sequential filtering ---
        ; Read all stratagem entries
        allEntries := []
        try {
            fileContent := FileRead(stratagemIniPath)
            Loop Parse, fileContent, "`n", "`r" {
                line := A_LoopField
                parts := StrSplit(line, "|")
                if (parts.Length >= 2) {
                    keyName := parts[1]
                    eqPos := InStr(keyName, "=")
                    if (!eqPos)
                        continue
                    id := Trim(SubStr(keyName, 1, eqPos - 1))
                    name := Trim(SubStr(keyName, eqPos + 1))
                    dbDirs := StrSplit(parts[2], ",")
                    allEntries.Push({id: id, name: name, directions: dbDirs})
                }
            }
        }
        
        ; Check exact match first
        for entry in allEntries {
            if (ArrayToString(entry.directions) = dirString)
                return {id: entry.id, name: entry.name}
        }
        
        ; Filter sequentially: for each detected arrow, keep only entries
        ; that match at that position. Continue until one remains or we run out of arrows.
        ; Positions with empty direction (tie/multiple edge matches) are skipped
        ; and treated as wildcards — they don't eliminate any candidates.
        candidates := allEntries.Clone()
        
        for idx, detectedDir in directions {
            if (candidates.Length <= 1)
                break
            
            ; Skip unknown directions (empty string from tie detection) — wildcard position
            if (detectedDir = "")
                continue
            
            filtered := []
            for entry in candidates {
                if (idx <= entry.directions.Length && entry.directions[idx] = detectedDir)
                    filtered.Push(entry)
            }
            
            ; Only apply filter if it narrows down but doesn't eliminate everything
            if (filtered.Length > 0)
                candidates := filtered
        }
        
        if (candidates.Length = 1) {
            ; Found unique matching stratagem via sequential filtering
            dbDirs := ArrayToString(candidates[1].directions)
            ; Count mismatches for the label
            maxLen := Max(directions.Length, candidates[1].directions.Length)
            mismatches := 0
            Loop maxLen {
                d1 := (A_Index <= directions.Length) ? directions[A_Index] : ""
                d2 := (A_Index <= candidates[1].directions.Length) ? candidates[1].directions[A_Index] : ""
                if (d1 != d2)
                    mismatches++
            }
            if (mismatches > 0)
                return {id: candidates[1].id, name: candidates[1].name " (best match)"}
            return {id: candidates[1].id, name: candidates[1].name}
        }
        
        ; Filtering didn't narrow to one — fall back to minimum mismatches
        bestMatch := {id: "", name: "", mismatches: 9999}
        for entry in allEntries {
            maxLen := Max(directions.Length, entry.directions.Length)
            mismatches := 0
            Loop maxLen {
                d1 := (A_Index <= directions.Length) ? directions[A_Index] : ""
                d2 := (A_Index <= entry.directions.Length) ? entry.directions[A_Index] : ""
                if (d1 != d2)
                    mismatches++
            }
            if (mismatches < bestMatch.mismatches)
                bestMatch := {id: entry.id, name: entry.name, mismatches: mismatches}
        }
        if (bestMatch.mismatches <= 3)
            return {id: bestMatch.id, name: bestMatch.name " (best match)"}
        
        return ""
        
    } else {
        ; --- Shape method: mismatch-based scoring ---
        ; Only count mismatches at positions where the detected direction
        ; is non-empty. Empty entries (padding for undetected arrows) are
        ; skipped — they don't count for or against a match.
        bestMatch := {id: "", name: "", mismatches: 9999}
        
        try {
            fileContent := FileRead(stratagemIniPath)
            Loop Parse, fileContent, "`n", "`r" {
                line := A_LoopField
                parts := StrSplit(line, "|")
                if (parts.Length >= 2) {
                    keyName := parts[1]
                    eqPos := InStr(keyName, "=")
                    if (!eqPos)
                        continue
                    
                    id := Trim(SubStr(keyName, 1, eqPos - 1))
                    name := Trim(SubStr(keyName, eqPos + 1))
                    
                    ; Check if all non-empty detected directions match the DB entry
                    nonEmptyCount := 0
                    allMatch := true
                    dbDirs := StrSplit(parts[2], ",")
                    Loop directions.Length {
                        d1 := directions[A_Index]
                        if (d1 = "")
                            continue  ; Skip padding empties
                        nonEmptyCount++
                        d2 := (A_Index <= dbDirs.Length) ? dbDirs[A_Index] : ""
                        if (d1 != d2) {
                            allMatch := false
                            break
                        }
                    }
                    ; If all non-empty positions match, this is the best candidate
                    ; But if any arrows were missing (empties in our detection vs DB length),
                    ; label as "best match" since some positions are uncertain
                    if (allMatch) {
                        if (nonEmptyCount < dbDirs.Length)
                            return {id: id, name: name " (best match)"}
                        return {id: id, name: name}
                    }
                    
                    ; Count mismatches, skipping empty detected positions
                    mismatches := 0
                    totalCompared := 0
                    Loop Max(directions.Length, dbDirs.Length) {
                        d1 := (A_Index <= directions.Length) ? directions[A_Index] : ""
                        if (d1 = "")
                            continue  ; Skip padding empties
                        totalCompared++
                        d2 := (A_Index <= dbDirs.Length) ? dbDirs[A_Index] : ""
                        if (d1 != d2)
                            mismatches++
                    }
                    ; Also check if DB has extra arrows beyond our detected ones
                    if (dbDirs.Length > 0) {
                        Loop dbDirs.Length {
                            d1 := (A_Index <= directions.Length) ? directions[A_Index] : ""
                            if (d1 = "")
                                mismatches++  ; DB has arrow where we have padding
                        }
                    }
                    
                    if (mismatches < bestMatch.mismatches)
                        bestMatch := {id: id, name: name, mismatches: mismatches}
                }
            }
        }
        
        if (bestMatch.mismatches <= 3)
            return {id: bestMatch.id, name: bestMatch.name " (best match)"}
        
        return ""
    }
}

; ============================================================================
; WRITE RESULTS TO FILE
; ============================================================================
WriteResults(stratagems, outputPath := "", profileName := "OCR") {
    if (outputPath = "")
        ; Fallback to main settings profile storage
        outputPath := A_ScriptDir "\\Config\\settings.ini"

    ; Build ordered list:
    ; 1) last 4 found stratagems first (in their original order)
    ; 2) the rest in reverse order
    ; 3) Skip duplicates — if a stratagem was already added, don't add it again
    activeList := ""
    profileIds := []
    total := stratagems.Length
    lastCount := Min(4, total)
    seenIds := Map()  ; Track which IDs have been added to prevent duplicates

    ; Last N (up to 4) at the front
    Loop lastCount {
        idx := total - lastCount + A_Index
        if (stratagems[idx].id != "unknown") {
            id := stratagems[idx].id
            if (!seenIds.Has(id)) {
                seenIds[id] := true
                profileIds.Push(id)
            }
        }
    }

    ; Remaining ones in reverse order
    remaining := total - lastCount
    Loop remaining {
        idx := remaining - A_Index + 1
        if (stratagems[idx].id != "unknown") {
            id := stratagems[idx].id
            if (!seenIds.Has(id)) {
                seenIds[id] := true
                profileIds.Push(id)
            }
        }
    }

    filteredIds := []
    for id in profileIds {
        if (OCR_IsExcluded(id))
            continue
        filteredIds.Push(id)
    }

    ; Required tail ordering (unless excluded):
    ; - Resupply immediately before Reinforce
    ; - Reinforce last
    ; - OCR Objective always included in the required tail
    ; - If any Eagle stratagem is present, Eagle Re-arm is forced into third-to-last
    hasEagle := false
    for id in filteredIds {
        if (SubStr(id, 1, 6) = "eagle_") {
            hasEagle := true
            break
        }
    }

    requiredTail := []
    if (hasEagle)
        requiredTail.Push("eagle_re_arm")
    requiredTail.Push("ocr_objective")
    requiredTail.Push("resupply")
    requiredTail.Push("reinforce")

    ; Remove existing occurrences to avoid duplicates and ensure final ordering
    for reqId in requiredTail {
        i := filteredIds.Length
        while (i >= 1) {
            if (filteredIds[i] = reqId)
                filteredIds.RemoveAt(i)
            i--
        }
    }

    ; Append required tail entries if not excluded
    for reqId in requiredTail {
        if (!OCR_IsExcluded(reqId))
            filteredIds.Push(reqId)
    }

    for id in filteredIds {
        if (activeList != "")
            activeList .= ","
        activeList .= id
    }

    ; Overwrite only the ActiveList field in target profile
    IniWrite(activeList, outputPath, "Profile_" profileName, "ActiveList")

    return filteredIds.Length
}

; ============================================================================
; MAIN FUNCTION
; ============================================================================
OCR_ScanToProfile(outputPath := "", profileName := "OCR") {
    global DebugMode, OCR_DetectedRowsMap, OCR_DetectionMethod
    
    ; For color detection, detect arrow color from the first arrow of the second row (for debug display)
    ; Capture BEFORE ScanAllStratagems runs, otherwise debug overlays pollute the pixel read
    arrowColorInfo := ""
    if (DebugMode && OCR_DetectionMethod = 0) {
        row2Y := StartY + StepY  ; Y of first arrow in row 2
        colorBitmap := Gdip_BitmapFromScreen(StartX "|" row2Y "|1|1")
        if (colorBitmap) {
            pixelColor := Gdip_GetPixel(colorBitmap, 0, 0)  ; Returns 0xAARRGGBB
            r := (pixelColor >> 16) & 0xFF
            g := (pixelColor >> 8) & 0xFF
            b := pixelColor & 0xFF
            colorHex := Format("0x{:06X}", (r << 16) | (g << 8) | b)
            arrowColorInfo := "Detected Arrow Color (1st arrow of 2nd row):`n" colorHex " (R=" r ", G=" g ", B=" b ")"
            Gdip_DisposeImage(colorBitmap)
        }
    }

    ; Scan all stratagem rows
    foundStratagems := ScanAllStratagems()

    ; Store latest detected row per stratagem for Scrambled Stratagems bypass
    OCR_DetectedRowsMap := Map()
    for strat in foundStratagems {
        if (strat.id != "unknown" && !OCR_DetectedRowsMap.Has(strat.id))
            OCR_DetectedRowsMap[strat.id] := strat.row
    }

    ; Reinforce is always on the first visible stratagem row.
    ; Keep this mapping even if OCR did not successfully identify Reinforce.
    if !OCR_DetectedRowsMap.Has("reinforce")
        OCR_DetectedRowsMap["reinforce"] := 1
    
    if (foundStratagems.Length = 0) {
        if (DebugMode) {
            msg := "No stratagems found!"
            if (arrowColorInfo != "")
                msg .= "`n`n" arrowColorInfo
            result := MsgBox(msg, "Scan Result", 48)
            if (result = "OK")
                ClearDebugVisualization()
        }
        return 0
    }
    
    ; Count valid (known) stratagems
    validCount := 0
    knownCount := 0
    for strat in foundStratagems {
        if (strat.id != "unknown") {
            knownCount++
            if (!OCR_IsExcluded(strat.id))
            validCount++
        }
    }

    ; Write results (also appends mandatory OCR Objective + Reinforce when not excluded)
    writtenCount := WriteResults(foundStratagems, outputPath, profileName)

    if (writtenCount = 0) {
        if (DebugMode) {
            msg := knownCount > 0
                ? "All detected stratagems (including required tail entries) are in the exclusion list. Nothing was written to profile."
                : "No usable stratagems found and all required tail entries are excluded. Nothing was written to profile."
            result := MsgBox(msg, "Scan Result", 48)
            if (result = "OK")
                ClearDebugVisualization()
        }
        return 0
    }
    
    ; Build message
    msg := "Stratagems found: " foundStratagems.Length "`n"
    msg .= "Written to profile: " writtenCount "`n`n"
    for strat in foundStratagems {
        msg .= strat.name " (row " strat.row ")`n"
    }
    
    ; Append detected arrow color info in debug mode
    if (arrowColorInfo != "")
        msg .= "`n" arrowColorInfo
    
    if (DebugMode) {
        result := MsgBox(msg, "Scan Result", 64)
        if (result = "OK")
            ClearDebugVisualization()
    }

    return writtenCount
}

; ============================================================================
; HELPER FUNCTIONS
; ============================================================================
ArrayToString(arr) {
    result := ""
    for index, item in arr {
        if (index > 1)
            result .= ","
        result .= item
    }
    return result
}

; ============================================================================
; SCRAMBLER BYPASS - ICON CAPTURE AND DETECTION
; ============================================================================
; Icon capture settings (base values for 1440p)
global IconSizeOCR := 56                    ; Icon size in pixels
global IconStartX := 70                  ; Starting X position
global IconStartY := 108                 ; Starting Y position
global IconVerticalStep := 70            ; Vertical offset between icons

; Flag to suppress debug mode during icon capture
global ScramblerSuppressDebug := false

; Scaled values for current resolution
global IconSizeScaled := IconSizeOCR
global IconStartXScaled := IconStartX
global IconStartYScaled := IconStartY
global IconVerticalStepScaled := IconVerticalStep

; Captured icons storage - stores actual GDI+ bitmaps
global IconCapturedIcons := []       ; Array of {slot, bitmap}
global IconCapturedCount := 0        ; Number of captured icons

; Initialize icon capture scaling
Icon_InitScaling() {
    global ScaleX, ScaleY
    global IconSizeScaled, IconStartXScaled, IconStartYScaled, IconVerticalStepScaled
    global IconSizeOCR, IconStartX, IconStartY, IconVerticalStep
    global HUDScale

    HUDScaleFactor := HUDScale / 0.90

    IconSizeScaled := Round(IconSizeOCR * ScaleY * HUDScaleFactor)
    IconStartXScaled := Round(IconStartX * ScaleX * HUDScaleFactor)
    IconStartYScaled := Round(IconStartY * ScaleY * HUDScaleFactor)
    IconVerticalStepScaled := Round(IconVerticalStep * ScaleY * HUDScaleFactor)
}

; Check if an icon exists at a specific row by detecting at least 2 arrows
; Uses the existing arrow detection logic
Icon_HasArrowsInRow(bitmap, rowIndex) {
    global StartY, StepY, StartX, StepX, MaxArrowsPerRow, ScreenWidth

    ; Calculate Y position for this row
    rowY := StartY + (rowIndex - 1) * StepY

    ; Check for at least 2 arrows in this row
    arrowCount := 0
    currentX := StartX

    Loop MaxArrowsPerRow {
        if (currentX > ScreenWidth - 20)
            break

        ; Use existing arrow detection
        direction := DetectArrowDirection(bitmap, currentX, rowY)
        if (direction != "") {
            arrowCount++
            if (arrowCount >= 2)
                return true  ; Found at least 2 arrows, icon exists
        } else {
            break  ; No arrow found, stop scanning this row
        }
        currentX += StepX
    }

    return false
}

; Capture icon bitmap from screen at specified row
; Returns the GDI+ bitmap of the icon (caller must dispose)
Scrambler_CaptureIconBitmap(rowIndex) {
    global IconSizeScaled, IconStartXScaled, IconStartYScaled, IconVerticalStepScaled
    
    ; Calculate position
    x := IconStartXScaled
    y := IconStartYScaled + (rowIndex - 1) * IconVerticalStepScaled
    
    ; Capture screen region
    try {
        bitmap := Gdip_BitmapFromScreen(x "|" y "|" IconSizeScaled "|" IconSizeScaled)
        return bitmap
    }
    return 0
}

; Dispose all captured icon bitmaps
Icon_DisposeCapturedIcons() {
    global IconCapturedIcons

    if (IsSet(IconCapturedIcons) && IsObject(IconCapturedIcons)) {
        for icon in IconCapturedIcons {
            if (icon.HasOwnProp("bitmap") && icon.bitmap != 0) {
                try Gdip_DisposeImage(icon.bitmap)
            }
        }
    }
    IconCapturedIcons := []
    IconCapturedCount := 0
}

; Capture all icons from screen and store them in REVERSED order
; Uses arrow detection to verify icon existence (requires at least 2 arrows per row)
; Returns the number of icons captured
Icon_CaptureAllIcons() {
    global MaxRows
    global IconCapturedIcons, IconCapturedCount
    global OCR_ScreenWidth, OCR_ScreenHeight

    ; Initialize scaling
    Icon_InitScaling()

    ; Dispose any previously captured icons
    Icon_DisposeCapturedIcons()
    
    ; Reset shape detection cache so we re-scan the screen fresh
    ; This is critical for shape detection: without it, the cached arrow
    ; positions from the previous scan keep their "used" flags and prevent
    ; detection on subsequent calls (e.g. opening radial menu a second time)
    ShapeResetCache()

    ; Get screen dimensions
    global ScreenWidth, ScreenHeight
    ScreenWidth := OCR_ScreenWidth
    ScreenHeight := OCR_ScreenHeight

    ; Capture full screen once for arrow detection
    screenBitmap := Gdip_BitmapFromScreen()

    ; Scan each row using MaxRows, but in REVERSED order (bottom-to-top)
    Loop MaxRows {
        rowIndex := MaxRows - A_Index + 1  ; Reverse the row index

        ; Check if row is within screen bounds
        rowY := StartY + (rowIndex - 1) * StepY
        if (rowY > ScreenHeight - 30)
            break

        ; Verify icon exists by checking for at least 2 arrows in this row
        if (Icon_HasArrowsInRow(screenBitmap, rowIndex)) {
            ; Capture the icon bitmap
            iconBitmap := Scrambler_CaptureIconBitmap(rowIndex)

            if (iconBitmap != 0) {
                IconCapturedIcons.Push({
                    slot: rowIndex,
                    bitmap: iconBitmap
                })
            }
        }
    }

    ; Dispose the full screen bitmap
    Gdip_DisposeImage(screenBitmap)

    IconCapturedCount := IconCapturedIcons.Length
    return IconCapturedCount
}

; Get the number of captured icons
Icon_GetCapturedCount() {
    global IconCapturedCount
    return IconCapturedCount
}

; Get captured icon by index (1-based, for radial menu sector)
Icon_GetCapturedIcon(index) {
    global IconCapturedIcons

    if (index > 0 && index <= IconCapturedIcons.Length)
        return IconCapturedIcons[index]
    return ""
}

; Get the slot number for a captured icon by index
Icon_GetSlotByIndex(index) {
    global IconCapturedIcons

    if (index > 0 && index <= IconCapturedIcons.Length)
        return IconCapturedIcons[index].slot
    return 0
}

; Get the bitmap for a captured icon by index
Icon_GetBitmapByIndex(index) {
    global IconCapturedIcons

    if (index > 0 && index <= IconCapturedIcons.Length)
        return IconCapturedIcons[index].bitmap
    return 0
}

; Get arrow sequence for a specific slot (reads from screen via OCR)
Icon_GetSequenceBySlot(slot) {
    ; Use the existing OCR function to read arrow sequence for a row
    return OCR_GetDirectionsByRow(slot)
}

; ============================================================================
; SETTINGS WINDOW
; ============================================================================
OCR_ShowSettingsWindow() {
    global

    ; Reuse existing settings window if already created
    if (IsObject(OCR_settingsGui)) {
        OCR_settingsGui.Show("Center")
        return
    }

    ; Create settings window
    OCR_settingsGui := Gui(, "OCR Settings (Base Values for 1440p)")
    OCR_settingsGui.MarginX := 10
    OCR_settingsGui.MarginY := 10
    OCR_settingsGui.OnEvent("Close", (*) => OCR_settingsGui.Hide())
    
    ; =========================================================================
    ; COLUMN 1
    ; =========================================================================
    
    ; -------------------------------------------------------------------------
    ; Groupbox 1: Arrow Position
    ; -------------------------------------------------------------------------
    groupArrowPos := OCR_settingsGui.Add("GroupBox", "x10 y10 w280 h150", "Arrow Position")
    OCR_settingsGui.Add("Text", "x20 y35 w120", "ArrowStartX:")
    edtArrowStartX := OCR_settingsGui.Add("Edit", "x+10 w120", ArrowStartX)
    OCR_settingsGui.Add("Text", "x20 y+10 w120", "ArrowStartY:")
    edtArrowStartY := OCR_settingsGui.Add("Edit", "x+10 w120", ArrowStartY)
    OCR_settingsGui.Add("Text", "x20 y+10 w120", "ArrowStepX:")
    edtArrowStepX := OCR_settingsGui.Add("Edit", "x+10 w120", ArrowStepX)
    OCR_settingsGui.Add("Text", "x20 y+10 w120", "ArrowStepY:")
    edtArrowStepY := OCR_settingsGui.Add("Edit", "x+10 w120", ArrowStepY)
    
    ; -------------------------------------------------------------------------
    ; Groupbox 2: Icon Position
    ; -------------------------------------------------------------------------
    groupIconPos := OCR_settingsGui.Add("GroupBox", "x10 y175 w280 h150", "Icon Position")
    OCR_settingsGui.Add("Text", "x20 y200 w120", "Icon Size:")
    edtIconSize := OCR_settingsGui.Add("Edit", "x+10 w120", IconSizeOCR)
    OCR_settingsGui.Add("Text", "x20 y+10 w120", "Start X:")
    edtIconStartX := OCR_settingsGui.Add("Edit", "x+10 w120", IconStartX)
    OCR_settingsGui.Add("Text", "x20 y+10 w120", "Start Y:")
    edtIconStartY := OCR_settingsGui.Add("Edit", "x+10 w120", IconStartY)
    OCR_settingsGui.Add("Text", "x20 y+10 w120", "Vertical Step:")
    edtIconVerticalStep := OCR_settingsGui.Add("Edit", "x+10 w120", IconVerticalStep)
    
    ; -------------------------------------------------------------------------
    ; Groupbox 3: General Settings
    ; -------------------------------------------------------------------------
    groupGeneral := OCR_settingsGui.Add("GroupBox", "x10 y345 w280 h280", "General Settings")
    OCR_settingsGui.Add("Text", "x20 y370 w230", "Detected Resolution: " A_ScreenWidth "x" A_ScreenHeight)
    global chkUseCustomResolution := OCR_settingsGui.Add("CheckBox", "x20 y+10 vChkUseCustomRes", "Use custom resolution")
    chkUseCustomResolution.Value := OCR_UseCustomResolution
    OCR_settingsGui.Add("Text", "x35 y+10 w45", "Width:")
    global edtCustomWidth := OCR_settingsGui.Add("Edit", "x80 yp w60 Number", OCR_CustomWidth)
    edtCustomWidth.Enabled := OCR_UseCustomResolution
    OCR_settingsGui.Add("Text", "x35 y+6 w45", "Height:")
    global edtCustomHeight := OCR_settingsGui.Add("Edit", "x80 yp w60 Number", OCR_CustomHeight)
    edtCustomHeight.Enabled := OCR_UseCustomResolution
    chkUseCustomResolution.OnEvent("Click", (*) => ToggleCustomResolutionEdits())
    OCR_settingsGui.Add("Text", "x20 y+10 w125", "MaxRows:")
    edtMaxRows := OCR_settingsGui.Add("Edit", "x160 yp w105", MaxRows)
    OCR_settingsGui.Add("Text", "x20 y+10 w125", "MaxArrowsPerRow:")
    edtMaxArrowsPerRow := OCR_settingsGui.Add("Edit", "x160 yp w105", MaxArrowsPerRow)
    OCR_settingsGui.Add("Text", "x20 y+10 w125", "Menu open delay (ms):")
    edtMenuOpenDelay := OCR_settingsGui.Add("Edit", "x160 yp w105", MenuOpenDelay)
    OCR_settingsGui.Add("Text", "x20 y+10 w125", "The in-game HUD Scale:")
    hudScaleList := ["0.75", "0.80", "0.85", "0.90", "0.95", "1.00", "1.05", "1.10", "1.15", "1.20", "1.25"]
    edtHUDScale := OCR_settingsGui.Add("DropDownList", "x160 yp w105", hudScaleList)
    hudScaleIndex := 4
    for i, val in hudScaleList {
        if (val = Format("{:.2f}", HUDScale)) {
            hudScaleIndex := i
            break
        }
    }
    edtHUDScale.Choose(hudScaleIndex)
    chkDebugMode := OCR_settingsGui.Add("Checkbox", "x20 y+10 w200", "Debug mode (visualization)")
    chkDebugMode.Value := DebugMode
    
    ; =========================================================================
    ; COLUMN 2
    ; =========================================================================
    
    ; -------------------------------------------------------------------------
    ; Groupbox 4: Arrow Detection Method
    ; -------------------------------------------------------------------------
    groupMethod := OCR_settingsGui.Add("GroupBox", "x310 y10 w280 h50", "Arrow Detection Method")
    OCR_settingsGui.Add("Text", "x320 y30 w110", "Detection Method:")
    methodList := ["Color Detection", "Shape Detection (Beta)"]
    edtDetectionMethod := OCR_settingsGui.Add("DropDownList", "x440 y28 w138", methodList)
    edtDetectionMethod.Choose(OCR_DetectionMethod + 1)
    edtDetectionMethod.OnEvent("Change", (*) => UpdateMethodHelp())
    UpdateMethodHelp() {
    }
    
    ; -------------------------------------------------------------------------
    ; Groupbox 5: Color Detection
    ; -------------------------------------------------------------------------
    groupColor := OCR_settingsGui.Add("GroupBox", "x310 y75 w280 h225", "Color Detection")
    OCR_settingsGui.Add("Text", "x320 y100 w115", "ArrowColor (RGB):")
    edtArrowColor := OCR_settingsGui.Add("Edit", "x450 yp w120", Format("0x{:06X}", ArrowColor))
    OCR_settingsGui.Add("Text", "x320 y+7 w115", "ColorTolerance:")
    edtColorTolerance := OCR_settingsGui.Add("Edit", "x450 yp w120", ColorTolerance)
    OCR_settingsGui.Add("Text", "x320 y+7 w115", "ExtractColorTol:")
    edtArrowExtractedColorTolerance := OCR_settingsGui.Add("Edit", "x450 yp w120", ArrowExtractedColorTolerance)
    OCR_settingsGui.Add("Text", "x320 y+7 w115", "ArrowCheckDistance:")
    edtArrowCheckDistance := OCR_settingsGui.Add("Edit", "x450 yp w120", ArrowCheckDistance)
    OCR_settingsGui.Add("Text", "x320 y+7 w115", "ArrowEdgeStripSize:")
    edtArrowEdgeStripSize := OCR_settingsGui.Add("Edit", "x450 yp w120", ArrowEdgeStripSize)
    OCR_settingsGui.Add("Text", "x320 y+7 w115", "ArrowCenterStability:")
    edtArrowCenterStability := OCR_settingsGui.Add("Edit", "x450 yp w120", ArrowCenterStability)
    OCR_settingsGui.Add("Text", "x320 y+7 w115", "MinEdgeMatches:")
    edtMinEdgeMatches := OCR_settingsGui.Add("Edit", "x450 yp w120", MinEdgeMatches)
    
    ; -------------------------------------------------------------------------
    ; Groupbox 6: Shape Detection
    ; -------------------------------------------------------------------------
    groupShape := OCR_settingsGui.Add("GroupBox", "x310 y315 w280 h200", "Shape Detection")
    ; Current template info
    currentTemplate := OCR_GetShapeTemplateResolution()
    OCR_settingsGui.Add("Text", "x320 y340 w240", "Template: " currentTemplate " (auto-detected)")
    ; Custom shape template selection
    global chkUseCustomShapeTemplate := OCR_settingsGui.Add("CheckBox", "x320 y+15 vChkUseCustomTemplate", "Use custom shape template")
    chkUseCustomShapeTemplate.Value := OCR_UseCustomShapeTemplate
    global edtCustomShapeTemplate := OCR_settingsGui.Add("DropDownList", "x340 y+5 w120", ["1080p", "1440p", "2160p"])
    ; Set the DDL to the current custom template value, or auto-detected if not set
    shapeTemplateChoice := OCR_CustomShapeTemplate
    if (shapeTemplateChoice = "")
        shapeTemplateChoice := OCR_GetShapeTemplateResolution()
    shapeTemplateIndex := 1
    for i, val in ["1080p", "1440p", "2160p"] {
        if (val = shapeTemplateChoice) {
            shapeTemplateIndex := i
            break
        }
    }
    edtCustomShapeTemplate.Choose(shapeTemplateIndex)
    edtCustomShapeTemplate.Enabled := OCR_UseCustomShapeTemplate
    chkUseCustomShapeTemplate.OnEvent("Click", (*) => ToggleCustomShapeTemplateEdits())
    ; Other setting
    OCR_settingsGui.Add("Text", "x320 y+15 w80", "Fault Tolerance:")
    edtFaultTolerance := OCR_settingsGui.Add("Edit", "x+10 w40", Format("{:.0f}", OCR_ShapeFaultTolerance * 100) . "%")
    global chkUseGray2Two := OCR_settingsGui.Add("CheckBox", "x320 y+10 w140", "Gray2Two patterns")
    chkUseGray2Two.Value := OCR_UseGray2Two
    global chkUseGrayDiff2Two := OCR_settingsGui.Add("CheckBox", "x320 y+10 w160", "GrayDiff2Two patterns")
    chkUseGrayDiff2Two.Value := OCR_UseGrayDiff2Two
    
    
    
    ; =========================================================================
    ; BUTTONS
    ; =========================================================================
    btnApply := OCR_settingsGui.Add("Button", "x125 y630 w100", "Apply")
    btnExclude := OCR_settingsGui.Add("Button", "x+10 yp w130", "Exclusion List")
    btnReset := OCR_settingsGui.Add("Button", "x+10 yp w100", "Reset")
    btnExclude.OnEvent("Click", (*) => OCR_ShowExcludeWindow())
    
    ; Apply button handler
    btnApply.OnEvent("Click", ApplySettings)
    ApplySettings(*) {
        global
        OCR_DetectionMethod := edtDetectionMethod.Value - 1  ; Dropdown index to 0/1
        ; Parse fault tolerance from percentage (e.g. "5%" -> 0.05)
        ftText := Trim(edtFaultTolerance.Value, "% ")
        OCR_ShapeFaultTolerance := Number(ftText) / 100
        ; Read pattern selection checkboxes
        OCR_UseGray2Two := chkUseGray2Two.Value
        OCR_UseGrayDiff2Two := chkUseGrayDiff2Two.Value
        if (OCR_ShapeFaultTolerance < 0.0)
            OCR_ShapeFaultTolerance := 0.0
        if (OCR_ShapeFaultTolerance > 1.0)
            OCR_ShapeFaultTolerance := 1.0
        ArrowStartX := edtArrowStartX.Value
        ArrowStartY := edtArrowStartY.Value
        ArrowStepX := edtArrowStepX.Value
        ArrowStepY := edtArrowStepY.Value
        ArrowCheckDistance := edtArrowCheckDistance.Value
        ArrowEdgeStripSize := edtArrowEdgeStripSize.Value
        ArrowColor := edtArrowColor.Value
        ColorTolerance := edtColorTolerance.Value
        ArrowExtractedColorTolerance := edtArrowExtractedColorTolerance.Value
        MinEdgeMatches := edtMinEdgeMatches.Value
        ArrowCenterStability := edtArrowCenterStability.Value
        MaxRows := edtMaxRows.Value
        MaxArrowsPerRow := edtMaxArrowsPerRow.Value
        DebugMode := chkDebugMode.Value
        MenuOpenDelay := edtMenuOpenDelay.Value
        
        HUDScale := Number(edtHUDScale.Text)
        
        ; Icon capture settings
        IconSizeOCR := edtIconSize.Value
        IconStartX := edtIconStartX.Value
        IconStartY := edtIconStartY.Value
        IconVerticalStep := edtIconVerticalStep.Value
        
        ; Custom resolution settings
        OCR_UseCustomResolution := chkUseCustomResolution.Value
        OCR_CustomWidth := Number(edtCustomWidth.Value)
        OCR_CustomHeight := Number(edtCustomHeight.Value)
        
        ; Custom shape template settings
        OCR_UseCustomShapeTemplate := chkUseCustomShapeTemplate.Value
        OCR_CustomShapeTemplate := edtCustomShapeTemplate.Text
        
        ; Recalculate scaled values
        OCR_InitScaling()
        Icon_InitScaling()
        OCR_SaveSettingsToIni()
        
        ; Force shape pattern re-initialization on next scan
        ; This makes pattern selection (Gray2Two/GrayDiff2Two) take effect immediately
        ShapeResetCache()
        
        ; Toggle persistent aiming grid based on DebugMode
        ToggleDebugGrid()

        ToolTip("Settings saved", A_ScreenWidth/2, 50)
        SetTimer(() => ToolTip(), -1500)
    }
    
    ; Reset button handler
    btnReset.OnEvent("Click", ResetSettings)
    ResetSettings(*) {
        global
        ; Hide grid if debug was on before reset
        if (DebugMode)
            HideAimingGrid()
        ; Reset everything to defaults
        OCR_DetectionMethod := 0
        ArrowStartX := 168
        ArrowStartY := 152
        ArrowStepX := 28.5
        ArrowStepY := 69.75
        ArrowCheckDistance := 8
        ArrowEdgeStripSize := 12
        ArrowCenterStability := 1
        ArrowColor := 0xB8B59B
        ColorTolerance := 60
        ArrowExtractedColorTolerance := 10
        MinEdgeMatches := 4
        MaxRows := 12
        MaxArrowsPerRow := 10
        DebugMode := false
        MenuOpenDelay := 200
        HUDScale := 0.90
        
        ; Reset Icon capture settings
        IconSizeOCR := 56
        IconStartX := 70
        IconStartY := 108
        IconVerticalStep := 70
        
        ; Reset custom resolution settings
        OCR_UseCustomResolution := false
        OCR_CustomWidth := 2560
        OCR_CustomHeight := 1440
        
        ; Reset custom shape template
        OCR_UseCustomShapeTemplate := false
        OCR_CustomShapeTemplate := ""
        
        ; Recalculate scaled values
        OCR_InitScaling()
        Icon_InitScaling()
        OCR_SaveSettingsToIni()

        ; Refresh controls with default values
        OCR_ShapeFaultTolerance := 0.20
        OCR_UseGray2Two := true
        OCR_UseGrayDiff2Two := true
        edtDetectionMethod.Choose(1)
        edtFaultTolerance.Value := "20%"
        chkUseGray2Two.Value := true
        chkUseGrayDiff2Two.Value := true
        edtArrowStartX.Value := ArrowStartX
        edtArrowStartY.Value := ArrowStartY
        edtArrowStepX.Value := ArrowStepX
        edtArrowStepY.Value := ArrowStepY
        edtArrowCheckDistance.Value := ArrowCheckDistance
        edtArrowEdgeStripSize.Value := ArrowEdgeStripSize
        edtArrowColor.Value := Format("0x{:06X}", ArrowColor)
        edtColorTolerance.Value := ColorTolerance
        edtArrowExtractedColorTolerance.Value := ArrowExtractedColorTolerance
        edtMinEdgeMatches.Value := MinEdgeMatches
        edtArrowCenterStability.Value := ArrowCenterStability
        edtMaxRows.Value := MaxRows
        edtMaxArrowsPerRow.Value := MaxArrowsPerRow
        chkDebugMode.Value := DebugMode
        edtMenuOpenDelay.Value := MenuOpenDelay
        edtHUDScale.Choose(4)
        
        ; Refresh custom resolution controls
        chkUseCustomResolution.Value := false
        edtCustomWidth.Value := 2560
        edtCustomHeight.Value := 1440
        ToggleCustomResolutionEdits()

        ; Refresh custom shape template controls
        chkUseCustomShapeTemplate.Value := false
        edtCustomShapeTemplate.Choose(1)
        edtCustomShapeTemplate.Enabled := false

        ; Refresh Icon controls
        edtIconSize.Value := IconSizeOCR
        edtIconStartX.Value := IconStartX
        edtIconStartY.Value := IconStartY
        edtIconVerticalStep.Value := IconVerticalStep

        ToolTip("Settings reset to defaults", A_ScreenWidth/2, 50)
        SetTimer(() => ToolTip(), -1500)
    }
    
    ; Show window centered on screen
    OCR_settingsGui.OnEvent("Escape", (*) => OCR_settingsGui.Destroy())
    OCR_settingsGui.Show("Center")
}

; Helper function to enable/disable custom resolution edit fields
ToggleCustomResolutionEdits() {
    global chkUseCustomResolution, edtCustomWidth, edtCustomHeight
    enabled := chkUseCustomResolution.Value
    edtCustomWidth.Enabled := enabled
    edtCustomHeight.Enabled := enabled
}

; Helper function to enable/disable custom shape template edit fields
ToggleCustomShapeTemplateEdits() {
    global chkUseCustomShapeTemplate, edtCustomShapeTemplate
    enabled := chkUseCustomShapeTemplate.Value
    edtCustomShapeTemplate.Enabled := enabled
}

; Initialize scaling at startup
OCR_LoadSettingsFromIni()
OCR_LoadExcludedFromIni()
OCR_InitScaling()
Icon_InitScaling()

; Show persistent aiming grid if debug mode was saved as enabled
ToggleDebugGrid()