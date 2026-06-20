Config = {
    Locale = 'en-US',

    Distance = {
        Draw     = 150.0, -- Meter: Sichtweite für Pflanzen
        Interact = 2.0,   -- Meter: Interaktionsdistanz
        Space    = 1.2,   -- Meter: Mindestabstand zwischen Pflanzen
        Above    = 5.0,   -- Meter: Freiraum über der Pflanzposition
    },

    SetLOD         = false,
    MaxGroundAngle = 0.6,  -- Max. Neigung des Bodens zum Pflanzen
    TimeMultiplier = 1.0,  -- Globaler Wachstumszeit-Multiplikator (1.0 = normal)

    -- Item das zum Pflanzen zusätzlich zum Samen benötigt wird
    FlowerPot = 'flower_pot',

    -- Alle gültigen Wasser-Items (beliebig viele eintragen)
    WaterItems = {
        'water_bottle',
        'watering_can',
    },

    -- Dünger-Item
    FertilizerItem = 'fertilizer',

    -- Qualitätsberechnung (1–5 Sterne)
    -- Basiert auf Anzahl der Bewässerungen und Düngungen
    -- Stern wird vergeben wenn Schwellwert erreicht/überschritten
    Quality = {
        Water = {
            [1] = 0,  -- 1 Stern: 0+ Bewässerungen
            [2] = 2,  -- 2 Sterne: 2+
            [3] = 4,  -- 3 Sterne: 4+
            [4] = 6,  -- 4 Sterne: 6+
            [5] = 8,  -- 5 Sterne: 8+
        },
        Fertilizer = {
            [1] = 0,  -- 1 Stern: 0+ Düngungen
            [2] = 1,  -- 2 Sterne: 1+
            [3] = 2,  -- 3 Sterne: 2+
            [4] = 3,  -- 4 Sterne: 3+
            [5] = 4,  -- 5 Sterne: 4+
        },
    },

    -- Verbrennungseffekt beim Vernichten
    Burn = {
        Enabled    = true,
        Collection = 'scr_mp_house',
        Effect     = 'scr_mp_int_fireplace_sml',
        Scale      = 1.5,
        Rotation   = vector3(0, 0, 0),
        Offset     = vector3(0, 0, 0.2),
        Duration   = 20000,
    },

    -- =========================================================
    -- WEED SORTEN — neue Sorte einfach hier hinzufügen!
    -- Jede Sorte braucht ein eigenes Samen-Item in ESX.
    -- stages: time = Minuten bis zur nächsten Stage
    --         harvest = true markiert die Ernte-Stage
    -- =========================================================
    Strains = {
        og_kush = {
            name       = 'OG Kush',
            seed       = 'og_kush_seed',
            product    = 'og_kush_weed',
            yield      = {3, 5},   -- zufällig 3–5 Weed beim Ernten
            seedReturn = {1, 3},   -- zufällig 1–3 Samen zurück
            stages = {
                {
                    label  = 'Keimling',
                    model  = `prop_weed_02`,
                    offset = vector3(0, 0, -1.0),
                    time   = 30,  -- 30 Minuten
                },
                {
                    label  = 'Wachstum',
                    model  = `prop_weed_02`,
                    offset = vector3(0, 0, -0.6),
                    time   = 120, -- 2 Stunden
                },
                {
                    label  = 'Blüte',
                    model  = `prop_weed_01`,
                    offset = vector3(0, 0, -0.3),
                    time   = 240, -- 4 Stunden
                },
                {
                    label   = 'Erntereif',
                    model   = `prop_weed_01`,
                    offset  = vector3(0, 0, 0),
                    time    = 120, -- Ernte-Fenster: 2 Stunden
                    harvest = true,
                },
            },
        },

        purple_haze = {
            name       = 'Purple Haze',
            seed       = 'purple_haze_seed',
            product    = 'purple_haze_weed',
            yield      = {3, 5},
            seedReturn = {1, 3},
            stages = {
                {
                    label  = 'Keimling',
                    model  = `prop_weed_02`,
                    offset = vector3(0, 0, -1.0),
                    time   = 40,
                },
                {
                    label  = 'Wachstum',
                    model  = `prop_weed_02`,
                    offset = vector3(0, 0, -0.6),
                    time   = 150,
                },
                {
                    label  = 'Blüte',
                    model  = `prop_weed_01`,
                    offset = vector3(0, 0, -0.3),
                    time   = 300,
                },
                {
                    label   = 'Erntereif',
                    model   = `prop_weed_01`,
                    offset  = vector3(0, 0, 0),
                    time    = 120,
                    harvest = true,
                },
            },
        },

        amnesia = {
            name       = 'Amnesia',
            seed       = 'amnesia_seed',
            product    = 'amnesia_weed',
            yield      = {3, 5},
            seedReturn = {1, 3},
            stages = {
                {
                    label  = 'Keimling',
                    model  = `prop_weed_02`,
                    offset = vector3(0, 0, -1.0),
                    time   = 35,
                },
                {
                    label  = 'Wachstum',
                    model  = `prop_weed_02`,
                    offset = vector3(0, 0, -0.6),
                    time   = 130,
                },
                {
                    label  = 'Blüte',
                    model  = `prop_weed_01`,
                    offset = vector3(0, 0, -0.3),
                    time   = 260,
                },
                {
                    label   = 'Erntereif',
                    model   = `prop_weed_01`,
                    offset  = vector3(0, 0, 0),
                    time    = 120,
                    harvest = true,
                },
            },
        },

        white_widow = {
            name       = 'White Widow',
            seed       = 'white_widow_seed',
            product    = 'white_widow_weed',
            yield      = {3, 5},
            seedReturn = {1, 3},
            stages = {
                {
                    label  = 'Keimling',
                    model  = `prop_weed_02`,
                    offset = vector3(0, 0, -1.0),
                    time   = 50,
                },
                {
                    label  = 'Wachstum',
                    model  = `prop_weed_02`,
                    offset = vector3(0, 0, -0.6),
                    time   = 180,
                },
                {
                    label  = 'Blüte',
                    model  = `prop_weed_01`,
                    offset = vector3(0, 0, -0.3),
                    time   = 360,
                },
                {
                    label   = 'Erntereif',
                    model   = `prop_weed_01`,
                    offset  = vector3(0, 0, 0),
                    time    = 120,
                    harvest = true,
                },
            },
        },
    },

    -- =========================================================
    -- WILD WEED SYSTEM
    -- Kein Blip, kein Marker, keine Map-Hinweise!
    -- =========================================================
    WildWeed = {
        -- Chance, dass eine Pflanze an einer Position erscheint (0.0–1.0)
        SpawnChance = 0.65,

        -- Fortschrittsbalken-Dauer beim Einsammeln (Millisekunden)
        CollectTime = 5000,

        -- Minigame-Schwierigkeit: {'easy','easy','medium'} etc.
        MinigameDifficulty = { 'easy', 'easy' },

        -- Welche Sorten können wild spawnen und mit welcher Wahrscheinlichkeit?
        -- chance-Werte müssen zusammen 100 ergeben!
        StrainChances = {
            { strain = 'og_kush',     chance = 40, prop = `prop_weed_01` },
            { strain = 'purple_haze', chance = 30, prop = `prop_weed_02` },
            { strain = 'amnesia',     chance = 20, prop = `prop_weed_01` },
            { strain = 'white_widow', chance = 10, prop = `prop_weed_02` },
        },

        -- Spawn-Positionen — so viele wie gewünscht hinzufügen!
        -- Kein Blip, kein Marker, Spieler müssen sie selbst finden.
        Positions = {
            -- Paleto Forest / North Blaine County
            vector3(-1043.26, -584.01, 53.84),
            vector3(-1089.46, -607.92, 45.55),
            vector3(-1066.83, -560.17, 52.19),
            vector3(-1124.55, -534.76, 56.78),
            vector3(-1009.14, -619.43, 51.62),
            vector3(-857.42,  -533.61, 28.45),
            vector3(-862.17,  -518.93, 29.12),
            vector3(-839.54,  -546.72, 27.88),
            vector3(-785.31,  -571.44, 26.33),
            vector3(-810.29,  -498.76, 30.91),
            -- Great Ocean Highway area
            vector3(-358.14, 6235.91, 30.42),
            vector3(-389.77, 6254.18, 29.87),
            vector3(-327.41, 6271.53, 31.14),
            vector3(-412.63, 6212.84, 28.76),
            vector3(-295.88, 6289.47, 32.33),
            -- Sandy Shores / Grapeseed
            vector3(2685.14, 3265.43, 55.24),
            vector3(2703.88, 3291.17, 54.98),
            vector3(2721.56, 3241.82, 56.41),
            vector3(2668.43, 3278.94, 54.67),
            vector3(2740.29, 3262.15, 57.83),
            -- Raton Canyon
            vector3(-481.62, 3779.14, 237.42),
            vector3(-503.44, 3801.76, 239.18),
            vector3(-459.17, 3752.39, 235.67),
            vector3(-527.83, 3762.54, 240.91),
            vector3(-441.29, 3819.61, 236.44),
            -- Mount Chilliad area
            vector3(495.17,  5603.84, 791.24),
            vector3(473.42,  5578.61, 788.77),
            vector3(518.83,  5621.37, 793.15),
            vector3(451.67,  5611.93, 786.44),
            vector3(539.14,  5589.24, 795.62),
        },
    },
}
