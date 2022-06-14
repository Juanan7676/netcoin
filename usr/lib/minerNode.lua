local component = require("component")
local serial = require("serialization")
local hs = require("math.hashService")

local updater = require("utreetxo.updater")
local utxoProvider = require("utreetxo.utxoProviderInMemory")

function newTransaction(t)
    cache.transpool[t.id] = t
end

function deleteTransaction(id)
    cache.transpool[id] = nil
end

minercentralIP = false

local getPrevChain = function(block, height)
    local newH = block.height - height
    if newH < 0 then newH = 0 end
    return storage.loadBlock(cache.blocks[newH])
end

function newBlock(block)
    if minercentralIP == false then return end

    local b = {}
    b.timestamp = os.time()
    b.transactions = {}
    b.previous = block.uuid
    b.height = block.height + 1
    
    local fbago = getPrevChain(block,49)
    b.target = getNextDifficulty(fbago,block)
    
    local rt = {}
    rt.id = randomUUID(16)
    rt.from = "gen"
    rt.to = cache.walletPK.serialize()
    rt.qty = getReward(b.height)
    rt.sources = {}
    rt.rem = 0
    rt.sig = component.data.ecdsa(rt.id .. rt.from .. rt.to .. rt.qty .. hs.hashSources(rt.sources).. rt.rem,cache.walletSK)
    table.insert(b.transactions,rt)

    b.uuid = "PLACEHOLDERFOR64BYTES---0000000000000000000000000000000000000000"
    
    updater.setupTmpEnv()
    utxoProvider.setupTmpEnv()
    for k,v in pairs(cache.transpool) do
        updater.setupTmpEnv()
        utxoProvider.setupTmpEnv()
        local result = verifyTransaction(v)
        if (result~=false and result~="gen") then
            table.insert(b.transactions,v)
            if #serial.serialize(b) > 5000 then -- maximum block size reached
                b.transactions[#b.transactions] = nil
                updater.discardTmpEnv()
                utxoProvider.discardTmpEnv()
            else
                updater.consolidateTmpEnv()
                utxoProvider.consolidateTmpEnv()
            end
        else
            cache.transpool[k] = nil
            updater.discardTmpEnv()
            utxoProvider.discardTmpEnv()
        end
    end
    updater.discardTmpEnv()
    utxoProvider.discardTmpEnv()

    b.uuid = tohex(component.data.sha256(b.height .. b.timestamp .. b.previous .. hs.hashTransactions(b.transactions)))

    component.modem.send(minercentralIP,7000,"NJ####" .. serial.serialize(b))
end

function genesisBlock()
    if minercentralIP == false then return end

    local b = {}
    b.timestamp = os.time()
    b.transactions = {}
    b.previous = ""
    b.height = 0
    b.target = STARTING_DIFFICULTY
    
    local rt = {}
    rt.id = randomUUID(16)
    rt.from = "gen"
    rt.to = cache.walletPK.serialize()
    rt.qty = getReward(b.height)
    rt.sources = {}
    rt.rem = 0
    rt.sig = component.data.ecdsa(rt.id .. rt.from .. rt.to .. rt.qty .. hs.hashSources(rt.sources) .. rt.rem,cache.walletSK)
    table.insert(b.transactions,rt)
    b.uuid = tohex(component.data.sha256(b.height .. b.timestamp .. b.previous .. hs.hashTransactions(b.transactions)))
    component.modem.send(minercentralIP,7000,"NJ####" .. serial.serialize(b))
end