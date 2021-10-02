# Mount SD card image (partitioned image) w/o kpartx

!!! caution
    This page hasn't recently updated. Information found here could be outdated and may lead to missconfiguration.  
    Some of the links and references may be broken or lead to non existing pages.  
    Please use this docs carefully. Most of the information here now is only for reference or example!

If you are working with SD card image I pretty sure that you were in the situation when you had to mount the image before write it to the SD card. 
Particular example when you want to modify `cmdline.txt` in a Raspberry PI image (because you want to use different partition for booting).

## With kpartx utility
If your system doesn't have `kpartx` utility install it for example with `apt-get install kpartx` command in case of Debian-Like systems.

For demonstration I use `2016-05-27-raspbian-jessie-lite.img` image. 

1. set up loop devices
`losetup -f 2016-05-27-raspbian-jessie-lite.img`

1. (optional) Check the loop device
```bash
losetup
NAME       SIZELIMIT OFFSET AUTOCLEAR RO BACK-FILE
/dev/loop0         0      0         0  0 /home/vinyo/Downloads/2016-05-27-raspbian-jessie-lite.img
```

1. Create device maps from partition tables
```bash
kpartx -av /dev/loop0
add map loop0p1 (254:0): 0 129024 linear /dev/loop0 8192
add map loop0p2 (254:1): 0 2572288 linear /dev/loop0 137216
```

1. (optional) Check mapped partitions with `blkid`
```
Simpliy type `blkid` and hit enter. Output:  
...
/dev/mapper/loop0p1: SEC_TYPE="msdos" LABEL="boot" UUID="22E0-C711" TYPE="vfat" PARTUUID="6fcf21f3-01"
/dev/mapper/loop0p2: UUID="202638e1-4ce4-45df-9a00-ad725c2537bb" TYPE="ext4" PARTUUID="6fcf21f3-02"
...
```

1. Mount these partitions
```
mkdir /mnt/tmp1  
mkdir /mnt/tmp2
mount -t vfat /dev/mapper/loop0p1 /mnt/tmp1  
mount -t ext4 /dev/mapper/loop0p2 /mnt/tmp2
```
After you are done with the neccessary modifications you can dismount everything.

1. DisMount
```bash
umount /mnt/tmp1
umount /mnt/tmp2
kpartx -dv /dev/loop0
losetup -d /dev/loop0
```
You can check it everything is unmounted by running `losetup` command, it should return with "nothing".

## Without kpartx utility

It is possible to mount partitions inside an image without kpart utility as well, but I think this way a little bit more complicated.

Follow these steps:

### Determine the size partitions (where is it started and ended)  

  1.1. Run `parted 2016-05-27-raspbian-jessie-lite.img`  
  1.2. Type `u b` and enter. --> This will change the display unit to bytes.  
  1.3. Type `print` to display partition layout. Sample output:  

```bash
parted 2016-05-27-raspbian-jessie-lite.img 
GNU Parted 3.2
Using /home/vinyo/Downloads/2016-05-27-raspbian-jessie-lite.img
Welcome to GNU Parted! Type 'help' to view a list of commands.
(parted) u b                                                              
(parted) print                                                            
Model:  (file)
Disk /home/vinyo/Downloads/2016-05-27-raspbian-jessie-lite.img: 1387266048B
Sector size (logical/physical): 512B/512B
Partition Table: msdos
Disk Flags: 

Number  Start      End          Size         Type     File system  Flags
 1      4194304B   70254591B    66060288B    primary  fat16        lba
 2      70254592B  1387266047B  1317011456B  primary  ext4

(parted) q                                                                
```

### Set up loopbak devices

As you can see there are two partition inside the image file. We need to create two loopback device for them:

```bash
losetup -f -o 4194304 --sizelimit 66060288 2016-05-27-raspbian-jessie-lite.img 
losetup -f -o 70254592 --sizelimit 1317011456 2016-05-27-raspbian-jessie-lite.img 
```

!!! warning
    Please double check the offset and sizelimit parameters!

Check with `losetup` and `blkid` commands:
**losetup:**
```
NAME        SIZELIMIT   OFFSET AUTOCLEAR RO BACK-FILE
/dev/loop0   66060288  4194304         0  0 /home/vinyo/Downloads/2016-05-27-raspbian-jessie-lite.img
/dev/loop1 1317011456 70254592         0  0 /home/vinyo/Downloads/2016-05-27-raspbian-jessie-lite.img
```
**blkid:**
```
/dev/loop0: SEC_TYPE="msdos" LABEL="boot" UUID="22E0-C711" TYPE="vfat"
/dev/loop1: UUID="202638e1-4ce4-45df-9a00-ad725c2537bb" TYPE="ext4"
```

### Mount the partitions
```
mount /dev/loop0 /mnt/tmp1
mount /dev/loop1 /mnt/tmp2
```

**Check:**
```
df -hT /dev/loop*
Filesystem     Type      Size  Used Avail Use% Mounted on
/dev/loop0     vfat       63M   21M   43M  33% /mnt/tmp1
/dev/loop1     ext4      1.2G  738M  389M  66% /mnt/tmp2
udev           devtmpfs   10M     0   10M   0% /dev
udev           devtmpfs   10M     0   10M   0% /dev
udev           devtmpfs   10M     0   10M   0% /dev
udev           devtmpfs   10M     0   10M   0% /dev
udev           devtmpfs   10M     0   10M   0% /dev
udev           devtmpfs   10M     0   10M   0% /dev
udev           devtmpfs   10M     0   10M   0% /dev
```

After you are done with you work unmount everything.


### Unmount the partitions
```bash
root@debian:~# umount /mnt/tmp1 /mnt/tmp2/
root@debian:~# losetup 
NAME        SIZELIMIT   OFFSET AUTOCLEAR RO BACK-FILE
/dev/loop0   66060288  4194304         0  0 /home/vinyo/Downloads/2016-05-27-raspbian-jessie-lite.img
/dev/loop1 1317011456 70254592         0  0 /home/vinyo/Downloads/2016-05-27-raspbian-jessie-lite.img
root@debian:~# losetup -d /dev/loop0 /dev/loop1
root@debian:~# losetup 
root@debian:~# 
```












 





