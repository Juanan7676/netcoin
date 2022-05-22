local updater = {}

---@alias UtxoProviderFunc fun(minH: integer, maxH: integer, minX: integer, maxX: integer): Proof[]

---@type UtxoProviderFunc
local utxoProvider = nil

---@param up UtxoProviderFunc
function updater.construct(up)
    utxoProvider = up
end

function updater.cbHandler(opName, ...)
    local varargs = ...
    if opName=="add" then
        local h, r = varargs[1],varargs[2]
        for proof in utxoProvider(nil, h, nil, nil) do
            if #proof.hashes == h then proof.index = proof.index + (1 << h) end
            proof.hashes[#proof.hashes + 1] = r
        end
    elseif opName=="add_initNil" then
        local inserted = utxoProvider(0, 0, 1, 1)
        if inserted~=nil then
            inserted.index = 0
        end
    elseif opName=="promoteToRoot" then
        local h, min, max = varargs[1], varargs[2],varargs[3]
        for proof in utxoProvider(h, h, min, max) do
            proof.index = proof.index - min
            for k=1,(#proof.hashes - h) do
                proof.hashes[#proof.hashes] = nil
            end
        end
    end
end
return updater