SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
CREATE PROCEDURE [dbo].[spPortalGet_Menu]

@UserID int = NULL,
@InstanceID int = NULL,
@VersionID int = NULL,
@ApplicationID int = NULL,
@MenuTypeBM int = NULL,
@MenuID int = NULL,
@GetVersion bit = 0,
@Debug int = 0

--EXEC spPortalGet_Menu @UserID = -10, @InstanceID = 304, @VersionID = 1001, @MenuTypeBM = 1, @Debug = 1

--#WITH ENCRYPTION#--

AS

DECLARE
	@Column nvarchar(50),
	@Command nvarchar(255),
	@ValidYN bit,
	@SQLStatement nvarchar(max),
	@Description nvarchar(255),
	@Version nvarchar(50) = '1.4.0.2134'

IF @GetVersion <> 0
	BEGIN
		IF @Version = '1.4.0.2134' SET @Description = 'Procedure created.'

		SELECT [Version] =  @Version, [Description] = @Description
		RETURN
	END

IF @UserID IS NULL OR @InstanceID IS NULL OR @VersionID IS NULL OR @MenuTypeBM IS NULL
	BEGIN
		PRINT 'Parameter @UserID, @InstanceID, @VersionID and @MenuTypeBM must be set'
		RETURN 
	END

SELECT
	@ApplicationID = ISNULL(@ApplicationID, MAX(ApplicationID))
FROM
	[Application]
WHERE
	InstanceID = @InstanceID AND
	SelectYN <> 0

IF @Debug <> 0 SELECT ApplicationID = @ApplicationID

CREATE TABLE #Valid (ValidYN bit)

SELECT
	MenuID,
	MenuName,
	MenuDescription,
	MenuParentID,
	MenuItemTypeID,
	MenuParameter,
	SortOrder,
	LicenseYN = CONVERT(bit, CASE WHEN ISNUMERIC(LicenseYN) <> 0 THEN LicenseYN ELSE 0 END),
	ExistYN = CONVERT(bit, CASE WHEN ISNUMERIC(ExistYN) <> 0 THEN ExistYN ELSE 0 END),
	SecurityYN = CONVERT(bit, CASE WHEN ISNUMERIC(SecurityYN) <> 0 THEN SecurityYN ELSE 0 END),
	License_String = LicenseYN,
	Exist_String = ExistYN,
	Security_String = SecurityYN
INTO
	#Menu
FROM
	Menu
WHERE
	InstanceID IN(0, @InstanceID) AND
	(VersionID = @VersionID OR VersionID = 0) AND
	MenuTypeBM & @MenuTypeBM > 0 AND
	(MenuID = @MenuID OR @MenuID IS NULL)
ORDER BY
	SortOrder

IF @Debug <> 0 SELECT TempTable = '#Menu', * FROM #Menu

		DECLARE Menu_Cursor CURSOR FOR
			SELECT 
				[MenuID],
				[Column] = 'LicenseYN',
				[Command] = REPLACE(REPLACE(REPLACE(License_String, '@UserID_Replace', @UserID), '@ApplicationID_Replace', @ApplicationID), '@InstanceID_Replace', @InstanceID)
			FROM
				#Menu
			WHERE
				ISNUMERIC(License_String) = 0

			UNION SELECT 
				[MenuID],
				[Column] = 'ExistYN',
				[Command] = REPLACE(REPLACE(REPLACE(Exist_String, '@UserID_Replace', @UserID), '@ApplicationID_Replace', @ApplicationID), '@InstanceID_Replace', @InstanceID)
			FROM
				#Menu
			WHERE
				ISNUMERIC(Exist_String) = 0

			UNION SELECT 
				[MenuID],
				[Column] = 'SecurityYN',
				[Command] = REPLACE(REPLACE(REPLACE(Security_String, '@UserID_Replace', @UserID), '@ApplicationID_Replace', @ApplicationID), '@InstanceID_Replace', @InstanceID)
			FROM
				#Menu
			WHERE
				ISNUMERIC(Security_String) = 0

			ORDER BY
				[MenuID],
				[Column]

			OPEN Menu_Cursor
			FETCH NEXT FROM Menu_Cursor INTO @MenuID, @Column, @Command

			WHILE @@FETCH_STATUS = 0
				BEGIN
					IF @Debug <> 0 SELECT [MenuID] = @MenuID, [Column] = @Column, [Command] = @Command

					TRUNCATE TABLE #Valid

					INSERT INTO #Valid (ValidYN) EXEC (@Command)

					IF @Debug <> 0 SELECT TempTable = '#Valid', [MenuID] = @MenuID, [Column] = @Column, * FROM #Valid

					SET @SQLStatement = '
						UPDATE M
						SET
							' + @Column + ' = V.ValidYN
						FROM
							#Menu M
							INNER JOIN #Valid V ON 1 = 1
						WHERE
							M.[MenuID] = ' + CONVERT(nvarchar(10), @MenuID)

					IF @Debug <> 0 PRINT @SQLStatement

					EXEC (@SQLStatement)

					FETCH NEXT FROM Menu_Cursor INTO  @MenuID, @Column, @Command
				END

		CLOSE Menu_Cursor
		DEALLOCATE Menu_Cursor	

	SELECT 
		MenuID,
		MenuName,
		MenuDescription,
		MenuParentID,
		MenuItemTypeID,
		MenuParameter,
		SortOrder
	FROM
		#Menu
	WHERE
		LicenseYN <> 0 AND
		ExistYN <> 0 AND
		SecurityYN <> 0
	ORDER BY
		SortOrder

	DROP TABLE #Menu
	DROP TABLE #Valid
GO
