jwt_header = os.getenv("JWT_HEADER")

local http = require "resty.http"

-- Bypass websocket with protocol, must with token
if ngx.req.get_headers()["Upgrade"] and ngx.req.get_headers()["Sec-WebSocket-Protocol"] then
    return
end


local auth_header = ngx.req.get_headers()["Authorization"]
local cookies = ngx.req.get_headers()["Cookie"]
local jwt = ngx.req.get_headers()[jwt_header]
local x_forwarded_for = ngx.req.get_headers()["X-Forwarded-For"]

local httpc = http.new()

-- Exchange cookie or token to plain jwt
local res, err = httpc:request_uri("http://user:8101/api/user/token", {
    method = "GET",
    headers = {
        ["Authorization"] = auth_header,
        ["Cookie"] = cookies,
        [jwt_header] = jwt,
        ["X-Forwarded-For"] = x_forwarded_for
    },
    query = {
        ["request_uri"] = ngx.var.request_uri
    }
})

if not res then
    ngx.log(ngx.ERR, "request error: ", err)
    return
end

if res.status ~= 200 then
    ngx.log(ngx.ERR, "request error: ", res.status, " ", res.body)
    ngx.status = res.status
    ngx.say(res.body)
    ngx.exit(res.status)
end

ngx.req.set_header(jwt_header, res.body)

-- Use subprotocol for websocket auth
if ngx.req.get_headers()["Upgrade"] then
    ngx.req.set_header("Sec-WebSocket-Protocol", "v1.token.websocket.example.com" .. "," .. jwt_header .. "." .. res.body)
end
