package.path = './tests/lib/?.lua;./usr/lib/?.lua;./usr/bin/?.lua;' .. package.path
package.loaded.component = require('mocks.component')
package.loaded.serialization = require('mocks.serialization')
package.loaded.filesystem = require('mocks.filesystem')
package.loaded.shell = require('mocks.shell')
package.loaded.term = require('mocks.term')
package.loaded.thread = require('mocks.thread')
package.loaded.event = require('mocks.event')

local storage = require("mocks.storage")

os.sleep = function(time) end

require("common")
require("math.BigNum")

lu = require('luaunit')

function test_miner_1()
    math.randomseed(0)
    res, nonce = minar('test', BigNum.toHex(BigNum.new(2)^240), package.loaded.component.data.sha256, 100000)
    print(nonce)
    lu.assertEquals(res, true)
end

os.exit(lu.LuaUnit.run())