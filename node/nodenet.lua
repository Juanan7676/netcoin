require("protocol")
local storage = require("storage")
local napi = require("netcraftAPI")
local component = require("component")
local serial = require("serialization")
local modem = component.modem
require("common")

local nodenet = {}

function nodenet.sendClient(c,p,msg)
    modem.send(c,p,cache.myPort,msg)
end

function nodenet.connectClient(c,p)
    nodenet.sendClient(c,p,"PING")
    local _,_,rp = napi.listentoclient(modem,cache.myPort,c,2)
    if (rp==nil) then return nil
    elseif (rp=="PONG!") then
        nodenet.sendClient(c,p,"NEWNODE####".. cache.myIP .. "####" .. cache.myPort .. "####0")
        cache.nodes[c] = {}
        cache.nodes[c].ip = c
        cache.nodes[c].port = p
        cache.nodes[c].miner = "0"
        cache.saveNodes()
        nodenet.sync()
    end
    return true
end

function nodenet.reloadWallet()
    local file = io.open("/mnt/".. storage.utxoDisk .. "/walletutxo.txt","r")
    local line = file:read()
    cache.lt = {}
    cache.pt = {}
    cache.cb = 0
    cache.tb = 0
    
    while line ~= nil do
        local parsed = explode(",",line)
        local t = getTransactionFromBlock(storage.loadBlock(parsed[2]),parsed[1])
        if (t~=nil) then
            local diff = storage.loadBlock(cache.getlastBlock()).height - storage.loadBlock(parsed[2]).height
            if (diff >= 3) then
                if (#cache.lt < 5) then cache.lt[#cache.lt+1] = t end
                cache.cb = cache.cb + t.qty
                cache.tb = cache.tb + t.qty
            else
                cache.pt[#cache.pt+1] = {t,diff}
                cache.tb = cache.tb + t.qty
            end
        end
        line = file:read()
    end
    file:close()
    file = io.open("/mnt/".. storage.utxoDisk .. "/walletremutxo.txt","r")
    while line ~= nil do
        local parsed = explode(",",line)
        local t = getTransactionFromBlock(storage.loadBlock(parsed[2]),parsed[1])
        if (t~=nil) then
            local diff = storage.loadBlock(cache.getlastBlock()).height - storage.loadBlock(parsed[2]).height
            if (diff >= 3) then
                if (#cache.lt < 5) then cache.lt[#cache.lt+1] = t end
                cache.cb = cache.cb + t.rem
                cache.tb = cache.tb + t.rem
            else
                cache.pt[#cache.pt+1] = {t,diff}
                cache.tb = cache.tb + t.rem
            end
        end
        line = file:read()
    end
    updateScreen(cache.cb,cache.tb,cache.rt,cache.pt)
end

function nodenet.confectionateTransaction(to, qty)
    if (qty>cache.cb) then return nil end
    local t = {}
    t.id = randomUUID(16)
    t.from = cache.walletPK.serialize()
    t.to = to
    t.qty = qty
    t.sources = {}
    local totalIN=0
    
    local file = io.open("/mnt/".. storage.utxoDisk .. "/walletremutxo.txt","r")
    while line ~= nil do
        local parsed = explode(",",line)
        local source = getTransactionFromBlock(storage.loadBlock(parsed[2]),parsed[1])
        if (source~=nil) then
            local diff = storage.loadBlock(cache.getlastBlock()).height - storage.loadBlock(parsed[2]).height
            if (diff >= 3) then
                totalIN = totalIN + source.rem
                table.insert(t.sources,source.id)
                if (totalIN >= qty) then break end
            end
        end
        line = file:read()
    end
    file:close()
    
    if totalIN >= qty then
        t.rem = totalIN - qty
        t.sig = data.ecdsa(t.id .. t.from .. t.to .. t.qty .. serial.serialize(t.sources) .. t.rem, cache.walletSK)
        return t
    end
    
    file = io.open("/mnt/".. storage.utxoDisk .. "/walletutxo.txt","r")
    while line ~= nil do
        local parsed = explode(",",line)
        local source = getTransactionFromBlock(storage.loadBlock(parsed[2]),parsed[1])
        if (source~=nil) then
            local diff = storage.loadBlock(cache.getlastBlock()).height - storage.loadBlock(parsed[2]).height
            if (diff >= 3) then
                totalIN = totalIN + source.qty
                table.insert(t.sources,source.id)
                if (totalIN >= qty) then break end
            end
        end
        line = file:read()
    end
    file:close()
    
    if totalIN >= qty then
        t.rem = totalIN - qty
        t.sig = data.ecdsa(t.id .. t.from .. t.to .. t.qty .. serial.serialize(t.sources) .. t.rem, cache.walletSK)
        return t
    end
    
    return nil
end

function nodenet.sync()
    -- Update node list
    for _,client in pairs(cache.nodes) do
        nodenet.sendClient(client.ip, client.port, "GETNODES")
        local msg
        repeat
            _,_,msg = napi.listentoclient(modem, cache.myPort, client.ip, 2)
            if msg~="NOT_IMPLEMENTED" and msg~=nil and msg~="END" then
                local parse = explode("####",msg)
                cache.nodes[parse[1]] = {}
                cache.nodes[parse[1]].ip = parse[1]
                cache.nodes[parse[1]].port = parse[2]
                cache.nodes[parse[1]].miner = parse[3]
                cache.saveNodes()
            end
        until msg=="END" or msg==nil or msg=="NOT_IMPLEMENTED"
    end
    -- Get last block
    for _,client in pairs(cache.nodes) do
        nodenet.sendClient(client.ip, client.port, "GET_LAST_BLOCK")
        local _,_,msg = napi.listentoclient(modem, cache.myPort, client.ip, 2)
        if msg~="NOT_IMPLEMENTED" and msg~=nil then
            local block = serial.unserialize(msg)
            local result = nodenet.newBlock(client.ip,client.port, block)
        end
    end
end

function nodenet.dispatchNetwork()
    local clientIP,clientPort,msg = napi.listen(modem, cache.myPort)
    local parsed = explode("####",msg)
    
    if parsed[1]=="GETBLOCK" then
        local req = parsed[2]
        local block = storage.loadBlock(req)
        if block==nil then nodenet.sendClient(clientIP,clientPort,"ERR_BLOCK_NOT_FOUND")
        else nodenet.sendClient(clientIP,clientPort,"OK####"..serial.serialize(block)) end
        
    elseif parsed[1]=="GETNODES" then
        for _,client in ipairs(cache.nodes) do
                nodenet.sendClient(clientIP,clientPort,client.ip .. "####" .. client.port .. "####" .. client.node)
            end
        nodenet.sendClient(clientIP,clientPort,"END")
    elseif parsed[1]=="NEWBLOCK" then
        local block = serial.unserialize(parsed[2])
        local result = nodenet.newBlock(clientIP,clientPort,block)
        if result==true then
            for _,client in pairs(cache.nodes) do
                nodenet.sendClient(client.ip, client.port, "NEWBLOCK####"..parsed[2])
            end
            nodenet.reloadWallet()
        end
    elseif parsed[1]=="NEWNODE" then
        local node = parsed[2]
        if cache[node]~=nil then
            for k,client in pairs(cache.nodes) do
                nodenet.sendClient(client.ip, client.port, "NEWNODE####" .. parsed[2] .. "####" .. parsed[3] .. "####" .. parsed[4])
            end
            cache.nodes[node] = {}
            cache.nodes[node].ip = node
            cache.nodes[node].port = parsed[3]
            cache.nodes[node].miner = parsed[4]
            cache.saveNodes()
        end
    elseif parsed[1]=="GET_LAST_BLOCK" then
        nodenet.sendClient(clientIP,clientPort,serial.serialize(storage.loadBlock(cache.getlastBlock())))
    elseif parsed[1]=="NEWTRANSACT" then
        for k,v in pairs(cache.nodes) do
            if v.miner=="1" then
                nodenet.sendClient(v.ip, v.port, "NEWTRANSACT####" .. parsed[2])
            end
        end
    elseif parsed[1]=="PING" then
        nodenet.sendClient(clientIP,clientPort,"PONG!")
    end
end

function nodenet.newBlock(clientIP,clientPort,block)
    if not block or not block.height then return false end
    if cache.getlastBlock()~="error" and block.height <= storage.loadBlock(cache.getlastBlock()).height then nodenet.sendClient(clientIP,clientPort,"NOT_ENOUGH_HEIGHT")
    elseif block.previous==nil then nodenet.sendClient(clientIP,clientPort,"INVALID_BLOCK")
    elseif block.previous ~= cache.getlastBlock() then -- We need more blocks!
        local result = nodenet.newUnknownBlock(clientIP,clientPort,block)
        if result==false then nodenet.sendClient(clientIP,clientPort,"ERR_BLOCKS_REJECTED") end
    elseif not verifyBlock(block) then nodenet.sendClient(clientIP,clientPort,"INVALID_BLOCK")
    else
        print("Consolidating block...")
        consolidateBlock(block)
        print("Added new block with id " .. block.uuid .. "at height" .. block.height)
        nodenet.sendClient(clientIP,clientPort,"BLOCK_ACCEPTED")
        return true
    end
    return false
end

function nodenet.newUnknownBlock(clientIP,clientPort,block)
    local lb = storage.loadBlock(cache.getlastBlock())
            local chain = lb
            if (chain==nil) then chain={uuid="",height=-1} end
            local recv = {block}
            while (chain.uuid~="" and chain.uuid ~= recv[#recv].uuid and recv[#recv].height~=0) or (chain.uuid=="" and recv[#recv].height~=0) do
                local msg
                local tries = 0
                repeat
                    nodenet.sendClient(clientIP,clientPort,"GETBLOCK####"..(recv[#recv].previous))
                    _,_,msg = napi.listentoclient(modem,cache.myPort,clientIP,2)
                    if msg~=nil then msg = explode("####",msg) 
                    else return false
                    end
                    tries = tries + 1
                until msg[1] == "OK" or tries >= 5
                if tries >= 5 then return false end
                local recvb = serial.unserialize(msg[2])
                if recvb.uuid ~= recv[#recv].previous then return false end
                recv[#recv+1] = recvb
                if (chain.uuid ~= "") then chain = storage.loadBlock(chain.previous) end
            end
            if chain.uuid=="" or ( ((lb.height - lb.height%10) ~= (chain.height - chain.height%10)) or recv[#recv].height==0) then
                local result = reconstructUTXOFromZero(recv, block)
                if (not result) then nodenet.sendClient(clientIP,clientPort,"INVALID_BLOCKS")
                else nodenet.sendClient(clientIP,clientPort,"BLOCK_ACCEPTED") return true end
            else
                local result = reconstructUTXOFromCache(recv, block)
                if (not result) then nodenet.sendClient(clientIP,clientPort,"INVALID_CHAIN")
                else nodenet.sendClient(clientIP,clientPort,"BLOCK_ACCEPTED") return true end
            end
    return false
end

return nodenet