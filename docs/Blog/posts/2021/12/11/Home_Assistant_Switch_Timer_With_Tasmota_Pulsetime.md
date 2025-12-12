---
title: Home Assistant Switch Timer With Tasmota Pulsetime
date: 2021-12-11
---

# Home Assistant Switch Timer With Tasmota Pulsetime

## Motivation

I have several switches in my house and garden which can be controlled from Home Assistant. But sometimes I forget to turn them off. So there are some lights in the garden which should turn off after a certain time. For example I almost always forgot to turn off the light which directed to front gate of my garden after my arrives home.  
All of my devices are flahed with [Tasmota](https://tasmota.github.io/docs/) firmware. Tasmota has a built in command to turn off the relay after certain period of time called "Pulsetime":


!!! quote
    PulseTime<x>  Display the amount of PulseTime remaining on the corresponding Relay<x>  
  
    <value> Set the duration to keep Relay<x> ON when Power<x> ON command is issued. After this amount of time, the power will be turned OFF.  
    0 / OFF = disable use of PulseTime for Relay<x>  
    1..111 = set PulseTime for Relay<x> in 0.1 second increments  
    112..64900 = set PulseTime for Relay<x>, offset by 100, in 1 second increments. Add 100 to desired interval in seconds, e.g., PulseTime 113 = 13 seconds and PulseTime 460 = 6   minutes (i.e., 360 seconds)    
    Note if you have more than 8 relays:  
    Defined PulseTime for relays <1-8> will also be active for correspondent Relay <9-16>.

<!-- more -->

My goal is to set this `PulseTime` value from my Home Assistant dashboard. There are several ways to achieve my goal, but I wanted to use the "native" Tasmota way. Maybe the only noticeable reason for using `PulsTime` is that this solution work even if the Home Assistant server or the network become unavailable, and you turn on your light with a button or switch. Many Sonoff device have button on them with which you can control the device without network connection.

Most of you may want to use the Home Assistant [Timer](https://www.home-assistant.io/integrations/timer/) function, and there are a lot of article about this topic on the Internet, but not much which focus on the `PulseTime` feature.

Before we begin I show you how it works, and you can decide to read more or leave. :D

Here is a picture of my controlling Dashboard:

<figure markdown> 
  ![Dummy image](/assets/images/1639139607.jpg)
  <figcaption>Fig 1</figcaption>
</figure>

I will refer to this picture a lot later in this post as `Fig 1`.

1. Drop Down list: You can select which device do you want to set up.
    + Helper Name: `input_select.timer_set`
    + Related Automation: [Changing The Device In The Dropdown List](#changing-the-device-in-the-dropdown-list)
2. Actual Value: This widget show you the actual value of the selected device. This box is automatically updated right after you select the device from the Drop Down list.
    + Helper Name: `input_number.pulsetimeactualvalue`
    + Related Automation: [Catch MQTT Message](#catch-mqtt-message)
3. Input field: You can specify the new value. Right after you typed the new number the PulseTime value is sent to the device via MQTT. Meanwhile the Actual value also updated.
    + Helper Name: `input_number.number`
    + Related Automation: [Set New PulseTime Value](#set-new-pulsetime-value)
4. Button for send the command to the device. This can be useful if you want to set the same value for several devices. Select the first device, set the new value, then select another device and without typing the value just push the button. This button is also useful if the device did not get the message for some reason and you want to resend.
    + Related Script: [PulseTime Set New](#pulsetime-set-new)
5. This button updates the "Debug" Markdown filed (6.). The 5. and 6. elements are optional and only for debugging.
    + Related Script: [Check Debug](#check-debug)

I try to explain my solution as detailed as I can, and I hope you will be able to adopt it to your setup if you want.

## End Device Configuration (Tasmota - MQTT)

### Topic

The first and really important thing is to see how I use the mqtt device topic. 

This is my schema: `sonoff/[DEVICE MAC ADDRESS]/[%prefix%]`

!!! info
    I use the MAC address without colons. Example: `AABBCCDDEE` or `1E2F3D4C5A`

**Screenshot Example**

![1639157794.jpg](/assets/images/1639157794.jpg)


Topic examples:

* Command: `sonoff/600194AD2A3C/cmnd/power`
* Command: `sonoff/tasmotas/cmnd/status`
* State: `sonoff/600194AD2A3C/tele/STATE`
* Status:`sonoff/600194AD2A3C/stat/STATUS`

Why I am using MAC address? Although MAC address is not so human friendly, but unique and clearly identifies the device. Example: You can easily find the device in your router if you are using DHCP. But, later you will see that no matter what topic you are using, it does not effect the `PulseTime` configuration much, you just have to understand how it works and adopt your to topic.

### Home Assistant Integration

Official documentation: [https://www.home-assistant.io/integrations/tasmota/](https://www.home-assistant.io/integrations/tasmota/)

**Important options:**

* Native discovery: `SetOption19 0`
* `SetOption30 0` for switches. (default)
* `SetOption30 1` for lights. 
* (Optional) `GroupTopic1 tasmotas`

**Other useful commands (Using `Grouptopic` and MQTT):**

* Set Timezone according my country.
```plain
sonoff/tasmotas/cmnd/Timezone -m '99'
sonoff/tasmotas/cmnd/TimeDST -m '0,0,3,1,2,120'
sonoff/tasmotas/cmnd/TimeSTD -m '0,0,10,1,3,60'
```
* Set `teleperiod` to 30 secs
```plain
sonoff/tasmotas/cmnd/TelePeriod -m '30'
```
* Set Syslog server
```plain
sonoff/tasmotas/cmnd/SysLog -m '3'
sonoff/tasmotas/cmnd/LogHost -m '172.16.0.100'
sonoff/tasmotas/cmnd/LogPort -m '514'
```
*  Display hostname and IP address in GUI
```plain
sonoff/tasmotas/cmnd/SetOption53 -m '1'
```

## Home Assistant - Helpers

We have to configure some helpers on the webUI: `Configuration-->Helpers`

### New Value

* Fig 1 / 3
* Helper name: `input_number.number` (Sorry for the naming :) )

This Helper is responsible for storing the new `Pulsetime`  value. 

![1639158264.jpg](/assets/images/1639158264.jpg)

### Actual Value

* Fig 1 / 2
* Helper name:  `input_number.pulsetimeactualvalue` 

This Helper holds the actual value of the selected Device.

![1639158918.jpg](/assets/images/1639158918.jpg)

### Actual MAC

* Fig 1 / 6 (Actual MAC)
* Helper name: `input_text.pulsetimeactualmac` 

This will store the actual topic, and displayed in the debug box. (Sorry for the naming, again)

![1639158366.jpg](/assets/images/1639158366.jpg)

### Last Result Message

* Fig 1 / 6 (Last Result)
* Helper name: `input_text.result` 

This stores the MQTT message from the device.

![1639158586.jpg](/assets/images/1639158586.jpg)


Example message:
```json linenums="1"
{
  "PulseTime1": {
    "Set": 0,
    "Remaining": 0
  }
}
```

Unfortunately tasmota don't send the actual `PulseTime` value with any of the `tele` messages, thus manually trigger is required. There are two situation when tasmota reply with this message:

 * When you set up a new value. `sonoff/BCDDC2802856/cmnd/pulsetime1 -m 1000`
 * Or send `null` message to the above topic. `sonoff/BCDDC2802856/cmnd/pulsetime1 -n`
 

### Drop Down list

* Fig 1 / 1
* Helper name: `input_select.timer_set` 

Here we build a list contains all the device which we want to use with `Pulsetime`. You can use human readable name or whatever you want. 

![1639158768.jpg](/assets/images/1639158768.jpg)

## Home Assistant - Automations

### Changing The Device In The Dropdown List

#### Trigger

This automation is triggered immediately after you have selected a new device form the drop down list.

```yaml linenums="1"
trigger:
  - platform: state
    entity_id: input_select.timer_set
```

#### Action

```yaml linenums="1"
action:
  - service: input_text.set_value
    target:
      entity_id: input_text.pulsetimeactualmac
    data:
      value: |
        {% set mapper =
          { 'Left Side Light':'sonoff/600194AD2A3C/cmnd/pulsetime1',
            'Kitchen Spot':'sonoff/600194AD7228/cmnd/pulsetime1',
            'Front Light': 'sonoff/DC4F22378237/cmnd/pulsetime1',
            'S20 - 02 - Bathroom Fan': 'sonoff/BCDDC28027AD/cmnd/pulsetime1',
            'S20 - 01 - Christmas Light': 'sonoff/BCDDC2802856/cmnd/pulsetime1'
          } %}
        {% set mac = mapper[states('input_select.timer_set')] %}
        {% if mac == NULL %}
          UNKNOWN
        {% else %}
          {{ mac }}
        {% endif %}
  - service: mqtt.publish
    data:
      topic: |
        {{ states('input_text.pulsetimeactualmac') }}
```

As you can see we have one `trigger` and two `action`s. 
The trigger is really simple: this automation is triggered when you select another device, as I wrote before.

We have to create a `mapper` to know which topic is mapped to the selected device. This was the hardest part of the whole project, figure out how to create relation between the selected device name and the topic to which we send messages. You may think it would be easier if I used the name of the device in the topic instead of the MAC address. But no. I have some 4CH sonoff device, and in this case the we have different `Pulstime` values for each channel. (`Pulsetime1, Pulsetime2 . . .`) So we need exact match between the selected equipment  (switch) and the device plus the channel number. This `mapper` was the best solution I could find.

!!! caution
    You have to specify the exact text here which you entered in the `input_select` helpers (case sensitive and check the leading and trailing white spaces twice)

So the `input_text.pulsetimeactualmac` will be either one of the topic or `UNKNOWN` if no mapper found.

The other action (`mqtt.publish`) publishes the previously selected topic using the mapper. Notice that we don't have `message` part here, just the topic. As I mentioned earlier this way the tasmota device will reply with the actual value in JSON format. To better understanding here is an example with Mosquitto:

```bash
mosquitto_pub -h [MQTT HOST] -u [MQTT USERNAME] -P [MQTT PASSWORD] -t 'sonoff/BCDDC2802856/cmnd/pulsetime1' -n
```

Reply:
```
sonoff/BCDDC2802856/stat/RESULT {"PulseTime1":{"Set":0,"Remaining":0}}
```

We have two goals with this JSON message:

* Store the "Set" value (0) to `input_number.pulsetimeactualvalue` helper. 
* Store the entire JSON message to `input_text.result` helper for debugging.

But to achive this we need another automation which I named "Catch MQTT Message" and the subject of the next chapter.


So the `mqtt.publish` action publishes `sonoff/BCDDC2802856/cmnd/pulsetime1` and we store the entire JSON `{"PulseTime1":{"Set":0,"Remaining":0}}` to `input_text.result` for debugging, and the '0' to `input_number.pulsetimeactualvalue`. 

Download entire `yaml`: [hass-automation-dropdown.yaml](https://github.com/jvincze84/jvincze84.github.io/blob/master/docs/files/hass-automation-dropdown.yaml)

### Catch MQTT Message

Let's see how we handle the received message.

#### Trigger

```yaml linenums="1"
trigger:
  - platform: mqtt
    topic: sonoff/+/stat/RESULT
    id: frommqtt
```

We subsribed for the `sonoff/+/stat/RESULT` topic. 

!!! info
    If you need explanation about what the `+` sign means please visit this site: [https://www.hivemq.com/blog/mqtt-essentials-part-5-mqtt-topics-best-practices/](https://www.hivemq.com/blog/mqtt-essentials-part-5-mqtt-topics-best-practices/)  
    With one world: single-level wild card.

Ok. But we have a problem. Tasmota may publish other result messages than `Pulsetime`. For example when a light turned on or off. Example:

```plain
sonoff/6001949C6548/stat/RESULT {"POWER1":"ON"}
sonoff/6001949C6548/stat/RESULT {"POWER2":"ON"}
sonoff/DC4F22378237/stat/RESULT {"POWER":"ON"}
sonoff/6001949C6548/stat/RESULT {"POWER3":"ON"}
sonoff/6001949C6548/stat/RESULT {"POWER4":"ON"}
sonoff/6001949C6548/stat/RESULT {"POWER1":"OFF"}
sonoff/DC4F22378237/stat/RESULT {"POWER":"OFF"}
sonoff/6001949C6548/stat/RESULT {"POWER2":"OFF"}
sonoff/6001949C6548/stat/RESULT {"POWER3":"OFF"}
sonoff/6001949C6548/stat/RESULT {"POWER4":"OFF"}
```

This will cause error when we try to parese the json... I want to explain what I'm talking about through an example.

As we discussed earlier we need the actual pulsetime from the device/channel. We can parse the JSON like this:

```bash title="Command"
echo -n '{"PulseTime1":{"Set":0,"Remaining":0}}' | jq -r '.PulseTime1.Set'
```
```text title="Output"
0
```

But what happens with the `{"POWER4":"OFF"}` message:

```bash title="Command"
echo -n '{"POWER4":"OFF"}' | jq -r '.PulseTime1.Set'
```
```text title="Output"
null
```

We got a big `null`. To avoid error or warn messages in the Home Assistant log we should filter the messages and process only the relevants. That's why we have condition.


#### Conditions

```yaml linenums="1"
condition:
  - condition: template
    value_template: '{{ ''PulseTime'' in  trigger.payload }}'
  - condition: template
    value_template: >-
      {{ trigger.topic.split('/')[1] in states('input_text.pulsetimeactualmac')
      }}
```

The **first** is a really simple condition. If the received JSON contains `PulseTime` we proceed to the Actions.

The **second** is a bit more complicated. We have to be sure that the MQTT message came from the right device. Why? I explain you:  
You selected the "Kitchen Spot" from the drop down list. The `input_number.pulseTimeActualValue` and `input_text.pulsetimeactualmac` set according to the selection. That's rigth. But if you send `PulseTime1` command to another device for example from the WebUI, the Automation is triggerd and set the wrong values. Simply: we need to check the MAC address and "Pulstime" word, as well.



#### Actions

```yaml linenums="1"
action:
  - service: input_number.set_value
    target:
      entity_id: input_number.pulseTimeActualValue
    data:
      value: |
        {% if "PulseTime1" in trigger.payload_json %}
          {% set pulseTime =  trigger.payload_json.PulseTime1.Set | int %}
        {% elif "PulseTime2" in trigger.payload_json %}
          {% set pulseTime =  trigger.payload_json.PulseTime2.Set | int %}
        {% elif "PulseTime3" in trigger.payload_json %}
          {% set pulseTime =  trigger.payload_json.PulseTime3.Set | int %}
        {% elif "PulseTime4" in trigger.payload_json %}
          {% set pulseTime =  trigger.payload_json.PulseTime4.Set | int %}
        {% else %}
          {% set pulseTime =  "notset" %}
        {% endif %}

        {% if  pulseTime != 'notset' %}
          {% if  pulseTime == 0 %}
            0
          {% else %}
            {{ ( pulseTime | int - 100 ) / 60 }}
          {% endif %}
        {% endif %}
  - service: input_text.set_value
    target:
      entity_id: input_text.result
    data:
      value: '{{trigger.payload_json}}'
```

When a new device is selected from the drop down list (Fig 1 / 1) we want to tihngs:

* See the actual value (Fig 1 / 2) - The first action is responsible for this (`input_number.set_value`)
* Display the entire JSON in the Debug box (Fig 1 / 6) The second action will do this (`input_text.set_value`)

Do remember that this Automation is closely connected to the previos one. We can say that the result of previously discussed Automation triggers this one: 

1. You select a new device from the drop down list
2. "Changing The Device In The Dropdown List" Automation is triggerdm and publish MQTT message.
3. This Automation catches the MQTT JSON message and process it.

The first action set the value of `input_number.pulseTimeActualValue` helper. But we have problem again. What about the multi-channel devices? We want to cofigure each channel separately, right? So we have to figure out the received message related to which channel? I've solved this problem with some `if - elif` cndition: If the JSON playload contains "PulseTime1" than we parse the json and store the value of the "Set" into the `pulseTime` variable.



Maybe this block have to be mentioned, as well:
```yaml linenums="1"
        {% if  pulseTime != 'notset' %}
          {% if  pulseTime == 0 %}
            0
          {% else %}
            {{ ( pulseTime | int - 100 ) / 60 }}
          {% endif %}
        {% endif %}
```

This all magic because of this behaviour:

!!! quota
    112..64900 = set PulseTime for Relay<x>, offset by 100, in 1 second increments. Add 100 to desired interval in seconds, e.g., PulseTime 113 = 13 seconds and PulseTime 460 = 6 minutes (i.e., 360 seconds)

* If we get `0` it means `0` --> PulseTime is disabled
* If we get for example `160`  it means `160 - 100=60` seconds (1min).

The second action (`input_text.set_value`) simply set the `input_text.result` helper value to the entire JSON message.

Downlaod entire `yaml`: [hass-automation-catchmqtt.yaml](https://github.com/jvincze84/jvincze84.github.io/blob/master/docs/files/hass-automation-catchmqtt.yaml)

### Set New PulseTime Value

Now we have only one Automation left to discuss. Everything we did before is useless if we can't set new value. This Automation is intended for do this. I can say that this is the most simpler from all. Everithing is prepared in the previous automations, so the only purpose of this automation is to set the desired new value.

#### Trigger

```yaml linenums="1"
trigger:
  - platform: state
    entity_id: input_number.number
```

Simple trigger: when a new value is set. I think no explanation is required.


#### Action

```yaml linenums="1"
action:
  - service: mqtt.publish
    data:
      topic: |
        {{ states('input_text.pulsetimeactualmac') }}
      payload: |
        {% set timer = ( trigger.to_state.state |  int * 60  ) + 100  %}
        {% if timer == 100 %}
          0
        {% else %}
          {{ timer }}
        {% endif %}
```

As we discussed earlier tasmota handle the pulsetime in a bit strange way. Do remember what we did, when we needed to transform the received value:
```plain
{{ ( pulseTime | int - 100 ) / 60 }}
```

Now we should do the opposite:
```plain
{% set timer = ( trigger.to_state.state |  int * 60  ) + 100  %}
```

What does `{% if timer == 100 %}`  mean?  
If you set the PulseTime value to zero (disable pulsetime): `0 * 60 + 100 = 100`  
That's why we need to specially handle the `100` value.

??? quota
    112..64900 = set PulseTime for Relay<x>, offset by 100, in 1 second increments. Add 100 to desired interval in seconds, e.g., PulseTime 113 = 13 seconds and PulseTime 460 = 6 minutes (i.e., 360 seconds)

Download entire `yaml`: [hass-automation-setnew.yaml](https://github.com/jvincze84/jvincze84.github.io/blob/master/docs/files/hass-automation-setnew.yaml)

---


## Home Assistant Scipts

Ok we are almost done. Only two part we have to mention. Do you remember the "PulseTime Set New" and "Check Debug" buttons (Fig 1 / 4 and 5)? 

!!! hint
    I don't provide download link to scripts, because the entire scripts are copied here.

### PulseTime Set New

```yaml linenums="1"
alias: PulseTime Set New
sequence:
  - service: mqtt.publish
    data:
      topic: |
        {{ states('input_text.pulsetimeactualmac') }}
      payload: |
        {% set timer = ( states('input_number.number') |  int * 60  ) + 100  %}
        {% if timer == 100 %}
          0
        {% else %}
          {{ timer }}
        {% endif %}
mode: single
```

I think every part of this script is discussed earlier and I don't want to repeat myself. :D


### Check Debug

```yaml linenums="1"
sequence:
  - service: mqtt.publish
    data:
      topic: '{{ states(''input_text.pulsetimeactualmac'') }}'
mode: single
alias: Pulsetime Check Debug
icon: mdi:update
```

Simply publish to topic stored in `input_text.pulsetimeactualmac` helper.

---

## Home Assistant Dashboard

For your convenience  I share the dashboard I use (Fig 1). Here you can check how each components are used.

```yaml linenums="1"
title: Otthon
views:
  - title: Timer
    path: prtoba
    icon: mdi:hammer-wrench
    badges: []
    cards:
      - type: entities
        entities:
          - input_select.timer_set
      - type: horizontal-stack
        cards:
          - type: entity
            entity: input_number.pulsetimeactualvalue
            name: Actual
          - type: entities
            entities:
              - input_number.number
            title: Set New
      - type: horizontal-stack
        cards:
          - type: button
            tap_action:
              action: toggle
            entity: script.pulsetime_set_new
            icon: mdi:check
            icon_height: 50px
          - type: button
            tap_action:
              action: toggle
            entity: script.update_all_infos
            show_state: false
            show_icon: true
            icon_height: 30px
            name: Check Debug
            icon: mdi:eye-check-outline
      - type: markdown
        content: |+
          * Last Result:
          ```json
          {{ states('input_text.result') }}
          ```

          * Actual MAC:
          ```json
          {{ states('input_text.pulsetimeactualmac') }}
          ```

          * Split
          ```json
          {{ states('input_text.pulsetimeactualmac').split('/')[1] }}
          ```
        title: Debug
```

## Summary

I do know that there are several other easier ways to achieve this functionality, but I think using Tasmota native `Pulsetime` feature is a good approach.

**Thank you for reading**, and hope this article (or some parts of it) was helpful for you.




