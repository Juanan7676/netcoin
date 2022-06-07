local thread = require("thread")
local component = require("component")
local serial = require("serialization")
local term = require("term")

local hashService = require("math.hashService")
hashService.constructor(component.data.sha256)
local storage = require("storage")
local updater = require("utreetxo.updater")
local utxoProvider = require("utreetxo.utxoProviderInMemory")
updater.constructor(utxoProvider.iterator)

require("cache")
cacheLib.load()
local nodenet = require("nodenet")
require("storage")

require("protocol")
protocolConstructor(component, storage, serial, updater, utxoProvider)

require("common")
require("minerNode")
require("wallet")
print("Synchronizing with network...")
nodenet.sync()
print("Sync done")
updateScreen(cache.cb,cache.tb,cache.rt,cache.pt)
term.setCursor(1,15)

local t = thread.create(function()
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
            file:close()
            cacheLib.save()
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
            cache.contacts[parsed[2]] = nil
            cacheLib.save()
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
            if file==nil then print("Unable to open file, make sure the path is correct")
            else
                file:write(cache.walletPK.serialize())
                file:close()
                print("Public node key successfully exported")
            end
        end
    elseif parsed[1]=="addNode" then
        if #parsed ~= 3 then print("Usage: addNode <IP> <port>")
        else
            local res = nodenet.connectClient(parsed[2],tonumber(parsed[3]))
            if res == nil then print("Could not connect to client, check client is online and ip/port is OK!")
            else print("Node added succesfully and synced") end
        end
    elseif parsed[1]=="mine" then
        if cacheLib.getlastBlock()~="error" then
            newBlock(storage.loadBlock(cacheLib.getlastBlock()))
        else
            genesisBlock()
        end
	elseif parsed[1]=="importBlock" then
		if #parsed == 1 then
			print("Usage: importBlock <file>")
		else
			local file = io.open(parsed[2],"r")
			local d = serial.unserialize(file:read("*a") or "")
            file:close()
			nodenet.newBlock(cache.myIP,1,d)
		end
	elseif parsed[1] == "refresh" then
		term.clear()
		updateScreen(cache.tb,cache.tb,cache.rt,cache.pt)
		term.setCursor(1,15)
	elseif parsed[1] == "listNodes" then
		for i,j in pairs(cache.nodes) do
			print(serial.serialize(j))
		end
	elseif parsed[1] == "setup" then
		storage.setup(true)
		term.clear()
		updateScreen(cache.tb,cache.tb,cache.rt,cache.pt)
		term.setCursor(1,15)
    elseif parsed[1] == "myip" then
        print("IP: " .. cache.myIP)
	elseif parsed[1] == "exit" then
		return true
    end
end
repeat
    local cmd = io.read()
    local done = processCommand(cmd)
until done

t:kill()
