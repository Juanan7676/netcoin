local hashService = require("math.hashService")

-- data: DataComponent
local component = {}

-- loadBlock(id: string): Block
-- saveBlock(block: Block): void
-- consolidatetmputxo(): void
-- setuptmpenvutxo(): void
-- discardtmputxo(): void
local storage = {}

-- serialize(obj: any): string
-- unserialize(data: string): any
local serial = {}

---@class Transaction
---@class TransactionProof
---@class Accumulator

---@class UtxoProvider
---@field addNormalUtxo fun(tx: Transaction, bH: number): nil
---@field addRemainderUtxo fun(tx: Transaction, bH: number): nil
---@field deleteUtxo fun(proof: TransactionProof): nil
---@field getUtxos fun(): TransactionProof[]
---@field setUtxos fun(arr: TransactionProof[]): nil
---@field setupZeroEnv fun(): nil
---@field setupTmpEnv fun(): nil
---@field discardTmpEnv fun(): nil
---@field consolidateTmpEnv fun(): nil
---@field iterator fun(minH: number, maxH: number, minX: number, maxX: number): function
local utxoProvider = {}

---@class Updater
---@field saveNormalUtxo fun(acc: Accumulator, tx: Transaction): Accumulator
---@field saveRemainderUtxo fun(acc: Accumulator, tx: Transaction): Accumulator
---@field deleteutxo fun(acc: Accumulator, proof: TransactionProof): Accumulator | false | nil
---@field setupTmpEnv fun(): nil
---@field discardTmpEnv fun(): nil
---@field consolidateTmpEnv fun(): nil
local updater = {}

---@param utxProv UtxoProvider
---@param updProv Updater
function protocolConstructor(componentProvider, storageProvider, serialProvider, updProv, utxProv)
    component = componentProvider
    storage = storageProvider
    serial = serialProvider
    updater = updProv
    utxoProvider = utxProv
end

require("math.BigNum")

-- Constants used in the protocol
STARTING_DIFFICULTY = BigNum.new(2) ^ 240

function getNextDifficulty(fbago, block)
    if block == nil then
        return STARTING_DIFFICULTY
    end -- Difficulty for genesis block
    if block.height == 0 then
        return STARTING_DIFFICULTY
    end -- Difficulty for genesis block
    if block.height % 50 ~= 0 or block.height == 0 then
        return block.target
    end

    local timeDiff = (block.timestamp - fbago.timestamp) * 1000 / 60 / 60 / 20
    local correctionFactor = (timeDiff / 15000)
    if correctionFactor > 4 then
        correctionFactor = 4
    end
    if correctionFactor < 0.25 then
        correctionFactor = 0.25
    end
    local quotient = (fbago.target * BigNum.new(correctionFactor * 100)) // BigNum.new(100)
    return quotient
end

function getReward(height)
    local halvings = math.floor(height / 1000)
    return math.floor(50000000 / 2 ^ halvings)
end

function getTransactionFromBlock(block, uid)
    if not block then
        return nil
    end
    for _, t in ipairs(block.transactions) do
        if t.id == uid then
            return t
        end
    end
    return nil
end

function hashSources(sources_table)
    local hash = ""
    table.sort(
        sources_table,
        function(a, b)
            return a.txid < b.txid
        end
    )
    for _, t in ipairs(sources_table) do
        hash = hashService.hash(hash .. t.height .. t.txid .. t.proof.baseHash .. t.proof.index)
        for _,v in ipairs(t.proof.hashes) do
            hash = hashService.hash(hash .. v)
        end
    end
    return hash
end

function loadFromHeight(height, id)
    local block = storage.loadBlock(cache.blocks[height])
    for _,v in ipairs(block.transactions) do
        if v.id == id then return v end
    end
    return nil
end

local verifySource = function(source, from)
    if (source.height == nil or source.proof == nil or source.txid == nil) then return false end
    
    local transaction = loadFromHeight(source.height, source.txid)
    if transaction == nil then return false end
    if transaction.to == from then
        local hash = hashService.hashData(transaction.id, transaction.to, transaction.qty)
        if hash ~= source.proof.baseHash then return false end
        if not updater.deleteutxo(cache.acc, source) then return false end
        return transaction.qty
    end
    if transaction.from == from then
        local hash = hashService.hashData(transaction.id, transaction.from, transaction.rem)
        if hash ~= source.proof.baseHash then return false end
        if not updater.deleteutxo(cache.acc, source) then return false end
        return transaction.rem
    end
    return false
end

function verifyTransaction(t)
    if not t.id or not t.from or not t.to or not t.qty or not t.sources or not t.rem or not t.sig then
        return false
    end
    if t.qty <= 0 or t.rem < 0 then
        print("invalid qty or rem")
        return false
    end
    if #t.sources > 0 then
        local pk = component.data.deserializeKey(t.from, "ec-public")
        if pk == nil then
            print("invalid public key")
            return false
        end
        if
            not component.data.ecdsa(
                t.id .. t.from .. t.to .. t.qty .. hashSources(t.sources) .. t.rem,
                pk,
                t.sig
            )
         then
            print("invalid signature")
            return false
        end
    end

    if (#t.sources == 0) then
        return "gen"
    end

    local inputSum = 0
    for _, v in ipairs(t.sources) do

        local res = verifySource(v, t.from)
        if res==false then return false end
        inputSum = inputSum + res
    end
    if inputSum ~= t.qty + t.rem then
        print("amounts IN and OUT do not match")
        return false
    end
    return true
end

local getPrevChain = function(block, n)
    local fbago = block
    for k = 1, n do
        fbago = storage.loadBlock(fbago.previous)
        if fbago == nil then
            return nil
        end
        if fbago.height == 0 then
            return fbago
        end
    end
    return fbago
end

local verifyTransactions = function(block)
    local genFound = false
    updater.setupTmpEnv()
    for _, v in ipairs(block.transactions) do
        local result = verifyTransaction(v)
        if result == false then
            updater.discardTmpEnv()
            return false
        end
        if result == "gen" then
            if v.qty ~= getReward(block.height) then
                updater.discardTmpEnv()
                return false
            end
            if genFound == true then
                updater.discardTmpEnv()
                return false
            else
                genFound = true
            end
        end
    end
    updater.discardTmpEnv()
    return true
end

function verifyBlock(block)
    if
        not block.uuid or not block.nonce or not block.height or not block.timestamp or not block.previous or
            not block.transactions or
            not block.target
     then
        print("malformed block")
        return false
    end
    if (#block.uuid ~= 64) then
        print("malformed uuid")
        return false
    end
    local headerHash =
        tohex(
        component.data.sha256(block.height .. block.timestamp .. block.previous .. hashService.hashTransactions(block.transactions))
    )
    if (headerHash ~= block.uuid) then
        print("invalid uuid")
        return false
    end

    if (block.height < 0) then
        print("invalid height")
        return false
    end
    if (block.timestamp > os.time()) then
        print("timestamp from the future")
        return false
    end

    if (#serial.serialize(block) > 5000) then
        print("block too large")
        return false
    end

    if block.height > 0 then --Exception: there's no previous block for genesis block!
        local prev = getPrevChain(block, 1)
        local file = io.open("prevbak.txt", "w")
        file:write(serial.serialize(prev))
        file:close()
        if prev == nil then
            print("previous block not found")
            return false
        end
        if prev.height ~= block.height - 1 then
            print(
                "invalid height: prev is " ..
                    prev.uuid .. " height " .. prev.height .. ", block is " .. block.uuid .. " height " .. block.height
            )
            return false
        end
        if prev.timestamp >= block.timestamp then
            print("invalid timestamp")
            return false
        end
    end

    local fbago = getPrevChain(block, 50)
    if BigNum.new(block.target) ~= BigNum.new(getNextDifficulty(fbago, getPrevChain(block, 1))) then
        print("invalid difficulty")
        return false
    end

    if BigNum.fromHex(tohex(component.data.sha256(headerHash .. block.nonce))) > BigNum.new(block.target) then
        print("invalid pow " .. block.uuid)
        return false
    end

    if not verifyTransactions(block) then
        print("invalid transactions")
        return false
    end
    return true
end

local updateutxo = function(block)
    cacheLib.updateTransactionCache()
    for _, t in ipairs(block.transactions) do -- update UTXO list
        if (t.from == cache.walletPK.serialize()) then
            cache.tb = cache.tb - t.qty + t.rem
        end
        if t.sources ~= nil then
            for _, s in ipairs(t.sources) do
                local result = updater.deleteutxo(cache.acc, s)
                if result==false then return nil end

                if (t.from == cache.walletPK.serialize()) then
                    utxoProvider.deleteUtxo(s)
                end
            end
        end
        if (t.qty > 0) then updater.saveNormalUtxo(cache.acc, t) end
        if (t.rem > 0) then updater.saveRemainderUtxo(cache.acc, t) end

        if (t.to == cache.walletPK.serialize() and t.qty > 0) then
            utxoProvider.addNormalUtxo(t, block.height)
            cache.tb = cache.tb + t.qty
            t.confirmations = 0
            cache.pt[t.id] = t
        end
        if (t.from == cache.walletPK.serialize() and t.rem > 0) then
            utxoProvider.addRemainderUtxo(t, block.height)
            cache.tb = cache.tb + t.rem
            t.confirmations = 0
            cache.pt[t.id] = t
        end
    end
    cacheLib.save()
end

function consolidateBlock(block)
    cacheLib.setlastBlock(block.uuid)
    storage.saveBlock(block) -- save block in database
    updateutxo(block) -- update UTXO transactions of this block
    if (block.height % 10 == 0) then
        storage.cacheutxo()
    end -- Every 10 blocks do an UTXO cache
    cache.blocks[block.height] = block.uuid
    cacheLib.save()
end

function reconstructUTXOFromZero(newblocks, lastblock)
    updater.setupTmpEnv()
    utxoProvider.setupZeroEnv()
    for k = 0, lastblock.height do
        local block
        if newblocks[k] ~= nil then block = storage.loadBlock(newblocks[k])
        else block = storage.loadBlock(cache.blocks[k]) end
        if not verifyBlock(block) then
            print("invalid block")
            updater.discardTmpEnv()
            utxoProvider.discardTmpEnv()
            for _, b in ipairs(newblocks) do
                storage.deleteBlock(b.uuid)
            end
            return false
        end
        updateutxo(block)
    end
    updater.consolidateTmpEnv()
    utxoProvider.consolidateTmpEnv()
    cacheLib.setlastBlock(lastblock.uuid)
    cacheLib.save()
    return true
end

function reconstructUTXOFromCache(newblocks, lastblock, cacheHeight)
    updater.setupTmpEnv()
    storage.setuptmpenvutxo_cache()
    for k = cacheHeight, lastblock.height do
        local block
        if newblocks[k] ~= nil then block = storage.loadBlock(newblocks[k])
        else block = storage.loadBlock(cache.blocks[k]) end
        if not verifyBlock(block) then
            storage.discardtmputxo()
            for _, b in pairs(newblocks) do
                storage.deleteBlock(b.uuid)
            end
            return false
        end
        updateutxo(block)
    end
    updater.consolidateTmpEnv()
    utxoProvider.consolidateTmpEnv()
    cacheLib.setlastBlock(lastblock.uuid)
    cacheLib.save()
    return true
end
