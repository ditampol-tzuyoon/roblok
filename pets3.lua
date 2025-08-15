--[[
    Script: Pet Mutation Bot (Logika Final & Stabil)
    Pembaruan:
    - Mencari tool di backpack berdasarkan UUID pet tua yang di-unequip untuk 100% akurasi.
    - Menambahkan jeda 5 detik setelah unequip untuk stabilitas.
]]

--//================================\\ FUNGSI GUI //================================//--
local function CreateGUI()
    if game:GetService("CoreGui"):FindFirstChild("PetMutationBotGUI") then
        game:GetService("CoreGui"):FindFirstChild("PetMutationBotGUI"):Destroy()
    end
    local screenGui = Instance.new("ScreenGui")
    screenGui.Name = "PetMutationBotGUI"; screenGui.ResetOnSpawn = false; screenGui.Parent = game:GetService("CoreGui")
    local mainFrame = Instance.new("Frame")
    mainFrame.Name = "MainFrame"; mainFrame.Size = UDim2.new(0, 300, 0, 180); mainFrame.Position = UDim2.new(0.5, -150, 0.5, -90); mainFrame.BackgroundColor3 = Color3.fromRGB(35, 35, 45); mainFrame.BorderColor3 = Color3.fromRGB(85, 85, 125); mainFrame.BorderSizePixel = 2; mainFrame.Active = true; mainFrame.Draggable = true; mainFrame.Parent = screenGui
    local titleLabel = Instance.new("TextLabel")
    titleLabel.Name = "TitleLabel"; titleLabel.Size = UDim2.new(1, 0, 0, 30); titleLabel.BackgroundColor3 = Color3.fromRGB(55, 55, 75); titleLabel.BorderColor3 = Color3.fromRGB(85, 85, 125); titleLabel.BorderSizePixel = 2; titleLabel.Text = "Pet Mutation Bot"; titleLabel.Font = Enum.Font.SourceSansBold; titleLabel.TextColor3 = Color3.fromRGB(255, 255, 255); titleLabel.TextSize = 18; titleLabel.Parent = mainFrame
    local function createStatusLabel(text, positionY)
        local label = Instance.new("TextLabel")
        label.Size = UDim2.new(1, -20, 0, 20); label.Position = UDim2.new(0, 10, 0, positionY); label.BackgroundTransparency = 1; label.Text = text; label.Font = Enum.Font.SourceSans; label.TextColor3 = Color3.fromRGB(220, 220, 220); label.TextSize = 14; label.TextXAlignment = Enum.TextXAlignment.Left; label.Parent = mainFrame
        return label
    end
    local timerStatus = createStatusLabel("Timer Mesin: Menunggu...", 40)
    local targetPetStatus = createStatusLabel("Target Pet: Tidak ada", 65)
    local cyclesStatus = createStatusLabel("Siklus Selesai: 0", 90)
    local toggleButton = Instance.new("TextButton")
    toggleButton.Name = "ToggleButton"; toggleButton.Size = UDim2.new(1, -20, 0, 30); toggleButton.Position = UDim2.new(0, 10, 0, 130); toggleButton.BackgroundColor3 = Color3.fromRGB(0, 180, 120); toggleButton.BorderColor3 = Color3.fromRGB(255, 255, 255); toggleButton.BorderSizePixel = 1; toggleButton.Text = "Aktifkan Bot"; toggleButton.Font = Enum.Font.SourceSansBold; toggleButton.TextColor3 = Color3.fromRGB(255, 255, 255); toggleButton.TextSize = 16; toggleButton.Parent = mainFrame
    return {gui = screenGui, timerLabel = timerStatus, targetLabel = targetPetStatus, cyclesLabel = cyclesStatus, button = toggleButton}
end
local GUI = CreateGUI()

--//================================\\ LOGIKA BOT //================================//--

local botActive, cyclesCompleted = false, 0
local PlayersService, ReplicatedStorage = game:GetService("Players"), game:GetService("ReplicatedStorage")
local player, playerGui, petMutationEvent, petsServiceEvent, petScrollingFrame, timerLabel, petModelLocation

function FindPetForMutation()
    for _, petFrame in ipairs(petScrollingFrame:GetChildren()) do
        if petFrame:IsA("Frame") and petFrame:FindFirstChild("Main") then
            local petAgeLabel = petFrame.Main:FindFirstChild("PET_AGE")
            local petTypeLabel = petFrame.Main:FindFirstChild("PET_TYPE")
            if petAgeLabel and petTypeLabel then
                local cleanedAgeText = string.gsub(petAgeLabel.Text, "%D", "")
                local petAgeNum = tonumber(cleanedAgeText) or 0
                local petTypeText = petTypeLabel.Text:lower()
                if petAgeNum >= 50 and not string.find(petTypeText, "rainbow") and not string.find(petTypeText, "golden") then
                    return petFrame.Name
                end
            end
        end
    end
    return nil
end

-- Fungsi baru yang stabil: Mencari Tool di backpack berdasarkan UUID yang diberikan
function FindToolInBackpackByUUID(targetUUID)
    local backpack = player:FindFirstChildOfClass("Backpack")
    if not backpack then return nil end
    
    for _, item in ipairs(backpack:GetChildren()) do
        if item:IsA("Tool") then
            local petUUID = item:GetAttribute("PET_UUID")
            if petUUID and petUUID == targetUUID then
                return item -- Kembalikan Tool yang cocok
            end
        end
    end
    return nil
end

function FindNewlyClaimedPetUUID()
    task.wait(2)
    local backpack = player:FindFirstChildOfClass("Backpack")
    if not backpack then return nil end
    local allDiloPets = {}
    for _, item in ipairs(backpack:GetChildren()) do
        if item:IsA("Tool") and item:GetAttribute("b") == "l" and string.find(item.Name, "Dilophosaurus") then
            table.insert(allDiloPets, item)
        end
    end
    if #allDiloPets > 0 then
        local newestPet = allDiloPets[#allDiloPets]
        return newestPet:GetAttribute("PET_UUID")
    end
    return nil
end

function FindCorrectPart(parentModel)
    local attempts = 0
    while attempts < 20 do
        for _, child in ipairs(parentModel:GetChildren()) do
            if child.Name == "Part" and child:FindFirstChild("BillboardPart") then
                return child
            end
        end
        task.wait(1); attempts = attempts + 1
    end
    return nil
end

function LoadGameObjects()
    player = PlayersService.LocalPlayer; if not player then return false, "Pemain tidak ditemukan." end
    playerGui = player:WaitForChild("PlayerGui", 10); if not playerGui then return false, "PlayerGui tidak ditemukan." end
    local gameEvents = ReplicatedStorage:WaitForChild("GameEvents", 10); if not gameEvents then return false, "Folder 'GameEvents' tidak ditemukan." end
    petMutationEvent = gameEvents:WaitForChild("PetMutationMachineService_RE", 5)
    petsServiceEvent = gameEvents:WaitForChild("PetsService", 5)
    if not petMutationEvent or not petsServiceEvent then return false, "Salah satu RemoteEvent tidak ditemukan." end
    local activePetUI = playerGui:WaitForChild("ActivePetUI", 10); if not activePetUI then return false, "UI 'ActivePetUI' tidak ditemukan." end
    petScrollingFrame = activePetUI:WaitForChild("Frame", 5):WaitForChild("Main", 5):WaitForChild("PetDisplay", 5):WaitForChild("ScrollingFrame", 5)
    if not petScrollingFrame then return false, "Path ke 'PetScrollingFrame' tidak lengkap." end
    local npcs = workspace:WaitForChild("NPCS", 15); if not npcs then return false, "Folder 'NPCS' tidak ditemukan." end
    local mutationMachine = npcs:WaitForChild("PetMutationMachine", 15); if not mutationMachine then return false, "Mesin 'PetMutationMachine' tidak ditemukan." end
    local machineModel = mutationMachine:WaitForChild("Model", 10); if not machineModel then return false, "Path rusak di '...:WaitForChild(\"Model\")'." end
    local machinePart = FindCorrectPart(machineModel); if not machinePart then return false, "Gagal menemukan 'Part' yang berisi 'BillboardPart'." end
    local billboardPart = machinePart:WaitForChild("BillboardPart", 5); if not billboardPart then return false, "Path rusak di '...:WaitForChild(\"BillboardPart\")'." end
    local billboardGui = billboardPart:WaitForChild("BillboardGui", 5); if not billboardGui then return false, "Path rusak di '...:WaitForChild(\"BillboardGui\")'." end
    timerLabel = billboardGui:WaitForChild("TimerTextLabel", 5); if not timerLabel then return false, "Objek 'TimerTextLabel' tidak ditemukan." end
    petModelLocation = mutationMachine:WaitForChild("PetModelLocation", 10); if not petModelLocation then return false, "Lokasi model pet tidak ditemukan." end
    return true, "Semua objek berhasil dimuat."
end

--//================================\\ KONTROL UTAMA (ALUR STABIL) //==========================//--

local success, message = LoadGameObjects()
if not success then
    print("ERROR FATAL:", message)
    GUI.button.Text = "ERROR MEMUAT"; GUI.button.BackgroundColor3 = Color3.fromRGB(150, 0, 0); GUI.button.Active = false
else
    print("Bot berhasil dimuat. Siap dijalankan.")
    GUI.button.MouseButton1Click:Connect(function() botActive = not botActive if botActive then print("Bot diaktifkan.") GUI.button.Text = "Nonaktifkan Bot" GUI.button.BackgroundColor3 = Color3.fromRGB(220, 50, 50) else print("Bot dinonaktifkan.") GUI.button.Text = "Aktifkan Bot" GUI.button.BackgroundColor3 = Color3.fromRGB(0, 180, 120) end end)
    coroutine.wrap(function()
        while task.wait(1) do
            local timerText = timerLabel and timerLabel.Text or "N/A"
            local petTuaUUID = FindPetForMutation()
            
            GUI.timerLabel.Text="Timer Mesin: "..timerText
            GUI.targetLabel.Text="Target Pet: "..(petTuaUUID or "Tidak ada")
            GUI.cyclesLabel.Text="Siklus Selesai: "..cyclesCompleted
            
            if botActive then
                if petTuaUUID and timerText:upper() == "READY" then
                    botActive = false
                    print("Kondisi terpenuhi. Memulai siklus...")
                    
                    if petModelLocation:FindFirstChild("Dilophosaurus") then
                        print("Mengklaim pet BARU dari mesin...")
                        petMutationEvent:FireServer("ClaimMutatedPet")
                        task.wait(20)
                    end
                    
                    print("Mengambil pet TUA dari farm (Unequip)...")
                    petsServiceEvent:FireServer("UnequipPet", petTuaUUID)
                    
                    -- Beri jeda 5 detik agar pet masuk ke backpack dengan stabil
                    print("Menunggu 5 detik untuk stabilitas backpack...")
                    task.wait(5)

                    print("Mencari Tool pet TUA di backpack dengan UUID: " .. petTuaUUID)
                    local petTuaTool = FindToolInBackpackByUUID(petTuaUUID)
                    
                    if petTuaTool then
                        local humanoid = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
                        if humanoid then
                            print("Memegang pet TUA: " .. petTuaTool.Name)
                            humanoid:EquipTool(petTuaTool)
                            task.wait(2)
                            
                            print("Memasukkan pet TUA ke mesin...")
                            petMutationEvent:FireServer("SubmitHeldPet")
                            task.wait(1)
                            petMutationEvent:FireServer("StartMachine")
                            task.wait(3)
                            
                            print("Mencari pet BARU di backpack untuk ditaruh ke farm...")
                            local petBaruUUID = FindNewlyClaimedPetUUID()
                            if petBaruUUID then
                                print("Menempatkan pet BARU (UUID: "..petBaruUUID..") ke farm...")
                                petsServiceEvent:FireServer("EquipPet", petBaruUUID)
                            else
                                warn("Tidak bisa menemukan UUID pet baru di backpack.")
                            end
                            
                            cyclesCompleted = cyclesCompleted + 1
                            print("Siklus selesai.")
                        else
                             warn("Humanoid tidak ditemukan.")
                        end
                    else
                        warn("Tidak dapat menemukan Tool pet TUA di backpack setelah di-unequip.")
                    end

                    task.wait(5)
                    botActive = true
                end
            end
        end
    end)()
end
