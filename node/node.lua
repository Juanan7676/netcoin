local nodenet = require("nodenet")
require("protocol")
local thread = require("thread")
local napi = require("netcraftAPI")
local component = require("component")
require("wallet")
require("common")
require("minerNode")

cache.loadNodes()
cache.myIP = component.modem.address
cache.myPort = 2000
cache.minerNode = false
cache.minerControl=""
cache.loadlastBlock()
print("Synchronizing with network...")
nodenet.sync()
print("Sync done")
cache.cb = 0
cache.tb = 0
cache.rt = {}
cache.pt = {}
cache.loadContacts()
nodenet.reloadWallet()

thread.create(function()
    while true do
        local status, err = pcall(nodenet.dispatchNetwork)
        if not status then print("Error: "..err) end
    end
end)

function processCommand(cmd)
    local parsed = explode(" ",cmd)
    if parsed[1]=="add" then
        if #parsed ~= 3 then print("Usage: add <contactName> <PKfile>")
        else
            local contact = parsed[2]
            local file = io.open(parsed[3],"r")
            if file==nil then print("Could not find file") return end
            cache.contacts[contact] = file:read("*a")
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
            local qty = math.floor(tonumber(parsed[3])*1000000)
            local tr = nodenet.confectionateTransaction(address,qty)
            if (tr==nil) then print("Could not make transaction! Maybe you tried to spend more funds than you have?")
            else
                for k,v in pairs(cache.nodes) do
                    nodenet.sendClient(v.ip, v.port, "NEWTRANSACT####" .. serial.serialize(tr))
                end
                if (cache.minerNode) then newTransaction(tr) end
                print("Transaction was completed successfully. You need to wait a few minutes for the transaction to be processed by miners and appear on the network. This process takes usually around 5 minutes.")
            end
        end
    elseif parsed[1]=="export" then
        if #parsed ~= 2 then print("Usage: export <PKfile>")
        else
            local contact = parsed[2]
            local file = io.open(parsed[2],"w")
            file:write(cache.walletPK.serialize())
            print("Public node key successfully exported")
        end
    elseif parsed[1]=="addNode" then
        if #parsed ~= 3 then print("Usage: addNode <IP> <port>")
        else
            local res = nodenet.connectClient(parsed[2],tonumber(parsed[3]))
            if res == nil then print("Could not connect to client, check client is online and ip/port is OK!")
            else print("Node added succesfully and synced") end
        end
    elseif parsed[1]=="mine" then
        if cache.getlastBlock()~="error" then
            newBlock(storage.loadBlock(cache.getlastBlock()))
        else
            genesisBlock()
        end
    end
end
while true do
    local cmd = io.read()
    processCommand(cmd)
end