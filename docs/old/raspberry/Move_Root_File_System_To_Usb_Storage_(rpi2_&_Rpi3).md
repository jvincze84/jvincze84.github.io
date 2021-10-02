# Move root file system to USB storage (RPI2 & RPI3)

!!! caution
    **This page has been updated a long time ago.**  Information found here could be outdated and may lead to missconfiguration.  
    Some of the links and references may be broken or lead to non existing pages.  
    Please use this docs carefully. Most of the information here now is only for reference or example!


==**UPDATE: 2018-11-06**==

Maybe this post has lost its purpose because nowadays all modern distros support moving root file system to external device, for examples:

* Raspberry PIs: With help of noobs you can install the whole OS to external device.
* Orange & Banana PIs: Armbian has the feature of moving file system to USB (`armbian-config`).

I don't think this article can be used as a complete guide, the only reason I let this post (a)live is the commands and links in it.

---

There are a lot of very good and useful guide on the Internet which can help you to move your root file system to an external USB storage.
Using external storage is highly recommended if you want to use your RPI as a server machine which runs 7/24.
I had a lot of problems with SD cards, I think they are absolutely unsuitable for use in a raspberry and store the root file system on them. I pretty sure all SD card will die in some months, and you will lost all of your data. This happens to me and I decided not to use SD cards anymore.

######You can find some guides here:
* [http://www.kupply.com/move-your-raspberry-pi-system-to-usb-in-10-steps](http://www.kupply.com/move-your-raspberry-pi-system-to-usb-in-10-steps)
* [https://www.raspberrypi.org/blog/pi-3-booting-part-i-usb-mass-storage-boot](https://www.raspberrypi.org/blog/pi-3-booting-part-i-usb-mass-storage-boot) (PI3 only)
* [https://liewdaryl.wordpress.com/2015/06/06/setting-up-raspberry-pi-2-including-moving-rootfs-to-usb-drive](https://liewdaryl.wordpress.com/2015/06/06/setting-up-raspberry-pi-2-including-moving-rootfs-to-usb-drive)
* [http://elinux.org/Transfer_system_disk_from_SD_card_to_hard_disk](http://elinux.org/Transfer_system_disk_from_SD_card_to_hard_disk)

So why am I writing this post? Just because I spent a lot of time to do this on my own, and I want to write down my experiences. 
These tips can be useful when you deal with SD card, SD card images and hard drives.

####1. Create Image From SD card with `dd`

You can create copy of your entire SD card. For example for backup.

`dd if=/dev/sdc of=RPI_sdcard.img bs=4096`

If something fails during working with the image try decrease "bs" to 1024.

####2. Extract Partitions From The Image File
#####2.1. Determine the size of partitions
I will use the official raspberry image.
Run this command: `parted 2016-09-23-raspbian-jessie.img`
Inside the parted type: 
```
(parted) u b
(parted) print
Number  Start      End          Size         Type     File system  Flags
 1      4194304B   70254591B    66060288B    primary  fat16        lba
 2      70254592B  4348444671B  4278190080B  primary  ext4
```
First one is the boot partition, the second one is the root partition.
#####2.1. Extract the first partition from the image
**Command:** `dd if=2016-09-23-raspbian-jessie.img iflag=skip_bytes,count_bytes,fullblock bs=4096 count=70254591 of=boot_fs.img`

This will create the `boot_fs.img`, inside it the second partition is absolutely unnecessary, so we can delete it. 

To do this use the fdisk utility. 
`Command: fdisk boot_fs.img`
Inside the fdisk type these commands:
```
Command (m for help): d
Partition number (1,2, default 2): 2

Partition 2 has been deleted.

Command (m for help): w
The partition table has been altered.
Syncing disks.
```

The created image is about 70MB, and it is more than enough to boot your PI, but be aware that you have to modify the `cmdline.txt` to use an external hard disk for the root partition. 

#####2.1. Extract the second partition from the image
**Command:**
`dd if=2016-09-23-raspbian-jessie.img iflag=skip_bytes,count_bytes,fullblock bs=4096 skip=70254592 count=4278190080 of=root_fs.img`

The meaning of the options:

* `if=2016-09-23-raspbian-jessie.img` --> Input file
* `iflag` --> "read as per the comma separated symbol list"
 * `skip_bytes` --> "treat 'skip=N' as a byte count (iflag only)"
 * `count_bytes` --> "treat 'count=N' as a byte count (iflag only)"
 * `fullblock` --> "accumulate full blocks of input (iflag only)"
* `skip=70254592` --> Skip the first 70254592 bytes from the image. The start position of the second partition inside the image file. 
* `count=4278190080` --> The size of the second partition.

That's all. At the end of this step we have two files:
```
-rw-r--r-- 1 root root 4278190080 nov 19 16:39 root_fs.img
-rw-r--r-- 1 root root 70254591 nov 19 16:36 boot_fs.img 
```

We can check all of them by using fdisk/parted/gdisk/gparted utility.

---

####3. Prepare HDDs
#####3.1. Remove all partition entries from the disk
**Example:** `wipefs --all /dev/sdb`  
==IMPORTANT:== This will destroy all data on your entire disk!

#####3.2. Create Partition

If you want to copy an image (for example the root_fs.img) to your Hard Drive, first create a partition on it.

**Run parted:**
`parted /dev/sdb`  

**You will see an error message:** 
`Error: /dev/sdb: unrecognised disk label`  

So we have to **create the disk label** first:
Command (inside parted): 
```
(parted) mktable msdos
Create a partition for the image. Its size have to be at least 4278190080 Byte, but we will create a 20GB partition.
(parted) mkpart                                                           
Partition type?  primary/extended? primary                                
File system type?  [ext2]? ext3
Start? 0%
(optional) Check the partition
(parted) p                                                                
Model: WDC WD25 00JB-98GVA0 (scsi)
Disk /dev/sdb: 250GB
Sector size (logical/physical): 512B/512B
Partition Table: msdos
Disk Flags: 

Number  Start   End     Size    Type     File system  Flags
 1      1049kB  20,0GB  20,0GB  primary  ext3         lba
```

After that you can create as many partition as you want. To create partitions you can use `gparted` graphical utility, too, or any other partition utility.

#####3.2. Copy image to the partition
**Command:**
`dd if=root_fs.img of=/dev/sdb1 bs=4096`

If you created larger partition than the image, you have to **resize to partition.** (Of course if you created smaller partition than the image, dd will fail with "no space left on device" error message.) 
Before running resize2fs you have to check the partition: `e2fsck -f /dev/sdb1`
Resize: `resize2fs /dev/sdb1`

####3. Configure Raspberry to use root fs on the external hard drive
#####3.1. `cmdline.txt`
This file can be found on the boot partition, on your SD card.

Modify from: `root=/dev/mmcblk0p2`
To: `root=/dev/sda1`

#####3.2. `etc/fstab`
This file must be located on your external hard disk root partition. If your SD card still have the root partition lest modify fstab on it, because it won't take effect.

Modify from: `/dev/mmcblk0p2 / ext4 defaults,noatime 0 1`
To: `/dev/sdaq / ext4 defaults,noatime 0 2`

####4. Final Thoughts

I think running OS from an external HDD (or SSD) is highly recommended. As this post doesn't give you a step-by-step guide, I share with you the method I usually move root fs to HDD:

1. Download the image from [https://www.raspberrypi.org/downloads/](https://www.raspberrypi.org/downloads/)
2. Write the image to an SD card. (Linux: dd)
3. Start your Raspberry PI and do the initial steps. The most important the FS resize.
4. Shutdown the Raspberry
5. Copy the root partition to the HDD. (Linux: dd)
5. Edit cmdline.txt and fstab. (Please aware that the cmdline.txt remains on the SD card, but the fstab must be edited on the HDD.)
6. Take back the SD card to the Raspberry & connect the external HDD.
7. Boot & Enjoy



==**References:**==

* [http://unix.stackexchange.com/questions/38164/create-partition-aligned-using-parted](http://unix.stackexchange.com/questions/38164/create-partition-aligned-using-parted)
* [https://www.pantz.org/software/parted/parted_and_disk_alignment.html](https://www.pantz.org/software/parted/parted_and_disk_alignment.html)
* [http://askubuntu.com/questions/201164/proper-alignment-of-partitions-on-an-advanced-format-hdd-using-parted](http://askubuntu.com/questions/201164/proper-alignment-of-partitions-on-an-advanced-format-hdd-using-parted) 
* [http://rainbow.chard.org/2013/01/30/how-to-align-partitions-for-best-performance-using-parted/](http://rainbow.chard.org/2013/01/30/how-to-align-partitions-for-best-performance-using-parted/)
* [http://gparted.org/h2-fix-msdos-pt.php](http://gparted.org/h2-fix-msdos-pt.php)
* [https://www.raspberrypi.org/documentation/hardware/raspberrypi/bootmodes/msd.md](https://www.raspberrypi.org/documentation/hardware/raspberrypi/bootmodes/msd.md)















 