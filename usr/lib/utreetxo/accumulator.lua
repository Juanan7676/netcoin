---@alias Proof {index: string, baseHash: string, hashes: string[]}
---@alias ElementNode string

require("common")

local lib = {}

local deps = {}
function lib.construct(hashFunc, serializator)
    deps.hashFunc = hashFunc
    deps.serializator = serializator
end

local parent = function(str1, str2)
    return deps.serializator(deps.hashFunc(str1 .. str2))
end

local calcRange = function(i, h)
    if h == 0 then
        return i ~ 1, i ~ 1
    end
    local x = ((i >> h) ~ 1) << h
    return x, x | ((1 << h) - 1)
end

function lib.add(acc, element, updatecb)
    local n = element
    local h = 0
    local r = acc[h]
    if r == nil then
        updatecb("add_initNil")
    end
    while r ~= nil do
        updatecb("add", h, r)
        n = parent(r, n)
        acc[h] = nil
        h = h + 1
        r = acc[h]
    end
    acc[h] = n
    return acc
end

function lib.delete(acco, proof, updatecb)
    local acc = copy(acco)
    local n = nil
    local h = 0
    local check = proof.baseHash

    while h < #proof.hashes do
        local p = proof.hashes[h]
        if proof.index & (1 << h) == 0 then check = parent(check, p)
        else check = parent(p, check) end

        if (n ~= nil) then
            updatecb("add", h, p)
            n = parent(p, n)
        elseif acc[h] == nil then
            acc[h] = p
            updatecb("promoteToRoot", h, proof.index, calcRange(proof.index, h))
        else
            updatecb("add2", h, proof.index, calcRange(proof.index, h))
            n = parent(p, acc[h])
            acc[h] = nil
        end
        h = h + 1
    end

    if check ~= acc[h] then return false end

    acc[h] = n
    return acc
end

return lib