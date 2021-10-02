# Diff Files

### Proba

```diff hl_lines="2 3"
Only in ghost-current/content/themes/casper/assets/built: prism.css
Only in ghost-current/content/themes/casper/assets/built: prism.css.map
Only in ghost-current/content/themes/casper/assets/css: prism.css
diff -u -r ghost-compare/content/themes/casper/assets/css/screen.css ghost-current/content/themes/casper/assets/css/screen.css
--- ghost-compare/content/themes/casper/assets/css/screen.css	2017-12-07 13:30:00.000000000 +0100
+++ ghost-current/content/themes/casper/assets/css/screen.css	2017-12-12 14:08:19.307838832 +0100
@@ -71,7 +71,7 @@
 /* Centered content container blocks */
 .inner {
     margin: 0 auto;
-    max-width: 1040px;
+    max-width: none;
     width: 100%;
 }
 
@@ -670,7 +670,7 @@
     display: flex;
     flex-direction: column;
     align-items: center;
-    max-width: 920px;
+    max-width: none;
 }
 
 .post-full-content h1,
Only in ghost-current/content/themes/casper/assets: ghostHunter
Only in ghost-current/content/themes/casper/assets/js: jquery.ghostHunter.js
Only in ghost-current/content/themes/casper/assets/js: jquery.ghostHunter.min.js
Only in ghost-current/content/themes/casper/assets/js: jquery.ghostHunter-nodependency.js
Only in ghost-current/content/themes/casper/assets/js: jquery.ghostHunter-nodependency.min.js
Only in ghost-current/content/themes/casper/assets/js: lunr.js
Only in ghost-current/content/themes/casper/assets/js: lunr.min.js
Only in ghost-current/content/themes/casper/assets/js: prism.js
diff -u -r ghost-compare/content/themes/casper/default.hbs ghost-current/content/themes/casper/default.hbs
--- ghost-compare/content/themes/casper/default.hbs	2017-12-07 13:30:00.000000000 +0100
+++ ghost-current/content/themes/casper/default.hbs	2017-12-12 12:46:55.127683665 +0100
@@ -13,6 +13,11 @@
 
     {{!-- Styles'n'Scripts --}}
     <link rel="stylesheet" type="text/css" href="{{asset "built/screen.css"}}" />
+    <script src="{{asset "js/prism.js"}}"></script>
+    <script src="{{asset "js/jquery.ghostHunter.min.js"}}"></script>
+    <script src="{{asset "js/lunr.js"}}"></script>
+
+    <link rel="stylesheet" type="text/css" href="{{asset "css/prism.css"}}" />
 
     {{!-- This tag outputs SEO meta+structured data and other important settings --}}
     {{ghost_head}}
Only in ghost-current/content/themes/casper/: node_modules
diff -u -r ghost-compare/content/themes/casper/partials/floating-header.hbs ghost-current/content/themes/casper/partials/floating-header.hbs
--- ghost-compare/content/themes/casper/partials/floating-header.hbs	2017-12-07 13:30:00.000000000 +0100
+++ ghost-current/content/themes/casper/partials/floating-header.hbs	2017-12-12 12:37:05.767664941 +0100
@@ -9,17 +9,6 @@
     </div>
     <span class="floating-header-divider">&mdash;</span>
     <div class="floating-header-title">{{title}}</div>
-    <div class="floating-header-share">
-        <div class="floating-header-share-label">Share this {{> "icons/point"}}</div>
-        <a class="floating-header-share-tw" href="https://twitter.com/share?text={{encode title}}&amp;url={{url absolute="true"}}"
-            onclick="window.open(this.href, 'share-twitter', 'width=550,height=235');return false;">
-            {{> "icons/twitter"}}
-        </a>
-        <a class="floating-header-share-fb" href="https://www.facebook.com/sharer/sharer.php?u={{url absolute="true"}}"
-            onclick="window.open(this.href, 'share-facebook','width=580,height=296');return false;">
-            {{> "icons/facebook"}}
-        </a>
-    </div>
     <progress class="progress" value="0">
         <div class="progress-container">
             <span class="progress-bar"></span>
Only in ghost-current/content/themes/casper/partials: floating-header.hbs-bck
```

---

## New Search page

### Ketto

```html
<!DOCTYPE html>
<!--[if lt IE 7]>      <html class="no-js lt-ie9 lt-ie8 lt-ie7"> <![endif]-->
<!--[if IE 7]>         <html class="no-js lt-ie9 lt-ie8"> <![endif]-->
<!--[if IE 8]>         <html class="no-js lt-ie9"> <![endif]-->
<!--[if gt IE 8]><!--> <html class="no-js"> <!--<![endif]-->
<head>

<meta charset="utf-8">
<meta http-equiv="X-UA-Compatible" content="IE=edge,chrome=1">
<title>ghostHunter</title>
<meta name="description" content="">
<meta name="viewport" content="width=device-width">

</head>
<body>

<form>
<input id="search-field" />
<input type="submit" value="search">
<input type="button" value="clear" onclick="clearResults();" />
</form>

<hr />

<section id="results"></section>

<script src="//ajax.googleapis.com/ajax/libs/jquery/1.10.1/jquery.min.js"></script>
<script src="../assets/js/jquery.ghostHunter.js"></script>

<script>

var searchField = $("#search-field").ghostHunter({
results     : "#results",
rss         : "rss.xml",
//Enable the "search as you type" by uncommenting the following line
//onKeyUp   : true,
result_template: "<a href='{{link}}'><p><h2>{{title}}</h2><h4>{{pubDate}}</h4>{{description}}</p></a>"

});

function clearResults() {
searchField.clear();
}

</script>

</body>
</html>
```

---

## Compile CSS (Gulp)

### Screen
![](/content/images/2017/12/2017-12-12_144510.jpg)

### Build

Itt kell kiadni a parancsokat: `... /ghost-current/content/themes/casper`
Ez a theme root dir.

```bash
npm install
gulp
```

## Egy
fdsfds

### Ketto
fsdf

### Ketto
dfsdf

#### Harom
fsdfsd

#### harom
sfsdfsf

### ketto
fsdfs

### egy
fsdf





