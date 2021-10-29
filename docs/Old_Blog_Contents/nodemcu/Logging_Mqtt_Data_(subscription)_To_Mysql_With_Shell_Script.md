!!! caution
    **This page has been updated a long time ago.**  Information found here could be outdated and may lead to missconfiguration.  
    Some of the links and references may be broken or lead to non existing pages.  
    Please use this docs carefully. Most of the information here now is only for reference or example!

    
# Logging MQTT data (subscription) to MySQL with Shell Script

I have a several ESPs which are continuously logging humidity and temperature values. I've decided to save all data to a Mysql database for later use or analysis. 
I found two different way to do this:

* OpenHAB persistence
* Shell script

Both have advantages and disadvantages as well, but you can use both at the same time, and after a while you can choose he best for you.
Or you can use [NodeRed ](https://nodered.org/) to logging data to DB if you don't like my solutions.


##0. My Data Model

All of my ESPs are sending data to a mqtt broker (mosquitto) using this topic format: `"NodeMCU/[NODEID]/status/[MEASSURE]"` and the data (value).

Here is an example about what kind of messages are sent by one of my ESP:

```
NodeMCU/585548/status/nodeid 585548
NodeMCU/585548/status/contacts/5 0
NodeMCU/585548/status/humidity 58
NodeMCU/585548/status/sta_macaddr 60:01:94:08:ef:4c
NodeMCU/585548/status/contacts/1 0
NodeMCU/585548/status/temperature -1.5
NodeMCU/585548/status/ap_macaddr 62:01:94:08:ef:4c
NodeMCU/585548/status/reboot 168457
NodeMCU/585548/status/uptime 1485351907
NodeMCU/585548/status/heap 19376
NodeMCU/585548/status/ipaddr 172.31.0.168
NodeMCU/585548/status/epoch 1485520364
NodeMCU/585548/status/rssi -57
NodeMCU/585548/status/voltage 3.531
NodeMCU/585548/status/publicip 46.1*7.*3.15*
```

**How do I collect the data?**
```lua
    function module.collectData()
        -- GENERAL STATUS UPDATE
        local table_status = {
            ["nodeid"] =  node.chipid(),
            ["sta_macaddr"] = wifi.sta.getmac(),
            ["ap_macaddr"] = wifi.ap.getmac(),
            ["ipaddr"] = wifi.sta.getip(),
            ["rssi"] = wifi.sta.getrssi(),
            ["epoch"] = rtctime.get(),
            ["reboot"] = tmr.time(),
            ["uptime"] =  rtctime.get() - tmr.time(),
            ["publicip"] = ipaddr,
            ["heap"] = node.heap(),
            ["voltage"] = adc.readvdd33(0)/1000, 
        } 
        
        -- ############# (optional) - DHT
        local status, temperature, humidity, temp_dec, humi_dec = dht.read(config.dhtPins)
        table_status["temperature"]=temperature
        table_status["humidity"]=humidity
        return table_status
     end -- End of collectData 
```

**How do I publish these data?**
```lua
    function module.publishData(mqtt,toPublishTable)
      -- PUBLISH DATA
      for st,va in pairs(toPublishTable) 
      do 
          m:publish(config.mqtt.publishTopicStatus..st,va,0,1) 
      end 
    end
```
I call this function (publishData()) by using a [timer ](https://nodemcu.readthedocs.io/en/master/en/modules/tmr/) in every 60 secs.


## 1. OpenHAB persistence

OpenHAB supports saving data to MySQL database by setting up the mysql persistence.

###1.1. Turn on MySQL persistance

* Unzip `org.openhab.persistence.mysql-1.8.3.jar` to your addons directory. In my case: `/opt/openhab/runtime/distribution-1.8.3-runtime/addons`  
You can download all addons from the OpenHAB official web page: 
[OpenHAB downloads](http://www.openhab.org/downloads.html)

* Edit `openhab.cfg` file. Set the following properties:

```cfg
persistence:default=mysql
mysql:url=jdbc:mysql://172.18.0.105:3306/openhab
mysql:user=openhab
mysql:password=openhab
mysql:localtime=true
```
OpenHAB will create all necessary table.

###1.2. Configuration

Create configuration file for MySQL persistence: `configurations/persistence/mysql.persist`

**Example:**
```
Strategies {
        default = everyChange
}
Items {
        Temperatures* -> "Temperatures"
        Humidities* -> "Humidities"
        prd_batt_349307_voltage -> "Battery Voltage"
}
```

For the better understand here is my Temperatures and Humidities group config and "prd_batt_349307_voltage" configuration:

**Temperature:**  
`Number  prd_347920_temp              "Shaft Temperature [%.1f Ã‚Â°C]"     <temperature>   (GroupShed,Temperatures) {mqtt="<[banana:NodeMCU/347920/status/temperature:state:default"], autoupdate="true" }`

**Humidity:**  
`Number  prd_347920_humi              "Shaft Humidity [%.1f %%]"        <humi>          (GroupShed,Humidities)   {mqtt="<[banana:NodeMCU/347920/status/humidity:state:default"], autoupdate="true" }`

**prd_batt_349307_voltage:**  
This is a battery powered DHT22 sensor with ESP01.
`Number  prd_batt_349307_voltage           "Batt Voltage: [%.1f mV]"        <info>              (BattDHT_1)              {mqtt="<[banana:NodeMCU/349307/status/voltage:state:default"], autoupdate="true" }`  

OpenHAB will log all temperature and humidity values to the MySQL database when the value has changed.

###1.3. The Database and Tables

OpenHAB creates a table for all logged items, and there is another table which contains the ID and the name of the items:

```
mysql -h 172.18.0.105 -u openhab -popenhab -s -N -e  "show tables;" openhab
Item1
Item2
Item3
...
...
Items
```
**Items table:**
```
mysql -h 172.18.0.105 -u openhab -popenhab -s -N -e  "select * from Items;" openhab
1       prd_81425_humi
2       prd_80100_humi
3       test_384849_humi
4       prd_batt_349307_temp
...
...
...
```

For example the values of

* `prd_batt_349307_temp` can be queried from the Item4 table.
* `test_384849_humi` can be found in the Item3 table.

You can query the minimum temperature since 2017.01.25:
```
mysql -h 172.18.0.105 -u openhab -popenhab  -e  "select min(value) from Item4 where Time >= '2017-01-25';" openhab
+------------+
| min(value) |
+------------+
|       18.1 |
+------------+
```

### 1.4. Remove incorrect data from the database

Unfortunately sometimes the temperature and humidity values are incorrect. This means a very low or very high values (>100 ; <-100), so I remove these entries from the database with a simple shell script which runs on every hour from crontab:

```bash
#!/bin/bash
IFS='
'

LOG="/opt/openhab/custom_scripts/clean_logs/logfile.log"

exec >> $LOG 2>&1

echo "#################### $( date +%F\ %T ) ####################"
for TABLE in $( mysql -h 172.18.0.105 -u openhab -popenhab -s -N -e  'show tables;' openhab | grep -v Items )
do
  ITEMID=$( echo $TABLE  | sed 's#[^0-9]##g' )
  ITEM_NAME=$( mysql -h 172.18.0.105 -u openhab -popenhab -s -N -e  "select ItemName from Items where ItemId=$ITEMID;" openhab )
  echo "---------------- $TABLE"
  echo "Item: $ITEM_NAME"
  echo "$ITEM_NAME" | egrep -q '(temp|humi)'
  TO_CLEAN=$?

  if [ $TO_CLEAN -eq 0 ]
  then
    mysql -h 172.18.0.105 -u openhab -popenhab -s -N -e  "select * from $TABLE where abs(Value)  > 100 ;" openhab
    mysql -h 172.18.0.105 -u openhab -popenhab -s -N -e  "delete from $TABLE where abs(Value)  > 100 ;" openhab
  else
    echo "NO Humi or temp"
  fi
  echo
done
```


OpenHAB persistence can work with all bindings, not only for MQTT. So if you are already using OpneHAB this method maybe the most suitable for you.

## 2. Shell (bash) Script

My another solution to log mqtt data to MySQL data is writing a simple shell script which subscribe to one or more topics, and INSERT data to the DB right after the message is received from the MQTT broker.

###2.1. Create The Database

Unfortunately nobody will create the database and tables for you, so you have to do this on your own. You are lucky because I share mine with you.

**Create database**
```sql
CREATE DATABASE IF NOT EXISTS `nodemcu` DEFAULT CHARACTER SET latin1 COLLATE latin1_swedish_ci;
-- Optional:
USE `nodemcu`;
```

**Create table**
```SQL
DROP TABLE IF EXISTS `esps`;
CREATE TABLE IF NOT EXISTS `esps` (
`_id` int(11) NOT NULL,
  `timestamp` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `nodeid` int(11) NOT NULL,
  `measure` text NOT NULL,
  `value` float NOT NULL,
  `comment` text NOT NULL
) ENGINE=InnoDB AUTO_INCREMENT=49334 DEFAULT CHARSET=latin1;
```

**Add indexes:**
```sql
ALTER TABLE `esps`
 ADD PRIMARY KEY (`_id`), ADD KEY `nodeid` (`nodeid`), ADD KEY `value` (`value`);
```

**Create user and GRANT accees:**
```sql
CREATE USER 'nodemcu'@'%' IDENTIFIED BY 'nodemcu';

GRANT USAGE ON *.* TO 'nodemcu'@'%' IDENTIFIED BY 'nodemcu' 
  WITH MAX_QUERIES_PER_HOUR 0 MAX_CONNECTIONS_PER_HOUR 0 
  MAX_UPDATES_PER_HOUR 0 MAX_USER_CONNECTIONS 0;
```

###2.2. Shell Script

```bash
#!/bin/bash
IFS='
'

mosquitto_sub -R -v -h 172.16.0.250 -u vinyo -P *****  -t 'NodeMCU/+/status/temperature'  -t 'NodeMCU/+/status/humidity' -t 'NodeMCU/+/status/voltage' | while read RAW_DATA
do
NODEID=$( echo $RAW_DATA | cut -f 2 -d"/" )
MEASURE=$( echo $RAW_DATA | cut -f 4 -d"/" | cut -f1 -d" " )
VALUE=$( echo $RAW_DATA | cut -f 2 -d" " )

LAST_VALUE=$( mysql -h 172.18.0.105 -u nodemcu -pnodemcu -N -s -e "select value from esps where nodeid='$NODEID' and measure='$MEASURE' order by _id DESC LIMIT 1;" nodemcu )

[ -z $LAST_VALUE ] && LAST_VALUE=0

if [ $LAST_VALUE != $VALUE ]
then
echo "INSERT (NodeId: $NODEID; MEASURE: $MEASURE ( $LAST_VALUE --> $VALUE )"
mysql -h 172.18.0.105 -u nodemcu -pnodemcu -e "insert into esps(nodeid,measure,value) VALUES('$NODEID','$MEASURE','$VALUE');" nodemcu
else
echo "Not Changed: (NodeId: $NODEID; MEASURE: $MEASURE ( $LAST_VALUE --> $VALUE )"
fi

done
```

**Explanation:**  

* The script inserts data only when it differs from the previous value ($LAST_VALUE).  
It is important because ESPs send messages very frequently, and without this the db would grow fast.
* At the first start (when there is no data in the db) 0 will be used as the `$LAST_VALUE`.  
`[ -z $LAST_VALUE ] && LAST_VALUE=0`  
Without this, at the first start the "if" statement would run into an error.
* It logs "only" the temperature, humidity and voltage values by subscripting these topics:  
 `mosquitto_sub -R -v -h 172.16.0.250 -u v*n*y*a -P *****  -t 'NodeMCU/+/status/temperature'  -t 'NodeMCU/+/status/humidity' -t 'NodeMCU/+/status/voltage'`
* This scripts log to the standard output. Of course you can redirect all output to a log file by putting the following line to script (before the mosquitto_sub command).  
`exec >> /path/of/the/log/file 2>&1`


**How to run in the background?**  
Simply use the well-known method: nohup + command + $ 
`nohup ./script-name-sh &`





















