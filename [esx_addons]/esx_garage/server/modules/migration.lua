GarageReady = false

local TABLE <const> = "owned_vehicles"
local MIGRATION_TABLE <const> = "esx_garage_migrations"
local MIGRATION_NAME <const> = "schema"
local LEGACY_MIGRATION_VERSION <const> = "1"
local MIGRATION_VERSION <const> = "1.14.2"

---@return string?
local function appliedMigrationVersion()
    local ok, version = pcall(MySQL.scalar.await,
        ("SELECT `version` FROM `%s` WHERE `name` = ?"):format(MIGRATION_TABLE),
        { MIGRATION_NAME })

    if not ok or version == nil then
        return nil
    end

    return tostring(version)
end

---@param version string?
---@return boolean
local function migrationApplied(version)
    return version == MIGRATION_VERSION or version == LEGACY_MIGRATION_VERSION
end

local function ensureMigrationTable()
    MySQL.query.await(([[
        CREATE TABLE IF NOT EXISTS `%s` (
            `name` VARCHAR(64) NOT NULL,
            `version` VARCHAR(32) NOT NULL DEFAULT '0',
            `applied_at` INT NOT NULL DEFAULT 0,
            PRIMARY KEY (`name`)
        )
    ]]):format(MIGRATION_TABLE))

    local versionType = MySQL.scalar.await(
        "SELECT DATA_TYPE FROM information_schema.COLUMNS WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = ? AND COLUMN_NAME = 'version'",
        { MIGRATION_TABLE })

    if versionType ~= "varchar" then
        MySQL.query.await(("ALTER TABLE `%s` MODIFY COLUMN `version` VARCHAR(32) NOT NULL DEFAULT '0'"):format(MIGRATION_TABLE))
    end
end

local function markMigrationApplied()
    local now = os.time()

    MySQL.query.await(
        ("INSERT INTO `%s` (`name`, `version`, `applied_at`) VALUES (?, ?, ?) ON DUPLICATE KEY UPDATE `version` = ?, `applied_at` = ?")
            :format(MIGRATION_TABLE),
        { MIGRATION_NAME, MIGRATION_VERSION, now, MIGRATION_VERSION, now })
end

---@param column string
---@return boolean
local function hasColumn(column)
    local count = MySQL.scalar.await(
        "SELECT COUNT(*) FROM information_schema.COLUMNS WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = ? AND COLUMN_NAME = ?",
        { TABLE, column })

    return (count or 0) > 0
end

---@param index string
---@return boolean
local function hasIndex(index)
    local count = MySQL.scalar.await(
        "SELECT COUNT(*) FROM information_schema.STATISTICS WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = ? AND INDEX_NAME = ?",
        { TABLE, index })

    return (count or 0) > 0
end

---@param column string
---@param definition string
---@return boolean
local function ensureColumn(column, definition)
    if hasColumn(column) then
        return false
    end

    MySQL.query.await(("ALTER TABLE `%s` ADD COLUMN `%s` %s"):format(TABLE, column, definition))

    return true
end

---@param index string
---@param definition string
---@return boolean
local function ensureIndex(index, definition)
    if hasIndex(index) then
        return false
    end

    MySQL.query.await(("ALTER TABLE `%s` ADD INDEX `%s` %s"):format(TABLE, index, definition))

    return true
end

---@type string[][]
local SCHEMA <const> = {
    { "parking", "VARCHAR(60) NULL DEFAULT NULL" },
    { "pound", "VARCHAR(60) NULL DEFAULT NULL" },
    { "custom_name", "VARCHAR(50) NULL DEFAULT NULL" },
    { "is_favorite", "TINYINT(1) NOT NULL DEFAULT 0" },
    { "last_used", "INT NULL DEFAULT NULL" },
    { "mileage", "INT NOT NULL DEFAULT 0" },
}

---@type string[][]
local INDEXES <const> = {
    { "idx_owned_vehicles_owner_plate", "(`owner`, `plate`)" },
    { "idx_owned_vehicles_owner_custom_name", "(`owner`, `custom_name`)" },
}

CreateThread(function()

    local added, indexed, legacy = 0, 0, 0

    local ok, err = pcall(function()
        local version = appliedMigrationVersion()
        if migrationApplied(version) then
            if version ~= MIGRATION_VERSION then
                ensureMigrationTable()
                markMigrationApplied()
            end

            return
        end

        ensureMigrationTable()

        for i = 1, #SCHEMA do
            if ensureColumn(SCHEMA[i][1], SCHEMA[i][2]) then
                added = added + 1
            end
        end

        for i = 1, #INDEXES do
            if ensureIndex(INDEXES[i][1], INDEXES[i][2]) then
                indexed = indexed + 1
            end
        end

        legacy = MySQL.scalar.await(("SELECT COUNT(*) FROM `%s` WHERE `stored` = 2"):format(TABLE)) or 0

        if legacy > 0 then
            local defaultLot = Config.Impounds and Config.Impounds[1] and Config.Impounds[1].id
            if defaultLot then
                MySQL.update.await(("UPDATE `%s` SET `stored` = 1, `parking` = NULL, `pound` = ? WHERE `stored` = 2"):format(TABLE),
                    { defaultLot })
            else
                MySQL.update.await(("UPDATE `%s` SET `stored` = 1, `parking` = NULL WHERE `stored` = 2"):format(TABLE))
            end
        end

        markMigrationApplied()
    end)

    if not ok then
        print(("[esx_garage] db migration FAILED, garages will not serve vehicles: %s"):format(tostring(err)))
        return
    end

    GarageReady = true

    if added > 0 or indexed > 0 or legacy > 0 then
        print(("[esx_garage] db migration applied: %d column(s) added, %d index(es) added, %d legacy impound row(s) converted"):format(added, indexed, legacy))
    end
end)
