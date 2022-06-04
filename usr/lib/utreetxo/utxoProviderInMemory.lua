local lib = {}

local utxos = {}
local utxos_backup = {}

local hashService = require("math.hashService")

function lib.setupTmpEnv()
    utxos_backup[#utxos_backup + 1] = utxos
end

function lib.setupZeroEnv()
    lib.setupTmpEnv()
    utxos = {}
end

function lib.discardTmpEnv()
    utxos = utxos_backup[#utxos_backup]
    utxos_backup[#utxos_backup] = nil
end

function lib.consolidateTmpEnv()
    utxos_backup[#utxos_backup] = nil
end

function lib.addNormalUtxo(tx, blockHeight)
    local proof = {index = 0, hashes = {}}
    setmetatable(
        proof.hashes,
        {
            __len = function()
                return -1
            end
        }
    ) -- In order for the alg to work, initial node should have h=-1.
    proof.baseHash = hashService.hashData( tx.id, tx.to, tx.qty )
    utxos[#utxos + 1] = {
        proof=proof,
        txid=tx.id,
        bH=blockHeight
    }
end

function lib.addRemainderUtxo(tx, blockHeight)
    local proof = {index = 0, hashes = {}}
    setmetatable(
        proof.hashes,
        {
            __len = function()
                return -1
            end
        }
    ) -- In order for the alg to work, initial node should have h=-1.
    proof.baseHash = hashService.hashData( tx.id, tx.from, tx.rem )
    utxos[#utxos + 1] = {
        proof=proof,
        txid=tx.id,
        bH=blockHeight
    }
end

function lib.deleteUtxo(tx)
    for i, v in ipairs(utxos) do
        if v.proof.baseHash == tx.proof.baseHash then
            table.remove(utxos, i)
            return
        end
    end
end

function lib.getUtxos()
    return utxos
end

function lib.setUtxos(t)
    utxos = t
end

local generator = function(minH, maxH, minX, maxX)
    local utxosCopy = copy(utxos)
    for i, v in ipairs(utxosCopy) do
        if
            not (minH ~= nil and #v.proof.hashes < minH) and not (maxH ~= nil and #v.proof.hashes > maxH) and
                not (minX ~= nil and v.proof.index < minX) and
                not (maxX ~= nil and v.proof.index > maxX)
         then
            coroutine.yield(utxos[i].proof)
        end
    end
end

function lib.iterator(minH, maxH, minX, maxX)
    return coroutine.wrap(
        function()
            generator(minH, maxH, minX, maxX)
        end
    )
end

return lib
