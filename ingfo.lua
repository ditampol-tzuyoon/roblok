--[[
    Skrip Gabungan Final (dengan Tombol Unload)
]]

-- ===============================================================
-- [[ 1. KONFIGURASI (HANYA EDIT BAGIAN INI) ]]
-- ===============================================================

local petYangDihitung = {
    {Name = "Corrupted Kitsune", Emoji = "<:CKitsune:1400626952146260050>"}
}

local eggYangDihitung = {
    {Name = "Bug Egg", Emoji = "<:bug_egg:1397995993248694489>"},
    {Name = "Mythical Egg", Emoji = "<:mythical_egg:1398058696050737303>"},
    {Name = "Zen Egg", Emoji = "🥚"},
    {Name = "Common Summer Egg", Emoji = "☀️"},
    {Name = "Paradise Egg", Emoji = "<:paradise_egg:1398058596239151165>"}
}

-- ===============================================================
-- [[ BAGIAN UTAMA SKRIP ]]
-- ===============================================================

local Rayfield = loadstring(game:HttpGet('https://sirius.menu/rayfield'))()
local HttpService = game:GetService("HttpService")

local Window = Rayfield:CreateWindow({
   Name = "Skrip Laporan | Dibuat oleh Erine",
   LoadingTitle = "Memuat Antarmuka...",
   LoadingSubtitle = "oleh Erine",
   Size = UDim2.new(0, 550, 0, 500), -- Ukuran disesuaikan untuk tombol baru
   Center = true
})

local MainTab = Window:CreateTab("Webhook", nil)
MainTab:CreateSection("Pengaturan Webhook")

function FormatNumber(number)
    local formatted = tostring(math.floor(number))
    local k = ""
    while formatted:len() > 3 do
        k = "." .. formatted:sub(-3) .. k
        formatted = formatted:sub(1, -4)
    end
    return formatted .. k
end

local webhookURL = ""
local manualMessageID = ""
local webhookMessageID = nil
local editURL = ""
local webhookLoopActive = false
local startTimeUnix = nil

function GatherData()
    local data = {}
    local player = game:GetService("Players").LocalPlayer
    if not player then return nil end
    local leaderstats = player:WaitForChild("leaderstats")
    data.Username = player.Name
    data.DisplayName = player.DisplayName
    data.UserId = player.UserId
    data.Sheckles = leaderstats and leaderstats:FindFirstChild("Sheckles") and FormatNumber(leaderstats.Sheckles.Value) or "N/A"
    local backpack = player:FindFirstChildOfClass("Backpack")
    if not backpack then 
        data.Pets = "Backpack tidak ditemukan."
        data.Eggs = "Backpack tidak ditemukan."
        return data 
    end
    local daftarTargetPet, daftarTargetEgg = {}, {}
    for _, pet in ipairs(petYangDihitung) do daftarTargetPet[pet.Name] = pet.Emoji end
    for _, egg in ipairs(eggYangDihitung) do daftarTargetEgg[egg.Name] = egg.Emoji end
    local hitunganPet, hitunganEgg = {}, {}
    for _, item in ipairs(backpack:GetChildren()) do
        if item:IsA("Tool") then
            local itemType = item:GetAttribute("b")
            if itemType == "l" then
                local namaDasar = string.gsub(item.Name, "%s*%[.*", "")
                if daftarTargetPet[namaDasar] then
                    hitunganPet[namaDasar] = {Count = (hitunganPet[namaDasar] and hitunganPet[namaDasar].Count or 0) + 1, Emoji = daftarTargetPet[namaDasar]}
                end
            elseif itemType == "c" then
                local namaLengkap = item.Name
                local namaDasar = string.gsub(namaLengkap, "%s*x%d+$", "")
                if daftarTargetEgg[namaDasar] then
                    local jumlah = tonumber(string.match(namaLengkap, "x(%d+)$")) or 1
                    hitunganEgg[namaDasar] = {Count = (hitunganEgg[namaDasar] and hitunganEgg[namaDasar].Count or 0) + jumlah, Emoji = daftarTargetEgg[namaDasar]}
                end
            end
        end
    end
    data.Pets = ""
    if next(hitunganPet) then
        for nama, info in pairs(hitunganPet) do data.Pets = data.Pets .. info.Emoji .. " " .. nama .. " x" .. info.Count .. "\n" end
    else
        data.Pets = "Tidak ada pet dari daftar."
    end
    data.Eggs = ""
    if next(hitunganEgg) then
        for nama, info in pairs(hitunganEgg) do data.Eggs = data.Eggs .. info.Emoji .. " " .. nama .. " x" .. info.Count .. "\n" end
    else
        data.Eggs = "Tidak ada egg dari daftar."
    end
    return data
end

function SendOrEditWebhook()
    local requestFunc = http_request or request or syn.request
    if not requestFunc then
        warn("Error: Fungsi http request tidak ditemukan.")
        webhookLoopActive = false
        return
    end
    
    local data = GatherData()
    if not data then
        warn("Gagal mengambil data pemain.")
        return
    end

    local description = "🕒 **Laporan dimulai:** <t:" .. startTimeUnix .. ":f>\n🕒 **Diperbarui:** <t:" .. os.time() .. ":R>"
    
    local embed = {
        title = "Script by ERINE",
        description = description,
        color = tonumber("0x2ECC71"),
        fields = {
            {name = "--- Info ---", value = "👤 " .. string.upper(data.DisplayName) .. " **[" .. data.Username .. "]**\n💰 " .. data.Sheckles, inline = false},
            {name = "--- Pets ---", value = data.Pets, inline = true},
            {name = "--- Eggs ---", value = data.Eggs, inline = true}
        },
        footer = {text = "Script by Erine"},
        timestamp = os.date("!%Y-%m-%dT%H:%M:%S.000Z")
    }
    
    if data.UserId then
        embed.thumbnail = {url = "https://tr.rbxcdn.com/30DAY-Avatar-15DAFEAFE18C7F64EA8F7E3D5DD65A92-Png/352/352/Avatar/Webp/noFilter"}
    end
    
    local payload = {username = "Laporan Bot", embeds = {embed}}
    local jsonPayload = HttpService:JSONEncode(payload)

    if not webhookMessageID then
        local success, response = pcall(function()
            return requestFunc({Url = webhookURL, Method = "POST", Headers = {["Content-Type"] = "application/json"}, Body = jsonPayload})
        end)
        if success and response and response.Body then
            local decodeSuccess, responseBody = pcall(HttpService.JSONDecode, HttpService, response.Body)
            if decodeSuccess and responseBody and responseBody.id then
                webhookMessageID = responseBody.id
                editURL = webhookURL .. "/messages/" .. webhookMessageID
                warn("Berhasil mendapatkan Message ID: " .. webhookMessageID)
            else
                warn("Gagal parse JSON dari Discord. Respons mentah: " .. response.Body)
            end
        elseif not success then
             warn("Terjadi error saat mengirim webhook: " .. tostring(response))
        end
    else
        pcall(function()
            requestFunc({Url = editURL, Method = "PATCH", Headers = {["Content-Type"] = "application/json"}, Body = jsonPayload})
        end)
    end
end

function WebhookLoop()
    while webhookLoopActive do
        if webhookURL and string.find(webhookURL, "https://discord.com/api/webhooks") then
            SendOrEditWebhook()
            if webhookLoopActive then
                warn("Laporan terkirim/diperbarui. Update selanjutnya dalam 60 detik.")
                task.wait(30)
            end
        else
            warn("URL Webhook tidak valid. Loop dijeda.")
            webhookLoopActive = false
        end
    end
end

MainTab:CreateInput({Name = "URL Webhook Discord", PlaceholderText = "Tempel URL webhook Anda di sini", Callback = function(text) webhookURL = text end})
MainTab:CreateInput({Name = "Message ID (Opsional)", PlaceholderText = "Isi jika ingin langsung edit pesan yang ada", Callback = function(text) manualMessageID = text end})
MainTab:CreateToggle({Name = "Aktifkan Laporan Otomatis", Description = "Mengirim dan memperbarui laporan ke Discord setiap 1 menit.", Callback = function(state)
    webhookLoopActive = state
    if state == true then
        startTimeUnix = os.time()
        if manualMessageID and manualMessageID ~= "" then
            webhookMessageID = manualMessageID
            editURL = webhookURL .. "/messages/" .. webhookMessageID
            warn("Mode Edit Langsung diaktifkan.")
        else
            webhookMessageID = nil
            warn("Mode Normal diaktifkan.")
        end
        task.spawn(WebhookLoop)
    else
        warn("Loop laporan webhook dinonaktifkan.")
    end
end, Default = false})

-- [[ BAGIAN BARU - TOMBOL UNLOAD ]]
MainTab:CreateSection("Pengaturan Skrip")
MainTab:CreateButton({
   Name = "Close & Unload Script",
   Callback = function()
      -- 1. Matikan semua loop yang sedang berjalan
      webhookLoopActive = false
      warn("Semua proses latar belakang dihentikan.")
      
      -- 2. Hancurkan GUI dan unload library Rayfield
      Rayfield:Unload()
   end,
})
