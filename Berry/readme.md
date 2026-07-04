Berry and HASPmota code to control your terrarium and show relevant data on an ESP32-4848S040 display (e.g. from https://de.aliexpress.com/item/1005007606761287.html?gatewayAdapt=glo2deu4itemAdapt). 
1) Configure the ESP32C6 climate hub as described on the main project page, including GPIO configuration.
3) Copy "autoexec.be" to the device. No other "rules" required but timers 1 (begin) and 2 (end) determine what is daytime.
4) Copy uPlot's uPlot.iife.min.js and uPlot.min.css files to the file system. This allows for creating the temperature chart without internet access.
5) Adjust timers and temperatures as desired. As a minimum timer1 and timer2 are required: day starts at timer1, ends at timer2.  
6) Install the "tasmota32s3-qio_opi" version of Tasmota on the ESP32-4848S040.
7) Use "auto-conf" and select "S3-4848S040"
8) Copy "autoexec_remote.be" - rename to "autoexec.be" - and the .jsonl file to the device.
9) Change the URL in autoexec.be to match your climate hub (currently set to http://tasmota-terra/).
10) Restart and enjoy.
