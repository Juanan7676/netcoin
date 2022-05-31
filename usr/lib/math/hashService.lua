local service = {}
local hashFunc = nil

service.constructor = function(f)
    hashFunc = f
end
service.hash = function(data)
    return hashFunc(data)
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
        table.sort(
            t.sources,
            function(a, b)
                return a < b
            end
        )
        for _, v in ipairs(t.sources) do
            hash = service.hash(hash .. v)
        end
    end
    return hash
end

return service
