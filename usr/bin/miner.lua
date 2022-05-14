comp = require("component")
modem = comp.modem
data = comp.data
thread = require("thread")
event = require("event")
serial = require("serialization")
require("math.BigNum")
require("common")

function tohex(str)
    return (str:gsub('.', function (c)
        return string.format('%02X', string.byte(c))
    end))
end

sha256 = comp.data.sha256
HASHES_PER_CYCLE = 100

function listen(timeout)
    modem.open(7001)
    local client, clientPort, msg, target
    
    if(timeout==nil) then _,_,client,_,_,msg,target = event.pull("modem_message")
    else _,_,client,_,_,msg,target = event.pull(timeout,"modem_message") end
    
    return client, msg, target
end

headers = ""
target = 0
jobStart = false
centralIP = nil

function start()
    
    thread.create( function()
    while true do
        local client,msg,t=listen()
        print("Starting new job")
        t = serial.unserialize(t)
        centralIP=client
        headers = msg
        target = t
        jobStart = true
    end end )
    
    while true do
        encontrado = false
        local val, res
        while not encontrado do
            if (jobStart==true) then
                local start = os.time()
                res,val = minar(headers,target, sha256, HASHES_PER_CYCLE)
                if res==true then break end
                local nend = os.time()
                local elapsed = (nend-start)*1000/60/60/20
                modem.send(centralIP,7001,"HR####"..(HASHES_PER_CYCLE/elapsed))
                os.sleep(0)
            else
                os.sleep(1)
            end
        end
        modem.send(centralIP,7001,"NF####"..val)
        jobStart = false
    end
end

start()