USE [DARanalytics]
GO

/****** Object:  StoredProcedure [dbo].[uspBuildHouseholdLevelTable]    Script Date: 10/29/2026 11:23:51 AM ******/
SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO







CREATE PROCEDURE [dbo].[uspBuildHouseholdLevelTable] 
AS BEGIN
/* 
Household Data Set
Created by Gary Thompson [GAT] on 6/13/2023
*/

/************************************************* OVERVIEW **********************************************************
This table is a repository of most of the measures used by DAR Analytics in its
standard reporting and analyses to document household level fields. 
Variables have been given descriptive names, but for more information about each variable and its calculation,
consult .....

NOTE: 
All changes to this table should be vetted through 
the Data Architect of DAR or Gordon
**************************************************************************************************************************
10.28.26 -GAT fixed break of name change from events to campus visit for principal giving measure
10.19.26 -GAT added primary_HH_constituent_id,  primary_HH_lookup_id, primary_hh_email, primary_hh_phone
10.15.26 -GAT modified eval_vcu_planned_giving_tier_hh
09.16.26 -GAT added mov_earliest_pending_interaction_date_hh, mov_latest_pending_interaction_date_hh
09.04.26 -GAT added flag_has_pending_interaction_hh, flag_has_pending_plan_interaction_hh
09.01.26 -GAT added flag_is_principal_gift_prospect_hh
06.29.26 -GAT added engagement_latest_email_click_through_date_hh
06.26.26 -GAT added pm_latest_past_committee_end_date_hh, pm_num_volunteer_tminus1_5 for NYU binning
06.24.26 -GAT added flag_ever_radar_user_hh
06.22.26 -GAT added    flag_attribute_volunteer_hh
					 , flag_committee_member_current_hh
					 , engagement_latest_event_attendance_date_hh
					 , pm_num_events_tminus0_hh
					 , pm_num_volunteer_tminus0_hh
06.15.26 -GAT added nyu_bin_hh
05.07.26 -GAT added revised eval_VCU_principal_giving_rank_hh
05.07.26 - WW added the eval_record_standard_metal_hh from CL to households (applies the best of either constituent to the hh level)
05.06.26 -GAT added principal gift points|score|rank and components in case HH expanded to be best in each category
05.06.26 -GAT added flag_rnl_interest_has_DAF_hh to bring it back into the CL code
03.24.26 -GAT added eval_overall_prospect_rank_hh (HH ranking) and eval_overall_prospect_rank_cl_hh (best rank of the individuals)
03.20.26 -GAT added eval_default_segment_grid_rank_hh
03.05.26 -GAT added foundation manager hh
12.04.25 -GAT added flag_WF_DAF_indicator_hh
10.07.25 -GAT added flag_parent_current_hh, flag_parent_constituency_hh, flag_parent_past_constituency_hh
09.17.25 -GAT added flag_VCU_employees_to_exclude_hh - to not track them post campaign launch event
08.22.25 -GAT added SSMS recommended index
07.10.25 -GAT and GB Added pm_pgi_PG_unitSA_short_name_list_hh and pm_pgi_PG_unitSA_inclination_list_hh
04.14.25 -GAT Added flag_mov_allofficers_cultivate_in_last365_hh, mov_allofficers_latest_completed_sig_all_interaction_cultivate_hh
04.08.25 -GAT Updated eval_vcu_planned_giving_tier_hh calculation to better represent who should be Tier 1 (all suspects with/without fundraisers and positives)
04.08.25 -GAT Added flag_pgi_PG_VCU_NAP_hh,	flag_pgi_PG_unit_NAP_hh	
03.21.25 -GAT Added lots of avp_manager fields for all the top units
03.07.25 -GAT Added flag_individual_hh
02.25.25 -GAT Removed the 3 MPAR DCUs from the LAGODEO Connectedness calculations & removed segments without LAGOs (SEM, Provost, et al)
02.24.25 -GAT modified household names and pharma names to handle situations where both HH members are deceased
02.20.25 -GAT added flag_HH_has_PM_and_worked_by_VCU_365
02.19.25 -GAT added flag_pgi_PG_referral_hh, flag_pgi_PG_VCU_future_hh	
01.08.25 -GAT added num_payments_future_scheduled_hh
01.03.25 -GAT added pm_LAGODEO_top unit fields
12.02.24 -GAT added flag_di_vip_hh
11.27.24 -GAT Added flag_campaign_primary_transaction_donor_hh
11.22.24 -GAT Added gvg_milestone_new_donor_hh_date, gvg_milestone_50k_hh_date,	gvg_milestone_1M_hh_date
				gvg_milestone_campaign_new_donor_hh_date, gvg_milestone_campaign_50k_hh_date,	gvg_milestone_campaign_1M_hh_date
11.07.24 -GAT Added pm_servicearea_connectedness_list_hh, pm_servicearea_connectedness_num_hh, pm_servicearea_connectedness_top_hh	
10.01.24 -GAT Added Tier 4 to the PG tiering to look at those with some score
09.27.24 -GAT Added Alumni Relations to eval_campaign_segment_hh
09.15.24 -GAT Changed household_lookup_id to be NULLABLE.  Not sure why one would ever pop up but they seem to.
09.05.24 -GAT Added in household_system_id
09.05.24 -GAT Added in an update statement at the end to update CL with these CHL values.  Seems to work and I can see it being useful elsewhere.
08.22.24 -GAT Added in flag_has_active_prospect_plan_hh
08.21.24 -GAT Removed BWF from PG Tier calculations
06.18.24 -GAT Added flag_vcu_facstaff_retired_hh and flag_vcu_facstaff_current_hh
05.13.24 -GAT Added Connection letters to the unit connection lists
04.25.24 -GAT Tweaked eval_campaign_segment_hh, added pm_unit_lago_connectedness_desc_top_hh
04.24.24 -GAT added in eval_campaign_segment_hh, added eval_capacity_rating_short_sort_hh
04.17.24 -GAT added pm_unit_lago fields
04.15.24 -GAT added pm_stage_calculated_hh
04.12.24 -GAT added mov_latest_lago_interaction_date_hh
12.11.23 -GAT add in count of HH members - num_hh_members
06.13.23 -GAT Version 1
**************************************************************************************************************************/

	declare 
		@filedatestring nchar(8),
		@destTable nvarchar(30),
		@startTime datetime,
		@rowsLoaded int,
		@errorMessage nvarchar(1000)
	
	set @startTime = getDate();
	set @errorMessage = N'';
	set @destTable = 'datamart.constituent_household_level';

	select @filedatestring = convert(nchar(8), getDate(), 112)

	--exec [DARanalytics].[dbo].[sp_logTableLoad] @destTable, N'start', @startTime, N'NoFileSource';


/* STEP 1. DELETE TABLE, IF ALREADY EXISTS */

BEGIN
	IF  EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[datamart].[constituent_household_level_temp]') AND type in (N'U'))
		DROP TABLE [datamart].[constituent_household_level_temp]

CREATE TABLE [datamart].[constituent_household_level_temp](
	z_last_update				datetime NOT NULL,
	household_system_id			uniqueidentifier NOT NULL,
	household_id				int NOT NULL,
	household_lookup_id			nvarchar(100) NULL,		--should be NOT NULL but occasionally someone in CL has a household_lookup_id of NULL
	bio_record_type_hh			nvarchar(20) NULL,
	bio_constituency_list_hh	nvarchar(4000) NULL,
	num_hh_members				int NOT NULL,
	num_hh_living_members		int NOT NULL,
	sum_primary_hh_members		int NOT NULL,
	bio_name_informal_hh		nvarchar(700) NULL,
	bio_name_informal_hh_last	nvarchar(700) NOT NULL,
	bio_name_informal_hh_pharma	nvarchar(700) NOT NULL,

	pm_unit_connectedness_list_hh		nvarchar (500) NULL,
	pm_unit_connectedness_list_short_hh	nvarchar (500) NULL,
	pm_unit_connectedness_num_hh		smallint NOT NULL,
	pm_unit_connectedness_top_hh		nvarchar (50) NULL,
	pm_unit_connectedness_avp_manager_top_hh		nvarchar (50) NULL,

	pm_unit_connectedness_list_other_hh	nvarchar (500) NULL,
	pm_unit_connectedness_num_other_hh	smallint NOT NULL,
	pm_unit_connectedness_top_other_hh	nvarchar (50) NULL,
	pm_unit_connectedness_other_avp_manager_top_hh	nvarchar (50) NULL,

	pm_unit_lago_connectedness_list_hh			nvarchar (500) NULL,
	pm_unit_lago_connectedness_list_short_hh	nvarchar (500) NULL,
	pm_unit_lago_connectedness_num_hh			smallint NOT NULL,
	pm_unit_lago_connectedness_top_hh			nvarchar (50) NULL,
	pm_unit_lago_connectedness_desc_top_hh		nvarchar (25) NULL,
	pm_unit_lago_connectedness_avp_manager_top_hh		nvarchar (50) NULL,

	pm_unit_AG_connectedness_list_hh			nvarchar (500) NULL,
	pm_unit_AG_connectedness_list_short_hh		nvarchar (500) NULL,
	pm_unit_AG_connectedness_num_hh				smallint NOT NULL,
	pm_unit_AG_connectedness_top_hh				nvarchar (50) NULL,
	pm_unit_AG_connectedness_desc_top_hh		nvarchar (25) NULL,
	pm_unit_AG_connectedness_avp_manager_top_hh		nvarchar (50) NULL,

	pm_unit_AG_AB_connectedness_list_hh			nvarchar (500) NULL,
	pm_unit_AG_AB_connectedness_list_short_hh	nvarchar (500) NULL,
	pm_unit_AG_AB_connectedness_num_hh			smallint NOT NULL,
	pm_unit_AG_AB_connectedness_top_hh			nvarchar (50) NULL,
	pm_unit_AG_AB_connectedness_desc_top_hh		nvarchar (25) NULL,
	pm_unit_AG_AB_connectedness_avp_manager_top_hh		nvarchar (50) NULL,

	pm_servicearea_connectedness_list_hh		nvarchar (500) NULL,
	pm_servicearea_connectedness_num_hh			smallint NOT NULL,
	pm_servicearea_connectedness_top_hh			nvarchar (50) NULL,
	pm_servicearea_connectedness_avp_manager_top_hh			nvarchar (50) NULL,

	pm_LAGODEO_connectedness_list_hh			nvarchar (1000) NULL,
	pm_LAGODEO_connectedness_num_hh				smallint NOT NULL,
	pm_LAGODEO_connectedness_top_hh				nvarchar (100) NULL,
	pm_LAGODEO_connectedness_desc_top_hh		nvarchar (25) NULL,
	pm_LAGODEO_connectedness_avp_manager_top_hh	nvarchar (50) NULL,

	pm_philDEO_connectedness_list_hh			nvarchar (1000) NULL,
	pm_philDEO_connectedness_num_hh				smallint NOT NULL,
	pm_philDEO_connectedness_top_hh				nvarchar (100) NULL,
	pm_philDEO_connectedness_desc_top_hh		nvarchar (25) NULL,
	pm_philDEO_connectedness_avp_manager_top_hh	nvarchar (50) NULL,

	pm_pgi_PG_unitSA_name_short_list_hh			nvarchar (500) NULL,
	pm_pgi_PG_unitSA_inclination_list_hh		nvarchar (500) NULL,

	gvg_recog_raised_life_hh		money NOT NULL,
	gvg_recog_received_life_hh		money NOT NULL,
	gvg_recog_raised_campaign_hh	money NOT NULL,
	gvg_recog_received_campaign_hh	money NOT NULL,
	gvg_recog_raised_MIRcampaign_hh	money NOT NULL,
	gvg_recog_received_MIRcampaign_hh	money NOT NULL,
	gvg_recog_raised_tminus0_5_hh	money NOT NULL,
	gvg_recog_received_tminus0_5_hh	money NOT NULL,

	gvg_recog_raised_tminus0_hh		money NOT NULL,
	gvg_recog_raised_tminus1_hh		money NOT NULL,
	gvg_recog_raised_tminus2_hh		money NOT NULL,
	gvg_recog_raised_tminus3_hh		money NOT NULL,
	gvg_recog_raised_tminus4_hh		money NOT NULL,
	gvg_recog_raised_tminus5_hh		money NOT NULL,
	gvg_recog_received_tminus0_hh	money NOT NULL,
	gvg_recog_received_tminus1_hh	money NOT NULL,
	gvg_recog_received_tminus2_hh	money NOT NULL,
	gvg_recog_received_tminus3_hh	money NOT NULL,
	gvg_recog_received_tminus4_hh	money NOT NULL,
	gvg_recog_received_tminus5_hh	money NOT NULL,

	flag_has_used_daf_hh		tinyint NOT NULL,
	flag_has_used_ff_hh			tinyint NOT NULL,
	flag_has_pg_vehicle_hh		tinyint NOT NULL,
	flag_has_revocable_pg_hh	tinyint NOT NULL,
	flag_campaign_primary_transaction_donor_hh tinyint NOT NULL,

	gvg_recog_raised_tminus0_5_hh_avg	money NOT NULL,
	gvg_recog_received_tminus0_5_hh_avg	money NOT NULL,
	gvg_10yrs_num_yrs_recog_hh			int NOT NULL,

	gvg_recog_first_hh					money NULL,
	gvg_recog_first_date_hh				date NULL,
	gvg_recog_first_FY_hh				int NULL,
	gvg_recog_latest_date_hh			date NULL,
	gvg_recog_latest_FY_hh				int NULL,
	gvg_recog_raised_life_hh_6bin		smallint NULL,
    gvg_recog_raised_life_hh_6bin_desc	nvarchar(30) NULL,
	gvg_milestone_new_donor_hh_date		date NULL,
	gvg_milestone_50k_hh_date			date NULL,
	gvg_milestone_1M_hh_date			date NULL,
	gvg_milestone_campaign_new_donor_hh_date	date NULL,
	gvg_milestone_campaign_50k_hh_date			date NULL,
	gvg_milestone_campaign_1M_hh_date			date NULL,
	num_payments_future_scheduled_hh	int NULL,

	eval_bwf_connectedness_hh			nvarchar(50) NULL,
	eval_bwf_major_gift_rating_hh		nvarchar(50) NULL,
	eval_vcu_connectedness_desc_hh		nvarchar(50) NULL,
	eval_vcu_connectedness_score_hh		int NULL,

	eval_vcu_planned_giving_score_hh	int NULL,
	eval_vcu_planned_giving_score_SQL_hh int NULL,
	eval_vcu_planned_giving_tier_hh     nvarchar(30) NULL,
	eval_capacity_rating_desc_sort_hh	nvarchar(50) NULL,
	eval_capacity_rating_desc_short_sort_hh	nvarchar(50) NULL,
	eval_campaign_segment_hh			nvarchar(25) NULL,
	eval_default_segment_grid_rank_hh	smallint NULL,
	eval_overall_prospect_rank_cl_hh	int NULL,				--this is the lowest rank of each of the individuals
	eval_overall_prospect_rank_hh		int NULL,				--this is the best rank of the HH by HHs
	eval_nyu_bin_hh						tinyint NULL,

	pm_prospect_status_hh				nvarchar(50) NULL,
	pm_stage_calculated_hh				nvarchar(30) NULL,

	mov_latest_lago_interaction_date_hh date NULL,
	flag_mov_allofficers_cultivate_in_last365_hh smallint NULL,
	mov_allofficers_latest_completed_sig_all_interaction_cultivate_hh date NULL,
	mov_allofficers_latest_completed_sig_primary_interaction_cultivate_hh date NULL,
    mov_allofficers_latest_completed_sig_secondary_interaction_cultivate_hh date NULL,
    mov_allofficers_latest_completed_sig_participant_interaction_cultivate_hh date NULL,
    mov_allofficers_latest_completed_sig_discovery_interaction_cultivate_hh date NULL,
	sol_num_ask_rolling_365x2_hh		int NOT NULL,
	sol_sum_ask_rolling_365x2_hh			money NULL,
	sol_sum_expected_ask_rolling_365x2_hh	money NULL,
	sol_sum_both_ask_rolling_365x2_hh		money NULL,
	flag_ask_rolling_365x2_hh			tinyint NOT NULL,
	flag_HH_has_PM_and_worked_by_VCU_365 tinyint NOT NULL,

	flag_living_hh						tinyint NOT NULL,
	flag_individual_hh					tinyint NOT NULL,
	flag_strikezone_hh					tinyint NOT NULL,
 	flag_strikezone_new_hh				tinyint NOT NULL,
	flag_double_alum_hh					tinyint NOT NULL,
	flag_alum_hh						tinyint NOT NULL,
	flag_di_vip_hh						tinyint NOT NULL,
	flag_managed_currently_hh			tinyint NOT NULL,
    flag_managed_prospect_currently_hh	tinyint NOT NULL,
    flag_managed_team_currently_hh		tinyint NOT NULL,
    flag_managed_stewardship_currently_hh		tinyint NOT NULL,
    flag_managed_discovery_currently_hh			tinyint NOT NULL,
    flag_managed_foundation_currently_hh		tinyint NOT NULL,
    flag_any_completed_interaction_last_365_hh	tinyint NOT NULL,
	flag_any_completed_sig_interaction_last_365_hh tinyint NOT NULL,
    flag_any_completed_SPV_last_365_hh	tinyint NOT NULL,
    flag_any_engagement_last_365_hh		tinyint NOT NULL,
    flag_any_engagement_campaign2030_hh	tinyint NOT NULL,
    flag_pgi_NAP_all_VCU_active_hh		tinyint NOT NULL,
    flag_pgi_referral_active_hh			tinyint NOT NULL,
    flag_pgi_planned_gift_active_hh		tinyint NOT NULL,
	flag_pgi_PG_referral_hh				tinyint NOT NULL,
    flag_pgi_PG_VCU_future_hh			tinyint NOT NULL,
	flag_pgi_PG_VCU_NAP_hh				tinyint NOT NULL,
	flag_pgi_PG_unit_NAP_hh				tinyint NOT NULL,
	flag_vcu_facstaff_current_hh		tinyint NOT NULL,
	flag_vcu_facstaff_retired_hh		tinyint NOT NULL,
	flag_has_active_prospect_plan_hh	tinyint NOT NULL,
	flag_VCU_employees_to_exclude_hh	tinyint NOT NULL,
	flag_has_nokids_GB_hh				tinyint NOT NULL,

	flag_TP_parent_hh					tinyint NULL,
    flag_TP_foundation_hh				tinyint NULL,
    flag_TP_complex_assets_hh			tinyint NULL,
    flag_TP_DAF_hh						tinyint NULL,
	flag_parent_current_hh				tinyint NULL,
	flag_parent_constituency_hh			tinyint NULL,
    flag_parent_past_constituency_hh	tinyint NULL,
	flag_WF_DAF_indicator_hh			tinyint NULL,
	flag_rnl_interest_has_DAF_hh		tinyint NULL,
	flag_ever_radar_user_hh				tinyint NULL,

	eval_VCU_principal_giving_points_hh	smallint NULL,
	eval_VCU_principal_giving_score_hh	smallint NULL,
	eval_VCU_principal_giving_rank_hh_lame	int NULL,
	eval_VCU_principal_giving_rank_hh		int NULL,

	eval_pringiv_1_highcapacity_hh		tinyint NULL,
	eval_pringiv_2_daf_stock_hh			tinyint NULL,	
	eval_pringiv_4_old_hh				tinyint NULL,
	eval_pringiv_5_alum_fac_hh			tinyint NULL,
	eval_pringiv_6_local_hh				tinyint NULL,
	eval_pringiv_8_managed_hh			tinyint NULL,	
	eval_pringiv_9_campus_visit_hh		tinyint NULL,	
	eval_pringiv_10_interactions_hh		tinyint NULL,		
	eval_pringiv_11_bigmoney_hh			tinyint NULL,
	eval_pringiv_12_committee_hh		tinyint NULL,
	eval_pringiv_13_spouse_engagement_hh		tinyint NULL,	
 	eval_pringiv_14_majorgift_hh		tinyint NULL,		
	eval_pringiv_17_rao_hh				tinyint NULL,

	eval_record_standard_metal_hh		nvarchar(100) NULL,
	flag_attribute_volunteer_hh			tinyint NULL,
	flag_committee_member_current_hh	tinyint NULL,
	engagement_latest_event_attendance_date_hh	date NULL,
	engagement_latest_email_click_through_date_hh date NULL,
	pm_num_events_tminus0_hh			smallint NULL,
	pm_num_volunteer_tminus0_hh			smallint NULL,
	pm_num_volunteer_tminus1_5_hh		smallint NULL,
	pm_latest_past_committee_end_date_hh date NULL,
	num_email_n_interactions_last24months_hh	smallint NULL,
	num_social_media_engagement_last24months_hh smallint NULL,
	flag_award_recipient_hh				tinyint NULL,
	flag_is_principal_gift_prospect_hh  tinyint NULL,
	flag_has_pending_interaction_hh		tinyint NULL,
	flag_has_pending_plan_interaction_hh	tinyint NULL,
	mov_earliest_pending_interaction_date_hh	date NULL, 
	mov_latest_pending_interaction_date_hh		date NULL,
	primary_HH_constituent_id					uniqueidentifier NULL,
    primary_HH_lookup_id						nvarchar(100) NULL,
    primary_hh_email					nvarchar(100) NULL,
    primary_hh_phone					nvarchar(100) NULL

) ON [PRIMARY]	

/* STEP 2. LOAD DATA INTO TABLE */
   INSERT INTO DARanalytics.datamart.constituent_household_level_temp

SELECT GETDATE() AS z_last_update
	 , cl1.household_system_id
     , cl1.household_id
	 , cl1.household_lookup_id
	 , min(cl1.bio_record_type) as bio_record_type_hh
	 , max(cl1.bio_constituency_list) as bio_constituency_list_hh  --need to add in spouse_constituency list and do some magic with string_split
	 , count(distinct constituent_system_id) as num_hh_members
	 , sum(flag_living) as num_hh_living_members
	 , sum(flag_is_primary_hh_member) as sum_primary_hh_members
	 , max(names.bio_name_informal_hh)	as bio_name_informal_hh
	 , max(case 
	        when cl1.bio_record_type = 'Organization' then names.bio_name_informal_hh
	 	   --one HH member only (living or deceased)
		    when spouse_system_id is null then concat(bio_lastname, ', ', bio_firstname, case when bio_death_date is not null then ' (D)' else '' end)  --gotta take into account 3+ person HHs with a deceased spouse

	    --2 HH members both deceased & single HH member deceased
	        when cl1.flag_is_primary_hh_member = 1 and cl1.flag_living = 0 and cl1.flag_spouse_living=0 and bio_lastname = spouse_lastname  then concat(bio_lastname, ', ', bio_firstname, case when bio_death_date is not null then ' (D)' else '' end, ' and ', spouse_firstname, case when spouse_death_date is not null then ' (D)' else '' end)
			when cl1.flag_is_primary_hh_member = 1 and cl1.flag_living = 0 and cl1.flag_spouse_living=0 and bio_lastname <> isnull(spouse_lastname,'zzz') then concat(bio_lastname, ', ', bio_firstname, case when bio_death_date is not null then ' (D)' else '' end, ' and ', spouse_lastname, ', ', spouse_firstname, case when spouse_death_date is not null then ' (D)' else '' end)

		--2 HH members, one living HH member and one deceased HH member
		    when cl1.flag_living = 1 and spouse_death_date is not null and bio_lastname = spouse_lastname  then concat(bio_lastname, ', ', bio_firstname, case when bio_death_date is not null then ' (D)' else '' end, ' and ', spouse_firstname, case when spouse_death_date is not null then ' (D)' else '' end)  --gotta take into account 3+ person HHs with a deceased spouse
		    when cl1.flag_living = 1 and spouse_death_date is not null and bio_lastname <> spouse_lastname then concat(bio_lastname, ', ', bio_firstname, case when bio_death_date is not null then ' (D)' else '' end, ' and ', spouse_lastname, ', ', spouse_firstname, case when spouse_death_date is not null then ' (D)' else '' end)  --gotta take into account 3+ person HHs with a deceased spouse

		--both living 
			when flag_is_primary_hh_member = 1 and bio_lastname = spouse_lastname  then concat(bio_lastname, ', ', bio_firstname, case when bio_death_date is not null then ' (D)' else '' end, ' and ', spouse_firstname, case when spouse_death_date is not null then ' (D)' else '' end)
			when flag_is_primary_hh_member = 1 and bio_lastname <> spouse_lastname then concat(bio_lastname, ', ', bio_firstname, case when bio_death_date is not null then ' (D)' else '' end, ' and ', spouse_lastname, ', ', spouse_firstname, case when spouse_death_date is not null then ' (D)' else '' end)
		
		--gotta take into account HHs with no hh member flagged as primary 
			when flag_is_primary_hh_member = 0 and spouse_system_id is null then concat('#', bio_lastcommafirstname)
		--	when flag_is_primary_hh_member = 0 then concat('__', bio_lastcommafirstname)  
	        when flag_is_primary_hh_member = 0 and bio_lastname = spouse_lastname  then concat('#',spouse_lastname, ', ', spouse_firstname, case when spouse_death_date is not null then ' (D)' else '' end, ' and ', bio_firstname, case when bio_death_date is not null then ' (D)' else '' end)
		    when flag_is_primary_hh_member = 0 and bio_lastname <> spouse_lastname then concat('#',spouse_lastname, ', ', spouse_firstname, case when spouse_death_date is not null then ' (D)' else '' end, ' and ', bio_lastname, ', ', bio_firstname, case when bio_death_date is not null then ' (D)' else '' end)
			else 
			'ZZZ- logic flaw' end)				as bio_name_informal_hh_last	

--Very specific naming for Pharma	
	, max(case

			when cl1.bio_record_type = 'Organization' then names.bio_name_informal_hh

		--Single Person HHs
			when spouse_system_id is null then concat(bio_firstname, ' ', case when bio_middle_initial='' then '' else concat(bio_middle_initial,' ') end, bio_lastname)
	
	--How to name them if both HH members are deceased
	        when flag_is_primary_hh_member = 1 and cl1.flag_living = 0 and spouse_death_date is not null and bio_lastname = spouse_lastname  
																										   then concat(bio_firstname, ' ', case when bio_middle_initial='' then '& ' else concat(bio_middle_initial,' & ') end, spouse_firstname, ' ',						case when spouse_middle_initial in ('.',' ') then '' else concat(spouse_middle_initial,' ') end, bio_lastname)
			when flag_is_primary_hh_member = 1 and cl1.flag_living = 0 and spouse_death_date is not null and bio_lastname <> spouse_lastname 
																										   then concat(bio_firstname, ' ', case when bio_middle_initial='' then ''   else concat(bio_middle_initial,' ')   end, bio_lastname, ' & ', spouse_firstname, ' ', case when spouse_middle_initial in ('.',' ') then '' else concat(spouse_middle_initial,' ') end, spouse_lastname)
	--Single Living Person HHs with deceased spouse
			--when cl1.flag_living = 1 and (spouse_system_id is null OR spouse_death_date is not null)   then bio_name_sans_D
			when cl1.flag_living = 1 and spouse_death_date is not null and bio_lastname = spouse_lastname  
																										   then concat(bio_firstname, ' ', case when bio_middle_initial='' then '& ' else concat(bio_middle_initial,' & ') end, spouse_firstname, ' ',						case when spouse_middle_initial in ('.',' ') then '' else concat(spouse_middle_initial,' ') end, bio_lastname)
			when cl1.flag_living = 1 and spouse_death_date is not null and bio_lastname <> spouse_lastname 
																										   then concat(bio_firstname, ' ', case when bio_middle_initial='' then ''   else concat(bio_middle_initial,' ')   end, bio_lastname, ' & ', spouse_firstname, ' ', case when spouse_middle_initial in ('.',' ') then '' else concat(spouse_middle_initial,' ') end, spouse_lastname)
	--If both HH members are lving 
	--Female Alums 
			when flag_alum = 1				   and bio_gender='Female' and bio_lastname = spouse_lastname  then concat(bio_firstname, ' ', case when bio_middle_initial='' then '& ' else concat(bio_middle_initial,' & ') end, spouse_firstname, ' ',						case when spouse_middle_initial='' then '' else concat(spouse_middle_initial,' ') end, bio_lastname)
	        when flag_alum = 1				   and bio_gender='Female' and bio_lastname <> spouse_lastname then concat(bio_firstname, ' ', case when bio_middle_initial='' then ''   else concat(bio_middle_initial,' ')   end, bio_lastname, ' & ', spouse_firstname, ' ', case when spouse_middle_initial='' then '' else concat(spouse_middle_initial,' ') end, spouse_lastname)
	--Male Alums 
			when flag_alum = 1										   and bio_lastname = spouse_lastname  then concat(bio_firstname, ' ', case when bio_middle_initial='' then '& ' else concat(bio_middle_initial,' & ') end, spouse_firstname, ' ',						case when spouse_middle_initial='' then '' else concat(spouse_middle_initial,' ') end, bio_lastname)
	        when flag_alum = 1										   and bio_lastname <> spouse_lastname then concat(bio_firstname, ' ', case when bio_middle_initial='' then ''   else concat(bio_middle_initial,' ')   end, bio_lastname, ' & ', spouse_firstname, ' ', case when spouse_middle_initial='' then '' else concat(spouse_middle_initial,' ') end, spouse_lastname)
	 
	--Female Faculty      
		    when flag_vcu_facstaff_current = 1 and bio_gender='Female' and bio_lastname =  spouse_lastname then concat(bio_firstname, ' ', case when bio_middle_initial='' then '& ' else concat(bio_middle_initial,' & ') end, spouse_firstname, ' ',						case when spouse_middle_initial='' then '' else concat(spouse_middle_initial,' ') end, bio_lastname)
	        when flag_vcu_facstaff_current = 1 and bio_gender='Female' and bio_lastname <> spouse_lastname then concat(bio_firstname, ' ', case when bio_middle_initial='' then ''   else concat(bio_middle_initial,' ')   end, bio_lastname, ' & ', spouse_firstname, ' ', case when spouse_middle_initial='' then '' else concat(spouse_middle_initial,' ') end, spouse_lastname)
	        when flag_vcu_facstaff_retired = 1 and bio_gender='Female' and bio_lastname =  spouse_lastname then concat(bio_firstname, ' ', case when bio_middle_initial='' then '& ' else concat(bio_middle_initial,' & ') end, spouse_firstname, ' ',						case when spouse_middle_initial='' then '' else concat(spouse_middle_initial,' ') end, bio_lastname)
	        when flag_vcu_facstaff_retired = 1 and bio_gender='Female' and bio_lastname <> spouse_lastname then concat(bio_firstname, ' ', case when bio_middle_initial='' then ''   else concat(bio_middle_initial,' ')   end, bio_lastname, ' & ', spouse_firstname, ' ', case when spouse_middle_initial='' then '' else concat(spouse_middle_initial,' ') end, spouse_lastname)
	--Male Faculty only
			when flag_vcu_facstaff_current = 1						   and bio_lastname =  spouse_lastname then concat(bio_firstname, ' ', case when bio_middle_initial='' then '& ' else concat(bio_middle_initial,' & ') end, spouse_firstname, ' ',						case when spouse_middle_initial='' then '' else concat(spouse_middle_initial,' ') end, bio_lastname)
	        when flag_vcu_facstaff_current = 1						   and bio_lastname <> spouse_lastname then concat(bio_firstname, ' ', case when bio_middle_initial='' then ''   else concat(bio_middle_initial,' ')   end, bio_lastname, ' & ', spouse_firstname, ' ', case when spouse_middle_initial='' then '' else concat(spouse_middle_initial,' ') end, spouse_lastname)
	        when flag_vcu_facstaff_retired = 1						   and bio_lastname =  spouse_lastname then concat(bio_firstname, ' ', case when bio_middle_initial='' then '& ' else concat(bio_middle_initial,' & ') end, spouse_firstname, ' ',						case when spouse_middle_initial='' then '' else concat(spouse_middle_initial,' ') end, bio_lastname)
	        when flag_vcu_facstaff_retired = 1						   and bio_lastname <> spouse_lastname then concat(bio_firstname, ' ', case when bio_middle_initial='' then ''   else concat(bio_middle_initial,' ')   end, bio_lastname, ' & ', spouse_firstname, ' ', case when spouse_middle_initial='' then '' else concat(spouse_middle_initial,' ') end, spouse_lastname)

	--Two Person HHs without alums or faculty with at least one person identified as Female
			when								   bio_gender='Female' and bio_lastname =  spouse_lastname then concat(bio_firstname, ' ', case when bio_middle_initial='' then '& ' else concat(bio_middle_initial,' & ') end, spouse_firstname, ' ',						case when spouse_middle_initial='' then '' else concat(spouse_middle_initial,' ') end, bio_lastname)
			when								   bio_gender='Female' and bio_lastname <> spouse_lastname then concat(bio_firstname, ' ', case when bio_middle_initial='' then ''   else concat(bio_middle_initial,' ')   end, bio_lastname, ' & ', spouse_firstname, ' ', case when spouse_middle_initial='' then '' else concat(spouse_middle_initial,' ') end, spouse_lastname)

	--Two Person HHs without alums or faculty with no one identified as Female
			when														   bio_lastname = spouse_lastname  then concat(bio_firstname, ' ', case when bio_middle_initial='' then '& ' else concat(bio_middle_initial,' & ')  end, spouse_firstname, ' ',						case when spouse_middle_initial='' then '' else concat(spouse_middle_initial,' ') end, bio_lastname)
			when														   bio_lastname <> spouse_lastname then concat(bio_firstname, ' ', case when bio_middle_initial='' then ''   else concat(bio_middle_initial,' ')   end, bio_lastname, ' & ', spouse_firstname, ' ', case when spouse_middle_initial='' then '' else concat(spouse_middle_initial,' ') end, spouse_lastname)
		
			else 'ZZZ Bad Logic' end)				as bio_name_informal_hh_pharma
	 , max(units_hh.unit_connectedness_list_hh)							as pm_unit_connectedness_list_hh
	 , max(units_hh.unit_connectedness_list_short_hh)					as pm_unit_connectedness_list_short_hh
	 , max(isnull(units_hh.unit_connectedness_num_hh,0))				as pm_unit_connectedness_num_hh 
	 , max(units_hh.unit_connectedness_top_hh)							as pm_unit_connectedness_top_hh
	 , max(units_hh.unit_connectedness_avp_manager_top_hh)				as pm_unit_connectedness_avp_manager_top_hh

	 , max(units_other_hh.unit_connectedness_list_other_hh)				as pm_unit_connectedness_list_other_hh
	 , max(isnull(units_other_hh.unit_connectedness_num_other_hh,0))	as pm_unit_connectedness_num_other_hh
	 , max(units_other_hh.unit_connectedness_other_top_hh)				as pm_unit_connectedness_top_other_hh
	 , max(units_other_hh.unit_connectedness_other_avp_manager_top_hh)	as pm_unit_connectedness_top_other_avp_manager_hh

	 , max(units_lago.unit_lago_connectedness_list_hh)					as pm_unit_lago_connectedness_list_hh	
	 , max(units_lago.unit_lago_connectedness_list_short_hh)			as pm_unit_lago_connectedness_list_short_hh
	 , max(isnull(units_lago.unit_lago_connectedness_num_hh,0))			as pm_unit_lago_connectedness_num_hh
	 , max(units_lago.unit_lago_connectedness_top_hh)					as pm_unit_lago_connectedness_top_hh
	 , max(units_lago.unit_lago_connectedness_desc_top_hh)				as pm_unit_lago_connectedness_desc_top_hh
	 , max(units_lago.unit_lago_connectedness_avp_manager_top_hh)		as pm_unit_lago_connectedness_avp_manager_top_hh

	 , max(units_AG.unit_AG_connectedness_list_hh)						as pm_unit_AG_connectedness_list_hh	
	 , max(units_AG.unit_AG_connectedness_list_short_hh)				as pm_unit_AG_connectedness_list_short_hh
	 , max(isnull(units_AG.unit_AG_connectedness_num_hh,0))				as pm_unit_AG_connectedness_num_hh
	 , max(units_AG.unit_AG_connectedness_top_hh)						as pm_unit_AG_connectedness_top_hh
	 , max(units_AG.unit_AG_connectedness_desc_top_hh)					as pm_unit_AG_connectedness_desc_top_hh
	 , max(units_AG.unit_AG_connectedness_avp_manager_top_hh)			as pm_unit_AG_connectedness_avp_manager_top_hh

	 , max(units_AG_ABonly.unit_AG_AB_connectedness_list_hh)			as pm_unit_AG_AB_connectedness_list_hh	
	 , max(units_AG_ABonly.unit_AG_AB_connectedness_list_short_hh)		as pm_unit_AG_AB_connectedness_list_short_hh
	 , max(isnull(units_AG_ABonly.unit_AG_AB_connectedness_num_hh,0))	as pm_unit_AG_AB_connectedness_num_hh
	 , max(units_AG_ABonly.unit_AG_AB_connectedness_top_hh)				as pm_unit_AG_AB_connectedness_top_hh
	 , max(units_AG_ABonly.unit_AG_AB_connectedness_desc_top_hh)		as pm_unit_AG_AB_connectedness_desc_top_hh
	 , max(units_AG_ABonly.unit_AG_AB_connectedness_avp_manager_top_hh)		as pm_unit_AG_AB_connectedness_avp_manager_top_hh

	 , max(servicearea_hh.servicearea_connectedness_list_hh)			as pm_servicearea_connectedness_list_hh
	 , max(isnull(servicearea_hh.servicearea_connectedness_num_hh,0))	as pm_servicearea_connectedness_num_hh 
	 , max(servicearea_hh.servicearea_connectedness_top_hh)				as pm_servicearea_connectedness_top_hh
	 , max(servicearea_hh.servicearea_connectedness_avp_manager_top_hh)	as pm_servicearea_connectedness_avp_manager_top_hh

	 , max(lagodeo_hh.lagodeo_connectedness_list_hh)					as pm_LAGODEO_connectedness_list_hh
	 , max(isnull(lagodeo_hh.lagodeo_connectedness_num_hh,0))			as pm_LAGODEO_connectedness_num_hh 
	 , max(lagodeo_hh.lagodeo_connectedness_top_hh)						as pm_LAGODEO_connectedness_top_hh
	 , max(lagodeo_hh.lagodeo_connectedness_desc_top_hh)				as pm_LAGODEO_connectedness_desc_top_hh
	 , max(lagodeo_hh.lagodeo_connectedness_avp_manager_top_hh)			as pm_LAGODEO_connectedness_avp_manager_top_hh

	 , max(phildeo_hh.phildeo_connectedness_list_hh)					as pm_philDEO_connectedness_list_hh
	 , max(isnull(phildeo_hh.phildeo_connectedness_num_hh,0))			as pm_philDEO_connectedness_num_hh 
	 , max(phildeo_hh.phildeo_connectedness_top_hh)						as pm_philDEO_connectedness_top_hh
	 , max(phildeo_hh.phildeo_connectedness_desc_top_hh)				as pm_philDEO_connectedness_desc_top_hh
	 , max(phildeo_hh.phildeo_connectedness_avp_manager_top_hh)			as pm_philDEO_connectedness_avp_manager_top_hh

	 , max(pgi_PG_unitSA_name_short_list_hh)							as pm_pgi_PG_unitSA_name_short_list_hh
	 , max(pgi_PG_unitSA_inclination_list_hh)							as pm_pgi_PG_unitSA_inclination_list_hh


/*can probably simplify/remove this code from here and use directly from the view when building views - speed?*/
	 , max(isnull(hh_gvg.gvg_recog_raised_life_hh,0))			as gvg_recog_raised_life_hh
	 , max(isnull(hh_gvg.gvg_recog_received_life_hh,0))			as gvg_recog_received_life_hh
	 , max(isnull(hh_gvg.gvg_recog_raised_campaign_hh,0))		as gvg_recog_raised_campaign_hh
	 , max(isnull(hh_gvg.gvg_recog_received_campaign_hh,0))		as gvg_recog_received_campaign_hh
	 , max(isnull(hh_gvg.gvg_recog_raised_MIRcampaign_hh,0))	as gvg_recog_raised_MIRcampaign_hh
	 , max(isnull(hh_gvg.gvg_recog_received_MIRcampaign_hh,0))	as gvg_recog_received_MIRcampaign_hh
	 , max(isnull(hh_gvg.gvg_recog_raised_tminus0_5_hh,0))		as gvg_recog_raised_tminus0_5_hh
	 , max(isnull(hh_gvg.gvg_recog_received_tminus0_5_hh,0))	as gvg_recog_received_tminus0_5_hh

	 , max(isnull(hh_gvg.gvg_recog_raised_tminus0_hh,0))		as gvg_recog_raised_tminus0_hh
	 , max(isnull(hh_gvg.gvg_recog_raised_tminus1_hh,0))		as gvg_recog_raised_tminus1_hh
	 , max(isnull(hh_gvg.gvg_recog_raised_tminus2_hh,0))		as gvg_recog_raised_tminus2_hh
	 , max(isnull(hh_gvg.gvg_recog_raised_tminus3_hh,0))		as gvg_recog_raised_tminus3_hh
	 , max(isnull(hh_gvg.gvg_recog_raised_tminus4_hh,0))		as gvg_recog_raised_tminus4_hh
	 , max(isnull(hh_gvg.gvg_recog_raised_tminus5_hh,0))		as gvg_recog_raised_tminus5_hh

	 , max(isnull(hh_gvg.gvg_recog_received_tminus0_hh,0))		as gvg_recog_received_tminus0_hh
	 , max(isnull(hh_gvg.gvg_recog_received_tminus1_hh,0))		as gvg_recog_received_tminus1_hh
	 , max(isnull(hh_gvg.gvg_recog_received_tminus2_hh,0))		as gvg_recog_received_tminus2_hh
	 , max(isnull(hh_gvg.gvg_recog_received_tminus3_hh,0))		as gvg_recog_received_tminus3_hh
	 , max(isnull(hh_gvg.gvg_recog_received_tminus4_hh,0))		as gvg_recog_received_tminus4_hh
	 , max(isnull(hh_gvg.gvg_recog_received_tminus5_hh,0))		as gvg_recog_received_tminus5_hh

	 , max(isnull(hh_gvg.flag_has_used_daf_hh,0))				as flag_has_used_daf_hh
	 , max(isnull(hh_gvg.flag_has_used_ff_hh,0))				as flag_has_used_ff_hh
	 , max(isnull(hh_gvg.flag_has_pg_vehicle_hh,0))				as flag_has_pg_vehicle_hh
	 , max(isnull(hh_gvg.flag_has_revocable_pg_hh,0))			as flag_has_revocable_pg_hh
	 , max(isnull(hh_gvg.flag_campaign_primary_transaction_donor_hh,0))	as flag_campaign_primary_transaction_donor_hh

	 , max(isnull(hh_gvg.gvg_recog_raised_tminus0_5_hh,0))	 /5	as gvg_recog_raised_tminus0_5_hh_avg
	 , max(isnull(hh_gvg.gvg_recog_received_tminus0_5_hh,0)) /5	as gvg_recog_received_tminus0_5_hh_avg
	 , max(isnull(hh_gvg.gvg_10yrs_num_yrs_recog_hh,0))			as gvg_10yrs_num_yrs_recog_hh

	 , max(hh_gvg.gvg_recog_first_hh)			as gvg_recog_first_hh				
	 , max(hh_gvg.gvg_recog_first_date_hh)		as gvg_recog_first_date_hh
	 , max(hh_gvg.gvg_recog_first_FY_hh)		as gvg_recog_first_FY_hh
	 , max(hh_gvg.gvg_recog_latest_date_hh)		as gvg_recog_latest_date_hh		
	 , max(hh_gvg.gvg_recog_latest_FY_hh)		as gvg_recog_latest_FY_hh		

	 , max(isnull(hh_gvg.gvg_recog_raised_life_hh_6bin,0))		as gvg_recog_raised_life_hh_6bin	
     , max(isnull(hh_gvg.gvg_recog_raised_life_hh_6bin_desc,'Entry Point - Non-Donor'))	as gvg_recog_raised_life_hh_6bin_desc

	 , max(hh_gvg.gvg_milestone_new_donor_hh_date)  as gvg_milestone_new_donor_hh_date
	 , max(hh_gvg.gvg_milestone_50k_hh_date)		as gvg_milestone_50k_hh_date
	 , max(hh_gvg.gvg_milestone_1M_hh_date)			as gvg_milestone_1M_hh_date
	 , max(hh_gvg.gvg_milestone_campaign_new_donor_hh_date) as gvg_milestone_campaign_new_donor_hh_date
	 , max(hh_gvg.gvg_milestone_campaign_50k_hh_date)		as gvg_milestone_campaign_50k_hh_date
	 , max(hh_gvg.gvg_milestone_campaign_1M_hh_date)		as gvg_milestone_campaign_1M_hh_date
	 , max(hh_gvg.num_payments_future_scheduled_hh)			as num_payments_future_scheduled_hh

/* end giving*/

	 , min(isnull(cl1.eval_bwf_connectedness,'Unrated'))  as eval_bwf_connectedness_hh
	 , min(isnull(case when cl1.eval_bwf_major_gift_rating = '10 Not rated' then NULL else cl1.eval_bwf_major_gift_rating end,'Unrated')) as eval_bwf_major_gift_rating_hh
	 , min(isnull(cl1.eval_vcu_connectedness_desc,'Unrated'))	as eval_vcu_connectedness_desc_hh
	 , max(cl1.eval_vcu_connectedness_score)					as eval_vcu_connectedness_score_hh
	 
	 , max(cl1.eval_vcu_planned_giving_score) as eval_vcu_planned_giving_score_hh
	 , max(cl1.eval_vcu_planned_giving_score_SQL) as eval_vcu_planned_giving_score_SQL_hh
	 , case when max(cl1.flag_pgi_NAP_all_VCU_active) = 1
	          or max(cl1.flag_pgi_NAP_unit_active_PG) = 1 
			  or max(cl1.flag_pgi_PG_VCU_NAP) = 1
			  then 'Tier X: Not a PG Prospect'  --should both spouses be NAP

			when max(cl1.flag_pgi_PG_referral)				= 1		--PG Suspect PGIs WITH a fundraiser attached
			  or max(cl1.flag_pgi_PG_VCU_future)			= 1	    --PG Suspect PGIs WITHOUT a fundraiser attached
			  or max(cl1.flag_pgi_PG_positive)				= 1		--PG Positives  added 4/11/25 on email from Ann Deppman
			--  or max(cl1.flag_pgi_planned_gift_active)	= 1     --this just says a PG pgi exists but not if its NAP or suspect etc
			then 'Tier 1: PGI'

	        when max(cl1.eval_vcu_planned_giving_score_SQL) >=10 
			  then 'Tier 1'
			when  max(cl1.eval_vcu_planned_giving_score_SQL) >=6 
			  then 'Tier 2'
			when max(cl1.eval_vcu_planned_giving_score_SQL) =5 
			  then 'Tier 3'
			when max(cl1.eval_vcu_planned_giving_score_SQL) =4 
			  then 'Tier 4'
			when max(cl1.eval_vcu_planned_giving_score_SQL) =3 
			  then 'Tier 5'
			when max(cl1.eval_vcu_planned_giving_score_SQL) =2 --added 10/1/24 after big switches to the score...namely not using having no children in the DB as a point gain
			  then 'Tier 6'
			else   'Tier 7' end as eval_vcu_planned_giving_tier_hh


	 , min(isnull(cl1.eval_capacity_rating_desc_sort,'O. Unrated'))		 as eval_capacity_rating_desc_sort_hh
	 , min(isnull(cl1.eval_capacity_rating_desc_short_sort,'O. Unrated')) as eval_capacity_rating_desc_short_sort_hh

	 --Define what campaign segment the HH is in
	 --https://docs.google.com/spreadsheets/d/1OzyyAWentiLCDXEGiAVuEv2-KI_OkHaYhOYna-CJ7lo/edit?gid=1867843860#gid=1867843860
	 --Moved J from Major to LAGO-C2 on 8/16/24
	  , case when left(min(isnull(cl1.eval_capacity_rating_desc_sort,'Unrated')),1) in ('A','B') and left(min(isnull(cl1.eval_vcu_connectedness_desc,'Unrated')),1) in ('A','B','C','D') then 'Principal'
			 when left(min(isnull(cl1.eval_capacity_rating_desc_sort,'Unrated')),1) in ('C','D') and left(min(isnull(cl1.eval_vcu_connectedness_desc,'Unrated')),1) in ('A','B','C') then 'Principal'
			 when left(min(isnull(cl1.eval_capacity_rating_desc_sort,'Unrated')),1) in ('E','F') and left(min(isnull(cl1.eval_vcu_connectedness_desc,'Unrated')),1) in ('A','B') then 'Principal'

			 when left(min(isnull(cl1.eval_capacity_rating_desc_sort,'Unrated')),1) in ('C','D') and left(min(isnull(cl1.eval_vcu_connectedness_desc,'Unrated')),1) in ('D') then 'Major'
			 when left(min(isnull(cl1.eval_capacity_rating_desc_sort,'Unrated')),1) in ('E','F') and left(min(isnull(cl1.eval_vcu_connectedness_desc,'Unrated')),1) in ('C','D') then 'Major'
			 when left(min(isnull(cl1.eval_capacity_rating_desc_sort,'Unrated')),1) in ('G')	and left(min(isnull(cl1.eval_vcu_connectedness_desc,'Unrated')),1) in ('A','B','C','D') then 'Major'
			 when left(min(isnull(cl1.eval_capacity_rating_desc_sort,'Unrated')),1) in ('H','I') and left(min(isnull(cl1.eval_vcu_connectedness_desc,'Unrated')),1) in ('A','B') then 'Major'

			 when left(min(isnull(cl1.eval_capacity_rating_desc_sort,'Unrated')),1) in ('J','K','L') and left(min(isnull(cl1.eval_vcu_connectedness_desc,'Unrated')),1) in ('A','B') then 'LAGO -C2'  --added J back in 8/16/24
			 when left(min(isnull(cl1.eval_capacity_rating_desc_sort,'Unrated')),1) in ('H','I','J','K') and left(min(isnull(cl1.eval_vcu_connectedness_desc,'Unrated')),1) in ('C') then 'LAGO -Discovery'  --,'D' removed on 4/25/24 

			 when left(min(isnull(cl1.eval_capacity_rating_desc_sort,'Unrated')),1) in ('M') and left(min(isnull(cl1.eval_vcu_connectedness_desc,'Unrated')),1) in ('A','B') then 'Alumni Relations'  --added on 9/27/24
			 when left(min(isnull(cl1.eval_capacity_rating_desc_sort,'Unrated')),1) in ('J','K','L','M') and left(min(isnull(cl1.eval_vcu_connectedness_desc,'Unrated')),1) in ('C') then 'Alumni Relations'
			 when left(min(isnull(cl1.eval_capacity_rating_desc_sort,'Unrated')),1) in ('H','I','J','K','L','M') and left(min(isnull(cl1.eval_vcu_connectedness_desc,'Unrated')),1) in ('D') then 'Alumni Relations'

	    else 'No Campaign Segment'
		end as eval_campaign_segment_hh

	, min(cl1.eval_default_segment_grid_rank)	as eval_default_segment_grid_rank_hh
	, min(cl1.eval_overall_prospect_rank)		as eval_overall_prospect_rank_cl_hh					--this is the individual ranking of the highest ranked person in the HH
	, case when min(cl1.eval_overall_prospect_rank) is not null 
		   then row_number() over( partition by (case when min(cl1.eval_overall_prospect_rank) is not null then 1 else 2 end)
									order by min(cl1.eval_overall_prospect_rank)
								 ) 
		   else NULL end as eval_overall_prospect_rank_hh	--this is the household rank
	, min(cl1.eval_nyu_bin)			as eval_nyu_bin_hh
							

	 --May need some tweaks or with the underlying pm_prospect_status in CL.... but darn good.  More than 2 person HHs create some complexity
	 --deceaseds always lose in these comparisons
	 , case when min(cl1.pm_prospect_status) = 'Assigned' then 'Assigned'
			when max(case when cl1.pm_prospect_status = 'Unassigned' then NULL else cl1.pm_prospect_status end) = 'Permanent Stewardship' then 'Permanent Stewardship'
			when max(case when cl1.pm_prospect_status = 'Unassigned' then NULL else cl1.pm_prospect_status end) = 'Referred' then 'Referred'
			when max(case when cl1.pm_prospect_status = 'Unassigned' then NULL else cl1.pm_prospect_status end) = 'Not a prospect' then 'Not a prospect'
			when max(case when cl1.pm_prospect_status = 'Unassigned' then NULL else cl1.pm_prospect_status end) = 'No Prospect Status' then 'No Prospect Status'  --the NULL record
			when max(cl1.pm_prospect_status) = 'Deceased' then 'Deceased'  --should only capture all HH members are deceased (and not having one of the 5 statuses above)
			when max(cl1.pm_prospect_status) = 'Unassigned' then 'Unassigned'
			else 'Undefined'
	        end as pm_prospect_status_hh
	 ,  max(cl1.pm_stage_calculated) --= 'Not a Prospect'			then 'Not a Prospect' 
			--when max(cl1.pm_stage_calculated) = 'Permanent Stewardship'	then 'Permanent Stewardship'
			--when min(cl1.pm_stage_calculated) = 'Solicitation'			or max(cl1.pm_stage_calculated) = 'Solicitation'			then 'Solicitation' 
			--when min(cl1.pm_stage_calculated) = 'Stewardship'			or max(cl1.pm_stage_calculated) = 'Stewardship'				then 'Stewardship' 
			--when min(cl1.pm_stage_calculated) = 'Cultivation'			or max(cl1.pm_stage_calculated) = 'Cultivation'				then 'Cultivation' 
			--when min(cl1.pm_stage_calculated) = 'Qualification'			or max(cl1.pm_stage_calculated) = 'Qualification'			then 'Qualification' 
			--when min(cl1.pm_stage_calculated) = 'Identification'		or max(cl1.pm_stage_calculated) = 'Identification'			then 'Identification'
			--when min(cl1.pm_stage_calculated) = 'No Stage Assigned'		or max(cl1.pm_stage_calculated) = 'No Stage Assigned'		then 'No Stage Assigned' 
	        --else 'Undefined' end
			as pm_stage_calculated_hh
	 , max(cl1.mov_latest_lago_interaction_date)		as mov_latest_lago_interaction_date_hh
	 , case when datediff(day,max(cl1.mov_latest_completed_sig_all_interaction_cultivate),getdate()) <= 365 then 1 else 0 end as flag_mov_allofficers_cultivate_in_last365_hh
	 , max(cl1.mov_latest_completed_sig_all_interaction_cultivate)			as mov_allofficers_latest_completed_sig_all_interaction_cultivate_hh
	 , max(cl1.mov_latest_completed_sig_primary_interaction_cultivate)		as mov_allofficers_latest_completed_sig_primary_interaction_cultivate_hh
	 , max(cl1.mov_latest_completed_sig_secondary_interaction_cultivate)	as mov_allofficers_latest_completed_sig_secondary_interaction_cultivate_hh
	 , max(cl1.mov_latest_completed_sig_participant_interaction_cultivate)	as mov_allofficers_latest_completed_sig_participant_interaction_cultivate_hh
	 , max(cl1.mov_latest_completed_sig_discovery_interaction_cultivate)	as mov_allofficers_latest_completed_sig_discovery_interaction_cultivate_hh
	 , max(cl1.sol_num_ask_rolling_365x2)				as sol_num_ask_rolling_365x2_hh
	 , sum(cl1.sol_sum_ask_rolling_365x2)				as sol_sum_ask_rolling_365x2_hh
	 , sum(cl1.sol_sum_expected_ask_rolling_365x2)		as sol_sum_expected_ask_rolling_365x2_hh
	 , sum(cl1.sol_sum_both_ask_rolling_365x2)			as sol_sum_both_ask_rolling_365x2_hh
	 , max(cl1.flag_ask_rolling_365x2)					as flag_ask_rolling_365x2_hh

	 ,case when max(cl1.flag_managed_prospect_currently) = 1
	   and (max(cl1.sol_num_ask_rolling_365x2)>=1
		or max(cl1.mov_latest_completed_sig_primary_interaction_cultivate)>=getdate()-366
		or max(cl1.mov_latest_completed_sig_secondary_interaction_cultivate)>=getdate()-366
		or max(cl1.mov_latest_completed_sig_discovery_interaction_cultivate)>=getdate()-366
		or max(cl1.flag_any_completed_interaction_last_365)=1
		)
	then 1 else 0 end as flag_HH_has_PM_and_worked_by_VCU_365


	 /*flags*/
	 , max(cl1.flag_living)								as flag_living_hh
	 , max(cl1.flag_individual)							as flag_individual_hh
	 , max(cl1.flag_strikezone)							as flag_strikezone_hh
	 , max(cl1.flag_strikezone_new)						as flag_strikezone_new_hh
	 , case when sum(cl1.flag_alum) >= 2 then 1 else 0 end as flag_double_alum_hh
	 , max(cl1.flag_alum)								as flag_alum_hh
	 , max(cl1.flag_di_vip)								as flag_di_vip_hh
     , max(cl1.flag_managed_currently)					as flag_managed_currently_hh
     , max(cl1.flag_managed_prospect_currently)			as flag_managed_prospect_currently_hh
     , max(cl1.flag_managed_team_currently)				as flag_managed_team_currently_hh
     , max(cl1.flag_managed_stewardship_currently)		as flag_managed_stewardship_currently_hh
     , max(cl1.flag_managed_discovery_currently)		as flag_managed_discovery_currently_hh
     , max(cl1.flag_managed_foundation_currently)		as flag_managed_foundation_currently_hh
     , max(cl1.flag_any_completed_interaction_last_365) as flag_any_completed_interaction_last_365_hh
	 , max(cl1.flag_any_completed_sig_interaction_last_365) as flag_any_completed_sig_interaction_last_365_hh
     , max(cl1.flag_any_completed_SPV_last_365)			as flag_any_completed_SPV_last_365_hh
     , max(cl1.flag_any_engagement_last_365)			as flag_any_engagement_last_365_hh
     , max(cl1.flag_any_engagement_campaign2030)		as flag_any_engagement_campaign2030_hh
     , max(cl1.flag_pgi_NAP_all_VCU_active)				as flag_pgi_NAP_all_VCU_active_hh
     , max(cl1.flag_pgi_referral_active)				as flag_pgi_referral_active_hh
     , max(cl1.flag_pgi_planned_gift_active)			as flag_pgi_planned_gift_active_hh
     , max(cl1.flag_pgi_PG_referral)					as flag_pgi_PG_referral_hh
     , max(cl1.flag_pgi_PG_VCU_future)					as flag_pgi_PG_VCU_future_hh
	 , max(cl1.flag_pgi_PG_VCU_NAP)						as flag_pgi_PG_VCU_NAP_hh
	 , max(cl1.flag_pgi_PG_unit_NAP)					as flag_pgi_PG_unit_NAP_hh
	 , max(cl1.flag_vcu_facstaff_current)				as flag_retired_vcu_current_hh
	 , max(cl1.flag_vcu_facstaff_retired)				as flag_retired_vcu_facstaff_hh
	 , case when max(cl1.pm_num_active_prospect_plans)>0 then 1 else 0 end as flag_has_active_prospect_plan_hh
	 , max(cl1.flag_VCU_employees_to_exclude)			as flag_VCU_employees_to_exclude_hh
	 , max(cl1.flag_has_nokids_GB)						as flag_has_nokids_GB_hh

	 , max(cl1.flag_TP_parent)							as flag_TP_parent_hh
     , max(cl1.flag_TP_foundation)						as flag_TP_foundation_hh
     , max(cl1.flag_TP_complex_assets)					as flag_TP_complex_assets_hh
     , max(cl1.flag_TP_DAF)								as flag_TP_DAF_hh

	 , max(cl1.flag_parent_current)						as flag_parent_current_hh
	 , max(cl1.flag_parent_constituency)				as flag_parent_constituency_hh
     , max(cl1.flag_parent_past_constituency)			as flag_parent_past_constituency_hh
	 , max(cl1.flag_WF_DAF_indicator)					as flag_WF_DAF_indicator_hh
	 , max(cl1.flag_rnl_interest_has_DAF)				as flag_rnl_interest_has_DAF
	 , max(cl1.flag_ever_radar_user)					as flag_ever_radar_user_hh

	 , max(cl1.eval_VCU_principal_giving_points)		as eval_VCU_principal_giving_points_hh
	 , max(cl1.eval_VCU_principal_giving_score)			as eval_VCU_principal_giving_score_hh
	 , min(cl1.eval_VCU_principal_giving_rank)			as eval_VCU_principal_giving_rank_hh_lame
	 , row_NUMBER() OVER (ORDER BY min(cl1.eval_VCU_principal_giving_rank)) as eval_VCU_principal_giving_rank_hh


	 , max(cl1.eval_pringiv_1_highcapacity)				as eval_pringiv_1_highcapacity_hh			
	 , max(cl1.eval_pringiv_2_daf_stock)				as eval_pringiv_2_daf_stock_hh				

	 , max(cl1.eval_pringiv_4_old)						as eval_pringiv_4_old_hh
	 , max(cl1.eval_pringiv_5_alum_fac)					as eval_pringiv_5_alum_fac_hh
	 , max(cl1.eval_pringiv_6_local)					as eval_pringiv_6_local_hh

	 , max(cl1.eval_pringiv_8_managed)					as eval_pringiv_8_managed_hh				
	 , max(cl1.eval_pringiv_9_campus_visit)				as eval_pringiv_9_campus_visit_hh				
	 , max(cl1.eval_pringiv_10_interactions)			as eval_pringiv_10_interactions_hh				
	 , max(cl1.eval_pringiv_11_bigmoney)				as eval_pringiv_11_bigmoney_hh			
	 , max(cl1.eval_pringiv_12_committee)				as eval_pringiv_12_committee_hh			
	 , max(cl1.eval_pringiv_13_spouse_engagement)		as eval_pringiv_13_spouse_engagement_hh	 		
	 , max(cl1.eval_pringiv_14_majorgift)				as eval_pringiv_14_majorgift_hh				

	 , max(cl1.eval_pringiv_17_rao)						as eval_pringiv_17_rao_hh

	 , min(cl1.eval_record_standard_metal)				as eval_record_standard_metal_hh
	 , max(cl1.flag_attribute_volunteer)				as flag_attribute_volunteer_hh
	 , max(cl1.flag_committee_member_current)			as flag_committee_member_current_hh
	 , max(cl1.engagement_latest_event_attendance_date) as engagement_latest_event_attendance_date_hh
	 , max(cl1.engagement_latest_email_click_through_date) as engagement_latest_email_click_through_date_hh
	 , max(cl1.pm_num_events_tminus0)					as pm_num_events_tminus0_hh
	 , max(cl1.pm_num_volunteer_tminus0)				as pm_num_volunteer_tminus0_hh
	 , max(cl1.pm_num_volunteer_tminus1_5)				as pm_num_volunteer_tminus1_5_hh
	 , max(cl1.pm_latest_past_committee_end_date)		as pm_latest_past_committee_end_date_hh
	 , max(cl1.num_email_n_interactions_last24months)	as num_email_n_interactions_last24months_hh
	 , max(cl1.num_social_media_engagement_last24months)	as num_social_media_engagement_last24months_hh
	 , max(cl1.flag_award_recipient)					as flag_award_recipient_hh
	 , max(cl1.flag_is_principal_gift_prospect)			as flag_is_principal_gift_prospect_hh
	 , max(cl1.flag_has_pending_interaction)			as flag_has_pending_interaction_hh
	 , max(cl1.flag_has_pending_plan_interaction)		as flag_has_pending_plan_interaction_hh
	 , min(cl1.mov_earliest_pending_interaction_date)	as mov_earliest_pending_interaction_date_hh 
	 , max(cl1.mov_latest_pending_interaction_date)		as mov_latest_pending_interaction_date_hh

	 , max(case when cl1.flag_is_primary_hh_member = 1  and cl1.flag_ever_radar_user = 0 then constituent_system_id else NULL end ) as primary_HH_constituent_id
     , max(case when cl1.flag_is_primary_hh_member = 1  and cl1.flag_ever_radar_user = 0 then constituent_lookup_id else NULL end ) as primary_HH_lookup_id
     , max(case when cl1.flag_is_primary_hh_member = 1  and cl1.flag_ever_radar_user = 0 then cntc_primary_email else NULL end )	as primary_hh_email
     , max(case when cl1.flag_is_primary_hh_member = 1  and cl1.flag_ever_radar_user = 0 then cntc_primary_phone else NULL end )	as primary_hh_phone

  FROM DARanalytics.datamart.constituent_level cl1
  left join DARanalytics.datamart.gvg_revenue_history_summary_hh hh_gvg on hh_gvg.household_dim_id = cl1.household_id  --attach HH giving
 
 /* names */
left join ( SELECT CONSTITUENTSYSTEMID
				 , max(fullname_summary)					as bio_name_informal_hh
			  FROM BBCRM_PROD_RPT_BBDW.BBDW.VCU_FACT_CONSTITUENTMARRIAGE
			 GROUP BY CONSTITUENTSYSTEMID		--unneeded - only for safety
			-- order by bio_name_informal_hh
          ) names on names.CONSTITUENTSYSTEMID = cl1.constituent_system_id


 	/*UNITS LIST BY HOUSEHOLD - MAIN ONES*/
	  left join (
		  select t.household_id
			 --  , string_agg(concat(t.unit_name,'' ), ', ') within group (order by row_num) as unit_connectedness_list_hh
			   , string_agg(concat(t.unit_name,'(',pm_unit_connectedness_letter,')','' ), ', ') within group (order by row_num) as unit_connectedness_list_hh
			  -- , string_agg(concat(t.unit_name_short,'' ), ', ') within group (order by row_num) as unit_connectedness_list_short_hh
			   , string_agg(concat(t.unit_name_short,'(',pm_unit_connectedness_letter,')','' ), ', ') within group (order by row_num) as unit_connectedness_list_short_hh
			   , count(*) as unit_connectedness_num_hh  --treating Other as 1 unit
			   , max(case when row_num = 1 then unit_name_short else NULL end) as unit_connectedness_top_hh
			   , max(case when row_num = 1 then unit_avp_officer_manager else NULL end) as unit_connectedness_avp_manager_top_hh

			--   , string_agg(concat(unit_name_short,'' ), ', ') within group (order by unit_name_short) as unit_connectedness_list_short
			--   , string_agg(concat(unit_name_short_other,'' ), ', ') within group (order by unit_name_short_other) as unit_connectedness_list_short_other
			--   , max(t.unit_connectedness_list) as unit_connectedness_list_old
			from ( select distinct household_id
					, unit_name
					, unit_name_short
					, min(pm_unit_connectedness_desc) as pm_unit_connectedness_desc
					, max(pm_unit_connectedness_score) as pm_unit_connectedness_score
					, isnull(left(min(pm_unit_connectedness_desc),1),'X') as pm_unit_connectedness_letter
					, row_number() over (partition by household_id order by isnull(left(min(pm_unit_connectedness_desc),1),'X'), max(pm_unit_connectedness_score) desc, min(unit_name)) as row_num
					, unit_avp_officer_manager			 
				 from DARanalytics.datamart.constituent_unit_level
				where flag_unit_philanthropic = 1				--only choose philanthropic units
				  and pm_unit_connectedness_desc is not null	--these should be removed upstream in CUL code
				  and flag_unit_pgi_not_unit_prospect = 0		--remove if there is a NAP unit PGI
				group by household_id, unit_name, unit_name_short, unit_avp_officer_manager	
			  ) t
		   group by household_id
			) units_hh on units_hh.household_id = cl1.household_id


	   left join (
		  select t.household_id
			--   , string_agg(concat(unit_name,'' ), ', ') within group (order by unit_name) as unit_connectedness_list
			--   , string_agg(concat(t.unit_name_other,'' ), ', ') within group (order by row_num) as unit_connectedness_list_other_hh
			   , string_agg(concat(t.unit_name_other,'(',pm_unit_connectedness_letter,')','' ), ', ') within group (order by row_num) as unit_connectedness_list_other_hh
			   , count(*) as unit_connectedness_num_other_hh  --treating Other as 1 unit
			   , max(case when row_num = 1 then unit_name_other else NULL end) as unit_connectedness_other_top_hh
			   , max(case when row_num = 1 then unit_avp_officer_manager else NULL end) as unit_connectedness_other_avp_manager_top_hh
			--   , string_agg(concat(unit_name_short,'' ), ', ') within group (order by unit_name_short) as unit_connectedness_list_short
			--   , string_agg(concat(unit_name_short_other,'' ), ', ') within group (order by unit_name_short_other) as unit_connectedness_list_short_other
			--   , max(t.unit_connectedness_list) as unit_connectedness_list_old
			from ( select distinct household_id
					, unit_name_other
					, min(pm_unit_connectedness_desc) as pm_unit_connectedness_desc
					, max(pm_unit_connectedness_score) as pm_unit_connectedness_score
					, isnull(left(min(pm_unit_connectedness_desc),1),'X') as pm_unit_connectedness_letter
					, row_number() over (partition by household_id order by isnull(left(min(pm_unit_connectedness_desc),1),'X'), max(pm_unit_connectedness_score) desc, min(unit_name_other)) as row_num
					, unit_avp_officer_manager					 
				 from DARanalytics.datamart.constituent_unit_level
				where flag_unit_philanthropic = 1				--only choose philanthropic units
				  and pm_unit_connectedness_desc is not null	--these should be removed upstream in CUL code
				  and flag_unit_pgi_not_unit_prospect = 0		--remove if there is a NAP unit PGI
				group by household_id, unit_name_other, unit_avp_officer_manager	
			  ) t
		   group by household_id
			) units_other_hh on units_other_hh.household_id = cl1.household_id

		left join (
	  select household_id
		   --, string_agg(concat(unit_name,'' ), ', ') within group (order by row_num) as unit_lago_connectedness_list_hh
		   --, string_agg(concat(unit_name_short,'' ), ', ') within group (order by row_num) as unit_lago_connectedness_list_short_hh
		   , string_agg(concat(unit_name,'(',pm_unit_connectedness_letter,')','' ), ', ') within group (order by row_num) as unit_lago_connectedness_list_hh
		   , string_agg(concat(unit_name_short,'(',pm_unit_connectedness_letter,')','' ), ', ') within group (order by row_num) as unit_lago_connectedness_list_short_hh
		   , count(*) as unit_lago_connectedness_num_hh --treating Other as 1 unit
		   , max(case when row_num = 1 then unit_name_short else NULL end) as unit_lago_connectedness_top_hh
		   , max(case when row_num = 1 then pm_unit_connectedness_desc else NULL end) as unit_lago_connectedness_desc_top_hh
		   , max(case when row_num = 1 then unit_avp_officer_manager else NULL end) as unit_lago_connectedness_avp_manager_top_hh
		from ( select distinct household_id
					, unit_name
					, unit_name_short
					, min(pm_unit_connectedness_desc) as pm_unit_connectedness_desc
					, max(pm_unit_connectedness_score) as pm_unit_connectedness_score
					, isnull(left(min(pm_unit_connectedness_desc),1),'X') as pm_unit_connectedness_letter
					, row_number() over (partition by household_id order by isnull(left(min(pm_unit_connectedness_desc),1),'X'), max(pm_unit_connectedness_score) desc, min(unit_name)) as row_num
					, unit_avp_officer_manager				 
				 from DARanalytics.datamart.constituent_unit_level
				where flag_unit_lago = 1						--only choose LAGO units
				  and pm_unit_connectedness_desc is not null	--these should be removed upstream in CUL code
				  and flag_unit_pgi_not_unit_prospect = 0		--remove if there is a NAP unit PGI
				group by household_id, unit_name, unit_name_short, unit_avp_officer_manager	
			  ) t
		group by household_id
		)units_lago on units_lago.household_id = cl1.household_id

--List of all AG (12 CSUs) connections
		left join (
	  select household_id
		   , string_agg(concat(unit_name,'(',pm_unit_connectedness_letter,')','' ), ', ') within group (order by row_num) as unit_AG_connectedness_list_hh
		   , string_agg(concat(unit_name_short,'(',pm_unit_connectedness_letter,')','' ), ', ') within group (order by row_num) as unit_AG_connectedness_list_short_hh
		   , count(*) as unit_AG_connectedness_num_hh --treating Other as 1 unit
		   , max(case when row_num = 1 then unit_name_short else NULL end) as unit_AG_connectedness_top_hh
		   , max(case when row_num = 1 then pm_unit_connectedness_desc else NULL end) as unit_AG_connectedness_desc_top_hh
		   , max(case when row_num = 1 then unit_avp_officer_manager else NULL end) as unit_AG_connectedness_avp_manager_top_hh
		from ( select distinct household_id
					, unit_name
					, unit_name_short
					, min(pm_unit_connectedness_desc) as pm_unit_connectedness_desc
					, max(pm_unit_connectedness_score) as pm_unit_connectedness_score
					, isnull(left(min(pm_unit_connectedness_desc),1),'X') as pm_unit_connectedness_letter
					, row_number() over (partition by household_id order by isnull(left(min(pm_unit_connectedness_desc),1),'X'), max(pm_unit_connectedness_score) desc, min(unit_name)) as row_num
					, unit_avp_officer_manager
				 from DARanalytics.datamart.constituent_unit_level
				where flag_unit_annual_giving = 1				--only choose AG units
				  and pm_unit_connectedness_desc is not null	--these should be removed upstream in CUL code
				  and flag_unit_pgi_not_unit_prospect = 0		--remove if there is a NAP unit PGI
				group by household_id, unit_name, unit_name_short, unit_avp_officer_manager
			  ) t
		group by household_id
		)units_AG on units_AG.household_id = cl1.household_id

/* 12 AG units only and only A/B connections*/
		left join (
	  select household_id
		   , string_agg(concat(unit_name,'(',pm_unit_connectedness_letter,')','' ), ', ') within group (order by row_num) as unit_AG_AB_connectedness_list_hh
		   , string_agg(concat(unit_name_short,'(',pm_unit_connectedness_letter,')','' ), ', ') within group (order by row_num) as unit_AG_AB_connectedness_list_short_hh
		   , count(*) as unit_AG_AB_connectedness_num_hh
		   , max(case when row_num = 1 then unit_name_short else NULL end) as unit_AG_AB_connectedness_top_hh
		   , max(case when row_num = 1 then pm_unit_connectedness_desc else NULL end) as unit_AG_AB_connectedness_desc_top_hh
		   , max(case when row_num = 1 then unit_avp_officer_manager else NULL end) as unit_AG_AB_connectedness_avp_manager_top_hh
		from ( select distinct household_id
					, unit_name
					, unit_name_short
					, min(pm_unit_connectedness_desc) as pm_unit_connectedness_desc
					, max(pm_unit_connectedness_score) as pm_unit_connectedness_score
					, isnull(left(min(pm_unit_connectedness_desc),1),'X') as pm_unit_connectedness_letter
					, row_number() over (partition by household_id order by isnull(left(min(pm_unit_connectedness_desc),1),'X'), max(pm_unit_connectedness_score) desc, min(unit_name)) as row_num
				    , unit_avp_officer_manager
				 from DARanalytics.datamart.constituent_unit_level
				where flag_unit_annual_giving = 1				--only choose AG units
				  and pm_unit_connectedness_desc is not null	--these should be removed upstream in CUL code
				  and flag_unit_pgi_not_unit_prospect = 0		--remove if there is a NAP unit PGI
				  and left(pm_unit_connectedness_desc,1) in ('A','B')
				group by household_id, unit_name, unit_name_short, unit_avp_officer_manager
			  ) t
		group by household_id
		)units_AG_ABonly on units_AG_ABonly.household_id = cl1.household_id

	  left join (
		  select t.household_id
			   , string_agg(concat(t.fud_service_area,'(',pm_servicearea_connectedness_letter,')','' ), ', ') within group (order by row_num) as servicearea_connectedness_list_hh
			   , count(*) as servicearea_connectedness_num_hh  --treating Other as 1 unit
			   , max(case when row_num = 1 then fud_service_area else NULL end) as servicearea_connectedness_top_hh
			   , max(case when row_num = 1 then service_area_avp_officer_manager else NULL end) as servicearea_connectedness_avp_manager_top_hh
			from ( select distinct household_id
					, fud_service_area
					, min(pm_servicearea_connectedness_desc) as pm_unit_connectedness_desc
					, max(pm_servicearea_connectedness_score) as pm_unit_connectedness_score
					, isnull(left(min(pm_servicearea_connectedness_desc),1),'X') as pm_servicearea_connectedness_letter
					, row_number() over (partition by household_id order by isnull(left(min(pm_servicearea_connectedness_desc),1),'X'), max(pm_servicearea_connectedness_score) desc, min(fud_service_area)) as row_num
				    , service_area_avp_officer_manager
				 from DARanalytics.datamart.constituent_servicearea_level
				where  pm_servicearea_connectedness_desc is not null	--these should be removed upstream in CUL code
				--  and flag_unit_pgi_not_unit_prospect = 0		--remove if there is a NAP unit PGI
				group by household_id, fud_service_area, service_area_avp_officer_manager
			  ) t
		   group by household_id
			) servicearea_hh on servicearea_hh.household_id = cl1.household_id

	  left join (
		  select t.household_id
			   , string_agg(concat(t.unit_name_short,'(',pm_unit_connectedness_letter,')','' ), ', ') within group (order by row_num) as lagodeo_connectedness_list_hh
			   , count(*) as lagodeo_connectedness_num_hh  --treating other as 1 unit
			   , max(case when row_num = 1 then unit_name_short else NULL end) as lagodeo_connectedness_top_hh
			   , min(case when row_num = 1 then pm_unit_connectedness_desc else NULL end) as lagodeo_connectedness_desc_top_hh
			   , max(case when row_num = 1 then unit_avp_officer_manager else NULL end) as lagodeo_connectedness_avp_manager_top_hh
			from ( select distinct household_id
					, unit_system_id
					, unit_name_short
					, min(pm_unit_connectedness_desc) as pm_unit_connectedness_desc
					, max(pm_unit_connectedness_score) as pm_unit_connectedness_score
					, isnull(left(min(pm_unit_connectedness_desc),1),'X') as pm_unit_connectedness_letter
					, row_number() over (partition by household_id order by isnull(left(min(pm_unit_connectedness_desc),1),'X'), max(pm_unit_connectedness_score) desc, min(unit_name_short)) as row_num
					, unit_avp_officer_manager
				 from DARanalytics.datamart.constituent_unit_servicearea_unioned
				where  pm_unit_connectedness_desc is not null	--these should be removed upstream in CUL code
				  and flag_unit_lagodeo = 1 
				  and unit_system_id not in ( 'E0545866-2173-49A2-A4FA-E8CBBEB597E2' --MCCC
											 , '1ADAC6A1-507E-4FDE-9225-F62D8B1E93E6' --Medicine
											 , 'BB907FDD-83A6-4136-9578-60215540CC37'  --VCUHS
											 , '6939E7EE-A6C0-46E9-BC79-1304B62E1704' --not associated with a service area
											 )
				--  and flag_unit_pgi_not_unit_prospect = 0		--remove if there is a NAP unit PGI
				group by household_id, unit_system_id, unit_name_short, unit_avp_officer_manager
			  ) t
		   group by household_id
			) lagodeo_hh on lagodeo_hh.household_id = cl1.household_id

	  left join (
		  select t.household_id
			   , string_agg(concat(t.unit_name_short,'(',pm_unit_connectedness_letter,')','' ), ', ') within group (order by row_num) as phildeo_connectedness_list_hh
			   , count(*) as phildeo_connectedness_num_hh  --treating other as 1 unit
			   , max(case when row_num = 1 then unit_name_short else NULL end) as phildeo_connectedness_top_hh
			   , min(case when row_num = 1 then pm_unit_connectedness_desc else NULL end) as phildeo_connectedness_desc_top_hh
			   , max(case when row_num = 1 then unit_avp_officer_manager else NULL end) as phildeo_connectedness_avp_manager_top_hh
			from ( select distinct household_id
					, unit_system_id
					, unit_name_short
					, min(pm_unit_connectedness_desc) as pm_unit_connectedness_desc
					, max(pm_unit_connectedness_score) as pm_unit_connectedness_score
					, isnull(left(min(pm_unit_connectedness_desc),1),'X') as pm_unit_connectedness_letter
					, row_number() over (partition by household_id order by isnull(left(min(pm_unit_connectedness_desc),1),'X'), max(pm_unit_connectedness_score) desc, min(unit_name_short)) as row_num
					, unit_avp_officer_manager
				 from DARanalytics.datamart.constituent_unit_servicearea_unioned
				where  pm_unit_connectedness_desc is not null	--these should be removed upstream in CUL code
				  and flag_unit_philanthropicdeo= 1
				  and unit_system_id not in ( 'E0545866-2173-49A2-A4FA-E8CBBEB597E2' --MCCC
											 , '1ADAC6A1-507E-4FDE-9225-F62D8B1E93E6' --Medicine
											 , 'BB907FDD-83A6-4136-9578-60215540CC37'  --VCUHS
											 , '6939E7EE-A6C0-46E9-BC79-1304B62E1704' --not associated with a service area
											 )
				--  and flag_unit_pgi_not_unit_prospect = 0		--remove if there is a NAP unit PGI
				group by household_id, unit_system_id, unit_name_short, unit_avp_officer_manager
			  ) t

		   group by household_id
			) phildeo_hh on phildeo_hh.household_id = cl1.household_id

			left join (
				 select t.household_id
 					  , string_agg(concat(t.pgi_unitSA_name_short,'' ), ', ') within group (order by t.pgi_unitSA_name_short) as pgi_PG_unitSA_name_short_list_hh
  					--  , string_agg(concat(t.pgi_unitSA_name_campaign,'' ), ', ') within group (order by t.pgi_unitSA_name_short) as pgi_PG_unitSA_name_campaign_list_hh
					  , string_agg(concat(t.pgi_inclination_level_code,'' ), ', ') within group (order by t.pgi_unitSA_name_short) as pgi_PG_unitSA_inclination_list_hh
							from ( select distinct household_id
										, pgi_unitSA_name_short
										, pgi_unitSA_name
										, pgi_unitSA_name_campaign
										, pgi_unitSA_system_id
										, pgi_inclination_level_code
				
								 from DARanalytics.tableau.unit_active_pgis
								where pgi_funding_type_code = 'Planned Gift Prospect'
								  and pgi_inclination_level_code in ('Suspect','Future Prospect','Positive')
								  and household_id is not null
								group by household_id
									   , pgi_unitSA_name_short
									   , pgi_unitSA_name
									   , pgi_unitSA_name_campaign
									   , pgi_unitSA_system_id
									   , pgi_inclination_level_code
							  ) t

						   group by household_id
					) PG_pgis on PG_pgis.household_id = cl1.household_id


 group by cl1.household_system_id, cl1.household_id, cl1.household_lookup_id

 /* where clause for entire select:  this excludes all entities to exclude. i.e. test records */


END


/* STEP 3. CREATE INDEXES */

	/*clustered index must come first - before all nonclustered indexes - otherwise all nonclustered
	  indexes are deleted upon trying to run a clustered index
	  
	  If there is ever a problem with run time, comment out the indexes to rule them out.  Often they use up too much
	  temp space and bork the procedure*/

	ALTER TABLE DARanalytics.datamart.constituent_household_level_temp
    ADD CONSTRAINT PK_Constituent_HH_temp PRIMARY KEY (household_system_id);

--CREATE CLUSTERED INDEX ix_household_pk ON DARanalytics.datamart.constituent_household_level_temp
--(	household_id ASC
--)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, SORT_IN_TEMPDB = ON, DROP_EXISTING = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [PRIMARY]

	CREATE NONCLUSTERED INDEX ix_household_lookup_id
	ON DARanalytics.datamart.constituent_household_level_temp (household_lookup_id);
	CREATE NONCLUSTERED INDEX ix_household_id
	ON DARanalytics.datamart.constituent_household_level_temp (household_id);

	/*SSMS recommended indexes*/
	CREATE NONCLUSTERED INDEX ix_touchpoints_parent
	ON DARanalytics.datamart.constituent_household_level_temp (flag_TP_parent_hh) 
	INCLUDE (flag_TP_foundation_hh, flag_TP_complex_assets_hh, flag_TP_DAF_hh);

	CREATE NONCLUSTERED INDEX ix_flag_living 
	ON DARanalytics.datamart.constituent_household_level_temp (flag_living_hh) 
	INCLUDE (eval_vcu_planned_giving_tier_hh);


/* STEP 4. Basic Error Checking and Logging*/
select  @rowsLoaded = count(*) from datamart.constituent_household_level_temp

if @rowsLoaded >500000
  BEGIN
   IF  EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'datamart.constituent_household_level') AND type in (N'U'))
				 DROP TABLE datamart.constituent_household_level
	   exec sp_rename 'datamart.constituent_household_level_temp', 'constituent_household_level'
	select @errorMessage = 'Successful overwrite of table ' + @destTable
   -- exec [DARanalytics].[dbo].[sp_logTableLoad] @destTable, N'finish', @startTime, N'Successful build', @rowsLoaded;
  END

else
  BEGIN
	select @errorMessage = 'constituent_household_level_temp seems off - go investigate: ' + @destTable
	--exec [DARanalytics].[dbo].[sp_logTableLoad] @destTable, N'finish', @startTime, @errorMessage, @rowsLoaded;
  END

  	--rename the PK so the next time it is run the temp table won't have the same name and bomb.
	EXEC sp_rename N'datamart.PK_Constituent_HH_temp', N'PK_Constituent_HH'


/*Update CL with these new CHL calculations.  Only way to line up household values over time as the household_id changes every Sunday*/
--Not sure why this is being flagged as red....it works fine
update DARanalytics.datamart.constituent_level
  set pm_stage_calculated_hh = chl.pm_stage_calculated_hh
  from DARanalytics.datamart.constituent_household_level chl 
	where chl.household_id = DARanalytics.datamart.constituent_level.household_id



END --of SP



GO

