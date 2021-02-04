local data = component.data
storage = require("storage")

local cache = {}
cache.lb = "error"
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

function getCurrDifficulty()
    local lb = storage.loadBlock(cache.getlastBlock())
    if lb.height%50 != 0 then return lb.target end
    
    local tenblocksago = lb
    for k=1,50 do
        tenblocksago = storage.loadBlock(tenblocksago.previous)
    end
    local timeDiff = (lb.timestamp - tenblocksago.timestamp)*1000/60/60/20
    local correctionFactor = (15000/timeDiff)
    if correctionFactor > 4 then correctionFactor = 4 end
    if correctionFactor < 0.25 then correctionFactor = 0.25 end
    return lb.target * correctionFactor
end

function getCurrReward()
    local lb = storage.loadBlock(cache.getlastBlock())
    local halvings = math.floor(lb.height/1000)
    return math.floor(50000000 / 2^halvings)
end

function verifyTransaction(t)
    if not t.id or not t.from or not t.to or not t.qty or not t.sources or not t.rem or not t.sig then return false end
    if not data.ecdsa(t.id .. t.from .. t.to .. t.qty .. serialization.serialize(sources) .. t.rem, t.from, t.sig) then return false end
    
    if (t.sources == nil) then return "gen" end
    local inputSum = 0
    for _,v in ipairs(t.sources) do
        if v.from == t.from then --This is a remainder
            if not storage.remutxopresent(v.id) then return false end
            inputSum = inputSum + v.rem
        else -- This is a normal transaction
            if not storage.utxopresent(v.id) then return false end
            if v.to ~= t.from then return false end
            inputSum = inputSum + v.qty
        end
    end
    if inputSum ~= t.qty + t.rem then return false end
    return true
end

function verifyBlock(block)
    if not block.uuid or not block.nonce or not block.height or not block.timestamp or not block.previous or not block.transactions or not block.target then return false end
    if (#block.uuid ~= 16) then return false end
    if block.target ~= getCurrDifficulty() then return false end
    
    if block.height > 0 then --Exception: there's no previous block for genesis block!
        local prev = storage.loadBlock(block.previous)
        if prev==nil then return false end
        if prev.height ~= block.height-1 then return false end
        if prev.timestamp >= block.timestamp then return false end
    end
    
    if tonumber(tohex(data.sha256(block.nonce .. block.height .. block.timestamp .. block.previous .. serialization.serialize(block.transactions))),16) > block.target then return false end
    local genFound = false
    for _,v in ipairs(block.transactions) do
        result = verifyTransaction(v)
        if result==false then return false end
        if result=="gen" then
            if v.qty ~= getCurrReward() then return false end
            if genFound == true then return false
            else genFound = true end
        end
     end
    return true
end

function consolidateBlock(block)
    cache.setlastBlock(block.uuid)
    for _,t in ipairs(block.transactions) do -- update UTXO list
        if t.sources==nil then storage.saveutxo(t.id)
        else
            for _,s in ipairs(t.sources) do
                if s.from==t.from then storage.removeremutxo(s.id)
                else storage.removeutxo(s.id) end
            end
        end
    end
    storage.saveBlock(block) -- save block in database
    if (block.height%10==0) then storage.cacheutxo() end -- Every 10 blocks do an UTXO cache
end

function reconstructUTXOFromZero(lk, newblocks)
    
end

function reconstructUTXOFromCache(lk, newblocks)
    
end