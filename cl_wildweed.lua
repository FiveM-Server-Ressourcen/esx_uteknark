--[[ WILD WEED CLIENT
     Spawns wild weed props at server-decided positions.
     No blips, no markers, no map hints.
     Players who walk close enough will see a press-E prompt.
--]]

local wildWeeds  = {}   -- { index, pos, strain, object }
local inWild     = false

-- ── Helpers ───────────────────────────────────────────────────────────────

local ANIM_PICKUP = { dict = 'pickup_object', clip = 'pickup_low', flag = 1 }

local function notify(msg, ntype)
    lib.notify({
        title       = 'UteKnark',
        description = msg,
        type        = ntype or 'inform',
        duration    = 4000,
    })
end

local function getWildProp(strain)
    return (Config.WildWeed.StrainProps and Config.WildWeed.StrainProps[strain])
        or `prop_weed_01`
end

local function getStrainName(strain)
    return (Config.Strains[strain] and Config.Strains[strain].name) or strain
end

-- ── Prop spawner ──────────────────────────────────────────────────────────

local function spawnWildProp(entry)
    local model = getWildProp(entry.strain)
    if not IsModelValid(model) then
        Citizen.Trace('Wild weed: invalid model for strain ' .. tostring(entry.strain) .. '\n')
        return
    end
    if not HasModelLoaded(model) then
        RequestModel(model)
        local t = GetGameTimer()
        while not HasModelLoaded(model) and GetGameTimer() < t + 3000 do
            Citizen.Wait(0)
        end
    end
    if not HasModelLoaded(model) then return end

    local weed = CreateObject(model, entry.pos, false, false, false)
    SetEntityHeading(weed, math.random(0, 359) * 1.0)
    FreezeEntityPosition(weed, true)
    SetEntityCollision(weed, false, true)
    SetModelAsNoLongerNeeded(model)
    entry.object = weed
end

local function deleteWildProp(entry)
    if entry.object and DoesEntityExist(entry.object) then
        DeleteObject(entry.object)
    end
    entry.object = nil
end

-- ── Find entry by index ───────────────────────────────────────────────────

local function findWild(index)
    for i, w in ipairs(wildWeeds) do
        if w.index == index then return i, w end
    end
    return nil, nil
end

-- ── Server → Client events ────────────────────────────────────────────────

RegisterNetEvent('esx_uteknark:wild_data')
AddEventHandler('esx_uteknark:wild_data', function(list)
    -- Clear existing
    for _, w in ipairs(wildWeeds) do deleteWildProp(w) end
    wildWeeds = {}

    for _, entry in ipairs(list) do
        local w = { index = entry.index, pos = entry.pos, strain = entry.strain, object = nil }
        table.insert(wildWeeds, w)
    end
    -- Props are spawned lazily in the interaction loop as player gets close
end)

RegisterNetEvent('esx_uteknark:wild_remove')
AddEventHandler('esx_uteknark:wild_remove', function(posIndex)
    local i, w = findWild(posIndex)
    if w then
        deleteWildProp(w)
        table.remove(wildWeeds, i)
    end
end)

RegisterNetEvent('esx_uteknark:wild_spawn')
AddEventHandler('esx_uteknark:wild_spawn', function(entry)
    local _, existing = findWild(entry.index)
    if existing then return end -- already there
    table.insert(wildWeeds, { index = entry.index, pos = entry.pos, strain = entry.strain, object = nil })
end)

-- ── Collection action ─────────────────────────────────────────────────────

local function collectWild(wild)
    if inWild then return end
    inWild = true

    Citizen.CreateThread(function()
        -- Optional skillcheck minigame
        local skillOk = lib.skillCheck({ 'easy', 'medium' }, { 'w', 'a', 's', 'd' })
        if not skillOk then
            notify(_U('wild_failed'), 'error')
            inWild = false
            return
        end

        -- Progress bar with animation
        local ok = lib.progressBar({
            duration  = Config.WildWeed.CollectTime,
            label     = _U('wild_progress', getStrainName(wild.strain)),
            canCancel = true,
            disable   = { move = true, car = true, combat = true },
            anim      = ANIM_PICKUP,
        })
        inWild = false
        if ok then
            -- Remove locally immediately for responsiveness
            local i, w = findWild(wild.index)
            if w then
                deleteWildProp(w)
                table.remove(wildWeeds, i)
            end
            TriggerServerEvent('esx_uteknark:collect_wild', wild.index)
        end
    end)
end

-- ── Draw distance / lazy spawn loop ──────────────────────────────────────

local SPAWN_DIST   = Config.Distance.Draw
local COLLECT_DIST = Config.Distance.Interact

Citizen.CreateThread(function()
    while true do
        local playerPed = PlayerPedId()
        local myLoc     = GetEntityCoords(playerPed)

        local closest     = nil
        local closestDist = math.huge

        for _, w in ipairs(wildWeeds) do
            local dist = #(w.pos - myLoc)

            -- Spawn prop if within draw distance and not already spawned
            if dist <= SPAWN_DIST and not w.object then
                spawnWildProp(w)
            end
            -- Despawn if out of draw range
            if dist > SPAWN_DIST * 1.1 and w.object then
                deleteWildProp(w)
            end

            if dist < closestDist then
                closestDist = dist
                closest     = w
            end
        end

        -- Interact with closest wild plant
        if closest and closestDist <= COLLECT_DIST and not IsPedInAnyVehicle(playerPed) then
            if not inWild then
                lib.showTextUI(_U('press_e_wild', getStrainName(closest.strain)), {
                    position = 'left-center',
                    icon     = 'leaf',
                })
                if IsControlJustPressed(0, 38) then -- E
                    lib.hideTextUI()
                    collectWild(closest)
                end
            end
        else
            if not inWild then lib.hideTextUI() end
        end

        Citizen.Wait(#wildWeeds > 0 and 0 or 500)
    end
end)

-- ── Request wild weed data from server once session is ready ───────────────

Citizen.CreateThread(function()
    while not NetworkIsSessionStarted() do Citizen.Wait(100) end
    Citizen.Wait(2000) -- slight delay so server is ready
    TriggerServerEvent('esx_uteknark:request_wild')
end)

-- ── Cleanup ───────────────────────────────────────────────────────────────

AddEventHandler('onResourceStop', function(name)
    if name == GetCurrentResourceName() then
        for _, w in ipairs(wildWeeds) do deleteWildProp(w) end
        wildWeeds = {}
        lib.hideTextUI()
    end
end)
