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
local df = assert(io.open("disks.txt","r"))
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
df:close()

function getMount(addr)
	local f = filesys.mounts()
	for p,m in f do
		if p.address == addr then return m end
	end
end

function storage.generateIndex()
    local file = io.open(getMount(storage.indexDisk).."/index.txt","w")
    file:write("0000000000000000,00\n")
    file:close()
end

function storage.loadIndex(uuid)
    local file,err = assert(io.open(getMount(storage.indexDisk).."/index.txt","r"))
    if file==nil then print(err) end
	if not uuid then return nil end
	local arr
	local data
	repeat
		data = file:read()
		if not data then return nil end
		arr = explode(",",data)
	until (arr[1] == uuid)
    if arr[1]=="0000000000000000" then file:close() return nil end
    if arr[1]~=uuid then -- Solve conflict
        local aux = io.open(getMount(storage.indexDisk).."/conflicts/"..arr[1]..".txt","r")
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
        file:close()
        return ret
    end
    file:close()
    return data
end

function storage.loadRawIndex(uuid)
    local file = io.open(getMount(storage.indexDisk).."/index.txt","r")
    
    local num = hexMod(tohex(storage.data.sha256(uuid)),150000)
	local data
    repeat
		data = file:read()
		if not data then return nil end
		arr = explode(",",data)
	until (arr[1] == uuid)
    file:close()
    return data
end

function storage.saveIndex(uuid,disk)
    local i = storage.loadRawIndex(uuid) or "0000000000000000"
    local arr = explode(",",i)
    if arr[1]~="0000000000000000" and arr[1]~=uuid then -- Solve conflict
        local file = io.open(getMount(storage.indexDisk).."/conflicts/"..arr[1]..".txt","a")
        file:write(uuid..","..disk.."\n")
        file:close()
    else
        local file = io.open(getMount(storage.indexDisk).."/index.txt","a")
        file:write(uuid..","..disk.."\n")
        file:close()
    end
end

function storage.loadBlock(uuid)
    local index = storage.loadIndex(uuid)
    if index==nil then return nil, "nonexistent index" end
	
    local data = explode(",",index)
    local disk = storage.disks[data[2]]
    if disk==nil then return nil, "invalid index" end
    local file = io.open(getMount(disk).."/"..uuid..".txt","r")
    local block = (serial.unserialize(file:read("*a")))
    file:close()
    return block
end

function storage.saveBlock(block)
    if storage.loadBlock(block.uuid) ~= nil then return end
    local data = serial.serialize(block)
    for k,d in pairs(storage.disks) do
        local hdd = component.proxy(component.get(d))
        if ( hdd.spaceTotal() - hdd.spaceUsed() >= data:len() ) then
            local file = io.open(getMount(d).."/"..(block.uuid)..".txt","w")
            file:write(data)
            file:close()
            storage.saveIndex(block.uuid,k)
            return
        end
    end
    error("[!] All disks are full, i'm unable to save block id ".. block.uuid)
    return nil
end

function storage.tmpsaveutxo(uuid,buuid) storage.saveutxo(uuid,buuid,true) end
function storage.saveutxo(uuid, buuid, tmp)
    local prefix = ""
    if tmp==true then prefix="tmp" end

    local file = io.open(getMount(storage.utxoDisk).."/"..prefix.."utxo.txt","a")
    file:write(uuid..","..buuid.."\n")
    file:close()
end

function storage.tmpsavewalletutxo(uuid,buuid) storage.savewalletutxo(uuid,buuid,true) end
function storage.savewalletutxo(uuid, buuid, tmp)
    local prefix = ""
    if tmp==true then prefix="tmp" end

    local file = io.open(getMount(storage.utxoDisk).."/"..prefix.."walletutxo.txt","a")
    file:write(uuid..","..buuid.."\n")
    file:close()
end

function storage.tmpsaveremutxo(uuid,buuid) storage.saveremutxo(uuid,buuid,true) end
function storage.saveremutxo(uuid, buuid, tmp)
    local prefix = ""
    if tmp==true then prefix="tmp" end

    local file = io.open(getMount(storage.utxoDisk).."/"..prefix.."remutxo.txt","a")
    file:write(uuid..","..buuid.."\n")
    file:close()
end

function storage.tmpsavewalletremutxo(uuid,buuid) storage.savewalletremutxo(uuid,buuid,true) end
function storage.savewalletremutxo(uuid, buuid, tmp)
    local prefix = ""
    if tmp==true then prefix="tmp" end

    local file = io.open(getMount(storage.utxoDisk).."/"..prefix.."walletremutxo.txt","a")
    file:write(uuid..","..buuid.."\n")
    file:close()
end

function storage.tmputxopresent(uuid) return storage.utxopresent(uuid,true) end
function storage.utxopresent(uuid, tmp)
    local prefix = ""
    if tmp==true then prefix="tmp" end

    local file = io.open(getMount(storage.utxoDisk).."/"..prefix.."utxo.txt","r")
    local line = file:read()
    while line ~= nil do
        local arr = explode(",",line)
        if arr[1]==uuid then file:close() return arr[2] end
        line = file:read()
    end
    file:close() return false
end

function storage.tmpremutxopresent(uuid) return storage.remutxopresent(uuid,true) end
function storage.remutxopresent(uuid, tmp)
    local prefix = ""
    if tmp==true then prefix="tmp" end
    
    local file = io.open(getMount(storage.utxoDisk).."/"..prefix.."remutxo.txt","r")
    local line = file:read()
    while line ~= nil do
        local arr = explode(",",line)
        if arr[1]==uuid then file:close() return arr[2] end
        line = file:read()
    end
    file:close()
    return false
end

function storage.tmpremoveutxo(uuid) storage.removeutxo(uuid,true) end
function storage.removeutxo(uuid, tmp)
    local prefix = ""
    if tmp==true then prefix="tmp" end
    
    local file = io.open(getMount(storage.utxoDisk).."/"..prefix.."utxo.txt","r")
    local newfile = io.open(getMount(storage.utxoDisk).."/"..prefix.."utxo2.txt","w")
    local line = file:read()
    while line ~= nil do
        if explode(",",line)[1]~=uuid then newfile:write(line.."\n") end
        line = file:read()
    end
    file:close()
    newfile:close()
    filesys.remove(getMount(storage.utxoDisk).."/"..prefix.."utxo.txt")
    filesys.rename(getMount(storage.utxoDisk).."/"..prefix.."utxo2.txt",getMount(storage.utxoDisk).."/"..prefix.."utxo.txt")
end

function storage.tmpremovewalletutxo(uuid) storage.removewalletutxo(uuid,true) end
function storage.removewalletutxo(uuid, tmp)
    local prefix = ""
    if tmp==true then prefix="tmp" end
    
    local file = io.open(getMount(storage.utxoDisk).."/"..prefix.."walletutxo.txt","r")
    local newfile = io.open(getMount(storage.utxoDisk).."/"..prefix.."walletutxo2.txt","w")
    local line = file:read()
    while line ~= nil do
        if explode(",",line)[1]~=uuid then newfile:write(line.."\n") end
        line = file:read()
    end
    file:close()
    newfile:close()
    filesys.remove(getMount(storage.utxoDisk).."/"..prefix.."walletutxo.txt")
    filesys.rename(getMount(storage.utxoDisk).."/"..prefix.."walletutxo2.txt",getMount(storage.utxoDisk).."/"..prefix.."walletutxo.txt")
end

function storage.tmpremoveremutxo(uuid) storage.removeremutxo(uuid,true) end
function storage.removeremutxo(uuid, tmp)
    local prefix = ""
    if tmp==true then prefix="tmp" end
    
    local file = io.open(getMount(storage.utxoDisk).."/"..prefix.."remutxo.txt","r")
    local newfile = io.open(getMount(storage.utxoDisk).."/"..prefix.."remutxo2.txt","w")
    local line = file:read()
    while line ~= nil do
        if explode(",",line)[1]~=uuid then newfile:write(line.."\n") end
        line = file:read()
    end
    file:close()
    newfile:close()
    filesys.remove(getMount(storage.utxoDisk).."/"..prefix.."remutxo.txt")
    filesys.rename(getMount(storage.utxoDisk).."/"..prefix.."remutxo2.txt",getMount(storage.utxoDisk).."/"..prefix.."remutxo.txt")
end

function storage.tmpremovewalletremutxo(uuid) storage.removewalletremutxo(uuid,true) end
function storage.removewalletremutxo(uuid, tmp)
    local prefix = ""
    if tmp==true then prefix="tmp" end
    
    local file = io.open(getMount(storage.utxoDisk).."/"..prefix.."walletremutxo.txt","r")
    local newfile = io.open(getMount(storage.utxoDisk).."/"..prefix.."walletremutxo2.txt","w")
    local line = file:read()
    while line ~= nil do
        if explode(",",line)[1]~=uuid then newfile:write(line.."\n") end
        line = file:read()
    end
    file:close()
    newfile:close()
    filesys.remove(getMount(storage.utxoDisk).."/"..prefix.."walletremutxo.txt")
    filesys.rename(getMount(storage.utxoDisk).."/"..prefix.."walletremutxo2.txt",getMount(storage.utxoDisk).."/"..prefix.."walletremutxo.txt")
end

function storage.discardtmputxo()
    filesys.remove(getMount(storage.utxoDisk).."/tmputxo.txt")
    filesys.remove(getMount(storage.utxoDisk).."/tmpremutxo.txt")
    filesys.remove(getMount(storage.utxoDisk).."/tmpwalletutxo.txt")
    filesys.remove(getMount(storage.utxoDisk).."/tmpwalletremutxo.txt")
end

function storage.consolidatetmputxo()
    filesys.remove(getMount(storage.utxoDisk).."/utxo.txt")
    filesys.remove(getMount(storage.utxoDisk).."/remutxo.txt")
    filesys.copy(getMount(storage.utxoDisk).."/tmputxo.txt",getMount(storage.utxoDisk).."/utxo.txt")
    filesys.copy(getMount(storage.utxoDisk).."/tmpremutxo.txt",getMount(storage.utxoDisk).."/remutxo.txt")
    filesys.remove(getMount(storage.utxoDisk).."/tmputxo.txt")
    filesys.remove(getMount(storage.utxoDisk).."/tmpremutxo.txt")
    
    filesys.remove(getMount(storage.utxoDisk).."/walletutxo.txt")
    filesys.remove(getMount(storage.utxoDisk).."/walletremutxo.txt")
    filesys.copy(getMount(storage.utxoDisk).."/tmpwalletutxo.txt",getMount(storage.utxoDisk).."/walletutxo.txt")
    filesys.copy(getMount(storage.utxoDisk).."/tmpwalletremutxo.txt",getMount(storage.utxoDisk).."/walletremutxo.txt")
    filesys.remove(getMount(storage.utxoDisk).."/tmpwalletutxo.txt")
    filesys.remove(getMount(storage.utxoDisk).."/tmpwalletremutxo.txt")
end

function storage.cacheutxo()
    filesys.remove(getMount(storage.utxoDisk).."/utxo_cached.txt")
    filesys.copy(getMount(storage.utxoDisk).."/utxo.txt",getMount(storage.utxoDisk).."/utxo_cached.txt")
    filesys.remove(getMount(storage.utxoDisk).."/remutxo_cached.txt")
    filesys.copy(getMount(storage.utxoDisk).."/remutxo.txt",getMount(storage.utxoDisk).."/remutxo_cached.txt")
    
    filesys.remove(getMount(storage.utxoDisk).."/walletutxo_cached.txt")
    filesys.copy(getMount(storage.utxoDisk).."/walletutxo.txt",getMount(storage.utxoDisk).."/walletutxo_cached.txt")
    filesys.remove(getMount(storage.utxoDisk).."/walletremutxo_cached.txt")
    filesys.copy(getMount(storage.utxoDisk).."/walletremutxo.txt",getMount(storage.utxoDisk).."/walletremutxo_cached.txt")
end

function storage.restoreutxo()
    filesys.remove(getMount(storage.utxoDisk).."/utxo.txt")
    filesys.copy(getMount(storage.utxoDisk).."/utxo_cached.txt",getMount(storage.utxoDisk).."/utxo.txt")
    filesys.remove(getMount(storage.utxoDisk).."/remutxo.txt")
    filesys.copy(getMount(storage.utxoDisk).."/remutxo_cached.txt",getMount(storage.utxoDisk).."/remutxo.txt")
    
    filesys.remove(getMount(storage.utxoDisk).."/walletutxo.txt")
    filesys.copy(getMount(storage.utxoDisk).."/walletutxo_cached.txt",getMount(storage.utxoDisk).."/walletutxo.txt")
    filesys.remove(getMount(storage.utxoDisk).."/walletremutxo.txt")
    filesys.copy(getMount(storage.utxoDisk).."/walletremutxo_cached.txt",getMount(storage.utxoDisk).."/walletremutxo.txt")
end

function storage.setuptmpenvutxo()
    local file = io.open(getMount(storage.utxoDisk).."/tmpwalletutxo.txt","w")
    file:close()
    file = io.open(getMount(storage.utxoDisk).."/tmpwalletremutxo.txt","w")
    file:close()
    file = io.open(getMount(storage.utxoDisk).."/tmputxo.txt","w")
    file:close()
    file = io.open(getMount(storage.utxoDisk).."/tmpremutxo.txt","w")
    file:close()
end

function storage.setuptmpenvutxo_cache()
    filesys.copy(getMount(storage.utxoDisk).."/utxo_cached.txt",getMount(storage.utxoDisk).."/tmputxo.txt")
    filesys.copy(getMount(storage.utxoDisk).."/remutxo_cached.txt",getMount(storage.utxoDisk).."/tmpremutxo.txt")
    filesys.copy(getMount(storage.utxoDisk).."/walletutxo_cached.txt",getMount(storage.utxoDisk).."/tmpwalletutxo.txt")
    filesys.copy(getMount(storage.utxoDisk).."/walletremutxo_cached.txt",getMount(storage.utxoDisk).."/tmpwalletremutxo.txt")
end

function storage.generateutxo()
    local file = io.open(getMount(storage.utxoDisk).."/utxo.txt","w")
    file:close()
    file = io.open(getMount(storage.utxoDisk).."/remutxo.txt","w")
    file:close()
    
    file = io.open(getMount(storage.utxoDisk).."/walletutxo.txt","w")
    file:close()
    file = io.open(getMount(storage.utxoDisk).."/walletremutxo.txt","w")
    file:close()
end

return storage