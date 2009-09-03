--------------------------------
-- Author: Gregor Best        --
-- Copyright 2009 Gregor Best --
--------------------------------

local setmetatable = setmetatable
local tonumber = tonumber
local pairs = pairs
local io = {
    popen = io.popen
}
local string = {
    match  = string.match,
    find   = string.find,
    format = string.format
}
local capi = {
    widget = widget,
}
local awful = require("awful")
local lib = require("obvious.lib")

module("obvious.volume_alsa")

local defaults = {}
defaults.term = "x-terminal-emulator -T Mixer"

local settings = {}
for key, value in pairs(defaults) do
    settings[key] = value
end

function set_term(t)
    settings.term = e or defaults.term
end

function get_data(cardid, channel)
    local rv = { }
    local fd = io.popen("amixer -c " .. cardid .. " -- sget " .. channel)
    if not fd then return end
    local status = fd:read("*all")
    fd:close()

    rv.volume = tonumber(string.match(status, "(%d?%d?%d)%%"))
    if not rv.volume then return end

    status = string.match(status, "%[(o[^%]]*)%]")
    if string.find(status, "on", 1, true) then
        rv.mute = false
    else
        rv.mute = true
    end

    return rv
end

local function update(obj)
    local status = get_data(obj.cardid, obj.channel) or { mute = true, volume = 0 }

    local color = "#900000"
    if not status.mute then
        color = "#009000"
    end
    obj.widget.text = lib.markup.fg.color(color, "☊") .. string.format(" %03d%%", status.volume)
end

function raise(cardid, channel, v)
    v = v or 1
    awful.util.spawn("amixer -q -c " .. cardid .. " sset " .. channel .. " " .. v .. "+", false)
end

function lower(cardid, channel, v)
    v = v or 1
    awful.util.spawn("amixer -q -c " .. cardid .. " sset " .. channel .. " " .. v .. "-", false)
end

function mute(cardid, channel)
    awful.util.spawn("amixer -c " .. cardid .. " sset " .. channel .. " toggle > /dev/null", false)
end

function mixer(cardid)
    awful.util.spawn(settings.term .. " -e 'alsamixer -c " .. cardid .. "'")
end

local function create(_, cardid, channel)
    local cardid = cardid or 0
    local channel = channel or "Master"

    local obj = { cardid = cardid, channel = channel }

    local widget = capi.widget({
        type  = "textbox",
        name  = "tb_volume",
        align = "right"
    })

    obj.widget = widget
    obj.update = function() update(obj) end

    widget:buttons(awful.util.table.join(
        awful.button({ }, 4, function () raise(obj.cardid, obj.channel, 1) obj.update() end),
        awful.button({ }, 5, function () lower(obj.cardid, obj.channel, 1) obj.update() end),
        awful.button({ }, 1, function () mute(obj.cardid, obj.channel)     obj.update() end),
        awful.button({ }, 3, function () mixer(obj.cardid)     obj.update() end)
    ))

    obj.set_layout  = function(obj, layout) obj.layout = layout                       return obj end
    obj.set_cardid  = function(obj, id)     obj.cardid = id              obj.update() return obj end
    obj.set_channel = function(obj, id)     obj.channel = id             obj.update() return obj end
    obj.raise       = function(obj, v) raise(obj.cardid, obj.channel, v) obj.update() return obj end
    obj.lower       = function(obj, v) lower(obj.cardid, obj.channel, v) obj.update() return obj end
    obj.mute        = function(obj, v) mute(obj.cardid, obj.channel, v)  obj.update() return obj end

    obj.update()
    lib.hooks.timer.register(10, 30, obj.update, "Update for the volume widget")
    lib.hooks.timer.start(obj.update)

    return obj
end

setmetatable(_M, { __call = create })
-- vim: filetype=lua:expandtab:shiftwidth=4:tabstop=4:softtabstop=4:encoding=utf-8:textwidth=80
