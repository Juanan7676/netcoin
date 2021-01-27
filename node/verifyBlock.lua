local data = component.data

function verifyBlock(block)
    if not block.uuid or not block.nonce or not block.height or not block.timestamp or not block.previous or not block.transactions or not block.target then return false end
    if (#block.uuid ~= 16) then return false end
    if block.target ~= protocol.getCurrDifficulty() then return false end
    if tonumber(tohex(data.sha256(block.nonce .. block.height .. block.timestamp .. block.previous .. serialization.serialize(block.transactions))),16) > block.target then return false end
    local genFound = false
    for _,v in ipairs(block.transactions) do
        result = verifyTransaction(v)
        if result==false then return false end
        if result=="gen" then
            if genFound == true then return false
            else genFound = true end
        end
     end
    return true
end