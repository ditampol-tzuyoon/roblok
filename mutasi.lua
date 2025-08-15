--[[
    Script: Pet Mutation Bot
    Description: Mengotomatiskan proses mutasi pet dengan mengambil pet yang sudah tua dari peternakan,
                 meletakkannya di mesin mutasi, dan menggantinya dengan pet baru dari inventaris.
]]

--//================================\\ SERVICES //================================//--
local PlayersService = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

--//================================\\ VARIABLES //===============================//--
-- Player & GUI
local player = PlayersService.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

-- Remote Events
local petMutationEvent = ReplicatedStorage:WaitForChild("GameEvents"):WaitForChild("PetMutationMachineService_RE")
local petsServiceEvent = ReplicatedStorage:WaitForChild("GameEvents"):WaitForChild("PetsService")

-- Game Objects
local petScrollingFrame = playerGui:WaitForChild("ActivePetUI"):WaitForChild("Frame"):WaitForChild("Main"):WaitForChild("PetDisplay"):WaitForChild("ScrollingFrame")
local mutationMachine = Workspace:WaitForChild("NPCS"):WaitForChild("PetMutationMachine")
local timerLabel = mutationMachine:WaitForChild("Model"):WaitForChild("Part"):WaitForChild("BillboardPart"):WaitForChild("BillboardGui"):WaitForChild("TimerTextLabel")
local petModelLocation = mutationMachine:WaitForChild("PetModelLocation")

--//================================\\ FUNCTIONS //===============================//--

--[[
    Fungsi untuk mencari pet yang siap untuk mutasi (Age 50+ dan bukan tipe Rainbow/Golden).
    @return (string | nil) - Mengembalikan UUID pet jika ditemukan, jika tidak nil.
]]
function FindPetForMutation()
    for _, petFrame in pairs(petScrollingFrame:GetChildren()) do
        -- Pastikan objek adalah Frame dan memiliki struktur yang benar
        if petFrame:IsA("Frame") and petFrame:FindFirstChild("Main") then
            local petAgeLabel = petFrame.Main:FindFirstChild("PET_AGE")
            local petTypeLabel = petFrame.Main:FindFirstChild("PET_TYPE")

            if petAgeLabel and petTypeLabel then
                local petAge = tonumber(petAgeLabel.Text) or 0
                local petType = petTypeLabel.Text:lower() -- Gunakan lower() untuk pencocokan yang tidak case-sensitive

                -- Kondisi: Umur 50+ DAN tipe tidak mengandung "rainbow" atau "golden"
                if petAge >= 50 and not string.find(petType, "rainbow") and not string.find(petType, "golden") then
                    print("Pet yang memenuhi syarat ditemukan:", petFrame.Name, "dengan Umur:", petAge)
                    return petFrame.Name -- Nama frame adalah UUID pet
                end
            end
        end
    end
    return nil -- Tidak ada pet yang memenuhi syarat
end

--[[
    Fungsi untuk mencari pet "Dilophosaurus" di dalam inventaris pemain untuk ditempatkan di peternakan.
    Catatan: Pengecekan umur di bawah 50 tidak dapat dilakukan karena data umur tidak tersedia pada item di Backpack.
    @return (string | nil) - Mengembalikan UUID pet jika ditemukan, jika tidak nil.
]]
function FindPetToPlaceOnFarm()
    local backpack = player:FindFirstChildOfClass("Backpack")
    if not backpack then
        warn("Backpack pemain tidak ditemukan.")
        return nil
    end

    for _, item in ipairs(backpack:GetChildren()) do
        if item:IsA("Tool") and item:GetAttribute("b") == "l" and string.find(item.Name, "Dilophosaurus") then
            local petUUID = item:GetAttribute("PET_UUID")
            if petUUID then
                print("Pet 'Dilophosaurus' ditemukan di inventaris untuk ditempatkan di peternakan. UUID:", petUUID)
                return petUUID
            end
        end
    end
    print("Tidak ada 'Dilophosaurus' yang cocok di inventaris.")
    return nil
end

--[[
    Fungsi untuk mengambil pet yang sudah selesai dari mesin mutasi.
]]
function TakePetFromMachine()
    print("Mengambil pet yang sudah selesai dari mesin...")
    local args = {"ClaimMutatedPet"}
    petMutationEvent:FireServer(unpack(args))
end

--[[
    Fungsi untuk melepaskan pet dari peternakan (mengambilnya).
    @param petUUID (string) - UUID dari pet yang akan dilepaskan.
]]
function TakePetFromFarm(petUUID)
    print("Mengambil pet target dari peternakan. UUID:", petUUID)
    local args = {"UnequipPet", petUUID}
    petsServiceEvent:FireServer(unpack(args))
end

--[[
    Fungsi untuk menempatkan pet baru ke peternakan.
]]
function PlacePetOnFarm()
    local petToEquipUUID = FindPetToPlaceOnFarm()
    if petToEquipUUID then
        print("Menempatkan pet baru ke peternakan. UUID:", petToEquipUUID)
        local args = {"EquipPet", petToEquipUUID}
        petsServiceEvent:FireServer(unpack(args))
    else
        warn("Gagal menempatkan pet baru, tidak ada yang ditemukan di inventaris.")
    end
end

--[[
    Fungsi untuk memasukkan pet yang sedang dipegang ke mesin dan memulai prosesnya.
]]
function PutPetIntoMachine()
    print("Memasukkan pet ke mesin mutasi...")
    -- Langkah 1: Masukkan pet
    local submitArgs = {"SubmitHeldPet"}
    petMutationEvent:FireServer(unpack(submitArgs))
    task.wait(1) -- Jeda singkat antar event untuk stabilitas

    -- Langkah 2: Mulai mesin
    print("Memulai mesin mutasi...")
    local startArgs = {"StartMachine"}
    petMutationEvent:FireServer(unpack(startArgs))
end

--//================================\\ MAIN LOOP //===============================//--

print("Script Otomatisasi Mutasi Pet Dimulai.")

while true do
    task.wait(5) -- Jeda utama antar siklus

    -- Cek kondisi utama: Timer mesin dan keberadaan pet yang siap mutasi
    local currentTimer = tonumber(timerLabel.Text) or -1
    local targetPetUUID = FindPetForMutation()

    if targetPetUUID and currentTimer == 0 then
        print("--- SIKLUS MUTASI BARU DIMULAI ---")

        -- Cek apakah ada pet yang sudah jadi di mesin
        if petModelLocation:FindFirstChild("Dilophosaurus") then
            TakePetFromMachine()
            task.wait(3)
        end

        -- Ambil pet target dari peternakan
        TakePetFromFarm(targetPetUUID)
        task.wait(3)

        -- Tempatkan pet baru ke peternakan dari inventaris
        PlacePetOnFarm()
        task.wait(3)

        -- Masukkan pet yang tadi diambil ke mesin dan mulai
        PutPetIntoMachine()
        print("--- SIKLUS MUTASI SELESAI ---")
    else
        -- Pesan status jika kondisi tidak terpenuhi
        if not targetPetUUID then
            print("Menunggu pet mencapai umur 50+...")
        end
        if currentTimer ~= 0 then
            print("Menunggu timer mesin mutasi selesai. Sisa waktu:", currentTimer)
        end
    end
end
