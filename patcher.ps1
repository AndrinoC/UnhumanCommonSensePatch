param(
    [string]$Action = "patch"
)

# UNHUMAN Mod Patcher (PowerShell Engine)
# Supports multi-language game installations (12 languages)

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
            Name = 'Context Menu Equip/Unequip/Buy Ammo/Apply Vault Code HTML'
            Target = '<div id="itemContextMenu">
        <div class="context-menu-item" data-action="inspect">Inspect</div>'
            Replacement = '<div id="itemContextMenu">
        <div class="context-menu-item" data-action="equip">Equip</div>
        <div class="context-menu-item" data-action="unequip">Unequip</div>
        <div class="context-menu-item" data-action="buyAmmo">Buy Ammo</div>
        <div class="context-menu-item" data-action="applyVaultCode">Apply Vault Code</div>
        <div class="context-menu-item" data-action="inspect">Inspect</div>'
            ExpectedCount = 1
        },
        @{
            Name = 'Context Menu Item Display (Equip/Unequip/Buy Ammo/Apply Vault Code)'
            Target = 'const t=document.querySelector(''#itemContextMenu [data-action="ensure"]'')'
            Replacement = 'const eq=document.querySelector(''#itemContextMenu [data-action="equip"]''),uneq=document.querySelector(''#itemContextMenu [data-action="unequip"]''),bAmmo=document.querySelector(''#itemContextMenu [data-action="buyAmmo"]''),vCode=document.querySelector(''#itemContextMenu [data-action="applyVaultCode"]'');if(eq)eq.style.display=("stash"===this.contextMenuSource||"container"===this.contextMenuSource)?"block":"none";if(uneq)uneq.style.display=("equipment"===this.contextMenuSource||"augment"===this.contextMenuSource)?"block":"none";if(bAmmo){const isEqWeapon="equipment"===this.contextMenuSource&&e&&"weapon"===e.type&&!Game.state?.inRaid;const mId=isEqWeapon?UI.getCompatibleMagId(e):null;bAmmo.style.display=mId?"block":"none";if(mId&&"function"==typeof T)bAmmo.textContent=T("Buy Ammo");}if(vCode){const isCraftable=e&&(e.type==="weapon"||e.type==="armor")&&!Game.state?.inRaid;vCode.style.display=isCraftable?"block":"none";if(isCraftable&&"function"==typeof T)vCode.textContent=T("Apply Vault Code");}const t=document.querySelector(''#itemContextMenu [data-action="ensure"]'')'
            ExpectedCount = 1
        },
        @{
            Name = 'Context Menu Action Handler (Equip/Unequip/Buy Ammo/Apply Vault Code)'
            Target = 'case"inspect":HintSystem.show("inspect_item")'
            Replacement = 'case"equip":case"unequip":UI.quickStashAction(this.contextMenuTarget,this.contextMenuSlot,this.contextMenuSource,null);break;case"buyAmmo":UI.buyAmmoAction(this.contextMenuTarget);break;case"applyVaultCode":UI.openVaultCodeModal(this.contextMenuTarget,this.contextMenuSlot,this.contextMenuSource);break;case"inspect":HintSystem.show("inspect_item")'
            ExpectedCount = 1
        },
        @{
            Name = 'Double-Click & Quick Stash & Hover & Empty Slot & Vault Modal Handler'
            Target = 'document.addEventListener("click",e=>{if(!e.shiftKey||Game.state.inRaid)return;if(void 0!==TutorialManager&&TutorialManager.active)return;let t=null,a=null,s=null,i=null;const n=e.target.closest(".tlo-slot-container .item-card");if(n){const e=n.closest("[data-slot]");if(e){const n=e.dataset.slot,o=Game.data.equipment[n];o&&(t="string"==typeof o?Items[o]:o,a=n,s="equipment",i=e)}}if(!t){const n=e.target.closest(".augment-slot.filled");if(n){const e=n.dataset.slot,o=Game.data.augments?.[e];o&&(t="string"==typeof o?Items[o]:o,a=e,s="augment",i=n)}}if(!t){const n=e.target.closest("#stashGrid .eft-merged-grid-slot, #stashGrid .stash-slot-item, #stashGrid .stash-grid-slot");if(n){const e=n.closest("[data-slot-index]")||n,o=UI.getItemFromGridSlot(e,Game.data.stash);o&&(t=o.item,a=o.slot,s="stash",i=e)}}if(!t){const n=e.target.closest("#loadoutRigGrid .stash-slot-item, #loadoutBackpackGrid .stash-slot-item, #loadoutPocketsGrid .stash-slot-item, #loadoutPouchGrid .stash-slot-item,#loadoutRigGrid .covered-drop-overlay, #loadoutBackpackGrid .covered-drop-overlay, #loadoutPouchGrid .covered-drop-overlay");if(n){const e=n.classList.contains("covered-drop-overlay")?n:n.closest(".eft-merged-grid-slot, .eft-discrete-slot");if(e){const n=e.closest("[id]"),o=e.dataset.containerType||("loadoutRigGrid"===n?.id?"rig":"loadoutBackpackGrid"===n?.id?"backpack":"loadoutPouchGrid"===n?.id?"pouch":"loadoutPocketsGrid"===n?.id?"pockets":null),r=void 0!==e.dataset.anchorSlot?parseInt(e.dataset.anchorSlot):parseInt(e.dataset.slotIndex);if(o&&!isNaN(r)){const n=Game.getActiveInventory(),l="rig"===o?"rigContents":"backpack"===o?"backpackContents":o;if(n?.[l]?.[r]){const c=n[l][r];t="string"==typeof c?Items[c]:c,a=r,s="container",i=e,i._containerType=o,i._contentsKey=l}}}}}if(!t||!s)return;e.preventDefault(),UI.hideItemTooltip();const o=e=>{MenuSFX.error(),e&&(e.classList.remove("shift-click-blocked"),e.offsetWidth,e.classList.add("shift-click-blocked"),e.addEventListener("animationend",()=>e.classList.remove("shift-click-blocked"),{once:!0}))};if("equipment"===s){const e=["rig","backpack","pouch"].includes(a)?Game._containerTxBegin(a):null;if(e&&!Game.evacuateContainerContents(a))return Game._containerTxRollback(e),void o(i);if(!Game.addToStash(t))return Game._containerTxRollback(e),GlobalNotif.show("STASH FULL","Free stash space first"),void o(i);Game.setEquipment(a,null),GameSFX.equip?.(),Game._saveDirty=!0,UI.renderStats(),UI.renderLoadout(),UI.renderStash()}else if("augment"===s){const e=t.slots?.[0]||a;Game.data.augmentLocker||(Game.data.augmentLocker={eye:[],brain:[],torso:[],skin:[],arms:[],legs:[],skeleton:[],internal:[],shoulder:[]}),Game.data.augmentLocker[e]||(Game.data.augmentLocker[e]=[]),Game.data.augmentLocker[e].push(t),Game.data.augments[a]=null,Game.invalidateStats(),Game.clampBodyHealthToMax(),void 0!==AugmentTriggers&&AugmentTriggers.invalidateAugmentCache(),GameSFX.equip?.(),Game._saveDirty=!0,UI.renderStats(),UI.renderLoadout()}else if("stash"===s){const e=t.type;if(["weapon","armor","accessory","container"].includes(e)){let s=[];if(Array.isArray(t.slots)&&t.slots.length)s=t.slots;else if("weapon"===e){const e=t.weaponClass||t.subtype||"ranged";s="melee"===e?["melee"]:"pistol"===e?["secondary","primary"]:["primary"]}else"armor"===e||"accessory"===e?s=["head","body","earpiece","facecover","eyewear"]:"container"===e&&(s="secure"===t.subtype?["pouch"]:["rig","backpack"]);let n=!1;for(const e of s)if(!Game.data.equipment[e]&&Game.canEquipToSlot(t,e)){Game.setEquipment(e,t),Game.removeFromStash(a),GameSFX.equip?.(),Game._saveDirty=!0,n=!0;break}if(!n)for(const e of s){const s=Game.data.equipment[e];if(!s||!Game.canEquipToSlot(t,e))continue;if(["rig","backpack","pouch"].includes(e)){const t=Game._containerTxBegin(e);if(!Game.evacuateContainerContents(e)){Game._containerTxRollback(t);continue}}const i="string"==typeof s?Items[s]:s;if(i){if(Game.removeFromStash(a),!Game.addToStash(i)){Game.addToStash(t);break}Game.setEquipment(e,t),GameSFX.equip?.(),Game._saveDirty=!0,n=!0;break}}if(!n)return void o(i)}else{if("augment"===e){const e=Game.data.prestige||0;let s=!1;for(const{slot:i,minPrestige:n}of AUGMENT_SLOT_DEFS)if(!(e<n)&&!Game.data.augments?.[i]&&Game.canEquipAugmentToSlot(t,i)){Game.data.augments[i]=t,Game.removeFromStash(a),Game.invalidateStats(),Game.clampBodyHealthToMax(),AugmentTriggers.invalidateAugmentCache(),GameSFX.equip?.(),Game._saveDirty=!0,HintSystem.show("augment_equip"),addQuestProgress("equip_augment",{slot:i,amount:1}),s=!0;break}return s?("augments"!==UI.activeLoadoutSubTab?UI.switchLoadoutSubTab("augments"):UI.renderLoadout(),void UI.renderStash()):void o(i)}{const e=Game.getActiveInventory(),s=getEffectiveSize(t),n=[{type:"rig",key:"rigContents"},{type:"backpack",key:"backpackContents"},{type:"pockets",key:"pockets"},{type:"pouch",key:"pouch"}];let r=!1;for(const i of n){if("pockets"!==i.type&&!Game.data.equipment[i.type])continue;const n=getContainerGridConfig(i.type);e[i.key]||(e[i.key]="pockets"===i.type?[null,null,null,null]:[]);const o="pockets"===i.type?s.width>1||s.height>1?-1:e.pockets.indexOf(null):findEmptySlotInContainer(s.width,s.height,e[i.key],n.cols,n.rows);if(o>=0){e[i.key][o]=t,Game.removeFromStash(a),Game.invalidateStats(),GameSFX.equip?.(),Game._saveDirty=!0,r=!0;break}}if(!r)return void o(i)}}UI.renderStats(),UI.renderLoadout(),UI.renderStash()}else if("container"===s){if(!Game.addToStash(t))return void o(i);const e=Game.getActiveInventory(),s=i._contentsKey;"pockets"===s?e[s][a]=null:delete e[s][a],Game.invalidateStats(),GameSFX.equip?.(),Game._saveDirty=!0,UI.renderStats(),UI.renderLoadout(),UI.renderStash()}})'
            Replacement = 'UI.getClickedItemDetails=function(e){let t=null,a=null,s=null,i=null;const n=e.target.closest(".tlo-slot-container .item-card");if(n){const e=n.closest("[data-slot]");if(e){const n=e.dataset.slot,o=Game.data.equipment[n];o&&(t="string"==typeof o?Items[o]:o,a=n,s="equipment",i=e)}}if(!t){const n=e.target.closest(".augment-slot.filled");if(n){const e=n.dataset.slot,o=Game.data.augments?.[e];o&&(t="string"==typeof o?Items[o]:o,a=e,s="augment",i=n)}}if(!t){const n=e.target.closest("#stashGrid .eft-merged-grid-slot, #stashGrid .stash-slot-item, #stashGrid .stash-grid-slot");if(n){const e=n.closest("[data-slot-index]")||n,o=UI.getItemFromGridSlot(e,Game.data.stash);o&&(t=o.item,a=o.slot,s="stash",i=e)}}if(!t){const n=e.target.closest("#loadoutRigGrid .stash-slot-item, #loadoutBackpackGrid .stash-slot-item, #loadoutPocketsGrid .stash-slot-item, #loadoutPouchGrid .stash-slot-item,#loadoutRigGrid .covered-drop-overlay, #loadoutBackpackGrid .covered-drop-overlay, #loadoutPouchGrid .covered-drop-overlay");if(n){const e=n.classList.contains("covered-drop-overlay")?n:n.closest(".eft-merged-grid-slot, .eft-discrete-slot");if(e){const n=e.closest("[id]"),o=e.dataset.containerType||("loadoutRigGrid"===n?.id?"rig":"loadoutBackpackGrid"===n?.id?"backpack":"loadoutPouchGrid"===n?.id?"pouch":"loadoutPocketsGrid"===n?.id?"pockets":null),r=void 0!==e.dataset.anchorSlot?parseInt(e.dataset.anchorSlot):parseInt(e.dataset.slotIndex);if(o&&!isNaN(r)){const n=Game.getActiveInventory(),l="rig"===o?"rigContents":"backpack"===o?"backpackContents":o;if(n?.[l]?.[r]){const c=n[l][r];t="string"==typeof c?Items[c]:c,a=r,s="container",i=e,i._containerType=o,i._contentsKey=l}}}}}return{item:t,slot:a,source:s,el:i}};UI.quickStashAction=function(t,a,s,i){if(!t||!s)return;UI.hideItemTooltip();const o=e=>{MenuSFX.error(),e&&(e.classList.remove("shift-click-blocked"),e.offsetWidth,e.classList.add("shift-click-blocked"),e.addEventListener("animationend",()=>e.classList.remove("shift-click-blocked"),{once:!0}))};if("equipment"===s){const e=["rig","backpack","pouch"].includes(a)?Game._containerTxBegin(a):null;if(e&&!Game.evacuateContainerContents(a))return Game._containerTxRollback(e),void o(i);if(!Game.addToStash(t))return Game._containerTxRollback(e),GlobalNotif.show("STASH FULL","Free stash space first"),void o(i);Game.setEquipment(a,null),GameSFX.equip?.(),Game._saveDirty=!0,UI.renderStats(),UI.renderLoadout(),UI.renderStash()}else if("augment"===s){const e=t.slots?.[0]||a;Game.data.augmentLocker||(Game.data.augmentLocker={eye:[],brain:[],torso:[],skin:[],arms:[],legs:[],skeleton:[],internal:[],shoulder:[]}),Game.data.augmentLocker[e]||(Game.data.augmentLocker[e]=[]),Game.data.augmentLocker[e].push(t),Game.data.augments[a]=null,Game.invalidateStats(),Game.clampBodyHealthToMax(),void 0!==AugmentTriggers&&AugmentTriggers.invalidateAugmentCache(),GameSFX.equip?.(),Game._saveDirty=!0,UI.renderStats(),UI.renderLoadout()}else if("stash"===s){const e=t.type;if(["weapon","armor","accessory","container"].includes(e)){let s=[];if(Array.isArray(t.slots)&&t.slots.length)s=t.slots;else if("weapon"===e){const e=t.weaponClass||t.subtype||"ranged";s="melee"===e?["melee"]:"pistol"===e?["secondary","primary"]:["primary"]}else"armor"===e||"accessory"===e?s=["head","body","earpiece","facecover","eyewear"]:"container"===e&&(s="secure"===t.subtype?["pouch"]:["rig","backpack"]);let n=!1;for(const e of s)if(!Game.data.equipment[e]&&Game.canEquipToSlot(t,e)){Game.setEquipment(e,t),Game.removeFromStash(a),GameSFX.equip?.(),Game._saveDirty=!0,n=!0;break}if(!n)for(const e of s){const s=Game.data.equipment[e];if(!s||!Game.canEquipToSlot(t,e))continue;if(["rig","backpack","pouch"].includes(e)){const t=Game._containerTxBegin(e);if(!Game.evacuateContainerContents(e)){Game._containerTxRollback(t);continue}}const i="string"==typeof s?Items[s]:s;if(i){if(Game.removeFromStash(a),!Game.addToStash(i)){Game.addToStash(t);break}Game.setEquipment(e,t),GameSFX.equip?.(),Game._saveDirty=!0,n=!0;break}}if(!n)return void o(i)}else{if("augment"===e){const e=Game.data.prestige||0;let s=!1;for(const{slot:i,minPrestige:n}of AUGMENT_SLOT_DEFS)if(!(e<n)&&!Game.data.augments?.[i]&&Game.canEquipAugmentToSlot(t,i)){Game.data.augments[i]=t,Game.removeFromStash(a),Game.invalidateStats(),Game.clampBodyHealthToMax(),AugmentTriggers.invalidateAugmentCache(),GameSFX.equip?.(),Game._saveDirty=!0,HintSystem.show("augment_equip"),addQuestProgress("equip_augment",{slot:i,amount:1}),s=!0;break}return s?("augments"!==UI.activeLoadoutSubTab?UI.switchLoadoutSubTab("augments"):UI.renderLoadout(),void UI.renderStash()):void o(i)}{const e=Game.getActiveInventory(),s=getEffectiveSize(t),n=[{type:"rig",key:"rigContents"},{type:"backpack",key:"backpackContents"},{type:"pockets",key:"pockets"},{type:"pouch",key:"pouch"}];let r=!1;for(const i of n){if("pockets"!==i.type&&!Game.data.equipment[i.type])continue;const n=getContainerGridConfig(i.type);e[i.key]||(e[i.key]="pockets"===i.type?[null,null,null,null]:[]);const o="pockets"===i.type?s.width>1||s.height>1?-1:e.pockets.indexOf(null):findEmptySlotInContainer(s.width,s.height,e[i.key],n.cols,n.rows);if(o>=0){e[i.key][o]=t,Game.removeFromStash(a),Game.invalidateStats(),GameSFX.equip?.(),Game._saveDirty=!0,r=!0;break}}if(!r)return void o(i)}}UI.renderStats(),UI.renderLoadout(),UI.renderStash()}else if("container"===s){if(!Game.addToStash(t))return void o(i);const e=Game.getActiveInventory(),s=i._contentsKey;"pockets"===s?e[s][a]=null:delete e[s][a],Game.invalidateStats(),GameSFX.equip?.(),Game._saveDirty=!0,UI.renderStats(),UI.renderLoadout(),UI.renderStash()}};UI.getCompatibleMagId=function(w){if(!w)return null;const item="string"==typeof w?(void 0!==window.Items&&Items[w])||(void 0!==window.ItemBases&&ItemBases[w]):w;if(!item||"weapon"!==item.type)return null;const sub=(item.subtype||item.weaponClass||"").toLowerCase();return["pistol","dmr","shotgun","smg","ar","bolt"].includes(sub)?"mag_"+sub:null};UI.isMagCompatible=function(m,w){if(!m||!w)return!1;const mag="string"==typeof m?(void 0!==window.Items&&Items[m])||(void 0!==window.ItemBases&&ItemBases[m]):m;const wep="string"==typeof w?(void 0!==window.Items&&Items[w])||(void 0!==window.ItemBases&&ItemBases[w]):w;if(!mag||!wep||"weapon"!==wep.type)return!1;const isMag="magazine"===mag.type||String(mag.baseId||"").startsWith("mag_")||"proto_magazine"===mag.baseId;if(!isMag)return!1;if("proto_magazine"===mag.baseId||"universal"===mag.subtype)return!0;const targetMagId=UI.getCompatibleMagId(wep);return!!(targetMagId&&(mag.baseId===targetMagId||mag.subtype===(wep.subtype||wep.weaponClass)))};UI.clearMagHighlights=function(){document.querySelectorAll(".uh-mag-highlight").forEach(e=>e.classList.remove("uh-mag-highlight"))};UI.highlightCompatibleMags=function(w){UI.clearMagHighlights();if(!w||"weapon"!==w.type||"melee"===w.subtype||"melee"===w.weaponClass)return;if(Game.data&&Game.data.stash){for(const s in Game.data.stash){const item=Game.data.stash[s];if(UI.isMagCompatible(item,w)){const el=document.querySelector("#stashGrid [data-slot-index=\"" + s + "\"]");if(el){const target=el.querySelector(".stash-slot-item")||el;target.classList.add("uh-mag-highlight")}}}}const inv="function"==typeof Game.getActiveInventory?Game.getActiveInventory():null;if(inv){const containers=[{id:"loadoutRigGrid",items:inv.rigContents},{id:"loadoutBackpackGrid",items:inv.backpackContents},{id:"loadoutPocketsGrid",items:inv.pockets},{id:"loadoutPouchGrid",items:inv.pouch}];containers.forEach(c=>{if(!c.items)return;const grid=document.getElementById(c.id);if(!grid)return;for(const s in c.items){const item=c.items[s];if(UI.isMagCompatible(item,w)){const el=grid.querySelector("[data-slot-index=\"" + s + "\"]");if(el){const target=el.querySelector(".stash-slot-item")||el;target.classList.add("uh-mag-highlight")}}}})}};UI.buyAmmoAction=function(w){const magId=UI.getCompatibleMagId(w);if(magId&&"function"==typeof openTraderShop){UI.hideContextMenu();openTraderShop("gunsmith");setTimeout(()=>{const el=document.querySelector(".fixed-stock-slot[data-fixed-base-id=\"" + magId + "\"]");if(el){el.click();el.scrollIntoView({behavior:"smooth",block:"center"});el.classList.add("uh-mag-focus-pulse");setTimeout(()=>el.classList.remove("uh-mag-focus-pulse"),3500)}},150)}};UI.getTraderForSlot=function(slot){if(["primary","secondary","melee"].includes(slot))return"gunsmith";if(["head","body","rig","backpack","pouch","earpiece","facecover","eyewear","companion","companion_toy","companion_food"].includes(slot))return"weaver";if(["relic"].includes(slot))return"signal_broker";if(["eye","brain","torso","skin","arms","legs","skeleton","internal","shoulder"].includes(slot))return"ripperdoc";return"gunsmith"};UI.closeQuickEquipModal=function(){const m=document.getElementById("uhQuickEquipModal");m&&m.remove()};UI.quickBuyForSlot=function(slot){const tId=UI.getTraderForSlot(slot);UI.closeQuickEquipModal();if("function"==typeof openTraderShop)openTraderShop(tId)};UI.quickEquipFromModal=function(slot,stashIdx,isAugment){const raw=Game.data?.stash?.[stashIdx];if(!raw)return;const item="string"==typeof raw?(Items[raw]||ItemBases[raw]):raw;if(!item)return;UI.closeQuickEquipModal();if(isAugment){Game.data.augmentLocker=Game.data.augmentLocker||{};Game.data.augments=Game.data.augments||{};Game.data.augments[slot]=item;Game.removeFromStash(stashIdx);Game.invalidateStats();Game.clampBodyHealthToMax();void 0!==AugmentTriggers&&AugmentTriggers.invalidateAugmentCache&&AugmentTriggers.invalidateAugmentCache();GameSFX.equip?.();Game._saveDirty=!0}else{Game.setEquipment(slot,item);Game.removeFromStash(stashIdx);GameSFX.equip?.();Game._saveDirty=!0}UI.renderStats();UI.renderLoadout();UI.renderStash()};UI.openQuickEquipModal=function(slot,isAugment){UI.closeQuickEquipModal();const rawSlotName=void 0!==EQUIP_SLOT_LABELS&&EQUIP_SLOT_LABELS[slot]?EQUIP_SLOT_LABELS[slot]:slot.toUpperCase();const slotLabel="function"==typeof T?T(rawSlotName):rawSlotName;const traderId=UI.getTraderForSlot(slot);const rawTraderName=void 0!==TraderConfig&&TraderConfig[traderId]&&TraderConfig[traderId].name?TraderConfig[traderId].name:traderId.toUpperCase();const traderName="function"==typeof T?T(rawTraderName):rawTraderName;const buyText="function"==typeof T?T("Buy from Trader"):("Buy from Trader");const equipText="function"==typeof T?T("EQUIP ITEM"):("EQUIP ITEM");const emptyText="function"==typeof T?T("No compatible items in stash"):("No compatible items in stash");const equippable=[];if(Game.data&&Game.data.stash){for(const s in Game.data.stash){const raw=Game.data.stash[s];if(!raw)continue;const item="string"==typeof raw?(Items[raw]||ItemBases[raw]):raw;if(!item)continue;const valid=isAugment?(Game.canEquipAugmentToSlot?Game.canEquipAugmentToSlot(item,slot):!1):(Game.canEquipToSlot?Game.canEquipToSlot(item,slot):!1);if(valid)equippable.push({item,slotIndex:s})}}const modal=document.createElement("div");modal.id="uhQuickEquipModal";modal.className="uh-modal-backdrop";modal.onclick=e=>{if(e.target===modal)UI.closeQuickEquipModal()};let itemsHtml="";if(0===equippable.length){itemsHtml="<div class=\"uh-modal-empty\"><div style=\"font-size:22px;margin-bottom:8px;opacity:0.4;\">[ &#8709; ]</div><div>" + emptyText + "</div></div>"}else{itemsHtml=equippable.map(e=>{const it=e.item;const img="function"==typeof getItemImage?getItemImage(it):(it.image||"");const emoji="function"==typeof getItemEmoji?getItemEmoji(it):"&#128230;";const rarity=void 0!==RarityConfig&&RarityConfig[it.tier||"standard"]?RarityConfig[it.tier||"standard"]:{hex:"#9ca3af"};const st=it.stats||(void 0!==window.ItemBases&&ItemBases[it.baseId])||(void 0!==window.Items&&Items[it.baseId])||it;const base=(void 0!==window.ItemBases&&ItemBases[it.baseId])||(void 0!==window.Items&&Items[it.baseId])||{};let detail="";if("weapon"===it.type){const dmg=st.damage??base.damage??it.damage??0;const rpm=st.rpm??base.rpm??it.rpm??0;const mag=st.magCapacity??base.magCapacity??it.magCapacity??0;detail=dmg + " DMG &middot; " + rpm + " RPM &middot; " + mag + " RND"}else if("armor"===it.type){const arm=st.armor??base.armor??it.armor??0;const hp=st.health??base.health??it.health??0;const eva=st.evasion??base.evasion??it.evasion??0;const p=[];if(arm>0)p.push(arm + " ARM");if(hp>0)p.push("+" + hp + " HP");if(eva>0)p.push("+" + eva + "% EVA");detail=p.length>0?p.join(" &middot; "):((it.description||"").substring(0,40))}else if("container"===it.type){const slt=st.slots??it.capacity??base.capacity??((it.width||1)*(it.height||1));detail=slt + " SLOTS"}else if("accessory"===it.type){const awr=st.awareness??base.awareness??it.awareness??0;const comms=st.comms??base.comms??it.comms??0;const stl=st.stealth??base.stealth??it.stealth??0;const p=[];if(awr>0)p.push("+" + awr + " AWR");if(comms>0)p.push("+" + comms + " COM");if(stl>0)p.push("+" + stl + "% STL");detail=p.length>0?p.join(" &middot; "):((it.description||"").substring(0,40))}else{detail=(it.description||"").substring(0,40)}return"<div class=\"uh-modal-item\" onclick=\"UI.quickEquipFromModal(''" + slot + "'',''" + e.slotIndex + "''," + (!!isAugment) + ")\"><img src=\"" + img + "\" class=\"uh-modal-item-img\" onerror=\"this.style.display=''none'';this.nextElementSibling.style.display=''flex'';\"><div class=\"item-icon-fallback\" style=\"display:none;width:40px;height:40px;align-items:center;justify-content:center;font-size:20px;\">" + emoji + "</div><div class=\"uh-modal-item-info\"><div class=\"uh-modal-item-name\" style=\"color:" + rarity.hex + "\">" + (it.name||it.baseId) + "</div><div class=\"uh-modal-item-desc\">" + detail + "</div></div><div class=\"uh-modal-item-action\">" + equipText + "</div></div>"}).join("")}modal.innerHTML="<div class=\"uh-modal-box\"><div class=\"uh-modal-header\"><div class=\"uh-modal-title\">[ " + equipText + " // " + slotLabel + " ]</div><button class=\"uh-modal-close\" onclick=\"UI.closeQuickEquipModal()\">&times;</button></div><div class=\"uh-modal-actions\"><button class=\"uh-modal-buy-btn\" onclick=\"UI.quickBuyForSlot(''" + slot + "'')\">" + buyText + " (" + traderName + ")</button></div><div class=\"uh-modal-body\">" + itemsHtml + "</div></div>";document.body.appendChild(modal)};UI.closeVaultCodeModal=function(){const m=document.getElementById("uhVaultCodeModal");m&&m.remove()};UI.openVaultCodeModal=function(targetItem,slot,source){UI.closeVaultCodeModal();if(!targetItem||Game.state?.inRaid)return;const cat=(typeof TechTerminal!=="undefined"&&TechTerminal.getItemCategory)?TechTerminal.getItemCategory(targetItem):("weapon"===targetItem.type?"ranged":"armor");const vault=Game.data?.techCraft?.codeVault||{kernelCodes:[],patchCodes:[],glitchCodes:[]};const compatible=[];(vault.kernelCodes||[]).forEach((c,idx)=>{const def=(typeof AffixDatabase!=="undefined"&&AffixDatabase.kernels)?AffixDatabase.kernels[c.groupKey]:null;if(!def||def.category===cat){compatible.push({...c,type:"kernel",vaultIdx:idx,name:c.modName||def?.nameTag||def?.name||"Kernel",color:"#a855f7"})}});(vault.patchCodes||[]).forEach((c,idx)=>{const def=(typeof AffixDatabase!=="undefined"&&AffixDatabase.patches)?AffixDatabase.patches[c.groupKey]:null;if(!def||def.category===cat){compatible.push({...c,type:"patch",vaultIdx:idx,name:c.modName||def?.nameTag||def?.name||"Patch",color:"#38bdf8"})}});(vault.glitchCodes||[]).forEach((c,idx)=>{compatible.push({...c,type:"glitch",vaultIdx:idx,name:c.protocol||"Glitch Protocol",color:"#ec4899"})});const titleText=("function"==typeof T?T("Select Vault Code"):"Select Vault Code")+" // "+(targetItem.name||targetItem.baseId);const emptyText="function"==typeof T?T("No compatible codes in vault"):"No compatible codes in vault";const modal=document.createElement("div");modal.id="uhVaultCodeModal";modal.className="uh-modal-backdrop";modal.onclick=e=>{if(e.target===modal)UI.closeVaultCodeModal()};let bodyHtml="";if(0===compatible.length){bodyHtml="<div class=\"uh-modal-empty\"><div style=\"font-size:22px;margin-bottom:8px;opacity:0.4;\">[ &#8709; ]</div><div>" + emptyText + "</div></div>"}else{bodyHtml=compatible.map(c=>{return"<div class=\"uh-modal-item\" onclick=\"UI.applyVaultCodeToItem(''" + c.code + "'',''" + c.type + "'',''" + slot + "'',''" + source + "'')\"><div style=\"font-size:18px;color:" + c.color + ";font-weight:bold;width:32px;text-align:center;\">&lt;&gt;</div><div class=\"uh-modal-item-info\"><div class=\"uh-modal-item-name\" style=\"color:" + c.color + "\">" + c.code + " [" + c.type.toUpperCase() + "]</div><div class=\"uh-modal-item-desc\">" + c.name + "</div></div><div class=\"uh-modal-item-action\" style=\"border-color:" + c.color + ";color:" + c.color + ";\">APPLY</div></div>"}).join("")}modal.innerHTML="<div class=\"uh-modal-box\"><div class=\"uh-modal-header\"><div class=\"uh-modal-title\" style=\"color:#a855f7;\">[ " + titleText + " ]</div><button class=\"uh-modal-close\" onclick=\"UI.closeVaultCodeModal()\">&times;</button></div><div class=\"uh-modal-body\">" + bodyHtml + "</div></div>";document.body.appendChild(modal)};UI.applyVaultCodeToItem=function(codeStr,codeType,slot,source){UI.closeVaultCodeModal();let target=null;if("stash"===source){target=Game.data?.stash?.[slot]}else if("equipment"===source){target=Game.data?.equipment?.[slot]}else if("container"===source){const inv=Game.getActiveInventory?Game.getActiveInventory():null;if(inv){for(const k of["pouch","backpackContents","rigContents","pockets"]){if(inv[k]&&inv[k][slot]){target=inv[k][slot];break}}}}if(!target)return;target.mods=target.mods||[];const vault=Game.data?.techCraft?.codeVault;if(!vault)return;const listKey=codeType+"Codes";const list=vault[listKey]||[];const idx=list.findIndex(c=>c.code===codeStr);if(idx<0)return;const codeObj=list[idx];let applied=!1;if("kernel"===codeType){applied=TechTerminal.applySpecificKernel(target,codeObj.groupKey)}else if("patch"===codeType){applied=TechTerminal.applySpecificPatch(target,codeObj.groupKey)}else if("glitch"===codeType){TechTerminal.applyGuaranteedGlitch(target,codeObj);applied=!0}if(applied){list.splice(idx,1);if(typeof ItemFactory!=="undefined"&&ItemFactory.applyModsToStats){ItemFactory.applyModsToStats(target)}Game.saveData();UI.renderStats();UI.renderLoadout();UI.renderStash();if(typeof GlobalNotif!=="undefined"){GlobalNotif.show("VAULT CODE APPLIED",codeStr+" installed successfully!")}if(typeof GameSFX!=="undefined"&&GameSFX.equip)GameSFX.equip()}else{if(typeof GlobalNotif!=="undefined"){GlobalNotif.show("APPLY FAILED","Incompatible mod or mod slot limit reached.")}}};if(!document.getElementById("uh-mod-styles")){const st=document.createElement("style");st.id="uh-mod-styles";st.textContent=".uh-mag-highlight{outline:2px solid #00ff41 !important;outline-offset:-1px !important;box-shadow:0 0 12px rgba(0,255,65,0.9),inset 0 0 8px rgba(0,255,65,0.4) !important;animation:uhMagPulse 1.2s infinite alternate ease-in-out !important;z-index:40 !important;}@keyframes uhMagPulse{0%{outline-color:#00ff41;box-shadow:0 0 6px rgba(0,255,65,0.6),inset 0 0 4px rgba(0,255,65,0.2);}100%{outline-color:#39ff14;box-shadow:0 0 16px rgba(57,255,20,1),inset 0 0 12px rgba(57,255,20,0.5);}}.uh-mag-focus-pulse{outline:2px solid #00ff41 !important;box-shadow:0 0 20px #00ff41,inset 0 0 10px rgba(0,255,65,0.5) !important;animation:uhFocusPulse 0.8s infinite alternate ease-in-out !important;}@keyframes uhFocusPulse{0%{transform:scale(1);box-shadow:0 0 10px #00ff41;}100%{transform:scale(1.06);box-shadow:0 0 24px #39ff14,inset 0 0 14px rgba(57,255,20,0.8);}}.uh-modal-backdrop{position:fixed;inset:0;z-index:9999;background:rgba(0,5,0,0.8);backdrop-filter:blur(4px);display:flex;align-items:center;justify-content:center;font-family:monospace;}.uh-modal-box{background:#020a04;border:1px solid #00ff41;box-shadow:0 0 25px rgba(0,255,65,0.35),inset 0 0 20px rgba(0,255,65,0.05);width:min(92vw,560px);max-height:82vh;display:flex;flex-direction:column;overflow:hidden;position:relative;}.uh-modal-header{display:flex;justify-content:space-between;align-items:center;padding:calc(12px * var(--ui-scale,1)) calc(16px * var(--ui-scale,1));border-bottom:1px solid rgba(0,255,65,0.25);background:rgba(0,255,65,0.05);}.uh-modal-title{color:#00ff41;font-size:calc(13px * var(--font-scale,1));font-weight:bold;letter-spacing:1.5px;text-shadow:0 0 8px rgba(0,255,65,0.5);}.uh-modal-close{background:transparent;border:1px solid rgba(0,255,65,0.3);color:#00ff41;cursor:pointer;padding:2px 8px;font-size:calc(12px * var(--font-scale,1));transition:all 0.15s ease;}.uh-modal-close:hover{background:#00ff41;color:#000;}.uh-modal-actions{padding:calc(10px * var(--ui-scale,1)) calc(16px * var(--ui-scale,1));display:flex;gap:8px;border-bottom:1px solid rgba(0,255,65,0.15);background:rgba(0,15,0,0.4);}.uh-modal-buy-btn{flex:1;background:rgba(0,255,65,0.12);border:1px solid #00ff41;color:#00ff41;padding:calc(8px * var(--ui-scale,1)) calc(12px * var(--ui-scale,1));font-size:calc(11px * var(--font-scale,1));font-weight:bold;cursor:pointer;letter-spacing:1px;transition:all 0.15s ease;text-shadow:0 0 6px rgba(0,255,65,0.4);display:flex;align-items:center;justify-content:center;gap:6px;}.uh-modal-buy-btn:hover{background:#00ff41;color:#000;box-shadow:0 0 12px rgba(0,255,65,0.8);}.uh-modal-body{padding:calc(14px * var(--ui-scale,1));overflow-y:auto;flex:1;display:flex;flex-direction:column;gap:8px;}.uh-modal-empty{text-align:center;padding:36px 16px;color:rgba(0,255,65,0.5);font-size:calc(12px * var(--font-scale,1));letter-spacing:1px;}.uh-modal-item{display:flex;align-items:center;gap:calc(12px * var(--ui-scale,1));background:rgba(0,20,0,0.4);border:1px solid rgba(0,255,65,0.2);padding:calc(8px * var(--ui-scale,1)) calc(12px * var(--ui-scale,1));cursor:pointer;transition:all 0.15s ease;position:relative;}.uh-modal-item:hover{background:rgba(0,255,65,0.12);border-color:#00ff41;box-shadow:0 0 10px rgba(0,255,65,0.3);transform:translateX(2px);}.uh-modal-item-img{width:calc(44px * var(--ui-scale,1));height:calc(44px * var(--ui-scale,1));object-fit:contain;flex-shrink:0;}.uh-modal-item-info{flex:1;min-width:0;}.uh-modal-item-name{font-size:calc(12px * var(--font-scale,1));font-weight:bold;white-space:nowrap;overflow:hidden;text-overflow:ellipsis;}.uh-modal-item-desc{font-size:calc(10px * var(--font-scale,1));opacity:0.7;margin-top:2px;}.uh-modal-item-action{font-size:calc(11px * var(--font-scale,1));color:#00ff41;border:1px solid rgba(0,255,65,0.4);padding:4px 8px;white-space:nowrap;font-weight:bold;}.uh-modal-item:hover .uh-modal-item-action{background:#00ff41;color:#000;}#igArena{display:none !important;}.ig-root{justify-content:center !important;}.ig-side{width:100% !important;max-width:960px !important;margin:0 auto !important;border-left:none !important;border-right:none !important;}.ig-reelstack{display:flex !important;flex-direction:column !important;gap:8px !important;width:min(90%, 820px) !important;max-height:72vh !important;overflow-y:auto !important;overflow-x:hidden !important;padding-right:4px !important;}.ig-reelwrap{flex-shrink:0 !important;}.ig-reelwrap.compact-mini{height:calc(46px * var(--font-scale, 1)) !important;}.ig-reelwrap.compact-mini .ig-card{height:calc(38px * var(--font-scale, 1)) !important;}.ig-reelwrap.compact-mini .ig-cicon{font-size:calc(12px * var(--font-scale, 1)) !important;}.ig-reelwrap.compact-mini .ig-clabel{font-size:calc(8px * var(--font-scale, 1)) !important;}#igCaches .ig-cacherow{padding:calc(8px * var(--ui-scale,1)) calc(12px * var(--ui-scale,1)) !important;background:rgba(0,15,0,0.45) !important;border:1px dashed rgba(0,255,65,0.25) !important;border-radius:2px !important;margin-bottom:calc(6px * var(--ui-scale,1)) !important;display:flex !important;align-items:center !important;gap:calc(10px * var(--ui-scale,1)) !important;}#igCaches .ig-cacherow:hover{background:rgba(0,255,65,0.06) !important;border-color:rgba(0,255,65,0.6) !important;}#igCaches .ig-cname{font-size:calc(12px * var(--font-scale,1)) !important;font-weight:bold !important;letter-spacing:1px !important;}#igCaches .ig-cdesc{font-size:calc(10px * var(--font-scale,1)) !important;color:rgba(0,255,65,0.6) !important;margin-top:2px !important;}#igCaches .ig-cbtn{padding:calc(5px * var(--ui-scale,1)) calc(12px * var(--ui-scale,1)) !important;font-size:calc(10px * var(--font-scale,1)) !important;font-weight:bold !important;border:1px solid #00ff41 !important;background:rgba(0,30,0,0.7) !important;color:#00ff41 !important;letter-spacing:1px !important;transition:all 0.15s ease !important;cursor:pointer !important;}#igCaches .ig-cbtn:hover:not(:disabled){background:#00ff41 !important;color:#000 !important;box-shadow:0 0 10px rgba(0,255,65,0.5) !important;}#igCaches .ig-cbtn:disabled{border-color:rgba(0,255,65,0.2) !important;color:rgba(0,255,65,0.25) !important;background:transparent !important;cursor:not-allowed !important;}#igCaches .ig-shophead{display:none !important;}#igCaches .ig-buyrow{padding:calc(6px * var(--ui-scale,1)) calc(12px * var(--ui-scale,1)) !important;background:rgba(0,10,0,0.5) !important;border:1px dashed rgba(0,255,65,0.25) !important;margin-bottom:calc(8px * var(--ui-scale,1)) !important;font-size:calc(10px * var(--font-scale,1)) !important;color:rgba(0,255,65,0.6) !important;display:flex !important;align-items:center !important;gap:calc(6px * var(--ui-scale,1)) !important;}#igCaches .ig-amt{padding:calc(3px * var(--ui-scale,1)) calc(8px * var(--ui-scale,1)) !important;font-size:calc(10px * var(--font-scale,1)) !important;border:1px solid rgba(0,255,65,0.3) !important;background:transparent !important;color:rgba(0,255,65,0.6) !important;cursor:pointer !important;}#igCaches .ig-amt.sel{border-color:#00ff41 !important;background:rgba(0,255,65,0.15) !important;color:#00ff41 !important;font-weight:bold !important;}";document.head.appendChild(st)}window.addEventListener("keydown",e=>{if("Escape"===e.key){UI.closeQuickEquipModal();UI.closeVaultCodeModal()}});if("function"==typeof UI.hideItemTooltip&&!UI._uhTooltipHooked){const origHide=UI.hideItemTooltip;UI.hideItemTooltip=function(){UI.clearMagHighlights();uhLastHoveredWeapon=null;return origHide.apply(this,arguments)};UI._uhTooltipHooked=!0}let uhLastHoveredWeapon=null;document.addEventListener("mouseover",e=>{if(Game.state?.inRaid)return;if(e.target.closest("#itemTooltip, #itemTooltipProtoMag, #uhQuickEquipModal, #uhVaultCodeModal"))return;const res=UI.getClickedItemDetails?UI.getClickedItemDetails(e):null;const item=res?res.item:null;const isWep=item&&"weapon"===item.type&&"melee"!==item.subtype&&"melee"!==item.weaponClass;const weapon=isWep?item:null;if(weapon===uhLastHoveredWeapon)return;uhLastHoveredWeapon=weapon;if(weapon){UI.highlightCompatibleMags(weapon)}else{UI.clearMagHighlights()}},{passive:!0});document.addEventListener("mouseleave",()=>{if(uhLastHoveredWeapon){uhLastHoveredWeapon=null;UI.clearMagHighlights()}},{passive:!0});document.addEventListener("click",e=>{if(!e.shiftKey||Game.state.inRaid)return;if(void 0!==TutorialManager&&TutorialManager.active)return;const res=UI.getClickedItemDetails(e);if(!res.item||!res.source)return;e.preventDefault();UI.quickStashAction(res.item,res.slot,res.source,res.el)});document.addEventListener("dblclick",e=>{if(Game.state.inRaid)return;if(void 0!==TutorialManager&&TutorialManager.active)return;const res=UI.getClickedItemDetails(e);if(!res.item||!res.source)return;e.preventDefault();UI.quickStashAction(res.item,res.slot,res.source,res.el)});document.addEventListener("click",e=>{if(Game.state?.inRaid)return;if(e.shiftKey)return;if(void 0!==TutorialManager&&TutorialManager.active)return;const slotEl=e.target.closest(".tlo-slot-container[data-slot], .augment-slot[data-slot]");if(!slotEl)return;const slot=slotEl.dataset.slot;if(!slot)return;const isAugment=slotEl.classList.contains("augment-slot");if(isAugment&&slotEl.classList.contains("locked-slot"))return;const equipped=isAugment?Game.data?.augments?.[slot]:Game.data?.equipment?.[slot];if(equipped||slotEl.classList.contains("filled")||slotEl.querySelector(".item-card"))return;e.preventDefault();e.stopPropagation();UI.openQuickEquipModal(slot,isAugment)});UI.updateSkillsIndicator=function(){try{const hasPts=(Game.data&&Game.data.skillTree&&Game.data.skillTree.availablePoints>0);const candidates=document.querySelectorAll(''.topbar-tab[data-target="skills"], .terminal-menu-item[data-target="skills"], .nav-dock-btn, button[data-target="skills"], button[onclick*="skills"]'');candidates.forEach(btn=>{if(btn.closest&&(btn.closest("#view-skills")||btn.closest("#skillTreeContainer")))return;const oc=btn.getAttribute("onclick")||"";const leads=btn.dataset.target==="skills"||oc.includes("''skills''")||oc.includes(''"skills"'')||oc.includes("selectOption(3)");if(!leads)return;if(!btn._uhBaseText){btn._uhBaseText=btn.textContent.replace(/\s*\*\s*/g,"").trim()}const curClean=btn.textContent.replace(/\s*\*\s*/g,"").trim();if(curClean&&curClean!==btn._uhBaseText&&!btn.textContent.includes("*")){btn._uhBaseText=curClean}const base=btn._uhBaseText||"SKILLS";if(hasPts){if(base.startsWith("[")&&base.endsWith("]")){const inner=base.substring(1,base.length-1).trim();btn.textContent="[ "+inner+" * ]"}else{btn.textContent=base+" *"}}else{btn.textContent=base}})}catch(e){}};if(typeof UI!=="undefined"&&typeof UI.switchTab==="function"&&!UI._uhSwitchTabHooked){const origSwitch=UI.switchTab;UI.switchTab=function(){const r=origSwitch.apply(this,arguments);try{UI.updateSkillsIndicator&&UI.updateSkillsIndicator()}catch(e){}return r};UI._uhSwitchTabHooked=!0}if(typeof UI!=="undefined"&&typeof UI.renderSkillTree==="function"&&!UI._uhRenderSkillTreeHooked){const origRenderSkillTree=UI.renderSkillTree;UI.renderSkillTree=function(){const r=origRenderSkillTree.apply(this,arguments);try{UI.updateSkillsIndicator&&UI.updateSkillsIndicator()}catch(e){}return r};UI._uhRenderSkillTreeHooked=!0}if(typeof NavDock!=="undefined"&&typeof NavDock.refresh==="function"&&!NavDock._uhRefreshHooked){const origNavRefresh=NavDock.refresh;NavDock.refresh=function(){const r=origNavRefresh.apply(this,arguments);try{UI.updateSkillsIndicator&&UI.updateSkillsIndicator()}catch(e){}return r};NavDock._uhRefreshHooked=!0}if(typeof InsanityGame!=="undefined"){InsanityGame.enemyTick=function(){};InsanityGame._startAutos=function(){}}if(!window._uhSkillTicker){window._uhSkillTicker=setInterval(()=>{try{UI.updateSkillsIndicator()}catch(e){}},1000)}MiningRig.decryptDrive=function(){let found=!1;if(Game.data&&Game.data.stash){for(const s in Game.data.stash){const it=Game.data.stash[s];if(it&&(it.baseId==="encrypted_drive"||it.id==="encrypted_drive"||it==="encrypted_drive")){Game.removeFromStash(s);found=!0;break}}}if(!found){const inv=("function"==typeof Game.getActiveInventory)?Game.getActiveInventory():null;if(inv){const containers=["pouch","backpackContents","rigContents","pockets"];for(const c of containers){const arr=inv[c];if(arr){for(let i=0;i<arr.length;i++){const it=arr[i];if(it&&(it.baseId==="encrypted_drive"||it.id==="encrypted_drive"||it==="encrypted_drive")){arr[i]=null;found=!0;break}}if(found)break}}}}if(!found){const msg=("function"==typeof T)?T("No Encrypted Drive in Stash or Pouch"):"No Encrypted Drive in Stash or Pouch";if(typeof GlobalNotif!=="undefined")GlobalNotif.show("NO DRIVE DETECTED",msg);if(typeof MenuSFX!=="undefined"&&MenuSFX.error)MenuSFX.error();return}const totalGpus=(typeof MiningRig.getTotalGPUs==="function")?MiningRig.getTotalGPUs():0;const r=Math.random();let s="patch";if(totalGpus>=5){s=r<0.25?"glitch":r<0.70?"kernel":r<0.90?"patch":"anchor"}else if(totalGpus>=1){s=r<0.05?"glitch":r<0.45?"kernel":r<0.85?"patch":"anchor"}else{s=r<0.20?"kernel":r<0.95?"patch":"anchor"}const n=(typeof TechTerminal.generateCode==="function")?TechTerminal.generateCode(s):("CODE-"+Math.floor(Math.random()*9e4+1e4));const vault=Game.data.techCraft.codeVault;const a=s+"Codes";vault[a]=vault[a]||[];let o;if("kernel"===s){const e=Object.keys(AffixDatabase.kernels),t=e[Math.floor(Math.random()*e.length)],a=AffixDatabase.kernels[t];o={code:n,modName:a.nameTag||a.name,groupKey:t}}else if("patch"===s){const e=Object.keys(AffixDatabase.patches),t=e[Math.floor(Math.random()*e.length)],a=AffixDatabase.patches[t];o={code:n,modName:a.nameTag||a.name,groupKey:t}}else if("anchor"===s){o={code:n}}else if("glitch"===s){const e=["Kernel Slot Injection","Clean Patch Swap","Elemental Sync","Echo-Tap Routine","Phantom Implicit","Module Class Flip"];o={code:n,protocol:e[Math.floor(Math.random()*e.length)]}}vault[a].push(o);if(Game.data.lifetimeStats)Game.data.lifetimeStats.codesCollected=(Game.data.lifetimeStats.codesCollected||0)+1;Game.saveData();if(typeof TechTerminal!=="undefined"){TechTerminal.print("","system");TechTerminal.print("========================================","success");TechTerminal.print("  DRIVE DECRYPTED: "+n,"success");TechTerminal.print("  Type: "+s.toUpperCase(),"info");TechTerminal.print("========================================","success");if(TechTerminal.renderCodeVault)TechTerminal.renderCodeVault();if(TechTerminal.updateStatusBar)TechTerminal.updateStatusBar()}if(typeof GlobalNotif!=="undefined"){GlobalNotif.show("DRIVE CRACKED","Extracted ["+s.toUpperCase()+"] code: "+n)}if(typeof GameSFX!=="undefined"&&GameSFX.equip)GameSFX.equip();if(typeof UI!=="undefined"&&UI.renderStash)UI.renderStash()};TechTerminal.sellAllBtc=function(){const btc=Game.data?.techCraft?.miningRig?.btc||0;if(btc<=0){if(typeof GlobalNotif!=="undefined")GlobalNotif.show("NO BTC","Your balance is 0 BTC.");return}const rate=MiningRig.BTC_PRICE_USD||7e4;const payout=Math.floor(btc*rate);Game.data.techCraft.miningRig.btc=0;Game.addMoney(payout);TechTerminal.updateStatusBar();if(TechTerminal.renderGPUGrid)TechTerminal.renderGPUGrid();Game.saveData();if(typeof GlobalNotif!=="undefined"){GlobalNotif.show("BITCOIN CASHOUT","Sold "+btc.toFixed(4)+" BTC for +$"+payout.toLocaleString())}if(typeof MenuSFX!=="undefined"&&MenuSFX.click)MenuSFX.click()};'
            ExpectedCount = 1
        },
        @{
            Name = 'Merge Config & Upgrade Rates'
            Target = 'MERGE_CONFIG={maxLevel:10,infMaxLevel:5,fragCost:5e7,infCost:1e10,modCost:1e6,gearCost:1e9,fragStatChance:10,fragSpecialChance:5,infChance:[15,10,5,4,3],infSpecialLevel:3,infAoeRadius:14,infBlinkRadius:6,infBlinkMax:4,infRiftRadius:8,infRiftMax:5,infMoonPct:30,infExtraDmgPct:50,modChance:[100,85,70,55,45,35,25,18,12,8],gearChance:[100,100,100,80,60,45,35,25,18,12],gearDestroyFrom:6,gearRiskLevelMult:2,techDropPct:5,wardChance:50,wardMoney:5e10,wardBtc:100,wardDropPct:.05,wardMinCL:25e3,fragValMult:e=>1+.5*e,modStatMult:e=>1+.1*e,infDmgPerLvl:100,gearStat:{weapon:{damage:.04,rpm:.015,handling:.02,armorPen:.02,magCapacity:.02,headshotMult:.005,reloadTime:-.01,attackSpeed:.02,staminaCost:-.01,reach:.01},armor:{armor:.03,health:.025}}};'
            Replacement = 'MERGE_CONFIG={maxLevel:10,infMaxLevel:5,fragCost:1e7,infCost:1e9,modCost:1e5,gearCost:1e9,fragStatChance:30,fragSpecialChance:20,infChance:[35,25,20,15,10],infSpecialLevel:3,infAoeRadius:14,infBlinkRadius:6,infBlinkMax:4,infRiftRadius:8,infRiftMax:5,infMoonPct:30,infExtraDmgPct:50,modChance:[100,85,70,55,45,35,25,18,12,8],gearChance:[100,100,100,85,70,55,45,35,25,20],gearDestroyFrom:999,gearRiskLevelMult:2,techDropPct:5,wardChance:50,wardMoney:5e10,wardBtc:100,wardDropPct:.05,wardMinCL:25e3,fragValMult:e=>1+.5*e,modStatMult:e=>1+.1*e,infDmgPerLvl:100,gearStat:{weapon:{damage:.04,rpm:.015,handling:.02,armorPen:.02,magCapacity:.02,headshotMult:.005,reloadTime:-.01,attackSpeed:.02,staminaCost:-.01,reach:.01},armor:{armor:.03,health:.025}}};'
            ExpectedCount = 1
        },
        @{
            Name = 'Mythic Weapon Upgrades Safe Outcome'
            Target = 'rollGearOutcome(e,t){const a=MERGE_CONFIG.gearChance[e-1]||0,s=100*(void 0===t?Math.random():t)<a;return{success:s,chance:a,destroyed:!s&&e>=MERGE_CONFIG.gearDestroyFrom}}'
            Replacement = 'rollGearOutcome(e,t){const a=MERGE_CONFIG.gearChance[e-1]||0,s=100*(void 0===t?Math.random():t)<a;return{success:s,chance:a,destroyed:!1}}'
            ExpectedCount = 1
        },
        @{
            Name = 'Mythic Weapon Upgrades Safety Floor at +5'
            Target = 'else c||r.upgradeLevel>0&&r.upgradeLevel--;l.destroyed||(r.mods=r.mods||[],ItemFactory.applyModsToStats(r))'
            Replacement = 'else c||(r.upgradeLevel=(r.upgradeLevel>=5)?Math.max(5,r.upgradeLevel-1):Math.max(0,(r.upgradeLevel||1)-1));l.destroyed||(r.mods=r.mods||[],ItemFactory.applyModsToStats(r))'
            ExpectedCount = 1
        },
        @{
            Name = 'Fragment Merging Safe Failure'
            Target = '_mergeOnce(e,t,a){Game.data.money-=t;const s=100*Math.random()<a;if(e.isMod){if(!takeMythicModulePlus(e.baseId,e.lvl))return Game.data.money+=t,!1;if(!takeMythicModulePlus(e.baseId,e.lvl))return addMythicModulePlus(e.baseId,e.lvl),Game.data.money+=t,!1;s&&addMythicModulePlus(e.baseId,e.lvl+1)}else s?this._mutateFragMerge(e.srcs[0],e.srcs[1]):(e.srcs[0].remove(),e.srcs[1].remove());return s}'
            Replacement = '_mergeOnce(e,t,a){Game.data.money-=t;const s=100*Math.random()<a;if(e.isMod){if(!takeMythicModulePlus(e.baseId,e.lvl))return Game.data.money+=t,!1;if(!takeMythicModulePlus(e.baseId,e.lvl))return addMythicModulePlus(e.baseId,e.lvl),Game.data.money+=t,!1;s&&addMythicModulePlus(e.baseId,e.lvl+1)}else s?this._mutateFragMerge(e.srcs[0],e.srcs[1]):e.srcs[1].remove();return s}'
            ExpectedCount = 1
        },
        @{
            Name = 'Fragment Merging Confirm Modal Label'
            Target = '{label:"On failure",value:"BOTH inputs are destroyed",color:"#ef4444"}'
            Replacement = '{label:"On failure",value:"Secondary copy consumed (Base preserved)",color:"#eab308"}'
            ExpectedCount = 1
        },
        @{
            Name = 'Fragment Merging Failure Notification'
            Target = '(MenuSFX.error?.(),GlobalNotif.show("MERGE FAILED",''<span style="color:#ef4444">Both inputs were destroyed.</span>''))'
            Replacement = '(MenuSFX.error?.(),GlobalNotif.show("MERGE FAILED",''<span style="color:#ef4444">Secondary copy consumed. Base preserved!</span>''))'
            ExpectedCount = 1
        },
        @{
            Name = 'ItemBases: Add Encrypted Military Drive'
            Target = 'const ItemBases={test_weapon:{'
            Replacement = 'const ItemBases={encrypted_drive:{id:"encrypted_drive",baseId:"encrypted_drive",name:"Encrypted Military Drive",type:"intel",subtype:"intel",tier:"custom",value:5e4,weight:.2,width:1,height:1,desc:"A hardened military storage module recovered from raid operations. Can be cracked instantly at the Mining Rig Decryption Station for guaranteed crafting codes.",icon:"💾"},test_weapon:{'
            ExpectedCount = 1
        },
        @{
            Name = 'Raid POI Drop: Encrypted Military Drive (15% chance)'
            Target = 'if(this.currentRarityBonus=0,!e._scavBonusGiven&&this._mythicArmorAbility("m_scavenger_core"))'
            Replacement = 'if(Math.random()<0.15){const dItem=JSON.parse(JSON.stringify(ItemBases.encrypted_drive));dItem.id="encrypted_drive_"+Date.now()+"_"+Math.floor(Math.random()*1000);this.lootingItems.push(dItem);}if(this.currentRarityBonus=0,!e._scavBonusGiven&&this._mythicArmorAbility("m_scavenger_core"))'
            ExpectedCount = 1
        },
        @{
            Name = 'Raid Boss Drop: Encrypted Military Drive (100% chance)'
            Target = 'if(this._addEnemyDrop(e,h),"ironfall_perimeter"===t&&getCurrentCL(t)>=10)'
            Replacement = 'if(e.isBoss||e.isWarden){const dItem=JSON.parse(JSON.stringify(ItemBases.encrypted_drive));dItem.id="encrypted_drive_"+Date.now();this._addEnemyDrop(e,dItem);}if(this._addEnemyDrop(e,h),"ironfall_perimeter"===t&&getCurrentCL(t)>=10)'
            ExpectedCount = 1
        },
        @{
            Name = 'Mining Rig: 15x BTC Production Rate'
            Target = 'MiningRig={BTC_PRICE_USD:7e4,BTC_PER_GPU_PER_MINUTE:1e-4,tickIntervalId:null,'
            Replacement = 'MiningRig={BTC_PRICE_USD:7e4,BTC_PER_GPU_PER_MINUTE:1.5e-3,tickIntervalId:null,'
            ExpectedCount = 1
        },
        @{
            Name = 'Mining Rig: 75% Fuel Drain Reduction'
            Target = 'const o=a.fuelDrainPerMinute*i;a.fuel=Math.max(0,a.fuel-o);'
            Replacement = 'const o=(a.fuelDrainPerMinute||1)*0.25*i;a.fuel=Math.max(0,a.fuel-o);'
            ExpectedCount = 1
        },
        @{
            Name = 'Mining Rig UI: Quick Sell BTC & Decrypt Station Buttons'
            Target = '<button class="mining-ctrl-btn" data-target="patch" onclick="TechTerminal.setSearchTarget(''patch'')">[PATCH]</button>
                                        </div>'
            Replacement = '<button class="mining-ctrl-btn" data-target="patch" onclick="TechTerminal.setSearchTarget(''patch'')">[PATCH]</button>
                                            <button id="uhSellBtcBtn" class="mining-ctrl-btn" style="color:#ffd700;border-color:#ffd700;margin-left:6px;" onclick="TechTerminal.sellAllBtc()">[ SELL ALL BTC ]</button>
                                            <button id="uhDecryptDriveBtn" class="mining-ctrl-btn" style="color:#00ff41;border-color:#00ff41;margin-left:6px;" onclick="MiningRig.decryptDrive()">[ DECRYPT MILITARY DRIVE ]</button>
                                        </div>'
            ExpectedCount = 1
        },
        @{
            Name = 'Mining Rig UI: Status Bar Live Dynamic Updates'
            Target = 'const t=document.getElementById("terminal-btc-value"),a=document.getElementById("terminal'
            Replacement = 'const sB=document.getElementById("uhSellBtcBtn");if(sB){const b=e.miningRig?.btc||0,p=Math.floor(b*(MiningRig.BTC_PRICE_USD||7e4)),l="function"==typeof T?T("SELL ALL BTC"):"SELL ALL BTC";sB.textContent="[ "+l+" (+$"+p.toLocaleString()+") ]";sB.style.opacity=b>0?"1":"0.5";}const dB=document.getElementById("uhDecryptDriveBtn");if(dB&&"function"==typeof T){dB.textContent="[ "+T("DECRYPT MILITARY DRIVE")+" ]";}const t=document.getElementById("terminal-btc-value"),a=document.getElementById("terminal'
            ExpectedCount = 1
        },
        @{
            Name = 'Raid Extraction: In-Raid Insanity Harvest & Summary Display'
            Target = 'let i=t("ITEMS LOOTED",this.stats.itemsLooted)+t("HOSTILES DOWN",this.stats.enemiesKilled)+t("LOOT VALUE","$"+(this.lootValue||0).toLocaleString(),"#FFD700")'
            Replacement = 'let insHarvested=0;if(e){const mT=(void 0!==MAP_DEFS&&MAP_DEFS[this.currentMapId]?.tier)||1,cL=("function"==typeof getCurrentCL)?getCurrentCL(this.currentMapId):0,bIns=150*mT*(1+0.1*Math.max(0,cL)),kIns=15*(this.stats?.enemiesKilled||0),hB=this.enemies&&this.enemies.some(en=>(en.isBoss||en.isWarden)&&en.dead)?600:0,fC=this.enemies&&this.enemies.length>0&&this.enemies.every(en=>en.dead)?250:0,pM=1+0.15*(Game.data?.prestige||0);insHarvested=Math.round((bIns+kIns+hB+fC)*pM);if(Game.data?.signalCorruption){Game.data.signalCorruption.insanity=(Game.data.signalCorruption.insanity||0)+insHarvested;Game._saveDirty=!0;}}this.stats.insanityGained=insHarvested;let i=t("ITEMS LOOTED",this.stats.itemsLooted)+t("HOSTILES DOWN",this.stats.enemiesKilled)+t("LOOT VALUE","$"+(this.lootValue||0).toLocaleString(),"#FFD700")+(e&&insHarvested>0?t("function"==typeof T?T("INSANITY HARVESTED"):"INSANITY HARVESTED","+"+insHarvested.toLocaleString(),"#c084fc"):"")'
            ExpectedCount = 1
        },
        @{
            Name = 'Insanity Caches Rebalance (Exclusive Raid Gear, Flux & Tech Economy)'
            Target = 'IG_CACHES={seed:{name:"SEED CACHE",cost:25e3,costCur:"money",color:"#00ff41",desc:"Pure insanity, paid in credits",dropW:0,dropLvl:1,table:[{w:50,kind:"ins",min:25,max:60},{w:30,kind:"ins",min:60,max:110},{w:15,kind:"ins",min:110,max:160},{w:5,kind:"ins",min:160,max:200}]},scrap:{name:"SCRAP CACHE",cost:150,color:"#9ca3af",desc:"Mixed low-tier gear + boosts",dropW:35,dropLvl:1,table:[{w:30,kind:"item",type:"any",rar:{standard:60,enhanced:30,custom:10}},{w:25,kind:"ins",min:30,max:80},{w:45,kind:"boost"}]},armory:{name:"ARMORY CACHE",cost:400,color:"#ffe14d",desc:"Weapons only",dropW:20,dropLvl:15,table:[{w:80,kind:"item",type:"weapon",rar:{standard:25,enhanced:35,custom:25,glitch:12,prototype:3}},{w:20,kind:"ins",min:60,max:150}]},aegis:{name:"AEGIS CACHE",cost:400,color:"#4dd8ff",desc:"Armor only",dropW:20,dropLvl:15,table:[{w:80,kind:"item",type:"armor",rar:{standard:25,enhanced:35,custom:25,glitch:12,prototype:3}},{w:20,kind:"ins",min:60,max:150}]},power:{name:"POWER CACHE",cost:800,color:"#a855f7",desc:"Boosts + permanent powers",dropW:15,dropLvl:25,table:[{w:62,kind:"boost"},{w:20,kind:"ins",min:100,max:250},{w:18,kind:"perma"}]},proto:{name:"PROTO CACHE",cost:1500,color:"#ff9d3d",desc:"High prototype odds",dropW:8,dropLvl:45,table:[{w:90,kind:"item",type:"any",rar:{custom:50,glitch:40,prototype:10}},{w:10,kind:"ins",min:150,max:300}]},mythic:{name:"MYTHIC CACHE",cost:4e3,color:"#ff4d4d",desc:"2% MYTHIC roll",dropW:2,dropLvl:70,req:{prestige:9,cl:7},table:[{w:980,kind:"item",type:"any",rar:{custom:20,glitch:55,prototype:25}},{w:20,kind:"item",type:"any",rar:{mythic:100}}]}};'
            Replacement = 'IG_CACHES={seed:{name:"SEED CACHE",cost:25e3,costCur:"money",color:"#00ff41",desc:"Pure insanity, paid in credits",dropW:0,dropLvl:1,table:[{w:50,kind:"ins",min:25,max:60},{w:30,kind:"ins",min:60,max:110},{w:15,kind:"ins",min:110,max:160},{w:5,kind:"ins",min:160,max:200}]},scrap:{name:"SCRAP CACHE",cost:150,color:"#9ca3af",desc:"Mixed gear, materials & flux",dropW:35,dropLvl:1,table:[{w:40,kind:"item",type:"any",rar:{standard:60,enhanced:30,custom:10}},{w:30,kind:"ins",min:30,max:80},{w:30,kind:"flux",amount:200,color:"#4dd8ff"}]},armory:{name:"ARMORY CACHE",cost:400,color:"#ffe14d",desc:"Weapons (Standard to Custom)",dropW:20,dropLvl:15,table:[{w:80,kind:"item",type:"weapon",rar:{standard:40,enhanced:45,custom:15}},{w:20,kind:"ins",min:60,max:150}]},aegis:{name:"AEGIS CACHE",cost:400,color:"#4dd8ff",desc:"Armor (Standard to Custom)",dropW:20,dropLvl:15,table:[{w:80,kind:"item",type:"armor",rar:{standard:40,enhanced:45,custom:15}},{w:20,kind:"ins",min:60,max:150}]},power:{name:"POWER CACHE",cost:800,color:"#a855f7",desc:"High flux, crafting intel & insanity",dropW:15,dropLvl:25,table:[{w:45,kind:"flux",amount:1000,color:"#4dd8ff"},{w:35,kind:"ins",min:200,max:500},{w:20,kind:"currency",id:"military_chip",amount:1,color:"#38bdf8"}]},proto:{name:"PROTO CACHE",cost:1500,color:"#ff9d3d",desc:"Tech drives & corruption bundles",dropW:8,dropLvl:45,table:[{w:35,kind:"currency",id:"tech_drive_flash",amount:2,color:"#38bdf8"},{w:35,kind:"currency",id:"tech_part_expansion",amount:1,color:"#a855f7"},{w:30,kind:"ins",min:500,max:1500}]},mythic:{name:"MYTHIC CACHE",cost:4e3,color:"#ff4d4d",desc:"Kernel chips, $1.5M & Abyss flux",dropW:2,dropLvl:70,req:{prestige:9,cl:7},table:[{w:40,kind:"currency",id:"tech_chip_kernel",amount:1,color:"#ef4444"},{w:35,kind:"money",amount:15e5,color:"#ffd700"},{w:25,kind:"flux",amount:5e3,color:"#c084fc"}]}};'
            ExpectedCount = 1
        },
        @{
            Name = 'Insanity Cache Rewards: Material & Currency Support'
            Target = 'const a=e.min+Math.floor(Math.random()*(e.max-e.min+1));return{kind:"ins",ins:a,icon:"◈",color:"#a855f7",label:"+"+a+" INSANITY"}'
            Replacement = 'if("currency"===e.kind)return{kind:"currency",id:e.id,amount:e.amount||1,icon:"◈",color:e.color||"#00ff41",label:(e.amount>1?e.amount+"× ":"")+(window.Items?.[e.id]?.name||e.id)};if("money"===e.kind)return{kind:"money",amount:e.amount,icon:"$",color:"#ffd700",label:"+$"+(e.amount||0).toLocaleString()};if("flux"===e.kind)return{kind:"flux",amount:e.amount,icon:"◈",color:"#4dd8ff",label:"+"+(e.amount||0).toLocaleString()+" FLUX"};const a=e.min+Math.floor(Math.random()*(e.max-e.min+1));return{kind:"ins",ins:a,icon:"◈",color:"#a855f7",label:"+"+a+" INSANITY"}'
            ExpectedCount = 1
        },
        @{
            Name = 'Insanity Cache Claim: Add Currency, Money & Flux'
            Target = 'let s=e.label;return"item"===e.kind?this._applyItemBatch([e],!1)[0]:("boost"===e.kind?this.addBoost(e.id):"perma"===e.kind?(t.perma[e.id]=(t.perma[e.id]||0)+1,this._recalcStats(),this._caseBatch||(this.renderStats(),this.renderBuffs()),"p_auto"===e.id&&this._startAutos()):"ins"===e.kind&&(a.insanity=(a.insanity||0)+e.ins,'
            Replacement = 'let s=e.label;return"item"===e.kind?this._applyItemBatch([e],!1)[0]:("boost"===e.kind?this.addBoost(e.id):"perma"===e.kind?(t.perma[e.id]=(t.perma[e.id]||0)+1,this._recalcStats(),this._caseBatch||(this.renderStats(),this.renderBuffs()),"p_auto"===e.id&&this._startAutos()):"currency"===e.kind?(Game.addCurrency(e.id,e.amount||1),{txt:e.label,color:e.color||"#00ff41"}):"money"===e.kind?(Game.addMoney(e.amount),{txt:e.label,color:"#ffd700"}):"flux"===e.kind?(a.flux=(a.flux||0)+e.amount,{txt:e.label,color:"#4dd8ff"}):"ins"===e.kind&&(a.insanity=(a.insanity||0)+e.ins,'
            ExpectedCount = 1
        },
        @{
            Name = 'Signal Corruption Nexus: UI Dashboard & Sub-Tabs Overhaul'
            Target = '<div id="view-insanity" class="flex-1 hidden relative min-h-0">
            <div class="ig-root">
                <div class="ig-arena" id="igArena">
                    <div class="ig-topbar">
                        <span style="display:flex;align-items:center;gap:10px;">
                            <div class="ig-statwrap" onmouseenter="InsanityGame.bumpPanel(''igStats'')">
                                <button class="ig-back" type="button">STATS ▾</button>
                                <div class="ig-statpanel" id="igStats"></div>
                            </div>
                            <div class="ig-statwrap">
                                <button class="ig-back" type="button" id="igFilterBtn" onclick="InsanityGame.toggleFilterMenu()">FILTER ▾</button>
                                <div class="ig-fxmenu hidden" id="igFilterMenu">
                                    <div class="ig-fxrow" onclick="InsanityGame.toggleSkipBoss()"><span>BOSS SKIP</span><span id="igSkipBoss">OFF</span></div>
                                    <div class="ig-filterdesc">Boss layers rewind to checkpoint instantly (farm mode). No boss kills, no boss cache drops.</div>
                                </div>
                            </div>
                            <div class="ig-statwrap">
                                <button class="ig-back ig-gear" onclick="InsanityGame.toggleFxMenu()" title="Effects">⚙</button>
                                <div class="ig-fxmenu hidden" id="igFxMenu">
                                    <div class="ig-fxrow" onclick="InsanityGame.toggleFx(''shake'')"><span>SCREEN SHAKE</span><span id="igFxShake">ON</span></div>
                                    <div class="ig-fxrow" onclick="InsanityGame.toggleFx(''flash'')"><span>GLITCH FLASH</span><span id="igFxFlash">ON</span></div>
                                    <div class="ig-fxrow" onclick="InsanityGame.cycleTextScale()"><span>TEXT SIZE</span><span id="igFxText">115%</span></div>
                                </div>
                            </div>
                        </span>
                        <span class="ig-title">░▒▓ INSANITY ▓▒░</span>
                        <span style="display:flex;align-items:center;gap:10px;">
                            <span class="ig-layerjump" id="igLayerJump"><button class="ig-back" onclick="InsanityGame.openLayerInput()" title="Jump to any layer you have reached this cycle">SELECT LAYER</button></span>
                            <span class="ig-lvl" id="igLevel">LAYER 1</span>
                        </span>
                    </div>
                    <div class="ig-progress" id="igProgress"></div>
                    <div class="ig-announce" id="igAnnounce"></div>
                    <div class="ig-buffs" id="igBuffs"></div>
                    <div class="ig-caseoverlay hidden" id="igCase">
                        <div class="ig-casename" id="igCaseName"></div>
                        <div class="ig-reelstack" id="igReelStack"></div>
                        <div class="ig-caseresult" id="igCaseResult"></div>
                        <div class="ig-casebtns">
                            <button class="ig-btn ig-caseclose hidden" id="igCaseAgain" onclick="InsanityGame.openAgain()">OPEN AGAIN</button>
                            <button class="ig-btn ig-caseclose hidden" id="igCaseClose" onclick="InsanityGame.closeCase()">CLOSE</button>
                        </div>
                    </div>
                    <div class="ig-enemybox" id="igEnemyBox">
                        <div class="ig-ename" id="igEnemyName">???</div>
                        <pre class="ig-eart" id="igEnemyArt"></pre>
                        <div class="ig-ehpbar"><div class="ig-ehpfill" id="igEnemyHpFill"></div><span class="ig-ehptext" id="igEnemyHpText"></span></div>
                    </div>
                    <div class="ig-combo" id="igCombo"></div>
                    <div class="ig-bottombar">
                        <span class="ig-cp" id="igCheckpoint">CHECKPOINT: 1</span>
                        <div class="ig-phpbar"><div class="ig-phpfill" id="igPlayerHpFill"></div><span class="ig-phptext" id="igPlayerHpText"></span></div>
                    </div>
                    <div class="ig-deathveil hidden" id="igDeath">SIGNAL LOST</div>
                </div>
                <div class="ig-side">
                    <div class="ig-wallet">
                        <div class="ig-wrow"><span>CREDITS</span><span id="igMoney">$0</span></div>
                        <div class="ig-wrow ig-ins"><span>INSANITY</span><span id="igIns">0</span></div>
                    </div>
                    <div class="ig-shop" id="igRebirth"></div>
                    <div class="ig-shop" id="igShop"></div>
                    <div class="ig-shop" id="igCaches"></div>
                </div>
            </div>
        </div>

        
        <div id="view-traders"'
            Replacement = '<div id="view-insanity" class="flex-1 flex flex-col min-h-0 relative hidden">
            <div class="terminal-main-container">
                <div class="terminal-header">
                    <div class="terminal-tabs">
                        <button id="nexusTabBtnMastery" class="terminal-tab active" onclick="InsanityGame.switchNexusView(''mastery'')">MADNESS PROTOCOL</button>
                        <button id="nexusTabBtnCaches" class="terminal-tab" onclick="InsanityGame.switchNexusView(''caches'')">SIGNAL CACHES</button>
                    </div>
                    <div class="terminal-status-bar">
                        <div class="terminal-status-item">
                            <span class="label">INSANITY</span>
                            <span class="value" id="nexusInsanityVal">0</span>
                        </div>
                        <div class="terminal-status-item">
                            <span class="label">FLUX</span>
                            <span class="value" id="nexusFluxVal">0</span>
                        </div>
                        <div class="terminal-status-item">
                            <span class="label">HOLLOW CROWN</span>
                            <span class="value" id="nexusHollowCrownBadge" title="0/50 Wardens Slain">TIER 0</span>
                        </div>
                        <div class="terminal-status-item">
                            <span class="label">SIN FRENZY</span>
                            <span class="value" id="nexusFrenzyBadge" title="0 / 20,000 Insanity">+0%</span>
                        </div>
                    </div>
                </div>

                <div class="terminal-tab-content active" id="terminal-tab-nexus-main" style="flex:1;overflow-y:auto;padding:calc(16px * var(--ui-scale, 1));display:flex;flex-direction:column;min-height:0;position:relative;">
                    <!-- Sub-View 1: Madness Protocol -->
                    <div id="nexusMasteryContent" style="display:block;max-width:1150px;width:100%;margin:0 auto;"></div>

                    <!-- Sub-View 2: Signal Caches Grid -->
                    <div id="nexusCachesContent" style="display:none;max-width:1000px;width:100%;margin:0 auto;">
                        <div id="igCaches" style="display:flex;flex-direction:column;gap:calc(10px * var(--ui-scale, 1));"></div>
                    </div>

                    <!-- Case Opening Overlay -->
                    <div class="ig-caseoverlay hidden" id="igCase">
                        <div class="ig-casename" id="igCaseName"></div>
                        <div class="ig-reelstack" id="igReelStack"></div>
                        <div class="ig-caseresult" id="igCaseResult"></div>
                        <div class="ig-casebtns">
                            <button class="ig-btn ig-caseclose hidden" id="igCaseAgain" onclick="InsanityGame.openAgain()">OPEN AGAIN</button>
                            <button class="ig-btn ig-caseclose hidden" id="igCaseClose" onclick="InsanityGame.closeCase()">CLOSE</button>
                        </div>
                    </div>
                </div>
            </div>
        </div>

        
        <div id="view-traders"'
            ExpectedCount = 1
        },
        @{
            Name = 'Communion Branch: Raid-Anchored Mastery Talents Rework'
            Target = 'sin_siphon:{branch:"communion",name:"SIN SIPHON",desc:"+5% INSANITY gain per rank",base:300,maxRank:10},lucid_night:{branch:"communion",name:"LUCID NIGHTMARE",desc:"+5% INSANITY click damage per rank",base:300,maxRank:10},blood_tithe:{branch:"communion",name:"BLOOD TITHE",desc:"+2% chance per rank that raid kills grant +1 insanity",base:500,maxRank:10},golden_mad:{branch:"communion",name:"GOLDEN MADNESS",desc:"+0.5% golden enemy chance per rank",base:600,maxRank:10},cache_inst:{branch:"communion",name:"CACHE INSTINCT",desc:"+1% boss cache drop chance per rank",base:500,maxRank:10},rigged_coin:{branch:"communion",name:"RIGGED COIN",desc:"+1% trader coin flip chance per rank",base:400,maxRank:10},crown_edge:{branch:"communion",name:"CROWN''S EDGE",desc:"Each HOLLOW CROWN tier grants +5% trader sell price",base:2500,maxRank:1,capstone:!0},crown_reso:{branch:"communion",name:"CROWN RESONANCE",desc:"Each HOLLOW CROWN tier grants +2% INSANITY click damage",base:2500,maxRank:1,capstone:!0},void_bargain:{branch:"communion",name:"VOID BARGAIN",desc:"Seed cache -20% cost, rebirth insanity cost -10%",base:5e3,maxRank:1,capstone:!0,requires:{sin_siphon:5}}}'
            Replacement = 'sin_siphon:{branch:"communion",name:"SIN SIPHON",desc:"+5% INSANITY gain per rank",base:300,maxRank:10},signal_reso:{branch:"communion",name:"SIGNAL RESONANCE",desc:"+3% movement & sprint speed in raids per rank",base:300,maxRank:10},blood_tithe:{branch:"communion",name:"BLOOD TITHE",desc:"+2% chance per rank that raid kills grant +1 insanity",base:500,maxRank:10},scav_eye:{branch:"communion",name:"SCAVENGER''S EYE",desc:"+2% chance per rank to find high-rarity loot containers",base:600,maxRank:10},cache_inst:{branch:"communion",name:"CACHE INSTINCT",desc:"+1% boss cache drop chance per rank",base:500,maxRank:10},rigged_coin:{branch:"communion",name:"RIGGED COIN",desc:"+1% trader coin flip chance per rank",base:400,maxRank:10},crown_edge:{branch:"communion",name:"CROWN''S EDGE",desc:"Each HOLLOW CROWN tier grants +5% trader sell price",base:2500,maxRank:1,capstone:!0},eldritch_surge:{branch:"communion",name:"ELDRITCH SURGE",desc:"Medical items heal an additional +15% over 5s",base:2500,maxRank:1,capstone:!0},corrupt_bargain:{branch:"communion",name:"CORRUPTED BARGAIN",desc:"All Signal Caches cost -15% (credits and insanity)",base:5e3,maxRank:1,capstone:!0,requires:{sin_siphon:5}}}'
            ExpectedCount = 1
        },
        @{
            Name = 'InsanityTree: Permanent Unlock & Node Migration'
            Target = 'InsanityTree={_fx:null,rank:e=>Game.data.insanityTree&&Game.data.insanityTree.nodes&&Game.data.insanityTree.nodes[e]||0,unlocked:()=>(Game.data.insanityGame?.rb?.count||0)>=1,'
            Replacement = 'InsanityTree={_fx:null,rank:e=>{if(!Game.data.insanityTree||!Game.data.insanityTree.nodes)return 0;const n=Game.data.insanityTree.nodes;if(n.lucid_night){n.signal_reso=(n.signal_reso||0)+n.lucid_night;delete n.lucid_night;}if(n.golden_mad){n.scav_eye=(n.scav_eye||0)+n.golden_mad;delete n.golden_mad;}if(n.crown_reso){n.eldritch_surge=(n.eldritch_surge||0)+n.crown_reso;delete n.crown_reso;}if(n.void_bargain){n.corrupt_bargain=(n.corrupt_bargain||0)+n.void_bargain;delete n.void_bargain;}return n[e]||0;},unlocked:()=>!0,'
            ExpectedCount = 1
        },
        @{
            Name = 'InsanityTree: Effects Rework'
            Target = 'return this._fx={raidDmg:.02*e("rage_signal"),headshot:.1*e("dead_calm"),rpm:.02*e("trigger_disc"),reload:Math.min(.3,.03*e("fast_hands")),hp:.02*e("thick_skin"),ac:2*e("plated_husk"),eva:2*e("ghost_step"),dmgTaken:e("dulled_pain"),igIns:.05*e("sin_siphon"),igDmg:.05*e("lucid_night"),bloodTithe:.02*e("blood_tithe"),igGold:.005*e("golden_mad"),igCache:.01*e("cache_inst"),crownReso:e("crown_reso")>0,voidBargain:e("void_bargain")>0,sinFrenzy:e("sin_frenzy")>0,wardenDmg:.05*e("wardens_bane"),bloodDebt:e("blood_debt")>0,hollowShell:e("hollow_shell")>0,riggedCoin:.01*e("rigged_coin"),crownEdge:e("crown_edge")>0},this._fx'
            Replacement = 'return this._fx={raidDmg:.02*e("rage_signal"),headshot:.1*e("dead_calm"),rpm:.02*e("trigger_disc"),reload:Math.min(.3,.03*e("fast_hands")),hp:.02*e("thick_skin"),ac:2*e("plated_husk"),eva:2*e("ghost_step"),dmgTaken:e("dulled_pain"),igIns:.05*e("sin_siphon"),signalReso:.03*e("signal_reso"),bloodTithe:.02*e("blood_tithe"),scavEye:.02*e("scav_eye"),igCache:.01*e("cache_inst"),eldritchSurge:e("eldritch_surge")>0,corruptBargain:e("corrupt_bargain")>0,sinFrenzy:e("sin_frenzy")>0,wardenDmg:.05*e("wardens_bane"),bloodDebt:e("blood_debt")>0,hollowShell:e("hollow_shell")>0,riggedCoin:.01*e("rigged_coin"),crownEdge:e("crown_edge")>0},this._fx'
            ExpectedCount = 1
        },
        @{
            Name = 'InsanityTree: canAllocate Unlock'
            Target = 'if(!this.unlocked())return{can:!1,reason:"REBIRTH TO UNLOCK"};'
            Replacement = '/* Unlocked permanently */'
            ExpectedCount = 1
        },
        @{
            Name = 'InsanityTree: allocate & respec Nexus Sync'
            Target = 'this.invalidate(),Game.invalidateStats(),MenuSFX.click&&MenuSFX.click(),Game.saveData(),this.renderUI(),!0)'
            Replacement = 'this.invalidate(),Game.invalidateStats(),MenuSFX.click&&MenuSFX.click(),Game.saveData(),(void 0!==InsanityGame&&InsanityGame.updateNexusHeader&&InsanityGame.updateNexusHeader()),this.renderUI(),!0)'
            ExpectedCount = 1
        },
        @{
            Name = 'InsanityTree: renderUI Dual Mount Start'
            Target = 'renderUI(){const e=document.getElementById("madnessProtocolContent");if(!e)return;const t=Game.data.signalCorruption?.insanity||0,a=Game.data.signalCorruption?.flux||0;if(!this.unlocked())return void(e.innerHTML=''\n                        <div class="mastery-header"><span class="mastery-header-title">MADNESS PROTOCOL</span></div>\n                        <div class="mastery-locked-text" style="margin-top:calc(20px * var(--ui-scale, 1));">// SIGNAL TOO WEAK</div>\n                        <div class="mastery-locked-hint">Complete your first REBIRTH in the INSANITY terminal to attune.<br>Permanent upgrades bought with insanity.</div>\n                        <div class="mastery-locked-status">LOCKED</div>'');'
            Replacement = 'renderUI(){const targets=[document.getElementById("madnessProtocolContent"),document.getElementById("nexusMasteryContent")].filter(Boolean);if(!targets.length)return;const t=Game.data.signalCorruption?.insanity||0,a=Game.data.signalCorruption?.flux||0;'
            ExpectedCount = 1
        },
        @{
            Name = 'InsanityTree: renderUI Template Var'
            Target = '},i=Object.values(Game.data.insanityTree?.nodes||{}).some(e=>e>0);e.innerHTML=`\n                    <div class="mastery-header">\n                        <span class="mastery-header-title" style="color:#a855f7;">MADNESS PROTOCOL</span>\n                        <span style="display:flex;gap:calc(12px * var(--ui-scale, 1));align-items:center;">\n                            <span class="mastery-header-flux" style="color:#a855f7;">INSANITY: ${t.toLocaleString()}</span>\n                            <span class="mastery-header-flux">FLUX: ${a.toLocaleString()}</span>\n                        </span>\n                    </div>\n                    <div style="color:rgba(168,85,247,0.45);font-size:calc(10px * var(--font-scale, 1));margin-bottom:calc(10px * var(--ui-scale, 1));">\n                        > Permanent upgrades bought with INSANITY &middot; rank cost grows &times;1.35 &middot; earned in the INSANITY terminal\n                    </div>\n                    <div style="display:flex;gap:calc(12px * var(--ui-scale, 1));align-items:flex-start;">\n                        ${[{key:"carnage",label:"CARNAGE // OFFENSE",color:"#ff4d4d"},{key:"husk",label:"HUSK // DEFENSE",color:"#4dd8ff"},{key:"communion",label:"COMMUNION // SYNERGY",color:"#a855f7"}]'
            Replacement = '},i=Object.values(Game.data.insanityTree?.nodes||{}).some(e=>e>0);const htmlContent=`\n                    <div style="display:flex;gap:calc(12px * var(--ui-scale, 1));align-items:flex-start;">\n                        ${[{key:"carnage",label:"CARNAGE // OFFENSE",color:"#ff4d4d"},{key:"husk",label:"HUSK // DEFENSE",color:"#4dd8ff"},{key:"communion",label:"COMMUNION // SYNERGY",color:"#00ff41"}]'
            ExpectedCount = 1
        },
        @{
            Name = 'InsanityTree: renderUI End targets.forEach'
            Target = '${this.RESPEC_COST.toLocaleString()} FLUX</button>\n                        </div>`:""}`}},MENTOR_TASKS='
            Replacement = '${this.RESPEC_COST.toLocaleString()} FLUX</button>\n                        </div>`:""}`;targets.forEach(el=>{el.innerHTML=htmlContent;});}},MENTOR_TASKS='
            ExpectedCount = 1
        },
        @{
            Name = 'Hollow Crown & Nexus Navigation in InsanityGame'
            Target = 'crownTier(){return Math.min(IG_CONST.CROWN_MAX,Math.floor(this.g().rb.count/IG_CONST.CROWN_STEP))}'
            Replacement = 'crownTier(){const w=Game.data?.signalCorruption?.stats?.wardensDefeated||0;return Math.min(IG_CONST.CROWN_MAX,Math.floor(w/5))},switchNexusView(view){this._nexusView=view||"mastery";const mTab=document.getElementById("nexusTabBtnMastery"),cTab=document.getElementById("nexusTabBtnCaches"),mContent=document.getElementById("nexusMasteryContent"),cContent=document.getElementById("nexusCachesContent");if(mTab&&cTab){if(this._nexusView==="mastery"){mTab.classList.add("active");cTab.classList.remove("active");if(mContent)mContent.style.display="block";if(cContent)cContent.style.display="none";if(void 0!==InsanityTree)InsanityTree.renderUI();}else{cTab.classList.add("active");mTab.classList.remove("active");if(mContent)mContent.style.display="none";if(cContent)cContent.style.display="block";this.renderCaches();}}this.updateNexusHeader();},updateNexusHeader(){const ins=Game.data?.signalCorruption?.insanity||0,flux=Game.data?.signalCorruption?.flux||0,insEl=document.getElementById("nexusInsanityVal"),fluxEl=document.getElementById("nexusFluxVal");if(insEl)insEl.textContent=ins.toLocaleString();if(fluxEl)fluxEl.textContent=flux.toLocaleString();const fz=document.getElementById("nexusFrenzyBadge");if(fz){const fzPct=Math.min(20,Math.floor(ins/1e3));fz.textContent="+"+fzPct+"%";fz.title=ins.toLocaleString()+" / 20,000 Insanity (+"+fzPct+"% Raid DMG)";fz.style.color=fzPct>0?"#ffd700":"#00ff41";}const cr=document.getElementById("nexusHollowCrownBadge");if(cr){const cT=this.crownTier(),w=Game.data?.signalCorruption?.stats?.wardensDefeated||0;cr.textContent=(cT>0?"TIER "+(this._CROWN_ROMAN[cT]||cT):"TIER 0")+(cT>0?" (+"+(cT*10)+"%)":"");cr.title=w+"/50 Wardens Slain (+"+(cT*10)+"% Raid DMG)";cr.style.color=cT>0?"#ffd700":"#00ff41";}}'
            ExpectedCount = 1
        },
        @{
            Name = 'InsanityGame.enter Nexus Initializer'
            Target = 'enter(){if(this.active)return;this._syncBoostClock();'
            Replacement = 'enter(){if(this.active)return;this.active=!0;this.updateNexusHeader();this.switchNexusView(this._nexusView||"mastery");return;this._syncBoostClock();'
            ExpectedCount = 1
        },
        @{
            Name = 'Corrupted Bargain Cache Discount in InsanityGame._cacheCost'
            Target = '_cacheCost(e){const t=IG_CACHES[e];return"seed"===e&&this._mfx().voidBargain?Math.round(.8*t.cost):t.cost}'
            Replacement = '_cacheCost(e){const t=IG_CACHES[e];if(!t)return 0;return this._mfx().corruptBargain?Math.round(.85*t.cost):t.cost}'
            ExpectedCount = 1
        },
        @{
            Name = 'Game.getStats Hollow Crown & Perks Wiring'
            Target = 't.sinFrenzy&&e.damage>0){const t=Math.min(20,Math.floor((Game.data.signalCorruption?.insanity||0)/1e3));e._sfBucket=t,t>0&&(e.damage=Math.floor(e.damage*(1+.01*t)))}'
            Replacement = 't.sinFrenzy&&e.damage>0){const t=Math.min(20,Math.floor((Game.data.signalCorruption?.insanity||0)/1e3));e._sfBucket=t,t>0&&(e.damage=Math.floor(e.damage*(1+.01*t)))}const cT=(void 0!==InsanityGame&&"function"==typeof InsanityGame.crownTier)?InsanityGame.crownTier():0;cT>0&&e.damage>0&&(e.damage=Math.floor(e.damage*(1+0.1*cT)));t.signalReso>0&&(e.spd=(e.spd||0)+Math.round(t.signalReso*100));t.scavEye>0&&(e.loot_rarity=(e.loot_rarity||1)*(1+t.scavEye));t.eldritchSurge&&(e.eldritchSurge=!0);'
            ExpectedCount = 1
        },
        @{
            Name = 'Eldritch Surge Healing Boost'
            Target = 'this.isHealing=!0,this.healingItem=e,this.healingPart=t,this.healingAmount=a,'
            Replacement = 'if(void 0!==InsanityTree&&"function"==typeof InsanityTree.effects&&InsanityTree.effects().eldritchSurge){a=Math.round(a*1.15);}this.isHealing=!0,this.healingItem=e,this.healingPart=t,this.healingAmount=a,'
            ExpectedCount = 1
        },
        @{
            Name = 'InsanityGame.openCache: Always Open Max Simultaneously'
            Target = 'openCache(e){const t=this.g(),a=IG_CACHES[e];if(this._caseSpinning||!a||(t.caches[e]||0)<1)return;if(!this._cacheReqOk(a))return void MenuSFX.error();const s=Math.min(1+(t.upg.multi||0),t.caches[e]);t.caches[e]-=s,'
            Replacement = 'openCache(e){const t=this.g(),a=IG_CACHES[e];if(this._caseSpinning||!a)return;if(!this._cacheReqOk(a))return void MenuSFX.error();let s=t.caches[e]||0;if(s<1){const c=Math.min(50,this._cacheBuyQty(e));if(c<1)return void MenuSFX.error();const cost=this._cacheCost(e)*c,cur="money"===a.costCur?(Game.data.money||0):(Game.data.signalCorruption.insanity||0);if(cur<cost)return void MenuSFX.error();if("money"===a.costCur)Game.data.money-=cost;else Game.data.signalCorruption.insanity-=cost;s=c;}else{const maxBatch=Math.min(50,s);t.caches[e]-=maxBatch;s=maxBatch;}if(s<1)return;'
            ExpectedCount = 1
        },
        @{
            Name = 'InsanityGame._runCaseReel: Simultaneous Slider Duration'
            Target = 'duration:3400+300*n,easing:"cubic-bezier(0.1,0.85,0.15,1)"'
            Replacement = 'duration:3200,easing:"cubic-bezier(0.1,0.85,0.15,1)"'
            ExpectedCount = 1
        },
        @{
            Name = 'InsanityGame._runCaseReel: Synchronized Completion'
            Target = '.onfinish=()=>{r.style.transform=`translate(${-m}px,${h}px)`,t.length>1&&SFXEngine.playNote(300+60*n,.06,"square",.05,0,"menu"),++s===t.length&&this._applyCaseRewards(t)}'
            Replacement = '.onfinish=()=>{r.style.transform=`translate(${-m}px,${h}px)`,++s===t.length&&(t.length>1&&SFXEngine.playNote(480,.08,"square",.06,0,"menu"),this._applyCaseRewards(t))}'
            ExpectedCount = 1
        },
        @{
            Name = 'InsanityGame.renderCaches: Open Max Button'
            Target = '+`<button class="ig-cbtn" ${!o||n<1?"disabled":""} onclick="InsanityGame.openCache(''${e}'')">OPEN${(t.upg.multi||0)>0&&n>1?" ×"+Math.min(1+t.upg.multi,n):""}</button>`+(this._openAllOk()&&n>1+(t.upg.multi||0)?`<button class="ig-cbtn" ${o?"":"disabled"} onclick="InsanityGame.openAllCaches(''${e}'')">ALL ×${Math.min(n,IG_CONST.OPEN_ALL_MAX)}</button>`:"")'
            Replacement = '+`<button class="ig-cbtn" ${!o||(n<1&&c<1)?"disabled":""} onclick="InsanityGame.openCache(''${e}'')">OPEN${(n>0?n:c)>0?" ×"+(n>0?n:c):""}</button>`'
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
        Write-Host "  5. Right-click context menu `"Equip`" / `"Unequip`" options" -ForegroundColor White
        Write-Host "  6. Right-click weapon `"Buy Ammo`" option (Gunsmith shop & mag selection)" -ForegroundColor White
        Write-Host "  7. Weapon hover magazine highlighting in Stash and Loadout" -ForegroundColor White
        Write-Host "  8. Empty loadout slot click Quick-Equip Modal & Trader Direct-Buy button" -ForegroundColor White
        Write-Host "  9. Multi-Language Support (12 Languages):" -ForegroundColor White
        Write-Host "     EN, DE, ES, FR, JA, KO, PL, PT, RU, TR, ZH, ZHTW" -ForegroundColor White
        Write-Host " 10. Skills Unspent Points Notification Asterisk on all Skills nav buttons" -ForegroundColor White
        Write-Host " 11. Mythic Weapon Upgrades (+1 to +10 Safe Checkpoints, No Weapon Deletion, Smoothed Odds)" -ForegroundColor White
        Write-Host " 12. Nullpoint Abyss Fragment Merging (Safe Failure - Base Preserved, Reduced Fees & Fairer Rates)" -ForegroundColor White
        Write-Host " 13. Raid Extraction Insanity: Safe extraction awards Insanity based on Map Tier, Kills, and Bosses (0 on death)" -ForegroundColor White
        Write-Host " 14. Signal Corruption Nexus UI Overhaul: Telemetry banner, live Sin Frenzy bonus & clean sub-tabs" -ForegroundColor White
        Write-Host " 15. Pure Raid & Material Caches: Boosts purged; drops tech drives, rare gear, `$1.5M & Abyss flux" -ForegroundColor White
        Write-Host " 16. Permanent Madness Protocol Unlock: Rebirth lock abolished, talents open immediately, auto-migration" -ForegroundColor White
        Write-Host " 17. Communion Talents Rework: Signal Resonance (speed), Scavenger's Eye (loot), Eldritch Surge, Corrupted Bargain" -ForegroundColor White
        Write-Host " 18. Hollow Crown Raid Milestone: Re-anchored to Warden/Boss kills (Tier I-X: +10% to +100% raid damage)" -ForegroundColor White
        Write-Host " 19. Mining Rig Economy Overhaul: 15× Bitcoin yield (1.5e-3 BTC/min/GPU) + 75% fuel reduction (0.25/min)" -ForegroundColor White
        Write-Host " 20. One-Click Bitcoin Cashout: Interactive [ SELL ALL BTC (+`$X) ] button in Mining Rig header" -ForegroundColor White
        Write-Host " 21. Decryption Station & Military Drives: Crack drives instantly for guaranteed codes; GPU hash rate scaling" -ForegroundColor White
        Write-Host " 22. Stash-Level Vault Code Injection: Right-click gear -> `"Apply Vault Code`" directly target-crafts affixes" -ForegroundColor White
        Write-Host " 23. Simultaneous Max Cache Opening: Auto-batch open max owned/affordable caches with synchronized reels" -ForegroundColor White
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