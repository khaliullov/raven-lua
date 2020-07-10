-- vim: st=4 sts=4 sw=4 et:
--- Network backend using [Tarantool http.client](https://www.tarantool.io/en/doc/2.2/reference/reference_lua/http/).
-- This module should be used when the Tarantool http.client library is available.
--
-- @module raven.senders.luasocket
-- @copyright 2014-2017 CloudFlare, Inc.
-- @license BSD 3-clause (see LICENSE file)

local util = require 'raven.util'
local http = require('http.client').new()

local pairs = pairs
local setmetatable = setmetatable
local parse_dsn = util.parse_dsn
local generate_auth_header = util.generate_auth_header
local _VERSION = util._VERSION
local _M = {}

local mt = {}
mt.__index = mt

function mt:send(json_str)
    local resp_buffer = {}
    local json = require('cjson')
    local opts = {
        headers = {
            ['Content-Type'] = 'applicaion/json',
            ['User-Agent'] = "raven-lua-tarantool/" .. _VERSION,
            ['X-Sentry-Auth'] = generate_auth_header(self),
        },
    }

    -- set master opts (if any)
    if self.opts then
        for h, v in pairs(self.opts) do
            opts[h] = v
        end
    end

    local response
    ok, code = pcall(function()
        response = http.request(http, 'POST', self.server, tostring(json_str), opts)
    end)
    if not ok then
        return nil, code
    end
    if response.status ~= 200 then
        return nil, response.body
    end
    return true
end

--- Configuration table for the nginx sender.
-- @field dsn DSN string
-- @field verify_ssl Whether or not the SSL certificate is checked (boolean,
--  defaults to false)
-- @field cafile Path to a CA bundle (see the `cafile` parameter in the
--  [newcontext](https://github.com/brunoos/luasec/wiki/LuaSec-0.6#ssl_newcontext)
--  docs)
-- @table sender_conf

--- Create a new sender object for the given DSN
-- @param conf Configuration table, see @{sender_conf}
-- @return A sender object
function _M.new(conf)
    local obj, err = parse_dsn(conf.dsn)
    if not obj then
        return nil, err
    end

    if obj.protocol == 'https' then
        obj.opts = {
            verify = conf.verify_ssl and 'peer' or 'none',
            cafile = conf.verify_ssl and conf.cafile or nil,
        }
    end

    return setmetatable(obj, mt)
end

return _M

