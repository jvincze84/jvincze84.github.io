!!! caution
    **This page has been updated a long time ago.**  Information found here could be outdated and may lead to missconfiguration.  
    Some of the links and references may be broken or lead to non existing pages.  
    Please use this docs carefully. Most of the information here now is only for reference or example!
    
# Install OpenALPR on Raspberry PI 3 (Part 2)

I'm writing this post because it was reported that there are some issues with installing OpenALPR and its dependencies. 
You can check the comments to my old post about this topic here: [Install OpenALPR on Raspberry PI 3](https://blog.vinczejanos.info/2016/08/31/install-openalpr-on-raspberry-pi-3/)

After the installation of OpenALPR you can get this error message:

```
Error in fopenReadStream: file not found
Error in pixaRead: stream not opened
Warning in pixaGetFont: pixa of char bitmaps not found
Info in bmfCreate: Generating pixa of bitmap fonts
Error in fopenReadStream: file not found
Error in pixRead: image file not found: /usr/local/src/openalpr/src/build/chars-14.tif
Error in pixaGenerateFont: pixs not all defined
Error in bmfCreate: font pixa not made
```

I think the main problem with my first post that some people try to follow the steps without checking the dependencies.
I tried to install OpenALPR by following my post, and  I successfully reproduced the issue.
Unfortunately I didn't have enough time to try this on my RPI3, so I created a VM with much more RAM and CPU than RPI have to decrease the compiles time. 
If you follow my old post you will install the latest packages which is not too good.

**So as the first step you have to always check the dependencies!**

## 1. **OpenALPR dependencies:** [Link](https://github.com/openalpr/openalpr)

>- Tesseract OCR v3.0.4 ([https://github.com/tesseract-ocr/tesseract](https://github.com/tesseract-ocr/tesseract))
>- OpenCV v2.4.8+ ([http://opencv.org/](https://github.com/tesseract-ocr/tesseract))

## 2. **Tesseract dependencies:** [Link](https://github.com/tesseract-ocr/tesseract/wiki/Compiling#linux)

![](/assets/images/2017/05/2017-04-19_150043.jpg)

==First Note:==

OpenALPR does NOT need the newest Tesseract! 
Tesseract needs Leptonica, and it can be download from [here](http://www.leptonica.com/download.html).

**BUT!** At the moment the newest version is:
> Latest version: 1.74.1 (1/3/17)

So we can notice that:

* OpenALRP needs Tesseract 3.04
* Tesseract needs Leptonica 1.71

Just for testing purpose I installed the latest Leptonica, Tesseract & OpenCV.

## 3. **OpenCV dependencies:** [Link](http://opencv.org/releases.html)

The Latest OpenCV version:

![](/assets/images/2017/05/2017-05-01_204940.jpg)

==Second Note:== We DO NOT need this version. 

If you get this error:
```bash
root@opanalpr-tst02:/usr/local/src/opencv-3.2.0/release# opencv_version
libdc1394 error: Failed to initialize libdc1394
```
Please run this: 
`ln /dev/null /dev/raw1394`

And / or install these packages:
```bash
apt-get install libdc1394-22-dev
apt-get install libdc1394-22 libdc1394-utils
```

## 4. Conclusion

If you install the newest version of all dependencies you will get this **error message**:
```
Error in fopenReadStream: file not found
Error in pixaRead: stream not opened
Warning in pixaGetFont: pixa of char bitmaps not found
Info in bmfCreate: Generating pixa of bitmap fonts
Error in fopenReadStream: file not found
Error in pixRead: image file not found: /usr/local/src/openalpr/src/build/chars-14.tif
Error in pixaGenerateFont: pixs not all defined
Error in bmfCreate: font pixa not made
```

==**Third Note:**==

I suggest to everyone to try installing only the requires version of dependencies, not always the latest one.

Maybe there are some ways to use OpenALPR with the latest OpenCV and Tesseract but I failed to find it.

Now here is a brief summary on how to install OpenALPR, including only the key steps with some explanation and suggestion.


## 5. Install OpenALPR

* **Install the dependencies**
```bash
apt-get install autoconf automake libtool libleptonica-dev libicu-dev libpango1.0-dev libcairo2-dev cmake git libgtk2.0-dev pkg-config libavcodec-dev libavformat-dev libswscale-dev python-dev python-numpy libjpeg-dev libpng-dev libtiff-dev libjasper-dev libdc1394-22-dev virtualenvwrapper liblog4cplus-dev libcurl4-openssl-dev
```
This part comes from my old post: [Install OpenALPR on Raspberry PI 3](https://blog.vinczejanos.info/2016/08/31/install-openalpr-on-raspberry-pi-3/)

* ==**Install Leptonica**==

```bash
cd /usr/src
wget http://www.leptonica.org/source/leptonica-1.71.tar.gz
tar xf leptonica-1.71.tar.gz
```

You may need to install these packages:
```bash
apt-get install libjpeg-dev libtiff5-dev libpng12-dev gcc make
```

**Compile:**
```bash
/usr/src/leptonica-1.71
./configure
make
make install
```

* ==**Install Tesseract**==

You also may need to install these packages:
```bash
apt-get install ca-certificates git
apt-get install autoconf automake libtool
apt-get install autoconf-archive
apt-get install pkg-config
```

If you plan to install the training tools, you also need the following libraries:
```bash
apt-get install libicu-dev
apt-get install libpango1.0-dev
apt-get install libcairo2-dev
```

**Clone From GIT**
```bash
cd /usr/src
git clone https://github.com/tesseract-ocr/tesseract.git
```

**Check available versions (tags)**
```bash
cd /usr/src/tesseract
git tag
```
**Checkout the version which we need:**
```bash
git checkout 3.04.01
```

**Run these commands:**
```bash
cd /usr/src/tesseract
./autogen.sh
./configure --enable-debug
make
make install
```

You will get the appropriate version:
```bash
root@openalpr-tst01:/usr/src/tesseract# tesseract -v
tesseract 3.04.01
 leptonica-1.71
  libjpeg 6b : libpng 1.2.50 : libtiff 4.0.3 : zlib 1.2.8
```

* ==**Install OpenCV**==

**Download and extract:**
```bash
cd /usr/src
wget https://github.com/opencv/opencv/archive/2.4.13.zip
unzip  2.4.13.zip
```

**Compile:**
```bash
cd opencv-2.4.13
mkdir release
cd release
cmake -D CMAKE_BUILD_TYPE=RELEASE -D CMAKE_INSTALL_PREFIX=/usr/local ..
make
make install
```

* ==**Install OpenALPR**==

**Download**
```bash
cd /usr/src
git clone https://github.com/openalpr/openalpr.git
```

**Build:**
```bash
cd openalpr/src
mkdir build
cd build
cmake -DCMAKE_INSTALL_PREFIX:PATH=/usr -DCMAKE_INSTALL_SYSCONFDIR:PATH=/etc ..
make
make install
```

If you experience some errors please try to install these packages:
```bash
apt-get install cmake
apt-get install liblog4cplus-dev libcurl3-dev
sudo apt-get install beanstalkd
apt-get install openjdk-7-jdk
export JAVA_HOME=/usr/lib/jvm/java-1.7.0-openjdk-amd64/
```

**Test:**
```bash
wget http://plates.openalpr.com/h786poj.jpg -O lp.jpg
alpr lp.jpg
```
The result must be something like this (Without any errors):
```bash
plate0: 8 results
    - 786P0      confidence: 90.1703
    - 786PO      confidence: 85.579
    - 786PQ      confidence: 85.3442
    - 786PD      confidence: 84.4616
    - 7B6P0      confidence: 69.4531
    - 7B6PO      confidence: 64.8618
    - 7B6PQ      confidence: 64.627
    - 7B6PD      confidence: 63.7444
```

If you get any type of missing library error at any steps, run `ldconfig` command. 

I hope this post will be useful for you, and you will be able to install OpenALPR.
If you have any further question or note you can leave a Disqus comment below.















