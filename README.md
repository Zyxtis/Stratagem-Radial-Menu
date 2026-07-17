🌐 **Language:** **English** | [Русский](localization/ru/Readme(ru).md)
# Stratagem Radial Menu
AutoHotkey script for Helldivers 2, designed to transform the player's playstyle by offering automation of stratagem input with extensive customization and a wide range of functions.

This AutoHotkey script is built for Helldivers 2, designed to streamline key combinations through advanced automation and a customizable Radial Menu. Instead of memorizing complex key combinations or cluttering your keyboard with dozens of binds, you can now call any Stratagem using an intuitive visual interface.

### Credits:

    Original Idea: RuggedTheDragon [(Reddit link)](https://www.reddit.com/r/Helldivers/comments/1n1t6jk/ok_hear_me_outa_radial_menu_for_stratagems/)
    Implementation Suggestion: piedras8negras [(Nexus Mods link)](https://www.nexusmods.com/helldivers2/mods/6584?tab=posts)
    Updated GDI+ Library: buliasz [(GitHub link)](https://github.com/buliasz/AHKv2-Gdip) [Required for the radial menu functionality and the Color-Based OCR method]
    Updated FindText Library: FeiYue [(AHK forum link)](https://www.autohotkey.com/boards/viewtopic.php?f=83&t=116471) [Required for the Shape-Based OCR method]
    Stratagem Icons(1.0-1.1): nvigneux [(GitHub link)](https://github.com/nvigneux/Helldivers-2-Stratagems-icons-svg)
    Improved Stratagem Icons(1.2+): Kungull [(GitHub link)](https://github.com/Kungull)

### Key Features:

    Radial Stratagem Menu: A sleek, on-screen circular menu that allows you to select and activate stratagems quickly with your mouse.
    One-Key Activation: Assign the Radial Menu to a single hotkey (keyboard or mouse) for instant access.
    Input Mode Selection: Choose between Arrow keys, WASD or any custom layout for Stratagem input to match your in-game settings.
    User-Friendly GUI: Easily manage your Stratagem list, profiles, and settings through a graphical interface.
    Auto-Pause/Close: active this option to manage the state of the script automatically.
    Stratagem Customization: add new or edit existed stratagem as game evolve.


### Usage Instructions:
1. Installation: Ensure you have AutoHotkey v2 installed. Unzip the archive and run Radial_menu.ahk.
2. Initial Setup: Open the Settings tab. Set your desired Radial Menu Key (Default: Middle Mouse Button). Match the Stratagem Menu Key in the script to your in-game key (Default: Left Ctrl). Set the Stratagem Input Layout to match between the script and the game (Default: Arrows in the script, WASD in-game).
3. Managing Binds: Use the GUI to add (+) or remove (-) Stratagems for your active profile. Double-click (LMB) a Stratagem in the list popup to mark it as a favorite. This allows you to highlight essential Stratagems (like Reinforce or Resupply) and sort them with a single click.
4. Using the Radial Menu: Hold the Radial Menu Key to open the menu. While holding the key, move your mouse to the desired Stratagem, then release the key to execute the macro.

### Important Notes:

    Window Mode: The game must be set to Windowed or Borderless Windowed mode for the Radial Menu GUI to overlay correctly.
    Administrator Rights: If Steam or Helldivers 2 is running as Administrator, you must run the script as Administrator as well.
    Layout Sensitivity: The script works best with the English keyboard layout. The settings include an Auto-Lang feature that automatically switches the keyboard layout when entering keys for creating bindings. If you encounter any issues, manually edit the Settings.ini or Profiles.ini files, or simply delete them (this will reset all saved settings, profiles, and bindings), then restart the script.

### Default Hotkeys:

    Middle Mouse Button — Radial Menu 
    F1 - Show/Hide main GUI
    F2 - Show/Hide floating list for keybinding profiles. Hold the key to move the list position.
    F3 - OCR Stratagem Scan
    F4 -  Scrambler Bypass toggle
    Insert — Suspend/Resume the script
    End — Close the script
    Page Up / Page Down — Switches profiles forward / backward (active only while holding the Radial Menu or Floating List key) 

### (*)Checkbox Function Description:

This adds the * operator to your hotkey. This means it will trigger regardless of whether other modifier keys (like Ctrl, Alt, Shift, or Win) are held down at the same time.

### AHK Designations:

    LButton - Left mouse button click
    RButton - Right mouse button click
    MButton - Middle mouse button / scroll wheel (click)
    XButton1 - Fourth mouse button (usually the "Back" button in a browser)
    XButton2 - Fifth mouse button (usually the "Forward" button in a browser)
    WheelUp - Scroll mouse wheel up
    WheelDown - Scroll mouse wheel down
    ^ - Ctrl key
    ! - Alt key
    + - Shift key
    * - "Any modifier key" operator. Makes the hotkey universal. The hotkey will trigger even if other modifiers (Ctrl, Alt, Shift, Win) are being held down at that moment.
    ~ - "Pass-through" operator. Causes the hotkey to execute its action without blocking the original keypress from reaching the application. 


### OCR Function Description:
<details>
<summary> **Expand** </summary>
    
Allows the script to detect your current Stratagems during a mission and use them within the radial menu. Its functionality is based on reading the specific arrow sequences of each Stratagem.

    Stratagem Scan (Default: F3): By pressing the hotkey, the OCR reads your current Stratagem arrows, automatically creates and switches to an OCR profile, and populates it with the detected Stratagems for immediate use.
    Scrambler Bypass (Default: F4) : When enabled, the script identifies available Stratagems every time the radial menu is opened and displays them. Once a Stratagem is selected, the OCR reads the current arrow sequence on the screen and executes it automatically.
    OCR Objective: This feature reads and executes Stratagems that are visible on the screen without needing to open the Stratagem menu. These are typically mission-specific Stratagems that appear in certain locations, such as Raising the Flag, Hellbombs, Uploading Data, etc.

Note on Performance: The OCR system is highly sensitive to the position and appearance of the stratagem menu. Any changes from the game's default settings may reduce detection accuracy or cause OCR to fail.
Examples include: Enabling visual effects such as Curved. Changing the stratagem menu HUD scale in the game settings(HUD scaling differences can be compensated for by adjusting the In-Game HUD Scale option in the OCR settings).

If you experience detection issues, enable Debug Mode. This will display the arrow detection grid so you can verify that it aligns correctly with the stratagem arrows on your system. If the grid does not match the arrows, you can manually adjust it until the alignment is correct.

**Detection Methods:**

1. Color-Based OCR

This method detects stratagem arrows based on their color. Keep in mind that it is sensitive to changes in image colors. Detection accuracy may decrease in very bright areas of the map. If you use HDR, ReShade, or any other software that modifies the game's color grading, OCR may fail to detect arrows entirely. In this case, enable **Debug Mode** and perform an **OCR Scan** (**F3**) during a mission to obtain the updated HEX color value of the arrows. Then replace the **Arrow Color** value in the OCR settings with the newly detected HEX code.

2. Shape-Based OCR

This method uses the **FindText** library to detect stratagem arrows based on their shape. At present, the pattern database supports only **1920×1080 (1080p)**, **2560×1440 (1440p)**, and **3840×2160 (2160p)** resolutions. The number of available patterns is still relatively small, so in most cases this method does not provide higher detection accuracy than the **Color-Based OCR** method.
</details>

### Assistant Modules:
<details>
<summary> **Expand** </summary>
    
A collection of helper modules designed to make gameplay more convenient and efficient. These assistants improve interaction with different game features, provide better control over various systems, and create a smoother and more comfortable gaming experience.

**Weapon Assistant:** Designed for use with weapons such as the Epoch, RS-422 "Railgun", ARC-3 "Arc Thrower", PLAS-101 "Purifier", and PLAS-15 "Loyalist".

There are four available modes: Purifier/Arc Thrower, Railgun, Epoch, and Power Throw:

    Purifier/Arc Thrower: Charges for ~1 second, then releases. Hold the left mouse button for continuous fire.
    Railgun (Unsafe): Automatically cuts off the charge at around 3 seconds, preventing overheating and weapon explosion. After reaching the cutoff point, the script automatically fires and reloads the weapon. If the hotkey is released earlier, the weapon fires immediately at the current charge level and reloads. Designed for use with the Railgun's "Unsafe" setting.
    Epoch: Automatically cuts off the charge at around 2.5 seconds, preventing overheating and weapon detonation. If the hotkey is released earlier, the weapon fires immediately with a lower charge. Reaching the cutoff point provides a wider damage area.
    Power Throw: Automates a timed sequence using the left mouse button and the interaction key to throw items—such as barrels and platinum bars—further than a standard throw.

How it works:
The script performs a predefined action cycle by automatically triggering a left-click based on the selected mode. Once launched, the script remains inactive until toggled via its assigned hotkey.

Safety Catch: The Safety Catch deactivates the macro fire button until a designated safety key is held, preventing accidental firing. To enable this feature, tick the checkbox and enter your desired key.
For example, if your macro fire key is LMB and the safety key is RMB, the macro will only execute while RMB is held. By using the tilde (~) operator, you allow the safety keypress to "pass through" to the game; this ensures the safety mechanism activates while still triggering the key's native in-game action (such as aiming).

It's not recommended to activate the Weapon Assistant while the AutoHotkey GUI window is active. Clicking inside the window might cause a "stuck click" which can be resolved by pressing Esc or opening Task Manager. 


**Driver Assistant:** This feature introduces automatic gear shifting to enhance vehicle responsiveness and handling. Press W to shift to forward gear and S to shift to reverse. Additionally, the script automatically deactivates this functionality when you press E (the vehicle exit key).

- Enhanced Gear Switch: Changes the gear switching algorithm, allowing direct switching to the selected gear instead of using the standard sequential switching process. This speeds up gear changes, but due to the game's built-in automatic gear shifting system, in some situations it may interfere and select a gear higher than expected. For proper operation, it is recommended to disable automatic gear shifting in the game settings.
- Driver Stratagem Call: Automates the process of changing seats when calling stratagems from a vehicle. When activating a stratagem through the radial menu or an assigned hotkey, the character automatically switches to the passenger seat, leans out of the window, and inputs the stratagem code. After that, you have **5 seconds** to throw the stratagem (**LMB**). If the throw is not performed within this time, the call is automatically canceled. After successfully throwing the stratagem, the character automatically returns to the driver's seat.

**Inventory Manager:** Drop an item from your inventory with a single key press.

**Quick Weapon Switch:** When enabled, the script tracks the 1, 2, 3, and 4 keys. Pressing the designated hotkey will switch between the two most recently used slots. For your convenience, you can disable tracking for specific slots(keys).
</details>


### Detailed Description of OCR Detection Methods
<details>
<summary> **Expand** </summary>

## 1. Color-Based OCR Method

The color-based OCR method detects stratagem arrows by analyzing their color information. The target arrow color is defined in the **ArrowColor** field using the **HEX (RGB)** format.

### Detection Parameters

The detection process uses several tolerance settings:

- **ColorTolerance** — defines the allowed color variation when searching for the initial arrow color.
- **ExtractColorTol** — defines the tolerance used for the extracted arrow color after a more precise color sample is obtained.
- **CenterStability** — controls the accuracy of the initial center-point color check:
  - **0** — checks only one pixel at the exact center of the arrow.
  - **1** — checks a 3×3 pixel area (center pixel plus surrounding pixels).
  - **2** — checks a 5×5 pixel area.
  - **3** — checks a 7×7 pixel area.

### Detection Process

The detection process works in two stages:

#### First Stage: Arrow Presence Detection

The script first checks whether an arrow exists by analyzing the color stability around its center point.

If the detected color matches the expected arrow color within the defined tolerance, the script extracts a more accurate color sample from the center of the arrow.

#### Second Stage: Arrow Direction Detection

The extracted color is then used to analyze the arrow edges and determine its direction.

- **ArrowCheckDistance** — defines the distance from the center point to the arrow edge where the edge check is performed.
- **ArrowEdgeStripSize** — defines the size of the perpendicular pixel strip used to compare colors along the arrow edge.
- **MinEdgeMatches** — filters out weak edge detections by ignoring edges with fewer matching pixels than the required minimum.

The final direction is determined by comparing the number of matching pixels within the edge strips. The side with the higher number of matching pixels represents the direction opposite to the arrow tip, allowing the script to accurately determine the arrow orientation.

## 2. Shape-Based OCR Method

The shape-based OCR method relies heavily on the **FindText** library and its pattern database.

Currently, the pattern database is quite limited, but it should be sufficient to provide basic functionality. Expanding the database with additional resolutions and arrow variations may improve detection accuracy in the future.

### Detection Parameters

- **FaultTolerance** — defines the allowed error variation when searching for an arrow using the available patterns.

- **ScanSteps** — divides the maximum tolerance into equal steps for progressive scanning. Instead of searching only once at the maximum tolerance, the scan is performed in multiple passes with gradually increasing tolerance.

Example:  
A **15% tolerance** with **3 scan steps** will perform searches at:
  
`5% → 10% → 15%`

This approach improves detection accuracy by prioritizing lower tolerance matches first. At high FaultTolerance values, searching directly with the maximum tolerance can cause false detections because multiple arrow directions may match the same pattern. A correct match found at a lower tolerance is accepted before less accurate matches at higher tolerance levels are considered.

## Detection Patterns
Gray2Two — Fast and efficient for high-contrast images with consistent lighting. It produces stable results when objects are clearly separated from the background and requires minimal parameter tuning.

GrayDiff2Two — Better suited for images with uneven lighting, gradients, shadows, or anti-aliased edges. By relying on local contrast instead of absolute brightness, it offers more robust detection in challenging visual conditions.
</details>

### Resolution Scaling Note

All pixel-based values depend on the screen resolution. The default visible values are calibrated for **1440p (2560×1440)** resolution.

If a different resolution is detected, all pixel-based values are automatically scaled to match the current screen resolution:

- **1080p (1920×1080)** → values are scaled by **0.75×**
- **1440p (2560×1440)** → values are used at **1.00×** (default)
- **2160p (3840×2160)** → values are scaled by **1.50×**

This scaling applies to all parameters that use pixel values, ensuring consistent detection behavior across different screen resolutions.

---
