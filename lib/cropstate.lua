local onServer = IsDuplicityVersion()

local cropstateMethods = {

    -- ── Plant a new seed (server only) ──────────────────────────────────
    plant = function(instance, location, strain)
        if not onServer then
            Citizen.Trace("cropstate:plant called on client – ignoring.\n")
            return
        end
        local now = os.time()
        MySQL.Async.insert(
            [[INSERT INTO `uteknark`
              (`x`,`y`,`z`,`strain`,`water`,`fertilizer`,`health`,`growth`,`quality`,`last_tick`)
              VALUES (@x,@y,@z,@strain,@water,@fert,@health,@growth,@quality,@tick);]],
            {
                ['@x']       = location.x,
                ['@y']       = location.y,
                ['@z']       = location.z,
                ['@strain']  = strain,
                ['@water']   = 80.0,
                ['@fert']    = 50.0,
                ['@health']  = 100.0,
                ['@growth']  = 0.0,
                ['@quality'] = 0.5,
                ['@tick']    = now,
            },
            function(id)
                instance:import(id, location, strain, 80.0, 50.0, 100.0, 0.0)
                TriggerClientEvent('esx_uteknark:planted', -1, id, location, strain, 80.0, 50.0, 100.0, 0.0)
                verbose('Plant', id, '(', strain, ') planted.')
            end
        )
    end,

    -- ── Load all plants from DB (server only) ──────────────────────────
    load = function(instance, callback)
        if not onServer then
            Citizen.Trace("cropstate:load called on client – ignoring.\n")
            return
        end
        verbose('Loading plants from DB...')
        MySQL.Async.fetchAll(
            [[SELECT `id`,`x`,`y`,`z`,`strain`,`water`,`fertilizer`,`health`,`growth`,`quality`,`last_tick`
              FROM `uteknark`;]],
            {},
            function(rows)
                Citizen.CreateThread(function()
                    for i, row in ipairs(rows) do
                        instance:import(
                            row.id,
                            vector3(row.x, row.y, row.z),
                            row.strain or 'og_kush',
                            row.water       or 80.0,
                            row.fertilizer  or 50.0,
                            row.health      or 100.0,
                            row.growth      or 0.0,
                            row.quality     or 0.5,
                            row.last_tick   or os.time()
                        )
                        if i % 50 == 0 then Citizen.Wait(0) end
                    end
                    if callback then callback(#rows) end
                    instance.loaded = true
                    verbose('Load complete –', #rows, 'plants')
                end)
            end
        )
    end,

    -- ── Add a plant to in-memory octree ──────────────────────────────────
    import = function(instance, id, location, strain, water, fertilizer, health, growth, quality, last_tick)
        local ok, obj = instance.octree:insert(location, 0.01, {
            id          = id,
            strain      = strain      or 'og_kush',
            water       = water       or 80.0,
            fertilizer  = fertilizer  or 50.0,
            health      = health      or 100.0,
            growth      = growth      or 0.0,
            quality     = quality     or 0.5,
            last_tick   = last_tick   or os.time(),
        })
        if not ok then
            Citizen.Trace(string.format("UteKnark: failed to import plant %i into octree\n", id))
            return
        end
        instance.index[id] = obj
    end,

    -- ── Apply a full growth-tick update ──────────────────────────────────
    tickUpdate = function(instance, id, water, fertilizer, health, growth, quality, now)
        local plant = instance.index[id]
        if not plant then return end

        plant.data.water       = water
        plant.data.fertilizer  = fertilizer
        plant.data.health      = health
        plant.data.growth      = growth
        plant.data.quality     = quality
        plant.data.last_tick   = now

        if onServer then
            MySQL.Async.execute(
                [[UPDATE `uteknark`
                  SET `water`=@w,`fertilizer`=@f,`health`=@h,`growth`=@g,`quality`=@q,`last_tick`=@t
                  WHERE `id`=@id LIMIT 1;]],
                {
                    ['@id'] = id, ['@w'] = water, ['@f'] = fertilizer,
                    ['@h'] = health, ['@g'] = growth, ['@q'] = quality, ['@t'] = now,
                },
                function()
                    -- Send to clients (quality NOT included – it's internal)
                    TriggerClientEvent('esx_uteknark:plantTick', -1, id, water, fertilizer, health, growth)
                end
            )
        end
    end,

    -- ── Update only care values (water/fertilizer) after player action ───
    updateCare = function(instance, id, water, fertilizer)
        local plant = instance.index[id]
        if not plant then return end
        if water      then plant.data.water      = water      end
        if fertilizer then plant.data.fertilizer = fertilizer end

        if onServer then
            MySQL.Async.execute(
                "UPDATE `uteknark` SET `water`=@w,`fertilizer`=@f WHERE `id`=@id LIMIT 1;",
                { ['@id'] = id, ['@w'] = plant.data.water, ['@f'] = plant.data.fertilizer },
                function()
                    TriggerClientEvent('esx_uteknark:plantTick', -1, id,
                        plant.data.water, plant.data.fertilizer, plant.data.health, plant.data.growth)
                end
            )
        end
    end,

    -- ── Remove a plant ────────────────────────────────────────────────────
    remove = function(instance, id, withPyro)
        local obj = instance.index[id]
        if not obj then return end
        local location = obj.bounds.location
        obj.data.deleted = true
        if obj.node then obj.node:remove(obj.oindex) end
        instance.index[id] = nil

        if onServer then
            MySQL.Async.execute(
                "DELETE FROM `uteknark` WHERE `id`=@id LIMIT 1;",
                { ['@id'] = id },
                function()
                    TriggerClientEvent('esx_uteknark:removePlant', -1, id)
                    if withPyro then
                        TriggerClientEvent('esx_uteknark:pyromaniac', -1, location)
                    end
                    verbose('Removed plant', id)
                end
            )
        else
            if obj.data.object and DoesEntityExist(obj.data.object) then
                DeleteObject(obj.data.object)
            end
            obj.data.object = nil
        end
    end,

    -- ── Send all plant data to a client (or broadcast) ───────────────────
    bulkData = function(instance, target)
        if onServer then
            target = target or -1
            while not instance.loaded do Citizen.Wait(1000) end
            local list = {}
            for id, plant in pairs(instance.index) do
                if type(id) == 'number' then
                    table.insert(list, {
                        id         = id,
                        location   = plant.bounds.location,
                        strain     = plant.data.strain,
                        water      = plant.data.water,
                        fertilizer = plant.data.fertilizer,
                        health     = plant.data.health,
                        growth     = plant.data.growth,
                        -- quality intentionally omitted
                    })
                end
            end
            TriggerClientEvent('esx_uteknark:bulk_data', target, list)
        else
            TriggerServerEvent('esx_uteknark:request_data')
        end
    end,
}

local cropstateMeta = {
    __newindex = function() end,
    __index    = function(t, k) return t._methods[k] end,
}

cropstate = {
    index    = { hashtable = true },
    octree   = pOctree(vector3(0, 1500, 0), vector3(12000, 13000, 2000)),
    loaded   = false,
    _methods = cropstateMethods,
}
setmetatable(cropstate, cropstateMeta)

-- ── Network events ─────────────────────────────────────────────────────────

if onServer then

    RegisterNetEvent('esx_uteknark:request_data')
    AddEventHandler('esx_uteknark:request_data', function()
        cropstate:bulkData(source)
    end)

    RegisterNetEvent('esx_uteknark:remove')
    AddEventHandler('esx_uteknark:remove', function(plantID, nearLoc)
        local src   = source
        local plant = cropstate.index[plantID]
        if not plant then
            TriggerClientEvent('esx_uteknark:removePlant', src, plantID)
            return
        end
        if #(nearLoc - plant.bounds.location) <= Config.Distance.Interact then
            cropstate:remove(plantID, true)
            makeToast(src, _U('interact_text'), _U('interact_destroyed'))
        end
    end)

    RegisterNetEvent('esx_uteknark:harvest')
    AddEventHandler('esx_uteknark:harvest', function(plantID, nearLoc)
        local src   = source
        local plant = cropstate.index[plantID]
        if not plant then return end
        if #(nearLoc - plant.bounds.location) > Config.Distance.Interact then return end
        if plant.data.growth < 100 then
            makeToast(src, _U('interact_text'), _U('harvest_not_ready'))
            return
        end

        local strainKey  = plant.data.strain
        local strainData = Config.Strains[strainKey]
        if not strainData then return end

        -- Quality multiplier (0.0-1.0, never shown to player)
        local q    = Config.Quality
        local mult = q.MinYieldMult + plant.data.quality * q.YieldRange
        local base = math.random(strainData.yield[1], strainData.yield[2])
        local wet  = math.max(1, math.floor(base * mult))
        local seeds = math.random(strainData.seedReturn[1], strainData.seedReturn[2])

        if GiveItem(src, strainData.wet_product, wet) then
            cropstate:remove(plantID)
            if seeds > 0 then GiveItem(src, strainData.seed, seeds) end
            makeToast(src, _U('interact_text'), _U('interact_harvested', wet, seeds))
        else
            makeToast(src, _U('interact_text'), _U('interact_full', wet))
        end
    end)

    RegisterNetEvent('esx_uteknark:water')
    AddEventHandler('esx_uteknark:water', function(plantID, nearLoc)
        local src   = source
        local plant = cropstate.index[plantID]
        if not plant then return end
        if #(nearLoc - plant.bounds.location) > Config.Distance.Interact then return end

        local waterItem = HasAnyItem(src, Config.WaterItems)
        if not waterItem then
            makeToast(src, _U('water_text'), _U('water_no_item'))
            return
        end
        TakeItem(src, waterItem)
        local newWater = math.min(100, plant.data.water + Config.WaterPerAction)
        cropstate:updateCare(plantID, newWater, nil)
        makeToast(src, _U('water_text'), _U('water_done'))
    end)

    RegisterNetEvent('esx_uteknark:fertilize')
    AddEventHandler('esx_uteknark:fertilize', function(plantID, nearLoc)
        local src   = source
        local plant = cropstate.index[plantID]
        if not plant then return end
        if #(nearLoc - plant.bounds.location) > Config.Distance.Interact then return end

        if not HasItem(src, Config.FertilizerItem) then
            makeToast(src, _U('fertilize_text'), _U('fertilize_no_item'))
            return
        end
        TakeItem(src, Config.FertilizerItem)
        local newFert = math.min(100, plant.data.fertilizer + Config.FertPerAction)
        cropstate:updateCare(plantID, nil, newFert)
        makeToast(src, _U('fertilize_text'), _U('fertilize_done'))
    end)

else -- CLIENT

    RegisterNetEvent('esx_uteknark:bulk_data')
    AddEventHandler('esx_uteknark:bulk_data', function(list)
        for _, p in ipairs(list) do
            cropstate:import(p.id, p.location, p.strain, p.water, p.fertilizer, p.health, p.growth)
        end
        cropstate.loaded = true
    end)

    RegisterNetEvent('esx_uteknark:planted')
    AddEventHandler('esx_uteknark:planted', function(id, location, strain, water, fert, health, growth)
        cropstate:import(id, location, strain, water, fert, health, growth)
    end)

    RegisterNetEvent('esx_uteknark:plantTick')
    AddEventHandler('esx_uteknark:plantTick', function(id, water, fert, health, growth)
        local plant = cropstate.index[id]
        if not plant then return end
        local oldStage = GetStageFromGrowth(plant.data.growth)
        plant.data.water      = water
        plant.data.fertilizer = fert
        plant.data.health     = health
        plant.data.growth     = growth
        -- If stage changed, delete the prop so it gets re-spawned with the new model
        local newStage = GetStageFromGrowth(growth)
        if newStage ~= oldStage and plant.data.object then
            if DoesEntityExist(plant.data.object) then
                DeleteObject(plant.data.object)
            end
            plant.data.object = nil
        end
    end)

    RegisterNetEvent('esx_uteknark:removePlant')
    AddEventHandler('esx_uteknark:removePlant', function(id)
        cropstate:remove(id)
    end)

end
