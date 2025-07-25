CREATE TABLE [dbo].[_Dimension_Member_sega]
(
[InstanceID] [int] NULL,
[DimensionID] [int] NULL,
[MemberID] [int] NULL,
[MemberKey] [nvarchar] (100) NULL,
[MemberDescription] [nvarchar] (255) NULL,
[HelpText] [nvarchar] (1024) NULL,
[NodeTypeBM] [int] NULL,
[SBZ] [bit] NULL,
[Source] [nvarchar] (50) NULL,
[Synchronized] [bit] NULL,
[LevelNo] [int] NULL,
[Level] [nvarchar] (50) NULL,
[SortOrder] [int] NULL,
[Parent] [nvarchar] (100) NULL,
[p@ProductCategory] [nvarchar] (255) NULL,
[p@ProductGroup] [nvarchar] (255) NULL,
[p@CountryOrigin] [nvarchar] (50) NULL,
[p@EntityPriority] [int] NULL,
[p@EntitySource] [nvarchar] (255) NULL,
[p@Hierarchy_SequenceNumber] [int] NULL,
[p@InActive] [nvarchar] (6) NULL,
[p@Level] [nvarchar] (50) NULL,
[p@Lvl1_ProdFamilyMainGroup_Description] [nvarchar] (255) NULL,
[p@Lvl1_ProdFamilyMainGroup_Label] [nvarchar] (50) NULL,
[p@Lvl2_ProdFamilySubGroup_Description] [nvarchar] (255) NULL,
[p@Lvl2_ProdFamilySubGroup_Label] [nvarchar] (50) NULL,
[p@Lvl3_ProdType_Description] [nvarchar] (255) NULL,
[p@Lvl3_ProdType_Label] [nvarchar] (50) NULL,
[p@Lvl4_ProdGroupActualDesc_Description] [nvarchar] (255) NULL,
[p@Lvl4_ProdGroupActualDesc_Label] [nvarchar] (50) NULL,
[p@Lvl5_ProductGroup_Description] [nvarchar] (255) NULL,
[p@Lvl5_ProductGroup_Label] [nvarchar] (50) NULL,
[p@MainGroup] [nvarchar] (50) NULL,
[p@Manufacturer] [nvarchar] (50) NULL,
[p@ManufacturerShortName] [nvarchar] (50) NULL,
[p@MtlAnalysis] [nvarchar] (250) NULL,
[p@ProdBase] [float] NULL,
[p@ProdDiameter] [float] NULL,
[p@ProdFamily] [nvarchar] (50) NULL,
[p@ProdFamily_ProductGroup] [nvarchar] (100) NULL,
[p@ProdFamilyDesc] [nvarchar] (100) NULL,
[p@ProdFamilyMainGroup] [nvarchar] (50) NULL,
[p@ProdFamilySubGroup] [nvarchar] (50) NULL,
[p@ProdGroupActualDesc] [nvarchar] (100) NULL,
[p@ProdHeight] [float] NULL,
[p@ProdKGM] [float] NULL,
[p@ProdLength] [float] NULL,
[p@ProdLength_t] [nvarchar] (20) NULL,
[p@ProdMaterialDesc] [nvarchar] (50) NULL,
[p@ProdOwnership] [nvarchar] (50) NULL,
[p@ProdThickness] [float] NULL,
[p@ProdTop] [float] NULL,
[p@ProdType] [nvarchar] (50) NULL,
[p@ProductGroupDesc] [nvarchar] (50) NULL,
[p@ProductManufacturer] [nvarchar] (50) NULL,
[p@ProdWidth] [float] NULL,
[p@SpecGroup] [nvarchar] (50) NULL,
[p@TopNode] [nvarchar] (50) NULL,
[p@TradeMaterial] [nvarchar] (50) NULL
)
GO
