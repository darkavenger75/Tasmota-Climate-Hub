import haspmota
import string
import json

var DS18B20_Temp
var SI7021_Temp
var SI7021_Hum

var DayMin
var DayMax
var NightMin
var NightMax

var cl = webclient()

def changeRelay(idx, val)
   var sTable = {true:'on', false:'off'}
   cl.begin(string.format("http://tasmota-terra/cm?cmnd=power%d%s%s",idx,'%20',sTable[val]))
   cl.GET()
   var s = cl.get_string()
end


def wakeButton()
   #print('Wake button pressed')
   tasmota.cmd('POWER4 ON')
end

def getRemoteTemp()
   cl.begin("http://tasmota-terra/cm?cmnd=status%2010")
   cl.GET()
   var s = cl.get_string()
   s = json.load(s)
   DS18B20_Temp  = s['StatusSNS']['DS18B20']['Temperature']
   SI7021_Temp   = s['StatusSNS']['SI7021']['Temperature']
   SI7021_Hum    = s['StatusSNS']['SI7021']['Humidity']
end

def getRemoteTempRanges()
   cl.begin("http://tasmota-terra/cm?cmnd=br%20persist.DayMin")
   cl.GET()
   var s = cl.get_string()
   s = json.load(s)
   DayMin  = s['Br']
   cl.begin("http://tasmota-terra/cm?cmnd=br%20persist.DayMax")
   cl.GET()
   s = cl.get_string()
   s = json.load(s)
   DayMax  = s['Br']
   cl.begin("http://tasmota-terra/cm?cmnd=br%20persist.NightMin")
   cl.GET()
   s = cl.get_string()
   s = json.load(s)
   NightMin  = s['Br']
   cl.begin("http://tasmota-terra/cm?cmnd=br%20persist.NightMax")
   cl.GET()
   s = cl.get_string()
   s = json.load(s)
   NightMax  = s['Br']
end

def updateTempRangesRemote()
   getRemoteTempRanges()
   global.p0b41.text = string.format('%0.1f',DayMin)+"°C"
   global.p0b43.text = string.format('%0.1f',DayMax)+"°C"
   global.p0b45.text = string.format('%0.1f',NightMin)+"°C"
   global.p0b47.text = string.format('%0.1f',NightMax)+"°C"   
end

def getRemotePower(idx)
   cl.begin(string.format("http://tasmota-terra/cm?cmnd=power%d",idx))
   cl.GET()
   var s = cl.get_string()
   s = json.load(s)
   s = s[string.format("POWER%d",idx)]
   return s
end

def updateTempRemote()
   getRemoteTemp()
   global.p0b11.text = string.format('%0.1f',DS18B20_Temp)+"°C"
   global.p0b13.text = string.format('%0.1f',SI7021_Temp)+"°C"
   global.p0b15.text = string.format('%0.0f',SI7021_Hum)+"%" 
   global.p0b31.val  = DS18B20_Temp*10
end

def updatePowerRemote()
   var s
   s=getRemotePower(1)
   if s=='OFF'
      global.p0b21.val = 'false'
   elif s=='ON'
      global.p0b21.val = 'true'
   end   
   s=getRemotePower(2)
   if s=='OFF'
      global.p0b22.val = 'false'
   elif s=='ON'
      global.p0b22.val = 'true'
   end
   s=getRemotePower(3)
   if s=='OFF'
      global.p0b23.val = 'false'
   elif s=='ON'
      global.p0b23.val = 'true'
   end
   s=getRemotePower(4)
   if s=='OFF'
      global.p0b24.val = 'false'
   elif s=='ON'
      global.p0b24.val = 'true'
   end
   s=getRemotePower(5)
   if s=='OFF'
      global.p0b25.val = 'false'
   elif s=='ON'
      global.p0b25.val = 'true'
   end 
end

tasmota.add_rule("hasp#p0b21#event=changed", def (val) changeRelay(1,global.p0b21.val) end)
#tasmota.add_rule("hasp#p0b22#event=changed", def (val) changeRelay(2,global.p0b22.val) end)
tasmota.add_rule("hasp#p0b23#event=changed", def (val) changeRelay(3,global.p0b23.val) end)
tasmota.add_rule("hasp#p0b24#event=changed", def (val) changeRelay(4,global.p0b24.val) end)
tasmota.add_rule("hasp#p0b25#event=changed", def (val) changeRelay(5,global.p0b25.val) end)
tasmota.add_rule("hasp#p0b99#event=down", wakeButton)

tasmota.add_rule("time#minute", updateTempRemote)
tasmota.add_rule("time#minute", updatePowerRemote)
tasmota.add_rule("time#minute", updateTempRangesRemote)
tasmota.add_rule("time#minute|10", def (val) tasmota.cmd('POWER4 OFF') end)

tasmota.add_rule("Time#Initialized", updateTempRemote)
tasmota.add_rule("Time#Initialized", updatePowerRemote)
tasmota.add_rule("Time#Initialized", updateTempRangesRemote)

haspmota.start("remote_terra.jsonl")

