Imports System.Collections.Generic
Imports System.Linq
Imports System.Linq.Expressions
Imports Varigence.Languages.Biml.Table
Imports System.Runtime.CompilerServices

Module TopologySort
    Public LoadedTables As New List(Of String)
    Public LoadableTables As New List(Of AstTableNode)
    Public Level As Integer = 0
    <Extension()>
    Public Function TopoSort(tables As ICollection(Of AstTableNode)) As ICollection(Of AstTableNode)
        Dim visitedList As New List(Of AstTableNode)
        Dim outputList As New List(Of AstTableNode)
        For Each tbl As asttablenode In tables
            TopoVisit(tbl, outputList, visitedList)
        Next
        Return outputList
    End Function

    Private Function TopoVisit(node As AstTableNode, outputList As List(Of AstTableNode), visitedList As List(Of AstTableNode))
        If Not visitedList.Contains(node) Then
            visitedList.Add(node)
            For Each dependentTable As AstTableNode In node.Columns.OfType(Of AstTableColumnTableReferenceNode).Select(Function(c) c.ForeignTable)
                TopoVisit(dependentTable, outputList, visitedList)
            Next
            For Each dependentTable As AstTableNode In node.Columns.OfType(Of AstMultipleColumnTableReferenceNode).Select(Function(c) c.ForeignTable)
                TopoVisit(dependentTable, outputList, visitedList)
            Next
            outputList.Add(node)
        End If
    End Function
End Module
