local storage = {}

component = require("component")
serial = require("serialization")
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
    local file = io.open("/mnt/"..(storage.indexDisk).."/index.txt","r")
    num = hexMod(tohex(storage.data.sha256(uuid)),150000)
    file:seek("set",20*num)
    local data = file:read()
    local arr = explode(",",data)
    if arr[1]~="0000000000000000" and arr[1]~=uuid then -- Solve conflict
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
    local file = io.open("/mnt/"..(storage.indexDisk).."/index.txt","r")
    num = hexMod(tohex(storage.data.sha256(uuid)),150000)
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
        num = hexMod(tohex(storage.data.sha256(uuid)),150000)
        file:seek("set",20*num)
    
        file:write(uuid..","..disk)
        file:close()
    end
end

function storage.loadBlock(uuid,disk)
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

return storage