# Tips And Tricks

In this page I will share you some random tips and tricks I use in my daily life, and I will update this post frequently.
Some of them will be commented, but not all.

---

## **Generate random strings**
`tr -cd '[:alnum:]' < /dev/./urandom | fold -w12 | head -n4`  
You can use these string for example as random generated passwords.

---

## **Run simple python http server**

`nohup python -m SimpleHTTPServer 8888 >>../access.log &`  
This will create a very simple http server on port 8888. 
Useful for shearing files quickly and easily over http protocol.

---

## **Poor man's VPN with sshuttle**
`sshuttle -r [USER]@[HOSTNAME] 0.0.0.0/0 --dns -v`

---

## **Split MP3 into equal time length slices**
Install required package: `apt-get install poc-streamer`
Split into 3mins slices:
`mp3splt  -t  3.00  [MP3 FILE] -o @n`  
Output will be: 01.mp3, 02.mp3, 04.mp3 . . . .

---

## **Convert  Video to 1280X (lower quality)**
It us useful when you want to convert your video files to lower quality.
Command:
```bash
avconv -y -i $MOVIE -vf "scale=1280:trunc(ow/a/2)*2" -vcodec libx264 -acodec libmp3lame $NEWNAME
```
Where:

  * **-y** overwrite output files
  * **-i** input files
  * **-vf scale=1280:trunc(ow/a/2)*2"** --> Keep original ratio, and avoid "height not divisible by 2" error message.
  * **-vcodec libx264** --> video codec
  * **-acodec libmp3lame** --> audio codec

You can replace "1280" to any other values which is divisible by 2. (640,480,etc...)

---

## **LUA - delay function**
Sometimes you have to use delay before the next function, and in this situation can be useful this little function.
```lua
function sleepAndContinueWithCommand(command)
    print("sleepAndContinueWithCommand Function")
    tmr.alarm(6,2000,tmr.ALARM_SINGLE, function()
        command()
   end) 
```

How to call it?
`sleepAndContinueWithCommand(FUNCTION_NAME)`

---

## **Modify Post Width of Ghost Blog**

Change `max-width` in this section
```css
/* Every post, on every page, gets this style on its <article> tag */
.post {
    position: relative;
    width: 80%;
    max-width: 1000px;
    margin: 4rem auto;
    padding-bottom: 4rem;
    border-bottom: #EBF2F6 1px solid;
    word-wrap: break-word;
}
```
---
## **Limit OprengePI CPU cores (enable/disable cores)**

```
echo 1 >/sys/devices/system/cpu/cpu0/online
echo 0 >/sys/devices/system/cpu/cpu1/online
echo 0 >/sys/devices/system/cpu/cpu2/online
echo 0 >/sys/devices/system/cpu/cpu3/online
```

Check CPU temperature:

`/sys/devices/virtual/thermal/thermal_zone0/temp`

---
## **tar from/to remote machine**

**tar from remote machine:**  
```bash
ssh root@172.16.0.240 "tar cfz - /etc /opt" >output.tar.gz
```

**tar to remote machine:**  
```bash
tar cvf - *.sh | ssh vinyo@172.16.0.240 "cat  >~/test.tar.gz"
```

**untar from remote machine**  
```bash
ssh vinyo@172.16.0.240 "cat ~/test.tar.gz" | tar xv  #OR
ssh vinyo@172.16.0.240 "cat ~/test.tar.gz" | tar xvf - 
```

**untar to remote machine**  
```bash
cat test.tar.gz | ssh 172.16.0.250 "cd /home/vinyo/temp ; tar xv" #OR
cat test.tar.gz | ssh 172.16.0.250 "cd /home/vinyo/temp ; tar xvf -"
```

---

## **Raspberry - prevent to sleep Wifi**

Find your Wifi chip module:
`ls -la /sys/module/`  
Mine is: 
`/sys/module/8189es/`  
Check power management status:  
`cat /sys/module/8189es/parameters/rtw_power_mgnt` 
If it is equal to 0 then you are OK.
If not, create a file something like this:
```
cat /etc/modprobe.d/8189es.conf 
options 8189es rtw_power_mgnt=0 rtw_enusbss=0
```

Restart.

---

## **Rename OpenVZ container**
`vzctl set [CTID] --hostname [NEW HOSTNAME] --save`

---
## **Unzip Each .zip File To Separate Directory**

You have to be in the directory which contains the .zip files.

```bash
for Z in $( find . -type f -name '*.zip') ; do B=$( basename $Z ) ; F=${B%.*} ; mkdir $F ; unzip $Z -d $F ; done
```

---
## **Read Parameter File In Linux Shell (bash)**

```bash
while IFS='=' read -r key value
do
    echo "... $key='$value'"
    eval "$key='$value'"
done < $PARAM_FILE
```
**Where:**

* `$PARAM_FILE` --> File which contains the paramter and values.
* `IFS='='` Internal Field Separator. Parameter names and Values are separated by `=` sign.  Example: `appname=weblogic`
* `eval "$key='$value'"` --> This will create system environment. 

---

## **Some Linux Console Fun**
Try them out, if you are brave enough. :)
```
apt-get moo
apt-get install sl  
apt-get install furtune
apt-get install cowsay
apt-get install figlet
```
Examples:

sl
```bash
fortune | cowsay
figlet "Hello"
```


---

## **Run command without X display**
This method can be useful when you want to run a command (which needs X11 display), but X11 display isn't running on your system. 
Typical error message: `failed to commit changes to dconf: Cannot autolaunch D-Bus without X11 $DISPLAY`
The solution is: **xvfb-run**

```bash
xvfb-run  -  run  specified  X  client or command in a virtual X server environment
```

**Install:**

```bash
apt-cache search xvfb-run
xvfb - Virtual Framebuffer 'fake' X server

apt-get install xvfb
```

How to use it?
```bash
xvfb-run --server-args="-screen 0, 1024x768x24" /usr/bin/ssconvert --export-type=Gnumeric_Excel:excel_dsf 20161105_090001.html 20161105_090001.xls
```

Or from a shell script:
```bash
xvfb-run --server-args="-screen 0, 1024x768x24" /usr/bin/wkhtmltopdf $*
```

There are 2 typical command I'm using with xvfb-run: `ssconvert` and `wkhtmltopdf `

---

## **Simple Image Viewer For Linux**

feh -- image viewer and cataloguer

---
## **Failed To Install Cisco AnyConnect on Xubuntu 16.04**

Error message: `Failed to start vpnagentd.service: Unit vpnagentd.service not found.` 

Solution:
```bash
apt install network-manager-openconnect
systemctl daemon-reload
```

Then restart the install.
==REFERENCE:==

[https://technicalsanctuary.wordpress.com/2016/05/28/installing-cisco-anyconnect-vpn-on-ubuntu-16-04/]()

---


## **Configure Extra Mouse Buttons Under Linux**##

This solution is tested on Linux Mint (Sarah) and Xubuntu 16.04.
So I have a Logitech M505 mouse and I love using the vertical scroll button to minimize and maximize the active window. I have never used these buttons according to its original function, they were always configured to minimize and maximize Window.

### What you need to install?
* xbindkeys
* xvkbd
* xdotool
* wmctrl  

Install them with one command: `sudo apt install xbindkeys xvkbd xdotool wmctrl`

### Create sample configuration file
`xbindkeys -d > ~/.xbindkeysrc`  
This will create a sample configuration file in your home directory.

Please remove the "Examples of commands:" section from this file to avoid furtherer conflicts.

```
"xbindkeys_show" 
  control+shift + q
```

### Determine the ID of the buttons you want to use
It is very simple. Just run `xev` command.

For example my left button code (button 1):
```
ButtonPress event, serial 37, synthetic NO, window 0x4800001,
    root 0xc5, subw 0x0, time 7138218, (103,85), root:(965,1564),
    state 0x10, button 1, same_screen YES

ButtonRelease event, serial 37, synthetic NO, window 0x4800001,
    root 0xc5, subw 0x0, time 7138264, (103,85), root:(965,1564),
    state 0x110, button 1, same_screen YES
```

Example with `grep` to easier determine button ID:
`xev | egrep -o 'button [0-9]{1,2}'`

### Configure `.xbindkeysrc`
So in my case I want to configure only two buttons:

* Left Scrolling for minimize window
* Right Scrolling for maximize window

I had to add only these two section to .xbindkeysrc:

* Minimize (Button 11)
```
"xdotool getactivewindow windowminimize"
b:11
```
* Maximize (button 12)
```
"wmctrl -r :ACTIVE: -b toggle,maximized_vert,maximized_horz"
b:12
```
As you can see we had to use two different command: `xdotool` and `wmctrl`.

If you want to use your buttons for any other activity I'm pretty sure that after some googleing you will find your solution.

---

##**Case Insensitive Search In Oracle DB**##

```sql
alter session set NLS_COMP=ANSI;
alter session set NLS_SORT=BINARY_CI;
```

==**REFERENCE:**==  
[http://stackoverflow.com/questions/1031844/oracle-db-how-can-i-write-query-ignoring-case](http://stackoverflow.com/questions/1031844/oracle-db-how-can-i-write-query-ignoring-case)

## **Change Date & Timestamp Format In Oracle DB**

```sql
alter session set NLS_DATE_FORMAT='yyyy-mm-dd HH24:mi:ss';
ALTER SESSION SET NLS_TIMESTAMP_FORMAT='yyyy-mm-dd HH24:mi:ss';
```


##**Redirect all output (stderr, stdout) to a file**##


```bash
#!/bin/bash

LOG="[LOG file location]"
exec >> $LOG 2>&1
...
...
...
```


## **Redirect nohup output**

You can redirect stdout and stderr to differrent files or into the same file.

**Examples:**

1. `nohup ./program >stdout.log 2>stderr.log`
2. `nohup ./progrem >stoutAndStderr.log 2>&1`
3. `abbreviated syntax `

nohup command > output-$(date +%Y%m%d_%H%M%S).log &

**Example startup script for OpenHAB:**

`cat start-daemon.sh`

```bash
#!/bin/sh
...
...
...

echo Launching the openHAB runtime...
nohup java \
    -Dosgi.clean=true \
    -Declipse.ignoreApp=true \
    -Dosgi.noShutdown=true  \
    -Djetty.port=$HTTP_PORT  \
    -Djetty.port.ssl=$HTTPS_PORT \
    -Djetty.home=.  \
    -Dlogback.configurationFile=configurations/logback.xml \
    -Dfelix.fileinstall.dir=addons -Dfelix.fileinstall.filter=.*\\.jar \
    -Djava.library.path=lib \
    -Djava.security.auth.login.config=/opt/openhab/runtime/distribution-1.8.3-runtime/etc/login.conf \
    -Dorg.quartz.properties=./etc/quartz.properties \
    -Dequinox.ds.block_timeout=240000 \
    -Dequinox.scr.waitTimeOnBlock=60000 \
    -Dfelix.fileinstall.active.level=4 \
    -Djava.awt.headless=true \
    -jar $cp $* \
    -console 9898 >nohup-$(date +%Y%m%d_%H%M%S).out &
```

---





















