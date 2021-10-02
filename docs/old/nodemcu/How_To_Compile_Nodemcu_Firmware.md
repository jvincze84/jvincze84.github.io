!!! caution
    **This page has been updated a long time ago.**  Information found here could be outdated and may lead to missconfiguration.  
    Some of the links and references may be broken or lead to non existing pages.  
    Please use this docs carefully. Most of the information here now is only for reference or example!
    
# How To Compile Nodemcu Firmware

In this post I will assist you through some easy steps on how to build NodeMCU firmware on your own. 
To do this firstly I created a vanilla Debian 8 OpenVZ container.

If you don't want to bother to compile NodeMCU firmware on your own, you have another option: you can make it online. [Here is the link](https://nodemcu-build.com/).

## 0. Step

Every time you install a new package you should start with updating your Linux system.
```bash
apt-get update
apt-get upgrade
```

```
root@nodemcu:~# uname -a
Linux nodemcu 2.6.32-39-pve #1 SMP Fri May 8 11:27:35 CEST 2015 x86_64 GNU/Linux
root@nodemcu:~# cat /etc/issue
Debian GNU/Linux 8 \n \l
```

## 1. Install the necessary packages

```bash
apt-get install git gcc make libtool-bin gperf bison flex build-essential texinfo automake libtool cvs autoconf libncurses5-dev help2man wget bzip2 python-dev python-serial python3-serial
```

You may need to install:
```bash
apt-get install gawk
```

## 2. Clone packages from git

* First we have to create a new user, because `esp-open-sdk` can not be compiled with root user.  
`useradd nodemcu`  
* Next create a working directory for nodemcu user:  
`mkdir /opt/nodemcu`  
* Give all permission:
```bash
chown -R nodemcu:nodemcu /opt/nodemcu/
chmod u+rwx /opt/nodemcu/
```
* Change to nodemcu user  
`sudo su - nodemcu`
* Clone the neccessary packages form Git.
```
cd /opt/nodemcu
git clone https://github.com/nodemcu/nodemcu-firmware
git clone --recursive https://github.com/pfalcon/esp-open-sdk
```
## 3. Compile `esp-open-sdk`
This package is needed to compile the NodeMCU firmware. Esp-open-sdk contains some tools which may will be useful in the future, for example tools to flash you ESP8266 board.

**Steps:**

* Change directory to /opt/nodemcu/esp-open-sdk   
`cd /opt/nodemcu/esp-open-sdk`
* Run make command  
`make STANDALONE=y`

If the compilation is successfully finished you should get something like that:
```
make[1]: Leaving directory '/opt/nodemcu/esp-open-sdk/esp-open-lwip'
cp -a esp-open-lwip/include/arch esp-open-lwip/include/lwip esp-open-lwip/include/netif \
    esp-open-lwip/include/lwipopts.h \
    /opt/nodemcu/esp-open-sdk/xtensa-lx106-elf/xtensa-lx106-elf/sysroot/usr/include/

Xtensa toolchain is built, to use it:

export PATH=/opt/nodemcu/esp-open-sdk/xtensa-lx106-elf/bin:$PATH

Espressif ESP8266 SDK is installed, its libraries and headers are merged with the toolchain


```
The point is the `export` line. Each time you want to compile NodeMCU firmware you have to run this export.

## 4. Configure and Compile NodeMCU firmware

### 4.1. Configuration
Before you run make command there are some configuration to do.
Configuration files:

``` bash
/opt/nodemcu/nodemcu-firmware/app/include/user_config.h
/opt/nodemcu/nodemcu-firmware/app/include/user_modules.h
/opt/nodemcu/nodemcu-firmware/app/include/user_version.h
```

* **user_version.h**  
In this file you can configure version related properties. Example:
```
#define NODE_VERSION    "NodeMCU 1.5.4.1 - custom bild by jvincze"
#ifndef BUILD_DATE  
#define BUILD_DATE        "2016-09-23"

```
* **user_modules.h**  
Here you can configure that which modules will be included in the firmware.
```
//#define LUA_USE_MODULES_AM2320 --> commented out, won't be compiled
//#define LUA_USE_MODULES_APA102
#define LUA_USE_MODULES_BIT --> will be compiled
//#define LUA_USE_MODULES_BMP085
```
* **user_config.h** 
In this file there are some board related configuration, for example: memory size.

**NOTE:**  
If you can not connect to your ESP after flashing it try to modify this value in `user_config.h`:
From:
`#define BIT_RATE_DEFAULT BIT_RATE_115200`  
To:
`#define BIT_RATE_DEFAULT BIT_RATE_9600`  

And re-flash your ESP.


### 4.2. Compilation
Now everything is ready to build our first NodeMCU firmware:
```
export PATH=/opt/nodemcu/esp-open-sdk/xtensa-lx106-elf/bin:$PATH
cd /opt/nodemcu/nodemcu-firmware
make
```
Our brand now firmware can be found here:
```
nodemcu@nodemcu:/opt/nodemcu/nodemcu-firmware/bin$ ls -al
total 392
drwxr-xr-x  2 nodemcu nodemcu   4096 Sep 23 14:02 .
drwxr-xr-x 15 nodemcu nodemcu   4096 Sep 23 13:58 ..
-rw-r--r--  1 nodemcu nodemcu     79 Sep 23 09:54 .gitignore
-rw-r--r--  1 nodemcu nodemcu  27808 Sep 23 14:02 0x00000.bin
-rw-r--r--  1 nodemcu nodemcu 354899 Sep 23 14:02 0x10000.bin
```

## References

* [https://github.com/nodemcu/nodemcu-firmware](https://github.com/nodemcu/nodemcu-firmware)
* [http://nodemcu.readthedocs.io/en/master/en/build/#linux-build-environment](https://github.com/nodemcu/nodemcu-firmware)
* [https://nodemcu-build.com/](https://github.com/nodemcu/nodemcu-firmware)
* [http://www.esp8266.com/wiki/doku.php?id=toolchain](https://github.com/nodemcu/nodemcu-firmware)
* [https://github.com/pfalcon/esp-open-sdk](https://github.com/nodemcu/nodemcu-firmware)

