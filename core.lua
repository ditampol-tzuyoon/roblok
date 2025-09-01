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
    apiLoopActive=state;
    if state==true then 
        if not (DataAPI and DataAPI:find("http")) or accessKey=="" then
            print(DataAPI)
            print(accessKey)
            print(getgenv().key)
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
