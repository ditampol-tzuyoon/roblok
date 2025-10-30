function GetRarityFromProbability(rawChance)
    if not rawChance or rawChance <= 0 then return nil end

    local oneInX = 1 / rawChance
    
    if oneInX >= 249999 then
        return "Secret"
    elseif oneInX >= 49999 then
        return "Mythic"
    elseif oneInX >= 4999 then
        return "Legendary"
    else
        return nil
    end
end

function GatherInventoryData()
    local result = { Fish={}, Gear={} }
    local hitungan = { Fish={}, Gear={} }
    
    local ReplicatedStorage = game:GetService("ReplicatedStorage")
    local ItemUtility = require(ReplicatedStorage.Shared.ItemUtility)
    local ReplionClient = require(ReplicatedStorage.Packages.Replion).Client

    local PlayerData = ReplionClient:WaitReplion("Data")
    if not PlayerData then 
        return result
    end

    local inventory = PlayerData:Get("Inventory")
    if not (inventory and inventory.Items) then 
        return result
    end

    local RarityMap = {
        [1] = "Common", [2] = "Uncommon", [3] = "Rare",
        [4] = "Epic", [5] = "Legendary", [6] = "Mythic", [7] = "Secret",
    }

    for _, itemData in ipairs(inventory.Items) do
        local fullData = ItemUtility:GetItemData(itemData.Id)
        if fullData and fullData.Data then
            local ItemType = fullData.Data.Type
            local ItemName = fullData.Data.Name
            local ItemIcon = fullData.Data.Icon
            local ItemRare

            if ItemType == "Fish" or ItemType == "Enchant Stones" then

                if fullData.Probability and fullData.Probability.Chance then
                    ItemRare = GetRarityFromProbability(fullData.Probability.Chance)
                end

                if not ItemRare then
                    ItemRare = RarityMap[fullData.Data.Tier] or "Unknown"
                end

                local weight = (itemData.Metadata and itemData.Metadata.Weight) or 0
                local variant = (itemData.Metadata and itemData.Metadata.VariantId and " | " .. tostring(itemData.Metadata.VariantId)) or ""
                local shiny = (itemData.Metadata and itemData.Metadata.Shiny and " | Shiny") or ""

                local details = tostring(weight) .. "Kg" .. variant .. shiny

                if not hitungan.Fish[ItemName] then
                    hitungan.Fish[ItemName] = { icon = ItemIcon, count = 0, rarity = ItemRare, detail = {} }
                end

                table.insert(hitungan.Fish[ItemName].detail, details)
                hitungan.Fish[ItemName].count = hitungan.Fish[ItemName].count + 1

            elseif ItemType == "Gears" then 
                ItemRare = RarityMap[fullData.Data.Tier] or "Unknown"
                if not hitungan.Gear[ItemName] then
                    hitungan.Gear[ItemName] = { icon = ItemIcon, count = 0, rarity = ItemRare, detail = {} }
                end
                table.insert(hitungan.Gear[ItemName].detail, ItemRare)
                hitungan.Gear[ItemName].count = hitungan.Gear[ItemName].count + 1
            end
        end
    end

    local fishingRodsCategory = inventory and inventory["Fishing Rods"]
    if fishingRodsCategory and #fishingRodsCategory > 0 then
        for _, itemData in ipairs(fishingRodsCategory) do
            local fullData = ItemUtility:GetItemData(itemData.Id)
            if fullData and fullData.Data and fullData.Data.Tier then
                local ItemName = fullData.Data.Name
                local ItemRare = RarityMap[fullData.Data.Tier] or "Unknown"
                local ItemIcon = fullData.Data.Icon or "NONE"
                if not hitungan.Gear[ItemName] then
                    hitungan.Gear[ItemName] = { icon = ItemIcon, count = 0, rarity = ItemRare, detail = {} }
                end
                table.insert(hitungan.Gear[ItemName].detail, ItemRare)
                hitungan.Gear[ItemName].count = hitungan.Gear[ItemName].count + 1
            end
        end
    end

    local baitsCategory = inventory and inventory.Baits
    if baitsCategory or #baitsCategory > 0 then
        for _, itemData in ipairs(baitsCategory) do
            local fullData = ItemUtility:GetBaitData(itemData.Id)
            if fullData and fullData.Data and fullData.Data.Tier then
                local ItemName = fullData.Data.Name
                local ItemRare = RarityMap[fullData.Data.Tier] or "Unknown"
                local ItemIcon = fullData.Data.Icon or "NONE"
                if not hitungan.Gear[ItemName] then
                    hitungan.Gear[ItemName] = { icon = ItemIcon, count = 0, rarity = ItemRare, detail = {} }
                end
                table.insert(hitungan.Gear[ItemName].detail, ItemRare)
                hitungan.Gear[ItemName].count = hitungan.Gear[ItemName].count + 1
            end
        end
    end

    for _, data in pairs(hitungan.Fish) do
        table.sort(data.detail, function(a, b)
            local weightA = tonumber(a:match("([%d%.]+)Kg")) or 0
            local weightB = tonumber(b:match("([%d%.]+)Kg")) or 0
            return weightA > weightB
        end)
    end


    for kategori, dataHitungan in pairs(hitungan) do
        for nama, data in pairs(dataHitungan) do
            if kategori == "Fish" or kategori == "Gear" then
                table.insert(result[kategori], {
                    name = nama,
                    icon = data.icon,
                    count = data.count,
                    rarity = data.rarity,
                    detail = data.detail
                })
            else
                table.insert(result[kategori], { name = nama, count = data })
            end
        end
    end
    return result
end

function UpdateApiData()
    local HttpService = game:GetService("HttpService")
    local player = game:GetService("Players").LocalPlayer
    local requestFunc = http_request or request or syn.request
    
    if not requestFunc then
        warn("Error: Fungsi http request tidak ditemukan.")
        return
    end
    if not player then return end

    local ReplicatedStorage = game:GetService("ReplicatedStorage")
    local ReplionClient = require(ReplicatedStorage.Packages.Replion).Client
    local PlayerData = ReplionClient:GetReplion("Data")
    local currentCoins = 0
    if PlayerData then
        currentCoins = PlayerData:Get("Coins") or 0
    end
    
    local inventoryData = GatherInventoryData()
    local leaderstats = player:WaitForChild("leaderstats")

    local payload = {
        username = player.Name,
        displayName = player.DisplayName,
        userId = player.UserId,
        caught = leaderstats and leaderstats:FindFirstChild("Caught") and leaderstats.Caught.Value or 0,
        coins = currentCoins, 
        lastUpdate = os.time(),
        inventory = inventoryData,
        hasOnline = true
    }

    local jsonPayload = HttpService:JSONEncode(payload)
    local requestData = {
        Url = DataAPI,
        Method = "POST",
        Headers = {["Content-Type"] = "application/json", ["X-Access-Key"] = accessKey},
        Body = jsonPayload
    }

    local success, response = pcall(function() return requestFunc(requestData) end)
    if not success then
        print("Gagal kirim data: " .. tostring(response))
    end
end
