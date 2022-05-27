package.path = "./tests/lib/?.lua;./usr/lib/?.lua;" .. package.path

lu = require("luaunit")

hashService = require("math.hashService")
sha = require("sha2")
function sha256(str)
    return sha.hex_to_bin(sha.sha256(str))
end
hashService.constructor(sha256)

utxoProvider = require("utreetxo.utxoProviderInMemory")

updater = require("utreetxo.updater")
updater.constructor(utxoProvider)

function test_simpleadd1()
    local myutxo = {
        id = "hey!",
        from = "test",
        to = "test2",
        qty = 1,
        rem = 0,
        sources = {"utxo1", "utxo2"},
        sig = "blablabla"
    }
    utxoProvider.
    updater.
end

os.exit(lu.LuaUnit.run())
