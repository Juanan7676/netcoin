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
    local sock = napi.connect(modem,c,p)
    if sock==false then return false end
    napi.send(sock,cache.myIP.."####"..msg)
    napi.close(sock)
end

function nodenet.dispatchNetwork(sv)
    local t = sv.listen()
    local clientIP = t[1]
    local msg = t[2]
    local clientPort = t[3]
    local parsed = explode("####",msg)
    
    if msg[1]=="GETBLOCK" then
        local req = msg[4]
        local block = storage.loadBlock(req)
        if block==nil then nodenet.sendClient(clientIP,clientPort,"ERR_BLOCK_NOT_FOUND")
        else nodenet.sendClient(clientIP,clientPort,"OK####"..serial.serialize(block)) end
        
    elseif msg[2]=="GETNODES" then
        for _,client in ipairs(cache.nodes) do
                nodenet.sendClient(clientIP,clientPort,client.ip .. "####" .. client.port)
            end
        nodenet.sendClient(clientIP,clientPort,"END")
    elseif msg[2]=="NEWBLOCK" then
        local block = serial.unserialize(msg[3])
        local result = nodenet.newBlock(sv,clientIP,clientPort,block)
        if result==true then
            for _,client in ipairs(cache.nodes) do
                nodenet.sendClient(client.ip, client.port, msg[2].."####"..msg[3])
            end
        end
    end
end

function nodenet.newBlock(sv,clientIP,clientPort,block)
    if block.height <= storage.loadBlock(cache.getlastBlock()).height then nodenet.sendClient(clientIP,clientPort,"NOT_ENOUGH_HEIGHT")
        else if block.previous ~= cache.getlastBlock() then -- We need more blocks!
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