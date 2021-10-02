!!! caution
    **This page has been updated a long time ago.**  Information found here could be outdated and may lead to missconfiguration.  
    Some of the links and references may be broken or lead to non existing pages.  
    Please use this docs carefully. Most of the information here now is only for reference or example!

# Compile GO language on Raspberry PI
There are many ways to install GO language, eg. you can compile from source or use the pre-compiled binaries.
Here I want to show you how you can compile GO from source.


## 1. PreRequirements:

* Raspberry PI 2 or 3
* Raspbian  
I used this version: `Linux raspberrypi 4.4.13-v7+ #894 SMP Mon Jun 13 13:13:27 BST 2016 armv7l GNU/Linux`
`2016-05-27-raspbian-jessie.zip` can be downloaded from the [official RPI page](https://www.raspberrypi.org/downloads/).
* gcc
* And you check these links:  

    * [System Requirements And Install](https://golang.org/doc/install#requirements)  
    * [Installing Go from source](https://golang.org/doc/install/source) 
    * [Official GO git repo](https://go.googlesource.com/go)  
    * [GitHub repo](https://github.com/golang/go)
 

## 2. Install from source using git

In order to install the latest `go` you have to install 1.4.x version first.
I followed [this](https://github.com/google/cloud-print-connector/wiki/Build-from-source) useful link. 

* create a dedicated user: `gcp`  
`root@raspberrypi:~# useradd gcp`
* I set the home dir to /opt/google-cloud-print
```bash
cat /etc/passwd|grep gcp
gcp:x:1002:1002::/opt/google-cloud-print:/bin/bash
```
* Clone the repository from GIT:  
`git clone https://github.com/golang/go`
* Rename and copy â€œgoâ€ directory for different versions:  
```command-line 
mv go go1.4.3
cp -r go1.4.3 go1.5.2
cp -r go1.4.3 go1.6.3
```
* Checkout the versions  
```command-line 
cd go1.4.3/
git checkout go1.4.3
cd ..

cd go1.5.2/
git checkout go1.5.2
cd ..

cd go1.6.3/
git checkout go1.6.3
```
As you can see I will compile 3 different versions: 1.4.3, 1.5.2 and the latest one: 1.6.3.

* First of all we will compile 1.4.3:
```
cd /opt/google-cloud-print/git/go1.4.3/src
./all.bash
```
* When the compilation is successfully finished, you have to set some system environments:
```bash
export GOROOT_BOOTSTRAP=/opt/google-cloud-print/git/go1.4.3
export GOROOT="/opt/google-cloud-print/git/go1.4.3"
export GOROOT_BOOTSTRAP="$GOROOT"
export GOPATH="$GOROOT/src"
export PATH="$PATH:$GOROOT/bin"
```
* Next compile the newer versions.  I move forward with 1.6.x:
```
cd /opt/google-cloud-print/git/go1.6.3/src
./all.bash
```
!!! note
    You can run into "not enough" memory issue while package is being tested, but despite the errors `go` will work properly.

If everything was fine you use different versions of GO, by exporting system environments.
I created 3 files to manage different versions:

**==setGoEnv1.4.3.sh==**
```bash
#!/bin/bash
export GOROOT="/opt/google-cloud-print/git/go1.4.3"
export GOROOT_BOOTSTRAP="$GOROOT"
export GOPATH="$GOROOT/src"
export PATH="$PATH:$GOROOT/bin"
```
**==setGoEnv1.5.2.sh==**
```bash
#!/bin/bash
export GOROOT="/opt/google-cloud-print/git/go1.5.2"
export GOROOT_BOOTSTRAP="$GOROOT"
export GOPATH="$GOROOT/src"
export PATH="$PATH:$GOROOT/bin"
```

**==setGoEnv1.6.3.sh==**
```bash
#!/bin/bash
export GOROOT="/opt/google-cloud-print/git/go1.6.3"
export GOROOT_BOOTSTRAP="$GOROOT"
export GOPATH="$GOROOT/src"
export PATH="$PATH:$GOROOT/bin"
```
* The final step is to check if GO working correctly or not.  
Directory Structure:
```bash
gcp@raspberrypi:~/git$ pwd
/opt/google-cloud-print/git
gcp@raspberrypi:~/git$ ls -al
total 32
drwxr-xr-x  5 gcp gcp 4096 Aug 11 14:35 .
drwxr-xr-x  4 gcp gcp 4096 Aug 11 11:55 ..
drwxr-xr-x 12 gcp gcp 4096 Aug 11 10:49 go1.4.3
drwxr-xr-x 11 gcp gcp 4096 Aug 11 11:17 go1.5.2
drwxr-xr-x 11 gcp gcp 4096 Aug 11 13:57 go1.6.3
-rwxr-xr-x  1 gcp gcp  158 Aug 11 14:34 setGoEnv1.4.3.sh
-rwxr-xr-x  1 gcp gcp  158 Aug 11 14:35 setGoEnv1.5.2.sh
-rwxr-xr-x  1 gcp gcp  158 Aug 11 14:35 setGoEnv1.6.3.sh
```
**Check versions:** 
```bash
gcp@raspberrypi:~/git$ . setGoEnv1.5.2.sh
gcp@raspberrypi:~/git$ go version
go version go1.5.2 linux/arm
```
```bash
gcp@raspberrypi:~/git$ source setGoEnv1.4.3.sh 
gcp@raspberrypi:~/git$ go version
go version go1.4.3 linux/arm
```

!!! note
    Please keep in mind that you have to log out from the current shell after using one of the installed go, because the scripts Iâ€™m using to set the environment which will concatenate the PATH after each run. For example you set the sysenv to use 1.4.3, the script will add `/opt/google-cloud-print/git/go1.4.3/bin/` directory to the PATH env.
    Or you have to remove the current go path from system `PATH` before sourceing another environment.

## 3. Install from downloaded source

You can download source code form the offical web page:
[https://golang.org/dl/](https://golang.org/dl/)

!!! note
    As you can see there are precompiled binary file for ARM CPUs. But only for ARMv6! Be sure which type of CPU you are using before downloading GO. (Raspberry 2 has ARMv7 CPU!)
    The install steps are the same as in case of using GIT.
    Just for fun I will show you how easy to use these official source codes.

* Download the source code of version 1.4.3.
![Download](/assets/img/2016-08-12_161725.jpg){ loading=lazy }
```
gcp@raspberrypi:~/sources$ wget https://storage.googleapis.com/golang/go1.4.3.src.tar.gz
--2016-08-12 16:19:08--  https://storage.googleapis.com/golang/go1.4.3.src.tar.gz
Resolving storage.googleapis.com (storage.googleapis.com)... 216.58.208.48, 2a00:1450:4001:817::2010
Connecting to storage.googleapis.com (storage.googleapis.com)|216.58.208.48|:443... connected.
HTTP request sent, awaiting response... 200 OK
Length: 10875170 (10M) [application/octet-stream]
Saving to: â€˜go1.4.3.src.tar.gz.1â€™

go1.4.3.src.tar.gz.1                            100%[=======================================================================================================>]  10.37M  5.26MB/s   in 2.0s   

2016-08-12 16:19:10 (5.26 MB/s) - â€˜go1.4.3.src.tar.gz.1â€™ saved [10875170/10875170]
```
* Extract
```
gcp@raspberrypi:~/sources$ tar xf go1.4.3.src.tar.gz 
gcp@raspberrypi:~/sources$ mv go go1.4.3
gcp@raspberrypi:~/sources$ 
```
* Compile
```
gcp@raspberrypi:~/sources/go1.4.3/src$ ./all.bash 
```

After the compilation is done you can compile later versions of `go`. Don't forget to set system environments before compiling.








