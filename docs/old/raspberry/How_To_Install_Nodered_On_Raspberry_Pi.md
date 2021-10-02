!!! caution
    **This page has been updated a long time ago.**  Information found here could be outdated and may lead to missconfiguration.  
    Some of the links and references may be broken or lead to non existing pages.  
    Please use this docs carefully. Most of the information here now is only for reference or example!
    
# How To Install NodeRED on Raspberry PI

**What is NodeRed?**
>Node-RED is a tool for wiring together hardware devices, APIs and online services in new and interesting ways.

## 0. Update Your System

As always we start with updating our system.
Run this with root:

```bash
apt-get update ; apt-get upgrade
```

## 1. Create User For NodeRed & NodeJS
We will run node-red with a non-root user.

* Add new user: `useradd nodered`
* Move user's home to /opt/nodered: `usermod -m -d /opt/nodered nodered`
* Change home directory's owner: `chown -R nodered:nodered /opt/nodered/`
* Change user's shell: `usermod -s /bin/bash nodered`

Login to user nodemcu: `sudo su - nodemcu`

## 2. Get The Necessary Packages

NodeRed is written in NodeJS, so the first step is to build a NodeJS runtime environment. We will build it from source, but the binaries are also available for multiple platforms on the [NodeJS official page.](https://nodejs.org/en/download/)

To compile from source we node some packages on our Linux system.[^1]
In my case I had to install only gcc, g++, clang and make packages with this command: `apt-get install gcc g++ clang make`

### 2.1. Download & Compile NodeJS

* Create a directory to store the source codes:  
`mkdir sources`
* Change to "sources" directory:  
`cd sources`
* Download the latest source code:  
`wget https://nodejs.org/dist/v7.2.0/node-v7.2.0.tar.gz`
* Untar:
`tar xf sources/node-v7.2.0.tar.gz`
* Check the available options of the 'configure' script:  
`cd /opt/nodered/sources/node-v7.2.0`  
`./configure --help`  
If you are using 'root' during the install you don't have to bother with options, simply run `./configure`. But now I'm using `nodered` user to compile nodered, so the 'prefix' option have to be used. Most of the configure script has this option, with this you can specify the directory you want to install the software (make install). The default is `/usr/local`, but nodered user do not have write access to this direcrory, thus we will specify a custom install localtion.
* Run the configure script:  
`./configure --prefix=/opt/nodered/node-v7.2.0`
* Run make:  
`make`  
This will take a long time (~2-3 hours). Please be patient. :)
* The last step is to run:  
`make install`

After the `make install` finished you will have the NodeJS runtime environment here:
```
ls -al /opt/nodered/node-v7.2.0/
total 24
drwxr-xr-x 6 nodered nodered 4096 Nov 25 07:12 .
drwxr-xr-x 4 nodered nodered 4096 Nov 25 07:13 ..
drwxr-xr-x 2 nodered nodered 4096 Nov 25 07:12 bin
drwxr-xr-x 3 nodered nodered 4096 Nov 25 07:12 include
drwxr-xr-x 3 nodered nodered 4096 Nov 25 07:12 lib
drwxr-xr-x 5 nodered nodered 4096 Nov 25 07:12 share
``` 

## 3. Install NodeRED
Now we are over the hump, there are a few commands left.

* Add NodeJS bin directory to PATH: `export PATH=$PATH:/opt/nodered/node-v7.2.0/bin/`
* Set up npm prefix system env: `export NPM_CONFIG_PREFIX=/opt/nodered/node-v7.2.0/lib/node_modules/`  
Unless this environment npm will try to install node-red to /usr/local, but 'nodered' user has no write access to this.
* Run: `npm install -g node-red`  
This command will install Node-Red, and after this process you can start your Node-Red instance by typing **`/opt/nodered/node-v7.2.0/lib/node_modules/bin/node-red`**.

######3.1. Run Node-Red In The Background
In order to run node-red in a the background we need one more package called `forever`.  [^3]

Do not forget to set up the system environments before install 'forever':
```
export NPM_CONFIG_PREFIX=/opt/nodered/node-v7.2.0/lib/node_modules/ 
export PATH=$PATH:/opt/nodered/node-v7.2.0/bin/
```
After that simply run: `npm -g install forever`
You can get help about forever by typing: `/opt/nodered/node-v7.2.0/lib/node_modules/bin/forever --help`

* Start Node-Red in the Background:  
`/opt/nodered/node-v7.2.0/lib/node_modules/bin/forever start /opt/nodered/node-v7.2.0/lib/node_modules/bin/node-red`  
You may want to specify ` --userDir /opt/node/.node-red`.
* Check running 'forever' processes:  
`/opt/nodered/node-v7.2.0/lib/node_modules/bin/forever list`
* Stop 'forever' process:
`/opt/nodered/node-v7.2.0/lib/node_modules/bin/forever stop /opt/nodered/node-v7.2.0/lib/node_modules/bin/node-red`  
You can use `'Id|Uid|Pid|Index|Script'` to stop the application. (For example UID can be check with 'list' option.)

######3.2. Add Extra Nodes To Node-Red
You can browse more than 1000 extra nodes and flows on the http://flows.nodered.org. 
For example: Install mysql node:
```
nodered@raspberrypi:~/.node-red$ npm install node-red-node-mysql
/opt/nodered/.node-red
â””â”€â”¬ node-red-node-mysql@0.0.11 
  â””â”€â”¬ mysql@2.11.1 
    â”œâ”€â”€ bignumber.js@2.3.0 
    â”œâ”€â”¬ readable-stream@1.1.14 
    â”‚ â”œâ”€â”€ core-util-is@1.0.2 
    â”‚ â”œâ”€â”€ inherits@2.0.3 
    â”‚ â”œâ”€â”€ isarray@0.0.1 
    â”‚ â””â”€â”€ string_decoder@0.10.31 
    â””â”€â”€ sqlstring@2.0.1 

npm WARN enoent ENOENT, open '/opt/nodered/.node-red/package.json'
npm WARN .node-red No description
npm WARN .node-red No repository field.
npm WARN .node-red No README data
npm WARN .node-red No license field.
```



==**REFERENCES:==**

[^1]: https://github.com/nodejs/node/blob/master/BUILDING.md
[^2]: http://flows.nodered.org/
[^3]: https://www.npmjs.com/package/forever
* https://github.com/node-red/node-red
* https://github.com/nodejs/node
* http://nodered.org/
* https://nodejs.org/


