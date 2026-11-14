local _, XC = ...
local cache

function XC:CatalogRank(comparison, context, profile)
    local item, slotID = comparison.item, comparison.slotID
    if not item or item.randomSuffix or not slotID or not comparison.score or comparison.status == "future"
        or comparison.status == "incomplete" or comparison.status == "unavailable" then return end
    local snapshot = self.Catalog[item.id]
    if not snapshot or snapshot.inv ~= item.inv then return end
    local slot = self:GetSlot(slotID)
    local rules = self.Rules
    local score = rules.Score(snapshot, profile.weights, slotID, profile.weaponDpsSlots)
    if not score or math.abs(score - comparison.score) > .01 then return end

    local options = self.db.options
    if not cache or cache.catalog ~= self.Catalog or cache.context ~= context or cache.weights ~= profile.weights
        or cache.profileID ~= profile.id or cache.crafted ~= options.crafted
        or cache.auction ~= options.auction or cache.solo ~= options.solo then
        cache = {catalog=self.Catalog, context=context, weights=profile.weights, profileID=profile.id,
            crafted=options.crafted, auction=options.auction, solo=options.solo, slots={}}
    end
    if not cache.slots[slotID] then
        local candidates = {}
        local sources = {faction=context.side == 1 and "alliance" or (context.side == 2 and "horde" or "both"),
            crafted=options.crafted, auction=options.auction, solo=options.solo}
        for id, entry in pairs(self.Catalog) do
            if rules.Usable(entry, context, slot) and rules.MinimumLevel(entry,context,slot)<=context.level then
                for _, source in ipairs(entry.sources or {}) do
                    if (source.minLevel or 0) <= context.level and rules.SourceAllowed(source, context, sources) then
                        local value = rules.Score(entry, profile.weights, slotID, profile.weaponDpsSlots)
                        if value and value > 0 then candidates[#candidates+1] = {id=id, score=value} end
                        break
                    end
                end
            end
        end
        table.sort(candidates, function(a, b)
            if a.score ~= b.score then return a.score > b.score end
            return a.id < b.id
        end)
        local ranks, previousScore, position = {}
        for i, candidate in ipairs(candidates) do
            if not previousScore or previousScore-candidate.score>1e-6 then
                previousScore,position=candidate.score,i
            end
            ranks[candidate.id]=position
        end
        cache.slots[slotID] = {rank=ranks, top=candidates[1] and candidates[1].score, count=#candidates}
    end
    local ranked = cache.slots[slotID]
    return ranked.rank[item.id], ranked.top, ranked.count
end
