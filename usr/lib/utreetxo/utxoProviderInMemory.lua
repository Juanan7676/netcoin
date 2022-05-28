local utxos = {}

local hashService = require("math.hashService")

function addUtxo(utx)
    local proof = {index=0, hashes = {}}
    setmetatable(proof.hashes,{__len=function() return -1 end}) -- In order for the alg to work, initial node should have h=-1.
    proof.baseHash = hashService.hashTransactions({utx})
    utxos[#utxos + 1] = proof
end

function deleteUtxo(proof)
    for i, v in ipairs(utxos) do
        if v.baseHash == proof.baseHash then
            table.remove(utxos, i)
            return
        end
    end
end

function getUtxos()
    return utxos
end

local generator = function(minH, maxH, minX, maxX)
    local utxosCopy = copy(utxos)
    for i, v in ipairs(utxosCopy) do
        if
            not (minH ~= nil and #v.hashes < minH) and not (maxH ~= nil and #v.hashes > maxH) and
                not (minX ~= nil and v.index < minX) and
                not (maxX ~= nil and v.index > maxX)
         then
            coroutine.yield(utxos[i])
        end
    end
end

return function(minH, maxH, minX, maxX)
    return coroutine.wrap(function() generator(minH, maxH, minX, maxX) end)
end
