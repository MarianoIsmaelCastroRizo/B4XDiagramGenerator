B4J=true
Group=Default Group
ModulesStructureVersion=1
Type=Class
Version=9.8
@EndOfDesignText@
Sub Class_Globals
	Public PageName As String

	Private xui As XUI
	Private ScrollPane1 As ScrollPane

	Private timer1 As Timer
	Private Arrows1 As arrows
	Private IsMoving As Boolean=True
	Private ControlPressed As Boolean=False

	Private cvs As B4XCanvas
	Private b4xfunction As B4XFunctions
	Private lblName, lblLine, lblStatus As B4XView

	Private colorPublic, colorPrivate As Int
	Private tabIsLoaded As Boolean = False
End Sub

Public Sub Initialize (Parent As TabPane, Name As String, TextFromFile As String, InfoSaved As Map)
	b4xfunction.Initialize
	Parent.LoadLayout("GenericTab", Name).Tag = Me
	PageName = Name
	ScrollPane1.LoadLayout("itemLayout",Parent.Width, Parent.Height)

	timer1.Initialize("Timer1", 2000)
	timer1.Enabled = True

	colorPublic = xui.Color_RGB(51, 200, 255)
	colorPrivate = xui.Color_RGB(254, 180, 34)
	If Initialized(InfoSaved) Then
		LoadSavedFunctions(InfoSaved)
	Else
		Dim result As Map = ExtractFunctionsAndCalls(TextFromFile)
		For Each func As String In result.Keys		
			Dim calls As List = result.Get(func)
			Dim updateChildren As FunctionsProperties = b4xfunction.GetItem(func)		
			updateChildren.Childrens = calls
		Next
	End If
End Sub

Private Sub LoadSavedFunctions(InfoSaved As Map)
	b4xfunction.functionList = InfoSaved.Get("Functions")
End Sub

Private Sub Timer1_Tick
	If IsMoving Then Return
	DrawLines
End Sub

Private Sub AddItemToList(name As String, extractName As String, line As Int, pointX As Double, pointY As Double, status As String)
	b4xfunction.Add(name, extractName, line, pointX, pointY, status)
End Sub

Private Sub ShowAll
	Dim n As Pane = ScrollPane1.InnerNode
	n.RemoveAllNodes
	Log("Show " & b4xfunction.functionList.Size)

	For Each item As FunctionsProperties In b4xfunction.functionList
		Dim p As B4XView=CreateItem(item)
		n.AddNode(p,p.Left, p.Top, p.Width,p.Height)
	Next

	n.PrefHeight = 2000
	n.PrefWidth = 2000
	cvs.Initialize(n)
	Arrows1.Initialize(cvs)
End Sub

'A letter-sized sheet equals 11 x 8.5 inches. Converting to pixels this is 792 x 612 pixels.
Private Sub DividePanelIntoSections
	Log("Here")
	Dim w As Double= ScrollPane1.InnerNode.PrefWidth
	Dim h As Double= ScrollPane1.InnerNode.PrefHeight
	Log(w)
	For i = 0 To w Step 748
		cvs.DrawLine(i, 0, i, h, xui.Color_LightGray, 1)
	Next
	For i = 0 To h Step 1080
		cvs.DrawLine(0, i, w, i, xui.Color_LightGray, 1)
	Next
End Sub

Public Sub SavePaneToImage
	Dim pnl As B4XView = ScrollPane1.InnerNode
	Dim fileNameImage As String = PageName & ".png"
	Dim Out As OutputStream = File.OpenOutput(xui.DefaultFolder, fileNameImage, False)
	pnl.Snapshot.WriteToStream(Out,100,"PNG")
	Out.Close
	Main.fx.ShowExternalDocument(File.GetUri(xui.DefaultFolder, fileNameImage))

	Dim bmp As B4XBitmap=pnl.Snapshot
	Dim widthCanvas, heightCanvas, numCol, numRow, index As Int
	widthCanvas=pnl.Width
	heightCanvas=pnl.Height
	numCol=3
	numRow=2
	index=1

	For i = 0 To widthCanvas-1 Step widthCanvas/numCol
		For j = 0 To heightCanvas-1 Step heightCanvas/numRow
			Log($"image ${index} from ${i}, ${j}"$)
			Dim img As B4XBitmap= bmp.Crop(i,j,widthCanvas/numCol,heightCanvas/numRow)
			Dim Out As OutputStream = File.OpenOutput(xui.DefaultFolder, "col "&index&".png", False)
			img.WriteToStream(Out,100,"PNG")
			Out.Close
			Sleep(100)
			index=index+1
		Next
	Next

	Dim shl As Shell
	shl.Initialize("shl", "explorer.exe", Array As String(xui.DefaultFolder))
	shl.Run(-1)
End Sub

Public Sub Update
	If tabIsLoaded = False Then
		ShowAll
		DrawLines
		tabIsLoaded = True
	End If
End Sub

Private Sub CreateItem(item As FunctionsProperties) As B4XView
	Dim p As B4XView=xui.CreatePanel("Item")
	p.LoadLayout("item")
	Dim nameToShow As String = item.FullName
	lblName.As(Label).WrapText=True
	Dim r As B4XRect = cvs.MeasureText(nameToShow, lblName.Font)
	Dim r2 As B4XRect = cvs.MeasureText(item.Line&item.Status, lblLine.Font)
	Dim width As Int=  IIf(r2.Width > r.Width,r2.Width, r.Width)
	p.SetLayoutAnimated(0, item.Point1.X, item.Point1.Y, width + 30, 60dip)
	item.Width = width
	item.Height = 60dip
	lblName.Text=nameToShow
	lblLine.Text=item.Line
	lblStatus.Text=item.Status
	Dim backGround As Int=IIf(item.Status.ToLowerCase.Contains("public"),colorPublic,colorPrivate)
	p.SetColorAndBorder(backGround, 1, xui.Color_Black, 8)
	p.Tag = item
	Return p
End Sub

Private Sub RemoveDuplicates(ThisChar As String, TargetString As String) As String
	Do While TargetString.Contains(ThisChar & ThisChar)
		TargetString = TargetString.Replace(ThisChar & ThisChar,ThisChar)
	Loop
	Return TargetString
End Sub

'Extracts functions and their calls from a .bas file in B4X
Private Sub ExtractFunctionsAndCalls(text As String) As Map
	text = RemoveDuplicates(" ", text)

	Dim CallMap As Map
	CallMap.Initialize

	Dim lines() As String = Regex.Split("\n", text)

	Dim AllFunctions As List
	AllFunctions.Initialize

	' Search for all functions and store names and starting lines
	Dim FunctionIndex As Map
	FunctionIndex.Initialize

	For i = 0 To lines.Length - 1
		Dim line As String = lines(i).Trim.ToLowerCase
		If(line.StartsWith("'")) Then Continue ' This is a comment
		Dim isPrivate As Boolean = line.StartsWith("private sub")
		Dim isSimple As Boolean = line.StartsWith("sub")
		Dim isPublic As Boolean = line.StartsWith("public sub")

		If isPrivate Or isPublic Or isSimple Then
			Dim parts() As String = Regex.Split("\s+", lines(i).Trim)
			If parts.Length > 1 Then
				Dim index As Int = IIf(isPrivate Or isPublic, 2, 1)
				Dim funcName As String = parts(index)

				If funcName.Contains("(") Then
					funcName = funcName.SubString2(0, funcName.IndexOf("("))
				End If

				Dim posX As Double = Rnd(1, 1900)
				Dim posY As Double = Rnd(1, 1900)

				Dim status As String = IIf(isPublic, "Public", "Private")
				Dim fullFuncName As String = DeleteCommentsFromEndLine(lines(i).Trim)
				AddItemToList(fullFuncName, funcName, i, posX, posY, status)

				AllFunctions.Add(funcName)
				FunctionIndex.Put(funcName, i)
			End If
		End If
	Next

	' Extract function blocks and detect function calls
	For Each func As String In AllFunctions
		Dim iStart As Int = FunctionIndex.Get(func)
		Dim iEnd As Int = lines.Length - 1

		For i = iStart + 1 To lines.Length - 1
			If lines(i).Trim.ToLowerCase.StartsWith("end sub") Then
				iEnd = i
				Exit
			End If
		Next

		Dim internalCalls As List
		internalCalls.Initialize

		Dim returnCalls As List
		returnCalls.Initialize

		For i = iStart + 1 To iEnd - 1
			Dim currentLine As String = lines(i).Trim

			' Detect common call patterns using regex
			Dim matcher As Matcher

			matcher = Regex.Matcher("(?i)wait for\((\w+)", currentLine)
			Do While matcher.Find
				Dim callName As String = matcher.Group(1)
				If AllFunctions.IndexOf(callName) > -1 And callName <> func Then
					internalCalls.Add(callName)
					Dim item As FunctionsProperties = b4xfunction.GetItem(func)
					returnCalls.Add(item)
				End If
			Loop

			matcher = Regex.Matcher("(?i)resumablesub\s*=\s*(\w+)", currentLine)
			Do While matcher.Find
				Dim callName As String = matcher.Group(1)
				If AllFunctions.IndexOf(callName) > -1 And callName <> func Then
					internalCalls.Add(callName)
					Dim item As FunctionsProperties = b4xfunction.GetItem(func)
					returnCalls.Add(item)
				End If
			Loop

			For Each possibleCall As String In AllFunctions
				If possibleCall <> func Then
					Dim callPattern As String = "(?i)\b" & possibleCall & "(\s*\(|\b)"
					Dim m As Matcher = Regex.Matcher(callPattern, currentLine)
					If m.Find And internalCalls.IndexOf(possibleCall) = -1 Then
						internalCalls.Add(possibleCall)
						If currentLine.Contains(".Initialize") Then Continue
						Dim item As FunctionsProperties = b4xfunction.GetItem(possibleCall)
						returnCalls.Add(item)
					End If
				End If
			Next
		Next

		CallMap.Put(func, returnCalls)
	Next

	Return CallMap
End Sub


Private Sub DeleteCommentsFromEndLine(cFunction As String) As String
	Return IIf(cFunction.Contains("'"), Regex.Split("'",cFunction)(0), cFunction)
End Sub

Public Sub SaveProject(kvs As KeyValueStore)
	Dim map1 As Map
	map1.Initialize
	
	map1.Put("Functions", b4xfunction.functionList)
	map1.Put("FileName", PageName) 
	kvs.Put(PageName, map1)  'java.lang.StackOverflowError on B4XTable
End Sub

Private Sub DrawLines
	IsMoving = True
	Dim Panel1 As B4XView=ScrollPane1.InnerNode
	If Panel1.NumberOfViews = 0 Then Return
	cvs.ClearRect(cvs.TargetRect)
	Dim arrowSpec As Map
	arrowSpec = CreateMap("Color": xui.Color_Blue, "Filled": True, "Thickness": 2, "TipWidth": 10, "TipHeight": 15)
	For Each item As FunctionsProperties In b4xfunction.functionList
		DrawSingleLine(item, arrowSpec)
	Next
End Sub

Private Sub DrawSingleLine(item As FunctionsProperties, arrowSpec As Map)
	Dim children As List= item.Childrens
'	If NotInitialized(children) Then
'		Log("Not Initialized")
'		 Return
'	End If
	
	If children.size > 0 Then
		Dim startPoint As Point = item.point1
		Dim y As Double = startPoint.y + item.height + 1
		Dim x As Double = startPoint.x + item.width / 2
		
		For i = 0 To children.size - 1
			Dim child As FunctionsProperties = children.get(i)
			Dim endPoint As Point = child.Point1
			Arrows1.draw2(x, y, endPoint.x+15, endPoint.y, 0, 100, arrowSpec)
		Next
	End If
End Sub

#Region ItemEvents

Private Sub Item_MouseDragged (EventData As MouseEvent)
	If EventData.PrimaryButtonDown Then ScrollPane1.Pannable=False
	ScrollPane1.MouseCursor=Main.fx.Cursors.OPEN_HAND
	Dim pnl As B4XView = Sender
	pnl.Left = pnl.Left + EventData.X - pnl.Width/2 - 20
	pnl.Top= pnl.Top +  EventData.Y - pnl.Height/2 + 10
	IsMoving=True
End Sub

Private Sub Item_MouseReleased (EventData As MouseEvent)
	ScrollPane1.MouseCursor=Main.fx.Cursors.DEFAULT
	ScrollPane1.Pannable=True
	Dim pnl As B4XView = Sender
	Dim item As FunctionsProperties = pnl.Tag
	Dim updatedItem As FunctionsProperties = b4xfunction.UpdateItem(item.ID, b4xfunction.newPoint(pnl.Left, pnl.Top))
	pnl.Tag = updatedItem
	cvs.ClearRect(cvs.TargetRect)
	Dim arrowSpec As Map
	arrowSpec = CreateMap("Color": xui.Color_Blue, "Filled": True, "Thickness": 2, "TipWidth": 10, "TipHeight": 15)
	DrawSingleLine(updatedItem, arrowSpec)
	IsMoving=False
End Sub

Private Sub Item_MouseClicked (EventData As MouseEvent)
	Dim p As B4XView=Sender
	If ControlPressed Then
		p.SetColorAndBorder(p.Color, 2, xui.Color_Blue,8)
		IsMoving=True
	Else
		p.SetColorAndBorder(p.Color, 1, xui.Color_Black,8)
	End If
End Sub

#End Region

Public Sub ExportToGraphviz As String
	Dim sb As StringBuilder
	sb.Initialize
	sb.Append($"digraph B4XTable {
	'node [shape=box, style=filled, fontname="Arial"];"$).Append(CRLF)

	For Each item As FunctionsProperties In b4xfunction.functionList
		Dim funcName As String = item.ExtractName
		Dim funcType As String = item.Status.ToLowerCase
		Dim fillColor As String = IIf(funcType = "private", "#FF8C00", "#003BFF")
		Dim fontColor As String = IIf(funcType = "private", "black", "white")
		sb.Append($"${funcName} [fillcolor=\"${fillColor}\", fontcolor=\"${fontColor}\", label=\"${funcName}\" ];"$).Append(CRLF)
	Next
	For Each item As FunctionsProperties In b4xfunction.functionList
		Dim parentFunc As String = item.ExtractName
		Dim children As List = b4xfunction.GetChildrenFromItem(item)
		If(NotInitialized(children)) Then Continue
		Dim childMap As Map
		childMap.Initialize
		For Each child As FunctionsProperties In children
			Dim childFunc As String = child.ExtractName
			childMap.Put(childFunc, "")
		Next
		If childMap.Size > 0 Then
			Dim innerSb As StringBuilder
			innerSb.Initialize
			innerSb.Append(parentFunc).Append(" -> {")
			For Each k As String In childMap.Keys
				innerSb.Append(k).Append(" ")
			Next
			innerSb.Remove(innerSb.Length - 1, innerSb.Length)
			innerSb.Append("}")
			sb.Append(innerSb.ToString).Append(CRLF)
		End If
	Next
	sb.Append("}")
	Return sb.ToString
End Sub

Public Sub ExportToPlantUML As String
	Dim sb As StringBuilder
	sb.Initialize
	sb.Append($"@startuml
skinparam class {
BackgroundColor<<private>> Orange
BackgroundColor<<public>> SkyBlue
}"$).Append(CRLF)

	For Each item As FunctionsProperties In b4xfunction.functionList
		Dim funcName As String = item.ExtractName
		Dim funcType As String = item.Status.ToLowerCase
		Dim lineNum As String = item.Line
		sb.Append($"class ${funcName} <<${funcType}>>
{
Line: ${lineNum}
}"$).Append(CRLF)
	Next
	For Each item As FunctionsProperties In b4xfunction.functionList
		Dim parentFunc As String = item.ExtractName
		Dim children As List = b4xfunction.GetChildrenFromItem(item)
		If(NotInitialized(children)) Then Continue
		Dim prevLink As String
		For Each child As FunctionsProperties In children
			Dim childFunc As String = child.ExtractName
			Dim newLink As String = $"${parentFunc} --> ${childFunc}"$
			If(newLink = prevLink) Then Continue
			sb.Append(newLink).Append(CRLF)
			prevLink = newLink
		Next
	Next
	sb.Append("@enduml")
	Return sb.ToString
End Sub

