-- SPDX-License-Identifier: GPL-3.0-only
-- Copyright (C) 2022-2026 ESX Framework
local D = VehicleShop
local seededOffers = {}
local MOJIBAKE_MARKERS = { 'Ã', 'Â' }
local HAS_UTF8 = type(utf8) == 'table' and type(utf8.len) == 'function'

local function isUtf8(value)
    return utf8.len(value) ~= nil
end

local function latin1ToUtf8(value)
    local characters = {}

    for index = 1, #value do
        characters[index] = utf8.char(value:byte(index))
    end

    return table.concat(characters)
end

local function utf8ToLatin1(value)
    local characters = {}

    for _, codepoint in utf8.codes(value) do
        if codepoint > 255 then
            return nil
        end

        characters[#characters + 1] = string.char(codepoint)
    end

    return table.concat(characters)
end

local function repairEncoding(value)
    if not HAS_UTF8 or type(value) ~= 'string' or value == '' then
        return value
    end

    if not isUtf8(value) then
        local converted = latin1ToUtf8(value)

        return isUtf8(converted) and converted or value
    end

    local marked = false

    for _, marker in ipairs(MOJIBAKE_MARKERS) do
        if value:find(marker, 1, true) then
            marked = true
            break
        end
    end

    if not marked then
        return value
    end

    local converted = utf8ToLatin1(value)

    if converted and converted ~= value and isUtf8(converted) then
        return converted
    end

    return value
end

function D.repairCategoryLabels(categories)
    for _, category in ipairs(categories) do
        local label = repairEncoding(category.label)

        if label ~= category.label then
            MySQL.update.await(
                'UPDATE vehicle_categories SET label = ? WHERE name = ?',
                { label, category.name }
            )
            category.label = label
        end
    end
end

function D.seedShop(shop)
    if shop.enabled == false then
        return
    end

    if shop.offers and seededOffers[shop.id] == shop then
        return
    end

    for _, offer in ipairs(shop.offers or {}) do
        local model = assert(D.normalizeModel(offer.model), 'Invalid dealership model')
        local price = assert(D.money(offer.price, true), 'Invalid dealership price')
        local kind = offer.type or shop.vehicleTypes[1]

        assert(VehicleShopTypes[kind], 'Invalid dealership vehicle type')

        local category = offer.category or shop.catalog or kind

        MySQL.insert.await('INSERT IGNORE INTO vehicle_categories (name, label) VALUES (?, ?)', { category, offer.categoryLabel or category })
        MySQL.insert.await(('INSERT IGNORE INTO vehicles (model, name, price, category, ' .. 'type) VALUES (?, ?, ?, ?, ' .. '?)'), { model, offer.name or offer.label or model, price, category, kind })
        MySQL.insert.await(
            [[INSERT IGNORE INTO dealership_vehicles (shop_id, model, price, vehicle_type, props)
            VALUES (?, ?, ?, ?, ?)]],
            { shop.id, model, price, kind, json.encode(offer.props or {}) }
        )
    end

    if not shop.offers then
        local placeholders, params = {}, { shop.id }

        for _, kind in ipairs(shop.vehicleTypes) do
            placeholders[#placeholders + 1] = '?'
            params[#params + 1] = kind
        end

        local condition = 'enabled = 1 AND type IN (' .. table.concat(placeholders, ',') .. ')'

        if shop.categories then
            local categories = {}

            for _, category in ipairs(shop.categories) do
                categories[#categories + 1] = '?'
                params[#params + 1] = category
            end

            condition = condition .. (#categories > 0 and (' AND category IN (' .. table.concat(categories, ',') .. ')') or ' AND 0 = 1')
        end

        -- Job offers share the SQL model catalog, but must never be automatically
        -- enrolled into an unrestricted civilian dealership during a later reload.
        if not shop.ownershipJob then
            local reserved, seen = {}, {}

            for _, other in pairs(D.shops) do
                if other.ownershipJob then
                    for _, offer in ipairs(other.offers or {}) do
                        local model = D.normalizeModel(offer.model)

                        if model and not seen[model] then
                            seen[model] = true
                            reserved[#reserved + 1] = model
                        end
                    end
                end
            end

            if #reserved > 0 then
                local reservedPlaceholders = {}

                for index = 1, #reserved do
                    reservedPlaceholders[index] = '?'
                    params[#params + 1] = reserved[index]
                end

                condition = condition
                    .. ' AND LOWER(model) NOT IN ('
                    .. table.concat(reservedPlaceholders, ',')
                    .. ')'
            end
        end

        local insertSql = 'INSERT IGNORE INTO dealership_vehicles (shop_id, model) '
            .. 'SELECT ?, LOWER(model) FROM vehicles WHERE ' .. condition

        MySQL.insert.await(insertSql, params)
    end

    seededOffers[shop.id] = shop
end

function D.reloadCatalog()
    while D.catalogLoading do
        Wait(0)
    end

    D.catalogLoading = true

    local ok, err = pcall(function()
        for _, shop in pairs(D.shops) do
            D.seedShop(shop)
        end

        local categories = MySQL.query.await('SELECT * FROM vehicle_categories')

        assert(type(categories) == 'table', 'Unable to load vehicle categories')
        D.repairCategoryLabels(categories)

        local rows = MySQL.query.await(('SELECT v.*, c.label AS categoryLabel FROM vehicles v LEFT ' .. 'JOIN vehicle_categories c ON v.category = ' .. 'c.name'))
        local members = MySQL.query.await('SELECT * FROM dealership_vehicles')

        assert(
            type(rows) == 'table' and type(members) == 'table',
            'Unable to load complete dealership catalog'
        )

        local catalog, membership = {}, {}

        for _, vehicle in ipairs(rows) do
            catalog[vehicle.model:lower()] = vehicle
        end

        for _, member in ipairs(members) do
            membership[member.shop_id] = membership[member.shop_id] or {}
            membership[member.shop_id][member.model:lower()] = member
        end

        local reservedModels = {}

        for shopId, shop in pairs(D.shops) do
            if shop.ownershipJob then
                for model in pairs(membership[shopId] or {}) do
                    reservedModels[model] = true
                end
            end
        end

        for shopId, shop in pairs(D.shops) do
            if not shop.ownershipJob then
                for model in pairs(membership[shopId] or {}) do
                    if reservedModels[model] then
                        membership[shopId][model] = nil
                    end
                end
            end
        end

        D.catalog, D.categories, D.members = catalog, categories, membership
    end)

    D.catalogLoading = false

    if not ok then
        error(err)
    end
end

function D.offer(shop, model, player)
    model = D.normalizeModel(model)

    local base = model and D.catalog[model]
    local member = model and D.members[shop.id] and D.members[shop.id][model]

    if not base or not member or (base.enabled ~= true and tonumber(base.enabled) ~= 1) or (member.enabled ~= true and tonumber(member.enabled) ~= 1) then
        return nil
    end

    local kind = member.vehicle_type or base.type

    if not VehicleShopTypes[kind] or not D.contains(shop.vehicleTypes, kind) then
        return nil
    end

    local offer = {
        model = model,
        name = base.name,
        category = base.category,
        categoryLabel = base.categoryLabel or base.category,
        type = kind,
        price = tonumber(member.price) or tonumber(base.price),
        minGrade = tonumber(member.min_grade) or 0,
        license = member.license,
        props = {},
    }

    if member.props then
        local ok, props = pcall(json.decode, member.props)

        if ok and type(props) == 'table' then
            offer.props = props
        end
    end

    if shop.resolveOffer then
        local ok, rule = pcall(shop.resolveOffer, player.source, model)

        if not ok or type(rule) ~= 'table' then
            return nil
        end

        offer.price, offer.props = rule.price, rule.props or offer.props
    end

    if not D.money(offer.price) then
        return nil
    end

    if offer.minGrade > 0 and (not player.job or player.job.grade < offer.minGrade) then
        return nil
    end

    return offer
end

function D.catalogFor(shop, player)
    local stock = {}

    for _, row in ipairs(MySQL.query.await(('SELECT vehicle, COUNT(*) AS amount FROM ' .. 'cardealer_vehicles WHERE shop_id = ? AND available = 1 ' .. 'GROUP BY ' .. 'vehicle'), { shop.id }) or {}) do
        stock[row.vehicle:lower()] = tonumber(row.amount)
    end

    local result = {}

    for model in pairs(D.members[shop.id] or {}) do
        local offer = D.offer(shop, model, player)

        if offer then
            offer.props = nil
            offer.stock = shop.stockMode == 'unlimited' and -1 or (stock[model] or 0)
            result[#result + 1] = offer
        end
    end

    table.sort(result, function(a, b)
        return a.name < b.name
    end)

    return result
end
