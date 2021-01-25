# lua-resty-ga

Send nginx/openresty access log to Google Analytics.

# Status

This library is used in [PoweredBy.Cloud](https://poweredby.cloud), 
but you should test it in your system before onboarding.

# Requires

ledgetech/lua-resty-http >= 0.14

# Install

```
luarocks install lua-resty-ga
```

or

```
opm get BeanYoung/lua-resty-ga
```


# Usage

```
# ga.conf

resolver 8.8.8.8 223.5.5.5 valid=3600s ipv6=off;

lua_ssl_trusted_certificate /etc/ssl/certs/ca-certificates.crt;

lua_shared_dict ga_cache 128m;

init_by_lua_block {
    local process = require 'ngx.process'
    process.enable_privileged_agent()
}

init_worker_by_lua_block {
    local process = require 'ngx.process'
    local ga = require 'resty.ga'

    if process.type() == 'privileged agent' then
        ngx.timer.every(1, ga.send)
    end
}

server {
    listen 0.0.0.0:80;
    location / {
        content_by_lua_block {
            ngx.say('ok')
        }

        log_by_lua_block {
            local ga = require 'resty.ga'

            -- Follow this link to create your tid.
            -- https://support.google.com/analytics/answer/10269537
            local tid = 'UA-188032216-1'

            -- Get cid from cookie or somewhere else based on your implementation
            local cid = 'user_id_0'

            local uip = ngx.var.remote_addr
            -- if your nginx is behind cloudflare
            local headers = ngx.req.get_headers()
            if headers['CF-Connecting-IP'] then
                uip = headers['CF-Connecting-IP']
            end

            ga.collect(tid, cid, uip)

            -- Follow this link to create custom dimensions and custom metrics.
            -- https://support.google.com/analytics/answer/2709829?hl=en
            -- Then you can send custom dimensions and custom metrics like this.
            --ga.collect(tid, cid, uip, true)
        }
    }
}
```

# Methods

## collect

`syntax: ga.collect(tid, cid, uip, send_cd_and_cm)`

Collect current request's log and push to cache.
It's better to call this method during log phase[`log_by_lua_*`](https://github.com/openresty/lua-nginx-module#log_by_lua).

`tid` is your google analytics tracking id. 
Please be aware that this is a Universal Analytics property rather than a Google Analytics 4 property. 
Follow this [link](https://support.google.com/analytics/answer/10269537) to create a tracking id.

`cid` is google analytics [client id](https://developers.google.com/analytics/devguides/collection/protocol/v1/parameters#cid). 

`uip` is google analytics [client ip address](https://developers.google.com/analytics/devguides/collection/protocol/v1/parameters#uip).

`send_cd_and_cm` is used to deside whether to send custom dimensions and custom metrics to google analytics.
Custom dimensions and custom metrics must be created in google analytics's admin dashboard before setting this parameter to `true`.
Also custom dimensions and custom metrics must be created in the following order:

| Custom Dimensions | Index | Scope |
|-------------------|-------|-------|
|       Status Code |     1 |   HIT |
|      Content Type |     2 |   HIT |
|      Cache Status |     3 |   HIT |

| Custom Metrics | Index | Scope | Format Type |
|----------------|-------|-------|-------------|
| Content Length |     1 |   HIT |     Integer |
|  Response Time |     2 |   HIT |     Integer |


## send

`syntax: ga.send(premature)`

Pop all request logs and send to google analytics server.
It's better to use timer to call this method in [privileged agent](https://github.com/openresty/lua-resty-core/blob/master/lib/ngx/process.md#enable_privileged_agent) every 1s.

# Author

Bingyu Chen [BeanYoung](mailto:beanyoungcn@gmail.com).
