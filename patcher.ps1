# UNHUMAN Mod Patcher (PowerShell Engine)
param(
    [string]$Action = "patch"
)

$Action = $Action.ToLower().TrimStart("-")
$BaseDir = $PSScriptRoot
if (-not $BaseDir) { $BaseDir = (Get-Location).Path }

$HtmlPath = Join-Path $BaseDir "package.nw\unhuman.html"
$BackupPath = Join-Path $BaseDir "package.nw\unhuman.html.bak"

$Utf8NoBom = New-Object System.Text.UTF8Encoding($false)

function Test-IsModded($content) {
    return ($content.Contains("skipTutorialToggle") -and
            $content.Contains("skipTutorialAndGrantRewards") -and
            $content.Contains("skipIntroSplash") -and
            $content.Contains("UI.getClickedItemDetails"))
}

function Show-Status {
    Write-Host "------------------------------------------------------------" -ForegroundColor Cyan
    Write-Host "                    UNHUMAN MOD STATUS                      " -ForegroundColor Cyan
    Write-Host "------------------------------------------------------------" -ForegroundColor Cyan
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
    } else {
        Write-Host "Target File  : NOT FOUND!" -ForegroundColor Red
    }
    Write-Host "------------------------------------------------------------" -ForegroundColor Cyan
}

function Restore-Backup {
    Write-Host "------------------------------------------------------------" -ForegroundColor Cyan
    Write-Host "            UNHUMAN MOD PATCHER: RESTORING BACKUP           " -ForegroundColor Cyan
    Write-Host "------------------------------------------------------------" -ForegroundColor Cyan

    if (-not (Test-Path $BackupPath)) {
        Write-Host "[ERROR] No backup found at: $BackupPath" -ForegroundColor Red
        return
    }

    Copy-Item -Path $BackupPath -Destination $HtmlPath -Force
    $content = [System.IO.File]::ReadAllText($HtmlPath, $Utf8NoBom)
    if (-not (Test-IsModded($content))) {
        Write-Host "[SUCCESS] Original game file restored successfully!" -ForegroundColor Green
    } else {
        Write-Host "[WARNING] Restored file still appears to have mod markers." -ForegroundColor Yellow
    }
}

function Apply-Patch {
    Write-Host "------------------------------------------------------------" -ForegroundColor Cyan
    Write-Host "              UNHUMAN MOD PATCHER: APPLYING MOD            " -ForegroundColor Cyan
    Write-Host "------------------------------------------------------------" -ForegroundColor Cyan

    if (-not (Test-Path $HtmlPath)) {
        Write-Host "[ERROR] Target file does not exist: $HtmlPath" -ForegroundColor Red
        return
    }

    $content = [System.IO.File]::ReadAllText($HtmlPath, $Utf8NoBom)

    if (Test-IsModded($content)) {
        if (Test-Path $BackupPath) {
            Write-Host "[INFO] Previous mod installation detected. Re-applying on fresh backup..." -ForegroundColor Yellow
            $content = [System.IO.File]::ReadAllText($BackupPath, $Utf8NoBom)
        } else {
            Write-Host "[INFO] The mod is ALREADY APPLIED to unhuman.html." -ForegroundColor Green
            Write-Host "[INFO] No changes needed."
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
                <label for="skipTutorialToggle" class="text-xs text-green-400 cursor-pointer select-none font-mono" style="letter-spacing: 1px;">
                    SKIP TUTORIAL (CLAIM ALL REWARDS)
                </label>
            </div>
            <button onclick="Game.finalizeCharacter()"'
            ExpectedCount = 1
        },
        @{
            Name = '1b. finalizeCharacter Hook & skipTutorialAndGrantRewards'
            Target = 'void 0!==TutorialManager&&setTimeout(()=>TutorialManager.showPrompt(),500)},healClockDrift()'
            Replacement = 'document.getElementById("skipTutorialToggle")?.checked?this.skipTutorialAndGrantRewards():(void 0!==TutorialManager&&setTimeout(()=>TutorialManager.showPrompt(),500))},skipTutorialAndGrantRewards(){this.data.tutorial={active:!1,stepIndex:0,completed:!0,raidCount:0};try{localStorage.setItem("unhuman_tutorial_ever_completed","true")}catch(e){}if(void 0!==TutorialManager){TutorialManager.active=!1;TutorialManager._removeGlobalBlocker&&TutorialManager._removeGlobalBlocker();TutorialManager.hideSpotlight&&TutorialManager.hideSpotlight()}this.data.mentor={enabled:!1,offerVet:!1,idx:void 0!==MENTOR_TASKS?MENTOR_TASKS.length:18,done:{},skipped:{},snap:null};if(void 0!==MentorSystem){MentorSystem.disable&&MentorSystem.disable();MentorSystem._hide&&MentorSystem._hide()}if(void 0!==MENTOR_TASKS&&Array.isArray(MENTOR_TASKS)){MENTOR_TASKS.forEach(e=>{try{e.onStart&&e.onStart()}catch(e){}try{e.grant&&e.grant()}catch(e){}this.data.mentor&&this.data.mentor.done&&(this.data.mentor.done[e.id]=!0)})}try{this.data.traderQuests||(this.data.traderQuests={});this.data.traderQuests.gs_welcome={status:"completed",progress:{}};"function"==typeof addStandingXP&&addStandingXP("gunsmith",25);if(void 0!==ItemFactory){const e=["ar_t3","smg_t3","shotgun_t3","dmr_t3"],t=e[Math.floor(Math.random()*e.length)],a=ItemFactory.create(t,"standard",1);a&&(a._tutorialWeapon=!0,this.addToStash(a)||this.recoverToGunsmith(a))}}catch(e){}if((this.data.level||1)<5){const e=5-(this.data.level||1);this.data.level=5,this.data.xp=0;this.data.skillTree||(this.data.skillTree={allocatedNodes:[],availablePoints:0,totalPointsSpent:0});this.data.skillTree.availablePoints=(this.data.skillTree.availablePoints||0)+e}try{this.addCurrency&&this.addCurrency("tech_chip_root",10);this.addCurrency&&this.addCurrency("tech_drive_flash",10);this.addCurrency&&this.addCurrency("tech_chip_kernel",10)}catch(e){}this.saveData();void 0!==GlobalNotif&&GlobalNotif.showCentered("TUTORIAL SKIPPED","All tutorial & mentor rewards granted! Welcome, Operator.")},healClockDrift()'
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
        },
        @{
            Name = '3b. completeIdleMinigame penalty'
            Target = 'this.startLootingWithBonus(e,{rarity:-.15,quantity:-.15})'
            Replacement = 'this.startLootingWithBonus(e,{rarity:.1,quantity:.1})'
            ExpectedCount = 1
        },
        @{
            Name = 'Context Menu Equip/Unequip HTML'
            Target = '<div id="itemContextMenu">
        <div class="context-menu-item" data-action="inspect">Inspect</div>'
            Replacement = '<div id="itemContextMenu">
        <div class="context-menu-item" data-action="equip">Equip</div>
        <div class="context-menu-item" data-action="unequip">Unequip</div>
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
            Name = 'Context Menu Action Handler (Equip/Unequip)'
            Target = 'case"inspect":HintSystem.show("inspect_item")'
            Replacement = 'case"equip":case"unequip":UI.quickStashAction(this.contextMenuTarget,this.contextMenuSlot,this.contextMenuSource,null);break;case"inspect":HintSystem.show("inspect_item")'
            ExpectedCount = 1
        },
        @{
            Name = 'Double-Click & Quick Stash Handler'
            Target = 'document.addEventListener("click",e=>{if(!e.shiftKey||Game.state.inRaid)return;if(void 0!==TutorialManager&&TutorialManager.active)return;let t=null,a=null,s=null,i=null;const n=e.target.closest(".tlo-slot-container .item-card");if(n){const e=n.closest("[data-slot]");if(e){const n=e.dataset.slot,o=Game.data.equipment[n];o&&(t="string"==typeof o?Items[o]:o,a=n,s="equipment",i=e)}}if(!t){const n=e.target.closest(".augment-slot.filled");if(n){const e=n.dataset.slot,o=Game.data.augments?.[e];o&&(t="string"==typeof o?Items[o]:o,a=e,s="augment",i=n)}}if(!t){const n=e.target.closest("#stashGrid .eft-merged-grid-slot, #stashGrid .stash-slot-item, #stashGrid .stash-grid-slot");if(n){const e=n.closest("[data-slot-index]")||n,o=UI.getItemFromGridSlot(e,Game.data.stash);o&&(t=o.item,a=o.slot,s="stash",i=e)}}if(!t){const n=e.target.closest("#loadoutRigGrid .stash-slot-item, #loadoutBackpackGrid .stash-slot-item, #loadoutPocketsGrid .stash-slot-item, #loadoutPouchGrid .stash-slot-item,#loadoutRigGrid .covered-drop-overlay, #loadoutBackpackGrid .covered-drop-overlay, #loadoutPouchGrid .covered-drop-overlay");if(n){const e=n.classList.contains("covered-drop-overlay")?n:n.closest(".eft-merged-grid-slot, .eft-discrete-slot");if(e){const n=e.closest("[id]"),o=e.dataset.containerType||("loadoutRigGrid"===n?.id?"rig":"loadoutBackpackGrid"===n?.id?"backpack":"loadoutPouchGrid"===n?.id?"pouch":"loadoutPocketsGrid"===n?.id?"pockets":null),r=void 0!==e.dataset.anchorSlot?parseInt(e.dataset.anchorSlot):parseInt(e.dataset.slotIndex);if(o&&!isNaN(r)){const n=Game.getActiveInventory(),l="rig"===o?"rigContents":"backpack"===o?"backpackContents":o;if(n?.[l]?.[r]){const c=n[l][r];t="string"==typeof c?Items[c]:c,a=r,s="container",i=e,i._containerType=o,i._contentsKey=l}}}}}if(!t||!s)return;e.preventDefault(),UI.hideItemTooltip();const o=e=>{MenuSFX.error(),e&&(e.classList.remove("shift-click-blocked"),e.offsetWidth,e.classList.add("shift-click-blocked"),e.addEventListener("animationend",()=>e.classList.remove("shift-click-blocked"),{once:!0}))};if("equipment"===s){const e=["rig","backpack","pouch"].includes(a)?Game._containerTxBegin(a):null;if(e&&!Game.evacuateContainerContents(a))return Game._containerTxRollback(e),void o(i);if(!Game.addToStash(t))return Game._containerTxRollback(e),GlobalNotif.show("STASH FULL","Free stash space first"),void o(i);Game.setEquipment(a,null),GameSFX.equip?.(),Game._saveDirty=!0,UI.renderStats(),UI.renderLoadout(),UI.renderStash()}else if("augment"===s){const e=t.slots?.[0]||a;Game.data.augmentLocker||(Game.data.augmentLocker={eye:[],brain:[],torso:[],skin:[],arms:[],legs:[],skeleton:[],internal:[],shoulder:[]}),Game.data.augmentLocker[e]||(Game.data.augmentLocker[e]=[]),Game.data.augmentLocker[e].push(t),Game.data.augments[a]=null,Game.invalidateStats(),Game.clampBodyHealthToMax(),void 0!==AugmentTriggers&&AugmentTriggers.invalidateAugmentCache(),GameSFX.equip?.(),Game._saveDirty=!0,UI.renderStats(),UI.renderLoadout()}else if("stash"===s){const e=t.type;if(["weapon","armor","accessory","container"].includes(e)){let s=[];if(Array.isArray(t.slots)&&t.slots.length)s=t.slots;else if("weapon"===e){const e=t.weaponClass||t.subtype||"ranged";s="melee"===e?["melee"]:"pistol"===e?["secondary","primary"]:["primary"]}else"armor"===e||"accessory"===e?s=["head","body","earpiece","facecover","eyewear"]:"container"===e&&(s="secure"===t.subtype?["pouch"]:["rig","backpack"]);let n=!1;for(const e of s)if(!Game.data.equipment[e]&&Game.canEquipToSlot(t,e)){Game.setEquipment(e,t),Game.removeFromStash(a),GameSFX.equip?.(),Game._saveDirty=!0,n=!0;break}if(!n)for(const e of s){const s=Game.data.equipment[e];if(!s||!Game.canEquipToSlot(t,e))continue;if(["rig","backpack","pouch"].includes(e)){const t=Game._containerTxBegin(e);if(!Game.evacuateContainerContents(e)){Game._containerTxRollback(t);continue}}const i="string"==typeof s?Items[s]:s;if(i){if(Game.removeFromStash(a),!Game.addToStash(i)){Game.addToStash(t);break}Game.setEquipment(e,t),GameSFX.equip?.(),Game._saveDirty=!0,n=!0;break}}if(!n)return void o(i)}else{if("augment"===e){const e=Game.data.prestige||0;let s=!1;for(const{slot:i,minPrestige:n}of AUGMENT_SLOT_DEFS)if(!(e<n)&&!Game.data.augments?.[i]&&Game.canEquipAugmentToSlot(t,i)){Game.data.augments[i]=t,Game.removeFromStash(a),Game.invalidateStats(),Game.clampBodyHealthToMax(),AugmentTriggers.invalidateAugmentCache(),GameSFX.equip?.(),Game._saveDirty=!0,HintSystem.show("augment_equip"),addQuestProgress("equip_augment",{slot:i,amount:1}),s=!0;break}return s?("augments"!==UI.activeLoadoutSubTab?UI.switchLoadoutSubTab("augments"):UI.renderLoadout(),void UI.renderStash()):void o(i)}{const e=Game.getActiveInventory(),s=getEffectiveSize(t),n=[{type:"rig",key:"rigContents"},{type:"backpack",key:"backpackContents"},{type:"pockets",key:"pockets"},{type:"pouch",key:"pouch"}];let r=!1;for(const i of n){if("pockets"!==i.type&&!Game.data.equipment[i.type])continue;const n=getContainerGridConfig(i.type);e[i.key]||(e[i.key]="pockets"===i.type?[null,null,null,null]:[]);const o="pockets"===i.type?s.width>1||s.height>1?-1:e.pockets.indexOf(null):findEmptySlotInContainer(s.width,s.height,e[i.key],n.cols,n.rows);if(o>=0){e[i.key][o]=t,Game.removeFromStash(a),Game.invalidateStats(),GameSFX.equip?.(),Game._saveDirty=!0,r=!0;break}}if(!r)return void o(i)}}UI.renderStats(),UI.renderLoadout(),UI.renderStash()}else if("container"===s){if(!Game.addToStash(t))return void o(i);const e=Game.getActiveInventory(),s=i._contentsKey;"pockets"===s?e[s][a]=null:delete e[s][a],Game.invalidateStats(),GameSFX.equip?.(),Game._saveDirty=!0,UI.renderStats(),UI.renderLoadout(),UI.renderStash()}})'
            Replacement = 'UI.getClickedItemDetails=function(e){let t=null,a=null,s=null,i=null;const n=e.target.closest(".tlo-slot-container .item-card");if(n){const e=n.closest("[data-slot]");if(e){const n=e.dataset.slot,o=Game.data.equipment[n];o&&(t="string"==typeof o?Items[o]:o,a=n,s="equipment",i=e)}}if(!t){const n=e.target.closest(".augment-slot.filled");if(n){const e=n.dataset.slot,o=Game.data.augments?.[e];o&&(t="string"==typeof o?Items[o]:o,a=e,s="augment",i=n)}}if(!t){const n=e.target.closest("#stashGrid .eft-merged-grid-slot, #stashGrid .stash-slot-item, #stashGrid .stash-grid-slot");if(n){const e=n.closest("[data-slot-index]")||n,o=UI.getItemFromGridSlot(e,Game.data.stash);o&&(t=o.item,a=o.slot,s="stash",i=e)}}if(!t){const n=e.target.closest("#loadoutRigGrid .stash-slot-item, #loadoutBackpackGrid .stash-slot-item, #loadoutPocketsGrid .stash-slot-item, #loadoutPouchGrid .stash-slot-item,#loadoutRigGrid .covered-drop-overlay, #loadoutBackpackGrid .covered-drop-overlay, #loadoutPouchGrid .covered-drop-overlay");if(n){const e=n.classList.contains("covered-drop-overlay")?n:n.closest(".eft-merged-grid-slot, .eft-discrete-slot");if(e){const n=e.closest("[id]"),o=e.dataset.containerType||("loadoutRigGrid"===n?.id?"rig":"loadoutBackpackGrid"===n?.id?"backpack":"loadoutPouchGrid"===n?.id?"pouch":"loadoutPocketsGrid"===n?.id?"pockets":null),r=void 0!==e.dataset.anchorSlot?parseInt(e.dataset.anchorSlot):parseInt(e.dataset.slotIndex);if(o&&!isNaN(r)){const n=Game.getActiveInventory(),l="rig"===o?"rigContents":"backpack"===o?"backpackContents":o;if(n?.[l]?.[r]){const c=n[l][r];t="string"==typeof c?Items[c]:c,a=r,s="container",i=e,i._containerType=o,i._contentsKey=l}}}}}return{item:t,slot:a,source:s,el:i}};UI.quickStashAction=function(t,a,s,i){if(!t||!s)return;UI.hideItemTooltip();const o=e=>{MenuSFX.error(),e&&(e.classList.remove("shift-click-blocked"),e.offsetWidth,e.classList.add("shift-click-blocked"),e.addEventListener("animationend",()=>e.classList.remove("shift-click-blocked"),{once:!0}))};if("equipment"===s){const e=["rig","backpack","pouch"].includes(a)?Game._containerTxBegin(a):null;if(e&&!Game.evacuateContainerContents(a))return Game._containerTxRollback(e),void o(i);if(!Game.addToStash(t))return Game._containerTxRollback(e),GlobalNotif.show("STASH FULL","Free stash space first"),void o(i);Game.setEquipment(a,null),GameSFX.equip?.(),Game._saveDirty=!0,UI.renderStats(),UI.renderLoadout(),UI.renderStash()}else if("augment"===s){const e=t.slots?.[0]||a;Game.data.augmentLocker||(Game.data.augmentLocker={eye:[],brain:[],torso:[],skin:[],arms:[],legs:[],skeleton:[],internal:[],shoulder:[]}),Game.data.augmentLocker[e]||(Game.data.augmentLocker[e]=[]),Game.data.augmentLocker[e].push(t),Game.data.augments[a]=null,Game.invalidateStats(),Game.clampBodyHealthToMax(),void 0!==AugmentTriggers&&AugmentTriggers.invalidateAugmentCache(),GameSFX.equip?.(),Game._saveDirty=!0,UI.renderStats(),UI.renderLoadout()}else if("stash"===s){const e=t.type;if(["weapon","armor","accessory","container"].includes(e)){let s=[];if(Array.isArray(t.slots)&&t.slots.length)s=t.slots;else if("weapon"===e){const e=t.weaponClass||t.subtype||"ranged";s="melee"===e?["melee"]:"pistol"===e?["secondary","primary"]:["primary"]}else"armor"===e||"accessory"===e?s=["head","body","earpiece","facecover","eyewear"]:"container"===e&&(s="secure"===t.subtype?["pouch"]:["rig","backpack"]);let n=!1;for(const e of s)if(!Game.data.equipment[e]&&Game.canEquipToSlot(t,e)){Game.setEquipment(e,t),Game.removeFromStash(a),GameSFX.equip?.(),Game._saveDirty=!0,n=!0;break}if(!n)for(const e of s){const s=Game.data.equipment[e];if(!s||!Game.canEquipToSlot(t,e))continue;if(["rig","backpack","pouch"].includes(e)){const t=Game._containerTxBegin(e);if(!Game.evacuateContainerContents(e)){Game._containerTxRollback(t);continue}}const i="string"==typeof s?Items[s]:s;if(i){if(Game.removeFromStash(a),!Game.addToStash(i)){Game.addToStash(t);break}Game.setEquipment(e,t),GameSFX.equip?.(),Game._saveDirty=!0,n=!0;break}}if(!n)return void o(i)}else{if("augment"===e){const e=Game.data.prestige||0;let s=!1;for(const{slot:i,minPrestige:n}of AUGMENT_SLOT_DEFS)if(!(e<n)&&!Game.data.augments?.[i]&&Game.canEquipAugmentToSlot(t,i)){Game.data.augments[i]=t,Game.removeFromStash(a),Game.invalidateStats(),Game.clampBodyHealthToMax(),AugmentTriggers.invalidateAugmentCache(),GameSFX.equip?.(),Game._saveDirty=!0,HintSystem.show("augment_equip"),addQuestProgress("equip_augment",{slot:i,amount:1}),s=!0;break}return s?("augments"!==UI.activeLoadoutSubTab?UI.switchLoadoutSubTab("augments"):UI.renderLoadout(),void UI.renderStash()):void o(i)}{const e=Game.getActiveInventory(),s=getEffectiveSize(t),n=[{type:"rig",key:"rigContents"},{type:"backpack",key:"backpackContents"},{type:"pockets",key:"pockets"},{type:"pouch",key:"pouch"}];let r=!1;for(const i of n){if("pockets"!==i.type&&!Game.data.equipment[i.type])continue;const n=getContainerGridConfig(i.type);e[i.key]||(e[i.key]="pockets"===i.type?[null,null,null,null]:[]);const o="pockets"===i.type?s.width>1||s.height>1?-1:e.pockets.indexOf(null):findEmptySlotInContainer(s.width,s.height,e[i.key],n.cols,n.rows);if(o>=0){e[i.key][o]=t,Game.removeFromStash(a),Game.invalidateStats(),GameSFX.equip?.(),Game._saveDirty=!0,r=!0;break}}if(!r)return void o(i)}}UI.renderStats(),UI.renderLoadout(),UI.renderStash()}else if("container"===s){if(!Game.addToStash(t))return void o(i);const e=Game.getActiveInventory(),s=i._contentsKey;"pockets"===s?e[s][a]=null:delete e[s][a],Game.invalidateStats(),GameSFX.equip?.(),Game._saveDirty=!0,UI.renderStats(),UI.renderLoadout(),UI.renderStash()}};document.addEventListener("click",e=>{if(!e.shiftKey||Game.state.inRaid)return;if(void 0!==TutorialManager&&TutorialManager.active)return;const res=UI.getClickedItemDetails(e);if(!res.item||!res.source)return;e.preventDefault();UI.quickStashAction(res.item,res.slot,res.source,res.el)});document.addEventListener("dblclick",e=>{if(Game.state.inRaid)return;if(void 0!==TutorialManager&&TutorialManager.active)return;const res=UI.getClickedItemDetails(e);if(!res.item||!res.source)return;e.preventDefault();UI.quickStashAction(res.item,res.slot,res.source,res.el)})'
            ExpectedCount = 1
        }
    )

    Write-Host "[PATCH] Applying modifications..."
    foreach ($p in $Patches) {
        $parts = $content.Split(@($p.Target), [System.StringSplitOptions]::None)
        $count = $parts.Length - 1
        if ($count -ne $p.ExpectedCount) {
            Write-Host "[ERROR] Patch '$($p.Name)' expected $($p.ExpectedCount) match(es), but found $count." -ForegroundColor Red
            Write-Host "[ABORT] File content may differ from expected version. Aborting without saving." -ForegroundColor Red
            return
        }
        $content = [string]::Join($p.Replacement, $parts)
        Write-Host "  + [OK] $($p.Name)" -ForegroundColor Green
    }

    Write-Host "[SAVE] Writing updated unhuman.html..."
    [System.IO.File]::WriteAllText($HtmlPath, $content, $Utf8NoBom)

    $verifyContent = [System.IO.File]::ReadAllText($HtmlPath, $Utf8NoBom)
    if (Test-IsModded($verifyContent)) {
        Write-Host "------------------------------------------------------------" -ForegroundColor Cyan
        Write-Host "                 MOD APPLIED SUCCESSFULLY!                  " -ForegroundColor Green
        Write-Host "------------------------------------------------------------" -ForegroundColor Cyan
        Write-Host "Fixes included:"
        Write-Host "  1. Character Creation Tutorial Skip toggle + Instant Rewards" -ForegroundColor White
        Write-Host "  2. Intro Splash Skip toggle in Settings (ON by default) + Click/Key Skip" -ForegroundColor White
        Write-Host "  3. Removed -15% Loot Penalty for Auto-Complete Minigames in Raid Filters" -ForegroundColor White
        Write-Host "  4. Double Click to equip / unequip items" -ForegroundColor White
        Write-Host "  5. Right-click context menu Equip / Unequip options" -ForegroundColor White
        Write-Host "------------------------------------------------------------" -ForegroundColor Cyan
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
