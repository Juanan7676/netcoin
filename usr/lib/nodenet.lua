require("protocol")

local storage = require("storage")
local napi = require("netcraftAPI")
local component = require("component")
local serial = require("serialization")
local os = require("os")
local modem = component.modem
local utxoProvider = require("utreetxo.utxoProviderInMemory")
require("common")
require("minerNode")

local nodenet = {}

function nodenet.sendClient(c, p, msg)
    modem.send(c, tonumber(p), cache.myPort, msg)
end

function nodenet.connectClient(c, p)
    nodenet.sendClient(c, p, "PING")
    local _, _, rp = napi.listentoclient(modem, cache.myPort, c, 5)
    if (rp == nil) then
        return nil
    elseif (rp == "PONG!") then
        if (not cache.minerNode) then
            nodenet.sendClient(c, p, "NEWNODE####" .. cache.myIP .. "####" .. cache.myPort .. "####0")
        else
            nodenet.sendClient(c, p, "NEWNODE####" .. cache.myIP .. "####" .. cache.myPort .. "####1")
        end
        cache.nodes[c] = {}
        cache.nodes[c].ip = c
        cache.nodes[c].port = p
        cache.nodes[c].miner = "1"
        cache.saveNodes()
        nodenet.sync()
    end
    return true
end

function nodenet.reloadWallet()
    local file =
        assert(
        io.open(getMount(storage.utxoDisk) .. "/walletutxo.txt", "r"),
        "Error opening file " .. getMount(storage.utxoDisk) .. "/walletutxo.txt"
    )
    local line = file:read()
    cache.lt = {}
    cache.pt = {}
    cache.cb = 0
    cache.tb = 0

    while line ~= nil do
        local parsed = explode(",", line)
        local t = getTransactionFromBlock(storage.loadBlock(parsed[2]), parsed[1])
        if (t ~= nil) then
            local diff = storage.loadBlock(cacheLib.getlastBlock()).height - storage.loadBlock(parsed[2]).height

            if (diff >= 3) then
                if (#cache.lt < 5) then
                    cache.lt[#cache.lt + 1] = t
                end
                cache.cb = cache.cb + t.qty
                cache.tb = cache.tb + t.qty
            else
                cache.pt[#cache.pt + 1] = {t, diff}
                cache.tb = cache.tb + t.qty
            end
        end
        line = file:read()
        os.sleep()
    end
    file:close()
    file = assert(io.open(getMount(storage.utxoDisk) .. "/walletremutxo.txt", "r"))
    line = file:read()

    while line ~= nil do
        local parsed = explode(",", line)
        local t = getTransactionFromBlock(storage.loadBlock(parsed[2]), parsed[1])
        if (t ~= nil) then
            local diff = storage.loadBlock(cacheLib.getlastBlock()).height - storage.loadBlock(parsed[2]).height
            if (diff >= 3) then
                if (#cache.lt < 5) then
                    cache.lt[#cache.lt + 1] = t
                end
                cache.cb = cache.cb + t.rem
                cache.tb = cache.tb + t.rem
            else
                cache.pt[#cache.pt + 1] = {t, diff}
                cache.tb = cache.tb + t.rem
            end
        end
        line = file:read()
        os.sleep()
    end
    file:close()
    updateScreen(cache.tb, cache.pb, cache.rt, cache.pt)
end

function nodenet.confectionateTransaction(to, qty)
    if (qty > cache.tb) then
        return nil
    end
    local t = {}
    t.id = randomUUID(16)
    t.from = cache.walletPK.serialize()
    t.to = to
    t.qty = qty
    t.sources = {}
    local totalIN = 0

    for tx in utxoProvider.getUtxos() do
        local source = {
            height = tx.bH,
            proof = tx.proof,
            txid = tx.txid
        }
        local transaction = loadFromHeight(source.height, source.txid)
        if transaction==nil then print("ERROR: Stored utxo not found on chain") return nil end
        if transaction.to == t.from then
            totalIN = totalIN + transaction.qty
            t.sources[#t.sources+1] = source
        elseif transaction.from == t.from then
            totalIN = totalIN + transaction.rem
            t.sources[#t.sources+1] = source
        else
            print("ERROR: Stored utxo is incorrect, contact a developer!!!")
        end
        if totalIN >= qty then
            t.rem = totalIN - qty
            t.sig = data.ecdsa(t.id .. t.from .. t.to .. t.qty .. hashSources(t.sources) .. t.rem, cache.walletSK)
            return t
        end
    end

    return nil
end

function nodenet.sync()
    -- Update node list
    print("Updating node list...")
    for _, client in pairs(cache.nodes) do
        nodenet.sendClient(client.ip, tonumber(client.port), "GETNODES")
        local msg
        repeat
            _, _, msg = napi.listentoclient(modem, cache.myPort, client.ip, 2)
            if msg ~= "NOT_IMPLEMENTED" and msg ~= nil and msg ~= "END" then
                local parse = explode("####", msg)
                cache.nodes[parse[1]] = {}
                cache.nodes[parse[1]].ip = parse[1]
                cache.nodes[parse[1]].port = parse[2]
                cache.nodes[parse[1]].miner = parse[3]
                cache.saveNodes()
            end
        until msg == "END" or msg == nil or msg == "NOT_IMPLEMENTED"
        if msg == nil or msg == "nil" or msg == "NOT_IMPLEMENTED" then
            print("Client timeout or error on " .. client.ip)
        end
    end
    -- Get last block
    print("Updating last block...")
    for _, client in pairs(cache.nodes) do
        nodenet.sendClient(client.ip, tonumber(client.port), "GET_LAST_BLOCK")
        local _, _, msg = napi.listentoclient(modem, cache.myPort, client.ip, 2)
        if msg ~= "NOT_IMPLEMENTED" and msg ~= nil and msg ~= "nil" then
            local block = serial.unserialize(msg)
            print("Recv: block " .. block.uuid .. " height " .. block.height)
            local result = nodenet.newBlock(client.ip, client.port, block)
        else
            print("Client timeout or error on " .. client.ip)
        end
    end
end

function nodenet.dispatchNetwork()
    local clientIP, clientPort, msg = napi.listen(modem, cache.myPort)
    clientPort = tonumber(clientPort)
    if clientPort == nil then
        return
    end
    if msg == nil then
        return
    end
    local parsed = explode("####", msg)
    --print(parsed[1])
    if parsed[1] == "GETBLOCK" then
        local req = parsed[2]
        local block = storage.loadBlock(req)
        if block == nil then
            nodenet.sendClient(clientIP, clientPort, "ERR_BLOCK_NOT_FOUND")
        else
            nodenet.sendClient(clientIP, clientPort, "OK####" .. serial.serialize(block))
        end
    elseif parsed[1] == "GETNODES" then
        for _, client in ipairs(cache.nodes) do
            nodenet.sendClient(clientIP, clientPort, client.ip .. "####" .. client.port .. "####" .. client.node)
        end
        nodenet.sendClient(clientIP, clientPort, "END")
    elseif parsed[1] == "NEWBLOCK" then
        local block = serial.unserialize(parsed[2])
        local result = nodenet.newBlock(clientIP, clientPort, block)
        if result == true then
            for _, client in pairs(cache.nodes) do
                nodenet.sendClient(client.ip, tonumber(client.port), "NEWBLOCK####" .. parsed[2])
            end
            updateScreen(cache.tb, cache.pb, cache.rt, cache.pt)
        end
    elseif parsed[1] == "NEWNODE" then
        local node = parsed[2]
        if cache.nodes[node] == nil then
            for k, client in pairs(cache.nodes) do
                nodenet.sendClient(
                    client.ip,
                    tonumber(client.port),
                    "NEWNODE####" .. parsed[2] .. "####" .. parsed[3] .. "####" .. parsed[4]
                )
            end
            cache.nodes[node] = {}
            cache.nodes[node].ip = node
            cache.nodes[node].port = parsed[3]
            cache.nodes[node].miner = parsed[4]
            cache.saveNodes()
        end
    elseif parsed[1] == "GET_LAST_BLOCK" then
        nodenet.sendClient(clientIP, clientPort, serial.serialize(storage.loadBlock(cacheLib.getlastBlock())))
    elseif parsed[1] == "NEWTRANSACT" then
        if cache.minerNode then
            if parsed[2] ~= nil then
                newTransaction(serial.unserialize(parsed[2]))
            end
        end

        for k, v in pairs(cache.nodes) do
            if v.miner == "1" and v.ip ~= clientIP then
                nodenet.sendClient(v.ip, v.port, "NEWTRANSACT####" .. parsed[2])
            end
        end
    elseif parsed[1] == "PING" then
        nodenet.sendClient(clientIP, clientPort, "PONG!")
    elseif parsed[1] == "CENTRALMINER_ANNOUNCE" then
        if not cache.minerNode then
            nodenet.sendClient(clientIP, clientPort, "ERR_NOT_MINER")
        elseif minercentralIP ~= false and minercentralIP ~= clientIP then
            nodenet.sendClient(clientIP, clientPort, "ERR_FORBIDDEN")
        else
            minercentralIP = clientIP
            nodenet.sendClient(clientIP, clientPort, "OK")
            print("Miner central controller detected and registered.")
        end
    elseif parsed[1] == "NOT_IMPLEMENTED" then
        return
    else
        nodenet.sendClient(clientIP, clientPort, "NOT_IMPLEMENTED")
    end
end

function nodenet.newBlock(clientIP, clientPort, block)
    local file = io.open("bak.txt", "w")
    file:seek("end")
    file:write("\n")
    file:write(serial.serialize(block))
    file:close()
    if not block or not block.height then
        return false
    end
    if
        cacheLib.getlastBlock() ~= "error" and
            block.height <= (storage.loadBlock(cacheLib.getlastBlock()) or {height = -math.huge}).height
     then
        print("Block " .. block.uuid .. " rejected due to not enough height")
        nodenet.sendClient(clientIP, clientPort, "NOT_ENOUGH_HEIGHT")
    elseif block.previous == nil then
        print("Orphaned block " .. block.uuid .. " rejected")
        nodenet.sendClient(clientIP, clientPort, "INVALID_BLOCK")
    elseif block.previous ~= cacheLib.getlastBlock() then -- We need more blocks!
        print("Attempting to locate parent blocks of block " .. block.uuid .. "...")
        local result = nodenet.newUnknownBlock(clientIP, clientPort, block)
        if result == false then
            print("Orphaned block " .. block.uuid .. " rejected")
            nodenet.sendClient(clientIP, clientPort, "ERR_BLOCKS_REJECTED")
        elseif (cache.minerNode) then
            newBlock(storage.loadBlock(cacheLib.getlastBlock()))
        end
    elseif not verifyBlock(block) then
        print("Block " .. block.uuid .. " rejected due to being invalid")
        nodenet.sendClient(clientIP, clientPort, "INVALID_BLOCK")
    else
        consolidateBlock(block)
        print("Added new block with id " .. block.uuid .. "at height" .. block.height)
        nodenet.sendClient(clientIP, clientPort, "BLOCK_ACCEPTED")
        if (cache.minerNode) then
            newBlock(storage.loadBlock(cacheLib.getlastBlock()))
        end
        return true
    end
    return false
end

local requestBlock = function(client, port, blockUUID)
    nodenet.sendClient(client, port, "GETBLOCK###"..blockUUID)
    for k = 1,5 do
        local _,_,res = napi.listentoclient(modem, cache.myPort, client, 2)
        res = explode("####",res)
        if res[1] == "OK" then
            return serial.unserialize(res[2])
        end
    end
    return nil
end

local cleanBlocks = function(blockIds)
    for _,v in pairs(blockIds) do
        storage.deleteBlock(v)
    end
end

function nodenet.newUnknownBlock(clientIP, clientPort, block)
    if block.height == 0 then
        print("Genesis block received!")
        local result = reconstructUTXOFromZero(blockIds, block)
    end

    local blockIds = {}
    local b = block
    blockIds[b.height] = b
    storage.saveBlock(b)
    while cache.blocks[block.height] ~= block.uuid and b.height > 0 do
        b = requestBlock(clientIP, clientPort, block.previous)
        if b==nil then
            cleanBlocks(blockIds)
            return false
        end
        blockIds[b.height] = b
        storage.saveBlock(b)
    end
    local lastblock = storage.loadBlock(cache.lb) or {height=1}
    if b.height==0 or b.height < (lastblock.height - lastblock.height%10) then
        local result = reconstructUTXOFromZero(blockIds, b)
        if (not result) then
            nodenet.sendClient(clientIP, clientPort, "INVALID_BLOCKS")
        else
            nodenet.sendClient(clientIP, clientPort, "BLOCK_ACCEPTED")
            return true
        end
    else
        local result = reconstructUTXOFromCache(blockIds, b, lastblock.height - lastblock.height%10)
        if (not result) then
            nodenet.sendClient(clientIP, clientPort, "INVALID_CHAIN")
        else
            nodenet.sendClient(clientIP, clientPort, "BLOCK_ACCEPTED")
            return true
        end
    end
    cleanBlocks(blockIds)
    return false
end

return nodenet
