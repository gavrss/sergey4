SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
CREATE PROCEDURE [dbo].[spSend_MailMessage]
	@UserID int = NULL,
	@InstanceID int = NULL,
	@VersionID int = NULL,

	@UserPropertyTypeID int = NULL, --Mandatory
	@UserID_Group int = NULL, --Mandatory
	@ApplicationID INT = NULL,

	@JobID int = NULL, --Mandatory
	@Rows int = NULL,
	@ProcedureID INT = 880000186,
	@Parameter NVARCHAR(4000) = NULL,
	@StartTime DATETIME = NULL,
	@Duration datetime = 0 OUT,
	@Deleted int = 0 OUT,
	@Inserted int = 0 OUT,
	@Updated int = 0 OUT,
	@GetVersion bit = 0,
	@Debug bit = 0

--#WITH ENCRYPTION#--

AS
/*
EXEC spRun_Procedure_KeyValuePair
	@ProcedureName = 'spSend_MailMessage',
	@JSON = '
		[
		{"TKey" : "UserID",  "TValue": "-10"},
		{"TKey" : "InstanceID",  "TValue": "114"},
		{"TKey" : "VersionID",  "TValue": "1004"},
		{"TKey" : "UserPropertyTypeID",  "TValue": "-5"},
		{"TKey" : "UserID_Group",  "TValue": "-4"},
		{"TKey" : "JobID",  "TValue": "200"}
		]'
EXEC [spSend_MailMessage] @JobID = 0, @UserID_Group = -4, @InstanceID = 404,   @UserPropertyTypeID = -5, @Debug = 1 --Salinity @ApplicationID = 1312,
EXEC [spSend_MailMessage] @UserID = -10,  @InstanceID = 114, @VersionID = 1004, @UserPropertyTypeID = -5, @UserID_Group = -4, @JobID = 200, @Debug = 1 --AnnJoo @ApplicationID = 1314,
EXEC [spSend_MailMessage] @UserID = -10,  @InstanceID = 114, @VersionID = 1004, @UserPropertyTypeID = -6, @UserID_Group = -4, @JobID = 200, @Debug = 1 --AnnJoo @ApplicationID = 1314,
EXEC [spSend_MailMessage] @GetVersion = 1
*/
DECLARE
	@pcPortal_URL nvarchar(255),
	@Mail_ProfileName nvarchar(128),
	@Subject nvarchar(255),
	@Body nvarchar(max),
	@Importance varchar(6),
	@Recipient nvarchar(max),
	@CC nvarchar(max),
	@BCC nvarchar(max),
	@BodyHTML nvarchar(max),
	@ETLDatabase nvarchar(100),
	@SQLStatement nvarchar(max),

	@Step nvarchar(255),
	@JobLogID int,
	@ErrorNumber int,
	@Message nvarchar(500) = '',
	@Severity int = 0,
	@UserName nvarchar(100),
	@Description nvarchar(255),
	@Version nvarchar(50) = '1.4.0.2139'

IF @GetVersion <> 0
	BEGIN
		IF @Version = '1.4.0.2134' SET @Description = 'Procedure created.'
		IF @Version = '1.4.0.2139' SET @Description = 'Updated to standard template.'

		IF ISNULL((SELECT [ProcedureID] FROM [Procedure] WHERE [ProcedureName] = OBJECT_NAME(@@PROCID) AND DeletedID IS NULL), 0) <> @ProcedureID
			BEGIN
				SET @ProcedureID = NULL
				SELECT @ProcedureID = [ProcedureID] FROM [Procedure] WHERE [ProcedureName] = OBJECT_NAME(@@PROCID) AND DeletedID IS NULL
				IF @ProcedureID IS NULL
					SET @Message = 'SP ' + OBJECT_NAME(@@PROCID) + ' is not registered. Run SP spInsert_Procedure'
				ELSE
					SET @Message = 'ProcedureID mismatch, should be ' + CONVERT(nvarchar(10), @ProcedureID)
				SET @Severity = 16
				GOTO EXITPOINT
			END
		SELECT [Version] = @Version, [Description] = @Description, [ProcedureID] = @ProcedureID
		RETURN
	END

BEGIN TRY
	SET @Step = 'Set @StartTime'
		SET @StartTime = ISNULL(@StartTime, GETDATE())
		
	SET @Step = 'Set procedure variables'
		SELECT
			@Deleted = ISNULL(@Deleted, 0),
			@Inserted = ISNULL(@Inserted, 0),
			@Updated = ISNULL(@Updated, 0)

		SELECT @UserName = ISNULL(@UserName, suser_name())

		SELECT
			@ApplicationID = ISNULL(@ApplicationID, ApplicationID)
		FROM
			[Application]
		WHERE
			InstanceID = @InstanceID AND
			SelectYN <> 0

		SELECT
			@pcPortal_URL = [pcPortal_URL],
			@Mail_ProfileName = [Mail_ProfileName]
		FROM
			[Instance]
		WHERE
			InstanceID = @InstanceID

		SELECT 
			@ETLDatabase = ETLDatabase
		FROM
			[Application]
		WHERE
			ApplicationID = @ApplicationID

		IF @Debug <> 0 
			SELECT
				InstanceID = @InstanceID,
				ApplicationID = @ApplicationID,
				pcPortal_URL = @pcPortal_URL,
				Mail_ProfileName = @Mail_ProfileName

	SET @Step = 'Check mail profile'
		Mail:
		IF @Mail_ProfileName IS NULL
			BEGIN
				SET @Message = 'Mail_Profilename is not defined for selected InstanceID (' + CONVERT(nvarchar(10), @InstanceID) + ')'
				SET @Severity = 16
				GOTO EXITPOINT
			END
		ELSE
			CREATE TABLE #Recipient
				(
				Recipient nvarchar(100),
				CC nvarchar(100),
				BCC nvarchar(100)
				)

		SELECT 
			@Subject = [Subject],
			@Body = REPLACE([Body], '@UserName', @UserName),
			@Importance = [Importance]
		FROM
			[MailMessage]
		WHERE
			[ApplicationID] = @ApplicationID AND
			[UserPropertyTypeID] = @UserPropertyTypeID

		IF @Debug <> 0 
			SELECT
				[Subject] = @Subject,
				Body = @Body,
				Importance = @Importance

	SET @Step = 'Send mail to selected group'
		INSERT INTO #Recipient
			(
			Recipient,
			CC,
			BCC
			)
		SELECT
			Recipient = CASE WHEN ISNULL(UPVU.UserPropertyValue, UPVG.UserPropertyValue) = 'Recipient' THEN UPV3.UserPropertyValue ELSE NULL END,
			CC = CASE WHEN ISNULL(UPVU.UserPropertyValue, UPVG.UserPropertyValue) = 'CC' THEN UPV3.UserPropertyValue ELSE NULL END,
			BCC = CASE WHEN ISNULL(UPVU.UserPropertyValue, UPVG.UserPropertyValue) = 'BCC' THEN UPV3.UserPropertyValue ELSE NULL END
		FROM
			[User] U
			INNER JOIN [UserMember] UM ON UM.UserID_Group = @UserID_Group AND UM.UserID_User = U.UserID AND UM.SelectYN <> 0
			INNER JOIN [UserPropertyValue] UPV3 ON UPV3.UserID = U.UserID AND UPV3.UserPropertyTypeID = -3 AND UPV3.SelectYN <> 0
			LEFT JOIN [UserPropertyValue] UPVU ON UPVU.UserID = U.UserID AND UPVU.UserPropertyTypeID = @UserPropertyTypeID AND UPVU.SelectYN <> 0
			LEFT JOIN [UserPropertyValue] UPVG ON UPVG.UserID = UM.UserID_Group AND UPVG.UserPropertyTypeID = @UserPropertyTypeID AND UPVG.SelectYN <> 0
		WHERE
			(U.InstanceID = @InstanceID OR U.InstanceID = 0) AND
			U.SelectYN <> 0

		IF @Debug <> 0 SELECT TempTable = '#Recipient', * FROM #Recipient

		IF (SELECT COUNT(1) FROM #Recipient) = 0
			BEGIN
				SET @Message = 'No valid recipients are selected'
				SET @Severity = 16
				DROP TABLE #Recipient
				GOTO EXITPOINT
			END

		SELECT
			@Recipient = '',
			@CC = '',
			@BCC = ''

		SELECT
			@Recipient = @Recipient + CASE WHEN Recipient IS NULL THEN '' ELSE Recipient + ';' END,
			@CC = @CC + CASE WHEN CC IS NULL THEN '' ELSE CC + ';' END,
			@BCC = @BCC + CASE WHEN BCC IS NULL THEN '' ELSE BCC + ';' END
		FROM
			#Recipient

		SELECT
			@Recipient = CASE WHEN LEN(@Recipient) >= 4 THEN SUBSTRING(@Recipient, 1, LEN(@Recipient) -1) ELSE '' END,
			@CC = CASE WHEN LEN(@CC) >= 4 THEN SUBSTRING(@CC, 1, LEN(@CC) -1) ELSE '' END,
			@BCC = CASE WHEN LEN(@BCC) >= 4 THEN SUBSTRING(@BCC, 1, LEN(@BCC) -1) ELSE '' END

	SET @Step = 'Handle CheckSum'
		IF @UserPropertyTypeID IN (-5, -6)
			BEGIN
				CREATE TABLE #CheckSum
					(
					CheckSumName nvarchar(100),
					JobID int,
					CheckSumValue int,
					CheckSumReport nvarchar(100),
					EndTime datetime,
					SortOrder int
					)

				SET @SQLStatement = '
				INSERT INTO #CheckSum
					(
					CheckSumName,
					JobID,
					CheckSumValue,
					CheckSumReport,
					EndTime,
					SortOrder
					)
				SELECT 
					CS.CheckSumName,
					CSL.JobID,
					CSL.CheckSumValue,
					CSL.CheckSumReport,
					CSL.EndTime,
					CS.SortOrder
				FROM
					' + @ETLDatabase + '..[CheckSum] CS
					INNER JOIN ' + @ETLDatabase + '..[CheckSumLog] CSL ON CSL.JobID = ' + CONVERT(nvarchar(10), @JobID) + ' AND CSL.CheckSumID = CS.CheckSumID'

				IF @Debug <> 0 PRINT @SQLStatement
				EXEC (@SQLStatement)
				IF @Debug <> 0 SELECT TempTable = '#CheckSum', * FROM #CheckSum

				SET @BodyHTML = '
					<html>
					<body>
					' + @Body + '
					<table border="1" cellspacing="0" cellpadding="0"><colgroup><col width="60" /><col width="400" /><col width="60" /><col width="200" /></colgroup>
						<tbody>
						<tr>
							<td>JobID</td>
							<td>Name</td>
							<td>Errors#</td>
							<td>Time</td>
						</tr>'

				SELECT
					@BodyHTML = ISNULL(@BodyHTML, '') + CASE WHEN CheckSumValue > 0 THEN '<font color="red">' ELSE '' END +
								CHAR(13) + CHAR(10) + CHAR(9) + '<tr>' + 
								CHAR(13) + CHAR(10) + CHAR(9) + CHAR(9) + '<td>' + CONVERT(nvarchar(10), JobID) + '</td>' +
								CHAR(13) + CHAR(10) + CHAR(9) + CHAR(9) + '<td><a href="' + CheckSumReport + '">' + CheckSumName + '</a></td>' +
								CHAR(13) + CHAR(10) + CHAR(9) + CHAR(9) + '<td>' + CONVERT(nvarchar(10), CheckSumValue) + '</td>' + 
								CHAR(13) + CHAR(10) + CHAR(9) + CHAR(9) + '<td>' + CONVERT(nvarchar(50), EndTime) + '</td>' +
								CHAR(13) + CHAR(10) + CHAR(9) + '</tr>' + CASE WHEN CheckSumValue > 0 THEN '</font>' ELSE '' END
				FROM
					[#CheckSum]
				WHERE
					CheckSumValue > 0 OR @UserPropertyTypeID = -5
				ORDER BY
					SortOrder DESC,
					EndTime

				SET @BodyHTML = @BodyHTML + CHAR(13) + CHAR(10) + CHAR(9) + '</tbody>' + CHAR(13) + CHAR(10) + '</table>' + CHAR(13) + CHAR(10) + '</body>'  + CHAR(13) + CHAR(10) + '</html>'

				DROP TABLE #CheckSum
			END
		ELSE
			SET @BodyHTML = @Body

		IF @Debug <> 0
			BEGIN
				SELECT
					Profile_name = @Mail_ProfileName,
					Recipient = @Recipient,
					CC = @CC,
					BCC = @BCC,
					[Subject] = @Subject, 
					Body = @BodyHTML, 
					Body_format = 'HTML',
					Importance = @Importance

				PRINT @BodyHTML
			END

		EXEC msdb..sp_send_dbmail 
				@profile_name = @Mail_ProfileName,
				@recipients = @Recipient,
				@copy_recipients = @CC,
				@blind_copy_recipients = @BCC,
				@subject = @Subject, 
				@body = @BodyHTML, 
				@body_format = 'HTML',
				@importance = @Importance

	SET @Step = 'Drop temp tables'
		DROP TABLE #Recipient

	SET @Step = 'Set @Duration'
		SET @Duration = GetDate() - @StartTime

	SET @Step = 'Insert into JobLog'
		INSERT INTO JobLog (JobID, StartTime, ProcedureName, Duration, Deleted, Inserted, Updated, [Version], [Parameter], [UserName], [UserID], [InstanceID], [VersionID]) SELECT ISNULL(@JobID, @ProcedureID), @StartTime, OBJECT_NAME(@@PROCID), @Duration, @Deleted, @Inserted, @Updated, @Version, @Parameter, @UserName, @UserID, @InstanceID, @VersionID
				
	RETURN 0
END TRY

BEGIN CATCH
	INSERT INTO JobLog (JobID, StartTime, ProcedureName, Duration, Deleted, Inserted, Updated, ErrorNumber, ErrorSeverity, ErrorState, ErrorLine, ErrorProcedure, ErrorStep, ErrorMessage, [Version], [Parameter], [UserName], [UserID], [InstanceID], [VersionID]) SELECT ISNULL(@JobID, @ProcedureID), @StartTime, OBJECT_NAME(@@PROCID), GetDate() - @StartTime, @Deleted, @Inserted, @Updated, ERROR_NUMBER(), ERROR_SEVERITY(), ERROR_STATE(), ERROR_LINE(), ERROR_PROCEDURE(), @Step, ERROR_MESSAGE(), @Version, @Parameter, @UserName, @UserID, @InstanceID, @VersionID
	SET @JobLogID = @@IDENTITY
	SELECT @ErrorNumber = ErrorNumber FROM JobLog WHERE JobLogID = @JobLogID
	SELECT ErrorNumber, ErrorSeverity, ErrorState, ErrorProcedure, ErrorStep, ErrorLine, ErrorMessage FROM JobLog WHERE JobLogID = @JobLogID
	RETURN @ErrorNumber
END CATCH

SET @Step = 'Define exit point'
	EXITPOINT:
	RAISERROR (@Message, @Severity, 100)
GO
