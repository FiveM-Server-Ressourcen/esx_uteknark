local activePlants   = {}
local inAction       = false
local adminBlips     = {}
local adminActive    = false

-- Shared flag: cl_wildweed.lua reads this so both scripts
-- never fight over the same lib.showTextUI slot.
_uteknark_near_plant = false

-- ── Animation dict ────────────────────────────────────────────────────────

local ANIM_GARDEN = { dict = 'amb@world_human_gardener_plant@male@idle_a', clip = 'idle_a', flag = 1 }

-- ── Locale notification helper ────────────────────────────────────────────

local function notify(msg, ntype)
    lib.notify({ title = 'UteKnark', description = msg, type = ntype or 'inform', duration = 4000 })
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
            Config.Burn.Rotation, Config.Burn.Scale, false, false, false)
        while GetGameTimer() < begin + Config.Burn.Duration do Citizen.Wait(0) end
        StopParticleFxLooped(handle, 0)
        RemoveNamedPtfxAsset(Config.Burn.Collection)
    end)
end)

-- Legacy toast bridge
RegisterNetEvent('esx_uteknark:make_toast')
AddEventHandler('esx_uteknark:make_toast', function(_, message)
    notify(message)
end)

-- ── Plant prop management ─────────────────────────────────────────────────

local function spawnPlantProp(entry)
    if entry.data.object or entry.data.deleted then return end
    local stage  = GetStageFromGrowth(entry.data.growth)
    local strain = entry.data.strain or 'og_kush'
    local model  = GetPlantModel(strain, stage)
    if not IsModelValid(model) then model = `prop_mp_cone_01` end
    if not HasModelLoaded(model) then
        RequestModel(model)
        local t = GetGameTimer()
        while not HasModelLoaded(model) and GetGameTimer() < t + 2500 do Citizen.Wait(0) end
    end
    if not HasModelLoaded(model) then return end
    local stData = Growth[stage]
    local offset = (stData and stData.offset) or vector3(0, 0, 0)
    local loc    = entry.bounds.location
    local weed   = CreateObject(model, loc + offset, false, false, false)
    SetEntityHeading(weed, math.random(0, 359) * 1.0)
    FreezeEntityPosition(weed, true)
    SetEntityCollision(weed, false, true)
    if Config.SetLOD then SetEntityLodDist(weed, math.floor(Config.Distance.Draw)) end
    table.insert(activePlants, {
        node   = entry,
        object = weed,
        at     = loc,
        id     = entry.data.id,
        strain = strain,
    })
    entry.data.object = weed
    SetModelAsNoLongerNeeded(model)
end

-- Scan octree and spawn nearby props (background loop)
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

-- ── Plant status UI ───────────────────────────────────────────────────────

local function barLine(pct)
    return MakeBar(pct, 10) .. '  ' .. math.floor(pct) .. '%'
end

local function showPlantMenu(plant)
    local data       = plant.node.data
    local strainData = Config.Strains[data.strain] or {}
    local name       = strainData.name or data.strain
    local ready      = (data.growth or 0) >= 100
    local myLoc      = GetEntityCoords(PlayerPedId())
    local nearLoc    = vector3(myLoc.x, myLoc.y, myLoc.z)

    local options = {
        {   -- Water
            title     = '💧 ' .. _U('ui_water'),
            description = barLine(data.water or 0),
            icon      = 'droplet',
            iconColor = '#4fc3f7',
            disabled  = true,
        },
        {   -- Fertilizer
            title     = '🌿 ' .. _U('ui_fert'),
            description = barLine(data.fertilizer or 0),
            icon      = 'leaf',
            iconColor = '#81c784',
            disabled  = true,
        },
        {   -- Health
            title     = '❤️ ' .. _U('ui_health'),
            description = barLine(data.health or 100),
            icon      = 'heart',
            iconColor = '#ef5350',
            disabled  = true,
        },
        {   -- Growth
            title     = '🌱 ' .. _U('ui_growth'),
            description = barLine(data.growth or 0),
            icon      = 'seedling',
            iconColor = '#66bb6a',
            disabled  = true,
        },
        {   -- Status
            title     = ready
                and ('✅ ' .. _U('ui_ready_yes'))
                or  ('⏳ ' .. _U('ui_growing') .. ' ' .. math.floor(data.growth or 0) .. '%'),
            icon      = ready and 'check-circle' or 'clock',
            iconColor = ready and '#4caf50'       or '#ff9800',
            disabled  = true,
        },
        {   -- Divider
            title    = '─────────────────────',
            disabled = true,
        },
        {   -- Water button
            title    = _U('water_text'),
            icon     = 'droplet',
            disabled = (data.water or 0) >= 99,
            onSelect = function()
                if inAction then return end
                inAction = true
                Citizen.CreateThread(function()
                    local ok = lib.progressBar({
                        duration = 5000, label = _U('water_progress'),
                        canCancel = true,
                        disable   = { move = true, car = true, combat = true },
                        anim      = ANIM_GARDEN,
                    })
                    inAction = false
                    if ok then TriggerServerEvent('esx_uteknark:water', plant.id, nearLoc) end
                end)
            end,
        },
        {   -- Fertilize button
            title    = _U('fertilize_text'),
            icon     = 'leaf',
            disabled = (data.fertilizer or 0) >= 99,
            onSelect = function()
                if inAction then return end
                inAction = true
                Citizen.CreateThread(function()
                    local ok = lib.progressBar({
                        duration = 5000, label = _U('fertilize_progress'),
                        canCancel = true,
                        disable   = { move = true, car = true, combat = true },
                        anim      = ANIM_GARDEN,
                    })
                    inAction = false
                    if ok then TriggerServerEvent('esx_uteknark:fertilize', plant.id, nearLoc) end
                end)
            end,
        },
    }

    -- Harvest (only when growth = 100%)
    if ready then
        table.insert(options, {
            title     = _U('interact_harvest'),
            icon      = 'scissors',
            iconColor = '#ffee58',
            onSelect  = function()
                if inAction then return end
                inAction = true
                Citizen.CreateThread(function()
                    local ok = lib.progressBar({
                        duration = 6000, label = _U('harvest_progress'),
                        canCancel = true,
                        disable   = { move = true, car = true, combat = true },
                        anim      = ANIM_GARDEN,
                    })
                    inAction = false
                    if ok then TriggerServerEvent('esx_uteknark:harvest', plant.id, nearLoc) end
                end)
            end,
        })
    end

    -- Destroy
    table.insert(options, {
        title     = _U('interact_destroy'),
        icon      = 'fire',
        iconColor = '#f44336',
        onSelect  = function()
            if inAction then return end
            inAction = true
            Citizen.CreateThread(function()
                local ok = lib.progressBar({
                    duration = 4000, label = _U('destroy_progress'),
                    canCancel = true,
                    disable   = { move = true, car = true, combat = true },
                    anim      = ANIM_GARDEN,
                })
                inAction = false
                if ok then
                    for i, p in ipairs(activePlants) do
                        if p.id == plant.id then
                            if DoesEntityExist(p.object) then DeleteObject(p.object) end
                            table.remove(activePlants, i)
                            break
                        end
                    end
                    TriggerServerEvent('esx_uteknark:remove', plant.id, nearLoc)
                end
            end)
        end,
    })

    lib.registerContext({ id = 'uteknark_plant_menu', title = '🌿 ' .. name, options = options })
    lib.showContext('uteknark_plant_menu')
end

-- ── Main plant interaction loop ────────────────────────────────────────────

local function DrawIndicator(location, color)
    DrawMarker(6, location, 0.0, 0.0, 0.0, -90.0, 0.0, 0.0,
        1.0, 1.0, 1.0, color[1], color[2], color[3], color[4],
        false, false, 2, false, 0, 0, false)
end

Citizen.CreateThread(function()
    local drawDist = Config.Distance.Draw * 1.01
    while true do
        local playerPed = PlayerPedId()
        if #activePlants > 0 then
            local myLoc           = GetEntityCoords(playerPed)
            local closestDist
            local closestPlant
            for i = #activePlants, 1, -1 do
                local plant = activePlants[i]
                local dist  = #(plant.at - myLoc)
                if not DoesEntityExist(plant.object) or plant.node.data.deleted then
                    table.remove(activePlants, i)
                elseif dist > drawDist then
                    DeleteObject(plant.object)
                    plant.node.data.object = nil
                    table.remove(activePlants, i)
                else
                    if not closestDist or dist < closestDist then
                        closestDist  = dist
                        closestPlant = plant
                    end
                end
            end
            if closestPlant and not IsPedInAnyVehicle(playerPed) then
                if closestDist <= Config.Distance.Interact then
                    -- Marker
                    local stage  = GetStageFromGrowth(closestPlant.node.data.growth)
                    local stData = Growth[stage]
                    if stData then
                        DrawIndicator(closestPlant.at + stData.marker.offset, stData.marker.color)
                    end
                    -- TextUI
                    if not inAction then
                        if not _uteknark_near_plant then
                            _uteknark_near_plant = true
                            lib.showTextUI(_U('press_e_options'), { position = 'left-center', icon = 'cannabis' })
                        end
                        if IsControlJustPressed(0, 38) then
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
            duration  = 4000,
            label     = _U('planting_progress', strainName),
            canCancel = true,
            disable   = { move = true, car = true, combat = true },
            anim      = ANIM_GARDEN,
        })
        inAction = false
        if success then TriggerServerEvent('esx_uteknark:success_plant', location, strainKey) end
    end)
end)

-- ── Admin blip system ─────────────────────────────────────────────────────

RegisterCommand('weedplants', function()
    if adminActive then
        for _, b in ipairs(adminBlips) do RemoveBlip(b) end
        adminBlips  = {}
        adminActive = false
        lib.notify({ title = 'UteKnark', description = _U('admin_blips_off'), type = 'inform' })
    else
        TriggerServerEvent('esx_uteknark:admin_request')
    end
end, false)

RegisterNetEvent('esx_uteknark:admin_denied')
AddEventHandler('esx_uteknark:admin_denied', function()
    lib.notify({ title = 'UteKnark', description = _U('admin_no_perm'), type = 'error' })
end)

RegisterNetEvent('esx_uteknark:admin_data')
AddEventHandler('esx_uteknark:admin_data', function(plants, wild)
    adminActive = true
    for _, p in ipairs(plants) do
        local blip = AddBlipForCoord(p.location.x, p.location.y, p.location.z)
        SetBlipSprite(blip, Config.AdminBlips.PlantSprite)
        SetBlipColour(blip, Config.AdminBlips.PlantColor)
        SetBlipScale(blip, Config.AdminBlips.PlantScale)
        SetBlipAsShortRange(blip, false)
        local sName = (Config.Strains[p.strain] and Config.Strains[p.strain].name) or p.strain
        BeginTextCommandSetBlipName('STRING')
        AddTextComponentSubstringPlayerName(
            sName .. ' | ' .. _U('ui_growth') .. ': ' .. math.floor(p.growth) .. '%' ..
            ' | HP: ' .. math.floor(p.health) .. '%')
        EndTextCommandSetBlipName(blip)
        table.insert(adminBlips, blip)
    end
    for _, w in ipairs(wild) do
        local blip = AddBlipForCoord(w.pos.x, w.pos.y, w.pos.z)
        SetBlipSprite(blip, Config.AdminBlips.WildSprite)
        SetBlipColour(blip, Config.AdminBlips.WildColor)
        SetBlipScale(blip, Config.AdminBlips.WildScale)
        SetBlipAsShortRange(blip, false)
        local sName = (Config.Strains[w.strain] and Config.Strains[w.strain].name) or w.strain
        BeginTextCommandSetBlipName('STRING')
        AddTextComponentSubstringPlayerName('Wild: ' .. sName)
        EndTextCommandSetBlipName(blip)
        table.insert(adminBlips, blip)
    end
    lib.notify({
        title       = 'UteKnark Admin',
        description = _U('admin_blips_on', #plants, #wild),
        type        = 'success',
    })
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
    for _, b in ipairs(adminBlips) do RemoveBlip(b) end
    adminBlips = {}
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
