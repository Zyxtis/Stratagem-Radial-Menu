#Requires AutoHotkey v2.0

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

OCR_LoadSettingsFromIni() {
    global OCR_IniPath
    global ArrowStartX, ArrowStartY, ArrowStepX, ArrowStepY
    global ArrowCheckDistance, ArrowEdgeStripSize, ArrowCenterStability
    global ArrowColor, ColorTolerance, MinEdgeMatches, MaxRows, MaxArrowsPerRow, DebugMode
    global IconSizeOCR, IconStartX, IconStartY, IconVerticalStep, MenuOpenDelay, HUDScale

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
        MinEdgeMatches := Number(IniRead(OCR_IniPath, section, "MinEdgeMatches", MinEdgeMatches))
        MaxRows := Number(IniRead(OCR_IniPath, section, "MaxRows", MaxRows))
        MaxArrowsPerRow := Number(IniRead(OCR_IniPath, section, "MaxArrowsPerRow", MaxArrowsPerRow))
        DebugMode := IniRead(OCR_IniPath, section, "DebugMode", DebugMode ? "1" : "0") = "1"
        MenuOpenDelay := Number(IniRead(OCR_IniPath, section, "MenuOpenDelay", MenuOpenDelay))
        HUDScale := Number(IniRead(OCR_IniPath, section, "HUDScale", HUDScale))
        
        ; Load icon capture settings
        IconSizeOCR := Number(IniRead(OCR_IniPath, section, "IconSizeOCR", IconSizeOCR))
        IconStartX := Number(IniRead(OCR_IniPath, section, "IconStartX", IconStartX))
        IconStartY := Number(IniRead(OCR_IniPath, section, "IconStartY", IconStartY))
        IconVerticalStep := Number(IniRead(OCR_IniPath, section, "IconVerticalStep", IconVerticalStep))
    } catch {
    }
}

OCR_SaveSettingsToIni() {
    global OCR_IniPath
    global ArrowStartX, ArrowStartY, ArrowStepX, ArrowStepY
    global ArrowCheckDistance, ArrowEdgeStripSize, ArrowCenterStability
    global ArrowColor, ColorTolerance, MinEdgeMatches, MaxRows, MaxArrowsPerRow, DebugMode
    global IconSizeOCR, IconStartX, IconStartY, IconVerticalStep, MenuOpenDelay

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
    IniWrite(MinEdgeMatches, OCR_IniPath, section, "MinEdgeMatches")
    IniWrite(MaxRows, OCR_IniPath, section, "MaxRows")
    IniWrite(MaxArrowsPerRow, OCR_IniPath, section, "MaxArrowsPerRow")
    IniWrite(DebugMode ? "1" : "0", OCR_IniPath, section, "DebugMode")
    IniWrite(MenuOpenDelay, OCR_IniPath, section, "MenuOpenDelay")
    IniWrite(Format("{:.2f}", HUDScale), OCR_IniPath, section, "HUDScale")
    
    ; Save icon capture settings
    IniWrite(IconSizeOCR, OCR_IniPath, section, "IconSizeOCR")
    IniWrite(IconStartX, OCR_IniPath, section, "IconStartX")
    IniWrite(IconStartY, OCR_IniPath, section, "IconStartY")
    IniWrite(IconVerticalStep, OCR_IniPath, section, "IconVerticalStep")
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
    
    ScaleX := A_ScreenWidth / BaseWidth
    ScaleY := A_ScreenHeight / BaseHeight
    
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
    global pToken, StartX, StartY, StepX, StepY, MaxArrowsPerRow, MaxRows
    
    ; Get screen dimensions
    ScreenWidth := A_ScreenWidth
    ScreenHeight := A_ScreenHeight
    
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
    global StartY, StepY, MaxRows

    ; Get screen dimensions
    ScreenWidth := A_ScreenWidth
    ScreenHeight := A_ScreenHeight

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

    return firstDirections
}

; Returns arrow sequence from a specific OCR row (1-based)
OCR_GetDirectionsByRow(rowNumber) {
    global StartY, StepY

    if (rowNumber < 1)
        return []

    ScreenWidth := A_ScreenWidth
    ScreenHeight := A_ScreenHeight

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
    for arrow in arrows
        directions.Push(arrow.direction)

    Gdip_DisposeImage(bitmap)
    Gdip_DeleteGraphics(G)
    SelectObject(hdc, obm)
    DeleteObject(hbm)
    DeleteDC(hdc)

    return directions
}

; Scan a single arrow row
ScanArrowRow(bitmap, rowY, ScreenWidth) {
    global StartX, StepX, MaxArrowsPerRow
    
    arrows := []
    currentX := StartX
    
    Loop MaxArrowsPerRow {
        if (currentX > ScreenWidth - 20)
            break
        
        direction := DetectArrowDirection(bitmap, currentX, rowY)
        if (direction != "") {
            arrows.Push({x: currentX, y: rowY, direction: direction})
        } else {
            ; If no arrow found, stop scanning this row
            ; (no first arrow or end of sequence)
            break
        }
        currentX += StepX
    }
    
    return arrows
}

; ============================================================================
; ARROW DIRECTION DETECTION
; ============================================================================
DetectArrowDirection(bitmap, centerX, centerY) {
    global ArrowColor, ColorTolerance, CheckDistance, DebugMode, EdgeStripSize, CenterStability, ScramblerSuppressDebug
    
    ; Check if debug should be suppressed (during Scrambler bypass)
    showDebug := DebugMode && !ScramblerSuppressDebug
    
    ; Multi-monitor fix: Offset coordinates by virtual screen origin
    VirtualScreenLeft := SysGet(76)  ; SM_XVIRTUALSCREEN
    VirtualScreenTop  := SysGet(77)  ; SM_YVIRTUALSCREEN
    bitmapX := centerX - VirtualScreenLeft
    bitmapY := centerY - VirtualScreenTop
    
    ; Check center stability (all pixels in area must match)
    if (!IsCenterStable(bitmap, bitmapX, bitmapY)) {
        ; Show a cross if center read fails
        if (showDebug)
            ShowFailedCenter(centerX, centerY, "Center is unstable")
        return ""
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
        match := IsColorMatch(bitmap, px, py)
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
        match := IsColorMatch(bitmap, px, py)
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
        match := IsColorMatch(bitmap, px, py)
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
        match := IsColorMatch(bitmap, px, py)
        if (match)
            rightMatches++
        rightPixels.Push({x: px, y: py, match: match})
    }
    
    ; Determine direction by maximum matches
    ; Edge with most matches is OPPOSITE to arrow direction
    maxMatches := Max(topMatches, bottomMatches, leftMatches, rightMatches)
    
    direction := ""
    if (topMatches = maxMatches)
        direction := "Down"       ; Top edge matched -> arrow points down
    else if (bottomMatches = maxMatches)
        direction := "Up"         ; Bottom edge matched -> arrow points up
    else if (leftMatches = maxMatches)
        direction := "Right"      ; Left edge matched -> arrow points right
    else if (rightMatches = maxMatches)
        direction := "Left"       ; Right edge matched -> arrow points left
    
    ; Debug visualization
    if (showDebug && direction != "") {
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
        ; Show a cross if edge read fails
        if (showDebug)
            ShowFailedCenter(centerX, centerY, "Edges: " maxMatches "/" MinEdgeMatches)
        return ""
    }
    
    return direction
}

; ============================================================================
; DEBUG VISUALIZATION
; ============================================================================
global debugGuiList := []

CreatePixel(x, y, color) {
    global debugGuiList
    
    pixel := Gui("+AlwaysOnTop -Caption +ToolWindow +E0x20", "Pixel")
    pixel.BackColor := color
    pixel.Show("x" x " y" y " w2 h2 NA")
    debugGuiList.Push(pixel)
}

ShowDebugVisualization(centerX, centerY, topPixels, bottomPixels, leftPixels, rightPixels, direction, topMatches, bottomMatches, leftMatches, rightMatches) {
    global MinEdgeMatches
    
    ; Determine best edge
    maxMatches := Max(topMatches, bottomMatches, leftMatches, rightMatches)
    
    ; Center cross (green)
    CreatePixel(centerX, centerY, "Lime")
    CreatePixel(centerX - 1, centerY, "Lime")
    CreatePixel(centerX + 1, centerY, "Lime")
    CreatePixel(centerX, centerY - 1, "Lime")
    CreatePixel(centerX, centerY + 1, "Lime")
    
    ; Yellow = best edge, Red = matched, Blue = not matched
    
    ; Top edge
    isBestTop := (topMatches = maxMatches && maxMatches >= MinEdgeMatches)
    for pixel in topPixels {
        color := pixel.match ? (isBestTop ? "Yellow" : "Red") : "Blue"
        CreatePixel(pixel.x, pixel.y, color)
    }
    
    ; Bottom edge
    isBestBottom := (bottomMatches = maxMatches && bottomMatches >= MinEdgeMatches)
    for pixel in bottomPixels {
        color := pixel.match ? (isBestBottom ? "Yellow" : "Red") : "Blue"
        CreatePixel(pixel.x, pixel.y, color)
    }
    
    ; Left edge
    isBestLeft := (leftMatches = maxMatches && leftMatches >= MinEdgeMatches)
    for pixel in leftPixels {
        color := pixel.match ? (isBestLeft ? "Yellow" : "Red") : "Blue"
        CreatePixel(pixel.x, pixel.y, color)
    }
    
    ; Right edge
    isBestRight := (rightMatches = maxMatches && rightMatches >= MinEdgeMatches)
    for pixel in rightPixels {
        color := pixel.match ? (isBestRight ? "Yellow" : "Red") : "Blue"
        CreatePixel(pixel.x, pixel.y, color)
    }
}

; ============================================================================
; FAILED CENTER VISUALIZATION
; ============================================================================
ShowFailedCenter(centerX, centerY, reason) {
    ; Draw red cross (X)
    CreatePixel(centerX, centerY, "Red")
    CreatePixel(centerX - 1, centerY - 1, "Red")
    CreatePixel(centerX + 1, centerY - 1, "Red")
    CreatePixel(centerX - 1, centerY + 1, "Red")
    CreatePixel(centerX + 1, centerY + 1, "Red")
}

; ============================================================================
; CLEAR VISUALIZATION
; ============================================================================
ClearDebugVisualization() {
    global debugGuiList
    
    ; Close all marker GUI windows
    for pixelGui in debugGuiList {
        try {
            pixelGui.Destroy()
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
IsColorMatch(bitmap, x, y) {
    global ArrowColor, ColorTolerance
    
    try {
        pixelColor := Gdip_GetPixel(bitmap, x, y)
        
        ; Gdip_GetPixel returns ARGB format (0xAARRGGBB)
        ; Extract RGB components
        r1 := (pixelColor >> 16) & 0xFF
        g1 := (pixelColor >> 8) & 0xFF
        b1 := pixelColor & 0xFF
        
        r2 := (ArrowColor >> 16) & 0xFF
        g2 := (ArrowColor >> 8) & 0xFF
        b2 := ArrowColor & 0xFF
        
        ; Check tolerance per channel
        if (Abs(r1 - r2) <= ColorTolerance 
            && Abs(g1 - g2) <= ColorTolerance 
            && Abs(b1 - b2) <= ColorTolerance)
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
    if (directions.Length = 0)
        return ""
    
    ; Build direction string for lookup
    dirString := ""
    for index, dir in directions {
        if (index > 1)
            dirString .= ","
        dirString .= dir
    }
    
    ; Read stratagems.ini and find match
    stratagemIniPath := A_ScriptDir "\\Config\\stratagems.ini"
    
    ; Read full file and search directly
    try {
        fileContent := FileRead(stratagemIniPath)
        
        ; Search for line with EXACT direction match
        ; Format: id=Name|Dir1,Dir2,Dir3|...
        ; We need to match the complete sequence, not just a prefix
        Loop Parse, fileContent, "`n", "`r" {
            line := A_LoopField
            parts := StrSplit(line, "|")
            if (parts.Length >= 2) {
                ; parts[2] contains the direction sequence
                if (parts[2] = dirString) {
                    ; Found exact match, extract key and name
                    keyName := parts[1]
                    eqPos := InStr(keyName, "=")
                    if (eqPos) {
                        id := SubStr(keyName, 1, eqPos - 1)
                        name := SubStr(keyName, eqPos + 1)
                        return {id: id, name: name}
                    }
                }
            }
        }
    }
    
    return ""
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
    activeList := ""
    profileIds := []
    total := stratagems.Length
    lastCount := Min(4, total)

    ; Last N (up to 4) at the front
    Loop lastCount {
        idx := total - lastCount + A_Index
        if (stratagems[idx].id != "unknown")
            profileIds.Push(stratagems[idx].id)
    }

    ; Remaining ones in reverse order
    remaining := total - lastCount
    Loop remaining {
        idx := remaining - A_Index + 1
        if (stratagems[idx].id != "unknown")
            profileIds.Push(stratagems[idx].id)
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
    global DebugMode, OCR_DetectedRowsMap
    
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
            result := MsgBox("No stratagems found!", "Scan Result", 48)
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

    ; Initialize scaling
    Icon_InitScaling()

    ; Dispose any previously captured icons
    Icon_DisposeCapturedIcons()

    ; Get screen dimensions
    global ScreenWidth, ScreenHeight
    ScreenWidth := A_ScreenWidth
    ScreenHeight := A_ScreenHeight

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
    OCR_settingsGui.MarginX := 20
    OCR_settingsGui.MarginY := 20
    OCR_settingsGui.OnEvent("Close", (*) => OCR_settingsGui.Hide())
    
    ; Arrow detection base values for 1440p
    groupArrow := OCR_settingsGui.Add("GroupBox", "x10 y10 w280 h220", "Arrow Detection")
    OCR_settingsGui.Add("Text", "x20 y40 w120", "ArrowStartX:")
    edtArrowStartX := OCR_settingsGui.Add("Edit", "x150 y35 w120", ArrowStartX)
    OCR_settingsGui.Add("Text", "x20 y70 w120", "ArrowStartY:")
    edtArrowStartY := OCR_settingsGui.Add("Edit", "x150 y65 w120", ArrowStartY)
    OCR_settingsGui.Add("Text", "x20 y100 w120", "ArrowStepX:")
    edtArrowStepX := OCR_settingsGui.Add("Edit", "x150 y95 w120", ArrowStepX)
    OCR_settingsGui.Add("Text", "x20 y130 w120", "ArrowStepY:")
    edtArrowStepY := OCR_settingsGui.Add("Edit", "x150 y125 w120", ArrowStepY)
    OCR_settingsGui.Add("Text", "x20 y160 w120", "ArrowCheckDistance:")
    edtArrowCheckDistance := OCR_settingsGui.Add("Edit", "x150 y155 w120", ArrowCheckDistance)
    OCR_settingsGui.Add("Text", "x20 y190 w120", "ArrowEdgeStripSize:")
    edtArrowEdgeStripSize := OCR_settingsGui.Add("Edit", "x150 y185 w120", ArrowEdgeStripSize)
    
    ; Color and tolerance
    groupColor := OCR_settingsGui.Add("GroupBox", "x310 y10 w250 h100", "Color and tolerance")
    OCR_settingsGui.Add("Text", "x320 y40 w120", "ArrowColor (RGB):")
    edtArrowColor := OCR_settingsGui.Add("Edit", "x440 y35 w100", Format("0x{:06X}", ArrowColor))
    OCR_settingsGui.Add("Text", "x320 y70 w120", "ColorTolerance:")
    edtColorTolerance := OCR_settingsGui.Add("Edit", "x440 y65 w100", ColorTolerance)
    
    ; Other settings
    groupOther := OCR_settingsGui.Add("GroupBox", "x310 y120 w250 h210", "Other settings")
    OCR_settingsGui.Add("Text", "x320 y150 w120", "MinEdgeMatches:")
    edtMinEdgeMatches := OCR_settingsGui.Add("Edit", "x440 y145 w100", MinEdgeMatches)
    OCR_settingsGui.Add("Text", "x320 y180 w120", "ArrowCenterStability:")
    edtArrowCenterStability := OCR_settingsGui.Add("Edit", "x440 y175 w100", ArrowCenterStability)
    OCR_settingsGui.Add("Text", "x320 y210 w120", "MaxRows:")
    edtMaxRows := OCR_settingsGui.Add("Edit", "x440 y205 w100", MaxRows)
    OCR_settingsGui.Add("Text", "x320 y240 w120", "MaxArrowsPerRow:")
    edtMaxArrowsPerRow := OCR_settingsGui.Add("Edit", "x440 y235 w100", MaxArrowsPerRow)
    OCR_settingsGui.Add("Text", "x320 y270 w120", "Menu open delay (ms):")
    edtMenuOpenDelay := OCR_settingsGui.Add("Edit", "x440 y265 w100", MenuOpenDelay)
    chkDebugMode := OCR_settingsGui.Add("Checkbox", "x320 y300", "Debug mode(visualization, heavy on system)")
    chkDebugMode.Value := DebugMode
    
    ; HUD Scale
    groupHUDScale := OCR_settingsGui.Add("GroupBox", "x310 y340 w250 h50", "The in-game HUD scale")
    hudScaleList := ["0.75", "0.80", "0.85", "0.90", "0.95", "1.00", "1.05", "1.10", "1.15", "1.20", "1.25"]
    edtHUDScale := OCR_settingsGui.Add("DropDownList", "x320 y360 w120", hudScaleList)
    ; Select current HUDScale
    hudScaleIndex := 4
    for i, val in hudScaleList {
        if (val = Format("{:.2f}", HUDScale)) {
            hudScaleIndex := i
            break
        }
    }
    edtHUDScale.Choose(hudScaleIndex)
    
    
    ; Icon Capture Settings (Scrambler Bypass)
    groupIconCapture := OCR_settingsGui.Add("GroupBox", "x10 y240 w280 h150", "Icon Capture (Scrambler Bypass)")
    OCR_settingsGui.Add("Text", "x20 y270 w120", "Icon Size:")
    edtIconSize := OCR_settingsGui.Add("Edit", "x150 y265 w120", IconSizeOCR)
    OCR_settingsGui.Add("Text", "x20 y300 w120", "Start X:")
    edtIconStartX := OCR_settingsGui.Add("Edit", "x150 y295 w120", IconStartX)
    OCR_settingsGui.Add("Text", "x20 y330 w120", "Start Y:")
    edtIconStartY := OCR_settingsGui.Add("Edit", "x150 y325 w120", IconStartY)
    OCR_settingsGui.Add("Text", "x20 y360 w120", "Vertical Step:")
    edtIconVerticalStep := OCR_settingsGui.Add("Edit", "x150 y355 w120", IconVerticalStep)
    
    ; Buttons
    btnApply := OCR_settingsGui.Add("Button", "x115 y420 w100", "Apply")
    btnExclude := OCR_settingsGui.Add("Button", "x+10 y420 w130", "Exclusion List")
    btnReset := OCR_settingsGui.Add("Button", "x+10 y420 w100", "Reset")
    btnExclude.OnEvent("Click", (*) => OCR_ShowExcludeWindow())
    
    ; Apply button handler
    btnApply.OnEvent("Click", ApplySettings)
    ApplySettings(*) {
        global
        ArrowStartX := edtArrowStartX.Value
        ArrowStartY := edtArrowStartY.Value
        ArrowStepX := edtArrowStepX.Value
        ArrowStepY := edtArrowStepY.Value
        ArrowCheckDistance := edtArrowCheckDistance.Value
        ArrowEdgeStripSize := edtArrowEdgeStripSize.Value
        ArrowColor := edtArrowColor.Value
        ColorTolerance := edtColorTolerance.Value
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
        
        ; Recalculate scaled values
        OCR_InitScaling()
        OCR_SaveSettingsToIni()

        ToolTip("Settings saved", A_ScreenWidth/2, 50)
        SetTimer(() => ToolTip(), -1500)
    }
    
    ; Reset button handler
    btnReset.OnEvent("Click", ResetSettings)
    ResetSettings(*) {
        global
        ; Reset everything to defaults
        ArrowStartX := 168
        ArrowStartY := 152
        ArrowStepX := 28.5
        ArrowStepY := 69.75
        ArrowCheckDistance := 8
        ArrowEdgeStripSize := 12
        ArrowCenterStability := 1
        ArrowColor := 0xB8B59B
        ColorTolerance := 60
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
        
        ; Recalculate scaled values
        OCR_InitScaling()
        OCR_SaveSettingsToIni()

        ; Refresh controls with default values
        edtArrowStartX.Value := ArrowStartX
        edtArrowStartY.Value := ArrowStartY
        edtArrowStepX.Value := ArrowStepX
        edtArrowStepY.Value := ArrowStepY
        edtArrowCheckDistance.Value := ArrowCheckDistance
        edtArrowEdgeStripSize.Value := ArrowEdgeStripSize
        edtArrowColor.Value := Format("0x{:06X}", ArrowColor)
        edtColorTolerance.Value := ColorTolerance
        edtMinEdgeMatches.Value := MinEdgeMatches
        edtArrowCenterStability.Value := ArrowCenterStability
        edtMaxRows.Value := MaxRows
        edtMaxArrowsPerRow.Value := MaxArrowsPerRow
        chkDebugMode.Value := DebugMode
        edtMenuOpenDelay.Value := MenuOpenDelay
        edtHUDScale.Choose(4)
        
        ; Refresh Icon controls
        edtIconSize.Value := IconSizeOCR
        edtIconStartX.Value := IconStartX
        edtIconStartY.Value := IconStartY
        edtIconVerticalStep.Value := IconVerticalStep

        ToolTip("Settings reset to defaults", A_ScreenWidth/2, 50)
        SetTimer(() => ToolTip(), -1500)
    }
    
    ; Show window centered on screen
    OCR_settingsGui.Show("Center")
}

; Initialize scaling at startup
OCR_LoadSettingsFromIni()
OCR_LoadExcludedFromIni()
OCR_InitScaling()
