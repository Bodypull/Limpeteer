#Region ;**** Directives created by AutoIt3Wrapper_GUI ****
#AutoIt3Wrapper_Icon=..\..\..\..\..\..\Program Files (x86)\AutoIt3\Aut2Exe\Icons\AutoIt_Main_v10_256x256_RGB-A.ico
#AutoIt3Wrapper_Outfile=Limpeteer.Exe
#AutoIt3Wrapper_Res_Fileversion=1.0.5.0
#EndRegion ;**** Directives created by AutoIt3Wrapper_GUI ****
#include <Date.au3>
#include <GUIConstantsEx.au3>
#include <StructureConstants.au3>
#include <WindowsConstants.au3>
#include <StaticConstants.au3>
#include <Array.au3>
#include <GuiStatusBar.au3>
#include <SQLite.au3>
#include <Misc.au3>
#include <Winapi.au3>
#include <GuiListView.au3>
#include <GuiEdit.au3>
#include <Inet.au3>
#include <GuiComboBox.au3>
#include "ExtMsgBox.au3"
#include <Misc.au3>
#include "_Tools.au3"

; Credits to inara for providing data

_ExtMsgBoxSet(2+4+32)

If _Singleton("Limpeteer", 1) = 0 Then
	_ExtMsgBox($EMB_ICONSTOP, "Close", "", "Another Instance of Limpeteer os already running")
	Exit
EndIf

Opt("TrayIconHide", 1) ;0=show, 1=hide tray icon
Opt("GUICloseOnESC", 0) ;1=ESC  closes, 0=ESC won't close

Global $TimerCheckJournal
Global $LastFilePointer = -1
Global $LastFileTimeString = -1
Global $LastTimeStamp = -1
Global $LastContent = -1
Global $WatchFile = -1
Global $sKeppEvents = "BuyDrones,CollectCargo,Died,EjectCargo,EngineerCraft,MarketBuy,MarketSell,MaterialCollected,MaterialDiscarded,MiningRefined,MissionAccepted,MissionCompleted,SellDrones,Synthesis"
Global $fIni = @ScriptDir & "\settings.ini"
Global $Path = IniRead($fIni, "PATH", "JOURNAL", @UserProfileDir & "\Saved Games\Frontier Developments\Elite Dangerous\")
Global $ParseCommmodities = IniRead($fIni, "SETTINGS", "Parse Commodities", 0)

IniWrite($fIni, "SETTINGS", "Parse Commodities", $ParseCommmodities)

$Gui = GUICreate("Limpeteer", 400, 370, IniRead($fIni, "WINPOS", "GUIX", -1), IniRead($fIni, "WINPOS", "GUIY", -1))
$WinPos = WinGetPos($Gui)
$ClientSize = WinGetClientSize($Gui)


$MenuFile = GUICtrlCreateMenu("File")
$MenuFileExport = GUICtrlCreateMenuItem("Export CSV", $MenuFile)
GUICtrlCreateMenuItem("", $MenuFile)
$MenuFileRebuild = GUICtrlCreateMenuItem("Rebuild Database", $MenuFile)
GUICtrlCreateMenuItem("", $MenuFile)
$MenuFileClose = GUICtrlCreateMenuItem("Exit", $MenuFile)
$MenuView = GUICtrlCreateMenu("View")
$MenuViewMaterials = GUICtrlCreateMenuItem("Show Materials", $MenuView)

$MenuSetting = GUICtrlCreateMenu("Settings")
$MenuSettingsShowZeros = GUICtrlCreateMenuItem("List Zero Counts", $MenuSetting)
If IniRead($fIni, "SETTINGS", "Show Zeros", 0) = 1 Then
	GUICtrlSetState($MenuSettingsShowZeros, $GUI_CHECKED)
EndIf
$MenuSettingsParseCommodities = GUICtrlCreateMenuItem("Parse Commodities", $MenuSetting)
If $ParseCommmodities = 1 Then
	GUICtrlSetState($MenuSettingsParseCommodities, $GUI_CHECKED)
EndIf

$MenuHelp = GUICtrlCreateMenu("Help")
$MenuHelpAbout = GUICtrlCreateMenuItem("About", $MenuHelp)

$GroupBluePrints = GUICtrlCreateGroup("Blueprints", 10, 10, 380, 150)
GUICtrlCreateLabel("Category", 20, 32)
$ComboCat = GUICtrlCreateCombo("Any", 120, 30, 250)
GUICtrlCreateLabel("Modifiaction", 20, 62)
$ComboMod = GUICtrlCreateCombo("Any", 120, 60, 250)
GUICtrlCreateLabel("Engineer / Grade", 20, 92)
$ComboEng = GUICtrlCreateCombo("Any", 120, 90, 180)
$ComboLvl = GUICtrlCreateCombo("Any", 310, 90, 60)
$ButtonShow = GUICtrlCreateButton("Show", 120, 120, 100)
$ButtonReset = GUICtrlCreateButton("Reset", 270, 120, 100)
GUICtrlCreateGroup("", -99, -99, 1, 1)

$StatusBar = _GUICtrlStatusBar_Create($Gui)

$EditDebug = _GUICtrlEdit_Create($Gui, "", 0, $ClientSize[1]-150-45, $ClientSize[0], 150)

_SQLite_Startup()

Global $DbED = _SQLite_Open("edmat.db")
If $DbED = 0 Then
	If _ExtMsgBox($EMB_ICONSTOP, "Exit|Ignore", @ScriptName, "Error opening Database @error: " & @error & " Extended: " & @extended & " Message: " & _SQLite_ErrMsg($DbED), 0) = 1 Then _Exit()
EndIf

_PopCombo()
GUISetState()


$GuiMaterials = GUICreate("Data / Materials", IniRead($fIni, "WINPOS", "MATW", 600), IniRead($fIni, "WINPOS", "MATH", 600), IniRead($fIni, "WINPOS", "MATX", $WinPos[0]+100), IniRead($fIni, "WINPOS", "MATY", $WinPos[1]+50), $WS_MAXIMIZEBOX+$WS_MINIMIZEBOX+$WS_SIZEBOX, "")
$ClientSize = WinGetClientSize($GuiMaterials)
$lvMaterials = GUICtrlCreateListView("", 0, 0,  $ClientSize[0], $ClientSize[1], $LVS_REPORT+$LVS_EDITLABELS, $LVS_EX_GRIDLINES+$LVS_EX_FULLROWSELECT)


$GuiBlueprints = GUICreate("Blueprints", IniRead($fIni, "WINPOS", "BLUW", 600), IniRead($fIni, "WINPOS", "BLUH", 300), IniRead($fIni, "WINPOS", "BLUX", -1), IniRead($fIni, "WINPOS", "BLUY", -1), $WS_MAXIMIZEBOX+$WS_MINIMIZEBOX+$WS_SIZEBOX)
$ClientSize = WinGetClientSize($GuiBlueprints)
$lvBlueprints = GUICtrlCreateListView("", 0, 0, $ClientSize[0], $ClientSize[1], $LVS_REPORT, $LVS_EX_GRIDLINES+$LVS_EX_FULLROWSELECT)

$g_hListViewMat = GUICtrlGetHandle($lvMaterials)
$g_hListViewBP = GUICtrlGetHandle($lvBlueprints)

_GUICtrlListView_RegisterSortCallBack($lvMaterials)
_GUICtrlListView_RegisterSortCallBack($lvBlueprints)

If Not @Compiled Then HotKeySet("{F5}", "_Exit")
;~ _ResetDB()
_ParseJournal()
_CountCommodities()
_CountMaterials()
_PopLVmaterials()

While 1
	$msg = GUIGetMsg(1)
	Switch $msg[0]
		Case $GUI_EVENT_CLOSE, $MenuFileClose
			If $msg[1] = $Gui Then
				_Exit()
			Else
				GUISetState(@SW_HIDE, $msg[1])
			EndIf
		Case $MenuFileRebuild
			_ResetDB()
		Case $MenuViewMaterials
			GUISetState(@SW_SHOW, $GuiMaterials)
		Case $lvMaterials
			_GUICtrlListView_SortItems($lvMaterials, GUICtrlGetState($lvMaterials))
		Case $lvBlueprints
			_GUICtrlListView_SortItems($lvBlueprints, GUICtrlGetState($lvBlueprints))
		Case $ComboCat
			_PopCombo($msg[0])
		Case $ComboMod
			_PopCombo($msg[0])
		Case $ComboEng
			_PopCombo($msg[0])
		Case $ComboLvl
			_PopCombo($msg[0])
		Case $ButtonReset
			_ResetFilter()
		Case $ButtonShow
			_ShowBluePrint()
		Case $MenuHelpAbout
			If _ExtMsgBox($EMB_ICONINFO, "Visit|Close", "About", "Limpeteer Version: " & FileGetVersion(@ScriptFullPath) & @CRLF & @CRLF & "Material parser for Elite Dangerous v2.2.02" & @CRLF & @CRLF & "Developed by Bodypull" & @CRLF & @CRLF & "https://github.com/Bodypull/Limpeteer", 0, $Gui) = 1 Then
				ShellExecute("https://github.com/Bodypull/Limpeteer")
			EndIf
		Case $MenuFileExport
			_ExportCSV()
		Case $MenuSettingsShowZeros
			If BitAND(GUICtrlRead($MenuSettingsShowZeros), $GUI_CHECKED) = $GUI_CHECKED Then
				GUICtrlSetState($MenuSettingsShowZeros, $GUI_UNCHECKED)
			Else
				GUICtrlSetState($MenuSettingsShowZeros, $GUI_CHECKED)
			EndIf
			_PopLVmaterials()
		Case $MenuSettingsParseCommodities
			If BitAND(GUICtrlRead($MenuSettingsParseCommodities), $GUI_CHECKED) = $GUI_CHECKED Then
				GUICtrlSetState($MenuSettingsParseCommodities, $GUI_UNCHECKED)
				$ParseCommmodities = 0
			Else
				GUICtrlSetState($MenuSettingsParseCommodities, $GUI_CHECKED)
				$ParseCommmodities = 1
				_CountCommodities()
			EndIf
			_PopLVmaterials()
	EndSwitch

	If TimerDiff($TimerCheckJournal) > 500 Then
		$TimerCheckJournal = TimerInit()
		$hED = WinGetHandle("Elite - Dangerous (CLIENT)")
		If $hED <> 0 Then
			If WinActive($hED) Then
				If _ParseJournal() Then
					_CountCommodities()
					_CountMaterials()
					_PopLVmaterials()
				EndIf
			EndIf
		Else
			$WatchFile = -1
			$LastFilePointer = -1
		EndIf
	EndIf
WEnd

Func _ShowInara($Item, $hLV)
	If $hLV = $g_hListViewMat Then
		_DB("HERE")
		$Query = "SELECT inaraID FROM components WHERE name = " & _SQLite_Escape(_GUICtrlListView_GetItemText($lvMaterials, $Item, 1))
		$aResult = _GetTable($Query, $DbED)
		If UBound($aResult) > 1 And Number($aResult[1][0]) > 0 Then
			ShellExecute("http://inara.cz/galaxy-component/" & $aResult[1][0])
		EndIf
	ElseIf $hLV = $g_hListViewBP Then
		If Number(_GUICtrlListView_GetItemText($lvBlueprints, $Item, 1)) > 0 Then
			ShellExecute("http://inara.cz/galaxy-blueprint/" & _GUICtrlListView_GetItemText($lvBlueprints, $Item, 1))
		EndIf
	EndIf
EndFunc

Func _EditItem($Item)
	$Input = _GUICtrlListView_GetItemText($lvMaterials, $Item)
	If $Input = $gValue Then
		Return
	EndIf
	If Not StringIsDigit($Input) Then
		_DB($Input & " Only Digits accepted", 1)
		_GUICtrlListView_SetItemText($lvMaterials, $Item, $gValue)
		Return
	Else
		If _GUICtrlListView_GetItemGroupID($lvMaterials, $Item) = 1 Then
			$Query = "UPDATE cargo "
		Else
			$Query = "UPDATE materials "
		EndIf
		$Query &= "SET count = " & $Input & " WHERE LOWER(name) = " & _SQLite_Escape(StringLower(_GUICtrlListView_GetItemText($lvMaterials, $Item, 5)))
		_Execute($Query, $DbED)
		If @error Then
			_DB("Update failed", 1)
		Else
			_DB($gValue &  " --> " & $Input & " " & _GUICtrlListView_GetItemText($lvMaterials, $Item, 1) & " (" & _GUICtrlListView_GetItemText($lvMaterials, $Item, 5) & ")", 1)
			_ExportCSV(False)
		EndIf
	EndIf
	$gEdit = ""
EndFunc

Func _ExportCSV($User=True)
	If $User Then
		$File = FileSaveDialog("Export CSV", "::{450D8FBA-AD25-11D0-98A8-0800361B1103}" , "CSV (*.csv)",  $FD_PATHMUSTEXIST+ $FD_PROMPTOVERWRITE, "Limpeteer Export.csv", $Gui)
		If @error Then Return
	Else
		$File = @ScriptDir & "\" & "Backup v" & FileGetVersion(@ScriptFullPath) & ".csv"
	EndIf

	$Query = ""
	$Query &= "SELECT "
	$Query &= "count AS 'Count ', "
	$Query &= "CASE WHEN clearNames.clearName IS NOT NULL THEN clearNames.clearName ELSE components.name END AS 'Name                   ', "
	$Query &= "category AS 'Category   ', "
	$Query &= "COUNT(blueprintID) AS 'hide', "
	$Query &= "components.grade AS 'Grade      ', "
	$Query &= "materials.name AS 'Encoded Name ' "
	$Query &= "FROM materials "
	$Query &= "LEFT JOIN clearNames ON LOWER(clearNames.name) = LOWER(materials.name) "
	$Query &= "LEFT JOIN components ON clearNames.clearName = components.name OR LOWER(REPLACE(components.name, ' ', '')) = LOWER(materials.name) "
	$Query &= "LEFT JOIN ingredients ON ingredients.component = components.inaraID "
	$Query &= "WHERE count >= 0 "
	$Query &= "GROUP BY materials.name "

	If $ParseCommmodities > 0 Then
		$Query &= "UNION ALL "

		$Query &= "SELECT "
		$Query &= "count AS 'Count ', "
		$Query &= "CASE WHEN clearNames.clearName IS NOT NULL THEN clearNames.clearName ELSE CASE WHEN components.name IS NOT NULL THEN components.name ELSE commodities.name END END AS 'Name                   ', "
		$Query &= "CASE WHEN components.type IS NOT NULL THEN components.type ELSE commodities.cat_name || ' (Commodity)' END AS 'Category      ', "
		$Query &= "COUNT(blueprintID) AS 'hide', "
		$Query &= "CASE WHEN components.grade IS NOT NULL THEN components.grade ELSE '' END AS 'Grade     ', "
		$Query &= "cargo.name AS 'Encoded Name ' "
		$Query &= "FROM cargo "
		$Query &= "LEFT JOIN clearNames ON LOWER(clearNames.name) = LOWER(cargo.name) "
		$Query &= "LEFT JOIN components ON clearNames.clearName = components.name OR LOWER(REPLACE(components.name, ' ', '')) = LOWER(cargo.name) "
		$Query &= "LEFT JOIN commodities ON clearNames.clearName = commodities.name OR LOWER(REPLACE(commodities.name, ' ', '')) = LOWER(cargo.name) "
		$Query &= "LEFT JOIN ingredients ON ingredients.component = components.inaraID "
		$Query &= "WHERE count >= 0 "
		$Query &= "GROUP BY cargo.name "
	EndIf

	$aResult = _GetTable($Query, $DbED)
	If @error Then
		_DB(_SQLite_ErrMsg($DbED), 1)
		Return
	EndIf

	_ArraySort($aResult, 0, 1, 0, 1)

	$sCSV = ""
	For $i = 0 To UBound($aResult)-1
		For $j = 0 To UBound($aResult, 2)-1
			$sCSV &= $aResult[$i][$j]
			If $j < UBound($aResult, 2)-1 Then $sCSV &= ","
		Next
		$sCSV &= @CRLF
	Next
	$hFile = FileOpen($File, $FO_OVERWRITE)
	If FileWrite($hFile, $sCSV) = 1 Then
		If $User Then _DB(UBound($aResult)-2 & " Entries exported", 1)
	Else
		_DB("Failed to write to " & $File, 1)
	EndIf
	FileClose($hFile)
EndFunc

Func _ShowBluePrint()
	$Query = "SELECT "
	$Query &= "'Yes    ' AS 'Can Craft   ', "
	$Query &= "blueprints.inaraID AS 'hide', "
	$Query &= "blueprints.type AS 'Category      ', "
	$Query &= "modification AS 'Modification            ', "
	$Query &= "grade AS 'Grade ', "
	$Query &= "engineer AS 'Engineer   ' "
	$Query &= "FROM blueprints "
	$Query &= "JOIN ingredients ON blueprintID = blueprints.inaraID "
	If GUICtrlRead($ComboLvl) <> "Any" Then $Query &= "AND ingredients.grade = " & GUICtrlRead($ComboLvl) & " "
	$Query &= "JOIN engineers ON engineers.type = blueprints.type "
	$Query &= "AND engineers.maxGrade >= ingredients.grade "
	If GUICtrlRead($ComboLvl) <> "Any" Then $Query &= "AND CAST(maxGrade AS int) >= " & GUICtrlRead($ComboLvl) & " "
	If GUICtrlRead($ComboEng) <> "Any" Then $Query &= "AND engineer = " & _SQLite_Escape(GUICtrlRead($ComboEng)) & " "
	$Query &= "WHERE blueprints.inaraID IS NOT NULL "
	If GUICtrlRead($ComboCat) <> "Any" Then $Query &= "AND blueprints.type = " & _SQLite_Escape(GUICtrlRead($ComboCat)) & " "
	If GUICtrlRead($ComboMod) <> "Any" Then $Query &= "AND modification = " & _SQLite_Escape(GUICtrlRead($ComboMod)) & " "
	If GUICtrlRead($ComboEng) <> "Any" Then $Query &= "AND engineers LIKE " & _SQLite_Escape("%" & GUICtrlRead($ComboEng) & "%") & " "
	$Query &= "GROUP BY blueprints.type, modification, grade, engineer "
	$aResult = _GetTable($Query, $DbED)

	$Columns = UBound($aResult, 2)
	ReDim $aResult[UBound($aResult)][UBound($aResult,2)+8]
	For $i = $Columns To UBound($aResult, 2)-2 Step 2
		$aResult[0][$i] = "Ingredient"
		$aResult[0][$i+1] = "Available"
	Next

	For $i = 1 To UBound($aResult)-1
		_SB("Building " & $i & " of " & UBound($aResult)-1 & " Blueprints")
		$Query = "SELECT name, location FROM ingredients JOIN components ON inaraID = component WHERE blueprintID = " & $aResult[$i][1] & " AND ingredients.grade = " & $aResult[$i][4]
		$aComponents = _GetTable($Query, $DbED)
		For $j = 1 To UBound($aComponents)-1
			$aResult[$i][$Columns + ($j-1) * 2] = $aComponents[$j][0]
			$Query = "SELECT count FROM materials JOIN clearNames ON clearNames.name = materials.name AND clearName = " & _SQLite_Escape($aComponents[$j][0])

			$aResult[$i][$Columns + ($j-1) * 2 + 1] = $aComponents[$j][1]
			$aCount = _GetTable($Query, $DbED)
			If UBound($aCount) > 1 Then
				If $aCount[1][0] > 0 Then
					$aResult[$i][$Columns + ($j-1) * 2] = "[" & $aCount[1][0] & "] " & $aResult[$i][$Columns + ($j-1) * 2]
					$aResult[$i][$Columns + ($j-1) * 2+1] = "Yes"
				EndIf
			EndIf
			If Not StringInStr($aResult[$i][6], "[") Then
				$aResult[$i][0] = "-"
			EndIf
			If $aResult[$i][0] <> "-" And $aResult[$i][8] <> "" And Not StringInStr($aResult[$i][8], "[") Then
				If StringInStr($aResult[$i][9], "Market") Then
					$aResult[$i][0] = "[Market] Yes"
				Else
					$aResult[$i][0] = "-"
				EndIf
			EndIf
			If $aResult[$i][0] <> "-" And $aResult[$i][10] <> "" And Not StringInStr($aResult[$i][10], "[") Then
				If StringInStr($aResult[$i][11], "Market") Then
					$aResult[$i][0] = "[Market] Yes"
				Else
					$aResult[$i][0] = "-"
				EndIf
			EndIf
			If $aResult[$i][0] <> "-" And $aResult[$i][12] <> "" And Not StringInStr($aResult[$i][12], "[") Then
				If StringInStr($aResult[$i][13], "Market") Then
					$aResult[$i][0] = "[Market] Yes"
				Else
					$aResult[$i][0] = "-"
				EndIf
			EndIf
		Next
	Next

	_ArraySort($aResult, 1, 1)
	$sTitle = UBound($aResult)-1 & " Blueprints"
	If GUICtrlRead($ComboCat) <> "Any" Then $sTitle &= " - Category: " & GUICtrlRead($ComboCat)
	If GUICtrlRead($ComboMod) <> "Any" Then $sTitle &= " - Modifiaction: " & GUICtrlRead($ComboMod)
	If GUICtrlRead($ComboEng) <> "Any" Then $sTitle &= " - Engineer: " & GUICtrlRead($ComboEng)
	If GUICtrlRead($ComboLvl) <> "Any" Then $sTitle &= " - Grade: " & GUICtrlRead($ComboLvl)
	WinSetTitle($GuiBlueprints, "", $sTitle)
	GUISetState(@SW_SHOW, $GuiBlueprints)
	_PopLVBlueprints($aResult)
EndFunc

Func _ResetFilter()
	_GUICtrlComboBox_SetCurSel($ComboCat, 0)
	_GUICtrlComboBox_SetCurSel($ComboMod, 0)
	_GUICtrlComboBox_SetCurSel($ComboEng, 0)
	_GUICtrlComboBox_SetCurSel($ComboLvl, 0)
	_PopCombo(-1)
EndFunc

Func _ParseInara()
	$Ingredients = False
	If $Ingredients Then
		$Query = "SELECT inaraID FROM blueprints "
		$aResult = _GetTable($Query, $DbED)
		$Query = ""
		For $i = 1 To UBound($aResult)-1
			$sWeb = _INetGetSource("http://inara.cz/galaxy-blueprint/" & $aResult[$i][0])
			$aBluePrints = StringRegExp($sWeb, '((?U)<h3 class="header">.+<br></div></div>)', 3)
			For $j = 0 To UBound($aBluePrints)-1
				$aGrade = StringRegExp($aBluePrints[$j], '(?:Grade )(\d)', 3)
				$aCost = StringRegExp($aBluePrints[$j], '(?:<a href="/galaxy-component/)(\d+)', 3)
				For $k = 0 To UBound($aCost)-1
					$Query &= "INSERT INTO ingredients VALUES (" & $aResult[$i][0] & "," & $aGrade[0] & "," & $aCost[$k] & "); " & @CRLF
				Next
			Next
			_DB($i & " of " & UBound($aResult)-1)
		Next
		_DB($Query)
		_Execute("BEGIN;", $DbED)
		_Execute($Query, $DbED)
		_Execute("COMMIT;", $DbED)
	EndIf

	$BluePrints = False
	If $BluePrints Then
		$sWeb = _INetGetSource("http://inara.cz/galaxy-blueprints")
		$aBluePrints = StringRegExp($sWeb, '(<tr><td class="lineright paddingleft">(?U).+)(?:</td></tr>)', 3)
		$Query = ""
		For $i = 0 To UBound($aBluePrints)-1
			$sWeb = $aBluePrints[$i]
			$Query &= "INSERT INTO blueprints VALUES ("
			$aSRE = StringRegExp($sWeb, '(?:<a href="/galaxy-blueprint/)(\d+)', 3)
			$Query &= $aSRE[0] & ","
			$aSRE = StringRegExp($sWeb, '(?:<tr><td class="lineright paddingleft">)((?U).+)(?:<)', 3)
			$Query &= _SQLite_Escape($aSRE[0]) & ","
			$aSRE = StringRegExp($sWeb, '(?:" class="inverse">)((?U).+)(?:<)', 3)
			$Query &= _SQLite_Escape($aSRE[0]) & ","
			$aSRE = StringRegExp($sWeb, '(?:<td class="minor">)(.+)', 3)
			$Query &= _SQLite_Escape($aSRE[0]) & ");" & @CRLF
		Next
		_DB($Query)
		_Execute("BEGIN;", $DbED)
		_Execute($Query, $DbED)
		_Execute("COMMIT;", $DbED)
	EndIf

	$Components = False
	If $Components Then
		$sWeb = _INetGetSource("http://inara.cz/galaxy-components")
		$aComponents = StringRegExp($sWeb, '(<a href="/galaxy-component/\d+(?U).+)(?:</td></tr>)', 3)

		$Query = "DELETE FROM components; " & @CRLF
		For $i = 0 To UBound($aComponents)-1
			$sWeb = $aComponents[$i]
			$Query &= "INSERT INTO components VALUES ("
			$aSRE = StringRegExp($sWeb, '(?:<a href="/galaxy-component/)(\d+)', 3)
			$Query &= $aSRE[0] & ","
			$aSRE = StringRegExp($sWeb, '(?:class="inverse">)((?U).+)(?:<)', 3)
			$Query &= _SQLite_Escape($aSRE[0]) & ","
			$aSRE = StringRegExp($sWeb, '(?:</a></td><td class="lineright" data-order="\d+">)((?U).+)(?:<)', 3)
			$Query &= _SQLite_Escape($aSRE[0]) & ","
			$aSRE = StringRegExp($sWeb, '(?: class="stationicon">)((?U).+)(?:<)', 3)
			$Query &= _SQLite_Escape($aSRE[0]) & ","
			$aSRE = StringRegExp($sWeb, '(?:</td><td class="lineright">)((?U).+)(?:</td><td)', 3)
			$aSRE[0] = StringRegExpReplace($aSRE[0], '(<a href="/galaxy-starsystem/\d+" class="inverse">)', "")
			$aSRE[0] = StringRegExpReplace($aSRE[0], '(</a>)', "")
			$Query &= _SQLite_Escape($aSRE[0]) & ");" & @CRLF
		Next
		_DB($Query)
		_Execute("BEGIN;", $DbED)
		_Execute($Query, $DbED)
		_Execute("COMMIT;", $DbED)
	EndIf

	$Engineers = False
	If $Engineers Then
		$sWeb = _INetGetSource("http://inara.cz/galaxy-engineers")
		$aEngineers = StringRegExp($sWeb, '(<a href="/galaxy-engineer/\d+(?U).+)(?:</div></div>)', 3)
		$Query = "DELETE FROM engineers; " & @CRLF
		For $i = 0 To UBound($aEngineers)-1
			$sWeb = $aEngineers[$i]

			$aSRE = StringRegExp($sWeb, '(?:<a href="/galaxy-engineer/)(\d+)', 3)
			$Id = $aSRE[0]


			$aSRE = StringRegExp($sWeb, '(?:<h4>)((?U).+)(?:</h4>)', 3)
			$Name = $aSRE[0]


			$aSRE = StringRegExp($sWeb, '(?:<span class="smaller">)((?U).+)(?:</span><br>)', 3)
			For $j = 0 To UBound($aSRE)-1
				$aGrade = StringRegExp($aSRE[$j], '(?:G)(\d+)', 3)
				$aMod = StringRegExp($aSRE[$j], '(?:"small">)(.+)', 3)
				$Query &= "INSERT INTO engineers VALUES (" & $Id & "," & _SQLite_Escape($Name) & "," & _SQLite_Escape($aMod[0]) & "," & $aGrade[0] & ");" & @CRLF
			Next
		Next
		_DB($Query)
		_Execute("BEGIN;", $DbED)
		_Execute($Query, $DbED)
		_Execute("COMMIT;", $DbED)
	EndIf
EndFunc

Func _PopLVBlueprints($aArray)

	For $i = _GUICtrlListView_GetColumnCount($lvBlueprints) To UBound($aArray, 2)+1 Step -1
		_DB("Delete " &  _GUICtrlListView_GetColumnCount($lvBlueprints) & " <> " & UBound($aArray, 2))
		_GUICtrlListView_DeleteColumn($lvBlueprints, $i)
	Next

	For $i = _GUICtrlListView_GetItemCount($lvBlueprints) To UBound($aArray) Step -1
		_GUICtrlListView_DeleteItem($lvBlueprints, $i-1)
	Next

	For $i = 0 To UBound($aArray, 2)-1

		If UBound($aArray) > 1 And StringIsDigit($aArray[1][$i]) Then
			$Align = 1
		Else
			$Align = 0
		EndIf
		If $aArray[0][$i] = "hide" Then
			$Width = 0
		Else
			$Width = StringLen($aArray[0][$i]) * 8
		EndIf
		$aCol = _GUICtrlListView_GetColumn($lvBlueprints, $i)
		If $aCol[5] = "" Then
			_GUICtrlListView_InsertColumn($lvBlueprints, $i, $aArray[0][$i], $Width, $Align)
		ElseIf $aCol[5] <> $aArray[0][$i] Then
			_GUICtrlListView_SetColumn($lvBlueprints, $i, $aArray[0][$i], $Width, $Align)
		EndIf
	Next

	For $i = 1 To UBound($aArray)-1
		For $j = 0 To UBound($aArray, 2)-1
			$aItem = _GUICtrlListView_GetItem($lvBlueprints, $i-1, $j)
			If $aItem[3] = "" Then
				If $j = 0 Then
					_GUICtrlListView_AddItem($lvBlueprints, $aArray[$i][$j])
				Else
					_GUICtrlListView_AddSubItem($lvBlueprints, $i-1, $aArray[$i][$j], $j)
				EndIf
			ElseIf $aItem[3] <> $aArray[$i][$j] Then
				_GUICtrlListView_SetItemText($lvBlueprints, $i-1, $aArray[$i][$j], $j)
			EndIf
		Next
	Next
	_GUICtrlListView_EndUpdate($lvBlueprints)
	GUISetState(@SW_SHOW, $GuiBlueprints)
	If BitAND(WinGetState($GuiBlueprints), 16) Then
		GUISetState(@SW_RESTORE, $GuiBlueprints)
	EndIf
	WinActivate($GuiBlueprints)
EndFunc

Func _PopCombo($ControlID=0)
	If $ControlID <> $ComboCat Then
		$Query = "SELECT type FROM blueprints "
		If GUICtrlRead($ComboLvl) <> "Any" Then
			$Query &= "JOIN ingredients ON blueprintID = inaraID "
			$Query &= "AND ingredients.grade = " & GUICtrlRead($ComboLvl) & " "
		EndIf
		$Query &= "WHERE type IS NOT NULL "
		If GUICtrlRead($ComboEng) <> "Any" Then
			$Query &= "AND engineers LIKE " & _SQLite_Escape("%" & GUICtrlRead($ComboEng) & "%") & " "
		EndIf
		If GUICtrlRead($ComboMod) <> "Any" Then
			$Query &= "AND modification = " & _SQLite_Escape(GUICtrlRead($ComboMod)) & " "
		EndIf

		$Query &= "GROUP BY type ORDER BY type "
		$aResult = _GetTable($Query, $DbED)
		$sAdd = "|Any|"
		For $i = 1 To UBound($aResult)-1
			$sAdd &= $aResult[$i][0] & "|"
		Next
		$Select = GUICtrlRead($ComboCat)
		$Index = _ArraySearch($aResult, $Select, 1)
		If $Index = -1 Then $Select = "Any"
		GUICtrlSetData($ComboCat, $sAdd, $Select)
	EndIf

	If $ControlID <> $ComboMod Then
		$Query = "SELECT modification FROM blueprints "
		If GUICtrlRead($ComboLvl) <> "Any" Then
			$Query &= "JOIN ingredients ON blueprintID = inaraID "
			$Query &= "AND ingredients.grade = " & GUICtrlRead($ComboLvl) & " "
		EndIf
		$Query &= "WHERE modification IS NOT NULL "
		If GUICtrlRead($ComboCat) <> "Any" Then
			$Query &= "AND type = " & _SQLite_Escape(GUICtrlRead($ComboCat)) & " "
		EndIf
		If GUICtrlRead($ComboEng) <> "Any" Then
			$Query &= "AND engineers LIKE " & _SQLite_Escape("%" & GUICtrlRead($ComboEng) & "%") & " "
		EndIf
		$Query &= "GROUP BY modification ORDER BY modification "
		$aResult = _GetTable($Query, $DbED)
		$sAdd = "|Any|"
		For $i = 1 To UBound($aResult)-1
			$sAdd &= $aResult[$i][0] & "|"
		Next
		$Select = GUICtrlRead($ComboMod)
		$Index = _ArraySearch($aResult, $Select, 1)
		If $Index = -1 Then $Select = "Any"
		GUICtrlSetData($ComboMod, $sAdd, $Select)
	EndIf

	If $ControlID <> $ComboEng Then
		$Query = "SELECT engineer FROM engineers "

		$Query &= "WHERE engineer IS NOT NULL "

		If GUICtrlRead($ComboCat) <> "Any" Then
			$Query &= "AND type = " & _SQLite_Escape(GUICtrlRead($ComboCat)) & " "
		ElseIf GUICtrlRead($ComboMod) <> "Any" Then
			$Query &= "AND type IN (SELECT type FROM blueprints WHERE modification = " & _SQLite_Escape(GUICtrlRead($ComboMod)) & ") "
		EndIf
		If GUICtrlRead($ComboLvl) <> "Any" Then
			$Query &= "AND maxGrade >= " & GUICtrlRead($ComboLvl) & " "
		EndIf
		$Query &= "GROUP BY engineer ORDER BY engineer "

		$aResult = _GetTable($Query, $DbED)
		$sAdd = "|Any|"
		For $i = 1 To UBound($aResult)-1
			$sAdd &= $aResult[$i][0] & "|"
		Next
		$Select = GUICtrlRead($ComboEng)
		$Index = _ArraySearch($aResult, $Select, 1)
		If $Index = -1 Then $Select = "Any"
		GUICtrlSetData($ComboEng, $sAdd, $Select)
	EndIf

	If $ControlID <> $ComboLvl Then
		$Query = "SELECT MAX(maxGrade) FROM engineers "
		$Query &= "WHERE maxGrade IS NOT NULL "
		If GUICtrlRead($ComboCat) <> "Any" Then
			$Query &= "AND type = " & _SQLite_Escape(GUICtrlRead($ComboCat)) & " "
		ElseIf GUICtrlRead($ComboMod) <> "Any" Then
			$Query &= "AND type IN (SELECT type FROM blueprints WHERE modification = " & _SQLite_Escape(GUICtrlRead($ComboMod)) & ") "
		EndIf
		If GUICtrlRead($ComboEng) <> "Any" Then
			$Query &= "AND engineer = " & _SQLite_Escape(GUICtrlRead($ComboEng)) & " "
		EndIf
		$Query &= "UNION ALL "
		$Query &= "SELECT MAX(grade) FROM ingredients "
		$Query &= "WHERE grade IS NOT NULL "
		If GUICtrlRead($ComboCat) <> "Any" Then
			$Query &= "AND blueprintID IN (SELECT inaraID FROM blueprints WHERE type = " & _SQLite_Escape(GUICtrlRead($ComboCat)) & ") "
		EndIf
		If GUICtrlRead($ComboMod) <> "Any" Then
			$Query &= "AND blueprintID IN (SELECT inaraID FROM blueprints WHERE modification = " & _SQLite_Escape(GUICtrlRead($ComboMod)) & ") "
		EndIf

		$aResult = _GetTable($Query, $DbED)
		$MaxGrade = _ArrayMin($aResult, 1, 1)

		If UBound($aResult) > 1 Then
			$sAdd = "|Any|"
			For $i = 1 To $MaxGrade
				$sAdd &= $i & "|"
			Next
			$Select = GUICtrlRead($ComboLvl)
			If $Select > $MaxGrade Then $Select = "Any"
			GUICtrlSetData($ComboLvl, $sAdd, $Select)
		EndIf
	EndIf
	$TestTimer = TimerInit()
	If GUICtrlRead($ComboCat) <> "Any" Or GUICtrlRead($ComboMod) <> "Any" Or GUICtrlRead($ComboEng) <> "Any" Or GUICtrlRead($ComboLvl) <> "Any" Then
		$Query = "SELECT 1 "
		$Query &= "FROM blueprints "
		$Query &= "JOIN ingredients ON blueprintID = blueprints.inaraID "
		If GUICtrlRead($ComboLvl) <> "Any" Then $Query &= "AND ingredients.grade = " & GUICtrlRead($ComboLvl) & " "
		$Query &= "JOIN engineers ON engineers.type = blueprints.type "
		$Query &= "AND engineers.maxGrade >= ingredients.grade "
		If GUICtrlRead($ComboLvl) <> "Any" Then $Query &= "AND CAST(maxGrade AS int) >= " & GUICtrlRead($ComboLvl) & " "
		If GUICtrlRead($ComboEng) <> "Any" Then $Query &= "AND engineer = " & _SQLite_Escape(GUICtrlRead($ComboEng)) & " "
		$Query &= "WHERE blueprints.inaraID IS NOT NULL "
		If GUICtrlRead($ComboCat) <> "Any" Then $Query &= "AND blueprints.type = " & _SQLite_Escape(GUICtrlRead($ComboCat)) & " "
		If GUICtrlRead($ComboMod) <> "Any" Then $Query &= "AND modification = " & _SQLite_Escape(GUICtrlRead($ComboMod)) & " "
		If GUICtrlRead($ComboEng) <> "Any" Then $Query &= "AND engineers LIKE " & _SQLite_Escape("%" & GUICtrlRead($ComboEng) & "%") & " "
		$Query &= "GROUP BY blueprints.type, modification, grade, engineer "
		$aResult = _GetTable($Query, $DbED)
	Else
		Dim $aResult[1161]
	EndIf
	GUICtrlSetData($GroupBluePrints, UBound($aResult)-1 & " Blueprints (" & 1160 - (UBound($aResult)-1) &  " Filtered out)")
EndFunc

Func _PopLVmaterials()
	$Query = ""
	$Query &= "SELECT "
	$Query &= "count AS 'Count ', "
	$Query &= "CASE WHEN clearNames.clearName IS NOT NULL THEN clearNames.clearName ELSE components.name END AS 'Name                   ', "
	$Query &= "category AS 'Category   ', "
	$Query &= "COUNT(blueprintID) AS 'hide', "
	$Query &= "components.grade AS 'Grade      ', "
	$Query &= "materials.name AS 'Encoded Name ' "
	$Query &= "FROM materials "
	$Query &= "LEFT JOIN clearNames ON LOWER(clearNames.name) = LOWER(materials.name) "
	$Query &= "LEFT JOIN components ON clearNames.clearName = components.name OR LOWER(REPLACE(components.name, ' ', '')) = LOWER(materials.name) "
	$Query &= "LEFT JOIN ingredients ON ingredients.component = components.inaraID "
	If BitAND(GUICtrlRead($MenuSettingsShowZeros), $GUI_CHECKED) <> $GUI_CHECKED Then
		$Query &= "WHERE count <> 0 "
	EndIf
	$Query &= "GROUP BY materials.name "

	If $ParseCommmodities > 0 Then
		$Query &= "UNION ALL "
		$Query &= "SELECT "
		$Query &= "count AS 'Count ', "
		$Query &= "CASE WHEN clearNames.clearName IS NOT NULL THEN clearNames.clearName ELSE CASE WHEN components.name IS NOT NULL THEN components.name ELSE commodities.name END END AS cName, "
		$Query &= "CASE WHEN components.type IS NOT NULL THEN components.type ELSE commodities.cat_name || ' (Commodity)' END AS 'Category      ', "
		$Query &= "COUNT(blueprintID) AS 'hide', "
		$Query &= "CASE WHEN components.grade IS NOT NULL THEN components.grade ELSE '' END AS 'Grade     ', "
		$Query &= "cargo.name AS 'Encoded Name ' "
		$Query &= "FROM cargo "
		$Query &= "LEFT JOIN clearNames ON LOWER(clearNames.name) = LOWER(cargo.name) "
		$Query &= "LEFT JOIN components ON clearNames.clearName = components.name OR LOWER(REPLACE(components.name, ' ', '')) = LOWER(cargo.name) "
		$Query &= "LEFT JOIN commodities ON clearNames.clearName = commodities.name OR LOWER(REPLACE(commodities.name, ' ', '')) = LOWER(cargo.name) "
		$Query &= "LEFT JOIN ingredients ON ingredients.component = components.inaraID "
		If BitAND(GUICtrlRead($MenuSettingsShowZeros), $GUI_CHECKED) <> $GUI_CHECKED Then
			$Query &= "WHERE count <> 0 "
		EndIf
		$Query &= "GROUP BY cargo.name "
		$Query &= "HAVING cName IN (SELECT name FROM components) "
	EndIf

	$aArray = _GetTable($Query, $DbED)

	If @error Then Return

	_ArraySort($aArray, 0, 1, 0, 1)
	_GUICtrlListView_BeginUpdate($lvMaterials)

	Dim $aGroupInfo[5] = ["", "Engineering Commodities", "Materials", "Data", "Data / Materials Not Used By Engineers"]
	If _GUICtrlListView_GetGroupCount($lvMaterials) = 0 Then
		_GUICtrlListView_EnableGroupView($lvMaterials)
		$Align = 0
		For $i = 1 To UBound($aGroupInfo)-1
			_GUICtrlListView_InsertGroup($lvMaterials, -1, $i, $aGroupInfo[$i], $Align)
			_GUICtrlListView_SetGroupInfo($lvMaterials, $i, $aGroupInfo[$i], $Align, $LVGS_COLLAPSIBLE)
		Next
	EndIf

	For $i = _GUICtrlListView_GetColumnCount($lvMaterials) To UBound($aArray, 2)+1 Step -1
		_GUICtrlListView_DeleteColumn($lvMaterials, $i)
	Next

	For $i = _GUICtrlListView_GetItemCount($lvMaterials) To UBound($aArray) Step -1
		_GUICtrlListView_DeleteItem($lvMaterials, $i-1)
	Next

	For $i = 0 To UBound($aArray, 2)-1
		$aCol = _GUICtrlListView_GetColumn($lvMaterials, $i)
		If UBound($aArray) > 1 And StringIsDigit($aArray[1][$i]) Then
			$Align = 1
		Else
			$Align = 0
		EndIf

		If $aArray[0][$i] = "hide" Then
			$Width = 0
		Else
			$Width = StringLen($aArray[0][$i]) * 8
		EndIf

		If $aCol[5] = "" Then
			_GUICtrlListView_InsertColumn($lvMaterials, $i, $aArray[0][$i], $Width, $Align)
		ElseIf $aCol[5] <> $aArray[0][$i] Then
			_GUICtrlListView_SetColumn($lvMaterials, $i, $aArray[0][$i], $Width, $Align)
		EndIf
	Next

	$Materials = 0
	$Data = 0
	$Cargo = 0

	For $i = 1 To UBound($aArray)-1
		For $j = 0 To UBound($aArray, 2)-1
			$aItem = _GUICtrlListView_GetItem($lvMaterials, $i-1, $j)
			If $aItem[3] = "" Then
				If $j = 0 Then
					_GUICtrlListView_AddItem($lvMaterials, $aArray[$i][$j])
				Else
					_GUICtrlListView_AddSubItem($lvMaterials, $i-1, $aArray[$i][$j], $j)
				EndIf
			ElseIf $aItem[3] <> $aArray[$i][$j] Then
				_GUICtrlListView_SetItemText($lvMaterials, $i-1, $aArray[$i][$j], $j)
			EndIf
		Next
		If StringInStr($aArray[$i][2], "Commodity") Or $aArray[$i][1] = "Drones" Then
			$Cargo += $aArray[$i][0]
			_GUICtrlListView_SetItemGroupID($lvMaterials, $i-1, 1)
		ElseIf $aArray[$i][3] = 0 Then
			If $aArray[$i][2] = "Encoded" Then
				$Data += $aArray[$i][0]
			Else
				$Materials += $aArray[$i][0]
			EndIf
			_GUICtrlListView_SetItemGroupID($lvMaterials, $i-1, 4)
		ElseIf $aArray[$i][2] = "Encoded" Then
			$Data += $aArray[$i][0]
			_GUICtrlListView_SetItemGroupID($lvMaterials, $i-1, 3)
		Else
			_GUICtrlListView_SetItemGroupID($lvMaterials, $i-1, 2)
			$Materials += $aArray[$i][0]
		EndIf
	Next

	_GUICtrlListView_EndUpdate($lvMaterials)
	$sTitle = "Data (" & $Data & ") - Materials (" & $Materials & ")"
	If WinGetTitle($GuiMaterials) <> $sTitle Then WinSetTitle($GuiMaterials, "", $sTitle)
	If UBound($aArray) > 1 Then GUISetState(@SW_SHOW, $GuiMaterials)
EndFunc

Func _ResetDB()
	$User = _ExtMsgBox($EMB_ICONQUERY, "Yes|No", "Rebuild Databse", "This will reset the Databse. All Journal Files have to be parsed again.", 0, $Gui)
	If $User = 1 Then
		$Query = ""
		$Query &= "DELETE FROM journal; " & @CRLF
		$Query &= "UPDATE materials SET count = 0; " & @CRLF
		$Query &= "UPDATE parser SET fileTimeString = 0, timeStamp = 0, event = '', content = ''; " & @CRLF
		$Query &= "UPDATE cargo SET count = 0; " & @CRLF
		_Execute($Query, $DbED)
		_Execute("VACUUM", $DbED)
		$LastTimeStamp = 0
		$WatchFile = -1
		$LastFilePointer = -1
		$LastFilePointer = -1
		$LastFileTimeString = -1
		_PopLVmaterials()
		_SB("Database Wiped")
		_ParseJournal()
	EndIf
EndFunc

Func _CountMaterials()
	$Query = "SELECT MAX(timestamp), parsed FROM journal WHERE event = 'Died' "
	$aResult = _GetTable($Query, $DbED)
	If UBound($aResult) > 1 And $aResult[1][0] > 0 Then
		$Died = $aResult[1][0]
	Else
		$Died = 0
	EndIf

	$Query = ""
	$Debug = 0

	$pQuery = "SELECT * FROM journal WHERE (event = 'MaterialCollected' OR event = 'MaterialDiscarded') AND (parsed IS NULL OR parsed = " & $Debug & ") "
	$aResult = _GetTable($pQuery, $DbED)
	For $i = 1 To UBound($aResult)-1
		_SB("Update Material Collected / Discarded " & $i & " of " & UBound($aResult)-1)
		$aName = StringRegExp($aResult[$i][3], '(?:Name":")((?U).+)(?:")', 3)
		$aCat = StringRegExp($aResult[$i][3], '(?:Category":")((?U).+)(?:")', 3)
		$aCount = StringRegExp($aResult[$i][3], '(?:Count":)(\d+)', 3)
		If UBound($aName) = 1 And UBound($aCat) = 1 And UBound($aCount) = 1 Then
			If $aResult[$i][2] = "MaterialDiscarded" Then
				_DB("Discarded: " & $aCount[0] & " x " & $aName[0], 1)
				$aCount[0] *= -1
			Else
				_DB("Collected: " & $aCount[0] & " x " & $aName[0], 1)
			EndIf
			$Query &= "INSERT OR IGNORE INTO materials VALUES (" & _SQLite_Escape($aName[0]) & ", " & _SQLite_Escape($aCat[0]) & ", 0);" & @CRLF
			$Query &= "UPDATE materials SET count = count + " & $aCount[0] & " WHERE LOWER(name) = " & _SQLite_Escape(StringLower($aName[0])) & ";" & @CRLF
		EndIf
		$Query &= "UPDATE journal SET parsed = 1 WHERE filename = " & $aResult[$i][0] & " AND timestamp = " & $aResult[$i][1] & " AND content = " & _SQLite_Escape($aResult[$i][3]) & ";" & @CRLF
	Next

	$pQuery = "SELECT * FROM journal WHERE event = 'EngineerCraft' AND (parsed IS NULL OR parsed = " & $Debug & ")"
	$aResult = _GetTable($pQuery, $DbED)
	For $i = 1 To UBound($aResult)-1
		_SB("Update Materials used by Engineers " & $i & " of " & UBound($aResult)-1)
		$aIngredients = StringRegExp($aResult[$i][3], '(?:"Ingredients":\x7B)((?U).+)(?:\x7D)', 3)
		If UBound($aIngredients) = 1 Then
			$sUsed = "Engineer used: "
			$aUsed = StringRegExp($aIngredients[0], '(?:")((?U).+)(?:")', 3)

			For $j = 0 To UBound($aUsed)-1
				$Query &= "UPDATE materials SET count = count - 1 WHERE LOWER(name) = " & _SQLite_Escape(StringLower($aUsed[$j])) & ";" & @CRLF
				If $aResult[$i][1] > $Died Then
					$Query &= "UPDATE cargo SET count = count - 1 WHERE LOWER(name) = " & _SQLite_Escape(StringLower($aUsed[$j])) & ";" & @CRLF
				EndIf
				$sUsed &= " 1 x " & $aUsed[$j] & "  "
			Next
			_DB($sUsed, 1)
;~ 			If UBound($aUsed) > 1 Then
;~ 				_DB($Query)
;~ 				_ArrayDisplay($aUsed)
;~ 			EndIf
		EndIf
		$Query &= "UPDATE journal SET parsed = 1 WHERE filename = " & $aResult[$i][0] & " AND timestamp = " & $aResult[$i][1] & " AND content = " & _SQLite_Escape($aResult[$i][3]) & ";" & @CRLF
	Next

	$pQuery = "SELECT * FROM journal WHERE event = 'Synthesis' AND (parsed IS NULL OR parsed = " & $Debug & ")"
	$aResult = _GetTable($pQuery, $DbED)
	For $i = 1 To UBound($aResult)-1
		_SB("Update Materials used by Synthesis " & $i & " of " & UBound($aResult)-1)
		$aIngredients = StringRegExp($aResult[$i][3], '(?:"Materials":\x7B)((?U).+)(?:\x7D)', 3)
		If UBound($aIngredients) = 1 Then
			$aUsed = StringRegExp($aIngredients[0], '(?:")((?U).+)(?:")', 3)
			$aCount = StringRegExp($aIngredients[0], '(?:":)(\d)', 3)
			For $j = 0 To UBound($aUsed)-1
				If UBound($aCount) > $j Then
					$Query &= "UPDATE materials SET count = count - " & $aCount[$j] & " WHERE LOWER(name) = " & _SQLite_Escape(StringLower($aUsed[$j])) & ";" & @CRLF
					_DB("Synthesis used: " & $aCount[$j] & " x " & $aUsed[$j], 1)
				EndIf
			Next
		EndIf
		$Query &= "UPDATE journal SET parsed = 1 WHERE filename = " & $aResult[$i][0] & " AND timestamp = " & $aResult[$i][1] & " AND content = " & _SQLite_Escape($aResult[$i][3]) & ";" & @CRLF
	Next

	If $Query <> "" Then
		_Execute("BEGIN;", $DbED)
		_Execute($Query, $DbED)
		_Execute("COMMIT;", $DbED)
	EndIf
EndFunc

Func _CountCommodities()
	If $ParseCommmodities = 0 Then Return
	$TestTimer = TimerInit()
	$Debug = 0

	$Query = "SELECT MAX(timestamp), parsed FROM journal WHERE event = 'Died' "
	$aResult = _GetTable($Query, $DbED)
	If UBound($aResult) > 1 And $aResult[1][0] > 0 Then
		$Died = $aResult[1][0]
		$Query = ""
		If $aResult[1][1] <> 1 Then
			$Query &= "UPDATE cargo SET count = 0 WHERE count > 0; "
		EndIf
		$Query &= "UPDATE journal SET parsed = 1 WHERE event = 'Died' AND timestamp = " & $Died & ";"
		_Execute($Query, $DbED)
	Else
		$Died = 0
	EndIf

	$Query = ""
	$pQuery = "SELECT * FROM journal WHERE timestamp > " & $Died & " AND (event = 'MissionCompleted' OR event = 'MissionAccepted') AND content LIKE " & _SQLite_Escape('%"Commodity":"$%') & " AND (parsed IS NULL OR parsed = " & $Debug & ")"
	$aResult = _GetTable($pQuery, $DbED)

	For $i = 1 To UBound($aResult)-1
		_SB("Update Commodity Mission accepted " & $i & " / " & UBound($aResult)-1)
		$aCommHaulage = StringRegExp($aResult[$i][3], '(?:"Commodity":"\x24)((?U).+)(?:_Name)', 3)
		If UBound($aCommHaulage) = 1 Then
			$aCount = StringRegExp($aResult[$i][3], '(?:"Count":)(\d+)', 3)
			If UBound($aCount) = 1 Then
				If $aResult[$i][2] = "MissionAccepted" Then
					_DB("Cargo Load: " & $aCount[0] & " x " & $aCommHaulage[0], 1)
				Else
					_DB("Cargo Unload: " & $aCount[0] & " x " & $aCommHaulage[0], 1)
					$aCount[0] *= -1
				EndIf
				$Query &= "INSERT OR IGNORE INTO cargo VALUES (" & _SQLite_Escape(StringLower($aCommHaulage[0])) & ", 0);"
				$Query &= "UPDATE cargo SET count = count + " & $aCount[0] & " WHERE LOWER(name) = " & _SQLite_Escape(StringLower($aCommHaulage[0])) & ";"
			EndIf
		EndIf
		$Query &= "UPDATE journal SET parsed = 1 WHERE filename = " & $aResult[$i][0] & " AND timestamp = " & $aResult[$i][1] & " AND content = " & _SQLite_Escape($aResult[$i][3]) & ";"
	Next

	$pQuery = "SELECT * FROM journal WHERE timestamp > " & $Died & " AND (event = 'MissionCompleted' AND content LIKE " & _SQLite_Escape('%CommodityReward%') & ") AND (parsed IS NULL OR parsed = " & $Debug & ")"
	$aResult = _GetTable($pQuery, $DbED)

	For $i = 1 To UBound($aResult)-1
		_SB("Update Commodity Mission Reward " & $i & " / " & UBound($aResult)-1)
		$aCommReward = StringRegExp($aResult[$i][3], '(?:CommodityReward":\x5B)((?U).+)(?:\x5D)', 3)
		If UBound($aCommReward) > 0 Then
			$aName = StringRegExp($aCommReward[0], '(?:\x7B "Name": ")((?U).+)(?:")', 3)
			$aCount = StringRegExp($aCommReward[0], '(?:"Count": )(\d+)', 3)
			If UBound($aName) > 0 And UBound($aCount) > 0 Then
				_DB("Cargo Rewarded: " & $aCount[0] & " x " & $aName[0], 1)
				$Query &= "INSERT OR IGNORE INTO cargo VALUES (" & _SQLite_Escape($aName[0]) & ", 0);" & @CRLF
				$Query &= "UPDATE cargo SET count = count + " & $aCount[0] & " WHERE LOWER(name) = " & _SQLite_Escape(StringLower($aName[0])) & ";" & @CRLF
			EndIf
		EndIf
		$Query &= "UPDATE journal SET parsed = 1 WHERE filename = " & $aResult[$i][0] & " AND timestamp = " & $aResult[$i][1] & " AND content = " & _SQLite_Escape($aResult[$i][3]) & ";" & @CRLF
	Next

	$pQuery = "SELECT * FROM journal WHERE timestamp > " & $Died & " AND (event = 'MarketBuy' Or event = 'MarketSell') AND (parsed IS NULL OR parsed = " & $Debug & ")"
	$aResult = _GetTable($pQuery, $DbED)
	For $i = 1 To UBound($aResult)-1
		_SB("Update Market Buy / Sell " & $i & " / " & UBound($aResult)-1)
		$aName = StringRegExp($aResult[$i][3], '(?:Type":")((?U).+)(?:")', 3)
		$aCount = StringRegExp($aResult[$i][3], '(?:Count":)(\d+)', 3)
		If UBound($aName) > 0 And UBound($aCount) > 0 Then
			If $aResult[$i][2] = "MarketSell" Then
				_DB("Cargo Sold: " & $aCount[0] & " x " & $aName[0], 1)
				$aCount[0] *= -1
			Else
				_DB("Cargo Bought: " & $aCount[0] & " x " & $aName[0], 1)
			EndIf
			$Query &= "INSERT OR IGNORE INTO cargo VALUES (" & _SQLite_Escape($aName[0]) & ", 0);" & @CRLF
			$Query &= "UPDATE cargo SET count = count + " & $aCount[0] & " WHERE LOWER(name) = " & _SQLite_Escape(StringLower($aName[0])) & ";" & @CRLF
		EndIf
		$Query &= "UPDATE journal SET parsed = 1 WHERE filename = " & $aResult[$i][0] & " AND timestamp = " & $aResult[$i][1] & " AND content = " & _SQLite_Escape($aResult[$i][3]) & ";" & @CRLF
	Next

	$pQuery = "SELECT * FROM journal WHERE timestamp > " & $Died & " AND (event = 'BuyDrones' OR event = 'SellDrones') AND (parsed IS NULL OR parsed = " & $Debug & ")"
	$aResult = _GetTable($pQuery, $DbED)
	For $i = 1 To UBound($aResult)-1
		_SB("Update Drones " & $i & " / " & UBound($aResult)-1)
		$aName = StringRegExp($aResult[$i][3], '(?:Type":")((?U).+)(?:")', 3)
		If UBound($aName) = 1 Then
			$aCount = StringRegExp($aResult[$i][3], '(?:Count":)(\d+)', 3)
			If UBound($aCount) = 1 Then
				If $aResult[$i][2] = "BuyDrones" Then
					_DB("Bought " & $aCount[0] & " x " & $aName[0], 1)
				Else
					_DB("Sold " & $aCount[0] & " x " & $aName[0], 1)
					$aCount[0] *= -1
				EndIf
				$Query &= "INSERT OR IGNORE INTO cargo VALUES (" & _SQLite_Escape($aName[0]) & ", 0);"  & @CRLF
				$Query &= "UPDATE cargo SET count = count + " & $aCount[0] & " WHERE LOWER(name) = " & _SQLite_Escape(StringLower($aName[0])) & ";" & @CRLF
			EndIf
		EndIf
		$Query &= "UPDATE journal SET parsed = 1 WHERE filename = " & $aResult[$i][0] & " AND timestamp = " & $aResult[$i][1] & " AND content = " & _SQLite_Escape($aResult[$i][3]) & ";" & @CRLF
	Next

	$pQuery = "SELECT * FROM journal WHERE timestamp > " & $Died & " AND (event = 'CollectCargo' OR event = 'EjectCargo') AND (parsed IS NULL OR parsed = " & $Debug & ")"
	$aResult = _GetTable($pQuery, $DbED)
	For $i = 1 To UBound($aResult)-1
		_SB("Update Cargo Collected / Ejected " & $i & " / " & UBound($aResult)-1)
		$aName = StringRegExp($aResult[$i][3], '(?:Type":")((?U).+)(?:")', 3)
		If UBound($aName) = 1 Then
			If $aResult[$i][2] = "CollectCargo" Then
				Dim $aCount[1] = [-1]
			Else
				$aCount = StringRegExp($aResult[$i][3], '(?:Count":)(\d+)', 3)
			EndIf
			If UBound($aCount) = 1 Then
				If $aCount[0] < 0 Then
					_DB("Collected 1 x " & $aName[0], 1)
				Else
					_DB("Ejected " & $aCount[0] & " x " & $aName[0], 1)
				EndIf
				$Query &= "INSERT OR IGNORE INTO cargo VALUES (" & _SQLite_Escape($aName[0]) & ", 0);" & @CRLF
				$Query &= "UPDATE cargo SET count = count - " & $aCount[0] & " WHERE LOWER(name) = " & _SQLite_Escape(StringLower($aName[0])) & ";" & @CRLF
			EndIf
		EndIf
		$Query &= "UPDATE journal SET parsed = 1 WHERE filename = " & $aResult[$i][0] & " AND timestamp = " & $aResult[$i][1] & " AND content = " & _SQLite_Escape($aResult[$i][3]) & ";" & @CRLF
	Next

	If $Query <> "" Then
		_Execute("BEGIN;", $DbED)
;~ 		_DB($Query)
		_Execute($Query, $DbED)
		_Execute("COMMIT;", $DbED)
	EndIf
EndFunc

Func _ParseJournal()
	$TestTimer = TimerInit()
	$DoCount = False
	$QueryInsert = ""
	$QueryParser = ""

	If $WatchFile = -1 Then
		$hSearch = FileFindFirstFile($Path & "Journal.*.log")
		If $hSearch > -1 Then
			Dim $aFiles[1] = ["Journal Log"]
			Do
				$sFileName = FileFindNextFile($hSearch)
				If @error Then ExitLoop
				_ArrayAdd($aFiles, $sFileName)
			Until 0
			FileClose($hSearch)
			_ArraySort($aFiles, 0, 1)

			$TotalEntris = 0
			$TotalInserts = 0
			$Query = "SELECT * FROM parser "
			$aResult = _GetTable($Query, $DbED)
			If @error Then Return
			If UBound($aResult) > 1 Then
				$LastFileTimeString = $aResult[1][0]
				$LastTimeStamp = $aResult[1][1]
				$LastContent = $aResult[1][3]
			EndIf

			If $LastTimeStamp <= 0 Then
				$User = _ExtMsgBox($EMB_ICONQUERY, "Yes|No", "Found " & UBound($aFiles)-1 & " Journal Files", "Parse Journal Files now?", 0, $Gui)
				If $User = 2 Then
					Return
				EndIf
				GUISetState(@SW_DISABLE, $Gui)
			EndIf

			For $i = 1 To UBound($aFiles)-1
				$sFileTimeString = Number(StringMid($aFiles[$i], 9, 12))
				$WatchFile = $aFiles[$i]
				If $LastFileTimeString > $sFileTimeString Then
					ContinueLoop
				EndIf
				_DB("Parsing " & $aFiles[$i], 1)
				$hFile = FileOpen($Path & $aFiles[$i], 0)
				$sLog = FileRead($hFile)
				FileClose($hFile)

				Local $Entries, $Inserts
				$QueryInsert &= _ParseLog($sLog, $sFileTimeString, $QueryParser, $Entries, $Inserts)

				_SB("Parsing File " & $i & " of " & UBound($aFiles)-1 & " with " & $Entries & " Entries")
				$TotalEntris += $Entries
				$TotalInserts += $Inserts
			Next
			_SB(UBound($aFiles)-1 & " Journal Files, " & $TotalEntris & " new Entries, " & $TotalInserts & " new Inserts (" & Round(TimerDiff($TestTimer)) & " ms)")
		Else
			Do
				_SB("ERROR: no Journal Files found")
				$Path = FileSelectFolder("Select Journal Folder - Standard Path: " & @UserProfileDir & "\Saved Games\Frontier Developments\Elite Dangerous", @UserProfileDir & "\Saved Games\Frontier Developments\Elite Dangerous\", 0, @UserProfileDir & "\Saved Games\Frontier Developments\Elite Dangerous\", $Gui)
				If $Path <> "" Then
					$Path &= "\"
					$hSearch = FileFindFirstFile($Path & "Journal.*.log")
					If $hSearch > -1 Then
						IniWrite($fIni, "PATH", "JOURNAL", $Path)
						Dim $aFiles[1] = ["Journal Log"]
						Do
							$sFileName = FileFindNextFile($hSearch)
							If @error Then ExitLoop
							_ArrayAdd($aFiles, $sFileName)
						Until 0
						FileClose($hSearch)
						_SB("Found " & UBound($aFiles)-1 & " Journal Files")
						_ParseJournal()
						ExitLoop
					EndIf
					_SB("")
				EndIf
			Until $Path = ""
		EndIf
	Else
		$hFile = _WinAPI_CreateFile($Path & $WatchFile, 2, 2, BitOR(2, 4))
		If $hFile = 0 Then
			SetError(1)
			ConsoleWrite($WatchFile & " " & _WinAPI_GetLastErrorMessage() & @CRLF)
			Return
		Else
			$Pointer = _WinAPI_SetFilePointer($hFile, 0, $FILE_END)
			$sLog = ""
			If $Pointer > $LastFilePointer Then
				$PointerWait = $Pointer
				_SB("Wait for Log to finish new Entries")
				Do
					Sleep(800)
					$Pointer = _WinAPI_SetFilePointer($hFile, 0, $FILE_END)
				Until $Pointer >= $PointerWait
				_SB("")

				$TestTimer = TimerInit()
				If $LastFilePointer > 0 Then
					Local $nBytes
					$NewBytes = $Pointer - $LastFilePointer
					$tBuffer = DllStructCreate("byte[" & $NewBytes & "]")
					_WinAPI_SetFilePointer($hFile, -$NewBytes-2, $FILE_END)
					If Not _WinAPI_ReadFile($hFile, $tBuffer, $NewBytes, $nBytes) Then
						ConsoleWrite($WatchFile & " " & _WinAPI_GetLastErrorMessage() & @CRLF)
					EndIf
					$sLog = BinaryToString(DllStructGetData($tBuffer, 1))
					_DB($sLog)
				EndIf
			EndIf
			_WinAPI_CloseHandle($hFile)
			$LastFilePointer = $Pointer
			If $sLog <> "" Then
				$sFileTimeString = Number(StringMid($WatchFile, 9, 12))
				Local $Entries, $Inserts
				$QueryInsert = _ParseLog($sLog, $sFileTimeString, $QueryParser, $Entries, $Inserts)
				_SB($Entries & " new Entries, " & $Inserts & " new Inserts (" & Round(TimerDiff($TestTimer)) & " ms)")
			EndIf
		EndIf
	EndIf

	If $QueryInsert <> "" Then
		_Execute("BEGIN;", $DbED)
		If @error Then Return
		_Execute($QueryInsert, $DbED)
		_Execute("COMMIT;", $DbED)
		_CountCommodities()
		_CountMaterials()
		_PopLVmaterials()
		GUISetState(@SW_ENABLE, $Gui)
		$DoCount = True
	EndIf

	If $QueryParser <> "" Then _Execute($QueryParser, $DbED)

	Return $DoCount
EndFunc

Func _ParseLog($sLog, $sFileTimeString, ByRef $QueryParser, ByRef $Entries, ByRef $Inserts)
	$Inserts = 0
	$Entries = 0
	$Query = ""
	$QueryParser = ""

	$aTimeStamp = StringRegExp($sLog, '(?:"timestamp":")(\d+-\d+-\d+T\d+:\d+:\d+)', 3)
	$aEvent = StringRegExp($sLog, '(?:"event":")((?U).+)(?:")', 3)
	$aContent = StringRegExp($sLog, '(.+)', 3)

	For $j = 0 To UBound($aTimeStamp)-1
		$aTimeStamp[$j] = StringReplace($aTimeStamp[$j], "-", "")
		$aTimeStamp[$j] = StringReplace($aTimeStamp[$j], "T", "")
		$aTimeStamp[$j] = StringReplace($aTimeStamp[$j], ":", "")
		$aTimeStamp[$j] = Number($aTimeStamp[$j])

		If $LastTimeStamp > $aTimeStamp[$j] Then
			ContinueLoop
		EndIf

		If $LastTimeStamp = $aTimeStamp[$j] And $LastContent = $aContent[$j] Then
			ContinueLoop
		EndIf

		$Entries += 1

		If StringInStr($sKeppEvents, $aEvent[$j]) Then
			$Inserts += 1
			$Query &= "INSERT INTO journal VALUES (" & $sFileTimeString & "," & $aTimeStamp[$j] & "," & _SQLite_Escape($aEvent[$j]) & "," & _SQLite_Escape($aContent[$j]) & ", NULL);" & @CRLF
		EndIf
	Next
	$QueryParser = "UPDATE parser SET fileTimeString = " & $sFileTimeString & ", timeStamp = " & $aTimeStamp[UBound($aTimeStamp)-1] & ", event = " & _SQLite_Escape($aEvent[UBound($aTimeStamp)-1]) & ", content = " & _SQLite_Escape($aContent[UBound($aTimeStamp)-1])
	$LastTimeStamp = $aTimeStamp[UBound($aTimeStamp)-1]
	$LastContent = $aContent[UBound($aContent)-1]
	Return $Query
EndFunc

Func _DB($Message, $Flag = 0)
	If $Flag = 1 Then
		_GUICtrlEdit_AppendText($EditDebug, _NowTime() & @TAB & $Message & @CRLF)
	Else
		ConsoleWrite(_NowTime() & @TAB & $Message & @CRLF)
	EndIf
EndFunc

Func _SB($Message)
	_GUICtrlStatusBar_SetText($StatusBar, $Message)
EndFunc

Func _Exit()
	IniWrite($fIni, "SETTINGS", "Show Zeros", BitAND(GUICtrlRead($MenuSettingsShowZeros), $GUI_CHECKED))
	IniWrite($fIni, "SETTINGS", "Parse Commodities", $ParseCommmodities)
	$WinPos = WinGetPos($Gui, "")
	If $WinPos[0] >=0 And $WinPos[1] >= 0 Then
		IniWrite($fIni, "WINPOS", "GUIX", $WinPos[0])
		IniWrite($fIni, "WINPOS", "GUIY", $WinPos[1])
	EndIf
	$WinPos = WinGetPos($GuiMaterials, "")
	If $WinPos[0] >=0 And $WinPos[1] >= 0 Then
		IniWrite($fIni, "WINPOS", "MATX", $WinPos[0])
		IniWrite($fIni, "WINPOS", "MATY", $WinPos[1])
	EndIf
	If $WinPos[2] >=50 And $WinPos[3] >= 50 Then
		IniWrite($fIni, "WINPOS", "MATW", $WinPos[2])
		IniWrite($fIni, "WINPOS", "MATH", $WinPos[3])
	EndIf
	$WinPos = WinGetPos($GuiBlueprints, "")
	If $WinPos[0] >=0 And $WinPos[1] >= 0 Then
		IniWrite($fIni, "WINPOS", "BLUX", $WinPos[0])
		IniWrite($fIni, "WINPOS", "BLUY", $WinPos[1])
	EndIf
	If $WinPos[2] >=50 And $WinPos[3] >= 50 Then
		IniWrite($fIni, "WINPOS", "BLUW", $WinPos[2])
		IniWrite($fIni, "WINPOS", "BLUH", $WinPos[3])
	EndIf
	_SQLite_Shutdown()
	_GUICtrlListView_UnRegisterSortCallBack($lvMaterials)
	_GUICtrlListView_UnRegisterSortCallBack($lvBlueprints)
	Exit
EndFunc

Func _GetTable($Query, $DB)
	Local $iRows, $iColumns, $iRval, $aResult
	$iRval = _SQLite_GetTable2d($DB, $Query, $aResult, $iRows, $iColumns)
	If $iRval <> $SQLITE_OK Then
		_DB(@ScriptLineNumber & " " & _SQLite_ErrMsg($DB))
		SetError(1)
	EndIf
	Return $aResult
EndFunc

Func _Execute($Query, $DB)
	$iRval = _SQLite_Exec($DB, $Query)
	If $iRval <> $SQLITE_OK Then
		_DB(@ScriptLineNumber & " " & _SQLite_ErrMsg($DB))
		SetError(1)
	EndIf
	Return $iRval = $SQLITE_OK
EndFunc