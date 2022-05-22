---@alias Proof {index: string, hashes: string[]}
---@alias ElementNode string

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
    if h==0 then return i~1,i~1 end
    local x = ((i >> h)~1) << h
    return x, x | ((1 << h) - 1)
end

function lib.add(acc, element, updatecb)
    local n = element
    local h = 0
    local r = acc[h]
    if r==nil then updatecb("add_initNil") end
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

function lib.delete(acc, proof, updatecb)
    local n = nil
    local h = 0
    while h < #proof.hashes do
        local p = proof.hashes[h]
        if (n~=nil) then n = parent(p,n)
        elseif acc[h]==nil then 
            acc[h]=p
            updatecb("promoteToRoot", h, calcRange(proof.index, h))
        else
            n = parent(p, acc[h])
            acc[h]=nil
        end
        h = h +1
    end
    acc[h] = n
    return acc
end

return lib