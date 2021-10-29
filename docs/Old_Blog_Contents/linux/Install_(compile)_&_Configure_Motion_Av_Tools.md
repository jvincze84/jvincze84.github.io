!!! caution
    **This page has been updated a long time ago.**  Information found here could be outdated and may lead to missconfiguration.  
    Some of the links and references may be broken or lead to non existing pages.  
    Please use this docs carefully. Most of the information here now is only for reference or example!
    
# Install (compile) & Configure motion + AV tools

## 0. Update running system & Install necessary pacgakes

* As always, start with updating you linux system.

```bash
apt-get update
apt-get upgrade
```

* Install packages

```bash
apt-get install libjpeg-dev libjpeg62-turbo-dev autoconf automake build-essential libzip-dev git yasm nasm pkg-config libavutil-dev libavformat-dev libavcodec-dev libswscale-dev autoconf automake build-essential pkgconf libtool libzip-dev libjpeg62 git libavformat-dev libavcodec-dev libavutil-dev libswscale-dev libavdevice-dev ca-certificates webp libwebp-dev curl lynx zip apache2 libx264-dev x264 libav-tools mpv
```

## 1. Install libav12

!!! note
    This step is **optional**, because at the 0. step we installed libav-tools package which contains avconv.  
    But with compiling from source we get a newer version:

* Repository: avconv version 11.8-6:11.8-1~deb8u1+rpi1
* Compiled: avconv version 12, Copyright (c) 2000-2016 the Libav developers


### 1.1. Download source code from the git repository

```bash
cd /usr/src
git clone https://github.com/todostreaming/libav12
```

### 1.2. Configure & make and make install

#### 1.2.1. Configure

```bash
cd /usr/src/libav12
./configure --enable-libwebp --enable-libx264 --logfile=/root/libav-conf-$(date +%s).log --enable-gpl --prefix=/opt/libav12 | tee -a /root/libav-conf-$(date +%s).out
```

After the configure is done you can check two log files:

* `/root/libav-conf-*.log`
* `/root/libav-conf-*.out`

The configure script must be done without any error. If you see errors in one of the log files please do not continue, and try to fix them. Usually the most error cause by a missing library and easy can be fixed with install the missing lib using `apt-get install` command.

#### 1.2.2. **Compile** the source code:

To speed up this process lets use `-j2` option. (Or if you want -j3 or -j4)

```bash
make -j2
```

During this process maybe you will some warning messages, but no errors. So you can skip them.

> **`-j [jobs], --jobs[=jobs]`**  
Specifies  the  number  of  jobs (commands) to run simultaneously.  If there is more than one -j option, the last one is effective.  If the -j option is given without an argument, make will not limit the number of jobs that can run simultaneously.

#### 1.2.3. **Install** libav

To do this simply run this command:

```bash
make install
```

The binaries will be available in the directory specified with "--prefix" option when we run configure script. In our case: `/opt/libav12`

==References:==  

* [https://wiki.libav.org](https://wiki.libav.org/)
* [https://libav.org](https://libav.org/)
* [https://github.com/todostreaming/libav12](https://github.com/todostreaming/libav12)

## 2. Install / Compile FFMpeg

FFMpeg is no longer available in Debian repository, so if you want to use it you have to compile on your own. 

```bash
cd /usr/src
git clone https://github.com/FFmpeg/FFmpeg
root@rpi2camsrv01:/usr/src/FFmpeg# ./configure --prefix=/opt/ffmpeg --enable-libx264 --enable-libwebp --enable-gpl --enable-nonfree
make
make install
```

Note: The make command runs very long time. Please be patient, and / or try run with -j[234] option.


## 3. Install / Compile Motion

Motion can be easily installed with `apt-get install motion`, so you my think this post is absolutely useless and has no sense. But if you want to use RTSP stream, you have to have the latest (or at lease 4.x) version of motion. The version of apt-get repository is too old and has not this feature:

```bash
root@rpi2camsrv01:/opt/motion-3.4.1-316/bin# apt-cache show motion
Package: motion
Source: motion (3.2.12+git20140228-4)
Version: 3.2.12+git20140228-4+b2
```

By using the git source code we can install the latest version:
`motion Version 4.0.1+git8a1b9a97`

If you want to use motion with **mysql** support in the future you need some additional packages:
`apt-get install libmysql++-dev libmysqlclient-dev`

### 3.1. Clone from git

```bash
/usr/src
git clone https://github.com/Motion-Project/motion.git
```

##### 3.2. Configure
Before you start you may want to read the INSTALL guide:
`less /usr/src/motion/INSTALL `

You can choose which library do you want to use ffmpeg / libav:

```bash
cd /usr/src/motion
autoreconf -fiv
./configure --prefix=/opt/motion-3.4.1-316 --with-ffmpeg=/opt/ffmpeg
#OR
./configure --prefix=/opt/motion-3.4.1-316 --with-ffmpeg=/opt/libav12
```

You can configure without "with-ffmpeg" option, it this case configure script will use the already installed libraries (libav-tool)

After the configure script done you will see something like this:

```
   **************************
      Configure status       
      motion 4.0.1+git8a1b9a9
   **************************

OS             :     Linux
pthread support:     Yes
jpeg support:        Yes
webp support:        No
V4L2 support:        Yes
BKTR support:        No
MMAL support:        Yes
 ... MMAL_CFLAGS: -std=gnu99 -DHAVE_MMAL -Irasppicam -I/opt/vc/include
 ... MMAL_OBJ: mmalcam.o raspicam/RaspiCamControl.o raspicam/RaspiCLI.o
 ... MMAL_LIBS: -L/opt/vc/lib -lmmal_core -lmmal_util -lmmal_vc_client -lvcos -lvchostif -lvchiq_arm
FFmpeg support:      Yes
 ... FFMPEG_CFLAGS: -I/opt/libav12/include  
 ... FFMPEG_LIBS: -lswscale -lavdevice -lavformat -lavcodec -lx264 -lwebp -lz -pthread -lavresample -L/opt/libav12/lib -lavutil -lm  
SQLite3 support:     No
MYSQL support:       Yes
PostgreSQL support:  No

CFLAGS: -g -O2 -I/usr/local/include -g -O2 -D_THREAD_SAFE 
LIBS: -lm -L/usr/local/lib -pthread -ljpeg -lmysqlclient -lz
LDFLAGS:  -L/usr/local/lib 

Install prefix:       /opt/motion-3.4.1-316
```

If you need **webp** support configure with `--with-webp` option. The necessary packages are already installed in the 0. step (webp libwebp-dev).
`/configure --prefix=/opt/motion-3.4.1-316 --with-ffmpeg=/opt/libav12 --with-webp`

### 3.2. Make & Make install

Now we have only to easy steps left, run make and make install.

```bash
make
make install
```

Your motion instance is now ready to use, and can be located in `/opt/motion-3.4.1-316`.

## ==**Update - 2017.05.09**==

If you want to use fmpeg to encode/decode .webm files you need to install these extra packages:

```bash
apt-get install libvorbis-dev libvpx-dev mjpegtools
(optional) apt-get instell vpx-tools imagemagick
```

And configure **ffmpeg** with these **parameters**:
```
./configure --prefix=/opt/ffmpeg-webm --enable-libx264 --enable-libwebp --enable-gpl --enable-nonfree --enable-libvpx --enable-libvorbis
```

## 4. Configure Motion to start at boot

###4.1. Create user for motion service

```bash
useradd motion
root@rpi2camsrv01:/lib/systemd/system# id motion
uid=1002(motion) gid=1002(motion) groups=1002(motion)
```

### 4.2. Edit motion.service systemd config file

An example service file can be found in the motion install directory:
`/opt/motion-3.4.1-316/share/motion/examples/motion.service`

* Copy this file to systemd directory:

```
cd /lib/systemd/system
cp /opt/motion-3.4.1-316/share/motion/examples/motion.service .
```

* Create dir for PID file

```bash
mkdir /opt/motion-3.4.1-316/var
```

* Edit motion.sevice file

```
[Unit]
Description=Motion daemon
After=local-fs.target network.target

[Service]
User=motion
Group=motion
PIDFile=/opt/motion-3.4.1-316/var/motion.pid
ExecStart=/opt/motion-3.4.1-316/bin/motion -n
Type=simple
StandardError=null

[Install]
WantedBy=multi-user.target
```

* Change Owner of motion

```
chown -R motion:motion /opt/motion-3.4.1-316/
```

* Try to start motion.service

```
root@rpi2camsrv01:/lib/systemd/system# systemctl start motion.service 
```

* Check the service

```
root@rpi2camsrv01:/lib/systemd/system# systemctl status motion.service 
â— motion.service - Motion daemon
   Loaded: loaded (/lib/systemd/system/motion.service; disabled)
   Active: active (running) since Fri 2017-03-24 09:36:46 UTC; 5s ago
 Main PID: 12812 (motion)
   CGroup: /system.slice/motion.service
           â””â”€12812 /opt/motion-3.4.1-316/bin/motion -n
```

* Stop service and install service file

```
root@rpi2camsrv01:/lib/systemd/system# systemctl stop  motion.service 
root@rpi2camsrv01:/lib/systemd/system# systemctl enable  motion.service 
Created symlink from /etc/systemd/system/multi-user.target.wants/motion.service to /lib/systemd/system/motion.service.
```

Now you should use 'motion' user to configure motion, otherwise the owner of files may be changed causing permission denied. 

```
root@rpi2camsrv01:/lib/systemd/system# sudo su - motion
No directory, logging in with HOME=/
motion@rpi2camsrv01:/opt/motion-3.4.1-316$ 
```

You can create home directory to motion user:
```
mkdir /home/motion
chown -R motion:motion /home/motion/
```

You motion installation is ready for use now. 


## 5. Configure Motion to use an ONVIF IP camera via RTSP stream

You can buy low budget IP cameras from eBay, Aliexpress and so on.
Nowadays almost all cheap cameras are using ONVIF interface. I have 3 IP cameras and I have to say that the web interfaces of them are really poor. My main problem is that two of them have web interface which can be accessed only with IE, because of ActiveX. :( I hate it because I usually use Linux. Another option to configure you camera is to use some ONVIF manager software. Usually the provider of the camera send a software, as well, but its also need Windows. :( I tried to find some ONVIF manager for Linux, but could not find a really good one. I don't care too much because normally a camera have to be set up once, and then can be used. 
To use these cameras with MOTION you have to determine the stream URL. If you are lucky you can find it somewhere in the web interface. 
The following steps are valid only if you have already configured you camera. This means  that the cam is connected to your network at least, and you know it IP address.
This post doesn't aim to describe 'how to configure your cam', so you have to do it on your own. 
It is more exciting to find you ONVIF camera's stream URLs. 
If you don't like my method you can do some googleing to find the URLs of your camera.

### 5.1. What you need?

* Installed [SOAPUI](https://www.soapui.org/).
* Your camera WebService URL. Unfortunately this can be different from mine.  
Here is two examples:
  * http://172.19.0.3:8080
  * http://172.19.0.2/onvif/device_service

At this step the main problem is that I don't know exact method to find your camera web service URL. If the two example above aren't working you have to do some searching on Google. 

According to the [Official Documentation](https://www.onvif.org/specs/core/ONVIF-Core-Specification-v250.pdf) the URL should be this:

>The entry point for the device management service is fixed to:
>`http://onvif_host/onvif/device_service`

---

### 5.2. Load ONVIF device WSDL to soapUI

URL: https://www.onvif.org/ver10/device/wsdl/devicemgmt.wsdl

![](/assets/images/2017/03/2017-03-24_110640.jpg)

### 5.3. Modify Endpoint

![](/assets/images/2017/03/2017-03-24_110755.jpg)

![](/assets/images/2017/03/2017-03-24_110925.jpg)

You can specify username password if your camera is using authentication

![](/assets/images/2017/03/2017-03-24_111005.jpg)

Assign the newly added endpoint to the requests, without this you can specify the endpoint for all requests. 

![](/assets/images/2017/03/2017-03-24_111114.jpg)

Now you can close this window.

### 5.4. GetServices

Find 'GetServices' in the left panel.

![](/assets/images/2017/03/2017-03-24_111457.jpg)

Modify the request to:

```xml
<wsdl:IncludeCapability>true</wsdl:IncludeCapability>
```

You will get all web services which supported by your camera. I paste only the relavant information from the request here.
```xml
<tds:Namespace>http://www.onvif.org/ver10/device/wsdl</tds:Namespace>
<tds:XAddr>http://172.19.0.3:8080/onvif/devices</tds:XAddr>
<tds:Namespace>http://www.onvif.org/ver10/media/wsdl</tds:Namespace>
<tds:XAddr>http://172.19.0.3:8080/onvif/media</tds:XAddr>
<tds:Namespace>http://www.onvif.org/ver10/events/wsdl</tds:Namespace>
<tds:XAddr>http://172.19.0.3:8080/onvif/events</tds:XAddr>
<tds:Namespace>http://www.onvif.org/ver20/analytics/wsdl</tds:Namespace>
<tds:XAddr>http://172.19.0.3:8080/onvif/analytics</tds:XAddr>
```

We need the media one: `http://www.onvif.org/ver10/media/wsdl`
Copy paste this URL to your browser to get the WSDL location.
You will be redirected to this URL:
`https://www.onvif.org/ver10/media/wsdl/media.wsdl7`

Add this WSDL to your soapUI project. For reference please see chapter 5.2.



### 5.5. MediaBinding / GetProfiles

![](/assets/images/2017/03/2017-03-24_112851.jpg)

With this you get the profiles of you camera. I don't copy paste the whole response here just some important parts.

* I have two profiles:

```xml
<trt:Profiles fixed="true" token="MainProfileToken">
<trt:Profiles fixed="true" token="SubProfileToken">
```

* You can find everything about the profiles for example resolution:

```xml
<tt:VideoEncoderConfiguration token="main_video_encoder_cfg_token">
   <tt:Name>main_video_encoder_cfg</tt:Name>
   <tt:UseCount>1</tt:UseCount>
   <tt:Encoding>H264</tt:Encoding>
   <tt:Resolution>
      <tt:Width>1920</tt:Width>
      <tt:Height>1080</tt:Height>
   </tt:Resolution>
```

![](/assets/images/2017/03/2017-03-24_113919.jpg)

I want to use this profile in Motion (MainProfileToken).

These profiles can be found on the web interface, but maybe the name is different.

--- 

### 5.6. Get URLS (MediaBinding / GetStreamUri)

![](/assets/images/2017/03/2017-03-24_114115.jpg)

**Now you have to edit this XML before start the request.**

Open this URL in you browser:
https://www.onvif.org/ver10/media/wsdl/media.wsdl
And find 'GetStreamUri' operation.

You will see how to configure this request.

![](/assets/images/2017/03/2017-03-24_114236.jpg)

Example:

```xml
<soap:Envelope xmlns:soap="http://www.w3.org/2003/05/soap-envelope" xmlns:wsdl="http://www.onvif.org/ver10/media/wsdl" xmlns:sch="http://www.onvif.org/ver10/schema">
   <soap:Header/>
   <soap:Body>
      <wsdl:GetStreamUri>
         <wsdl:StreamSetup>
            <sch:Stream>RTP-Unicast</sch:Stream>
            <sch:Transport>
               <sch:Protocol>RTSP</sch:Protocol>
               <!--Optional:-->
               <sch:Tunnel/>
            </sch:Transport>
            <!--You may enter ANY elements at this point-->
         </wsdl:StreamSetup>
         <wsdl:ProfileToken>MainProfileToken</wsdl:ProfileToken>
      </wsdl:GetStreamUri>
   </soap:Body>
</soap:Envelope>
```

The most important things to note the ProfileToken:

```xml
<wsdl:ProfileToken>MainProfileToken</wsdl:ProfileToken>
```

![](/assets/images/2017/03/2017-03-24_114517.jpg)

Finally we have the stream URL:
```xml
<tt:Uri>rtsp://172.19.0.3:554/11</tt:Uri>
```

You can try this url in VLC media player. 

Just for demonstration my `<wsdl:ProfileToken>SubProfileToken</wsdl:ProfileToken>` address is:

```xml
<tt:Uri>rtsp://172.19.0.3:554/12</tt:Uri>
```


### 5.7. (Bonus) MediaBinding / GetSnapshotUri

You can get snapshot images from ONVIF cameras. To get the URL use GetSnapshotUri request:

![](/assets/images/2017/03/2017-03-24_115039.jpg)

```xml
<tt:Uri>http://172.19.0.3:80/web/auto.jpg?-usr=admin&amp;-pwd=admin&amp;</tt:Uri>
```


### 5.8. (Bonus) DeviceBinding / GetDeviceInformation

Just for fun my last sample request is the 'GetDeviceInformation'.
**Request:**
```xml
<soap:Envelope xmlns:soap="http://www.w3.org/2003/05/soap-envelope" xmlns:wsdl="http://www.onvif.org/ver10/device/wsdl">
   <soap:Header/>
   <soap:Body>
      <wsdl:GetDeviceInformation/>
   </soap:Body>
</soap:Envelope>
```

**Response:**

```xml
...
   <SOAP-ENV:Header/>
   <SOAP-ENV:Body>
      <tds:GetDeviceInformationResponse>
         <tds:Manufacturer>IPCAM</tds:Manufacturer>
         <tds:Model>C6F0SiZ3N0P0L0</tds:Model>
         <tds:FirmwareVersion>V6.1.10.2.1-20150624</tds:FirmwareVersion>
         <tds:SerialNumber>00E0F8218509</tds:SerialNumber>
         <tds:HardwareId>V6.1.10.2.1-20150624</tds:HardwareId>
      </tds:GetDeviceInformationResponse>
   </SOAP-ENV:Body>
</SOAP-ENV:Envelope>
```

![](/assets/images/2017/03/2017-03-24_115645.jpg)


**Note:**  

Not all requests are support by all cameras, but the main features are implemented (, I hope). Maybe your camera has different Profile names, but the xml tags must be the same.



### 5.9. Motion Configuration changes

* Change directory to motion conf  
`cd /opt/motion-3.4.1-316/etc/motion`

* Rename motion-dist.conf to motion.conf  
`mv motion-dist.conf motion.conf`

* Turn on daemon mode  
`daemon on`

* Configure Logs
  * Run: `mkdir  -p /opt/motion-3.4.1-316/var/log/motion`
  * Chage **conf** to:  
`logfile /opt/motion-3.4.1-316/var/log/motion/motion.log`

* Increase log level  
`log_level 7`

* Comment out videodevice line, since we will use netcam.  
`#videodevice /dev/video0`

* Change resolution  
```
# Image width (pixels). Valid range: Camera dependent, default: 352
width 1920

# Image height (pixels). Valid range: Camera dependent, default: 288
height 1080
```

* Change frame rate  
`framerate 7`

* Specify netcam_url  
`netcam_url rtsp://172.19.0.4:554/11`

* Switch keepalive on  
`netcam_keepalive on`

* **Motion Detection Settings**
  * Change treshold: `threshold 2500`
  * Increase minimum motion frame: `minimum_motion_frames 3`
  * Modify event_gap: `event_gap 10`
  * Set max movie time to 10 mins: `max_movie_time 600`  
  This is optional. I don't save any movies, but only images. It's your choice.
  * Turn video save off: `ffmpeg_output_movies off`
>
* **File save settings:**
  * Specify target dir to save images (and / or videos)  
  `mkdir -p /opt/motion-3.4.1-316/var/spool/motion`  
  `target_dir /opt/motion-3.4.1-316/var/spool/motion` 
  * Set up the pictures name conversation:  
  ~~`picture_filename imgs/%Y-%m-%d/%H-%M-%S__%q-%D`~~  
  `picture_filename imgs/%Y-%m-%d/%H/%H-%M-%S__%q-%D`  
  This will save images to [target_dir]/imgs/YEAR-MONTH-DAY/HOUR-MIN-SEC__FRAMENUMBER_MOTION.jpg format. 

* (optional) **Enable access to web control and Live View from anywhere**

```
stream_localhost off
webcontrol_localhost off
```

I do not save movies, because 

* movies are taken real time, and uses CPU
* moves are captured real-time, I mean 10 minutes movies takes 10 minutes to watch about 10 minutes long motion detection, so instead of this I create timelapse movies based on saved images. This way I can check the movies faster than the event happened and if I find something, I can look for the saved images to investigate it deeper. 

Motion has a log of configuration it worth it to look through the motion.conf file I'm sure you will find exciting and useful options. 
My setup is just enough to detect motion and save images. 
I post process the images using shell scripts and ffmpeg (or libav) tools.

## 6. Create movie from still images (*.jpg)

Now we have a lot of images from the camera. My motion save one images in every 30 seconds:
```
# Make automated snapshot every N seconds (default: 0 = disabled)
snapshot_interval 30
```
And save images when motion is detected:
```
# Threshold for number of changed pixels in an image that
# triggers motion detection (default: 1500)
threshold 2500
```

My motion saves images in the following directory structure:
`/storage/motion/output/cam1/imgs/[DATE]/[HOUR]/*.jpg`

**Setup:**

```bash
picture_filename imgs/%Y-%m-%d/%H/%H-%M-%S__%q-%D
target_dir /storage/motion/output/cam1
...
target_dir /storage/motion/output/cam2
```

Each camera uses its own directory. 

I'm using this shell script to create movie from the images:

```bash
#!/bin/bash

ROOT_DIR="/storage/motion/output"

function LOG() {
  echo "[ $( date +%F\ %T ) ] - $1 "
}


###
## VARIABLES
###
TMP_DIR="/storage/motion/tmp"
CAM_IMG_DIRS=$( mktemp $TMP_DIR/dovid_XXXXXXXXXXX.txt )
NOW_DATE=$( date  +%Y-%m-%d-%H )

LOG "###"
LOG "## Starting SCRITP"
LOG "###"
LOG "Prepare temorary file: $CAM_IMG_DIRS"
LOG "Running first FOR loop: Searching for camera dirs (cam[X]). "
for DIR in $( find $ROOT_DIR -mindepth 1 -maxdepth 1 -type d | egrep 'cam[0-9]{1,1}' | sort -n )
do
  CAM_NUM=$( echo $DIR | egrep -o 'cam[0-9]{1,1}' ) # Extract camera number, example: cam1, cam2 ...
  LOG "Runninng second FOR loop: Searching for dates in camera[X] dir"
  for DATE_IN_DIR in $( find $DIR/imgs -mindepth 1 -maxdepth 1 -type d | egrep '[0-9]{4,4}-[0-9]{2,2}-[0-9]{2,2}' | sort -n )
  do
    LOG "Running third FOR loop: Searching HOURS in camX/DATE/* ($DATE_IN_DIR) "
    for HOUR_IN_DATE_IN_DIR in $( find $DATE_IN_DIR -mindepth 1 -maxdepth 1 -type d | egrep '[0-9]{2,2}' | sort -n )
    do
      DATE_FROM_DIR=$( basename $DATE_IN_DIR ) # Extract Date From Directory Name
      HOUR_FROM_DIR=$( basename $HOUR_IN_DATE_IN_DIR ) # Extract HOUR number
      VID_DIR="$ROOT_DIR/$CAM_NUM/vids/$DATE_FROM_DIR" # Preapre VIDEO DIR
      VID_FILE="$VID_DIR/$DATE_FROM_DIR-$HOUR_FROM_DIR.avi" # SET Video FILE
      [ ! -d $VID_DIR  ] && mkdir -p $VID_DIR
      if [ ! -f $VID_FILE ]
      then
        LOG "Adding this line to $CAM_IMG_DIRS"
        echo "$HOUR_IN_DATE_IN_DIR|$VID_FILE" | tee -a $CAM_IMG_DIRS
      fi
    done
  done
done
LOG "Preparing temporary file is done."

LOG "################ PROCESSING temporary file ################"
while IFS='|' read -r IMG_DIR VID_FILE
do
  LOG "+++++ Processing: +++++"
  LOG "-- Image Dir: $IMG_DIR"
  LOG "-- Video File: $VID_FILE"
  VID_FILE_BN=$( basename $VID_FILE ) # Video File Base Name
  VID_FILE_BN_WO_EXT="${VID_FILE_BN%.*}" # Video File WO Base Name
  LOG "-- Checking the the hour..."
  if [ "$VID_FILE_BN_WO_EXT" != "$NOW_DATE" ]
  then
    LOG "!!!!!!!!!!!!!!!!!! Encoding: $VID_FILE !!!!!!!!!!!!!!!!!!"
    START_ENC_DATE=$( date +%s )
    for FILE in $( find $IMG_DIR -type f -name '*.jpg' | sort )
    do
      cat $FILE
    done | /opt/ffmpeg/bin/ffmpeg -loglevel warning -r 25 -f image2pipe -i - -c:v mpeg4 -vtag xvid -qscale:v 14 $VID_FILE
    RETVAL=$?
    STOP_ENC_DATE=$( date +%s )
    LOG "Encoding DONE in $(( $STOP_ENC_DATE - $START_ENC_DATE  )) seconds, and finsihed with $RETVAL error code."
  else
    LOG "$NOW_DATE is the current date (hour), so we can not process this folder.  Skipping... ($VID_FILE) "
  fi
done <$CAM_IMG_DIRS
echo
echo
```

This script creates separate movie files per hours. Example:

```
motion@camsrv01:/opt/motion-3.4.1-316/etc/motion$ ls -al /storage/motion/output/cam1/vids/2017-05-13
total 680340
drwxr-xr-x 2 motion motion     4096 May 14 00:10 .
drwxr-xr-x 9 motion motion     4096 May 14 00:10 ..
-rw-r--r-- 1 motion motion 11216416 May 13 01:10 2017-05-13-00.avi
-rw-r--r-- 1 motion motion  4704858 May 13 02:10 2017-05-13-01.avi
-rw-r--r-- 1 motion motion  4349738 May 13 03:10 2017-05-13-02.avi
-rw-r--r-- 1 motion motion  6069618 May 13 04:10 2017-05-13-03.avi
-rw-r--r-- 1 motion motion 10084490 May 13 05:10 2017-05-13-04.avi
-rw-r--r-- 1 motion motion 16269868 May 13 06:10 2017-05-13-05.avi
-rw-r--r-- 1 motion motion 29998296 May 13 07:11 2017-05-13-06.avi
-rw-r--r-- 1 motion motion 42320628 May 13 08:11 2017-05-13-07.avi
-rw-r--r-- 1 motion motion 57703934 May 13 09:12 2017-05-13-08.avi
-rw-r--r-- 1 motion motion 46332720 May 13 10:11 2017-05-13-09.avi
-rw-r--r-- 1 motion motion 48425176 May 13 11:11 2017-05-13-10.avi
-rw-r--r-- 1 motion motion 47206092 May 13 12:11 2017-05-13-11.avi
-rw-r--r-- 1 motion motion 43665386 May 13 13:11 2017-05-13-12.avi
-rw-r--r-- 1 motion motion 36392852 May 13 14:11 2017-05-13-13.avi
-rw-r--r-- 1 motion motion 64864312 May 13 15:11 2017-05-13-14.avi
-rw-r--r-- 1 motion motion 44121274 May 13 16:11 2017-05-13-15.avi
-rw-r--r-- 1 motion motion 43531740 May 13 17:11 2017-05-13-16.avi
-rw-r--r-- 1 motion motion 30732256 May 13 18:11 2017-05-13-17.avi
-rw-r--r-- 1 motion motion 25023926 May 13 19:10 2017-05-13-18.avi
-rw-r--r-- 1 motion motion 22104216 May 13 20:10 2017-05-13-19.avi
-rw-r--r-- 1 motion motion 25939654 May 13 21:11 2017-05-13-20.avi
-rw-r--r-- 1 motion motion 15746894 May 13 22:11 2017-05-13-21.avi
-rw-r--r-- 1 motion motion 11119838 May 13 23:10 2017-05-13-22.avi
-rw-r--r-- 1 motion motion  8694202 May 14 00:10 2017-05-13-23.avi
```

**Crontab:**
```
10      *       *       *       *       /storage/motion/scripts/do_vids_v2.sh >>/storage/motion/logs/cam1_vid_create.log 2>&1
```






















