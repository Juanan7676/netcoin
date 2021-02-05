-- NetCraft API by Juanan76
local event = require("event")

local net = {}

function send(modem,client,port,rport,msg)
    modem.send(client,port,rport,msg)
end

function listen(modem, port, timeout)
    modem.open(port)
    local client, clientPort, msg
    
    if(timeout==nil) then _,client,_,_,clientPort,msg = event.pull("modem_message")
    else _,client,_,_,clientPort,msg = event.pull("modem_message") end
    
    return client, clientPort, msg
end

function listentoclient(modem, port, client, timeout)
    modem.open(port)
    local client, clientPort, msg
    
    if(timeout==nil) then _,client,_,_,clientPort,msg = event.pull("modem_message",nil,client)
    else _,client,_,_,clientPort,msg = event.pull("modem_message",nil,client) end
    return client, clientPort, msg
end

return net