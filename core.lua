function GatherInventoryData()
    local inventory = { Pets={}, Eggs={}, Fruits={}, Seeds={}, Gears={}, Packs={}, Foods={}, Unknown={} }
    local backpack = player and player:FindFirstChildOfClass("Backpack")
    if not backpack then return inventory end
    local hitungan = { Pets={}, Eggs={}, Fruits={}, Seeds={}, Gears={}, Packs={}, Foods={}, Unknown={} }
    local gearAttributes = {b=true,d=true,f=true,o=true,q=true,r=true,e=true,v=true,s=true,k=true,m=true,h=true}
    for _, item in ipairs(backpack:GetChildren()) do
        if item:IsA("Tool") then
            local itemName, itemType = item.Name, item:GetAttribute("b")
            if itemType == "l" then
                local namaDasar = itemName:gsub("%s*%[.*", "")
                if namaDasar ~= "" then
                    if not hitungan.Pets[namaDasar] then
                        hitungan.Pets[namaDasar] = { count = 0, detail = {} }
                    end
                    local weight = itemName:match("%[([%d%.]+ KG)%]") or "0 KG"
                    local age = itemName:match("%[(Age %d+)%]") or "Age N/A"
                    table.insert(hitungan.Pets[namaDasar].detail, weight .. " | " .. age)
                    hitungan.Pets[namaDasar].count = hitungan.Pets[namaDasar].count + 1
                end
            elseif itemType == "j" then
                local namaDasar = item:GetAttribute("f")
                if namaDasar ~= "" then
                    if not hitungan.Fruits[namaDasar] then
                        hitungan.Fruits[namaDasar] = { count = 0, detail = {} }
                    end
                    local weight = itemName:match("%[([%d%.]+kg)%]") or "0kg"
                    table.insert(hitungan.Fruits[namaDasar].detail, weight)
                    hitungan.Fruits[namaDasar].count = hitungan.Fruits[namaDasar].count + 1
                end
            elseif itemType == "c" then
                local namaDasar = itemName:gsub("%s*x%d+$", "")
                if namaDasar ~= "" then
                    local jumlah = tonumber(itemName:match("x(%d+)$")) or 1
                    hitungan.Eggs[namaDasar] = (hitungan.Eggs[namaDasar] or 0) + jumlah
                end
            elseif itemType == "n" then
                local namaDasar = itemName:gsub("%s*%[X%d+]", "")
                if namaDasar ~= "" then
                    local jumlah = tonumber(itemName:match("%[X(%d+)]")) or 1
                    hitungan.Seeds[namaDasar] = (hitungan.Seeds[namaDasar] or 0) + jumlah
                end
            elseif itemType == "a" then
                local namaDasar = itemName:gsub("%s*%[X%d+]", "")
                if namaDasar ~= "" then
                    local jumlah = tonumber(itemName:match("%[X(%d+)]")) or 1
                    hitungan.Packs[namaDasar] = (hitungan.Packs[namaDasar] or 0) + jumlah
                end
            elseif itemType == "u" then
                local namaDasar = itemName:gsub("%s*%[X%d+]", "")
                if namaDasar ~= "" then
                    local jumlah = tonumber(itemName:match("%[X(%d+)]")) or 1
                    local words = {}
                    for word in namaDasar:gmatch("%S+") do table.insert(words, word) end
                    local lastWord = ""
                    for i = #words, 1, -1 do
                        if not words[i]:match("^%[.-kg%]$") then lastWord = words[i]; break end
                    end
                    local shortName = (words[1] or "") .. " " .. (lastWord ~= "" and lastWord or words[#words])
                    hitungan.Foods[shortName] = (hitungan.Foods[shortName] or 0) + jumlah
                end
            elseif gearAttributes[itemType] then
                local namaDasar, jumlah = itemName, 1
                local nameMatch, countMatch = itemName:match("^(.-)%s*x(%d+)$")
                if nameMatch and countMatch then
                    namaDasar, jumlah = nameMatch, tonumber(countMatch)
                else
                    namaDasar = itemName:gsub("%s*%[.*", "")
                end
                if namaDasar ~= "" then hitungan.Gears[namaDasar] = (hitungan.Gears[namaDasar] or 0) + jumlah end
            else
                local namaDasar = itemName:gsub("%s*%[.*", "")
                local jumlah = tonumber(itemName:match("x(%d+)$")) or 1
                if namaDasar ~= "" then
                    local key = namaDasar .. "|" .. tostring(itemType)
                    hitungan.Unknown[key] = (hitungan.Unknown[key] or 0) + jumlah
                end
            end
        end
    end
    for _, data in pairs(hitungan.Pets) do
        table.sort(data.detail, function(a, b)
            local weightA = tonumber(a:match("([%d%.]+) KG")) or 0
            local weightB = tonumber(b:match("([%d%.]+) KG")) or 0
            return weightA > weightB
        end)
    end
    for _, data in pairs(hitungan.Fruits) do
        table.sort(data.detail, function(a, b)
            local weightA = tonumber(a:match("([%d%.]+)kg")) or 0
            local weightB = tonumber(b:match("([%d%.]+)kg")) or 0
            return weightA > weightB
        end)
    end
    for kategori, dataHitungan in pairs(hitungan) do
        for nama, data in pairs(dataHitungan) do
            if kategori == "Pets" or kategori == "Fruits" then
                table.insert(inventory[kategori], {
                    name = nama,
                    count = data.count,
                    detail = data.detail
                })
            elseif kategori == "Unknown" then
                local itemName, itemType = nama:match("^(.-)|(.+)$")
                table.insert(inventory.Unknown, { name = itemName, type = itemType, count = data })
            else
                table.insert(inventory[kategori], { name = nama, count = data })
            end
        end
    end
    return inventory
end

function UpdateApiData(isOnline)
    local requestFunc = http_request or request or syn.request
    if not requestFunc then warn("Error: Fungsi http request tidak ditemukan."); apiLoopActive = false; return end
    if not player then return end
    local inventoryData = GatherInventoryData()
    local leaderstats = player:WaitForChild("leaderstats")
    local payload = {
        username = player.Name, displayName = player.DisplayName, userId = player.UserId,
        sheckles = leaderstats and leaderstats:FindFirstChild("Sheckles") and leaderstats.Sheckles.Value or 0,
        lastUpdate = os.time(), inventory = inventoryData, hasOnline = isOnline
    }
    local jsonPayload = HttpService:JSONEncode(payload)
    local requestData = {
        Url = DataAPI, Method = "POST",
        Headers = {["Content-Type"] = "application/json", ["X-Access-Key"] = accessKey},
        Body = jsonPayload
    }
    local success, response = pcall(function() return requestFunc(requestData) end)
    if not success then
        print("Gagal kirim data: " .. tostring(response))
    end
end

function ApiUpdateLoop()
    while apiLoopActive do
        if DataAPI and string.find(DataAPI, "http") then
            UpdateApiData(true)
            if apiLoopActive then task.wait(updateInterval) end
        else
            apiLoopActive = false
        end
    end
end

function RunningAPI(state)
    print(DataAPI)
    print(accessKey)
    print(getgenv().key)
    apiLoopActive=state;
    if state==true then 
        if not (DataAPI and DataAPI:find("http")) or accessKey=="" then
            warn("KONFIGURASI API/KEY TIDAK VALID.")
            apiLoopActive=false
            return
        end
        task.spawn(ApiUpdateLoop)
        warn("Laporan API dimulai.")
    else
        pcall(UpdateApiData, false)
        warn("Laporan API dihentikan.")
    end
    SaveSettings()
end
