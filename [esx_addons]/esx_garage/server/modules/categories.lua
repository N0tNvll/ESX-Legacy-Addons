-- SPDX-License-Identifier: GPL-3.0-only
-- Copyright (C) 2022-2026 ESX Framework

-- Ownership (public/job) and physical vehicle category are independent.
GarageCategories = {}

local aliases = {
    ground = {
        '',
        'car',
        'automobile',
        'motorcycle',
        'bike',
        'bicycle',
        'truck',
        'emergency',
        'trailer',
        'quadbike',
        'amphibious_automobile',
        'amphibious_quadbike',
    },
    boat = { 'boat', 'submarine' },
    helicopter = { 'helicopter', 'heli' },
    plane = { 'plane', 'airplane', 'blimp' },
    train = { 'train' },
}

local byType = {}

for category, values in pairs(aliases) do
    for _, value in ipairs(values) do
        byType[value] = category
    end
end

function GarageCategories.fromType(value)
    return byType[type(value) == 'string' and value:lower() or '']
end

function GarageCategories.allowed(location)
    local configured = location.vehicleCategories

    if configured == nil then
        -- Compatibility for old definitions; unspecified garages are land garages.
        configured = location.type == 'boat' and { 'boat' }
            or location.type == 'aircraft' and { 'helicopter', 'plane' }
            or { 'ground' }
    end

    if type(configured) ~= 'table' or #configured == 0 then
        return {}
    end

    local result = {}

    for _, category in ipairs(configured) do
        if not aliases[category] then
            return {}
        end

        result[category] = true
    end

    return result
end

local function modelValues(model)
    local values = { tostring(model):lower() }
    local hash = tonumber(model) or GetHashKey(model)

    values[#values + 1] = tostring(math.floor(hash))
    values[#values + 1] = tostring(math.floor(hash < 0 and hash + 4294967296 or hash))
    values[#values + 1] = tostring(math.floor(hash >= 2147483648 and hash - 4294967296 or hash))
    return values
end

local function modelOf(row)
    local ok, props = pcall(json.decode, row.vehicle or '')

    return ok and type(props) == 'table' and props.model or nil
end

local function modelValue(model)
    local numeric = tonumber(model)

    return numeric and tostring(math.floor(numeric)) or tostring(model):lower()
end

function GarageCategories.resolve(row)
    if not next(Config.VehicleCategoryOverrides or {}) then
        return GarageCategories.fromType(row.type)
    end

    local model = modelOf(row)

    if model ~= nil then
        local value = modelValue(model)

        for configured, category in pairs(Config.VehicleCategoryOverrides or {}) do
            for _, candidate in ipairs(modelValues(configured)) do
                if candidate == value then
                    return aliases[category] and category or nil
                end
            end
        end
    end

    return GarageCategories.fromType(row.type)
end

function GarageCategories.accepts(location, row)
    local category = GarageCategories.resolve(row)

    return category ~= nil and GarageCategories.allowed(location)[category] == true
end

function GarageCategories.acceptsEntity(location, entity)
    local category = GarageCategories.fromType(GetVehicleType(entity))

    return category ~= nil and GarageCategories.allowed(location)[category] == true
end

function GarageCategories.models(location, source)
    if location.models == nil then
        return nil
    end

    local models = location.models

    if
        type(models) == 'function' or (ESX.IsFunctionReference and ESX.IsFunctionReference(models))
    then
        local ok, result = pcall(models, source)

        models = ok and result or {}
    end

    local values = {}

    for _, model in ipairs(type(models) == 'table' and models or {}) do
        for _, value in ipairs(modelValues(model)) do
            values[value] = true
        end
    end

    return values
end

function GarageCategories.acceptsModel(location, row, source)
    local allowed = GarageCategories.models(location, source)

    return allowed == nil or allowed[modelValue(modelOf(row))] == true
end

function GarageCategories.condition(location, source)
    local cases, params = {}, {}

    for model, category in pairs(Config.VehicleCategoryOverrides or {}) do
        assert(aliases[category], 'Invalid vehicle category override')

        local values, placeholders = modelValues(model), {}

        for _, value in ipairs(values) do
            params[#params + 1] = value
            placeholders[#placeholders + 1] = '?'
        end

        params[#params + 1] = category
        cases[#cases + 1] = (
            (
                'WHEN LOWER(CASE WHEN JSON_VALID(`vehicle`) THEN '
                .. "JSON_UNQUOTE(JSON_EXTRACT(`vehicle`, '$.model')) ELSE '' END) "
                .. 'IN (%s) THEN '
                .. '?'
            )
        ):format(table.concat(placeholders, ','))
    end

    local typeCases = {}

    for category, values in pairs(aliases) do
        for _, value in ipairs(values) do
            typeCases[#typeCases + 1] = 'WHEN ? THEN ?'
            params[#params + 1] = value
            params[#params + 1] = category
        end
    end

    local expression = "CASE COALESCE(LOWER(`type`), '') "
        .. table.concat(typeCases, ' ')
        .. ' ELSE NULL END'

    if #cases > 0 then
        expression = 'CASE ' .. table.concat(cases, ' ') .. ' ELSE ' .. expression .. ' END'
    end

    local placeholders = {}

    for category in pairs(GarageCategories.allowed(location)) do
        placeholders[#placeholders + 1] = '?'
        params[#params + 1] = category
    end

    if #placeholders == 0 then
        return '0 = 1', {}
    end

    local condition = '(' .. expression .. ') IN (' .. table.concat(placeholders, ',') .. ')'
    local models = GarageCategories.models(location, source)

    if models then
        local modelPlaceholders = {}

        for value in pairs(models) do
            modelPlaceholders[#modelPlaceholders + 1] = '?'
            params[#params + 1] = value
        end

        if #modelPlaceholders == 0 then
            return '0 = 1', {}
        end

        condition = condition
            .. (
                (
                    ' AND LOWER(CASE WHEN JSON_VALID(`vehicle`) THEN '
                    .. "JSON_UNQUOTE(JSON_EXTRACT(`vehicle`, '$.model')) ELSE '' "
                    .. 'END) IN '
                    .. '(%s)'
                )
            ):format(table.concat(modelPlaceholders, ','))
    end

    return condition, params
end

function GarageCategories.impound(row, preferred)
    for _, lot in ipairs(Config.Impounds or {}) do
        if lot.id == preferred and GarageCategories.accepts(lot, row) then
            return lot.id
        end
    end

    for _, lot in ipairs(Config.Impounds or {}) do
        if GarageCategories.accepts(lot, row) then
            return lot.id
        end
    end
end

function GarageCategories.validate(location)
    assert(
        next(GarageCategories.allowed(location)),
        'A garage/impound needs valid vehicleCategories'
    )
end
