# Install OpenALPR on Raspberry PI 3

!!! caution
    This page hasn't recently updated. Information found here could be outdated and may lead to missconfiguration.  
    Some of the links and references may be broken or lead to non existing pages.  
    Please use this docs carefully. Most of the information here now is only for reference or example!

!!! warning
    It seems there  are some problems with using the latest Tesseract code base.
    For mor details please see the comments!

!!! info
    I wrote a now post about this topic. "Install OpenALPR on Raspberry PI 3 (Part 2)"

Before you start installing OpenALPR I suggest you to go through this and the mentioned post first. They may contain a lot of useful information. 



In this tutorial I will show how can you install [OpenALPR](https://github.com/openalpr/openalpr) on you Raspberry PI 3.
From its home page:
> OpenALPR is an open source **Automatic License Plate Recognition** library written in C++ with bindings in C#, Java, Node.js, Go, and Python. The library analyzes images and video streams to identify license plates. The output is the text representation of any license plate characters.

So after successfully installation of OpenALPR you Raspberry will be able to recognize License Plates from a single photo or from live stream. 
Please note that in your country **maybe illegal** to use this tool on public or even for private use, therefore I use it only for my entertainment.

OK. Lets Begin. :)

## What is needed?

* Raspberry Image: 2016-05-27-raspbian-jessie.img  
[https://www.raspberrypi.org/downloads/](https://www.raspberrypi.org/downloads/)
* At least ~~8GB~~ 16GB microSD card to flash the image.
* Raspberry PI 2 or 3 (I do not advise RPI 1 because I think it is too slow, and image processing will also be slow, and the compiling process will take much longer)

##  Update & Upgrade

Before you start installing alpr and its dependencies update your Raspbian. I use a vanilla image so it is must to update.

!!! comment
    I will do evry step with root access. (Without root access you are lost, or at least the install process will be much harder.)  
    This Raspberry is only for this project thus I don't have to care about loosing anything, or installing packages which overrides other projects. 

Run the following commands:
```bash
apt-get update 
apt-get upgrade
```

## Install the necessary packages

Previously I gathered all of the packages are needed to compile alpr and all of its dependencies. 

```bash
apt-get install autoconf automake libtool
apt-get install libleptonica-dev
apt-get install libicu-dev libpango1.0-dev libcairo2-dev
apt-get install cmake git libgtk2.0-dev pkg-config libavcodec-dev libavformat-dev libswscale-dev
apt-get install python-dev python-numpy libjpeg-dev libpng-dev libtiff-dev libjasper-dev libdc1394-22-dev
apt-get install virtualenvwrapper
apt-get install liblog4cplus-dev
apt-get install libcurl4-openssl-dev

```

In one line:  

```bash
apt-get install autoconf automake libtool libleptonica-dev libicu-dev libpango1.0-dev \
libcairo2-dev cmake git libgtk2.0-dev pkg-config libavcodec-dev libavformat-dev \
libswscale-dev python-dev python-numpy libjpeg-dev libpng-dev libtiff-dev \
libjasper-dev libdc1394-22-dev virtualenvwrapper liblog4cplus-dev libcurl4-openssl-dev
```

Based on another tutorial I know It has a chance that `apt-get isntall` will fail with "no package found". In this case you have to manually find the missing package using `apt-cache search ....`. 
It may happen that in the meanwhile the package name or version has been changed therefore apt won't find it.

## Dependencies

I think this chapter will be the hardest to be done.
Offical github Install documentation:
[https://github.com/openalpr/openalpr/wiki/Compilation-instructions-(Ubuntu-Linux)](https://www.raspberrypi.org/downloads/)
[https://github.com/openalpr/openalpr](https://www.raspberrypi.org/downloads/)

OpenALPR requires the following additional libraries:

- [Tesseract OCR v3.0.4](https://github.com/tesseract-ocr/tesseract)
- [OpenCV v2.4.8+](http://opencv.org/)

And these have them own dependencies. :(

### Tesseract OCR

* Download (clone) the package from git.
Reference:  [https://github.com/tesseract-ocr/tesseract/wiki/Compiling](https://www.raspberrypi.org/downloads/)

```bash
cd /usr/local/src/
git clone https://github.com/tesseract-ocr/tesseract
```

If you want to use the exactly same version I used please checkout `3.05.00dev-380-g2660647`. Currently this is the master.

* Follow these steps:
```bash
cd /usr/local/src/tesseract
./autogen.sh 
```

* If you are lucky you will get this message:
```bash
All done.
To build the software now, do something like:

$ ./configure [--enable-debug] [...other options]
```

* Next step is configure the package, as suggested in the message above run `./configure`. :)
If you want to know what "other options" are available first run `./configure --help`. Now I don't want to override the default configuration. If you compile without root access or you want to specify the install location please use this option:

```bash
Installation directories:
  --prefix=PREFIX         install architecture-independent files in PREFIX
                          [/usr/local]
```

As you can see by default Tesseract will be installed in `/usr/local/`.
It is OK for me.

After configuring run:
`make` - It will take long time.  If you want make it faster use `-j2` option or if you are brave enough `-j4`. :) 
```plain
-j [jobs], --jobs[=jobs]
            Specifies the number of jobs (commands) to run simultaneously.  If there is more than one -j option, the last one is effective.  If the -j option is given without  an  arguâ€
            ment, make will not limit the number of jobs that can run simultaneously.
```

I have tried with `-j4` but it leads to "segmentation fault". So I advise you to run max 2 jobs simultaneously.

Finish the install with `make install` command.

You can check if the compilation was successfully or not by:

```bash
root@raspberrypi:/usr/local/src/tesseract# tesseract 
tesseract: error while loading shared libraries: libtesseract.so.3: cannot open shared object file: No such file or directory
```
If you get the error below **try to run** `ldconfig`.

Now you can check again:
```bash
root@raspberrypi:/usr/local/src/tesseract# tesseract -v
tesseract 3.05.00dev
 leptonica-1.71
  libgif 4.1.6(?) : libjpeg 6b : libpng 1.2.50 : libtiff 4.0.3 : zlib 1.2.8 : libwebp 0.4.1 : libopenjp2 2.1.0
```

Optionally you can install tesseract training:
```
make training
sudo make training-install
```

### OpenCV

* [Home page](http://opencv.org/)
* [Download page](http://opencv.org/downloads.html)
* [Current latest version](https://github.com/Itseez/opencv/archive/2.4.13.zip)
* [Install Documentation](http://docs.opencv.org/2.4/doc/tutorials/introduction/linux_install/linux_install.html#linux-installation)


**Pre-Steps:**

* Download the latest version.

```bash
cd /usr/local/src
wget https://github.com/Itseez/opencv/archive/2.4.13.zip
mv 2.4.13.zip OpenCV-2.4.13.zip
```

* Unzip it

`unzip -q  OpenCV-2.4.13.zip`  
This will create a directory: `/usr/local/src/opencv-2.4.13`

* Run cmake 

```bash
cd /usr/local/src/opencv-2.4.13
mkdir release
cd release
cmake -D CMAKE_BUILD_TYPE=RELEASE -D CMAKE_INSTALL_PREFIX=/usr/local -D BUILD_NEW_PYTHON_SUPPORT=ON -D INSTALL_C_EXAMPLES=ON -D INSTALL_PYTHON_EXAMPLES=ON  -D BUILD_EXAMPLES=ON ..
```

This comamnd will configure the project.
If you are lucky again you will get this message:

```plain
-- Configuring done
-- Generating done
-- Build files have been written to: /usr/local/src/opencv-2.4.13/release
```

* Run make

I strongly recommend to use `-j2` option, because this step takes the most of time:
`root@raspberrypi:/usr/local/src/opencv-2.4.13/release# make -j2`

Unfortunately at the first time my `make` command died with this message:

```
[ 47%] Building CXX object modules/ocl/CMakeFiles/opencv_ocl.dir/src/cl_runtime/clamdfft_runtime.cpp.o
c++: internal compiler error: Segmentation fault (program cc1plus)
Please submit a full bug report,
with preprocessed source if appropriate.
See <file:///usr/share/doc/gcc-4.9/README.Bugs> for instructions.
modules/ocl/CMakeFiles/opencv_ocl.dir/build.make:719: recipe for target 'modules/ocl/CMakeFiles/opencv_ocl.dir/src/cl_runtime/clamdfft_runtime.cpp.o' failed
make[2]: *** [modules/ocl/CMakeFiles/opencv_ocl.dir/src/cl_runtime/clamdfft_runtime.cpp.o] Error 4
CMakeFiles/Makefile2:4734: recipe for target 'modules/ocl/CMakeFiles/opencv_ocl.dir/all' failed
make[1]: *** [modules/ocl/CMakeFiles/opencv_ocl.dir/all] Error 2
make[1]: *** Waiting for unfinished jobs....
```

As I wrote above you may get this error. It may be caused by because you run out of memory. I don't know exact solution for this issue on Raspberry, but I have some suggestion:

* Reboot you RPI
* Try not to specify `-j` option or use `-j1`
* Run `make clean` and `make` again
* Increase swap space.

```bash
fallocate --length 2GiB /root/2G.swap
chmod 0600 /root/2G.swap
mkswap /root/2G.swap 
swapon /root/2G.swap 

```

After 'n' (re)tries `make -j2` command finished successfully.
The next (and final) step with OpenCV is run:
`make install`

## Install OpenALPR
Finally we can continue with OpenALPR. :)

* Clone the git repository:

```bash
cd /usr/local/src
git clone https://github.com/openalpr/openalpr.git
```

* (optional) Check version

```bash
cd openalpr
git describe --tags
v2.1.0-513-gcd2aab0
```
Now this is the master branch. If the master branch is not this version, you can checkout v2.1.0 if you want to use exact same version.
`git checkout v2.1.0`

* Run cmake

```bash
root@raspberrypi:/usr/local/src/openalpr# cd src/
root@raspberrypi:/usr/local/src/openalpr/src# cmake ./
```

* run make
* 
`root@raspberrypi:/usr/local/src/openalpr/src# make`  
The situation is the same, if `make` fails try to follow the steps are described earlier.

Please remember to run `ldconfig`.


Now you can see that compiling OpenALPR is much easier than installing its dependencies. And please note that I have gathered the necessary packages. At the very first time I installed these packages It took 6 or more hours. Despite the lot of good articles there were a lot of dependencies I had to find manually.
And first time I tried to install OpenCV and Tesseract into a custom directories for example `/opt/OpenCV` and `/opt/Tesseract`. If you try this you have to manually define these libraries to OpenALPR in **CMakeLists.txt**. 
Just for demonstration I tried these settings:

```bash
SET(OpenCV_DIR "/opt/opencv-2.4.13/share/OpenCV/")
SET(Tesseract_DIR "/usr/src/tesseract")
SET(Tesseract_LIB "/opt/tesseract/lib/")
SET(Tesseract_INCLUDE_DIRS "/opt/tesseract/include/")
SET(Tesseract_INCLUDE_BASEAPI_DIR "/opt/tesseract/include")
SET(Tesseract_PKGCONF_INCLUDE_DIRS "/opt/tesseract/include/tesseract")
```

But for some reason `make` always failed because of tesseract. After some hours I was fed up with it and installed tesseract to its default location.
I had to recompile only tesseract to successfully compile OpenALPR, OpenCV remained in `/opt/`. In this case this line is must inserted to CMakeLists.txt:
`SET(OpenCV_DIR "/opt/opencv-2.4.13/share/OpenCV/")`.

Ok. Test the newly install alpr system.
```bash
cd /usr/local/src/openalpr/src
root@raspberrypi:/usr/local/src# alpr ea7the.jpg 
plate0: 10 results
    - EA7THE	 confidence: 91.0578
    - EA7TBE	 confidence: 84.133
    - EA7T8E	 confidence: 83.0083
    - EA7TRE	 confidence: 82.7869
    - EA7TE	 confidence: 82.5961
    - EA7TME	 confidence: 80.2908
    - EA7TH6	 confidence: 77.0045
    - EA7THB	 confidence: 75.5779
    - EA7TH	 confidence: 74.6576
    - EA7TB6	 confidence: 70.0797
```

Wow. It is working. :)
You can find configuration examples in `/usr/local/share/openalpr/config` directory.

**REFERENCES:**  

* [http://www.pyimagesearch.com/2015/02/23/install-opencv-and-python-on-your-raspberry-pi-2-and-b/](http://www.pyimagesearch.com/2015/02/23/install-opencv-and-python-on-your-raspberry-pi-2-and-b/)
* [http://docs.opencv.org/2.4/doc/tutorials/introduction/linux_install/linux_install.html#linux-installation](http://www.pyimagesearch.com/2015/02/23/install-opencv-and-python-on-your-raspberry-pi-2-and-b/)
* [https://virtualenv.pypa.io/en/stable/](http://www.pyimagesearch.com/2015/02/23/install-opencv-and-python-on-your-raspberry-pi-2-and-b/)
* [https://gist.github.com/amstanley/9da7febc9a3e3c2228ee](http://www.pyimagesearch.com/2015/02/23/install-opencv-and-python-on-your-raspberry-pi-2-and-b/)





