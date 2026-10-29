USE [DARanalytics]
GO

/****** Object:  StoredProcedure [dbo].[uspBuildConstituentOfficerLevelTable]    Script Date: 10/29/2026 10:27:44 AM ******/
SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO









CREATE PROCEDURE [dbo].[uspBuildConstituentOfficerLevelTable] 
AS BEGIN
/* 
Constituent-Officer Data Set
Created by Gary Thompson [GAT] on 3/9/2023
*/

/************************************************* OVERVIEW **********************************************************
This table is a repository of most of the measures used by DAR Analytics in its
standard reporting and analyses to document constituent relationships with particular officers. 
Variables have been given descriptive names, but for more information about each variable and its calculation,
consult .....

Any variable with suffix of "_hh" means that the variable is aggregated at the household level
and both members of the household will have the same value.

NOTE: 
All changes to this table should be vetted through 
the Data Architect of DAR
**************************************************************************************************************************/

/************************************************* CHANGE LOG **********************************************************
09.15.26 -GAT added mov_ofcr_earliest_pending_interaction_date, mov_ofcr_latest_pending_interaction_date to help with pending interaction calculations
09.04.26 -GAT added flag_ofcr_has_pending_plan_interaction
09.01.26 -GAT added flag_ofcr_has_pending_interaction
09.01.26 -GAT Added flag_is_principal_gift_prospect - moved this code creation from CL to COL as officer information is needed and only linked here.  Then brought into CL from here
08.04.26 -GAT Added in officer_latest_slotting_code, officer_latest_slotting_title, officer_latest_slotting_title_simplified
07.13.26 -GAT added mov_ofcr_latest_referral_system_id for the OCAE referral needs
05.15.26 -GAT elimated some test records from IS,PD managing people
04.03.26 -GAT reversed the managing stint list so that the most recent from date is first and not last.  
04.03.26 -GAT fixed the handling of different assignments to better account for when an officer is assigned more than one role.  
03.30.26 -GAT changed household_lookup_id to be 100 digits to account for weird 11 digit ids.
03.19.26 -GAT added officer_latest_date_from and officer_latest_date_to to find assignments that have bad assigned to dates.
			  added officer_latest_date_from_by_site to allow for looking for assignments out of a current officers tenure at their latest site.  Handles different jobs at same site.
03.11.26 -GAT Added Development staff into the mix but removed them from any 'managed' fields
03.05.26 -GAT Added Foundation manager fields to a number of places.
12.17.25 -GAT Added first_interaction_after_referral_date, first_DM_assignment_after_referral_date, first_PMTM_assignment_after_referral_date
12.01.25 -GAT added flag_currently_managed_by_vp
10.24.25 -GAT Added flag_ofcr_planned_gift_referral_recipient, flag_ofcr_planned_gift_referral_recipient_hh, flag_ofcr_planned_gift_referral_recipient_active and flag_ofcr_planned_gift_referral_recipient_active_hh
08.22.25 -GAT Added SSMS recommended index
07.16.25 -GAT Added in Past Other Managers: Z Team Member, Z Stewardship Manager, Z Discovery manager; 
	created pm_ofcr_prospect_manager_latest_date, pm_ofcr_team_member_latest_date, pm_ofcr_stewardship_manager_latest_date,	pm_ofcr_discovery_manager_latest_date
07.15.25 -GAT Added in Past Prospect Managers: pm_num_managing_stints, pm_managing_stint_list, status now includes X Prospect Manager	
07.09.25 -GAT Added in household_lookup_id
07.09.25 -GAT Tweaked latest_managed_date to be the latest date the officer managed the person. If still managing it should be today's date
05.01.25 -GAT Tweaks to referral_response_status
04.11.25 -GAT Version Update to include the updated Interactions table: officer_unit_constituent_interactions_all2
03.07.25 -GAT Added officer_latest_unit_name_short
02.20.24 -GAT Added flag_government_agency
11.11.24 -GAT Added officer_latest_unit_name_campaign (requested by Jeremy)
08.01.24 -GAT Updated PGI to unit_name from fundraiser_unit_name. Created referral_unit_id and referral_unit_name
07.31.24 -GAT Added referral_response_status to handle cancelled referrals.  Also changes to flag_unacted.
07.29.24 -GAT Removed being managed from the code determining if a referral is unacted upon. Reimplemented and will change on the Aug 2 EOD
07.22.24 -GAT Modified the sig_i query to only use completed interactions
06.28.24 -GAT Added in plan information for latest cultivate interactions
05.30.24 -GAT Added mov_latest_interaction_sig_primary_cultivate & mov_latest_interaction_sig_secondary_cultivate
04.03.24 -GAT Added in some resiliency to the 'managed' code  -		 WHERE FUNDRAISERROLECODE not in ('External Relations Manager')
12.18.23 -GAT Added mov_ofcr_latest_referral_receipt_stop_date
05.19.23 -GAT Added in Referral fields
05.11.23 -GAT Fixed bug on interactions to correctly view discovery interactions.  Still using only current/latest job which makes some sense but maybe not in this table.
03.09.23 -GAT Version 1
**************************************************************************************************************************/

	declare 
		@filedatestring nchar(8),
		@destTable nvarchar(30),
		@startTime datetime,
		@rowsLoaded int,
		@errorMessage nvarchar(1000)
	
	set @startTime = getDate();
	set @errorMessage = N'';
	set @destTable = 'datamart.constituent_officer_level';

	select @filedatestring = convert(nchar(8), getDate(), 112)

	--exec [DARanalytics].[dbo].[sp_logTableLoad] @destTable, N'start', @startTime, N'NoFileSource';


/* STEP 1. DELETE TABLE, IF ALREADY EXISTS */

BEGIN
	IF  EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[datamart].[constituent_officer_level_temp]') AND type in (N'U'))
		DROP TABLE [datamart].[constituent_officer_level_temp]

CREATE TABLE [datamart].[constituent_officer_level_temp](
	[z_last_update] datetime NOT NULL,
	[constituent_dim_id] int NOT NULL,        
	[constituent_system_id] uniqueidentifier NOT NULL,
	[constituent_lookup_id] nvarchar(100) NULL,
	bio_lastcommafirstname nvarchar(155) NULL,
	flag_government_agency tinyint NOT NULL,
	household_system_id uniqueidentifier NOT NULL,
	household_lookup_id nvarchar(100) NOT NULL,				--changed from 10 to 100 when one showed up with 11 digits on 3/28/2026
	[household_id] int NOT NULL,
	[officer_dim_id] nvarchar(12) NOT NULL,
	[officer_system_id] uniqueidentifier NOT NULL,
	[officer_lookup_id] nvarchar(100) NULL,
	[officer_name] nvarchar(175) NOT NULL,
	officer_latest_unit_id nvarchar(3) NULL,
	officer_latest_unit_name nvarchar(100) NULL,
	officer_latest_unit_name_short nvarchar(100) NULL,
	officer_latest_unit_name_campaign nvarchar(100) NULL,
	officer_latest_job_level nvarchar(20) NULL,
	officer_latest_slotting_code nvarchar(5) NULL,
	officer_latest_slotting_title nvarchar(100) NULL,
	officer_latest_slotting_title_simplified nvarchar(100) NULL,
	officer_latest_avp nvarchar(50) NULL,
	officer_latest_date_from date NULL,
	officer_latest_date_to date NULL,
	officer_latest_date_from_by_site date NULL,
	flag_active_officer tinyint NOT NULL,
	flag_exclude_natalie tinyint NOT NULL,
--	[officer_name_abbrev] [nvarchar](62) NOT NULL,
	[flag_ofcr_contacted] tinyint NOT NULL,
--	[flag_ofcr_solicited] [int] NOT NULL,
--	[flag_ofcr_open_ready] [int] NOT NULL,
--	[flag_ofcr_open_submitted] [int] NOT NULL,
	flag_ofcr_referral_recipient tinyint NOT NULL,
	flag_ofcr_referral_recipient_hh tinyint NOT NULL,
	flag_ofcr_planned_gift_referral_recipient tinyint NOT NULL,
	flag_ofcr_planned_gift_referral_recipient_hh tinyint NOT NULL,
	flag_ofcr_planned_gift_referral_recipient_active tinyint NOT NULL,
	flag_ofcr_planned_gift_referral_recipient_active_hh tinyint NOT NULL,
	flag_ofcr_pgi_NAP tinyint NOT NULL,
	[flag_ofcr_currently_managed] tinyint NOT NULL,
	flag_ofcr_current_prospect_manager tinyint NOT NULL,
	flag_ofcr_current_team_member tinyint NOT NULL,
	flag_ofcr_current_stewardship_manager tinyint NOT NULL,
	flag_ofcr_current_discovery_manager tinyint NOT NULL,
	flag_ofcr_current_foundation_manager tinyint NOT NULL,
	flag_ofcr_current_development_staff tinyint NOT NULL,
	flag_ofcr_current_alumni_staff tinyint NOT NULL,
--	[flag_ofcr_currently_managed_lead] [int] NOT NULL,
	[flag_ofcr_ever_managed] tinyint NOT NULL,
	[flag_ofcr_managed_current_FY] tinyint NOT NULL,
	[flag_ofcr_managed_previous_FY] tinyint NOT NULL,

	flag_unacted_referral tinyint NULL,
    flag_unacted_referral_hh tinyint NULL,
	referral_response_status tinyint NULL,
	referral_response_status_hh tinyint NULL,
	referral_unit_id	nvarchar(3) NULL,
	referral_unit_name	nvarchar(250) NULL,

    [pm_ofcr_days_managed] [int] NULL,
	[pm_ofcr_earliest_manage_date] [date] NULL,
	[pm_ofcr_latest_manage_date] [date] NULL,
	pm_ofcr_current_prospect_manager_latest_date [date] NULL,
	pm_ofcr_current_team_member_latest_date [date] NULL,
	pm_ofcr_current_stewardship_manager_latest_date [date] NULL,
	pm_ofcr_current_discovery_manager_latest_date [date] NULL,
	pm_ofcr_current_foundation_manager_latest_date [date] NULL,
	pm_ofcr_current_development_staff_latest_date [date] NULL,
	pm_ofcr_prospect_manager_latest_date	[date] NULL,
	pm_ofcr_team_member_latest_date	[date] NULL,
	pm_ofcr_stewardship_manager_latest_date	[date] NULL,
	pm_ofcr_discovery_manager_latest_date	[date] NULL,
	pm_ofcr_foundation_manager_latest_date	[date] NULL,
	pm_ofcr_development_staff_latest_date	[date] NULL,

	pm_ofcr_manage_status   nvarchar (100) NULL,
	pm_num_managing_stints	tinyint NULL,
	pm_managing_stint_list	nvarchar(500) NULL,
	
	mov_num_interaction_sig_all [int] NULL,
	mov_num_interaction_sig_primary [int] NULL,
	mov_num_interaction_sig_participant [int] NULL,
	mov_num_interaction_sig_secondary [int] NULL,
	mov_num_interaction_discovery [int] NULL,

	mov_latest_interaction_sig_all [date] NULL,
	mov_latest_interaction_sig_primary [date] NULL,
	mov_latest_interaction_sig_participant [date] NULL,
	mov_latest_interaction_sig_secondary [date] NULL,
	mov_latest_interaction_discovery [date] NULL,

	mov_latest_interaction_sig_all_cultivate [date] NULL,
	mov_latest_interaction_sig_primary_cultivate [date] NULL,
	mov_latest_interaction_sig_participant_cultivate [date] NULL,
	mov_latest_interaction_sig_secondary_cultivate [date] NULL,
	mov_latest_interaction_sig_discovery_cultivate [date] NULL,

	mov_earliest_interaction_sig_all [date] NULL,
	mov_earliest_interaction_sig_primary [date] NULL,
	mov_earliest_interaction_sig_participant [date] NULL,
	mov_earliest_interaction_sig_secondary [date] NULL,
	mov_earliest_interaction_discovery [date] NULL,

	flag_interaction_sig_FY_current tinyint NOT NULL,
	flag_interaction_sig_FY_previous tinyint NOT NULL,
	mov_latest_interaction_sig_FY [int] NULL,

	--mov_latest_interaction_sig_primary_cultivate_chk  [date] NULL,
	--mov_latest_interaction_sig_secondary_cultivate_chk  [date] NULL,
	--mov_latest_interaction_sig_participant_cultivate  [date] NULL,
	--mov_latest_interaction_sig_discovery_cultivate  [date] NULL,

	mov_latest_interaction_plan_name_all_cultivate nvarchar(100) NULL,
	mov_latest_interaction_plan_name_primary_cultivate nvarchar(100) NULL,
	mov_latest_interaction_plan_name_participant_cultivate nvarchar(100) NULL,
	mov_latest_interaction_plan_name_secondary_cultivate nvarchar(100) NULL,

	mov_latest_interaction_plan_id_all_cultivate uniqueidentifier NULL,
	mov_latest_interaction_plan_id_primary_cultivate uniqueidentifier NULL,
	mov_latest_interaction_plan_id_participant_cultivate uniqueidentifier NULL,
	mov_latest_interaction_plan_id_secondary_cultivate	uniqueidentifier NULL,

	mov_ofcr_latest_referral_receipt [date] NULL,
	mov_ofcr_latest_referral_receipt_stop_date [date] NULL,
--	mov_ofcr_latest_referral_summary nvarchar(max) NULL,
--	mov_ofcr_latest_referral_type nvarchar(8) NULL,
--	mov_ofcr_latest_referral_enterdat date NULL,
--	mov_ofcr_latest_referral_referrer_id nvarchar(10) NULL,
--	mov_ofcr_latest_referral_referrer_name nvarchar(100) NULL,
--	[mov_ofcr_latest_referrer_date] [date] NULL,
	mov_ofcr_latest_referrer_name nvarchar(100) NULL,
	mov_ofcr_latest_referrer_id nvarchar(100) NULL,
	mov_ofcr_latest_referrer_unit_name nvarchar(100) NULL,
	mov_ofcr_latest_referrer_job_level nvarchar(20) NULL,
	mov_ofcr_latest_referral_type nvarchar(100) NULL,
    mov_ofcr_latest_referral_note1 nvarchar(MAX) NULL,
    mov_ofcr_latest_referral_note2 nvarchar(MAX) NULL,
    mov_ofcr_latest_referral_note3 nvarchar(MAX) NULL,
	mov_ofcr_latest_referral_system_id nvarchar(MAX) NULL,
	flag_latest_referral_active tinyint NOT NULL,
	flag_currently_managed_by_vp tinyint NOT NULL,
	first_interaction_after_referral_date date NULL,
    first_DM_assignment_after_referral_date date NULL,
    first_PMTM_assignment_after_referral_date date NULL,
	flag_is_principal_gift_prospect tinyint NULL,
	flag_ofcr_has_pending_interaction tinyint NULL,
	flag_ofcr_has_pending_plan_interaction tinyint NULL,
	mov_ofcr_earliest_pending_interaction_date date NULL,
	mov_ofcr_latest_pending_interaction_date date NULL
 
	

) --ON [PRIMARY]	

/* STEP 2. LOAD DATA INTO TABLE */
   INSERT INTO DARanalytics.datamart.constituent_officer_level_temp

	SELECT

	/* date loaded */
	--CONVERT(DATE,GETDATE()) AS z_last_update
	GETDATE() AS z_last_update

	/* ID variables */
	,base.constituent_dim_id
	,base.constituent_system_id
	,cl.constituent_lookup_id
	,cl.bio_lastcommafirstname
	,cl.flag_government_agency
	,cl.household_system_id
	,cl.household_lookup_id
	,cl.household_id
	,base.officer_dim_id
	,base.officer_system_id
	,cl_ofcr.constituent_lookup_id	as officer_lookup_id
--	,j.joint_id
	,coalesce(goi.officer_name,cl_ofcr.bio_lastcommafirstname) as officer_name  --use GOI name unless missing then use CL
	,goi.unit_id		 as officer_latest_unit_id
	,goi.unit_name		 as officer_latest_unit_name
	,goi.unit_name_short as officer_latest_unit_name_short
	,goi.unit_name_campaign	as officer_latest_unit_name_campaign
	,goi.job_level		 as officer_latest_job_level
	,goi.slotting_code	 as officer_latest_slotting_code
	,goi.slotting_title	 as officer_latest_slotting_title
	,goi.slotting_title_simplified	 as officer_latest_slotting_title_simplified
	,goi.avp_officer_manager as officer_latest_avp
	,goi.date_from		 as officer_latest_date_from
	,goi.date_to		 as officer_latest_date_to
	,goi.earliest_datefrom_by_site	as officer_latest_date_from_by_site
	,isnull(goi.flag_active_officer,0)	as flag_active_officer
	,isnull(goi.flag_exclude_natalie,0) as flag_exclude_natalie    --might need this to be 1 for people not in GOI
--	,cl_ofcr.preferred_name AS officer_name
	--,CONCAT(cl_ofcr.lastname,', ', cl_ofcr.firstname) AS officer_name
--	,CONCAT(cl_ofcr.lastname,'_',LEFT(ISNULL(cl_ofcr.nickname,cl_ofcr.firstname),1)) AS officer_name_abbrev

	,base.flag_ofcr_contacted
--	,base.flag_ofcr_solicited
--	,CASE WHEN latest_solicitid_ready_ofcr IS NOT NULL THEN 1 ELSE 0 END flag_ofcr_open_ready
--	,CASE WHEN latest_solicitid_sub_ofcr IS NOT NULL THEN 1 ELSE 0 END flag_ofcr_open_submitted
	,isnull(base.flag_ofcr_referral_recipient,0)				as flag_ofcr_referral_recipient
	,isnull(chol.flag_ofcr_referral_recipient_hh,0)				as flag_ofcr_referral_recipient_hh
	,isnull(base.flag_ofcr_planned_gift_referral_recipient,0)		as flag_ofcr_planned_gift_referral_recipient
	,isnull(chol.flag_ofcr_planned_gift_referral_recipient_hh,0)	as flag_ofcr_planned_gift_referral_recipient_hh
	,isnull(ref.flag_planned_gift_referral_active,0)				as flag_ofcr_planned_gift_referral_recipient_active
	,isnull(chol.flag_ofcr_planned_gift_referral_recipient_active_hh,0)	as flag_ofcr_planned_gift_referral_recipient_active_hh
	
	,base.flag_ofcr_pgi_NAP
	,base.flag_ofcr_currently_managed
	,base.flag_ofcr_current_prospect_manager
	,base.flag_ofcr_current_team_member
	,base.flag_ofcr_current_stewardship_manager
	,base.flag_ofcr_current_discovery_manager
	,base.flag_ofcr_current_foundation_manager
	,base.flag_ofcr_current_development_staff
	,base.flag_ofcr_current_alumni_staff
	,base.flag_ofcr_ever_managed
	,base.flag_ofcr_managed_current_FY
	,base.flag_ofcr_managed_previous_FY

	,CASE 
		  WHEN ref.latest_referral_date is not null					--been referred to officer
		   AND ref.latest_referral_date >= '2020-07-01'
	     --  AND (getdate()- ref.latest_referral_date) between 90 and 365					  --only interested in these dates
		   AND (CONVERT(DATE,sig_i.latest_interaction_sig_primary) >= ref.latest_referral_date      --substantive move since referral
		     OR CONVERT(DATE,sig_i.latest_interaction_sig_participant) >= ref.latest_referral_date  --could combine these 3 with the all but leaving them separate for now
		     OR CONVERT(DATE,sig_i.latest_interaction_sig_secondary) >= ref.latest_referral_date
			 OR CONVERT(DATE,sig_i.latest_interaction_discovery) >= ref.latest_referral_date
	      --   OR CONVERT(DATE,s.latest_solicit_date_all_ofcr) >= ref.latest_referral_date  --solicit since referral add this in later
		     OR ( isnull(ref.referral_stop_date,'2099-12-31') <= getdate()	--e only want PM, SM, and TM to count IF the referral is end dated OR fundraiser added a PGI-NAP
			   AND (base.flag_ofcr_current_prospect_manager = 1
				 OR base.flag_ofcr_current_team_member = 1
				 OR base.flag_ofcr_current_stewardship_manager = 1
				 OR base.flag_ofcr_current_foundation_manager = 1
				-- OR base.flag_ofcr_current_development_staff = 1		--not included as per Rachels instructions
				 OR base.flag_ofcr_pgi_NAP = 1
				   )
				)
			 --being DM doesn't count.
			 --currently on team  removed per Rachel on 7/29/24
			-- OR isnull(ref.referral_stop_date,'2099-12-31') <= getdate()					--end dated referral probably indicates assignment
			-- OR mng.latest_ofcr_manage_date >= ref.latest_referral_date                   --was added to team since referral  need to add
			--going to be other edge cases but this is a start
			   )
		  THEN 0   --Acted upon referrals
		--  WHEN ref.latest_referral_date >= '2020-07-01' and isnull(ref.referral_stop_date,'2099-12-31') <= getdate() then 1  --Cancelled Referrals
		  WHEN ref.latest_referral_date >= '2020-07-01'  then 1   --Unacted Referrals
		--  WHEN datediff(day,ref.latest_referral_date,getdate()) < 1050  then 1   --recent referral in last 3 years
		  ELSE NULL end as flag_unacted_referral  --Old pre-campaign referrals
	,  chol.flag_unacted_referral_hh as flag_unacted_referral_hh
	
		,CASE 
		  WHEN ref.latest_referral_date is not null					--been referred to officer
		   AND ref.latest_referral_date >= '2020-07-01'
	     --  AND (getdate()- ref.latest_referral_date) between 90 and 365					  --only interested in these dates
		   AND (CONVERT(DATE,sig_i.latest_interaction_sig_primary) >= ref.latest_referral_date      --substantive move since referral
		     OR CONVERT(DATE,sig_i.latest_interaction_sig_participant) >= ref.latest_referral_date
		     OR CONVERT(DATE,sig_i.latest_interaction_sig_secondary) >= ref.latest_referral_date
			 OR CONVERT(DATE,sig_i.latest_interaction_discovery) >= ref.latest_referral_date
	      --   OR CONVERT(DATE,s.latest_solicit_date_all_ofcr) >= ref.latest_referral_date  --solicit since referral add this in later
		     OR ( isnull(ref.referral_stop_date,'2099-12-31') <= getdate()	--e only want PM, SM, and TM to count IF the referral is end dated OR fundraiser added a PGI-NAP
			   AND (base.flag_ofcr_current_prospect_manager = 1
				 OR base.flag_ofcr_current_team_member = 1
				 OR base.flag_ofcr_current_stewardship_manager = 1
				 OR base.flag_ofcr_current_foundation_manager = 1
				-- OR base.flag_ofcr_current_development_staff = 1		--doesnt count
				 OR base.flag_ofcr_pgi_NAP = 1
				 OR base.latest_managed_date_notDM >= ref.latest_referral_date  --added 5/1/25 to account for changes in managing status
				   )
				)

			   )
		  THEN 0   --Acted upon referrals
		  WHEN ref.latest_referral_date >= '2020-07-01' and isnull(ref.referral_stop_date,'2099-12-31') <= getdate() then 1  --Cancelled Referrals
		  WHEN ref.latest_referral_date >= '2020-07-01'  then 2   --Unacted Referrals
		--  WHEN datediff(day,ref.latest_referral_date,getdate()) < 1050  then 1   --recent referral in last 3 years
		  ELSE 9 end as referral_response_status  --Old pre-campaign referrals
	,chol.referral_response_status_hh as referral_response_status_hh
	
	,ref.unit_id as referral_unit_id
	,ref.unit_name as referral_unit_name

	,base.days_managed					as pm_ofcr_days_managed
	,base.earliest_managed_date			as pm_ofcr_earliest_manage_date
	,base.latest_managed_date			as pm_ofcr_latest_manage_date
	,base.ofcr_current_prospect_manager_latest_date		as pm_ofcr_current_prospect_manager_latest_date
	,base.ofcr_current_team_member_latest_date			as pm_ofcr_current_team_member_latest_date	
	,base.ofcr_current_stewardship_manager_latest_date	as pm_ofcr_current_stewardship_manager_latest_date
	,base.ofcr_current_discovery_manager_latest_date	as pm_ofcr_current_discovery_manager_latest_date
	,base.ofcr_current_foundation_manager_latest_date	as pm_ofcr_current_foundation_manager_latest_date
	,base.ofcr_current_development_staff_latest_date	as pm_ofcr_current_development_staff_latest_date
	,base.ofcr_prospect_manager_latest_date				as pm_ofcr_prospect_manager_latest_date
	,base.ofcr_team_member_latest_date					as pm_ofcr_team_member_latest_date
	,base.ofcr_stewardship_manager_latest_date			as pm_ofcr_stewardship_manager_latest_date
	,base.ofcr_discovery_manager_latest_date			as pm_ofcr_discovery_manager_latest_date
	,base.ofcr_foundation_manager_latest_date			as pm_ofcr_foundation_manager_latest_date
	,base.ofcr_development_staff_latest_date			as pm_ofcr_development_staff_latest_date
	,base.officer_manage_status				as pm_ofcr_manage_status
	,base.num_managing_stints				as pm_num_managing_stints
	,base.managing_stint_list				as pm_managing_stint_list				
/*	
	,base.flag_ofcr_managed_2FY_ago

	,CASE WHEN isnull(m.num_moves_previousFY_ofcr_incl,0) > 0 THEN 1 ELSE 0 END flag_ofcr_previousFY_move_incl
	,CASE WHEN isnull(m.num_moves_previousFY_ofcr_excl,0) > 0 THEN 1 ELSE 0 END flag_ofcr_previousFY_move_excl
	,CASE WHEN isnull(m.num_moves_currentFY_ofcr_incl,0) > 0 THEN 1 ELSE 0 END flag_ofcr_currentFY_move_incl
	,CASE WHEN isnull(m.num_moves_currentFY_ofcr_excl,0) > 0 THEN 1 ELSE 0 END flag_ofcr_currentFY_move_excl

	,CASE WHEN isnull(m.number_of_visit_ofcr_previous_fy,0) > 0 THEN 1 ELSE 0 END flag_ofcr_previousFY_visit
	,CASE WHEN isnull(m.number_of_visit_ofcr_current_fy,0) > 0 THEN 1 ELSE 0 END flag_ofcr_currentFY_visit

	,base.flag_ofcr_in_watch_list
	--May still be problematic when joint_id changes over time
*/


--	,base.days_managed            AS pm_ofcr_days_managed
--	,mng.latest_ofcr_manage_date  AS pm_ofcr_latest_manage_date



	/* SIGNIFICANT moves by officer - with latest UNIT only  */
	 , ISNULL(sig_i.num_interaction_sig_all,0)			as mov_num_interaction_sig_all
	 , ISNULL(sig_i.num_interaction_sig_primary,0)		as mov_num_interaction_sig_primary
	 , ISNULL(sig_i.num_interaction_sig_participant,0)	as mov_num_interaction_sig_participant
	 , ISNULL(sig_i.num_interaction_sig_secondary,0)	as mov_num_interaction_sig_secondary
	 , ISNULL(sig_i.num_interaction_discovery,0)		as mov_num_interaction_discovery

	 , sig_i.latest_interaction_sig_all					as mov_latest_interaction_sig_all
	 , sig_i.latest_interaction_sig_primary				as mov_latest_interaction_sig_primary
	 , sig_i.latest_interaction_sig_participant			as mov_latest_interaction_sig_participant
	 , sig_i.latest_interaction_sig_secondary			as mov_latest_interaction_sig_secondary
	 , sig_i.latest_interaction_discovery				as mov_latest_interaction_discovery

	 , sig_i.latest_interaction_sig_all_cultivate		as mov_latest_interaction_sig_all_cultivate
	 , sig_i.latest_interaction_sig_primary_cultivate	as mov_latest_interaction_sig_primary_cultivate
	 , sig_i.latest_interaction_sig_participant_cultivate	as mov_latest_interaction_sig_participant_cultivate
	 , sig_i.latest_interaction_sig_secondary_cultivate	as mov_latest_interaction_sig_secondary_cultivate
	 , sig_i.latest_interaction_sig_discovery_cultivate	as mov_latest_interaction_sig_discovery_cultivate

	 , sig_i.earliest_interaction_sig_all				as mov_earliest_interaction_sig_all
	 , sig_i.earliest_interaction_sig_primary			as mov_earliest_interaction_sig_primary
	 , sig_i.earliest_interaction_sig_participant		as mov_earliest_interaction_sig_participant
	 , sig_i.earliest_interaction_sig_secondary			as mov_earliest_interaction_sig_secondary
	 , sig_i.earliest_interaction_discovery				as mov_earliest_interaction_discovery

	 , isnull(sig_i.flag_interaction_sig_FY_current,0)	as flag_interaction_sig_FY_current
	 , isnull(sig_i.flag_interaction_sig_FY_previous,0)	as flag_interaction_sig_FY_previous
	 , sig_i.latest_interaction_sig_FY					as mov_latest_interaction_sig_FY

	 --, sig_ic.latest_interaction_sig_primary_cultivate		as mov_latest_interaction_sig_primary_cultivate_chk
	 --, sig_ic.latest_interaction_sig_secondary_cultivate	as mov_latest_interaction_sig_secondary_cultivate_chk
	 --, sig_ic.latest_interaction_sig_participant_cultivate	as mov_latest_interaction_sig_participant_cultivate
	 --, sig_ic.latest_interaction_sig_discovery_cultivate	as mov_latest_interaction_sig_discovery_cultivate

	 , sig_ic.latest_interaction_plan_name_all_cultivate			as mov_latest_interaction_plan_name_all_cultivate
	 , sig_ic.latest_interaction_plan_name_primary_cultivate		as mov_latest_interaction_plan_name_primary_cultivate
	 , sig_ic.latest_interaction_plan_name_participant_cultivate	as mov_latest_interaction_plan_name_participant_cultivate
	 , sig_ic.latest_interaction_plan_name_secondary_cultivate		as mov_latest_interaction_plan_name_secondary_cultivate

	 , sig_ic.latest_interaction_plan_id_all_cultivate				as mov_latest_interaction_plan_id_all_cultivate
	 , sig_ic.latest_interaction_plan_id_primary_cultivate			as mov_latest_interaction_plan_id_primary_cultivate
	 , sig_ic.latest_interaction_plan_id_secondary_cultivate		as mov_latest_interaction_plan_id_secondary_cultivate	
	 , sig_ic.latest_interaction_plan_id_participant_cultivate		as mov_latest_interaction_plan_id_participant_cultivate

/*
	,ISNULL(m.number_of_moves_ofcr,0) AS mov_ofcr_number_of_moves
	,ISNULL(m.number_of_moves_ofcr_past2yrs,0) AS mov_ofcr_past2yrs_number_of_moves
	,ISNULL(m.number_of_attcontc_ofcr,0) AS mov_ofcr_number_of_attempted
	,ISNULL(m.number_of_visit_ofcr,0) AS mov_ofcr_number_of_visits
	,ISNULL(m.number_of_visit_ofcr_previous_fy,0) AS mov_ofcr_number_of_visits_previousFY
	,ISNULL(m.number_of_visit_ofcr_current_fy,0) AS mov_ofcr_number_of_visits_currentFY
	,ISNULL(m.num_moves_previousFY_ofcr_incl,0) AS mov_ofcr_previousFY_num_moves_incl
	,ISNULL(m.num_moves_previousFY_ofcr_excl,0) AS mov_ofcr_previousFY_num_moves_excl
	,ISNULL(m.num_moves_currentFY_ofcr_incl,0) AS mov_ofcr_currentFY_num_moves_incl
	,ISNULL(m.num_moves_currentFY_ofcr_excl,0) AS mov_ofcr_currentFY_num_moves_excl

	,m.latest_moveid_inc_ofcr AS mov_ofcr_latest_move_id_incl
	,CONVERT(DATE,m.latest_movedate_inc_ofcr) AS mov_ofcr_latest_date_incl
	,CONVERT(DATE,m2.latest_movedate_inc_ofcr) AS mov_ofcr_latest_date_any
	,m.latest_moveid_exc_ofcr AS mov_ofcr_latest_move_id_excl
	,CONVERT(DATE,m.latest_movedate_exc_ofcr) AS mov_ofcr_latest_date_excl
	,m.latest_moveid_visit_ofcr AS mov_ofcr_latest_move_id_visit
	,CONVERT(DATE,m.latest_movedate_visit_ofcr) AS mov_ofcr_latest_date_visit
	,m.latest_moveid_qualify_ofcr AS mov_ofcr_latest_move_id_qualify
	,CONVERT(DATE,m.latest_movedate_qualify_ofcr) AS mov_ofcr_latest_date_qualify

	,m.earliest_moveid_inc_ofcr AS mov_ofcr_earliest_move_id_incl
	,CONVERT(DATE,m.earliest_movedate_inc_ofcr) AS mov_ofcr_earliest_date_incl
	,m.earliest_moveid_exc_ofcr AS mov_ofcr_earliest_move_id_excl
	,CONVERT(DATE,m.earliest_movedate_exc_ofcr) AS mov_ofcr_earliest_date_excl

	,m.latest_moveid_droppros_ofcr AS mov_ofcr_move_id_droppros
	,REPLACE(REPLACE(REPLACE(m.latest_move_writeup_ofcr,CHAR(9),''),CHAR(10),''),CHAR(13),'') AS mov_ofcr_latest_writeup
*/
--	,ref.moveid as mov_ofcr_latest_referral_moveid
	,ref.latest_referral_date AS mov_ofcr_latest_referral_receipt  --may need to re-examine these to make sure pulling info from latest
	,ref.referral_stop_date	  AS mov_ofcr_latest_referral_receipt_stop_date  --may need to re-examine these to make sure pulling info from latest
--	,ref.latest_referral_summary as mov_ofcr_latest_referral_summary
--	,ref.latest_referral_type as mov_ofcr_latest_referral_type
--	,ref.latest_referral_enterdat as mov_ofcr_latest_referral_enterdat
	,ref.latest_referrer_name as mov_ofcr_latest_referral_referrer_name
	,ref.latest_referrer_system_id as mov_ofcr_latest_referral_referrer_id
	,ref.latest_referrer_unit_name as mov_ofcr_latest_referral_referrer_unit_name
	,ref.latest_referrer_job_level  as mov_ofcr_latest_referrer_job_level
	,ref.latest_referral_type		as mov_ofcr_latest_referral_type
    ,ref.latest_referral_note1		as mov_ofcr_latest_referral_note1
    ,ref.latest_referral_note2		as mov_ofcr_latest_referral_note2
    ,ref.latest_referral_note3		as mov_ofcr_latest_referral_note3
	,ref.latest_referral_system_id	as mov_ofcr_latest_referral_system_id
	,isnull(ref.flag_referral_active,0)		as flag_latest_referral_active
	,case when goi.job_level in ('SAVP','VP') and base.flag_ofcr_currently_managed = 1 then 1 else 0 end as flag_currently_managed_by_vp

	,refdates.first_interaction_after_referral_date
    ,refdates.first_DM_assignment_after_referral_date
    ,refdates.first_PMTM_assignment_after_referral_date

	--,cl.flag_is_principal_gift_prospect								--trying to get a better handle on what it means to be a principal gift prospect
	,case when cl.eval_capacity_rating between 9 and 15								--$1M and above
		   and (base.flag_ofcr_current_prospect_manager = 1							--any of the 4 main assignments
			 OR base.flag_ofcr_current_team_member = 1
			 OR base.flag_ofcr_current_stewardship_manager = 1
			 OR base.flag_ofcr_current_discovery_manager = 1
				)
		   and goi.unit_name not in ('DAR - Corporate and Foundation Relations', 'MCV Foundation')		--not Principal Gift Prospects
		   and goi.slotting_title_simplified is not null												--gets rid of PD, Charmica, Meg
		   and goi.slotting_title_simplified <> 'Not a Fundraiser'										--gets rid of Ann D, Josh Leidy etc...
		   then 1 else 0 end as flag_is_principal_gift_prospect

	,isnull(noncomp.flag_officer_has_pending_interaction,0)				as flag_ofcr_has_pending_interaction
	,isnull(noncomp.flag_officer_has_pending_plan_interaction,0)		as flag_ofcr_has_pending_plan_interaction
	,noncomp.mov_ofcr_earliest_pending_interaction_date
	,noncomp.mov_ofcr_latest_pending_interaction_date
/*	,ref2.latest_referrer_date AS mov_ofcr_latest_referrer_date
	,ref2.officer_id as mov_ofcr_latest_referrer_id
	,ref2.latest_referrer_name as mov_ofcr_latest_referrer_name


	

	/* solicitations (BY officer) */
	,s.latest_solicitid_all_ofcr AS sol_ofcr_latest_solictid
	,CONVERT(DATE,s.latest_solicit_date_all_ofcr) AS sol_ofcr_latest_date_all
	,s.latest_solicitid_ready_ofcr AS sol_ofcr_latest_solictid_ready
	,s.latest_solicitdat_ready_ofcr AS sol_ofcr_latest_date_ready
	,s.latest_solicitid_sub_ofcr AS sol_ofcr_latest_solictid_submit
	,CONVERT(DATE,s.latest_solicdat_sub_ofcr) AS sol_ofcr_latest_date_submit
	,s.latest_solicitid_closed_ofcr AS sol_ofcr_latest_solictid_closed
	,CONVERT(DATE,s.latest_solicdat_closed_ofcr) AS sol_ofcr_latest_date_closed
	,s.latest_solicitid_accepted_ofcr AS sol_ofcr_latest_solictid_accepted
	,CONVERT(DATE,s.latest_solicdat_accepted_ofcr) AS sol_ofcr_latest_date_accepted
	,REPLACE(REPLACE(REPLACE(s.latest_solicit_summary_ofcr,CHAR(9),''),CHAR(10),''),CHAR(13),'') AS sol_ofcr_latest_summary
	,ISNULL(s.life_total_asked_ofcr,0) AS sol_ofcr_life_total_ask
	,ISNULL(s.life_total_accepted_ofcr,0) AS sol_ofcr_life_total_accept
	,ISNULL(s.dfwd_total_asked_ofcr,0) AS sol_ofcr_dfwd_total_ask
	,ISNULL(s.dfwd_total_accepted_ofcr,0) AS sol_ofcr_dfwd_total_accept
	,ISNULL(s.past_five_total_asked_ofcr,0) AS sol_ofcr_past_5_total_ask
	,ISNULL(s.past_five_total_accepted_ofcr,0) AS sol_ofcr_past_5_total_accept
	,ISNULL(s.total_in_ready_ofcr,0) AS sol_ofcr_ready_total_ask
	,ISNULL(s.total_in_submitted_ofcr,0) AS sol_ofcr_submit_total_ask

	/* call lists */
	,ISNULL(cl.number_of_call_lists_ofcr,0) AS pm_ofcr_number_of_call_lists
	,CONVERT(DATE,cl.latest_call_list_date_ofcr) AS pm_ofcr_latest_call_list_date
    ,earliest_on_team        as pm_ofcr_earliest_on_team
    ,latest_on_team          as pm_ofcr_latest_on_team
	,goi.unit_id             as unit_id_current
	
	/* Engage fields*/
	,base.flag_ofcr_engage_household
*/

	FROM
	/* base connections --  All possible officer-constituent connections must have at least one record in Base for the ensuing left joins to connect to
		N=70k t=1s
	*/
	(
	SELECT
		 max(base1.constituent_dim_id)	as constituent_dim_id
		,base1.constituent_system_id
		,max(base1.officer_dim_id)		as officer_dim_id
		,base1.officer_system_id
		,MAX(CASE WHEN base1.rel_type = 'contact' THEN 1 ELSE 0 END) AS flag_ofcr_contacted
	--	,MAX(CASE WHEN rel_type = 'solicit' THEN 1 ELSE 0 END) AS flag_ofcr_solicited
		,MIN(base1.officer_manage_status_ordered) as officer_manage_status_ordered
		,substring(MIN(base1.officer_manage_status_ordered),4,LEN(MIN(base1.officer_manage_status_ordered))) as officer_manage_status
		,MAX(CASE WHEN base1.rel_type = 'managed' AND base1.officer_manage_status_ordered in ('1. Prospect Manager','2. Team Member','2. Stewardship Manager','2. Discovery Manager','2. Foundation Manager')   THEN 1 ELSE 0 END)		AS flag_ofcr_currently_managed
		,MAX(CASE WHEN base1.rel_type = 'managed' AND base1.officer_manage_status_ordered = '1. Prospect Manager' THEN 1 ELSE 0 END)			AS flag_ofcr_current_prospect_manager
		,MAX(CASE WHEN base1.rel_type = 'managed' AND base1.officer_manage_status_ordered = '2. Team Member' THEN 1 ELSE 0 END)					AS flag_ofcr_current_team_member
		,MAX(CASE WHEN base1.rel_type = 'managed' AND base1.officer_manage_status_ordered = '2. Stewardship Manager' THEN 1 ELSE 0 END)			AS flag_ofcr_current_stewardship_manager
		,MAX(CASE WHEN base1.rel_type = 'managed' AND base1.officer_manage_status_ordered = '2. Discovery Manager' THEN 1 ELSE 0 END)			AS flag_ofcr_current_discovery_manager
		,MAX(CASE WHEN base1.rel_type = 'managed' AND base1.officer_manage_status_ordered = '2. Foundation Manager' THEN 1 ELSE 0 END)			AS flag_ofcr_current_foundation_manager
		,MAX(CASE WHEN base1.rel_type = 'dev_staff' THEN 1 ELSE 0 END)			AS flag_ofcr_current_development_staff			--dev staff not considered a manager or the person ever being managed
		,MAX(CASE WHEN base1.rel_type = 'managed' AND base1.officer_manage_status_ordered = '2. Alumni Relations Staff' THEN 1 ELSE 0 END)		AS flag_ofcr_current_alumni_staff
		,MAX(CASE WHEN base1.rel_type = 'managed' AND base1.officer_manage_status_ordered in ('1. Prospect Manager','2. Team Member','2. Stewardship Manager','2. Discovery Manager','2. Foundation Manager'
																							 ,'3. X Prospect Manager','4. Z Team Member','4. Z Stewardship Manager','4. Z Discovery Manager','4. Z Foundation Manager')
																							 THEN 1 ELSE 0 END) AS flag_ofcr_ever_managed

		,SUM(CASE WHEN base1.rel_type = 'managed' AND base1.officer_manage_status_ordered in ('1. Prospect Manager','2. Team Member','2. Stewardship Manager','2. Discovery Manager','2. Foundation Manager') THEN base1.total_days_managed ELSE NULL END) AS days_managed
		,MAX(CASE WHEN base1.rel_type = 'managed' AND base1.managed_in_current_FY = 1 THEN 1 ELSE 0 END) AS flag_ofcr_managed_current_FY
		,MAX(CASE WHEN base1.rel_type = 'managed' AND base1.managed_in_previous_FY = 1 THEN 1 ELSE 0 END) AS flag_ofcr_managed_previous_FY
	--	,MAX(CASE WHEN rel_type = 'managed' AND managed_during_previous_2FY_ago = 1 THEN 1 ELSE 0 END) AS flag_ofcr_managed_2FY_ago

		,MIN(CASE WHEN base1.rel_type = 'managed' AND base1.officer_manage_status_ordered in ('1. Prospect Manager'		,'2. Team Member'	,'2. Stewardship Manager'	,'2. Discovery Manager'		,'2. Foundation Manager'
																							 ,'3. X Prospect Manager'	,'4. Z Team Member'	,'4. Z Stewardship Manager'	,'4. Z Discovery Manager'	,'4. Z Foundation Manager') THEN base1.earliest_managed_date ELSE NULL END) AS earliest_managed_date
		,MAX(CASE WHEN base1.rel_type = 'managed' AND base1.officer_manage_status_ordered in ('1. Prospect Manager'		,'2. Team Member'	,'2. Stewardship Manager'	,'2. Discovery Manager'		,'2. Foundation Manager'
																							 ,'3. X Prospect Manager'	,'4. Z Team Member'	,'4. Z Stewardship Manager'	,'4. Z Discovery Manager'	,'4. Z Foundation Manager') THEN base1.latest_managed_date  ELSE NULL END)  AS latest_managed_date
		,MAX(CASE WHEN base1.rel_type = 'managed' AND base1.officer_manage_status_ordered in ('1. Prospect Manager'		,'2. Team Member'	,'2. Stewardship Manager'	,'2. Discovery Manager'		,'2. Foundation Manager'
																							 ,'3. X Prospect Manager'	,'4. Z Team Member'	,'4. Z Stewardship Manager'	,'4. Z Discovery Manager'	,'4. Z Foundation Manager') THEN base1.latest_managed_date  ELSE NULL END)  AS latest_managed_date_notDM

		,MAX(CASE WHEN base1.rel_type = 'managed' AND base1.officer_manage_status_ordered = '1. Prospect Manager'	THEN base1.latest_managed_date ELSE NULL END)	AS ofcr_current_prospect_manager_latest_date
		,MAX(CASE WHEN base1.rel_type = 'managed' AND base1.officer_manage_status_ordered = '2. Team Member'		THEN base1.latest_managed_date ELSE NULL END)	AS ofcr_current_team_member_latest_date
		,MAX(CASE WHEN base1.rel_type = 'managed' AND base1.officer_manage_status_ordered = '2. Stewardship Manager' THEN base1.latest_managed_date ELSE NULL END)	AS ofcr_current_stewardship_manager_latest_date
		,MAX(CASE WHEN base1.rel_type = 'managed' AND base1.officer_manage_status_ordered = '2. Discovery Manager'	THEN base1.latest_managed_date ELSE NULL END)	AS ofcr_current_discovery_manager_latest_date
		,MAX(CASE WHEN base1.rel_type = 'managed' AND base1.officer_manage_status_ordered = '2. Foundation Manager' THEN base1.latest_managed_date ELSE NULL END)	AS ofcr_current_foundation_manager_latest_date
		,MAX(CASE WHEN base1.rel_type = 'dev_staff' THEN base1.latest_managed_date ELSE NULL END)	AS ofcr_current_development_staff_latest_date

		,MAX(CASE WHEN base1.rel_type = 'managed' AND base1.officer_manage_status_ordered in ('1. Prospect Manager',	'3. X Prospect Manager')	THEN base1.latest_managed_date ELSE NULL END)	AS ofcr_prospect_manager_latest_date
		,MAX(CASE WHEN base1.rel_type = 'managed' AND base1.officer_manage_status_ordered in ('2. Team Member',			'4. Z Team Member')			THEN base1.latest_managed_date ELSE NULL END)	AS ofcr_team_member_latest_date
		,MAX(CASE WHEN base1.rel_type = 'managed' AND base1.officer_manage_status_ordered in ('2. Stewardship Manage',	'4. Z Stewardship Manage')	THEN base1.latest_managed_date ELSE NULL END)	AS ofcr_stewardship_manager_latest_date
		,MAX(CASE WHEN base1.rel_type = 'managed' AND base1.officer_manage_status_ordered in ('2. Discovery Manager',	'4. Z Discovery Manager')	THEN base1.latest_managed_date ELSE NULL END)	AS ofcr_discovery_manager_latest_date
		,MAX(CASE WHEN base1.rel_type = 'managed' AND base1.officer_manage_status_ordered in ('2. Foundation Manager',	'4. Z Foundation Manager')	THEN base1.latest_managed_date ELSE NULL END)	AS ofcr_foundation_manager_latest_date
		,MAX(CASE WHEN base1.rel_type = 'dev_staff' THEN base1.latest_managed_date ELSE NULL END)	AS ofcr_development_staff_latest_date	--duplicative of ofcr_current_development_staff_latest_date as we dont track past development_staff assignments....yet

		,MAX(CASE WHEN base1.rel_type = 'managed' THEN base1.num_managing_stints ELSE NULL END) AS num_managing_stints
		,MAX(CASE WHEN base1.rel_type = 'managed' THEN base1.managing_stint_list ELSE NULL END) AS managing_stint_list
		
		--,MAX(CASE WHEN base1.rel_type = 'managed' AND base1.officer_manage_status_ordered in ('1. Prospect Manager','2. Team Member','2. Stewardship Manager','2. Discovery Manager','2. Foundation Manager') THEN base1.num_managing_stints ELSE NULL END) AS num_managing_stints		--i dont think these do what they are purporting to do
		--,MAX(CASE WHEN base1.rel_type = 'managed' AND base1.officer_manage_status_ordered in ('Prospect Manager','2. Team Member','2. Stewardship Manager','2. Discovery Manager','2. Foundation Manager') THEN base1.managing_stint_list ELSE NULL END) AS managing_stint_list		--i dont think these do what they are purporting to do
		
		,MAX(CASE WHEN base1.rel_type = 'referred' THEN 1 ELSE 0 END) AS flag_ofcr_referral_recipient
		,MAX(CASE WHEN base1.rel_type = 'referred' and base1.pgi_funding_type_code = 'Planned Gift Prospect' THEN 1 ELSE 0 END) AS flag_ofcr_planned_gift_referral_recipient
	--	,MAX(CASE WHEN rel_type = 'call list' THEN 1 ELSE 0 END) AS flag_ofcr_has_been_on_call_list  -- redundant after pm_ofcr_number_of_call_lists

		,MAX(CASE when base1.rel_type = 'not a prospect'	THEN 1 ELSE 0 END) as flag_ofcr_pgi_NAP
		--,MAX(CASE when base1.rel_type = 'pending interaction' then 1 else 0 end) as flag_has_pending_interaction --handled in the subquery
	--	,MAX(CASE WHEN base1.rel_type = 'current_role' AND base1.officer_manage_status = 'Engagement Manager' THEN 1 ELSE 0 END)		AS flag_ofcr_current_engagement_manager

		FROM (

			/* managed  -- N = 78K t=1s 3/5/26 */

select constituent_dim_id
	 , constituent_system_id
     , officer_dim_id
	 , officer_system_id
	 , NULL as unit_id
	 , NULL as unit_name
	 , 'managed' as rel_type
	 , min(status)					as officer_manage_status		--CURRENT, CURRENT-TEAM, PAST, PAST-TEAM
	 , min(status_ordered)			as officer_manage_status_ordered
	 , count(*)						as num_managing_stints
	 , string_agg(concat(status_ordered,'' ), ', ') within group (order by date_from desc)	as managing_stint_list
	 , min(CONVERT(DATE,ISNULL(date_from,NULL)))		as earliest_managed_date  --was '1990-12-25'
	-- , max(CONVERT(DATE,ISNULL(date_from,NULL)))		as latest_managed_date   -- current
	 , max(CONVERT(DATE,ISNULL(date_to,getdate())))			as latest_managed_date   -- changed on 7/9/25 to represent the 
	 , sum(days_managed)			as total_days_managed
	 , max(managed_in_currentFY)	as managed_in_current_FY
	 , max(managed_in_previousFY)	as managed_in_previous_FY
	 , NULL							as pgi_funding_type_code


from 
(
--combining 4 queries to get all possible managing statuses

--CURRENT PROSPECT MANAGER STINTS some null startdates
SELECT CONSTITUENTDIMID			as constituent_dim_id
	  ,CONSTITUENTSYSTEMID		as constituent_system_id
      ,FUNDRAISERDIMID			as officer_dim_id
	  ,FUNDRAISERSYSTEMID		as officer_system_id
      ,PROSPECTMANAGERSTARTDATE	as date_from
      ,PROSPECTMANAGERENDDATE	as date_to
	  ,'Prospect Manager'		as status
	  ,'1. Prospect Manager'	as status_ordered
	  ,case when DATEDIFF(year,dateadd(month,6,isnull(PROSPECTMANAGERENDDATE,getdate())),dateadd(month,6,getdate())) = 0 then 1 else 0 end as managed_in_currentFY
   	  ,case when DATEDIFF(year,dateadd(month,6,isnull(PROSPECTMANAGERENDDATE,getdate())),dateadd(month,6,getdate())) = 1 then 1 
	        when (DATEDIFF(year,dateadd(month,6,isnull(PROSPECTMANAGERENDDATE,getdate())),dateadd(month,6,getdate())) = 0
			 and DATEDIFF(year,dateadd(month,6,isnull(PROSPECTMANAGERSTARTDATE,getdate())),dateadd(month,6,getdate())) >=1) then 1 else 0 end as managed_in_previousFY
      , DATEDIFF(year,dateadd(month,6,isnull(PROSPECTMANAGERENDDATE,getdate())),dateadd(month,6,getdate())) as dateto_diff
	  , DATEDIFF(year,dateadd(month,6,isnull(PROSPECTMANAGERSTARTDATE,getdate())),dateadd(month,6,getdate())) as datefrom_diff
	  , datediff(day,isnull(PROSPECTMANAGERSTARTDATE,getdate()),isnull(PROSPECTMANAGERENDDATE,getdate())) as days_managed

  FROM BBCRM_PROD_RPT_BBDW.BBDW.DIM_PROSPECT p
  where p.fundraiserdimid > 0
    and getdate() between coalesce(p.PROSPECTMANAGERSTARTDATE,'1/1/1980') and coalesce(p.PROSPECTMANAGERENDDATE, '12/31/2099')
   -- and prospectstatus = 'assigned' --a dozen or so not a prospects but they are in this table, hmm one unassigned
  --order by managed_in_currentFY, managed_in_previousFY

 UNION ALL

 /* All current managers - Team, Stewardship, Discovery, Foundation, Development Staff, Engagement, Alumni (Excludes Team-Former and Prospect Manager)*/

SELECT pt.PROSPECTDIMID			as constituent_dim_id
	 , pt.PROSPECTSYSTEMID		as constituent_system_id
	 , pt.FUNDRAISERDIMID		as officer_dim_id
	 , pt.FUNDRAISERSYSTEMID	as officer_system_id
	 , min(pt.min_startdate)	as date_from
	 , max(pt.max_enddate)		as date_to
	 , min(pt.fundraiserrolecode)					as status
	  ,concat('2. ',min(pt.fundraiserrolecode))		as status_ordered
	 , max(pt.managed_in_currentFY) as managed_in_current_FY
	 , max(pt.managed_in_previousFY) as managed_in_previous_FY
     , max(DATEDIFF(year,dateadd(month,6,isnull(pt.max_enddate	,getdate())),dateadd(month,6,getdate()))) as dateto_diff
	 , min(DATEDIFF(year,dateadd(month,6,isnull(pt.min_startdate,getdate())),dateadd(month,6,getdate()))) as datefrom_diff
	 , max(pt.days_managed) as total_days_managed

  FROM (
		SELECT p.PROSPECTSYSTEMID
		     , p.PROSPECTDIMID
			 , max(c.FULLNAME) as prospect_name
			 , FUNDRAISERROLECODE
			 , FUNDRAISERSYSTEMID
			 , FUNDRAISERNAME
			 , FUNDRAISERDIMID
			 , case when NULLIF(MAX(COALESCE(EndDate,'9999-12-31')),'9999-12-31') is null then 1 else 0 end as prospect_role_current
		     , min(isnull(STARTDATE,'1990-01-01')) as min_startdate
		     , max(isnull(ENDDATE,getdate())) as max_enddate
			 , max(datediff(day,isnull(STARTDATE,'1990-01-01'),isnull(ENDDATE,getdate()))) as days_managed
			 , max(case when DATEDIFF(year,dateadd(month,6,isnull(ENDDATE,getdate())),dateadd(month,6,getdate())) = 0 then 1 else 0 end) as managed_in_currentFY
   	         , max(case when DATEDIFF(year,dateadd(month,6,isnull(ENDDATE,getdate())),dateadd(month,6,getdate())) = 1 then 1 
	                when (DATEDIFF(year,dateadd(month,6,isnull(ENDDATE,getdate())),dateadd(month,6,getdate())) = 0
		 	         and DATEDIFF(year,dateadd(month,6,isnull(STARTDATE,getdate())),dateadd(month,6,getdate())) >=1) then 1 else 0 end) as managed_in_previousFY

		  FROM BBCRM_PROD_RPT_BBDW.BBDW.VCU_DIM_PROSPECTTEAM p
	 left join BBCRM_PROD_RPT_BBDW.BBDW.DIM_CONSTITUENT c on c.CONSTITUENTDIMID = p.PROSPECTDIMID
		 WHERE FUNDRAISERROLECODE not in ('Team Member - Former'   --Gets rid of situations where someone is both team member and team member - former can revisit if we need these connections
	           , 'External Relations Manager')  --an old code that sometimes gets misapplied
			and c.isactive=1
		 GROUP BY p.prospectsystemid, p.fundraiserrolecode, p.FUNDRAISERSYSTEMID, p.FUNDRAISERNAME, p.FUNDRAISERDIMID, p.PROSPECTDIMID
   -- ORDER BY fundraiserrolecode --prospectteam_current desc
	  ) pt

  where pt.prospect_role_current = 1  --only keep current managers
  and pt.fundraiserrolecode <> 'Development Staff'

  group by  prospectsystemid, FUNDRAISERSYSTEMID, prospectdimid, FUNDRAISERDIMID
  -- having  min(fundraiserrolecode) = 'Team Member'
  --order by officer_manage_status, officer_name

  UNION ALL

  /*Past Prospect Manager*/
  SELECT pmh.CONSTITUENTDIMID		as constituent_dim_id
	  , c.CONSTITUENTSYSTEMID		as constituent_system_id
      , pmh.FUNDRAISERDIMID			as officer_dim_id
	  , c2.CONSTITUENTSYSTEMID		as officer_system_id
      , DATEFROM				as date_from
      , DATETO					as date_to
	  , 'X Prospect Manager'	as status
	  , '3. X Prospect Manager'	as status_ordered
	  , case when DATEDIFF(year,dateadd(month,6,isnull(DATETO,getdate())),dateadd(month,6,getdate())) = 0 then 1 else 0 end as managed_in_currentFY
   	  , case when DATEDIFF(year,dateadd(month,6,isnull(DATETO,getdate())),dateadd(month,6,getdate())) = 1 then 1 
	         when (DATEDIFF(year,dateadd(month,6,isnull(DATETO,getdate())),dateadd(month,6,getdate())) = 0
		  	  and DATEDIFF(year,dateadd(month,6,isnull(DATEFROM,getdate())),dateadd(month,6,getdate())) >=1) then 1 else 0 end as managed_in_previousFY
      , DATEDIFF(year,dateadd(month,6,isnull(DATETO,getdate())),dateadd(month,6,getdate())) as dateto_diff
	  , DATEDIFF(year,dateadd(month,6,isnull(DATEFROM,getdate())),dateadd(month,6,getdate())) as datefrom_diff
	  , datediff(day,isnull(DATEFROM,getdate()),isnull(DATETO,getdate())) as days_managed

   FROM BBCRM_PROD_RPT_BBDW.BBDW.VCU_FACT_PROSPECTMANAGERHISTORY pmh
   join BBCRM_PROD_RPT_BBDW.BBDW.VCU_RPT_CONSTITUENTLIST c on c.CONSTITUENTDIMID = pmh.CONSTITUENTDIMID		--only want active records. added since pmh doesn't have system IDs
   join BBCRM_PROD_RPT_BBDW.BBDW.VCU_RPT_CONSTITUENTLIST c2 on c2.CONSTITUENTDIMID = pmh.FUNDRAISERDIMID	--same

  UNION ALL

  /*Past Team, Stewardship and Discovery Managers*/
  SELECT pt.PROSPECTDIMID		as constituent_dim_id
	 , pt.PROSPECTSYSTEMID		as constituent_system_id
	 , pt.FUNDRAISERDIMID		as officer_dim_id
	 , pt.FUNDRAISERSYSTEMID	as officer_system_id
	 , min(pt.min_startdate)	as date_from
	 , max(pt.max_enddate)		as date_to
	 , concat('Z ',min(case when pt.fundraiserrolecode = 'Team Member - Former' then 'Team Member' else pt.fundraiserrolecode end ))		as status
	  ,concat('4. Z ',min(case when pt.fundraiserrolecode = 'Team Member - Former' then 'Team Member' else pt.fundraiserrolecode end ))		as status_ordered
	 , max(pt.managed_in_currentFY) as managed_in_current_FY
	 , max(pt.managed_in_previousFY) as managed_in_previous_FY
     , max(DATEDIFF(year,dateadd(month,6,isnull(pt.max_enddate	,getdate())),dateadd(month,6,getdate()))) as dateto_diff
	 , min(DATEDIFF(year,dateadd(month,6,isnull(pt.min_startdate,getdate())),dateadd(month,6,getdate()))) as datefrom_diff
	 , max(pt.days_managed) as total_days_managed

  FROM (
		SELECT p.PROSPECTSYSTEMID
		     , p.PROSPECTDIMID
			 , max(c.FULLNAME) as prospect_name
			 , FUNDRAISERROLECODE
			 , FUNDRAISERSYSTEMID
			 , FUNDRAISERNAME
			 , FUNDRAISERDIMID
			 , case when NULLIF(MAX(COALESCE(EndDate,'9999-12-31')),'9999-12-31') is null then 1 else 0 end as prospect_role_current
		     , min(isnull(STARTDATE,'1990-01-01')) as min_startdate
		     , max(isnull(ENDDATE,getdate())) as max_enddate
			 , max(datediff(day,isnull(STARTDATE,'1990-01-01'),isnull(ENDDATE,getdate()))) as days_managed
			 , max(case when DATEDIFF(year,dateadd(month,6,isnull(ENDDATE,getdate())),dateadd(month,6,getdate())) = 0 then 1 else 0 end) as managed_in_currentFY
   	         , max(case when DATEDIFF(year,dateadd(month,6,isnull(ENDDATE,getdate())),dateadd(month,6,getdate())) = 1 then 1 
	                when (DATEDIFF(year,dateadd(month,6,isnull(ENDDATE,getdate())),dateadd(month,6,getdate())) = 0
		 	         and DATEDIFF(year,dateadd(month,6,isnull(STARTDATE,getdate())),dateadd(month,6,getdate())) >=1) then 1 else 0 end) as managed_in_previousFY

		  FROM BBCRM_PROD_RPT_BBDW.BBDW.VCU_DIM_PROSPECTTEAM p
	 left join BBCRM_PROD_RPT_BBDW.BBDW.DIM_CONSTITUENT c on c.CONSTITUENTDIMID = p.PROSPECTDIMID
		 --WHERE FUNDRAISERROLECODE not in ('Team Member - Former'   --Gets rid of situations where someone is both team member and team member - former can revisit if we need these connections
	  --         , 'External Relations Manager')  --an old code that sometimes gets misapplied
		WHERE c.isactive = 1
		 GROUP BY p.prospectsystemid, p.fundraiserrolecode, p.FUNDRAISERSYSTEMID, p.FUNDRAISERNAME, p.FUNDRAISERDIMID, p.PROSPECTDIMID
   -- ORDER BY fundraiserrolecode --prospectteam_current desc
	  ) pt

  where pt.prospect_role_current = 0  --only keep current managers

  group by prospectsystemid, FUNDRAISERSYSTEMID, prospectdimid, FUNDRAISERDIMID
  -- having  min(fundraiserrolecode) = 'Team Member'

   ) mng  --end of four union statements

  group by constituent_system_id, officer_system_id, constituent_dim_id, officer_dim_id
  --  order by managed_in_current_FY, managed_in_previous_FY

UNION ALL

 /* All current Development Staff (Excludes Team-Former and Prospect Manager)  --Need to separate these out as they can be in addition to TM/FM/SM/DM/EM */
/* This code works but could very well be simplified*/

SELECT pt.PROSPECTDIMID			as constituent_dim_id
	 , pt.PROSPECTSYSTEMID		as constituent_system_id
	 , pt.FUNDRAISERDIMID		as officer_dim_id
	 , pt.FUNDRAISERSYSTEMID	as officer_system_id
	 , NULL as unit_id
	 , NULL as unit_name
	 , 'dev_staff'				as rel_type 

	 , NULL as officer_manage_status
	 , NULL as officer_manage_status_ordered
	 , NULL as num_managing_stints
	 , NULL as managing_stint_list
	 , NULL as earliest_managed_date
	 , NULL as latest_managed_date
	 , NULL as total_days_managed
	 , NULL as managed_in_current_FY
	 , NULL as managed_in_previous_FY
	 , NULL as pgi_funding_type_code

  FROM (
		SELECT p.PROSPECTSYSTEMID
		     , p.PROSPECTDIMID
		--	 , max(c.FULLNAME) as prospect_name
			 , FUNDRAISERROLECODE
			 , FUNDRAISERSYSTEMID
			 , FUNDRAISERNAME
			 , FUNDRAISERDIMID
			 , case when NULLIF(MAX(COALESCE(EndDate,'9999-12-31')),'9999-12-31') is null then 1 else 0 end as prospect_role_current
		  --   , min(isnull(STARTDATE,'1990-01-01')) as min_startdate
		  --   , max(isnull(ENDDATE,getdate())) as max_enddate
			 --, max(datediff(day,isnull(STARTDATE,'1990-01-01'),isnull(ENDDATE,getdate()))) as days_managed
			 --, max(case when DATEDIFF(year,dateadd(month,6,isnull(ENDDATE,getdate())),dateadd(month,6,getdate())) = 0 then 1 else 0 end) as managed_in_currentFY
   	--         , max(case when DATEDIFF(year,dateadd(month,6,isnull(ENDDATE,getdate())),dateadd(month,6,getdate())) = 1 then 1 
	   --             when (DATEDIFF(year,dateadd(month,6,isnull(ENDDATE,getdate())),dateadd(month,6,getdate())) = 0
		 	--         and DATEDIFF(year,dateadd(month,6,isnull(STARTDATE,getdate())),dateadd(month,6,getdate())) >=1) then 1 else 0 end) as managed_in_previousFY

		  FROM BBCRM_PROD_RPT_BBDW.BBDW.VCU_DIM_PROSPECTTEAM p
	 left join BBCRM_PROD_RPT_BBDW.BBDW.DIM_CONSTITUENT c on c.CONSTITUENTDIMID = p.PROSPECTDIMID
		 WHERE FUNDRAISERROLECODE = 'Development Staff'
			and c.isactive=1
		 GROUP BY p.prospectsystemid, p.fundraiserrolecode, p.FUNDRAISERSYSTEMID, p.FUNDRAISERNAME, p.FUNDRAISERDIMID, p.PROSPECTDIMID
   -- ORDER BY fundraiserrolecode --prospectteam_current desc
	  ) pt

  where pt.prospect_role_current = 1  --only keep current managers
  --and pt.fundraiserrolecode = 'Development Staff'
  --and pt.PROSPECTSYSTEMID = '3D484561-4F5E-4B56-B05B-8A4695D4521D'

  group by  prospectsystemid, FUNDRAISERSYSTEMID, prospectdimid, FUNDRAISERDIMID
  -- having  min(fundraiserrolecode) = 'Team Member'
  --order by officer_manage_status, officer_name



UNION ALL

		/* Officer(by Unit) x Constituent Interactions
		  N= 147K t=3s Mar 30 2026*/
SELECT i.constituent_dim_id
	 , i.constituent_system_id
     , i.officer_dim_id
	 , i.officer_system_id
	 , NULL as unit_id
	 , NULL as unit_name
	 , 'contact'				as rel_type 

	 , NULL as officer_manage_status
	 , NULL as officer_manage_status_ordered
	 , NULL as num_managing_stints
	 , NULL as managing_stint_list
	 , NULL as earliest_managed_date
	 , NULL as latest_managed_date
	 , NULL as total_days_managed
	 , NULL as managed_in_current_FY
	 , NULL as managed_in_previous_FY
	 , NULL as pgi_funding_type_code

      -- [interaction_constituent_combo_id]
      --,[interaction_system_id]
	      -- ,[constituent_lookup_id]
     -- ,[constituent_system_id]
      --,[household_id]
     -- ,[officer_lookup_id]
     -- ,[officer_system_id]
      --,[officer_interaction_role]
      --,[officer_interaction_role_detail]
      --,[bio_name]
      --,[bio_lastcommafirstname]
      --,[pm_ofcr_manage_status]
      --,[flag_ofcr_currently_managed]
      --,[flag_ofcr_current_prospect_manager]
      --,[officer_name]
      --,[primary_fundraiser_name]
      --,[officer_name_morethanGOI]
      --,[primary_fundraiser_name_morethanGOI]

      --,[unit_name_campaign]
      --,[interaction_site_list_campaign]
      --,[position_order_desc]
      --,[flag_active_officer]
      --,[flag_use_in_fundraiser_reports]
      --,[officer_campus]
      --,[officer_job_level]
      --,[avp_officer_manager]
      --,[flag_full_tenure_current_FY]
      --,[flag_full_tenure_previous_FY]
      --,[interaction_subcategory]
      --,[interaction_category]
      --,[interaction_type]
      --,[interaction_status]
      --,[flag_is_contact_report]
      --,[flag_is_interaction]
      --,[prospect_plan_dim_id]
      --,[plan_outline_step_dim_id]
      --,[prospect_plan_status_dim_id]
      --,[prospect_plan_name]
      --,[prospect_plan_status]
      --,[prospect_plan_type]
      --,[prospect_plan_system_id]
      --,[interaction_lookup_id]
      --,[interaction_objective]
      --,[flag_is_first_interaction]
      --,[flag_is_last_interaction]
      --,[interaction_comment]
      --,[interaction_sequence]
      --,[interaction_actual_date]
      --,[interaction_change_date]
      --,[interaction_expected_date]
      --,[flag_officer_in_GOI_table]
      --,[flag_sig_interaction_type]
      --,[flag_sig_interaction_2030]
      --,[flag_sig_interaction_cultivate]
      --,[interaction_FY]
      --,[flag_FY_current]
      --,[flag_FY_previous]
      --,[flag_is_officer]
      --,[flag_same_time_last_FY]
      --,[current_prospect_manager]
      --,[current_prospect_manager_system_id]
      --,[current_prospect_manager_job_level]
      --,[current_prospect_manager_unit_name]
      --,[current_prospect_manager_avp]
      --,[mov_ofcr_latest_referral_receipt]
      --,[mov_ofcr_latest_referral_receipt_stop_date]
      --,[flag_interaction_during_referral]
      --,[flag_latest_referral_active]
      --,[interaction_participants]
      --,[interaction_owner_name]
      --,[interaction_owner_system_id]
      --,[bio_age]
      --,[bio_death_date]
      --,[gvg_recog_raised_life_hh]
      --,[eval_vcu_planned_giving_score_sql]
      --,[flag_has_pg_vehicle_hh]
      --,[pm_current_team]
  FROM DARanalytics.tableau.officer_unit_constituent_interactions_all i
  join DARanalytics.ref.gift_officer_info goi on goi.officer_system_id = i.officer_system_id   --limit this to people in Org Hierarchy
											 and goi.position_order_desc = 1
  group by i.constituent_dim_id
		 , i.constituent_system_id
         , i.officer_dim_id
		 , i.officer_system_id

UNION ALL


/* referred to N= 3414 t=1s  Mar 30 2026*/
select r.constituent_dim_id		as constituent_dim_id
	 , r.constituent_system_id	as constituent_system_id
     , r.pgi_fundraiser_dim_id	as officer_dim_id
	 , r.pgi_fundraiser_system_id	as officer_system_id
	 , max(r.pgi_unit_id)       as unit_id				--twas max(r.pgi_fundraiser_unit_id) while some PGis have multiple units, anyone with fundraiser only has one
	 , max(r.pgi_unit_name)		as unit_name			--was max(r.pgi_fundraiser_unit_name)
	 , 'referred'				as rel_type 

  --   , t.CONSTITUENTSYSTEMID		as constituent_system_id
  --   , t.FUNDRAISERSYSTEMID			as primary_officer_system_id
  --   , max(t.CONSTITUENTLOOKUPID)	as constituent_lookup_id
  --   , max(t.bio_name)				as bio_name
  --  , max(t.officer_name)			as primary_officer_name

	-- , max(position_order_desc)		as officer_unit_order
	 , NULL as officer_manage_status
	 , NULL as officer_manage_status_ordered
	 , NULL as num_managing_stints
	 , NULL as managing_stint_list
	 , NULL as earliest_managed_date
	 , NULL as latest_managed_date
	 , NULL as total_days_managed
	 , NULL as managed_in_current_FY
	 , NULL as managed_in_previous_FY
	 , pgi_funding_type_code


FROM (
SELECT [constituent_dim_id]
      ,[constituent_system_id]
      ,[constituent_lookup_id]
      ,[bio_name]
      ,[eval_capacity_rating_desc]
      ,[pm_prospect_status]
      ,[pm_prospect_status_hh]
      ,[affil_school1]
      ,[eval_bwf_planned_gift_rating]
      ,[eval_vcu_planned_giving_score]
      ,[eval_bwf_major_gift_rating]
      ,[PROSPECTGIVINGINTERESTSDIMID]
      ,[PROSPECTGIVINGINTERESTSSYSTEMID]
      ,[SITEDIMID]
      ,[pgi_unit_name]
      ,[pgi_unit_id]
      ,[pgi_default_unit_ldo_name]
      ,[pgi_default_unit_ldo_id]
      ,[pgi_funding_type_code]
      ,[pgi_inclination_level_code]
      ,[pgi_comment]
      ,[pgi_include_spouse]
      ,[row_num]
      ,[row_num_pgsi]
      ,[start_date]
      ,[stop_date]
      ,[flag_all_of_vcu_not_prospect]
      ,[flag_unit_not_prospect]
      ,[pgi_fundraiser_system_id]
	  ,pgi_fundraiser_dim_id
      ,[pgi_fundraiser_name]
      ,[pgi_fundraiser_unit_id]
      ,[pgi_fundraiser_unit_name]
      ,[flag_alum]
      ,[flag_strikezone]
      ,[flag_rp_legacysociety]
      ,[prospect_status_group]
      ,[pgi_referral_note1]
      ,[pgi_referral_note2]
      ,[pgi_referral_note3]
      ,[pgi_fundraiser_name_notgoi]
      ,[pgi_fundraiser_system_id_all]
	 , pgi_submitter_name
  FROM [DARanalytics].[tableau].[unit_all_pgis]
  where pgi_inclination_level_code = 'suspect'				 --told by Ben that these are all Referrals
    and pgi_fundraiser_name is not null						 --new field that allows us to do this linking
	and isnull(pgi_referral_note1,'blah') not like '%test%'  --eventually will be cleaned in the data
	and start_date <= getdate()								 --supposedly these will also be clened up in the future
	) r
	  group by r.constituent_dim_id, r.pgi_fundraiser_dim_id, pgi_funding_type_code , r.constituent_system_id, r.pgi_fundraiser_system_id --t.unit_id

UNION ALL

/* NAPs N= 762 t=1s*/
select r.constituent_dim_id					as constituent_dim_id
	 , r.constituent_system_id				as constituent_system_id
     , r.pgi_fundraiser_dim_id				as officer_dim_id
	 , r.pgi_fundraiser_system_id			as officer_system_id
	 , max(r.pgi_fundraiser_unit_id)        as unit_id   --this is junk just a placeholder til I convert this entire table to Officer-Unit
	 , max(r.pgi_fundraiser_unit_name)		as unit_name
	 , 'not a prospect'						as rel_type 

  --   , t.CONSTITUENTSYSTEMID		as constituent_system_id
  --   , t.FUNDRAISERSYSTEMID			as primary_officer_system_id
  --   , max(t.CONSTITUENTLOOKUPID)	as constituent_lookup_id
  --   , max(t.bio_name)				as bio_name
  --  , max(t.officer_name)			as primary_officer_name

	-- , max(position_order_desc)		as officer_unit_order
	 , NULL as officer_manage_status
	 , NULL as officer_manage_status_ordered
	 , NULL as num_managing_stints
	 , NULL as managing_stint_list
	 , NULL as earliest_managed_date
	 , NULL as latest_managed_date
	 , NULL as total_days_managed
	 , NULL as managed_in_current_FY
	 , NULL as managed_in_previous_FY
	 , pgi_funding_type_code

FROM (
SELECT [constituent_dim_id]
      ,[constituent_system_id]
      ,[constituent_lookup_id]
      ,[bio_name]
      ,[eval_capacity_rating_desc]
      ,[pm_prospect_status]
      ,[pm_prospect_status_hh]
      ,[affil_school1]
      ,[eval_bwf_planned_gift_rating]
      ,[eval_vcu_planned_giving_score]
      ,[eval_bwf_major_gift_rating]
      ,[PROSPECTGIVINGINTERESTSDIMID]
      ,[PROSPECTGIVINGINTERESTSSYSTEMID]
      ,[SITEDIMID]
      ,[pgi_unit_name]
      ,[pgi_unit_id]
      ,[pgi_default_unit_ldo_name]
      ,[pgi_default_unit_ldo_id]
      ,[pgi_funding_type_code]
      ,[pgi_inclination_level_code]
      ,[pgi_comment]
      ,[pgi_include_spouse]
      ,[row_num]
      ,[row_num_pgsi]
      ,[start_date]
      ,[stop_date]
      ,[flag_all_of_vcu_not_prospect]
      ,[flag_unit_not_prospect]
      ,[pgi_fundraiser_system_id]
	  ,pgi_fundraiser_dim_id
      ,[pgi_fundraiser_name]
      ,[pgi_fundraiser_unit_id]
      ,[pgi_fundraiser_unit_name]
      ,[flag_alum]
      ,[flag_strikezone]
      ,[flag_rp_legacysociety]
      ,[prospect_status_group]
      ,[pgi_referral_note1]
      ,[pgi_referral_note2]
      ,[pgi_referral_note3]
      ,[pgi_fundraiser_name_notgoi]
      ,[pgi_fundraiser_system_id_all]
	 , pgi_submitter_name
  FROM [DARanalytics].[tableau].[unit_all_pgis]
  where pgi_inclination_level_code like '%not a prospect%'	 --told by Ben that these are all Referrals
    and pgi_fundraiser_system_id is not null			 --new field that allows us to do this linking
	and isnull(pgi_referral_note1,'blah') not like '%test%'  --eventually will be cleaned in the data
	and start_date <= getdate()								 --supposedly these will also be clened up in the future
	) r
	  group by r.constituent_dim_id, r.pgi_fundraiser_dim_id, pgi_funding_type_code, r.constituent_system_id, r.pgi_fundraiser_system_id  --, t.unit_id

UNION ALL

/* Pending Interactions N=6k  t=0s*/
select pi.constituent_dim_id			as constituent_dim_id
	 , pi.constituent_system_id				as constituent_system_id
     , pi.officer_dim_id					as officer_dim_id
	 , pi.officer_system_id					as officer_system_id
	 , NULL									as unit_id   --this is junk just a placeholder til I convert this entire table to Officer-Unit
	 , NULL									as unit_name
	 , 'pending interaction'						as rel_type 

	 , NULL as officer_manage_status
	 , NULL as officer_manage_status_ordered
	 , NULL as num_managing_stints
	 , NULL as managing_stint_list
	 , NULL as earliest_managed_date
	 , NULL as latest_managed_date
	 , NULL as total_days_managed
	 , NULL as managed_in_current_FY
	 , NULL as managed_in_previous_FY
	 , NULL as pgi_funding_type_code

FROM (
		SELECT constituent_system_id
			 , max(constituent_dim_id) as constituent_dim_id
			 , officer_system_id
			 , max(officer_dim_id) as officer_dim_id
			 , max(case when interaction_status = 'Pending' then 1 else 0 end)  as flag_officer_has_pending_interaction
			 , max(case when interaction_status = 'Pending' and prospect_plan_dim_id > 0 then 1 else 0 end)  as flag_officer_has_pending_plan_interaction
			 --, min(case when interaction_status = 'Pending' then interaction_actual_date else NULL end)  as officer_earliest_pending_interaction_date
			 --, max(case when interaction_status = 'Pending' then interaction_actual_date else NULL end)  as officer_latest_pending_interaction_date
		  FROM DARanalytics.tableau.officer_unit_constituent_interactions_notcompleted
	  GROUP BY constituent_system_id, officer_system_id							 
	) pi




		) BASE1   --inner base.  Can have multiple relationships between officer and prospect

GROUP BY
	 BASE1.constituent_system_id
	,BASE1.officer_system_id
	--,BASE1.constituent_dim_id				--switched to system IDs on 3.30.26
	--,BASE1.officer_dim_id
)  base  --only one record per prospect-officer combination


	JOIN DARanalytics.datamart.constituent_level cl			ON cl.constituent_system_id = base.constituent_system_id
	JOIN DARanalytics.datamart.constituent_level cl_ofcr	ON cl_ofcr.constituent_system_id = base.officer_system_id
	--JOIN prma_playground.ref.joint_id j on base.entity_id = j.entity_id
	
	/*just trying to get the current unit info attached to the officer*/
	left join DARanalytics.ref.gift_officer_info goi on goi.officer_system_id = base.officer_system_id
													and position_order_desc = 1
		
	/*connect in Household officer fields*/
	left join DARanalytics.datamart.constituent_household_officer_level chol on chol.household_id		= cl.household_id
																			and chol.officer_system_id	= cl_ofcr.constituent_system_id
			  
	/* call lists */
	
	/* Officer(by Unit) x Constituent Interactions N=104k t=2s*/
	left join (
SELECT constituent_system_id
	 , i.officer_system_id		as primary_officer_system_id
	 , 'contact'				as rel_type
	 , NULL as unit_id		  --this is junk just a placeholder til I convert this entire table to Officer-Unit
	 , constituent_dim_id
	 , constituent_lookup_id
     , i.officer_dim_id
	 , bio_name
	 , max(i.officer_name)				as primary_officer_name
	 , NULL as unit_name
	 , max(i.position_order_desc) as officer_unit_order --This is a bad field and would only indicate how many jbos they've had since their first interaction

	 , NULL as officer_manage_status
	 , NULL as total_days_managed
	 , NULL as managed_in_current_FY
	 , NULL as managed_in_previous_FY
	 , NULL as earliest_managed_date
	 , NULL as latest_managed_date



      -- [interaction_constituent_combo_id]
      --,[interaction_system_id]
	      -- ,[constituent_lookup_id]
     -- ,[constituent_system_id]
      --,[household_id]
     -- ,[officer_lookup_id]
     -- ,[officer_system_id]
      --,[officer_interaction_role]
      --,[officer_interaction_role_detail]
      --,[bio_name]
      --,[bio_lastcommafirstname]
      --,[pm_ofcr_manage_status]
      --,[flag_ofcr_currently_managed]
      --,[flag_ofcr_current_prospect_manager]
      --,[officer_name]
      --,[primary_fundraiser_name]
      --,[officer_name_morethanGOI]
      --,[primary_fundraiser_name_morethanGOI]

      --,[unit_name_campaign]
      --,[interaction_site_list_campaign]
      --,[position_order_desc]
      --,[flag_active_officer]
      --,[flag_use_in_fundraiser_reports]
      --,[officer_campus]
      --,[officer_job_level]
      --,[avp_officer_manager]
      --,[flag_full_tenure_current_FY]
      --,[flag_full_tenure_previous_FY]
      --,[interaction_subcategory]
      --,[interaction_category]
      --,[interaction_type]
      --,[interaction_status]
      --,[flag_is_contact_report]
      --,[flag_is_interaction]
      --,[prospect_plan_dim_id]
      --,[plan_outline_step_dim_id]
      --,[prospect_plan_status_dim_id]
      --,[prospect_plan_name]
      --,[prospect_plan_status]
      --,[prospect_plan_type]
      --,[prospect_plan_system_id]
      --,[interaction_lookup_id]
      --,[interaction_objective]
      --,[flag_is_first_interaction]
      --,[flag_is_last_interaction]
      --,[interaction_comment]
      --,[interaction_sequence]
      --,[interaction_actual_date]
      --,[interaction_change_date]
      --,[interaction_expected_date]
      --,[flag_officer_in_GOI_table]
      --,[flag_sig_interaction_type]
      --,[flag_sig_interaction_2030]
      --,[flag_sig_interaction_cultivate]
      --,[interaction_FY]
      --,[flag_FY_current]
      --,[flag_FY_previous]
      --,[flag_is_officer]
      --,[flag_same_time_last_FY]
      --,[current_prospect_manager]
      --,[current_prospect_manager_system_id]
      --,[current_prospect_manager_job_level]
      --,[current_prospect_manager_unit_name]
      --,[current_prospect_manager_avp]
      --,[mov_ofcr_latest_referral_receipt]
      --,[mov_ofcr_latest_referral_receipt_stop_date]
      --,[flag_interaction_during_referral]
      --,[flag_latest_referral_active]
      --,[interaction_participants]
      --,[interaction_owner_name]
      --,[interaction_owner_system_id]
      --,[bio_age]
      --,[bio_death_date]
      --,[gvg_recog_raised_life_hh]
      --,[eval_vcu_planned_giving_score_sql]
      --,[flag_has_pg_vehicle_hh]
      --,[pm_current_team]
  FROM DARanalytics.tableau.officer_unit_constituent_interactions_all i
  join DARanalytics.ref.gift_officer_info goi on goi.officer_system_id = i.officer_system_id   --limit this to people in Org Hierarchy
											 and i.interaction_actual_date between goi.date_from and goi.date_to
 
  group by i.constituent_dim_id
		 , i.constituent_lookup_id
		 , i.constituent_system_id
		 , i.bio_name
		 , i.officer_dim_id
		 , i.officer_lookup_id
		 , i.officer_system_id
		

	) interactions on interactions.constituent_system_id			= base.constituent_system_id
				  and interactions.primary_officer_system_id		= base.officer_system_id

/* COMPLETED significant interactions  N= 204k t=4s*/
  left join (
	  SELECT i.constituent_system_id
		  , max(i.constituent_dim_id) as constituent_dim_id
		 , i.officer_system_id
		 , max(i.officer_dim_id) as officer_dim_id
		 , count(case when i.flag_sig_interaction_type = 1 and i.officer_interaction_role in ('primary','participant','secondary') then i.interaction_actual_date else NULL end) as num_interaction_sig_all
		 , count(case when i.flag_sig_interaction_type = 1 and i.officer_interaction_role = 'primary'     then i.interaction_actual_date else NULL end) as num_interaction_sig_primary
		 , count(case when i.flag_sig_interaction_type = 1 and i.officer_interaction_role = 'participant' then i.interaction_actual_date else NULL end) as num_interaction_sig_participant
		 , count(case when i.flag_sig_interaction_type = 1 and i.officer_interaction_role = 'secondary'   then i.interaction_actual_date else NULL end) as num_interaction_sig_secondary
		 , count(case when									   i.officer_interaction_role = 'discovery'   then i.interaction_actual_date else NULL end) as num_interaction_discovery

		 ,   max(case when i.flag_sig_interaction_type = 1 and i.officer_interaction_role in ('primary','participant','secondary') then interaction_actual_date else NULL end) as latest_interaction_sig_all
		 ,   max(case when i.flag_sig_interaction_type = 1 and i.officer_interaction_role = 'primary'     then i.interaction_actual_date else NULL end) as latest_interaction_sig_primary
		 ,   max(case when i.flag_sig_interaction_type = 1 and i.officer_interaction_role = 'participant' then i.interaction_actual_date else NULL end) as latest_interaction_sig_participant
		 ,   max(case when i.flag_sig_interaction_type = 1 and i.officer_interaction_role = 'secondary'   then i.interaction_actual_date else NULL end) as latest_interaction_sig_secondary
		 ,   max(case when									   i.officer_interaction_role = 'discovery'   then i.interaction_actual_date else NULL end) as latest_interaction_discovery

		 ,   min(case when i.flag_sig_interaction_type = 1 and i.officer_interaction_role in ('primary','participant','secondary') then interaction_actual_date else NULL end) as earliest_interaction_sig_all
		 ,   min(case when i.flag_sig_interaction_type = 1 and i.officer_interaction_role = 'primary'     then interaction_actual_date else NULL end) as earliest_interaction_sig_primary
		 ,   min(case when i.flag_sig_interaction_type = 1 and i.officer_interaction_role = 'participant' then interaction_actual_date else NULL end) as earliest_interaction_sig_participant
		 ,   min(case when i.flag_sig_interaction_type = 1 and i.officer_interaction_role = 'secondary'   then interaction_actual_date else NULL end) as earliest_interaction_sig_secondary
		 ,   min(case when									   i.officer_interaction_role = 'discovery'   then interaction_actual_date else NULL end) as earliest_interaction_discovery

		 , max(case when i.flag_sig_interaction_type = 1 then flag_FY_current else NULL end) as flag_interaction_sig_FY_current
		 , max(case when i.flag_sig_interaction_type = 1 then flag_FY_previous else NULL end) as flag_interaction_sig_FY_previous
		 , max(case when i.flag_sig_interaction_type = 1 then interaction_FY else NULL end) as latest_interaction_sig_FY

		 , max(case when i.flag_sig_interaction_cultivate = 1 and officer_interaction_role in ('primary','participant','secondary') then interaction_actual_date else NULL end) as latest_interaction_sig_all_cultivate
		 , max(case when i.flag_sig_interaction_cultivate = 1 and officer_interaction_role = 'primary'     then interaction_actual_date else NULL end) as latest_interaction_sig_primary_cultivate
		 , max(case when i.flag_sig_interaction_cultivate = 1 and officer_interaction_role = 'participant' then interaction_actual_date else NULL end) as latest_interaction_sig_participant_cultivate
		 , max(case when i.flag_sig_interaction_cultivate = 1 and officer_interaction_role = 'secondary'   then interaction_actual_date else NULL end) as latest_interaction_sig_secondary_cultivate
		 , max(case when i.flag_sig_interaction_cultivate = 1 and officer_interaction_role = 'discovery'   then interaction_actual_date else NULL end) as latest_interaction_sig_discovery_cultivate	
	
	
	/*
	constituent_dim_id
		  ,constituent_lookup_id
		  ,constituent_system_id 
		  ,i.officer_dim_id
		  ,i.officer_system_id
		  ,officer_interaction_role
		  ,bio_name
		  ,bio_lastcommafirstname
		  ,pm_ofcr_manage_status
		  ,flag_ofcr_currently_managed
		  ,i.officer_name
		  ,full_name
		  ,i.unit_id
		  ,i.unit_name
		  ,i.position_order_desc
		  ,i.flag_active_officer
		  ,i.flag_use_in_fundraiser_reports
		  ,i.officer_campus
		  ,interaction_subcategory
		  ,interaction_category
		  ,interaction_type
		  ,interaction_status
		  ,flag_is_contact_report
		  ,flag_is_interaction
		  ,prospect_plan_dim_id
		  ,plan_outline_step_dim_id
		  ,prospect_plan_status_dim_id
		  ,interaction_lookup_id
		  ,interaction_objective
		  ,flag_is_first_interaction
		  ,flag_is_last_interaction
		  ,interaction_comment
		  ,interaction_sequence
		  ,interaction_actual_date
		  ,flag_officer_in_GOI_table
		  ,flag_sig_interaction_type
		  ,flag_sig_interaction_2030
		  ,interaction_FY
		  ,flag_FY_current
		  ,flag_FY_previous
		  */
	  FROM DARanalytics.tableau.officer_unit_constituent_interactions_all i
	  join DARanalytics.ref.gift_officer_info goi on goi.officer_system_id = i.officer_system_id
												 and i.interaction_actual_date between goi.date_from and goi.date_to
	  --where i.interaction_status = 'Completed'  --added on 7/22/24 after discussion with Rachel and Jeremy
	  group by  i.constituent_system_id, i.officer_system_id --, goi.unit_id (need to take out unit here.  Keeping this strictly an officer - constituent level no matter which job)
       
	   ) sig_i  on sig_i.constituent_system_id = base.constituent_system_id
			   and sig_i.officer_system_id     = base.officer_system_id
	
/*Looking at latest plan information for completed cultivate interactions by all four role categories*/
	left join (
	select ic.constituent_system_id
		 , max(ic.constituent_dim_id) as constituent_dim_id
		 , ic.officer_system_id
		 , max(ic.officer_dim_id) as officer_dim_id
		 --, max(case when ic.officer_interaction_role = 'primary'		then ic.interaction_actual_date else NULL end) as latest_interaction_sig_primary_cultivate
		 --, max(case when ic.officer_interaction_role = 'participant'	then ic.interaction_actual_date else NULL end) as latest_interaction_sig_participant_cultivate
		 --, max(case when ic.officer_interaction_role = 'secondary'		then ic.interaction_actual_date else NULL end) as latest_interaction_sig_secondary_cultivate
		 --, max(case when ic.officer_interaction_role = 'discovery'		then ic.interaction_actual_date else NULL end) as latest_interaction_sig_discovery_cultivate

		 , max(case when ic.officer_interaction_role in ('primary','participant','secondary') then ic.prospect_plan_name else NULL end) as latest_interaction_plan_name_all_cultivate
		 , max(case when ic.officer_interaction_role = 'primary'		then ic.prospect_plan_name else NULL end) as latest_interaction_plan_name_primary_cultivate
		 , max(case when ic.officer_interaction_role = 'participant'	then ic.prospect_plan_name else NULL end) as latest_interaction_plan_name_participant_cultivate
		 , max(case when ic.officer_interaction_role = 'secondary'		then ic.prospect_plan_name else NULL end) as latest_interaction_plan_name_secondary_cultivate

		 , max(case when ic.officer_interaction_role in ('primary','participant','secondary') then ic.prospect_plan_system_id else NULL end) as latest_interaction_plan_id_all_cultivate
		 , max(case when ic.officer_interaction_role = 'primary'		then ic.prospect_plan_system_id else NULL end) as latest_interaction_plan_id_primary_cultivate
		 , max(case when ic.officer_interaction_role = 'participant'	then ic.prospect_plan_system_id else NULL end) as latest_interaction_plan_id_participant_cultivate
		 , max(case when ic.officer_interaction_role = 'secondary'		then ic.prospect_plan_system_id else NULL end) as latest_interaction_plan_id_secondary_cultivate

from (		
	SELECT i.constituent_system_id
		 , i.officer_system_id
		 , i.constituent_dim_id
		 , i.officer_dim_id
		 , i.officer_interaction_role
		 , i.interaction_actual_date
		 , row_number() over (partition by i.constituent_system_id, i.officer_system_id
							  order by i.interaction_actual_date desc, i.interaction_system_id)
					as row_num_cultivate
		 , i.prospect_plan_name	
		 
		 , i.prospect_plan_dim_id
		 , i.prospect_plan_system_id
		 , i.prospect_plan_type
		 , i.prospect_plan_status
	
	  FROM DARanalytics.tableau.officer_unit_constituent_interactions_all i
	  join DARanalytics.ref.gift_officer_info goi on goi.officer_system_id = i.officer_system_id
												 and i.interaction_actual_date between goi.date_from and goi.date_to
	 where i.flag_sig_interaction_cultivate = 1 
	  -- and i.interaction_status = 'completed'
	 -- order by officer_system_id, constituent_system_id, row_num_cultivate
	   ) ic

   where ic.row_num_cultivate = 1
group by  ic.constituent_system_id, ic.officer_system_id --  ic.constituent_dim_id, ic.officer_dim_id,--probably redundant

 ) sig_ic		on sig_ic.constituent_system_id = base.constituent_system_id
			   and sig_ic.officer_system_id     = base.officer_system_id

   /* solicitations by officer */
	
   /* latest managed date*/
   
	/* referrals N=800 t=1s*/
	left join (
select max(r.constituent_dim_id)	as constituent_dim_id
	 , r.constituent_system_id
     , max(r.pgi_fundraiser_dim_id)	as officer_dim_id
	 , r.pgi_fundraiser_system_id	as officer_system_id
	 , max(r.pgi_unit_id)       as unit_id			--we're good here.  The only PGis with multiple sites have no fundraisers
	 , max(r.pgi_unit_name)		as unit_name
	 , convert(date,max(r.start_date))		as latest_referral_date
	 , convert(date,max(isnull(r.stop_date,'2099-12-31')))	as referral_stop_date  --dealing with duplicate PGIs where one has been end-dated to avoid duplication
	 , max(case when isnull(r.stop_date,'2099-12-31') > getdate() then 1 else 0 end) as flag_referral_active
	 , max(case when isnull(r.stop_date,'2099-12-31') > getdate() and pgi_funding_type_code = 'Planned Gift Prospect' then 1 else 0 end) as flag_planned_gift_referral_active
	 , max(pgi_submitter_name) as latest_referrer_name
	 , max(pgi_submitter_system_id) as latest_referrer_system_id
     , max(pgi_submitter_unit_name) as latest_referrer_unit_name
	 , max(pgi_submitter_job_level) as latest_referrer_job_level
	 , max(pgi_funding_type_code) as latest_referral_type
     , max(pgi_referral_note1) as latest_referral_note1
     , max(pgi_referral_note2) as latest_referral_note2
     , max(pgi_referral_note3) as latest_referral_note3
	 , max(PROSPECTGIVINGINTERESTSSYSTEMID) as latest_referral_system_id

FROM (
SELECT [constituent_dim_id]
      ,[constituent_system_id]
      ,[constituent_lookup_id]
      ,[bio_name]
      ,[eval_capacity_rating_desc]
      ,[pm_prospect_status]
      ,[pm_prospect_status_hh]
      ,[affil_school1]
      ,[eval_bwf_planned_gift_rating]
      ,[eval_vcu_planned_giving_score]
      ,[eval_bwf_major_gift_rating]
      ,[PROSPECTGIVINGINTERESTSDIMID]
      ,[PROSPECTGIVINGINTERESTSSYSTEMID]
      ,[SITEDIMID]
      ,[pgi_unit_name]
      ,[pgi_unit_id]
      ,[pgi_default_unit_ldo_name]
      ,[pgi_default_unit_ldo_id]
      ,[pgi_funding_type_code]
      ,[pgi_inclination_level_code]
      ,[pgi_comment]
      ,[pgi_include_spouse]
      ,[row_num]
      ,[row_num_pgsi]
      ,[start_date]
      ,[stop_date]
      ,[flag_all_of_vcu_not_prospect]
      ,[flag_unit_not_prospect]
      ,[pgi_fundraiser_system_id]
	  ,pgi_fundraiser_dim_id
      ,[pgi_fundraiser_name]
      ,[pgi_fundraiser_unit_id]
      ,[pgi_fundraiser_unit_name]
      ,[flag_alum]
      ,[flag_strikezone]
      ,[flag_rp_legacysociety]
      ,[prospect_status_group]
      ,[pgi_referral_note1]
      ,[pgi_referral_note2]
      ,[pgi_referral_note3]
      ,[pgi_fundraiser_name_notgoi]
      ,[pgi_fundraiser_system_id_all]
	  , pgi_submitter_name
      ,[pgi_submitter_system_id]
      ,[pgi_submitter_unit_name]
	  ,pgi_submitter_job_level
  FROM DARanalytics.tableau.unit_all_pgis
  where pgi_inclination_level_code = 'suspect'				 --told by Ben that these are all Referrals
    and pgi_fundraiser_name is not null						 --new field that allows us to do this linking
	and isnull(pgi_referral_note1,'blah') not like '%test%'  --eventually will be cleaned in the data
	and start_date <= getdate()								 --supposedly these will also be cleaned up in the future
	) r
	  group by r.constituent_system_id, r.pgi_fundraiser_system_id --, t.unit_id					 --supposedly these will also be cleaned up in the future

	) ref on ref.constituent_system_id = base.constituent_system_id
	     and ref.officer_system_id		= base.officer_system_id

	--bring in some dates related to referrals....first interaction, DM and PM?TM assignments
	left join DARanalytics.tableau.referral_dates_after_referral refdates on refdates.constituent_system_id = base.constituent_system_id
																		 and refdates.officer_system_id = base.officer_system_id

	left join (
		SELECT constituent_system_id
			 , officer_system_id
			 , max(case when interaction_status = 'Pending' then 1 else 0 end)  as flag_officer_has_pending_interaction
			 , max(case when interaction_status = 'Pending' and prospect_plan_dim_id > 0 then 1 else 0 end)  as flag_officer_has_pending_plan_interaction
			 , min(case when interaction_status = 'Pending' then interaction_actual_date else NULL end)  as mov_ofcr_earliest_pending_interaction_date
			 , max(case when interaction_status = 'Pending' then interaction_actual_date else NULL end)  as mov_ofcr_latest_pending_interaction_date
		  FROM DARanalytics.tableau.officer_unit_constituent_interactions_notcompleted
	  GROUP BY constituent_system_id, officer_system_id
			 ) noncomp on noncomp.constituent_system_id = base.constituent_system_id
					  and noncomp.officer_system_id		= base.officer_system_id


/* where clause for entire select:  this excludes all entities to exclude. i.e. test records - may need to include these for cleanup??*/
WHERE cl_ofcr.constituent_lookup_id not in  ( '8-11092540'		--Chen, Bei
											, '8-10258569'		--Bromley, Ben
											, '8-11114701'		--Helms, Spencer
											, '8-10955008'		--Brandell-Mayers, Rachel
											, '8-10950800'		--Cuevas, Joey	
											, '8-10166428'		--Naumann, Carrie	
											)

/*base.entity_id NOT IN (SELECT entity_id
		                       FROM prma_playground.ref.entities_to_exclude
		                      WHERE flag_training_record = 1)
							  */

END


/* STEP 3. CREATE INDEXES */

	/*clustered index must come first - before all nonclustered indexes - otherwise all nonclustered
	  indexes are deleted upon trying to run a clustered index
	  
	  If there is ever a problem with run time, comment out the indexes to rule them out.  Often they use up too much
	  temp space and bork the procedure*/

	ALTER TABLE DARanalytics.datamart.constituent_officer_level_temp
    ADD CONSTRAINT PK_Constituent_Officer_temp PRIMARY KEY (constituent_system_id, officer_system_id);
/*
CREATE CLUSTERED INDEX ix_officer_constituent_pk ON DARanalytics.datamart.constituent_officer_level_temp
(	officer_dim_id ASC,
	constituent_dim_id ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, SORT_IN_TEMPDB = ON, DROP_EXISTING = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [PRIMARY]
*/
	CREATE NONCLUSTERED INDEX ix_constituent_dim_id
	ON DARanalytics.datamart.constituent_officer_level_temp (constituent_dim_id);
	CREATE NONCLUSTERED INDEX ix_constituent_system_id
	ON DARanalytics.datamart.constituent_officer_level_temp (constituent_system_id);
	CREATE NONCLUSTERED INDEX ix_constituent_lookup_id
	ON DARanalytics.datamart.constituent_officer_level_temp (constituent_lookup_id);
	CREATE NONCLUSTERED INDEX ix_officer_id
	ON DARanalytics.datamart.constituent_officer_level_temp (officer_dim_id);
	CREATE NONCLUSTERED INDEX ix_officer_system_id
	ON DARanalytics.datamart.constituent_officer_level_temp (officer_system_id);
	CREATE NONCLUSTERED INDEX ix_officer_lookup_id
	ON DARanalytics.datamart.constituent_officer_level_temp (officer_lookup_id);
	CREATE NONCLUSTERED INDEX ix_flag_ofcr_referral_recpt
	ON DARanalytics.datamart.constituent_officer_level_temp (flag_ofcr_referral_recipient);
	CREATE NONCLUSTERED INDEX ix_household_id
	ON DARanalytics.datamart.constituent_officer_level_temp (household_id);
	CREATE NONCLUSTERED INDEX ix_household_system_id
	ON DARanalytics.datamart.constituent_officer_level_temp (household_system_id);

	/*Recommended SSMS Indexes*/
	CREATE NONCLUSTERED INDEX ix_ofcr_manage_status
	ON DARanalytics.datamart.constituent_officer_level_temp (pm_ofcr_manage_status)
	INCLUDE (z_last_update, constituent_dim_id, constituent_lookup_id, household_id, officer_name, officer_latest_unit_id, officer_latest_unit_name
			, officer_latest_job_level, officer_latest_avp, flag_active_officer, flag_ofcr_contacted, flag_ofcr_referral_recipient, flag_ofcr_referral_recipient_hh
			, flag_ofcr_currently_managed, flag_ofcr_current_prospect_manager, flag_ofcr_current_team_member, flag_ofcr_current_stewardship_manager
			, flag_ofcr_current_discovery_manager, flag_ofcr_ever_managed, flag_ofcr_managed_current_FY, flag_ofcr_managed_previous_FY, flag_unacted_referral
			, flag_unacted_referral_hh, pm_ofcr_days_managed, pm_ofcr_earliest_manage_date, pm_ofcr_latest_manage_date, pm_ofcr_current_prospect_manager_latest_date
			, pm_ofcr_current_team_member_latest_date, pm_ofcr_current_stewardship_manager_latest_date, pm_ofcr_current_discovery_manager_latest_date);

	CREATE INDEX ix_officer_currently_managed
	ON DARanalytics.datamart.constituent_officer_level_temp (flag_ofcr_currently_managed) 
	INCLUDE (officer_lookup_id, officer_name, officer_latest_unit_name, officer_latest_unit_name_short, officer_latest_unit_name_campaign
			, officer_latest_avp, flag_ofcr_current_prospect_manager, flag_ofcr_current_team_member, flag_ofcr_current_stewardship_manager
			, flag_ofcr_current_discovery_manager, pm_ofcr_days_managed);



/* STEP 4. Basic Error Checking and Logging*/
select  @rowsLoaded = count(*) from datamart.constituent_officer_level_temp

if @rowsLoaded >10000
  BEGIN
   IF  EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'datamart.constituent_officer_level') AND type in (N'U'))
				 DROP TABLE datamart.constituent_officer_level
	   exec sp_rename 'datamart.constituent_officer_level_temp', 'constituent_officer_level'
	select @errorMessage = 'Successful overwrite of table ' + @destTable
   -- exec [DARanalytics].[dbo].[sp_logTableLoad] @destTable, N'finish', @startTime, N'Successful build', @rowsLoaded;
  END

else
  BEGIN
	select @errorMessage = 'constituent_officer_level_temp seems off - go investigate: ' + @destTable
	--exec [DARanalytics].[dbo].[sp_logTableLoad] @destTable, N'finish', @startTime, @errorMessage, @rowsLoaded;
  END

  	--rename the PK so the next time it is run the temp table won't have the same name and bomb.
	EXEC sp_rename N'datamart.PK_Constituent_Officer_temp', N'PK_Constituent_Officer'

END --of SP
GO

