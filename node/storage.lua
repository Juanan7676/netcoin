local storage = {}

component = require("component")
serial = require("serialization")
filesys = require("filesystem")
require("common")
storage.data = component.data
storage.disks = {}

if (storage.data==nil) then
    print("No data card present on device!")
end
local df = io.open("disks.txt","r")
local line = df:read()
local arr = explode(",",line)
storage.indexDisk = arr[2]
line = df:read()
arr = explode(",",line)
storage.utxoDisk = arr[2]
line = df:read()
while line ~= nil do
    arr = explode(",",line)
    storage.disks[arr[1]] = arr[2]
    line = df:read()
end

function storage.generateIndex()
    local file = io.open("/mnt/"..(storage.indexDisk).."/index.txt","w")
    for k=1,150000 do
        file:write("0000000000000000,00\n")
    end
    file:close()
end

function storage.loadIndex(uuid)
    
    file = io.open("/mnt/"..(storage.indexDisk).."/index.txt","r")
    num = hexMod(tohex(storage.data.sha256(uuid)),150000)
    file:seek("set",20*num)
    local data = file:read()
    local arr = explode(",",data)
    if arr[1]=="0000000000000000" then return nil end
    if arr[1]~=uuid then -- Solve conflict
        local aux = io.open("/mnt/"..(storage.indexDisk).."/conflicts/"..arr[1]..".txt","r")
        local line = aux:read()
        local ret = nil
        while line ~= nil do
            local tmp = explode(",",line)
            if tmp[1]==uuid then
                ret = line
                break
            end
            line = aux:read()
        end
        aux:close()
        return ret
    end
    file:close()
    return data
end

function storage.loadRawIndex(uuid)
    utxo = utxo or false
    file = io.open("/mnt/"..(storage.indexDisk).."/index.txt","r")
    
    local num = hexMod(tohex(storage.data.sha256(uuid)),150000)
    file:seek("set",20*num)
    local data = file:read()
    file:close()
    return data
end

function storage.saveIndex(uuid,disk)
    local i = storage.loadRawIndex(uuid)
    local arr = explode(",",i)
    if arr[1]~="0000000000000000" and arr[1]~=uuid then -- Solve conflict
        local file = io.open("/mnt/"..(storage.indexDisk).."/conflicts/"..arr[1]..".txt","a")
        file:write(uuid..","..disk.."\n")
        file:close()
    else
        local file = io.open("/mnt/"..(storage.indexDisk).."/index.txt","a")
        local num = hexMod(tohex(storage.data.sha256(uuid)),150000)
        file:seek("set",20*num)
    
        file:write(uuid..","..disk)
        file:close()
    end
end

function storage.loadBlock(uuid)
    local index = storage.loadIndex(uuid)
    if index==nil then return nil end
    local data = explode(",",index)
    local disk = storage.disks[data[2]]
    if disk==nil then return nil end
    local file = io.open("/mnt/"..disk.."/"..uuid..".txt","r")
    local block = serial.unserialize(file:read("*a"))
    file:close()
    return block
end

function storage.saveBlock(block)
    if storage.loadBlock(block.uuid) ~= nil then return end
    local data = serial.serialize(block)
    for k,d in pairs(storage.disks) do
        local hdd = component.proxy(component.get(d))
        if ( hdd.spaceTotal() - hdd.spaceUsed() >= data:len() ) then
            local file = io.open("/mnt/"..d.."/"..(block.uuid)..".txt","w")
            file:write(data)
            file:close()
            storage.saveIndex(block.uuid,k)
            return
        end
    end
    print("[!] All disks are full, i'm unable to save block id ".. block.uuid)
    return nil
end

function storage.tmpsaveutxo(uuid,buuid) storage.saveutxo(uuid,buuid,true) end
function storage.saveutxo(uuid, buuid, tmp)
    local prefix = ""
    if tmp==true then prefix="tmp" end

    local file = io.open("/mnt/"..(storage.utxoDisk).."/"..prefix.."utxo.txt","a")
    file:write(uuid..","..buuid.."\n")
    file:close()
end

function storage.tmpsavewalletutxo(uuid,buuid) storage.savewalletutxo(uuid,buuid,true) end
function storage.savewalletutxo(uuid, buuid, tmp)
    local prefix = ""
    if tmp==true then prefix="tmp" end

    local file = io.open("/mnt/"..(storage.utxoDisk).."/"..prefix.."walletutxo.txt","a")
    file:write(uuid..","..buuid.."\n")
    file:close()
end

function storage.tmpsaveremutxo(uuid,buuid) storage.saveremutxo(uuid,buuid,true) end
function storage.saveremutxo(uuid, buuid, tmp)
    local prefix = ""
    if tmp==true then prefix="tmp" end

    local file = io.open("/mnt/"..(storage.utxoDisk).."/"..prefix.."remutxo.txt","a")
    file:write(uuid..","..buuid.."\n")
    file:close()
end

function storage.tmpsavewalletremutxo(uuid,buuid) storage.savewalletremutxo(uuid,buuid,true) end
function storage.savewalletremutxo(uuid, buuid, tmp)
    local prefix = ""
    if tmp==true then prefix="tmp" end

    local file = io.open("/mnt/"..(storage.utxoDisk).."/"..prefix.."walletremutxo.txt","a")
    file:write(uuid..","..buuid.."\n")
    file:close()
end

function storage.tmputxopresent(uuid) storage.utxopresent(uuid,true) end
function storage.utxopresent(uuid, tmp)
    local prefix = ""
    if tmp==true then prefix="tmp" end

    local file = io.open("/mnt/"..(storage.utxoDisk).."/"..prefix.."utxo.txt","r")
    local line = file:read()
    while line ~= nil do
        local arr = explode(",",line)
        if arr[1]==uuid then return arr[2] end
    end
    return false
end

function storage.tmpremutxopresent(uuid) storage.remutxopresent(uuid,true) end
function storage.remutxopresent(uuid, tmp)
    local prefix = ""
    if tmp==true then prefix="tmp" end
    
    local file = io.open("/mnt/"..(storage.utxoDisk).."/"..prefix.."remutxo.txt","r")
    local line = file:read()
    while line ~= nil do
        local arr = explode(",",line)
        if arr[1]==uuid then return arr[2] end
    end
    return false
end

function storage.tmpremoveutxo(uuid) storage.removeutxo(uuid,true) end
function storage.removeutxo(uuid, tmp)
    local prefix = ""
    if tmp==true then prefix="tmp" end
    
    local file = io.open("/mnt/"..(storage.utxoDisk).."/"..prefix.."utxo.txt","r")
    local newfile = io.open("/mnt/"..(storage.utxoDisk).."/"..prefix.."utxo2.txt","w")
    local line = file:read()
    while line ~= nil do
        if explode(",",line)[1]~=uuid then newfile:write(line.."\n") end
    end
    file:close()
    newfile:close()
    filesys.remove("/mnt/"..(storage.utxoDisk).."/"..prefix.."utxo.txt")
    filesys.rename("/mnt/"..(storage.utxoDisk).."/utxo2.txt","/mnt/"..(storage.utxoDisk).."/"..prefix.."utxo.txt")
end

function storage.tmpremovewalletutxo(uuid) storage.removewalletutxo(uuid,true) end
function storage.removewalletutxo(uuid, tmp)
    local prefix = ""
    if tmp==true then prefix="tmp" end
    
    local file = io.open("/mnt/"..(storage.utxoDisk).."/"..prefix.."walletutxo.txt","r")
    local newfile = io.open("/mnt/"..(storage.utxoDisk).."/"..prefix.."walletutxo2.txt","w")
    local line = file:read()
    while line ~= nil do
        if explode(",",line)[1]~=uuid then newfile:write(line.."\n") end
    end
    file:close()
    newfile:close()
    filesys.remove("/mnt/"..(storage.utxoDisk).."/"..prefix.."walletutxo.txt")
    filesys.rename("/mnt/"..(storage.utxoDisk).."/walletutxo2.txt","/mnt/"..(storage.utxoDisk).."/"..prefix.."walletutxo.txt")
end

function storage.tmpremoveremutxo(uuid) storage.removeremutxo(uuid,true) end
function storage.removeremutxo(uuid, tmp)
    local prefix = ""
    if tmp==true then prefix="tmp" end
    
    local file = io.open("/mnt/"..(storage.utxoDisk).."/"..prefix.."remutxo.txt","r")
    local newfile = io.open("/mnt/"..(storage.utxoDisk).."/"..prefix.."remutxo2.txt","w")
    local line = file:read()
    while line ~= nil do
        if explode(",",line)[1]~=uuid then newfile:write(line.."\n") end
    end
    file:close()
    newfile:close()
    filesys.remove("/mnt/"..(storage.utxoDisk).."/"..prefix.."remutxo.txt")
    filesys.rename("/mnt/"..(storage.utxoDisk).."/"..prefix.."remutxo2.txt","/mnt/"..(storage.utxoDisk).."/"..prefix.."remutxo.txt")
end

function storage.tmpremovewalletremutxo(uuid) storage.removewalletremutxo(uuid,true) end
function storage.removewalletremutxo(uuid, tmp)
    local prefix = ""
    if tmp==true then prefix="tmp" end
    
    local file = io.open("/mnt/"..(storage.utxoDisk).."/"..prefix.."walletremutxo.txt","r")
    local newfile = io.open("/mnt/"..(storage.utxoDisk).."/"..prefix.."walletremutxo2.txt","w")
    local line = file:read()
    while line ~= nil do
        if explode(",",line)[1]~=uuid then newfile:write(line.."\n") end
    end
    file:close()
    newfile:close()
    filesys.remove("/mnt/"..(storage.utxoDisk).."/"..prefix.."walletremutxo.txt")
    filesys.rename("/mnt/"..(storage.utxoDisk).."/"..prefix.."walletremutxo2.txt","/mnt/"..(storage.utxoDisk).."/"..prefix.."walletremutxo.txt")
end

function storage.discardtmputxo()
    filesys.remove("/mnt/"..(storage.utxoDisk).."/tmputxo.txt")
    filesys.remove("/mnt/"..(storage.utxoDisk).."/tmpremutxo.txt")
    filesys.remove("/mnt/"..(storage.utxoDisk).."/tmpwalletutxo.txt")
    filesys.remove("/mnt/"..(storage.utxoDisk).."/tmpwalletremutxo.txt")
end

function storage.consolidatetmputxo()
    filesys.remove("/mnt/"..(storage.utxoDisk).."/utxo.txt")
    filesys.remove("/mnt/"..(storage.utxoDisk).."/remutxo.txt")
    filesys.copy("/mnt/"..(storage.utxoDisk).."/tmputxo.txt","/mnt/"..(storage.utxoDisk).."/utxo.txt")
    filesys.copy("/mnt/"..(storage.utxoDisk).."/tmpremutxo.txt","/mnt/"..(storage.utxoDisk).."/remutxo.txt")
    filesys.remove("/mnt/"..(storage.utxoDisk).."/tmputxo.txt")
    filesys.remove("/mnt/"..(storage.utxoDisk).."/tmpremutxo.txt")
    
    filesys.remove("/mnt/"..(storage.utxoDisk).."/walletutxo.txt")
    filesys.remove("/mnt/"..(storage.utxoDisk).."/walletremutxo.txt")
    filesys.copy("/mnt/"..(storage.utxoDisk).."/tmpwalletutxo.txt","/mnt/"..(storage.utxoDisk).."/walletutxo.txt")
    filesys.copy("/mnt/"..(storage.utxoDisk).."/tmpwalletremutxo.txt","/mnt/"..(storage.utxoDisk).."/walletremutxo.txt")
    filesys.remove("/mnt/"..(storage.utxoDisk).."/tmpwalletutxo.txt")
    filesys.remove("/mnt/"..(storage.utxoDisk).."/tmpwalletremutxo.txt")
end

function storage.cacheutxo()
    filesys.remove("/mnt/"..(storage.utxoDisk).."/utxo_cached.txt")
    filesys.copy("/mnt/"..(storage.utxoDisk).."/utxo.txt","/mnt/"..(storage.utxoDisk).."/utxo_cached.txt")
    filesys.remove("/mnt/"..(storage.utxoDisk).."/remutxo_cached.txt")
    filesys.copy("/mnt/"..(storage.utxoDisk).."/remutxo.txt","/mnt/"..(storage.utxoDisk).."/remutxo_cached.txt")
    
    filesys.remove("/mnt/"..(storage.utxoDisk).."/walletutxo_cached.txt")
    filesys.copy("/mnt/"..(storage.utxoDisk).."/walletutxo.txt","/mnt/"..(storage.utxoDisk).."/walletutxo_cached.txt")
    filesys.remove("/mnt/"..(storage.utxoDisk).."/walletremutxo_cached.txt")
    filesys.copy("/mnt/"..(storage.utxoDisk).."/walletremutxo.txt","/mnt/"..(storage.utxoDisk).."/walletremutxo_cached.txt")
end

function storage.restoreutxo()
    filesys.remove("/mnt/"..(storage.utxoDisk).."/utxo.txt")
    filesys.copy("/mnt/"..(storage.utxoDisk).."/utxo_cached.txt","/mnt/"..(storage.utxoDisk).."/utxo.txt")
    filesys.remove("/mnt/"..(storage.utxoDisk).."/remutxo.txt")
    filesys.copy("/mnt/"..(storage.utxoDisk).."/remutxo_cached.txt","/mnt/"..(storage.utxoDisk).."/remutxo.txt")
    
    filesys.remove("/mnt/"..(storage.utxoDisk).."/walletutxo.txt")
    filesys.copy("/mnt/"..(storage.utxoDisk).."/walletutxo_cached.txt","/mnt/"..(storage.utxoDisk).."/walletutxo.txt")
    filesys.remove("/mnt/"..(storage.utxoDisk).."/walletremutxo.txt")
    filesys.copy("/mnt/"..(storage.utxoDisk).."/walletremutxo_cached.txt","/mnt/"..(storage.utxoDisk).."/walletremutxo.txt")
end

return storage