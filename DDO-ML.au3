#AutoIt3Wrapper_icon=icon.ico

#include <String.au3>
#include <Crypt.au3>
#include <GUIConstantsEx.au3>
#include <WindowsConstants.au3>
#include <Array.au3>
#include <Constants.au3>
#include <_XMLDomWrapper.au3>
#include <ListViewConstants.au3>
#include <GuiListView.au3>
#include <File.au3>

$xml_file = "ddo-ml.xml"
$ini_file = "ddo-ml.ini"

Opt("trayautopause", 0)
Opt("TrayMenuMode", 3)
Opt("TrayOnEventMode", 1)
Opt("GUIOnEventMode", 1)
$background_launch = 0
$gui = 0
$patch_gui = 0

$login_timeout = 1200000

$set_directory_item = TrayCreateItem("Set Directory")
TrayItemSetOnEvent(-1, "set_directory")
Func set_directory()
	IniWrite($ini_file, "Startup", "directory", stringReplace(FileSelectFolder("Locate DDO Folder", ""), "\","\\"))
	TrayItemSetState($set_directory_item, $TRAY_UNCHECKED)
EndFunc   ;==>set_directory

$set_server_item = TrayCreateItem("Set Server")
TrayItemSetOnEvent(-1, "set_server")
Func set_server()
	IniWrite($ini_file, "Startup", "server", InputBox("Question", "Choose Server:", "khyber", ""))
	TrayItemSetState($set_server_item, $TRAY_UNCHECKED)
EndFunc   ;==>set_server

$background_launch_item = TrayCreateItem("Background Launch")
TrayItemSetOnEvent(-1, "set_background_launch")

$delete_Awesomium = TrayCreateItem("Delete Awesomium")
TrayItemSetOnEvent(-1, "delete_Awesomium")

$restore_Awesomium = TrayCreateItem("Restore Awesomium")
TrayItemSetOnEvent(-1, "restore_Awesomium")

$kill_Awesomium = TrayCreateItem("Kill Awesomium")
TrayItemSetOnEvent(-1, "kill_Awesomium")

$encrypt = TrayCreateItem("Encrypt Passwords")
TrayItemSetOnEvent(-1, "encrypt")

Func set_background_launch()
	$background_launch = Abs($background_launch - 1)
	If $background_launch == 0 Then
		TrayItemSetState($background_launch_item, $TRAY_UNCHECKED)
	Else
		TrayItemSetState($background_launch_item, $TRAY_CHECKED)
	EndIf
EndFunc   ;==>set_background_launch

$exit_item = TrayCreateItem("Exit")
TrayItemSetOnEvent(-1, "_exit")
Func _exit()
	if $gui <> 0 then
	$pos = wingetpos($gui)
	IniWrite($ini_file, "startup", "x", $pos[0])
	IniWrite($ini_file, "startup", "y", $pos[1])
	$pos = wingetclientsize($gui)
	IniWrite($ini_file, "startup", "width", $pos[0])
	IniWrite($ini_file, "startup", "height", $pos[1])
EndIf

	Exit 0
EndFunc   ;==>_exit

If IniRead($ini_file, "startup", "ckey", "") == "" Then
   $ckey = ""
   Dim $aSpace[3]
   $digits = 15
   For $i = 1 To $digits
	   $aSpace[0] = Chr(Random(65, 90, 1)) ;A-Z
	   $aSpace[1] = Chr(Random(97, 122, 1)) ;a-z
	   $aSpace[2] = Chr(Random(48, 57, 1)) ;0-9
	   $ckey &= $aSpace[Random(0, 2, 1)]
   Next
   IniWrite($ini_file, "startup", "ckey", $ckey)
EndIf
$ckey = IniRead($ini_file, "startup", "ckey", "")

If IniRead($ini_file, "startup", "firstlaunch", "1") == 1 Then
	IniWrite($ini_file, "startup", "firstlaunch", "0")
	set_directory()
	set_server()
EndIf
$ddo_folder = IniRead($ini_file, "startup", "directory", "C:\\Program Files (x86)\\Turbine\\DDO Unlimited")
$server = IniRead($ini_file, "startup", "server", "khyber")

$debug = IniRead($ini_file, "startup", "debug", "0")

If _XMLFileOpen($xml_file) == -1 Then
	_XMLCreateFile($xml_file, "root", False)
EndIf

;account, pass, rename (optional), char (optional)
$short_count = _XMLGetNodeCount("root/shortcut")

Dim $labels[$short_count]
For $i = 1 To $short_count Step 1
	$labels[$i - 1] = _xmlGetattrib("shortcut[" & $i & "]", "label")
Next
$x = IniRead($ini_file, "startup", "x", "-1")
$y = IniRead($ini_file, "startup", "y", "-1")
$width = IniRead($ini_file, "startup", "width", "140")
$height = IniRead($ini_file, "startup", "height", "180")
$gui = GUICreate("DDO-ML", $width, $height, $x, $y, BitOR($GUI_SS_DEFAULT_GUI, $WS_SIZEBOX), BitOR($WS_EX_TOOLWINDOW,$WS_EX_TOPMOST,0x08000000))
WinSetTrans($gui, "", 200)
$aiGUISize = WinGetClientSize($gui)

$sList = GUICtrlCreateListView("", 0, 0, $aiGUISize[0], $aiGUISize[1], BitOR($LVS_REPORT, $LVS_SINGLESEL, $LVS_NOSORTHEADER, $LVS_NOSCROLL))
GUICtrlSetFont(-1, 8)
_GUICtrlListView_AddColumn($sList, "Ver. 0.1", 180)

Dim $label_controls[$short_count]
For $i = 1 To $short_count Step 1
	$label_controls[$i - 1] = GUICtrlCreateListViewItem($labels[$i - 1], $sList)
	GUICtrlSetOnEvent(-1, "launch")
Next
GUICtrlCreateListViewItem(" ", $sList)
;$add_new_item = GUICtrlCreateListViewItem("(Add New)", $sList)
$close_item = GUICtrlCreateListViewItem("(Close Background)", $sList)
GUICtrlSetOnEvent(-1, "close_background")

$close_item = GUICtrlCreateListViewItem("(Patch Game)", $sList)
GUICtrlSetOnEvent(-1, "patch_game")

GUISetOnEvent($GUI_EVENT_CLOSE, "_exit")
GUISetState(@SW_SHOW)

$locktimer = 0
$lock = 0
$active = 0

While 1
	If $lock == 1 And TimerDiff($locktimer) > 7000 Then
		WinSetOnTop($active, "", 0)
		$lock = 0
		WinSetOnTop($gui, "", 1)
	ElseIf $lock == 0 Then
		$temp = WinGetHandle("[ACTIVE]")
		If WinActive("[CLASS:Turbine Device Class]") Then
			$active = $temp
			;winsetontop($gui,"",1)
		EndIf
	EndIf
	Sleep(100)
WEnd

Func launch()
	$shortcut = _GUICtrlListView_GetItemTextString($sList)
	_GUICtrlListView_SetColumn($sList, 0, "Start... " & $shortcut)
	$i = 0
	For $i = 1 To $short_count Step 1
		If _xmlGetattrib("shortcut[" & $i & "]", "label") == $shortcut Then
			ExitLoop
		EndIf
	Next
	$acc_count = _XMLGetNodeCount("root/shortcut[" & $i & "]/account")
	Dim $py_out[$acc_count]
	Dim $rename[$acc_count]
	Dim $pid[$acc_count]
	Dim $character[$acc_count]
	For $acc = 1 To $acc_count Step 1
		$user = _xmlGetattrib("shortcut[" & $i & "]/account[" & $acc & "]", "user")
		$pass = _xmlGetattrib("shortcut[" & $i & "]/account[" & $acc & "]/pass", "value")
		$subscription = _xmlGetattrib("shortcut[" & $i & "]/account[" & $acc & "]/subscription", "value")
		if @error Then
		   $subscription = ""
		EndIf
		if $pass == "" Then
		   $pass = _xmlGetattrib("shortcut[" & $i & "]/account[" & $acc & "]/pass", "encrypted_value")
		   $pass = _HexToString ( $pass )
		   $pass = _Crypt_DecryptData ( $pass, $ckey, $CALG_AES_256 )
		   ;consolewrite($pass & @CRLF)
		   $pass = binarytostring($pass)
		   ;consolewrite($pass)
		EndIf
		$rename[$acc - 1] = _xmlGetattrib("shortcut[" & $i & "]/account[" & $acc & "]/rename", "value")
		$character[$acc - 1] = _xmlGetattrib("shortcut[" & $i & "]/account[" & $acc & "]/character", "value")
		$tempstring = 'ddolauncher.exe' & ' -s ' & $server & ' -g "' & $ddo_folder & '" -u "' & $user & '" -a "' & $pass & '" -z "' & $subscription & '"'

		 if $debug == 1 Then
			_FileWriteLog ( "debug.txt", $tempstring )
		 EndIf

		$py_handle = Run($tempstring, "", @SW_HIDE, 0x6)
		_GUICtrlListView_SetColumn($sList, 0, "Login " & $user)
		local $timer = timerInit()
		While 1
			$py_out[$acc - 1] = $py_out[$acc - 1] & StdoutRead($py_handle)
			If @error Then ExitLoop
			sleep(100)
			if TimerDiff($timer) > $login_timeout Then
				_GUICtrlListView_SetColumn($sList, 0, "Auth. timeout " & $user)
				consoleWrite($py_out[$acc - 1])
				ExitLoop
				;to do: write log file
			EndIf
		WEnd

		 if $debug == 1 Then
			_FileWriteLog ( "debug.txt", $py_out[$acc - 1] )
		 EndIf
	Next

	If $background_launch == 1 Then
		WinActivate($active)
		_LockSetFGWin(1)
		WinSetOnTop($active, "", 1)
	EndIf
	For $acc = 1 To $acc_count Step 1
		If Not StringInStr($py_out[$acc - 1] , "dndclient.exe") Then
			_GUICtrlListView_SetColumn($sList, 0, "Error " & $user)
			;Exit 1
		Else
			If $character[$acc - 1] <> "" Then
				$py_out[$acc - 1]  = $py_out[$acc - 1]  & " -u " & $character[$acc - 1]
			EndIf
			_GUICtrlListView_SetColumn($sList, 0, "Launching client " & $user)
			$pid = Run($ddo_folder & "\\" & $py_out[$acc - 1], $ddo_folder)
			Run('ddoclient_wrapper.exe' & ' ' & $pid & ' "' & $rename[$acc - 1] & '"' )
		;$pid = RunWait("ddoclient_wrapper.exe " & $ddo_folder & " " & $rename[$acc - 1] & ' "' & $character[$acc - 1] & '" "' & $tempstring & '"')
		EndIf
	Next
	If $background_launch == 1 Then
		$locktimer = TimerInit()
		$lock = 1
	EndIf
	while(processExists("ddoclient_wrapper.exe"))
		sleep(100)
	WEnd
	_GUICtrlListView_SetColumn($sList, 0, "Done... " & $shortcut)
EndFunc   ;==>launch

Func close_background()
	;to do: also close any remaining wrappers
	$ddowindows = WinList("[CLASS:Turbine Device Class]")
	For $i = 1 To $ddowindows[0][0]

		If $ddowindows[$i][1] <> $active Then
			WinKill($ddowindows[$i][1])
			ProcessClose(WinGetProcess($ddowindows[$i][1]))
		EndIf
	Next
	_GUICtrlListView_SetColumn($sList, 0, "Done... closed")
EndFunc   ;==>close_background

Func _deletepatchgui()
	GUIDelete($patch_gui)
EndFunc
Func patch_game()
	$patch_gui = GuiCreate("Patch Window", 400,300)
	$patch_edit = GuiCtrlCreateEdit("",0,0,400,300)
	GUISetState(@SW_SHOW)
	;$py_handle = Run("ddolauncher.exe -p -g " & $ddo_folder)
	GUICtrlSetData($patch_edit, @CRLF & "***Starting Patch Process***")
	$py_handle = Run(@ComSpec & ' /c ddolauncher.exe -p -g "' & $ddo_folder & '"',@workingdir,@sw_hide,0x6)
	While 1
		$patch_text = StdoutRead($py_handle)
		If @error Then ExitLoop
		sleep(1000)
		GUICtrlSetData($patch_edit, @CRLF & $patch_text & "..." & GUICtrlRead($patch_edit))
	WEnd
	GUICtrlSetData($patch_edit,"***DONE***" & @CRLF & GUICtrlRead($patch_edit))
	GUISetOnEvent($GUI_EVENT_CLOSE, "_deletepatchgui")
EndFunc

Func delete_Awesomium()
	;make backup if DNE
	DirRemove( $ddo_folder & "\AwesomiumProcess.exe" )
	if(FileExists ( $ddo_folder & "\AwesomiumProcess.exe" )) Then
		FileCopy($ddo_folder & "\AwesomiumProcess.exe",$ddo_folder & "\AwesomiumProcess.bak") ;should not overwrite if exists
		FileDelete( $ddo_folder & "\AwesomiumProcess.exe" )
	EndIf
	;delete
EndFunc

Func restore_Awesomium()
	;restore from backup
	DirRemove( $ddo_folder & "\AwesomiumProcess.exe" )
	if(FileExists ( $ddo_folder & "\AwesomiumProcess.bak" )) Then
		FileCopy($ddo_folder & "\AwesomiumProcess.bak",$ddo_folder & "\AwesomiumProcess.exe") ;should not overwrite if exists
	EndIf
EndFunc

Func kill_Awesomium()
	;restore from backup
	while(ProcessExists("AwesomiumProcess.exe"))
		ProcessClose("AwesomiumProcess.exe")
	WEnd
EndFunc


;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

Func _LockSetFGWin($nLock = 0)
	Local Const $LSFW_LOCK = 1
	Local Const $LSFW_ULOCK = 2
	If $nLock Then
		$nLock = $LSFW_LOCK
	Else
		$nLock = $LSFW_ULOCK
	EndIf
	Local $aDLLLock = DllCall("USER32.DLL", "int", "LockSetForegroundWindow", "uint", $nLock)
	If IsArray($aDLLLock) And $aDLLLock[0] > 0 Then Return 1
	Return SetError(1, 0, 0)
EndFunc   ;==>_LockSetFGWin

Func _ProcessGetHWnd($iPid, $iOption = 1, $sTitle = "", $iTimeout = 2000)
	Local $aReturn[1][1] = [[0]], $aWin, $hTimer = TimerInit()

	While 1

		; Get list of windows
		$aWin = WinList($sTitle)

		; Searches thru all windows
		For $i = 1 To $aWin[0][0]

			; F*ound a window owned by the given PID
			If $iPid = WinGetProcess($aWin[$i][1]) Then

				; Option 0 or 1 used
				If $iOption = 1 Or ($iOption = 0 And $aWin[$i][0] <> "") Then
					Return $aWin[$i][1]

					; Option 2 is used
				ElseIf $iOption = 2 Then
					ReDim $aReturn[UBound($aReturn) + 1][2]
					$aReturn[0][0] += 1
					$aReturn[$aReturn[0][0]][0] = $aWin[$i][0]
					$aReturn[$aReturn[0][0]][1] = $aWin[$i][1]
				EndIf
			EndIf
		Next

		; If option 2 is used and there was matches then the list is returned
		If $iOption = 2 And $aReturn[0][0] > 0 Then Return $aReturn

		; If timed out then give up
		If TimerDiff($hTimer) > $iTimeout Then ExitLoop

		; Waits before new attempt
		Sleep(Opt("WinWaitDelay"))
	WEnd


	; No matches
	SetError(1)
	Return 0
EndFunc   ;==>_ProcessGetHWnd



;;;;encryption stuff

func encrypt()
   $filename = @workingdir & "\\" & $xml_file
   $oXML = _CreateMSXMLObj()
   If Not IsObj($oXML) Then
	   MsgBox(0, "_CreateMSXMLObj()", "ERROR!: Unable to create MSXML Object!!", 10)
	   Exit 1
   EndIf

   $oXML.async = False
   $error = $oXML.Load ($filename)
   If Not $error Then
	   MsgBox(0, "Load XML", "An error occurred loading " & $filename, 10)
	   Exit 1
   EndIf

   $root = $oXML.documentElement

   For $shortcut In $root.childNodes
	  for $account in $shortcut.childNodes
		 $pass = $account.selectsinglenode("pass")
			$pass_value = $pass.getAttribute("value")
			if $pass_value <> "" then
			   $pass_encrypted_value = _Crypt_EncryptData ( $pass_value, $ckey, $CALG_AES_256 )
			   $pass_encrypted_value = Hex ($pass_encrypted_value)
			   $pass.setAttribute ("encrypted_value", $pass_encrypted_value)
			   $pass.setAttribute ("value", "")
			EndIf
	   next
   Next
   $oXML.Save ($filename)
EndFunc

Func _CreateMSXMLObj() ; Creates a MSXML instance depending on the version installed on the system
    $xmlObj = ObjCreate("Msxml2.DOMdocument.6.0") ; Latest available, default in Vista
    If IsObj($xmlObj) Then Return $xmlObj

    $xmlObj = ObjCreate("Msxml2.DOMdocument.5.0") ; Office 2003
    If IsObj($xmlObj) Then Return $xmlObj

    $xmlObj = ObjCreate("Msxml2.DOMdocument.4.0")
    If IsObj($xmlObj) Then Return $xmlObj

    $xmlObj = ObjCreate("Msxml2.DOMdocument.3.0") ; XP and w2k3 server
    If IsObj($xmlObj) Then Return $xmlObj

    $xmlObj = ObjCreate("Msxml2.DOMdocument.2.6") ; Win98 ME...
    If IsObj($xmlObj) Then Return $xmlObj

    Return 0
EndFunc   ;==>_CreateMSXMLObj