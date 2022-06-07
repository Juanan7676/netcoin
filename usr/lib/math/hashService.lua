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
    table.sort(
        sources_table,
        function(a, b)
            return a.txid < b.txid
        end
    )
    for _, t in ipairs(sources_table) do
        hash = service.hash(hash .. t.height .. t.txid .. t.proof.baseHash .. t.proof.index)
        for _,v in ipairs(t.proof.hashes) do
            hash = service.hash(hash .. v)
        end
    end
    return hash
end

service.hashTransactions = function(transaction_table)
    local hash = ""
    table.sort(
        transaction_table,
        function(a, b)
            return a.id < b.id
        end
    )
    for _, t in ipairs(transaction_table) do
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
