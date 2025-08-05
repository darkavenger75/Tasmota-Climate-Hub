import webserver
import string
import persist
import json

#- power0 = LED
power1 = HID
power2 = heatlamp
power3 = heatmat
power4 = fan

DS18B20 = temperature to be regulated on
SI7021  = additional temp+humidity

timer1,timer2 = daytime heating on/off - must be defined
timers switch output directly if enabled, correct state is check at restart

Thermostat
if temp<...Min -> heatlamp, heatmat on
if temp>...Min+0.2 -> heatmat off
if temp>...Max -> heatlamp off 

DayMin : minimum daytime temp (all heating on)  
DayMax : maximum daytime temp (all heating off) 
NightMin 	
NightMax -#
	
class MySlider

  def init()
    if (!persist.DayMin)
        persist.DayMin = 24
    end
    if (!persist.DayMax)
        persist.DayMax = 26
    end	
    if (!persist.NightMin)
        persist.NightMin = 18
    end
    if (!persist.NightMax)
        persist.NightMax = 20
    end	
	if (!persist.tempLog)
        persist.tempLog = []
    end	
  end
 
  def web_add_main_button()
    webserver.content_send("<div style='padding:0'><h3>Set day temperature</h3></div>")
    webserver.content_send(
      self._render_button(persist.DayMin, "Min.", "DayMin")
    )
    webserver.content_send(
      self._render_button(persist.DayMax, "Max.", "DayMax")
    )
	webserver.content_send("<div style='padding:0'><h3>Set night temperature</h3></div>")
    webserver.content_send(
      self._render_button(persist.NightMin, "Min.", "NightMin")
    )
    webserver.content_send(
      self._render_button(persist.NightMax, "Max.", "NightMax")
    )		
  end

  def _render_button(persist_item, label, id)
    return "<div style='padding:0'>"+
        "<table style='width: 100%'>"+
          "<tr>"+
            "<td><label>"..label.." </label></td>"+
            "<td align=\"right\"><span id='lab_"..id.."'>"..persist_item.."</span>°C</td>"+
          "</tr>"+
        "</table>"+
        "<input type=\"range\" min=\"16\" max=\"28\" step=\"1\" "+
          "onchange='la(\"&"..id.."=\"+this.value)' "+
          "oninput=\"document.getElementById('lab_"..id.."').innerHTML=this.value\" "+
          "value='"..persist_item.."'/>"+
      "</div>"
  end
 
  def web_sensor()  
    if webserver.has_arg("DayMin")
      persist.DayMin = int(webserver.arg("DayMin"))
      persist.save()
    end
    if webserver.has_arg("DayMax")
      persist.DayMax = int(webserver.arg("DayMax"))
      persist.save()
    end	
	if webserver.has_arg("NightMin")
      persist.NightMin = int(webserver.arg("NightMin"))
      persist.save()
    end
    if webserver.has_arg("NightMax")
      persist.NightMax = int(webserver.arg("NightMax"))
      persist.save()
    end		
  end
end

slider = MySlider()
tasmota.add_driver(slider)

def timerTime(mytimer)
	var k=tasmota.cmd(mytimer)
	k = k[mytimer]['Time']
	k = tasmota.strptime(k, "%H:%M")['hour']*60 + tasmota.strptime(k, "%H:%M")['min']
	return k
end

def timerChannel(mytimer)
	var k=tasmota.cmd(mytimer)
	k = k[mytimer]['Output']
	return k
end

def timerEnable(mytimer)
	var k=tasmota.cmd(mytimer)
	k = k[mytimer]['Enable']
	return k
end

def curtimeMins()
	var timestamp = tasmota.rtc('local')
	var k   = tasmota.time_dump(timestamp)['hour']*60 + tasmota.time_dump(timestamp)['min']	
	return k
end	

def checkisday()
	var isDay     = false
	var curtime   = curtimeMins()	
	var tTime     = timerTime('Timer1')
	var tTime2    = timerTime('Timer2')
	if (curtime>=tTime) && (curtime<tTime2)
		isDay = true
	end
	return isDay
end

def checktime()
	var curtime = curtimeMins()	
	for i:1..8
		var tTime    = timerTime(string.format('Timer%d',2*i-1))
		var tTime2   = timerTime(string.format('Timer%d',2*i))
		var tChannel = timerChannel(string.format('Timer%d',2*i-1))
		var tEnable  = timerEnable(string.format('Timer%d',2*i-1))						
		if tEnable			
			if (curtime>=tTime) && (curtime<tTime2)
				tasmota.set_power(tChannel-1, true)
			else
				tasmota.set_power(tChannel-1, false)
			end				
		end
	end
end

def thermostat()
	var isDay = checkisday()
	var sensors=json.load(tasmota.read_sensors())
	var curTemp = sensors['DS18B20']['Temperature']
	if isDay
		if curTemp<persist.DayMin
			tasmota.set_power(2, true)
			tasmota.set_power(3, true)
		elif curTemp>persist.DayMax
			tasmota.set_power(2, false)
			tasmota.set_power(3, false)				
		elif curTemp>(persist.DayMin+0.2)
			tasmota.set_power(3, false)	
		end		
	else
		if curTemp<persist.NightMin
			tasmota.set_power(2, true)
			tasmota.set_power(3, true)
		elif curTemp>persist.NightMax
			tasmota.set_power(2, false)
			tasmota.set_power(3, false)				
		elif curTemp>(persist.NightMin+0.2)
			tasmota.set_power(3, false)	
		end			
	end
	
	if persist.tempLog.size() == 240
		persist.tempLog.pop(0)
	end
	persist.tempLog.push(curTemp)		
end

def onBoot()
	tasmota.cmd('DhtDelay 480,40')
end

def onRestart()
    persist.save()
end

tasmota.add_rule("System#Init", onBoot)
tasmota.add_rule("Time#Initialized", checktime)
tasmota.add_rule("Time#Minute|5", thermostat)
tasmota.add_rule("System#Save",onRestart)

class DS18B20Diagramm : Driver
    def init()
		if (!persist.tempLog)
			persist.tempLog = []
		end
        tasmota.add_driver(self)
    end
	
    def web_add_main_button()

        webserver.content_send(
            "<script type='text/javascript' src='https://www.gstatic.com/charts/loader.js'></script>"
            "<script type='text/javascript'>"
            "google.charts.load('current', {'packages':['corechart']});"
            "google.charts.setOnLoadCallback(drawChart);"
            "function drawChart() {"
            "  var data = google.visualization.arrayToDataTable(["
            "  ['Hour', 'Temperature [°C]'],"
        )

        for i: 0 .. persist.tempLog.size() - 1
            webserver.content_send(format("[%0.2f, %s],", real(i)*5/60, str(persist.tempLog[i])))
        end

        webserver.content_send(
            "  ]);"
            "  var options = {"
            "    title: 'Temperature 24h',"
            "    hAxis: {format: '0',minValue: 0, maxValue: 24, ticks: [0, 2, 4, 6, 8, 10, 12, 14, 16, 18, 20, 22, 24 ]},"
            "    vAxis: {minValue: 20, maxValue: 30},"
			"    legend: {position: 'none'}"
            "  };"
            "  var chart = new google.visualization.AreaChart(document.getElementById('chart_div'));"
            "  chart.draw(data, options);"
            "}"
            "</script>"
            "<div id='chart_div' style='width: 100%; height: 350px;'></div>"
        )
    end
end

DS18B20_diagramm = DS18B20Diagramm()
tasmota.remove_driver(DS18B20Diagramm) 
tasmota.add_driver(DS18B20Diagramm)