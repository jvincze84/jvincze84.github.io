!!! caution
    **This page has been updated a long time ago.**  Information found here could be outdated and may lead to missconfiguration.  
    Some of the links and references may be broken or lead to non existing pages.  
    Please use this docs carefully. Most of the information here now is only for reference or example!
    
# Install mps-youtube console based youtube player

Why do I need console based youtube player? The answer is very simple. When I'm working in my Workshop I want to listen music from youtube. OK. I know that there are uncountable way to listen music online. 
I have some old desktop PC which  have very limited resources, and can't able to play youtube clip in browser. This old PC is connected to an as old HIFI system as the PC itself. 
So I needed a lightweight youtube player which can be run on an old PC. After some gooleing I found mps-youtube. 
It is very simple to install and use it. I love it.  :) This is exactly what I wanted.

Here is the steps to install mps-youtube:
**Install python pip3:**  
`apt-get install python3-pip`

**Install dependencies:**  
`apt-get install mplayer2 mpv`

**Install mps-youtube:**  
`pip3 install mps-youtube`

**Install youtube-dl:**  
`pip3 install youtube_dl`

**Set player to mpv**  
Run `mpsyt`
Type: `set player /usr/bin/mpv`

==Reference:==

* [https://github.com/mps-youtube/mps-youtube](https://github.com/mps-youtube/mps-youtube)

**Bonus:** Some youdube-dl example.

* Download youtube video in MP3 format:

```bash
youtube-dl --restrict-filenames --no-mtime --extract-audio --audio-format mp3 --audio-quality 0 -o /path/to/dir/%\(title\)s.%\(ext\)s [LINK]
```

Where:
  * `--restrict-filenames` Restrict filenames to only ASCII characters, and avoid "&" and spaces in filenames
  * `--no-mtime` Do not use the Last-modified header to set the file modification time
  * `-x, --extract-audio` Convert video files to audio-only files (requires ffmpeg or avconv and ffprobe or avprobe)
  * `--audio-format mp3` Save output as MP3.
  * `audio-quality` Specify ffmpeg/avconv audio quality, insert a value between 0 (better) and 9 (worse) for VBR or a specific bitrate like 128K (default 5)
  * `-o /path/to/dir/%\(title\)s.%\(ext\)s` Output directory and file pattern.

* Download Video File

Simply run `youtube-dl [LINK]`, this will save the video in mp4 format.

* Process URLs from file:  

`youtube-dl --batch-file list.txt` 








