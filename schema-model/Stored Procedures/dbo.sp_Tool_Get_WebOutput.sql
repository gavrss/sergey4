SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
CREATE PROCEDURE [dbo].[sp_Tool_Get_WebOutput]
	@URL varchar(255),
	@Output nvarchar(MAX) OUTPUT

--#WITH ENCRYPTION#--

AS

BEGIN
	DECLARE @tmp nvarchar(MAX), @lnk nvarchar(400), @cmd nvarchar(1000)

	SELECT @lnk = REPLACE(@URL, '&', '"&"')
	SELECT @cmd = N'powershell.exe -noprofile -executionpolicy bypass -command (Invoke-WebRequest -Uri ''' + @lnk + ''' -UseBasicParsing).content'

	--SELECT @URL
	--SELECT @lnk	
	--SELECT @cmd

	DECLARE @tmpTable TABLE (tmpTable nvarchar(max))

	-- To allow advanced options to be changed. 
	EXEC sp_configure 'show advanced options', 1;  
	RECONFIGURE;
	-- To enable the feature.  
	EXEC sp_configure 'xp_cmdshell', 1 
	RECONFIGURE;

	--xp_cmdshell use
	INSERT INTO @tmpTable EXEC xp_cmdshell @cmd

	-- To disable the feature.  
	EXEC sp_configure 'xp_cmdshell', 0;
	RECONFIGURE;
	-- To disallow advanced options to be changed.  
	EXEC sp_configure 'show advanced options', 0;
	RECONFIGURE; 

	--SELECT * FROM @tmpTable
	--SELECT @Output = STRING_AGG(tmpTable, '') FROM @tmpTable

	SELECT @Output = ''

	DECLARE Sample_Cursor CURSOR FOR
			
			SELECT tmp = tmpTable FROM @tmpTable

			OPEN Sample_Cursor
			FETCH NEXT FROM Sample_Cursor INTO @tmp

			WHILE @@FETCH_STATUS = 0
				BEGIN
					SELECT @Output = @Output + ISNULL(@tmp, '')

					FETCH NEXT FROM Sample_Cursor INTO @tmp
				END

		CLOSE Sample_Cursor
		DEALLOCATE Sample_Cursor

END
GO
