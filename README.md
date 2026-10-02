# UnhumanCommonSensePatch

A comprehensive Quality-of-Life (QoL) patch and mod bundle for **UNHUMAN**.

The patcher modifies the game package directly (`package.nw\unhuman.html` and `package.nw\lang\*.js`), adding essential inventory management shortcuts, weapon & ammunition conveniences, loadout automation, and full multi-language localization across 12 languages.

---

## Features

### 1. Tutorial Skip Toggle + Instant Rewards
- Adds a **Skip Tutorial** toggle directly in the Character Creation screen.
- Bypasses the tutorial sequence and mentor tasks without missing out on progression.
- Automatically grants all starting rewards: **$225,000 cash**, **Level 5**, **4 Skill Points**, random tier-3 starter weapon, and tech upgrade chips.

### 2. Start Screen / Intro Splash Skip
- Adds a toggle in Game Settings (`Settings > Display`, ON by default).
- Allows instant skipping of the splash screen by clicking anywhere or pressing any key.

### 3. Minigame Auto-Complete Penalty Removal
- Automatically adjusts auto-complete minigame penalties (removes the `-15%` loot penalty in Raid Filters on game versions where applicable).

### 4. Double-Click to Equip / Unequip Items
- **From Stash / Containers**: Double-click weapons, armor, accessories, or containers to equip them into available slots or automatically pack them into rigs/backpacks/pockets.
- **From Loadout**: Double-click equipped weapons, armor, or rigs to instantly unequip them to stash.
- **From Augments**: Double-click augments to equip or unequip to/from the augment locker.

### 5. Right-Click Context Menu Equip / Unequip
- Adds contextual **"Equip"** option when right-clicking stash and container items.
- Adds contextual **"Unequip"** option when right-clicking equipped gear or augment items.

### 6. Right-Click Weapon "Buy Ammo" Shortcut
- Right-clicking an equipped weapon in your loadout displays a **"Buy Ammo"** option in the context menu.
- Clicking it automatically opens the **Gunsmith** trader shop tab, auto-selects the compatible clip/magazine in the fixed stock list, smoothly scrolls to it, and pulses it with a glowing green neon indicator for immediate purchase.

### 7. Weapon Hover Compatible Magazine Highlighting
- Hovering over any weapon in your stash or loadout dynamically scans and highlights all compatible clips and magazines across your entire inventory:
  - Stash grid
  - Equipped Chest Rig container
  - Equipped Backpack container
  - Pockets
  - Secure Pouch
- Highlighted magazines pulse with a cyber green neon glow (`.uh-mag-highlight`) to make ammunition and mag management effortless.
- Highlights automatically clear when the mouse leaves or when the tooltip closes.

### 8. Empty Loadout Slot Quick-Equip Modal & Trader Direct-Buy
- Clicking any empty equipment slot in your loadout (`primary`, `secondary`, `melee`, `head`, `body`, `rig`, `backpack`, `pouch`, `earpiece`, `facecover`, `eyewear`, etc.) or empty augment slot opens an interactive cyber-styled **Quick-Equip Modal**:
  - Displays all compatible items for that slot currently stored in your stash.
  - Lists essential item stats (Damage, RPM, Durability, Armor rating, Container grid size, Rarity tier coloring).
  - Clicking any item immediately equips it to that slot.
  - Features a direct **"Buy from Trader (TRADER_NAME)"** shortcut button at the top that navigates directly to the designated trader for that gear category:
    - Weapons -> **Gunsmith**
    - Armor, Rigs, Bags, & Accessories -> **Weaver**
    - Cybernetic Augments -> **Ripperdoc**
    - Relics -> **Signal Broker**

### 9. Full Multi-Language Support (12 Languages)
All mod-added elements (toggles, notifications, menu options, modal dialogs, and button labels) are fully localized across all 12 game languages:
- **English** (`en`)
- **German / Deutsch** (`de`)
- **Spanish / Español (LATAM)** (`es`)
- **French / Français** (`fr`)
- **Japanese / 日本語** (`ja`)
- **Korean / 한국어** (`ko`)
- **Polish / Polski** (`pl`)
- **Portuguese / Português (BR)** (`pt`)
- **Russian / Русский** (`ru`)
- **Turkish / Türkçe** (`tr`)
- **Simplified Chinese / 简体中文** (`zh`)
- **Traditional Chinese / 繁體中文** (`zhtw`)

### 10. Insanity Background Generation & Layer Step Visual Progress Indicator
- Auto-clickers continue processing in the background when navigating away from the Insanity minigame tab (while raiding in Operations, managing Stash/Loadout, Crafting in Tech Table, or Trading).
- Deals auto-attack damage, defeats enemies, collects Insanity currency, rolls boss caches, advances layers, and updates checkpoints seamlessly.
- **100% Silent & Performance-Optimized**: Suppresses all SFX, VFX (screen shake, flash), and death screen overlays while running in the background. Does not touch hidden DOM elements, ensuring zero FPS drop during raids or hideout navigation.
- **Auto-Reset to Layer 1 on Death**: If auto Insanity is defeated by a difficult layer or boss, it automatically resets to Layer 1 rather than locking into an unwinnable checkpoint death loop. This enables continuous autonomous farming of Insanity currency from earlier layers, while preserving the highest layer reached (`runBest`).
- **Visual Progress Indicator**: Fills the "INSANITY" navigation menu button across the top bar, Hub Terminal (`[ INSANITY ]`), and NavDock from left to right with a clean slate grey fill (`--uh-ins-fill`) indicating the current 10-layer step and enemy HP progression.

### 11. SKILLS Asterisk Indicator on Unspent Points
- Dynamically attaches an asterisk `*` to any button that leads to SKILLS and reads as SKILLS (`SKILLS *`, `[ SKILLS * ]`) whenever the player has unspent skill points to allocate (`availablePoints > 0`).
- Seamlessly clears the asterisk once all points are spent.
- Works across all navigation views (Top Bar, Hub Terminal, NavDock) and is fully compatible with all 12 supported languages.

Uses a dual-layer internationalization architecture:
1. **Dynamic Runtime Injection**: Injects mod dictionaries into the game's `I18N` engine so translations work dynamically upon booting and switching languages in-game.
2. **Static Dictionary Patching**: Updates `package.nw\lang\*.js` files with safety `.bak` backups.
3. **Modular Localization**: All translation strings are defined in [`translations.json`](translations.json), making it easy to tweak or add community translations.

---

## Installation & Usage

1. **Extract or Copy Files**:
   Place the mod files (`patcher.bat`, `patcher.js`, `patcher.ps1`, `translations.json`) into:
   - Your game root directory (where `package.nw` is located), **OR**
   - A `mod` subfolder inside your game directory (e.g., `<GameFolder>\mod\`).

2. **Run the Patcher**:
   - Double-click **`patcher.bat`** (or run `powershell -ExecutionPolicy Bypass -File patcher.ps1`).
   - If Node.js is installed on your PATH, it uses the Node.js engine; otherwise, it automatically falls back to the native PowerShell engine without requiring any external dependencies or runtimes.

3. **Menu Options**:
   - **`[1] Apply Mod Patch`**: Backs up originals and applies all mod features and language files.
   - **`[2] Restore Original Game`**: Restores `unhuman.html` and all language files from original backups.
   - **`[3] Check Mod Status`**: Displays whether the mod is applied, backup status, and localization counts.
   - **`[4] Exit`**

---

## Safety & Backups

- Automatic backups (`package.nw\unhuman.html.bak` and `package.nw\lang\*.js.bak`) are created prior to any file modification.
- Re-applying the mod safely restores from the clean backup first, ensuring completely idempotent updates.
- Using **Option 2 (Restore)** restores the game to its completely vanilla state at any time.

---

## Contributing

Open for suggestions and improvements! Feel free to fork this repository, submit issues, or create pull requests with additional features or localization improvements.
