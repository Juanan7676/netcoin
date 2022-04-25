require("common")
component = require("component")
serial = require("serialization")

require("protocol")
protocolConstructor(require("component"), require("storage"), require("serialization"), require("filesystem"))

require("wallet")
cache.transpool = {}

function newTransaction(t)
    cache.transpool[t.id] = t
end

function deleteTransaction(id)
    cache.transpool[id] = nil
end

function newBlock(block)
    local b = {}
    b.uuid = randomUUID(16)
    b.timestamp = os.time()
    b.transactions = {}
    b.previous = block.uuid
    b.height = block.height + 1
    
    local fbago = getPrevChain(block,49)
    b.target = getNextDifficulty(fbago,block)
    
    for k,v in pairs(cache.transpool) do
        local result = verifyTransaction(v, storage.utxopresent, storage.remutxopresent)
        if (result~=false and result~="gen") then
            table.insert(b.transactions,v)
        else
            cache.transpool[k] = nil
        end
    end
    
    local rt = {}
    rt.id = randomUUID(16)
    rt.from = "gen"
    rt.to = cache.walletPK.serialize()
    rt.qty = getReward(b.height)
    rt.sources = {}
    rt.rem = 0
    rt.sig = component.data.ecdsa(rt.id .. rt.from .. rt.to .. rt.qty .. serial.serialize(rt.sources) .. rt.rem,cache.walletSK)
    table.insert(b.transactions,rt)
    b.transactions = serial.serialize(b.transactions)
    component.modem.broadcast(7000,"NJ####" .. serial.serialize(b))
end

function genesisBlock()
    local b = {}
    b.uuid = randomUUID(16)
    b.timestamp = os.time()
    b.transactions = {}
    b.previous = b.uuid
    b.height = 0
    b.target = serial.unserialize(serial.serialize(2^240))
    
    local rt = {}
    rt.id = randomUUID(16)
    rt.from = "gen"
    rt.to = cache.walletPK.serialize()
    rt.qty = getReward(b.height)
    rt.sources = {}
    rt.rem = 0
    rt.sig = component.data.ecdsa(rt.id .. rt.from .. rt.to .. rt.qty .. serial.serialize(rt.sources) .. rt.rem,cache.walletSK)
    table.insert(b.transactions,rt)
    b.transactions = serial.serialize(b.transactions)
    component.modem.broadcast(7000,"NJ####" .. serial.serialize(b))
end