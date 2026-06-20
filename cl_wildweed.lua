--[[ WILD WEED CLIENT
     Spawns wild weed props at server-decided positions.
     No blips, no markers, no map hints.
     Players who walk close enough will see a press-E prompt.

     Uses _uteknark_near_plant (global set by cl_uteknark.lua) so both
     scripts never fight over the same lib.showTextUI slot.
--]]

local wildWeeds      = {}    -- { index, pos, strain, object }
local inWild         = false
local wildUiShowing  = false -- tracks whether we own the TextUI

-- ── ox_lib wrapper ────────────────────────────────────────────────────────

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

-- ── Prop helpers ──────────────────────────────────────────────────────────

local function spawnWildProp(entry)
    if entry.object then return end
    local model = getWildProp(entry.strain)
    if not IsModelValid(model) then
        Citizen.Trace('WildWeed: invalid model for ' .. tostring(entry.strain) .. '\n')
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

-- ── Index lookup ──────────────────────────────────────────────────────────

local function findWild(index)
    for i, w in ipairs(wildWeeds) do
        if w.index == index then return i, w end
    end
    return nil, nil
end

-- ── Server → Client sync events ───────────────────────────────────────────

RegisterNetEvent('esx_uteknark:wild_data')
AddEventHandler('esx_uteknark:wild_data', function(list)
    for _, w in ipairs(wildWeeds) do deleteWildProp(w) end
    wildWeeds = {}
    for _, entry in ipairs(list) do
        table.insert(wildWeeds, {
            index  = entry.index,
            pos    = entry.pos,
            strain = entry.strain,
            object = nil,
        })
    end
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
    if existing then return end
    table.insert(wildWeeds, {
        index  = entry.index,
        pos    = entry.pos,
        strain = entry.strain,
        object = nil,
    })
end)

-- ── Collection ────────────────────────────────────────────────────────────

local function collectWild(wild)
    if inWild then return end
    inWild = true

    -- Hide TextUI before starting the action
    if wildUiShowing then
        lib.hideTextUI()
        wildUiShowing = false
    end

    Citizen.CreateThread(function()
        -- Optional skillcheck minigame
        local skillOk = lib.skillCheck({ 'easy', 'medium' }, { 'w', 'a', 's', 'd' })
        if not skillOk then
            notify(_U('wild_failed'), 'error')
            inWild = false
            return
        end

        local ok = lib.progressBar({
            duration  = Config.WildWeed.CollectTime,
            label     = _U('wild_progress', getStrainName(wild.strain)),
            canCancel = true,
            disable   = { move = true, car = true, combat = true },
            anim      = { dict = 'pickup_object', clip = 'pickup_low', flag = 1 },
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

-- ── Main loop: prop management + interaction ──────────────────────────────

local SPAWN_DIST   = Config.Distance.Draw
local COLLECT_DIST = Config.Distance.Interact
local prevNearWild = false -- tracks last state for efficient TextUI updates

Citizen.CreateThread(function()
    while true do
        local playerPed = PlayerPedId()
        local myLoc     = GetEntityCoords(playerPed)
        local inVeh     = IsPedInAnyVehicle(playerPed)

        local closest     = nil
        local closestDist = math.huge

        for _, w in ipairs(wildWeeds) do
            local dist = #(w.pos - myLoc)

            -- Lazy spawn within draw range
            if dist <= SPAWN_DIST and not w.object then
                spawnWildProp(w)
            end
            -- Despawn when out of range
            if dist > SPAWN_DIST * 1.1 and w.object then
                deleteWildProp(w)
            end

            if dist < closestDist then
                closestDist = dist
                closest     = w
            end
        end

        -- Determine if we should show wild-weed TextUI.
        -- Only show when: close enough, not in vehicle, no planted-plant UI is active,
        -- no wild action in progress.
        local nearWild = (
            closest and
            closestDist <= COLLECT_DIST and
            not inVeh and
            not inWild and
            not _uteknark_near_plant -- respect planted plant priority
        )

        if nearWild and not prevNearWild then
            -- Just entered range → show TextUI
            lib.showTextUI(_U('press_e_wild', getStrainName(closest.strain)), {
                position = 'left-center',
                icon     = 'leaf',
            })
            wildUiShowing = true
            prevNearWild  = true
        elseif not nearWild and prevNearWild then
            -- Just left range → hide TextUI (only if we own it)
            if wildUiShowing then
                lib.hideTextUI()
                wildUiShowing = false
            end
            prevNearWild = false
        end

        -- E key press handling
        if nearWild and IsControlJustPressed(0, 38) then
            collectWild(closest)
        end

        Citizen.Wait(#wildWeeds > 0 and 0 or 500)
    end
end)

-- ── Request wild weed data once session is ready ──────────────────────────

Citizen.CreateThread(function()
    while not NetworkIsSessionStarted() do Citizen.Wait(100) end
    Citizen.Wait(2500)
    TriggerServerEvent('esx_uteknark:request_wild')
end)

-- ── Cleanup ───────────────────────────────────────────────────────────────

AddEventHandler('onResourceStop', function(name)
    if name ~= GetCurrentResourceName() then return end
    for _, w in ipairs(wildWeeds) do deleteWildProp(w) end
    wildWeeds = {}
    if wildUiShowing then lib.hideTextUI() end
    wildUiShowing = false
    prevNearWild  = false
end)
