-- =========================================================
-- GROWTH HELPERS
-- Hilfsfunktionen für das Sortenbasierte Wachstumssystem.
-- Alle Wachstumsdaten kommen aus Config.Strains.
-- =========================================================

function GetStrainData(strainKey)
    return Config.Strains[strainKey]
end

function GetStageData(strainKey, stage)
    local strain = Config.Strains[strainKey]
    if not strain then return nil end
    return strain.stages[stage]
end

function GetStageCount(strainKey)
    local strain = Config.Strains[strainKey]
    if not strain then return 0 end
    return #strain.stages
end

function IsHarvestStage(strainKey, stage)
    local stageData = GetStageData(strainKey, stage)
    return stageData ~= nil and stageData.harvest == true
end

-- Berechnet Qualität (1–5 Sterne) basierend auf Pflege
function GetQualityStars(waterCount, fertCount)
    waterCount = waterCount or 0
    fertCount  = fertCount  or 0

    local waterStars = 1
    for stars = 5, 2, -1 do
        if waterCount >= Config.Quality.Water[stars] then
            waterStars = stars
            break
        end
    end

    local fertStars = 1
    for stars = 5, 2, -1 do
        if fertCount >= Config.Quality.Fertilizer[stars] then
            fertStars = stars
            break
        end
    end

    return math.min(5, math.max(1, math.floor((waterStars + fertStars) / 2)))
end

function GetQualityLabel(stars)
    local labels = {
        [1] = '★☆☆☆☆  Schlecht',
        [2] = '★★☆☆☆  Mäßig',
        [3] = '★★★☆☆  Normal',
        [4] = '★★★★☆  Gut',
        [5] = '★★★★★  Perfekt',
    }
    return labels[stars] or '★☆☆☆☆  Schlecht'
end
