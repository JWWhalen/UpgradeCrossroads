local name, XC = ...
XC.name = name
XC.version = "0.9.0"
XC.Slots = {
    {id=1,label="Head",inv={1}}, {id=2,label="Neck",inv={2}},
    {id=3,label="Shoulder",inv={3}}, {id=15,label="Back",inv={16}},
    {id=5,label="Chest",inv={5,20}}, {id=9,label="Wrist",inv={9}},
    {id=10,label="Hands",inv={10}}, {id=6,label="Waist",inv={6}},
    {id=7,label="Legs",inv={7}}, {id=8,label="Feet",inv={8}},
    {id=11,label="Ring 1",inv={11}}, {id=12,label="Ring 2",inv={11}},
    {id=13,label="Trinket 1",inv={12}}, {id=14,label="Trinket 2",inv={12}},
    {id=16,label="Main hand",inv={13,17,21}},
    {id=17,label="Off hand",inv={13,14,22,23}}, {id=18,label="Ranged / relic",inv={15,25,26,28}},
}
-- Named class/spec choices use transparent starter role weights. Specs with the
-- same role intentionally share defaults; these are not simulated BiS weights.
local roleWeights = {
    melee={str=1,agi=.8,sta=.25,ap=.5,crit=9,hit=10,dps=5},
    ranged={agi=1,str=.1,sta=.25,int=.15,rap=.5,ap=.15,crit=9,hit=10,dps=5},
    caster={int=.6,spi=.2,sta=.2,sp=1,crit=7,hit=9,mpr=1},
    healer={int=.6,spi=.6,sta=.2,heal=1,sp=.3,mpr=2},
    tank={sta=1,armor=.025,str=.35,agi=.35,def=2,dodge=8,parry=8,block=5,dps=.4},
}
XC.ClassLabels={WARRIOR="Warrior",PALADIN="Paladin",HUNTER="Hunter",ROGUE="Rogue",PRIEST="Priest",SHAMAN="Shaman",MAGE="Mage",WARLOCK="Warlock",DRUID="Druid"}
XC.DefaultProfiles={WARRIOR="warrior_arms",PALADIN="paladin_retribution",HUNTER="hunter_beastmastery",ROGUE="rogue_combat",PRIEST="priest_holy",SHAMAN="shaman_enhancement",MAGE="mage_frost",WARLOCK="warlock_affliction",DRUID="druid_feralcat"}
XC.Profiles={}
local function add(class,id,spec,role,description,form)
    local weights={}; for k,v in pairs(roleWeights[role]) do weights[k]=v end
    local dpsSlots={}
    if form then dpsSlots[16]=true
    else
        if role=="ranged" then dpsSlots[18]=true
        elseif role=="melee" or role=="tank" then dpsSlots[16]=true; dpsSlots[17]=true end
    end
    XC.Profiles[#XC.Profiles+1]={id=id,class=class,spec=spec,label=XC.ClassLabels[class].." - "..spec,role=role,
        weights=weights,weaponDpsSlots=dpsSlots,
        basis="Starter role weights; not a simulation.",
        description=description.." Specs using this role share starter weights. Customize with /uc weights."}
end
add("WARRIOR","warrior_arms","Arms","melee","Melee damage stat comparison.")
add("WARRIOR","warrior_fury","Fury","melee","Melee damage stat comparison.")
add("WARRIOR","warrior_protection","Protection","tank","Defensive stats and melee weapon DPS; mitigation caps are not simulated.")
add("PALADIN","paladin_holy","Holy","healer","Healing and mana stat comparison.")
add("PALADIN","paladin_protection","Protection","tank","Defensive stat comparison; spell threat and block interactions are not simulated.")
add("PALADIN","paladin_retribution","Retribution","melee","Melee stat comparison; seal and spell interactions are not simulated.")
add("HUNTER","hunter_beastmastery","Beast Mastery","ranged","Ranged attack stats and ranged weapon DPS; pet damage is not simulated.")
add("HUNTER","hunter_marksmanship","Marksmanship","ranged","Ranged attack stats and ranged weapon DPS; shot rotations are not simulated.")
add("HUNTER","hunter_survival","Survival (melee)","melee","Melee attack stats and melee weapon DPS; trap damage is not simulated.")
add("HUNTER","hunter_survivalranged","Survival (ranged)","ranged","Alternative ranged playstyle; ranged attack stats and ranged weapon DPS.")
add("ROGUE","rogue_assassination","Assassination","melee","Melee stat comparison; poison damage and weapon speed are not simulated.")
add("ROGUE","rogue_combat","Combat","melee","Melee stat comparison; weapon speed and rotations are not simulated.")
add("ROGUE","rogue_subtlety","Subtlety","melee","Melee stat comparison; opening attacks and weapon speed are not simulated.")
add("PRIEST","priest_discipline","Discipline","healer","Healing and mana stat comparison; absorb effects are not simulated.")
add("PRIEST","priest_holy","Holy","healer","Healing and mana stat comparison.")
add("PRIEST","priest_shadow","Shadow","caster","Spell damage and mana stat comparison; school-specific effects are not simulated.")
add("SHAMAN","shaman_elemental","Elemental","caster","Spell damage and mana stat comparison.")
add("SHAMAN","shaman_enhancement","Enhancement","melee","Melee stat comparison; imbues and spell interactions are not simulated.")
add("SHAMAN","shaman_restoration","Restoration","healer","Healing and mana stat comparison.")
add("MAGE","mage_arcane","Arcane","caster","Spell damage and mana stat comparison; school-specific effects are not simulated.")
add("MAGE","mage_fire","Fire","caster","Spell damage and mana stat comparison; school-specific effects are not simulated.")
add("MAGE","mage_frost","Frost","caster","Spell damage and mana stat comparison; school-specific effects are not simulated.")
add("WARLOCK","warlock_affliction","Affliction","caster","Spell damage and mana stat comparison; damage-over-time effects are not simulated.")
add("WARLOCK","warlock_demonology","Demonology","caster","Spell damage and mana stat comparison; pet damage is not simulated.")
add("WARLOCK","warlock_destruction","Destruction","caster","Spell damage and mana stat comparison; school-specific effects are not simulated.")
add("DRUID","druid_balance","Balance","caster","Spell damage and mana stat comparison.")
add("DRUID","druid_feralcat","Feral (cat)","melee","Melee stats and main-hand weapon DPS; form abilities and procs are not simulated.",true)
add("DRUID","druid_feralbear","Feral (bear)","tank","Defensive stats and main-hand weapon DPS; form mitigation and procs are not simulated.",true)
add("DRUID","druid_restoration","Restoration","healer","Healing and mana stat comparison.")
XC.KindLabels = {quest="Quest reward",dungeon="Dungeon drop",raid="Raid target",world="World drop",craft="Crafted",vendor="Vendor",reputation="Reputation",auction="Auction house"}
XC.Colors = {bg={.035,.047,.068,1},panel={.065,.081,.11,1},raised={.09,.11,.15,1},border={.17,.21,.28,1},text={.91,.93,.95,1},muted={.59,.66,.75,1},gold={.95,.73,.36,1},reliable={.37,.82,.68,1},dungeon={.4,.67,1,1},longterm={.76,.58,1,1}}
function XC:Print(message)
    if DEFAULT_CHAT_FRAME then DEFAULT_CHAT_FRAME:AddMessage("|cfff2ba5cUpgrade Crossroads|r  "..tostring(message)) end
end
function XC:GetSlot(id)
    for _, slot in ipairs(self.Slots) do if slot.id==id then return slot end end
    return self.Slots[1]
end
local function playerClass(class)
    if not class then local _,token=UnitClass("player"); class=token end
    return XC.ClassLabels[class] and class or "WARRIOR"
end
function XC:GetProfiles(class)
    class=playerClass(class)
    local profiles={}
    for _,profile in ipairs(self.Profiles) do
        if profile.class==class then profiles[#profiles+1]=profile end
    end
    return profiles
end
function XC:ResolveProfileID(id,class)
    class=playerClass(class)
    for _,profile in ipairs(self.Profiles) do
        if profile.id==id and profile.class==class then return id end
    end
    -- Resolve a saved broad role only within this character's class.
    if roleWeights[id] then
        for _,profile in ipairs(self:GetProfiles(class)) do
            if profile.id==self.DefaultProfiles[class] and profile.role==id then return profile.id end
        end
        for _,profile in ipairs(self:GetProfiles(class)) do
            if profile.role==id then return profile.id end
        end
    end
    return self.DefaultProfiles[class]
end
function XC:GetProfile(id)
    id=self:ResolveProfileID(id)
    for _,profile in ipairs(self.Profiles) do
        if profile.id==id then
            local result={}; for k,v in pairs(profile) do result[k]=v end
            result.weights=self.db and self.db.weights and self.db.weights[id] or profile.weights
            return result
        end
    end
end
function XC:MigrateProfiles(class)
    class=playerClass(class)
    local db=self.db
    if not db then return end
    if not db.profileMigration then
        -- Keep old entries as a backup, and independently copy their values.
        -- Existing spec overrides always win. Resetting a spec later stays reset.
        for _,profile in ipairs(self:GetProfiles(class)) do
            local old=db.weights[profile.role]
            if type(old)=="table" and db.weights[profile.id]==nil then
                local copy={}; for k,v in pairs(old) do copy[k]=v end
                db.weights[profile.id]=copy
            end
        end
        db.profileMigration=1
    end
    db.profile=self:ResolveProfileID(db.profile,class)
end
