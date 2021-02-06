local nodenet = require("nodenet")
require("protocol")
local thread = require("thread")
local napi = require("netcraftAPI")
local component = require("component")

cache.loadNodes()
cache.myIP = component.modem.address
cache.myPort = 2000
cache.loadlastBlock()

thread.create(function()
    while true do
        nodenet.dispatchNetwork()
    end
end)

io.read()