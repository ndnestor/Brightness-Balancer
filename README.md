# Brightness-Balancer

## The Goal
Reduce the end-user's eye strain by modulating their screen's brightness based on what is currently present on their screen. The brighter the pizels are on average, the lower the brightness setting of the end-user's screen will get. This is mainly a solution for laptops as desktop monitors usually cannot have their brightness setting be modulated programmatically. Laptops, on the other hand, almost always support software-based brightness modulation.

## Technologies
This project uses AutoHotKey. The latest version of AutoHotKey that this has been tested on is 1.1.22.02.

## Launch
To build this project, you firstly need to clone this repo. Then [download AutoHotkey from here](https://www.autohotkey.com). Aftering finishing the setup process, run the file called "Ahk2Exe.exe". Click the "Browse" button next to the "Source" box. Locate and select "Brightness Balancer.ahk" which comes with this repo. Blick the "Browse" button next to the "Destination" box. Locate and select the folder that contains "Settings.txt" which also comes with this repo. Finally click the "Convert" button. A .exe file should appear in the same folder as the "Settings.txt" file. Congratuations, you can now run it :)
