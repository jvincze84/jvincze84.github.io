!!! caution
    **This page has been updated a long time ago.**  Information found here could be outdated and may lead to missconfiguration.  
    Some of the links and references may be broken or lead to non existing pages.  
    Please use this docs carefully. Most of the information here now is only for reference or example!

    
# Reliable MQTT conenction with NodeMCU

## TL;DR
I want to use ESP modules for my brand new project: **H**ome **A**utomatization **W**ith **O**penHAB (HAWO). :) To realise this I want to connect some ESP module to my OpenHAB server using MQTT broker (mosquitto). Building a complete Smart Home is not my goal (at least not now), I only want to control some lights / stuff with my phone (or tablet) and place some DHT22 (Temperature and Humidity) sensors in my house, workshop and garden.  
I started working with NodeMCU some months ago and I ran into several problems and bugs during my coding. I cannot write all my experience to this post, but I hope this will be helpful for you. :)

Steps to be done before you can connect to mqtt broker:

* Install and configure mosquitto mqtt broker 
* Connect ESP8266 module to your Wi-fi network  

Maybe later I will write a posts about these steps, but now I want to give more details only about mqtt connection in this thread. 
So I need a reliable connection to my mqtt broker which can handle network or other errors. Unfortunately for some reason mqtt module can not re-connect to broker for example if Wi-fi disconnect and reconnect. 
To better understand here is a basic example to connect to the broker.

```lua
m = mqtt.Client("ClienID", 60, "test", "test123")
m:connect("192.168.10.10", 1883, 0, 
  function(client) 
     print("connected") 
   end, 
 function(client, reason) 
  print("failed reason: "..reason) 
end)
```
When you specify `mqtt.client:connect()` you have on option to turn on/off auto-reconnect. 
`mqtt:connect(host[, port[, secure[, autoreconnect]]][, function(client)[, function(client, reason)]])`

## What kind of problem can occurr?

* Wi-fi disconnection 
* MQTT broker become unavailable or is being restarted.
* Other network issues (eg.: DNS error)
* Misconfiguration: bad username, password, etc.

My biggest problem is that the connection between ESP and the broker cannot be tested in any way. 
Based on my experiences I ran into these problems:

* Using **autoreconnect true**
  * If I restart mosquitto the clients reconnect to it successfully. 
  * But if I disconnect and connect to Wi-fi, the clients can not reconnect. This is a big problem because you can not reconnect to the broker. If you try `mqtt.client:connect()` again ESP will give you "Already Connected" error message. If you try firstly `mqtt.client:close()` the ESP will be restarted. I do not know if this behavior is a bug or a feature but it is really annoying.

I tried to check if the connection is established or not with this `if` condition:  
```lua
if  m:publish(config.mqttLwtTopic,"Active",0,1)
  then
    DO SOMETHING
  else
    DO SOMETHING ELSE
end
```

But if you use autoreconnect=true it will return with true in any case, regardless whether  the message has been delivered or not. 

* Using **autoreconnect false**  
It can be a good option but in this case we have to check the connection manually, and reconnect if something happens. 

My final solution is two functions and a timer combined with each other:
```lua
local function checkLwt()
    if  m:publish(config.mqttLwtTopic,"Active",0,1)
        then
            return true
        else
            return false
    end
end

local function connectReconnect()
    m:connect(config.mqttHost, config.mqttPort, 0, 0,
    function(client) 
            print("MQTT connected to: "..config.mqttHost) 
            subsribe()
            onMessage()
            tmr.start(config.mqttCheckTimerId)
    end, 
    function(client, reason) 
            print("failed reason: "..reason) 
            print("Sleep for 10 secs")
            tmr.alarm(6,10000,tmr.ALARM_SINGLE, function()
                connectReconnect()
            end)
 
            
    end)
end
tmr.register(config.mqttCheckTimerId,config.mqttTmrDelay, tmr.ALARM_AUTO,
function()
        local status, err = pcall(checkLwt)
        if status == true and err == true
        then
            print("LWT OK")
            updateStatus()
        elseif status == true and err == false
        then
            print("LWT FAILED")
            connectReconnect()
        end
        if status == false and err ~= true
        then
                print("LWT faild with notconnected...")
                tmr.stop(config.mqttCheckTimerId)
        end
                

end)
```

## checkLwt()

There are three scenarios:

* Message is successfully delivered. Return true.
* Message is failed to deliver. Return false.
* And the last one is the worst. :( If this function is called while the client is trying to connect to the broker it will fail with "Not Connected" exception and ESP will be restarted. That's why I use `pcall` (Protected Call) in the timer.

```lua
local status, err = pcall(checkLwt)
if status == true and err == true
...

```
The `status` is true when the function returns without exception. It prevents the ESP from restarting if the function throws an exception (Not Connected). Status can be true or false.
The `err` can be `true` or the error message of the exception.
Based on that 3 scenario exists:

* `status == true and err == true`  
  The function successfully finished. Everything is OK.
* `status == true and err == false`  
In this situation probably there is something with mqtt server. For example it stopped or is unreachable.
* `status == false and err ~= true`  
Please not that I use "not equal" `~=` because err can be an error message as well. 
So in this situation it is likely that we get "not connected" exception, and maybe something happened with the Wi-fi connection.
* bonus: `status == false and err == true`  
O.K. This is not possible. If status is false it means that we got an exception thus err could not be true.

## connectReconnect() & tmr()

This is the main part of my code. What will happen when connectReconnect function is called?

1. If the connection to the broker is successful
  * the timer will be started
  * and some other functions will be called. 
1. If the client failed to connect to the broker
  * Wait 10 secs and the function will call itself.  
As you can see this is a recursive function which continuously call itself until the connection is established.
The timer check whether the publication is working or not. Why  is it necessary to use 2 different error conditions? If the checkLwt fails, we have to know why, because if it fails due to **the broker unavailability**, callback events of `mqtt.client:connect()` won't work, neither the success nor the failed function will run.

At first `status == true and err == false` condition will be always true, and connectReconnect() function will be called. From that point there are two error case:

* There is some network error, for example "DNS failure!". In this case the function will call itself. BUT! The timer is still running and will run into the `status == false and err ~= true` condition (because of "Not Connected" exception). We have to stop the timer because it is unnecessary.  The recursive function will call itself until the connection is not ready, and if we call `mqtt.client:connect()` multiple times, we will get "Already Connected" exception.
* The broker is shut down: `status == true and err == false` As I mentioned in this case the callback event of  `mqtt.client:connect()` won't work that's why we have to call connectReconnect() until the connection is not ready. 

I've created a table for the better understanding of `status` and `err`:

![Table](/assets/images/2016/09/2016-09-23_114913.jpg)


**Two** more very **important** things:

* Call connectReconnect() function after the network connection is successfully established. 
* Register the "offline" callback event:
```lua
m:on("offline", function(con) 
    print ("Offline") 
    setup.resetRelay()
    tmr.start(config.mqttCheckTimerId)
end) 
```

**==NOTE==**  
Always start the connection procedure by starting the timer, not by calling conenctReconnect() function. (`tmr.start(config.mqttCheckTimerId)`)!!! 
Why? Because if you are connected to Wi-fi network and call connectReconnect() function, but MQTT broker is unavailable the timer never will be started, because `mqtt.client:connect()` will fail and neither the true nor the false function will be called (because of previously mentioned bug).

**Summary:**

Maybe this is not the best solution but I failed to find better one. I tried uncountable   variations of functions and timers and their combinations. The most important for me that the connection has to be reliable, and in case of any error ESP has to be reconnected to the broker.
Maybe when the mentioned bugs will be fixed in the future, it will be enough to use only the reconnect=true option.

You can download my full example from this [link](https://drive.google.com/drive/folders/0B4xTxuaiVCZyZm0yMEpJMWNGclk?usp=sharing).

**==References:==**

* https://docs.coronalabs.com/api/library/index.html
* https://nodemcu.readthedocs.io/en/master/
* https://www.lua.org/pil/8.5.html

==**UPDATE:**== [Reliable MQTT connection with NodeMCU (part 2)](http://blog.vinczejanos.info/2016/12/21/reliable-mqtt-connection-with-nodemcu-part-2/)

