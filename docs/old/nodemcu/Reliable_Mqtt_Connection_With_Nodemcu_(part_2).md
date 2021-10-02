!!! caution
    **This page has been updated a long time ago.**  Information found here could be outdated and may lead to missconfiguration.  
    Some of the links and references may be broken or lead to non existing pages.  
    Please use this docs carefully. Most of the information here now is only for reference or example!
    
# Reliable MQTT connection with NodeMCU (part 2)

Thanks to "Modestas" post on [my previous article ](http://blog.vinczejanos.info/2016/09/29/reliable-mqtt-conenction-with-nodemcu/) now I will show you another solution to this topic, which is much easier to understand and simpler.

* **First we will create a config file like this:**
```lua
--[[
File Name: config.lua
]]
local module = {}
    module.NodeID=node.chipid()

    -- mqtt Related Config    
    module.mqttHost="172.16.0.***"
    module.mqttPort="1883"
    module.mqttUserName="**************"
    module.mqttpassword="**************"
    module.mqttLwtTopic="NodeMCU/lwt/"..module.NodeID
  
    module.mqttSubscibeTopics={["NodeMCU/"..module.NodeID.."/command"]=0,["NodeMCU/"..module.NodeID.."/relayCh/+"]=0}
    module.mqttPublishTopicStatus="NodeMCU/"..module.NodeID.."/status/"
    module.mqttUpdateStatusInterval=60000
    module.mqttUpdateStatusTimerId=2
return module
```

You can use `table` object to store these parameter/value pairs instead of this module. Maybe later I will write a post about 'how to do that'.

* **Create MQTT client and set LWT**
```lua
m=mqtt.Client(config.NodeID, 10, config.mqttUserName, config.mqttpassword)
m:lwt(config.mqttLwtTopic, "Inactive", 0,1)
```
And do not forget to set **`isMqttAlive`** value to `false`. We will use this variable to determine if mqtt connection is alive or not. The initial value must be false, because at the first run the ESP isn't connected to the broker.

* **connectToMqtt() Function**

```lua
function connectToMqtt()
    m:connect(config.mqttHost, config.mqttPort, 0, 0, function(client) 
        isMqttAlive = true 
        print("Successfully Conencted to MQTT broker: "..config.mqttHost.." on port: "..config.mqttPort)

-- Here you can do some useful things. Example subscribe to a topic, or set up what should happen if a message is received. (`mqtt.client:on()`)

    end,
    function(con,reason)
        print("Faild to connect to MQTT broker: "..config.mqttHost.." on port: "..config.mqttPort..", Reason: "..reason)
    isMqttAlive = false
    end)
end
```

This function will be used to connect to the MQTT broker, and the `isMqttAlive` variable is also will be set here:
-If the ESP is successfully connected to the broker, `isMqttAlive` will be true.  
-If something goes wrong, this variable will be false.  


* **Set up mqtt.client:on("offline"....)**
```lua
m:on("offline", function(con) 
    isMqttAlive = false 
    print("Disconnected from MQTT")
end)
```
If the ESP disconnects from the broker this will set `isMqttAlive` to false.
 
* **Final steps**

After you call `connectToMqtt()` function you have to check the value of `isMqttAlive` before each message publication.

In my case I use a DHT22 sensor to monitor temperature and humidity, and I send update every 10 minutes. To do this a timer should be used. Example:

```lua
tmr.alarm(config.mqttUpdateStatusTimerId,config.mqttUpdateStatusInterval, tmr.ALARM_AUTO, function()
if isMqttAlive == false
    then
        print("Reconnect To MQTT:"..config.mqttHost.." on port: "..config.mqttPort)
        connectToMqtt()
    else
        print("MQTT is OK: "..config.mqttHost.." on port: "..config.mqttPort)
        mqttUpdateGeneralStatus(m)
    end
end)
```

As you can see, first,  I check if `isMqttAlive` is ture or false.
- If it is false I call `connectToMqtt()` function to (re)connect to the broker.  
- If it is true the `mqttUpdateGeneralStatus(m)` function will be called, which queries the sensor and send the actual temperature and humidity values to the broker.

* **A Complete Example**

```lua
local config=require("config")
local setup=require("setup")
local mqttSP=require("mqttSP")
m=mqtt.Client(config.NodeID, 10, config.mqttUserName, config.mqttpassword)
m:lwt(config.mqttLwtTopic, "Inactive", 0,1)


isMqttAlive=false

-- Conenct Function
function connectToMqtt()
    m:connect(config.mqttHost, config.mqttPort, 0, 0, function(client) 
        isMqttAlive = true 
        print("Successfully Conencted to MQTT broker: "..config.mqttHost.." on port: "..config.mqttPort)
        mqttSP.mqttSubsribe(m,config.mqttSubscibeTopics)
        mqttSP.mqttOnMessage(m)
        m:publish(config.mqttLwtTopic,"Active",0,1)
        m:on("offline", function(con) 
           isMqttAlive = false 
           print("Disconnected from MQTT")
        end)
    end,
    function(con,reason)
        print("Faild to connect to MQTT broker: "..config.mqttHost.." on port: "..config.mqttPort..", Reason: "..reason)
    end)
end

-- Connect To Broker
connectToMqtt()

-- Start Timer
tmr.alarm(config.mqttUpdateStatusTimerId,config.mqttUpdateStatusInterval, tmr.ALARM_AUTO, function()
if isMqttAlive == false
    then
        print("Reconnect To MQTT:"..config.mqttHost.." on port: "..config.mqttPort)
        connectToMqtt()
    else
        print("MQTT is OK: "..config.mqttHost.." on port: "..config.mqttPort)
        mqttSP.mqttUpdateGeneralStatus(m,setup.getPublicIp())
    end
end)
```
==**REFERENCES:**==

* https://nodemcu.readthedocs.io/en/master/en/modules/mqtt/




















