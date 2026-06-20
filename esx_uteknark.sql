-- =========================================================
-- ESX UteKnark — Datenbankschema v2.0
--
-- FRISCHE INSTALLATION:
--   Nur dieses SQL ausführen.
--
-- MIGRATION von v1.x (soil-basiertes System):
--   ALTER TABLE `uteknark` ADD COLUMN IF NOT EXISTS `strain` varchar(50) NOT NULL DEFAULT 'og_kush' AFTER `z`;
--   ALTER TABLE `uteknark` ADD COLUMN IF NOT EXISTS `water_count` int(11) NOT NULL DEFAULT 0;
--   ALTER TABLE `uteknark` ADD COLUMN IF NOT EXISTS `fertilizer_count` int(11) NOT NULL DEFAULT 0;
--   ALTER TABLE `uteknark` DROP COLUMN IF EXISTS `soil`;
-- =========================================================

CREATE TABLE IF NOT EXISTS `uteknark` (
  `id`               INT(10) UNSIGNED NOT NULL AUTO_INCREMENT,
  `x`                FLOAT(10)        NOT NULL,
  `y`                FLOAT(10)        NOT NULL,
  `z`                FLOAT(10)        NOT NULL,
  `strain`           VARCHAR(50)      NOT NULL DEFAULT 'og_kush'
                                      COMMENT 'Key aus Config.Strains',
  `stage`            INT(3) UNSIGNED  NOT NULL DEFAULT 1,
  `water_count`      INT(11)          NOT NULL DEFAULT 0,
  `fertilizer_count` INT(11)          NOT NULL DEFAULT 0,
  `time`             TIMESTAMP        NOT NULL DEFAULT CURRENT_TIMESTAMP
                                               ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  INDEX (`strain`, `stage`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='ESX UteKnark v2.0';
