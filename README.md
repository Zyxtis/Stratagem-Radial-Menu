# Stratagem-Radial-Menu
AutoHotkey script for Helldivers 2, designed to transform the player's playstyle by offering automation of stratagem input with extensive customization and a wide range of functions.

This AutoHotkey script is built for Helldivers 2, designed to streamline key combinations through advanced automation and a customizable Radial Menu. Instead of memorizing complex key combinations or cluttering your keyboard with dozens of binds, you can now call any Stratagem using an intuitive visual interface.

Credits:

    Original Idea: RuggedTheDragon [(Reddit link)](https://www.reddit.com/r/Helldivers/comments/1n1t6jk/ok_hear_me_outa_radial_menu_for_stratagems/)
    Implementation Suggestion: piedras8negras [(Nexus Mods link)](https://www.nexusmods.com/helldivers2/mods/6584?tab=posts)
    Updated GDI+ Library: buliasz [(GitHub link)](https://github.com/buliasz/AHKv2-Gdip)
    Stratagem Icons(1.0-1.1): nvigneux [(GitHub link)](https://github.com/nvigneux/Helldivers-2-Stratagems-icons-svg)
    Improved Stratagem Icons(1.2+): Kungull [(GitHub link)](https://github.com/Kungull)

Key Features:

    Radial Stratagem Menu: A sleek, on-screen circular menu that allows you to select and activate stratagems quickly with your mouse.
    One-Key Activation: Assign the Radial Menu to a single hotkey (keyboard or mouse) for instant access.
    Input Mode Selection: Choose between Arrow keys, WASD or any custom layout for Stratagem input to match your in-game settings.
    User-Friendly GUI: Easily manage your Stratagem list, profiles, and settings through a graphical interface.
    Auto-Pause/Close: active this option to manage the state of the script automatically.
    Stratagem Customization: add new or edit existed stratagem as game evolve.


Usage Instructions:
1. Installation: Ensure you have AutoHotkey v2 installed. Unzip the archive and run Radial_menu.ahk.
2. Initial Setup: Open the Settings tab. Set your desired Radial Menu Key (Default: Middle Mouse Button). Match the Stratagem Menu Key in the script to your in-game key (Default: Left Ctrl). Set your Stratagem Input Layout (Arrows are highly recommended, as the game uses WASD by default).
3. Managing Binds: Use the GUI to add (+) or remove (-) Stratagems for your active profile. Double-click (LMB) a Stratagem in the list popup to mark it as a favorite. This allows you to highlight essential Stratagems (like Reinforce or Resupply) and sort them with a single click.
4. Using the Radial Menu: Press the Radial Menu Key to trigger the menu. While holding the key, move your mouse toward the desired Stratagem and release it to execute the macro.

Important Notes:

    Window Mode: The game must be set to Windowed or Borderless Windowed mode for the Radial Menu GUI to overlay correctly.
    Administrator Rights: If Steam or Helldivers 2 is running as Administrator, you must run the script as Administrator as well.
    Layout Sensitivity: The script works best with the English keyboard layout. If you encounter any issues, manually edit the Settings.ini file or simply delete it (this will reset all saved settings and binds), then restart the script.

Default Hotkeys:

    Middle Mouse Button — Radial Menu 
    F1 - Show/Hide main GUI
    F2 - Show/Hide floating list for keybinding profiles
    F3 - OCR Stratagem Scan
    F4 -  Scrambler Bypass toggle
    Insert — Suspend/Resume the script
    End — Close the script
    Page Up / Page Down — Switches profiles forward / backward (active only while holding the Radial Menu or Floating List key) 

(*)Checkbox Function Description:
This adds the * operator to your hotkey. This means it will trigger regardless of whether other modifier keys (like Ctrl, Alt, Shift, or Win) are held down at the same time.

AHK Designations:

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


OCR Function Description:
Allows the script to detect your current Stratagems during a mission and use them within the radial menu. Its functionality is based on reading the specific arrow sequences of each Stratagem.

    Stratagem Scan (Default: F3): By pressing the hotkey, the OCR reads your current Stratagem arrows, automatically creates and switches to an OCR profile, and populates it with the detected Stratagems for immediate use.
    Scrambler Bypass (Default: F4) : When enabled, the script identifies available Stratagems every time the radial menu is opened and displays them. Once a Stratagem is selected, the OCR reads the current arrow sequence on the screen and executes it automatically.
    OCR Objective: This feature reads and executes Stratagems that are visible on the screen without needing to open the Stratagem menu. These are typically mission-specific Stratagems that appear in certain locations, such as Raising the Flag, Hellbombs, Uploading Data, etc.

Note on Performance: The OCR is sensitive to color palettes and may function incorrectly in extremely bright areas of the map. If you use ReShade or other color-grading tools, the OCR may stop working entirely. In this case, you must manually extract the modified HEX color code of your Stratagem arrows and update the ArrowColor field in OCR Settings.


Weapon Assistant: 
Designed for use with weapons such as the Epoch, RS-422 "Railgun", ARC-3 "Arc Thrower", PLAS-101 "Purifier", and PLAS-15 "Scythe".

There are four available modes: Purifier/Arc Thrower, Railgun, Epoch, and Power Throw:

    Purifier/Arc Thrower: Charges for ~1 second, then releases. Hold the left mouse button for continuous fire.
    Railgun (Unsafe): Press and hold to charge for ~3 seconds; the weapon then fires and reloads automatically. If the hotkey is released early, it will fire and reload upon release. Use this mode for the Railgun’s "Unsafe" setting.
    Epoch: Charges for ~2.5 seconds, then releases.
    Power Throw: Automates a timed sequence using the left mouse button and the interaction key to throw items—such as barrels and platinum bars—further than a standard throw.

How it works:
The script performs a predefined action cycle by automatically triggering a left-click based on the selected mode. Once launched, the script remains inactive until toggled via its assigned hotkey.

The Safety Catch deactivates the fire button until a designated safety key is held, preventing accidental firing. To enable this feature, tick the checkbox and enter your desired key.
For example, if your fire key is LMB and the safety key is RMB, the macro will only execute while RMB is held. By using the tilde (~) operator, you allow the safety keypress to "pass through" to the game; this ensures the safety mechanism activates while still triggering the key's native in-game action (such as aiming).

It's not recommended to activate the Weapon Assistant while the AutoHotkey GUI window is active. Clicking inside the window might cause a "stuck click" which can be resolved by pressing Esc or opening Task Manager. 

Driver Assistant: This feature introduces automatic gear shifting to enhance vehicle responsiveness and handling. Press W to shift to first gear and S to shift to reverse. Additionally, the script automatically deactivates this functionality when you press E (the vehicle exit key).

Inventory Manager: Drop an item from your inventory with a single key press.

Quick Weapon Switch: When enabled, the script tracks the 1, 2, 3, and 4 keys. Pressing the designated hotkey will switch between the two most recently used slots. For your convenience, you can disable tracking for specific slots(keys).
