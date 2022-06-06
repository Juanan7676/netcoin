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

local saveHash = function(acc, hash)
    return accumulator.add(acc, hash, cbHandler)
end

--- Updates and saves the given normal utxo in the accumulator
function updater.saveNormalUtxo(acc, tx)
    return saveHash(acc, hashService.hashData( tx.id, tx.to, tx.qty ) )
end

--- Updates and saves the given remainder utxo in the accumulator
function updater.saveRemainderUtxo(acc, tx)
    return saveHash(acc, hashService.hashData( tx.id, tx.from, tx.rem ) )
end

--- Updates and deletes the given utxo into the accumulator.
--- Returns nil if the updater is not constructed, false if the utxo was not present, the updated accumulator otherwise.
function updater.deleteutxo(acc, tx)
    if utxoProvider == nil then
        return nil
    end
    return accumulator.delete(acc, tx.proof, cbHandler)
end

function updater.setupTmpEnv()
    if cache._acc == nil then cache._acc = {} end
    cache._acc[#cache._acc + 1] = cache.acc

    if cache._pb == nil then cache._pb = {} end
    cache._pb[#cache._acc + 1] = cache.pb

    if cache._tb == nil then cache._tb = {} end
    cache._tb[#cache._acc + 1] = cache.tb

    if cache._pt == nil then cache._pt = {} end
    cache._pt[#cache._acc + 1] = cache.pt

    if cache._rt == nil then cache._rt = {} end
    cache._rt[#cache._acc + 1] = cache.rt
end

function updater.discardTmpEnv()
    cache.acc = cache._acc[#cache._acc]
    cache._acc[#cache._acc] = nil

    cache.pb = cache._pb[#cache._pb]
    cache._pb[#cache._pb] = nil

    cache.pt = cache._pt[#cache._pt]
    cache._pt[#cache._pt] = nil

    cache.tb = cache._tb[#cache._tb]
    cache._tb[#cache._tb] = nil

    cache.rt = cache._rt[#cache._rt]
    cache._rt[#cache._rt] = nil
end

function updater.consolidateTmpEnv()
    cache._acc[#cache._acc] = nil
    cache._pb[#cache._pb] = nil
    cache._pt[#cache._pt] = nil
    cache._tb[#cache._tb] = nil
    cache._rt[#cache._rt] = nil
end

return updater
