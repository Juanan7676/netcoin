comp = require("component")
modem = comp.modem

function listen(timeout)
    modem.open(7000)
    local client, clientPort, msg
    
    if(timeout==nil) then _,_,client,_,_,clientPort,msg = event.pull("modem_message")
    else _,_,client,_,_,clientPort,msg = event.pull(timeout,"modem_message") end
    
    return client, clientPort, msg
end

function minar(headers)
    local nonce = math.random(0,43157426426)
    while true do
        for k=1,1000 do
        local hash = data.sha256(nonce..headers)
        if hash ~= nil then
        if (tonumber(tohex(hash),16) <= block.target) then print(tonumber(tohex(hash),16)) coroutine.yield(nonce) end
        nonce = nonce + 1
        end
        end
        coroutine.yield(false)
        os.sleep(0)
    end
end

headers = ""
jobStart = false

function start()
    
    mc = coroutine.create(minar)
    
    thread.create( function()
    while true do
        local client,_,msg=listen()
        headers = msg
        jobStart = true
    end end )
    
    while true do
        encontrado = false
        local val
        while not encontrado do
            if (jobStart==true) then
                local start = os.time()
                __,val = coroutine.resume(mc,headers,math.random(0,43157426426))
                local nend = os.time()
            else
                os.sleep(1000)
            end
            local elapsed = (nend-start)*1000/60/60/20
            modem.broadcast(7000,"HR####"..(1000/elapsed))
            if val~=false then break end
        end
        modem.broadcast(7000,"NF####"..val)
        jobStart = false
    end
end