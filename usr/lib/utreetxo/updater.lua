local accumulator = require("utreetxo.accumulator")
accumulator.construct(function(a) return a end)

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
        for k = 1, (treeH - h) do
            proof.hashes[#proof.hashes] = nil
        end
        proof.hashes[#proof.hashes + 1] = proofRight
        setmetatable(proof.hashes, {__len = function() return -1 end})
    end
end

local cbHandler = function(opName, ...)
    if opName == "add" then
        local h, proofLeft, proofRight = ...
        for proof in utxoProvider(h-1, h, nil, nil) do
            if #proof.hashes == h then
                proof.hashes[#proof.hashes + 1] = proofRight
            else
                proof.index = proof.index + (1 << h)
                setmetatable(proof.hashes, {})
                proof.hashes[#proof.hashes + 1] = proofLeft
            end
            local oldH = #proof.hashes
            setmetatable(proof.hashes,{__len = function() return oldH - 1 end})
        end
    elseif opName == "updateH" then
        local targetH = ...
        for proof in utxoProvider(targetH, targetH, nil, nil) do
            setmetatable(proof.hashes,{})
        end
    elseif opName == "promoteToRoot" then
        rootPromoter(...)
    elseif opName == "add2" then
        local h, initTreeH, proofLeft, proofRight, min, max = ...

        rootPromoter2(h, initTreeH, min, max, proofRight)

        for proof in utxoProvider(h, h, nil, nil) do
            proof.index = proof.index + (1 << h)
            proof.hashes[#proof.hashes + 1] = proofLeft
            setmetatable(proof.hashes, {__len = function() return -1 end})
        end
    elseif opName == "add3" then
        local h, initTreeH, proofLeft, proofRight, min, max = ...

        for proof in utxoProvider(-1, -1, nil, nil) do
            proof.index = proof.index + (1 << h)
            proof.hashes[h + 1] = proofLeft
        end
        
        rootPromoter2(h, initTreeH, min, max, proofRight)

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
