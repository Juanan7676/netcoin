component = require("component")
local data = component.data
local storage = require("storage")
local serial = require("serialization")
filesys = require("filesystem")

cache = {}
cache.lb = "error"
cache.nodes = {}
cache.contacts = {}
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
function cache.loadContacts()
    local file = io.open("contacts.txt","r")
    cache.contacts = serial.unserialize(file:read("*a"))
    file:close()
end
function cache.saveContacts()
    local file = io.open("contacts.txt","w")
    file:write(serial.serialize(cache.contacts))
    file:close()
end

function getNextDifficulty(fbago,block)
    if block.height==0 then return tonumber((2^250).."") end -- Difficulty for genesis block
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

function getTransactionFromBlock(block,uid)
    for _,t in ipairs(block.transactions) do
        if t.id == uid then return t end
    end
    return nil
end

function searchBlockInList(list,uid)
    for _,b in pairs(list) do
        if b.id==uid then return b end
    end
    return nil
end

function verifyTransaction(t, up, rup, newBlocks)
    if not t.id or not t.from or not t.to or not t.qty or not t.sources or not t.rem or not t.sig then return false end
    if t.qty <= 0 or t.rem < 0 then print("invalid qty or rem") return false end
    if #t.sources > 0 then
        local pk = data.deserializeKey(t.from,"ec-public")
        if pk==nil then print("invalid public key") return false end
        if not data.ecdsa(t.id .. t.from .. t.to .. t.qty .. serial.serialize(sources) .. t.rem,pk, t.sig)  then print("invalid signature") return false end
    end
    
    if (#t.sources == 0) then return "gen" end
    local inputSum = 0
    for _,v in ipairs(t.sources) do
        local trans, block
        local rem = false
        local utxoblock = up(v)
        if utxoblock ~= nil then
            block = storage.loadBlock(utxoblock)
            if block==nil then
                if newBlocks==nil then print("stored utxo block not found on chain") return false end
                block = searchBlockInList(newBlocks,utxoblock)
                if block==nil then print("could not find utxo block on list") return false end
            end
        else
            remutxoblock = rup(v)
            if remutxoblock==nil then print("uxto not found") return false 
            else
                block = storage.loadBlock(remutxoblock)
                if block==nil then
                    if newBlocks==nil then print("stored utxo block not found on chain") return false end
                    block = searchBlockInList(newBlocks,remutxoblock)
                    if block==nil then print("could not find utxo block on list") return false end
                end
                rem = true
            end
        end
        
        trans = getTransactionFromBlock(block,v)
        if trans==nil then print("transaction not found on block") return false end
        
        if trans.from == t.from and rem then --This is a remainder
            inputSum = inputSum + trans.rem
        elseif not rem then -- This is a normal transaction
            if trans.to ~= t.from then print("source not matches") return false end
            inputSum = inputSum + trans.qty
        else print("treating a remainder as a normal trans or viceversa") return false
        end
    end
    if inputSum ~= t.qty + t.rem then print("amounts IN and OUT do not match") return false end
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
    if (n==0) then return block end
    local fbago = block
    for k=1,n do
        local tmp = blocks[k+1]
        if tmp==nil then
            fbago = storage.loadBlock(fbago.previous)
            if fbago==nil then return nil end
            if fbago.height==0 and k < n then return nil end
        else
            fbago = tmp
        end
    end
    return fbago
end

function verifyTransactions(block, tmp, blocks)
    local genFound = false
    for _,v in ipairs(serial.unserialize(block.transactions)) do
        if (tmp==nil) then result = verifyTransaction(v, storage.utxopresent, storage.remutxopresent)
        else result = verifyTransaction(v, storage.tmputxopresent, storage.tmpremutxopresent, blocks) end
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
    if tonumber(tohex(data.sha256(block.nonce .. block.height .. block.timestamp .. block.previous .. block.transactions)),16) > block.target then return false end
    
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
    if tonumber(tohex(data.sha256(block.nonce .. block.height .. block.timestamp .. block.previous .. block.transactions)),16) > block.target then print("invalid pow "..block.uuid) return false end
    
    if not verifyTransactions(block, true, blocks) then print("invalid transactions") return false end
    return true
end

function updateutxo(block)
for _,t in ipairs(serial.unserialize(block.transactions)) do -- update UTXO list
        if t.sources~=nil then
            for _,s in ipairs(t.sources) do
                if s.from==t.from then 
                    storage.removeremutxo(s.id)
                    if (t.from==walletPK.serialize()) then storage.removewalletremutxo(s.id) end
                else 
                    storage.removeutxo(s.id)
                    if (t.from==walletPK.serialize()) then storage.removewalletutxo(s.id) end
                end
            end
        end
        storage.saveutxo(t.id, block.uuid)
        if (t.rem>0) then storage.saveremutxo(t.id) end
        
        if (t.to==cache.walletPK.serialize() and t.qty>0) then storage.savewalletutxo(t.id, block.uuid) end
        if (t.from==walletPK.serialize() and t.rem>0) then storage.savewalletremutxo(t.id, block.uuid) end
    end
end

function updatetmputxo(block)
for _,t in ipairs(serial.unserialize(block.transactions)) do -- update UTXO list
        if t.sources~=nil then
            for _,s in ipairs(t.sources) do
                if s.from==t.from then 
                    storage.tmpremoveremutxo(s.id)
                    if (t.from==walletPK.serialize()) then storage.tmpremovewalletremutxo(s.id) end
                else
                    if (t.from==walletPK.serialize()) then storage.tmpremovewalletutxo(s.id) end
                    storage.tmpremoveutxo(s.id) 
                end
            end
        end
        storage.tmpsaveutxo(t.id, block.uuid)
        if (t.rem>0) then storage.tmpsaveremutxo(t.id) end
        
        if (t.to==cache.walletPK.serialize() and t.qty>0) then storage.tmpsavewalletutxo(t.id, block.uuid) end
        if (t.from==cache.walletPK.serialize() and t.rem>0) then storage.tmpsavewalletremutxo(t.id, block.uuid) end
    end
end

function consolidateBlock(block)
    cache.setlastBlock(block.uuid)
    storage.saveBlock(block) -- save block in database
    if (block.height%10==0) then storage.cacheutxo() end -- Every 10 blocks do an UTXO cache
end

function reconstructUTXOFromZero(newblocks, lastblock)
    storage.setuptmpenvutxo()
    for k=0,lastblock.height do
        local block = getPrevList(lastblock,newblocks,lastblock.height-k)
        if not verifyTmpBlock(block,newblocks) then
            print("invalid block")
            storage.discardtmputxo()
            return false
        end
        updatetmputxo(block)
    end
    for _,b in ipairs(newblocks) do
        storage.saveBlock(b)
    end
    storage.consolidatetmputxo()
    cache.setlastBlock(lastblock.uuid)
    return true
end

function reconstructUTXOFromCache(newblocks, lastblock)
    storage.setuptmpenvutxo_cache()
    for k=lastblock.height - lastblock.height%10,lastblock.height do
        local block = getPrevList(lastblock,newblocks,lastblock.height-k)
        if not verifyTmpBlock(block,newblocks) then
            storage.discardtmputxo()
            return false
        end
        updatetmputxo(block)
    end
    for _,b in ipairs(newblocks) do
        storage.saveBlock(b)
    end
    storage.consolidatetmputxo()
    cache.setlastBlock(lastblock.uuid)
    return true
end