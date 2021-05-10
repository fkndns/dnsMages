require "DamageLib"
require "2DGeometry"
require "MapPositionGOS"
require "GGPrediction"


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

function CalcRDmg(unit)
    local Damage = 0
    local Distance = GetDistance(myHero.pos, unit.pos)
    local MathDist = math.floor(math.floor(Distance)/100)   
    local level = myHero:GetSpellData(_R).level
    local BaseQ = ({25, 35, 45})[level] + 0.15 * myHero.bonusDamage
    local QMissHeal = ({25, 30, 35})[level] / 100 * (unit.maxHealth - unit.health)
    local dist = myHero.pos:DistanceTo(unit.pos)
    if Distance < 100 then
        Damage = BaseQ + QMissHeal
    elseif Distance >= 1500 then
        Damage = BaseQ * 10 + QMissHeal     
    else
        Damage = ((((MathDist * 6) + 10) / 100) * BaseQ) + BaseQ + QMissHeal
    end
    return CalcPhysicalDamage(myHero, unit, Damage)
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

local function dnsTargetSelector(unit, range)
    local fullDamUnit = (unit.totalDamage + unit.ap * 0.7)
    local healthPercentUnit = (unit.health / unit.maxHealth)
    local unitStrength = fullDamUnit / healthPercentUnit
    local dtarget = nil
    if dtarget ~= nil then
        local fullDamdtarget = (dtarget.totalDamage + dtarget.ap * 0.7) 
        local healthPercentdtarget = (dtarget.health / dtarget.maxHealth) 
        local dtargetStrength = fullDamdtarget / healthPercentdtarget
    end
    if ValidTarget(unit, range) then
        --PrintChat("target")
        if dtarget == nil or unitStrength > dtargetStrength then
            dtarget = unit
            PrintChat(dtarget.charName)
        end
    end
    return dtarget
end

function GetTurretShot(unit)
    local turrets = _G.SDK.ObjectManager:GetTurrets(GetDistance(unit.pos) + 1000)
    for i = 1, #turrets do
        local turret = turrets[i]
        if turret and turret.activeSpell.valid and turret.activeSpell.target == unit.handle and not turret.activeSpell.isStopped and turret.team == 300-myHero.team then
            --PrintChat("turret shot")
            return true
        else
            return false
        end
    end
end

local function CustomCastMM(spell,pos)
    local MMSpot = Vector(pos):ToMM()
    local MouseSpotBefore = mousePos
    Control.SetCursorPos(MMSpot.x, MMSpot.y)
    Control.KeyDown(spell); Control.KeyUp(spell)
    DelayAction(function() Control.SetCursorPos(MouseSpotBefore) end, 0.20)
end

local function HitChanceConvert(menVal)
    if menVal == 1 then
        return 0
    elseif menVal == 2 then 
        return 0.25
    elseif menVal == 3 then
        return 0.5
    elseif menVal == 4 then
        return 0.75
    elseif menVal == 5 then
        return 1
    end
end

function GGCast(spell, target, spellprediction, hitchance)
        if not (target or spellprediction) then
            return false
        end
        if spellprediction == nil then
            if target == nil then
                Control.KeyDown(spell)
                Control.KeyUp(spell)
                return true
            end
            _G.Control.CastSpell(spell, target)
            return true
        end
        if target == nil then
            return false
        end
        spellprediction:GetPrediction(target, myHero)
        if spellprediction:CanHit(hitchance or HITCHANCE_HIGH) and GetDistance(spellprediction.CastPosition, myHero.pos) < spellprediction.Range and GetDistance(spellprediction.CastPosition, target.pos) < 250 then
            _G.Control.CastSpell(spell, spellprediction.CastPosition)
            return true
        end
        return false
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
local Timer = Game.Timer()
local ComboTimer = nil
local AARange = 550
local QRange = 1000
local WRange = 850
local ERange = 615
local RRange = 740
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
    self.Menu.Combo:MenuElement({id = "qcombohc", name = "[Q] HitChance >=", value = 2, drop = {"Normal", "High", "Immobile"}, leftIcon = BrandQIcon})
    self.Menu.Combo:MenuElement({id = "wcombo", name = "Use [W] in Combo", value = true, leftIcon = BrandWIcon})
    self.Menu.Combo:MenuElement({id = "wcombohc", name = "[W] HitChance >=", value = 2, drop = {"Normal","High", "Immobile"}, leftIcon = BrandWIcon})
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

    --misc
    self.Menu:MenuElement({id = "misc", name = "Misc", type = MENU})
    self.Menu.misc:MenuElement({id = "movementhelper", name = "RangeHelper", value = false})
    self.Menu.misc:MenuElement({id = "blockaa", name = "Block [AA] in Combo"})
    self.Menu.misc:MenuElement({id = "blockaalvl", name = "Block [AA] after lvl", value = 9, min = 1, max = 18})

end

function Brand:Spells()
    QSpell = {speed = 1200, delay = 0.25, radius = 60, range = 1000, collision = {"minion"}, type = "linear"}
    WSpell = {speed = math.huge, delay = 0.877, radius = 60, range = 850, collision = {}, type = "circular"}

    Q = GGPrediction:SpellPrediction({Type = GGPrediction.SPELLTYPE_LINE, Speed = 1200, Range = 1000, Delay = 0.25, Radius = 30, Collision = true, CollisionTypes = {GGPrediction.COLLISION_MINION}})
    WPrediction = GGPrediction:SpellPrediction({Type = GGPrediction.SPELLTYPE_CIRCLE, Speed = math.huge, Range = 850, Delay = 0.877, Radius = 50, Collision = false})
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
    target = GetTarget(AARange)
    if target and ValidTarget(target) then
        --PrintChat(target.pos:To2D())
        --PrintChat(mousePos:To2D())
        GaleMouseSpot = self:MoveHelper(target)
    else
        _G.SDK.Orbwalker.ForceMovement = nil
    end
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
    self:AABlock()
end

function Brand:CastingChecks()
    if not CastingQ or not CastingW or not CastingE or not CastingR then
        return true
    else
        return false
    end
end

function Brand:SmoothChecks()
    if self:CastingChecks() and _G.SDK.Cursor.Step == 0 and _G.SDK.Spell:CanTakeAction({q = 0.33, w = 0.33, e = 0.33, r = 0.33}) then
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
    if ValidTarget(enemy, QRange) and self:CanUse(_Q, "Combo") and BuffActive(enemy, PassiveBuff) and self:SmoothChecks() then
        GGCast(HK_Q, enemy, Q, self.Menu.Combo.qcombohc:Value()+1)
    end
end

function Brand:WCombo()
    local WTarget = GetTarget(WRange)
    if ValidTarget(WTarget, WRange) and self:CanUse(_W, "Combo") and self:SmoothChecks() then
        GGCast(HK_W, WTarget, WPrediction, self.Menu.Combo.wcombohc:Value()+1)
    end
end

function Brand:ECombo()
    local ETarget = GetTarget(ERange)
    if ValidTarget(target, ERange) and self:CanUse(_E, "Combo") and self:SmoothChecks() then
        Control.CastSpell(HK_E, target)
    end
end

function Brand:RCombo(enemy)
    if ValidTarget(enemy, RRange) and self:CanUse(_R, "Combo") and GetEnemyCount(550, enemy) >= self.Menu.Combo.rcombocount:Value() and self:SmoothChecks() then
        Control.CastSpell(HK_R, enemy)
    end
end

function Brand:QKS(enemy)
    if ValidTarget(enemy, QRange) and self:CanUse(_Q, "KS") and enemy.health / enemy.maxHealth <= 0.5 and self:SmoothChecks() then
        local QDam = getdmg("Q", enemy, myHero, myHero:GetSpellData(_Q).level)
        if enemy.health <= QDam then
            GGCast(HK_Q, enemy, Q)
        end
    end
end

function Brand:WKS(enemy)
    if ValidTarget(enemy, WRange) and self:CanUse(_W, "KS") and enemy.health / enemy.maxHealth <= 0.5 and self:SmoothChecks() then
        local WDam = getdmg("W", enemy, myHero, myHero:GetSpellData(_W).level)
        if enemy.health <= WDam then
            GGCast(HK_W, enemy, WPrediction)
        end
    end
end

function Brand:EKS(enemy)
    if ValidTarget(enemy, ERange) and self:CanUse(_E, "KS") and enemy.health / enemy.maxHealth <= 0.5 then
        local EDam = getdmg("E", enemy, myHero, myHero:GetSpellData(_E).level)
        if enemy.health <= EDam and self:SmoothChecks() then
            Control.CastSpell(HK_E, enemy)
        end
    end
end

function Brand:DyingR(enemy)
    if ValidTarget(enemy, RRange) and self:CanUse(_R, "Dying") and myHero.health / myHero.maxHealth <= 0.3 and enemy.activeSpell.valid and enemy.activeSpell.spellWasCast and self:SmoothChecks() then
        if enemy.activeSpell.target == myHero.handle then
            Control.CastSpell(HK_R, enemy)
        else
            local placementPos = enemy.activeSpell.placementPos
            local width = myHero.boundingRadius + 50
            if enemy.activeSpell.width > 0 then width = width + enemy.activeSpell.width end
            local spellLine = ClosestPointOnLineSegment(myHero.pos, enemy.pos, placementPos)
            if GetDistance(myHero.pos, spellLine) <= width then
                Control.CastSpell(HK_R, enemy)
            end
        end
    end
end

function Brand:WLaneClear(minion)
    if ValidTarget(minion, WRange) and self:CanUse(_W, "LaneClear") and self:SmoothChecks() and GetMinionCount(WRange, 200, minion) >= self.Menu.laneclear.wlaneclearcount:Value() then
        CustomCast(HK_W, minion)
    end
end

function Brand:AABlock()
    if self.Menu.misc.blockaa:Value() then
        if myHero.levelData.lvl >= self.Menu.misc.blockaalvl:Value() then
            if Mode() == "Combo" then
                _G.SDK.Orbwalker:SetAttack(false)
            else
                _G.SDK.Orbwalker:SetAttack(true)
            end
        end
    end
end

function Brand:MoveHelper(unit)
    local EAARangel = _G.SDK.Data:GetAutoAttackRange(unit)
    local MoveSpot = nil
    local RangeDif = AARange - EAARangel
    local ExtraRangeDist = RangeDif
    local ExtraRangeChaseDist = RangeDif - 100

    local ScanDirection = Vector((myHero.pos-mousePos):Normalized())
    local ScanDistance = GetDistance(myHero.pos, unit.pos) * 0.8
    local ScanSpot = myHero.pos - ScanDirection * ScanDistance
    

    local MouseDirection = Vector((unit.pos-ScanSpot):Normalized())
    local MouseSpotDistance = EAARangel + ExtraRangeDist
    if not IsFacing(unit) then
        MouseSpotDistance = EAARangel + ExtraRangeChaseDist
    end
    if MouseSpotDistance > AARange then
        MouseSpotDistance = AARange
    end

    local MouseSpot = unit.pos - MouseDirection * (MouseSpotDistance)
    local MouseDistance = GetDistance(unit.pos, mousePos)
    local GaleMouseSpotDirection = Vector((myHero.pos-MouseSpot):Normalized())
    local GalemouseSpotDistance = GetDistance(myHero.pos, MouseSpot)
    if GalemouseSpotDistance > 300 then
        GalemouseSpotDistance = 300
    end
    local GaleMouseSpoty = myHero.pos - GaleMouseSpotDirection * GalemouseSpotDistance
    MoveSpot = MouseSpot

    if MoveSpot then
        if GetDistance(myHero.pos, MoveSpot) < 50 or IsUnderEnemyTurret(MoveSpot) then
            _G.SDK.Orbwalker.ForceMovement = nil
        elseif self.Menu.misc.movementhelper:Value() and GetDistance(myHero.pos, unit.pos) <= AARange-50 and (Mode() == "Combo" or Mode() == "Harass") and self:CastingChecks() and MouseDistance < 750 then
            _G.SDK.Orbwalker.ForceMovement = MoveSpot
        else
            _G.SDK.Orbwalker.ForceMovement = nil
        end
    end
    return GaleMouseSpoty
end

function OnLoad()
    Manager()
end

class "Lux"

local EnemyLoaded = false
local AllyLoaded = false
local Timer = Game.Timer()
local ComboTimer = nil

-- lux icons
local HeroIcon = "https://www.proguides.com/public/media/rlocal/champion/splash/99.jpg"
local QIcon = "https://www.proguides.com/public/media/rlocal/champion/ability/thumbnail/LuxLightBinding.png"
local WIcon = "https://www.proguides.com/public/media/rlocal/champion/ability/thumbnail/LuxPrismaticWave.png"
local EIcon = "https://www.proguides.com/public/media/rlocal/champion/ability/thumbnail/LuxLightStrikeKugel.png"
local RIcon = "https://www.proguides.com/public/media/rlocal/champion/ability/thumbnail/LuxMaliceCannon.png"

-- ranges
local AARange = 550
local QRange = 1175
local WRange = 1150
local ERange = 1100
local RRange = 3340

-- buffs
local LuxPassive = "LuxIlluminatingFraulein"
local LuxESlow = "luxeslow"
local LuxQBuff = "LuxLightBindingMis"

--counts 
local RCount = nil
local RMinionCount = nil
local EMinionCount = nil

function Lux:Menu() 
    self.Menu = MenuElement({type = MENU, id = "Lux", name = "dnsLux", leftIcon = HeroIcon})

    -- Combo
    self.Menu:MenuElement({id = "combo", name = "Combo", type = MENU})
    self.Menu.combo:MenuElement({id = "qcombo", name = "Use [Q] in Combo", value = true, leftIcon = QIcon})
    self.Menu.combo:MenuElement({id = "qcombohc", name = "[Q] HitChance >=", value = 2, drop = {"Normal", "High", "Immobile"}, leftIcon = QIcon})
    self.Menu.combo:MenuElement({id = "wcombo", name = "Use [W] in Combo", value = true, leftIcon = WIcon})
    self.Menu.combo:MenuElement({id = "wcombohp", name = "[W] HP <=", value = 80, min = 5, max = 95, step = 5, identifier = "%", leftIcon = WIcon})
    self.Menu.combo:MenuElement({id = "wcomboally", name = "[W] Allies", type = MENU, leftIcon = WIcon})
    self.Menu.combo:MenuElement({id = "ecombo", name = "Use [E] in Combo", value = true, leftIcon = EIcon})
    self.Menu.combo:MenuElement({id = "ecombohc", name = "[E] HitChance >=", value = 2, drop = {"Normal", "High", "Immobile"}, leftIcon = EIcon})
    self.Menu.combo:MenuElement({id = "ecombocount", name = "[E] PokeCount >=", value = 1, min = 1, max = 5, step = 1, leftIcon = EIcon})
    self.Menu.combo:MenuElement({id = "rcombo", name = "Use [R] on immobile Target", value = true, leftIcon = RIcon})
    self.Menu.combo:MenuElement({id = "rmassiv", name = "[R] to Damage multiple Enemies", value = true, leftIcon = RIcon})
    self.Menu.combo:MenuElement({id = "rmassivcount", name = "[R] HitCount >=", value = 3, min = 1, max = 5, step = 1, leftIcon = RIcon})
    self.Menu.combo:MenuElement({id = "rmassivhc", name = "[R] HitChance", value = 2, drop = {"Normal", "High", "Immobile"}, leftIcon = RIcon})
    self.Menu.combo:MenuElement({id = "rsemi", name = "Semi [R]", key = string.byte("T"), toggle = false})


    -- Auto
    self.Menu:MenuElement({id = "auto", name = "Auto", type = MENU})
    self.Menu.auto:MenuElement({id = "qauto", name = "Use [Q] KS", value = true, leftIcon = QIcon})
    self.Menu.auto:MenuElement({id = "qinterrupt", name = "Use [Q] Interrupter", value = true, leftIcon = QIcon})
    self.Menu.auto:MenuElement({id = "wauto", name = "Use [W] Auto", value = true, leftIcon = WIcon})
    self.Menu.auto:MenuElement({id = "wautohp", name = "[W] HP <=", value = 25, min = 5, max = 100, step = 5, identifier = "%", leftIcon = WIcon})
    self.Menu.auto:MenuElement({id = "wautoally", name = "[W] Allies", type = MENU, leftIcon = WIcon})
    self.Menu.auto:MenuElement({id = "eauto", name = "Use [E] KS", value = true, leftIcon = EIcon})
    self.Menu.auto:MenuElement({id = "rauto", name = "Use [R] KS", value = true, leftIcon = RIcon})

    -- LaneClear
    self.Menu:MenuElement({id = "laneclear", name = "LaneClear", type = MENU})
    self.Menu.laneclear:MenuElement({id = "elaneclear", name = "Use [E] in LaneClear", value = true, leftIcon = EIcon})
    self.Menu.laneclear:MenuElement({id = "elaneclearcount", name = "[E] HitCount >=", value = 3, min = 1, max = 7, step = 1, leftIcon = EIcon})
    self.Menu.laneclear:MenuElement({id = "elaneclearmana", name = "[E] Mana >=", value = 40, min = 0, max = 100, step = 5, identifier = "%", leftIcon = EIcon})
    self.Menu.laneclear:MenuElement({id = "rlaneclear", name = "Use [R] in LaneClear", value = true, leftIcon = RIcon})
    self.Menu.laneclear:MenuElement({id = "rlaneclearcount", name = "[R] HitCount >=", value = 6, min = 1, max = 7, step = 1, leftIcon = RIcon})
    self.Menu.laneclear:MenuElement({id = "rlaneclearmana", name = "[R] Mana >=", value = 40, min = 0, max = 100, step = 5, identifier = "%", leftIcon = RIcon})

    --LastHit
    self.Menu:MenuElement({id = "lasthit", name = "LastHit", type = MENU})
    self.Menu.lasthit:MenuElement({id = "qlasthit", name = "Use [Q] on Cannon", value = true, leftIcon = QIcon})
    self.Menu.lasthit:MenuElement({id = "qlasthitmana", name = "[Q] Mana >=", value = 40, min = 5, max = 100, step = 5, identifier = "%", leftIcon = QIcon})
    self.Menu.lasthit:MenuElement({id = "elasthit", name = "Use [E] to LastHit", value = true, leftIcon = EIcon})
    self.Menu.lasthit:MenuElement({id = "elasthitcount", name = "[E] HitCount >=", value = 2, min = 1, max = 7, step = 1, leftIcon = EIcon})
    self.Menu.lasthit:MenuElement({id = "elasthitmana", name = "[E] Mana >=", value = 40, min = 5, max = 100, step = 5, identifier= "%", leftIcon = EIcon})


    -- Draws
    self.Menu:MenuElement({id = "draws", name = "Draws", type = MENU})
    self.Menu.draws:MenuElement({id = "qdraws", name = "Draw [Q] Range", value = false, leftIcon = QIcon})
    self.Menu.draws:MenuElement({id = "wdraws", name = "Draw [W] Range", value = false, leftIcon = WIcon})
    self.Menu.draws:MenuElement({id = "edraws", name = "Draw [E] Range", value = false, leftIcon = EIcon})
    self.Menu.draws:MenuElement({id = "rdraws", name = "Draw [R] Range", value = false, leftIcon = RIcon})

    self.Menu:MenuElement({id = "misc", name = "Misc", type = MENU})
    self.Menu.misc:MenuElement({id = "movementhelper", name = "RangedHelper", value = false})
    self.Menu.misc:MenuElement({id = "blockaa", name = "Block [AA] in Combo", value = true})
    self.Menu.misc:MenuElement({id = "blockaalvl", name = "If [lvl] is higher then", value = 9, min = 1, max = 18, step = 1})

end

function Lux:ActiveMenu()
    for i, ally in pairs(AllyHeroes) do
        self.Menu.combo.wcomboally:MenuElement({id = ally.charName, name = ally.charName, value = true})
        self.Menu.auto.wautoally:MenuElement({id = ally.charName, name = ally.charName, value = true})
    end
end

function Lux:Spells() 
    QSpell = {speed = 1200, range = QRange, delay = 0.25, radius = 40, collision = {"minion"}, type = "linear"}
    WSpell = {speed = 2400, range = WRange, delay = 0.25, radius = 110, collision = {}, type = "linear"}
    ESpell = {speed = 1200, range = ERange, delay = 0.25, radius = 60, collision = {}, type = "circular"}
    RSpell = {speed = math.huge, range = RRange, delay = 1, radius = 50, collision = {}, type = "linear"}

    Q = GGPrediction:SpellPrediction({Type = GGPrediction.SPELLTYPE_LINE, Speed = 1200, Range = 1075, Radius = 30, Delay = 0.25, Collision = true, MaxCollision = 1, CollisionTypes = {GGPrediction.COLLISION_MINION}})
    W = GGPrediction:SpellPrediction({Type = GGPrediction.SPELLTYPE_LINE, Speed = 2400, Range = 1150, Radius = 60, Delay = 0.25, Collision = false})
    E = GGPrediction:SpellPrediction({Type = GGPrediction.SPELLTYPE_CIRCLE, Speed = 1200, Range = 1000, Radius = 50, Delay = 0.25, Collision = false})
    R = GGPrediction:SpellPrediction({Type = GGPrediction.SPELLTYPE_LINE, Speed = math.huge, Range = 3340, Radius = 30, Delay = 1, Collision = false})

end

function Lux:Draws()
    if self.Menu.draws.qdraws:Value() then
        Draw.Circle(myHero, Q.Range, 2, Draw.Color(255, 255, 255, 0))
    end
    if self.Menu.draws.wdraws:Value() then
        Draw.Circle(myHero, W.Range, 2, Draw.Color(255, 255, 0, 255))
    end
    if self.Menu.draws.edraws:Value() then
        Draw.Circle(myHero, E.Range, 2, Draw.Color(255, 0, 255, 255))
    end
    if self.Menu.draws.rdraws:Value() then
        Draw.Circle(myHero, R.Range, 2, Draw.Color(255, 255, 255, 255))
    end
end

function Lux:Tick()
    if _G.JustEvade and _G.JustEvade:Evading() or (_G.ExtLibEvade and _G.ExtLibEvade.Evading) or Game.IsChatOpen() or myHero.dead then return end
    target = GetTarget(AARange)
    if target and ValidTarget(target) then
        --PrintChat(target.pos:To2D())
        --PrintChat(mousePos:To2D())
        GaleMouseSpot = self:MoveHelper(target)
    else
        _G.SDK.Orbwalker.ForceMovement = nil
    end
    CastingQ = myHero.activeSpell.name == "LuxLightBinding"
    CastingW = myHero.activeSpell.name == "LuxPrismaticWave"
    CastingE = myHero.activeSpell.name == "LuxLightStrikeKugel"
    CastingE2 = myHero.activeSpell.name == "LuxLightstrikeToggle"
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
    if AllyLoaded == false then
        local CountAlly = 0
        for i, ally in pairs(AllyHeroes) do
            CountAlly = CountAlly + 1
        end
        if CountAlly < 1 then
            GetAllyHeroes()
        else
            AllyLoaded = true
            PrintChat("Ally Loaded")
            self:ActiveMenu()
        end
    end
    self:Logic()
    self:Auto()
    self:Minions()
    self:AABlock()
end

function Lux:SmoothChecks()
    if self:CastingChecks() and not _G.SDK.Attack:IsActive() and _G.SDK.Cursor.Step == 0 and _G.SDK.Spell:CanTakeAction({q = 0.33, w = 0.33, e = 0.33, r = 1.13}) then
        return true
    else
        return false
    end
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
        if mode == "KS" and IsReady(_Q) and self.Menu.auto.qauto:Value() then
            return true
        end
        if mode == "Interrupter" and IsReady(_Q) and self.Menu.auto.qinterrupt:Value() then
            return true
        end
        if mode == "LastHit" and IsReady(_Q) and self.Menu.lasthit.qlasthit:Value() and myHero.mana / myHero.maxMana >= self.Menu.lasthit.qlasthitmana:Value() / 100 then
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
        if mode == "LastHit" and IsReady(_E) and self.Menu.lasthit.elasthit:Value() and myHero.mana / myHero.maxMana >= self.Menu.lasthit.elasthitmana:Value() / 100 then
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
        if mode == "Massiv" and IsReady(_R) and self.Menu.combo.rmassiv:Value() then
            return true
        end
        if mode == "LaneClear" and IsReady(_R) and self.Menu.laneclear.rlaneclear:Value() and myHero.mana / myHero.maxMana >= self.Menu.laneclear.rlaneclearmana:Value() / 100 then
            return true
        end
        if mode == "Semi" and IsReady(_R) and self.Menu.combo.rsemi:Value() then
            return true
        end
    end
end



function Lux:Logic() 
    self:TurretShield()
    if Mode() == "Combo" then
        self:QCombo()
        self:ECombo()
        self:RCombo()
    end
end

function Lux:Auto()
    for i, enemy in pairs(EnemyHeroes) do
        self:EReact(enemy)
        self:QKS(enemy)
        self:QInterrupt(enemy)
        self:EKS(enemy)
        self:RKS(enemy)
        self:WAuto(enemy)
        self:SemiR(enemy)
        if Mode() == "Combo" then
            self:WCombo(enemy)
            self:RMassive(enemy)
        end

        for j, ally in pairs(AllyHeroes) do 
            self:WAutoAlly(enemy, ally)
            self:TurretShieldAlly(ally)
            if Mode() == "Combo" then
                self:WComboAlly(enemy, ally)
            end
        end
    end
end

function Lux:Minions()
    local minions = _G.SDK.ObjectManager:GetEnemyMinions(QRange)
    for i = 1, #minions do
        local minion = minions[i]

        if Mode() == "LaneClear" then
            self:ELaneClear(minion)
            self:RLaneClear(minion)
        end
        if Mode() == "LastHit" then
            self:QLastHit(minion)
            self:ELastHit(minion)
        end
    end
end

-- [functions] --

function Lux:QCombo()
    local QComboTarget = GetTarget(Q.Range)
    if ValidTarget(QComboTarget) and self:CanUse(_Q, "Combo") and self:SmoothChecks() then
        GGCast(HK_Q, QComboTarget, Q, self.Menu.combo.qcombohc:Value()+1)
    end
end

function Lux:WCombo(enemy)
    if self:CanUse(_W, "Combo") and myHero.health / myHero.maxHealth <= self.Menu.combo.wcombohp:Value() / 100 and enemy.activeSpell.valid and enemy.activeSpell.spellWasCast and self:SmoothChecks() then
        if enemy.activeSpell.target == myHero.handle then
            _G.Control.CastSpell(HK_W)
        else
            local placementPos = enemy.activeSpell.placementPos
            local width = myHero.boundingRadius + 50
            if enemy.activeSpell.width > 0 then width = width + enemy.activeSpell.width end
            local spellLine = ClosestPointOnLineSegment(myHero.pos, enemy.pos, placementPos)
            if GetDistance(myHero.pos, spellLine) <= width then
                _G.Control.CastSpell(HK_W)
            end
        end
    end
end

function Lux:WComboAlly(enemy, ally)
    if ValidTarget(ally, W.Range) and self:CanUse(_W, "Combo") and ally.health / ally.maxHealth <= self.Menu.combo.wcombohp:Value() / 100 and enemy.activeSpell.valid and enemy.activeSpell.spellWasCast and self:SmoothChecks() and self.Menu.combo.wcomboally[ally.charName]:Value() then
        if enemy.activeSpell.target == ally.handle then
            GGCast(HK_W, ally, W)
        else
            local placementPos = enemy.activeSpell.placementPos
            local width = ally.boundingRadius + 50
            if enemy.activeSpell.width > 0 then width = width + enemy.activeSpell.width end
            local spellLine = ClosestPointOnLineSegment(ally.pos, enemy.pos, placementPos)
            if GetDistance(ally.pos, spellLine) <= width then
                GGCast(HK_W, ally, W)
            end
        end
    end
end


function Lux:ECombo()
    local EComboTarget = GetTarget(E.Range)
    if EComboTarget ~= nil and self:CanUse(_E, "Combo") and myHero:GetSpellData(_E).toggleState == 0 and GetEnemyCount(240, EComboTarget) >= self.Menu.combo.ecombocount:Value() and self:SmoothChecks() then
        GGCast(HK_E, EComboTarget, E, self.Menu.combo.ecombohc:Value()+1)
    end
end

function Lux:EReact(enemy)
    if IsValid(enemy) and self:CanUse(_E, "Combo") and myHero:GetSpellData(_E).toggleState == 2 then
        Control.KeyDown(HK_E)
        Control.KeyUp(HK_E)
    end
end

function Lux:RCombo()
    local RComboTarget = GetTarget(R.Range)
    if RComboTarget ~= nil and self:CanUse(_R, "Combo") and self:SmoothChecks() and IsImmobile(RComboTarget) >= 0.5 then
        if RComboTarget.pos:ToScreen().onScreen then
            GGCast(HK_R, RComboTarget, R)
        else
            R:GetPrediction(RComboTarget, myHero)
            local Direction = Vector((myHero.pos-W.CastPosition):Normalized())
            local CastSpot = myHero.pos - Direction * 800
            GGCast(HK_R, CastSpot)
        end
    end
end

function Lux:RMassive(enemy)
    if ValidTarget(enemy, R.Range) and self:CanUse(_R, "Massiv") and self:SmoothChecks() then
        local count = 0
        for j, enemy2 in pairs(EnemyHeroes) do 
            local RLine = ClosestPointOnLineSegment(enemy2.pos, myHero.pos, enemy.pos)
            if GetDistance(enemy2.pos, RLine) <= 120 then
                count = count + 1
            end
        end
        RCount = count
        --PrintChat(RCount)
        if RCount >= self.Menu.combo.rmassivcount:Value() then
            if enemy.pos:ToScreen().onScreen then
                GGCast(HK_R, enemy, R)
            else
                R:GetPrediction(enemy, myHero)
                local Direction = Vector((myHero.pos-R.CastPosition):Normalized())
                local CastSpot = myHero.pos - Direction * 800
                GGCast(HK_R, CastSpot)
            end
        end
    end
end

function Lux:GetRDam(unit)
    local passivdmg = 10 + 10 * myHero.levelData.lvl + myHero.ap * 0.2
    if BuffActive(unit, LuxPassive) then
        local QDam = getdmg("R", unit, myHero, myHero:GetSpellData(_R).level) + CalcMagicalDamage(myHero, unit, passivdmg)
        return QDam
    else
        local QDam = getdmg("R", unit, myHero, myHero:GetSpellData(_R).level)
        return QDam
    end
end


function Lux:QKS(enemy)
    if ValidTarget(enemy, Q.Range) and self:CanUse(_Q, "KS") and self:SmoothChecks() then
        local QDam = getdmg("Q", enemy, myHero, myHero:GetSpellData(_Q).level)
       if enemy.health <= QDam then
            GGCast(HK_Q, enemy, Q)
        end
    end
end

function Lux:QInterrupt(enemy)
    local Timer = Game.Timer()
    if ValidTarget(enemy, Q.Range) and self:CanUse(_Q, "Interrupter") and self:SmoothChecks() and enemy.activeSpell.valid and enemy.activeSpell.castEndTime - Timer > 0.4 then
        GGCast(HK_Q, enemy, Q)
    end
end

function Lux:WAuto(enemy)
    if self:CanUse(_W, "Auto") and myHero.health / myHero.maxHealth <= self.Menu.auto.wautohp:Value() / 100 and enemy.activeSpell.valid and enemy.activeSpell.spellWasCast and self:SmoothChecks() then
        if enemy.activeSpell.target == myHero.handle then
            _G.Control.CastSpell(HK_W)
        else
            local placementPos = enemy.activeSpell.placementPos
            local width = myHero.boundingRadius + 50
            if enemy.activeSpell.width > 0 then width = width + enemy.activeSpell.width end
            local spellLine = ClosestPointOnLineSegment(myHero.pos, enemy.pos, placementPos)
            if GetDistance(myHero.pos, spellLine) <= width then
                _G.Control.CastSpell(HK_W)
            end
        end
    end
end

function Lux:WAutoAlly(enemy, ally) 
  if ValidTarget(ally, W.Range) and self:CanUse(_W, "Auto") and ally.health / ally.maxHealth <= self.Menu.auto.wautohp:Value() / 100 and enemy.activeSpell.valid and enemy.activeSpell.spellWasCast and self:SmoothChecks() and self.Menu.auto.wautoally[ally.charName]:Value() then
        if enemy.activeSpell.target == ally.handle then
            GGCast(HK_W, ally, W)
        else
            local placementPos = enemy.activeSpell.placementPos
            local width = ally.boundingRadius + 50
            if enemy.activeSpell.width > 0 then width = width + enemy.activeSpell.width end
            local spellLine = ClosestPointOnLineSegment(ally.pos, enemy.pos, placementPos)
            if GetDistance(ally.pos, spellLine) <= width then
                GGCast(HK_W, ally, W)
            end
        end
    end
end  

function Lux:TurretShield()
    if self:CanUse(_W, "Auto") and myHero.health / myHero.maxHealth <= self.Menu.auto.wautohp:Value() / 100 and self:SmoothChecks() and GetTurretShot(myHero) then
        _G.Control.CastSpell(HK_W)
    end
end

function Lux:TurretShieldAlly(ally)
    if ValidTarget(ally, W.Range) and self:CanUse(_W, "Auto") and ally.health / ally.maxHealth <= self.Menu.auto.wautohp:Value() / 100 and self:SmoothChecks() and GetTurretShot(ally) then
        GGCast(HK_W, ally, W)
    end
end


function Lux:EKS(enemy)
    if ValidTarget(enemy, E.Range) and self:CanUse(_E, "KS") and myHero:GetSpellData(_E).toggleState == 0 and self:SmoothChecks() then
        local EDam = getdmg("E", enemy, myHero, myHero:GetSpellData(_E).level)
        if enemy.health <= EDam then
            GGCast(HK_E, enemy, E)
        end
    end
end

function Lux:RKS(enemy)
    if ValidTarget(enemy, R.Range) and self:CanUse(_R, "KS") and self:SmoothChecks() then
        local RDam = self:GetRDam(enemy)
        if enemy.health <= RDam then
            if enemy.pos:ToScreen().onScreen then
                GGCast(HK_R, enemy, R)
            else
                R:GetPrediction(enemy, myHero)
                local Direction = Vector((myHero.pos-R.CastPosition):Normalized())
                local CastSpot = myHero.pos - Direction * 800
                GGCast(HK_R, CastSpot)
            end
        end
    end
end

function Lux:ELaneClear(minion)
    if ValidTarget(minion, E.Range) and self:CanUse(_E, "LaneClear") and myHero:GetSpellData(_E).toggleState == 0 and self:SmoothChecks() and GetMinionCount(ERange, 200, minion) >= self.Menu.laneclear.elaneclearcount:Value() then
        CustomCast(HK_E, minion)
    end
    if myHero:GetSpellData(_E).toggleState == 2 then
        Control.CastSpell(HK_E)
    end
end

function Lux:RLaneClear(minion)
    if ValidTarget(minion, Q.Range) and self:CanUse(_R, "LaneClear") and self:SmoothChecks() then
        local count = 0
        local minions2 = _G.SDK.ObjectManager:GetEnemyMinions(QRange)
        for i = 1, #minions2 do
            local minion2 = minions2[i]
            local RLine = ClosestPointOnLineSegment(minion2.pos, myHero.pos, minion.pos)
            if GetDistance(minion2.pos, RLine) <= 120 then
                count = count + 1
            end
        end
        RMinionCount = count
        if RMinionCount >= self.Menu.laneclear.rlaneclearcount:Value() then
            GGCast(HK_R, minion)
        end
    end
end

function Lux:QLastHit(minion)
    if ValidTarget(minion, Q.Range) and self:CanUse(_Q, "LastHit") and self:SmoothChecks() and (minion.charName == "SRU_ChaosMinionSiege" or minion.charName == "SRU_OrderMinionSiege") then
        local QDam = getdmg("Q", minion, myHero, myHero:GetSpellData(_Q).level)
        if minion.health <= QDam then
            GGCast(HK_Q, minion)
        end
    end
end

function Lux:ELastHit(minion)
    if ValidTarget(minion, E.Range) and self:CanUse(_E, "LastHit") and self:SmoothChecks() then
        local EDam = getdmg("E", minion, myHero, myHero:GetSpellData(_E).level)
        if minion.health <= EDam then
            local count = 0
            local minions2 = _G.SDK.ObjectManager:GetEnemyMinions(ERange)
            for i = 1, #minions2 do
                local minion2 = minions2[i]
                local EDam2 = getdmg("E", minion2, myHero, myHero:GetSpellData(_E).level)
                if minion2.health <= EDam2 and GetDistance(minion.pos, minion2.pos) <= 200 then
                    count = count + 1
                end
            end
            EMinionCount = count
            if EMinionCount >= self.Menu.lasthit.elasthitcount:Value() then
                GGCast(HK_E, minion)
            end
        end
    end
    if myHero:GetSpellData(_E).toggleState == 2 then
        _G.Control.CastSpell(HK_E)
    end
end

function Lux:SemiR(enemy)
    if ValidTarget(enemy, R.Range) and self:CanUse(_R, "Semi") and self:SmoothChecks() and GetDistance(enemy.pos, mousePos) <= 400 then
        GGCast(HK_R, enemy, R)
    end
end

function Lux:AABlock()
    if self.Menu.misc.blockaa:Value() then
        if myHero.levelData.lvl >= self.Menu.misc.blockaalvl:Value() then
            if Mode() == "Combo" then
                _G.SDK.Orbwalker:SetAttack(false)
            else
                _G.SDK.Orbwalker:SetAttack(true)
            end
        end
    end
end

function Lux:MoveHelper(unit)
    local EAARangel = _G.SDK.Data:GetAutoAttackRange(unit)
    local MoveSpot = nil
    local RangeDif = AARange - EAARangel
    local ExtraRangeDist = RangeDif
    local ExtraRangeChaseDist = RangeDif - 100

    local ScanDirection = Vector((myHero.pos-mousePos):Normalized())
    local ScanDistance = GetDistance(myHero.pos, unit.pos) * 0.8
    local ScanSpot = myHero.pos - ScanDirection * ScanDistance
    

    local MouseDirection = Vector((unit.pos-ScanSpot):Normalized())
    local MouseSpotDistance = EAARangel + ExtraRangeDist
    if not IsFacing(unit) then
        MouseSpotDistance = EAARangel + ExtraRangeChaseDist
    end
    if MouseSpotDistance > AARange then
        MouseSpotDistance = AARange
    end

    local MouseSpot = unit.pos - MouseDirection * (MouseSpotDistance)
    local MouseDistance = GetDistance(unit.pos, mousePos)
    local GaleMouseSpotDirection = Vector((myHero.pos-MouseSpot):Normalized())
    local GalemouseSpotDistance = GetDistance(myHero.pos, MouseSpot)
    if GalemouseSpotDistance > 300 then
        GalemouseSpotDistance = 300
    end
    local GaleMouseSpoty = myHero.pos - GaleMouseSpotDirection * GalemouseSpotDistance
    MoveSpot = MouseSpot

    if MoveSpot then
        if GetDistance(myHero.pos, MoveSpot) < 50 or IsUnderEnemyTurret(MoveSpot) then
            _G.SDK.Orbwalker.ForceMovement = nil
        elseif self.Menu.misc.movementhelper:Value() and GetDistance(myHero.pos, unit.pos) <= AARange-50 and (Mode() == "Combo" or Mode() == "Harass") and self:CastingChecks() and MouseDistance < 750 then
            _G.SDK.Orbwalker.ForceMovement = MoveSpot
        else
            _G.SDK.Orbwalker.ForceMovement = nil
        end
    end
    return GaleMouseSpoty
end

function OnLoad()
    Manager()
end

