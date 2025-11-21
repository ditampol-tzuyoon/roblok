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
    -- [DIUBAH] Inisialisasi 4 kategori baru
    local result = { Fish={}, Rods={}, Bobbers={}, Other={} }
    local hitungan = { Fish={}, Rods={}, Bobbers={}, Other={} }
    
    local ReplicatedStorage = game:GetService("ReplicatedStorage")
    local ItemUtility = require(ReplicatedStorage.Shared.ItemUtility)
    local ReplionClient = require(ReplicatedStorage.Packages.Replion).Client

    local PlayerData = ReplionClient:WaitReplion("Data")
    if not PlayerData then 
        return result
    end

    local inventory = PlayerData:Get("Inventory")
    if not (inventory and (inventory.Items or inventory["Fishing Rods"] or inventory.Baits)) then 
        return result
    end

    local RarityMap = {
        [1] = "Common", [2] = "Uncommon", [3] = "Rare",
        [4] = "Epic", [5] = "Legendary", [6] = "Mythic", [7] = "Secret",
    }

    -- Fungsi helper untuk menghitung harga (dari kode Anda sebelumnya)
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

                -- [DIUBAH] Hanya 'Fish' yang masuk ke kategori Fish
                if ItemType == "Fish" then
                    
                    if fullData.Probability and fullData.Probability.Chance then
                        ItemRare = GetRarityFromProbability(fullData.Probability.Chance)
                    end
                    if not ItemRare then
                        ItemRare = RarityMap[fullData.Data.Tier] or "Unknown"
                    end

                    -- 1. Dapatkan data mentah
                    local weight = (itemData.Metadata and itemData.Metadata.Weight) or 0
                    local mutation_str = (itemData.Metadata and itemData.Metadata.VariantId) or nil
                    local is_shiny = (itemData.Metadata and itemData.Metadata.Shiny) or false
                    
                    -- 2. Bangun tabel 'variant' dan 'mutation'
                    local variant_table = {}
                    if is_shiny then
                        table.insert(variant_table, "Shiny")
                    end
                    
                    local mutation_table = {}
                    if mutation_str then
                        table.insert(mutation_table, tostring(mutation_str))
                    end

                    -- 3. Hitung harga dinamis
                    local finalPrice = CalculateFishPrice(itemData, fullData)

                    -- 4. Buat objek detail yang baru
                    local details_object = {
                        weight = weight,
                        variant = variant_table,
                        mutation = mutation_table,
                        price = finalPrice 
                    }
                    
                    -- 5. Inisialisasi hitungan jika belum ada
                    if not hitungan.Fish[ItemName] then
                        local basePrice = fullData.SellPrice or 0
                        hitungan.Fish[ItemName] = { 
                            icon = ItemIcon, 
                            count = 0, 
                            rarity = ItemRare, 
                            price = basePrice, -- Harga dasar
                            detail = {} 
                        }
                    end

                    -- 6. Masukkan objek baru ke array detail
                    table.insert(hitungan.Fish[ItemName].detail, details_object) 
                    hitungan.Fish[ItemName].count = hitungan.Fish[ItemName].count + 1
                
                -- [DIUBAH] 'Enchant Stones' dan 'Gears' masuk ke 'Other'
                elseif ItemType == "Enchant Stones" or ItemType == "Gears" then 
                    ItemRare = RarityMap[fullData.Data.Tier] or "Unknown"
                    
                    if not hitungan.Other[ItemName] then
                        local basePrice = fullData.SellPrice or 0
                        hitungan.Other[ItemName] = { 
                            icon = ItemIcon, 
                            count = 0, 
                            rarity = ItemRare, 
                            price = basePrice,
                            isStone = (ItemType == "Enchant Stones"), -- Tandai jika ini stone
                            detail = {} 
                        }
                    end
                    
                    if ItemType == "Gears" then
                        table.insert(hitungan.Other[ItemName].detail, ItemRare)
                    end
                    -- Hanya tambahkan count, 'detail' tidak diproses untuk 'Other'
                    hitungan.Other[ItemName].count = hitungan.Other[ItemName].count + 1
                end
            end
        end
    end

    -- [DIUBAH] Loop untuk Fishing Rods (Masuk ke hitungan.Rods)
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

    -- [DIUBAH] Loop untuk Baits (Masuk ke hitungan.Bobbers)
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

    -- Mengurutkan tabel 'Fish' berdasarkan 'weight'
    for _, data in pairs(hitungan.Fish) do
        table.sort(data.detail, function(a, b)
            return (a.weight or 0) > (b.weight or 0)
        end)
    end


    -- [DIUBAH] Masukkan semua 4 kategori ke hasil akhir
    for kategori, dataHitungan in pairs(hitungan) do
        for nama, data in pairs(dataHitungan) do
            
            if kategori == "Fish" or kategori == "Rods" or kategori == "Bobbers" or kategori == "Other" then
                table.insert(result[kategori], {
                    name = nama,
                    icon = data.icon,
                    count = data.count,
                    rarity = data.rarity,
                    price = data.price,
                    isStone = data.isStone or false, -- Teruskan flag isStone
                    detail = data.detail
                })
            else
                table.insert(result[kategori], { name = nama, count = data })
            end
        end
    end
    return result
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
    local currentCoins = 0
    if PlayerData then
        currentCoins = PlayerData:Get("Coins") or 0
    end
    
    local inventoryData = GatherInventoryData()
    local leaderstats = player:WaitForChild("leaderstats")
    local rarestStat = leaderstats and leaderstats:FindFirstChild("Rarest Fish")

    local payload = {
        username = player.Name,
        displayName = player.DisplayName,
        userId = player.UserId,
        caught = leaderstats and leaderstats:FindFirstChild("Caught") and leaderstats.Caught.Value or 0,
        rarest = rarestStat and rarestStat.Value or 0,
        coins = currentCoins, 
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
        Headers = {["Content-Type"] = "application/json", ["X-Access-Key"] = accessKey},
        Body = jsonPayload
    }

    local success, response = pcall(function() return requestFunc(requestData) end)
    if not success then
        print("Gagal kirim data: " .. tostring(response))
    end
end
