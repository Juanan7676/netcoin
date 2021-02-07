component = require("component")
local data = component.data
local storage = require("storage")
local serial = require("serialization")
filesys = require("filesystem")

cache = {}
cache.lb = "error"
cache.nodes = {}
function cache.getlastBlock()
    return cache.lb
end
function cache.loadlastBlock()
    local file = io.open("lb.txt","r")
    cache.lb = file:read()
    file:close()
end
function cache.savelastBlock()
    local file = io.open("lb.txt","w")
    file:write(cache.lb)
    file:close()
end
function cache.setlastBlock(uuid)
    cache.lb = uuid
    cache.savelastBlock()
end
function cache.loadNodes()
    local file = io.open("nodes.txt","r")
    cache.nodes = serial.unserialize(file:read("*a"))
    file:close()
end
function cache.saveNodes()
    local file = io.open("nodes.txt","w")
    file:write(serial.serialize(cache.nodes))
    file:close()
end

function getNextDifficulty(fbago,block)
    if block.height==0 then return tonumber((2^240).."") end -- Difficulty for genesis block
    if block.height%50 ~= 0 or block.height==0 then return block.target end
    
    local timeDiff = (block.timestamp - fbago.timestamp)*1000/60/60/20
    local correctionFactor = (15000/timeDiff)
    if correctionFactor > 4 then correctionFactor = 4 end
    if correctionFactor < 0.25 then correctionFactor = 0.25 end
    return tonumber((block.target * correctionFactor).."")
end

function getReward(height)
    local halvings = math.floor(height/1000)
    return math.floor(50000000 / 2^halvings)
end

function verifyTransaction(t, up, rup)
    if not t.id or not t.from or not t.to or not t.qty or not t.sources or not t.rem or not t.sig then return false end
    if not data.ecdsa(t.id .. t.from .. t.to .. t.qty .. serial.serialize(sources) .. t.rem, data.deserializeKey(t.from,"ec-public"), t.sig) then print("invalid signature") return false end
    
    if (#t.sources == 0) then return "gen" end
    local inputSum = 0
    for _,v in ipairs(t.sources) do
        if v.from == t.from then --This is a remainder
            if not up(v.id) then print("remainder not found") return false end
            inputSum = inputSum + v.rem
        else -- This is a normal transaction
            if not rup(v.id) then print("source not found") return false end
            if v.to ~= t.from then print("source not matches") return false end
            inputSum = inputSum + v.qty
        end
    end
    if inputSum ~= t.qty + t.rem then return false end
    return true
end

function getPrevChain(block, n)
    local fbago = block
        for k=1,n do
            fbago = storage.loadBlock(fbago.previous)
            if fbago.height==0 and k < n then return nil end
        end
        return fbago
end

function getPrevList(block, blocks, n)
    local fbago = block
        for k=1,n do
            fbago = blocks[k+1]
            if fbago==nil then fbago = storage.loadBlock(fbago.previous)
            if fbago.height==0 and k < n then return nil end
        end
        return fbago
    end
end

function verifyTransactions(block, tmp)
    local genFound = false
    for _,v in ipairs(block.transactions) do
        if (tmp==nil) then result = verifyTransaction(v, storage.utxopresent, storage.remutxopresent)
        else result = verifyTransaction(v, storage.tmputxopresent, storage.tmpremutxopresent) end
        if result==false then return false end
        if result=="gen" then
            if v.qty ~= getReward(block.height) then return false end
            if genFound == true then return false
            else genFound = true end
        end
     end
    return true
end

function verifyBlock(block)
    if not block.uuid or not block.nonce or not block.height or not block.timestamp or not block.previous or not block.transactions or not block.target then return false end
    if (#block.uuid ~= 16) then return false end
    
    if block.height > 0 then --Exception: there's no previous block for genesis block!
        local prev = getPrevChain(block,1)
        if prev==nil then return false end
        if prev.height ~= block.height-1 then return false end
        if prev.timestamp >= block.timestamp then return false end
    end
    
    local fbago = getPrevChain(block,50)
    if block.target ~= getNextDifficulty(fbago,block) then return false end
    if tonumber(tohex(data.sha256(block.nonce .. block.height .. block.timestamp .. block.previous .. serial.serialize(block.transactions))),16) > block.target then return false end
    
    if not verifyTransactions(block) then return false end
    return true
end

function verifyTmpBlock(block, blocks)
    if not block.uuid or not block.nonce or not block.height or not block.timestamp or not block.previous or not block.transactions or not block.target then return false end
    if (#block.uuid ~= 16) then return false end
    
    if block.height > 0 then --Exception: there's no previous block for genesis block!
        local prev = getPrevList(block,blocks,1)
        if prev==nil then return false end
        if prev.height ~= block.height-1 then return false end
        if prev.timestamp >= block.timestamp then return false end
    end
    
    local fbago = getPrevList(block,blocks,50)
    if block.target ~= getNextDifficulty(fbago,block) then print("invalid difficulty") return false end
    if tonumber(tohex(data.sha256(block.nonce .. block.height .. block.timestamp .. block.previous .. serial.serialize(block.transactions))),16) > block.target then print("invalid pow") return false end
    
    if not verifyTransactions(block, true) then print("invalid transactions") return false end
    return true
end

function updateutxo(block)
for _,t in ipairs(block.transactions) do -- update UTXO list
        if t.sources~=nil then
            for _,s in ipairs(t.sources) do
                if s.from==t.from then storage.removeremutxo(s.id)
                else storage.removeutxo(s.id) end
            end
        end
        storage.saveutxo(t.id)
    end
end

function updatetmputxo(block)
for _,t in ipairs(block.transactions) do -- update UTXO list
        if t.sources~=nil then
            for _,s in ipairs(t.sources) do
                if s.from==t.from then storage.tmpremoveremutxo(s.id)
                else storage.tmpremoveutxo(s.id) end
            end
        end
        storage.tmpsaveutxo(t.id)
    end
end

function consolidateBlock(block)
    cache.setlastBlock(block.uuid)
    storage.saveBlock(block) -- save block in database
    if (block.height%10==0) then storage.cacheutxo() end -- Every 10 blocks do an UTXO cache
end

function reconstructUTXOFromZero(newblocks, lastblock)
    for k=0,lastblock.height do
        local block = getPrevList(lastblock,newblocks,lastblock.height-k)
        if not verifyTmpBlock(block,newblocks) then
            print("invalid block")
            storage.discardtmputxo()
            return false
        end
        updatetmputxo(block)
    end
    storage.consolidatetmputxo()
    return true
end

function reconstructUTXOFromCache(newblocks, lastblock)
    filesys.copy("/mnt/"..(storage.utxoDisk).."/utxo_cached.txt","/mnt/"..(storage.utxoDisk).."/utxo.txt")
    filesys.copy("/mnt/"..(storage.utxoDisk).."/remutxo_cached.txt","/mnt/"..(storage.utxoDisk).."/remutxo.txt")
    
    for k=lastblock.height - lastblock.height%10,lastblock.height do
        local block = getPrevList(lastblock,newblocks,lastblock.height-k)
        if not verifyTmpBlock(block,newblocks) then
            storage.discardtmputxo()
            return false
        end
        updatetmputxo(block)
    end
    storage.consolidatetmputxo()
    return true
end