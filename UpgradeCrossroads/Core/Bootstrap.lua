local name, XC = ...
XC.name = name
XC.version = "0.5.2"
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
XC.Profiles = {
    {id="melee",label="Melee",weights={str=1,agi=.8,sta=.25,ap=.5,crit=9,hit=10,dps=5}},
    {id="ranged",label="Ranged",weights={agi=1,str=.1,sta=.25,int=.15,rap=.5,ap=.15,crit=9,hit=10,dps=5}},
    {id="caster",label="Caster",weights={int=.6,spi=.2,sta=.2,sp=1,crit=7,hit=9,mpr=1}},
    {id="healer",label="Healer",weights={int=.6,spi=.6,sta=.2,heal=1,sp=.3,mpr=2}},
    {id="tank",label="Tank",weights={sta=1,armor=.025,str=.35,agi=.35,def=2,dodge=8,parry=8,block=5,dps=.4}},
}
XC.KindLabels = {quest="Quest reward",dungeon="Dungeon drop",raid="Raid target",world="World drop",craft="Crafted",vendor="Vendor",reputation="Reputation",auction="Auction house"}
XC.Colors = {bg={.035,.047,.068,1},panel={.065,.081,.11,1},raised={.09,.11,.15,1},border={.17,.21,.28,1},text={.91,.93,.95,1},muted={.59,.66,.75,1},gold={.95,.73,.36,1},reliable={.37,.82,.68,1},dungeon={.4,.67,1,1},longterm={.76,.58,1,1}}
function XC:Print(message)
    if DEFAULT_CHAT_FRAME then DEFAULT_CHAT_FRAME:AddMessage("|cfff2ba5cUpgrade Crossroads|r  "..tostring(message)) end
end
function XC:GetSlot(id)
    for _, slot in ipairs(self.Slots) do if slot.id==id then return slot end end
    return self.Slots[1]
end
function XC:GetProfile(id)
    for _, profile in ipairs(self.Profiles) do
        if profile.id==id then
            return {id=profile.id,label=profile.label,weights=self.db and self.db.weights and self.db.weights[id] or profile.weights}
        end
    end
    return self.Profiles[1]
end
