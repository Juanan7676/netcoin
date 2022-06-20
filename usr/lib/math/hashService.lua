local service = {}
local hashFunc = nil

service.constructor = function(f)
    hashFunc = f
end
service.hash = function(data)
    return hashFunc(data)
end

service.hashSources = function(sources_table)
    local hash = ""
    local st = copy(sources_table)
    table.sort(
        st,
        function(a, b)
            return a.txid < b.txid
        end
    )
    for _, t in ipairs(st) do
        hash = service.hash(hash .. t.height .. t.txid .. t.proof.baseHash .. t.proof.index)
        for _,v in ipairs(t.proof.hashes) do
            hash = service.hash(hash .. v)
        end
    end
    return hash
end

service.hashTransactions = function(transaction_table)
    local hash = ""
    local txTable = copy(transaction_table)
    table.sort(
        txTable,
        function(a, b)
            return a.id < b.id
        end
    )
    for _, t in ipairs(txTable) do
        hash = service.hash(hash .. t.id .. t.from .. t.to .. t.qty .. t.rem .. t.sig)
        hash = service.hash(hash .. service.hashSources(t.sources))
    end
    return hash
end

service.hashData = function(...)
    local args = table.pack(...)
    local hash = ""
    for _, v in ipairs(args) do
        hash = service.hash(hash .. v)
    end
    return hash
end

return service
