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
updater.constructor(utxoProvider.iterator)

local acc = {}

function Dump(o)
    if type(o) == 'table' then
       local s = '{ '
       for k,v in pairs(o) do
          if type(k) ~= 'number' then k = '"'..k..'"' end
          s = s .. '['..k..'] = ' .. Dump(v) .. ','
       end
       return s .. '} '
    else
       return tostring(o)
    end
 end 

function Test01_simpleadd()
    local myutxo = {
        id = "hey!",
        from = "test",
        to = "test2",
        qty = 1,
        rem = 0,
        sources = {"utxo1", "utxo2"},
        sig = "blablabla"
    }
    utxoProvider.addUtxo(myutxo)
    acc = updater.saveutxo(acc, myutxo)
    lu.assertEquals(acc[0], "335d712f953d70aed03692a14eb4fcf6945be69e208a2a96b983f3ff14d5163f")
    lu.assertEquals(acc[1], nil)
    
    local proof = utxoProvider(0, 0, nil, nil)()
    lu.assertNotEquals(proof, nil)
    lu.assertEquals(#proof.hashes, 0)
end

function Test02_Delete()
    local proof = utxoProvider(0, 0, nil, nil)()
    local res = updater.deleteutxo(acc, proof)
    lu.assertNotEquals(res, nil)
    lu.assertNotEquals(res, false)
    utxoProvider.deleteUtxo(proof)
    lu.assertEquals(utxoProvider(0, 0, nil, nil)(), nil)
end

function Test03_ComplexDelete()
    local acc = {}
    for k = 1,50 do
        local utxo = {
            id = tostring(k),
            from = tostring(-k),
            to = tostring(-k),
            qty = k*134315141%400,
            rem = k*549625732%842,
            sources = {tostring(2*k), tostring(2*k+1)},
            sig = tostring(k*4310573825438%124942)
        }
        utxoProvider.addUtxo(utxo)
        acc = updater.saveutxo(acc, utxo)
    end
    local toDelete = utxoProvider.getUtxos()[39]
    acc = updater.deleteutxo(acc, toDelete)
    lu.assertNotEquals(acc, false)

    toDelete = utxoProvider.getUtxos()[16]
    acc = updater.deleteutxo(acc, toDelete)
    lu.assertNotEquals(acc, false)

    toDelete = utxoProvider.getUtxos()[12]
    acc = updater.deleteutxo(acc, toDelete)
    lu.assertNotEquals(acc, false)

    toDelete = utxoProvider.getUtxos()[43]
    acc = updater.deleteutxo(acc, toDelete)
    lu.assertNotEquals(acc, false)

    toDelete = utxoProvider.getUtxos()[1]
    acc = updater.deleteutxo(acc, toDelete)
    lu.assertNotEquals(acc, false)
end

os.exit(lu.LuaUnit.run())
