local accumulator = require("accumulator")
local hashService = require("math.hashService")

local updater = {}

---@alias UtxoProviderFunc fun(minH: integer, maxH: integer, minX: integer, maxX: integer): Proof[]

---@type UtxoProviderFunc
local utxoProvider = nil

---@param up UtxoProviderFunc
function updater.constructor(up)
    utxoProvider = up
end

local rootPromoter = function(h, treeH, min, max)
    for proof in utxoProvider(treeH, treeH, min, max) do
        proof.index = proof.index - min
        for k = 1, (#proof.hashes - h) do
            proof.hashes[#proof.hashes] = nil
        end
    end
end

local rootPromoter2 = function(h, treeH, min, max, proofRight)
    for proof in utxoProvider(treeH, treeH, min, max) do
        proof.index = proof.index - min
        for k = 1, (#proof.hashes - h) do
            proof.hashes[#proof.hashes] = nil
        end
        proof.hashes[#proof.hashes + 1] = proofRight
    end
end

local cbHandler = function(opName, ...)
    local varargs = ...
    if opName == "add" then
        local h, r = varargs[1], varargs[2]
        for proof in utxoProvider(nil, h, nil, nil) do
            if #proof.hashes == h then
                proof.index = proof.index + (1 << h)
            end
            proof.hashes[#proof.hashes + 1] = r
        end
    elseif opName == "add_initNil" then
        local inserted = utxoProvider(0, 0, 1, 1)
        if inserted ~= nil then
            inserted.index = 0
        end
    elseif opName == "promoteToRoot" then
        rootPromoter(varargs[1], varargs[2], varargs[3], varargs[4])
    elseif opName == "add2" then
        local h, initTreeH, min, max, proofLeft, proofRight = table.unpack(varargs)

        rootPromoter2(h, initTreeH, min, max, proofRight)

        for proof in utxoProvider(h, h, nil, nil) do
            proof.index = proof.index + varargs[4] + 1
            proof.hashes[#proof.hashes + 1] = proofLeft
        end
    else
        print("ERROR: opName not found " .. opName)
    end
end

--- Updates and saves the given utxo into the accumulator.
function updater.saveutxo(acc, utx)
    if utxoProvider == nil then
        return nil
    end
    return accumulator.add(acc, hashService.hashTransactions({utx}), cbHandler)
end

--- Updates and deletes the given utxo into the accumulator.
--- Returns nil if the updater is not constructed, false if the utxo was not present, the updated accumulator otherwise.
function updater.deleteutxo(acc, proof)
    if utxoProvider == nil then
        return nil
    end
    return accumulator.delete(acc, proof, cbHandler)
end

return updater
