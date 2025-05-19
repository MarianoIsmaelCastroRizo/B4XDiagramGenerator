B4J=true
Group=Default Group
ModulesStructureVersion=1
Type=Class
Version=9.8
@EndOfDesignText@
Sub Class_Globals
	Type Point(X As Double, Y As Double)
		
	Type FunctionsProperties (ID As Int, FullName As String, ExtractName As String, _
	Line As Int, Status As String, Point1 As Point, _ 
	Childrens As List, Width As Int, Height As Int)
	
	Public functionList As List
End Sub

Public Sub Initialize
	functionList.Initialize
End Sub

Public Sub Add(fullName As String,  extractName As String, _
	 line As Int, pointX As Double, pointY As Double, status As String)
	 
	Dim Item As FunctionsProperties :	Item.Initialize
	Item.FullName = fullName
	Item.ExtractName = extractName
	Item.Line = line
	Item.Status = status
	Item.ID=functionList.Size	
	Item.Point1= newPoint(pointX, pointY)
	Item.Childrens = B4XCollections.GetEmptyList 'Default is empty
	functionList.Add(Item)
End Sub

Public Sub newPoint (X As Double, Y As Double) As Point
	Dim t1 As Point : t1.Initialize
	t1.X = X : t1.Y = Y
	Return t1
End Sub

Public Sub UpdateItem(ID As Int, pt As Point) As FunctionsProperties
	Dim newItem As FunctionsProperties = functionList.Get(ID)
	newItem.Point1=pt
	functionList.Set(ID,newItem)
	Return newItem
End Sub

Public Sub GetChildrenFromItem(ItemSearch As FunctionsProperties) As List
	For Each Item As FunctionsProperties In functionList
		If Item = ItemSearch Then
			Return Item.Childrens
		End If
	Next
	Dim listDefault As List
	Return listDefault
End Sub

Public Sub GetItem(nameFunction As String) As FunctionsProperties
	For Each item As FunctionsProperties In functionList
		If item.ExtractName = nameFunction Then
			Return item
		End If
	Next
	Dim itemDefault As FunctionsProperties
	Return itemDefault
End Sub
