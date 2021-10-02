# Install Debian Jessie to Orange PI Plus 2

!!! caution
    This page hasn't recently updated. Information found here could be outdated and may lead to missconfiguration.  
    Some of the links and references may be broken or lead to non existing pages.  
    Please use this docs carefully. Most of the information here now is only for reference or example!


Maybe you heard about Orange PI, and maybe you are interested in it.
I bought this little board because it's specification, I thought it has to be faster then Raspberry PI2, and it has built-in wifi chip, etc. I love all of my RPI very much and I wanted to try OPI as well, but buying OPI wasn't my best choice of my life. 
To say the least Orange PI is a little bit neglected and lack of support compared with Raspberry which has a very great and big community. Of course there are a lot of article on Internet about OPI, but sometimes you can't find what you want and you have to do it on your own. 
The whole story began with I wanted to install Jessie to my OPI.

## 0. Zero-Step
The first thing I have to realize that Debian Jessie image cannot be downloaded from [Orange PIs web site](http://www.orangepi.org/downloadresources/). If you don't want to spend (waste) time with build Jessie image, please visit OPI home page and choose from the ready-to-use distros. Maybe after a while Jessie will be also available for download. But now we have to build it manually. ~~(Maybe it can be downloaded from another website, I didn't do detailed search for it.)~~ Yes, it can be downloaded from [here](http://www.orangepi.cn/orangepibbsen/forum.php?mod=viewthread&tid=342).

I strongly recommend [this forum](http://www.orangepi.cn/orangepibbsen/forum.php?mod=viewthread&tid=342) for everyone who wants to deal with OrangePI. 
**In this post I will follow this guide.**

!!! important
    Most part of this post is by `ctrl+c` + `ctrl+v` from various other posts, I wrote this just for collecting things and give more help to others.

First I installed a (clean) Debian (8.5) system on a [Virtualbox ](https://www.virtualbox.org/) machine.

## 1. Installing dependencies

* As in case of any other installation we start with updating the OS.

```bash
sudo apt-get update
sudo apt-get upgrade
```

* Installing the necessary packages

`apt-get install gcc make debootstrap qemu-user-static git`

* Clone the git repository
 
```bash 
cd /usr/src
git clone https://github.com/loboris/OrangePi-BuildLinux
```


## 2. Setting up param.sh and create the image

```bash
cd /usr/src/OrangePi-BuildLinux
vi vi params.sh
```

* After the setting is done,my param.sh look like this (without commend and blank lines):

```bash
root@debian:/usr/src/OrangePi-BuildLinux# cat params.sh | grep -v \# | grep -v ^$
ONLY_BASE="no"
HOSTNAME="OrangePI"
USER="orangepi"
ROOTPASS="orangepi"
USERPASS="orangepi"
_timezone="Etc/UTC"
LANGUAGE="en"
LANG="en_US.UTF-8"
image_name="jessie"
_format="ext4"
fatsize=64
linuxsize=1800
distro="jessie"
repo="http://ftp.hu.debian.org/debian"
raspbian="no"
_compress="yes"
_boot_on_ext4="no"
```

* run **create_image**

Sample output: [https://drive.google.com/file/d/0B4xTxuaiVCZyV3dUVEppTnZQeWs](https://drive.google.com/file/d/0B4xTxuaiVCZyV3dUVEppTnZQeWs)

* After the script has been successfully finished we have jessie.img file:

`-rw-r--r-- 1 root root 1975517184 Sep  5 20:10 jessie.img`

## 3. Mount and set up the new image
I want to show you multiple ways to properly set up these files.
### 3.1 With kpartx

* To mount the image file use the following commands:

```bash
losetup -f
losetup /dev/loop0 jessie.img
kpartx -av /dev/loop0
```

For some reason the **last command `kpartx` will fail**, but the first partition can be mounted.

```plain
add map loop0p1 (254:0): 0 131072 linear /dev/loop0 40960
device-mapper: resume ioctl on loop0p2 failed: Invalid argument
create/reload failed on loop0p2
add map loop0p2 (0:0): 0 3686401 linear /dev/loop0 172032

root@debian:/usr/src/OrangePi-BuildLinux# blkid | grep  "/dev/mapper/"
/dev/mapper/loop0p1: LABEL="BOOT" UUID="DC73-B07C" TYPE="vfat" PARTUUID="8e7a5a1e-01"

mount -t vfat /dev/mapper/loop0p1 /mnt/
```

* Copy uImage and script.bin **according to your OPI version.** In my case:

```
cd /mnt/
cp uImage_OPI-PLUS uImage
cp script.bin.OPI-PLUS_1080p60_hdmi uImage
```

* Umount the partition and loop device:

```
sync
umount /mnt
kpartx -dv /dev/loop0
losetup -d /dev/loop0
```

###3.2 Without kpartx

This way is only different from the first one in mounting the image.

* First determine  the start and and position of partitions inside the image file.  
  * To do this run `parted jessie.img `
  * Type `u b`. This will change the unit type to `byte`.
  * Type `print`  
  
If you get `Error: Can't have a partition outside the disk!` error, type Ignore and continue.

You will show something like this:

```
Number  Start      End          Size         Type     File system  Flags
1      20971520B  88080383B    67108864B    primary  fat32
2      88080384B  1975517695B  1887437312B  primary  ext4
```

* Create loop devices

```
losetup -f  jessie.img -o 20971520 --sizelimit 67108864
losetup -f  jessie.img -o 88080384 --sizelimit 1887437312
```
* Check loop devices

```
root@debian:/usr/src/OrangePi-BuildLinux# blkid /dev/loop*
/dev/loop0: LABEL="BOOT" UUID="DC73-B07C" TYPE="vfat"
/dev/loop1: LABEL="linux" UUID="bb12e03a-254f-426a-be34-58fd5a9abb94" TYPE="ext4"
```

* Mount them

```
mkdir /mnt/tmp_loop0
mkdir /mnt/tmp_loop1
mount /dev/loop0 /mnt/tmp_loop0
mount /dev/loop1 /mnt/tmp_loop1
```
You can check tho mounted partitions:

* `ls -al /mnt/tmp_loop0`
* `ls -al /mnt/tmp_loop1`

Now you can modify uImage and script.bin.   

* After that unmount the image:

```bash
umount /mnt/tmp_loop0 /mnt/tmp_loop1
losetup -d /dev/loop0 /dev/loop1 
```

Now you can write this image to your SD card (or flashdrive), and boot you OPI. You can use Win32DiskImager or `dd` command to do this.

####3.3 Do it on your Orange PI
The last method is the easiest. Without any modification on the image file just write it to your SD card, and boot your Orange PI. 
In this case the board have to be connected to a keyboard and a monitor, because without properly configured uImage and script.bin it has a chance that ETH port won't work. 
After the OPI boot the boot partition should be mounted on `/boot` or `/media/boot`, here you can set up the uImage and script.bin. If you are done with it reboot your OPI, and check if ETH port & WIFI adapter working or not.

Advantage of using the first and second method is that you shouldn't connect your OPI to display, after flashing the image everything should be working.

##### **==REFERENCES & LINKS==**
* [https://github.com/google/cloud-print-connector/wiki/Install](https://drive.google.com/file/d/0B4xTxuaiVCZyV3dUVEppTnZQeWs)
* [https://github.com/google/cloud-print-connector/wiki/Build-from-source](https://drive.google.com/file/d/0B4xTxuaiVCZyV3dUVEppTnZQeWs)
* [http://www.orangepi.cn/orangepibbsen/forum.php?mod=viewthread&tid=342](https://drive.google.com/file/d/0B4xTxuaiVCZyV3dUVEppTnZQeWs)
* [http://vosse.blogspot.hu/2015/10/installing-linux-img-files-on-orange-pi.html](https://drive.google.com/file/d/0B4xTxuaiVCZyV3dUVEppTnZQeWs)
* [http://www.orangepi.org/Docs/Building.html](https://drive.google.com/file/d/0B4xTxuaiVCZyV3dUVEppTnZQeWs)
* [https://linux-sunxi.org/Main_Page](https://drive.google.com/file/d/0B4xTxuaiVCZyV3dUVEppTnZQeWs)
* [https://github.com/allwinner-zh/linux-3.4-sunxi](https://drive.google.com/file/d/0B4xTxuaiVCZyV3dUVEppTnZQeWs)
* [https://github.com/loboris/OrangePI-Kernel](https://drive.google.com/file/d/0B4xTxuaiVCZyV3dUVEppTnZQeWs)



