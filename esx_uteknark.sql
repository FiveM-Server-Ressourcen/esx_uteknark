-- =========================================================
-- ESX UteKnark — Datenbankschema v3.0 (dynamisches Wachstum)
--
-- FRISCHE INSTALLATION:
--   Nur dieses SQL ausführen.
--
-- MIGRATION von v2.x (stage/water_count/fertilizer_count):
--   ALTER TABLE `uteknark`
--       DROP COLUMN IF EXISTS `stage`,
--       DROP COLUMN IF EXISTS `water_count`,
--       DROP COLUMN IF EXISTS `fertilizer_count`,
--       DROP COLUMN IF EXISTS `time`,
--       ADD COLUMN IF NOT EXISTS `water`       FLOAT NOT NULL DEFAULT 80   AFTER `strain`,
--       ADD COLUMN IF NOT EXISTS `fertilizer`  FLOAT NOT NULL DEFAULT 50   AFTER `water`,
--       ADD COLUMN IF NOT EXISTS `health`      FLOAT NOT NULL DEFAULT 100  AFTER `fertilizer`,
--       ADD COLUMN IF NOT EXISTS `growth`      FLOAT NOT NULL DEFAULT 0    AFTER `health`,
--       ADD COLUMN IF NOT EXISTS `quality`     FLOAT NOT NULL DEFAULT 0.5  AFTER `growth`,
--       ADD COLUMN IF NOT EXISTS `last_tick`   INT UNSIGNED NOT NULL DEFAULT 0 AFTER `quality`;
-- =========================================================

DROP TABLE IF EXISTS `uteknark`;

CREATE TABLE `uteknark` (
    `id`          INT(10) UNSIGNED NOT NULL AUTO_INCREMENT,
    `x`           FLOAT            NOT NULL DEFAULT 0,
    `y`           FLOAT            NOT NULL DEFAULT 0,
    `z`           FLOAT            NOT NULL DEFAULT 0,
    `strain`      VARCHAR(50)      NOT NULL DEFAULT 'og_kush'
                                    COMMENT 'Schlüssel aus Config.Strains',

    -- Kontinuierliche Pflegewerte (0.0 – 100.0)
    `water`       FLOAT            NOT NULL DEFAULT 80
                                    COMMENT 'Wasserspiegel 0-100%',
    `fertilizer`  FLOAT            NOT NULL DEFAULT 50
                                    COMMENT 'Düngerspiegel 0-100%',
    `health`      FLOAT            NOT NULL DEFAULT 100
                                    COMMENT 'Gesundheit 0-100%',
    `growth`      FLOAT            NOT NULL DEFAULT 0
                                    COMMENT 'Wachstumsfortschritt 0-100%',

    -- Interne Qualität (0.0 – 1.0) – wird Spielern NICHT angezeigt
    `quality`     FLOAT            NOT NULL DEFAULT 0.5
                                    COMMENT 'Interne Qualität, beeinflusst Ertrag',

    -- Unix-Timestamp des letzten Server-Ticks (Verfall-Berechnung)
    `last_tick`   INT(10) UNSIGNED NOT NULL DEFAULT 0
                                    COMMENT 'os.time() beim letzten Tick',

    PRIMARY KEY (`id`),
    INDEX `idx_strain`  (`strain`),
    INDEX `idx_growth`  (`growth`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
  COMMENT='ESX UteKnark v3.0 – dynamisches Wachstumssystem';
