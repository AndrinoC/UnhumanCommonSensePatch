# UnhumanCommonSensePatch

A comprehensive Quality-of-Life (QoL), rebalance, and convenience mod bundle for **UNHUMAN**.

The patcher modifies the game package directly (`package.nw\unhuman.html` and `package.nw\lang\*.js`), adding essential inventory management shortcuts, weapon & ammunition conveniences, loadout automation, endgame progression safeguards, and full multi-language localization across 12 languages.

---

## Table of Contents
1. [Features Overview](#features-overview)
2. [Configuration Guide (How to Change Values)](#configuration-guide-how-to-change-values)
   - [Endgame Abyss & Crafting Rebalance](#1-endgame-abyss--crafting-rebalance)
   - [Insanity Background Generation Tuning](#2-insanity-background-generation-tuning)
   - [Tutorial Skip Starting Rewards](#3-tutorial-skip-starting-rewards)
   - [Visual Themes, Highlights & Colors](#4-visual-themes-highlights--colors)
   - [Editing Translations & Text](#5-editing-translations--text)
3. [How to Enable & Disable Specific Features](#how-to-enable--disable-specific-features)
   - [In-Game Toggles](#in-game-toggles)
   - [Patch-Level Toggles (Code)](#patch-level-toggles-code)
   - [Patch Name Mapping Reference](#patch-name-mapping-reference)
4. [How to Edit the Mod Files & Developer Workflow](#how-to-edit-the-mod-files--developer-workflow)
   - [Directory Structure](#directory-structure)
   - [Dual-Engine Architecture (Node.js vs PowerShell)](#dual-engine-architecture-nodejs-vs-powershell)
   - [Step-by-Step Editing Workflow](#step-by-step-editing-workflow)
   - [Backups & Safety Guarantees](#backups--safety-guarantees)
5. [Installation & Usage](#installation--usage)
6. [Supported Languages](#supported-languages)

---

## Features Overview

### 1. Tutorial Skip Toggle + Instant Rewards
* Adds a **Skip Tutorial** toggle directly in the Character Creation screen.
* Bypasses the tutorial sequence and mentor tasks without missing out on progression.
* Automatically grants starting rewards: **$225,000 cash**, **Level 5**, **4 Skill Points**, a random tier-3 starter weapon (AR, SMG, Shotgun, or DMR), and starter tech chips (10x Root, 10x Flash, 10x Kernel).

### 2. Start Screen / Intro Splash Skip
* Adds a toggle in Game Settings (`Settings > Display > Skip Intro Splash`, enabled by default).
* Allows instant skipping of the splash screen by clicking anywhere or pressing any key on boot.

### 3. Minigame Auto-Complete Penalty Removal
* Automatically adjusts auto-complete minigame penalties (removes the `-15%` loot penalty in Raid Filters on game versions where applicable).

### 4. Double-Click to Equip / Unequip Items
* **From Stash / Containers**: Double-click weapons, armor, accessories, or containers to equip them into available slots or automatically pack them into rigs/backpacks/pockets.
* **From Loadout**: Double-click equipped weapons, armor, or rigs to instantly unequip them to stash.
* **From Augments**: Double-click augments to equip or unequip to/from the augment locker.

### 5. Right-Click Context Menu Equip / Unequip
* Adds contextual **"Equip"** option when right-clicking stash and container items.
* Adds contextual **"Unequip"** option when right-clicking equipped gear or augment items.

### 6. Right-Click Weapon "Buy Ammo" Shortcut
* Right-clicking an equipped weapon in your loadout displays a **"Buy Ammo"** option in the context menu.
* Clicking it automatically opens the **Gunsmith** trader shop tab, auto-selects the compatible clip/magazine in the fixed stock list, smoothly scrolls to it, and pulses it with a glowing green neon indicator for immediate purchase.

### 7. Weapon Hover Compatible Magazine Highlighting
* Hovering over any weapon in your stash or loadout dynamically scans and highlights all compatible clips and magazines across your entire inventory:
  * Stash grid
  * Equipped Chest Rig container
  * Equipped Backpack container
  * Pockets
  * Secure Pouch
* Highlighted magazines pulse with a cyber green neon glow (`.uh-mag-highlight`) to make ammunition management effortless.
* Highlights automatically clear when the mouse leaves or when the tooltip closes.

### 8. Empty Loadout Slot Quick-Equip Modal & Trader Direct-Buy
* Clicking any empty equipment slot in your loadout (`primary`, `secondary`, `melee`, `head`, `body`, `rig`, `backpack`, `pouch`, `earpiece`, `facecover`, `eyewear`, etc.) or empty augment slot opens an interactive cyber-styled **Quick-Equip Modal**:
  * Displays all compatible items for that slot currently stored in your stash.
  * Lists essential item stats (Damage, RPM, Durability, Armor rating, Container grid size, Rarity tier coloring).
  * Clicking any item immediately equips it to that slot.
  * Features a direct **"Buy from Trader (TRADER_NAME)"** shortcut button at the top that navigates directly to the designated trader for that gear category:
    * Weapons -> **Gunsmith**
    * Armor, Rigs, Bags, & Accessories -> **Weaver**
    * Cybernetic Augments -> **Ripperdoc**
    * Relics -> **Signal Broker**

### 9. Insanity Background Generation & Visual Layer Step Indicator
* **Seamless Multitasking**: Auto-clickers unlocked in the Insanity minigame continue running in the background when navigating away to other tabs (Operations/Raids, Stash, Loadout, Tech Table, Traders, Quests, Skills).
* **100% Silent & Zero Performance Drop**: Suppresses all combat hit sounds, golden enemy spawn sweeps, screen shake, visual glitch flashes, and death overlays while running in the background. Does not touch hidden DOM elements, ensuring zero FPS impact during raids.
* **Auto-Reset to Layer 1 on Death**: If auto Insanity is defeated by a difficult layer or boss, it automatically resets to **Layer 1** rather than locking into an unwinnable checkpoint death loop. This enables continuous autonomous farming of Insanity currency from earlier layers, while preserving the highest cycle record (`runBest`).
* **Visual Progress Indicator**: Fills the "INSANITY" navigation menu button across the top bar, Hub Terminal (`[ INSANITY ]`), and NavDock from left to right with a clean slate grey fill (`--uh-ins-fill`) indicating the current 10-layer step and enemy HP progression.

### 10. SKILLS Asterisk Indicator on Unspent Points
* Dynamically attaches an asterisk `*` to any button that leads to SKILLS and reads as SKILLS (`SKILLS *`, `[ SKILLS * ]`) whenever the player has unspent skill points to allocate (`availablePoints > 0`).
* Seamlessly clears the asterisk once all points are spent.
* Works across all navigation views (Top Bar, Hub Terminal, NavDock) and is fully compatible with all 12 supported languages.

### 11. Mythic Weapon Upgrades (+1 to +10 Checkpoint & Zero Deletion)
* **Zero Weapon Deletion**: Permanently disables weapon destruction on failed upgrades across all levels (previously, upgrading past +5 had a catastrophic chance to permanently delete your weapon base).
* **Safety Checkpoint Floor at +5**: Failing an upgrade at +5 or higher only downgrades the weapon by 1 level, but will **never drop below +5**. Once you reach the +5 milestone, your weapon is permanently protected at +5 minimum.
* **Fairer Endgame Success Progression**: Smoothed success rates for higher tiers (+1 to +3: 100%, +4: 85%, +5: 70%, +6: 55%, +7: 45%, +8: 35%, +9: 25%, +10: 20%). Makes reaching +10 and unlocking the 3rd ability slot achievable with dedication rather than ~1/1,200 astronomical odds.
* **Dynamic UI Updates**: Modal dialogs automatically adjust to show "CONFIRM UPGRADE" with regular theme instead of danger alerts, and warning text updates to reflect level downgrade rather than deletion risk.

### 12. Nullpoint Abyss Fragment Merging (Safe Failure & Fee/Rate Rebalance)
* **Base Preservation on Failure**: When attempting to merge two Nullpoint Abyss fragments and failing, only the duplicate material fragment is consumed. Your primary base fragment is **100% preserved**, allowing you to continuously build up rare high-stat bases without losing them.
* **90% Fee Reduction on Infinity Fragments**: Merging Infinity fragments now costs $1B cash per attempt instead of the prohibitive $10B fee.
* **Standard Fragment & Module Cost Reductions**:
  * Standard Fragments: reduced from $50M to **$10M** per attempt.
  * Abyss Modules: reduced from $1M to **$100k** per attempt.
* **Rebalanced Merge Success Odds**:
  * Standard Stat Fragments: increased from 10% to **30%**.
  * Special Fragments: increased from 5% to **20%**.
  * Infinity Fragments: progression improved from [10, 5, 2, 1, 1]% to **[35, 25, 20, 15, 10]%**.
* **Context-Aware Notifications**: Modal preview specifies "Secondary copy consumed (Base preserved)" and failure banners accurately report that your base fragment was preserved.

### 13. Full Multi-Language Localization (12 Languages)
All mod-added elements (toggles, notifications, menu options, modal dialogs, and button labels) are fully localized across all 12 game languages:
English (`en`), German (`de`), Spanish (`es`), French (`fr`), Japanese (`ja`), Korean (`ko`), Polish (`pl`), Portuguese (`pt`), Russian (`ru`), Turkish (`tr`), Simplified Chinese (`zh`), and Traditional Chinese (`zhtw`).

---

## Configuration Guide (How to Change Values)

All configurable gameplay numbers and behaviors are defined in the patch files:
* **`patcher.js`** (used when running via Node.js or `patcher.bat` on systems with Node)
* **`patcher.ps1`** (used when running via native PowerShell)

> [!TIP]
> If you edit values in `patcher.js`, make sure to mirror the change in `patcher.ps1` (or vice versa) so your customization persists regardless of which engine runs!

### 1. Endgame Abyss & Crafting Rebalance

Located under the patch named **`"Merge Config & Upgrade Rates"`** (search for `MERGE_CONFIG` in `patcher.js` and `patcher.ps1`):

```javascript
MERGE_CONFIG = {
    // Merge Fees (Cash in dollars)
    fragCost: 1e7,        // Standard Fragment merge fee (1e7 = $10,000,000; vanilla was 5e7 = $50M)
    infCost: 1e9,         // Infinity Fragment merge fee (1e9 = $1,000,000,000; vanilla was 1e10 = $10B)
    modCost: 1e5,         // Mythic Module merge fee (1e5 = $100,000; vanilla was 1e6 = $1M)
    gearCost: 1e9,        // Mythic Weapon upgrade fee per attempt (1e9 = $1B)

    // Success Chances (in %)
    fragStatChance: 30,   // Standard Stat Fragment success rate (default mod: 30%; vanilla was 10%)
    fragSpecialChance: 20,// Special Fragment success rate (default mod: 20%; vanilla was 5%)
    infChance: [35, 25, 20, 15, 10], // Infinity Fragment rates for levels 1 to 5
    modChance: [100, 85, 70, 55, 45, 35, 25, 18, 12, 8], // Module rates +1 to +10

    // Mythic Weapon Upgrade Rates (+1 through +10)
    gearChance: [100, 100, 100, 85, 70, 55, 45, 35, 25, 20],

    // Weapon Destruction Level (Set to 999 to disable destruction completely)
    gearDestroyFrom: 999
};
```

#### Adjusting the Weapon Safety Floor Level
Located under patch **`"Mythic Weapon Upgrades Safety Floor at +5"`**:
```javascript
// Default mod behavior: failure above +5 downgrades by 1, but never drops below +5
r.upgradeLevel = (r.upgradeLevel >= 5) ? Math.max(5, r.upgradeLevel - 1) : Math.max(0, (r.upgradeLevel || 1) - 1);
```
* To change the checkpoint to **+7**: replace both `5`s with `7`.
* To allow dropping below +5 (vanilla downgrade behavior without deletion): change to `r.upgradeLevel = Math.max(0, (r.upgradeLevel || 1) - 1)`.

#### Preserving Fragments on Failure
Located under patch **`"Fragment Merging Safe Failure"`**:
```javascript
// On failure: consumes duplicate e.srcs[1], preserves base e.srcs[0]
s ? this._mutateFragMerge(e.srcs[0], e.srcs[1]) : e.srcs[1].remove();
```

---

### 2. Insanity Background Generation Tuning

Located inside the large script block in patch **`"Double-Click & Quick Stash & Hover & Empty Slot Handler"`**:

| Setting | Variable / Code Location | Default Value | Description |
| :--- | :--- | :--- | :--- |
| **Tick Rate** | `setInterval(..., 250)` (at bottom of script) | `250` ms (4 Hz) | Frequency of background damage processing. |
| **Respawn Delay** | `setTimeout(..., 1400)` inside `die()` | `1400` ms | Delay before respawning after dying in the background. |
| **Reset Layer on Death** | `if (e) e.level = 1;` | `1` | Layer to reset to on defeat. Set to `e.level = e.checkpoint;` if you prefer resetting to the nearest checkpoint instead of Layer 1. |
| **Enemy Attack Rate** | `atkMs = IG_CONST.ATTACK_MS ? ... : 1000` | `1000` ms (1s) | Interval between enemy attacks in the background. |

---

### 3. Tutorial Skip Starting Rewards

Located under patch **`"1b. finalizeCharacter Hook & skipTutorialAndGrantRewards"`**:

* **Starting Level**: `this.data.level = 5;` (Change `5` to desired starter level).
* **Starting Cash**: Granted via mentor tasks execution (default total ~$225,000). You can also add `this.addMoney && this.addMoney(amount);`.
* **Tech Chips**:
  ```javascript
  this.addCurrency("tech_chip_root", 10);
  this.addCurrency("tech_drive_flash", 10);
  this.addCurrency("tech_chip_kernel", 10);
  ```
  Adjust `10` to any quantity you want.
* **Starter Weapons**:
  ```javascript
  const e = ["ar_t3", "smg_t3", "shotgun_t3", "dmr_t3"];
  ```
  You can add or remove weapon base IDs from this array.

---

### 4. Visual Themes, Highlights & Colors

Located inside the embedded CSS block (`<style id="uh-mod-styles">`) in patch **`"Double-Click & Quick Stash & Hover & Empty Slot Handler"`**:

* **Magazine Pulse Highlight**:
  ```css
  .uh-mag-highlight {
      outline: 2px solid #00ff41 !important; /* Change outline color */
      box-shadow: 0 0 12px rgba(0,255,65,0.9) !important; /* Glow color */
  }
  ```
* **Insanity Progress Bar Fill Color**:
  ```css
  .uh-ins-running {
      background: linear-gradient(to right, rgba(160,175,190,0.35) 0%, ...);
  }
  ```
  Replace `rgba(160,175,190,0.35)` with any RGBA or Hex color (e.g. `rgba(0,255,65,0.25)` for a matrix green fill).
* **Quick-Equip Modal Backdrop & Box**:
  Adjust `.uh-modal-backdrop` and `.uh-modal-box` styling (borders, shadow, blur) to match your custom theme.

---

### 5. Editing Translations & Text

All user-facing text strings are centralized in **[`translations.json`](translations.json)**.

To customize any button label, notification, or modal text:
1. Open `translations.json`.
2. Locate the language key (e.g., `"en"` for English, `"de"` for German, `"ja"` for Japanese).
3. Change the string value:
   ```json
   "en": {
       "Buy Ammo": "Buy Ammo",
       "Buy from Trader": "Buy from Trader",
       "EQUIP ITEM": "EQUIP ITEM",
       "No compatible items in stash": "No compatible items in stash",
       "Secondary copy consumed (Base preserved)": "Secondary copy consumed (Base preserved)",
       "Secondary copy consumed. Base preserved!": "Secondary copy consumed. Base preserved!"
   }
   ```
4. Re-run `patcher.bat` -> Select **`[1] Apply Mod Patch`**.

---

## How to Enable & Disable Specific Features

### In-Game Toggles
* **Skip Tutorial**: Check or uncheck **"SKIP TUTORIAL (CLAIM ALL REWARDS)"** on the Character Creation screen.
* **Skip Intro Splash**: In-game, open **Settings** > **Display** > Toggle **"Skip Intro Splash"** ON or OFF.

### Patch-Level Toggles (Code)

Every feature in the mod is implemented as an isolated patch object in `patcher.js` and `patcher.ps1`. You can selectively turn any feature ON or OFF by commenting out its patch in the patch list.

#### Disabling a Patch in `patcher.js`
Wrap the patch object in multi-line comments `/* ... */` inside the `getPatches()` function:
```javascript
function getPatches(minifiedI18nJson) {
    return [
        /* Temporarily disable Safe Fragment Failure:
        {
            "name": "Fragment Merging Safe Failure",
            "target": "...",
            "replacement": "...",
            "expectedCount": 1
        },
        */
        // Other patches continue normally...
    ];
}
```

#### Disabling a Patch in `patcher.ps1`
Comment out the block using `<# ... #>` inside the `$patches = @(...)` array:
```powershell
<#
@{
    Name = "Fragment Merging Safe Failure"
    Search = "..."
    Replace = "..."
    ExpectedCount = 1
},
#>
```

After modifying the file, run `patcher.bat` -> **`[1] Apply Mod Patch`**. The patcher automatically restores the clean backup first, so any commented-out patch will immediately revert back to its vanilla game state!

---

### Patch Name Mapping Reference

Use this table to quickly find the exact patch name to edit or disable for each feature:

| Feature | Patch Name in `patcher.js` / `patcher.ps1` |
| :--- | :--- |
| **Multi-Language Dictionaries** | `0a. Mod I18N Dictionaries Injection`<br>`0b. Mod I18N ready() Dictionary Merge Hook` |
| **Tutorial Skip** | `1a. HTML Toggle in Character Creation Screen`<br>`1b. finalizeCharacter Hook & skipTutorialAndGrantRewards`<br>`1c. showPrompt cancelText`<br>`1d. confirmSkip onConfirm` |
| **Intro Splash Skip** | `2a. GameSettings defaults`<br>`2b. SettingsScreen._renderDisplay`<br>`2c. Splash Screen handler` |
| **Minigame Penalty Removal** | `3a. Filter Category description`<br>`3b. completeIdleMinigame penalty` |
| **Right-Click Context Menu** | `Context Menu Equip/Unequip/Buy Ammo HTML`<br>`Context Menu Item Display (Equip/Unequip/Buy Ammo)`<br>`Context Menu Action Handler (Equip/Unequip/Buy Ammo)` |
| **Quick-Equip / Hover Mags / Background Insanity / Skills Asterisk** | `Double-Click & Quick Stash & Hover & Empty Slot Handler` |
| **Abyss Fees & Success Rates** | `Merge Config & Upgrade Rates` |
| **Mythic Weapon Safe Outcome (No Deletion)** | `Mythic Weapon Upgrades Safe Outcome` |
| **Mythic Weapon +5 Safety Floor** | `Mythic Weapon Upgrades Safety Floor at +5` |
| **Fragment Merging Safe Failure (Base Preserved)** | `Fragment Merging Safe Failure`<br>`Fragment Merging Confirm Modal Label`<br>`Fragment Merging Failure Notification` |

---

## How to Edit the Mod Files & Developer Workflow

### Directory Structure
```text
UNHUMAN/ (or UnhumanCommonSensePatch/)
├── package.nw/                     # Game installation package
│   ├── unhuman.html                # Main game file modified by patcher
│   ├── unhuman.html.bak            # Clean original backup created automatically
│   └── lang/                       # Localization directory
│       ├── de.js, es.js, ...       # Patched language dictionaries
│       └── *.js.bak                # Clean language backups
├── mod/                            # Mod directory (or root repository)
│   ├── patcher.bat                 # One-click launcher (detects Node vs PowerShell)
│   ├── patcher.js                  # Primary patching engine (Node.js)
│   ├── patcher.ps1                 # Fallback patching engine (Native PowerShell)
│   ├── translations.json           # All multi-language translation strings
│   └── README.md                   # This documentation
```

### Dual-Engine Architecture (Node.js vs PowerShell)
* **`patcher.bat`** automatically checks if `node` is available on your system `PATH`.
* If Node.js is present: it runs `patcher.js`.
* If Node.js is not present: it seamlessly falls back to `patcher.ps1` via Windows PowerShell (no dependencies needed).
* **Recommendation**: If making custom modifications, keep `patcher.js` and `patcher.ps1` in sync, or simply edit the one corresponding to the engine you use.

### Step-by-Step Editing Workflow
1. **Open File**: Open `patcher.js` or `patcher.ps1` in VS Code, Notepad++, or your preferred text editor.
2. **Make Edits**: Adjust your desired rates, costs, colors, or comment out patches you do not want.
3. **Save**: Save the file (`Ctrl + S`).
4. **Apply Patch**: Double-click `patcher.bat` and press **`1`** (`Apply Mod Patch`).
   * The patcher automatically restores from the pristine `.bak` backup first, guaranteeing an idempotent, conflict-free patch application.
5. **Verify**: Launch **UNHUMAN** via Steam or executable and verify your adjustments in-game.

### Backups & Safety Guarantees
* **Automatic Creation**: The very first time `Apply Mod Patch` is run, the patcher creates:
  * `package.nw\unhuman.html.bak`
  * `package.nw\lang\*.js.bak`
* **Idempotency**: Every re-patch restores from `.bak` before applying changes. You never get "double-patch" syntax corruption.
* **Instant Revert**: Running `patcher.bat` and choosing **`[2] Restore Original Game`** completely restores vanilla files with zero leftover mod code.

---

## Installation & Usage

1. **Extract or Copy Files**:
   Place the mod files (`patcher.bat`, `patcher.js`, `patcher.ps1`, `translations.json`, `README.md`) into:
   * Your game root directory (where `package.nw` is located), **OR**
   * A `mod` subfolder inside your game directory (e.g., `<SteamFolder>\steamapps\common\UNHUMAN\mod\`).

2. **Run the Patcher**:
   * Double-click **`patcher.bat`** (or open PowerShell and run `powershell -ExecutionPolicy Bypass -File patcher.ps1`).

3. **Select Menu Option**:
   * **`[1] Apply Mod Patch`**: Applies all mod features, balance adjustments, and localization.
   * **`[2] Restore Original Game`**: Restores `unhuman.html` and language files to 100% vanilla.
   * **`[3] Check Mod Status`**: Displays mod application status, backup status, and localization counts.
   * **`[4] Exit`**

---

## Supported Languages

Full localization is included for all 12 game languages:
* **English** (`en`)
* **German / Deutsch** (`de`)
* **Spanish / Español (LATAM)** (`es`)
* **French / Français** (`fr`)
* **Japanese / 日本語** (`ja`)
* **Korean / 한국어** (`ko`)
* **Polish / Polski** (`pl`)
* **Portuguese / Português (BR)** (`pt`)
* **Russian / Русский** (`ru`)
* **Turkish / Türkçe** (`tr`)
* **Simplified Chinese / 简体中文** (`zh`)
* **Traditional Chinese / 繁體中文** (`zhtw`)

Translations use a dual-layer injection system (both dynamic `I18N` runtime merge and static dictionary patching) to ensure 100% compatibility across all game screens and live language switching.
