local storage = {}

storage.blocks = {}

-- Interface implementation

function storage.loadBlock(id)
    for _,block in ipairs(storage.blocks) do
        if block.uuid == id then return block end
    end
    return nil
end

function storage.saveBlock(block)
    table.insert(storage.blocks, block)
end

-- Some useful methods not relative to the interface implementation

function storage.saveBlockChain(chain)
    storage.blocks = chain
end

return storage