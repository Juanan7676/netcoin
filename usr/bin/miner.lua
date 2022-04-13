comp = require("component")
modem = comp.modem
data = comp.data
thread = require("thread")
event = require("event")

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
    nonce = math.random(-1000000000000,1000000000000)
    while true do
        for k=1,1000 do
            local hash = data.sha256(tostring(nonce)..h)
            if hash ~= nil then
                if (tonumber("0x"..tohex(hash)..".0") <= target) then return true,tostring(nonce) end
                nonce = nonce + 1
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
        print("Starting job with target "..t)
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
                modem.send(centralIP,7000,"HR####"..(1000/elapsed))
                if res==true then break end
                os.sleep(1)
            else
                os.sleep(1)
            end
        end
        modem.send(centralIP,7000,"NF####"..val)
        jobStart = false
    end
end