module("luci.controller.cloudflarespeedtest", package.seeall)

local fs = require "nixio.fs"

local LOG_FILE = "/var/log/cloudflarespeedtest.log"

local function is_running()
	return luci.sys.call("pidof cdnspeedtest >/dev/null 2>&1") == 0
end

function index()
	if not fs.access("/etc/config/cloudflarespeedtest") then
		return
	end

	local page
	page = entry({"admin", "services", "cloudflarespeedtest"}, firstchild(), _("Cloudflare Speed Test"), 99)
	page.dependent = false
	page.acl_depends = { "luci-app-cloudflarespeedtest" }

	entry({"admin", "services", "cloudflarespeedtest", "general"}, cbi("cloudflarespeedtest/cloudflarespeedtest"), _("Base Setting"), 1)
	entry({"admin", "services", "cloudflarespeedtest", "logread"}, form("cloudflarespeedtest/logread"), _("Logs"), 2)

	entry({"admin", "services", "cloudflarespeedtest", "status"}, call("act_status")).leaf = true
	entry({"admin", "services", "cloudflarespeedtest", "stop"}, call("act_stop")).leaf = true
	entry({"admin", "services", "cloudflarespeedtest", "start"}, call("act_start")).leaf = true
	entry({"admin", "services", "cloudflarespeedtest", "getlog"}, call("get_log")).leaf = true
end

function act_status()
	luci.http.prepare_content("application/json")
	luci.http.write_json({ running = is_running() })
end

function act_stop()
	luci.sys.call("pidof cdnspeedtest >/dev/null 2>&1 && kill -9 $(pidof cdnspeedtest) >/dev/null 2>&1")
	luci.http.prepare_content("application/json")
	luci.http.write_json({ running = is_running() })
end

function act_start()
	act_stop()
	luci.sys.call("/usr/bin/cloudflarespeedtest/cloudflarespeedtest.sh start >/dev/null 2>&1 &")
	luci.http.prepare_content("application/json")
	luci.http.write_json({ running = true })
end

function get_log()
	local pos = tonumber(luci.http.formvalue("pos")) or 0
	local content = ""
	local newpos = pos
	local size = fs.stat(LOG_FILE, "size") or 0

	if pos > size then
		pos = 0
	end

	if fs.access(LOG_FILE) then
		local fp = io.open(LOG_FILE, "r")
		if fp then
			fp:seek("set", pos)
			content = fp:read(131072) or ""
			newpos = fp:seek() or size
			fp:close()
		end
	end

	luci.http.prepare_content("application/json")
	luci.http.write_json({
		running = is_running(),
		pos = newpos,
		log = content
	})
end
