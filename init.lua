-- networking
ssid = "SSID"
passwd = "PASSWORD"
port_listen = 8000
addr_broadcast = "255.255.255.255"
interval = 3000 -- broadcast interval in ms

-- i2c attributes
i2c_id = 0
i2c_pinSCL = 1 -- actual 4
i2c_pinSDA = 2 -- actual 5
i2c_addr = 0x40
i2c.setup(i2c_id,i2c_pinSDA,i2c_pinSCL,i2c.SLOW)

-- sensor attributes
tempC = 0
humidRH = 0
sensor_toggle = 0

-- timer ids
id_sensor = 0
id_broadcast = 1
id_startup = 2

function start_broadcast(interval)
    -- start a broadcast timer with given ms interval
    tmr.alarm(id_broadcast, interval, 1, function()
        sk:send("GET / .. "{'Temp':" .. (tempC/10) .. "." .. (tempC%10) .. ",'Humid':" .. (humidRH/10) .. "." .. (humidRH%10) .. "}" .. HTTP/1.1\r\nHost: x.x.x.x\r\nConnection: keep-alive\r\nAccept: */*\r\n\r\n")
    end)
end

function do_humidity()
    -- calculate humidity
    i2c.start(i2c_id)
    i2c.address(i2c_id, i2c_addr, i2c.RECEIVER)
    local humidH, humidL = string.byte(i2c.read(i2c_id, 2),1,2)
    i2c.stop(i2c_id)
    local humid = bit.bor(bit.lshift(humidH, 8) , humidL)
    humidRH = (humid*1000)/65536
    -- get next temp
    i2c.start(i2c_id)
    i2c.address(i2c_id, i2c_addr, i2c.TRANSMITTER)
    i2c.write(i2c_id, 0x00)
    i2c.stop(i2c_id)
end

function do_temp()
    -- calculate temperature            
    i2c.start(i2c_id)
    i2c.address(i2c_id, i2c_addr, i2c.RECEIVER)
    local tempH, tempL = string.byte(i2c.read(i2c_id, 2),1,2)
    i2c.stop(i2c_id)
    local temp = bit.bor( bit.lshift(tempH, 8), tempL)
    tempC = (((temp*165)-(40*65536))*10)/65536
    -- get next humid
    i2c.start(i2c_id)
    i2c.address(i2c_id, i2c_addr, i2c.TRANSMITTER)
    i2c.write(i2c_id, 0x01)   
    i2c.stop(i2c_id)
end

-- start measurements
tmr.alarm(sensor_id, 1000, 1, function() 
    if sensor_toggle == 0 then
        sensor_toggle = 1
        do_humidity()
    else
        sensor_toggle = 0
        do_temp()
    end
end )

-- setup wifi 
wifi.setmode(wifi.STATION)
wifi.sta.config("SSID","PASSWORD")
wifi.sta.getip()

tmr.alarm(id_startup, 1000, 1, function()
    ip = wifi.sta.getip()
    if ip != nil then

        -- start server
        srv=net.createServer(net.TCP, 0)
        srv:listen(port_listen,function(conn)
            conn:on("receive", function(client,request)
                client:send("{'Temp':" .. (tempC/10) .. "." .. (tempC%10) .. ",'Humid':" .. (humidRH/10) .. "." .. (humidRH%10) .. "}");
                client:close();
                collectgarbage();
            end)
        end)

        -- start broadcaster loop
        sk=net.createConnection(net.UDP, 0)
        sk:connect(port_local,addr_broadcast)
        sk:on("connection", function(sck,c)
            start_broadcast(interval)
        end)
        sk:on("disconnection", function(sck,c)
            tmr.stop(id_broadcast)
            sk:connect(port_local,addr_broadcast)
        end)

        -- stop this loop
        tmr.stop(id_startup)

    end -- if != nil
end) -- alarm id_startup

