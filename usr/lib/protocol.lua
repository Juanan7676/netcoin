-- data: DataComponent
local component = {}

-- loadBlock(id: string): Block
-- saveBlock(block: Block): void
-- utxopresent(tx: Transaction): boolean
-- remutxopresent(tx: Transaction): boolean
-- tmputxopresent(tx: Transaction): boolean
-- tmpremutxopresent(tx: Transaction): boolean
-- tmpsaveutxo(txID: string, blockID: string): void
-- tmpsaveremutxo(txID: string, blockID: string): void
-- removeutxo(tx: Transaction): void
-- removeremutxo(tx: Transaction): void
-- removewalletutxto(tx: Transaction): void
-- removewalletremutxo(tx: Transaction): void
-- consolidatetmputxo(): void
-- setuptmpenvutxo(): void
-- discardtmputxo(): void
local storage = {}

-- serialize(obj: any): string
-- unserialize(data: string): any
local serial = {}
local filesys = {}

function protocolConstructor(componentProvider, storageProvider, serialProvider, filesysProvider)
    component = componentProvider
    storage = storageProvider
    serial = serialProvider
    filesys = filesysProvider
end

require("math.BigNum")

-- Constants used in the protocol
STARTING_DIFFICULTY = BigNum.new(2) ^ 240

cache = {}
cache.lb = "error"
cache.nodes = {}
cache.contacts = {}
function cache.getlastBlock()
    return cache.lb
end
function cache.loadlastBlock()
    local file = assert(io.open("lb.txt", "r"))
    cache.lb = file:read()
    file:close()
end
function cache.savelastBlock()
    local file = io.open("lb.txt", "w")
    file:write(cache.lb)
    file:close()
end
function cache.setlastBlock(uuid)
    cache.lb = uuid
    cache.savelastBlock()
end
function cache.loadNodes()
    local file = assert(io.open("nodes.txt", "r"))
    cache.nodes = serial.unserialize(file:read("*a"))
    file:close()
end
function cache.saveNodes()
    local file = assert(io.open("nodes.txt", "w"))
    file:write(serial.serialize(cache.nodes))
    file:close()
end
function cache.loadContacts()
    local file = assert(io.open("contacts.txt", "r"))
    cache.contacts = serial.unserialize(file:read("*a"))
    file:close()
end
function cache.saveContacts()
    local file = io.open("contacts.txt", "w")
    file:write(serial.serialize(cache.contacts))
    file:close()
end
function cache.loadBalances()
    local file = io.open("balances.txt", "r")
    if file == nil then
        cache.tb = 0
        cache.pb = 0
    else
        cache.tb = serial.unserialize(file:read())
        cache.pb = serial.unserialize(file:read())
        file:close()
    end
end
function cache.saveBalances()
    local file = io.open("balances.txt", "w")
    file:write(serial.serialize(cache.tb) .. "\n")
    file:write(serial.serialize(cache.pb) .. "\n")
    file:close()
end
function cache.loadPendingTransactions()
    local file = io.open("pt.txt", "r")
    if file == nil then
        cache.pt = {}
    else
        cache.pt = serial.unserialize(file:read("*a"))
        file:close()
    end
end
function cache.savePendingTransactions()
    local file = io.open("pt.txt", "w")
    file:write(serial.serialize(cache.pt) .. "\n")
    file:close()
end
function cache.loadRecentTransactions()
    local file = io.open("rt.txt", "r")
    if file == nil then
        cache.rt = {}
    else
        cache.rt = serial.unserialize(file:read("*a"))
        file:close()
    end
end
function cache.saveRecentTransactions()
    local file = io.open("rt.txt", "w")
    file:write(serial.serialize(cache.rt) .. "\n")
    file:close()
end
function cache.loadTranspool()
    local file = io.open("transpool.txt", "r")
    if file == nil then
        cache.transpool = {}
    else
        cache.transpool = serial.unserialize(file:read("*a"))
        file:close()
    end
end
function cache.saveTranspool()
    local file = io.open("transpool.txt", "w")
    file:write(serial.serialize(cache.transpool) .. "\n")
    file:close()
end
function cache.updateTransactionCache()
    for k, v in pairs(cache.pt) do
        if v.confirmations >= 3 then
            if v.to == cache.walletPK.serialize() then
                cache.tb = cache.tb + v.qty
            elseif v.from == cache.walletPK.serialize() then
                cache.tb = cache.tb + v.rem
                cache.tb = cache.tb - v.qty
            end
            cache.pt[k] = nil
            table.remove(cache.rt, 1)
            table.insert(cache.rt, v)
        else
            cache.pt[k].confirmations = v.confirmations + 1
        end
    end
end
function cache.updateTmpTransactionCache()
    for k, v in pairs(cache._pt) do
        if v.confirmations >= 3 then
            if v.to == cache.walletPK.serialize() then
                cache._tb = cache._tb + v.qty
            elseif v.from == cache.walletPK.serialize() then
                cache._tb = cache._tb + v.rem
                cache._tb = cache._tb - v.qty
            end
            cache._pt[k] = nil
            table.remove(cache._rt, 1)
            table.insert(cache._rt, v)
        else
            cache._pt[k].confirmations = v.confirmations + 1
        end
    end
end

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
    local quotient, _ = (fbago.target * BigNum.new(correctionFactor * 100)) / BigNum.new(100)
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

function searchBlockInList(list, uid)
    for _, b in pairs(list) do
        if b.uuid == uid then
            return b
        end
    end
    return nil
end

function hashTransactions(transaction_table)
    local hash = ""
    table.sort(
        transaction_table,
        function(a, b)
            return a.id < b.id
        end
    )
    for _, t in ipairs(transaction_table) do
        hash = component.data.sha256(hash .. t.id .. t.from .. t.to .. t.qty .. t.rem .. t.sig)
        table.sort(
            t.sources,
            function(a, b)
                return a < b
            end
        )
        for _, v in ipairs(t.sources) do
            hash = component.data.sha256(hash .. v)
        end
    end
    return hash
end

function concatenateSources(sources_table)
    local ret = ""
    table.sort(
        sources_table,
        function(a, b)
            return a < b
        end
    )
    for _, t in ipairs(sources_table) do
        ret = ret .. t
    end
    return ret
end

function verifyTransaction(t, up, rup, newBlocks)
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
                t.id .. t.from .. t.to .. t.qty .. concatenateSources(t.sources) .. t.rem,
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
        local trans, block
        local rem = false
        local normal = false
        local utxoblock = up(v)
        if utxoblock ~= nil and utxoblock ~= false then
            block = storage.loadBlock(utxoblock)
            if block == nil then
                if newBlocks == nil then
                    print("stored utxo block not found on chain")
                    return false
                end
                block = searchBlockInList(newBlocks, utxoblock)
                if block == nil then
                    print("could not find utxo block on list")
                    return false
                end
            end
            normal = true
        end

        local remutxoblock = rup(v)
        if remutxoblock ~= nil and remutxoblock ~= false then
            block = storage.loadBlock(remutxoblock)
            if block == nil then
                if newBlocks == nil then
                    print("stored utxo block not found on chain")
                    return false
                end
                block = searchBlockInList(newBlocks, remutxoblock)
                if block == nil then
                    print("could not find utxo block on list")
                    return false
                end
            end
            rem = true
        end

        if not rem and not normal then
            print("could not find utxo")
            return false
        end

        trans = getTransactionFromBlock(block, v)
        if trans == nil then
            print("transaction not found on block")
            return false
        end

        if trans.from == t.from and rem then --This is a remainder
            inputSum = inputSum + trans.rem
        elseif not rem then -- This is a normal transaction
            if trans.to ~= t.from then
                print("source not matches")
                return false
            end
            inputSum = inputSum + trans.qty
        else
            print("treating a remainder as a normal trans or viceversa")
            return false
        end
    end
    if inputSum ~= t.qty + t.rem then
        print("amounts IN and OUT do not match")
        return false
    end
    return true
end

function getPrevChain(block, n)
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

function getPrevList(block, blocks, n)
    if (n == 0) then
        return block
    end
    local fbago = block
    local start = 0
    for i = 1, #blocks do
        if blocks[i].uuid == block.uuid then
            start = i
            break
        end
    end
    --assert(start ~= 0)

    for k = 1, n do
        local tmp = blocks[k + start]
        if tmp == nil then
            fbago = storage.loadBlock(fbago.previous)
            if fbago == nil then
                return nil
            end
            if fbago.height == 0 and k < n then
                return nil
            end
        else
            fbago = tmp
        end
    end
    return fbago
end

function verifyTransactions(block, tmp, blocks)
    local genFound = false
    for _, v in ipairs(block.transactions) do
        if (tmp == nil) then
            result = verifyTransaction(v, storage.utxopresent, storage.remutxopresent)
        else
            result = verifyTransaction(v, storage.tmputxopresent, storage.tmpremutxopresent, blocks)
        end
        if result == false then
            return false
        end
        if result == "gen" then
            if v.qty ~= getReward(block.height) then
                return false
            end
            if genFound == true then
                return false
            else
                genFound = true
            end
        end
    end
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
        component.data.sha256(block.height .. block.timestamp .. block.previous .. hashTransactions(block.transactions))
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

function verifyTmpBlock(block, blocks)
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
        component.data.sha256(block.height .. block.timestamp .. block.previous .. hashTransactions(block.transactions))
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

    if block.height > 0 then --Exception: there's no previous block for genesis block!
        local prev = getPrevList(block, blocks, 1)
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

    local fbago = getPrevList(block, blocks, 50)
    if BigNum.new(block.target) ~= BigNum.new(getNextDifficulty(fbago, getPrevList(block, blocks, 1))) then
        print("invalid difficulty")
        return false
    end

    if BigNum.fromHex(tohex(component.data.sha256(headerHash .. block.nonce))) > BigNum.new(block.target) then
        print("invalid pow " .. block.uuid)
        return false
    end

    if not verifyTransactions(block, true, blocks) then
        print("invalid transactions")
        return false
    end
    return true
end

function updateutxo(block)
    cache.updateTransactionCache()
    for _, t in ipairs(block.transactions) do -- update UTXO list
        if t.sources ~= nil then
            for _, s in ipairs(t.sources) do
                local trans
                local sourceblock = storage.utxopresent(s)
                if sourceblock ~= false then
                    trans = getTransactionFromBlock(storage.loadBlock(sourceblock), s)
                else
                    sourceblock = storage.remutxopresent(s)
                    if sourceblock == false then
                        print("source is neither an UTXO nor a REMUTXO!")
                        return nil
                    end
                    trans = getTransactionFromBlock(storage.loadBlock(sourceblock), s)
                end

                if trans.from == t.from then
                    storage.removeremutxo(s)
                    if (t.from == cache.walletPK.serialize()) then
                        storage.removewalletremutxo(s)
                        cache.pb = cache.pb - trans.rem
                    end
                end
                if trans.to == t.from then
                    storage.removeutxo(s)
                    if (t.from == cache.walletPK.serialize()) then
                        storage.removewalletutxo(s)
                        cache.pb = cache.pb - trans.qty
                    end
                end
            end
        end
        storage.saveutxo(t.id, block.uuid)
        if (t.rem > 0) then
            storage.saveremutxo(t.id, block.uuid)
        end

        if (t.to == cache.walletPK.serialize() and t.qty > 0) then
            storage.savewalletutxo(t.id, block.uuid)
            cache.pb = cache.pb + t.qty
            t.confirmations = 0
            cache.pt[t.id] = t
        end
        if (t.from == cache.walletPK.serialize() and t.rem > 0) then
            storage.savewalletremutxo(t.id, block.uuid)
            cache.pb = cache.pb + t.rem
            trans.confirmations = 0
            cache.pt[t.id] = t
        end
    end
    cache.saveBalances()
    cache.savePendingTransactions()
    cache.saveRecentTransactions()
end

function updatetmputxo(block)
    cache.updateTmpTransactionCache()
    for _, t in ipairs(block.transactions) do -- update UTXO list
        if t.sources ~= nil then
            for _, s in ipairs(t.sources) do
                local trans
                local sourceblock = storage.tmputxopresent(s)
                if sourceblock ~= false then
                    trans = getTransactionFromBlock(storage.loadBlock(sourceblock), s)
                else
                    sourceblock = storage.tmpremutxopresent(s)
                    if sourceblock == false then
                        print("source is neither an UTXO nor a REMUTXO!")
                        return nil
                    end
                    trans = getTransactionFromBlock(storage.loadBlock(sourceblock), s)
                end

                if trans.from == t.from then
                    storage.tmpremoveremutxo(s)
                    if (t.from == cache.walletPK.serialize()) then
                        storage.tmpremovewalletremutxo(s)
                        cache._pb = cache._pb - trans.rem
                    end
                else
                    if (t.from == cache.walletPK.serialize()) then
                        storage.tmpremovewalletutxo(s)
                        cache._pb = cache._pb - trans.qty
                    end
                    storage.tmpremoveutxo(s)
                end
            end
        end
        storage.tmpsaveutxo(t.id, block.uuid)
        if (t.rem > 0) then
            storage.tmpsaveremutxo(t.id, block.uuid)
        end

        if (t.to == cache.walletPK.serialize() and t.qty > 0) then
            storage.tmpsavewalletutxo(t.id, block.uuid)
            cache._pb = cache._pb + t.qty
            t.confirmations = 0
            cache._pt[t.id] = t
        end
        if (t.from == cache.walletPK.serialize() and t.rem > 0) then
            storage.tmpsavewalletremutxo(t.id, block.uuid)
            cache._pb = cache._pb + t.rem
            trans.confirmations = 0
            cache._pt[t.id] = t
        end
    end
end

function consolidateBlock(block)
    cache.setlastBlock(block.uuid)
    storage.saveBlock(block) -- save block in database
    updateutxo(block) -- update UTXO transactions of this block
    if (block.height % 10 == 0) then
        storage.cacheutxo()
    end -- Every 10 blocks do an UTXO cache
    cache.savePendingTransactions()
    cache.saveRecentTransactions()
    cache.saveBalances()
end

function reconstructUTXOFromZero(newblocks, lastblock)
    storage.setuptmpenvutxo()
    for k = 0, lastblock.height do
        local block = getPrevList(lastblock, newblocks, lastblock.height - k)
        if not verifyTmpBlock(block, newblocks) then
            print("invalid block")
            storage.discardtmputxo()
            for _, b in pairs(newblocks) do
                storage.deleteBlock(b.uuid)
            end
            return false
        end
        storage.saveBlock(block)
        updatetmputxo(block)
    end
    storage.consolidatetmputxo()
    cache.setlastBlock(lastblock.uuid)
    cache.savePendingTransactions()
    cache.saveRecentTransactions()
    cache.saveBalances()
    return true
end

function reconstructUTXOFromCache(newblocks, lastblock)
    storage.setuptmpenvutxo_cache()
    for k = lastblock.height - lastblock.height % 10, lastblock.height do
        local block = getPrevList(lastblock, newblocks, lastblock.height - k)
        if not verifyTmpBlock(block, newblocks) then
            storage.discardtmputxo()
            for _, b in pairs(newblocks) do
                storage.deleteBlock(b.uuid)
            end
            return false
        end
        storage.saveBlock(block)
        updatetmputxo(block)
    end
    storage.consolidatetmputxo()
    cache.setlastBlock(lastblock.uuid)
    cache.savePendingTransactions()
    cache.saveRecentTransactions()
    cache.saveBalances()
    return true
end
