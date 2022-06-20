local utxos = {}

local lib = {}

function lib.reset()
    utxos = {}
end

function lib.add(tx)
    table.insert(utxos, tx)
end

function lib.rm(tx)
    for i, v in ipairs(utxos) do
        if v.proof.baseHash == tx.proof.baseHash then
            table.remove(utxos, i)
            return
        end
    end
end

function lib.get()
    return utxos
end

function lib.set(txTable)
    utxos = txTable
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