package.path = './lib/?.lua;./../usr/lib/?.lua;' .. package.path
package.loaded.component = require('mocks.component')
package.loaded.serialization = require('mocks.serialization')
package.loaded.filesystem = require('mocks.filesystem')
package.loaded.shell = require('mocks.shell')
package.loaded.term = require('mocks.term')

require('protocol')
protocolConstructor(require("mocks.component"), require("mocks.storage"), require("mocks.serialization"), require("mocks.filesystem"))

lu = require('luaunit')

local realSecondsToTimestamp = 60*60/1000*20

-- Difficulty does not change if block is not 0 mod 50
function test_getNextDifficulty_1()
    local fbago = {
        height=50,
        uuid='fffffffff',
        timestamp=0,
        previous='ffffffe',
        nonce=0,
        target = BigNum.new(2738174839217585342431),
        transactions={},
    }
    local newBlock = {
        height=51,
        uuid='ffffffff2',
        timestamp=0,
        previous='fffffffff',
        nonce=3,
        target = BigNum.new(2738174839217585342431),
        transactions={},
    }
    lu.assertEquals(getNextDifficulty(fbago, newBlock), BigNum.new(2738174839217585342431))
end

-- Difficulty does not change if block is 0 mod 50 but is exactly at 250 minutes elapsed (on target time)
function test_getNextDifficulty_2()
    local fbago = {
        height=50,
        uuid='fffffffff',
        timestamp=0,
        previous='ffffffe',
        nonce=0,
        target = BigNum.new(2)^BigNum.new(240),
        transactions={},
    }
    local newBlock = {
        height=100,
        uuid='ffffffff2',
        timestamp=250 * 60 * realSecondsToTimestamp,
        previous='fffffffff',
        nonce=3,
        target = BigNum.new(2)^BigNum.new(240),
        transactions={},
    }
    lu.assertEquals(getNextDifficulty(fbago, newBlock), BigNum.new(2)^BigNum.new(240))
end

-- Difficulty is divided by 4 if block is 0 mod 50 but is exactly at 1000 minutes elapsed (quadruple target time)
function test_getNextDifficulty_3()
    local fbago = {
        height=50,
        uuid='fffffffff',
        timestamp=0,
        previous='ffffffe',
        nonce=0,
        target = BigNum.new(2)^BigNum.new(240),
        transactions={},
    }
    local newBlock = {
        height=100,
        uuid='ffffffff2',
        timestamp=1000 * 60 * realSecondsToTimestamp,
        previous='fffffffff',
        nonce=3,
        target = 0,
        transactions={},
    }
    lu.assertEquals(getNextDifficulty(fbago, newBlock), BigNum.new(2)^BigNum.new(238))
end

-- Difficulty is quadrupled if block is 0 mod 50 but is exactly at 62.5 minutes elapsed (double target time)
function test_getNextDifficulty_4()
    local fbago = {
        height=50,
        uuid='fffffffff',
        timestamp=0,
        previous='ffffffe',
        nonce=0,
        target = BigNum.new(2)^BigNum.new(240),
        transactions={},
    }
    local newBlock = {
        height=100,
        uuid='ffffffff2',
        timestamp=62.5 * 60 * realSecondsToTimestamp,
        previous='fffffffff',
        nonce=3,
        target = BigNum.new(2)^BigNum.new(240),
        transactions={},
    }
    lu.assertEquals(getNextDifficulty(fbago, newBlock), BigNum.new(2)^BigNum.new(242))
end

-- Difficulty cannot increase more than x4
function test_getNextDifficulty_5()
    local fbago = {
        height=50,
        uuid='fffffffff',
        timestamp=0,
        previous='ffffffe',
        nonce=0,
        target = BigNum.new(2)^BigNum.new(240),
        transactions={},
    }
    local newBlock = { -- 2 minutes elapsed since 50 blocks ago
        height=100,
        uuid='ffffffff2',
        timestamp=2 * 60 * realSecondsToTimestamp,
        previous='fffffffff',
        nonce=3,
        target = 0,
        transactions={},
    }
    lu.assertEquals(getNextDifficulty(fbago, newBlock), BigNum.new(2)^BigNum.new(242))
end

-- Difficulty cannot decrease more than x4
function test_getNextDifficulty_6()
    local fbago = {
        height=50,
        uuid='fffffffff',
        timestamp=0,
        previous='ffffffe',
        nonce=0,
        target = BigNum.new(2)^BigNum.new(240),
        transactions={},
    }
    local newBlock = { -- 8000 minutes elapsed since 50 blocks ago
        height=100,
        uuid='ffffffff2',
        timestamp=8000 * 60 * realSecondsToTimestamp,
        previous='fffffffff',
        nonce=3,
        target = BigNum.new(2)^BigNum.new(240),
        transactions={},
    }
    lu.assertEquals(getNextDifficulty(fbago, newBlock), BigNum.new(2)^BigNum.new(238))
end

-- Difficulty of genesis block is 2^240
function test_getNextDifficulty_7()
    local fbago = nil
    local newBlock = {
        height=0,
        uuid='genesis',
        timestamp=123456 * 60 * realSecondsToTimestamp,
        previous='genesis',
        nonce=1,
        target = BigNum.new(2)^BigNum.new(240),
        transactions={},
    }
    lu.assertEquals(getNextDifficulty(fbago, newBlock), BigNum.new(2)^BigNum.new(240))
end

-- BigNum.fromHex: 0 in hex returns BigNum 0
function test_BigNumFromHex_1()
    local str = '0'
    lu.assertEquals(BigNum.fromHex(str), BigNum.new(0))
end

-- BigNum.fromHex: 03ffdf45276dd38ffac79b0e9c6c14d89d9113ad783d5922580f4c66a3305591 in hex returns BigNum 1809025501092300840245177669444428990784902737987287487228598362074015356305
function test_BigNumFromHex_2()
    local str = '03ffdf45276dd38ffac79b0e9c6c14d89d9113ad783d5922580f4c66a3305591'
    lu.assertEquals(BigNum.fromHex(str), BigNum.new('1809025501092300840245177669444428990784902737987287487228598362074015356305'))
end

os.exit(lu.LuaUnit.run())