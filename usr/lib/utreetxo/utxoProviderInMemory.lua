local utxos = {}

local hashService = require("math.hashService")

function addUtxo(utx)
    local proof = {h = 0, hashes = {}}
    proof.baseHash = hashService.hashTransactions({utx})
    utxos[#utxos + 1] = proof
end

function deleteUtxo(proof)
    for i, v in ipairs(utxos) do
        if v.baseHash == proof.baseHash then
            table.remove(proof, i)
        end
    end
end

return function(minH, maxH, minX, maxX)
    local ret = {}
    for _, v in ipairs(utxos) do
        if
            not (minH ~= nil and #v.hashes < minH) and not (maxH ~= nil and #v.hashes > maxH) and
                not (minX ~= nil and v.index < minX) and
                not (maxX ~= nil and v.index > maxX)
         then
            ret[#ret + 1] = v
        end
    end
    return ret
end
