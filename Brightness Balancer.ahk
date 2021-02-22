#NoEnv
#MaxHotkeysPerInterval 99000000
#HotkeyInterval 99000000
#KeyHistory 0
ListLines Off
Process, Priority, , A
SetBatchLines, -1
SetKeyDelay, -1, -1
SetMouseDelay, -1
SetDefaultMouseSpeed, 0
SetWinDelay, -1
CoordMode, Pixel, Screen

brightnessSetter := new BrightnessSetter()
percentOfScreenScanned := 0.1 ;inverse

if(FileExist("Settings.txt"))
{
	Loop, Read, Settings.txt
	{
		if(A_Index == 1)
		{
			tempIndex := InStr(A_LoopReadLine, A_Space, false, , 3)
			percentOfScreenScanned := 1 / SubStr(A_LoopReadLine, tempIndex, StrLen(A_LoopReadLine) - tempIndex + 1)
		}
		else if(A_Index == 2)
		{
			tempIndex := InStr(A_LoopReadLine, A_Space, false, , 3)
			maxAllowedBrightness := SubStr(A_LoopReadLine, tempIndex, StrLen(A_LoopReadLine) - tempIndex + 1)
		} else if(A_Index == 3)
		{
			tempIndex := InStr(A_LoopReadLine, A_Space, false, , 3)
			minAllowedBrightness := SubStr(A_LoopReadLine, tempIndex, StrLen(A_LoopReadLine) - tempIndex + 1)
			
		}
	}
} else
{
	MsgBox, Settings.txt does not exist or it is not in the same directory as this program. This program will exit
	ExitApp, 1
}
brightnessDampener := 100 / (maxAllowedBrightness - minAllowedBrightness)

Menu, Tray, Add, Settings, OpenSettings
OpenSettings()
{
	global
	Gui, SettingsWindow:New, , AutoBrightness Settings
	Gui, Add, Text, , Scan accuracy
	Gui, Add, Edit, vScanAccuracy
	temp := 1 / percentOfScreenScanned
	Gui, Add, UpDown, , %temp%
	
	Gui, Add, Text, , Maximum brightness
	Gui, Add, Edit, vMaximumBrightness
	Gui, Add, UpDown, , %maxAllowedBrightness%
	
	Gui, Add, Text, , Minimum brightness
	Gui, Add, Edit, vMinimumBrightness
	Gui, Add, Updown, , %minAllowedBrightness%
	
	Gui, Add, Button, gButtonSave Default, Save
	Gui, Add, Button, gButtonCancel, Cancel
	Gui, Show
}

ButtonSave()
{
	global
	Gui, Submit
	percentOfScreenScanned := 1 / ScanAccuracy
	maxAllowedBrightness := MaximumBrightness
	minAllowedBrightness := MinimumBrightness
	
	FileDelete, Settings.txt
	FileAppend, Scan Accuracy = %ScanAccuracy%`nMaximum Brightness = %MaximumBrightness%`nMinimum Brightness = %MinimumBrightness%, Settings.txt
}

ButtonCancel()
{
	Gui, Cancel
}

isLooping := false
hasLoopedBefore := false
Menu, Tray, Add, Start, ToggleLoop
ToggleLoop()
{
	global
	if(isLooping)
	{
		isLooping := false
		Menu, Tray, Delete, Stop
		Menu, Tray, Add, Start, ToggleLoop
	} else
	{
		isLooping := true
		Menu, Tray, Delete, Start		
		Menu, Tray, Add, Stop, ToggleLoop
		StartLoop()
	}
}

StartLoop()
{
	global
	Loop,
	{
		percentOfScreenScanned := 0.1 ;inverse
		widthIncrement := percentOfScreenScanned * A_ScreenWidth
		heightIncrement := percentOfScreenScanned * A_ScreenHeight
		loopMax := (1 / percentOfScreenScanned) + 1
		
		totalRed := 0x0
		totalGreen := 0x0
		totalBlue := 0x0
		Loop, %loopMax%
		{
			if(!isLooping)
			{
				break
			}
			outterLoopIndex := A_Index
			Loop, %loopMax%
			{	
				xCoord := widthIncrement * (outterLoopIndex - 1)
				yCoord := heightIncrement * (A_Index - 1)
				PixelGetColor, color, xCoord, yCoord, Slow RGB
				totalRed += "0x"SubStr(color, 3, 2)
				totalGreen += "0x"SubStr(color, 5, 2)
				totalBlue += "0x"SubStr(color, 7, 2)
			}
		}
		
		if(!isLooping)
		{
			break
		}
		
		avgColorBrightness := totalRed + totalGreen + totalBlue
		;Msgbox, %totalRed% %totalGreen% %totalBlue%
		newBrightness := ((100 - (avgColorBrightness / 765)) / brightnessDampener) + minAllowedBrightness
	  
		;Gets battery state
		VarSetCapacity(powerstatus, 1+1+1+1+4+4)
		success := DllCall("kernel32.dll\GetSystemPowerStatus", "uint", &powerstatus)
		acLineStatus := ReadInteger(&powerstatus,0,1,false)

		;Update the brightness
		gosub GetACDCBrightness
		if(acLineStatus == 1)
		{
			brightnessSetter.SetBrightness((newBrightness - vBrightnessAC))
			;Msgbox, %newBrightness% - %vBrightnessAC%
		} else
		{
			brightnessSetter.SetBrightness(newBrightness - vBrightnessDC)
			;MsgBox, %newBrightness% - %vBrightnessDC%
		}
	}
}






















;THIRD-PARTY BATTERY STATUS STUFF
;From https://autohotkey.com/board/topic/7022-acbattery-status/
ReadInteger( p_address, p_offset, p_size, p_hex=true )
{
  value = 0
  old_FormatInteger := a_FormatInteger
  if ( p_hex )
    SetFormat, integer, hex
  else
    SetFormat, integer, dec
  loop, %p_size%
    value := value+( *( ( p_address+p_offset )+( a_Index-1 ) ) << ( 8* ( a_Index-1 ) ) )
  SetFormat, integer, %old_FormatInteger%
  return, value
}







;THIRD-PARTY SET BRIGHTNESS STUFF
class BrightnessSetter {
	; qwerty12 - 27/05/17
	; https://github.com/qwerty12/AutoHotkeyScripts/tree/master/LaptopBrightnessSetter
	static _WM_POWERBROADCAST := 0x218, _osdHwnd := 0, hPowrprofMod := DllCall("LoadLibrary", "Str", "powrprof.dll", "Ptr") 

	__New() {
		if (BrightnessSetter.IsOnAc(AC))
			this._AC := AC
		if ((this.pwrAcNotifyHandle := DllCall("RegisterPowerSettingNotification", "Ptr", A_ScriptHwnd, "Ptr", BrightnessSetter._GUID_ACDC_POWER_SOURCE(), "UInt", DEVICE_NOTIFY_WINDOW_HANDLE := 0x00000000, "Ptr"))) ; Sadly the callback passed to *PowerSettingRegister*Notification runs on a new threadl
			OnMessage(this._WM_POWERBROADCAST, ((this.pwrBroadcastFunc := ObjBindMethod(this, "_On_WM_POWERBROADCAST"))))
	}

	__Delete() {
		if (this.pwrAcNotifyHandle) {
			OnMessage(BrightnessSetter._WM_POWERBROADCAST, this.pwrBroadcastFunc, 0)
			,DllCall("UnregisterPowerSettingNotification", "Ptr", this.pwrAcNotifyHandle)
			,this.pwrAcNotifyHandle := 0
			,this.pwrBroadcastFunc := ""
		}
	}

	SetBrightness(increment, jump := False, showOSD := False, autoDcOrAc := -1, ptrAnotherScheme := 0)
	{
		static PowerGetActiveScheme := DllCall("GetProcAddress", "Ptr", BrightnessSetter.hPowrprofMod, "AStr", "PowerGetActiveScheme", "Ptr")
			  ,PowerSetActiveScheme := DllCall("GetProcAddress", "Ptr", BrightnessSetter.hPowrprofMod, "AStr", "PowerSetActiveScheme", "Ptr")
			  ,PowerWriteACValueIndex := DllCall("GetProcAddress", "Ptr", BrightnessSetter.hPowrprofMod, "AStr", "PowerWriteACValueIndex", "Ptr")
			  ,PowerWriteDCValueIndex := DllCall("GetProcAddress", "Ptr", BrightnessSetter.hPowrprofMod, "AStr", "PowerWriteDCValueIndex", "Ptr")
			  ,PowerApplySettingChanges := DllCall("GetProcAddress", "Ptr", BrightnessSetter.hPowrprofMod, "AStr", "PowerApplySettingChanges", "Ptr")

		if (increment == 0 && !jump) {
			if (showOSD)
				BrightnessSetter._ShowBrightnessOSD()
			return
		}

		if (!ptrAnotherScheme ? DllCall(PowerGetActiveScheme, "Ptr", 0, "Ptr*", currSchemeGuid, "UInt") == 0 : DllCall("powrprof\PowerDuplicateScheme", "Ptr", 0, "Ptr", ptrAnotherScheme, "Ptr*", currSchemeGuid, "UInt") == 0) {
			if (autoDcOrAc == -1) {
				if (this != BrightnessSetter) {
					AC := this._AC
				} else {
					if (!BrightnessSetter.IsOnAc(AC)) {
						DllCall("LocalFree", "Ptr", currSchemeGuid, "Ptr")
						return
					}
				}
			} else {
				AC := !!autoDcOrAc
			}

			currBrightness := 0
			if (jump || BrightnessSetter._GetCurrentBrightness(currSchemeGuid, AC, currBrightness)) {
				 maxBrightness := BrightnessSetter.GetMaxBrightness()
				,minBrightness := BrightnessSetter.GetMinBrightness()

				if (jump || !((currBrightness == maxBrightness && increment > 0) || (currBrightness == minBrightness && increment < minBrightness))) {
					if (currBrightness + increment > maxBrightness)
						increment := maxBrightness
					else if (currBrightness + increment < minBrightness)
						increment := minBrightness
					else
						increment += currBrightness

					if (DllCall(AC ? PowerWriteACValueIndex : PowerWriteDCValueIndex, "Ptr", 0, "Ptr", currSchemeGuid, "Ptr", BrightnessSetter._GUID_VIDEO_SUBGROUP(), "Ptr", BrightnessSetter._GUID_DEVICE_POWER_POLICY_VIDEO_BRIGHTNESS(), "UInt", increment, "UInt") == 0) {
						; PowerApplySettingChanges is undocumented and exists only in Windows 8+. Since both the Power control panel and the brightness slider use this, we'll do the same, but fallback to PowerSetActiveScheme if on Windows 7 or something
						if (!PowerApplySettingChanges || DllCall(PowerApplySettingChanges, "Ptr", BrightnessSetter._GUID_VIDEO_SUBGROUP(), "Ptr", BrightnessSetter._GUID_DEVICE_POWER_POLICY_VIDEO_BRIGHTNESS(), "UInt") != 0)
							DllCall(PowerSetActiveScheme, "Ptr", 0, "Ptr", currSchemeGuid, "UInt")
					}
				}

				if (showOSD)
					BrightnessSetter._ShowBrightnessOSD()
			}
			DllCall("LocalFree", "Ptr", currSchemeGuid, "Ptr")
		}
	}

	IsOnAc(ByRef acStatus)
	{
		static SystemPowerStatus
		if (!VarSetCapacity(SystemPowerStatus))
			VarSetCapacity(SystemPowerStatus, 12)

		if (DllCall("GetSystemPowerStatus", "Ptr", &SystemPowerStatus)) {
			acStatus := NumGet(SystemPowerStatus, 0, "UChar") == 1
			return True
		}

		return False
	}
	
	GetDefaultBrightnessIncrement()
	{
		static ret := 10
		DllCall("powrprof\PowerReadValueIncrement", "Ptr", BrightnessSetter._GUID_VIDEO_SUBGROUP(), "Ptr", BrightnessSetter._GUID_DEVICE_POWER_POLICY_VIDEO_BRIGHTNESS(), "UInt*", ret, "UInt")
		return ret
	}

	GetMinBrightness()
	{
		static ret := -1
		if (ret == -1)
			if (DllCall("powrprof\PowerReadValueMin", "Ptr", BrightnessSetter._GUID_VIDEO_SUBGROUP(), "Ptr", BrightnessSetter._GUID_DEVICE_POWER_POLICY_VIDEO_BRIGHTNESS(), "UInt*", ret, "UInt"))
				ret := 0
		return ret
	}

	GetMaxBrightness()
	{
		static ret := -1
		if (ret == -1)
			if (DllCall("powrprof\PowerReadValueMax", "Ptr", BrightnessSetter._GUID_VIDEO_SUBGROUP(), "Ptr", BrightnessSetter._GUID_DEVICE_POWER_POLICY_VIDEO_BRIGHTNESS(), "UInt*", ret, "UInt"))
				ret := 100
		return ret
	}

	_GetCurrentBrightness(schemeGuid, AC, ByRef currBrightness)
	{
		static PowerReadACValueIndex := DllCall("GetProcAddress", "Ptr", BrightnessSetter.hPowrprofMod, "AStr", "PowerReadACValueIndex", "Ptr")
			  ,PowerReadDCValueIndex := DllCall("GetProcAddress", "Ptr", BrightnessSetter.hPowrprofMod, "AStr", "PowerReadDCValueIndex", "Ptr")
		return DllCall(AC ? PowerReadACValueIndex : PowerReadDCValueIndex, "Ptr", 0, "Ptr", schemeGuid, "Ptr", BrightnessSetter._GUID_VIDEO_SUBGROUP(), "Ptr", BrightnessSetter._GUID_DEVICE_POWER_POLICY_VIDEO_BRIGHTNESS(), "UInt*", currBrightness, "UInt") == 0
	}
	
	_ShowBrightnessOSD()
	{
		static PostMessagePtr := DllCall("GetProcAddress", "Ptr", DllCall("GetModuleHandle", "Str", "user32.dll", "Ptr"), "AStr", A_IsUnicode ? "PostMessageW" : "PostMessageA", "Ptr")
			  ,WM_SHELLHOOK := DllCall("RegisterWindowMessage", "Str", "SHELLHOOK", "UInt")
		if A_OSVersion in WIN_VISTA,WIN_7
			return
		BrightnessSetter._RealiseOSDWindowIfNeeded()
		; Thanks to YashMaster @ https://github.com/YashMaster/Tweaky/blob/master/Tweaky/BrightnessHandler.h for realising this could be done:
		if (BrightnessSetter._osdHwnd)
			DllCall(PostMessagePtr, "Ptr", BrightnessSetter._osdHwnd, "UInt", WM_SHELLHOOK, "Ptr", 0x37, "Ptr", 0)
	}

	_RealiseOSDWindowIfNeeded()
	{
		static IsWindow := DllCall("GetProcAddress", "Ptr", DllCall("GetModuleHandle", "Str", "user32.dll", "Ptr"), "AStr", "IsWindow", "Ptr")
		if (!DllCall(IsWindow, "Ptr", BrightnessSetter._osdHwnd) && !BrightnessSetter._FindAndSetOSDWindow()) {
			BrightnessSetter._osdHwnd := 0
			try if ((shellProvider := ComObjCreate("{C2F03A33-21F5-47FA-B4BB-156362A2F239}", "{00000000-0000-0000-C000-000000000046}"))) {
				try if ((flyoutDisp := ComObjQuery(shellProvider, "{41f9d2fb-7834-4ab6-8b1b-73e74064b465}", "{41f9d2fb-7834-4ab6-8b1b-73e74064b465}"))) {
					 DllCall(NumGet(NumGet(flyoutDisp+0)+3*A_PtrSize), "Ptr", flyoutDisp, "Int", 0, "UInt", 0)
					,ObjRelease(flyoutDisp)
				}
				ObjRelease(shellProvider)
				if (BrightnessSetter._FindAndSetOSDWindow())
					return
			}
			; who knows if the SID & IID above will work for future versions of Windows 10 (or Windows 8). Fall back to this if needs must
			Loop 2 {
				SendEvent {Volume_Mute 2}
				if (BrightnessSetter._FindAndSetOSDWindow())
					return
				Sleep 100
			}
		}
	}
	
	_FindAndSetOSDWindow()
	{
		static FindWindow := DllCall("GetProcAddress", "Ptr", DllCall("GetModuleHandle", "Str", "user32.dll", "Ptr"), "AStr", A_IsUnicode ? "FindWindowW" : "FindWindowA", "Ptr")
		return !!((BrightnessSetter._osdHwnd := DllCall(FindWindow, "Str", "NativeHWNDHost", "Str", "", "Ptr")))
	}

	_On_WM_POWERBROADCAST(wParam, lParam)
	{
		;OutputDebug % &this
		if (wParam == 0x8013 && lParam && NumGet(lParam+0, 0, "UInt") == NumGet(BrightnessSetter._GUID_ACDC_POWER_SOURCE()+0, 0, "UInt")) { ; PBT_POWERSETTINGCHANGE and a lazy comparison
			this._AC := NumGet(lParam+0, 20, "UChar") == 0
			return True
		}
	}

	_GUID_VIDEO_SUBGROUP()
	{
		static GUID_VIDEO_SUBGROUP__
		if (!VarSetCapacity(GUID_VIDEO_SUBGROUP__)) {
			 VarSetCapacity(GUID_VIDEO_SUBGROUP__, 16)
			,NumPut(0x7516B95F, GUID_VIDEO_SUBGROUP__, 0, "UInt"), NumPut(0x4464F776, GUID_VIDEO_SUBGROUP__, 4, "UInt")
			,NumPut(0x1606538C, GUID_VIDEO_SUBGROUP__, 8, "UInt"), NumPut(0x99CC407F, GUID_VIDEO_SUBGROUP__, 12, "UInt")
		}
		return &GUID_VIDEO_SUBGROUP__
	}

	_GUID_DEVICE_POWER_POLICY_VIDEO_BRIGHTNESS()
	{
		static GUID_DEVICE_POWER_POLICY_VIDEO_BRIGHTNESS__
		if (!VarSetCapacity(GUID_DEVICE_POWER_POLICY_VIDEO_BRIGHTNESS__)) {
			 VarSetCapacity(GUID_DEVICE_POWER_POLICY_VIDEO_BRIGHTNESS__, 16)
			,NumPut(0xADED5E82, GUID_DEVICE_POWER_POLICY_VIDEO_BRIGHTNESS__, 0, "UInt"), NumPut(0x4619B909, GUID_DEVICE_POWER_POLICY_VIDEO_BRIGHTNESS__, 4, "UInt")
			,NumPut(0xD7F54999, GUID_DEVICE_POWER_POLICY_VIDEO_BRIGHTNESS__, 8, "UInt"), NumPut(0xCB0BAC1D, GUID_DEVICE_POWER_POLICY_VIDEO_BRIGHTNESS__, 12, "UInt")
		}
		return &GUID_DEVICE_POWER_POLICY_VIDEO_BRIGHTNESS__
	}

	_GUID_ACDC_POWER_SOURCE()
	{
		static GUID_ACDC_POWER_SOURCE_
		if (!VarSetCapacity(GUID_ACDC_POWER_SOURCE_)) {
			 VarSetCapacity(GUID_ACDC_POWER_SOURCE_, 16)
			,NumPut(0x5D3E9A59, GUID_ACDC_POWER_SOURCE_, 0, "UInt"), NumPut(0x4B00E9D5, GUID_ACDC_POWER_SOURCE_, 4, "UInt")
			,NumPut(0x34FFBDA6, GUID_ACDC_POWER_SOURCE_, 8, "UInt"), NumPut(0x486551FF, GUID_ACDC_POWER_SOURCE_, 12, "UInt")
		}
		return &GUID_ACDC_POWER_SOURCE_
	}

}

BrightnessSetter_new() {
	return new BrightnessSetter()
}










;THIRD-PARTY GET BRIGHTNESS STUFF
;based on code by qwerty12:
;Set laptop brightness & show Win 10's native OSD - AutoHotkey Community
;https://autohotkey.com/boards/viewtopic.php?f=6&t=26921
GetACDCBrightness: ;get AC/DC brightness
F14:: ;set AC brightness
F15:: ;set DC brightness
;note: AC is the brightness when the laptop is plugged in
DllCall("powrprof\PowerGetActiveScheme", Ptr,0, PtrP,vActivePolicyGuid, UInt)
VarSetCapacity(GUID_VIDEO_SUBGROUP, 16)
NumPut(0x7516B95F, &GUID_VIDEO_SUBGROUP, 0, "UInt"), NumPut(0x4464F776, &GUID_VIDEO_SUBGROUP, 4, "UInt")
NumPut(0x1606538C, &GUID_VIDEO_SUBGROUP, 8, "UInt"), NumPut(0x99CC407F, &GUID_VIDEO_SUBGROUP, 12, "UInt")
VarSetCapacity(GUID_DEVICE_POWER_POLICY_VIDEO_BRIGHTNESS, 16)
NumPut(0xADED5E82, &GUID_DEVICE_POWER_POLICY_VIDEO_BRIGHTNESS, 0, "UInt"), NumPut(0x4619B909, &GUID_DEVICE_POWER_POLICY_VIDEO_BRIGHTNESS, 4, "UInt")
NumPut(0xD7F54999, &GUID_DEVICE_POWER_POLICY_VIDEO_BRIGHTNESS, 8, "UInt"), NumPut(0xCB0BAC1D, &GUID_DEVICE_POWER_POLICY_VIDEO_BRIGHTNESS, 12, "UInt")
DllCall("powrprof\PowerReadACValueIndex", Ptr,0, Ptr,vActivePolicyGuid, Ptr,&GUID_VIDEO_SUBGROUP, Ptr,&GUID_DEVICE_POWER_POLICY_VIDEO_BRIGHTNESS, UIntP,vBrightnessAC, UInt)
DllCall("powrprof\PowerReadDCValueIndex", Ptr,0, Ptr,vActivePolicyGuid, Ptr,&GUID_VIDEO_SUBGROUP, Ptr,&GUID_DEVICE_POWER_POLICY_VIDEO_BRIGHTNESS, UIntP,vBrightnessDC, UInt)
;e.g. 46 40
if InStr(A_ThisHotkey, "F13")
;MsgBox, % "AC brightness: " vBrightnessAC "`r`n" "DC brightness: " vBrightnessDC
if InStr(A_ThisHotkey, "F14")
{
;InputBox, vBrightnessAC2,, % vPrompt,,,,,,,, % vBrightnessAC
if !(vBrightnessAC2 = vBrightnessAC)
{
DllCall("powrprof\PowerWriteACValueIndex", Ptr,0, Ptr,vActivePolicyGuid, Ptr,&GUID_VIDEO_SUBGROUP, Ptr,&GUID_DEVICE_POWER_POLICY_VIDEO_BRIGHTNESS, UInt,vBrightnessAC2, UInt)
DllCall("powrprof\PowerSetActiveScheme", Ptr,0, Ptr,vActivePolicyGuid, UInt)
}
}
if InStr(A_ThisHotkey, "F15")
{
;InputBox, vBrightnessDC2,, % vPrompt,,,,,,,, % vBrightnessDC
if !(vBrightnessDC2 = vBrightnessDC)
{
DllCall("powrprof\PowerWriteDCValueIndex", Ptr,0, Ptr,vActivePolicyGuid, Ptr,&GUID_VIDEO_SUBGROUP, Ptr,&GUID_DEVICE_POWER_POLICY_VIDEO_BRIGHTNESS, UInt,vBrightnessDC2, UInt)
DllCall("powrprof\PowerSetActiveScheme", Ptr,0, Ptr,vActivePolicyGuid, UInt)
}
}
return
