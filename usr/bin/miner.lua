comp = require("component")
modem = comp.modem
data = comp.data
thread = require("thread")
event = require("event")
serial = require("serialization")
require("math.BigNum")
require("common")

math.randomseed(os.time())

function tohex(str)
    return (str:gsub('.', function (c)
        return string.format('%02X', string.byte(c))
    end))
end

function listen(timeout)
    modem.open(7000)
    local client, clientPort, msg, target
    
    if(timeout==nil) then _,_,client,_,_,msg,target = event.pull("modem_message")
    else _,_,client,_,_,msg,target = event.pull(timeout,"modem_message") end
    
    return client, msg, target
end

function minar(h, target)
    local nonce = randomUUID(16)
    h = tohex(sha256(h))
    while true do
        for k=1,1000 do
            local hash = sha256(h..nonce)
            if hash ~= nil then
                if (BigNum.fromHex(tohex(hash)) <= target) then return true,nonce end
                nonce = randomUUID(16)
            end
        end
        return false,false
    end
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
                res,val = minar(headers,tonumber(target))
                local nend = os.time()
                local elapsed = (nend-start)*1000/60/60/20
                modem.send(centralIP,7001,"HR####"..(1000/elapsed))
                if res==true then break end
                os.sleep(1)
            else
                os.sleep(1)
            end
        end
        modem.send(centralIP,7001,"NF####"..serial.serialize(val))
        jobStart = false
    end
end

start()