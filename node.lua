#!/usr/bin/lua

-- parent defined attributes
id = 1 -- my unique identifier
local_port = 80 -- for connecting to me from LAN
remote_port = 8000 -- for connecting to me from WAN
ssid = "ssid"
passwd = "pass"
parent_name = 'lair_server' -- ip looked up in dns later
parent_port = 8000 -- app server listens on this port
sleep_time = 1000000 -- sleeptime between announcements in microseconds

-- i2c attributes
i2c_id = 0
i2c_pinSDA = 4
i2c_pinSCL = 2
i2c_addr = 0x77

----------------------------------------------------------

function fetch_i2c()
    -- set temp pointer
    i2c.start(i2c_id)
    i2c.address(i2c_id, i2c_addr, i2c.TRANSMITTER)
    i2c.write(i2c_id, 0x00)
    i2c.stop(i2c_id)

    -- read temp
    i2c.start(i2c_id)
    i2c.address(pin, i2c_addr, i2c.RECEIVER)
    local temp = tonumber(i2c.read(i2c_id, 1), 16)
    i2c.stop(i2c_id)

    -- set rh pointer
    i2c.start(i2c_id)
    i2c.address(pin, i2c_addr, i2c.TRANSMITTER)
    i2c.write(i2c_id, 0x01)
    i2c.stop(i2c_id)

    -- read rh
    i2c.start(i2c_id)
    i2c.address(pin, i2c_addr, i2c.RECEIVER)
    local rh = tonumber(i2c.read(i2c_id, 1), 16)
    i2c.stop(i2c_id)

    return (temp, rh)

function get_data(temp, rh)
    -- build payload
    uptime = os.difftime(os.date() - date_start) -- uptime in seconds
    return id .. '/' .. local_port .. '/' .. remote_port .. '/' .. temp .. '/' .. rh .. '/' .. uptime
end

----------------------------------------------------------

-- configure network
wifi.setmode(wifi.STATION)
wifi.sta.config(ssid,passwd)
wifi.sta.getip()

-- setup
i2c.setup(i2c_id, i2c_pinSDA, i2c_pinSCL, i2c.SLOW)

-- get parent_ip from parent_name using dns
sk = net.createConnection(net.TCP, 0)
sk:dns(parent_name,function(conn,parent_ip) print(parent_ip) end)
sk = nil

date_start = os.date() -- used to calculate uptime

-- start server
srv = net.createServer(net.TCP)

-- communicate forever
while 1 do
    node.dsleep(sleep_time)

    sk = net.createConnection(net.TCP, 0)
    sk:connect(parent_port, parent_ip)
    sk.on("connection", function(sck,c)
        -- wait for connection before sending
        sk.send("GET /" .. get_data(fetch_i2c) .. " HTTP/1.1\r\n")
        end)
    sk = nil
end

