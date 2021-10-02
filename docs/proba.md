# Useful
```bash
echo "################ health ################"
curl "http://$(hostname -f):9200/_cat/health?v"

echo "################ Allocation ################"
curl "http://$(hostname -f):9200/_cat/allocation?v"

echo "################ indices ################"
curl "http://$(hostname -f):9200/_cat/indices?v"

echo "################ shards ################"
curl "http://$(hostname -f):9200/_cat/shards?v"

echo "################ nodes ################"
curl "http://$(hostname -f):9200/_cat/nodes?v"
```

# Template / Settings
## Change Settings of an index
```bash
curl -X PUT "localhost:9200/bitbucket-search/_settings?pretty" -H 'Content-Type: application/json' -d'
{
  "index" : {
    "number_of_replicas" : 0
  }
}
'
```

## Get Templates
`curl -s -X GET "http://itdevokdtstw1.vodafone.hu:30918/_index_template?pretty" | jq -r ".index_templates[].name"`

## Get One Template
### Command: 
`curl -s -X GET "http://itdevokdtstw1.vodafone.hu:30918/_index_template/logstash?pretty"`
### Output:
```json
{
  "index_templates" : [
    {
      "name" : "logstash",
      "index_template" : {
        "index_patterns" : [
          "logstash-*"
        ],
        "template" : {
          "settings" : {
            "index" : {
              "lifecycle" : {
                "name" : "logstash",
                "rollover_alias" : "logstash"
              },
              "number_of_shards" : "3",
              "number_of_replicas" : "0"
            }
          }
        },
        "composed_of" : [ ]
      }
    }
  ]
}
```

##  Create New & Check
### Command:
```
curl -X PUT "http://itdevokdtstw1.vodafone.hu:30918/_index_template/notused?pretty" -H 'Content-Type: application/json' -d'
```
### Response:
```json
{
        "index_patterns" : [
          "notused-*"
        ],
        "template" : {
          "settings" : {
            "index" : {
              "number_of_shards" : "3",
              "number_of_replicas" : "0"
            }
          }
        },
        "composed_of" : [ ]
      }
'
```

### Command:
```
curl -s -X GET "http://itdevokdtstw1.vodafone.hu:30918/_index_template/notused?pretty"
```

### Response:

```json
{
  "index_templates" : [
    {
      "name" : "notused",
      "index_template" : {
        "index_patterns" : [
          "notused-*"
        ],
        "template" : {
          "settings" : {
            "index" : {
              "number_of_shards" : "3",
              "number_of_replicas" : "0"
            }
          }
        },
        "composed_of" : [ ]
      }
    }
  ]
}
```







<body data-prismjs-copy-timeout="500">
	<pre><code class="language-js" data-prismjs-copy="Copy the JavaScript snippet!">console.log('Hello, world!');</code></pre>

	<pre><code class="language-c" data-prismjs-copy="Copy the C snippet!">int main() {
	return 0;
}</code></pre>
</body>
