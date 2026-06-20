-- =========================================================
-- WILD WEED SYSTEM — Client only
-- Kein Blip, kein Marker, keine Map-Hinweise.
-- Pflanzen spawnen zufällig an konfigurierten Positionen.
-- =========================================================

local wildPlants      = {}   -- { pos, strain, prop, object, collected }
local activeWildNear  = {}   -- Pflanzen in Sichtweite (haben ein Objekt)
local wildInteracting = false

-- Beim Resource-Start: zufällig entscheiden welche Positionen spawnen
local function initWildWeed()
    local strainTable = Config.WildWeed.StrainChances

    for _, pos in ipairs(Config.WildWeed.Positions) do
        if math.random() <= Config.WildWeed.SpawnChance then
            -- Sorte zufällig basierend auf Wahrscheinlichkeit wählen
            local roll   = math.random(100)
            local chosen = strainTable[1]
            local cumulative = 0
            for _, entry in ipairs(strainTable) do
                cumulative = cumulative + entry.chance
                if roll <= cumulative then
                    chosen = entry
                    break
                end
            end

            table.insert(wildPlants, {
                pos       = pos,
                strain    = chosen.strain,
                prop      = chosen.prop,
                object    = nil,
                collected = false,
            })
        end
    end
    Citizen.Trace(string.format("[UteKnark] %d Wilde Pflanzen gespawnt\n", #wildPlants))
end

-- Prop laden und erstellen
local function spawnWildProp(entry)
    local model = entry.prop
    if not model or not IsModelValid(model) then
        model = `prop_weed_01`
    end
    if not HasModelLoaded(model) then
        RequestModel(model)
        local deadline = GetGameTimer() + 2500
        while not HasModelLoaded(model) and GetGameTimer() < deadline do
            Citizen.Wait(0)
        end
    end
    if not HasModelLoaded(model) then return end

    local obj = CreateObject(model, entry.pos.x, entry.pos.y, entry.pos.z, false, false, false)
    SetEntityHeading(obj, math.random(0, 359) * 1.0)
    FreezeEntityPosition(obj, true)
    SetEntityCollision(obj, false, true)
    PlaceObjectOnGroundProperly(obj)
    SetModelAsNoLongerNeeded(model)
    entry.object = obj
    table.insert(activeWildNear, entry)
end

-- Prop löschen
local function despawnWildProp(entry)
    if entry.object and DoesEntityExist(entry.object) then
        DeleteObject(entry.object)
    end
    entry.object = nil
    for i, e in ipairs(activeWildNear) do
        if e == entry then
            table.remove(activeWildNear, i)
            break
        end
    end
end

-- Interaktion: Samen sammeln mit Progressbar + Minigame
local function collectWildPlant(entry)
    if wildInteracting then return end
    wildInteracting = true

    local strainData = GetStrainData(entry.strain)
    local strainName = strainData and strainData.name or entry.strain

    if lib.progressBar({
        duration    = Config.WildWeed.CollectTime,
        label       = 'Du sammelst ' .. strainName .. ' Samen...',
        useWhileDead = false,
        canCancel   = true,
        disable     = { move = true, car = true, combat = true },
        anim        = { scenario = 'WORLD_HUMAN_GARDENER_PLANT' },
    }) then
        -- Minigame
        local success = lib.skillCheck(Config.WildWeed.MinigameDifficulty, { 'w', 'a', 's', 'd' })
        if success then
            TriggerServerEvent('esx_uteknark:collectWildSeed', entry.strain)
            entry.collected = true
            despawnWildProp(entry)
            lib.notify({
                title       = 'Wild Weed',
                description = strainName .. ' Samen eingesammelt!',
                type        = 'success',
                duration    = 4000,
            })
        else
            lib.notify({
                title       = 'Wild Weed',
                description = 'Du hast die Pflanze beschädigt!',
                type        = 'error',
                duration    = 3000,
            })
        end
    else
        lib.notify({
            description = 'Einsammeln abgebrochen.',
            type        = 'error',
            duration    = 2000,
        })
    end

    wildInteracting = false
end

-- Haupt-Loop: Props in Reichweite spawnen/despawnen
Citizen.CreateThread(function()
    -- Kurz warten bis Session bereit
    while not NetworkIsSessionStarted() do
        Citizen.Wait(500)
    end

    math.randomseed(GetGameTimer())
    initWildWeed()

    local drawDist = Config.Distance.Draw

    while true do
        local myPos = GetEntityCoords(PlayerPedId())

        -- Props in Sichtweite spawnen
        for _, entry in ipairs(wildPlants) do
            if not entry.collected and not entry.object then
                local dist = #(myPos - entry.pos)
                if dist <= drawDist then
                    spawnWildProp(entry)
                end
            end
        end

        -- Props außer Sichtweite despawnen
        for i = #activeWildNear, 1, -1 do
            local entry = activeWildNear[i]
            local dist = #(myPos - entry.pos)
            if dist > drawDist * 1.05 then
                despawnWildProp(entry)
            end
        end

        Citizen.Wait(2000)
    end
end)

-- Interaktions-Loop: Nächste wilde Pflanze in Reichweite prüfen
Citizen.CreateThread(function()
    while not NetworkIsSessionStarted() do
        Citizen.Wait(500)
    end

    local interactDist = Config.Distance.Interact

    while true do
        if #activeWildNear > 0 and not wildInteracting then
            local myPos     = GetEntityCoords(PlayerPedId())
            local closest   = nil
            local closestD  = interactDist + 1

            for _, entry in ipairs(activeWildNear) do
                if not entry.collected then
                    local d = #(myPos - entry.pos)
                    if d < closestD then
                        closestD = d
                        closest  = entry
                    end
                end
            end

            if closest and closestD <= interactDist then
                local strainData = GetStrainData(closest.strain)
                local name = strainData and strainData.name or closest.strain

                -- Hinweis anzeigen (kein Marker / Blip!)
                BeginTextCommandDisplayHelp('STRING')
                AddTextComponentSubstringPlayerName('~INPUT_PICKUP~ ' .. name .. ' Samen sammeln')
                EndTextCommandDisplayHelp(0, false, true, 1)

                if IsControlJustPressed(0, 38) then -- E
                    collectWildPlant(closest)
                end

                Citizen.Wait(0)
            else
                Citizen.Wait(300)
            end
        else
            Citizen.Wait(500)
        end
    end
end)

-- Cleanup beim Resource-Stop
AddEventHandler('onResourceStop', function(resourceName)
    if resourceName ~= GetCurrentResourceName() then return end
    for _, entry in ipairs(activeWildNear) do
        if entry.object and DoesEntityExist(entry.object) then
            DeleteObject(entry.object)
        end
    end
    wildPlants     = {}
    activeWildNear = {}
end)
