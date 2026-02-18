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
    local result = { Fish={}, Rods={}, Bobbers={}, Potions={}, Charms={}, Other={} }
    local hitungan = { Fish={}, Rods={}, Bobbers={}, Potions={}, Charms={}, Other={} }
    
    local ReplicatedStorage = game:GetService("ReplicatedStorage")
    local ItemUtility = require(ReplicatedStorage.Shared.ItemUtility)
    local ReplionClient = require(ReplicatedStorage.Packages.Replion).Client

    local PlayerData = ReplionClient:WaitReplion("Data")
    if not PlayerData then 
        return result
    end

    local inventory = PlayerData:Get("Inventory")
    if not (inventory and (inventory.Items or inventory["Fishing Rods"] or inventory.Baits or inventory.Totems)) then 
        return result
    end

    local RarityMap = {
        [1] = "Common", [2] = "Uncommon", [3] = "Rare",
        [4] = "Epic", [5] = "Legendary", [6] = "Mythic", [7] = "Secret",
    }

    local function CalculateFishPrice(itemData, fullData)
        if not (fullData and fullData.Data and fullData.Data.Type == "Fish" and fullData.SellPrice and fullData.SellPrice > 0) then
            return 0
        end
        
        local basePrice = fullData.SellPrice
        local totalMultiplier = 1.0
        local metadata = itemData.Metadata

        if metadata then
            local itemWeightData = fullData.Weight
            local actualWeight = metadata.Weight
            
            if itemWeightData and actualWeight and itemWeightData.Default and itemWeightData.Default.Max < actualWeight then
                if itemWeightData.Big and itemWeightData.Big.Max and itemWeightData.Big.Max > itemWeightData.Default.Max then
                    local weightBonusRatio = (actualWeight - itemWeightData.Default.Max) / (itemWeightData.Big.Max - itemWeightData.Default.Max)
                    totalMultiplier = totalMultiplier + math.max(0, weightBonusRatio)
                end
            end

            local variantId = metadata.VariantId
            local isShiny = metadata.Shiny
            
            if variantId then
                local variantData = ItemUtility:GetVariantData(variantId)
                if variantData and variantData.SellMultiplier then
                    local variantBonus = variantData.SellMultiplier
                    if isShiny then variantBonus = variantBonus * 1.5 end
                    totalMultiplier = totalMultiplier + variantBonus
                elseif isShiny then
                    totalMultiplier = totalMultiplier + 1.5
                end
            elseif isShiny then
                totalMultiplier = totalMultiplier + 1.5
            end
        end
        return math.ceil(basePrice * totalMultiplier)
    end

    -- Loop untuk inventory.Items (Fish, Enchant Stones, Gears)
    if inventory.Items then
        for _, itemData in ipairs(inventory.Items) do
            local fullData = ItemUtility:GetItemData(itemData.Id)
            
            if not fullData then
                 fullData = ItemUtility.GetItemDataFromItemType("Fish", itemData.Id)
            end

            if fullData and fullData.Data then
                local ItemType = fullData.Data.Type
                local ItemName = fullData.Data.Name
                local ItemIcon = fullData.Data.Icon
                local ItemRare

                if ItemType == "Fish" then
                    
                    if fullData.Probability and fullData.Probability.Chance then
                        ItemRare = GetRarityFromProbability(fullData.Probability.Chance)
                    end
                    if not ItemRare then
                        ItemRare = RarityMap[fullData.Data.Tier] or "Unknown"
                    end

                    local weight = (itemData.Metadata and itemData.Metadata.Weight) or 0
                    local mutation_str = (itemData.Metadata and itemData.Metadata.VariantId) or nil
                    local is_shiny = (itemData.Metadata and itemData.Metadata.Shiny) or false
                    
                    local variant_table = {}
                    if is_shiny then table.insert(variant_table, "Shiny") end
                    
                    local mutation_table = {}
                    if mutation_str then table.insert(mutation_table, tostring(mutation_str)) end

                    local finalPrice = CalculateFishPrice(itemData, fullData)

                    local details_object = {
                        weight = weight,
                        variant = variant_table,
                        mutation = mutation_table,
                        price = finalPrice 
                    }
                    
                    if not hitungan.Fish[ItemName] then
                        local basePrice = fullData.SellPrice or 0
                        hitungan.Fish[ItemName] = { 
                            icon = ItemIcon, 
                            count = 0, 
                            rarity = ItemRare, 
                            price = basePrice, 
                            detail = {} 
                        }
                    end

                    table.insert(hitungan.Fish[ItemName].detail, details_object) 
                    hitungan.Fish[ItemName].count = hitungan.Fish[ItemName].count + 1
                
                elseif ItemType == "Enchant Stones" or ItemType == "Gears" or ItemType == "Evolved Enchant Stones" then 
                    ItemRare = RarityMap[fullData.Data.Tier] or "Unknown"
                    local quantity = itemData.Quantity or 1
                    
                    if not hitungan.Other[ItemName] then
                        local basePrice = fullData.SellPrice or 0
                        hitungan.Other[ItemName] = { 
                            icon = ItemIcon, 
                            count = 0, 
                            rarity = ItemRare, 
                            price = basePrice,
                            isStone = (ItemType == "Enchant Stones" or ItemType == "Evolved Enchant Stones"), 
                            isTotem = false,
                            detail = {} 
                        }
                    end
                    
                    if ItemType == "Gears" then
                        table.insert(hitungan.Other[ItemName].detail, ItemRare)
                    end
                    hitungan.Other[ItemName].count = hitungan.Other[ItemName].count + quantity
                end
            end
        end
    end

    -- Loop khusus untuk kategori Potion
    local potionsCategory = inventory and inventory.Potions
    if potionsCategory then
        for _, itemData in ipairs(potionsCategory) do
            -- Menggunakan GetPotionData sesuai dekompilasi baris 193
            local fullData = ItemUtility:GetPotionData(itemData.Id)

            if fullData and fullData.Data then
                local ItemName = fullData.Data.Name
                local ItemIcon = fullData.Data.Icon or "NONE"
                local ItemTier = fullData.Data.Tier or 1
                local ItemRare = RarityMap[ItemTier] or "Unknown"
                local quantity = itemData.Quantity or 1

                if not hitungan.Potions[ItemName] then
                    hitungan.Potions[ItemName] = { 
                        icon = ItemIcon, 
                        count = 0, 
                        rarity = ItemRare, 
                        price = fullData.SellPrice or 0,
                        detail = {} 
                    }
                end

                hitungan.Potions[ItemName].count = hitungan.Potions[ItemName].count + quantity
            end
        end
    end

    -- Loop khusus untuk kategori Charms
    local charmsCategory = inventory and inventory.Charms
    if charmsCategory then
        for _, itemData in ipairs(charmsCategory) do
            -- Menggunakan GetCharmData sesuai dekompilasi baris 81
            local fullData = ItemUtility:GetCharmData(itemData.Id)

            if fullData and fullData.Data then
                local ItemName = fullData.Data.Name
                local ItemIcon = fullData.Data.Icon or "NONE"
                local ItemTier = fullData.Data.Tier or 1
                local ItemRare = RarityMap[ItemTier] or "Unknown"
                local quantity = itemData.Quantity or 1

                if not hitungan.Charms[ItemName] then
                    hitungan.Charms[ItemName] = { 
                        icon = ItemIcon, 
                        count = 0, 
                        rarity = ItemRare, 
                        price = fullData.SellPrice or 0,
                        detail = {} 
                    }
                end

                hitungan.Charms[ItemName].count = hitungan.Charms[ItemName].count + quantity
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
                if not hitungan.Rods[ItemName] then
                    local basePrice = fullData.SellPrice or 0
                    hitungan.Rods[ItemName] = { 
                        icon = ItemIcon, 
                        count = 0, 
                        rarity = ItemRare, 
                        price = basePrice,
                        detail = {} 
                    }
                end
                table.insert(hitungan.Rods[ItemName].detail, ItemRare)
                hitungan.Rods[ItemName].count = hitungan.Rods[ItemName].count + 1
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
                if not hitungan.Bobbers[ItemName] then
                    local basePrice = fullData.SellPrice or 0
                    hitungan.Bobbers[ItemName] = { 
                        icon = ItemIcon, 
                        count = 0, 
                        rarity = ItemRare, 
                        price = basePrice,
                        detail = {} 
                    }
                end
                table.insert(hitungan.Bobbers[ItemName].detail, ItemRare)
                hitungan.Bobbers[ItemName].count = hitungan.Bobbers[ItemName].count + 1
            end
        end
    end

    local totemsCategory = inventory and inventory.Totems
    if totemsCategory and #totemsCategory > 0 then
        for _, itemData in ipairs(totemsCategory) do
            local fullData = ItemUtility:GetTotemData(itemData.Id)
            
            if fullData and fullData.Data then
                local ItemName = fullData.Data.Name
                local ItemRare = RarityMap[fullData.Data.Tier] or "Unknown"
                local ItemIcon = fullData.Data.Icon or "NONE"
                
                if not hitungan.Other[ItemName] then
                    local basePrice = fullData.SellPrice or 0
                    hitungan.Other[ItemName] = { 
                        icon = ItemIcon, 
                        count = 0, 
                        rarity = ItemRare, 
                        price = basePrice,
                        isStone = false,
                        isTotem = true,
                        detail = {} 
                    }
                end
                
                hitungan.Other[ItemName].count = hitungan.Other[ItemName].count + 1
            end
        end
    end

    for _, data in pairs(hitungan.Fish) do
        table.sort(data.detail, function(a, b)
            return (a.weight or 0) > (b.weight or 0)
        end)
    end

    for kategori, dataHitungan in pairs(hitungan) do
        for nama, data in pairs(dataHitungan) do
            local finalDetail = data.detail
            if kategori == "Other" then
                finalDetail = {}
            end
            
            if kategori == "Fish" or kategori == "Rods" or kategori == "Bobbers" or kategori == "Other" or kategori == "Potions" or kategori == "Charms" then
                table.insert(result[kategori], {
                    name = nama,
                    icon = data.icon,
                    count = data.count,
                    rarity = data.rarity,
                    price = data.price,
                    isStone = data.isStone or false, 
                    isTotem = data.isTotem or false,
                    detail = finalDetail
                })
            else
                table.insert(result[kategori], { name = nama, count = data })
            end
        end
    end
    return result
end

function GetCurrentRodEnchant()

    local ReplicatedStorage = game:GetService("ReplicatedStorage")
    local ReplionClient = require(ReplicatedStorage.Packages.Replion).Client
    local ItemUtility = require(ReplicatedStorage.Shared.ItemUtility)
    
    local StatsEnc1 = "None"
    local StatsEnc2 = "None"

    local PlayerData = ReplionClient:WaitReplion("Data")
    if not PlayerData then return StatsEnc1, StatsEnc2 end

    local equippedItems = PlayerData:Get("EquippedItems")
    if not equippedItems or not equippedItems[1] then return StatsEnc1, StatsEnc2 end
    local equippedUUID = equippedItems[1]

    local inventory = PlayerData:Get("Inventory")
    if not (inventory and inventory["Fishing Rods"]) then return StatsEnc1, StatsEnc2 end

    local equippedItemObject = nil
    for _, item in ipairs(inventory["Fishing Rods"]) do
        if item.UUID == equippedUUID then
            equippedItemObject = item
            break
        end
    end

    if equippedItemObject and equippedItemObject.Metadata then
        if equippedItemObject.Metadata.EnchantId then
            local enchant1 = ItemUtility:GetEnchantData(equippedItemObject.Metadata.EnchantId)
            if enchant1 and enchant1.Data then
                StatsEnc1 = enchant1.Data.Name
            end
        end
        
        if equippedItemObject.Metadata.EnchantId2 then
            local enchant2 = ItemUtility:GetEnchantData(equippedItemObject.Metadata.EnchantId2)
            if enchant2 and enchant2.Data then
                StatsEnc2 = enchant2.Data.Name
            end
        end

    end
    
    return StatsEnc1, StatsEnc2
end

function UpdateApiData(formatplaytime, latestCaught)
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
    
    -- 1. Ambil data Coins dari Replion
    local currentCoins = 0
    if PlayerData then
        currentCoins = PlayerData:Get("Coins") or 0
    end

    -- 2. Ambil data Enchant (Sesuai Versi Terbaik)
    local enc1, enc2 = GetCurrentRodEnchant()

    -- 3. Ambil data dari Leaderstats & Attributes
    local inventoryData = GatherInventoryData()
    local leaderstats = player:FindFirstChild("leaderstats")
    local playerAttributes = player:GetAttributes()

    -- 4. Susun Struktur playerStats sesuai catatan
    local playerStats = {
        caught = leaderstats and leaderstats:FindFirstChild("Caught") and leaderstats.Caught.Value or 0,
        rarest = leaderstats and leaderstats:FindFirstChild("Rarest Fish") and leaderstats["Rarest Fish"].Value or 0,
        coins = currentCoins,
        location = playerAttributes["LocationName"] or "Unknown",
        rod = {
            name = playerAttributes["FishingRod"] or "N/A",
            enchantSlot1 = enc1,
            enchantSlot2 = enc2
        }
    }

    -- 5. Susun Payload Akhir
    local payload = {
        username = player.Name,
        displayName = player.DisplayName,
        userId = player.UserId,
        playerStats = playerStats,
        lastUpdate = os.time(),
        lastCaught = latestCaught,
        playtime = formatplaytime,
        inventory = inventoryData,
        hasOnline = true
    }
    
    local jsonPayload = HttpService:JSONEncode(payload)
    local requestData = {
        Url = DataAPI,
        Method = "POST",
        Headers = {
            ["Content-Type"] = "application/json", 
            ["X-Access-Key"] = accessKey
        },
        Body = jsonPayload
    }

    local success, response = pcall(function() return requestFunc(requestData) end)
    if not success then
        print("Gagal kirim data: " .. tostring(response))
    end
end
