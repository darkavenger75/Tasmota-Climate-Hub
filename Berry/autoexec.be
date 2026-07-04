import webserver
import string
import persist
import json

class MyInputBox
  def init()
    if (!persist.DayMin)     persist.DayMin = 24 end 
    if (!persist.DayMax)     persist.DayMax = 27 end
    if (!persist.NightMin)   persist.NightMin = 18 end
    if (!persist.NightMax)   persist.NightMax = 20 end	
    if (!persist.tempLog)    persist.tempLog = [] end	
  end
 
  def web_add_main_button()
    webserver.content_send("<div style='padding:0'><h3>Set day temperature</h3></div>")
    webserver.content_send(self._render_button(persist.DayMin, "Min.", "DayMin"))
    webserver.content_send(self._render_button(persist.DayMax, "Max.", "DayMax"))
    webserver.content_send("<div style='padding:0'><h3>Set night temperature</h3></div>")
    webserver.content_send(self._render_button(persist.NightMin, "Min.", "NightMin"))
    webserver.content_send(self._render_button(persist.NightMax, "Max.", "NightMax"))		
  end

  def _render_button(persist_item, label, id)
    return "<div style='padding:0'>" +
           "<table style='width: 100%'>" +
           "<tr>" +
           "<td style='width: 7em'><label>" .. label .. " </label></td>" +
           "<td><input type='number' min='16' max='28' step='1' style='width: 7em' " +
           "onchange='la(\"&" .. id .. "=\"+this.value)' " +
           "oninput=\"document.getElementById('lab_" .. id .. "').innerHTML=this.value\" " +
           "value='" .. str(persist_item) .. "'/></td>" +
           "<td align='right'><span id='lab_" .. id .. "'>" .. str(persist_item) .. "</span>°C</td>" +
           "</tr>" +
           "</table>" +
           "</div>"
  end
 
  def web_sensor()  
    if webserver.has_arg("DayMin")   persist.DayMin = int(webserver.arg("DayMin")) end
    if webserver.has_arg("DayMax")   persist.DayMax = int(webserver.arg("DayMax")) end	
    if webserver.has_arg("NightMin") persist.NightMin = int(webserver.arg("NightMin")) end
    if webserver.has_arg("NightMax") persist.NightMax = int(webserver.arg("NightMax")) end		
  end
end

InputBox = MyInputBox()
tasmota.add_driver(InputBox)

# --- Helper Functions ---
def timerTime(mytimer)
  var k = tasmota.cmd(mytimer)
  if !k || !k.find(mytimer) return 0 end
  var t = k[mytimer]['Time']
  var parsed = tasmota.strptime(t, "%H:%M")
  return parsed['hour'] * 60 + parsed['min']
end

def timerChannel(mytimer)
  var k = tasmota.cmd(mytimer)
  return (k && k.find(mytimer)) ? k[mytimer]['Output'] : 1
end

def timerEnable(mytimer)
  var k = tasmota.cmd(mytimer)
  return (k && k.find(mytimer)) ? k[mytimer]['Enable'] : 0
end

def curtimeMins()
  var timestamp = tasmota.rtc('local')
  var td = tasmota.time_dump(timestamp)
  return td['hour'] * 60 + td['min']
end	

def checkisday()
  var curtime = curtimeMins()	
  var tTime   = timerTime('Timer1')
  var tTime2  = timerTime('Timer2')
  return (curtime >= tTime) && (curtime < tTime2)
end

def checktime()
  var curtime = curtimeMins()	
  for i:1..8
    var t_prefix = string.format('Timer%d', 2*i-1)
    var tTime    = timerTime(t_prefix)
    var tTime2   = timerTime(string.format('Timer%d', 2*i))
    var tChannel = timerChannel(t_prefix)
    var tEnable  = timerEnable(t_prefix)						
    if tEnable			
      if (curtime >= tTime) && (curtime < tTime2)
        tasmota.set_power(tChannel - 1, true)
      else
        tasmota.set_power(tChannel - 1, false)
      end				
    end
  end
end

def thermostat()
  var isDay = checkisday()
  var sensors = json.load(tasmota.read_sensors())
  
  if !sensors.find('DS18B20') return end
  var curTemp = sensors['DS18B20']['Temperature']
  
  if isDay
    if curTemp < (persist.DayMin - 1.0)
      tasmota.set_power(2, true)
      tasmota.set_power(3, true)
    elif curTemp < persist.DayMin
      tasmota.set_power(2, true)
    elif curTemp > persist.DayMax
      tasmota.set_power(2, false)
      tasmota.set_power(3, false)				
    elif curTemp > persist.DayMin
      tasmota.set_power(3, false)	
    end		
  else
    tasmota.set_power(2, false) # Halogen off at night
    if curTemp < persist.NightMin
      tasmota.set_power(3, true)
    elif curTemp > persist.NightMax
      tasmota.set_power(3, false)				
    end		
  end
  
  if persist.tempLog.size() >= 96
    persist.tempLog.pop(0)
  end
  persist.tempLog.push(curTemp)		
end

def onBoot()
  tasmota.cmd('DhtDelay 480,40')
  tasmota.cmd('DhtDelay2 480,40')
end

tasmota.add_rule("System#Init", onBoot)
tasmota.add_rule("Time#Initialized", checktime)
tasmota.add_rule("Time#Minute|15", thermostat)

class DS18B20Diagramm : Driver
  def web_add_main_button()
    var fcss = open("uPlot.min.css", "r")
    if fcss
      var css_content = fcss.read()
      fcss.close()
      webserver.content_send("<style>" .. css_content .. "</style>")
    end

    webserver.content_send(
      "<style>"
      "  .u-title { color: #000000; }"
      "  .u-legend .u-label, .u-legend .u-value { color: #000000; }"
      "</style>"
      "<script src='/ufsd?download=/uPlot.iife.min.js'></script>"
      "<div id='chart_div' style='background-color: #ffffff; margin-top: 10px; box-sizing: border-box;'></div>"
      "<script type='text/javascript'>"
      "  var xData = [];"
      "  var yData = [];"
    )

    for i: 0 .. persist.tempLog.size() - 1
      webserver.content_send(
        string.format("  xData.push(%0.2f); yData.push(%s);", real(i) * 15 / 60, str(persist.tempLog[i]))
      )
    end

    webserver.content_send(
      "  var data = [xData, yData];"
      "  var opts = {"
      "    title: 'Temperature 24h',"
      "    width: document.getElementById('chart_div').offsetWidth || 800,"
      "    height: 260,"
      "    scales: {"
      "      x: { time: false, min: 0, max: 24 },"
      "      y: {"
      "        auto: true,"
      "        range: function(self, dataMin, dataMax) {"
      "          var finalMin = Math.min(20, dataMin);"
      "          var finalMax = Math.max(30, dataMax);"
      "          return [finalMin, finalMax];"
      "        }"
      "      }"
      "    },"
      "    axes: ["
      "      {"
      "        scale: 'x',"
      "        stroke: '#000000',"
      "        splits: [0, 2, 4, 6, 8, 10, 12, 14, 16, 18, 20, 22, 24]"
      "      },"
      "      {"
      "        scale: 'y',"
      "        stroke: '#000000'"
      "      }"
      "    ],"
      "    series: ["
      "      {},"
      "      {"
      "        label: 'Temperature [°C]',"
      "        stroke: 'rgb(65, 105, 225)'," 
      "        fill: 'rgba(65, 105, 225, 0.1)'," 
      "        width: 2"
      "      }"
      "    ]"
      "  };"
      "  var uplot = new uPlot(opts, data, document.getElementById('chart_div'));"
      "</script>"
    )
  end
end

DS18B20_diagramm = DS18B20Diagramm()
tasmota.remove_driver(DS18B20_diagramm) 
tasmota.add_driver(DS18B20_diagramm)
