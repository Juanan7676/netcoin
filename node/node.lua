local nodenet = require("nodenet")
require("protocol")
local thread = require("thread")
local napi = require("netcraftAPI")
local component = require("component")
require("wallet")
require("common")

cache.loadNodes()
cache.myIP = component.modem.address
cache.myPort = 2000
cache.loadlastBlock()
print("Synchronizing with network...")
nodenet.sync()
print("Sync done")
cache.cb = 0
cache.tb = 0
cache.rt = {}
cache.pt = {}
cache.loadContacts()

thread.create(function()
    while true do
        nodenet.dispatchNetwork()
    end
end)

function processCommand(cmd)
    local parsed = explode(" ",cmd)
    if parsed[1]=="add" then
        if #parsed ~= 3 then print("Usage: add <contactName> <address>")
        else
            local contact = parsed[2]
            local address = parsed[3]
            cache.contacts[contact] = fromhex(address)
            cache.saveContacts()
            print("Contact " .. contact .. " saved succesfully!")
        end
    elseif parsed[1]=="contacts" then
        print("These are your contacts:")
        for k,_ in pairs(cache.contacts) do
            print("- "..k)
        end
        print("You can pay them using pay <contact> <amount>")
    elseif parsed[1]=="remove" then
        if #parsed ~= 2 then print("Usage: remove <contactName>")
        else
            cache.contacts[contact] = nil
            cache.saveContacts()
            print("Operation done successfully")
        end
    elseif parsed[1]=="pay" then
        if #parsed ~= 3 then print("Usage: pay <contactName> <amount>")
        else
            local address = cache.contacts[parsed[2]]
            if address==nil then print("Contact not found!") return false end
            local qty = tonumber(parsed[3])
            nodenet.confectionateTransaction(address,qty)
            print("Transaction was completed successfully. You need to wait a few minutes for the transaction to be processed by miners and appear on the network. This process takes usually around 5 minutes.")
        end
    end
end

io.read()