local serial = require("serialization")

cache = {}
function cache.getlastBlock()
    return cache.lb
end

function cache.load()
    local file = io.open("cache.txt", "r")
    if file==nil then
        cache.lb = "error"
        cache.nodes = {}
        cache.contacts = {}
        cache.myIP = ""
        cache.myPort = 2000
        cache.rt = {}
        cache.pt = {}
        cache.cb = 0
        cache.tb = 0
        cache.minerNode = true
        cache.transpool = {}
        cache.acc = {}
        cache.blocks = {}
        cache.save()
    else
        cache = serial.unserialize(file:read("*a"))
        file:close()
    end
end

function cache.save()
    local file = io.open("cache.txt","w")
    file:write(serial.serialize(cache))
    file:close()
end

function cache.setlastBlock(uuid)
    cache.lb = uuid
    cache.save()
end

function cache.updateTransactionCache()
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

function cache.updateTmpTransactionCache()
    for k, v in pairs(cache._pt) do
        if v.confirmations >= 3 then
            if v.to == cache.walletPK.serialize() then
                cache._tb = cache._tb + v.qty
            elseif v.from == cache.walletPK.serialize() then
                cache._tb = cache._tb + v.rem
                cache._tb = cache._tb - v.qty
            end
            cache._pt[k] = nil
            if #cache._rt >= 10 then
                table.remove(cache._rt, 1)
            end
            table.insert(cache._rt, v)
        else
            cache._pt[k].confirmations = v.confirmations + 1
        end
    end
end