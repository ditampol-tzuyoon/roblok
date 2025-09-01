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
