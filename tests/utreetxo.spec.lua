package.path = "./tests/lib/?.lua;./usr/lib/?.lua;" .. package.path

local lu = require("luaunit")

local hashService = require("math.hashService")
local sha = require("sha2")
local sha256 = function(str)
    return sha.sha256(str)
end
hashService.constructor(sha256)

local utxoProvider = require("utreetxo.utxoProviderInMemory")

local updater = require("utreetxo.updater")
updater.addProvider(utxoProvider.iterator)

function Test01_simpleadd()
    local acc = {}
    local myutxo = {
        id = "hey!",
        from = "test",
        to = "test2",
        qty = 1,
        rem = 0,
        sources = {"utxo1", "utxo2"},
        sig = "blablabla"
    }
    utxoProvider.addNormalUtxo(myutxo, 0)
    acc = updater.saveNormalUtxo(acc, myutxo)
    lu.assertEquals(acc[0], "69a0df622d29d8d763d619d4f68ad13b5974e2e35da33edcb5ffdef98f5ee789")
    lu.assertEquals(acc[1], nil)

    local tx = utxoProvider.getUtxos()[1]
    lu.assertNotEquals(tx, nil)
    lu.assertEquals(#tx.proof.hashes, 0)
end

function Test02_Delete()
    local acc = {}
    utxoProvider.setUtxos({})

    local myutxo = {
        id = "hey!",
        from = "test",
        to = "test2",
        qty = 1,
        rem = 0,
        sources = {"utxo1", "utxo2"},
        sig = "blablabla"
    }
    utxoProvider.addNormalUtxo(myutxo, 0)
    acc = updater.saveNormalUtxo(acc, myutxo)

    local tx = utxoProvider.getUtxos()[1]
    local res = updater.deleteutxo(acc, tx)
    lu.assertNotEquals(res, nil)
    lu.assertNotEquals(res, false)
    utxoProvider.deleteUtxo(tx)
    lu.assertEquals(utxoProvider.getUtxos()[1], nil)
end

function Test03_ComplexDelete()
    local acc = {}
    utxoProvider.setUtxos({})
    for k = 1, 50 do
        local utxo = {
            id = tostring(k),
            from = tostring(-k),
            to = tostring(-k),
            qty = k * 134315141 % 400,
            rem = k * 549625732 % 842,
            sources = {tostring(2 * k), tostring(2 * k + 1)},
            sig = tostring(k * 4310573825438 % 124942)
        }
        utxoProvider.addNormalUtxo(utxo, 0)
        acc = updater.saveNormalUtxo(acc, utxo)
    end

    for k = 1, 50 do
        local toDelete = utxoProvider.getUtxos()[1]
        utxoProvider.deleteUtxo(toDelete)
        acc = updater.deleteutxo(acc, toDelete)
        lu.assertNotEquals(acc, false)
    end
end

function Test03B_ComplexDeleteRemainder()
    local acc = {}
    utxoProvider.setUtxos({})
    for k = 1, 50 do
        local utxo = {
            id = tostring(k),
            from = tostring(-k),
            to = tostring(-k),
            qty = k * 134315141 % 400,
            rem = k * 549625732 % 842,
            sources = {tostring(2 * k), tostring(2 * k + 1)},
            sig = tostring(k * 4310573825438 % 124942)
        }
        utxoProvider.addRemainderUtxo(utxo, 0)
        acc = updater.saveRemainderUtxo(acc, utxo)
    end
    
    for k = 1, 50 do
        local toDelete = utxoProvider.getUtxos()[1]
        utxoProvider.deleteUtxo(toDelete)
        acc = updater.deleteutxo(acc, toDelete)
        lu.assertNotEquals(acc, false)
    end
end

function Test04_deletetwice()
    -- clean
    utxoProvider.setUtxos({})
    local acc = {}
    local myutxo = {
        id = "hey!",
        from = "test",
        to = "test2",
        qty = 1,
        rem = 0,
        sources = {"utxo1", "utxo2"},
        sig = "blablabla"
    }

    -- act
    utxoProvider.addNormalUtxo(myutxo, 0)
    acc = updater.saveNormalUtxo(acc, myutxo)
    local proof = utxoProvider.getUtxos()[1]
    acc = updater.deleteutxo(acc, proof)
    lu.assertNotEquals(acc, false)
    acc = updater.deleteutxo(acc, proof)
    lu.assertEquals(acc, false)
end

function Test05_mixedOps()
    local acc = {}
    utxoProvider.setUtxos({})
    for k = 1, 50 do
        if k >= 5 then
            local toDelete = utxoProvider.getUtxos()[1]
            utxoProvider.deleteUtxo(toDelete)
            acc = updater.deleteutxo(acc, toDelete)
            lu.assertNotEquals(acc, false)
        end
        local utxo = {
            id = tostring(k),
            from = tostring(-k),
            to = tostring(-k),
            qty = k * 134315141 % 400,
            rem = k * 549625732 % 842,
            sources = {tostring(2 * k), tostring(2 * k + 1)},
            sig = tostring(k * 4310573825438 % 124942)
        }
        utxoProvider.addRemainderUtxo(utxo, 0)
        acc = updater.saveRemainderUtxo(acc, utxo)
    end
end

function Test06_mixedOpsOdd()
    local acc = {}
    utxoProvider.setUtxos({})
    for k = 1, 7 do
        if k >= 6 then
            local toDelete = utxoProvider.getUtxos()[1]
            utxoProvider.deleteUtxo(toDelete)
            acc = updater.deleteutxo(acc, toDelete)
            lu.assertNotEquals(acc, false)
        end
        local utxo = {
            id = tostring(k),
            from = tostring(-k),
            to = tostring(-k),
            qty = k * 134315141 % 400,
            rem = k * 549625732 % 842,
            sources = {tostring(2 * k), tostring(2 * k + 1)},
            sig = tostring(k * 4310573825438 % 124942)
        }
        utxoProvider.addNormalUtxo(utxo, 0)
        acc = updater.saveNormalUtxo(acc, utxo)
        utxoProvider.addRemainderUtxo(utxo, 0)
        acc = updater.saveRemainderUtxo(acc, utxo)
    end
end

function Test07_discardTmpEnv()
    cache = {}
    cache.acc = {}
    utxoProvider.setUtxos({})

    updater.setupTmpEnv()
    local myutxo = {
        id = "hey!",
        from = "test",
        to = "test2",
        qty = 1,
        rem = 0,
        sources = {"utxo1", "utxo2"},
        sig = "blablabla"
    }
    utxoProvider.addNormalUtxo(myutxo, 0)
    cache.acc = updater.saveNormalUtxo(cache.acc, myutxo)
    updater.discardTmpEnv()
    lu.assertEquals(cache.acc[0], nil)
end

function Test08_consolidateTmpEnv()
    cache = {}
    cache.acc = {}
    utxoProvider.setUtxos({})

    updater.setupTmpEnv()
    local myutxo = {
        id = "hey!",
        from = "test",
        to = "test2",
        qty = 1,
        rem = 0,
        sources = {"utxo1", "utxo2"},
        sig = "blablabla"
    }
    utxoProvider.addNormalUtxo(myutxo, 0)
    cache.acc = updater.saveNormalUtxo(cache.acc, myutxo)
    updater.consolidateTmpEnv()
    lu.assertNotEquals(cache.acc[0], nil)
end

function Test09_discardTmpEnvUTX()
    cache = {}
    cache.acc = {}
    utxoProvider.setUtxos({})

    utxoProvider.setupTmpEnv()
    local myutxo = {
        id = "hey!",
        from = "test",
        to = "test2",
        qty = 1,
        rem = 0,
        sources = {"utxo1", "utxo2"},
        sig = "blablabla"
    }
    utxoProvider.addNormalUtxo(myutxo, 0)
    cache.acc = updater.saveNormalUtxo(cache.acc, myutxo)
    utxoProvider.discardTmpEnv()
    lu.assertEquals(#utxoProvider.getUtxos(), 0)
end

function Test10_consolidateTmpEnvUTX()
    cache = {}
    cache.acc = {}
    utxoProvider.setUtxos({})

    utxoProvider.setupTmpEnv()
    local myutxo = {
        id = "hey!",
        from = "test",
        to = "test2",
        qty = 1,
        rem = 0,
        sources = {"utxo1", "utxo2"},
        sig = "blablabla"
    }
    utxoProvider.addNormalUtxo(myutxo, 0)
    cache.acc = updater.saveNormalUtxo(cache.acc, myutxo)
    utxoProvider.consolidateTmpEnv()
    lu.assertEquals(#utxoProvider.getUtxos(), 1)
end

os.exit(lu.LuaUnit.run())
