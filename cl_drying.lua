--[[ DRYING SYSTEM CLIENT
     Players bring wet weed to a drying station, run a progress bar,
     and receive dry weed in return.
     No DB table needed – the server does the item swap after the client
     confirms the timer completed.
--]]

local inDrying    = false
local dryUiShown  = false

-- ── Helpers ───────────────────────────────────────────────────────────────

local function notify(msg, ntype)
    lib.notify({ title = _U('drying_text'), description = msg, type = ntype or 'inform', duration = 4000 })
end

local function getWetWeedInInventory()
    local found = {}
    for key, strain in pairs(Config.Strains) do
        if strain.wet_product then
            found[#found + 1] = { key = key, item = strain.wet_product, name = strain.name }
        end
    end
    return found
end

-- ── Drying interaction ────────────────────────────────────────────────────

local function openDryingMenu(stationName)
    if inDrying then return end
    local strains = getWetWeedInInventory()
    if #strains == 0 then
        notify(_U('drying_no_wet'), 'error')
        return
    end

    local options = {}
    for _, s in ipairs(strains) do
        local sRef = s  -- closure capture
        table.insert(options, {
            title       = sRef.name,
            description = _U('drying_desc', sRef.item),
            icon        = 'leaf',
            onSelect    = function()
                Citizen.CreateThread(function()
                    -- Ask for quantity
                    local input = lib.inputDialog(_U('drying_text'), {
                        { type = 'number', label = _U('drying_amount'), default = 1, min = 1, max = 100 },
                    })
                    if not input or not input[1] then return end
                    local count = math.max(1, math.floor(input[1]))

                    -- Run drying progress bar
                    inDrying = true
                    local ok = lib.progressBar({
                        duration     = Config.DryingTime * 1000,
                        label        = _U('drying_progress', sRef.name),
                        useWhileDead = false,
                        canCancel    = true,
                        disable      = { move = true, car = true, combat = true },
                        anim         = { dict = 'mini@repair', clip = 'fixing_a_player', flag = 49 },
                    })
                    inDrying = false

                    if ok then
                        TriggerServerEvent('esx_uteknark:dry_weed', sRef.key, count)
                    else
                        notify(_U('drying_cancelled'), 'error')
                    end
                end)
            end,
        })
    end

    lib.registerContext({
        id      = 'uteknark_drying_menu',
        title   = '🏭 ' .. stationName,
        options = options,
    })
    lib.showContext('uteknark_drying_menu')
end

-- ── Main loop: proximity detection ────────────────────────────────────────

local dryUiTarget  = nil
local prevNearDry  = false

Citizen.CreateThread(function()
    while true do
        local playerPed = PlayerPedId()
        local myLoc     = GetEntityCoords(playerPed)
        local inVeh     = IsPedInAnyVehicle(playerPed)

        local nearStation = nil
        local nearDist    = Config.Distance.Interact + 0.01

        for _, station in ipairs(Config.DryingStations) do
            local dist = #(station.pos - myLoc)
            if dist < nearDist then
                nearDist    = dist
                nearStation = station
            end
        end

        -- Draw markers at stations when within visual range
        for _, station in ipairs(Config.DryingStations) do
            local dist = #(station.pos - myLoc)
            if dist < 30.0 then
                DrawMarker(1,
                    station.pos.x, station.pos.y, station.pos.z,
                    0, 0, 0, 0, 0, 0,
                    0.5, 0.5, 0.3,
                    200, 160, 60, 130,
                    false, false, 2, false, nil, nil, false)
            end
        end

        local inRange = nearStation ~= nil and not inVeh and not inDrying

        if inRange and not prevNearDry and not _uteknark_near_plant then
            prevNearDry = true
            dryUiShown  = true
            lib.showTextUI(_U('press_e_dry', nearStation.name), { position = 'left-center', icon = 'fire' })
        elseif not inRange and prevNearDry then
            prevNearDry = false
            if dryUiShown then lib.hideTextUI() end
            dryUiShown = false
        end

        if inRange and IsControlJustPressed(0, 38) and not _uteknark_near_plant then
            if dryUiShown then lib.hideTextUI(); dryUiShown = false; prevNearDry = false end
            openDryingMenu(nearStation.name)
        end

        Citizen.Wait(#Config.DryingStations > 0 and 0 or 5000)
    end
end)

-- ── Cleanup ────────────────────────────────────────────────────────────────

AddEventHandler('onResourceStop', function(name)
    if name ~= GetCurrentResourceName() then return end
    if dryUiShown then lib.hideTextUI() end
    inDrying   = false
    prevNearDry = false
    dryUiShown  = false
end)
