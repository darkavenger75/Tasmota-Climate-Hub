import haspmota
import string
import json

# Configuration Constant (avoids duplicating credentials)
var REMOTE_URL = "http://****/cm?user=****&password=****&cmnd="

var cl = webclient()

# Helper function to send commands safely
def sendRemoteCmd(cmnd_str)
   cl.begin(REMOTE_URL .. cmnd_str)
   cl.GET()
   var res = cl.get_string()
   return res != "" ? json.load(res) : nil
end

# Controls remote relays instantly when toggled on the touchscreen
def changeRelay(idx, val)
   var state_str = val ? "on" : "off"
   # URL-encode the space character using %20
   sendRemoteCmd(string.format("power%d%%20%s", idx, state_str))
end

def wakeButton()
   tasmota.cmd('POWER4 ON')
   global.p0b21.enabled = true
   global.p0b23.enabled = true
   global.p0b24.enabled = true
   global.p0b25.enabled = true
end

# ULTRA OPTIMIZATION: Fetches all remote stats in a single network trip
def updateRemoteDashboard()
   # This asks the remote device to construct a single JSON payload of everything we need
   var remote_berry_code = "json.dump({" 
      "\"sensors\":json.load(tasmota.read_sensors())," 
      "\"p1\":tasmota.get_power(0),\"p2\":tasmota.get_power(1),\"p3\":tasmota.get_power(2),\"p4\":tasmota.get_power(3),\"p5\":tasmota.get_power(4)," 
      "\"dMin\":persist.DayMin,\"dMax\":persist.DayMax,\"nMin\":persist.NightMin,\"nMax\":persist.NightMax" 
   "})"

   # URL-encode the code payload for the Tasmota 'br' command
   var response = sendRemoteCmd("br%20" .. cl.url_encode(remote_berry_code))
   
   if !response || !response.find('Br') return end
   var data = json.load(response['Br'])
   if !data return end

   # 1. Update Temperatures & Humidity
   if data.find('sensors') && data['sensors'].find('DS18B20')
      var dsTemp = data['sensors']['DS18B20']['Temperature']
      global.p0b11.text = string.format('%0.1f', dsTemp) .. "°C"
      global.p0b31.val  = int(dsTemp * 10)
   end
   if data.find('sensors') && data['sensors'].find('SI7021-19')
      global.p0b13.text = string.format('%0.1f', data['sensors']['SI7021-19']['Temperature']) .. "°C"
      global.p0b15.text = string.format('%0.0f', data['sensors']['SI7021-19']['Humidity']) .. "%"
   end

   # 2. Update Relay Power Switches (Eliminates 5 individual HTTP requests)
   global.p0b21.val = data['p1']
   global.p0b22.val = data['p2']
   global.p0b23.val = data['p3']
   global.p0b24.val = data['p4']
   global.p0b25.val = data['p5']

   # 3. Update Target Ranges (Eliminates 4 individual HTTP requests)
   global.p0b41.text = string.format('%0.1f', data['dMin']) .. "°C"
   global.p0b43.text = string.format('%0.1f', data['dMax']) .. "°C"
   global.p0b45.text = string.format('%0.1f', data['nMin']) .. "°C"
   global.p0b47.text = string.format('%0.1f', data['nMax']) .. "°C"   
end

def displaySleep()
   tasmota.cmd('POWER4 OFF')
   global.p0b21.enabled = false
   global.p0b22.enabled = false
   global.p0b23.enabled = false
   global.p0b24.enabled = false
   global.p0b25.enabled = false
end

# Component Event Triggers
tasmota.add_rule("hasp#p0b21#event=changed", def (val) changeRelay(1, global.p0b21.val) end)
tasmota.add_rule("hasp#p0b23#event=changed", def (val) changeRelay(3, global.p0b23.val) end)
tasmota.add_rule("hasp#p0b24#event=changed", def (val) changeRelay(4, global.p0b24.val) end)
tasmota.add_rule("hasp#p0b25#event=changed", def (val) changeRelay(5, global.p0b25.val) end)
tasmota.add_rule("hasp#p0b99#event=down", wakeButton)

# Consolidated Cron Rules (Runs the single aggregated query smoothly)
tasmota.add_rule("time#minute", updateRemoteDashboard)
tasmota.add_rule("time#minute|10", displaySleep)
tasmota.add_rule("Time#Initialized", updateRemoteDashboard)

haspmota.start("remote_terra.jsonl")
