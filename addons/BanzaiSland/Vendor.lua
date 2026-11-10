-- Island: vendor visits. Opening a vendor can sell your grey items and repair your gear, then
-- one card sums it up: "Sold 14 junk +2g 10s 4c · Repaired -1g 35s 0c". Both are optional.
local ADDON, ns = ...
if ns.Blocked then return end -- BanzaiSland: the original Island is enabled (Guard.lua)
local L = ns.L

local floor = math.floor
local I, C = ns.Island, ns.C
local GOLD = C.gold
local MUTED_HEX = ns.Hex(C.muted[1], C.muted[2], C.muted[3])
local BATCH = 10            -- items sold per step, so the vendor keeps up
local STEP = 0.25

local V = { open = false }
ns.Vendor = V

local function Money(copper) return ns.Instance and ns.Instance.Money(copper) or ns.MoneyText(copper):sub(2) end

local function NumSlots(bag)
    if C_Container and C_Container.GetContainerNumSlots then return C_Container.GetContainerNumSlots(bag) or 0 end
    return GetContainerNumSlots and GetContainerNumSlots(bag) or 0
end

-- quality, locked, no sale value, item link, stack size
local function SlotInfo(bag, slot)
    if C_Container and C_Container.GetContainerItemInfo then
        local d = C_Container.GetContainerItemInfo(bag, slot)
        if not d then return nil end
        return d.quality, d.isLocked, d.hasNoValue, d.hyperlink, d.stackCount or 1
    elseif GetContainerItemInfo then
        local _, count, locked, quality, _, _, link, _, noValue = GetContainerItemInfo(bag, slot)
        return quality, locked, noValue, link, count or 1
    end
end

local function SellPrice(link)
    local getInfo = (C_Item and C_Item.GetItemInfo) or GetItemInfo
    if not (getInfo and link) then return nil end
    local ok, _, _, _, _, _, _, _, _, _, _, price = pcall(getInfo, link)
    if ok and type(price) == "number" then return price end
end

-- grey items worth something, as { bag, slot, value }
local function Junk()
    local list = {}
    for bag = 0, (NUM_BAG_SLOTS or 4) do
        for slot = 1, NumSlots(bag) do
            local quality, locked, noValue, link, count = SlotInfo(bag, slot)
            if quality == 0 and not locked and not noValue and link then
                local price = SellPrice(link)
                if price and price > 0 then list[#list + 1] = { bag = bag, slot = slot, value = price * (count or 1) } end
            end
        end
    end
    return list
end

local function Use(bag, slot)
    if C_Container and C_Container.UseContainerItem then
        C_Container.UseContainerItem(bag, slot)
    elseif UseContainerItem then
        UseContainerItem(bag, slot)
    end
end

-- ---------------------------------------------------------------- the visit

local function ShowCard()
    local v = V.visit
    V.visit = nil
    if not v or not I.built then return end
    if v.moneyBefore then
        -- what actually happened: items gone from the bags, and the money the vendor paid
        v.sold = math.max(0, (v.total or 0) - #Junk())
        v.earned = math.max(0, GetMoney() - v.moneyBefore + v.repaired)
    end
    if v.sold == 0 and v.repaired == 0 and not v.short then return end
    local bits, line = {}, nil
    if v.sold > 0 then bits[#bits + 1] = L["Sold %d junk +%s"]:format(v.sold, Money(v.earned)) end
    if v.repaired > 0 then bits[#bits + 1] = L["Repaired -%s"]:format(Money(v.repaired)) end
    if v.short then line = L["Not enough gold to repair (%s)"]:format(Money(v.short)) end
    local net = v.earned - v.repaired
    I:PushCard({ group = "loot",
        kind = "won", key = "vendor", glyph = "Coin", tone = GOLD, cap = L["VENDOR"], capColor = GOLD,
        title = table.concat(bits, MUTED_HEX .. "  ·  |r"), color = C.fg,
        res = (v.sold > 0 and v.repaired > 0) and ((net >= 0 and "+" or "-") .. Money(math.abs(net))) or nil,
        resColor = net >= 0 and C.fg or C.muted,
        line = line and (MUTED_HEX .. line .. "|r") or nil, hold = 3.2, priority = 1,
    })
end

local function Repair()
    local v = V.visit
    if not v or not V.open then return end
    if ns.db.vendorRepair and CanMerchantRepair and CanMerchantRepair() and GetRepairAllCost then
        local cost, can = GetRepairAllCost()
        if can and cost and cost > 0 then
            if GetMoney() >= cost then
                RepairAllItems()
                v.repaired = cost
            else
                v.short = cost
            end
        end
    end
    C_Timer.After(0.6, ShowCard)
end

-- sell in small steps; the earnings are what the vendor actually paid
local function SellStep()
    local v = V.visit
    if not v or not V.open then return end
    local list = Junk()
    if #list == 0 or v.steps > 40 then
        C_Timer.After(0.3, Repair)
        return
    end
    v.steps = v.steps + 1
    for i = 1, math.min(BATCH, #list) do
        Use(list[i].bag, list[i].slot)
    end
    C_Timer.After(STEP, SellStep)
end

local function OnShow()
    V.open = true
    if not ns.db or not (ns.db.vendorSell or ns.db.vendorRepair) then return end
    if IsShiftKeyDown and IsShiftKeyDown() then return end       -- hold Shift to skip it this time
    V.visit = { sold = 0, earned = 0, repaired = 0, steps = 0, moneyBefore = GetMoney(),
                total = ns.db.vendorSell and #Junk() or 0 }
    if ns.db.vendorSell then SellStep() else Repair() end
end

local function OnClose()
    V.open = false
    if V.visit then ShowCard() end
end

function ns.DemoVendor()
    V.visit = { sold = 14, earned = 21004, repaired = 13500, steps = 0 }
    ShowCard()
end

local ev = CreateFrame("Frame")
ev:SetScript("OnEvent", function(_, event)
    if event == "MERCHANT_SHOW" then
        OnShow()
    elseif event == "MERCHANT_CLOSED" then
        OnClose()
    end
end)
for _, event in ipairs({ "MERCHANT_SHOW", "MERCHANT_CLOSED" }) do pcall(ev.RegisterEvent, ev, event) end
