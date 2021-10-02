!!! caution
    **This page has been updated a long time ago.**  Information found here could be outdated and may lead to missconfiguration.  
    Some of the links and references may be broken or lead to non existing pages.  
    Please use this docs carefully. Most of the information here now is only for reference or example!

    
# How To Unbrick ESP8266 (Blinking Blue Led)

## TL;DR

I have some ESP8266 (NodeMCU DEV kit, ESP-01 and ESP07). Two of them bricked during firmware upgrade (Flashing). The first was my mistake because I mistyped the memory address, and the other was a power outage. So I had two bricked ESP. 
After I powered up the board, the blue led was blinking continuously and rapidly.
I tried to update the firmware with custom builds and with builds from [https://nodemcu-build.com/](https://nodemcu-build.com/), but all my tries was unsuccessful. 
I was a bit upset and was thinking about getting rid of them, but I never give up anything so easily.
After doing some google search I found some articles about the memory map of the ESP, and some article on "how to update boot loader". Honestly, I'm not a developer, and I couldn't say everything I read was clear to me, but finally I successfully brought two ESP back from the death. :) 
I'm writing this post just because I think it will be useful for someone, some time. I absolutely do not guarantee that this method will work in any cases, the only think I can suggest: do not give up trying, and googleing. :) And note that maybe your ESP has a different memory layout, so first do some search to find as many details about your ESP as you can.

## 1. Check your EPS8266 Symptoms
As I mentioned above the blue led on my esp was continuously blinking, when connected it to my computer. I used an USB to serial converter, and saw this message repeating endlessly:

```
 ets Jan  8 2013,rst cause:2, boot mode:(3,6)

load 0x40100000, len 25952, room 16 
tail 0
chksum 0x9a
load 0x3ffe8000, len 2276, room 8 
tail 12
chksum 0x03
ho 0 tail 12 room 4
load 0x3ffe88e4, len 8, room 12 
tail 8
chksum 0x3f
csum 0x3f
rf cal sector: 251
rf[112] 
```
I think this means that the ESP was restarting continuously, maybe because it couldn't find the boot loader or any of the necessary files. I could upload the firmware, so I think one of the following files must have been missing, corrupt or overwritten:

* blank.bin
* boot_v1.5.bin
* esp_init_data_default.bin

## 2. Collect The Necessary Files

The easiest way to do is download from this [link](https://drive.google.com/drive/folders/0B4xTxuaiVCZyaUlkZkNHN1c2RVE?usp=sharing).
Or you can download the SDK from [Gitub](https://github.com/esp8266/esp8266-wiki/tree/master/sdk) as well.

If the links become broken or unavailable, you have two options:
1. Do some search (Google is your best friend. :))
2. Compile the Nodemcu firmware (with SDK). To do this you can [follow my previous post](https://blog.vinczejanos.info/2016/10/24/how-to-compile-nodemcu-firmware/).

I don't want to write the whole process again, so after you successfully compiled NodeMCU firmware on your own, you should have the necessary files.

Actually you only have to compile ["esp-open-sdk"](https://github.com/pfalcon/esp-open-sdk), the NodeMCU firmware isn't definitely needed to unbrick, if you have a pre-compiled firmware, you can use it. 
**NOTE:** If you use some downloaded firmware instead of compiling one, please check which SDK was used for compiling!

The files you will need can be located here:
```
nodemcu@openhab:~/esp-open-sdk/ESP8266_NONOS_SDK_V1.5.4_16_05_20/bin$ find
.
./boot_v1.2.bin
./boot_v1.5.bin
./upgrade
./esp_init_data_default.bin
./at
./at/512+512
./at/512+512/user1.1024.new.2.bin
./at/512+512/user2.1024.new.2.bin
./at/README.md
./at/1024+1024
./at/1024+1024/user2.2048.new.5.bin
./at/1024+1024/user1.2048.new.5.bin
./at/noboot
./at/noboot/eagle.irom0text.bin
./at/noboot/eagle.flash.bin
./blank.bin
```

##3. Flashing the ESP
Before you flash the files to the ESP, double-check the size of its flash. 
Based on the following tables [^1] upload the files to the appropriate  memory address.

![](/assets/images/2016/10/more-addresses.jpg)

![](/assets/images/2016/10/2016-10-24_192541.jpg)

I used [nodemcu-flasher](https://github.com/nodemcu/nodemcu-flasher) to flash my ESP with these settings:
![2016-10-24_192917.jpg](/content/images/2016/10/2016-10-24_192917.jpg)

* blank.bin --> 0x7E000
* esp_init_data_default.bin --> 0x3FC000
* user1.1024.new.2.bin --> 0x01000
* boot_v1.5.bin --> 0x00000

The last step is to flash your firmware, for example with a custom build one:
```
nodemcu@openhab:~/nodemcu-firmware/bin$ ls -al
total 444
drwxr-xr-x  2 nodemcu nodemcu   4096 Oct 24 18:26 .
drwxr-xr-x 15 nodemcu nodemcu   4096 Nov  1 11:28 ..
-rw-r--r--  1 nodemcu nodemcu  28160 Nov  1 11:29 0x00000.bin
-rw-r--r--  1 nodemcu nodemcu 413495 Nov  1 11:29 0x10000.bin
-rw-r--r--  1 nodemcu nodemcu     79 Oct 24 18:20 .gitignore
```

I hope this post will be useful, and you will be able to unbrick your ESPs.

==**REFERENCES:**==

* [http://jasiek.me/2015/04/28/unbricking-an-esp8266-with-flashing-led.html](http://jasiek.me/2015/04/28/unbricking-an-esp8266-with-flashing-led.html)
* [http://www.electrodragon.com/w/ESP8266_AT_Commands](http://www.electrodragon.com/w/ESP8266_AT_Commands)
* [https://nodemcu.readthedocs.io/en/master/en/flash/](https://nodemcu.readthedocs.io/en/master/en/flash/) (Upgrading Firmware)
* [https://github.com/esp8266/esp8266-wiki/tree/master/sdk](https://github.com/esp8266/esp8266-wiki/tree/master/sdk)
* [https://github.com/esp8266/esp8266-wiki](https://github.com/esp8266/esp8266-wiki)

[^1]: * [https://espressif.com/sites/default/files/documentation/2a-esp8266-sdk_getting_started_guide_en.pdf](https://espressif.com/sites/default/files/documentation/2a-esp8266-sdk_getting_started_guide_en.pdf)










