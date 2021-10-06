# How I Built This Site?

## TL;DR

As wrote on the index page, I changed from Ghos Blog to MKDocs. This was necessary because my Ghost version was really outdated and I could not get used to its new editor.  
I have some essential requirement against the platform I use:

* Should be easy to use with native MarkDown support
* Should not have billions of features I won't use ever (to avoid unnecessary system load)
* Must have integrated very good search engine
* Look-And-Feel must be easily customised without plugins or addons
* Since I post a lot of code bloks, code highlighting is must. It should be achieved natively or using prism.js
* Source code of the contens (*.md) shold be stored in a Git repository.

### What was the alternatives?

* CMS Systems
  * Drupal, WordPress, Joomla : All of these are CMS systems, and too robust for my purpose. I needed a light-weight system.
* Static Site Generators and 
  * Jekyll, Gatsby.js, Scully, MKDocs, etc. : They are way more closer to my expectations. 

And how I chose up MKDocs over the rest? My selection process was really simple. I gave a try all of them, this means I spent 2 hours to try each of them. The winner was with which I could get closer to my expectations in 2 hours. And of course which was closer to my taste in coding, manageability and flexibility.

Now It seems MKDocs does exactly what I need. Probably most of the other static website gernerator would have been perfect for me, but after 2 hours of using I found it rellay comfortable for me. And I did not regret my choice. All of my old contents are migrated to this site, and meantime I did some customisation on the the theme and the site. And this is the main topic of this post: How I migrated the content and how I use MKDocs?

## Prepare MKDocs Docker Image

If you blinks at the official MKDocs installtion page you can see that the installation should be done by run `python pip install` command.  
I don't like to install various python packages on my computer, because sooner or later I'm going to stuck in failed requirements. So at the first step I had to make decision what to use: python virtualenv or Docker. Of course I chose Docker.

I do know that "Material for MkDocs" have official Docker image, but I like to use Docker images was built by my own. Every time I build a new Docker image from scratch I learn something or make my knowledge deeper about Dockerfiles, so it's absolutely worth it.

### Dockerfile & Build
<pre class="line-numbers language-docker" data-src="/files/Dockerfile"></pre>

* `FROM python:3-alpine` --> Using the official python image.
* `ARG USER=1001` --> Default user id. If you don't specify another when building the container (see below)
* `ENTRYPOINT` --> The default command to run when the container starts.


**Build command**
```bash
docker build -t exmaple-mkdocs:v1 --build-arg=USER=$(id -u) .
```

!!! important
    Docker container will be built using your local user id. This will help you to avoid permission deined when mounting local directory inside the container. 


### Usage Examples

* Get help
```bash
docker run -it exmaple-mkdocs:v1 --help
```

* Create New Site
```bash
mkdir /tmp/example/
docker run -it -v /tmp/example:/build exmaple-mkdocs:v1 new /build
```

This command will create the following initial files (inside the `/tmp/example` directory on you local system:
```plain
.
./docs
./docs/index.md
./mkdocs.yml
```

!!! info
    With  `-v` parameter you can mount one of your local directory inside the container (bind mount). So the running process iside the container will see your local direcotry `/tmp/example` as `bild`. (`-v /HOST-DIR:/CONTAINER-DIR`). If 'HOST-DIR' is omitted, Docker automatically creates the new volume on the host (default location: `/var/lib/docker/volumes`).


* Get into the container
```bash
docker run -it --entrypoint=/bin/bash exmaple-mkdocs:v1

```

* Run the builtin development server
```bash
docker run -it -p 8789:8000 \
-v /tmp/example:/build exmaple-mkdocs:v1 \
serve --dev-addr 0.0.0.0:8000 --config-file /build/mkdocs.yml
```

This command may need some explanation:

* `docker run -it` --> Run the container in interacrive mode and allocate a pseudo-tty.
* `-p 8789:8000` --> Publish container port **8000** on the host port **8789**. This means process binding the port 8000 inside the container will be published on the local port 8789.
* `serve --dev-addr 0.0.0.0:8000 --config-file /build/mkdocs.yml` --> Arguments of the `mkdocs` command. (ENTRYPOINT)
  - The bind port (8000) must be the same as specified at `-p` parameter.
  - Since we bind mounted the `/tmp/example` local directory into the container's `/build` we can acces mkdocs.yml inside the container as `/build/mkdocs.yml`


Now you can access your newly created site at http://localhost:8789 or http://[your machine ip address]:8789.  
Every modification inside the `/tmp/example` directory immediately take effetcs, so you don't need to restart the container, your browser will refresh the page automatically. But be aware that if you make systax error in the `mkdocs.yml` the container will exit and you need to manually retart it.

## Configure

### mkdocs.yml

Configuring your MKDocs intstance basically means editing `mkdocs.yml`.

You can see my current configuration below:
<pre class="line-numbers language-yaml" data-src="/files/mkdocs.yml"></pre>

I think there is nothing special in this configuration, but could be a good example. Every part of this file is very well documented on the officail Material and MKDocs website:

* [https://www.mkdocs.org/user-guide/](https://www.mkdocs.org/user-guide/)
* [https://squidfunk.github.io/mkdocs-material/](https://squidfunk.github.io/mkdocs-material/)

!!! info
    All the items in the `nav` section is relative to the `docs` directory. Example: `old/Iptables_Examples.md` is located at `/tmp/example/docs/old/Iptables_Examples.md`


I think the only thing to metion is my `extra.css` file.

### `extra.css`

```css
.md-grid {
max-width: initial;
}
 
pre[class*="language-"] {
       max-height: 32em !important; 
}

.md-clipboard {
  display: none !important;
}

.md-typeset pre>code {
   overflow: unset !important;
   padding: unset !important;
}
```

I know using `!important` is not the best things to do, but I'm not a web developer and I needed a 'quick and dirty solution'. Maybe later, if I have more time I will customise the mkdocs theme and leave `!important`.

??? info
    More about `!important`: [https://stackoverflow.com/questions/9245353/what-does-important-mean-in-css](https://stackoverflow.com/questions/9245353/what-does-important-mean-in-css). "Using !important has its purposes (though I struggle to think of them), but it's much like using a nuclear explosion to stop the foxes killing your chickens; yes, the foxes will be killed, but so will the chickens. And the neighbourhood."

* **md-grid (Material Theme)**

Reference: [Content area width](https://squidfunk.github.io/mkdocs-material/setup/setting-up-navigation/?h=width#content-area-width)

> The width of the content area is set so the length of each line doesn't exceed 80-100 characters, depending on the width of the characters. While this is a reasonable default, as longer lines tend to be harder to read, it may be desirable to increase the overall width of the content area, or even make it stretch to the entire available space.
> This can easily be achieved with an additional stylesheet and a few lines of CSS:  
> .md-grid {  
>  max-width: initial;  
>  }

* **pre[class*="language-"] (prismjs)**

Add vertical scroll bar when code block cointans more than 32 lines.

* **md-clipboard (Material Theme)**

This section disables the theme built in "copy to clipoad" funcion, it's neccessary if you wish to use the prismjs "copy to clipboard" method.

* **md-typeset pre>code (Material Theme)**

Some functions of prismj won't work properly without this modification, for example line numbering.

Example: 
```html
<pre class="line-numbers language-docker" data-src="/files/Dockerfile"></pre>
```
**Screenshot:**

![MissingNumbering](assets/images/Screenshot_2021-10-06_08-20-14.png)

You can see that the line number from the left hand side of the lines are missing.

## Build the site

If you are done writing your docs, and `nav` section is properly configured in `mkdocs.yml` it's time to build your site. I will show three methods to publis the site.

!!! important
    `mkdocs serve` is absolutely not suitable for production. It's only purpose to help you developing the site, and watch realtime your modification.

### Build Site & Own Web Server
### Build Site & Nginx with Docer
### GitHub Pages






















