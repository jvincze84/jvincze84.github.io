# Nokia 6120c (BB5) Forgotten Security Code

!!! caution
    **This page has been updated a long time ago.**  Information found here could be outdated and may lead to missconfiguration.  
    Some of the links and references may be broken or lead to non existing pages.  
    Please use this docs carefully. Most of the information here now is only for reference or example!
    

Maybe this post is a bit outdated, but still can be useful whose wants to bring back an old Nokia phone to life.
My story is very simple and usual. I've forgotten my security code of an old Nokia 6120c. The key problem was that I locked my phone, and could not turn it on. It always asked for the security code, and after 5 tries locked for 5 minutes, thus brute force would have been a bit time-consuming. Oh! Why I wanted to use such an old phone? I had to carry my iPhone to the service and was thinking about going back in time and using one of my really old phone during I'm waiting to get my iPhone back, so I chose my old Nokia 6120c. 

I had started googling and found some article about how to unlock BB5 phones. Unfortunately there are a lot of article which can lead you to the wrong way. For example generating master unlock code is not possible for bb5 phones, and please aware of downloading software from unknown sources.

**NOTE:** Resetting your phone won't set your security code to its original (12345)! By the way, you can hard reset your phone by following these easy steps:

1. Turn OFF your phone.
1. Press and **hold** "Green phone" + "3" + "*" button.
1. Press and hold the power button while the phone is turned on.
1. After displaying the "Nokia" message and the phone turned on (or asking for security code, if it is locked) you can release the mentioned button in the 2. step.

---

==**REFERENCE Link:**==

[http://forum.gsmhosting.com/vbb/f299/get-your-phone-lock-code-security-code-without-reset-format-nokia-bb5-phones-teste-667948/](http://forum.gsmhosting.com/vbb/f299/get-your-phone-lock-code-security-code-without-reset-format-nokia-bb5-phones-teste-667948/)

It the post linked below you can find everything you need to successfully retrieve your security code. Here I want to give you a "real" step by step guide with screenshots and examples. 

**What will you need?**

1. A locked **phone** with forgotten security code (You don't really need this, you can do it as hobby, as well :) )
1. An **USB cable**
1. An ~5K **resistor**
1. Installed NSS (**Nemesis Service Suite** 1.0.38.15)  During the install please choose the **"Virtual USB device"**. 
Download link:
1. Installed "**Nokia Suite**" or "**Nokia Connectivity Cable Driver**"
1. (Optional) Charger

**First** you have to connect the 5K resistor between BSI (middle) and GNS ("-") pins of the battery connector. DO NOT short circuit your battery by connecting the "+" and "-" to each other even through the resistor!

---
![Screenshot1](/assets/images/2017/01/IMG_1875-1.JPG)

---

![Screenshot2](/assets/images/2017/01/IMG_1874-1.JPG)
---

**Next** turn your phone on. You have to see something like this:

![](/assets/images/2017/01/IMG_1877-1.JPG)


**After that** you should connect the phone to your computer with the mini USB cable and start NSS.   
**Click on** the magnifier button on the top right corner:

![](/assets/images/2017/01/2017-01-09_213106.jpg)


**Click on** the Device Info, then the Scan button:

![](/assets/images/2017/01/2017-01-09_213137.jpg)

**Finally** click on the "Permanent Memory" tab, and "Read" button:

![](/assets/images/2017/01/2017-01-09_213157.jpg)



**As the last step** a .pm file will be created in this directory: "c:\Program Files (x86)\NSS\Backup\pm\". The file name have to be the imei number of your phone. Example: "358640012938846.pm"

Look for the line beginning with "5=", in my case this is the 218. line.
Example:
`5=38343634350000000000`

**Remove** every second "3" digit and the trailing zeros, the remaining is your security code (`84645`).

That's all! :)











