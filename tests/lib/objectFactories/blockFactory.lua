require('common')
require('protocol')
local sha = require('sha2')

require('math.BigNum')

function sha256(str)
    return sha.hex_to_bin(sha.sha256(str))
end

function mine(h, target)
    local nonce = BigNum.new(math.random(-1000000000000,1000000000000))
    h = tohex(sha256(h))
    while true do
        for k=1,1000 do
            local hash = sha256(h..tostring(nonce))
            if hash ~= nil then
                if (BigNum.fromHex(tohex(hash)) <= target) then return true,tostring(nonce) end
                nonce = nonce + 1
            end
        end
        return false,false
    end
end

BlockFactory = {height = 0, nonce = '', transactions = {}, timestamp = 0, previous = '', target = STARTING_DIFFICULTY, uuid = ''}
    function BlockFactory:new()
        local ret = {}
        setmetatable(ret, self)
        self.__index = self
        ret.uuid = randomUUID(16)
        return ret
    end

    function BlockFactory:setUUID(u)
        self.uuid = u
        return self
    end

    function BlockFactory:setHeight(h)
        self.height = h
        return self
    end

    function BlockFactory:setTimestamp(t)
        self.timestamp = t
        return self
    end

    function BlockFactory:setPreviousUUID(u)
        self.previous = u
        return self
    end

    function BlockFactory:setPreviousBlock(b)
        self.previous = b.uuid
        return self
    end

    function BlockFactory:setTarget(t)
        self.target = t
        return self
    end

    function BlockFactory:setTransactions(tt)
        self.transactions = tt
        return self
    end

    function BlockFactory:addTransaction(t)
        table.insert(self.transactions, t)
    end

    function BlockFactory:calculateValidNonce()
        local hash = false
        local found = false
        local headers = self.uuid .. self.height .. self.timestamp .. self.previous .. hashTransactions(self.transactions)
        while not found do
            found, hash = mine(headers, self.target)
        end
        self.nonce = hash
        return self
    end

    function BlockFactory:create()
        return {
            uuid = self.uuid,
            height = self.height,
            nonce = self.nonce,
            transactions = self.transactions,
            timestamp = self.timestamp,
            previous = self.previous,
            target = self.target
        }
    end

    function BlockFactory:createChain(length, targets)
        local blocks = {
            BlockFactory:new()
                        :setHeight(0)
                        :setTarget(targets[1])
                        :calculateValidNonce()
                        :create()
        }

        for k=2,length do
            table.insert(blocks,
                BlockFactory:new()
                    :setHeight(k-1)
                    :setPreviousBlock(blocks[k-1])
                    :setTarget(targets[k])
                    :calculateValidNonce()
                    :create()
            )
        end

        return blocks
    end

return BlockFactory