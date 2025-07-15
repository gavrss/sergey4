SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO

CREATE PROCEDURE [dbo].[spPortalGet_MetaData_List]

	@InstanceID int,
	@UserID int,
	@MetaDataTypeBM int --User = 1, WorkFlowState = 2, Supported Locale = 4, Supported Language = 8, Country = 16

AS

--EXEC [spPortalGet_MetaData_List] @InstanceID = 304, @UserID = 1004, @MetaDataTypeBM = 2

IF @MetaDataTypeBM & 1 > 0 --User

SELECT 
	U.[InstanceID],
	[UserID],
	[UserName],
	[UserNameAD],
	[UserNameDisplay],
	U.[UserTypeID],
	UserTypeName = UT.UserTypeName,
	U.[UserLicenseTypeID],
	UserLicenseTypeName = ULT.UserLicenseTypeName,
	U.[LocaleID],
	L.[LocaleCode],
	LocaleName = L.LocaleName,
	U.[LanguageID],
	LanguageName = La.LanguageName_ISO
FROM
	[pcINTEGRATOR].[dbo].[User] U
	LEFT JOIN UserType UT ON UT.UserTypeID = U.UserTypeID
	LEFT JOIN UserLicenseType ULT ON ULT.UserLicenseTypeID = U.UserLicenseTypeID
	LEFT JOIN Locale L ON L.LocaleID = U.LocaleID
	LEFT JOIN [Language] La ON La.LanguageID = U.LanguageID
WHERE
	U.InstanceID = @InstanceID AND
	U.SelectYN <> 0

IF @MetaDataTypeBM & 2 > 0 --WorkFlowState
	SELECT
		WorkFlowStateID,
		WorkflowStateName
	FROM
		WorkFlowState
	WHERE
		InstanceID = @InstanceID

IF @MetaDataTypeBM & 4 > 0 -- Supported Locale list
	SELECT
		LocaleID,
		LocaleCode,
		LocaleName,
		LanguageID,
		CountryID
	FROM
		Locale
	WHERE
		SelectYN <> 0

IF @MetaDataTypeBM & 8 > 0 -- Supported Language list
	SELECT
	  [LanguageID],
	  [LanguageCode],
      [LanguageName],
      [LanguageName],
      [LanguageCode_ISO3],
      [LanguageName_Eng],
      [LanguageName_ISO],
      [LanguageName_Native],
      [LanguageCode_639-1],
      [LanguageCode_639-2/T],
      [LanguageCode_639-2/B],
      [LanguageCode_639-3],
      [LanguageFamily]
	FROM
		[Language]
	WHERE
		SelectYN <> 0

IF @MetaDataTypeBM & 16 > 0 -- Country list
	SELECT
		*
	FROM
		Country

GO
