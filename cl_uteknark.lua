local table        = table
local activePlants = {}
local inAction     = false  -- prevents overlapping progress bars

-- Shared flag: cl_wildweed.lua reads this so both files
-- never fight over the same lib.showTextUI slot.
_uteknark_near_plant = false

-- ── Animation dicts ───────────────────────────────────────────────────────

local ANIM_GARDEN = { dict = 'amb@world_human_gardener_plant@male@idle_a', clip = 'idle_a',   flag = 1 }
local ANIM_PICKUP = { dict = 'pickup_object',                              clip = 'pickup_low', flag = 1 }

-- ── ox_lib notification wrapper ───────────────────────────────────────────

local function notify(msg, ntype)
    lib.notify({
        title       = 'UteKnark',
        description = msg,
        type        = ntype or 'inform',
        duration    = 4000,
    })
end

-- ── Burn / particle effect ────────────────────────────────────────────────

RegisterNetEvent('esx_uteknark:pyromaniac')
AddEventHandler('esx_uteknark:pyromaniac', function(location)
    if not Config.Burn.Enabled then return end
    local myLoc = GetEntityCoords(PlayerPedId())
    if not location then location = myLoc + vector3(0, 0, -1) end
    if #(location - myLoc) > Config.Distance.Draw then return end
    Citizen.CreateThread(function()
        local begin = GetGameTimer()
        RequestNamedPtfxAsset(Config.Burn.Collection)
        while not HasNamedPtfxAssetLoaded(Config.Burn.Collection) and GetGameTimer() < begin + 5000 do
            Citizen.Wait(0)
        end
        UseParticleFxAsset(Config.Burn.Collection)
        local handle = StartParticleFxLoopedAtCoord(
            Config.Burn.Effect, location + Config.Burn.Offset,
            Config.Burn.Rotation, Config.Burn.Scale, false, false, false
        )
        while GetGameTimer() < begin + Config.Burn.Duration do Citizen.Wait(0) end
        StopParticleFxLooped(handle, 0)
        RemoveNamedPtfxAsset(Config.Burn.Collection)
    end)
end)

-- Legacy toast → ox_lib notify bridge
RegisterNetEvent('esx_uteknark:make_toast')
AddEventHandler('esx_uteknark:make_toast', function(_, message)
    notify(message)
end)

-- ── Plant prop spawner ────────────────────────────────────────────────────

local function spawnPlantProp(entry)
    local stage  = entry.data.stage  or 1
    local strain = entry.data.strain or 'og_kush'
    local model  = GetPlantModel(strain, stage)

    if not model or not IsModelValid(model) then
        model = `prop_mp_cone_01`
    end
    if not HasModelLoaded(model) then
        RequestModel(model)
        local t = GetGameTimer()
        while not HasModelLoaded(model) and GetGameTimer() < t + 2500 do
            Citizen.Wait(0)
        end
    end
    if not HasModelLoaded(model) then
        Citizen.Trace('UteKnark: Failed to load model for plant ' .. tostring(entry.data.id) .. '\n')
        return
    end

    local offset = (Growth[stage] and Growth[stage].offset) or vector3(0, 0, 0)
    local weed   = CreateObject(model, entry.bounds.location + offset, false, false, false)
    SetEntityHeading(weed, math.random(0, 359) * 1.0)
    FreezeEntityPosition(weed, true)
    SetEntityCollision(weed, false, true)
    if Config.SetLOD then
        SetEntityLodDist(weed, math.floor(Config.Distance.Draw))
    end
    table.insert(activePlants, {
        node   = entry,
        object = weed,
        at     = entry.bounds.location,
        stage  = stage,
        strain = strain,
        id     = entry.data.id,
    })
    entry.data.object = weed
    SetModelAsNoLongerNeeded(model)
end

-- ── Scan octree and spawn nearby props (background loop) ──────────────────

Citizen.CreateThread(function()
    local drawDist = Config.Distance.Draw * 1.01
    while true do
        local here = GetEntityCoords(PlayerPedId())
        cropstate.octree:searchSphereAsync(here, drawDist, function(entry)
            if not entry.data.object and not entry.data.deleted then
                spawnPlantProp(entry)
            end
        end, true)
        Citizen.Wait(1500)
    end
end)

-- ── DrawIndicator (ring at plant base) ───────────────────────────────────

local function DrawIndicator(location, color)
    DrawMarker(6, location, 0.0, 0.0, 0.0, -90.0, 0.0, 0.0,
        1.0, 1.0, 1.0,
        color[1], color[2], color[3], color[4],
        false, false, 2, false, 0, 0, false)
end

local function getStrainName(strain)
    return (Config.Strains[strain] and Config.Strains[strain].name) or strain
end

-- ── ox_lib context menu for a planted plant ───────────────────────────────

local function showPlantMenu(plant)
    local stageData  = Growth[plant.stage]
    local strainName = getStrainName(plant.strain)
    local options    = {}

    -- Primary stage action (tend or harvest)
    if stageData and stageData.interact then
        if stageData.yield then
            table.insert(options, {
                title       = _U('menu_harvest'),
                description = _U('menu_harvest_desc'),
                icon        = 'seedling',
                onSelect    = function()
                    if inAction then return end
                    inAction = true
                    Citizen.CreateThread(function()
                        local ok = lib.progressBar({
                            duration  = Config.ActionTime,
                            label     = _U('harvest_progress'),
                            canCancel = true,
                            disable   = { move = true, car = true, combat = true },
                            anim      = ANIM_GARDEN,
                        })
                        inAction = false
                        if ok then
                            TriggerServerEvent('esx_uteknark:frob', plant.id, GetEntityCoords(PlayerPedId()))
                        end
                    end)
                end,
            })
        else
            table.insert(options, {
                title       = _U('menu_tend'),
                description = _U('menu_tend_desc'),
                icon        = 'hand',
                onSelect    = function()
                    if inAction then return end
                    inAction = true
                    Citizen.CreateThread(function()
                        local ok = lib.progressBar({
                            duration  = Config.ActionTime,
                            label     = _U('tend_progress'),
                            canCancel = true,
                            disable   = { move = true, car = true, combat = true },
                            anim      = ANIM_GARDEN,
                        })
                        inAction = false
                        if ok then
                            TriggerServerEvent('esx_uteknark:frob', plant.id, GetEntityCoords(PlayerPedId()))
                        end
                    end)
                end,
            })
        end
    end

    -- Water
    table.insert(options, {
        title       = _U('menu_water'),
        description = _U('menu_water_desc'),
        icon        = 'droplet',
        onSelect    = function()
            if inAction then return end
            inAction = true
            Citizen.CreateThread(function()
                local ok = lib.progressBar({
                    duration  = 5000,
                    label     = _U('water_progress'),
                    canCancel = true,
                    disable   = { move = true, car = true, combat = true },
                    anim      = ANIM_GARDEN,
                })
                inAction = false
                if ok then
                    TriggerServerEvent('esx_uteknark:water', plant.id, GetEntityCoords(PlayerPedId()))
                end
            end)
        end,
    })

    -- Fertilize
    table.insert(options, {
        title       = _U('menu_fertilize'),
        description = _U('menu_fertilize_desc'),
        icon        = 'flask',
        onSelect    = function()
            if inAction then return end
            inAction = true
            Citizen.CreateThread(function()
                local ok = lib.progressBar({
                    duration  = 5000,
                    label     = _U('fertilize_progress'),
                    canCancel = true,
                    disable   = { move = true, car = true, combat = true },
                    anim      = ANIM_GARDEN,
                })
                inAction = false
                if ok then
                    TriggerServerEvent('esx_uteknark:fertilize', plant.id, GetEntityCoords(PlayerPedId()))
                end
            end)
        end,
    })

    -- Destroy
    table.insert(options, {
        title       = _U('menu_destroy'),
        description = _U('menu_destroy_desc'),
        icon        = 'trash',
        onSelect    = function()
            if inAction then return end
            inAction = true
            Citizen.CreateThread(function()
                local ok = lib.progressBar({
                    duration  = Config.ActionTime,
                    label     = _U('destroy_progress'),
                    canCancel = true,
                    disable   = { move = true, car = true, combat = true },
                    anim      = ANIM_GARDEN,
                })
                inAction = false
                if ok then
                    local myLoc = GetEntityCoords(PlayerPedId())
                    for i, p in ipairs(activePlants) do
                        if p.id == plant.id then
                            if DoesEntityExist(p.object) then DeleteObject(p.object) end
                            table.remove(activePlants, i)
                            break
                        end
                    end
                    TriggerServerEvent('esx_uteknark:remove', plant.id, myLoc)
                end
            end)
        end,
    })

    lib.registerContext({
        id      = 'uteknark_plant_menu',
        title   = strainName .. ' – Stage ' .. tostring(plant.stage) .. '/' .. tostring(#Growth),
        options = options,
    })
    lib.showContext('uteknark_plant_menu')
end

-- ── Main plant interaction loop ───────────────────────────────────────────

Citizen.CreateThread(function()
    local drawDist = Config.Distance.Draw * 1.01
    while true do
        local playerPed = PlayerPedId()

        if #activePlants > 0 then
            local myLoc           = GetEntityCoords(playerPed)
            local closestDistance
            local closestPlant

            for i = #activePlants, 1, -1 do
                local plant = activePlants[i]
                local dist  = #(plant.at - myLoc)
                if not DoesEntityExist(plant.object) then
                    table.remove(activePlants, i)
                elseif dist > drawDist then
                    DeleteObject(plant.object)
                    plant.node.data.object = nil
                    table.remove(activePlants, i)
                elseif not closestDistance or dist < closestDistance then
                    closestDistance = dist
                    closestPlant    = plant
                end
            end

            if closestPlant and closestDistance and not IsPedInAnyVehicle(playerPed) then
                if closestDistance <= Config.Distance.Interact then
                    local stageData = Growth[closestPlant.stage]
                    if stageData then
                        DrawIndicator(closestPlant.at + stageData.marker.offset, stageData.marker.color)
                    end
                    if not inAction then
                        if not _uteknark_near_plant then
                            _uteknark_near_plant = true
                        end
                        lib.showTextUI(_U('press_e_options'), { position = 'left-center', icon = 'cannabis' })
                        if IsControlJustPressed(0, 38) then -- E key
                            lib.hideTextUI()
                            showPlantMenu(closestPlant)
                        end
                    end
                else
                    if _uteknark_near_plant then
                        _uteknark_near_plant = false
                        lib.hideTextUI()
                    end
                end
            else
                if _uteknark_near_plant then
                    _uteknark_near_plant = false
                    lib.hideTextUI()
                end
            end
            Citizen.Wait(0)
        else
            if _uteknark_near_plant then
                _uteknark_near_plant = false
                lib.hideTextUI()
            end
            Citizen.Wait(500)
        end
    end
end)

-- ── Planting ──────────────────────────────────────────────────────────────

local plantingOffset = vector3(0, 2, -3)

local function getGroundLocation()
    local ped = PlayerPedId()
    if IsPedInAnyVehicle(ped) then return false, 'planting_in_vehicle' end

    local from   = GetEntityCoords(ped)
    local target = GetOffsetFromEntityInWorldCoords(ped, plantingOffset)
    local ray    = StartShapeTestRay(from, target, 17, ped, 7)
    local _, hit, hitLoc = GetShapeTestResult(ray)

    if hit ~= 1 then return false, 'planting_no_ground' end
    if #(from - hitLoc) > Config.Distance.Interact then return false, 'planting_too_far', hitLoc end

    local hits = cropstate.octree:searchSphere(hitLoc, Config.Distance.Space)
    if #hits > 0 then return false, 'planting_too_close', hitLoc end

    return true, 'planting_ok', hitLoc
end

RegisterNetEvent('esx_uteknark:attempt_plant')
AddEventHandler('esx_uteknark:attempt_plant', function(strainKey)
    if inAction then return end
    local ok, reason, location = getGroundLocation()
    if not ok then
        notify(_U(reason), 'error')
        return
    end
    local strainName = (Config.Strains[strainKey] and Config.Strains[strainKey].name) or strainKey
    inAction = true
    Citizen.CreateThread(function()
        local success = lib.progressBar({
            duration  = Config.ActionTime,
            label     = _U('planting_progress', strainName),
            canCancel = true,
            disable   = { move = true, car = true, combat = true },
            anim      = ANIM_GARDEN,
        })
        inAction = false
        if success then
            TriggerServerEvent('esx_uteknark:success_plant', location, strainKey)
        end
    end)
end)

-- ── Cleanup ────────────────────────────────────────────────────────────────

AddEventHandler('onResourceStop', function(name)
    if name ~= GetCurrentResourceName() then return end
    for _, plant in ipairs(activePlants) do
        if DoesEntityExist(plant.object) then DeleteObject(plant.object) end
    end
    activePlants         = {}
    _uteknark_near_plant = false
    lib.hideTextUI()
end)

-- ── Debug toggle ──────────────────────────────────────────────────────────

RegisterNetEvent('esx_uteknark:toggle_debug')
AddEventHandler('esx_uteknark:toggle_debug', function()
    debug.active = not debug.active
    TriggerServerEvent('esx_uteknark:log', debug.active and 'enabled debug' or 'disabled debug')
end)

-- ── Session startup ────────────────────────────────────────────────────────

Citizen.CreateThread(function()
    while not NetworkIsSessionStarted() do Citizen.Wait(100) end
    cropstate:bulkData()
end)
