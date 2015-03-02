USE [custom]
GO
/****** Object:  StoredProcedure [dbo].[PostProcessStory_beta]    Script Date: 03/02/2015 10:00:18 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
/********************************************************************************
 * Method      : MNG Post save story processing
 * Purpose     : post process stories after they have been saved in online database
 *               - Add SEO label
 *               - Add publication taxonomy
 *               - Add news profile as main profile in some cases
				 - Convert dateline to all caps
 * 20140419 MY : Created
 * 20130706 MY : Fixed default publication taxonomy word
 * 20141224 SW : Added a script for converting the dateline to all uppercase letters. 
			     This was done per for SalesForce case 00064439
 ********************************************************************************/
ALTER PROCEDURE [dbo].[PostProcessStory_beta] 
  @ASite            varchar(2)       = '', 
  @AGUID            varchar(255)     = null,
  @afallbackprofile int              = 1033598,
  @AddPublicatoinTaxonomy int        = 0,
  @publicationTaxonomy    int        = 0,
  @Adebug                 int        = 0 as
  
declare
  @LStoryDate varchar(8),
  @LStoryCategory varchar(54),
  @LStoryId int,
  @LUpdArtIndex int,
  @UpdateArtIndex int,
  @modifiedby varchar(54)
  
  /* Stores the character position number after >> in a string */ 
  declare @AsubstringNumTable table (substringNum int) 

  /*
  Declaring a variable so we can assign it to the value in the substringNum column 
  in the @AsubstirngNumTable temp table
  */ 
  declare @AsubstringNumVal int
  
  /* 
  Stores the original tekst data , this is used beacause text data types 
  can't be used in REPLACE() functions 
  */ 
  declare @AparagraphText1 varchar(5000) 

  /* Stores the result of the replacement */ 
  declare @AparagraphText2 varchar(5000) 

begin
  set nocount on
  
  set @LStoryDate            = ''
  set @LStoryCategory        = ''
  set @LStoryId              = -1  
  set @LUpdArtIndex          = -1
  set @UpdateArtIndex        = -1
  
  if @ASite <> '' and @AGUID <> ''
  begin
    select @LStoryDate=a.Dato, @LStoryCategory=a.Kategori, @LStoryId=a.Lopenr,
      @modifiedby=b.LastModifiedBy
    from web.dbo.Artikkler_hode (nolock) a
      left join web.dbo.Artikkler_status (nolock) b
        on (b.Avis=a.Avis and b.Dato=a.Dato and b.Kategori=a.Kategori and b.Lopenr=a.Lopenr)
    where a.Avis=@ASite and RowGUID=@AGUID
    
	/* inserting the position number after the >> chracters in a string into this table*/ 
	insert into @AsubstringNumTable (substringNum)
	select patindex('%&gt;&gt;%', Tekst) 
	from web.dbo.artikkler_tekst (nolock)
	where Avis=@ASite and Lopenr=@LStoryId

	/* 
	Assigning the value of the substringNum column in the AsubstringNumTable 
	to this variable 
	*/ 
	select @AsubstringNumVal = 
	substringNum 
	from @AsubstringNumTable

	/* 
	Assinging the original text in the Tekst column for the artikkler_tekst table 
	to this variable 
	*/ 
	select @AparagraphText1 = 
	Tekst 
	from web.dbo.artikkler_tekst (nolock)
	where Avis=@ASite and Lopenr=@LStoryId


	/* Assinging the replacement result to this variable */ 
	select @AparagraphText2 = 
	REPLACE
	(
	@AparagraphText1,
	REPLACE(SUBSTRING(@AparagraphText1,0,@AsubstringNumVal),'<hardreturn>',''),
	UPPER(REPLACE(SUBSTRING(@AparagraphText1,0,@AsubstringNumVal),'<hardreturn>',''))
	)

	/* 
	Updating the artikkler_tekst table by setting the Tekst column 
	to the data that's assigned to the AparagraphText2 variable 
	*/ 
	update web.dbo.Artikkler_tekst
	set Tekst = @AparagraphText2
	where Avis=@ASite and Lopenr=@LStoryId

    -- instead of calling multiple SPs just calling one SP
    if @AddPublicatoinTaxonomy <> 0
    begin
      if @Adebug = 1 
        print 'adding publication taxonomy'
      if @publicationTaxonomy <> 0
      begin
        if not exists (select value
                       from web.dbo.Artikkler_nkeys (nolock)
                       where Avis=@ASite and Dato=@LStoryDate and Kategori=@LStoryCategory and Lopenr=@LStoryId and Value=@publicationTaxonomy)
        begin
          insert into web.dbo.Artikkler_nkeys (Avis, Dato, Kategori, Lopenr, Value, Class)
          values (@ASite, @LStoryDate, @LStoryCategory, @LStoryId, @publicationTaxonomy, 4)
          set @LUpdArtIndex = 1
        end
      end
    end

    -- Fix Story profile
    -- THIS IS REALLY BAD AND MUST BE REMOVED --
    /*
    delete from webextras.dbo.Artikkler_Profile_Priority 
    where Profile_ID not in (select Profile_ID
                             from web.dbo.profile (nolock)
                             where Avis=@ASite)
    */                             

    exec custom.dbo.AddFailoverProfile @ASite, @LStoryDate, @LStoryCategory, @LStoryId, @UpdateArtIndex
  
    exec custom.dbo.AddSEOLabelToStory @ASite=@Asite, @AGUID=@AGUID, 
                                       @afallbackprofile=@afallbackprofile, 
                                       @Adebug=@Adebug
                                       
    if @UpdateArtIndex=1 or @LUpdArtIndex=1
    begin
      exec web.dbo.GenTaxonomyIndex @avis=@ASite, @Dato=@LStoryDate, @Kategori=@LStoryCategory, @lopenr=@LStoryId,@quiet=1      
    end
    
    -- convert extra field to asset
    if @modifiedby = 'GNPortal-1'
    begin
      declare @ListOfAsset table (assettype varchar(112),
                                  assetvalue varchar(512),
                                  saxoAssettype int,
                                  objectGUID varchar(255))

/*
      insert into @ListOfAsset (assettype, assetvalue, saxoAssettype, objectGUID)
      select Varname, cast(varvalue as varchar(512)), b.Type, c.RowGUID
      from web.dbo.Artikkler_fields (nolock) a
        left join web.dbo.MediaFileTypes (nolock) b
          on (b.Avis=a.Avis and b.Extension=substring(a.Varname, 0, LEN(a.Varname)-1))
        left join web.dbo.Artikkler_hode (nolock) c
          on (c.Avis=a.Avis and c.Dato=a.Dato and c.Kategori=a.Kategori and c.Lopenr=a.Lopenr)
        left join web.dbo.Artikkler_status (nolock) e
          on (e.Avis = a.Avis and e.Dato=a.Dato and e.Kategori=a.Kategori and e.Lopenr=a.Lopenr)
      where a.Avis=@Asite and c.RowGUID=@AGUID
        and e.CreatedBy = 'GNPortal-1'
        and substring(a.Varname, 0, LEN(a.Varname)-1) in (select Extension
                        from web.dbo.MediaFileTypes (nolock) mfile 
                        where mfile.Avis=@Asite and mfile.[external] = 1)
*/
      insert into @ListOfAsset (assettype, assetvalue, saxoAssettype, objectGUID)
      select substring(a.Varname, 1, LEN(a.Varname)-1), cast(varvalue as varchar(512)), b.Type, c.RowGUID
      from web.dbo.Artikkler_fields (nolock) a
        left join web.dbo.MediaFileTypes (nolock) b
          on (b.Avis=a.Avis and b.Extension=substring(a.Varname, 1, LEN(a.Varname)-1))
        left join web.dbo.Artikkler_hode (nolock) c
          on (c.Avis=a.Avis and c.Dato=a.Dato and c.Kategori=a.Kategori and c.Lopenr=a.Lopenr)
        left join web.dbo.Artikkler_status (nolock) e
          on (e.Avis = a.Avis and e.Dato=a.Dato and e.Kategori=a.Kategori and e.Lopenr=a.Lopenr)
      where a.Avis=@Asite and c.RowGUID=@AGUID
        and e.CreatedBy = 'GNPortal-1'
        and substring(a.Varname, 1, LEN(a.Varname)-1) in (select Extension
                        from web.dbo.MediaFileTypes (nolock) mfile 
                        where mfile.Avis=@Asite and mfile.[external] = 1)                        

      delete from web.dbo.MediaFiles
      where Avis=@Asite and Title=@AGUID 

      insert into web.dbo.MediaFiles (Avis, Filename, Filesize, OrgFileName, ShowArchive, MediaType, Description, ExternalUrl, Title)
      select @Asite, assetvalue, 0, assetvalue, 1, saxoAssettype, '', assetvalue, objectGUID
      from @ListOfAsset
      where saxoAssettype is not null

      delete from web.dbo.Artikler_Attachments 
      where Avis=@ASite and Dato=@LStoryDate and Kategori=@LStoryCategory and Lopenr=@LStoryId

      insert into web.dbo.Artikler_Attachments (Avis, Dato, Kategori, Lopenr, ID, Start, Stopp, AutoStart, DirectDownload, DirectLink)
      select @ASite, @LStoryDate, @LStoryCategory, @LStoryId, ID, null, null, 0,0,0
      from web.dbo.MediaFiles (nolock)
      where Avis=@ASite and Title=@AGUID 
        and ID not in (select ID 
                       from web.dbo.Artikler_Attachments (nolock) 
                       where Avis=@ASite and Dato=@LStoryDate and Kategori=@LStoryCategory and Lopenr=@LStoryId)    
    end
                                       
  end
                                     
  set nocount off
end
