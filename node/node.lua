local nodenet = require("nodenet")
require("protocol")
local thread = require("thread")
local napi = require("netcraftAPI")
local component = require("component")

cache.loadNodes()
cache.myIP = "1.0.0.0"
cache.myPort = "2000"

thread.create(function()
    local sv = napi.server(component.modem,cache.myPort)
    while true do
        nodenet.dispatchNetwork(sv)
    end
end)

io.read()