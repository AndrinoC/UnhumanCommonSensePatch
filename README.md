# UnhumanCommonSensePatch

A Quality-of-Life (QoL) patch and mod bundle for **UNHUMAN**.

The patcher modifies the game package directly (`package.nw\unhuman.html` and `package.nw\lang\*.js`), adding essential usability improvements, inventory quality-of-life shortcuts, and full multi-language localization.

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
- **From Stash / Containers**: Double-click weapons, armor, accessories, or containers to equip them into available slots or pack them into rigs/backpacks/pockets.
- **From Loadout**: Double-click equipped weapons, armor, or rigs to instantly unequip them to stash.
- **From Augments**: Double-click augments to equip or unequip to/from the augment locker.

### 5. Right-Click Context Menu Equip / Unequip
- Adds contextual **"Equip"** option when right-clicking stash and container items.
- Adds contextual **"Unequip"** option when right-clicking equipped gear or augment items.

### 6. Full Multi-Language Support (12 Languages)
All mod-added elements (toggles, notifications, menu options, and alerts) are fully localized across all 12 game languages:
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
   - If Node.js is installed on your PATH, it uses the Node.js engine; otherwise, it automatically falls back to the PowerShell engine without requiring any dependencies.

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
