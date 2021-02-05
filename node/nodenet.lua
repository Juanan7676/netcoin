local protocol = require("protocol")
local storage = require("storage")
local napi = require("netcraftAPI")
local component = require("component")
local serial = require("serialization")
require("protocol")
local modem = component.modem
require("common")

local nodenet = {}

function nodenet.sendClient(c,p,msg)
    modem.send(c,p,cache.myPort,msg)
end

function nodenet.dispatchNetwork(sv)
    local clientIP,clientPort,msg = napi.listen(modem)
    local parsed = explode("####",msg)
    
    if parsed[1]=="GETBLOCK" then
        local req = parsed[2]
        local block = storage.loadBlock(req)
        if block==nil then nodenet.sendClient(clientIP,clientPort,"ERR_BLOCK_NOT_FOUND")
        else nodenet.sendClient(clientIP,clientPort,"OK####"..serial.serialize(block)) end
        
    elseif parsed[1]=="GETNODES" then
        for _,client in ipairs(cache.nodes) do
                nodenet.sendClient(clientIP,clientPort,client.ip .. "####" .. client.port)
            end
        nodenet.sendClient(clientIP,clientPort,"END")
    elseif parsed[1]=="NEWBLOCK" then
        local block = serial.unserialize(parsed[2])
        local result = nodenet.newBlock(sv,clientIP,clientPort,block)
        if result==true then
            for _,client in ipairs(cache.nodes) do
                nodenet.sendClient(client.ip, client.port, parsed[1].."####"..parsed[2])
            end
        end
    end
end

function nodenet.newBlock(sv,clientIP,clientPort,block)
    if not block or not block.height then return false end
    if cache.getlastBlock()~="error" and block.height <= storage.loadBlock(cache.getlastBlock()).height then nodenet.sendClient(clientIP,clientPort,"NOT_ENOUGH_HEIGHT")
    elseif block.previous==nil then nodenet.sendClient(clientIP,clientPort,"INVALID_BLOCK")
    elseif cache.getlastBlock()~="error" and block.previous ~= cache.getlastBlock() then -- We need more blocks!
            local lb = storage.loadBlock(cache.getlastBlock())
            local chain = lb
            local recv = {block}
            while chain.uuid ~= recv.uuid do
                local tries = 0
                repeat
                nodenet.sendClient("GETBLOCK,"..(recv.previous))
                local msg = explode("####",nodenet.getResponse(sv,client,port))
                tries = tries + 1
                until msg[2] ~= "OK" and tries < 5
                if tries >= 5 then return false end
                local recvb = serial.unserialize(msg[3])
                if recvb.uuid ~= recv.previous then return false end
                table.insert(recv,recvb)
                chain = storage.loadBlock(chain.previous)
            end
            if ((lb.height - lb.height%10) ~= (recv.height - lb.height%10)) then
                local result = protocol.reconstructUTXOFromCache(chain, recv)
                if (not result) then nodenet.sendClient(clientIP,clientPort,"INVALID_BLOCKS")
                else nodenet.sendClient(clientIP,clientPort,"BLOCK_ACCEPTED") return true end
            else
                local result = protocol.reconstructUTXOFromZero(chain, recv)
                if (not result) then nodenet.sendClient(clientIP,clientPort,"INVALID_CHAIN")
                else nodenet.sendClient(clientIP,clientPort,"BLOCK_ACCEPTED") return true end
            end
            
    elseif not verifyBlock(block) then nodenet.sendClient(clientIP,clientPort,"INVALID_BLOCK")
    else
        consolidateBlock(block)
        nodenet.sendClient(clientIP,clientPort,"BLOCK_ACCEPTED")
        return true
    end
    return false
end

function nodenet.getResponse(sv,client,port)
    local clientIP,msg,clientPort = sv.listen()
    local parsed = explode("####",msg)
    
    if clientIP ~= client then nodenet.sendClient(clientIP,clientPort,"BUSY")
    else return msg end
end

return nodenet