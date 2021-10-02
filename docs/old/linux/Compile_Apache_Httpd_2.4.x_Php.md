# Compile Apache HTTPD 2.4.X & PHP

!!! caution
    This page hasn't recently updated. Information found here could be outdated and may lead to missconfiguration.  
    Some of the links and references may be broken or lead to non existing pages.  
    Please use this docs carefully. Most of the information here now is only for reference or example!



 
## What Is Needed / Requirements

Compiling apache from source is very easy you have to follow some steps. In case of almost all linux distributions Apache http server can be installed via its package manager.
There are some **advantages** of compiling Apache (or any other application) from source, but If you don't have any special requirement I advise to install Apache from package manager. But yet in certain cases you have to compile from source:  

* You do not have root access. In this case it will be hard to install the necessary packages. :) But If every needed packages are installed you can compile apache. And run it with your own user. If you install apache from package manager, apache will write its log files with root user, and the config files will be writable for only root user. Of course you can give (r/w) permission to other user to these files.
I think this scenario is rare, and without root access your possibilities are very limited.
* You can install different version of the application, which cannot be install via package manager. 
* You can complie the application with certain flags and options which may be missing  in the repository. 

**Disadvantages:**

* You have to install all dependencies manually. 
* Your package manager will unaware of the changes. 
* Your applications will have to be updated manually.
* Maybe you package manager will be overwrite the dependencies.

In my case I had to install the following packages:

* `apt-get install libpcre3-dev`
* `apt-get install libxml2-dev`

My OS:
Debian GNU/Linux 8 
Linux vps10 2.6.32-042stab116.2 #1 SMP Fri Jun 24 15:33:57 MSK 2016 x86_64 GNU/Linux

These packages must be downloaded:

* [Apache HTTPD source.](https://httpd.apache.org/) 
* [APR and APR util](https://apr.apache.org/download.cgi)
* [PHP 5](http://php.net)

## Preparation

I created a certain user which will be used all over the whole install process and this user will run the apace process.

```bash
adduser apache2
mkdir /opt/apache2
chown apache2:apache2 /opt/apache2/
```

I modified this user's shell to `/bin/false` and home directory to `/opt/apache2`.
```bash
root@vps10:/home/vinyo# cat /etc/passwd|grep apa
apache2:x:1002:1002:,,,:/opt/apache2/:/bin/false
```

So this user won't be able to login to the linux box, but you can use `sudo` to switch to apache2 user:
`sudo -u apache2 bash`

## Download the necessary sources

I put all sources to: `/opt/apache2/sources`

```bash
cd /opt/apache2/
mkdir sources
cd sources/
wget http://xenia.sote.hu/ftp/mirrors/www.apache.org//httpd/httpd-2.4.23.tar.gz
wget http://xenia.sote.hu/ftp/mirrors/www.apache.org//apr/apr-1.5.2.tar.gz
wget http://xenia.sote.hu/ftp/mirrors/www.apache.org//apr/apr-util-1.5.4.tar.gz
wget http://fr2.php.net/distributions/php-5.6.25.tar.gz
```

## Compile Apache whit apr and apr-util

* **First you have to untar the apache source**
```bash
cd /opt/apache2/sources/
tar xf httpd-2.4.23.tar.gz
```

* **Untar apr, apr-util**
```bash
cd /opt/apache2/sources/httpd-2.4.23/srclib
tar xf /opt/apache2/sources/apr-1.5.2.tar.gz
tar xf /opt/apache2/sources/apr-util-1.5.4.tar.gz
```

* **Rename APR directories**
```bash
mv apr-1.5.2 apr
mv apr-util-1.5.4 apr-util
```

* **Compile Apache**
```bash
cd /opt/apache2/sources/httpd-2.4.23
./configure  --enable-mpms-shared=all --enable-ssl --prefix=/opt/apache2/httpd-2.4.23
make
make install
```

Apache will be installed to `/opt/apache2/httpd-2.4.23`. 
After the make install command you can start you newly installed apache httpd server.
But if you try to start apache you will be get this error:

```plain
apache2@vps10:/opt/apache2/httpd-2.4.23/bin$ ./apachectl start
(13)Permission denied: AH00072: make_sock: could not bind to address [::]:80
(13)Permission denied: AH00072: make_sock: could not bind to address 0.0.0.0:80
no listening sockets available, shutting down
AH00015: Unable to open logs
```

Yes, only root user can bind ports below 1025. So we have to modify listen port in `/opt/apache2/httpd-2.4.23/conf/httpd.conf` file.
From: `Listen 80`
To: `Listen 8080`
After that little modification apache can be started. Check the log file:

```plain
cat /opt/apache2/httpd-2.4.23/logs/error_log
[Sat Aug 27 12:02:53.021908 2016] [mpm_event:notice] [pid 30164:tid 140121349551872] AH00489: Apache/2.4.23 (Unix) PHP/5.6.25 configured -- resuming normal operations
[Sat Aug 27 12:02:53.021972 2016] [core:notice] [pid 30164:tid 140121349551872] AH00094: Command line: '/opt/apache2/httpd-2.4.23/bin/httpd'
```

Now your apache web server is accessible on port 8080, you can call it from your browser.

## Install PHP

* Previously we downloaded the php source, now **untar** it:
```bash
cd /opt/apache2/sources
tar xf php-5.6.25.tar.gz
```

* **Compile**
```bash
./configure --with-apxs2=/opt/apache2/httpd-2.4.23/bin/apxs --with-mysql --prefix=/opt/apache2/php-5.6.25
make 
make install
```

This will create a new directory: `/opt/apache2/php-5.6.25` This is the install path of php. 
During the installation php will modify your apache configuration to load php module:
`LoadModule php5_module        modules/libphp5.so`
And you can find the php module in apache modules directory:
```bash
apache2@vps10:/opt/apache2/httpd-2.4.23/modules$ ls -al | grep php
-rwxr-xr-x  1 apache2 apache2 28575008 Aug 27 09:09 libphp5.so
```

Before you **restart your apache2** instance place your php.ini to the appropriate place:
`apache2@vps10:/opt/apache2/php-5.6.25/lib$ cp /opt/apache2/sources/php-5.6.25/php.ini-production php.ini`

To check if php is working place `info.php` file to your htdocs directory with this content:
```bash
apache2@vps10:/opt/apache2/httpd-2.4.23/htdocs$ cat info.php
<?php
phpinfo();
?>
```

You can call this file using lynx:
```bash
lynx --dump http://localhost:8080/info.php | grep php.ini
   Configuration File (php.ini) Path /opt/apache2/php-5.6.25/lib
   Loaded Configuration File /opt/apache2/php-5.6.25/lib/php.ini
```
## Summary
As you can see "compiling apache from source" consist of a few steps, but after that if you need any additional php module you will have to install them manually by:

* Using /opt/apache2/php-5.6.25/bin/**pear**
* Using /opt/apache2/php-5.6.25/bin/**pecl**
* Compile from source (phpize, configure, make, make install)

If you can afford, consider using your package manager to install apache & php, because it is much simpler and in most cases you won't need to compile from source. 
























