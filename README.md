ESP32-C6 based climate controller for Tasmota

A flexible Tasmota hub with 4 sensor inputs and 5 relay outputs. 
- RJ9 inputs for Sonoff WTS01 or THS01 (or whatever you want to connect requiring 1 GPIO, GND, 3.3V).
- Solid state relay main voltage outputs, max. 2A each.
- Option to add Zigbee module Ebyte E18-MS1 to integrate some of your Zigbee devices (check https://zigbee.blakadder.com/zigbee2tasmota.html for compatibility).

Instructions
- Eagle schematic, board, Gerber, BOM and CPL files are provided. Someone like JLCPCB can make the PCB and assemble it for you (check placement of components!). You might have to preorder the RJ9 sockets and solid state relays (Omron or Panasonic) or add them later yourself. 
- Flash with Tasmota for ESP32C6. If you want Zigbee support you must complie your own version, e.g. with Gitpod.
- Set-up GPIO according to "Tasmota_ESP32C6_GPIO_Config.png" and your own configuration.
- If attaching DS18x20 close the jumpers on the respective ports to add pullup resistors.
- If attaching THS01 (SI7021) add rule "ON System#Init DO DhtDelay 480,40 ENDON" or sensor might not work reliably.
- If you want the Zigbee module you have to flash it first with Z-Stack Home 1.2 coordinator firmware from https://github.com/Koenkk/Z-Stack-firmware. A debug port is provided. See https://tasmota.github.io/docs/CC2530/#flash-zigbee-adapter for options. Do not forget to close the jumper next to the board such that it will be powered.
- An example rule with 6 timers (3x ON/OFF) set to "rule" is provided. It will switch relays 1 and 2 on and off according to timers 1/2 and 3/4. It will switch relay 3 according to the temperture input from DS18B20 with limits chosen by timer 3 for mem1/mem2 (timer on) or mem3/mem4 (timer off).  
