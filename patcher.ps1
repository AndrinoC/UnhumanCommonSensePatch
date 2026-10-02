# UNHUMAN Mod Patcher (PowerShell Engine)
# Supports multi-language game installations (12 languages)
param(
    [string]$Action = "patch"
)

[Console]::OutputEncoding = [System.Text.Encoding]::UTF8

$Action = $Action.ToLower().TrimStart("-")
$BaseDir = $PSScriptRoot
if (-not $BaseDir) { $BaseDir = (Get-Location).Path }

$GameDir = if (Test-Path (Join-Path $BaseDir "package.nw")) {
    $BaseDir
} elseif (Test-Path (Join-Path $BaseDir "..\package.nw")) {
    (Resolve-Path (Join-Path $BaseDir "..")).Path
} else {
    $BaseDir
}

$NwDir = Join-Path $GameDir "package.nw"
$HtmlPath = Join-Path $NwDir "unhuman.html"
$BackupPath = Join-Path $NwDir "unhuman.html.bak"
$LangDir = Join-Path $NwDir "lang"
$TranslationsPath = Join-Path $BaseDir "translations.json"

$Utf8NoBom = New-Object System.Text.UTF8Encoding($false)
$LangCodes = @("de", "es", "fr", "ja", "ko", "pl", "pt", "ru", "tr", "zh", "zhtw")

function Load-Translations {
    if (-not (Test-Path $TranslationsPath)) {
        Write-Host "[ERROR] translations.json not found at: $TranslationsPath" -ForegroundColor Red
        exit 1
    }
    $raw = [System.IO.File]::ReadAllText($TranslationsPath, [System.Text.Encoding]::UTF8)
    return ($raw | ConvertFrom-Json)
}

function Test-IsModded($content) {
    return ($content.Contains("skipTutorialToggle") -or
            $content.Contains("UI.getClickedItemDetails"))
}

function Show-Status {
    Write-Host "============================================================" -ForegroundColor Cyan
    Write-Host "                    UNHUMAN MOD STATUS                      " -ForegroundColor Cyan
    Write-Host "============================================================" -ForegroundColor Cyan
    Write-Host "Target File  : $HtmlPath"
    if (Test-Path $HtmlPath) {
        $content = [System.IO.File]::ReadAllText($HtmlPath, $Utf8NoBom)
        $modded = Test-IsModded($content)
        $hasBackup = Test-Path $BackupPath
        if ($modded) {
            Write-Host "Mod Applied  : " -NoNewline
            Write-Host "YES (MODDED)" -ForegroundColor Green
        } else {
            Write-Host "Mod Applied  : " -NoNewline
            Write-Host "NO (ORIGINAL/UNMODDED)" -ForegroundColor Yellow
        }
        if ($hasBackup) {
            Write-Host "Backup Exists: " -NoNewline
            Write-Host "YES (package.nw\unhuman.html.bak)" -ForegroundColor Green
        } else {
            Write-Host "Backup Exists: " -NoNewline
            Write-Host "NO" -ForegroundColor Yellow
        }

        # Check language files
        $locCount = 0
        $langBakCount = 0
        if (Test-Path $LangDir) {
            foreach ($code in $LangCodes) {
                $lf = Join-Path $LangDir "$code.js"
                $lb = Join-Path $LangDir "$code.js.bak"
                if (Test-Path $lf) {
                    $c = [System.IO.File]::ReadAllText($lf, $Utf8NoBom)
                    if ($c.Contains("// UNHUMAN MOD LOCALIZATION")) {
                        $locCount++
                    }
                }
                if (Test-Path $lb) {
                    $langBakCount++
                }
            }
        }
        Write-Host "Localization : $locCount / $($LangCodes.Count) language files localized" -ForegroundColor Cyan
        if ($langBakCount -gt 0) {
            Write-Host "Lang Backups : YES ($langBakCount files in package.nw\lang)" -ForegroundColor Green
        } else {
            Write-Host "Lang Backups : NO" -ForegroundColor Yellow
        }
    } else {
        Write-Host "Target File  : NOT FOUND!" -ForegroundColor Red
    }
    Write-Host "============================================================" -ForegroundColor Cyan
}

function Patch-LanguageFiles($translations) {
    if (-not (Test-Path $LangDir)) {
        Write-Host "[WARN] Language directory not found at: $LangDir" -ForegroundColor Yellow
        return
    }

    Write-Host "[I18N] Patching language dictionary files..." -ForegroundColor Cyan
    foreach ($lang in $LangCodes) {
        $langFile = Join-Path $LangDir "$lang.js"
        $langBak = Join-Path $LangDir "$lang.js.bak"
        if (-not (Test-Path $langFile)) { continue }

        if (-not (Test-Path $langBak)) {
            Copy-Item -Path $langFile -Destination $langBak -Force
            $content = [System.IO.File]::ReadAllText($langFile, [System.Text.Encoding]::UTF8)
        } else {
            $content = [System.IO.File]::ReadAllText($langBak, [System.Text.Encoding]::UTF8)
        }

        $marker = "window.I18N_DICTS.$lang = {"
        $idx = $content.IndexOf($marker)
        if ($idx -lt 0) {
            Write-Host "  - [WARN] Could not find dictionary header in lang/$lang.js" -ForegroundColor Yellow
            continue
        }

        $langObj = $translations.$lang
        if (-not $langObj) { continue }

        $entries = @()
        foreach ($prop in $langObj.psobject.properties) {
            $k = $prop.Name.Replace("\", "\\").Replace('"', '\"')
            $v = ([string]$prop.Value).Replace("\", "\\").Replace('"', '\"')
            $entries += "    `"$k`": `"$v`","
        }
        $entriesText = $entries -join "`n"
        $repl = "$marker`n    // UNHUMAN MOD LOCALIZATION`n$entriesText"

        $newContent = $content.Substring(0, $idx) + $repl + $content.Substring($idx + $marker.Length)
        [System.IO.File]::WriteAllText($langFile, $newContent, $Utf8NoBom)
        Write-Host "  + [OK] Localized lang/$lang.js ($($entries.Count) strings)" -ForegroundColor Green
    }
}

function Restore-LanguageFiles {
    if (-not (Test-Path $LangDir)) { return }
    Write-Host "[RESTORE] Restoring language files from backups..." -ForegroundColor Cyan
    foreach ($lang in $LangCodes) {
        $langFile = Join-Path $LangDir "$lang.js"
        $langBak = Join-Path $LangDir "$lang.js.bak"
        if (Test-Path $langBak) {
            Copy-Item -Path $langBak -Destination $langFile -Force
            Write-Host "  + Restored lang/$lang.js" -ForegroundColor Green
        }
    }
}

function Restore-Backup {
    Write-Host "============================================================" -ForegroundColor Cyan
    Write-Host "            UNHUMAN MOD PATCHER: RESTORING BACKUP           " -ForegroundColor Cyan
    Write-Host "============================================================" -ForegroundColor Cyan

    if (-not (Test-Path $BackupPath)) {
        Write-Host "[ERROR] No backup found at: $BackupPath" -ForegroundColor Red
        return
    }

    Copy-Item -Path $BackupPath -Destination $HtmlPath -Force
    Restore-LanguageFiles

    $content = [System.IO.File]::ReadAllText($HtmlPath, $Utf8NoBom)
    if (-not (Test-IsModded($content))) {
        Write-Host "[SUCCESS] Original game files restored successfully!" -ForegroundColor Green
    } else {
        Write-Host "[WARNING] Restored file still appears to have mod markers." -ForegroundColor Yellow
    }
}

function Apply-Patch {
    Write-Host "============================================================" -ForegroundColor Cyan
    Write-Host "              UNHUMAN MOD PATCHER: APPLYING MOD            " -ForegroundColor Cyan
    Write-Host "============================================================" -ForegroundColor Cyan

    if (-not (Test-Path $HtmlPath)) {
        Write-Host "[ERROR] Target file does not exist: $HtmlPath" -ForegroundColor Red
        return
    }

    $translations = Load-Translations
    $minJson = ($translations | ConvertTo-Json -Compress)

    $content = [System.IO.File]::ReadAllText($HtmlPath, $Utf8NoBom)

    if (Test-IsModded($content)) {
        if (Test-Path $BackupPath) {
            Write-Host "[INFO] Previous mod installation detected. Re-applying on fresh backup..." -ForegroundColor Yellow
            $content = [System.IO.File]::ReadAllText($BackupPath, $Utf8NoBom)
        } else {
            Write-Host "[INFO] The mod is ALREADY APPLIED to unhuman.html." -ForegroundColor Green
            Patch-LanguageFiles $translations
            return
        }
    }

    if (-not (Test-Path $BackupPath)) {
        Write-Host "[BACKUP] Creating original backup: package.nw\unhuman.html.bak ..." -ForegroundColor Yellow
        Copy-Item -Path $HtmlPath -Destination $BackupPath -Force
        Write-Host "[BACKUP] Backup created successfully." -ForegroundColor Green
    } else {
        Write-Host "[BACKUP] Using backup at: package.nw\unhuman.html.bak" -ForegroundColor Cyan
    }

    # Define replacement steps
    $Patches = @(
        @{
            Name = '0a. Mod I18N Dictionaries Injection'
            Target = 'window.I18N_DICTS=window.I18N_DICTS||{};const I18N={lang:"en",dict:null,'
            Replacement = "window.I18N_DICTS=window.I18N_DICTS||{};window.UH_MOD_I18N=$minJson;const I18N={lang:`"en`",dict:null,"
            ExpectedCount = 1
        },
        @{
            Name = '0b. Mod I18N ready() Dictionary Merge Hook'
            Target = 'ready(){if(this.dict=I18N_DICTS[this.lang]||null,this.dict){'
            Replacement = 'ready(){if(window.UH_MOD_I18N&&window.I18N_DICTS&&this.lang&&window.UH_MOD_I18N[this.lang]){window.I18N_DICTS[this.lang]=window.I18N_DICTS[this.lang]||{};Object.assign(window.I18N_DICTS[this.lang],window.UH_MOD_I18N[this.lang])}if(this.dict=I18N_DICTS[this.lang]||null,this.dict){if(window.UH_MOD_I18N&&this.lang&&window.UH_MOD_I18N[this.lang]){Object.assign(this.dict,window.UH_MOD_I18N[this.lang])}'
            ExpectedCount = 1
        },
        @{
            Name = '1a. HTML Toggle in Character Creation Screen'
            Target = '<div onclick="Game.selectAvatar(4)" class="avatar-option w-16 h-16 cursor-pointer" data-id="4" style="border:1px solid rgba(0,255,65,0.3);background:rgba(0,5,0,0.6);"><img src="assets/avatars/avatar_4.png" style="width:100%;height:100%;object-fit:cover;image-rendering:pixelated;pointer-events:none;" draggable="false"></div>
                </div>
            </div>
            <button onclick="Game.finalizeCharacter()"'
            Replacement = '<div onclick="Game.selectAvatar(4)" class="avatar-option w-16 h-16 cursor-pointer" data-id="4" style="border:1px solid rgba(0,255,65,0.3);background:rgba(0,5,0,0.6);"><img src="assets/avatars/avatar_4.png" style="width:100%;height:100%;object-fit:cover;image-rendering:pixelated;pointer-events:none;" draggable="false"></div>
                </div>
            </div>
            <div class="mb-6 flex items-center justify-center gap-3">
                <input type="checkbox" id="skipTutorialToggle" class="accent-emerald-500 w-4 h-4 cursor-pointer" checked>
                <label for="skipTutorialToggle" class="text-xs text-green-400 cursor-pointer select-none font-mono text-center" style="letter-spacing: 1px;">
                    SKIP TUTORIAL (CLAIM ALL REWARDS)
                </label>
            </div>
            <button onclick="Game.finalizeCharacter()"'
            ExpectedCount = 1
        },
        @{
            Name = '1b. finalizeCharacter Hook & skipTutorialAndGrantRewards'
            Target = 'void 0!==TutorialManager&&setTimeout(()=>TutorialManager.showPrompt(),500)},healClockDrift()'
            Replacement = 'document.getElementById("skipTutorialToggle")?.checked?this.skipTutorialAndGrantRewards():(void 0!==TutorialManager&&setTimeout(()=>TutorialManager.showPrompt(),500))},skipTutorialAndGrantRewards(){this.data.tutorial={active:!1,stepIndex:0,completed:!0,raidCount:0};try{localStorage.setItem("unhuman_tutorial_ever_completed","true")}catch(e){}if(void 0!==TutorialManager){TutorialManager.active=!1;TutorialManager._removeGlobalBlocker&&TutorialManager._removeGlobalBlocker();TutorialManager.hideSpotlight&&TutorialManager.hideSpotlight()}this.data.mentor={enabled:!1,offerVet:!1,idx:void 0!==MENTOR_TASKS?MENTOR_TASKS.length:18,done:{},skipped:{},snap:null};if(void 0!==MentorSystem){MentorSystem.disable&&MentorSystem.disable();MentorSystem._hide&&MentorSystem._hide()}if(void 0!==MENTOR_TASKS&&Array.isArray(MENTOR_TASKS)){MENTOR_TASKS.forEach(e=>{try{e.onStart&&e.onStart()}catch(e){}try{e.grant&&e.grant()}catch(e){}this.data.mentor&&this.data.mentor.done&&(this.data.mentor.done[e.id]=!0)})}try{this.data.traderQuests||(this.data.traderQuests={});this.data.traderQuests.gs_welcome={status:"completed",progress:{}};"function"==typeof addStandingXP&&addStandingXP("gunsmith",25);if(void 0!==ItemFactory){const e=["ar_t3","smg_t3","shotgun_t3","dmr_t3"],t=e[Math.floor(Math.random()*e.length)],a=ItemFactory.create(t,"standard",1);a&&(a._tutorialWeapon=!0,this.addToStash(a)||this.recoverToGunsmith(a))}}catch(e){}if((this.data.level||1)<5){const e=5-(this.data.level||1);this.data.level=5,this.data.xp=0;this.data.skillTree||(this.data.skillTree={allocatedNodes:[],availablePoints:0,totalPointsSpent:0});this.data.skillTree.availablePoints=(this.data.skillTree.availablePoints||0)+e}try{this.addCurrency&&this.addCurrency("tech_chip_root",10);this.addCurrency&&this.addCurrency("tech_drive_flash",10);this.addCurrency&&this.addCurrency("tech_chip_kernel",10)}catch(e){}this.saveData();void 0!==GlobalNotif&&GlobalNotif.showCentered("function"==typeof T?T("TUTORIAL SKIPPED"):"TUTORIAL SKIPPED","function"==typeof T?T("All tutorial & mentor rewards granted! Welcome, Operator."):"All tutorial & mentor rewards granted! Welcome, Operator.")},healClockDrift()'
            ExpectedCount = 1
        },
        @{
            Name = '1c. showPrompt cancelText'
            Target = 'cancelText:e?"SKIP TUTORIAL":null,noBackdropClose:!0,onConfirm:()=>TutorialManager.start(),onCancel:e?()=>TutorialManager.skip():null'
            Replacement = 'cancelText:"SKIP TUTORIAL",noBackdropClose:!0,onConfirm:()=>TutorialManager.start(),onCancel:()=>(Game.skipTutorialAndGrantRewards?Game.skipTutorialAndGrantRewards():TutorialManager.skip())'
            ExpectedCount = 1
        },
        @{
            Name = '1d. confirmSkip onConfirm'
            Target = 'onConfirm:()=>this.skip()'
            Replacement = 'onConfirm:()=>{this.skip();Game.skipTutorialAndGrantRewards&&Game.skipTutorialAndGrantRewards()}'
            ExpectedCount = 1
        },
        @{
            Name = '2a. GameSettings defaults'
            Target = 'mergeConfirm:!0,skipUpgradeAnim:!1,autoAcceptQuests:!1,'
            Replacement = 'mergeConfirm:!0,skipUpgradeAnim:!1,autoAcceptQuests:!1,skipIntroSplash:!0,'
            ExpectedCount = 2
        },
        @{
            Name = '2b. SettingsScreen._renderDisplay'
            Target = '${this._toggle("CRT Effects","crtEffects",GameSettings.crtEffects)}'
            Replacement = '${this._toggle("Skip Intro Splash","skipIntroSplash",!1!==GameSettings.skipIntroSplash)}\n                        ${this._toggle("CRT Effects","crtEffects",GameSettings.crtEffects)}'
            ExpectedCount = 1
        },
        @{
            Name = '2c. Splash Screen handler'
            Target = 'const s=document.getElementById("splashScreen");s&&(sessionStorage.getItem("UH_SplashDone")?s.remove():(sessionStorage.setItem("UH_SplashDone","1"),setTimeout(()=>{s.classList.add("fade-out"),setTimeout(()=>s.remove(),600)},1e4)))'
            Replacement = '(()=>{const s=document.getElementById("splashScreen");if(s){const k=()=>s.remove();s.addEventListener("click",k);window.addEventListener("keydown",k,{once:!0});GameSettings.skipIntroSplash!==!1||sessionStorage.getItem("UH_SplashDone")?s.remove():(sessionStorage.setItem("UH_SplashDone","1"),setTimeout(()=>{s.classList.add("fade-out"),setTimeout(()=>s.remove(),600)},1e4))}})()'
            ExpectedCount = 1
        },
        @{
            Name = '3a. Filter Category description'
            Target = '{id:"minigameIdleMode",label:"Minigame Idle Mode",desc:"Auto-complete lockpick/hacking (10s wait, -15% loot)",type:"checkbox"}'
            Replacement = '{id:"minigameIdleMode",label:"Minigame Idle Mode",desc:"Auto-complete lockpick/hacking (10s wait, no penalty)",type:"checkbox"}'
            ExpectedCount = 1
            Optional = $true
        },
        @{
            Name = '3b. completeIdleMinigame penalty'
            Target = 'this.startLootingWithBonus(e,{rarity:-.15,quantity:-.15})'
            Replacement = 'this.startLootingWithBonus(e,{rarity:.1,quantity:.1})'
            ExpectedCount = 1
            Optional = $true
        },
        @{
            Name = 'Context Menu Equip/Unequip/Buy Ammo HTML'
            Target = '<div id="itemContextMenu">
        <div class="context-menu-item" data-action="inspect">Inspect</div>'
            Replacement = '<div id="itemContextMenu">
        <div class="context-menu-item" data-action="equip">Equip</div>
        <div class="context-menu-item" data-action="unequip">Unequip</div>
        <div class="context-menu-item" data-action="buyAmmo">Buy Ammo</div>
        <div class="context-menu-item" data-action="inspect">Inspect</div>'
            ExpectedCount = 1
        },
        @{
            Name = 'Context Menu Item Display (Equip/Unequip)'
            Target = 'const t=document.querySelector(''#itemContextMenu [data-action="ensure"]'')'
            Replacement = 'const eq=document.querySelector(''#itemContextMenu [data-action="equip"]''),uneq=document.querySelector(''#itemContextMenu [data-action="unequip"]'');if(eq)eq.style.display=("stash"===this.contextMenuSource||"container"===this.contextMenuSource)?"block":"none";if(uneq)uneq.style.display=("equipment"===this.contextMenuSource||"augment"===this.contextMenuSource)?"block":"none";const t=document.querySelector(''#itemContextMenu [data-action="ensure"]'')'
            ExpectedCount = 1
        },
        @{
            Name = 'Context Menu Action Handler (Equip/Unequip/Buy Ammo)'
            Target = 'case"inspect":HintSystem.show("inspect_item")'
            Replacement = 'case"equip":case"unequip":UI.quickStashAction(this.contextMenuTarget,this.contextMenuSlot,this.contextMenuSource,null);break;case"buyAmmo":UI.buyAmmoAction(this.contextMenuTarget);break;case"inspect":HintSystem.show("inspect_item")'
            ExpectedCount = 1
        },
        @{
            Name = 'Double-Click & Quick Stash & Hover & Empty Slot Handler'
            Target = 'document.addEventListener("click",e=>{if(!e.shiftKey||Game.state.inRaid)return;if(void 0!==TutorialManager&&TutorialManager.active)return;let t=null,a=null,s=null,i=null;const n=e.target.closest(".tlo-slot-container .item-card");if(n){const e=n.closest("[data-slot]");if(e){const n=e.dataset.slot,o=Game.data.equipment[n];o&&(t="string"==typeof o?Items[o]:o,a=n,s="equipment",i=e)}}if(!t){const n=e.target.closest(".augment-slot.filled");if(n){const e=n.dataset.slot,o=Game.data.augments?.[e];o&&(t="string"==typeof o?Items[o]:o,a=e,s="augment",i=n)}}if(!t){const n=e.target.closest("#stashGrid .eft-merged-grid-slot, #stashGrid .stash-slot-item, #stashGrid .stash-grid-slot");if(n){const e=n.closest("[data-slot-index]")||n,o=UI.getItemFromGridSlot(e,Game.data.stash);o&&(t=o.item,a=o.slot,s="stash",i=e)}}if(!t){const n=e.target.closest("#loadoutRigGrid .stash-slot-item, #loadoutBackpackGrid .stash-slot-item, #loadoutPocketsGrid .stash-slot-item, #loadoutPouchGrid .stash-slot-item,#loadoutRigGrid .covered-drop-overlay, #loadoutBackpackGrid .covered-drop-overlay, #loadoutPouchGrid .covered-drop-overlay");if(n){const e=n.classList.contains("covered-drop-overlay")?n:n.closest(".eft-merged-grid-slot, .eft-discrete-slot");if(e){const n=e.closest("[id]"),o=e.dataset.containerType||("loadoutRigGrid"===n?.id?"rig":"loadoutBackpackGrid"===n?.id?"backpack":"loadoutPouchGrid"===n?.id?"pouch":"loadoutPocketsGrid"===n?.id?"pockets":null),r=void 0!==e.dataset.anchorSlot?parseInt(e.dataset.anchorSlot):parseInt(e.dataset.slotIndex);if(o&&!isNaN(r)){const n=Game.getActiveInventory(),l="rig"===o?"rigContents":"backpack"===o?"backpackContents":o;if(n?.[l]?.[r]){const c=n[l][r];t="string"==typeof c?Items[c]:c,a=r,s="container",i=e,i._containerType=o,i._contentsKey=l}}}}}if(!t||!s)return;e.preventDefault(),UI.hideItemTooltip();const o=e=>{MenuSFX.error(),e&&(e.classList.remove("shift-click-blocked"),e.offsetWidth,e.classList.add("shift-click-blocked"),e.addEventListener("animationend",()=>e.classList.remove("shift-click-blocked"),{once:!0}))};if("equipment"===s){const e=["rig","backpack","pouch"].includes(a)?Game._containerTxBegin(a):null;if(e&&!Game.evacuateContainerContents(a))return Game._containerTxRollback(e),void o(i);if(!Game.addToStash(t))return Game._containerTxRollback(e),GlobalNotif.show("STASH FULL","Free stash space first"),void o(i);Game.setEquipment(a,null),GameSFX.equip?.(),Game._saveDirty=!0,UI.renderStats(),UI.renderLoadout(),UI.renderStash()}else if("augment"===s){const e=t.slots?.[0]||a;Game.data.augmentLocker||(Game.data.augmentLocker={eye:[],brain:[],torso:[],skin:[],arms:[],legs:[],skeleton:[],internal:[],shoulder:[]}),Game.data.augmentLocker[e]||(Game.data.augmentLocker[e]=[]),Game.data.augmentLocker[e].push(t),Game.data.augments[a]=null,Game.invalidateStats(),Game.clampBodyHealthToMax(),void 0!==AugmentTriggers&&AugmentTriggers.invalidateAugmentCache(),GameSFX.equip?.(),Game._saveDirty=!0,UI.renderStats(),UI.renderLoadout()}else if("stash"===s){const e=t.type;if(["weapon","armor","accessory","container"].includes(e)){let s=[];if(Array.isArray(t.slots)&&t.slots.length)s=t.slots;else if("weapon"===e){const e=t.weaponClass||t.subtype||"ranged";s="melee"===e?["melee"]:"pistol"===e?["secondary","primary"]:["primary"]}else"armor"===e||"accessory"===e?s=["head","body","earpiece","facecover","eyewear"]:"container"===e&&(s="secure"===t.subtype?["pouch"]:["rig","backpack"]);let n=!1;for(const e of s)if(!Game.data.equipment[e]&&Game.canEquipToSlot(t,e)){Game.setEquipment(e,t),Game.removeFromStash(a),GameSFX.equip?.(),Game._saveDirty=!0,n=!0;break}if(!n)for(const e of s){const s=Game.data.equipment[e];if(!s||!Game.canEquipToSlot(t,e))continue;if(["rig","backpack","pouch"].includes(e)){const t=Game._containerTxBegin(e);if(!Game.evacuateContainerContents(e)){Game._containerTxRollback(t);continue}}const i="string"==typeof s?Items[s]:s;if(i){if(Game.removeFromStash(a),!Game.addToStash(i)){Game.addToStash(t);break}Game.setEquipment(e,t),GameSFX.equip?.(),Game._saveDirty=!0,n=!0;break}}if(!n)return void o(i)}else{if("augment"===e){const e=Game.data.prestige||0;let s=!1;for(const{slot:i,minPrestige:n}of AUGMENT_SLOT_DEFS)if(!(e<n)&&!Game.data.augments?.[i]&&Game.canEquipAugmentToSlot(t,i)){Game.data.augments[i]=t,Game.removeFromStash(a),Game.invalidateStats(),Game.clampBodyHealthToMax(),AugmentTriggers.invalidateAugmentCache(),GameSFX.equip?.(),Game._saveDirty=!0,HintSystem.show("augment_equip"),addQuestProgress("equip_augment",{slot:i,amount:1}),s=!0;break}return s?("augments"!==UI.activeLoadoutSubTab?UI.switchLoadoutSubTab("augments"):UI.renderLoadout(),void UI.renderStash()):void o(i)}{const e=Game.getActiveInventory(),s=getEffectiveSize(t),n=[{type:"rig",key:"rigContents"},{type:"backpack",key:"backpackContents"},{type:"pockets",key:"pockets"},{type:"pouch",key:"pouch"}];let r=!1;for(const i of n){if("pockets"!==i.type&&!Game.data.equipment[i.type])continue;const n=getContainerGridConfig(i.type);e[i.key]||(e[i.key]="pockets"===i.type?[null,null,null,null]:[]);const o="pockets"===i.type?s.width>1||s.height>1?-1:e.pockets.indexOf(null):findEmptySlotInContainer(s.width,s.height,e[i.key],n.cols,n.rows);if(o>=0){e[i.key][o]=t,Game.removeFromStash(a),Game.invalidateStats(),GameSFX.equip?.(),Game._saveDirty=!0,r=!0;break}}if(!r)return void o(i)}}UI.renderStats(),UI.renderLoadout(),UI.renderStash()}else if("container"===s){if(!Game.addToStash(t))return void o(i);const e=Game.getActiveInventory(),s=i._contentsKey;"pockets"===s?e[s][a]=null:delete e[s][a],Game.invalidateStats(),GameSFX.equip?.(),Game._saveDirty=!0,UI.renderStats(),UI.renderLoadout(),UI.renderStash()}})'
            Replacement = 'UI.getClickedItemDetails=function(e){let t=null,a=null,s=null,i=null;const n=e.target.closest(".tlo-slot-container .item-card");if(n){const e=n.closest("[data-slot]");if(e){const n=e.dataset.slot,o=Game.data.equipment[n];o&&(t="string"==typeof o?Items[o]:o,a=n,s="equipment",i=e)}}if(!t){const n=e.target.closest(".augment-slot.filled");if(n){const e=n.dataset.slot,o=Game.data.augments?.[e];o&&(t="string"==typeof o?Items[o]:o,a=e,s="augment",i=n)}}if(!t){const n=e.target.closest("#stashGrid .eft-merged-grid-slot, #stashGrid .stash-slot-item, #stashGrid .stash-grid-slot");if(n){const e=n.closest("[data-slot-index]")||n,o=UI.getItemFromGridSlot(e,Game.data.stash);o&&(t=o.item,a=o.slot,s="stash",i=e)}}if(!t){const n=e.target.closest("#loadoutRigGrid .stash-slot-item, #loadoutBackpackGrid .stash-slot-item, #loadoutPocketsGrid .stash-slot-item, #loadoutPouchGrid .stash-slot-item,#loadoutRigGrid .covered-drop-overlay, #loadoutBackpackGrid .covered-drop-overlay, #loadoutPouchGrid .covered-drop-overlay");if(n){const e=n.classList.contains("covered-drop-overlay")?n:n.closest(".eft-merged-grid-slot, .eft-discrete-slot");if(e){const n=e.closest("[id]"),o=e.dataset.containerType||("loadoutRigGrid"===n?.id?"rig":"loadoutBackpackGrid"===n?.id?"backpack":"loadoutPouchGrid"===n?.id?"pouch":"loadoutPocketsGrid"===n?.id?"pockets":null),r=void 0!==e.dataset.anchorSlot?parseInt(e.dataset.anchorSlot):parseInt(e.dataset.slotIndex);if(o&&!isNaN(r)){const n=Game.getActiveInventory(),l="rig"===o?"rigContents":"backpack"===o?"backpackContents":o;if(n?.[l]?.[r]){const c=n[l][r];t="string"==typeof c?Items[c]:c,a=r,s="container",i=e,i._containerType=o,i._contentsKey=l}}}}}return{item:t,slot:a,source:s,el:i}};UI.quickStashAction=function(t,a,s,i){if(!t||!s)return;UI.hideItemTooltip();const o=e=>{MenuSFX.error(),e&&(e.classList.remove("shift-click-blocked"),e.offsetWidth,e.classList.add("shift-click-blocked"),e.addEventListener("animationend",()=>e.classList.remove("shift-click-blocked"),{once:!0}))};if("equipment"===s){const e=["rig","backpack","pouch"].includes(a)?Game._containerTxBegin(a):null;if(e&&!Game.evacuateContainerContents(a))return Game._containerTxRollback(e),void o(i);if(!Game.addToStash(t))return Game._containerTxRollback(e),GlobalNotif.show("STASH FULL","Free stash space first"),void o(i);Game.setEquipment(a,null),GameSFX.equip?.(),Game._saveDirty=!0,UI.renderStats(),UI.renderLoadout(),UI.renderStash()}else if("augment"===s){const e=t.slots?.[0]||a;Game.data.augmentLocker||(Game.data.augmentLocker={eye:[],brain:[],torso:[],skin:[],arms:[],legs:[],skeleton:[],internal:[],shoulder:[]}),Game.data.augmentLocker[e]||(Game.data.augmentLocker[e]=[]),Game.data.augmentLocker[e].push(t),Game.data.augments[a]=null,Game.invalidateStats(),Game.clampBodyHealthToMax(),void 0!==AugmentTriggers&&AugmentTriggers.invalidateAugmentCache(),GameSFX.equip?.(),Game._saveDirty=!0,UI.renderStats(),UI.renderLoadout()}else if("stash"===s){const e=t.type;if(["weapon","armor","accessory","container"].includes(e)){let s=[];if(Array.isArray(t.slots)&&t.slots.length)s=t.slots;else if("weapon"===e){const e=t.weaponClass||t.subtype||"ranged";s="melee"===e?["melee"]:"pistol"===e?["secondary","primary"]:["primary"]}else"armor"===e||"accessory"===e?s=["head","body","earpiece","facecover","eyewear"]:"container"===e&&(s="secure"===t.subtype?["pouch"]:["rig","backpack"]);let n=!1;for(const e of s)if(!Game.data.equipment[e]&&Game.canEquipToSlot(t,e)){Game.setEquipment(e,t),Game.removeFromStash(a),GameSFX.equip?.(),Game._saveDirty=!0,n=!0;break}if(!n)for(const e of s){const s=Game.data.equipment[e];if(!s||!Game.canEquipToSlot(t,e))continue;if(["rig","backpack","pouch"].includes(e)){const t=Game._containerTxBegin(e);if(!Game.evacuateContainerContents(e)){Game._containerTxRollback(t);continue}}const i="string"==typeof s?Items[s]:s;if(i){if(Game.removeFromStash(a),!Game.addToStash(i)){Game.addToStash(t);break}Game.setEquipment(e,t),GameSFX.equip?.(),Game._saveDirty=!0,n=!0;break}}if(!n)return void o(i)}else{if("augment"===e){const e=Game.data.prestige||0;let s=!1;for(const{slot:i,minPrestige:n}of AUGMENT_SLOT_DEFS)if(!(e<n)&&!Game.data.augments?.[i]&&Game.canEquipAugmentToSlot(t,i)){Game.data.augments[i]=t,Game.removeFromStash(a),Game.invalidateStats(),Game.clampBodyHealthToMax(),AugmentTriggers.invalidateAugmentCache(),GameSFX.equip?.(),Game._saveDirty=!0,HintSystem.show("augment_equip"),addQuestProgress("equip_augment",{slot:i,amount:1}),s=!0;break}return s?("augments"!==UI.activeLoadoutSubTab?UI.switchLoadoutSubTab("augments"):UI.renderLoadout(),void UI.renderStash()):void o(i)}{const e=Game.getActiveInventory(),s=getEffectiveSize(t),n=[{type:"rig",key:"rigContents"},{type:"backpack",key:"backpackContents"},{type:"pockets",key:"pockets"},{type:"pouch",key:"pouch"}];let r=!1;for(const i of n){if("pockets"!==i.type&&!Game.data.equipment[i.type])continue;const n=getContainerGridConfig(i.type);e[i.key]||(e[i.key]="pockets"===i.type?[null,null,null,null]:[]);const o="pockets"===i.type?s.width>1||s.height>1?-1:e.pockets.indexOf(null):findEmptySlotInContainer(s.width,s.height,e[i.key],n.cols,n.rows);if(o>=0){e[i.key][o]=t,Game.removeFromStash(a),Game.invalidateStats(),GameSFX.equip?.(),Game._saveDirty=!0,r=!0;break}}if(!r)return void o(i)}}UI.renderStats(),UI.renderLoadout(),UI.renderStash()}else if("container"===s){if(!Game.addToStash(t))return void o(i);const e=Game.getActiveInventory(),s=i._contentsKey;"pockets"===s?e[s][a]=null:delete e[s][a],Game.invalidateStats(),GameSFX.equip?.(),Game._saveDirty=!0,UI.renderStats(),UI.renderLoadout(),UI.renderStash()}};UI.getCompatibleMagId=function(w){if(!w)return null;const item="string"==typeof w?(void 0!==window.Items&&Items[w])||(void 0!==window.ItemBases&&ItemBases[w]):w;if(!item||"weapon"!==item.type)return null;const sub=(item.subtype||item.weaponClass||"").toLowerCase();return["pistol","dmr","shotgun","smg","ar","bolt"].includes(sub)?"mag_"+sub:null};UI.isMagCompatible=function(m,w){if(!m||!w)return!1;const mag="string"==typeof m?(void 0!==window.Items&&Items[m])||(void 0!==window.ItemBases&&ItemBases[m]):m;const wep="string"==typeof w?(void 0!==window.Items&&Items[w])||(void 0!==window.ItemBases&&ItemBases[w]):w;if(!mag||!wep||"weapon"!==wep.type)return!1;const isMag="magazine"===mag.type||String(mag.baseId||"").startsWith("mag_")||"proto_magazine"===mag.baseId;if(!isMag)return!1;if("proto_magazine"===mag.baseId||"universal"===mag.subtype)return!0;const targetMagId=UI.getCompatibleMagId(wep);return!!(targetMagId&&(mag.baseId===targetMagId||mag.subtype===(wep.subtype||wep.weaponClass)))};UI.clearMagHighlights=function(){document.querySelectorAll(".uh-mag-highlight").forEach(e=>e.classList.remove("uh-mag-highlight"))};UI.highlightCompatibleMags=function(w){UI.clearMagHighlights();if(!w||"weapon"!==w.type||"melee"===w.subtype||"melee"===w.weaponClass)return;if(Game.data&&Game.data.stash){for(const s in Game.data.stash){const item=Game.data.stash[s];if(UI.isMagCompatible(item,w)){const el=document.querySelector(`#stashGrid [data-slot-index="${s}"]`);if(el){const target=el.querySelector(".stash-slot-item")||el;target.classList.add("uh-mag-highlight")}}}}const inv="function"==typeof Game.getActiveInventory?Game.getActiveInventory():null;if(inv){const containers=[{id:"loadoutRigGrid",items:inv.rigContents},{id:"loadoutBackpackGrid",items:inv.backpackContents},{id:"loadoutPocketsGrid",items:inv.pockets},{id:"loadoutPouchGrid",items:inv.pouch}];containers.forEach(c=>{if(!c.items)return;const grid=document.getElementById(c.id);if(!grid)return;for(const s in c.items){const item=c.items[s];if(UI.isMagCompatible(item,w)){const el=grid.querySelector(`[data-slot-index="${s}"]`);if(el){const target=el.querySelector(".stash-slot-item")||el;target.classList.add("uh-mag-highlight")}}}})}};UI.buyAmmoAction=function(w){const magId=UI.getCompatibleMagId(w);if(magId&&"function"==typeof openTraderShop){UI.hideContextMenu();openTraderShop("gunsmith");setTimeout(()=>{const el=document.querySelector(`.fixed-stock-slot[data-fixed-base-id="${magId}"]`);if(el){el.click();el.scrollIntoView({behavior:"smooth",block:"center"});el.classList.add("uh-mag-focus-pulse");setTimeout(()=>el.classList.remove("uh-mag-focus-pulse"),3500)}},150)}};UI.getTraderForSlot=function(slot){if(["primary","secondary","melee"].includes(slot))return"gunsmith";if(["head","body","rig","backpack","pouch","earpiece","facecover","eyewear","companion","companion_toy","companion_food"].includes(slot))return"weaver";if(["relic"].includes(slot))return"signal_broker";if(["eye","brain","torso","skin","arms","legs","skeleton","internal","shoulder"].includes(slot))return"ripperdoc";return"gunsmith"};UI.closeQuickEquipModal=function(){const m=document.getElementById("uhQuickEquipModal");m&&m.remove()};UI.quickBuyForSlot=function(slot){const tId=UI.getTraderForSlot(slot);UI.closeQuickEquipModal();if("function"==typeof openTraderShop)openTraderShop(tId)};UI.quickEquipFromModal=function(slot,stashIdx,isAugment){const raw=Game.data?.stash?.[stashIdx];if(!raw)return;const item="string"==typeof raw?(Items[raw]||ItemBases[raw]):raw;if(!item)return;UI.closeQuickEquipModal();if(isAugment){Game.data.augmentLocker=Game.data.augmentLocker||{};Game.data.augments=Game.data.augments||{};Game.data.augments[slot]=item;Game.removeFromStash(stashIdx);Game.invalidateStats();Game.clampBodyHealthToMax();void 0!==AugmentTriggers&&AugmentTriggers.invalidateAugmentCache&&AugmentTriggers.invalidateAugmentCache();GameSFX.equip?.();Game._saveDirty=!0}else{Game.setEquipment(slot,item);Game.removeFromStash(stashIdx);GameSFX.equip?.();Game._saveDirty=!0}UI.renderStats();UI.renderLoadout();UI.renderStash()};UI.openQuickEquipModal=function(slot,isAugment){UI.closeQuickEquipModal();const rawSlotName=void 0!==EQUIP_SLOT_LABELS&&EQUIP_SLOT_LABELS[slot]?EQUIP_SLOT_LABELS[slot]:slot.toUpperCase();const slotLabel="function"==typeof T?T(rawSlotName):rawSlotName;const traderId=UI.getTraderForSlot(slot);const rawTraderName=void 0!==TraderConfig&&TraderConfig[traderId]&&TraderConfig[traderId].name?TraderConfig[traderId].name:traderId.toUpperCase();const traderName="function"==typeof T?T(rawTraderName):rawTraderName;const buyText="function"==typeof T?T("Buy from Trader"):("Buy from Trader");const equipText="function"==typeof T?T("EQUIP ITEM"):("EQUIP ITEM");const emptyText="function"==typeof T?T("No compatible items in stash"):("No compatible items in stash");const equippable=[];if(Game.data&&Game.data.stash){for(const s in Game.data.stash){const raw=Game.data.stash[s];if(!raw)continue;const item="string"==typeof raw?(Items[raw]||ItemBases[raw]):raw;if(!item)continue;const valid=isAugment?(Game.canEquipAugmentToSlot?Game.canEquipAugmentToSlot(item,slot):!1):(Game.canEquipToSlot?Game.canEquipToSlot(item,slot):!1);if(valid)equippable.push({item,slotIndex:s})}}const modal=document.createElement("div");modal.id="uhQuickEquipModal";modal.className="uh-modal-backdrop";modal.onclick=e=>{if(e.target===modal)UI.closeQuickEquipModal()};let itemsHtml="";if(0===equippable.length){itemsHtml=`<div class="uh-modal-empty"><div style="font-size:22px;margin-bottom:8px;opacity:0.4;">[ &#8709; ]</div><div>${emptyText}</div></div>`}else{itemsHtml=equippable.map(e=>{const it=e.item;const img="function"==typeof getItemImage?getItemImage(it):(it.image||"");const emoji="function"==typeof getItemEmoji?getItemEmoji(it):"&#128230;";const rarity=void 0!==RarityConfig&&RarityConfig[it.tier||"standard"]?RarityConfig[it.tier||"standard"]:{hex:"#9ca3af"};const st=it.stats||(void 0!==window.ItemBases&&ItemBases[it.baseId])||(void 0!==window.Items&&Items[it.baseId])||it;const base=(void 0!==window.ItemBases&&ItemBases[it.baseId])||(void 0!==window.Items&&Items[it.baseId])||{};let detail="";if("weapon"===it.type){const dmg=st.damage??base.damage??it.damage??0;const rpm=st.rpm??base.rpm??it.rpm??0;const mag=st.magCapacity??base.magCapacity??it.magCapacity??0;detail=`${dmg} DMG &middot; ${rpm} RPM &middot; ${mag} RND`}else if("armor"===it.type){const arm=st.armor??base.armor??it.armor??0;const hp=st.health??base.health??it.health??0;const eva=st.evasion??base.evasion??it.evasion??0;const p=[];if(arm>0)p.push(`${arm} ARM`);if(hp>0)p.push(`+${hp} HP`);if(eva>0)p.push(`+${eva}% EVA`);detail=p.length>0?p.join(" &middot; "):((it.description||"").substring(0,40))}else if("container"===it.type){const slt=st.slots??it.capacity??base.capacity??((it.width||1)*(it.height||1));detail=`${slt} SLOTS`}else if("accessory"===it.type){const awr=st.awareness??base.awareness??it.awareness??0;const comms=st.comms??base.comms??it.comms??0;const stl=st.stealth??base.stealth??it.stealth??0;const p=[];if(awr>0)p.push(`+${awr} AWR`);if(comms>0)p.push(`+${comms} COM`);if(stl>0)p.push(`+${stl}% STL`);detail=p.length>0?p.join(" &middot; "):((it.description||"").substring(0,40))}else{detail=(it.description||"").substring(0,40)}return`<div class="uh-modal-item" onclick="UI.quickEquipFromModal(''${slot}'',''${e.slotIndex}'',${!!isAugment})"><img src="${img}" class="uh-modal-item-img" onerror="this.style.display=''none'';this.nextElementSibling.style.display=''flex'';"><div class="item-icon-fallback" style="display:none;width:40px;height:40px;align-items:center;justify-content:center;font-size:20px;">${emoji}</div><div class="uh-modal-item-info"><div class="uh-modal-item-name" style="color:${rarity.hex}">${it.name||it.baseId}</div><div class="uh-modal-item-desc">${detail}</div></div><div class="uh-modal-item-action">${equipText}</div></div>`}).join("")}modal.innerHTML=`<div class="uh-modal-box"><div class="uh-modal-header"><div class="uh-modal-title">[ ${equipText} // ${slotLabel} ]</div><button class="uh-modal-close" onclick="UI.closeQuickEquipModal()">&times;</button></div><div class="uh-modal-actions"><button class="uh-modal-buy-btn" onclick="UI.quickBuyForSlot(''${slot}'')">${buyText} (${traderName})</button></div><div class="uh-modal-body">${itemsHtml}</div></div>`;document.body.appendChild(modal)};if(!document.getElementById("uh-mod-styles")){const st=document.createElement("style");st.id="uh-mod-styles";st.textContent=`.uh-mag-highlight{outline:2px solid #00ff41 !important;outline-offset:-1px !important;box-shadow:0 0 12px rgba(0,255,65,0.9),inset 0 0 8px rgba(0,255,65,0.4) !important;animation:uhMagPulse 1.2s infinite alternate ease-in-out !important;z-index:40 !important;}@keyframes uhMagPulse{0%{outline-color:#00ff41;box-shadow:0 0 6px rgba(0,255,65,0.6),inset 0 0 4px rgba(0,255,65,0.2);}100%{outline-color:#39ff14;box-shadow:0 0 16px rgba(57,255,20,1),inset 0 0 12px rgba(57,255,20,0.5);}}.uh-mag-focus-pulse{outline:2px solid #00ff41 !important;box-shadow:0 0 20px #00ff41,inset 0 0 10px rgba(0,255,65,0.5) !important;animation:uhFocusPulse 0.8s infinite alternate ease-in-out !important;}@keyframes uhFocusPulse{0%{transform:scale(1);box-shadow:0 0 10px #00ff41;}100%{transform:scale(1.06);box-shadow:0 0 24px #39ff14,inset 0 0 14px rgba(57,255,20,0.8);}}.uh-modal-backdrop{position:fixed;inset:0;z-index:9999;background:rgba(0,5,0,0.8);backdrop-filter:blur(4px);display:flex;align-items:center;justify-content:center;font-family:monospace;}.uh-modal-box{background:#020a04;border:1px solid #00ff41;box-shadow:0 0 25px rgba(0,255,65,0.35),inset 0 0 20px rgba(0,255,65,0.05);width:min(92vw,560px);max-height:82vh;display:flex;flex-direction:column;overflow:hidden;position:relative;}.uh-modal-header{display:flex;justify-content:space-between;align-items:center;padding:calc(12px * var(--ui-scale,1)) calc(16px * var(--ui-scale,1));border-bottom:1px solid rgba(0,255,65,0.25);background:rgba(0,255,65,0.05);}.uh-modal-title{color:#00ff41;font-size:calc(13px * var(--font-scale,1));font-weight:bold;letter-spacing:1.5px;text-shadow:0 0 8px rgba(0,255,65,0.5);}.uh-modal-close{background:transparent;border:1px solid rgba(0,255,65,0.3);color:#00ff41;cursor:pointer;padding:2px 8px;font-size:calc(12px * var(--font-scale,1));transition:all 0.15s ease;}.uh-modal-close:hover{background:#00ff41;color:#000;}.uh-modal-actions{padding:calc(10px * var(--ui-scale,1)) calc(16px * var(--ui-scale,1));display:flex;gap:8px;border-bottom:1px solid rgba(0,255,65,0.15);background:rgba(0,15,0,0.4);}.uh-modal-buy-btn{flex:1;background:rgba(0,255,65,0.12);border:1px solid #00ff41;color:#00ff41;padding:calc(8px * var(--ui-scale,1)) calc(12px * var(--ui-scale,1));font-size:calc(11px * var(--font-scale,1));font-weight:bold;cursor:pointer;letter-spacing:1px;transition:all 0.15s ease;text-shadow:0 0 6px rgba(0,255,65,0.4);display:flex;align-items:center;justify-content:center;gap:6px;}.uh-modal-buy-btn:hover{background:#00ff41;color:#000;box-shadow:0 0 12px rgba(0,255,65,0.8);}.uh-modal-body{padding:calc(14px * var(--ui-scale,1));overflow-y:auto;flex:1;display:flex;flex-direction:column;gap:8px;}.uh-modal-empty{text-align:center;padding:36px 16px;color:rgba(0,255,65,0.5);font-size:calc(12px * var(--font-scale,1));letter-spacing:1px;}.uh-modal-item{display:flex;align-items:center;gap:calc(12px * var(--ui-scale,1));background:rgba(0,20,0,0.4);border:1px solid rgba(0,255,65,0.2);padding:calc(8px * var(--ui-scale,1)) calc(12px * var(--ui-scale,1));cursor:pointer;transition:all 0.15s ease;position:relative;}.uh-modal-item:hover{background:rgba(0,255,65,0.12);border-color:#00ff41;box-shadow:0 0 10px rgba(0,255,65,0.3);transform:translateX(2px);}.uh-modal-item-img{width:calc(44px * var(--ui-scale,1));height:calc(44px * var(--ui-scale,1));object-fit:contain;flex-shrink:0;}.uh-modal-item-info{flex:1;min-width:0;}.uh-modal-item-name{font-size:calc(12px * var(--font-scale,1));font-weight:bold;white-space:nowrap;overflow:hidden;text-overflow:ellipsis;}.uh-modal-item-desc{font-size:calc(10px * var(--font-scale,1));opacity:0.7;margin-top:2px;}.uh-modal-item-action{font-size:calc(11px * var(--font-scale,1));color:#00ff41;border:1px solid rgba(0,255,65,0.4);padding:4px 8px;white-space:nowrap;font-weight:bold;}.uh-modal-item:hover .uh-modal-item-action{background:#00ff41;color:#000;}.uh-ins-running{background:linear-gradient(to right, rgba(160,175,190,0.35) 0%, rgba(160,175,190,0.35) var(--uh-ins-fill, 0%), rgba(0,0,0,0.12) var(--uh-ins-fill, 0%), rgba(0,0,0,0.12) 100%) !important;transition:background 0.1s linear;}.topbar-tab.uh-ins-running.active{background:rgba(0,255,65,0.10) !important;}.uh-ins-running{background:linear-gradient(to right, rgba(160,175,190,0.35) 0%, rgba(160,175,190,0.35) var(--uh-ins-fill, 0%), rgba(0,0,0,0.12) var(--uh-ins-fill, 0%), rgba(0,0,0,0.12) 100%) !important;transition:background 0.1s linear;}.topbar-tab.uh-ins-running.active{background:rgba(0,255,65,0.10) !important;}`;document.head.appendChild(st)}window.addEventListener("keydown",e=>{if("Escape"===e.key)UI.closeQuickEquipModal()});if("function"==typeof UI.hideItemTooltip&&!UI._uhTooltipHooked){const origHide=UI.hideItemTooltip;UI.hideItemTooltip=function(){UI.clearMagHighlights();uhLastHoveredWeapon=null;return origHide.apply(this,arguments)};UI._uhTooltipHooked=!0}let uhLastHoveredWeapon=null;document.addEventListener("mouseover",e=>{if(Game.state?.inRaid)return;if(e.target.closest("#itemTooltip, #itemTooltipProtoMag, #uhQuickEquipModal"))return;const res=UI.getClickedItemDetails?UI.getClickedItemDetails(e):null;const item=res?res.item:null;const isWep=item&&"weapon"===item.type&&"melee"!==item.subtype&&"melee"!==item.weaponClass;const weapon=isWep?item:null;if(weapon===uhLastHoveredWeapon)return;uhLastHoveredWeapon=weapon;if(weapon){UI.highlightCompatibleMags(weapon)}else{UI.clearMagHighlights()}},{passive:!0});document.addEventListener("mouseleave",()=>{if(uhLastHoveredWeapon){uhLastHoveredWeapon=null;UI.clearMagHighlights()}},{passive:!0});document.addEventListener("click",e=>{if(!e.shiftKey||Game.state.inRaid)return;if(void 0!==TutorialManager&&TutorialManager.active)return;const res=UI.getClickedItemDetails(e);if(!res.item||!res.source)return;e.preventDefault();UI.quickStashAction(res.item,res.slot,res.source,res.el)});document.addEventListener("dblclick",e=>{if(Game.state.inRaid)return;if(void 0!==TutorialManager&&TutorialManager.active)return;const res=UI.getClickedItemDetails(e);if(!res.item||!res.source)return;e.preventDefault();UI.quickStashAction(res.item,res.slot,res.source,res.el)});document.addEventListener("click",e=>{if(Game.state?.inRaid)return;if(e.shiftKey)return;if(void 0!==TutorialManager&&TutorialManager.active)return;const slotEl=e.target.closest(".tlo-slot-container[data-slot], .augment-slot[data-slot]");if(!slotEl)return;const slot=slotEl.dataset.slot;if(!slot)return;const isAugment=slotEl.classList.contains("augment-slot");if(isAugment&&slotEl.classList.contains("locked-slot"))return;const equipped=isAugment?Game.data?.augments?.[slot]:Game.data?.equipment?.[slot];if(equipped||slotEl.classList.contains("filled")||slotEl.querySelector(".item-card"))return;e.preventDefault();e.stopPropagation();UI.openQuickEquipModal(slot,isAugment)});UI.updateSkillsIndicator = function() { try { const hasPts = (Game.data && Game.data.skillTree && Game.data.skillTree.availablePoints > 0); const candidates = document.querySelectorAll(''.topbar-tab[data-target="skills"], .terminal-menu-item[data-target="skills"], .nav-dock-btn, button[data-target="skills"], button[onclick*="skills"]''); candidates.forEach(btn => { if (btn.closest && (btn.closest("#view-skills") || btn.closest("#skillTreeContainer"))) return; const oc = btn.getAttribute("onclick") || ""; const leads = btn.dataset.target === "skills" || oc.includes("''skills''") || oc.includes(''"skills"'') || oc.includes("selectOption(3)"); if (!leads) return; if (!btn._uhBaseText) { btn._uhBaseText = btn.textContent.replace(/\s*\*\s*/g, "").trim(); } const curClean = btn.textContent.replace(/\s*\*\s*/g, "").trim(); if (curClean && curClean !== btn._uhBaseText && !btn.textContent.includes("*")) { btn._uhBaseText = curClean; } const base = btn._uhBaseText || "SKILLS"; if (hasPts) { if (base.startsWith("[") && base.endsWith("]")) { const inner = base.substring(1, base.length - 1).trim(); btn.textContent = "[ " + inner + " * ]"; } else { btn.textContent = base + " *"; } } else { btn.textContent = base; } }); } catch (e) {} }; if (typeof UI !== "undefined" && typeof UI.switchTab === "function" && !UI._uhSwitchTabHooked) { const origSwitch = UI.switchTab; UI.switchTab = function() { const r = origSwitch.apply(this, arguments); try { UI.updateSkillsIndicator && UI.updateSkillsIndicator(); if (typeof InsanityGame !== "undefined" && InsanityGame.updateNavIndicator) { InsanityGame.updateNavIndicator(); } } catch (e) {} return r; }; UI._uhSwitchTabHooked = true; } if (typeof UI !== "undefined" && typeof UI.renderSkillTree === "function" && !UI._uhRenderSkillTreeHooked) { const origRenderSkillTree = UI.renderSkillTree; UI.renderSkillTree = function() { const r = origRenderSkillTree.apply(this, arguments); try { UI.updateSkillsIndicator && UI.updateSkillsIndicator(); } catch (e) {} return r; }; UI._uhRenderSkillTreeHooked = true; } if (typeof NavDock !== "undefined" && typeof NavDock.refresh === "function" && !NavDock._uhRefreshHooked) { const origNavRefresh = NavDock.refresh; NavDock.refresh = function() { const r = origNavRefresh.apply(this, arguments); try { UI.updateSkillsIndicator && UI.updateSkillsIndicator(); if (typeof InsanityGame !== "undefined" && InsanityGame.updateNavIndicator) { InsanityGame.updateNavIndicator(); } } catch (e) {} return r; }; NavDock._uhRefreshHooked = true; } if (typeof InsanityGame !== "undefined") { InsanityGame.updateNavIndicator = function() { try { const btns = document.querySelectorAll(''.topbar-tab[data-target="insanity"], .terminal-menu-item[data-target="insanity"], .nav-dock-btn[data-target="insanity"], .nav-dock-btn[onclick*="insanity"]''); if (!btns || !btns.length) return; let totRate = 0; const maxAuto = (typeof IG_CONST !== "undefined" && IG_CONST.AUTO_MAX) ? IG_CONST.AUTO_MAX : 5; for (let e = 1; e <= maxAuto; e++) { if (typeof this.autoRate === "function") { totRate += this.autoRate(e); } } if (totRate <= 0) { btns.forEach(b => { b.classList.remove("uh-ins-running"); b.style.removeProperty("--uh-ins-fill"); b.removeAttribute("title"); }); return; } const g = (typeof this.g === "function") ? this.g() : (Game.data && Game.data.insanityGame); const lvl = (g && g.level) ? g.level : 1; const step = (lvl - 1) % 10; let eProg = 0; if (this.enemy && this.enemy.maxHpL !== undefined && this.enemy.hpL !== undefined) { if (this.enemy.hpL < 0) { eProg = 1; } else { const r = Math.pow(10, this.enemy.hpL - this.enemy.maxHpL); eProg = Math.max(0, Math.min(1, 1 - r)); } } const pct = Math.min(100, Math.max(0, ((step + eProg) / 10) * 100)).toFixed(1); btns.forEach(b => { b.classList.add("uh-ins-running"); b.style.setProperty("--uh-ins-fill", pct + "%"); b.title = "Insanity: Layer " + lvl + " (" + pct + "%)"; }); } catch (e) {} }; InsanityGame._bgHitAcc = 0; InsanityGame._bgEnemyAcc = 0; InsanityGame._runBackgroundTick = function(dMs) { try { if (this.active) { this.updateNavIndicator(); return; } let totRate = 0; const maxAuto = (typeof IG_CONST !== "undefined" && IG_CONST.AUTO_MAX) ? IG_CONST.AUTO_MAX : 5; for (let e = 1; e <= maxAuto; e++) { if (typeof this.autoRate === "function") { totRate += this.autoRate(e); } } if (totRate <= 0) { this.updateNavIndicator(); return; } if (!this.base || !this.pstats) { const a = Game.getStats ? Game.getStats() : {}; this.base = { dmg: Math.max(1, a.damage || a.dmg || 1), hp: Math.max(1, a.hp || 100), ac: a.ac || 0, eva: Math.min((typeof IG_CONST !== "undefined" && IG_CONST.EVA_CAP) ? IG_CONST.EVA_CAP : 40, a.eva || 0), critCh: Math.min(20, (a.handling || 0) / 5), critMult: Math.max(1.2, a.headshotMult || 1.5) }; if (typeof this._recalcStats === "function") { this._recalcStats(); } if (this.pstats) { this.playerHpL = this.pstats.maxHpL; } } if (!this.enemy && typeof this.spawnEnemy === "function") { this.spawnEnemy(); } if (this.dead || !this.enemy) { this.updateNavIndicator(); return; } this._isBgTick = true; const dSec = dMs / 1000; this._bgHitAcc = (this._bgHitAcc || 0) + totRate * dSec; const hits = Math.min(25, Math.floor(this._bgHitAcc)); this._bgHitAcc -= hits; for (let i = 0; i < hits; i++) { if (this.dead || !this.enemy) break; const isCrit = (100 * Math.random()) < (this.pstats ? this.pstats.critCh : 5); let dmg = (typeof this.clickDamage === "function") ? this.clickDamage() : 1; if (isCrit && this.pstats && this.pstats.critMultL) { dmg += this.pstats.critMultL; } if (typeof this._lSub === "function") { this.enemy.hpL = this._lSub(this.enemy.hpL, dmg); } else { this.enemy.hpL -= 0.1; } if (this.enemy.hpL < 0) { if (typeof this.kill === "function") this.kill(); } } this._bgEnemyAcc = (this._bgEnemyAcc || 0) + dMs; const atkMs = (typeof IG_CONST !== "undefined" && IG_CONST.ATTACK_MS) ? IG_CONST.ATTACK_MS : 1000; if (this._bgEnemyAcc >= atkMs) { this._bgEnemyAcc -= atkMs; if (!this.dead && this.enemy && this.pstats) { if (this.pstats.regen > 0 && this.playerHpL < this.pstats.maxHpL && typeof this._lAdd === "function") { this.playerHpL = Math.min(this.pstats.maxHpL, this._lAdd(this.playerHpL, this.pstats.maxHpL + Math.log10(this.pstats.regen / 100))); } const dodged = (100 * Math.random()) < this.pstats.eva; if (!dodged && typeof this._lSub === "function") { const edmg = Math.max(0, this._lSub(this.enemy.dmgL + Math.log10(1 - (this.pstats.dr || 0)), Math.log10(this.pstats.ac || 0))); this.playerHpL = this._lSub(this.playerHpL, edmg); if (this.playerHpL < 0 && typeof this.die === "function") { this.die(); } } } } this._isBgTick = false; this.updateNavIndicator(); } catch (e) { this._isBgTick = false; } }; if (!InsanityGame._uhHooked) { const origSpawn = InsanityGame.spawnEnemy; InsanityGame.spawnEnemy = function() { if (!this.active) { try { const e = (typeof this.g === "function") ? this.g() : (Game.data && Game.data.insanityGame); if (!e) return; if (e.skipBoss && e.level % 10 == 0 && e.level !== e.checkpoint) { e.level = (e.checkpoint <= e.level && e.checkpoint > e.level - 10) ? e.checkpoint : Math.max(1, e.level - 9); this._dirty = true; } const t = e.level, a = t % 10 == 0; const goldCh = (typeof IG_CONST !== "undefined" && IG_CONST.GOLD_CHANCE) ? IG_CONST.GOLD_CHANCE : 0.03; const s = !a && Math.random() < (goldCh + ((typeof this._mfx === "function" && this._mfx().igGold) ? this._mfx().igGold : 0)) * ((typeof this._boostActive === "function" && this._boostActive("b_gold")) ? 4 : 1); const tiers = this._tiers || ["#00ff41"]; const i = tiers[Math.floor((t - 1) / 10) % tiers.length]; const hpBase = (typeof IG_CONST !== "undefined" && IG_CONST.HP_BASE) ? IG_CONST.HP_BASE : 100; const hpGrowth = (typeof IG_CONST !== "undefined" && IG_CONST.HP_GROWTH) ? IG_CONST.HP_GROWTH : 1.15; const bossHpMult = (typeof IG_CONST !== "undefined" && IG_CONST.BOSS_HP_MULT) ? IG_CONST.BOSS_HP_MULT : 5; const edmgBase = (typeof IG_CONST !== "undefined" && IG_CONST.EDMG_BASE) ? IG_CONST.EDMG_BASE : 10; const edmgGrowth = (typeof IG_CONST !== "undefined" && IG_CONST.EDMG_GROWTH) ? IG_CONST.EDMG_GROWTH : 1.12; const bossDmgMult = (typeof IG_CONST !== "undefined" && IG_CONST.BOSS_DMG_MULT) ? IG_CONST.BOSS_DMG_MULT : 3; this.enemy = { maxHpL: Math.log10(hpBase) + (t - 1) * Math.log10(hpGrowth) + (a ? Math.log10(bossHpMult) : 0), dmgL: Math.log10(edmgBase) + (t - 1) * Math.log10(edmgGrowth) + (a ? Math.log10(bossDmgMult) : 0), isBoss: a, isGold: s, color: s ? "#ffd700" : i }; this.enemy.hpL = this.enemy.maxHpL; } catch (err) {} return; } return origSpawn.apply(this, arguments); }; const origKill = InsanityGame.kill; InsanityGame.kill = function() { if (!this.active) { try { const e = (typeof this.g === "function") ? this.g() : (Game.data && Game.data.insanityGame); const t = Game.data && Game.data.signalCorruption; if (!e || !t) return; const a = e.level > (e.claimed || 0); let r = (typeof this.insReward === "function") ? this.insReward() : 1; if (this.enemy && this.enemy.isGold) { r *= (typeof IG_CONST !== "undefined" && IG_CONST.GOLD_INS_MULT) ? IG_CONST.GOLD_INS_MULT : 5; } const pIns = (typeof this._permaMult === "function") ? this._permaMult("p_ins") : 1; const mIns = 1 + ((typeof this._mfx === "function" && this._mfx().igIns) ? this._mfx().igIns : 0); const bIns = (typeof this._boostActive === "function" && this._boostActive("b_ins")) ? 2 : 1; if (a) { r = Math.max(1, Math.round(r * pIns * mIns * bIns)); t.insanity = (t.insanity || 0) + r; e.claimed = e.level; if (typeof this._earnAdd === "function") this._earnAdd(r, e.level); } else { const recPct = (typeof IG_CONST !== "undefined" && IG_CONST.RECLAIM_PCT) ? IG_CONST.RECLAIM_PCT : 0.2; r = Math.round(r * recPct * pIns * mIns * bIns); if (r > 0) { t.insanity = (t.insanity || 0) + r; if (typeof this._earnAdd === "function") this._earnAdd(r, e.level); } } e.kills = (e.kills || 0) + 1; if (this.enemy && this.enemy.isBoss) { e.bossKills = (e.bossKills || 0) + 1; e.checkpoint = Math.max(e.checkpoint || 1, e.level + 1); const cacheBase = (typeof IG_CONST !== "undefined" && IG_CONST.BOSS_CACHE_CHANCE) ? IG_CONST.BOSS_CACHE_CHANCE : 0.05; const cacheMfx = (typeof this._mfx === "function" && this._mfx().igCache) ? this._mfx().igCache : 0; const cacheCh = cacheBase + cacheMfx; if (Math.random() < cacheCh * Math.pow(1.01, e.upg ? (e.upg.bosschance || 0) : 0) && typeof IG_CACHES !== "undefined") { const keys = Object.keys(IG_CACHES); const wFn = k => IG_CACHES[k].dropW * (e.level >= IG_CACHES[k].dropLvl ? 1 : 0.05); const totW = keys.reduce((acc, k) => acc + wFn(k), 0); let rnd = Math.random() * totW; let picked = keys[0]; for (const k of keys) { rnd -= wFn(k); if (rnd <= 0) { picked = k; break; } } e.caches = e.caches || {}; e.caches[picked] = (e.caches[picked] || 0) + 1; } } e.level = (e.level || 1) + 1; if (e.level > (e.best || 0)) e.best = e.level; if (e.level > (e.runBest || 0)) e.runBest = e.level; if (this.pstats) this.playerHpL = this.pstats.maxHpL; if (typeof this.spawnEnemy === "function") this.spawnEnemy(); Game._saveDirty = true; this._dirty = true; } catch (err) {} return; } return origKill.apply(this, arguments); }; const origDie = InsanityGame.die; InsanityGame.die = function() { if (!this.active) { try { this.dead = true; this.combo = 1; const e = (typeof this.g === "function") ? this.g() : (Game.data && Game.data.insanityGame); if (e) e.level = e.checkpoint; if (Game.saveData) Game.saveData(); this._dirty = false; setTimeout(() => { this.dead = false; if (this.pstats) this.playerHpL = this.pstats.maxHpL; if (typeof this.spawnEnemy === "function") this.spawnEnemy(); }, 1400); } catch (err) {} return; } return origDie.apply(this, arguments); }; if (typeof SFXEngine !== "undefined") { const origSweep = SFXEngine.playSweep; SFXEngine.playSweep = function() { if (InsanityGame._isBgTick || (!InsanityGame.active && arguments[4] === 0)) return; return origSweep.apply(this, arguments); }; const origNote = SFXEngine.playNote; SFXEngine.playNote = function() { if (InsanityGame._isBgTick || (!InsanityGame.active && arguments[4] === 0)) return; return origNote.apply(this, arguments); }; const origChord = SFXEngine.playChord; SFXEngine.playChord = function() { if (InsanityGame._isBgTick || (!InsanityGame.active && arguments[4] === 0)) return; return origChord.apply(this, arguments); }; } InsanityGame._uhHooked = true; } if (!window._uhBgTicker) { window._uhBgTicker = setInterval(() => { try { UI.updateSkillsIndicator(); InsanityGame._runBackgroundTick(250); } catch (e) {} }, 250); } }UI.updateSkillsIndicator = function() { try { const hasPts = (Game.data && Game.data.skillTree && Game.data.skillTree.availablePoints > 0); const candidates = document.querySelectorAll(''.topbar-tab[data-target="skills"], .terminal-menu-item[data-target="skills"], .nav-dock-btn, button[data-target="skills"], button[onclick*="skills"]''); candidates.forEach(btn => { if (btn.closest && (btn.closest("#view-skills") || btn.closest("#skillTreeContainer"))) return; const oc = btn.getAttribute("onclick") || ""; const leads = btn.dataset.target === "skills" || oc.includes("''skills''") || oc.includes(''"skills"'') || oc.includes("selectOption(3)"); if (!leads) return; if (!btn._uhBaseText) { btn._uhBaseText = btn.textContent.replace(/\s*\*\s*/g, "").trim(); } const curClean = btn.textContent.replace(/\s*\*\s*/g, "").trim(); if (curClean && curClean !== btn._uhBaseText && !btn.textContent.includes("*")) { btn._uhBaseText = curClean; } const base = btn._uhBaseText || "SKILLS"; if (hasPts) { if (base.startsWith("[") && base.endsWith("]")) { const inner = base.substring(1, base.length - 1).trim(); btn.textContent = "[ " + inner + " * ]"; } else { btn.textContent = base + " *"; } } else { btn.textContent = base; } }); } catch (e) {} }; if (typeof UI !== "undefined" && typeof UI.switchTab === "function" && !UI._uhSwitchTabHooked) { const origSwitch = UI.switchTab; UI.switchTab = function() { const r = origSwitch.apply(this, arguments); try { UI.updateSkillsIndicator && UI.updateSkillsIndicator(); if (typeof InsanityGame !== "undefined" && InsanityGame.updateNavIndicator) { InsanityGame.updateNavIndicator(); } } catch (e) {} return r; }; UI._uhSwitchTabHooked = true; } if (typeof UI !== "undefined" && typeof UI.renderSkillTree === "function" && !UI._uhRenderSkillTreeHooked) { const origRenderSkillTree = UI.renderSkillTree; UI.renderSkillTree = function() { const r = origRenderSkillTree.apply(this, arguments); try { UI.updateSkillsIndicator && UI.updateSkillsIndicator(); } catch (e) {} return r; }; UI._uhRenderSkillTreeHooked = true; } if (typeof NavDock !== "undefined" && typeof NavDock.refresh === "function" && !NavDock._uhRefreshHooked) { const origNavRefresh = NavDock.refresh; NavDock.refresh = function() { const r = origNavRefresh.apply(this, arguments); try { UI.updateSkillsIndicator && UI.updateSkillsIndicator(); if (typeof InsanityGame !== "undefined" && InsanityGame.updateNavIndicator) { InsanityGame.updateNavIndicator(); } } catch (e) {} return r; }; NavDock._uhRefreshHooked = true; } if (typeof InsanityGame !== "undefined") { InsanityGame.updateNavIndicator = function() { try { const btns = document.querySelectorAll(''.topbar-tab[data-target="insanity"], .terminal-menu-item[data-target="insanity"], .nav-dock-btn[data-target="insanity"], .nav-dock-btn[onclick*="insanity"]''); if (!btns || !btns.length) return; let totRate = 0; const maxAuto = (typeof IG_CONST !== "undefined" && IG_CONST.AUTO_MAX) ? IG_CONST.AUTO_MAX : 5; for (let e = 1; e <= maxAuto; e++) { if (typeof this.autoRate === "function") { totRate += this.autoRate(e); } } if (totRate <= 0) { btns.forEach(b => { b.classList.remove("uh-ins-running"); b.style.removeProperty("--uh-ins-fill"); b.removeAttribute("title"); }); return; } const g = (typeof this.g === "function") ? this.g() : (Game.data && Game.data.insanityGame); const lvl = (g && g.level) ? g.level : 1; const step = (lvl - 1) % 10; let eProg = 0; if (this.enemy && this.enemy.maxHpL !== undefined && this.enemy.hpL !== undefined) { if (this.enemy.hpL < 0) { eProg = 1; } else { const r = Math.pow(10, this.enemy.hpL - this.enemy.maxHpL); eProg = Math.max(0, Math.min(1, 1 - r)); } } const pct = Math.min(100, Math.max(0, ((step + eProg) / 10) * 100)).toFixed(1); btns.forEach(b => { b.classList.add("uh-ins-running"); b.style.setProperty("--uh-ins-fill", pct + "%"); b.title = "Insanity: Layer " + lvl + " (" + pct + "%)"; }); } catch (e) {} }; InsanityGame._bgHitAcc = 0; InsanityGame._bgEnemyAcc = 0; InsanityGame._runBackgroundTick = function(dMs) { try { if (this.active) { this.updateNavIndicator(); return; } let totRate = 0; const maxAuto = (typeof IG_CONST !== "undefined" && IG_CONST.AUTO_MAX) ? IG_CONST.AUTO_MAX : 5; for (let e = 1; e <= maxAuto; e++) { if (typeof this.autoRate === "function") { totRate += this.autoRate(e); } } if (totRate <= 0) { this.updateNavIndicator(); return; } if (!this.base || !this.pstats) { const a = Game.getStats ? Game.getStats() : {}; this.base = { dmg: Math.max(1, a.damage || a.dmg || 1), hp: Math.max(1, a.hp || 100), ac: a.ac || 0, eva: Math.min((typeof IG_CONST !== "undefined" && IG_CONST.EVA_CAP) ? IG_CONST.EVA_CAP : 40, a.eva || 0), critCh: Math.min(20, (a.handling || 0) / 5), critMult: Math.max(1.2, a.headshotMult || 1.5) }; if (typeof this._recalcStats === "function") { this._recalcStats(); } if (this.pstats) { this.playerHpL = this.pstats.maxHpL; } } if (!this.enemy && typeof this.spawnEnemy === "function") { this.spawnEnemy(); } if (this.dead || !this.enemy) { this.updateNavIndicator(); return; } this._isBgTick = true; const dSec = dMs / 1000; this._bgHitAcc = (this._bgHitAcc || 0) + totRate * dSec; const hits = Math.min(25, Math.floor(this._bgHitAcc)); this._bgHitAcc -= hits; for (let i = 0; i < hits; i++) { if (this.dead || !this.enemy) break; const isCrit = (100 * Math.random()) < (this.pstats ? this.pstats.critCh : 5); let dmg = (typeof this.clickDamage === "function") ? this.clickDamage() : 1; if (isCrit && this.pstats && this.pstats.critMultL) { dmg += this.pstats.critMultL; } if (typeof this._lSub === "function") { this.enemy.hpL = this._lSub(this.enemy.hpL, dmg); } else { this.enemy.hpL -= 0.1; } if (this.enemy.hpL < 0) { if (typeof this.kill === "function") this.kill(); } } this._bgEnemyAcc = (this._bgEnemyAcc || 0) + dMs; const atkMs = (typeof IG_CONST !== "undefined" && IG_CONST.ATTACK_MS) ? IG_CONST.ATTACK_MS : 1000; if (this._bgEnemyAcc >= atkMs) { this._bgEnemyAcc -= atkMs; if (!this.dead && this.enemy && this.pstats) { if (this.pstats.regen > 0 && this.playerHpL < this.pstats.maxHpL && typeof this._lAdd === "function") { this.playerHpL = Math.min(this.pstats.maxHpL, this._lAdd(this.playerHpL, this.pstats.maxHpL + Math.log10(this.pstats.regen / 100))); } const dodged = (100 * Math.random()) < this.pstats.eva; if (!dodged && typeof this._lSub === "function") { const edmg = Math.max(0, this._lSub(this.enemy.dmgL + Math.log10(1 - (this.pstats.dr || 0)), Math.log10(this.pstats.ac || 0))); this.playerHpL = this._lSub(this.playerHpL, edmg); if (this.playerHpL < 0 && typeof this.die === "function") { this.die(); } } } } this._isBgTick = false; this.updateNavIndicator(); } catch (e) { this._isBgTick = false; } }; if (!InsanityGame._uhHooked) { const origSpawn = InsanityGame.spawnEnemy; InsanityGame.spawnEnemy = function() { if (!this.active) { try { const e = (typeof this.g === "function") ? this.g() : (Game.data && Game.data.insanityGame); if (!e) return; if (e.skipBoss && e.level % 10 == 0 && e.level !== e.checkpoint) { e.level = (e.checkpoint <= e.level && e.checkpoint > e.level - 10) ? e.checkpoint : Math.max(1, e.level - 9); this._dirty = true; } const t = e.level, a = t % 10 == 0; const goldCh = (typeof IG_CONST !== "undefined" && IG_CONST.GOLD_CHANCE) ? IG_CONST.GOLD_CHANCE : 0.03; const s = !a && Math.random() < (goldCh + ((typeof this._mfx === "function" && this._mfx().igGold) ? this._mfx().igGold : 0)) * ((typeof this._boostActive === "function" && this._boostActive("b_gold")) ? 4 : 1); const tiers = this._tiers || ["#00ff41"]; const i = tiers[Math.floor((t - 1) / 10) % tiers.length]; const hpBase = (typeof IG_CONST !== "undefined" && IG_CONST.HP_BASE) ? IG_CONST.HP_BASE : 100; const hpGrowth = (typeof IG_CONST !== "undefined" && IG_CONST.HP_GROWTH) ? IG_CONST.HP_GROWTH : 1.15; const bossHpMult = (typeof IG_CONST !== "undefined" && IG_CONST.BOSS_HP_MULT) ? IG_CONST.BOSS_HP_MULT : 5; const edmgBase = (typeof IG_CONST !== "undefined" && IG_CONST.EDMG_BASE) ? IG_CONST.EDMG_BASE : 10; const edmgGrowth = (typeof IG_CONST !== "undefined" && IG_CONST.EDMG_GROWTH) ? IG_CONST.EDMG_GROWTH : 1.12; const bossDmgMult = (typeof IG_CONST !== "undefined" && IG_CONST.BOSS_DMG_MULT) ? IG_CONST.BOSS_DMG_MULT : 3; this.enemy = { maxHpL: Math.log10(hpBase) + (t - 1) * Math.log10(hpGrowth) + (a ? Math.log10(bossHpMult) : 0), dmgL: Math.log10(edmgBase) + (t - 1) * Math.log10(edmgGrowth) + (a ? Math.log10(bossDmgMult) : 0), isBoss: a, isGold: s, color: s ? "#ffd700" : i }; this.enemy.hpL = this.enemy.maxHpL; } catch (err) {} return; } return origSpawn.apply(this, arguments); }; const origKill = InsanityGame.kill; InsanityGame.kill = function() { if (!this.active) { try { const e = (typeof this.g === "function") ? this.g() : (Game.data && Game.data.insanityGame); const t = Game.data && Game.data.signalCorruption; if (!e || !t) return; const a = e.level > (e.claimed || 0); let r = (typeof this.insReward === "function") ? this.insReward() : 1; if (this.enemy && this.enemy.isGold) { r *= (typeof IG_CONST !== "undefined" && IG_CONST.GOLD_INS_MULT) ? IG_CONST.GOLD_INS_MULT : 5; } const pIns = (typeof this._permaMult === "function") ? this._permaMult("p_ins") : 1; const mIns = 1 + ((typeof this._mfx === "function" && this._mfx().igIns) ? this._mfx().igIns : 0); const bIns = (typeof this._boostActive === "function" && this._boostActive("b_ins")) ? 2 : 1; if (a) { r = Math.max(1, Math.round(r * pIns * mIns * bIns)); t.insanity = (t.insanity || 0) + r; e.claimed = e.level; if (typeof this._earnAdd === "function") this._earnAdd(r, e.level); } else { const recPct = (typeof IG_CONST !== "undefined" && IG_CONST.RECLAIM_PCT) ? IG_CONST.RECLAIM_PCT : 0.2; r = Math.round(r * recPct * pIns * mIns * bIns); if (r > 0) { t.insanity = (t.insanity || 0) + r; if (typeof this._earnAdd === "function") this._earnAdd(r, e.level); } } e.kills = (e.kills || 0) + 1; if (this.enemy && this.enemy.isBoss) { e.bossKills = (e.bossKills || 0) + 1; e.checkpoint = Math.max(e.checkpoint || 1, e.level + 1); const cacheBase = (typeof IG_CONST !== "undefined" && IG_CONST.BOSS_CACHE_CHANCE) ? IG_CONST.BOSS_CACHE_CHANCE : 0.05; const cacheMfx = (typeof this._mfx === "function" && this._mfx().igCache) ? this._mfx().igCache : 0; const cacheCh = cacheBase + cacheMfx; if (Math.random() < cacheCh * Math.pow(1.01, e.upg ? (e.upg.bosschance || 0) : 0) && typeof IG_CACHES !== "undefined") { const keys = Object.keys(IG_CACHES); const wFn = k => IG_CACHES[k].dropW * (e.level >= IG_CACHES[k].dropLvl ? 1 : 0.05); const totW = keys.reduce((acc, k) => acc + wFn(k), 0); let rnd = Math.random() * totW; let picked = keys[0]; for (const k of keys) { rnd -= wFn(k); if (rnd <= 0) { picked = k; break; } } e.caches = e.caches || {}; e.caches[picked] = (e.caches[picked] || 0) + 1; } } e.level = (e.level || 1) + 1; if (e.level > (e.best || 0)) e.best = e.level; if (e.level > (e.runBest || 0)) e.runBest = e.level; if (this.pstats) this.playerHpL = this.pstats.maxHpL; if (typeof this.spawnEnemy === "function") this.spawnEnemy(); Game._saveDirty = true; this._dirty = true; } catch (err) {} return; } return origKill.apply(this, arguments); }; const origDie = InsanityGame.die; InsanityGame.die = function() { if (!this.active) { try { this.dead = true; this.combo = 1; const e = (typeof this.g === "function") ? this.g() : (Game.data && Game.data.insanityGame); if (e) e.level = e.checkpoint; if (Game.saveData) Game.saveData(); this._dirty = false; setTimeout(() => { this.dead = false; if (this.pstats) this.playerHpL = this.pstats.maxHpL; if (typeof this.spawnEnemy === "function") this.spawnEnemy(); }, 1400); } catch (err) {} return; } return origDie.apply(this, arguments); }; if (typeof SFXEngine !== "undefined") { const origSweep = SFXEngine.playSweep; SFXEngine.playSweep = function() { if (InsanityGame._isBgTick || (!InsanityGame.active && arguments[4] === 0)) return; return origSweep.apply(this, arguments); }; const origNote = SFXEngine.playNote; SFXEngine.playNote = function() { if (InsanityGame._isBgTick || (!InsanityGame.active && arguments[4] === 0)) return; return origNote.apply(this, arguments); }; const origChord = SFXEngine.playChord; SFXEngine.playChord = function() { if (InsanityGame._isBgTick || (!InsanityGame.active && arguments[4] === 0)) return; return origChord.apply(this, arguments); }; } InsanityGame._uhHooked = true; } if (!window._uhBgTicker) { window._uhBgTicker = setInterval(() => { try { UI.updateSkillsIndicator(); InsanityGame._runBackgroundTick(250); } catch (e) {} }, 250); } }'
            ExpectedCount = 1
        }
    )

    Write-Host "[PATCH] Applying code modifications..." -ForegroundColor Cyan
    foreach ($p in $Patches) {
        $target = if ($content.Contains("`r`n")) { $p.Target } else { $p.Target.Replace("`r`n", "`n") }
        $replacement = if ($content.Contains("`r`n")) { $p.Replacement } else { $p.Replacement.Replace("`r`n", "`n") }
        $parts = $content.Split(@($target), [System.StringSplitOptions]::None)
        $count = $parts.Length - 1
        if ($count -ne $p.ExpectedCount) {
            if ($p.Optional) {
                Write-Host "  * [SKIPPED] $($p.Name) (not present in this game version - already updated)" -ForegroundColor Yellow
                continue
            }
            Write-Host "[ERROR] Patch '$($p.Name)' expected $($p.ExpectedCount) match(es), but found $count." -ForegroundColor Red
            Write-Host "[ABORT] File content may differ from expected version. Aborting without saving." -ForegroundColor Red
            return
        }
        $content = [string]::Join($replacement, $parts)
        Write-Host "  + [OK] $($p.Name)" -ForegroundColor Green
    }

    Write-Host "[SAVE] Writing updated unhuman.html..." -ForegroundColor Cyan
    [System.IO.File]::WriteAllText($HtmlPath, $content, $Utf8NoBom)

    # Patch language files
    Patch-LanguageFiles $translations

    $verifyContent = [System.IO.File]::ReadAllText($HtmlPath, $Utf8NoBom)
    if (Test-IsModded($verifyContent)) {
        Write-Host "============================================================" -ForegroundColor Cyan
        Write-Host "                 MOD APPLIED SUCCESSFULLY!                  " -ForegroundColor Green
        Write-Host "============================================================" -ForegroundColor Cyan
        Write-Host "Features & Quality-of-Life Improvements:" -ForegroundColor White
        Write-Host "  1. Character Creation Tutorial Skip toggle + Instant Rewards" -ForegroundColor White
        Write-Host "  2. Intro Splash Skip toggle in Settings (ON by default) + Click/Key Skip" -ForegroundColor White
        Write-Host "  3. Removed Minigame Auto-Complete penalty (if applicable)" -ForegroundColor White
        Write-Host "  4. Double Click to equip / unequip items (stash, loadout, augments)" -ForegroundColor White
        Write-Host "  5. Right-click context menu Equip / Unequip options" -ForegroundColor White
        Write-Host "  6. Right-click weapon Buy Ammo option (Gunsmith shop & mag selection)" -ForegroundColor White
        Write-Host "  7. Weapon hover magazine highlighting in Stash and Loadout" -ForegroundColor White
        Write-Host "  8. Empty loadout slot click Quick-Equip Modal & Trader Direct-Buy button" -ForegroundColor White
        Write-Host "  9. Multi-Language Support (12 Languages):" -ForegroundColor White
        Write-Host "     EN, DE, ES, FR, JA, KO, PL, PT, RU, TR, ZH, ZHTW" -ForegroundColor White
        Write-Host " 10. Insanity Background Generation (Silent auto-generation & grey layer progress fill)" -ForegroundColor White
        Write-Host " 11. Skills Unspent Points Notification Asterisk on all Skills nav buttons" -ForegroundColor White
        Write-Host "============================================================" -ForegroundColor Cyan
    } else {
        Write-Host "[ERROR] Verification failed after writing file!" -ForegroundColor Red
    }
}

switch ($Action) {
    "patch"   { Apply-Patch }
    "1"       { Apply-Patch }
    "restore" { Restore-Backup }
    "2"       { Restore-Backup }
    "status"  { Show-Status }
    "3"       { Show-Status }
    default   {
        Write-Host "Usage: powershell -File patcher.ps1 [patch|restore|status]"
    }
}
