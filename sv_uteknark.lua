local ESX          = nil
local VERBOSE      = false
local lastPlant    = {}
local VERSION      = '2.1.0'

AddEventHandler('playerDropped', function() lastPlant[source] = nil end)

-- ── Logging ───────────────────────────────────────────────────────────────

function log(...)
    local parts = { ... }
    local line  = ''
    for _, v in ipairs(parts) do line = line .. ' ' .. tostring(v) end
    Citizen.Trace('[' .. os.date('%H:%M:%S') .. '] <' .. GetCurrentResourceName() .. '>' .. line .. '\n')
end
function verbose(...) if VERBOSE then log(...) end end

-- ── ESX item helpers ──────────────────────────────────────────────────────

function HasItem(who, what, count)
    count = count or 1
    if not ESX then return false end
    local xp = ESX.GetPlayerFromId(who)
    if not xp then return false end
    local item = xp.getInventoryItem(what)
    return item and item.count >= count
end

function HasAnyItem(who, items)
    if not ESX then return nil end
    local xp = ESX.GetPlayerFromId(who)
    if not xp then return nil end
    for _, name in ipairs(items) do
        local item = xp.getInventoryItem(name)
        if item and item.count >= 1 then return name end
    end
    return nil
end

function TakeItem(who, what, count)
    count = count or 1
    if not ESX then return false end
    local xp = ESX.GetPlayerFromId(who)
    if not xp then return false end
    local item = xp.getInventoryItem(what)
    if item and item.count >= count then
        xp.removeInventoryItem(what, count)
        return true
    end
    return false
end

function GiveItem(who, what, count)
    count = count or 1
    if not ESX then return false end
    local xp = ESX.GetPlayerFromId(who)
    if not xp then return false end
    local item = xp.getInventoryItem(what)
    if item then
        if not item.limit or item.limit == -1 or item.count + count <= item.limit then
            xp.addInventoryItem(what, count)
            return true
        end
    else
        log('GiveItem: item', what, 'not found in ESX items')
    end
    return false
end

-- ── Notifications ─────────────────────────────────────────────────────────

function makeToast(target, subject, message)
    TriggerClientEvent('esx_uteknark:make_toast', target, subject, message)
end
function inChat(target, message)
    if target == 0 then log(message)
    else TriggerClientEvent('chat:addMessage', target, { args = { 'UteKnark', message } }) end
end

-- ── Planting ──────────────────────────────────────────────────────────────

RegisterNetEvent('esx_uteknark:success_plant')
AddEventHandler('esx_uteknark:success_plant', function(location, strainKey)
    local src        = source
    local strainData = Config.Strains[strainKey]
    if not strainData then return end

    local now  = os.time()
    local last = lastPlant[src] or 0
    if now <= last + 2 then
        makeToast(src, _U('planting_text'), _U('planting_too_fast'))
        return
    end

    local hits = cropstate.octree:searchSphere(location, Config.Distance.Space)
    if #hits > 0 then
        makeToast(src, _U('planting_text'), _U('planting_too_close'))
        return
    end
    if not HasItem(src, strainData.seed) then
        makeToast(src, _U('planting_text'), _U('planting_no_seed'))
        return
    end
    if not HasItem(src, Config.FlowerPot) then
        makeToast(src, _U('planting_text'), _U('planting_no_pot'))
        return
    end

    TakeItem(src, strainData.seed)
    TakeItem(src, Config.FlowerPot)
    cropstate:plant(location, strainKey)
    makeToast(src, _U('planting_text'), _U('planting_ok', strainData.name))
    lastPlant[src] = now
end)

-- ── Drying ────────────────────────────────────────────────────────────────

RegisterNetEvent('esx_uteknark:dry_weed')
AddEventHandler('esx_uteknark:dry_weed', function(strainKey, count)
    local src        = source
    local strainData = Config.Strains[strainKey]
    if not strainData then return end
    count = math.max(1, math.min(count, 100))

    if not HasItem(src, strainData.wet_product, count) then
        makeToast(src, _U('drying_text'), _U('drying_no_wet'))
        return
    end
    TakeItem(src, strainData.wet_product, count)
    if GiveItem(src, strainData.dry_product, count) then
        makeToast(src, _U('drying_text'), _U('drying_done', count, strainData.name))
    else
        -- Inventory full – give wet weed back
        GiveItem(src, strainData.wet_product, count)
        makeToast(src, _U('drying_text'), _U('drying_full'))
    end
end)

-- ── Wild Weed ─────────────────────────────────────────────────────────────

local wildWeedState    = {}
local wildRespawnQueue = {}

local function pickRandomStrain()
    local weights = Config.WildWeed.StrainWeights
    local total   = 0
    for _, e in ipairs(weights) do total = total + e.weight end
    local roll, acc = math.random(1, total), 0
    for _, e in ipairs(weights) do
        acc = acc + e.weight
        if roll <= acc then return e.strain end
    end
    return weights[#weights].strain
end

local function initWildWeed()
    math.randomseed(os.time())
    for i, _ in ipairs(Config.WildWeed.Positions) do
        if math.random() <= Config.WildWeed.SpawnChance then
            wildWeedState[i] = { strain = pickRandomStrain(), active = true }
        else
            wildWeedState[i] = { strain = nil, active = false }
        end
    end
    local count = 0
    for _, s in pairs(wildWeedState) do if s.active then count = count + 1 end end
    log('Wild weed initialized:', count, '/', #Config.WildWeed.Positions, 'positions active')
end

function buildWildWeedList()
    local list = {}
    for idx, state in pairs(wildWeedState) do
        if state.active then
            local pos = Config.WildWeed.Positions[idx]
            table.insert(list, { index = idx, pos = vector3(pos.x, pos.y, pos.z), strain = state.strain })
        end
    end
    return list
end

RegisterNetEvent('esx_uteknark:request_wild')
AddEventHandler('esx_uteknark:request_wild', function()
    TriggerClientEvent('esx_uteknark:wild_data', source, buildWildWeedList())
end)

RegisterNetEvent('esx_uteknark:collect_wild')
AddEventHandler('esx_uteknark:collect_wild', function(posIndex)
    local src   = source
    local state = wildWeedState[posIndex]
    if not state or not state.active then return end
    local strainData = Config.Strains[state.strain]
    if not strainData then return end

    local count = math.random(Config.WildWeed.SeedReward[1], Config.WildWeed.SeedReward[2])
    if GiveItem(src, strainData.seed, count) then
        makeToast(src, _U('wild_text'), _U('wild_collected', count, strainData.name))
        state.active = false
        state.strain = nil
        table.insert(wildRespawnQueue, { index = posIndex, respawnAt = os.time() + Config.WildWeed.RespawnTime })
        TriggerClientEvent('esx_uteknark:wild_remove', -1, posIndex)
    else
        makeToast(src, _U('wild_text'), _U('wild_full'))
    end
end)

-- Wild respawn ticker (every minute)
Citizen.CreateThread(function()
    while true do
        Citizen.Wait(60000)
        local now = os.time()
        local i   = 1
        while i <= #wildRespawnQueue do
            local e = wildRespawnQueue[i]
            if now >= e.respawnAt then
                if math.random() <= Config.WildWeed.SpawnChance then
                    local strain = pickRandomStrain()
                    wildWeedState[e.index] = { strain = strain, active = true }
                    local pos = Config.WildWeed.Positions[e.index]
                    TriggerClientEvent('esx_uteknark:wild_spawn', -1, {
                        index = e.index, pos = vector3(pos.x, pos.y, pos.z), strain = strain,
                    })
                else
                    wildWeedState[e.index] = { strain = nil, active = false }
                end
                table.remove(wildRespawnQueue, i)
            else
                i = i + 1
            end
        end
    end
end)

-- ── Admin overview ────────────────────────────────────────────────────────

RegisterNetEvent('esx_uteknark:admin_request')
AddEventHandler('esx_uteknark:admin_request', function()
    local src = source
    if not IsPlayerAceAllowed(src, 'command.uteknark') then
        TriggerClientEvent('esx_uteknark:admin_denied', src)
        return
    end
    local plants = {}
    for id, plant in pairs(cropstate.index) do
        if type(id) == 'number' then
            table.insert(plants, {
                id       = id,
                location = plant.bounds.location,
                strain   = plant.data.strain,
                health   = plant.data.health,
                growth   = plant.data.growth,
                water    = plant.data.water,
                fert     = plant.data.fertilizer,
            })
        end
    end
    TriggerClientEvent('esx_uteknark:admin_data', src, plants, buildWildWeedList())
end)

-- ── Growth & Decay Tick ───────────────────────────────────────────────────

Citizen.CreateThread(function()
    -- Wait for DB
    while not cropstate.loaded do Citizen.Wait(1000) end

    while true do
        Citizen.Wait(Config.Decay.TickInterval * 1000)

        local now      = os.time()
        local toRemove = {}
        local d        = Config.Decay
        local qc       = Config.Quality

        for id, plant in pairs(cropstate.index) do
            if type(id) == 'number' then
                local elapsed = math.max(0, now - (plant.data.last_tick or now))
                local mins    = elapsed / 60.0

                if mins < 0.05 then -- skip tiny intervals
                    -- still update timestamp
                    plant.data.last_tick = now
                else
                    -- ── Water & Fertilizer decay ──────────────────────────
                    local newWater = math.max(0, plant.data.water      - d.WaterPerMinute * mins)
                    local newFert  = math.max(0, plant.data.fertilizer - d.FertPerMinute  * mins)

                    -- ── Health ────────────────────────────────────────────
                    local avgCare    = (newWater + newFert) * 0.5
                    local healthDelta = 0
                    if avgCare < d.HealthThreshold then
                        healthDelta = -d.HealthDecayRate * mins
                    elseif avgCare >= d.HealthGoodThreshold then
                        healthDelta = d.HealthRegenRate * mins
                    end
                    local newHealth = math.max(0, math.min(100, plant.data.health + healthDelta))

                    if newHealth <= 0 then
                        table.insert(toRemove, id)
                        plant.data.last_tick = now
                    else
                        -- ── Growth ────────────────────────────────────────
                        local newGrowth = plant.data.growth
                        if newGrowth < 100 and newHealth > d.MinHealthForGrowth then
                            local strainKey  = plant.data.strain or 'og_kush'
                            local timeMult   = (Config.Strains[strainKey] and Config.Strains[strainKey].timeMultiplier) or 1.0
                            local wFactor    = math.min(1.0, newWater / 50.0)
                            local fFactor    = math.max(0.5, math.min(1.0, newFert / 50.0))
                            local hFactor    = newHealth / 100.0
                            local rate       = (d.GrowthRateBase / timeMult) * wFactor * fFactor * hFactor
                            newGrowth        = math.min(100.0, newGrowth + rate * mins)
                        end

                        -- ── Quality (EMA) ─────────────────────────────────
                        local careScore = (newWater  / 100.0) * qc.WaterWeight
                                        + (newFert   / 100.0) * qc.FertWeight
                                        + (newHealth / 100.0) * qc.HealthWeight
                        local newQuality = plant.data.quality * (1.0 - qc.EmaAlpha) + careScore * qc.EmaAlpha

                        cropstate:tickUpdate(id, newWater, newFert, newHealth, newGrowth, newQuality, now)
                    end
                end
            end
        end

        -- Remove dead plants
        for _, id in ipairs(toRemove) do
            verbose('Plant', id, 'died (health = 0)')
            cropstate:remove(id, true)
        end
    end
end)

-- ── ESX Init & usable items ───────────────────────────────────────────────

Citizen.CreateThread(function()
    local tries  = 60
    local loaded = false
    while not loaded and tries > 0 do
        TriggerEvent('esx:getSharedObject', function(obj)
            ESX = obj
            if ESX and next(ESX.Items) then
                loaded = true
                -- Register every strain's seed
                for strainKey, strain in pairs(Config.Strains) do
                    if ESX.Items[strain.seed] then
                        log('Registering usable item:', strain.seed)
                        ESX.RegisterUsableItem(strain.seed, function(playerSrc)
                            local now  = os.time()
                            local last = lastPlant[playerSrc] or 0
                            if now > last + 2 then
                                if HasItem(playerSrc, strain.seed) then
                                    TriggerClientEvent('esx_uteknark:attempt_plant', playerSrc, strainKey)
                                else
                                    makeToast(playerSrc, _U('planting_text'), _U('planting_no_seed'))
                                end
                            else
                                makeToast(playerSrc, _U('planting_text'), _U('planting_too_fast'))
                            end
                        end)
                    else
                        log('WARNING: seed item', strain.seed, 'not in ESX items!')
                    end
                end
            end
        end)
        Citizen.Wait(1000)
        tries = tries - 1
    end
    if not ESX then log('CRITICAL: Could not get ESX object!') end
end)

-- ── DB load & wild weed init ──────────────────────────────────────────────

Citizen.CreateThread(function()
    while GetResourceState('mysql-async') ~= 'started' do Citizen.Wait(500) end
    Citizen.Wait(500)
    cropstate:load(function(count)
        log('UteKnark loaded', count, 'plant(s)')
        initWildWeed()
    end)
end)

-- ── Commands ──────────────────────────────────────────────────────────────

local commands = {
    debug = function(src)
        if src == 0 then log('Console: debug toggle is client-only') return end
        TriggerClientEvent('esx_uteknark:toggle_debug', src)
    end,
    stats = function(src)
        local count = 0
        for id, _ in pairs(cropstate.index) do
            if type(id) == 'number' then count = count + 1 end
        end
        local wild = 0
        for _, s in pairs(wildWeedState) do if s.active then wild = wild + 1 end end
        inChat(src, string.format('Plants: %i | Wild: %i/%i', count, wild, #Config.WildWeed.Positions))
    end,
    stage = function(src, args)
        if args[1] and args[2] then
            local id    = tonumber(args[1])
            local g     = tonumber(args[2])
            local plant = cropstate.index[id]
            if plant and g and g >= 0 and g <= 100 then
                cropstate:tickUpdate(id, plant.data.water, plant.data.fertilizer,
                    plant.data.health, g, plant.data.quality, os.time())
                inChat(src, 'Plant ' .. id .. ' growth set to ' .. g .. '%')
            else
                inChat(src, 'Usage: /uteknark stage <plantID> <growth 0-100>')
            end
        end
    end,
    wild = function(src)
        local a, t = 0, #Config.WildWeed.Positions
        for _, s in pairs(wildWeedState) do if s.active then a = a + 1 end end
        inChat(src, string.format('Wild weed: %i/%i active', a, t))
    end,
}

RegisterCommand('uteknark', function(src, args)
    if #args == 0 then inChat(src, _U('command_empty', VERSION)) return end
    local dir = string.lower(args[1])
    local sub = {}
    for i = 2, #args do table.insert(sub, args[i]) end
    if commands[dir] then
        commands[dir](src, sub)
    else
        inChat(src, _U('command_invalid', dir))
    end
end, true)

RegisterNetEvent('esx_uteknark:log')
AddEventHandler('esx_uteknark:log', function(...)
    log(source, GetPlayerName(source), ...)
end)
