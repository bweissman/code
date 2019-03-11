Imports Varigence.Biml.CoreLowerer.SchemaManagement
Imports Varigence.Biml.Extensions
Imports Varigence.Languages.Biml
Imports Varigence.Languages.Biml.Connection
Imports System.Data
Imports System.Collections.Generic
Public Class BF
    Public Shared Function GetNonEmptyList(Conn As AstDbConnectionNode, SQL As String) As List(Of String)
        Dim tmplist As New List(Of String)
        If SQL.Contains(" ") = 0 Then SQL = "select * from " + SQL
        Dim DT As DataTable = ExternalDataAccess.GetDataTable(Conn.ConnectionString, SQL)
        For Each dr As datarow In DT.rows
            tmplist.Add(dr.item(0).ToString())
        Next
        If tmplist.Count = 0 Then tmplist.Add("NONEMPTYFILLER")
        Return tmplist
    End Function
    Public Shared Function GetDT(Conn As AstDbConnectionNode, SQL As String) As DataTable
        If SQL.Contains(" ") = 0 Then SQL = "select * from " + SQL
        Return ExternalDataAccess.GetDataTable(Conn.ConnectionString, SQL)
    End Function
    Public Shared Function DefaultImportOptions()
        Return ImportOptions.ExcludeIdentity Or ImportOptions.ExcludePrimaryKey Or ImportOptions.ExcludeUniqueKey Or ImportOptions.ExcludeColumnDefault _
            Or ImportOptions.ExcludeIndex Or ImportOptions.ExcludeCheckConstraint Or ImportOptions.ExcludeForeignKey
    End Function
End Class
