!!! caution
    **This page has been updated a long time ago.**  Information found here could be outdated and may lead to missconfiguration.  
    Some of the links and references may be broken or lead to non existing pages.  
    Please use this docs carefully. Most of the information here now is only for reference or example!

    
# Create Self Singet Certificate

## Easyest Way
You can create Self Signed Certificate for you web server with just one command:

`openssl req -x509 -nodes -days 365 -newkey rsa:2048 -keyout mysitename.key -out mysitename.crt`


References:

* https://www.sslshopper.com/article-how-to-create-and-install-an-apache-self-signed-certificate.html
* https://httpd.apache.org/docs/2.4/ssl/ssl_faq.html

### With CSR (Certificate Signing Request) - DES3

Honestly there is no real difference between this and the previous method, if you use a self signed certificate. 
But if you create CSR you can send it to Certifying Authority (CA) to be signed.
And this method is useful when you want to use the same key with different certs.

* **Generate Private Key**  
`openssl genrsa -des3 -out example.key 2048`  
I recommend that create at lease 2048 bit key.  
``` bash
openssl genrsa -des3 -out example.key 1024
Generating RSA private key, 1024 bit long modulus
....++++++
............++++++
e is 65537 (0x10001)
Enter pass phrase for example.key:
Verifying - Enter pass phrase for example.key:
```
* **Generate a CSR**  
`openssl req -new -key example.key -out example.csr`
Output:
```
openssl req -new -key example.key -out example.csr
Enter pass phrase for example.key:
You are about to be asked to enter information that will be incorporated
into your certificate request.
What you are about to enter is what is called a Distinguished Name or a DN.
There are quite a few fields but you can leave some blank
For some fields there will be a default value,
If you enter '.', the field will be left blank.
-----
Country Name (2 letter code) [AU]:HU
State or Province Name (full name) [Some-State]:SomeState
Locality Name (eg, city) []:City
Organization Name (eg, company) [Internet Widgits Pty Ltd]:SomeState's Company
Organizational Unit Name (eg, section) []:Technology
Common Name (e.g. server FQDN or YOUR name) []:example.com
Email Address []:no-spam@realmail.com

Please enter the following 'extra' attributes
to be sent with your certificate request
A challenge password []:12345678
An optional company name []:
```
At this point you can send your CSR file to a CA, if you need a "real", trusted cert.

* **Remove Passphrase from Key**  
If you skip these steps apache will ask for the passphrase at each startup. 
`cp example.key example.key.org`  
`openssl rsa -in example.key.org -out example.key`

* **Generating Self-Signed Certificate**   
`openssl x509 -req -days 365 -in example.csr -signkey example.key -out example.crt`

Now you have some new files:
```
ls -lrt
total 12
-rw-r--r-- 1 janos.vincze bio 761 Aug 15 12:53 example.csr
-rw-r--r-- 1 janos.vincze bio 963 Aug 15 12:59 example.key.org
-rw-r--r-- 1 janos.vincze bio 887 Aug 15 12:59 example.key
-rw-r--r-- 1 janos.vincze bio 1001 Aug 15 13:03 example.crt

```
But you only need the `.key` and `.crt` file to configure apache.

### With root key CA
I don't know if there is anybody who wants to use a root CA key on its own webpage(s). I can imagine one scenario when it can be useful. Inside an organization you can create a root CA key and sign all your certificate with it, then import the CA to all clients.
For example, you have many web servers inside your intranet and sign all its certificate with your own CA. Clients inside your network can use these webpages as "trusted" provider if the root CA pub key is imported to the browser or to the system. I will show you how to install root CA cert into Firefox and Internet Explorer, but first we need to follow these steps to create the necessary files.

* **Generate ROOT CA**  
`openssl genrsa -des3 -out rootCA.key 2048`  
`openssl req -x509 -new -nodes -key rootCA.key -sha256 -days 1024 -out rootCA.pem -config rootCA.conf`  
As you can see we are using a configuration file: `rootCA.conf`  So you first need to create something like this:
```
[req]
distinguished_name = req_distinguished_name

[req_distinguished_name]
countryName = HU
countryName_default = HU
stateOrProvinceName = Budapest
stateOrProvinceName_default = Budapest
localityName = Budapest
localityName_default = Budapest
organizationalUnitName	= Technology
organizationalUnitName_default	= Technology
commonName = VinczeJanosRootCA
commonName_default = VinczeJanosRootCA
organizationName = Some Ltd
organizationName_default = Some Ltd.
E=jvincze84@gmail.com
commonName_max	= 64
```
* **Generate web server key(s)**  
`openssl genrsa -out server1.key 2048`  
You should generate one key per sites. 
* **Generate CSR for the key**  
This step is very similar to the previously mentioned.
  * Generate the CSR:  
`openssl req -sha256 -new -out server1.csr -key server1.key -config config.cnf`
  * Backup the original server key:  
`cp server1.key server1.key.org`
  * Remove the Passphrase  
`openssl rsa -in server1.key.org -out server1.key`  
You will use this key on the server.  
==**NOTE:**== You can see another config file: `config.cnf` This is necessary for the server key/crt. And please note that you can use `alt.names` in the configuration files. This is very useful if you have multiple domain names for one server or virtualhost. For example, you have two domain name: www.server.com and login.server.com. And these names are associated to one apache virtualhost: www.server.com -> ServerName and login.server.com -> ServerAlias.   
**Example Config File:**
```
[req]
distinguished_name = req_distinguished_name
req_extensions = v3_req

[req_distinguished_name]
countryName = HU
countryName_default = HU
stateOrProvinceName = Budapest
stateOrProvinceName_default = Budapest
localityName = Budapest
localityName_default = Budapest
organizationalUnitName	= Technology
organizationalUnitName_default	= Technology
commonName = server1.company.com
commonName_default = server1.company.com
organizationName = Company Ltd.
organizationName_default = Company Ltd.
E=boss@company.com
commonName_max	= 64

[ v3_req ]
# Extensions to add to a certificate request
subjectAltName = @alt_names

[alt_names]
DNS.1 = server1.company.com
DNS.2 = server2.company.com

```

* **Sign your csr with the root CA key**  
`openssl x509 -req -in server1.csr -CA rootCA.pem -CAkey rootCA.key -CAcreateserial -out server1.crt -days 3650 -extensions v3_req  -extfile config.cnf`  
This command will create the `server1.crt` which is to be used on Apache webserver.

Ok now we have the .key and .crt files. Check the cert:
`openssl x509 -in server1.crt -text -noout`

**Output:**
```
Certificate:
    Data:
        Version: 3 (0x2)
        Serial Number:
            87:8b:67:2d:2d:60:2c:48
    Signature Algorithm: sha256WithRSAEncryption
        Issuer: C=HU, ST=Budapest, L=Budapest, OU=Technology, CN=VinczeJanosRootCA, O=Some Ltd.
        Validity
            Not Before: Aug 16 09:59:59 2016 GMT
            Not After : Aug 14 09:59:59 2026 GMT
        Subject: C=HU, ST=Budapest, L=Budapest, OU=Technology, CN=server1.company.com, O=Company Ltd.
        Subject Public Key Info:
            Public Key Algorithm: rsaEncryption
                Public-Key: (2048 bit)
                Modulus:
                    00:9c:ed:ec:7d:b4:bf:4e:ff:3a:ab:ef:d5:a3:fd:
                    a1:a7:96:d0:30:c5:69:f7:a7:6c:91:ef:78:7f:03:
                    e9:48:f3:11:45:12:39:f6:4e:ed:79:60:df:f0:6b:
                    9a:59:16:7a:22:31:34:c7:10:df:a0:ca:c6:fb:6a:
                    ee:77:a3:6d:89:d2:b3:db:7f:f2:f9:d0:b5:5b:f2:
                    ed:0c:8e:03:85:5d:75:8a:de:29:dd:cd:d6:a8:7b:
                    8f:2c:5b:77:95:19:b9:da:42:d0:15:d5:c5:20:08:
                    61:83:2a:18:78:c9:1a:7c:55:df:25:ff:6a:69:53:
                    09:1a:22:a0:b6:98:63:09:ef:a9:3f:54:56:4d:78:
                    ea:2f:d7:cd:e8:58:8e:08:64:45:59:a5:c4:93:d7:
                    ac:b5:99:1d:5c:7a:3b:6b:85:c7:cb:33:8c:e4:b0:
                    bf:80:f1:cd:d7:68:70:dc:a0:ba:bd:fd:02:d3:36:
                    3d:11:c9:f9:71:c8:dd:2f:3f:b5:5d:8a:66:2e:34:
                    33:32:44:b3:49:78:5b:13:f9:8f:6f:42:d1:1f:f5:
                    bb:4d:6f:b1:81:42:c2:93:3c:f2:81:5d:1d:1d:19:
                    a4:40:e2:d1:2c:a5:2e:6d:fa:ad:ff:31:c3:65:58:
                    e3:ba:50:10:80:3e:53:86:ce:0e:43:df:cd:77:dd:
                    f9:f3
                Exponent: 65537 (0x10001)
        X509v3 extensions:
            X509v3 Subject Alternative Name:
                DNS:server1.company.com, DNS:server2.company.com
    Signature Algorithm: sha256WithRSAEncryption
         af:80:32:53:42:9c:8f:9e:4f:4b:e5:05:cc:41:5b:2f:c8:68:
         1d:eb:d8:8c:07:56:d3:ba:77:d4:f9:89:7e:ea:28:57:58:59:
         9e:df:bd:84:eb:2a:48:06:8e:44:c6:35:52:79:4e:c7:c7:0d:
         2d:4c:08:aa:5a:95:2a:10:65:7b:56:59:26:bb:fc:4e:5b:6c:
         73:08:18:d0:2b:59:a2:90:78:7c:2f:1d:d7:41:4e:87:59:71:
         78:87:59:8f:f9:67:33:ae:d6:77:f0:70:00:38:e5:e8:41:67:
         a1:b5:1d:33:ff:8a:89:97:99:cd:6c:b2:77:01:57:03:35:a5:
         25:0d:4b:19:dd:d3:ed:98:66:0a:c2:94:17:42:68:6f:2a:19:
         e1:cb:d3:2e:e7:e5:3a:8b:6e:3d:86:51:e9:29:56:9e:7e:b0:
         34:96:78:bf:60:8b:db:07:2a:3e:a3:2f:44:2a:70:8f:16:b2:
         c8:97:31:a0:ea:53:87:48:9d:6d:e3:20:33:c3:68:2a:40:37:
         06:cb:fe:4c:01:6f:a2:6a:f1:43:0f:ed:1c:84:4e:a7:4d:a7:
         7d:44:21:56:46:94:2f:75:6d:cf:be:1b:46:cd:5c:ef:e6:f6:
         6e:9a:53:b5:96:9a:a7:08:73:31:14:27:57:e3:66:63:cd:82:
         3a:f3:e0:3c
```

### Minimal Apache (1.4) configuration

Now we can create an apache self signed certificate with 3 different methods, but as result we have to have one `.crt` and one `.key` file.
This VirtualHost example redirects all http request to https, and works as a transparent proxy:
```apacheconf
<VirtualHost *:80>
        ServerName http://pve.server.com
        RewriteEngine On
        RewriteCond %{HTTPS} !=on
        RewriteRule ^/?(.*) https://%{SERVER_NAME}/$1 [R,L]
</VirtualHost>

<VirtualHost *:443>
  ServerAdmin webmaster@localhost
  SSLProxyEngine on
  SSLProxyCheckPeerCN off
  SSLProxyVerify none
  SSLProxyCheckPeerName off
  SSLProxyCheckPeerExpire off
  SSLProxyProtocol all

  DocumentRoot /var/www/html
  ServerName https://pve.server.com

  SSLEngine on

  SSLCertificateFile    /etc/apache2/cert/pve.crt
  SSLCertificateKeyFile /etc/apache2/cert/pve.key
  BrowserMatch "MSIE [17-9]" ssl-unclean-shutdown

        DocumentRoot /var/www
        <Directory />
                Options FollowSymLinks
                AllowOverride None
        </Directory>
        <Directory /var/www/>
                Options Indexes FollowSymLinks MultiViews Indexes
                AllowOverride all
                Order allow,deny
                allow from all
        </Directory>


        ErrorLog ${APACHE_LOG_DIR}/pve-error.log
        CustomLog ${APACHE_LOG_DIR}/pve-access.log combined

        ProxyRequests off
        ProxyPreserveHost on


        ProxyPass /   https://10.30.16.100:8006/
        ProxyPassReverse /   https://10.30.16.100:8006/

</VirtualHost>
```

### Import you root CA key to Firefox

If you don't want to get a "self Signed certificate" warning in FF you can import you root ca public key to Firefox with a few easy steps.

* Go to `about:preferences`, **Advanced**, **Certificate**.![](/content/images/2016/08/2016-08-16_122053.jpg) And Click **View Certificates**.
* In the pop-up window Choose **Authories**  and click "**import**"  ![](/content/images/2016/08/2016-08-16_122526.jpg)
* Import your `rootCA.pem` file. 
![](/content/images/2016/08/2016-08-16_122641.jpg)

Next time you visit your website FF will trust its certificate.







 





















