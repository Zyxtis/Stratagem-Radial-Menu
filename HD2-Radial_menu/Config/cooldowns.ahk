; cooldowns.ahk - Stratagem cooldown tracking and Eagle uses tracking
; Included from Radial_menu.ahk

; --- COOLDOWN STATE ---
global CooldownsEnabled := false
global CooldownDeploymentKey := "LButton"
global CooldownDeploymentGamepadButton := ""
global CooldownDeploymentGamepadButtonDraft := ""
global CooldownDeploymentGamepadTriggered := false
global CooldownWaitDeployKey := true   ; when true, cooldown starts only after the Deployment Button is pressed
global CooldownDeployWaitTimeMs := 5000 ; deployment confirmation window in milliseconds
global BlockStratagemsOnCooldown := true
global CooldownModules := Map(
    "streamlined_request_process", false,
    "hand_carts", false,
    "zero_g_breech_loading", false,
    "liquid_ventilated_cockpit", false,
    "pit_crew_hazard_pay", false,
    "expanded_weapons_bay", false,
    "advanced_crew_training", false,
    "targeting_software_upgrade", false,
    "morale_augmentation", false,    
    "synthetic_supplementation", false,
    "rapid_launch_system", false,
    "streamlined_launch_process", false,
    "dynamic_tracking", false
)
global StratagemCooldownReadyAt := Map()  ; id -> A_TickCount when stratagem is ready again
global StratagemCallInReadyAt := Map()   ; id -> A_TickCount when the call-in phase ends
global StratagemBetweenReadyAt := Map()  ; id -> A_TickCount when the between-call phase ends
global CooldownPendingId := ""           ; stratagem awaiting deployment confirmation
global CooldownsGui := 0
global LastCooldownRedrawTick := 0
global Radial_pBrushCooldown := 0
global Radial_pBrushCooldownText := 0
global Radial_pBrushCallInText := 0
global Radial_hFontCooldown := 0

; Eagle uses tracking: id -> remaining uses (Eagles share a common pool via Eagle Re-arm)
global EagleUsesLeft := Map()

; --- COOLDOWN FUNCTIONS ---

; Ordered list of the 13 Stratagem Call-in & Cooldown Upgrade Modules
CooldownModuleList() {
    return [
        "streamlined_request_process",
        "hand_carts",
        "zero_g_breech_loading",
        "liquid_ventilated_cockpit",
        "pit_crew_hazard_pay",
        "expanded_weapons_bay",
        "advanced_crew_training",
        "targeting_software_upgrade",
        "morale_augmentation",
        "synthetic_supplementation",
        "rapid_launch_system",
        "streamlined_launch_process",
        "dynamic_tracking"
    ]
}

; Returns the effective cooldown applied after deploying the given stratagem, taking the currently enabled upgrade modules into account. Returns 0 when the stratagem has no meaningful cooldown to track
GetStratagemCooldownSeconds(id) {
    global StratagemSubCat, StratagemBetweenUses, StratagemFullRecharge, CooldownModules

    if !IsObject(StratagemFullRecharge) || !StratagemFullRecharge.Has(id)
        return 0

    sub := StratagemSubCat.Has(id) ? StratagemSubCat[id] : ""

    isEagle := (SubStr(id, 1, 6) = "eagle_")
    isOrbital := (SubStr(id, 1, 8) = "orbital_")
    isBackpack := (sub = "Backpack" || sub = "Рюкзаки")
    isSupport := (sub = "Support Weapons" || sub = "Оружие Поддержки")
    isSentry := (sub = "Sentry" || sub = "Турели")
    isEmplacement := (sub = "Emplacement" || sub = "Установки")
    isResupply := (id = "resupply")

    ; Eagle stratagems only have a between-call cooldown after each deployment
    if (isEagle) {
        base := 0.0
        if StratagemBetweenUses.Has(id) {
            v := StratagemBetweenUses[id]
            base := (v = "" || v = "N/A") ? 0.0 : v + 0.0
        }
        if (base <= 0)
            return 0
        if (CooldownModules.Has("liquid_ventilated_cockpit") && CooldownModules["liquid_ventilated_cockpit"])
            base *= 0.5
        return base
    }

    ; Non-Eagle stratagems use the full recharge timer
    v := StratagemFullRecharge[id]
    if (v = "" || v = "N/A")
        return 0
    base := v + 0.0
    if (base <= 0)
        return 0

    mult := 1.0
    if (CooldownModules.Has("morale_augmentation") && CooldownModules["morale_augmentation"])
        mult -= 0.05
    if (isOrbital && CooldownModules.Has("zero_g_breech_loading") && CooldownModules["zero_g_breech_loading"])
        mult -= 0.10
    if (isBackpack && CooldownModules.Has("hand_carts") && CooldownModules["hand_carts"])
        mult -= 0.10
    if (isSupport && CooldownModules.Has("streamlined_request_process") && CooldownModules["streamlined_request_process"])
        mult -= 0.10
    if ((isSentry || isEmplacement || isResupply) && CooldownModules.Has("synthetic_supplementation") && CooldownModules["synthetic_supplementation"])
        mult -= 0.10

    return base * mult
}

; Returns the effective call-in time (in seconds) for a stratagem, applying the modules that make the call-in instant. Returns 0 when there is no call-in delay.
GetStratagemCallInSeconds(id) {
    global StratagemCallInTime, StratagemSubCat, CooldownModules

    if !IsObject(StratagemCallInTime) || !StratagemCallInTime.Has(id)
        return 0

    v := StratagemCallInTime[id]
    if (v = "" || v = "N/A")
        return 0
    base := v + 0.0
    if (base <= 0)
        return 0

    sub := StratagemSubCat.Has(id) ? StratagemSubCat[id] : ""
    isOrbital := (SubStr(id, 1, 8) = "orbital_")
    isSupport := (sub = "Support Weapons" || sub = "Оружие Поддержки")
    isSentry := (sub = "Sentry" || sub = "Турели")
    isEmplacement := (sub = "Emplacement" || sub = "Установки")

    ; Modules that make the call-in instant
    if (isOrbital && CooldownModules.Has("targeting_software_upgrade") && CooldownModules["targeting_software_upgrade"])
        return 0
    if (isEmplacement && CooldownModules.Has("rapid_launch_system") && CooldownModules["rapid_launch_system"])
        return 0
    if (isSentry && CooldownModules.Has("dynamic_tracking") && CooldownModules["dynamic_tracking"])
        return 0
    if (isSupport && CooldownModules.Has("streamlined_launch_process") && CooldownModules["streamlined_launch_process"])
        return 0

    return base
}

; True when the stratagem is currently in its call-in phase
IsStratagemInCallIn(id) {
    global StratagemCallInReadyAt
    if !IsObject(StratagemCallInReadyAt) || !StratagemCallInReadyAt.Has(id)
        return false
    return (StratagemCallInReadyAt[id] > A_TickCount)
}

; Remaining cooldown seconds for a stratagem (0 when ready). During the call-in phase this returns the call-in time remaining; afterwards the recharge time.
GetStratagemRemainingSeconds(id) {
    global StratagemCooldownReadyAt, StratagemCallInReadyAt
    now := A_TickCount
    ; Call-in phase takes priority
    if (IsObject(StratagemCallInReadyAt) && StratagemCallInReadyAt.Has(id) && StratagemCallInReadyAt[id] > now)
        return (StratagemCallInReadyAt[id] - now) / 1000
    if !IsObject(StratagemCooldownReadyAt) || !StratagemCooldownReadyAt.Has(id)
        return 0
    rem := StratagemCooldownReadyAt[id] - now
    return (rem > 0) ? rem / 1000 : 0
}

; True when a stratagem cannot currently be called because it is on cooldown, has no Eagle uses left, or is an unnecessary Eagle Re-arm.
IsStratagemUnavailable(id) {
    global CooldownsEnabled, StratagemCooldownReadyAt
    if (!CooldownsEnabled)
        return false

    now := A_TickCount
    if (StratagemCooldownReadyAt.Has(id) && StratagemCooldownReadyAt[id] > now)
        return true

    return IsEagleOutOfUses(id) || IsEagleRearmDimmed(id)
}

; Shared call gate used by every stratagem execution path.
IsStratagemCallBlocked(id) {
    global BlockStratagemsOnCooldown
    return (BlockStratagemsOnCooldown && IsStratagemUnavailable(id))
}

; True when an Eagle stratagem has no uses left (unavailable until reloaded)
IsEagleOutOfUses(id) {
    if !IsEagleStratagem(id)
        return false
    if (id = "eagle_re_arm")
        return false
    return (GetEagleUses(id) <= 0)
}

; True when at least one active stratagem is currently on cooldown, an Eagle is out of uses, or Eagle Re-arm has no recharge work to do
HasAnyActiveCooldown() {
    global ActiveStratagems, StratagemCooldownReadyAt, CooldownsEnabled
    if (!CooldownsEnabled || !IsObject(StratagemCooldownReadyAt))
        return false
    now := A_TickCount
    for id in ActiveStratagems {
        if (StratagemCooldownReadyAt.Has(id) && StratagemCooldownReadyAt[id] > now)
            return true
        if IsEagleOutOfUses(id) || IsEagleRearmDimmed(id)
            return true
    }
    return false
}

; True when at least one stratagem in the supplied list currently has a countdown timer
HasAnyCooldownCountdownIn(stratagemIds) {
    global StratagemCooldownReadyAt, CooldownsEnabled
    if (!CooldownsEnabled || !IsObject(StratagemCooldownReadyAt))
        return false

    now := A_TickCount
    for id in stratagemIds {
        if (StratagemCooldownReadyAt.Has(id) && StratagemCooldownReadyAt[id] > now)
            return true
    }
    return false
}

; Cooldown countdown check for the radial profile
HasAnyCooldownCountdown() {
    global ActiveStratagems
    return HasAnyCooldownCountdownIn(ActiveStratagems)
}

; Cooldown countdown check for the floating keybind list's profile
HasAnyKeybindCooldownCountdown() {
    global ActiveKeybindStratagems
    return HasAnyCooldownCountdownIn(ActiveKeybindStratagems)
}

; Request a radial redraw once per second while any cooldown countdown is visible. The final redraw is requested when the last countdown ends
RequestCooldownRadialRedraw() {
    global CooldownsEnabled, LastCooldownRedrawTick, ForceRadialRedraw

    if (!CooldownsEnabled || !HasAnyCooldownCountdown()) {
        if (LastCooldownRedrawTick != 0)
            ForceRadialRedraw := true
        LastCooldownRedrawTick := 0
        return
    }

    now := A_TickCount
    if (LastCooldownRedrawTick = 0 || now - LastCooldownRedrawTick >= 1000)
        ForceRadialRedraw := true
}

; Record that the radial menu was redrawn so the next countdown refresh starts a fresh one-second interval. This also clears the gate after the final draw.
RecordCooldownRadialRedraw() {
    global CooldownsEnabled, LastCooldownRedrawTick
    LastCooldownRedrawTick := (CooldownsEnabled && HasAnyCooldownCountdown()) ? A_TickCount : 0
}

; True when the stratagem is an Eagle stratagem
IsEagleStratagem(id) => (SubStr(id, 1, 6) = "eagle_")

; Base Eagle uses (from data + the Expanded Weapons Bay module), minimum 1
GetEagleMaxUses(id) {
    global StratagemUses, CooldownModules
    base := 1
    if IsObject(StratagemUses) && StratagemUses.Has(id) {
        v := StratagemUses[id]
        if (v != "" && v != "N/A")
            base := Integer(v)
    }
    if (CooldownModules.Has("expanded_weapons_bay") && CooldownModules["expanded_weapons_bay"])
        base += 1
    if (base < 1)
        base := 1
    return base
}

; Remaining uses for an Eagle stratagem (initialized to its maximum on first query)
GetEagleUses(id) {
    global EagleUsesLeft
    maxUses := GetEagleMaxUses(id)
    if !EagleUsesLeft.Has(id) {
        EagleUsesLeft[id] := maxUses
        return maxUses
    }
    return EagleUsesLeft[id]
}

; Display suffix for stratagem labels (e.g. " [3]"). Uses tracking is part of the cooldown feature, so no uses count is shown when cooldowns are disabled.
; Eagle Re-arm is not a deployable weapon, so it never shows a uses count.
GetEagleUsesLabel(id) {
    global CooldownsEnabled
    if (!CooldownsEnabled || !IsEagleStratagem(id) || id = "eagle_re_arm")
        return ""
    return " [" . GetEagleUses(id) . "]"
}

; True when at least one deployable Eagle in the active profile has a use remaining
HasAnyActiveEagleUseRemaining() {
    global ActiveStratagems
    for id in ActiveStratagems {
        if !IsEagleStratagem(id)
            continue
        if (id = "eagle_re_arm")
            continue
        if (GetEagleUses(id) >= 1)
            return true
    }
    return false
}

; Full reload time for an Eagle stratagem.
; Pit Crew Hazard Pay always reduces the reload by 20%. 
; Advanced Crew Training reduces it by 10% when it was available at the moment the reload started.
; Morale Augmentation is applied to the manual Eagle Re-arm path.
GetEagleFullReloadSeconds(id, advancedCrewTrainingApplies := false, moraleAugmentationApplies := false) {
    global StratagemFullRecharge, CooldownModules
    base := 150.0
    if IsObject(StratagemFullRecharge) && StratagemFullRecharge.Has(id) {
        v := StratagemFullRecharge[id]
        if (v != "" && v != "N/A")
            base := v + 0.0
    }
    if (base <= 0)
        base := 150.0
    mult := 1.0
    if (CooldownModules.Has("pit_crew_hazard_pay") && CooldownModules["pit_crew_hazard_pay"])
        mult -= 0.20
    if (CooldownModules.Has("advanced_crew_training") && CooldownModules["advanced_crew_training"] && advancedCrewTrainingApplies)
        mult -= 0.10
    if (moraleAugmentationApplies && CooldownModules.Has("morale_augmentation") && CooldownModules["morale_augmentation"])
        mult -= 0.05
    if (mult < 0)
        mult := 0
    return base * mult
}

; Starts a stratagem's cooldown: first the call-in phase (shown in a different colour), then the full recharge / between-call timer.
StartStratagemCooldown(id) {
    global StratagemCooldownReadyAt, StratagemCallInReadyAt
    now := A_TickCount
    callIn := GetStratagemCallInSeconds(id)
    recharge := GetStratagemCooldownSeconds(id)
    if (callIn > 0)
        StratagemCallInReadyAt[id] := now + Round(callIn * 1000)
    else if StratagemCallInReadyAt.Has(id)
        StratagemCallInReadyAt.Delete(id)
    StratagemCooldownReadyAt[id] := now + Round((callIn + recharge) * 1000)
}

; Sets a call-in + recharge timer pair for a stratagem (call-in phase first).
SetCallInThenRecharge(id, rechargeSecs) {
    global StratagemCooldownReadyAt, StratagemCallInReadyAt
    now := A_TickCount
    callIn := GetStratagemCallInSeconds(id)
    if (callIn > 0)
        StratagemCallInReadyAt[id] := now + Round(callIn * 1000)
    else if StratagemCallInReadyAt.Has(id)
        StratagemCallInReadyAt.Delete(id)
    StratagemCooldownReadyAt[id] := now + Round((callIn + rechargeSecs) * 1000)
}

; Applies the shared Eagle between-call cooldown to EVERY active Eagle stratagem
; Eagle Re-arm is NOT included here - it only goes on cooldown once all Eagles are out of uses
ApplyEagleBetweenCallCooldown(sourceId) {
    global ActiveStratagems, StratagemCooldownReadyAt, StratagemCallInReadyAt, StratagemBetweenReadyAt
    ; Absolute reference times computed once from the called Eagle
    now := A_TickCount
    callIn := GetStratagemCallInSeconds(sourceId)
    between := GetStratagemCooldownSeconds(sourceId)
    callInAt := (callIn > 0) ? (now + Round(callIn * 1000)) : 0
    readyAt := now + Round((callIn + between) * 1000)

    for id in ActiveStratagems {
        if !IsEagleStratagem(id)
            continue
        if (id = "eagle_re_arm")
            continue
        ; Apply the exact same timestamps to every Eagle so they stay in sync
        if (callInAt > 0)
            StratagemCallInReadyAt[id] := callInAt
        else if StratagemCallInReadyAt.Has(id)
            StratagemCallInReadyAt.Delete(id)
        if (between > 0)
            StratagemBetweenReadyAt[id] := readyAt
        else if StratagemBetweenReadyAt.Has(id)
            StratagemBetweenReadyAt.Delete(id)
        StratagemCooldownReadyAt[id] := readyAt
    }
}

; Sets the full Eagle reload sequence for one stratagem: the between-call phase, then the full rearm. The call-in phase is SKIPPED for a full reload. All timers are set so the phases stay in sync across Eagles.
SetEagleFullReloadSequence(id, advancedCrewTrainingApplies := false, moraleAugmentationApplies := false) {
    global StratagemCooldownReadyAt, StratagemCallInReadyAt, StratagemBetweenReadyAt
    now := A_TickCount
    between := GetStratagemCooldownSeconds(id)
    reload := GetEagleFullReloadSeconds(id, advancedCrewTrainingApplies, moraleAugmentationApplies)

    ; Full reload skips the call-in phase
    if StratagemCallInReadyAt.Has(id)
        StratagemCallInReadyAt.Delete(id)

    if (between > 0)
        StratagemBetweenReadyAt[id] := now + Round(between * 1000)
    else if StratagemBetweenReadyAt.Has(id)
        StratagemBetweenReadyAt.Delete(id)

    StratagemCooldownReadyAt[id] := now + Round((between + reload) * 1000)
}

; Full reload for ALL Eagle stratagems AND Eagle Re-arm (between + rearm, synced)
; and restore their uses to maximum. Used when the last Eagle use is spent while the other Eagles are already out of uses.
ApplyEagleFullReloadAll(advancedCrewTrainingApplies := false, moraleAugmentationApplies := false) {
    global ActiveStratagems, EagleUsesLeft

    ; Set every timer before restoring uses so all Eagles use the same availability
    ; snapshot that triggered this automatic full reload.
    for id in ActiveStratagems {
        if !IsEagleStratagem(id)
            continue
        SetEagleFullReloadSequence(id, advancedCrewTrainingApplies, moraleAugmentationApplies)
    }

    for id in ActiveStratagems {
        if (IsEagleStratagem(id) && id != "eagle_re_arm")
            EagleUsesLeft[id] := GetEagleMaxUses(id)
    }
}

; Full reload for a SINGLE Eagle stratagem (used when its own uses are exhausted).
; Synced across all Eagles and Eagle Re-arm.
ApplyEagleFullReload(id, advancedCrewTrainingApplies := false) {
    ApplyEagleFullReloadAll(advancedCrewTrainingApplies, false)
}

; Eagle Re-arm: full reload for ALL Eagles WITHOUT the call-in / between phases.
; Uses are restored to maximum.
ApplyEagleRearm() {
    global StratagemCooldownReadyAt, StratagemCallInReadyAt, StratagemBetweenReadyAt, ActiveStratagems, EagleUsesLeft
    now := A_TickCount
    advancedCrewTrainingApplies := HasAnyActiveEagleUseRemaining()

    ; Manual Eagle Re-arm receives Morale Augmentation. Set every timer before
    ; restoring uses so all active Eagles use the same availability snapshot.
    for id in ActiveStratagems {
        if !IsEagleStratagem(id)
            continue
        if StratagemCallInReadyAt.Has(id)
            StratagemCallInReadyAt.Delete(id)
        if StratagemBetweenReadyAt.Has(id)
            StratagemBetweenReadyAt.Delete(id)
        reload := GetEagleFullReloadSeconds(id, advancedCrewTrainingApplies, true)
        StratagemCooldownReadyAt[id] := now + Round(reload * 1000)
    }

    for id in ActiveStratagems {
        if IsEagleStratagem(id)
            EagleUsesLeft[id] := GetEagleMaxUses(id)
    }
}

; Number of deployable Eagle stratagems currently in the active profile
; (Eagle Re-arm is not a deployable weapon, so it is not counted)
GetActiveEagleCount() {
    global ActiveStratagems
    n := 0
    for id in ActiveStratagems {
        if !IsEagleStratagem(id)
            continue
        if (id = "eagle_re_arm")
            continue
        n++
    }
    return n
}

; True when every deployable Eagle stratagem in the active profile has no uses left (Eagle Re-arm is ignored)
AreAllActiveEaglesExhausted() {
    global ActiveStratagems
    found := false
    for id in ActiveStratagems {
        if !IsEagleStratagem(id)
            continue
        if (id = "eagle_re_arm")
            continue
        found := true
        if (GetEagleUses(id) > 0)
            return false
    }
    return found
}

; True when the active profile has at least one deployable Eagle and every one
; of those Eagles currently has its maximum number of uses. Re-arm is unnecessary
; in that state, so its sector should be dimmed. Eagle Re-arm itself is ignored.
AreAllActiveEaglesAtMaxUses() {
    global ActiveStratagems
    found := false
    for id in ActiveStratagems {
        if !IsEagleStratagem(id)
            continue
        if (id = "eagle_re_arm")
            continue
        found := true
        if (GetEagleUses(id) != GetEagleMaxUses(id))
            return false
    }
    return found
}

; True only for an Eagle Re-arm sector that has nothing left to recharge.
IsEagleRearmDimmed(id) {
    return (id = "eagle_re_arm" && AreAllActiveEaglesAtMaxUses())
}

; Applies the cooldown/uses effects for a confirmed stratagem deployment
ApplyStratagemDeployment(id) {
    global StratagemCooldownReadyAt, ForceRadialRedraw, IsMenuVisible, EagleUsesLeft

    if (id = "eagle_re_arm") {
        ; Eagle Re-arm: full reload of every Eagle stratagem and restore all uses
        ApplyEagleRearm()
        InvalidateRadialCache()
    } else if IsEagleStratagem(id) {
        ; Capture availability before consuming the selected use. Advanced Crew
        ; Training still applies when this call exhausts the selected Eagle.
        advancedCrewTrainingApplies := HasAnyActiveEagleUseRemaining()

        ; Consume one use
        remaining := GetEagleUses(id) - 1
        if (remaining < 0)
            remaining := 0
        EagleUsesLeft[id] := remaining

        if (remaining > 0) {
            ; Uses remain: there is only one Eagle jet, so calling any Eagle puts
            ; ALL Eagles on the same call-in + between-call cooldown (synced to
            ; the called Eagle's call-in time).
            ApplyEagleBetweenCallCooldown(id)
        } else if (GetActiveEagleCount() <= 1) {
            ; Single Eagle: when its uses run out it goes on its own full reload
            ; (call-in + between + rearm).
            ApplyEagleFullReload(id, advancedCrewTrainingApplies)
        } else if (AreAllActiveEaglesExhausted()) {
            ; Multiple Eagles and ALL are now out of uses: they all go on the
            ; synced full reload (call-in + between + rearm) together.
            ApplyEagleFullReloadAll(advancedCrewTrainingApplies, false)
        } else {
            ; This Eagle is out of uses but other Eagles still have uses. It still
            ; plays the call-in + between-call phase (shared jet), then stays
            ; unavailable (dimmed) until the pool is exhausted or Eagle Re-arm.
            ApplyEagleBetweenCallCooldown(id)
        }

        ; Eagle label shows remaining uses, so the cached background must refresh
        InvalidateRadialCache()
    } else {
        StartStratagemCooldown(id)
    }

    if IsMenuVisible
        ForceRadialRedraw := true

    ; Refresh the floating keybind list immediately (if visible) and keep it ticking
    OnCooldownStateChanged()
}

; Arm the deployment confirmation for the given stratagem after its macro executes.
; When CooldownWaitDeployKey is false, the cooldown starts immediately instead.
CooldownArmFor(id) {
    global CooldownsEnabled, CooldownPendingId, CooldownWaitDeployKey, CooldownDeploymentGamepadTriggered, CooldownDeployWaitTimeMs
    if !CooldownsEnabled
        return
    ; Eagle Re-arm triggers immediately (no deployment confirmation / deployment button):
    ; it instantly puts every Eagle on full reload and restores their uses
    if (id = "eagle_re_arm") {
        ApplyEagleRearm()
        InvalidateRadialCache()
        OnCooldownStateChanged()
        return
    }
    if (GetStratagemCooldownSeconds(id) <= 0)
        return
    ; If waiting for the deployment key is disabled, start the cooldown right away
    if !CooldownWaitDeployKey {
        ApplyStratagemDeployment(id)
        return
    }
    CooldownPendingId := id
    CooldownDeploymentGamepadTriggered := false
    SetCooldownDeploymentHotkey(true)
    ; Opening the stratagem menu again also cancels the confirmation
    SetCooldownMenuCancelHotkey(true)
    ; Auto-disarm if the confirmation button is not pressed within the configured time
    SetTimer(CooldownDisarm, -CooldownDeployWaitTimeMs)
}

CooldownDisarm() {
    global CooldownPendingId, CooldownDeploymentGamepadTriggered
    CooldownPendingId := ""
    CooldownDeploymentGamepadTriggered := false
    SetCooldownDeploymentHotkey(false)
    SetCooldownMenuCancelHotkey(false)
}

; Cancel a pending deployment confirmation (e.g. when the stratagem menu is opened again or another stratagem is called)
CancelPendingDeployment(*) {
    global CooldownPendingId, CooldownDeploymentGamepadTriggered
    if (CooldownPendingId = "")
        return
    CooldownPendingId := ""
    CooldownDeploymentGamepadTriggered := false
    SetTimer(CooldownDisarm, 0)
    SetCooldownDeploymentHotkey(false)
    SetCooldownMenuCancelHotkey(false)
}

; Register/unregister the deployment confirmation hotkey (passes through to the game)
SetCooldownDeploymentHotkey(active) {
    global CooldownDeploymentKey
    if (active && CooldownDeploymentKey != "")
        RegisterSimpleHotkey("~" . CooldownDeploymentKey, ConfirmCooldownDeployment, "CooldownDeployment")
    else
        RegisterSimpleHotkey("", ConfirmCooldownDeployment, "CooldownDeployment")
}

; Poll the optional gamepad deployment button while a deployment confirmation is pending.
CheckCooldownDeploymentGamepadTrigger() {
    global CooldownPendingId, CooldownDeploymentGamepadButton, CooldownDeploymentGamepadTriggered
    global IsMenuVisible, IsExecutingMacro

    if (CooldownPendingId = "" || CooldownDeploymentGamepadButton = "" || IsMenuVisible || IsExecutingMacro) {
        CooldownDeploymentGamepadTriggered := false
        return false
    }

    isPressed := IsGamepadButtonPressed(CooldownDeploymentGamepadButton)
    if (isPressed && !CooldownDeploymentGamepadTriggered) {
        CooldownDeploymentGamepadTriggered := true
        ConfirmCooldownDeployment()
        return true
    }

    CooldownDeploymentGamepadTriggered := isPressed
    return false
}

; Register/unregister a pass-through hotkey on the stratagem menu key so opening the
; stratagem menu again cancels a pending deployment confirmation
SetCooldownMenuCancelHotkey(active) {
    global StratagemMenuKey, CooldownDeploymentKey
    if (active && StratagemMenuKey != "" && StratagemMenuKey != CooldownDeploymentKey)
        RegisterSimpleHotkey("~" . StratagemMenuKey, CancelPendingDeployment, "CooldownMenuCancel")
    else
        RegisterSimpleHotkey("", CancelPendingDeployment, "CooldownMenuCancel")
}

; Confirms the pending stratagem deployment and starts its cooldown
ConfirmCooldownDeployment(*) {
    global CooldownPendingId, CooldownDeploymentGamepadTriggered
    if (CooldownPendingId = "")
        return
    id := CooldownPendingId
    CooldownPendingId := ""
    CooldownDeploymentGamepadTriggered := false
    SetTimer(CooldownDisarm, 0)
    SetCooldownDeploymentHotkey(false)
    SetCooldownMenuCancelHotkey(false)

    ApplyStratagemDeployment(id)
}

; Suffix for keybind list rows: " [12s]" while on cooldown plus Eagle uses " [3]".
; Returns an empty string when there is nothing to show.
GetCooldownListSuffix(id) {
    global CooldownsEnabled
    suffix := ""
    if CooldownsEnabled {
        rem := GetStratagemRemainingSeconds(id)
        if (rem > 0)
            suffix .= " [" . Ceil(rem) . "s]"
    }
    suffix .= GetEagleUsesLabel(id)
    return suffix
}

InitCooldownGraphics() {
    global Radial_pBrushCooldown, Radial_pBrushCooldownText, Radial_pBrushCallInText, Radial_hFontCooldown
    global Radial_hFamily, IconSize
    if (Radial_pBrushCooldown = 0) {
        Radial_pBrushCooldown := Gdip_BrushCreateSolid(0xB0000000)
        Radial_pBrushCooldownText := Gdip_BrushCreateSolid(0xFFFF4040)   ; red = recharge
        Radial_pBrushCallInText := Gdip_BrushCreateSolid(0xFFFFD700)     ; gold = call-in
        fontSize := Max(12, Round(IconSize * 0.55))
        Radial_hFontCooldown := Gdip_FontCreate(Radial_hFamily, fontSize, 1)
    }
}

; Draws dark overlays and remaining-time text for every sector that is on cooldown
DrawCooldownOverlays(pGraphics, count, sectorAngle, mid) {
    global ActiveStratagems, StratagemCooldownReadyAt, StratagemCallInReadyAt, CooldownsEnabled, MenuSize, InnerRadius
    global Radial_pBrushCooldown, Radial_pBrushCooldownText, Radial_pBrushCallInText, Radial_hFontCooldown, Radial_hFormat

    if (!CooldownsEnabled || !IsObject(StratagemCooldownReadyAt))
        return

    now := A_TickCount
    ; Skip quickly when there is no cooldown, out-of-uses Eagle, or unnecessary Re-arm
    anyActive := false
    for id in ActiveStratagems {
        if (StratagemCooldownReadyAt.Has(id) && StratagemCooldownReadyAt[id] > now) {
            anyActive := true
            break
        }
        if IsEagleOutOfUses(id) || IsEagleRearmDimmed(id) {
            anyActive := true
            break
        }
    }
    if !anyActive
        return

    InitCooldownGraphics()

    Loop count {
        id := ActiveStratagems[A_Index]
        onCooldown := (StratagemCooldownReadyAt.Has(id) && StratagemCooldownReadyAt[id] > now)
        outOfUses := IsEagleOutOfUses(id)
        rearmDimmed := IsEagleRearmDimmed(id)
        if !(onCooldown || outOfUses || rearmDimmed)
            continue

        startA := -90 - (sectorAngle / 2) + (A_Index - 1) * sectorAngle
        Gdip_FillPie(pGraphics, Radial_pBrushCooldown, 0, 0, MenuSize, MenuSize, startA, sectorAngle)

        ; Out-of-uses Eagles and an unnecessary Re-arm are only dimmed (no countdown text)
        if !onCooldown
            continue

        ; Determine the current phase for this stratagem:
        ;   call-in  -> gold number
        ;   between  -> red number
        ;   recharge -> red number
        inCallIn := (IsObject(StratagemCallInReadyAt) && StratagemCallInReadyAt.Has(id) && StratagemCallInReadyAt[id] > now)
        inBetween := (!inCallIn && IsObject(StratagemBetweenReadyAt) && StratagemBetweenReadyAt.Has(id) && StratagemBetweenReadyAt[id] > now)

        ; Out-of-uses Eagles show NO call-in / between countdown text - they are
        ; only dimmed during those phases. They still show the recharge countdown
        ; once the full rearm phase begins.
        if (outOfUses && (inCallIn || inBetween))
            continue

        if (inCallIn) {
            secs := Ceil((StratagemCallInReadyAt[id] - now) / 1000)
            brush := Radial_pBrushCallInText
        } else {
            secs := Ceil((StratagemCooldownReadyAt[id] - now) / 1000)
            brush := Radial_pBrushCooldownText
        }

        rad := (startA + sectorAngle / 2) * 3.14159 / 180
        dist := mid * 0.7
        tx := mid + Cos(rad) * dist
        ty := mid + Sin(rad) * dist

        text := Format("{:d}", secs)
        RectF := Buffer(16)
        NumPut("Float", tx - 50, "Float", ty - 22, "Float", 100, "Float", 44, RectF)
        DllCall("gdiplus\GdipDrawString", "Ptr", pGraphics, "WStr", text, "Int", -1, "Ptr", Radial_hFontCooldown, "Ptr", RectF, "Ptr", Radial_hFormat, "Ptr", brush)
    }

    ; Punch the center hole back out so the dim only covers the wheel ring
    ; (same technique used by the radial background: compositing mode 1 + clear brush)
    Gdip_SetCompositingMode(pGraphics, 1)
    pBrushClear := Gdip_BrushCreateSolid(0x00000000)
    Gdip_FillEllipse(pGraphics, pBrushClear, mid - InnerRadius, mid - InnerRadius, InnerRadius * 2, InnerRadius * 2)
    Gdip_DeleteBrush(pBrushClear)
    Gdip_SetCompositingMode(pGraphics, 0)
}

; --- COOLDOWNS POPUP ---
UpdateCooldownDeployWaitTimeEnabled(editCtrl, checkCtrl, *) {
    editCtrl.Enabled := checkCtrl.Value
}

ShowCooldownsPopup() {
    global settingsGui, CooldownsGui, CooldownsEnabled, CooldownDeploymentKey, CooldownDeploymentGamepadButton, CooldownDeploymentGamepadButtonDraft, CooldownModules, CooldownWaitDeployKey, CooldownDeployWaitTimeMs, BlockStratagemsOnCooldown, StratagemMenuKey

    if IsSet(CooldownsGui) && CooldownsGui {
        try {
            if WinExist("ahk_id " CooldownsGui.Hwnd) {
                CooldownsGui.Show()
                return
            }
        } catch {
        }
        CooldownsGui := 0
    }

    SwitchToEnglishLayout()
    CooldownsGui := Gui("-Caption +LastFound +Owner" settingsGui.Hwnd, Lang.Get("cooldowns_title"))
    CooldownsGui.BackColor := "202020"
    CooldownsGui.SetFont("s" Scale(10) " cC4C4C4", "Segoe UI")
    CooldownsGui.MarginX := Scale(5)
    CooldownsGui.MarginY := Scale(5)
    CooldownsGui.OnEvent("Close", (*) => CooldownsCloseGui())
    CooldownsGui.OnEvent("Escape", (*) => CooldownsCloseGui())

    ; Title bar (draggable)
    CooldownsGui.SetFont("cFFFFFF s" Scale(12))
    CooldownsGui.Add("Text", "x0 y0 w" Scale(330) " h" Scale(30) " Background2A2A2A Border +Center", Lang.Get("cooldowns_title")).OnEvent("Click", (*) => PostMessage(0xA1, 2,,, "A"))
    CooldownsGui.Add("Button", "x+5 y0 w" Scale(30) " h" Scale(30), "X").OnEvent("Click", (*) => CooldownsCloseGui())
    CooldownsGui.SetFont("s" Scale(10) " cC4C4C4")

    ; Enable checkbox
    cbEnable := AddStandardCheckBox(CooldownsGui, "x" Scale(15) " y" Scale(45) " vCooldownsEnable")
    cbEnable.Value := CooldownsEnabled
    CooldownsGui.Add("Text", "x+0 yp", Lang.Get("enable_cooldowns"))

    ; Block calls to stratagems that are currently unavailable
    cbBlock := AddStandardCheckBox(CooldownsGui, "x" Scale(15) " y+" Scale(6) " vCooldownsBlock")
    cbBlock.Value := BlockStratagemsOnCooldown
    CooldownsGui.Add("Text", "x+0 yp", Lang.Get("block_stratagems_on_cooldown"))

    ; Wait Deployment Key checkbox (checked by default; tied to the Deployment Button)
    cbWaitDeploy := AddStandardCheckBox(CooldownsGui, "x" Scale(15) " y+" Scale(6) " vCooldownsWaitDeploy")
    cbWaitDeploy.Value := CooldownWaitDeployKey
    CooldownsGui.Add("Text", "x+0 yp", Lang.Get("wait_deploy_key"))

    ; Deployment key + optional gamepad capture button on the same row
    CooldownsGui.Add("Text", "x" Scale(15) " y+" Scale(12) " w" Scale(150), Lang.Get("deployment_button"))
    deploymentInput := HotkeyInput(CooldownsGui, 15, 0, "", {value: StripWildcard(CooldownDeploymentKey), hasWildcard: false})
    CooldownDeploymentGamepadButtonDraft := CooldownDeploymentGamepadButton
    deploymentGamepadCaptureBtn := CooldownsGui.Add("Button", "x+" Scale(5) " yp w" Scale(28) " h" Scale(24), "🎮")
    deploymentGamepadCaptureBtn.OnEvent("Click", ShowCooldownGamepadCapturePopup)
    CooldownsGui.Add("Text", "x" Scale(15) " y+" Scale(6) " w" Scale(350) " cGray", Format(Lang.Get("deployment_button_hint"), StratagemMenuKey))

    ; Deployment confirmation timeout (before Upgrade Modules)
    CooldownsGui.Add("Text", "x" Scale(15) " y+" Scale(8) " w" Scale(220), Lang.Get("deploy_wait_time"))
    deployWaitTimeEdit := CooldownsGui.Add("Edit", "x" Scale(15) " y+" Scale(6) " w" Scale(50) " Number Background2f2f2f", CooldownDeployWaitTimeMs)
    deployWaitTimeEdit.Enabled := CooldownWaitDeployKey
    cbWaitDeploy.OnEvent("Click", UpdateCooldownDeployWaitTimeEnabled.Bind(deployWaitTimeEdit, cbWaitDeploy))

    ; Upgrade modules
    CooldownsGui.Add("Text", "x" Scale(15) " y+" Scale(12) " w" Scale(300) " cFFD700", Lang.Get("modules_label"))

    moduleCbs := Map()
    for moduleName in CooldownModuleList() {
        cb := AddStandardCheckBox(CooldownsGui, "x" Scale(20) " y+" Scale(6))
        cb.Value := CooldownModules.Has(moduleName) ? CooldownModules[moduleName] : false
        CooldownsGui.Add("Text", "x+0 yp", Lang.Get("module_" moduleName))
        moduleCbs[moduleName] := cb
    }

    ; Buttons
    btnSave := CooldownsGui.Add("Button", "x" Scale(30) " y+" Scale(15) " w" Scale(150) " h" Scale(30), Lang.Get("save"))
    btnSave.OnEvent("Click", (*) => CooldownsSaveAndClose(cbEnable, cbBlock, cbWaitDeploy, deploymentInput, deployWaitTimeEdit, moduleCbs))

    btnClose := CooldownsGui.Add("Button", "x+" Scale(10) " yp w" Scale(150) " h" Scale(30), Lang.Get("kocr_close"))
    btnClose.OnEvent("Click", (*) => CooldownsCloseGui())

    CooldownsGui.Show("AutoSize")
    DllCall("RedrawWindow", "Ptr", CooldownsGui.Hwnd, "Ptr", 0, "Ptr", 0, "UInt", 0x0185)
}

CooldownsSaveAndClose(cbEnable, cbBlock, cbWaitDeploy, deploymentInput, deployWaitTimeEdit, moduleCbs) {
    global CooldownsEnabled, CooldownDeploymentKey, CooldownDeploymentGamepadButton, CooldownDeploymentGamepadButtonDraft, CooldownModules, CooldownWaitDeployKey, CooldownDeployWaitTimeMs, BlockStratagemsOnCooldown

    CooldownsEnabled := cbEnable.Value
    BlockStratagemsOnCooldown := cbBlock.Value
    CooldownWaitDeployKey := cbWaitDeploy.Value

    val := deploymentInput.GetValue()
    CooldownDeploymentKey := (val = "") ? "LButton" : val
    CooldownDeploymentGamepadButton := CooldownDeploymentGamepadButtonDraft

    CooldownDeployWaitTimeMs := (deployWaitTimeEdit.Value = "") ? 5000 : Integer(deployWaitTimeEdit.Value)
    if (CooldownDeployWaitTimeMs < 1000 || CooldownDeployWaitTimeMs > 60000) {
        CooldownDeployWaitTimeMs := 5000
        deployWaitTimeEdit.Value := 5000
    }

    for moduleName, cb in moduleCbs
        CooldownModules[moduleName] := cb.Value

    SaveSettings()

    ; Rebuild both cached radial labels and the visible floating list so toggling
    ; cooldown tracking immediately shows/hides Eagle uses counts.
    InvalidateRadialCache()
    OnCooldownStateChanged()
    CooldownsCloseGui()
}

CooldownsCloseGui(*) {
    global CooldownsGui, CooldownDeploymentGamepadButtonDraft
    CooldownDeploymentGamepadButtonDraft := ""
    if IsSet(CooldownsGui) && CooldownsGui {
        try CooldownsGui.Destroy()
    }
    CooldownsGui := 0
}
