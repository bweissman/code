use [BimlDemo_SSIS_Performance]

exec [SP_CleanTables]

truncate table meta.tables 
insert into meta.tables ([TableName]
      ,[Pattern]
      ,[Parameters]
      ,[LastAvg]
      ,[Active]
      ,[Container])
SELECT [TableName]
      ,[Pattern]
      ,[Parameters]
      ,[LastAvg]
      ,[Active]
	  , Container
  FROM [BimlDemo_SSIS_Performance].[SAMPLES].[Tables] where SampleName= 'Plain'
  AND TableName <> 'Salesline'

   

  truncate table meta.tables 
insert into meta.tables ([TableName]
      ,[Pattern]
      ,[Parameters]
      ,[LastAvg]
      ,[Active]
      ,[Container])
SELECT [TableName]
      ,[Pattern]
      ,[Parameters]
      ,[LastAvg]
      ,[Active]
      ,[Container]
  FROM [BimlDemo_SSIS_Performance].[SAMPLES].[Tables] where SampleName= 'Many'


  exec [dbo].[SP_SetContainers] 1
  GO
  Select * from [META].[Container]


  exec [dbo].[SP_SetContainers] 3
  GO
  Select * from [META].[Container] ORDER BY Duration desc
  
  exec [dbo].[SP_SetContainers] 7
  GO
  Select * from [META].[Container] ORDER BY Duration desc

  exec [dbo].[SP_SetContainers] 8
  GO
  Select * from [META].[Container] ORDER BY Duration desc
