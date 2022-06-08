local serial = require("serialization")
local component = require("component")

cache = {}
cacheLib = {}
function cacheLib.getlastBlock()
    return cache.lb
end

function cacheLib.load()
    local file = io.open("cache.txt", "r")
    if file==nil then
        cache.lb = "error"
        cache.nodes = {}
        cache.contacts = {}
        cache.myIP = component.modem.address
        cache.myPort = 2000
        cache.rt = {}
        cache.pt = {}
        cache.cb = 0
        cache.tb = 0
        cache.minerNode = true
        cache.transpool = {}
        cache.acc = {}
        cache.blocks = {}
        cacheLib.save()
    else
        cache = serial.unserialize(file:read("*a"))
        file:close()
    end
end

function cacheLib.save()
    local walletPK = cache.walletPK
    local walletSK = cache.walletSK
    cache.walletPK = nil
    cache.walletSK = nil

    local file = io.open("cache.txt","w")
    file:write(serial.serialize(cache))
    file:close()

    cache.walletPK = walletPK
    cache.walletSK = walletSK
end

function cacheLib.setlastBlock(uuid)
    cache.lb = uuid
    cacheLib.save()
end

function cacheLib.updateTransactionCache()
    for k, v in pairs(cache.pt) do
        if v.confirmations >= 3 then
            if v.to == cache.walletPK.serialize() then
                cache.tb = cache.tb + v.qty
            elseif v.from == cache.walletPK.serialize() then
                cache.tb = cache.tb + v.rem
                cache.tb = cache.tb - v.qty
            end
            cache.pt[k] = nil
            if #cache.rt >= 10 then
                table.remove(cache.rt, 1)
            end
            table.insert(cache.rt, v)
        else
            cache.pt[k].confirmations = v.confirmations + 1
        end
    end
end