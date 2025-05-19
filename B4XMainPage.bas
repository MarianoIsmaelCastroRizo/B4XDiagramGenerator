B4A=true
Group=Default Group
ModulesStructureVersion=1
Type=Class
Version=9.85
@EndOfDesignText@
#Region Shared Files
#CustomBuildAction: folders ready, %WINDIR%\System32\Robocopy.exe,"..\..\Shared Files" "..\Files"
'Ctrl + click to sync files: ide://run?file=%WINDIR%\System32\Robocopy.exe&args=..\..\Shared+Files&args=..\Files&FilesSync=True
#End Region

'Ctrl + click to export as zip: ide://run?File=%B4X%\Zipper.jar&Args=B4XDiagramGenerator_versionEstable.zip

Sub Class_Globals
	Private Root As B4XView
	Private xui As XUI

	Private kvs As KeyValueStore
	Private MenuBar1 As MenuBar
	Private RecentManager As RecentFilesManager
	
	Private PanelPopup As B4XView
	Private dialog As B4XDialog
	Private dialog2 As B4XProgressDialog
	Private txtNameProject As B4XView
	Private nameApp As String = "B4X Diagram Generator"
	
	Private FC As FileChooser
	Private TabPane1 As TabPane
	Private CurrenPage As GenericTab
	Private Arc As Archiver	
	
	Private exportToClipboard As Boolean
End Sub

Public Sub Initialize
	B4XPages.GetManager.LogEvents = True	
End Sub

Private Sub B4XPage_Created (Root1 As B4XView)
	Root = Root1
	Root.LoadLayout("MainPage")
	xui.SetDataFolder(nameApp)

	kvs.Initialize(xui.DefaultFolder,"kvs.dat")
	RecentManager.Initialize(Me, "RecentManager", MenuBar1.Menus.Get(0))
	dialog.Initialize(Root)
	dialog2.Initialize(Root)
	dialog.Title = nameApp
	
	FC.Initialize
	FC.Title = nameApp
	
	Dim documents As String = GetSystemProperty("user.home", "") & "/Documents"
	FC.InitialDirectory=documents
	
	B4XPages.SetTitle(Me, nameApp)
End Sub

Private Sub CrearPaginas(pages As List) As ResumableSub
	TabPane1.Tabs.Clear
	Log(pages.Size)
	
	dialog2.ShowDialog("Wait, please....")
	For Each infoFile As Map In pages
		Dim InfoSaved As Map = infoFile.GetDefault("InfoSaved", Null)		
				
		Dim gt As GenericTab
		gt.Initialize(TabPane1, infoFile.Get("Name"), infoFile.Get("TextFromFile"), InfoSaved)
	Next
	TabPane1.SelectedIndex = 0
	Sleep(10)
	dialog2.hide
	Return CurrenPage.IsInitialized
End Sub

Private Sub B4XPage_FormClosed
	Log("B4XPage_FormClosed")	
End Sub

Private Sub B4XPage_Resize (Width As Int, Height As Int)
'	ScrollPane1.SetSize(Width, Height -  MenuBar1.Height )
End Sub

Private Sub LoadBASFile As ResumableSub
	FC.SetExtensionFilter("Choose file",Array As String("*.bas"))
	Dim FileChosen As String
	FileChosen=FC.ShowOpen(B4XPages.GetNativeParent(Me))
	If FileChosen = "" Then Return False
	
	Dim filepath As String =File.GetFileParent(FileChosen) ' FileChosen.SubString2(0,FileChosen.LastIndexOf("\"))
	Dim fileName As String = File.GetName(FileChosen) 'FileChosen.SubString(FileChosen.LastIndexOf("\")+1)

	Dim text As String
	text = File.ReadString(filepath, fileName)	
	Dim nameFile As String = fileName.Replace(".bas","")
	Dim infoFile As Map = CreateMap("Name": nameFile, "TextFromFile": text)		
	Wait For(CrearPaginas(Array(infoFile))) Complete(CurrenPageIsInitialized As Boolean)
	Return True
End Sub

Private Sub LoadB4XFile As ResumableSub
	FC.SetExtensionFilter("Choose file",Array As String("*.b4xlib"))
	Dim FileChosen As String
	FileChosen=FC.ShowOpen(B4XPages.GetNativeParent(Me))

	If FileChosen = "" Then Return False
	Dim filepath As String =File.GetFileParent(FileChosen) ' FileChosen.SubString2(0,FileChosen.LastIndexOf("\"))
	Dim fileName As String = File.GetName(FileChosen) 'FileChosen.SubString(FileChosen.LastIndexOf("\")+1)
	
	Dim destination As String = File.Combine(xui.DefaultFolder, fileName)
	File.Delete(destination, "") 'empty folder
	
	Arc.UnZip(filepath, fileName, destination, Null)
	Wait For (File.ListFilesAsync(destination)) Complete (Success As Boolean, listFiles As List)
	Dim archivosProcesar As List
	archivosProcesar.Initialize
	For Each file1 As String In listFiles		
		If file1.EndsWith(".bas") = False Then Continue
		Dim textFromFile As String
		textFromFile = File.ReadString(destination, file1)
		Dim nameFile As String = file1.Replace(".bas","")
		
		Dim infoFile As Map = CreateMap("Name": nameFile, "TextFromFile": textFromFile)
		archivosProcesar.Add(infoFile)
	Next
	Wait For(CrearPaginas(archivosProcesar)) Complete(CurrenPageIsInitialized As Boolean)
	Return True
End Sub

'Return True to close, False to cancel
Private Sub B4XPage_CloseRequest As ResumableSub
	Dim sf As Object = xui.Msgbox2Async("Close?", nameApp, "Yes", "", "No", Null)
	Wait For (sf) Msgbox_Result (Result As Int)
	If Result = xui.DialogResponse_Positive Then		
		RecentManager.SaveList
		ExitApplication
		Return True
	End If
	Return False
End Sub

'Delegate the native menu action to B4XPage_MenuClick.
Private Sub MenuBar1_Action
	Dim mi As MenuItem = Sender
	
	Dim t As String
	If mi.Tag = Null Then t = mi.Text.Replace("_", "") Else t = mi.Tag
	B4XPage_MenuClick(t)
End Sub

Private Sub chkItem_SelectedChange (Selected As Boolean)
'	Log(Selected)
	exportToClipboard = Selected
End Sub

Private Sub B4XPage_MenuClick(item As String)
	Log(item)
	Select item
		Case "Open Bas"
			LoadBASFile
		Case "Open B4XLib"
			LoadB4XFile
		Case "Save Page"
			Dim sf As Object = xui.Msgbox2Async("Save project?", "Attention", "Yes", "Cancel", "No", Null)
			Wait For (sf) Msgbox_Result (Result As Int)
			If Result = xui.DialogResponse_Positive Then
				txtNameProject.Text = CurrenPage.PageName
				PanelPopup.Visible=True
				Wait For (dialog.ShowCustom(PanelPopup, "OK", "", "CANCEL")) Complete (Result As Int)
				If Result = xui.DialogResponse_Positive Then					
					CurrenPage.SaveProject(kvs)					
					RecentManager.AddFile(txtNameProject.Text)
				End If
			End If
		
		Case "Close"
			B4XPage_CloseRequest
			
		Case "Image"
			CurrenPage.SavePaneToImage
			
		Case "PlantUML"			
			Dim uml As String =	CurrenPage.ExportToPlantUML
			If exportToClipboard Then
				Main.fx.Clipboard.SetString(uml)
				Main.fx.ShowExternalDocument("https://www.plantuml.com/plantuml/uml/")
			Else			
				Dim nameFile As String = $"${CurrenPage.PageName}.uml"$
				Dim archivo As String = SaveAs("Save File UML", nameFile, "*.uml", "UML File")
				If archivo <> "" Then
					File.WriteString(archivo, "", uml)
				End If
			End If
			
		Case "Graphviz (DOT)"
			Dim dot As String =	CurrenPage.ExportToGraphviz
			If exportToClipboard Then
				Main.fx.Clipboard.SetString(dot)
				Main.fx.ShowExternalDocument("https://dreampuf.github.io/GraphvizOnline")
			Else				
				Dim nameFile As String = $"${CurrenPage.PageName}.dot"$
				Dim archivo As String = SaveAs("Save File DOT", nameFile, "*.dot", "DOT File")
				If archivo <> "" Then
					File.WriteString(archivo, "", dot)
				End If
			End If
			
		Case "Open PlantUML Online"
			Main.fx.ShowExternalDocument("https://www.plantuml.com/plantuml/uml/")
			
		Case "Open Graphviz Online"
			Main.fx.ShowExternalDocument("https://dreampuf.github.io/GraphvizOnline")
			
		Case "Copy result from Exports to Clipboard"
			
	End Select
End Sub


Private Sub SaveAs(title As String, fileName1 As String, extension As String, tittleExtension As String) As String
	Dim FC2 As FileChooser
	FC2.Initialize
	FC2.Title=title
	Dim desktop As String = GetSystemProperty("user.home", "") & "/Desktop"
	FC2.InitialDirectory = desktop
	FC2.InitialFileName = fileName1
	FC2.SetExtensionFilter(tittleExtension,Array As String(extension))
	
	Dim FileChosen As String
	FileChosen=FC2.ShowSave(B4XPages.GetNativeParent(Me))
	Return FileChosen
End Sub

Private Sub RecentManager_Click (RecentFile As String)
	Dim m As Map = kvs.Get(RecentFile)
	Dim infoSaved As Map = CreateMap("Functions": m.Get("Functions"))
	
	Dim infoFile As Map = CreateMap("Name": m.Get("FileName"), "TextFromFile": "", "InfoSaved": infoSaved )
	Wait For(CrearPaginas(Array(infoFile))) Complete(CurrenPageIsInitialized As Boolean)
End Sub

Private Sub TabPane1_TabChanged (SelectedTab As TabPage)
'	Log(SelectedTab.Tag Is GenericTab)
	If Initialized(SelectedTab) Then
		CurrenPage = SelectedTab.Tag
		CurrenPage.Update
	End If
End Sub