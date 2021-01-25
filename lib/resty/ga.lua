local _M = {}

local cjson = require 'cjson'
local http = require 'resty.http'
local table_isempty = require 'table.isempty'

local ga_cache = ngx.shared.ga_cache


local function send_hits(hits)
    local payloads = {}
    for _, hit in ipairs(hits) do
        local payload, err = ngx.encode_args(hit)
        if not payload then
            ngx.log(
                ngx.ERR,
                string.format('failed to ngx.encode_args hit: %s', err)
            )
        else
            table.insert(payloads, payload)
        end
    end
    if table_isempty(payloads) then
        return
    end

    local httpc = http.new()
    local api = 'http://www.google-analytics.com/batch'
    local option = {
        method = 'POST',
        body = table.concat(payloads, '\r\n'),
        keepalive_timeout = 60000,
        keepalive_pool = 10
    }
    local res, err = httpc:request_uri(api, option)
    if not res then
        ngx.log(ngx.ERR, string.format('failed to send ga request: %s', err))
    end
end


function _M.collect(tid, cid, uip)
    ngx.update_time()
    local now = ngx.now()

    local hit = {
        v = 1,
        t = 'pageview',
        tid = tid,
        cid = cid,
        uip = uip
    }

    hit['ua'] = ngx.var.http_user_agent
    hit['dr'] = ngx.var.http_referer
    hit['dh'] = ngx.var.host
    hit['dp'] = ngx.var.uri

    local res, err = ngx.re.match(ngx.var.uri, '^.*/([^/]{1,})$', 'jo')
    if res and res[1] then
        hit['dt'] = res[1]
    end

    if ngx.var.http_accept_language then
        local res, err = ngx.re.match(
            ngx.var.http_accept_language,
            '^([a-zA-Z]{2,3}(-[a-zA-Z]{2,3})?).*$',
            'jo')
        if res and res[1] then
            hit['ul'] = res[1]
        end
    end

    -- content length
    hit['cm1'] = ngx.header.content_length
    -- response time
    hit['cm2'] = math.floor((now - ngx.req.start_time()) * 1000 + 0.5)

    -- http status
    hit['cd1'] = ngx.status
    -- content type
    hit['cd2'] = ngx.header.content_type
    -- cache hit status
    hit['cd3'] = ngx.var.upstream_cache_status

    hit['created_at'] = now

    local encoded_hit, err = cjson.encode(hit)
    if not encoded_hit then
        ngx.log(ng.ERR, string.format('failed to encode hit: %s', err))
        return nil, 'failed to create encoded hit'
    end
    ga_cache:rpush(tid, encoded_hit)
end


function _M.send()
    while true do
        local tids = ga_cache:get_keys(0)
        if not tids then
            break
        end
        for _, tid in ipairs(tids) do
            local hits = {}
            local now = ngx.now()

            for i = 1, 20, 1 do
                local encoded_hit, err = ga_cache:lpop(tid)
                if encoded_hit then
                    local hit, err = cjson.decode(encoded_hit)
                    if hit then
                        hit['qt'] = math.floor(
                            (now - hit['created_at']) * 1000 + 0.5)
                        hit['created_at'] = nil
                        table.insert(hits, hit)
                    end
                end
            end

            if not table_isempty(hits) then
                send_hits(hits)
            end
        end
    end
end


return _M
