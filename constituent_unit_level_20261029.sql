USE [DARanalytics]
GO

/****** Object:  StoredProcedure [dbo].[uspBuildConstituentUnitLevelTable]    Script Date: 10/29/2026 10:28:13 AM ******/
SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO













CREATE PROCEDURE [dbo].[uspBuildConstituentUnitLevelTable] 
AS BEGIN
/* 
Analytics Data Mart -- Constituent-Unit Data Set
Created by Gary Thompson [GAT] on 01/31/23
*/

/* Need to swap out depending on server. Probably some way to do this dynamically.
BBCRM_PROD_RPT_BBDW
BBCRM_PROD_RPT_BBDW
*/

/************************************************* OVERVIEW **********************************************************
This table is a repository of most of the measures used byDAR Analytics in its
standard reporting and analyses to document constituent relationships with particular schools and units. 
Variables have been given descriptive names, but for more information about each variable and its calculation,
consult .....

Any variable with "hh" suffix means that the variable is aggregated at the household level
and both members of the household will have the same value.

NOTE: 
All changes to this table should be vetted through 
the Data Architect DAR Analytics
**************************************************************************************************************************/

/************************************************* CHANGE LOG **********************************************************
09/17/26 -GAT added flag_unit_pgi_not_principal_major_prospect, flag_unit_pgi_not_leadership_prospect and updated flag_unit_pgi_not_unit_prospect to only be with 'All levels'
08/20/26 -GAT updated how event attendance was calculated in unit_connectedness to better match NYU
08/18/26 -GAT updated the SOE department code to use the more generalized tables crosswalk_major|subdept_to_department created by two SPs that can handle more CSUs
08/10/26 -GAT tweaked giving to exclude some funds and tributes
08/07/26 -GAT tweaked unit_connectedness score for manage/referral from 7 to 3
07/17/26 -GAT tweaked unit connectedness scores to match VCU connectedness.  got rid of double counting of managed and referrals
07/14/26 -GAT tweaked the parent sub query to get rid of students without an educational college - which would not link up to any known unit and hence a NULL problem
03/19/26 - WWW refactored RNL survey interest attributes (rnl_survey subquery) and including new 2025 attributes
				-- https://docs.google.com/document/d/1Zxg4XAyjD8BK-j7BU2O2UI2ySkMLwGs4M-8mYP_eLtc/edit?tab=t.0
03/11/26 -GAT added bio_constituency_list and updated pm_unit_connectedness_score and _desc to be E. Weakly Connected when certain constituency lists happen
03/04/26 -GAT Added a freshness date on the RNL surveys of 3 years....after that they don't count towards unit connectedness.
12/03/25 -GAT added honor program graduates as alums of the honors college
11/12/25 -GAT added flag_unit_email_click_last365
11/03/25 -GAT added gvg_latest_unit_recognition_txt_hh
10/21/25 -GAT added flag_unit_parent_ever
10/17/25 -GAT swapped out the giving summary views for the datamart for HH unit giving; 
09/23/25 -GAT Added flag_unit_parent_current based on the currently attending student and their latest primary major
09/22/25 -GAT Updated The current employees to include a lot more people, especially MPAR and VCUHS
09/19/25 -GAT Modified facultystaff to put ICA in Arts and Life Sciences in H&S (not sure if there were any of the latter)
08/21/25 - WW modified to include 20 RNL Interest attirbutes to particular unit scores
08/19/25 -GAT Added two indexes recommended by SSMS
03/21/25 -GAT Added unit_avp_officer_manager
03/10/25 -GAT Added flag_has_pg_vehicle_hh, flag_has_revocable_pg_hh
02/11/25 -GAT Added events to the unit connectedness score
01/28/25 -GAT Changed unit_name_campaign to allow NULLs as it was changed in school_unit_info to be that way
12/19/24 -GAT Added household_system_id and household_lookup_id
12/12/24 -GAT Added flag_unit_AG_wAthletics to support the PG Spring Appeal
11/11/24 -GAT Added unit_name_campaign
10/25/24 -GAT Added bio_lastcommafirstname,	bio_birthday_next, bio_age, affil_preferred_class
08/26/24 -GAT Added primary_unit_tiebreaker_index and flag_unit_AG_MPAR
05/17/24 -GAT Added flag_exclude_call_list_VCU from CL to improve the calc for flag_unit_primary_hh_member
04/26/24 -GAT Added lago_officer_lookup_id and lago_officer_name
04/17/24 -GAT Added flag_unit_lago
04/16/24 -GAT Added flag_unit_philanthropic and flag_unit_annual_giving
04/16/24 -GAT Fixed facutly staff connection to not match on empty fields
02/14/24 -GAT Updated Unit Connectedness Scoring and ranges
02/08/24 -GAT Added in Managed by Team and others within the unit
12/06/23 -GAT Deceased people have NULL pm_unit_connections to all units
01/31/23 -[GAT] First iteration

**************************************************************************************************************************/

declare 
		@destTable nvarchar(30),
		@startTime datetime,
		@rowsLoaded int,
		@errorMessage nvarchar(1000)
	
	set @startTime = getDate();
	set @errorMessage = N'';

	set @destTable = 'datamart.constituent_unit_level';
--	exec [DARanalytics].[dbo].[sp_logTableLoad] @destTable, N'start', @startTime, N'NoFileSource';

 
/* STEP 1. DELETE TABLE, IF ALREADY EXISTS */
	IF OBJECT_ID('datamart.constituent_unit_level_temp', 'U') IS NOT NULL 
	DROP TABLE datamart.constituent_unit_level_temp;

/*Put a create table statement here to better control datatypes and sizes*/
CREATE TABLE [datamart].[constituent_unit_level_temp](
	[z_last_update] [datetime] NOT NULL,
	[constituent_dim_id] int NOT NULL,
	[constituent_system_id] uniqueidentifier NOT NULL,
	[constituent_lookup_id] [nvarchar](100) NOT NULL,
	household_system_id uniqueidentifier NOT NULL,
	household_id int NOT NULL,  --
	household_lookup_id nvarchar(100) NOT NULL,  --
	flag_is_primary_hh_member [tinyint] NOT NULL, 
	[bio_name] [nvarchar](154) NOT NULL,
	bio_lastcommafirstname nvarchar(155) NOT NULL,
	bio_birthday_next DATE NULL,
	bio_age int NULL,
	bio_constituency_list nvarchar(4000) NULL,
	affil_preferred_class int NULL,
	eval_capacity_rating int NULL,
	eval_capacity_rating_desc_short_sort nvarchar(20) NULL,
	[unit_name] [nvarchar](40) NOT NULL,
	unit_name_short [nvarchar](250) NOT NULL,
	unit_name_other [nvarchar](250) NOT NULL,
	unit_name_campaign [nvarchar](250) NULL,
	[unit_id] [nvarchar](3) NOT NULL,
	unit_system_id uniqueidentifier NOT NULL,
	campus_code_new nvarchar(100) NULL,
	unit_avp_officer_manager nvarchar(50) NULL,
	flag_unit_lago tinyint NOT NULL,
	lago_officer_lookup_id nvarchar(100) NULL,
    lago_officer_name nvarchar(100) NULL,
	flag_unit_philanthropic tinyint NOT NULL,
	flag_unit_annual_giving tinyint NOT NULL,
	flag_unit_AG_wAthletics tinyint NOT NULL,
	flag_unit_AG_wMPAR tinyint NOT NULL,
	unit_connectedness_list nvarchar(max) NULL,
	unit_connectedness_num int NULL,
	unit_connectedness_num_hh int NULL,
	pm_unit_connectedness_score_hh int NULL,
	pm_unit_connectedness_desc_hh nvarchar(25) NULL,
	flag_unit_primary_hh_member tinyint NULL,
	pm_campaign_segment nvarchar(20) NULL,

	[unit_alum_ug_year] [nvarchar](4) NULL,
	 unit_yrs_til_ug_reunion [nvarchar](4) NULL,
	[unit_alum_grad_year] [nvarchar](4) NULL,
	[unit_yrs_til_grad_reunion] [int] NULL,
	[flag_unit_alum] [tinyint] NOT NULL,
	[flag_unit_alum_ug] [tinyint] NOT NULL,
	[flag_unit_alum_grad] [tinyint] NOT NULL,
--	[flag_unit_alum_HS] [tinyint] NOT NULL,
--	[flag_unit_parent_former] [tinyint] NOT NULL,
	[flag_unit_donor] [tinyint] NOT NULL,
	[flag_unit_do_not_contact] [tinyint] NOT NULL,
	flag_unit_pgi_not_unit_prospect [tinyint] NOT NULL,
	flag_unit_pgi_not_principal_major_prospect [tinyint] NOT NULL,
	flag_unit_pgi_not_leadership_prospect [tinyint] NOT NULL,
	flag_unit_pgi_suspect_or_positive [tinyint] NOT NULL,
	[flag_unit_board_current] [tinyint] NOT NULL,  
--	[flag_unit_board_former] [tinyint] NOT NULL,
	[flag_unit_managed_current] [tinyint] NOT NULL, 
	flag_unit_managed_prospect_current [tinyint] NOT NULL,
	flag_unit_managed_team_current [tinyint] NOT NULL,
	flag_unit_managed_stewardship_current [tinyint] NOT NULL,
	flag_unit_managed_discovery_current [tinyint] NOT NULL,
	flag_unit_managed_engagement_current [tinyint] NOT NULL,
	flag_unit_managed_alumni_rel_current [tinyint] NOT NULL,
	flag_unit_facultystaff_current [tinyint] NOT NULL,
	flag_unit_surveyinterest_current [tinyint] NOT NULL,
	flag_unit_parent_current tinyint NOT NULL,
	flag_unit_parent_ever tinyint NOT NULL,
	flag_unit_email_click_last365 tinyint NOT NULL,

    pm_unit_connectedness_score int NULL,
	pm_unit_connectedness_desc nvarchar(25) NULL,
	pm_unit_connect_alum int NULL,
	pm_unit_connect_managed int NULL,
	pm_unit_connect_discovery int NULL,
	pm_unit_connect_contact_info int NULL, 
	pm_unit_connect_gvg_5k int NULL, 
	pm_unit_connect_gvg_500_under30yo int NULL,  
	--pm_unit_connect_gvg_gift_cnt int NULL,	
	pm_unit_connect_gvg_each5FYs int NULL,
	pm_unit_connect_has_job_info int NULL, 
	pm_unit_connect_do_not_contact  int NULL,
	pm_unit_connect_pgi_suspect_or_positive int NULL,  
	pm_unit_connect_pgi_not_unit_prospect int NULL,
	pm_unit_connect_gvg_recency int NULL,
	pm_unit_connect_num_boardsNcommittees int NULL,
	pm_unit_connect_facultystaff_current int NULL,
	pm_unit_connect_ed_involvement int NULL,
	pm_unit_connect_rnl_interest int NULL,
	pm_primary_unit_tiebreaker_index smallint NOT NULL,

	/* OLD Giving based on Giving Summary*/
	gvg_unit_life_cash			money NOT NULL,
	gvg_unit_life_cash_recog	money NOT NULL,
	gvg_unit_life_ngp			money NOT NULL,
	gvg_unit_life_ngp_recog		money NOT NULL,
	gvg_unit_life_gift_count	int NOT NULL,

    gvg_unit_life_cash_pct			float NOT NULL,
	gvg_unit_life_cash_recog_pct	float NOT NULL,
	gvg_unit_life_ngp_pct			float NOT NULL,
    gvg_unit_life_ngp_recog_pct		float NOT NULL,

	gvg_unit_latest_date_cash_recog date NULL,
	gvg_unit_latest_date_ngp_recog date NULL,

	[gvg_unit_tminus0_cash_recog] [decimal](38, 2) NOT NULL,
	[gvg_unit_tminus1_cash_recog] [decimal](38, 2) NOT NULL,
	[gvg_unit_tminus2_cash_recog] [decimal](38, 2) NOT NULL,
	[gvg_unit_tminus3_cash_recog] [decimal](38, 2) NOT NULL,
	[gvg_unit_tminus4_cash_recog] [decimal](38, 2) NOT NULL,
	[gvg_unit_tminus5_cash_recog] [decimal](38, 2) NOT NULL,

	/*NEW HH Giving based on Revenue History Summary*/
	gvg_unit_recog_received_life_hh			money NOT NULL,
	gvg_unit_recog_raised_life_hh			money NOT NULL,
	gvg_unit_life_number_transactions_hh	int NOT NULL,

	gvg_unit_recog_received_life_hh_pct		float NOT NULL,
    gvg_unit_recog_raised_life_hh_pct		float NOT NULL,

	gvg_recog_unit_latest_date date NULL,
	--gvg_recog_unit_latest_rasied_date date NULL,

	gvg_unit_recog_received_tminus0_5_hh [decimal](38, 2) NOT NULL,
	gvg_unit_recog_received_tminus0_hh [decimal](38, 2) NOT NULL,
	gvg_unit_recog_received_tminus1_hh [decimal](38, 2) NOT NULL,
	gvg_unit_recog_received_tminus2_hh [decimal](38, 2) NOT NULL,
	gvg_unit_recog_received_tminus3_hh [decimal](38, 2) NOT NULL,
	gvg_unit_recog_received_tminus4_hh [decimal](38, 2) NOT NULL,
	gvg_unit_recog_received_tminus5_hh [decimal](38, 2) NOT NULL,

	gvg_unit_recog_raised_tminus0_5_hh [decimal](38, 2) NOT NULL,   
	gvg_unit_recog_raised_tminus0_hh [decimal](38, 2) NOT NULL,
	gvg_unit_recog_raised_tminus1_hh [decimal](38, 2) NOT NULL,
	gvg_unit_recog_raised_tminus2_hh [decimal](38, 2) NOT NULL,
	gvg_unit_recog_raised_tminus3_hh [decimal](38, 2) NOT NULL,
	gvg_unit_recog_raised_tminus4_hh [decimal](38, 2) NOT NULL,
	gvg_unit_recog_raised_tminus5_hh [decimal](38, 2) NOT NULL,

	gvg_unit_10yrs_num_yrs_recog_hh		tinyint NOT NULL,
	gvg_unit_donor_category_live_hh		nvarchar(30)  NULL,
	flag_has_future_pledge_payment_hh	tinyint NOT NULL,
	flag_has_pg_vehicle_hh				tinyint NOT NULL,
    flag_has_revocable_pg_hh			tinyint NOT NULL,
	--gvg_latest_unit_recognition_txt		nvarchar(400) NULL,
	gvg_latest_unit_recognition_txt_hh	nvarchar(400) NULL,
	--[gvg_unit_top_fund_supported] [nvarchar](4000) NULL,
	--[gvg_unit_top_three_funds_giving] [nvarchar](4000) NULL,
	--gvg_unit_percent_in_honor_memoriam decimal(38,2) NULL,

	eng_unit_num_committees_current tinyint NOT NULL,
	eng_unit_latest_committee_current_date date NULL,

    flag_living tinyint NOT NULL,
	flag_individual tinyint NOT NULL,
	flag_alum tinyint NOT NULL,
	flag_exclude_call_list_VCU tinyint NOT NULL,
	flag_unit_has_fundraiser tinyint NOT NULL,
	flag_unit_has_alums tinyint NOT NULL,
	flag_unit_solicitable_email tinyint NOT NULL,
	flag_unit_solicitable_mail tinyint NOT NULL,
	flag_unit_solicitable_phone tinyint NOT NULL

) ON [PRIMARY]

/* STEP 2. LOAD DATA INTO TABLE */
 insert INTO DARanalytics.datamart.constituent_unit_level_temp

	SELECT

	/* date loaded */
	GETDATE() AS z_last_update

	/* ID variables */
	,base.constituent_dim_id
	,cl.constituent_system_id
	,cl.constituent_lookup_id
	,cl.household_system_id
	,cl.household_id
	,cl.household_lookup_id
	,cl.flag_is_primary_hh_member as flag_is_primary_hh_member
	,cl.bio_name
	,cl.bio_lastcommafirstname
	,cl.bio_birthday_next
	,cl.bio_age
	,cl.bio_constituency_list
	,cl.affil_preferred_class
	,cl.eval_capacity_rating
	,cl.eval_capacity_rating_desc_short_sort

	,base.unit_name
	,sui.unit_name_short
	,sui.unit_name_other
	,sui.campaign_display_name as unit_name_campaign
	,base.unit_id
	,sui.site_id  as unit_system_id
	,sui.campus_code_new
	,sui.avp_officer_manager				as unit_avp_officer_manager
	,isnull(sui.flag_unit_lago,0)			as flag_unit_lago
	,sui.lago_officer_lookup_id
    ,sui.lago_officer_name

	,isnull(sui.flag_unit_philanthropic,0)	as flag_unit_philanthropic
	,isnull(sui.flag_unit_annual_giving,0)	as flag_unit_annual_giving
	,isnull(sui.flag_unit_AG_wAthletics,0)	as flag_unit_AG_wAthletics
	,isnull(sui.flag_unit_AG_wMPAR,0)		as flag_unit_AG_wMPAR
	,NULL as unit_connectedness_list
	,NULL as unit_connectedness_num
	,NULL as unit_connectedness_num_hh
	,NULL as pm_unit_connectedness_score_hh
	,NULL as pm_unit_connectedness_desc_hh
	,NULL as flag_unit_primary_hh_member
	,NULL as pm_campaign_segment

	/*
	,su.usecode AS unit_usecode
	,REPLACE(REPLACE(REPLACE(REPLACE(su.ads_directory_dept,CHAR(9),''),CHAR(10),''),CHAR(13),''),CHAR(34),'')   AS unit_ads_directory_code
	,su.devunit_prefix AS unit_devunit_prefix
	,case when base.flag_unit_alum_ug = 1 then su.ugrad_school_code else null end  AS unit_ugrad_school_code
	,case when base.flag_unit_alum_grad = 1 then su.grad_school_code else null end AS unit_grad_school_code
	,su.highest_board AS unit_highest_board
	,su.userid_prefix AS unit_userid_prefix
 */
	,base.unit_alum_ug_year AS unit_alum_ug_year
	,case when cl.flag_living = 1 
	      then (5 - (year(dateadd(month,6,getdate())) - base.unit_alum_ug_year) % 5) % 5  
		  else null end as unit_yrs_til_ug_reunion
	,base.unit_alum_grad_year AS unit_alum_grad_year
	,case when cl.flag_living = 1 
	      then (5 - (year(dateadd(month,6,getdate())) - base.unit_alum_grad_year) % 5) % 5  
		  else null end as unit_yrs_til_grad_reunion
		 
	,base.flag_unit_alum
	,base.flag_unit_alum_ug
	,base.flag_unit_alum_grad
--	,base.flag_unit_alum_HS
	,base.flag_unit_donor
	,isnull(cl.flag_do_not_contact,0)         AS flag_unit_do_not_contact     --just using the overall VCU flag until I get around to unit
	,base.flag_unit_pgi_not_unit_prospect     --unit not a prospect
	,base.flag_unit_pgi_not_principal_major_prospect
	,base.flag_unit_pgi_not_leadership_prospect
	,base.flag_unit_pgi_suspect_or_positive
	,base.flag_unit_board_current
 --	,base.flag_unit_managed_current  --replaced by below

	,isnull(case when (base.flag_unit_managed_current = 1			--prospect manager
					or pt.flag_unit_managed_team_current = 1
					or pt.flag_unit_managed_stewardship_current = 1
					or pt.flag_unit_managed_discovery_current = 1
					or pt.flag_unit_managed_engagement_current = 1
					) then 1 else 0 end,0) as flag_unit_managed_current
	,isnull(base.flag_unit_managed_current,0)				as flag_unit_managed_prospect_current
	,isnull(pt.flag_unit_managed_team_current,0)			as flag_unit_managed_team_current
	,isnull(pt.flag_unit_managed_stewardship_current,0)		as flag_unit_managed_stewardship_current
	,isnull(pt.flag_unit_managed_discovery_current,0)		as flag_unit_managed_discovery_current
	,isnull(pt.flag_unit_managed_engagement_current,0)		as flag_unit_managed_engagement_current
	,isnull(pt.flag_unit_managed_alumni_relations_current,0) as flag_unit_managed_alumni_rel_current
	,isnull(flag_unit_facultystaff_current,0)				as flag_unit_facultystaff_current
	,isnull(flag_unit_surveyinterest_current,0)		as flag_unit_surveyinterest_current
	,isnull(base.flag_unit_parent_current,0)				as flag_unit_parent_current
	,isnull(base.flag_unit_parent_ever,0)					as flag_unit_parent_ever
	,isnull(base.flag_unit_email_click_last365,0)			as flag_unit_email_click_last365


	/*connectedness*/
	, case when base.flag_unit_alum = 1 then 7 else 0 end     --alums
	
	+ case when base.flag_unit_parent_current = 1 then 5 else 0 end				--parent of current student in unit
	+ case when isnull(case when ( base.flag_unit_managed_current = 1			--prospect manager  7
								or pt.flag_unit_managed_team_current = 1		--7
								or pt.flag_unit_managed_stewardship_current = 1 --7
								or pgi_good.bio_name is not null				-- brought in so not double counted with management
					  ) then 1 else 0 end,0) = 1 then 3 else 0 end				--currently managed moved from 7 to 3 on 8/7/26
	+ case when isnull(pt.flag_unit_managed_discovery_current,0) = 1 then 0 else 0 end      --currently unit discovery managed  --changed to 0 on 7/17/26 wtih CM and RBM

	--giving last 5 FYs - should this be without certain funds?
	+ case when gvg_unit_hh.gvg_unit_recog_raised_tminus0_5_wo_certain_funds_hh >= 5000
	         or gvg_unit_hh.gvg_unit_recog_received_tminus0_5_wo_certain_funds_hh >= 5000 then 10 
		   else 0 end	

	+ case when (gvg_unit_hh.gvg_unit_recog_raised_tminus0_5_wo_certain_funds_hh  >= 500 
	          or gvg_unit_hh.gvg_unit_recog_received_tminus0_5_wo_certain_funds_hh  >= 500 )
			and isnull(cl.bio_age,200) between 18 and 30 then 10 
		   else 0 end

	+ case when gvg_unit_hh.gvg_unit_recog_received_life_wo_certain_funds_hh >= 100000 then 6		--giving all time over 100k then 6 points....this is proposed by Gary 8/19/26 to align with NYU
		   else 0 end

	+ case when gvg_unit_hh.gvg_recog_raised_tminus0_hh > 0 or gvg_unit_hh.gvg_recog_received_tminus0_hh > 0 or gvg_unit_hh.flag_has_future_pledge_payment_hh = 1 then 3 else 0 end --a point for each year giving in past 5+
	+ case when	gvg_unit_hh.gvg_recog_raised_tminus1_hh > 0 or gvg_unit_hh.gvg_recog_received_tminus1_hh > 0 then 3 else 0 end
	+ case when	gvg_unit_hh.gvg_recog_raised_tminus2_hh > 0 or gvg_unit_hh.gvg_recog_received_tminus2_hh > 0 then 2 else 0 end
	+ case when	gvg_unit_hh.gvg_recog_raised_tminus3_hh > 0 or gvg_unit_hh.gvg_recog_received_tminus3_hh > 0 then 2 else 0 end
	+ case when	gvg_unit_hh.gvg_recog_raised_tminus4_hh > 0 or gvg_unit_hh.gvg_recog_received_tminus4_hh > 0 then 1 else 0 end
	+ case when	gvg_unit_hh.gvg_recog_raised_tminus5_hh > 0 or gvg_unit_hh.gvg_recog_received_tminus5_hh > 0 then 1 else 0 end

	+ ceiling((isnull(gvg_unit_hh.gvg_10yrs_num_yrs_recog_hh,0))/2)		--more points for consistent giving over the last 10 FYs plus current

	+ case when gvg_unit_hh.gvg_donor_category_live_hh = 'Sybunt 6yr_plus' then 1 else 0 end  --1 point for ever donated a long time ago
				
	+ case when cl.bio_job_title is not null
	        and cl.bio_employer_name is not null then 0				--changed to 0 on 2/7/24
		   else 0 end

	+ case when pgi.bio_name is not null then 1 else 0 end			--has a PGI of -unit not a prospect

--	+ case when pgi_good.bio_name is not null then 7 else 0 end		--has a PGI of -suspect- or -positive-		moved into the management section above so as to not double count.

	 + case when isnull(committees.flag_unit_committee_member_current,0)	 >= 1 then 5 else 0 end 

	+ case when fs.CONSTITUENTDIMID is not null then 5 else 0 end --INVESTIGATE CURRENT FAC/STAFF OF UNIT

	+ case when ei.constituent_dim_id is not null then 10 else 0 end		--educational involvement -- Athletics, Library Student Worker, Rams in Recovery 10 pts for Student Affairs unit

	+ case when evnts_past3yrs.num_unit_events_past3yrs_attended >=5 then 5
		   when evnts_past3yrs.num_unit_events_past3yrs_attended >=3 then 3
		   when evnts_past3yrs.num_unit_events_past3yrs_attended>=1 then 1
		   when evnts_past3yrs.num_unit_events_life_attended>=1 then 0			--Removed on2/11/25 Ben/Rachel decision
		   else 0 end
	+ case when evnts_past3yrs.num_unit_events_tminus0_attended >=2 then 3 else 0 end			--Proposed 3 points for very recent indiv event attendance to match NYU bin better

	+ case when rnl_interests.CONSTITUENTSYSTEMID is not null then 3 else 0 end -- as pm_unit_connect_rnl_interest  --current freshness date is 3 years.

	+ case when flag_unit_email_click_last365 = 1 then 2 else 0 end			--at least one email click within last 365 days
																														
     as pm_unit_connectedness_score

	, NULL as pm_unit_connectedness_desc

	/*START parts of the unit connectedness score */
	, case when base.flag_unit_alum = 1 then 7 else 0 end		as pm_unit_connect_alum --alums
--	, case when base.flag_unit_managed_current = 1 then 10 else 0 end		as pm_unit_connect_managed --currently managed
	, case when isnull(case when ( base.flag_unit_managed_current = 1			--prospect manager  7
								or pt.flag_unit_managed_team_current = 1		--7
								or pt.flag_unit_managed_stewardship_current = 1 --7
								or pgi_good.bio_name is not null
					  ) then 1 else 0 end,0) = 1 then 3 else 0 end			as pm_unit_connect_managed	--currently managed
	, case when isnull(pt.flag_unit_managed_discovery_current,0) = 1 then 0 else 0 end  as pm_unit_connect_discovery    --currently unit discovery managed  --zeroed out on 7/17/26 with CM and RBM
	
	, 
	 --  case when isnull(cl.cntc_primary_email,'') <> '' then 1 else 0 end            --contact_info
	 --+ case when isnull(cl.cntc_primary_phone,'') <> '' then 1 else 0 end 
	 --+ case when isnull(replace(replace(replace(replace(cl.geo_addr_pref_street,char(9),''),char(10),''),char(13),''),char(34),''),'') <> '' then 1 else 0 end 
	0 as pm_unit_connect_contact_info --contact_info
	
	, case when gvg_unit_hh.gvg_recog_raised_tminus0_5_hh >= 5000
			 or gvg_unit_hh.gvg_recog_received_tminus0_5_hh >= 5000 then 10 
		   else 0 end									as pm_unit_connect_gvg_5k  --giving last 5 FYs
	, case when (gvg_unit_hh.gvg_recog_raised_tminus0_5_hh  >= 500 
	          or gvg_unit_hh.gvg_recog_received_tminus0_5_hh  >= 500 )
			and isnull(cl.bio_age,200) between 18 and 30 then 10 
		   else 0 end											as pm_unit_connect_gvg_500_under30yo  --giving last 5 FYs for young alums 
	--, case when g.gvg_unit_life_gift_count > 20 then 5			
	--	   when g.gvg_unit_life_gift_count > 10 then 3
	--	   when g.gvg_unit_life_gift_count >  5 then 2
	--	   when g.gvg_unit_life_gift_count >  0 then 1
	--	   else 0 end											as pm_unit_connect_gvg_gift_cnt  --giving count lifetime to unit
	, case when gvg_unit_hh.gvg_recog_raised_tminus0_hh > 0 or gvg_unit_hh.gvg_recog_received_tminus0_hh > 0 or gvg_unit_hh.flag_has_future_pledge_payment_hh = 1 then 3 else 0 end --a point for each year giving in past 5+
	+ case when	gvg_unit_hh.gvg_recog_raised_tminus1_hh > 0 or gvg_unit_hh.gvg_recog_received_tminus1_hh > 0 then 3 else 0 end
	+ case when	gvg_unit_hh.gvg_recog_raised_tminus2_hh > 0 or gvg_unit_hh.gvg_recog_received_tminus2_hh > 0 then 2 else 0 end
	+ case when	gvg_unit_hh.gvg_recog_raised_tminus3_hh > 0 or gvg_unit_hh.gvg_recog_received_tminus3_hh > 0 then 2 else 0 end
	+ case when	gvg_unit_hh.gvg_recog_raised_tminus4_hh > 0 or gvg_unit_hh.gvg_recog_received_tminus4_hh > 0 then 1 else 0 end
	+ case when	gvg_unit_hh.gvg_recog_raised_tminus5_hh > 0 or gvg_unit_hh.gvg_recog_received_tminus5_hh > 0 then 1 else 0 end	
	as pm_unit_connect_gvg_each5FYs --a point for each year giving in past 5+
				
	, case when cl.bio_job_title is not null
	        and cl.bio_employer_name is not null then 0
		   else 0 end													as pm_unit_connect_has_job_info 

    , case when cl.flag_do_not_contact = 1 then 0 else 0 end			as pm_unit_connect_do_not_contact  --big neg for DO NOT CONTACT
    , case when pgi.bio_name is not null then 1 else 0 end			    as pm_unit_connect_pgi_not_unit_prospect  --big neg for NOT A UNIT PROSPECT
    , case when pgi_good.bio_name is not null then 0 else 0 end			as pm_unit_connect_pgi_suspect_or_positive  --big positive for connectivity - moved to management section to avoid double counting
	--, case when datediff(month,g.gvg_unit_latest_ngp_recog,getdate()) <= 3 then 6
	--       when datediff(month,g.gvg_unit_latest_ngp_recog,getdate()) <= 6 then 5
	--	   when datediff(month,g.gvg_unit_latest_ngp_recog,getdate()) <= 12 then 4
	--	   when datediff(month,g.gvg_unit_latest_ngp_recog,getdate()) <= 18 then 3
	--	   when datediff(month,g.gvg_unit_latest_ngp_recog,getdate()) <= 24 then 2
	--	   when datediff(month,g.gvg_unit_latest_ngp_recog,getdate()) <= 36 then 1
	--	   else 0 end
	, ceiling((isnull(gvg_unit_hh.gvg_10yrs_num_yrs_recog_hh,0))/2) as pm_unit_connect_gvg_recency
	, case when isnull(committees.flag_unit_committee_member_current,0)	 >= 1 then 5 else 0 end					as pm_unit_connect_num_boardsNcommittees
	, case when fs.CONSTITUENTDIMID is not null then 5 else 0 end		as pm_unit_connect_facultystaff_current
	, case when ei.constituent_dim_id is not null then 10 else 0 end	as pm_unit_connect_ed_involvement
	, case when rnl_interests.CONSTITUENTSYSTEMID is not null then 3 else 0 end as pm_unit_connect_rnl_interest

	/*END parts of the unit connectedness score */

	, isnull(sui.primary_unit_tiebreaker_index,1000) as primary_unit_tiebreaker_index

	/* OLD giving based on GIVING SUMMARY */
	,ISNULL(g.gvg_unit_life_cash,0)			as gvg_unit_life_cash  			/* pp, gi, mc */
	,ISNULL(g.gvg_unit_life_cash_recog,0)	as gvg_unit_life_cash_recog		/* pp, gi, mc */
	,ISNULL(g.gvg_unit_life_ngp,0)			as gvg_unit_life_ngp			/* pl, gi, mc */
    ,ISNULL(g.gvg_unit_life_ngp_recog,0)	as gvg_unit_life_ngp_recog		/* pl, gi, mc */
	,ISNULL(g.gvg_unit_life_gift_count,0)	as gvg_unit_life_gift_count

	/* Giving unit percentage of total VCU giving*/
	,case when ISNULL(cl.gvg_life_cash,0) = 0		then 0 else ISNULL(g.gvg_unit_life_cash,0)		/ cl.gvg_life_cash		 end as gvg_unit_life_cash_pct  			
	,case when ISNULL(cl.gvg_life_cash_recog,0) = 0 then 0 else ISNULL(g.gvg_unit_life_cash_recog,0)/ cl.gvg_life_cash_recog end as gvg_unit_life_cash_recog_pct
	,case when ISNULL(cl.gvg_life_ngp,0) = 0		then 0 else ISNULL(g.gvg_unit_life_ngp,0)		/ cl.gvg_life_ngp		 end as gvg_unit_life_ngp_pct
    ,case when ISNULL(cl.gvg_life_ngp_recog,0) = 0	then 0 else ISNULL(g.gvg_unit_life_ngp_recog,0)	/ cl.gvg_life_ngp_recog  end as gvg_unit_life_ngp_recog_pct

    ,g.gvg_unit_latest_cash_recog	  --cash recog
    ,g.gvg_unit_latest_ngp_recog	--ngp recog

	/* total cash in past few years */
	,ISNULL(g.gvg_unit_tminus0_cash_recog,0) as gvg_unit_tminus0_cash_recog
	,isnull(g.gvg_unit_tminus1_cash_recog,0) as gvg_unit_tminus1_cash_recog
	,isnull(g.gvg_unit_tminus2_cash_recog,0) as gvg_unit_tminus2_cash_recog
	,isnull(g.gvg_unit_tminus3_cash_recog,0) as gvg_unit_tminus3_cash_recog
	,isnull(g.gvg_unit_tminus4_cash_recog,0) as gvg_unit_tminus4_cash_recog
	,isnull(g.gvg_unit_tminus5_cash_recog,0) as gvg_unit_tminus5_cash_recog


	/* NEW UNIT GIVING BASED ON REVENUE HISTORY AND SUMMARY VIEW gvg_revenue_history_summary_hh_unit*/
	 			
	,ISNULL(gvg_unit_hh.gvg_recog_received_life_hh,0)		as gvg_unit_recog_received_life_hh			
    ,ISNULL(gvg_unit_hh.gvg_recog_raised_life_hh,0)		as gvg_unit_recog_raised_life_hh	
	,ISNULL(gvg_unit_hh.gvg_life_number_transactions_hh,0)	as gvg_unit_life_number_transactions_hh

	/* Giving unit percentage of total VCU giving*/ 			
	,case when ISNULL(gvg_vcu.gvg_recog_received_life_hh,0) = 0 then 0 else ISNULL(gvg_unit_hh.gvg_recog_received_life_hh,0)/ gvg_vcu.gvg_recog_received_life_hh end as gvg_unit_recog_received_life_hh_pct
    ,case when ISNULL(gvg_vcu.gvg_recog_raised_life_hh,0) = 0	then 0 else ISNULL(gvg_unit_hh.gvg_recog_raised_life_hh,0)	/ gvg_vcu.gvg_recog_raised_life_hh  end as gvg_unit_recog_raised_life_hh_pct

    ,gvg_unit_hh.gvg_recog_latest_date_hh	as gvg_recog_unit_latest_date	 
  --  ,gvg_unit_hh.gvg_recog_latest_rasied_date		as gvg_recog_unit_latest_rasied_date	      

	/* total RECEIVED in past few years */
	,ISNULL(gvg_unit_hh.gvg_recog_received_tminus0_5_hh,0) as gvg_unit_recog_received_tminus0_5_hh
	,ISNULL(gvg_unit_hh.gvg_recog_received_tminus0_hh,0) as gvg_unit_recog_received_tminus0_hh
	,isnull(gvg_unit_hh.gvg_recog_received_tminus1_hh,0) as gvg_unit_recog_received_tminus1_hh
	,isnull(gvg_unit_hh.gvg_recog_received_tminus2_hh,0) as gvg_unit_recog_received_tminus2_hh
	,isnull(gvg_unit_hh.gvg_recog_received_tminus3_hh,0) as gvg_unit_recog_received_tminus3_hh
	,isnull(gvg_unit_hh.gvg_recog_received_tminus4_hh,0) as gvg_unit_recog_received_tminus4_hh
	,isnull(gvg_unit_hh.gvg_recog_received_tminus5_hh,0) as gvg_unit_recog_received_tminus5_hh

	/* total RAISED in past few years */
	,ISNULL(gvg_unit_hh.gvg_recog_raised_tminus0_5_hh,0) as gvg_unit_recog_raised_tminus0_5_hh
	,ISNULL(gvg_unit_hh.gvg_recog_raised_tminus0_hh,0) as gvg_unit_recog_raised_tminus0_hh
	,isnull(gvg_unit_hh.gvg_recog_raised_tminus1_hh,0) as gvg_unit_recog_raised_tminus1_hh
	,isnull(gvg_unit_hh.gvg_recog_raised_tminus2_hh,0) as gvg_unit_recog_raised_tminus2_hh
	,isnull(gvg_unit_hh.gvg_recog_raised_tminus3_hh,0) as gvg_unit_recog_raised_tminus3_hh
	,isnull(gvg_unit_hh.gvg_recog_raised_tminus4_hh,0) as gvg_unit_recog_raised_tminus4_hh
	,isnull(gvg_unit_hh.gvg_recog_raised_tminus5_hh,0) as gvg_unit_recog_raised_tminus5_hh

	, isnull(gvg_unit_hh.gvg_10yrs_num_yrs_recog_hh,0) as gvg_unit_10yrs_num_yrs_recog_hh
	, case when cl.flag_living = 1 then isnull(gvg_unit_hh.gvg_donor_category_live_hh,'Never Donor') else 'Deceased' end as gvg_unit_donor_category_live_hh  --changed to all constituents and not just individuals
	, isnull(gvg_unit_hh.flag_has_future_pledge_payment_hh,0) as flag_has_future_pledge_payment_hh
	, isnull(gvg_unit_hh.flag_has_pg_vehicle_hh,0) as flag_has_pg_vehicle_hh
    , isnull(gvg_unit_hh.flag_has_revocable_pg_hh,0) as flag_has_revocable_pg_hh

	--, concat(isnull(convert(varchar(20),gvg_unit_hh.gvg_recog_latest_date,101),'')
	--	,case when gvg_unit_hh.gvg_recog_latest_date is null then '' else '- $' end
	--	,isnull(convert(varchar(20),gvg_unit_hh.gvg_latest_unit_recognition_amount,1),'')
	--	,case when gvg_unit_hh.gvg_unit_latest_recognition_amount is null then '' else ' (' end
	--	,isnull(gvg_unit_hh.gvg_unit_latest_designation_name,'')
	--	,case when gvg_unit_hh.gvg_unit_latest_designation_name is null then '' else ')' end
	--	) as gvg_latest_unit_recognition_txt
	,concat(isnull(convert(varchar(20),gvg_unit_hh.gvg_recog_latest_date_hh,101),'')
		,case when gvg_unit_hh.gvg_recog_latest_date_hh is null then '' else ': $' end
		,isnull(convert(varchar(20),gvg_unit_hh.gvg_unit_latest_recognition_amount_hh,1),'')
		,case when gvg_unit_hh.gvg_unit_latest_recognition_amount_hh is null then '' else ': (' end
		,isnull(gvg_unit_hh.gvg_unit_latest_designation_name_hh,'')
		,case when gvg_unit_hh.gvg_unit_latest_designation_name_hh is null then '' else ')' end
		) as gvg_latest_unit_recognition_txt_hh


 /*Engagement: Boards Committees, Events, Clubs etc...*/

    ,isnull(committees.num_active_unit_boardsNcommittees,0)	as eng_unit_num_committees_current
	,committees.latest_unit_committee_start_date			as eng_unit_latest_committee_current_date

	 , cl.flag_living
	 , cl.flag_individual
	 , cl.flag_alum
	 , cl.flag_exclude_call_list_VCU

	 , isnull(sui.flag_unit_has_fundraiser,0)	as flag_unit_has_fundraiser
	 , isnull(sui.flag_unit_has_alums,0)		as flag_unit_has_alums

	 /* Solicitable by Unit (and by extension VCU as well) */

	 /*tie in logic from all of VCU solicit view since if you aren't solicitable at the VCU level you aren't at the unit level*/
	-- , cl.pm_solicit_code_list
	 , case when isnull(cs_vcu.solicit_email,1) = 1 and isnull(cs.solicitable_email,1) = 1 then 1 else 0 end		as flag_unit_solicitable_email
	 , case when isnull(cs_vcu.solicit_mail,1) = 1  and isnull(cs.solicitable_mail,1)  = 1 then 1 else 0 end		as flag_unit_solicitable_mail
	 , case when isnull(cs_vcu.solicit_phone,1) = 1 and isnull(cs.solicitable_phone,1) = 1 then 1 else 0 end		as flag_unit_solicitable_phone


	FROM
	/* START BASE of ALL defined connections between a prospect and a specific unit 
	--Need to add in the educational involvement fields of interest
	   N=637K;  Time= 16 secs  Oct 2025*/
	(SELECT
		 base1.constituent_dim_id
        ,base1.unit_id
		,max(base1.unit_name) as unit_name

		,MAX(CASE WHEN rel_type = 'alumni' THEN 1 ELSE 0 END) AS flag_unit_alum
		,MAX(CASE WHEN rel_type = 'alumni' AND is_leader = 1 THEN 1 ELSE 0 END) AS flag_unit_alum_ug
		,MAX(CASE WHEN rel_type = 'alumni' AND is_leader = 2 THEN 1 ELSE 0 END) AS flag_unit_alum_grad
		,MAX(CASE WHEN rel_type = 'alumni' AND is_leader = 1 THEN UNIT_CLASS_YEAR ELSE NULL END) AS unit_alum_ug_year
		,MAX(CASE WHEN rel_type = 'alumni' AND is_leader = 2 THEN UNIT_CLASS_YEAR ELSE NULL END) AS unit_alum_grad_year
		,MAX(CASE WHEN rel_type = 'donor' THEN 1 ELSE 0 END) AS flag_unit_donor
		,MAX(CASE WHEN rel_type = 'board' and current_board = 1 THEN 1 ELSE 0 END) AS flag_unit_board_current
		,MAX(CASE WHEN rel_type = 'pgi good' THEN 1 ELSE 0 END) AS flag_unit_pgi_suspect_or_positive
		,MAX(CASE WHEN rel_type = 'pgi NAP All Levels' THEN 1 ELSE 0 END) AS flag_unit_pgi_not_unit_prospect
		,MAX(CASE WHEN rel_type = 'PGI NAP Principal/Major Gift' THEN 1 ELSE 0 END) AS flag_unit_pgi_not_principal_major_prospect
		,MAX(CASE WHEN rel_type = 'PGI NAP Leadership Annual Gift' THEN 1 ELSE 0 END) AS flag_unit_pgi_not_leadership_prospect

		,MAX(CASE WHEN rel_type = 'managed' THEN 1 ELSE 0 END) AS flag_unit_managed_current
		,MAX(CASE WHEN rel_type = 'team managed' THEN 1 ELSE 0 END) AS flag_unit_team_managed_current
		,MAX(CASE WHEN rel_type = 'education involvement' THEN 1 ELSE 0 END) AS flag_unit_in_education_involvement
		,MAX(CASE WHEN rel_type = 'facultystaff' THEN 1 ELSE 0 END) AS flag_unit_facultystaff_current
		,MAX(CASE WHEN rel_type = 'surveyinterest' THEN 1 ELSE 0 END) AS flag_unit_surveyinterest_current
		,MAX(CASE WHEN rel_type = 'parent' THEN 1 ELSE 0 END) AS flag_unit_parent_current
		,MAX(CASE WHEN rel_type = 'parentever' THEN 1 ELSE 0 END) AS flag_unit_parent_ever
		,MAX(CASE WHEN rel_type = 'email_click' THEN 1 ELSE 0 END) AS flag_unit_email_click_last365

	/*	,MAX(CASE WHEN rel_type = 'parent' AND pa_earliest_class_yr < YEAR(GETDATE()) THEN 1 ELSE 0 END) AS flag_unit_parent_former
		,MAX(CASE WHEN rel_type = 'ever managed' THEN 1 ELSE 0 END) AS flag_unit_managed_ever
		,MAX(CASE WHEN rel_type = 'board' AND former_board = 1 THEN 1 ELSE 0 END) AS flag_unit_board_former
		,MAX(CASE WHEN rel_type = 'contact' THEN 1 ELSE 0 END) AS flag_unit_contacted
		,MAX(CASE WHEN rel_type = 'solicit' THEN 1 ELSE 0 END) AS flag_unit_solicited
		,MAX(CASE WHEN rel_type = 'referral' THEN 1 ELSE 0 END) AS flag_unit_referral
  */

	FROM (  /*list of connection possibilities between entity and unit */

			/* UG ALUMNI - includes those without degrees and certs? count N=164k Time = 1sec */
				SELECT a.CONSTITUENTDIMID as constituent_dim_id
				     , coalesce(sui.unit_id,'500')			as unit_id 
                     , coalesce(sui.unit_name,'Other')		as unit_name 
				     , 'Alumni' AS REL_TYPE
				     , MAX(1)   AS IS_LEADER
				     , NULL AS PA_EARLIEST_CLASS_YR
				     , NULL AS PA_MOST_RECENT_CLASS_YR
				     , NULL AS CURRENT_BOARD
				     , NULL AS FORMER_BOARD
				     , MAX(A.DEGREEYEAR) AS unit_class_year

                  FROM --BBCRM_PROD_RPT_BBDW.BBDW.VCU_RPT_ALUMNIBYDECADE a
				       BBCRM_PROD_RPT_BBDW.BBDW.VCU_RPT_ALUMNIBYDECADE a
                    join DARanalytics.ref.school_unit_info sui on sui.site_id = a.siteid  --only interested in units that are in SUI
                 WHERE a.undergraduate = 1
  			  GROUP BY
				     A.constituentdimID
				   , sui.unit_id  
				   , sui.unit_name --can probably get rid of this
		    --  order by unit_id
	
	UNION ALL

			/* GRAD ALUMNI - N=90k Time = 1sec*/
					SELECT a.CONSTITUENTDIMID as constituent_id
				     , coalesce(sui.unit_id,'500')				as unit_id 
                     , coalesce(sui.unit_name,'Other')			as unit_name 
				     , 'Alumni' AS REL_TYPE
				     , MAX(2)   AS IS_LEADER
				     , NULL AS PA_EARLIEST_CLASS_YR
				     , NULL AS PA_MOST_RECENT_CLASS_YR
				     , NULL AS CURRENT_BOARD
				     , NULL AS FORMER_BOARD
				     , MAX(A.DEGREEYEAR) AS unit_class_year
	                 
                  FROM --BBCRM_PROD_RPT_BBDW.BBDW.VCU_RPT_ALUMNIBYDECADE a
				       BBCRM_PROD_RPT_BBDW.BBDW.VCU_RPT_ALUMNIBYDECADE a
                  join DARanalytics.ref.school_unit_info sui on sui.site_id = a.siteid
                 WHERE a.graduate = 1
  			  GROUP BY
				     A.constituentdimID
				   , sui.unit_id  
				   , sui.unit_name --can probably get rid of this

				  --   order by unit_id
	UNION ALL

			/* ALL ALUMNI - N=2.6k Time = 1sec  --this captures alums who for whatever reason can't be classified as to undergrad or grad degree*/
					SELECT a.CONSTITUENTDIMID as constituent_id
				     , coalesce(sui.unit_id,'500')				as unit_id 
                     , coalesce(sui.unit_name,'Other')			as unit_name 
				     , 'Alumni' AS REL_TYPE
				     , MAX(3)   AS IS_LEADER
				     , NULL AS PA_EARLIEST_CLASS_YR
				     , NULL AS PA_MOST_RECENT_CLASS_YR
				     , NULL AS CURRENT_BOARD
				     , NULL AS FORMER_BOARD
				     , MAX(A.DEGREEYEAR) AS unit_class_year
	                 
                  FROM --BBCRM_PROD_RPT_BBDW.BBDW.VCU_RPT_ALUMNIBYDECADE a
				       BBCRM_PROD_RPT_BBDW.BBDW.VCU_RPT_ALUMNIBYDECADE a
                  join DARanalytics.ref.school_unit_info sui on sui.site_id = a.siteid
				  where a.undergraduate = 0
				    and a.graduate = 0
 
  			  GROUP BY
				     A.constituentdimID
				   , sui.unit_id  
				   , sui.unit_name --can probably get rid of this

UNION ALL

			/* CURRENT PARENTS N= 19k Time= 5secs  9/23/25*/
			
			SELECT parent_dim_id as constituent_dim_id
	             , unit_id 
	             , unit_name
	 			 , 'Parent' AS REL_TYPE
				 , NULL AS IS_LEADER
				 , NULL AS PA_EARLIEST_CLASS_YR
				 , NULL AS PA_MOST_RECENT_CLASS_YR
				 , NULL AS CURRENT_BOARD
				 , NULL AS FORMER_BOARD
				 , NULL AS SCHOOL_UNIT_CLASS_YEAR
			  from (
					SELECT --concat(p.CONSTITUENTSYSTEMID,'_',edu.CONSTITUENTSYSTEMID) as parent_kid_id
						   p.CONSTITUENTSYSTEMID	as parent_system_id
						  ,p.CONSTITUENTDIMID		as parent_dim_id
						 

						  ,edu.CONSTITUENTDIMID
						  ,edu.CONSTITUENTSYSTEMID
						  ,edu.EDUCATIONDEGREE
						  ,ei.EDUCATIONALCOLLEGE
						  ,edu.EDUCATIONPROGRAM
						  ,edu.EDUCATIONSTARTDATE					--only refers to latest recorded semester - data is a bit crap
						  ,edu.EDUCATIONSYSTEMID
						  ,ei.EDUCATIONDIMID
						  ,ei.EDUCATIONALDEPARTMENT


						  ,case when sui.campaign_display_name is not null then sui.campaign_display_name
								when ei.EDUCATIONALCOLLEGE = 'Wilder School' then 'L. Douglas Wilder School of Government & Public Affairs'
								when ei.EDUCATIONALCOLLEGE = 'School of Life Sciences' then 'College of Humanities & Sciences'
								when ei.EDUCATIONALCOLLEGE = 'University College' then 'University College'
								when ei.EDUCATIONALCOLLEGE = 'School of Public Health' then 'School of Public Health'
								else NULL end as campaign_display_name
						  ,case when sui.unit_id is not null then sui.unit_id
								when ei.EDUCATIONALCOLLEGE = 'Wilder School' then 280
								when ei.EDUCATIONALCOLLEGE = 'School of Life Sciences' then 245
								when ei.EDUCATIONALCOLLEGE = 'University College' then 150
								when ei.EDUCATIONALCOLLEGE = 'School of Public Health' then 470
								else NULL end as unit_id
						  ,case when sui.unit_name is not null then sui.unit_name
								when ei.EDUCATIONALCOLLEGE = 'Wilder School' then 'Wilder School'
								when ei.EDUCATIONALCOLLEGE = 'School of Life Sciences' then 'Humanities and Sciences'
								when ei.EDUCATIONALCOLLEGE = 'University College' then 'University College'
								when ei.EDUCATIONALCOLLEGE = 'School of Public Health' then 'Public Health'
								else NULL end as unit_name

						 -- ,p.CONSTITUENTRELATIONSHIPTYPEDIMID
						 -- ,p.RECIPROCALCONSTITUENTSYSTEMID
					 	 -- ,cl.constituent_lookup_id
						 -- ,cl.bio_name as student_name
						 -- ,edu.EDUCATIONCONSTITUENCYSTATUS		--constant
						 -- ,edu.EDUCATIONINSTITUTION				--constant
					  FROM BBCRM_PROD_RPT_BBDW.BBDW.v_FACT_CONSTITUENTRELATIONSHIP as p
					  join (  --getting latest dim_education record per student
  							select * from (
											select * 
											 	 , row_number() over (partition by edu.CONSTITUENTSYSTEMID order by EDUCATIONSTARTDATEDIMID desc, EDUCATIONINFORMATIONSOURCEDATE desc) as row_num
											  from BBCRM_PROD_RPT_BBDW.BBDW.DIM_EDUCATION edu
											 where edu.EDUCATIONCONSTITUENCYSTATUS	= 'Currently attending' 
											   and edu.EDUCATIONINSTITUTION			= 'Virginia Commonwealth University (VCU)'
											   --and CONSTITUENTSYSTEMID = '10C01858-7A00-4393-B689-10E80B8C5F0D'
											) t
							  where row_num = 1
							) as edu on p.RECIPROCALCONSTITUENTSYSTEMID = edu.CONSTITUENTSYSTEMID

						 join BBCRM_PROD_RPT_BBDW.BBDW.DIM_EDUCATIONADDITIONALINFORMATION ei on edu.CONSTITUENTSYSTEMID = ei.CONSTITUENTSYSTEMID
																							and edu.educationdimid = ei.educationdimid				--join in the row that matches the latest currently attending record
																							and ei.EDUCATIONALCOLLEGE <> 'No Educational College'	--gets rid of students who don't have an educational college to link to in the unit table we are creating.  Created NULLs which aren't allowed
	
					left join DARanalytics.ref.school_unit_info sui on sui.campaign_display_name = ei.EDUCATIONALCOLLEGE
					--	 join DARanalytics.datamart.constituent_level as cl on cl.constituent_system_id = edu.CONSTITUENTSYSTEMID
						where p.CONSTITUENTRELATIONSHIPTYPEDIMID	= 2		--parent relationship
						  and edu.EDUCATIONCONSTITUENCYSTATUS		= 'Currently attending' 
						  and edu.EDUCATIONINSTITUTION				= 'Virginia Commonwealth University (VCU)'
						  and ei.EDUCATIONALDEGREETYPE				= 'Primary Major'
						  and ei.EDUCATIONALCOLLEGE					not in ('Engineering & Pharmacy','Office of the VP for Research')		--grad programs with no siteid
							--and edu.CONSTITUENTSYSTEMID = '05FE2F98-457C-403B-8BED-D56918DA5995_97D19C57-4248-4D3D-9EAD-99857F265B08'
							--order by unit_id
					) par 
					join BBCRM_PROD_RPT_BBDW.BBDW.VCU_RPT_CONSTITUENTLIST cl on cl.constituentdimid = par.parent_dim_id  --gets rid of 2 inactive records	
					--need to group in case a parent has more than 1 child in the same unit
					group by par.parent_dim_id	
						   , par.unit_id 
						   , par.unit_name

	UNION ALL

	/* EVER PARENTS N= 35k Time= 2secs  10/21/25*/
			
			SELECT par_ever.parent_dim_id as constituent_dim_id
	             , par_ever.unit_id 
	             , par_ever.unit_name
	 			 , 'ParentEver' AS REL_TYPE
				 , NULL AS IS_LEADER
				 , NULL AS PA_EARLIEST_CLASS_YR
				 , NULL AS PA_MOST_RECENT_CLASS_YR
				 , NULL AS CURRENT_BOARD
				 , NULL AS FORMER_BOARD
				 , NULL AS SCHOOL_UNIT_CLASS_YEAR
			  from (
					SELECT --concat(p.CONSTITUENTSYSTEMID,'_',edu.CONSTITUENTSYSTEMID) as parent_kid_id
						   p.CONSTITUENTSYSTEMID	as parent_system_id
						  ,p.CONSTITUENTDIMID		as parent_dim_id
						 

						  ,edu.CONSTITUENT_dim_ID
						  ,edu.CONSTITUENT_SYSTEM_ID
						  ,edu.EDUCATIONDEGREE
						  ,ei.EDUCATIONALCOLLEGE
						  ,edu.EDUCATIONPROGRAM
						  ,edu.EDUCATIONSTARTDATE					--only refers to latest recorded semester - data is a bit crap
						  ,edu.EDUCATIONSYSTEMID
						  ,ei.EDUCATIONDIMID
						  ,ei.EDUCATIONALDEPARTMENT


						  ,case when sui.campaign_display_name is not null then sui.campaign_display_name
								when ei.EDUCATIONALCOLLEGE = 'Wilder School' then 'L. Douglas Wilder School of Government & Public Affairs'
								when ei.EDUCATIONALCOLLEGE = 'School of Life Sciences' then 'College of Humanities & Sciences'
								when ei.EDUCATIONALCOLLEGE = 'University College' then 'University College'
								when ei.EDUCATIONALCOLLEGE = 'School of Public Health' then 'School of Public Health'
								else NULL end as campaign_display_name
						  ,case when sui.unit_id is not null then sui.unit_id
								when ei.EDUCATIONALCOLLEGE = 'Wilder School' then 280
								when ei.EDUCATIONALCOLLEGE = 'School of Life Sciences' then 245
								when ei.EDUCATIONALCOLLEGE = 'University College' then 150
								when ei.EDUCATIONALCOLLEGE = 'School of Public Health' then 470
								else NULL end as unit_id
						  ,case when sui.unit_name is not null then sui.unit_name
								when ei.EDUCATIONALCOLLEGE = 'Wilder School' then 'Wilder School'
								when ei.EDUCATIONALCOLLEGE = 'School of Life Sciences' then 'Humanities and Sciences'
								when ei.EDUCATIONALCOLLEGE = 'University College' then 'University College'
								when ei.EDUCATIONALCOLLEGE = 'School of Public Health' then 'Public Health'
								else NULL end as unit_name

						 -- ,p.CONSTITUENTRELATIONSHIPTYPEDIMID
						 -- ,p.RECIPROCALCONSTITUENTSYSTEMID
					 	 -- ,cl.constituent_lookup_id
						 -- ,cl.bio_name as student_name
						 -- ,edu.EDUCATIONCONSTITUENCYSTATUS		--constant
						 -- ,edu.EDUCATIONINSTITUTION				--constant
					  FROM BBCRM_PROD_RPT_BBDW.BBDW.v_FACT_CONSTITUENTRELATIONSHIP as p
					  join (  --getting latest dim_education record per student
							 select * from (
											select * 
											 	 , row_number() over (partition by edu.constituent_system_id order by educationstartdate desc, EDUCATIONINFORMATIONSOURCEDATE desc) as row_num
											  --from BBCRM_PROD_RPT_BBDW.BBDW.DIM_EDUCATION edu
											  from DARanalytics.tableau.vcu_education_degrees edu
											 where edu.EDUCATIONCONSTITUENCYSTATUS	in ('Graduated', 'Currently attending')
											  -- and edu.EDUCATIONINSTITUTION			= 'Virginia Commonwealth University (VCU)'
											   --and CONSTITUENTSYSTEMID = '10C01858-7A00-4393-B689-10E80B8C5F0D'
											) t
							  where row_num = 1
							) as edu on p.RECIPROCALCONSTITUENTSYSTEMID = edu.constituent_system_id

						 join BBCRM_PROD_RPT_BBDW.BBDW.DIM_EDUCATIONADDITIONALINFORMATION ei on edu.constituent_system_id = ei.CONSTITUENTSYSTEMID
																							and edu.educationdimid = ei.educationdimid				--join in the row that matches the latest currently attending record
					  left join DARanalytics.ref.school_unit_info sui on sui.campaign_display_name = ei.EDUCATIONALCOLLEGE
					--	 join DARanalytics.datamart.constituent_level as cl on cl.constituent_system_id = edu.CONSTITUENTSYSTEMID
						where p.CONSTITUENTRELATIONSHIPTYPEDIMID	= 2		--parent relationship
						  --and edu.EDUCATIONCONSTITUENCYSTATUS		= 'Currently attending' 
						  --and edu.EDUCATIONINSTITUTION				= 'Virginia Commonwealth University (VCU)'				
						  and ei.EDUCATIONALDEGREETYPE				= 'Primary Major'
						  and ei.EDUCATIONALCOLLEGE					not in ('Engineering & Pharmacy','Office of the VP for Research')		--grad programs with no siteid
							--and edu.CONSTITUENTSYSTEMID = '05FE2F98-457C-403B-8BED-D56918DA5995_97D19C57-4248-4D3D-9EAD-99857F265B08'
							--order by unit_id
					) par_ever 
					join BBCRM_PROD_RPT_BBDW.BBDW.VCU_RPT_CONSTITUENTLIST cl on cl.constituentsystemid = par_ever.parent_system_id  --gets rid of 2 inactive records	
					left join DARanalytics.ref.school_unit_info sui on sui.unit_id = par_ever.unit_id
					where sui.unit_id is not null --gets rid of daVinci center grads as well as some unknowns

					--need to group in case a parent has more than 1 child in the same unit
					group by par_ever.parent_dim_id	
						   , par_ever.unit_id 
						   , par_ever.unit_name
						   
	UNION ALL
			/* DONORS -- All units N= 391K Time= 10secs*/
			SELECT constituent_dim_id
	             , unit_id 
	             , unit_name
	 			 , 'Donor' AS REL_TYPE
				 , NULL AS IS_LEADER
				 , NULL AS PA_EARLIEST_CLASS_YR
				 , NULL AS PA_MOST_RECENT_CLASS_YR
				 , NULL AS CURRENT_BOARD
				 , NULL AS FORMER_BOARD
				 , NULL AS SCHOOL_UNIT_CLASS_YEAR

			  FROM DARanalytics.datamart.gvg_revenue_history_summary_indiv_unit
			--  where unit_name like '%massey%'
			  --where unit_id <> '500'  --these are unit agnostic  --removed upstream

		UNION ALL

			/* CURRENTLY MANAGED N=4k Time= 1secs*/
				 --FOR SOME REASON THERE ARE 3 PEOPLE WITH 'NOT A PROSPECT' or 'UNASSIGNED' PROSPECT STATUSES IN THIS GROUP
		SELECT 	 p.CONSTITUENTDIMID as constituent_dim_id
				 , coalesce(goi.unit_id,'500')			as unit_id  --Other is the default so it isn't null
				 , coalesce(goi.unit_name,'Other')		as unit_name
				 , 'Managed' as REL_TYPE
				 , NULL AS IS_LEADER
				 , NULL AS PA_EARLIEST_CLASS_YR
				 , NULL AS PA_MOST_RECENT_CLASS_YR
				 , NULL AS CURRENT_BOARD
				 , NULL AS FORMER_BOARD
				 , NULL AS SCHOOL_UNIT_CLASS_YEAR
	
		  FROM BBCRM_PROD_RPT_BBDW.BBDW.DIM_PROSPECT p
     left join DARanalytics.ref.gift_officer_info goi on goi.officer_system_id = p.FUNDRAISERSYSTEMID
												   and goi.position_order_desc = 1    --latest position                                         
         where getdate() between coalesce(p.PROSPECTMANAGERSTARTDATE,'1/1/1980') and coalesce(p.PROSPECTMANAGERENDDATE, '12/31/2099')
           and fundraiserdimid > 0
      group by p.CONSTITUENTDIMID, p.CONSTITUENTSYSTEMID, goi.unit_id, goi.unit_name
	  --order by unit_id
	

		UNION ALL

/*  PROSPECT TEAM MANAGED  */

SELECT pt.constituent_dim_id
	 , coalesce(pt.unit_id,'500')			as unit_id  --Other is the default so it isn't null
	 , coalesce(pt.unit_name,'Other')		as unit_name
	 , 'Team Managed' as REL_TYPE
	 , NULL AS IS_LEADER
	 , NULL AS PA_EARLIEST_CLASS_YR
	 , NULL AS PA_MOST_RECENT_CLASS_YR
	 , NULL AS CURRENT_BOARD
	 , NULL AS FORMER_BOARD
	 , NULL AS SCHOOL_UNIT_CLASS_YEAR

	
--SELECT PROSPECTSYSTEMID as constituent_system_id
--     , max(case when FUNDRAISERROLECODE = 'Team Member' then 1 else 0 end) as flag_managed_team_current  --people can be both team member and team member former so there is that
--	 , max(case when FUNDRAISERROLECODE like '%stewardship%' then 1 else 0 end) as flag_managed_stewardship_current
--	 , max(case when FUNDRAISERROLECODE like '%discovery%' then 1 else 0 end) as flag_managed_discovery_current
--	 , max(case when FUNDRAISERROLECODE like '%engagement%' then 1 else 0 end) as flag_managed_engagement_current
--	 , max(case when FUNDRAISERROLECODE like '%alumni%' then 1 else 0 end) as flag_managed_alumni_relations_current
--     , sum(case when FUNDRAISERROLECODE = 'Team Member' then 1 else 0 end
--		+ case when FUNDRAISERROLECODE like '%stewardship%' then 1 else 0 end 
--		+ case when FUNDRAISERROLECODE like '%discovery%' then 1 else 0 end
--		+ case when FUNDRAISERROLECODE like '%engagement%' then 1 else 0 end
--		+ case when FUNDRAISERROLECODE like '%alumni%' then 1 else 0 end) as pm_num_managed_types
  
  FROM (
		SELECT pt.PROSPECTDIMID		as constituent_dim_id
			-- , pt.FUNDRAISERROLECODE
			 , goi.unit_id
			 , goi.unit_name
			 , case when NULLIF(MAX(COALESCE(EndDate,'9999-12-31')),'9999-12-31') is null then 1 else 0 end as prospectteam_current
		--   , max(STARTDATE) as min_startdate
		--   , max(ENDDATE) as max_enddate

		  FROM BBCRM_PROD_RPT_BBDW.BBDW.VCU_DIM_PROSPECTTEAM pt
     left join DARanalytics.ref.gift_officer_info goi on goi.officer_system_id = pt.FUNDRAISERSYSTEMID
												   and goi.position_order_desc = 1    --latest position    
		 WHERE pt.FUNDRAISERROLECODE <> 'Team Member - Former'   --Gets rid of situations where someone is both team member and team member - former
	  GROUP BY pt.prospectdimid, goi.unit_id, goi.unit_name --, fundraiserrolecode
   -- ORDER BY fundraiserrolecode --prospectteam_current desc
	  ) pt

  where pt.prospectteam_current = 1
  group by pt.constituent_dim_id, pt.unit_id, pt.unit_name
 -- order by pm_num_managed_types desc
	



			/* EVER MANAGED N=33k Time=1secs*/
	
	/*EDUCATIONAL INVOLVEMENT N=5k Time=1sec*/
	UNION ALL

		SELECT CONSTITUENTDIMID as constituent_dim_id
			 , coalesce(sui.unit_id,'500')			as unit_id 
			 , coalesce(sui.unit_name,'Other')		as unit_name 
			 , 'Education Involvement' as REL_TYPE
			 , NULL AS IS_LEADER
			 , NULL AS PA_EARLIEST_CLASS_YR
			 , NULL AS PA_MOST_RECENT_CLASS_YR
			 , NULL AS CURRENT_BOARD
			 , NULL AS FORMER_BOARD
			 , NULL AS SCHOOL_UNIT_CLASS_YEAR
		  FROM (
				SELECT CONSTITUENTDIMID
					 , CONSTITUENTSYSTEMID
					 , EDUCATIONALINVOLVEMENTTYPEDESCRIPTION
					-- , EDUCATIONALINVOLVEMENTSYSTEMID
					 , case when educationalinvolvementtypedescription = 'Athletics' then '210'					
							when educationalinvolvementtypedescription = 'Library Student Worker' then '275'	
							when educationalinvolvementtypedescription = 'Rams in Recovery' then '145'			
							else NULL end as unit_id
				  FROM BBCRM_PROD_RPT_BBDW.BBDW.DIM_EDUCATIONALINVOLVEMENT
				 where educationalinvolvementtypedescription in ('Athletics', 'Library Student Worker','Rams in Recovery')
				 group by CONSTITUENTDIMID, CONSTITUENTSYSTEMID, EDUCATIONALINVOLVEMENTTYPEDESCRIPTION   -- EDUCATIONALINVOLVEMENTSYSTEMID  --, EDUCATIONALINVOLVEMENTNAME
			  -- order by educationalinvolvementtypedescription
		) t
		 left join DARanalytics.ref.school_unit_info sui on sui.unit_id = t.unit_id

			UNION ALL

			/* BOARDS and COMMITTEES N=1.5k Time=1secs*/
		
			SELECT constituent_dim_id
				 , coalesce(sui.unit_id,'500')			as unit_id 
				 , coalesce(sui.unit_name,'Other')		as unit_name 
				 , 'Board' as REL_TYPE
				 , NULL AS IS_LEADER
				 , NULL AS PA_EARLIEST_CLASS_YR
				 , NULL AS PA_MOST_RECENT_CLASS_YR
				 , 1 AS CURRENT_BOARD
				 , NULL AS FORMER_BOARD
				 , NULL AS SCHOOL_UNIT_CLASS_YEAR
			--	 , count(*) as num_active_boardsNcommittees

			/*,
			  ,[constituent_lookup_id]
			  , constituent_system_id
			  ,[bio_name]
			  ,[start_date]
			  ,[end_date]
			  ,[iscurrent]
			  ,[isprimary]
			  ,[bio_gender]
			  ,[bio_race_desc]
			  */
	  
  FROM DARanalytics.tableau.committees_active_members cam
  left join DARanalytics.ref.committee_site_crosswalk csc on csc.committee_lookup_ID = cam.constituent_group_lookup_id
  left join DARanalytics.ref.school_unit_info sui on sui.site_dim_id = csc.site_dim_id
  where unit_id is not null
   group by cam.constituent_dim_id, sui.unit_id, sui.unit_name
 --order by num_active_boardsNcommittees desc, unit_id 


	
			--UNION ALL

			/* CONTACTED N=243k Time=15secs */


			--UNION ALL

/* SOLICITED FOR BENEFITING UNIT  N=35k Time=1secs  */
	
		  

		--UNION ALL

			/* SOLICITED BY OFFICER N=32k Time=1secs */


			--UNION ALL

			/* REFERRALS */


UNION ALL

			/* PGI UNIT SUSPECT OR  */
			SELECT constituent_dim_id
				 , coalesce(pgi_unit_id,'500')					as unit_id
				 , coalesce(pgi_unit_name,'Other')				as unit_name
				 , 'PGI Good'					as REL_TYPE
			--	 , pgi_inclination_level_code
			--	 , pm_prospect_status
				 , NULL AS IS_LEADER
				 , NULL AS PA_EARLIEST_CLASS_YR
				 , NULL AS PA_MOST_RECENT_CLASS_YR
				 , NULL AS CURRENT_BOARD
				 , NULL AS FORMER_BOARD
				 , NULL AS SCHOOL_UNIT_CLASS_YEAR

/*
SELECT constituent_dim_id
      ,constituent_system_id
      ,constituent_lookup_id
      ,bio_name
      --,pm_prospect_status
      --,pm_prospect_status_hh
      --,PROSPECTGIVINGINTERESTSDIMID
      --,PROSPECTGIVINGINTERESTSSYSTEMID
      ,SITEDIMID  as site_dim_id
      ,pgi_unit_name
      ,pgi_unit_id
      ,pgi_funding_type_code
      --,pgi_inclination_level_code
      --,pgi_comment
      --,pgi_include_spouse
      --,row_num
      --,row_num_pgsi
      --,start_date
      --,stop_date
      --,flag_all_of_vcu_not_prospect
      --,flag_unit_not_prospect
      --,pgi_fundraiser_unit_id
      --,pgi_fundraiser_unit_name
*/
  FROM DARanalytics.tableau.unit_active_pgis

   where pgi_inclination_level_code in ('Suspect','Positive')
     and isnull(pm_prospect_status,'isNULL') in ('Assigned','Referred','Permanent Stewardship','isNULL')

group by constituent_dim_id
      , constituent_system_id
      , constituent_lookup_id
	  , bio_name
	  , pgi_unit_name
      , pgi_unit_id
	  , sitedimid
	 -- , pgi_inclination_level_code
	 -- , pm_prospect_status

UNION ALL 

			/* PGI UNIT NOT A PROSPECT */
			SELECT constituent_dim_id
				 , coalesce(pgi_unit_id,'500')	 				as unit_id
				 , coalesce(pgi_unit_name,'Other') 				as unit_name
				 , 'PGI NAP All Levels'						as REL_TYPE
				 , NULL AS IS_LEADER
				 , NULL AS PA_EARLIEST_CLASS_YR
				 , NULL AS PA_MOST_RECENT_CLASS_YR
				 , NULL AS CURRENT_BOARD
				 , NULL AS FORMER_BOARD
				 , NULL AS SCHOOL_UNIT_CLASS_YEAR

  FROM DARanalytics.tableau.unit_active_pgis

  where (
       (pgi_inclination_level_code = 'Not a prospect-unit based only' and pgi_funding_type_code = 'All Levels' and pm_prospect_status= 'Unassigned')
    or (pgi_inclination_level_code = 'Not a prospect-unit based only' and pgi_funding_type_code = 'All Levels' and pm_prospect_status= 'Not a Prospect')
    or (pgi_inclination_level_code = 'Not a prospect-unit based only' and pgi_funding_type_code = 'All Levels' and pm_prospect_status= 'Assigned' and pgi_unit_id<>pgi_fundraiser_unit_id)
    or (pgi_inclination_level_code = 'Not a prospect-unit based only' and pgi_funding_type_code = 'All Levels' and pm_prospect_status= 'Assigned' and pgi_fundraiser_unit_id is NULL)
	or (pgi_inclination_level_code = 'Not a prospect-unit based only' and pgi_funding_type_code = 'All Levels' and pm_prospect_status= 'Permanent Stewardship')
		)
	--and pgi_unit_id is not null

group by constituent_dim_id
      , constituent_system_id
      , constituent_lookup_id
	  , bio_name
	  , pgi_unit_name
      , pgi_unit_id
	  , sitedimid
-- order by pgi_unit_id

UNION ALL

			/* PGI NOT A Principal Major Gift PROSPECT to the Unit*/
			SELECT constituent_dim_id
				 , coalesce(pgi_unit_id,'500')	 				as unit_id
				 , coalesce(pgi_unit_name,'Other') 				as unit_name
				 , 'PGI NAP Principal/Major Gift'						as REL_TYPE
				 , NULL AS IS_LEADER
				 , NULL AS PA_EARLIEST_CLASS_YR
				 , NULL AS PA_MOST_RECENT_CLASS_YR
				 , NULL AS CURRENT_BOARD
				 , NULL AS FORMER_BOARD
				 , NULL AS SCHOOL_UNIT_CLASS_YEAR

  FROM DARanalytics.tableau.unit_active_pgis

  where (
       (pgi_inclination_level_code = 'Not a prospect-unit based only' and pgi_funding_type_code = 'Principal/Major Gift' and pm_prospect_status= 'Unassigned')
    or (pgi_inclination_level_code = 'Not a prospect-unit based only' and pgi_funding_type_code = 'Principal/Major Gift' and pm_prospect_status= 'Not a Prospect')
    or (pgi_inclination_level_code = 'Not a prospect-unit based only' and pgi_funding_type_code = 'Principal/Major Gift' and pm_prospect_status= 'Assigned' and pgi_unit_id<>pgi_fundraiser_unit_id)
    or (pgi_inclination_level_code = 'Not a prospect-unit based only' and pgi_funding_type_code = 'Principal/Major Gift' and pm_prospect_status= 'Assigned' and pgi_fundraiser_unit_id is NULL)
	or (pgi_inclination_level_code = 'Not a prospect-unit based only' and pgi_funding_type_code = 'Principal/Major Gift' and pm_prospect_status= 'Permanent Stewardship')
		)
	--and pgi_unit_id is not null

group by constituent_dim_id
      , constituent_system_id
      , constituent_lookup_id
	  , bio_name
	  , pgi_unit_name
      , pgi_unit_id
	  , sitedimid

UNION ALL

			/* PGI NOT A Leadership Annual Gift PROSPECT to the Unit*/
			SELECT constituent_dim_id
				 , coalesce(pgi_unit_id,'500')	 				as unit_id
				 , coalesce(pgi_unit_name,'Other') 				as unit_name
				 , 'PGI NAP Leadership Annual Gift'						as REL_TYPE
				 , NULL AS IS_LEADER
				 , NULL AS PA_EARLIEST_CLASS_YR
				 , NULL AS PA_MOST_RECENT_CLASS_YR
				 , NULL AS CURRENT_BOARD
				 , NULL AS FORMER_BOARD
				 , NULL AS SCHOOL_UNIT_CLASS_YEAR

  FROM DARanalytics.tableau.unit_active_pgis

  where (
       (pgi_inclination_level_code = 'Not a prospect-unit based only' and pgi_funding_type_code = 'Leadership annual gift' and pm_prospect_status= 'Unassigned')
    or (pgi_inclination_level_code = 'Not a prospect-unit based only' and pgi_funding_type_code = 'Leadership annual gift' and pm_prospect_status= 'Not a Prospect')
    or (pgi_inclination_level_code = 'Not a prospect-unit based only' and pgi_funding_type_code = 'Leadership annual gift' and pm_prospect_status= 'Assigned' and pgi_unit_id<>pgi_fundraiser_unit_id)
    or (pgi_inclination_level_code = 'Not a prospect-unit based only' and pgi_funding_type_code = 'Leadership annual gift' and pm_prospect_status= 'Assigned' and pgi_fundraiser_unit_id is NULL)
	or (pgi_inclination_level_code = 'Not a prospect-unit based only' and pgi_funding_type_code = 'Leadership annual gift' and pm_prospect_status= 'Permanent Stewardship')
		)
	--and pgi_unit_id is not null

group by constituent_dim_id
      , constituent_system_id
      , constituent_lookup_id
	  , bio_name
	  , pgi_unit_name
      , pgi_unit_id
	  , sitedimid

UNION ALL

/*Current Employees*/
SELECT t.CONSTITUENTDIMID					as constituent_dim_id
	 , coalesce(t.unit_id,'500')	 		as unit_id
	 , coalesce(t.unit_name,'Other') 		as unit_name
	 , 'FacultyStaff'						as REL_TYPE
	 , NULL AS IS_LEADER
	 , NULL AS PA_EARLIEST_CLASS_YR
	 , NULL AS PA_MOST_RECENT_CLASS_YR
	 , NULL AS CURRENT_BOARD
	 , NULL AS FORMER_BOARD
	 , NULL AS SCHOOL_UNIT_CLASS_YEAR

--, t.CONSTITUENTSYSTEMID
--, t.CONSTITUENTLOOKUPID
--, t.service_area_id_match	as service_area_system_id
 from (
		select fs.CONSTITUENTDIMID, fs.CONSTITUENTLOOKUPID, fs.CONSTITUENTSYSTEMID, sui.unit_id, sui.unit_name
		from (  --select all the current employees and try to assign them to a unit and service area based on their jobdivision
			SELECT CONSTITUENTSYSTEMID
				 , CONSTITUENTDIMID
				 , CONSTITUENTLOOKUPID
	
				 , case when jobdivision = '' and employer = 'VCU Health System' then 400
						when jobdivision in ('','Retiree') then NULL
						when jobdivision = 'Institute for Contemporary Art' then 205			--Changing ICA to Arts
						when jobdivision = 'Life Sciences' then 245								--Changing Life Sciences to H&S
						when jobdivision = 'College of Humanities and Sciences' then 245
						when jobdivision = 'College of Humanit and Sciences' then 245
						when jobdivision = 'L D Wilder Sch of Govt & Pub Affrs' then 280	
						when jobdivision = 'Massey Cancer Center' then 405							
						when jobdivision = 'Massey Comprehensive Cancer Ctr' then 405							
						when jobdivision = 'Hospital - VCUMC' then 400							
						when jobdivision = 'Student Affairs (Vice Provost)' then 145
						when jobdivision = 'VCU Graduate School' then 235	
						when jobdivision = 'School of Denistry' then 310	
						when jobdivision = 'School of Public Health' then 470
						when jobdivision = 'Ambulatory Clinics - VCUMC' then 400	
						when jobdivision = 'Cardiology' then 400	
						when jobdivision = 'Division of Cardiology' then 400	
						when jobdivision = 'Hospital - CMH' then 400	
						when jobdivision = 'Hospital - CSBR' then 400
						when jobdivision = 'Hospital - CSMC' then 400	
						when jobdivision = 'Hospital - TAPP' then 400	
						when jobdivision = 'Long Term Care - CMH' then 400
						when jobdivision = 'Long Term Care - CSBR' then 400
						when jobdivision = 'MCVP Physicians' then 400
						when jobdivision = 'Physicians - CMHP' then 400
						when jobdivision = 'Physicians - MCVP' then 400
						when jobdivision = 'VCU School of Medicine - MCVP' then 350
						when jobdivision = 'VCUHS MCV Hospital' then 400
						when jobdivision = 'Athletics' then 210
						when jobdivision = 'Global Education Office' then 230
						when jobdivision = 'Graduate School' then 235
						when jobdivision = 'Honors College' then 240
						when jobdivision = 'Office Of The Provost' then 135
						when jobdivision = 'University College' then 150
						when jobdivision = 'VP For Health Sciences' then 810
		 				when jobdivision = sui.campaign_display_name then sui.unit_id

						when employer = 'VCU Health System' then 400
						else NULL end as unit_id_match

				,  case when jobdivision = ''									then NULL
						when jobdivision = 'Massey Cancer Center'				then '2286B060-9561-409A-A1CC-60578F7E23DA'							
						when jobdivision = 'Massey Comprehensive Cancer Ctr'	then '2286B060-9561-409A-A1CC-60578F7E23DA'							
						when jobdivision = 'Cardiology'							then '945B52BD-4ADB-462D-AF8B-BA98D0C608C4'	
						when jobdivision = 'Division of Cardiology'				then '945B52BD-4ADB-462D-AF8B-BA98D0C608C4'	
						else NULL end as service_area_id_match

			  ,JOBDIVISION
			  ,JOBDEPARTMENT
			  ,EMPLOYER

		  FROM BBCRM_PROD_RPT_BBDW.BBDW.VCU_RPT_FACULTYSTAFF_CURRENT fs
		  left join DARanalytics.ref.school_unit_info sui on sui.campaign_display_name = fs.jobdivision
		  where fs.iscurrentemployment = 1

  ) fs
  left join DARanalytics.ref.school_unit_info sui on sui.unit_id = fs.unit_id_match
  where fs.unit_id_match is not null

  ) t
	 group by t.CONSTITUENTSYSTEMID
			, t.CONSTITUENTDIMID
			, t.CONSTITUENTLOOKUPID
			, t.unit_id
			, t.unit_name
			--, t.service_area_id_match

UNION ALL
(
/* people who received interest attributes from a survey 
RNL only as of August 2025 
21,666 people , <1s runtime*/

		SELECT CONSTITUENTDIMID							as constituent_dim_id
			 , coalesce(sui.unit_id,'500')	 					as unit_id
			 , coalesce(sui.unit_name,'Other') 				as unit_name
			 , 'surveyinterest'										as REL_TYPE
			 , NULL AS IS_LEADER
			 , NULL AS PA_EARLIEST_CLASS_YR
			 , NULL AS PA_MOST_RECENT_CLASS_YR
			 , NULL AS CURRENT_BOARD
			 , NULL AS FORMER_BOARD
			 , NULL AS SCHOOL_UNIT_CLASS_YEAR
from (

select 
    fca.constituentsystemid
    , fca.constituentdimid
    , um.unit_id
from bbcrm_prod_rpt_bbdw.bbdw.fact_constituentattribute as fca
inner join bbcrm_prod_rpt_bbdw.bbdw.dim_attribute as dima 
    on fca.attributedimid = dima.attributedimid
inner join (
	 select * from (values 
		('9DD1464C-5CD1-4909-BD71-01240E6812AE' , '145'), --Addiction and Recovery attribute / Student Affairs
		('520CE3E8-68C9-4422-A570-29D0F4FF1D02' , '145'), --Crisis or Student Emergency Fund attribute / Student Affairs
		('82704EE0-D14C-4AF6-9A6D-C76DA28ABFE7' , '145'), --First-Generation Students attribute / Student Affairs
		('19D98271-4DE9-42F7-828C-1A38ED5A4217' , '145'), --Food Insecurity attribute / Student Affairs
		('E1217CEB-18E5-4DD9-87EA-D788A76C9C59' , '145'), --Religious/Faith-Based attribute / Student Affairs
		('1A5EB708-77F3-47C4-BFAF-D9997940D9BB' , '145'), --Scholarship attribute / Student Affairs
		('D02BB97A-FFAA-4B5C-AAA1-281231719D3F' , '145'), --Student Activities & Student Life attribute / Student Affairs
		('2780A0B3-A009-41BD-B839-ADCB86E59AD6' , '145'), --Student Success attribute / Student Affairs
		('61FA3ED3-B971-4001-A90A-961EB5688F87' , '160'), --University-wide Area of Greatest Need attribute / University Wide
		('FE81411B-A4BA-491C-9337-91DC95D53871' , '160'), --VCU attribute / University Wide
		('DBA1A674-9E18-4C2C-BE37-03A034BCA0BF' , '205'), --Arts & Culture attribute / Arts
		('3E109C73-7415-43E6-9DFE-660B1DE008F2' , '210'), --Athletics attribute / Athletics
		('C754D54E-8CE4-44F2-A65B-7FC48111BCFE' , '220'), --Education & Youth Development attribute / Education
		('FD38BBCF-4CF1-4417-8D2A-5E7B9C03DAD8' , '220'), --Higher Education attribute / Education
		('1ECFDD86-0CB1-4356-B9A0-F38B4FC1ED61' , '260'), --Environmental Conservation attribute / Life Sciences
		('BEF384D6-2BE5-443D-8F2F-083096F2534A' , '265'), --Mental Health Services attribute / Social Work
		('C778E576-5BCC-4E6A-9393-5CD82C22D910' , '265'), --Social Services & Community Support attribute / Social Work
		('C778E576-5BCC-4E6A-9393-5CD82C22D910' , '280'), --Social Services & Community Support attribute / Wilder School
		('3872209C-33F1-4EFF-85AC-311EA107788A' , '350'), --Medical Research attribute / Medicine
		('BEF384D6-2BE5-443D-8F2F-083096F2534A' , '350'), --Mental Health Services attribute / Medicine
		('ADF36527-A80B-45B2-BEC5-09DCF4AE2479' , '360'), --Research attribute / Office of Research and Innovation
		('E97F4B8E-9997-428B-9B57-5042BF6E8C7C' , '400'), --Healthcare & Wellness attribute / VCU Health System
		('3872209C-33F1-4EFF-85AC-311EA107788A' , '400'), --Medical Research attribute / VCU Health System
		('3872209C-33F1-4EFF-85AC-311EA107788A' , '405') --Medical Research attribute / VCU Massey Comprehensive Cancer Center
    ) as mapping(attribute_id, unit_id)
) as um 
    on dima.attributevaluesystemid = um.attribute_id
group by fca.constituentsystemid, fca.constituentdimid, um.unit_id
	
/*	select CONSTITUENTSYSTEMID, CONSTITUENTDIMID, unit_id from
		(			
					--just to make it easy to check unit_ids
					--SELECT [unit_id] ,[unit_name] FROM [DARanalytics].[ref].[school_unit_info] order by unit_name
					SELECT
						  fca.CONSTITUENTSYSTEMID ,dima.ATTRIBUTEVALUESYSTEMID ,fca.ATTRIBUTEVALUE, fca.constituentdimid
							, 145 as unit_id --Student affairs
					  FROM BBCRM_PROD_RPT_BBDW.BBDW.FACT_CONSTITUENTATTRIBUTE as fca
					  left join	BBCRM_PROD_RPT_BBDW.bbdw.DIM_ATTRIBUTE as dima
					  on fca.ATTRIBUTEDIMID = dima.ATTRIBUTEDIMID
						where dima.ATTRIBUTEVALUESYSTEMID in ( '9DD1464C-5CD1-4909-BD71-01240E6812AE' ,
					 '520CE3E8-68C9-4422-A570-29D0F4FF1D02' ,  '82704EE0-D14C-4AF6-9A6D-C76DA28ABFE7' 
					 , '19D98271-4DE9-42F7-828C-1A38ED5A4217' , 'E1217CEB-18E5-4DD9-87EA-D788A76C9C59' ,
					 '1A5EB708-77F3-47C4-BFAF-D9997940D9BB' , 'D02BB97A-FFAA-4B5C-AAA1-281231719D3F' ,
					 '2780A0B3-A009-41BD-B839-ADCB86E59AD6' )

					UNION ALL
					SELECT
						  fca.CONSTITUENTSYSTEMID ,dima.ATTRIBUTEVALUESYSTEMID ,fca.ATTRIBUTEVALUE, fca.constituentdimid
							, 160 as unit_id --university wide
					  FROM [BBCRM_PROD_RPT_BBDW].[BBDW].[FACT_CONSTITUENTATTRIBUTE] as fca
					  left join                BBCRM_PROD_RPT_BBDW.bbdw.DIM_ATTRIBUTE as dima
					  on fca.ATTRIBUTEDIMID = dima.ATTRIBUTEDIMID
						where dima.ATTRIBUTEVALUESYSTEMID in ( '61FA3ED3-B971-4001-A90A-961EB5688F87' ,  'FE81411B-A4BA-491C-9337-91DC95D53871' )

					UNION ALL
					SELECT
						  fca.CONSTITUENTSYSTEMID ,dima.ATTRIBUTEVALUESYSTEMID ,fca.ATTRIBUTEVALUE, fca.constituentdimid
							, 205 as unit_id --arts
					  FROM [BBCRM_PROD_RPT_BBDW].[BBDW].[FACT_CONSTITUENTATTRIBUTE] as fca
					  left join                BBCRM_PROD_RPT_BBDW.bbdw.DIM_ATTRIBUTE as dima
					  on fca.ATTRIBUTEDIMID = dima.ATTRIBUTEDIMID
						where dima.ATTRIBUTEVALUESYSTEMID = 'DBA1A674-9E18-4C2C-BE37-03A034BCA0BF'

					UNION ALL
					SELECT
						  fca.CONSTITUENTSYSTEMID ,dima.ATTRIBUTEVALUESYSTEMID ,fca.ATTRIBUTEVALUE, fca.constituentdimid
							, 210 as unit_id --athletics
					  FROM [BBCRM_PROD_RPT_BBDW].[BBDW].[FACT_CONSTITUENTATTRIBUTE] as fca
					  left join                BBCRM_PROD_RPT_BBDW.bbdw.DIM_ATTRIBUTE as dima
					  on fca.ATTRIBUTEDIMID = dima.ATTRIBUTEDIMID
						where dima.ATTRIBUTEVALUESYSTEMID = '3E109C73-7415-43E6-9DFE-660B1DE008F2'

					UNION ALL
					SELECT
						  fca.CONSTITUENTSYSTEMID ,dima.ATTRIBUTEVALUESYSTEMID ,fca.ATTRIBUTEVALUE, fca.constituentdimid
							, 220 as unit_id --education
					  FROM [BBCRM_PROD_RPT_BBDW].[BBDW].[FACT_CONSTITUENTATTRIBUTE] as fca
					  left join                BBCRM_PROD_RPT_BBDW.bbdw.DIM_ATTRIBUTE as dima
					  on fca.ATTRIBUTEDIMID = dima.ATTRIBUTEDIMID
						where dima.ATTRIBUTEVALUESYSTEMID in ( 'C754D54E-8CE4-44F2-A65B-7FC48111BCFE' ,
					 'FD38BBCF-4CF1-4417-8D2A-5E7B9C03DAD8' )

					UNION ALL
					SELECT
						  fca.CONSTITUENTSYSTEMID ,dima.ATTRIBUTEVALUESYSTEMID ,fca.ATTRIBUTEVALUE, fca.constituentdimid
							, 260 as unit_id --life sciences
					  FROM [BBCRM_PROD_RPT_BBDW].[BBDW].[FACT_CONSTITUENTATTRIBUTE] as fca
					  left join                BBCRM_PROD_RPT_BBDW.bbdw.DIM_ATTRIBUTE as dima
					  on fca.ATTRIBUTEDIMID = dima.ATTRIBUTEDIMID
						where dima.ATTRIBUTEVALUESYSTEMID = '1ECFDD86-0CB1-4356-B9A0-F38B4FC1ED61'

					UNION ALL
					SELECT
						  fca.CONSTITUENTSYSTEMID ,dima.ATTRIBUTEVALUESYSTEMID ,fca.ATTRIBUTEVALUE, fca.constituentdimid
							, 265 as unit_id --social work
					  FROM [BBCRM_PROD_RPT_BBDW].[BBDW].[FACT_CONSTITUENTATTRIBUTE] as fca
					  left join                BBCRM_PROD_RPT_BBDW.bbdw.DIM_ATTRIBUTE as dima
					  on fca.ATTRIBUTEDIMID = dima.ATTRIBUTEDIMID
						where dima.ATTRIBUTEVALUESYSTEMID in ( 'C778E576-5BCC-4E6A-9393-5CD82C22D910' , 
						'BEF384D6-2BE5-443D-8F2F-083096F2534A' )

					UNION ALL
					SELECT
						  fca.CONSTITUENTSYSTEMID ,dima.ATTRIBUTEVALUESYSTEMID ,fca.ATTRIBUTEVALUE, fca.constituentdimid
							, 280 as unit_id --wilder
					  FROM [BBCRM_PROD_RPT_BBDW].[BBDW].[FACT_CONSTITUENTATTRIBUTE] as fca
					  left join                BBCRM_PROD_RPT_BBDW.bbdw.DIM_ATTRIBUTE as dima
					  on fca.ATTRIBUTEDIMID = dima.ATTRIBUTEDIMID
						where dima.ATTRIBUTEVALUESYSTEMID = 'C778E576-5BCC-4E6A-9393-5CD82C22D910'

					UNION ALL
					SELECT
						  fca.CONSTITUENTSYSTEMID ,dima.ATTRIBUTEVALUESYSTEMID ,fca.ATTRIBUTEVALUE, fca.constituentdimid
							, 350 as unit_id --medicine
					  FROM [BBCRM_PROD_RPT_BBDW].[BBDW].[FACT_CONSTITUENTATTRIBUTE] as fca
					  left join                BBCRM_PROD_RPT_BBDW.bbdw.DIM_ATTRIBUTE as dima
					  on fca.ATTRIBUTEDIMID = dima.ATTRIBUTEDIMID
						where dima.ATTRIBUTEVALUESYSTEMID in ( 'BEF384D6-2BE5-443D-8F2F-083096F2534A' ,
						'3872209C-33F1-4EFF-85AC-311EA107788A' )

					UNION ALL
					SELECT
						  fca.CONSTITUENTSYSTEMID ,dima.ATTRIBUTEVALUESYSTEMID ,fca.ATTRIBUTEVALUE, fca.constituentdimid
							, 360 as unit_id --ORI
					  FROM [BBCRM_PROD_RPT_BBDW].[BBDW].[FACT_CONSTITUENTATTRIBUTE] as fca
					  left join                BBCRM_PROD_RPT_BBDW.bbdw.DIM_ATTRIBUTE as dima
					  on fca.ATTRIBUTEDIMID = dima.ATTRIBUTEDIMID
						where dima.ATTRIBUTEVALUESYSTEMID = 'ADF36527-A80B-45B2-BEC5-09DCF4AE2479'

					UNION ALL
					SELECT
						  fca.CONSTITUENTSYSTEMID ,dima.ATTRIBUTEVALUESYSTEMID ,fca.ATTRIBUTEVALUE, fca.constituentdimid
							, 400 as unit_id --vcu health 
					  FROM [BBCRM_PROD_RPT_BBDW].[BBDW].[FACT_CONSTITUENTATTRIBUTE] as fca
					  left join                BBCRM_PROD_RPT_BBDW.bbdw.DIM_ATTRIBUTE as dima
					  on fca.ATTRIBUTEDIMID = dima.ATTRIBUTEDIMID
						where dima.ATTRIBUTEVALUESYSTEMID in ( 'E97F4B8E-9997-428B-9B57-5042BF6E8C7C' ,
						 '3872209C-33F1-4EFF-85AC-311EA107788A' )

					UNION ALL
					SELECT
						  fca.CONSTITUENTSYSTEMID ,dima.ATTRIBUTEVALUESYSTEMID ,fca.ATTRIBUTEVALUE, fca.constituentdimid
							, 405 as unit_id --massey 
					  FROM [BBCRM_PROD_RPT_BBDW].[BBDW].[FACT_CONSTITUENTATTRIBUTE] as fca
					  left join	BBCRM_PROD_RPT_BBDW.bbdw.DIM_ATTRIBUTE as dima
  						on fca.ATTRIBUTEDIMID = dima.ATTRIBUTEDIMID
					  where dima.ATTRIBUTEVALUESYSTEMID = '3872209C-33F1-4EFF-85AC-311EA107788A'

		) as t
		GROUP BY CONSTITUENTSYSTEMID, CONSTITUENTDIMID, unit_id */

) as rnl_survey
left join DARanalytics.ref.school_unit_info as sui on sui.unit_id = rnl_survey.unit_id

	) 

	UNION ALL

	/* email clicks for the last 365 days
	  n=25k time=5s  date 11/12/25 */
	SELECT CONSTITUENTDIMID							as constituent_dim_id
		, coalesce(sui.unit_id,'500')	 			as unit_id
		, coalesce(sui.unit_name,'Other') 			as unit_name
		, 'email_click'								as REL_TYPE
		, NULL AS IS_LEADER
		, NULL AS PA_EARLIEST_CLASS_YR
		, NULL AS PA_MOST_RECENT_CLASS_YR
		, NULL AS CURRENT_BOARD
		, NULL AS FORMER_BOARD
		, NULL AS SCHOOL_UNIT_CLASS_YEAR

	 -- , count(*) as num_unit_email_clicks_last365
    
  FROM BBCRM_PROD_RPT_BBDW.BBDW.VCU_V_QUERY_COMMUNICATIONSHISTORY comm
  left join DARanalytics.ref.school_unit_info sui on sui.unit_name = comm.site
 where comm.response in ('E-mail clicked','eclick')
   and comm.channel = 'Email'
   and datediff(day,comm.datesent,getdate()) <= 365
 group by constituentdimid
		, sui.unit_id
		, sui.unit_name


	UNION ALL

		/* Treat 'Honors Program-Graduates' as ALUMNI of the honors college count N=6.5k Time = 1sec */
				SELECT CONSTITUENTDIMID		as constituent_dim_id
				     , 240					as unit_id 
                     , 'Honors College'		as unit_name 
				     , 'Alumni' AS REL_TYPE
				     , MAX(1)   AS IS_LEADER
				     , NULL AS PA_EARLIEST_CLASS_YR
				     , NULL AS PA_MOST_RECENT_CLASS_YR
				     , NULL AS CURRENT_BOARD
				     , NULL AS FORMER_BOARD
				     , max(year(dateadd(month,6,ADDEDDATE)))	 AS unit_class_year

				  FROM BBCRM_PROD_RPT_BBDW.BBDW.DIM_EDUCATIONALINVOLVEMENT
				 WHERE EDUCATIONALINVOLVEMENTNAME ='Honors Program-Graduates'
			  GROUP BY CONSTITUENTDIMID
					 , CONSTITUENTSYSTEMID



		) BASE1

		GROUP BY
			BASE1.constituent_dim_id,
			BASE1.unit_id
			--BASE1.SCHOOL_UNIT

		) base  --end of base to get subset of prospect/unit relationships.  If they aren't in here they won't be in the final table since its all left joins

	--JOIN BBCRM_PROD_RPT_BBDW.BBDW.DIM_CONSTITUENT b ON base.constituent_id = b.constituentdimid
	JOIN DARanalytics.datamart.constituent_level cl ON base.constituent_dim_id = cl.constituent_dim_id

	/* bring in donor_category_unit but leave other giving in view*/
	left join DARanalytics.datamart.gvg_revenue_history_summary_hh_unit gvg_unit_hh on gvg_unit_hh.household_dim_id = cl.household_id
																				   and gvg_unit_hh.unit_id = base.unit_id

	/* bring in VCU giving*/
	left join DARanalytics.datamart.gvg_revenue_history_summary_hh gvg_vcu on gvg_vcu.household_dim_id = cl.household_id
																		  

	/* bring in Gordon's Contactable and Solicitable Flags/Fields */
	left join DARanalytics.ref.constituent_VCU_contact_solicitable_unit cs on cs.constituent_system_id = cl.constituent_system_id
																		  and cs.unit_id = base.unit_id

	/* bring in Gordon's Contactable and Solicitable Flags/Fields for VCU to use in logic of solicitable at the unit level */
	left join DARanalytics.ref.constituent_VCU_contact_solicitable cs_vcu on cs_vcu.constituent_system_id = cl.constituent_system_id
	
	/* TEAM MEMBERSHIP N=3k Time=0secs*/
	LEFT JOIN (

SELECT t.constituent_dim_id
	 , t.unit_id
     , max(case when t.FUNDRAISERROLECODE = 'Team Member' then 1 else 0 end) as flag_unit_managed_team_current  --people can be both team member and team member former so there is that
	 , max(case when t.FUNDRAISERROLECODE like '%stewardship%' then 1 else 0 end) as flag_unit_managed_stewardship_current
	 , max(case when t.FUNDRAISERROLECODE like '%discovery%' then 1 else 0 end) as flag_unit_managed_discovery_current
	 , max(case when t.FUNDRAISERROLECODE like '%engagement%' then 1 else 0 end) as flag_unit_managed_engagement_current
	 , max(case when t.FUNDRAISERROLECODE like '%alumni%' then 1 else 0 end) as flag_unit_managed_alumni_relations_current
     , sum(case when t.FUNDRAISERROLECODE = 'Team Member' then 1 else 0 end
		+ case when t.FUNDRAISERROLECODE like '%stewardship%' then 1 else 0 end 
		+ case when t.FUNDRAISERROLECODE like '%discovery%' then 1 else 0 end
		+ case when t.FUNDRAISERROLECODE like '%engagement%' then 1 else 0 end
		+ case when t.FUNDRAISERROLECODE like '%alumni%' then 1 else 0 end) as pm_num_unit_managed_types
  
  FROM (
		SELECT vpt.PROSPECTDIMID		as constituent_dim_id
			 , vpt.FUNDRAISERROLECODE
			 , goi.unit_id
			 , goi.unit_name
			 , case when NULLIF(MAX(COALESCE(EndDate,'9999-12-31')),'9999-12-31') is null then 1 else 0 end as prospectteam_current
		--   , max(STARTDATE) as min_startdate
		--   , max(ENDDATE) as max_enddate

		  FROM BBCRM_PROD_RPT_BBDW.BBDW.VCU_DIM_PROSPECTTEAM vpt
     left join DARanalytics.ref.gift_officer_info goi on goi.officer_system_id = vpt.FUNDRAISERSYSTEMID
												   and goi.position_order_desc = 1    --latest position    
		 WHERE vpt.FUNDRAISERROLECODE <> 'Team Member - Former'   --Gets rid of situations where someone is both team member and team member - former
	  GROUP BY vpt.prospectdimid, goi.unit_id, goi.unit_name, vpt.fundraiserrolecode
   -- ORDER BY fundraiserrolecode --prospectteam_current desc
	  ) t

  where t.prospectteam_current = 1
  group by t.constituent_dim_id, t.unit_id, t.unit_name
 -- order by pm_num_unit_managed_types desc

	) pt ON pt.constituent_dim_id	= base.constituent_dim_id
	    AND pt.unit_id				= base.unit_id


/* Donor Summary Giving  N=360k Time=3mins 0secs*/
	LEFT JOIN ( 
			SELECT g.CONSTITUENTDIMID		as constituent_id
	             , sui.unit_id
	             , sui.unit_name
				 /* lifetime giving */
				 , max(case when g.summarytypeid = 1 then isnull(g.lifetime_total,0) else 0 end) AS gvg_unit_life_cash  		/* pp, gi, mc */
				 , max(case when g.summarytypeid = 2 then isnull(g.lifetime_total,0) else 0 end) AS gvg_unit_life_cash_recog 	/* pp, gi, mc */
				 , max(case when g.summarytypeid = 3 then isnull(g.lifetime_total,0) else 0 end) AS gvg_unit_life_ngp			/* pl, gi, mc */
				 , max(case when g.summarytypeid = 4 then isnull(g.lifetime_total,0) else 0 end) AS gvg_unit_life_ngp_recog		/* pl, gi, mc */
				 , max(case when g.summarytypeid = 2 then isnull(g.lifetime_count,0) else 0 end) AS gvg_unit_life_gift_count   --cash recog

				 /* gift timing fields */
				 , max(case when g.summarytypeid = 2 then convert(date,g.lastgiftdate) else NULL end) AS gvg_unit_latest_cash_recog  --cash recog
				 , max(case when g.summarytypeid = 4 then convert(date,g.lastgiftdate) else NULL end) AS gvg_unit_latest_ngp_recog   --ngp recog

				 /* total cash in past few years */
				 , max(case when g.summarytypeid = 2 then ISNULL(g.currentfy_total,0) else 0 end)	AS gvg_unit_tminus0_cash_recog   --cash recog
				 , max(case when g.summarytypeid = 2 then ISNULL(g.onefyago_total,0) else 0 end)	AS gvg_unit_tminus1_cash_recog   --cash recog
				 , max(case when g.summarytypeid = 2 then ISNULL(g.twofyago_total,0) else 0 end)	AS gvg_unit_tminus2_cash_recog   --cash recog
				 , max(case when g.summarytypeid = 2 then ISNULL(g.threefyago_total,0) else 0 end)	AS gvg_unit_tminus3_cash_recog   --cash recog
				 , max(case when g.summarytypeid = 2 then ISNULL(g.fourfyago_total,0) else 0 end)	AS gvg_unit_tminus4_cash_recog   --cash recog
				 , max(case when g.summarytypeid = 2 then ISNULL(g.fivefyago_total,0) else 0 end)	AS gvg_unit_tminus5_cash_recog   --cash recog
	
	             

              FROM BBCRM_PROD_RPT_BBDW.BBDW.VCU_RPT_GIVINGSUMMARY g
              join DARanalytics.ref.school_unit_info sui on sui.report_code1_id = g.REPORTCODE1ID  --for unit report we only care about the units and not the higher summaries
             WHERE summarytypeid in (1   -- cash                       --this seems to catch all donors
			                        ,2   -- cash recognition
									,3   -- ngp
									,4)  -- ngp_recog  
               and reportcode1id is not null
		  GROUP BY g.CONSTITUENTDIMID
			     , sui.unit_id
				 , sui.unit_name

				-- order by constituent_id, unit_id
	) g ON g.constituent_id	= base.constituent_dim_id
	   AND g.unit_id		= base.unit_id

	/*Educational Involvement*/
	LEFT JOIN (
			SELECT CONSTITUENTDIMID		AS constituent_dim_id
				 , CONSTITUENTSYSTEMID
				 , EDUCATIONALINVOLVEMENTTYPEDESCRIPTION
			  -- , EDUCATIONALINVOLVEMENTSYSTEMID
				 , case when educationalinvolvementtypedescription = 'Athletics' then '210'					
						when educationalinvolvementtypedescription = 'Library Student Worker' then '275'	
						when educationalinvolvementtypedescription = 'Rams in Recovery' then '145'			
						else NULL end as unit_id
			  FROM BBCRM_PROD_RPT_BBDW.BBDW.DIM_EDUCATIONALINVOLVEMENT
			 where educationalinvolvementtypedescription in ('Athletics', 'Library Student Worker','Rams in Recovery')
			 group by CONSTITUENTDIMID, CONSTITUENTSYSTEMID, EDUCATIONALINVOLVEMENTTYPEDESCRIPTION   -- EDUCATIONALINVOLVEMENTSYSTEMID  --, EDUCATIONALINVOLVEMENTNAME
		  -- order by educationalinvolvementtypedescription
		  ) ei on ei.constituent_dim_id = base.constituent_dim_id
		      and ei.unit_id = base.unit_id

/* RNL INTERESTS */
--so i dont have to repeatedly look this up
--SELECT [unit_id] ,[unit_name] FROM [DARanalytics].[ref].[school_unit_info] order by unit_name
--Written by Wren in August 2025.  Be nice, I'm new.  

	LEFT JOIN (
			select CONSTITUENTSYSTEMID, CONSTITUENTDIMID, unit_id from
		(			
					--just to make it easy to check unit_ids
					--SELECT [unit_id] ,[unit_name] FROM [DARanalytics].[ref].[school_unit_info] order by unit_name
					SELECT
						  fca.CONSTITUENTSYSTEMID ,dima.ATTRIBUTEVALUESYSTEMID ,fca.ATTRIBUTEVALUE, fca.constituentdimid, fca.ATTRIBUTESTARTDATE
							, 145 as unit_id --Student affairs
					  FROM [BBCRM_PROD_RPT_BBDW].[BBDW].[FACT_CONSTITUENTATTRIBUTE] as fca
					  left join	BBCRM_PROD_RPT_BBDW.bbdw.DIM_ATTRIBUTE as dima
					  on fca.ATTRIBUTEDIMID = dima.ATTRIBUTEDIMID
						where dima.ATTRIBUTEVALUESYSTEMID in ( '9DD1464C-5CD1-4909-BD71-01240E6812AE' ,
					 '520CE3E8-68C9-4422-A570-29D0F4FF1D02' ,  '82704EE0-D14C-4AF6-9A6D-C76DA28ABFE7' 
					 , '19D98271-4DE9-42F7-828C-1A38ED5A4217' , 'E1217CEB-18E5-4DD9-87EA-D788A76C9C59' ,
					 '1A5EB708-77F3-47C4-BFAF-D9997940D9BB' , 'D02BB97A-FFAA-4B5C-AAA1-281231719D3F' ,
					 '2780A0B3-A009-41BD-B839-ADCB86E59AD6' )

					UNION ALL
					SELECT
						  fca.CONSTITUENTSYSTEMID ,dima.ATTRIBUTEVALUESYSTEMID ,fca.ATTRIBUTEVALUE, fca.constituentdimid, fca.ATTRIBUTESTARTDATE
							, 160 as unit_id --university wide
					  FROM [BBCRM_PROD_RPT_BBDW].[BBDW].[FACT_CONSTITUENTATTRIBUTE] as fca
					  left join                BBCRM_PROD_RPT_BBDW.bbdw.DIM_ATTRIBUTE as dima
					  on fca.ATTRIBUTEDIMID = dima.ATTRIBUTEDIMID
						where dima.ATTRIBUTEVALUESYSTEMID in ( '61FA3ED3-B971-4001-A90A-961EB5688F87' ,  'FE81411B-A4BA-491C-9337-91DC95D53871' )

					UNION ALL
					SELECT
						  fca.CONSTITUENTSYSTEMID ,dima.ATTRIBUTEVALUESYSTEMID ,fca.ATTRIBUTEVALUE, fca.constituentdimid, fca.ATTRIBUTESTARTDATE
							, 205 as unit_id --arts
					  FROM [BBCRM_PROD_RPT_BBDW].[BBDW].[FACT_CONSTITUENTATTRIBUTE] as fca
					  left join                BBCRM_PROD_RPT_BBDW.bbdw.DIM_ATTRIBUTE as dima
					  on fca.ATTRIBUTEDIMID = dima.ATTRIBUTEDIMID
						where dima.ATTRIBUTEVALUESYSTEMID = 'DBA1A674-9E18-4C2C-BE37-03A034BCA0BF'

					UNION ALL
					SELECT
						  fca.CONSTITUENTSYSTEMID ,dima.ATTRIBUTEVALUESYSTEMID ,fca.ATTRIBUTEVALUE, fca.constituentdimid, fca.ATTRIBUTESTARTDATE
							, 210 as unit_id --athletics
					  FROM [BBCRM_PROD_RPT_BBDW].[BBDW].[FACT_CONSTITUENTATTRIBUTE] as fca
					  left join                BBCRM_PROD_RPT_BBDW.bbdw.DIM_ATTRIBUTE as dima
					  on fca.ATTRIBUTEDIMID = dima.ATTRIBUTEDIMID
						where dima.ATTRIBUTEVALUESYSTEMID = '3E109C73-7415-43E6-9DFE-660B1DE008F2'

					UNION ALL
					SELECT
						  fca.CONSTITUENTSYSTEMID ,dima.ATTRIBUTEVALUESYSTEMID ,fca.ATTRIBUTEVALUE, fca.constituentdimid, fca.ATTRIBUTESTARTDATE
							, 220 as unit_id --education
					  FROM [BBCRM_PROD_RPT_BBDW].[BBDW].[FACT_CONSTITUENTATTRIBUTE] as fca
					  left join                BBCRM_PROD_RPT_BBDW.bbdw.DIM_ATTRIBUTE as dima
					  on fca.ATTRIBUTEDIMID = dima.ATTRIBUTEDIMID
						where dima.ATTRIBUTEVALUESYSTEMID in ( 'C754D54E-8CE4-44F2-A65B-7FC48111BCFE' ,
					 'FD38BBCF-4CF1-4417-8D2A-5E7B9C03DAD8' )

					UNION ALL
					SELECT
						  fca.CONSTITUENTSYSTEMID ,dima.ATTRIBUTEVALUESYSTEMID ,fca.ATTRIBUTEVALUE, fca.constituentdimid, fca.ATTRIBUTESTARTDATE
							, 260 as unit_id --life sciences
					  FROM [BBCRM_PROD_RPT_BBDW].[BBDW].[FACT_CONSTITUENTATTRIBUTE] as fca
					  left join                BBCRM_PROD_RPT_BBDW.bbdw.DIM_ATTRIBUTE as dima
					  on fca.ATTRIBUTEDIMID = dima.ATTRIBUTEDIMID
						where dima.ATTRIBUTEVALUESYSTEMID = '1ECFDD86-0CB1-4356-B9A0-F38B4FC1ED61'

					UNION ALL
					SELECT
						  fca.CONSTITUENTSYSTEMID ,dima.ATTRIBUTEVALUESYSTEMID ,fca.ATTRIBUTEVALUE, fca.constituentdimid, fca.ATTRIBUTESTARTDATE
							, 265 as unit_id --social work
					  FROM [BBCRM_PROD_RPT_BBDW].[BBDW].[FACT_CONSTITUENTATTRIBUTE] as fca
					  left join                BBCRM_PROD_RPT_BBDW.bbdw.DIM_ATTRIBUTE as dima
					  on fca.ATTRIBUTEDIMID = dima.ATTRIBUTEDIMID
						where dima.ATTRIBUTEVALUESYSTEMID in ( 'C778E576-5BCC-4E6A-9393-5CD82C22D910' , 
						'BEF384D6-2BE5-443D-8F2F-083096F2534A' )

					UNION ALL
					SELECT
						  fca.CONSTITUENTSYSTEMID ,dima.ATTRIBUTEVALUESYSTEMID ,fca.ATTRIBUTEVALUE, fca.constituentdimid, fca.ATTRIBUTESTARTDATE
							, 280 as unit_id --wilder
					  FROM [BBCRM_PROD_RPT_BBDW].[BBDW].[FACT_CONSTITUENTATTRIBUTE] as fca
					  left join                BBCRM_PROD_RPT_BBDW.bbdw.DIM_ATTRIBUTE as dima
					  on fca.ATTRIBUTEDIMID = dima.ATTRIBUTEDIMID
						where dima.ATTRIBUTEVALUESYSTEMID = 'C778E576-5BCC-4E6A-9393-5CD82C22D910'

					UNION ALL
					SELECT
						  fca.CONSTITUENTSYSTEMID ,dima.ATTRIBUTEVALUESYSTEMID ,fca.ATTRIBUTEVALUE, fca.constituentdimid, fca.ATTRIBUTESTARTDATE
							, 350 as unit_id --medicine
					  FROM [BBCRM_PROD_RPT_BBDW].[BBDW].[FACT_CONSTITUENTATTRIBUTE] as fca
					  left join                BBCRM_PROD_RPT_BBDW.bbdw.DIM_ATTRIBUTE as dima
					  on fca.ATTRIBUTEDIMID = dima.ATTRIBUTEDIMID
						where dima.ATTRIBUTEVALUESYSTEMID in ( 'BEF384D6-2BE5-443D-8F2F-083096F2534A' ,
						'3872209C-33F1-4EFF-85AC-311EA107788A' )

					UNION ALL
					SELECT
						  fca.CONSTITUENTSYSTEMID ,dima.ATTRIBUTEVALUESYSTEMID ,fca.ATTRIBUTEVALUE, fca.constituentdimid, fca.ATTRIBUTESTARTDATE
							, 360 as unit_id --ORI
					  FROM [BBCRM_PROD_RPT_BBDW].[BBDW].[FACT_CONSTITUENTATTRIBUTE] as fca
					  left join                BBCRM_PROD_RPT_BBDW.bbdw.DIM_ATTRIBUTE as dima
					  on fca.ATTRIBUTEDIMID = dima.ATTRIBUTEDIMID
						where dima.ATTRIBUTEVALUESYSTEMID = 'ADF36527-A80B-45B2-BEC5-09DCF4AE2479'

					UNION ALL
					SELECT
						  fca.CONSTITUENTSYSTEMID ,dima.ATTRIBUTEVALUESYSTEMID ,fca.ATTRIBUTEVALUE, fca.constituentdimid, fca.ATTRIBUTESTARTDATE
							, 400 as unit_id --vcu health 
					  FROM [BBCRM_PROD_RPT_BBDW].[BBDW].[FACT_CONSTITUENTATTRIBUTE] as fca
					  left join                BBCRM_PROD_RPT_BBDW.bbdw.DIM_ATTRIBUTE as dima
					  on fca.ATTRIBUTEDIMID = dima.ATTRIBUTEDIMID
						where dima.ATTRIBUTEVALUESYSTEMID in ( 'E97F4B8E-9997-428B-9B57-5042BF6E8C7C' ,
						 '3872209C-33F1-4EFF-85AC-311EA107788A' )

					UNION ALL
					SELECT
						  fca.CONSTITUENTSYSTEMID ,dima.ATTRIBUTEVALUESYSTEMID ,fca.ATTRIBUTEVALUE, fca.constituentdimid, fca.ATTRIBUTESTARTDATE
							, 405 as unit_id --massey 
					  FROM [BBCRM_PROD_RPT_BBDW].[BBDW].[FACT_CONSTITUENTATTRIBUTE] as fca
					  left join	BBCRM_PROD_RPT_BBDW.bbdw.DIM_ATTRIBUTE as dima
  						on fca.ATTRIBUTEDIMID = dima.ATTRIBUTEDIMID
					  where dima.ATTRIBUTEVALUESYSTEMID = '3872209C-33F1-4EFF-85AC-311EA107788A'

		) as t
		WHERE datediff(day,t.ATTRIBUTESTARTDATE,getdate()) < 1095 		--3 years rolling  2 years = 730
		GROUP BY CONSTITUENTSYSTEMID, CONSTITUENTDIMID, unit_id

)	rnl_interests
on rnl_interests.CONSTITUENTDIMID = base.constituent_dim_id
and rnl_interests.unit_id = base.unit_id

		/* BOARDS and COMMITTEES N=1.5k Time=1secs*/  

	LEFT JOIN (
	SELECT constituent_dim_id
				 , sui.unit_id
				 , sui.unit_name
				 , count(*) as num_active_unit_boardsNcommittees
				-- , max(start_date) as latest_board_start_date
         , 1 as flag_unit_committee_member_current
		 , max(case when board_description like '%board%' then 1 else 0 end)	 as flag_unit_board_member_current
		 , max(isnull(start_date,'1959-12-31')) as latest_unit_committee_start_date
		 , min(isnull(start_date,'1959-12-31')) as earliest_unit_committee_start_date
		 , max(case when board_description like '%board%' then isnull(start_date,'1959-12-31') else null end) as latest_unit_board_start_date
		 , min(case when board_description like '%board%' then isnull(start_date,'1959-12-31') else null end) as earliest_unit_board_start_date
 		 , max(case when rownum = 1 then board_description + ' ' + '(' + convert(nvarchar(4),year(isnull(start_date,'1959-12-31'))) + ')' else null end)
     	  +max(case when rownum = 2 then isnull('; ' + board_description + ' (' + convert(nvarchar(4),year(isnull(start_date,'1959-12-31'))) + ')','') else '' end)
      	  +max(case when rownum = 3 then isnull('; ' + board_description + ' (' + convert(nvarchar(4),year(isnull(start_date,'1959-12-31'))) + ')','') else '' end) as latest_unit_committees_current

      	 , max(case when board_description like '%board%' and rownum = 1 then board_description + ' ' + '(' + convert(nvarchar(4),year(isnull(start_date,'1959-12-31'))) + ')' else null end)
      	  +max(case when board_description like '%board%' and rownum = 2 then isnull('; ' + board_description + ' (' + convert(nvarchar(4),year(isnull(start_date,'1959-12-31'))) + ')','') else '' end)
      	  +max(case when board_description like '%board%' and rownum = 3 then isnull('; ' + board_description + ' (' + convert(nvarchar(4),year(isnull(start_date,'1959-12-31'))) + ')','') else '' end) as latest_unit_boards_current

  FROM DARanalytics.tableau.committees_active_members cam
  left join DARanalytics.ref.committee_site_crosswalk csc on csc.committee_lookup_ID = cam.constituent_group_lookup_id
  left join DARanalytics.ref.school_unit_info sui on sui.site_dim_id = csc.site_dim_id
  where unit_id is not null
   group by cam.constituent_dim_id, sui.unit_id, sui.unit_name
 --order by num_active_boardsNcommittees desc, unit_id 


	--		SELECT constituent_dim_id
	--			 , sui.unit_id
	--			 , sui.unit_name
	--			 , count(*) as num_active_boardsNcommittees
	--			 , max(start_date) as latest_board_start_date
	--			-- , 1 as flag_on_boardsNcommittees
	--		/*,
	--		  ,[constituent_lookup_id]
	--		  , constituent_system_id
	--		  ,[bio_name]
	--		  ,[start_date]
	--		  ,[end_date]
	--		  ,[iscurrent]
	--		  ,[isprimary]
	--		  ,[bio_gender]
	--		  ,[bio_race_desc]
	--		  */
	  
 -- FROM DARanalytics.tableau.committees_active_members cam
 -- left join DARanalytics.ref.committee_site_crosswalk csc on csc.committee_lookup_ID = cam.constituent_group_lookup_id
 -- left join DARanalytics.ref.school_unit_info sui on sui.site_dim_id = csc.site_dim_id
 -- where unit_id is not null
 --  group by cam.constituent_dim_id, sui.unit_id, sui.unit_name
 ----order by num_active_boardsNcommittees desc, unit_id 
	) committees on committees.constituent_dim_id = base.constituent_dim_id
		    and committees.unit_id = base.unit_id


	/* PGI SUSPECT OR POSITIVE - NEED TO BREAK OUT PG STUFF FROM THE REST*/
	left join (
			SELECT constituent_dim_id
				 , constituent_system_id
				 , constituent_lookup_id
				 , bio_name
      --,pm_prospect_status
      --,pm_prospect_status_hh
      --,PROSPECTGIVINGINTERESTSDIMID
      --,PROSPECTGIVINGINTERESTSSYSTEMID
				 , SITEDIMID  as site_dim_id
				 , pgi_unit_name	as unit_name
				 , pgi_unit_id		as unit_id
				 --, pgi_funding_type_code
				 --, pgi_inclination_level_code
				 --, pgi_comment
      --,pgi_include_spouse
      --,row_num
      --,row_num_pgsi
      --,start_date
      --,stop_date
      --,flag_all_of_vcu_not_prospect
      --,flag_unit_not_prospect
      --,pgi_fundraiser_unit_id
      --,pgi_fundraiser_unit_name

  FROM DARanalytics.tableau.unit_active_pgis

   where pgi_inclination_level_code in ('Suspect','Positive')
     and isnull(pm_prospect_status,'isNULL') in ('Assigned','Referred','Permanent Stewardship','isNULL')

group by constituent_dim_id
      , constituent_system_id
      , constituent_lookup_id
	  , bio_name
	  , pgi_unit_name
      , pgi_unit_id
	  , sitedimid
	 -- , pgi_inclination_level_code
	 -- , pm_prospect_status
	 ) pgi_good ON base.constituent_dim_id = pgi_good.constituent_dim_id
			   AND base.unit_id = pgi_good.unit_id



	/* PGI UNIT NOT A PROSPECT  NEED TO BREAK OUT PG STUFF FROM THE REST*/
	LEFT JOIN (
			SELECT constituent_dim_id
				 , constituent_system_id
				 , constituent_lookup_id
				 , bio_name
      --,pm_prospect_status
      --,pm_prospect_status_hh
      --,PROSPECTGIVINGINTERESTSDIMID
      --,PROSPECTGIVINGINTERESTSSYSTEMID
				 , SITEDIMID  as site_dim_id
				 , pgi_unit_name	as unit_name
				 , pgi_unit_id		as unit_id
				 --, pgi_funding_type_code
				 --, pgi_inclination_level_code
				 --, pgi_comment
      --,pgi_include_spouse
      --,row_num
      --,row_num_pgsi
      --,start_date
      --,stop_date
      --,flag_all_of_vcu_not_prospect
      --,flag_unit_not_prospect
      --,pgi_fundraiser_unit_id
      --,pgi_fundraiser_unit_name

  FROM DARanalytics.tableau.unit_active_pgis

  where 
       (pgi_inclination_level_code = 'Not a prospect-unit based only' and pm_prospect_status= 'Unassigned')
    or (pgi_inclination_level_code = 'Not a prospect-unit based only' and pm_prospect_status= 'Not a Prospect')
    or (pgi_inclination_level_code = 'Not a prospect-unit based only' and pm_prospect_status= 'Assigned' and pgi_unit_id<>pgi_fundraiser_unit_id)
    or (pgi_inclination_level_code = 'Not a prospect-unit based only' and pm_prospect_status= 'Assigned' and pgi_fundraiser_unit_id is NULL)
	or (pgi_inclination_level_code = 'Not a prospect-unit based only' and pm_prospect_status= 'Permanent Stewardship')


group by constituent_dim_id
      , constituent_system_id
      , constituent_lookup_id
	  , bio_name
	  , pgi_unit_name
      , pgi_unit_id
	  , sitedimid

			) pgi ON base.constituent_dim_id = pgi.constituent_dim_id
				 AND base.unit_id = pgi.unit_id

left join (  --this can be improved especially on the MPAR side  --gets 18.6k of 20k at the moment
SELECT t.CONSTITUENTDIMID
	 , coalesce(t.unit_id,'500')	 		as unit_id
	 , coalesce(t.unit_name,'Other') 		as unit_name
	 , 'FacultyStaff'						as REL_TYPE
	 , NULL AS IS_LEADER
	 , NULL AS PA_EARLIEST_CLASS_YR
	 , NULL AS PA_MOST_RECENT_CLASS_YR
	 , NULL AS CURRENT_BOARD
	 , NULL AS FORMER_BOARD
	 , NULL AS SCHOOL_UNIT_CLASS_YEAR

--, t.CONSTITUENTSYSTEMID
--, t.CONSTITUENTLOOKUPID
--, t.service_area_id_match	as service_area_system_id
 from (
		select fs2.CONSTITUENTDIMID, fs2.CONSTITUENTLOOKUPID, fs2.CONSTITUENTSYSTEMID, sui.unit_id, sui.unit_name, fs2.service_area_id_match
		from (  --select all the current employees and try to assign them to a unit and service area based on their jobdivision
			SELECT CONSTITUENTSYSTEMID
				 , CONSTITUENTDIMID
				 , CONSTITUENTLOOKUPID
	
				 , case when jobdivision = '' and employer = 'VCU Health System' then 400
						when jobdivision in ('','Retiree') then NULL
						when jobdivision = 'Institute for Contemporary Art' then 205			--Changing ICA to Arts
						when jobdivision = 'Life Sciences' then 245								--Changing Life Sciences to H&S
						when jobdivision = 'College of Humanities and Sciences' then 245
						when jobdivision = 'College of Humanit and Sciences' then 245
						when jobdivision = 'L D Wilder Sch of Govt & Pub Affrs' then 280	
						when jobdivision = 'Massey Cancer Center' then 405							
						when jobdivision = 'Massey Comprehensive Cancer Ctr' then 405							
						when jobdivision = 'Hospital - VCUMC' then 400							
						when jobdivision = 'Student Affairs (Vice Provost)' then 145
						when jobdivision = 'VCU Graduate School' then 235	
						when jobdivision = 'School of Denistry' then 310	
						when jobdivision = 'School of Public Health' then 470
						when jobdivision = 'Ambulatory Clinics - VCUMC' then 400	
						when jobdivision = 'Cardiology' then 400	
						when jobdivision = 'Division of Cardiology' then 400	
						when jobdivision = 'Hospital - CMH' then 400	
						when jobdivision = 'Hospital - CSBR' then 400
						when jobdivision = 'Hospital - CSMC' then 400	
						when jobdivision = 'Hospital - TAPP' then 400	
						when jobdivision = 'Long Term Care - CMH' then 400
						when jobdivision = 'Long Term Care - CSBR' then 400
						when jobdivision = 'MCVP Physicians' then 400
						when jobdivision = 'Physicians - CMHP' then 400
						when jobdivision = 'Physicians - MCVP' then 400
						when jobdivision = 'VCU School of Medicine - MCVP' then 350
						when jobdivision = 'VCUHS MCV Hospital' then 400
						when jobdivision = 'Athletics' then 210
						when jobdivision = 'Global Education Office' then 230
						when jobdivision = 'Graduate School' then 235
						when jobdivision = 'Honors College' then 240
						when jobdivision = 'Office Of The Provost' then 135
						when jobdivision = 'University College' then 150
						when jobdivision = 'VP For Health Sciences' then 810
		 				when jobdivision = sui.campaign_display_name then sui.unit_id

						when employer = 'VCU Health System' then 400
						else NULL end as unit_id_match

				,  case when jobdivision = '' then NULL
						when jobdivision = 'Massey Cancer Center'					then '2286B060-9561-409A-A1CC-60578F7E23DA'							
						when jobdivision = 'Massey Comprehensive Cancer Ctr' then '2286B060-9561-409A-A1CC-60578F7E23DA'							
						when jobdivision = 'Cardiology' then '945B52BD-4ADB-462D-AF8B-BA98D0C608C4'	
						when jobdivision = 'Division of Cardiology' then '945B52BD-4ADB-462D-AF8B-BA98D0C608C4'	
						else NULL end as service_area_id_match

			  ,JOBDIVISION
			  ,JOBDEPARTMENT
			  ,EMPLOYER

		  FROM BBCRM_PROD_RPT_BBDW.BBDW.VCU_RPT_FACULTYSTAFF_CURRENT fs2
		  left join DARanalytics.ref.school_unit_info sui on sui.campaign_display_name = fs2.jobdivision
		  where fs2.iscurrentemployment = 1

  ) fs2
  left join DARanalytics.ref.school_unit_info sui on sui.unit_id = fs2.unit_id_match
  where fs2.unit_id_match is not null

  ) t
	 group by t.CONSTITUENTSYSTEMID
			, t.CONSTITUENTDIMID
			, t.CONSTITUENTLOOKUPID
			, t.unit_id
			, t.unit_name
			, t.service_area_id_match
  ) fs on fs.CONSTITUENTDIMID = base.constituent_dim_id
      and fs.unit_id = base.unit_id


 /*Let's look at the new event data */
left join (
			SELECT constituent_system_id
				 , constituent_dim_id
				 , count(*) as num_events_unit_attended
				 , sum(case when start_date >= '2020-07-01' then 1 else 0 end) as num_events_campaign_unit_attended
				 , unit_id
				 , unit_name_short
			  FROM DARanalytics.tableau.event_registrants_unit
			 where attend_status = 'Attended' --not in ('Unknown','Cancelled','Did Not Attend')
			   and constituent_system_id is not null
			   and constituent_system_id <> '00000000-0000-0000-0000-000000000000'
			   and unit_id is not null
			 --and event_CSU_list is null
			 group by constituent_system_id
					, constituent_dim_id
					, unit_id
				    , unit_name_short
			-- order by num_events_attended desc
		) evnts on evnts.constituent_dim_id = base.constituent_dim_id
			   and evnts.unit_id = base.unit_id

/*Let's look at the new event data for past 3 rolling years */
left join (
			SELECT constituent_system_id
				 , constituent_dim_id
				 , count(*) as num_unit_events_life_attended
				 , sum(case when start_date between dateadd(year,-3,getdate()) and getdate() then 1 else 0 end) as num_unit_events_past3yrs_attended
				 , sum(case when year(dateadd(month,6,start_date)) = year(dateadd(month,6,getdate())) then 1 else 0 end) as num_unit_events_tminus0_attended
				 , unit_id
				 , unit_name_short

			  FROM DARanalytics.tableau.event_registrants_unit
			 where attend_status = 'Attended' --not in ('Unknown','Cancelled','Did Not Attend')
			   and constituent_system_id is not null
			   and constituent_system_id <> '00000000-0000-0000-0000-000000000000'
			   and unit_id is not null
			 group by constituent_system_id
					, constituent_dim_id
					, unit_id
				    , unit_name_short
			-- order by num_events_attended desc
		) evnts_past3yrs on evnts_past3yrs.constituent_dim_id = base.constituent_dim_id
						and evnts_past3yrs.unit_id = base.unit_id

/*Overall join tables */
left join DARanalytics.ref.school_unit_info sui on sui.unit_id = base.unit_id



/* where clause for entire select:  this excludes all constituents to exclude. i.e. test records */
--WHERE base.constituent_id NOT IN (SELECT constituent_id 
--                               FROM DARanalytics.ref.constituents_to_exclude
--							   WHERE flag_training_record = 1)

/*ADJUSTMENTS */
--dead people have no connectedness
UPDATE datamart.constituent_unit_level_temp  set
pm_unit_connectedness_score = (case when flag_living = 1 and bio_constituency_list in ('','Individual','Prospect','Individual, Prospect') then 1  --1 and not 0 like VCU_connectedness
									when flag_living = 1 then pm_unit_connectedness_score 
									else NULL end)


/* FOR UNITS WITHOUT ALUMS */
UPDATE datamart.constituent_unit_level_temp  set
 pm_unit_connectedness_desc = (case	when pm_unit_connectedness_score >= 14 then 'A Very Connected'		--was 15/10/5/2/1
									when pm_unit_connectedness_score >= 9  then 'B Connected'
									when pm_unit_connectedness_score >= 4  then 'C Somewhat Connected'
									when pm_unit_connectedness_score >= 2  then 'D Modestly Connected'
									when pm_unit_connectedness_score = 1 then 'E Weakly Connected'
									--when pm_unit_connectedness_score < 1  then  'F Not Connected'
									else NULL end)

/*FOR UNITS WITH ALUMNI */
UPDATE datamart.constituent_unit_level_temp  set
 pm_unit_connectedness_desc = (case	when pm_unit_connectedness_score >= 14 then 'A Very Connected'          --was 20/15/11/8/7
									when pm_unit_connectedness_score >= 9  then 'B Connected'
									when pm_unit_connectedness_score >= 8  then 'C Somewhat Connected'
									when pm_unit_connectedness_score >= 7  then 'D Modestly Connected'
									when pm_unit_connectedness_score between 1 and 6  then 'E Weakly Connected'
									else NULL end)
  WHERE flag_unit_has_alums = 1
  
  --moved flag to school_unit_info table to better control.
  --unit_id in (205	--Arts		
  --                 ,215	--Business
		--		   ,220	--Education
		--		   ,225	--Engineering
		--		   ,245	--Humanities
		--		   ,265	--Social Work
		--		   ,280	--Wilder
		--		   ,310	--Dentistry
		--		   ,315	--Health Professions
		--		   ,350	--SOM
		--		   ,355	--SON
		--		   ,365	--Pharmacy
		--		   --Any others???
		--		   )

/* CREATE UNIT NAME LIST - replaced by easier code in CL table - this is obsolete*/
UPDATE datamart.constituent_unit_level_temp  set
unit_connectedness_list = (
SELECT unit_name 
 FROM
    (
        SELECT DISTINCT ST2.constituent_system_id,
					--	ST2.constituent_lookup_id
            (
                SELECT ST1.unit_name + ' , ' AS [text()]
                FROM datamart.constituent_unit_level_temp  ST1
                WHERE ST1.constituent_system_id = ST2.constituent_system_id
                ORDER BY ST1.constituent_system_id
                FOR XML PATH (''), TYPE
            ).value('text()[1]','nvarchar(max)') unit_name
        FROM datamart.constituent_unit_level_temp ST2
     --where ST2.[constituent_lookup_id] = '8-10079996'
    ) UnitList
	WHERE UnitList.constituent_system_id = datamart.constituent_unit_level_temp.constituent_system_id
 )

 /*UPDATE COUNT OF UNIT CONNECTEDNESS*/
 UPDATE datamart.constituent_unit_level_temp  set
 unit_connectedness_num = (
							SELECT cnt
                              FROM
                          ( select count(*) as cnt
                                 , constituent_system_id
                              from datamart.constituent_unit_level_temp
							 where pm_unit_connectedness_score > 0
						  group by constituent_system_id
                          ) UnitNum
	WHERE UnitNum.constituent_system_id = datamart.constituent_unit_level_temp.constituent_system_id  
	)

 UPDATE datamart.constituent_unit_level_temp  set
 unit_connectedness_num_hh = (
							SELECT cnt
                              FROM
                          ( select count(distinct unit_id) as cnt
                                 , household_id
                              from datamart.constituent_unit_level_temp
							 where pm_unit_connectedness_score > 0
						  group by household_id
                          ) UnitNum
	WHERE UnitNum.household_id = datamart.constituent_unit_level_temp.household_id  
	)

 /*UPDATE campaign segment */
  --UPDATE datamart.constituent_unit_level_temp  set
  --pm_campaign_segment = case when eval


;
with hh_unit_CTE(uc_row_num, constituent_system_id, unit_id)
 as 
    ( select row_number() over (partition by household_id, unit_id order by flag_living desc, flag_exclude_call_list_VCU, pm_unit_connectedness_score desc, flag_is_primary_hh_member desc, constituent_dim_id) as uc_row_num
		 --  , household_id
		   , constituent_system_id
		   , unit_id

		from datamart.constituent_unit_level_temp

	)

UPDATE datamart.constituent_unit_level_temp
   SET flag_unit_primary_hh_member = case when hh.uc_row_num = 1 then 1 else 0 end
  from datamart.constituent_unit_level_temp cul
 inner join hh_unit_CTE hh
    on cul.constituent_system_id = hh.constituent_system_id
   and cul.unit_id = hh.unit_id

;
with hh_unit_CTE2(pm_unit_connectedness_score_hh, pm_unit_connectedness_desc_hh, household_id, unit_id)
 as 
(SELECT max(pm_unit_connectedness_score) as pm_unit_connectedness_score_hh
	  , min(pm_unit_connectedness_desc) as pm_unit_connectedness_desc_hh
	  , household_id
	  , unit_id

  FROM DARanalytics.datamart.constituent_unit_level_temp
  where flag_living = 1
  group by household_id, unit_id
  )

UPDATE datamart.constituent_unit_level_temp
   SET pm_unit_connectedness_score_hh = hh2.pm_unit_connectedness_score_hh
     , pm_unit_connectedness_desc_hh = hh2.pm_unit_connectedness_desc_hh
  from datamart.constituent_unit_level_temp cul
  left join hh_unit_CTE2 hh2
    on cul.household_id = hh2.household_id
   and cul.unit_id = hh2.unit_id

/* STEP 3. CREATE INDEXES */
  --once the null units are gone then we can add this unique PK
	ALTER TABLE DARanalytics.datamart.constituent_unit_level_temp
    ADD CONSTRAINT PK_Constituent_Unit_temp PRIMARY KEY (constituent_system_id,unit_id);

	CREATE NONCLUSTERED INDEX ix_unit_constituent_id
	ON DARanalytics.datamart.constituent_unit_level_temp (unit_id, constituent_dim_id);
	CREATE NONCLUSTERED INDEX ix_unit_system_constituent_id
	ON DARanalytics.datamart.constituent_unit_level_temp (unit_system_id, constituent_dim_id);
	CREATE NONCLUSTERED INDEX ix_constituent_id
	ON DARanalytics.datamart.constituent_unit_level_temp (constituent_dim_id);
	CREATE NONCLUSTERED INDEX ix_constituent_system_id
	ON DARanalytics.datamart.constituent_unit_level_temp (constituent_system_id);
	CREATE NONCLUSTERED INDEX ix_household_id
	ON DARanalytics.datamart.constituent_unit_level_temp (household_id);
	CREATE NONCLUSTERED INDEX ix_school_unit
	ON DARanalytics.datamart.constituent_unit_level_temp (unit_name);
	CREATE NONCLUSTERED INDEX ix_school_unit_short
	ON DARanalytics.datamart.constituent_unit_level_temp (unit_name_short);
	CREATE NONCLUSTERED INDEX ix_unit_id
	ON DARanalytics.datamart.constituent_unit_level_temp (unit_id);
	CREATE NONCLUSTERED INDEX ix_unit_system_id
	ON DARanalytics.datamart.constituent_unit_level_temp (unit_system_id);

	--RECOMMENDED BY SSMS
	CREATE NONCLUSTERED INDEX ix_hh_unitname_unitprimarymember
	ON DARanalytics.datamart.constituent_unit_level_temp (household_system_id,unit_name_short,flag_unit_primary_hh_member)
	INCLUDE (constituent_lookup_id);

	CREATE NONCLUSTERED INDEX ix_constituent_lookup_id
	ON DARanalytics.datamart.constituent_unit_level_temp (constituent_lookup_id) 
	INCLUDE (household_id, unit_name_campaign);

	--RECOMMENDED BY SOLARWINDS
	CREATE NONCLUSTERED INDEX ix_has_alums_id
	ON DARanalytics.datamart.constituent_unit_level_temp (flag_unit_has_alums)
	INCLUDE (pm_unit_connectedness_score);

	CREATE NONCLUSTERED INDEX ix_has_flag_unit_AG
	ON DARanalytics.datamart.constituent_unit_level_temp (flag_unit_AG_wAthletics,pm_unit_connectedness_score,pm_unit_connectedness_desc)
	INCLUDE (bio_birthday_next,bio_age,affil_preferred_class,unit_name,flag_unit_AG_wMPAR,flag_unit_alum);

	CREATE NONCLUSTERED INDEX ix_has_flag_unit_AG_wMPAR
	ON DARanalytics.datamart.constituent_unit_level_temp (flag_unit_AG_wMPAR,flag_unit_annual_giving,pm_unit_connectedness_score,pm_unit_connectedness_desc)
	INCLUDE (bio_birthday_next,bio_age,affil_preferred_class,unit_name,flag_unit_alum);

	CREATE NONCLUSTERED INDEX ix_has_flag_unit_AG_wMPAR2
	ON DARanalytics.datamart.constituent_unit_level_temp (flag_unit_AG_wMPAR,flag_unit_pgi_not_unit_prospect,pm_unit_connectedness_score,pm_unit_connectedness_desc) 
	INCLUDE (unit_name,unit_name_short,unit_system_id,flag_unit_alum);

	CREATE NONCLUSTERED INDEX ix_has_flag_unit_AG_wMPAR3
	ON DARanalytics.datamart.constituent_unit_level_temp (flag_unit_AG_wMPAR,flag_unit_pgi_not_unit_prospect,pm_unit_connectedness_score,pm_unit_connectedness_desc)
	INCLUDE (unit_name,flag_unit_alum);

	CREATE NONCLUSTERED INDEX ix_has_flag_unit_annual_giving
	ON DARanalytics.datamart.constituent_unit_level_temp (flag_unit_annual_giving,flag_unit_pgi_not_unit_prospect,pm_unit_connectedness_score,pm_unit_connectedness_desc)
	INCLUDE (unit_name,flag_unit_alum);

	CREATE NONCLUSTERED INDEX ix_flag_unit_philanthropic
	ON DARanalytics.datamart.constituent_unit_level_temp (flag_unit_philanthropic,flag_unit_pgi_not_unit_prospect,pm_unit_connectedness_score,pm_unit_connectedness_desc)
	INCLUDE (unit_name,flag_unit_alum);

	CREATE NONCLUSTERED INDEX ix_flag_unit_connectedness
	ON DARanalytics.datamart.constituent_unit_level_temp (pm_unit_connectedness_score,pm_unit_connectedness_desc)
	INCLUDE (unit_name,flag_unit_alum);

	CREATE NONCLUSTERED INDEX ix_has_flag_unit_has_alums
	ON DARanalytics.datamart.constituent_unit_level_temp (flag_unit_has_alums)
	INCLUDE (pm_unit_connectedness_score);




--CHECK IF TABLE IS NOT EMPTY or REDUCED
select  @rowsLoaded = count(*) from datamart.constituent_unit_level_temp

if @rowsLoaded >= 500000 
BEGIN
   IF  EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'datamart.constituent_unit_level') AND type in (N'U'))
				DROP TABLE datamart.constituent_unit_level
	
	exec sp_rename 'datamart.constituent_unit_level_temp', 'constituent_unit_level'
	select @errorMessage = 'Succesful overwrite of table ' + @destTable
	--exec [DARanalytics].[dbo].[sp_logTableLoad] @destTable, N'finish', @startTime, @errorMessage, @rowsLoaded;
END


ELSE
BEGIN
	select @errorMessage = 'constituent_unit_level_temp seems off - go investigate: '
	--exec [DARanalytics].[dbo].[sp_logTableLoad] @destTable, N'finish', @startTime, @errorMessage, @rowsLoaded;
END

  	--rename the PK so the next time it is run the temp table won't have the same name and bomb.
	EXEC sp_rename N'datamart.PK_Constituent_Unit_temp', N'PK_Constituent_Unit'

END
GO

