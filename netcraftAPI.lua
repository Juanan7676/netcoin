-- NetCraft API by Juanan76
local event = require("event")

local net = {}

function listen(modem, timeout)
    local client, clientPort, msg
    
    if(timeout==nil) then _,client,_,_,clientPort,msg = event.pull("modem_message")
    else _,client,_,_,clientPort,msg = event.pull("modem_message") end
    
    return client, clientPort, msg
end

function listentoclient(modem, client, timeout)
    local client, clientPort, msg
    
    if(timeout==nil) then _,client,_,_,clientPort,msg = event.pull("modem_message",nil,client)
    else _,client,_,_,clientPort,msg = event.pull("modem_message",nil,client) end
    return client, clientPort, msg
end

return net