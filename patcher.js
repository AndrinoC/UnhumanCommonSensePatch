/**
 * UNHUMAN Mod Patcher Engine
 * Modifies package.nw/unhuman.html to add:
 * 1. Tutorial skip toggle in Character Creation + Instant Rewards
 * 2. Skip Intro Splash toggle in Settings + Click/Key to Skip
 * 3. Remove -15% loot penalty for Auto-Complete Minigames in Raid Filters
 * 4. Double click to equip/unequip items
 * 5. Add equip/unequip to item right-click context menu
 */

const fs = require('fs');
const path = require('path');

const BASE_DIR = __dirname;
const HTML_PATH = path.join(BASE_DIR, 'package.nw', 'unhuman.html');
const BACKUP_PATH = path.join(BASE_DIR, 'package.nw', 'unhuman.html.bak');

const PATCHES = [
    {
        "name": "1a. HTML Toggle in Character Creation Screen",
        "target": "<div onclick=\"Game.selectAvatar(4)\" class=\"avatar-option w-16 h-16 cursor-pointer\" data-id=\"4\" style=\"border:1px solid rgba(0,255,65,0.3);background:rgba(0,5,0,0.6);\"><img src=\"assets/avatars/avatar_4.png\" style=\"width:100%;height:100%;object-fit:cover;image-rendering:pixelated;pointer-events:none;\" draggable=\"false\"></div>\n                </div>\n            </div>\n            <button onclick=\"Game.finalizeCharacter()\"",
        "replacement": "<div onclick=\"Game.selectAvatar(4)\" class=\"avatar-option w-16 h-16 cursor-pointer\" data-id=\"4\" style=\"border:1px solid rgba(0,255,65,0.3);background:rgba(0,5,0,0.6);\"><img src=\"assets/avatars/avatar_4.png\" style=\"width:100%;height:100%;object-fit:cover;image-rendering:pixelated;pointer-events:none;\" draggable=\"false\"></div>\n                </div>\n            </div>\n            <div class=\"mb-6 flex items-center justify-center gap-3\">\n                <input type=\"checkbox\" id=\"skipTutorialToggle\" class=\"accent-emerald-500 w-4 h-4 cursor-pointer\" checked>\n                <label for=\"skipTutorialToggle\" class=\"text-xs text-green-400 cursor-pointer select-none font-mono\" style=\"letter-spacing: 1px;\">\n                    SKIP TUTORIAL (CLAIM ALL REWARDS)\n                </label>\n            </div>\n            <button onclick=\"Game.finalizeCharacter()\"",
        "expectedCount": 1
    },
    {
        "name": "1b. finalizeCharacter Hook & skipTutorialAndGrantRewards",
        "target": "void 0!==TutorialManager&&setTimeout(()=>TutorialManager.showPrompt(),500)},healClockDrift()",
        "replacement": "document.getElementById(\"skipTutorialToggle\")?.checked?this.skipTutorialAndGrantRewards():(void 0!==TutorialManager&&setTimeout(()=>TutorialManager.showPrompt(),500))},skipTutorialAndGrantRewards(){this.data.tutorial={active:!1,stepIndex:0,completed:!0,raidCount:0};try{localStorage.setItem(\"unhuman_tutorial_ever_completed\",\"true\")}catch(e){}if(void 0!==TutorialManager){TutorialManager.active=!1;TutorialManager._removeGlobalBlocker&&TutorialManager._removeGlobalBlocker();TutorialManager.hideSpotlight&&TutorialManager.hideSpotlight()}this.data.mentor={enabled:!1,offerVet:!1,idx:void 0!==MENTOR_TASKS?MENTOR_TASKS.length:18,done:{},skipped:{},snap:null};if(void 0!==MentorSystem){MentorSystem.disable&&MentorSystem.disable();MentorSystem._hide&&MentorSystem._hide()}if(void 0!==MENTOR_TASKS&&Array.isArray(MENTOR_TASKS)){MENTOR_TASKS.forEach(e=>{try{e.onStart&&e.onStart()}catch(e){}try{e.grant&&e.grant()}catch(e){}this.data.mentor&&this.data.mentor.done&&(this.data.mentor.done[e.id]=!0)})}try{this.data.traderQuests||(this.data.traderQuests={});this.data.traderQuests.gs_welcome={status:\"completed\",progress:{}};\"function\"==typeof addStandingXP&&addStandingXP(\"gunsmith\",25);if(void 0!==ItemFactory){const e=[\"ar_t3\",\"smg_t3\",\"shotgun_t3\",\"dmr_t3\"],t=e[Math.floor(Math.random()*e.length)],a=ItemFactory.create(t,\"standard\",1);a&&(a._tutorialWeapon=!0,this.addToStash(a)||this.recoverToGunsmith(a))}}catch(e){}if((this.data.level||1)<5){const e=5-(this.data.level||1);this.data.level=5,this.data.xp=0;this.data.skillTree||(this.data.skillTree={allocatedNodes:[],availablePoints:0,totalPointsSpent:0});this.data.skillTree.availablePoints=(this.data.skillTree.availablePoints||0)+e}try{this.addCurrency&&this.addCurrency(\"tech_chip_root\",10);this.addCurrency&&this.addCurrency(\"tech_drive_flash\",10);this.addCurrency&&this.addCurrency(\"tech_chip_kernel\",10)}catch(e){}this.saveData();void 0!==GlobalNotif&&GlobalNotif.showCentered(\"TUTORIAL SKIPPED\",\"All tutorial & mentor rewards granted! Welcome, Operator.\")},healClockDrift()",
        "expectedCount": 1
    },
    {
        "name": "1c. showPrompt cancelText",
        "target": "cancelText:e?\"SKIP TUTORIAL\":null,noBackdropClose:!0,onConfirm:()=>TutorialManager.start(),onCancel:e?()=>TutorialManager.skip():null",
        "replacement": "cancelText:\"SKIP TUTORIAL\",noBackdropClose:!0,onConfirm:()=>TutorialManager.start(),onCancel:()=>(Game.skipTutorialAndGrantRewards?Game.skipTutorialAndGrantRewards():TutorialManager.skip())",
        "expectedCount": 1
    },
    {
        "name": "1d. confirmSkip onConfirm",
        "target": "onConfirm:()=>this.skip()",
        "replacement": "onConfirm:()=>{this.skip();Game.skipTutorialAndGrantRewards&&Game.skipTutorialAndGrantRewards()}",
        "expectedCount": 1
    },
    {
        "name": "2a. GameSettings defaults",
        "target": "mergeConfirm:!0,skipUpgradeAnim:!1,autoAcceptQuests:!1,",
        "replacement": "mergeConfirm:!0,skipUpgradeAnim:!1,autoAcceptQuests:!1,skipIntroSplash:!0,",
        "expectedCount": 2
    },
    {
        "name": "2b. SettingsScreen._renderDisplay",
        "target": "${this._toggle(\"CRT Effects\",\"crtEffects\",GameSettings.crtEffects)}",
        "replacement": "${this._toggle(\"Skip Intro Splash\",\"skipIntroSplash\",!1!==GameSettings.skipIntroSplash)}\\n                        ${this._toggle(\"CRT Effects\",\"crtEffects\",GameSettings.crtEffects)}",
        "expectedCount": 1
    },
    {
        "name": "2c. Splash Screen handler",
        "target": "const s=document.getElementById(\"splashScreen\");s&&(sessionStorage.getItem(\"UH_SplashDone\")?s.remove():(sessionStorage.setItem(\"UH_SplashDone\",\"1\"),setTimeout(()=>{s.classList.add(\"fade-out\"),setTimeout(()=>s.remove(),600)},1e4)))",
        "replacement": "(()=>{const s=document.getElementById(\"splashScreen\");if(s){const k=()=>s.remove();s.addEventListener(\"click\",k);window.addEventListener(\"keydown\",k,{once:!0});GameSettings.skipIntroSplash!==!1||sessionStorage.getItem(\"UH_SplashDone\")?s.remove():(sessionStorage.setItem(\"UH_SplashDone\",\"1\"),setTimeout(()=>{s.classList.add(\"fade-out\"),setTimeout(()=>s.remove(),600)},1e4))}})()",
        "expectedCount": 1
    },
    {
        "name": "3a. Filter Category description",
        "target": "{id:\"minigameIdleMode\",label:\"Minigame Idle Mode\",desc:\"Auto-complete lockpick/hacking (10s wait, -15% loot)\",type:\"checkbox\"}",
        "replacement": "{id:\"minigameIdleMode\",label:\"Minigame Idle Mode\",desc:\"Auto-complete lockpick/hacking (10s wait, no penalty)\",type:\"checkbox\"}",
        "expectedCount": 1
    },
    {
        "name": "3b. completeIdleMinigame penalty",
        "target": "this.startLootingWithBonus(e,{rarity:-.15,quantity:-.15})",
        "replacement": "this.startLootingWithBonus(e,{rarity:.1,quantity:.1})",
        "expectedCount": 1
    },
    {
        "name": "Context Menu Equip/Unequip HTML",
        "target": "<div id=\"itemContextMenu\">\n        <div class=\"context-menu-item\" data-action=\"inspect\">Inspect</div>",
        "replacement": "<div id=\"itemContextMenu\">\n        <div class=\"context-menu-item\" data-action=\"equip\">Equip</div>\n        <div class=\"context-menu-item\" data-action=\"unequip\">Unequip</div>\n        <div class=\"context-menu-item\" data-action=\"inspect\">Inspect</div>",
        "expectedCount": 1
    },
    {
        "name": "Context Menu Item Display (Equip/Unequip)",
        "target": "const t=document.querySelector('#itemContextMenu [data-action=\"ensure\"]')",
        "replacement": "const eq=document.querySelector('#itemContextMenu [data-action=\"equip\"]'),uneq=document.querySelector('#itemContextMenu [data-action=\"unequip\"]');if(eq)eq.style.display=(\"stash\"===this.contextMenuSource||\"container\"===this.contextMenuSource)?\"block\":\"none\";if(uneq)uneq.style.display=(\"equipment\"===this.contextMenuSource||\"augment\"===this.contextMenuSource)?\"block\":\"none\";const t=document.querySelector('#itemContextMenu [data-action=\"ensure\"]')",
        "expectedCount": 1
    },
    {
        "name": "Context Menu Action Handler (Equip/Unequip)",
        "target": "case\"inspect\":HintSystem.show(\"inspect_item\")",
        "replacement": "case\"equip\":case\"unequip\":UI.quickStashAction(this.contextMenuTarget,this.contextMenuSlot,this.contextMenuSource,null);break;case\"inspect\":HintSystem.show(\"inspect_item\")",
        "expectedCount": 1
    },
    {
        "name": "Double-Click & Quick Stash Handler",
        "target": "document.addEventListener(\"click\",e=>{if(!e.shiftKey||Game.state.inRaid)return;if(void 0!==TutorialManager&&TutorialManager.active)return;let t=null,a=null,s=null,i=null;const n=e.target.closest(\".tlo-slot-container .item-card\");if(n){const e=n.closest(\"[data-slot]\");if(e){const n=e.dataset.slot,o=Game.data.equipment[n];o&&(t=\"string\"==typeof o?Items[o]:o,a=n,s=\"equipment\",i=e)}}if(!t){const n=e.target.closest(\".augment-slot.filled\");if(n){const e=n.dataset.slot,o=Game.data.augments?.[e];o&&(t=\"string\"==typeof o?Items[o]:o,a=e,s=\"augment\",i=n)}}if(!t){const n=e.target.closest(\"#stashGrid .eft-merged-grid-slot, #stashGrid .stash-slot-item, #stashGrid .stash-grid-slot\");if(n){const e=n.closest(\"[data-slot-index]\")||n,o=UI.getItemFromGridSlot(e,Game.data.stash);o&&(t=o.item,a=o.slot,s=\"stash\",i=e)}}if(!t){const n=e.target.closest(\"#loadoutRigGrid .stash-slot-item, #loadoutBackpackGrid .stash-slot-item, #loadoutPocketsGrid .stash-slot-item, #loadoutPouchGrid .stash-slot-item,#loadoutRigGrid .covered-drop-overlay, #loadoutBackpackGrid .covered-drop-overlay, #loadoutPouchGrid .covered-drop-overlay\");if(n){const e=n.classList.contains(\"covered-drop-overlay\")?n:n.closest(\".eft-merged-grid-slot, .eft-discrete-slot\");if(e){const n=e.closest(\"[id]\"),o=e.dataset.containerType||(\"loadoutRigGrid\"===n?.id?\"rig\":\"loadoutBackpackGrid\"===n?.id?\"backpack\":\"loadoutPouchGrid\"===n?.id?\"pouch\":\"loadoutPocketsGrid\"===n?.id?\"pockets\":null),r=void 0!==e.dataset.anchorSlot?parseInt(e.dataset.anchorSlot):parseInt(e.dataset.slotIndex);if(o&&!isNaN(r)){const n=Game.getActiveInventory(),l=\"rig\"===o?\"rigContents\":\"backpack\"===o?\"backpackContents\":o;if(n?.[l]?.[r]){const c=n[l][r];t=\"string\"==typeof c?Items[c]:c,a=r,s=\"container\",i=e,i._containerType=o,i._contentsKey=l}}}}}if(!t||!s)return;e.preventDefault(),UI.hideItemTooltip();const o=e=>{MenuSFX.error(),e&&(e.classList.remove(\"shift-click-blocked\"),e.offsetWidth,e.classList.add(\"shift-click-blocked\"),e.addEventListener(\"animationend\",()=>e.classList.remove(\"shift-click-blocked\"),{once:!0}))};if(\"equipment\"===s){const e=[\"rig\",\"backpack\",\"pouch\"].includes(a)?Game._containerTxBegin(a):null;if(e&&!Game.evacuateContainerContents(a))return Game._containerTxRollback(e),void o(i);if(!Game.addToStash(t))return Game._containerTxRollback(e),GlobalNotif.show(\"STASH FULL\",\"Free stash space first\"),void o(i);Game.setEquipment(a,null),GameSFX.equip?.(),Game._saveDirty=!0,UI.renderStats(),UI.renderLoadout(),UI.renderStash()}else if(\"augment\"===s){const e=t.slots?.[0]||a;Game.data.augmentLocker||(Game.data.augmentLocker={eye:[],brain:[],torso:[],skin:[],arms:[],legs:[],skeleton:[],internal:[],shoulder:[]}),Game.data.augmentLocker[e]||(Game.data.augmentLocker[e]=[]),Game.data.augmentLocker[e].push(t),Game.data.augments[a]=null,Game.invalidateStats(),Game.clampBodyHealthToMax(),void 0!==AugmentTriggers&&AugmentTriggers.invalidateAugmentCache(),GameSFX.equip?.(),Game._saveDirty=!0,UI.renderStats(),UI.renderLoadout()}else if(\"stash\"===s){const e=t.type;if([\"weapon\",\"armor\",\"accessory\",\"container\"].includes(e)){let s=[];if(Array.isArray(t.slots)&&t.slots.length)s=t.slots;else if(\"weapon\"===e){const e=t.weaponClass||t.subtype||\"ranged\";s=\"melee\"===e?[\"melee\"]:\"pistol\"===e?[\"secondary\",\"primary\"]:[\"primary\"]}else\"armor\"===e||\"accessory\"===e?s=[\"head\",\"body\",\"earpiece\",\"facecover\",\"eyewear\"]:\"container\"===e&&(s=\"secure\"===t.subtype?[\"pouch\"]:[\"rig\",\"backpack\"]);let n=!1;for(const e of s)if(!Game.data.equipment[e]&&Game.canEquipToSlot(t,e)){Game.setEquipment(e,t),Game.removeFromStash(a),GameSFX.equip?.(),Game._saveDirty=!0,n=!0;break}if(!n)for(const e of s){const s=Game.data.equipment[e];if(!s||!Game.canEquipToSlot(t,e))continue;if([\"rig\",\"backpack\",\"pouch\"].includes(e)){const t=Game._containerTxBegin(e);if(!Game.evacuateContainerContents(e)){Game._containerTxRollback(t);continue}}const i=\"string\"==typeof s?Items[s]:s;if(i){if(Game.removeFromStash(a),!Game.addToStash(i)){Game.addToStash(t);break}Game.setEquipment(e,t),GameSFX.equip?.(),Game._saveDirty=!0,n=!0;break}}if(!n)return void o(i)}else{if(\"augment\"===e){const e=Game.data.prestige||0;let s=!1;for(const{slot:i,minPrestige:n}of AUGMENT_SLOT_DEFS)if(!(e<n)&&!Game.data.augments?.[i]&&Game.canEquipAugmentToSlot(t,i)){Game.data.augments[i]=t,Game.removeFromStash(a),Game.invalidateStats(),Game.clampBodyHealthToMax(),AugmentTriggers.invalidateAugmentCache(),GameSFX.equip?.(),Game._saveDirty=!0,HintSystem.show(\"augment_equip\"),addQuestProgress(\"equip_augment\",{slot:i,amount:1}),s=!0;break}return s?(\"augments\"!==UI.activeLoadoutSubTab?UI.switchLoadoutSubTab(\"augments\"):UI.renderLoadout(),void UI.renderStash()):void o(i)}{const e=Game.getActiveInventory(),s=getEffectiveSize(t),n=[{type:\"rig\",key:\"rigContents\"},{type:\"backpack\",key:\"backpackContents\"},{type:\"pockets\",key:\"pockets\"},{type:\"pouch\",key:\"pouch\"}];let r=!1;for(const i of n){if(\"pockets\"!==i.type&&!Game.data.equipment[i.type])continue;const n=getContainerGridConfig(i.type);e[i.key]||(e[i.key]=\"pockets\"===i.type?[null,null,null,null]:[]);const o=\"pockets\"===i.type?s.width>1||s.height>1?-1:e.pockets.indexOf(null):findEmptySlotInContainer(s.width,s.height,e[i.key],n.cols,n.rows);if(o>=0){e[i.key][o]=t,Game.removeFromStash(a),Game.invalidateStats(),GameSFX.equip?.(),Game._saveDirty=!0,r=!0;break}}if(!r)return void o(i)}}UI.renderStats(),UI.renderLoadout(),UI.renderStash()}else if(\"container\"===s){if(!Game.addToStash(t))return void o(i);const e=Game.getActiveInventory(),s=i._contentsKey;\"pockets\"===s?e[s][a]=null:delete e[s][a],Game.invalidateStats(),GameSFX.equip?.(),Game._saveDirty=!0,UI.renderStats(),UI.renderLoadout(),UI.renderStash()}})",
        "replacement": "UI.getClickedItemDetails=function(e){let t=null,a=null,s=null,i=null;const n=e.target.closest(\".tlo-slot-container .item-card\");if(n){const e=n.closest(\"[data-slot]\");if(e){const n=e.dataset.slot,o=Game.data.equipment[n];o&&(t=\"string\"==typeof o?Items[o]:o,a=n,s=\"equipment\",i=e)}}if(!t){const n=e.target.closest(\".augment-slot.filled\");if(n){const e=n.dataset.slot,o=Game.data.augments?.[e];o&&(t=\"string\"==typeof o?Items[o]:o,a=e,s=\"augment\",i=n)}}if(!t){const n=e.target.closest(\"#stashGrid .eft-merged-grid-slot, #stashGrid .stash-slot-item, #stashGrid .stash-grid-slot\");if(n){const e=n.closest(\"[data-slot-index]\")||n,o=UI.getItemFromGridSlot(e,Game.data.stash);o&&(t=o.item,a=o.slot,s=\"stash\",i=e)}}if(!t){const n=e.target.closest(\"#loadoutRigGrid .stash-slot-item, #loadoutBackpackGrid .stash-slot-item, #loadoutPocketsGrid .stash-slot-item, #loadoutPouchGrid .stash-slot-item,#loadoutRigGrid .covered-drop-overlay, #loadoutBackpackGrid .covered-drop-overlay, #loadoutPouchGrid .covered-drop-overlay\");if(n){const e=n.classList.contains(\"covered-drop-overlay\")?n:n.closest(\".eft-merged-grid-slot, .eft-discrete-slot\");if(e){const n=e.closest(\"[id]\"),o=e.dataset.containerType||(\"loadoutRigGrid\"===n?.id?\"rig\":\"loadoutBackpackGrid\"===n?.id?\"backpack\":\"loadoutPouchGrid\"===n?.id?\"pouch\":\"loadoutPocketsGrid\"===n?.id?\"pockets\":null),r=void 0!==e.dataset.anchorSlot?parseInt(e.dataset.anchorSlot):parseInt(e.dataset.slotIndex);if(o&&!isNaN(r)){const n=Game.getActiveInventory(),l=\"rig\"===o?\"rigContents\":\"backpack\"===o?\"backpackContents\":o;if(n?.[l]?.[r]){const c=n[l][r];t=\"string\"==typeof c?Items[c]:c,a=r,s=\"container\",i=e,i._containerType=o,i._contentsKey=l}}}}}return{item:t,slot:a,source:s,el:i}};UI.quickStashAction=function(t,a,s,i){if(!t||!s)return;UI.hideItemTooltip();const o=e=>{MenuSFX.error(),e&&(e.classList.remove(\"shift-click-blocked\"),e.offsetWidth,e.classList.add(\"shift-click-blocked\"),e.addEventListener(\"animationend\",()=>e.classList.remove(\"shift-click-blocked\"),{once:!0}))};if(\"equipment\"===s){const e=[\"rig\",\"backpack\",\"pouch\"].includes(a)?Game._containerTxBegin(a):null;if(e&&!Game.evacuateContainerContents(a))return Game._containerTxRollback(e),void o(i);if(!Game.addToStash(t))return Game._containerTxRollback(e),GlobalNotif.show(\"STASH FULL\",\"Free stash space first\"),void o(i);Game.setEquipment(a,null),GameSFX.equip?.(),Game._saveDirty=!0,UI.renderStats(),UI.renderLoadout(),UI.renderStash()}else if(\"augment\"===s){const e=t.slots?.[0]||a;Game.data.augmentLocker||(Game.data.augmentLocker={eye:[],brain:[],torso:[],skin:[],arms:[],legs:[],skeleton:[],internal:[],shoulder:[]}),Game.data.augmentLocker[e]||(Game.data.augmentLocker[e]=[]),Game.data.augmentLocker[e].push(t),Game.data.augments[a]=null,Game.invalidateStats(),Game.clampBodyHealthToMax(),void 0!==AugmentTriggers&&AugmentTriggers.invalidateAugmentCache(),GameSFX.equip?.(),Game._saveDirty=!0,UI.renderStats(),UI.renderLoadout()}else if(\"stash\"===s){const e=t.type;if([\"weapon\",\"armor\",\"accessory\",\"container\"].includes(e)){let s=[];if(Array.isArray(t.slots)&&t.slots.length)s=t.slots;else if(\"weapon\"===e){const e=t.weaponClass||t.subtype||\"ranged\";s=\"melee\"===e?[\"melee\"]:\"pistol\"===e?[\"secondary\",\"primary\"]:[\"primary\"]}else\"armor\"===e||\"accessory\"===e?s=[\"head\",\"body\",\"earpiece\",\"facecover\",\"eyewear\"]:\"container\"===e&&(s=\"secure\"===t.subtype?[\"pouch\"]:[\"rig\",\"backpack\"]);let n=!1;for(const e of s)if(!Game.data.equipment[e]&&Game.canEquipToSlot(t,e)){Game.setEquipment(e,t),Game.removeFromStash(a),GameSFX.equip?.(),Game._saveDirty=!0,n=!0;break}if(!n)for(const e of s){const s=Game.data.equipment[e];if(!s||!Game.canEquipToSlot(t,e))continue;if([\"rig\",\"backpack\",\"pouch\"].includes(e)){const t=Game._containerTxBegin(e);if(!Game.evacuateContainerContents(e)){Game._containerTxRollback(t);continue}}const i=\"string\"==typeof s?Items[s]:s;if(i){if(Game.removeFromStash(a),!Game.addToStash(i)){Game.addToStash(t);break}Game.setEquipment(e,t),GameSFX.equip?.(),Game._saveDirty=!0,n=!0;break}}if(!n)return void o(i)}else{if(\"augment\"===e){const e=Game.data.prestige||0;let s=!1;for(const{slot:i,minPrestige:n}of AUGMENT_SLOT_DEFS)if(!(e<n)&&!Game.data.augments?.[i]&&Game.canEquipAugmentToSlot(t,i)){Game.data.augments[i]=t,Game.removeFromStash(a),Game.invalidateStats(),Game.clampBodyHealthToMax(),AugmentTriggers.invalidateAugmentCache(),GameSFX.equip?.(),Game._saveDirty=!0,HintSystem.show(\"augment_equip\"),addQuestProgress(\"equip_augment\",{slot:i,amount:1}),s=!0;break}return s?(\"augments\"!==UI.activeLoadoutSubTab?UI.switchLoadoutSubTab(\"augments\"):UI.renderLoadout(),void UI.renderStash()):void o(i)}{const e=Game.getActiveInventory(),s=getEffectiveSize(t),n=[{type:\"rig\",key:\"rigContents\"},{type:\"backpack\",key:\"backpackContents\"},{type:\"pockets\",key:\"pockets\"},{type:\"pouch\",key:\"pouch\"}];let r=!1;for(const i of n){if(\"pockets\"!==i.type&&!Game.data.equipment[i.type])continue;const n=getContainerGridConfig(i.type);e[i.key]||(e[i.key]=\"pockets\"===i.type?[null,null,null,null]:[]);const o=\"pockets\"===i.type?s.width>1||s.height>1?-1:e.pockets.indexOf(null):findEmptySlotInContainer(s.width,s.height,e[i.key],n.cols,n.rows);if(o>=0){e[i.key][o]=t,Game.removeFromStash(a),Game.invalidateStats(),GameSFX.equip?.(),Game._saveDirty=!0,r=!0;break}}if(!r)return void o(i)}}UI.renderStats(),UI.renderLoadout(),UI.renderStash()}else if(\"container\"===s){if(!Game.addToStash(t))return void o(i);const e=Game.getActiveInventory(),s=i._contentsKey;\"pockets\"===s?e[s][a]=null:delete e[s][a],Game.invalidateStats(),GameSFX.equip?.(),Game._saveDirty=!0,UI.renderStats(),UI.renderLoadout(),UI.renderStash()}};document.addEventListener(\"click\",e=>{if(!e.shiftKey||Game.state.inRaid)return;if(void 0!==TutorialManager&&TutorialManager.active)return;const res=UI.getClickedItemDetails(e);if(!res.item||!res.source)return;e.preventDefault();UI.quickStashAction(res.item,res.slot,res.source,res.el)});document.addEventListener(\"dblclick\",e=>{if(Game.state.inRaid)return;if(void 0!==TutorialManager&&TutorialManager.active)return;const res=UI.getClickedItemDetails(e);if(!res.item||!res.source)return;e.preventDefault();UI.quickStashAction(res.item,res.slot,res.source,res.el)})",
        "expectedCount": 1
    }
];

function isModded(content) {
    return content.includes('skipTutorialToggle') &&
           content.includes('skipTutorialAndGrantRewards') &&
           content.includes('skipIntroSplash') &&
           content.includes('UI.getClickedItemDetails');
}

function getStatus() {
    if (!fs.existsSync(HTML_PATH)) {
        console.error('[ERROR] Game file not found at:', HTML_PATH);
        return { ok: false, error: 'FILE_NOT_FOUND' };
    }
    const content = fs.readFileSync(HTML_PATH, 'utf8');
    const modded = isModded(content);
    const backupExists = fs.existsSync(BACKUP_PATH);
    return { ok: true, modded, backupExists };
}

function patch() {
    console.log('------------------------------------------------------------');
    console.log('              UNHUMAN MOD PATCHER: APPLYING MOD            ');
    console.log('------------------------------------------------------------');

    if (!fs.existsSync(HTML_PATH)) {
        console.error('[ERROR] Target file does not exist: ' + HTML_PATH);
        process.exit(1);
    }

    let content = fs.readFileSync(HTML_PATH, 'utf8');

    // If already modded, restore clean backup first to guarantee clean re-patch
    if (isModded(content)) {
        if (fs.existsSync(BACKUP_PATH)) {
            console.log('[INFO] Previous mod installation detected. Re-applying on fresh backup...');
            content = fs.readFileSync(BACKUP_PATH, 'utf8');
        } else {
            console.log('[INFO] The mod is already applied and no backup is available.');
            return;
        }
    }

    // Create backup if doesn't exist
    if (!fs.existsSync(BACKUP_PATH)) {
        console.log('[BACKUP] Creating original backup: package.nw\\unhuman.html.bak ...');
        fs.copyFileSync(HTML_PATH, BACKUP_PATH);
        console.log('[BACKUP] Backup created successfully.');
    } else {
        console.log('[BACKUP] Using backup at: package.nw\\unhuman.html.bak');
    }

    console.log('[PATCH] Applying modifications...');
    for (const p of PATCHES) {
        const parts = content.split(p.target);
        const count = parts.length - 1;
        if (count !== p.expectedCount) {
            console.error(`[ERROR] Patch "${p.name}" expected ${p.expectedCount} match(es), but found ${count}.`);
            console.error('[ABORT] File content may differ from expected version. Aborting without saving.');
            process.exit(1);
        }
        content = parts.join(p.replacement);
        console.log(`  + [OK] ${p.name}`);
    }

    console.log('[SAVE] Writing updated unhuman.html...');
    fs.writeFileSync(HTML_PATH, content, 'utf8');

    const verifyContent = fs.readFileSync(HTML_PATH, 'utf8');
    if (isModded(verifyContent)) {
        console.log('------------------------------------------------------------');
        console.log('                 MOD APPLIED SUCCESSFULLY!                  ');
        console.log('------------------------------------------------------------');
        console.log('Fixes included:');
        console.log('  1. Character Creation Tutorial Skip toggle + Instant Rewards');
        console.log('  2. Intro Splash Skip toggle in Settings (ON by default) + Click/Key Skip');
        console.log('  3. Removed -15% Loot Penalty for Auto-Complete Minigames in Raid Filters');
        console.log('  4. Double Click to equip / unequip items (stash, loadout, augments)');
        console.log('  5. Right-click context menu "Equip" / "Unequip" options');
        console.log('------------------------------------------------------------');
    } else {
        console.error('[ERROR] Verification failed after writing file!');
        process.exit(1);
    }
}

function restore() {
    console.log('------------------------------------------------------------');
    console.log('            UNHUMAN MOD PATCHER: RESTORING BACKUP           ');
    console.log('------------------------------------------------------------');

    if (!fs.existsSync(BACKUP_PATH)) {
        console.error('[ERROR] No backup found at: ' + BACKUP_PATH);
        process.exit(1);
    }

    fs.copyFileSync(BACKUP_PATH, HTML_PATH);
    const content = fs.readFileSync(HTML_PATH, 'utf8');
    if (!isModded(content)) {
        console.log('[SUCCESS] Original game file restored successfully!');
    } else {
        console.warn('[WARNING] Restored file still appears to have mod markers.');
    }
}

function printStatus() {
    const status = getStatus();
    console.log('------------------------------------------------------------');
    console.log('                    UNHUMAN MOD STATUS                      ');
    console.log('------------------------------------------------------------');
    console.log('Target File  :', HTML_PATH);
    if (!status.ok) {
        console.log('File Status  : NOT FOUND');
    } else {
        console.log('Mod Applied  :', status.modded ? 'YES (MODDED)' : 'NO (ORIGINAL/UNMODDED)');
        console.log('Backup Exists:', status.backupExists ? 'YES (package.nw\\unhuman.html.bak)' : 'NO');
    }
    console.log('------------------------------------------------------------');
}

// CLI entry point
const action = (process.argv[2] || 'patch').toLowerCase().replace(/^-+/, '');

switch (action) {
    case 'patch':
    case '1':
        patch();
        break;
    case 'restore':
    case '2':
        restore();
        break;
    case 'status':
    case '3':
        printStatus();
        break;
    default:
        console.log('Usage: node patcher.js [patch|restore|status]');
        break;
}
