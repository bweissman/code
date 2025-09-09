USE master
GO
CREATE MASTER KEY ENCRYPTION BY PASSWORD = 'MyVeryS3cureP@ssw0rd'
GO
USE TestDB
GO
SELECT * FROM [Users]
-- now setup MI Link
GO
USE master
GO
SELECT name, encryption_algorithm_desc, connection_auth_desc FROM sys.database_mirroring_endpoints
SELECT name FROM sys.certificates
GO
USE TestDB
GO
INSERT INTO Users VALUES (2, 'Ironman')
GO
SELECT * FROM [Users]
GO
CREATE TABLE [dbo].[Items](
	[Id] [int] NOT NULL,
	[Name] [nvarchar](50) NULL
) ON [PRIMARY]
