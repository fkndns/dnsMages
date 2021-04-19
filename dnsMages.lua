require "PremiumPrediction"
require "DamageLib"
require "2DGeometry"
require "MapPositionGOS"


local EnemyHeroes = {}
local AllyHeroes = {}
local EnemySpawnPos = nil
local AllySpawnPos = nil

--[[ AutoUpdate deactivated until proper rank.
do
    
    local Version = 1.0
    
    local Files = {
        Lua = {
            Path = SCRIPT_PATH,
            Name = "dnsMages.lua",
            Url = "https://raw.githubusercontent.com/fkndns/dnsMages/main/dnsMages.lua"
       },
        Version = {
            Path = SCRIPT_PATH,
            Name = "dnsActivator.version",
            Url = "https://raw.githubusercontent.com/fkndns/dnsMages/main/dnsMages.version"    -- check if Raw Adress correct pls.. after you have create the version file on Github
        }
    }
    
    local function AutoUpdate()
        
        local function DownloadFile(url, path, fileName)
            DownloadFileAsync(url, path .. fileName, function() end)
            while not FileExist(path .. fileName) do end
        end
        
        local function ReadFile(path, fileName)
            local file = io.open(path .. fileName, "r")
            local result = file:read()
            file:close()
            return result
        end
        
        DownloadFile(Files.Version.Url, Files.Version.Path, Files.Version.Name)
        local textPos = myHero.pos:To2D()
        local NewVersion = tonumber(ReadFile(Files.Version.Path, Files.Version.Name))
        if NewVersion > Version then
            DownloadFile(Files.Lua.Url, Files.Lua.Path, Files.Lua.Name)
            print("New dnsMarksmen Version. Press 2x F6")     -- <-- you can change the massage for users here !!!!
        else
            print(Files.Version.Name .. ": No Updates Found")   --  <-- here too
        end
    
    end
    
    AutoUpdate()

end 
--]]

local ItemHotKey = {[ITEM_1] = HK_ITEM_1, [ITEM_2] = HK_ITEM_2,[ITEM_3] = HK_ITEM_3, [ITEM_4] = HK_ITEM_4, [ITEM_5] = HK_ITEM_5, [ITEM_6] = HK_ITEM_6,}

local function GetInventorySlotItem(itemID)
    assert(type(itemID) == "number", "GetInventorySlotItem: wrong argument types (<number> expected)")
    for _, j in pairs({ITEM_1, ITEM_2, ITEM_3, ITEM_4, ITEM_5, ITEM_6}) do
        if myHero:GetItemData(j).itemID == itemID and myHero:GetSpellData(j).currentCd == 0 then return j end
    end
    return nil
end

local function IsNearEnemyTurret(pos, distance)
    --PrintChat("Checking Turrets")
    local turrets = _G.SDK.ObjectManager:GetTurrets(GetDistance(pos) + 1000)
    for i = 1, #turrets do
        local turret = turrets[i]
        if turret and GetDistance(turret.pos, pos) <= distance+915 and turret.team == 300-myHero.team then
            --PrintChat("turret")
            return turret
        end
    end
end

local function IsUnderEnemyTurret(pos)
    --PrintChat("Checking Turrets")
    local turrets = _G.SDK.ObjectManager:GetTurrets(GetDistance(pos) + 1000)
    for i = 1, #turrets do
        local turret = turrets[i]
        if turret and GetDistance(turret.pos, pos) <= 915 and turret.team == 300-myHero.team then
            --PrintChat("turret")
            return turret
        end
    end
end

function GetDifference(a,b)
    local Sa = a^2
    local Sb = b^2
    local Sdif = (a-b)^2
    return math.sqrt(Sdif)
end

function GetDistanceSqr(Pos1, Pos2)
    local Pos2 = Pos2 or myHero.pos
    local dx = Pos1.x - Pos2.x
    local dz = (Pos1.z or Pos1.y) - (Pos2.z or Pos2.y)
    return dx^2 + dz^2
end

function DrawTextOnHero(hero, text, color)
    local pos2D = hero.pos:To2D()
    local posX = pos2D.x - 50
    local posY = pos2D.y
    Draw.Text(text, 28, posX + 50, posY - 15, color)
end

function GetDistance(Pos1, Pos2)
    return math.sqrt(GetDistanceSqr(Pos1, Pos2))
end

function IsImmobile(unit)
    local MaxDuration = 0
    for i = 0, unit.buffCount do
        local buff = unit:GetBuff(i)
        if buff and buff.count > 0 then
            local BuffType = buff.type
            if BuffType == 5 or BuffType == 11 or BuffType == 21 or BuffType == 22 or BuffType == 24 or BuffType == 29 or buff.name == "recall" then
                local BuffDuration = buff.duration
                if BuffDuration > MaxDuration then
                    MaxDuration = BuffDuration
                end
            end
        end
    end
    return MaxDuration
end

function IsCleanse(unit)
    local MaxDuration = 0
    for i = 0, unit.buffCount do
        local buff = unit:GetBuff(i)
        if buff and buff.count > 0 then
            local BuffType = buff.type
            if BuffType == 5 or BuffType == 8 or BuffType == 9 or BuffType == 11 or BuffType == 21 or BuffType == 22 or BuffType == 24 or BuffType == 31 then
                local BuffDuration = buff.duration
                if BuffDuration > MaxDuration then
                    MaxDuration = BuffDuration
                end
            end
        end
    end
    return MaxDuration
end

function IsChainable(unit)
    local MaxDuration = 0
    for i = 0, unit.buffCount do
        local buff = unit:GetBuff(i)
        if buff and buff.count > 0 then
            local BuffType = buff.type
            if BuffType == 5 or BuffType == 8 or BuffType == 9 or BuffType == 11 or BuffType == 21 or BuffType == 22 or BuffType == 24 or BuffType == 31 or BuffType == 10 then
                local BuffDuration = buff.duration
                if BuffDuration > MaxDuration then
                    MaxDuration = BuffDuration
                end
            end
        end
    end
    return MaxDuration
end

function GetEnemyHeroes()
    for i = 1, Game.HeroCount() do
        local Hero = Game.Hero(i)
        if Hero.isEnemy then
            table.insert(EnemyHeroes, Hero)
            PrintChat(Hero.name)
        end
    end
    --PrintChat("Got Enemy Heroes")
end

function GetEnemyBase()
    for i = 1, Game.ObjectCount() do
        local object = Game.Object(i)
        
        if not object.isAlly and object.type == Obj_AI_SpawnPoint then 
            EnemySpawnPos = object
            break
        end
    end
end

function GetAllyBase()
    for i = 1, Game.ObjectCount() do
        local object = Game.Object(i)
        
        if object.isAlly and object.type == Obj_AI_SpawnPoint then 
            AllySpawnPos = object
            break
        end
    end
end

function GetAllyHeroes()
    for i = 1, Game.HeroCount() do
        local Hero = Game.Hero(i)
        if Hero.isAlly and Hero.charName ~= myHero.charName then
            table.insert(AllyHeroes, Hero)
            PrintChat(Hero.name)
        end
    end
    --PrintChat("Got Enemy Heroes")
end

function GetBuffStart(unit, buffname)
    for i = 0, unit.buffCount do
        local buff = unit:GetBuff(i)
        if buff.name == buffname and buff.count > 0 then 
            return buff.startTime
        end
    end
    return nil
end

function GetBuffExpire(unit, buffname)
    for i = 0, unit.buffCount do
        local buff = unit:GetBuff(i)
        if buff.name == buffname and buff.count > 0 then 
            return buff.expireTime
        end
    end
    return nil
end

function GetBuffDuration(unit, buffname)
    for i = 0, unit.buffCount do
        local buff = unit:GetBuff(i)
        if buff.name == buffname and buff.count > 0 then 
            return buff.duration
        end
    end
    return 0
end

function GetBuffStacks(unit, buffname)
    for i = 0, unit.buffCount do
        local buff = unit:GetBuff(i)
        if buff.name == buffname and buff.count > 0 then 
            return buff.count
        end
    end
    return 0
end

local function GetWaypoints(unit) -- get unit's waypoints
    local waypoints = {}
    local pathData = unit.pathing
    table.insert(waypoints, unit.pos)
    local PathStart = pathData.pathIndex
    local PathEnd = pathData.pathCount
    if PathStart and PathEnd and PathStart >= 0 and PathEnd <= 20 and pathData.hasMovePath then
        for i = pathData.pathIndex, pathData.pathCount do
            table.insert(waypoints, unit:GetPath(i))
        end
    end
    return waypoints
end

local function GetUnitPositionNext(unit)
    local waypoints = GetWaypoints(unit)
    if #waypoints == 1 then
        return nil -- we have only 1 waypoint which means that unit is not moving, return his position
    end
    return waypoints[2] -- all segments have been checked, so the final result is the last waypoint
end

local function GetUnitPositionAfterTime(unit, time)
    local waypoints = GetWaypoints(unit)
    if #waypoints == 1 then
        return unit.pos -- we have only 1 waypoint which means that unit is not moving, return his position
    end
    local max = unit.ms * time -- calculate arrival distance
    for i = 1, #waypoints - 1 do
        local a, b = waypoints[i], waypoints[i + 1]
        local dist = GetDistance(a, b)
        if dist >= max then
            return Vector(a):Extended(b, dist) -- distance of segment is bigger or equal to maximum distance, so the result is point A extended by point B over calculated distance
        end
        max = max - dist -- reduce maximum distance and check next segments
    end
    return waypoints[#waypoints] -- all segments have been checked, so the final result is the last waypoint
end

function GetTarget(range)
    if _G.SDK then
        return _G.SDK.TargetSelector:GetTarget(range, _G.SDK.DAMAGE_TYPE_MAGICAL);
    else
        return _G.GOS:GetTarget(range,"AD")
    end
end

function GotBuff(unit, buffname)
    for i = 0, unit.buffCount do
        local buff = unit:GetBuff(i)
        --PrintChat(buff.name)
        if buff.name == buffname and buff.count > 0 then 
            return buff.count
        end
    end
    return 0
end

function BuffActive(unit, buffname)
    for i = 0, unit.buffCount do
        local buff = unit:GetBuff(i)
        if buff.name == buffname and buff.count > 0 then 
            return true
        end
    end
    return false
end

function IsReady(spell)
    return myHero:GetSpellData(spell).currentCd == 0 and myHero:GetSpellData(spell).level > 0 and myHero:GetSpellData(spell).mana <= myHero.mana and Game.CanUseSpell(spell) == 0
end

function Mode()
    if _G.SDK then
        if _G.SDK.Orbwalker.Modes[_G.SDK.ORBWALKER_MODE_COMBO] then
            return "Combo"
        elseif _G.SDK.Orbwalker.Modes[_G.SDK.ORBWALKER_MODE_HARASS] or Orbwalker.Key.Harass:Value() then
            return "Harass"
        elseif _G.SDK.Orbwalker.Modes[_G.SDK.ORBWALKER_MODE_LANECLEAR] or Orbwalker.Key.Clear:Value() then
            return "LaneClear"
        elseif _G.SDK.Orbwalker.Modes[_G.SDK.ORBWALKER_MODE_LASTHIT] or Orbwalker.Key.LastHit:Value() then
            return "LastHit"
        elseif _G.SDK.Orbwalker.Modes[_G.SDK.ORBWALKER_MODE_FLEE] then
            return "Flee"
        end
    else
        return GOS.GetMode()
    end
end

function GetItemSlot(unit, id)
    for i = ITEM_1, ITEM_7 do
        if unit:GetItemData(i).itemID == id then
            return i
        end
    end
    return 0
end

function IsFacing(unit)
    local V = Vector((unit.pos - myHero.pos))
    local D = Vector(unit.dir)
    local Angle = 180 - math.deg(math.acos(V*D/(V:Len()*D:Len())))
    if math.abs(Angle) < 80 then 
        return true  
    end
    return false
end

function IsMyHeroFacing(unit)
    local V = Vector((myHero.pos - unit.pos))
    local D = Vector(myHero.dir)
    local Angle = 180 - math.deg(math.acos(V*D/(V:Len()*D:Len())))
    if math.abs(Angle) < 80 then 
        return true  
    end
    return false
end

function SetMovement(bool)
    if _G.PremiumOrbwalker then
        _G.PremiumOrbwalker:SetAttack(bool)
        _G.PremiumOrbwalker:SetMovement(bool)       
    elseif _G.SDK then
        _G.SDK.Orbwalker:SetMovement(bool)
        _G.SDK.Orbwalker:SetAttack(bool)
    end
end


local function CheckHPPred(unit, SpellSpeed)
     local speed = SpellSpeed
     local range = myHero.pos:DistanceTo(unit.pos)
     local time = range / speed
     if _G.SDK and _G.SDK.Orbwalker then
         return _G.SDK.HealthPrediction:GetPrediction(unit, time)
     elseif _G.PremiumOrbwalker then
         return _G.PremiumOrbwalker:GetHealthPrediction(unit, time)
    end
end

function EnableMovement()
    SetMovement(true)
end

local function IsValid(unit)
    if (unit and unit.valid and unit.isTargetable and unit.alive and unit.visible and unit.networkID and unit.pathing and unit.health > 0) then
        return true;
    end
    return false;
end

local function ClosestPointOnLineSegment(p, p1, p2)
    local px = p.x
    local pz = p.z
    local ax = p1.x
    local az = p1.z
    local bx = p2.x
    local bz = p2.z
    local bxax = bx - ax
    local bzaz = bz - az
    local t = ((px - ax) * bxax + (pz - az) * bzaz) / (bxax * bxax + bzaz * bzaz)
    if (t < 0) then
        return p1, false
    end
    if (t > 1) then
        return p2, false
    end
    return {x = ax + t * bxax, z = az + t * bzaz}, true
end

local function ValidTarget(unit, range)
    if (unit and unit.valid and unit.isTargetable and unit.alive and unit.visible and unit.networkID and unit.pathing and unit.health > 0) then
        if range then
            if GetDistance(unit.pos) <= range then
                return true;
            end
        else
            return true
        end
    end
    return false;
end

local function GetEnemyCount(range, pos)
    local pos = pos.pos
    local count = 0
    for i, hero in pairs(EnemyHeroes) do
    local Range = range * range
        if GetDistanceSqr(pos, hero.pos) < Range and IsValid(hero) then
        count = count + 1
        end
    end
    return count
end

local function GetAllyCount(range, pos)
    local pos = pos.pos
    local count = 0
    for i, hero in pairs(AllyHeroes) do
    local Range = range * range
        if GetDistanceSqr(pos, hero.pos) < Range and IsValid(hero) then
        count = count + 1
        end
    end
    return count
end

local function GetMinionCount(checkrange, range, pos)
    local minions = _G.SDK.ObjectManager:GetEnemyMinions(checkrange)
    local pos = pos.pos
    local count = 0
    for i = 1, #minions do 
        local minion = minions[i]
        local Range = range * range
        if GetDistanceSqr(pos, minion.pos) < Range and IsValid(minion) then
            count = count + 1
        end
    end
    return count
end

class "Manager"

function Manager:__init()
    if myHero.charName == "Brand" then
        DelayAction(function() self:LoadBrand() end, 1.05)
    end
    if myHero.charName == "Lux" then
        DelayAction(function() self:LoadLux() end, 1.05)
    end
    if myHero.charName == "Irelia" then
        DelayAction(function() self:LoadIrelia() end, 1.05)
    end
end

function Manager:LoadBrand()
    Brand:Spells()
    Brand:Menu()
    Callback.Add("Tick", function() Brand:Tick() end)
    Callback.Add("Draw", function() Brand:Draws() end)
end

function Manager:LoadLux()
    Lux:Spells()
    Lux:Menu()
    Callback.Add("Tick", function() Lux:Tick() end)
    Callback.Add("Draw", function() Lux:Draws() end)
end

function Manager:LoadIrelia()
    Irelia:Spells()
    Irelia:Menu()
    Callback.Add("Tick", function() Irelia:Tick() end)
    Callback.Add("Draw", function() Irelia:Draws() end)
end


class "Brand"

local EnemyLoaded = false
local QRange = 980 + myHero.boundingRadius
local WRange = 830 + myHero.boundingRadius
local ERange = 556 + myHero.boundingRadius
local RRange = 682 + myHero.boundingRadius
local PassiveBuff = "BrandAblaze"
local BrandIcon = "https://www.proguides.com/public/media/rlocal/champion/thumbnail/63.png"
local BrandQIcon = "https://www.proguides.com/public/media/rlocal/champion/ability/thumbnail/BrandQ.png"
local BrandWIcon = "https://www.proguides.com/public/media/rlocal/champion/ability/thumbnail/BrandW.png"
local BrandEIcon = "https://www.proguides.com/public/media/rlocal/champion/ability/thumbnail/BrandE.png"
local BrandRIcon = "https://www.proguides.com/public/media/rlocal/champion/ability/thumbnail/BrandR.png"

function Brand:Menu()
    self.Menu = MenuElement({type = MENU, id = "brand", name = "dnsBrand", leftIcon = BrandIcon})

    -- Combo
    self.Menu:MenuElement({id = "Combo", name = "Combo", type = MENU})
    self.Menu.Combo:MenuElement({id = "qcombo", name = "Use [Q] in Combo", value = true, leftIcon = BrandQIcon})
    self.Menu.Combo:MenuElement({id = "qcombohc", name = "[Q] HitChance >=", value = 0.7, min = 0.1, max = 1.0, step = 0.1, leftIcon = BrandQIcon})
    self.Menu.Combo:MenuElement({id = "wcombo", name = "Use [W] in Combo", value = true, leftIcon = BrandWIcon})
    self.Menu.Combo:MenuElement({id = "wcombohc", name = "[W] HitChance >=", value = 0.5, min = 0.1, max = 1.0, step = 0.1, leftIcon = BrandWIcon})
    self.Menu.Combo:MenuElement({id = "ecombo", name = "Use [E] in Combo", value = true, leftIcon = BrandEIcon})
    self.Menu.Combo:MenuElement({id = "rcombo", name = "Use [R] in Combo", value = true, leftIcon = BrandRIcon})
    self.Menu.Combo:MenuElement({id = "rcombocount", name = "[R] HitCount >=", value = 3, min = 1, max = 5, step = 1, leftIcon = BrandRIcon})


    -- Auto
    self.Menu:MenuElement({id = "Auto", name = "Auto", type = MENU})
    self.Menu.Auto:MenuElement({id = "qks", name = "[Q] KS", value = true, leftIcon = BrandQIcon})
    self.Menu.Auto:MenuElement({id = "wks", name = "[W] KS", value = true, leftIcon = BrandWIcon})
    self.Menu.Auto:MenuElement({id = "eks", name = "[E] KS", value = true, leftIcon = BrandEIcon})
    self.Menu.Auto:MenuElement({id = "dyingr", name = "[R] when dying", value = true, leftIcon = BrandRIcon})


    -- LaneClear
    self.Menu:MenuElement({id = "laneclear", name = "LaneClear", type = MENU})
    self.Menu.laneclear:MenuElement({id = "wlaneclear", name = "Use [W] in LaneClear", value = true, leftIcon = BrandWIcon})
    self.Menu.laneclear:MenuElement({id = "wlaneclearcount", name = "[W] HitCount >=", value = 3, min = 1, max = 7, leftIcon = BrandWIcon})
    self.Menu.laneclear:MenuElement({id = "wlaneclearmana", name = "[W] Mana >=", value = 40, min = 0, max = 100, step = 5, identifier = "%", leftIcon = BrandWIcon})


    -- Draws
    self.Menu:MenuElement({id = "Draws", name = "Draws", type = MENU})
    self.Menu.Draws:MenuElement({id = "qdraw", name = "Draw [Q] Range", value = false, leftIcon = BrandQIcon})
    self.Menu.Draws:MenuElement({id = "wdraw", name = "Draw [W] Range", value = false, leftIcon = BrandWIcon})
    self.Menu.Draws:MenuElement({id = "edraw", name = "Draw [E] Range", value = false, leftIcon = BrandEIcon})
    self.Menu.Draws:MenuElement({id = "rdraw", name = "Draw [R] Range", value = false, leftIcon = BrandRIcon})


end

function Brand:Spells()
    QSpellData = {speed = 1600, range = QRange, delay = 0.25, radius = 70, collision = {"minion"}, type = "linear"}
    WSpellData = {speed = math.huge, range = WRange, delay = 0.85, radius = 200, collision = {}, type = "circular"}
end

function Brand:Draws()
    if self.Menu.Draws.qdraw:Value() then
        Draw.Circle(myHero, QRange, 2, Draw.Color(255, 234, 156, 19))
    end
    if self.Menu.Draws.wdraw:Value() then
        Draw.Circle(myHero, WRange, 2, Draw.Color(255, 127, 234, 19))
    end
    if self.Menu.Draws.edraw:Value() then
        Draw.Circle(myHero, ERange, 2, Draw.Color(255, 19, 234, 215))
    end
    if self.Menu.Draws.rdraw:Value() then
        Draw.Circle(myHero, RRange, 2, Draw.Color(255, 234, 19, 231))
    end
end

function Brand:Tick()
    if _G.JustEvade and _G.JustEvade:Evading() or (_G.ExtLibEvade and _G.ExtLibEvade.Evading) or Game.IsChatOpen() or myHero.dead then return end
    target = GetTarget(1200)
    CastingQ = myHero.activeSpell.name == "BrandQ"
    CastingW = myHero.activeSpell.name == "BrandW"
    CastingE = myHero.activeSpell.name == "BrandE"
    CastingR = myHero.activeSpell.name == "BrandR"
    if EnemyLoaded == false then
        local CountEnemy = 0
        for i, enemy in pairs(EnemyHeroes) do
            CountEnemy = CountEnemy + 1
        end
        if CountEnemy < 1 then
            GetEnemyHeroes()
        else
            EnemyLoaded = true
            PrintChat("Enemy Loaded")
        end
    end
    self:Logic()
    self:Auto()
    self:Minions()
end

function Brand:CastingChecks()
    if not CastingQ or not CastingW or not CastingE or not CastingR then
        return true
    else
        return false
    end
end

function Brand:CanUse(spell, mode)
    if mode == nil then
        mode = Mode()
    end

    if spell == _Q then
        if mode == "Combo" and IsReady(_Q) and self.Menu.Combo.qcombo:Value() then
            return true
        end
        if mode == "KS" and IsReady(_Q) and self.Menu.Auto.qks:Value() then
            return true
        end
    end
    if spell == _W then
        if mode == "Combo" and IsReady(_W) and self.Menu.Combo.wcombo:Value() then
            return true
        end
        if mode == "KS" and IsReady(_W) and self.Menu.Auto.wks:Value() then
            return true
        end
        if mode == "LaneClear" and IsReady(_W) and self.Menu.laneclear.wlaneclear:Value() and myHero.mana / myHero.maxMana >= self.Menu.laneclear.wlaneclearmana:Value() / 100 then
            return true
        end
    end
    if spell == _E then
        if mode == "Combo" and IsReady(_E) and self.Menu.Combo.ecombo:Value() then
            return true
        end
        if mode == "KS" and IsReady(_E) and self.Menu.Auto.eks:Value() then
            return true
        end
    end
    if spell == _R then
        if mode == "Combo" and IsReady(_R) and self.Menu.Combo.rcombo:Value() then
            return true
        end
        if mode == "Dying" and IsReady(_R) and self.Menu.Auto.dyingr:Value() then
            return true
        end
    end
end

function Brand:Logic()
    if target == nil then return end

    if Mode() == "Combo" then
        self:WCombo()
        self:ECombo()
    end

end

function Brand:Auto()
    for i, enemy in pairs(EnemyHeroes) do


        self:QKS(enemy)
        self:WKS(enemy)
        self:EKS(enemy)
        self:DyingR(enemy)


        if Mode() == "Combo" then
            self:QCombo(enemy)
            self:RCombo(enemy)
        end
    end
end

function Brand:Minions()
    local minions = _G.SDK.ObjectManager:GetEnemyMinions(WRange)
    for i = 1, #minions do
        local minion = minions[i]
        if Mode() == "LaneClear" then
            self:WLaneClear(minion)
        end
    end
end




-- [functions] -- 

function Brand:QCombo(enemy)
    if ValidTarget(enemy, QRange) and self:CanUse(_Q, "Combo") and GetBuffDuration(enemy, PassiveBuff) >= 0.1 then
        local pred = _G.PremiumPrediction:GetPrediction(myHero, enemy, QSpellData)
        if pred.CastPos and pred.HitChance >= self.Menu.Combo.qcombohc:Value() and self:CastingChecks() then
            Control.CastSpell(HK_Q, pred.CastPos)
        end
    end
end

function Brand:WCombo()
    if ValidTarget(target, WRange) and self:CanUse(_W, "Combo") then
        local pred = _G.PremiumPrediction:GetPrediction(myHero, target, WSpellData)
        if pred.CastPos and pred.HitChance >= self.Menu.Combo.wcombohc:Value() and self:CastingChecks() and myHero.attackData.state ~= 2 then
            Control.CastSpell(HK_W, pred.CastPos)
        end
    end
end

function Brand:ECombo()
    if ValidTarget(target, ERange) and self:CanUse(_E, "Combo") and self:CastingChecks() and myHero.attackData.state ~= 2 then
        Control.CastSpell(HK_E, target)
    end
end

function Brand:RCombo(enemy)
    if ValidTarget(enemy, RRange) and self:CanUse(_R, "Combo") and GetEnemyCount(550, enemy) >= self.Menu.Combo.rcombocount:Value() and self:CastingChecks() then
        Control.CastSpell(HK_R, enemy)
    end
end

function Brand:QKS(enemy)
    if ValidTarget(enemy, QRange) and self:CanUse(_Q, "KS") and enemy.health / enemy.maxHealth <= 0.5 then
        local QDam = getdmg("Q", enemy, myHero, myHero:GetSpellData(_Q).level)
        if enemy.health <= QDam then
            local pred = _G.PremiumPrediction:GetPrediction(myHero, enemy, QSpellData)
            if pred.CastPos and pred.HitChance >= 0.5 and self:CastingChecks() then
                Control.CastSpell(HK_Q, pred.CastPos)
            end
        end
    end
end

function Brand:WKS(enemy)
    if ValidTarget(enemy, WRange) and self:CanUse(_W, "KS") and enemy.health / enemy.maxHealth <= 0.5 then
        local WDam = getdmg("W", enemy, myHero, myHero:GetSpellData(_W).level)
        if enemy.health <= WDam then
            local pred = _G.PremiumPrediction:GetPrediction(myHero, enemy, QSpellData)
            if pred.CastPos and pred.HitChance >= 0.5 and self:CastingChecks() then
                Control.CastSpell(HK_W, pred.CastPos)
            end
        end
    end
end

function Brand:EKS(enemy)
    if ValidTarget(enemy, ERange) and self:CanUse(_E, "KS") and enemy.health / enemy.maxHealth <= 0.5 then
        local EDam = getdmg("E", enemy, myHero, myHero:GetSpellData(_E).level)
        if enemy.health <= EDam and self:CastingChecks() then
            Control.CastSpell(HK_E, enemy)
        end
    end
end

function Brand:DyingR(enemy)
    if ValidTarget(enemy, RRange) and self:CanUse(_R, "Dying") and myHero.health / myHero.maxHealth <= 0.15 and enemy.activeSpell.target == myHero.handle then
        Control.CastSpell(HK_R, enemy)
    end
end

function Brand:WLaneClear(minion)
    if ValidTarget(minion, WRange) and self:CanUse(_W, "LaneClear") and self:CastingChecks() and myHero.attackData.state ~= 2 and GetMinionCount(WRange, 200, minion) >= self.Menu.laneclear.wlaneclearcount:Value() then
        local pred = _G.PremiumPrediction:GetPrediction(myHero, minion, WSpellData)
        if pred.CastPos and pred.HitChance >= 0.25 then
            Control.CastSpell(HK_W, pred.CastPos)
        end
    end
end


function OnLoad()
    Manager()
end

class "Lux"

local EnemyLoaded = false
local QRange = 1240 + myHero.boundingRadius
local WRange = 1175 + myHero.boundingRadius
local ERange = 1100 + myHero.boundingRadius
local RRange = 3400 + myHero.boundingRadius
local LuxPassive = "LuxIlluminatingFraulein"
local LuxESlow = "luxeslow"


function Lux:Menu() 
    self.Menu = MenuElement({type = MENU, id = "Lux", name = "dnsLux"})

    -- Combo
    self.Menu:MenuElement({id = "combo", name = "Combo", type = MENU})
    self.Menu.combo:MenuElement({id = "qcombo", name = "Use [Q] in Combo", value = true})
    self.Menu.combo:MenuElement({id = "qcombohc", name = "[Q] HitChance >=", value = 0.5, min = 0.1, max = 1.0, step = 0.1})
    self.Menu.combo:MenuElement({id = "wcombo", name = "Use [W] in Combo", value = true})
    self.Menu.combo:MenuElement({id = "wcombohp", name = "[W] HP <=", value = 80, min = 5, max = 95, step = 5, identifier = "%"})
    self.Menu.combo:MenuElement({id = "ecombo", name = "Use [E] in Combo", value = true})
    self.Menu.combo:MenuElement({id = "ecombohc", name = "[E] HitChance >=", value = 0.5, min = 0.1, max = 1.0, step = 0.1})
    self.Menu.combo:MenuElement({id = "ecombocount", name = "[E] PokeCount >=", value = 1, min = 1, max = 5, step = 1})
    self.Menu.combo:MenuElement({id = "rcombo", name = "Use [R] in Combo", value = true})
    self.Menu.combo:MenuElement({id = "rcombohc", name = "[R] HitChance >=", value = 0.5, min = 0.1, max = 1.0, step = 0.1})


    -- Auto
    self.Menu:MenuElement({id = "auto", name = "Auto", type = MENU})
    self.Menu.auto:MenuElement({id = "qauto", name = "Use [Q] Auto", value = true})
    self.Menu.auto:MenuElement({id = "wauto", name = "Use [W] Auto", value = true})
    self.Menu.auto:MenuElement({id = "eauto", name = "Use [E] KS", value = true})
    self.Menu.auto:MenuElement({id = "rauto", name = "Use [R] KS", value = true})

    -- LaneClear
    self.Menu:MenuElement({id = "laneclear", name = "LaneClear", type = MENU})
    self.Menu.laneclear:MenuElement({id = "elaneclear", name = "Use [E] in LaneClear", value = true})
    self.Menu.laneclear:MenuElement({id = "elaneclearcount", name = "[E] HitCount >=", value = 3, min = 1, max = 7, step = 1})
    self.Menu.laneclear:MenuElement({id = "elaneclearmana", name = "[E] Mana >=", value = 40, min = 0, max = 100, step = 5, identifier = "%"})


    -- Draws
    self.Menu:MenuElement({id = "draws", name = "Draws", type = MENU})
    self.Menu.draws:MenuElement({id = "qdraws", name = "Draw [Q] Range", value = false})
    self.Menu.draws:MenuElement({id = "wdraws", name = "Draw [W] Range", value = false})
    self.Menu.draws:MenuElement({id = "edraws", name = "Draw [E] Range", value = false})
    self.Menu.draws:MenuElement({id = "rdraws", name = "Draw [R] Range", value = false})

end

function Lux:Spells() 
    QSpellData = {speed = 1200, range = QRange, delay = 0.25, radius = 70, collision = {"minion"}, type = "linear"}
    WSpellData = {speed = 2400, range = WRange, delay = 0.25, radius = 110, collision = {}, type = "linear"}
    ESpellData = {speed = 1200, range = ERange, delay = 0.25, radius = 300, collision = {}, type = "circular"}
    RSpellData = {speed = math.huge, range = RRange, delay = 1, radius = 120, collision = {}, type = "linear"}
end

function Lux:Draws()
    if self.Menu.draws.qdraws:Value() then
        Draw.Circle(myHero, QRange, 2, Draw.Color(255, 255, 255, 0))
    end
    if self.Menu.draws.wdraws:Value() then
        Draw.Circle(myHero, WRange, 2, Draw.Color(255, 255, 0, 255))
    end
    if self.Menu.draws.edraws:Value() then
        Draw.Circle(myHero, ERange, 2, Draw.Color(255, 0, 255, 255))
    end
    if self.Menu.draws.rdraws:Value() then
        Draw.Circle(myHero, RRange, 2, Draw.Color(255, 255, 255, 255))
    end
end

function Lux:Tick()
    if _G.JustEvade and _G.JustEvade:Evading() or (_G.ExtLibEvade and _G.ExtLibEvade.Evading) or Game.IsChatOpen() or myHero.dead then return end
    target = GetTarget(1300)
    CastingQ = myHero.activeSpell.name == "LuxLightBinding"
    CastingW = myHero.activeSpell.name == "LuxPrismaticWave"
    CastingE = myHero.activeSpell.name == "LuxLightStrikeKugel"
    CastingE2 = myHero.activeSpell.name == "LuxLightStrikeToggle"
    CastingR = myHero.activeSpell.name == "LuxMaliceCannon"
    if EnemyLoaded == false then
        local CountEnemy = 0
        for i, enemy in pairs(EnemyHeroes) do
            CountEnemy = CountEnemy + 1
        end
        if CountEnemy < 1 then
            GetEnemyHeroes()
        else
            EnemyLoaded = true
            PrintChat("Enemy Loaded")
        end
    end
    self:Logic()
    self:Auto()
    self:Minions()
end

function Lux:CastingChecks()
    if not CastingQ or not CastingW or not CastingE or not CastingE2 or not CastingR then
        return true
    else
        return false
    end
end

function Lux:CanUse(spell, mode)
    if mode == nil then 
        mode = Mode()
    end

    if spell == _Q then
        if mode == "Combo" and IsReady(_Q) and self.Menu.combo.qcombo:Value() then
            return true
        end
        if mode == "Auto" and IsReady(_Q) and self.Menu.auto.qauto:Value() then
            return true
        end
    end
    if spell == _W then
        if mode == "Combo" and IsReady(_W) and self.Menu.combo.wcombo:Value() then
            return true
        end
        if mode == "Auto" and IsReady(_W) and self.Menu.auto.wauto:Value() then
            return true
        end
    end
    if spell == _E then
        if mode == "Combo" and IsReady(_E) and self.Menu.combo.ecombo:Value() then
            return true
        end
        if mode == "KS" and IsReady(_E) and self.Menu.auto.eauto:Value() then
            return true
        end
        if mode == "LaneClear" and IsReady(_E) and self.Menu.laneclear.elaneclear:Value() and myHero.mana / myHero.maxMana >= self.Menu.laneclear.elaneclearmana:Value() / 100 then
            return true
        end
    end
    if spell == _R then
        if mode == "Combo" and IsReady(_R) and self.Menu.combo.rcombo:Value() then
            return true
        end
        if mode == "KS" and IsReady(_R) and self.Menu.auto.rauto:Value() then
            return true
        end
    end
end



function Lux:Logic() 
    if target == nil then return end

    if Mode() == "Combo" then
        self:QCombo()
    end
end

function Lux:Auto()
    for i, enemy in pairs(EnemyHeroes) do

    end
end

function Lux:Minions()
    local minions = _G.SDK.ObjectManager:GetEnemyMinions(ERange)
    for i = 1, #minions do
        local minion = minions[i]
    end
end

-- [functions] --

function Lux:QCombo()
    if ValidTarget(target, QRange) and self:CanUse(_Q, "Combo") and self:CastingChecks() then
        local pred = _G.PremiumPrediction:GetPrediction(myHero, target, QSpellData)
        if pred.CastPos and pred.HitChance >= self.Menu.combo.qcombohc:Value() then
            Control.CastSpell(HK_Q, pred.CastPos)
        end
    end
end


function OnLoad()
    Manager()
end
