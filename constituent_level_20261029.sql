USE [DARanalytics]
GO

/****** Object:  StoredProcedure [dbo].[uspBuildConstituentLevelTable]    Script Date: 10/29/2026 10:25:45 AM ******/
SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO







/* WARNING: If you are viewing this procedure, always foul the ALTER PROCEDURE line with gibberish so the code does not run (i.e. lkjdasdjfALTER procedure...) 
   Do not comment out or indescriminately run the script, it contains drop table commands that will drop the existing datamart  */
CREATE PROCEDURE [dbo].[uspBuildConstituentLevelTable]

AS BEGIN


/* 
Constituent Data Mart -- Main Data Set
Created by Gary Thompson GAT on 1/30/2023
Last modified by Gary Thompson GAT on 9/25/2024
*/

/************************************************* OVERVIEW **********************************************************
This table is a repository of most of the measures used by DAR Analytics in its
standard reporting and analyses, with one row per constituent ID. Variables have been given descriptive
names, but for more information about each variable and its calculation ....

Any variable with "hh" suffix means that the variable is aggregated at the household level
and both members of the household will have the same value.

NOTE: 
All changes to this table should be vetted through 
the DAR Analytics group
**************************************************************************************************************************/

/************************************************* CHANGE LOG (Newer changes at top) *************************************
10/28/26 -GAT added	eval_pringiv_13_spouse_engagement
10/20/26 -GAT added 	mov_earliest_pending_interaction_type		nvarchar(200) NULL,
						mov_earliest_pending_interaction_objective	nvarchar(200) NULL,
						mov_earliest_pending_interaction_comment	nvarchar(MAX) NULL,
						mov_earliest_pending_interaction_date2		date NULL,
						mov_earliest_pending_interaction_concat_info nvarchar(MAX) NULL,
						mov_num_pending_interactions
10/15/26 -GAT added pg_vehicle_list
10/07/26 -GAT added list_of_education_colleges
09/30/26 -GAT added BESTCAPACITYVALUESORT =99	then NULL (O.Unrated)	as 99 is now a thing (from Al)
09/29/26 -GAT fixed a calculation in principal_giving_score
09/18/26 -GAT added 24 pm_top_unit fields to finally clean that up
09/17/26 -GAT removed the Connectedness Override
09/16/26 -GAT removed flag_lgbtq_affinity
09/15/26 -GAT added mov_earliest_pending_interaction_date, mov_latest_pending_interaction_date
09/11/26 -GAT added pm_mg_prioritization_score and pm_mg_prioritization_score_list to help PD sift through more people
09/08/26 -GAT added pm_current_fundraiser_lead_avp
09/04/26 -GAT added flag_has_pending_plan_interaction
09/01/26 -GAT added flag_has_pending_interaction
09/01/26 -GAT added flag_managed_currently_wo_FM to look at only those managed by the 4 main assignments PM, TM, DM and SM
09/01/26 -GAT added flag_is_principal_gift_prospect from COL
08/27/26 -GAT added gvg_recog_first_hh as part of the connectedness score
08/21/26 -GAT added in geo_addr_pref_msa_code, geo_addr_pref_msa_desc_census
08/20/26 -GAT proposed 3 points for having more than 2 events in current FY to better match NYU bin.  May want to adjust NYU
08/19/26 -GAT proposed 6 points for gvg_recog_received_life_wo_certain_funds_hh > 100k to align with NYU bin. Should move some old (not recent) big donors up a level or two.
08/14/26 -GAT replaced data source reference for flag_rev_ira_gift
08/07/26 -GAT tweaked VCU connectedness score: lowered managed/referral from 7 to 3; lowered double alum from 5 to 4
08/06/26 -GAT updated how flag_is_volunteer is calculated...now using constituent_engagement minus the board membership
08/05/26 -GAT removed 'prospect' and 'individual,prospect' from the eval_vcu_connectedness_score manual overwrite
07/30/26 -GAT Added in flag_legally_contactable_snap_FY26
07/24/26 -GAT Tweaked Connectedness score moving 20 and 21s to B from A
07/23/26 -GAT Improved the biz owner flag - got rid of dim IDs
07/21/26 -GAT Tweaked VCU Connectedness score to better account for double counting some things
07/20/26 -GAT added sol_sum_documented_accepted_ask_last1825
07/08/26 -GAT added flag_mov_stewardship_SPV_interaction_last_365
06/30/26 -GAT NULLed out al_donor_category, al_min_donor_category, al_catgrouping
06/29/26 -GAT added num_email_n_interactions_last24months, num_social_media_engagement_last24months, flag_first_gen_student, flag_award_recipient [for nyu_bin]
06/18/26 -GAT added pm_num_events_tminus0, pm_num_volunteer_tminus0, pm_num_volunteer_tminus1_5, pm_latest_past_committee_end_date -used as factors in NYU binning
06/18/26 -GAT added a flag for first gen students - only started with students in FY26....a ways before they become alums and we will probably never have a definitive all alum field.
06/17/26 -GAT updated and moved Windfall into an SP to speed things along
06/15/26 -GAT added nickname
06/09/26 -GAT moved a view to a SP for the committees member prework to speed up and hopefully solve the late CL runtimes
06/04/26 -GAT added pm_latest_duediligence_note_type to be added to unit_active_pgis DS
06/03/26 -GAT fixed pgi_top_parent_active_latest_year to handle different formats of the top parent comment (year location doesnt matter now)
06/03/26 -GAT tightened up current and past committees subqueries to not be self referential; replaced with code from committees_active_members_prework
06/01/26 -GAT added flag_current_reunion_class
					affil_list_of_current_reunion_schools	
					affil_list_of_current_reunion_class_years	
					affil_list_of_current_reunion_degrees		
					affil_list_of_current_reunion_departments
05/28/26 -GAT added eval_nyu_bin V1
05/26/26 -GAT added 	inv_late_cur_commite_end_date,
						inv_early_cur_commite_end_date,
						inv_latest_cur_board_end_date,
						inv_early_cur_board_end_date,
						inv_latest_cur_board_primary_end_date,
						inv_early_cur_board_primary_end_date,
						inv_latest_committees_past,
						inv_latest_boards_past
05/15/56 -GAT added commit_amount_5bin_highest_single_gift which identifies the highest commitment level of the constituent
05/12/26 -GAT made lots of changes to counting relations in radar and to #7 in the principal giving score
05/11/26 -GAT started work on getting relationship counts more robust
05/11/26 -GAT added gvg_life_total_non_VCU, eval_pringiv_3_big_non_VCU_gvg, eval_pringiv_7_life_connection for the principal giving score
05/07/26 - WW added eval_record_standard_metal for record standards  (platinum/gold/silver/bronze/iron) as a part of the data strategy project
05/05/26 -GAT added flag_rnl_interest_has_DAF and included in DAF calcs and PG calcs
05/05/26 -GAT added flag_parent_prospective_constituency
04/24/26 -GAT added eval_pringiv factors to the principal giving score
04/21/26 -GAT added , val_VCU_principal_giving_points, eval_VCU_principal_giving_score, eval_VCU_principal_giving_rank
04/20/26 -GAT updated VCU connectedness scores to remove giving from certain funds (Massey challenge et al, Real Estate Excellence, Tribute)
04/20/26 -GAT added pm_unit_connectedness_list_ltg_short_all, pm_unit_connectedness_donated_num_all
04/17/26 -GAT added flag_has_non_vcu_education_record, flag_has_vcu_education_record to help with DI metrics
04/14/26 -GAT added engagement_latest_email_click_through_date,	engagement_latest_event_attendance_date
04/14/26 -GAT added bio_name_VCU_Standard_Joint and bio_name_VCU_Standard_Individual
04/14/26 -GAT flag_pgi_top_parent_active, pgi_top_parent_active_latest_year		--for Gordon's parents dash
04/01/26 -GAT added mov_num_sig_interactions_non_DAR_leadership_past_60_months
03/31/26 -GAT added mov_num_SPV_interactions_past_60_months, mov_num_SPV_interactions_with_Rao
03/26/26 -GAT added mov_latest_completed_sig_interaction_owner, mov_latest_completed_sig_interaction_owner_system_id, mov_latest_completed_sig_interaction_type
03/24/26 -GAT added eval_overall_prospect_rank_hh (HH rank) and eval_overall_prospect_rank_cl_hh (highest ranked HH member)
03/23/26 -GAT added eval_default_segment_grid_rank_hh and eval_overall_prospect_rank
03/19/26 -GAT added flag_presidents_club_society
03/11/26 -GAT added pm_current_development_staff as well as adding this group to the team member lists
03/11/26 -GAT edited eval_vcu_connectedness_score & _desc to manually move people to E. Not Connected who have certain CONSTITUENCY lists.
03/10/26 -GAT & GLB added flag_SOM_2000plus_Alum
03/05/26 -GAT added geo_miles_from_richmond
03/05/26 -GAT added in foundation manager fields
01/16/26 -GAT added num_engagements_lifetime, num_engagements_campaign,	max_engagement_date, min_engagement_date	
01/12/26 -GAT added z_date_record_added
01/12/26 -GAT added bio_num_relationships_individuals as part of Acquisition/Retention analysis
12/16/25 -GAT/GB added Grad/Ugrad to bio_parents_of_students_names
12/12/25 -GAT Added 5 'undefined individuals' to the z_exclude_groups
12/05/25 -GAT modified automatic staging to include two more levels.  May mess up some downstream coding since the numbers changed for each item
12/04/25 -GAT added bio_parents_of_students_names for Gordon
12/03/25 -GAT added flag_WF_DAF_indicator field and added flag_WF_DAF_indicator to flag_has_daf_hh  --need to HH that part
12/02/25 -GAT added eval_vcu_primary_giving_connectedness_score -- because someone thinks this is a good idea
12/02/25 -GAT added bio_birth_date_radar -- useful for Russell to look for wonky birthdates in radar
12/01/25 -GAT added flag_platinum_board_member and flag_currently_managed_by_vp
11/18/25 -GAT added bio_org_industry, bio_org_parent_corp, bio_org_is_primary_org
11/13/25 -GAT added num_email_clicks_last365 to the connectedness score.  Also adjusted Range of B connected from min 15 to min 16 to make C2 more exclusive.
11/12/25 -GAT added num_email_clicks_last365
11/12/25 -GAT added flag_vcu_alumni_ug_degree, flag_vcu_young_alumni_ug_degree, flag_vcu_alumni_grad_degree, flag_vcu_young_alumni_grad_degree, flag_vcu_recent_any_degree for GB and Julia
11/10/25 -WW  added in volunteer & mentor attribute flags, per RBM request on the AEO dash
11/07/25 -GAT Added flag_has_picture_in_radar, cntc_linkedin, cntc_facebook, cntc_twitter
10/21/25 -GAT Updated to use the gvg_revenue_history_summary_indiv datamart rather than view
10/17/25 -GAT Moved flag_prospect_managed_activation_hh, flag_assigned_activation_hh from the view to here
10/14/25 -GAT Added flag_legally_contactable (Wren needed it.  Comes from Al and is snapshotted annually)
					flag_legally_contactable_snap  -- from the latest snap of Als
					flag_min_class_year
10/13/25 -GAT Added gvg_latest_vcu_recognition_txt and gvg_latest_vcu_recognition_txt_hh (at the line item level)
10/08/25 -GAT Added bio_employer_lookup_id, bio_employer_dim_id
09/30/25 -GAT Added bio_job_department, bio_job_division, bio_job_schedule
09/29/25 -GAT added flag_bio_job_current, bio_job_career_level, bio_job_relationship_type
09/29/25 -GAT redefined flag_pgi_NAP_all_VCU_active to include 'all levels' and principal/major gifts only
			  removed flag_pgi_principal_gift_active and flag_pgi_af_gift_active
09/19/25 -GAT changed and added: 	pg_fall_appeal_segmentation_ageclass		--the first two were renamed
								  , pg_spring_appeal_segmentation_ageclass
								  , pg_spring_appeal_segmentation_campus
								  , pg_spring_appeal_segmentation_connectedness
								  , pg_spring_appeal_segmentation_connectedness_score
09/17/25 -GAT added flag_VCU_employees_to_exclude_hh as we don't want spouses of these people either
09/17/25 -GAT added flag_VCU_employees_to_exclude (includes students) to identify non-managed VCU employees so as not to track them in campaign metrics. Also added flag_student
09/02/25 -GAT added in some pm_current_PM fields to identify these people 
08/28/25 -GAT added in some fields for dealing with the 'Primary' Boards
08/28/25 -GAT added bio_job start/end_dates
08/27/25 -GAT changed flag_daf_3_types to flag_has_daf_hh
08/25/25 -GAT updated eval_VCU_planned_giving_score_SQL to include touchpoints parents field (nokids); also merged in touchpoints DAF indicator with has used a DAF
08/25/25 -GAT added flag_has_nokids_TP_hh, flag_has_nokids 
08/25/25 -GAT added flag_parent_past_constituency
08/22/25 -GAT added more SSMS recommended indexes
08/21/25 -WW added eval_vcu_connect_survey_respondant, which awards 3 points when a person responds to at least 1 survey in the last 3 yrs
08/18/25 -GAT added many new indexes including household_system_id and flag_is_primary_hh_member.  Got rid of some name indexes
08/14/25 -GAT added bio_employer_system_id and bio_job_category to help with identifying job industry
08/11/25 -GAT created flag_daf_3types to include 3 different methods:  Giving via DAF, Touchpoint data, Gift
07/18/25 -GAT added in pm_current_prospect_manager, pm_current_stewardship_manager, pm_current_team_member, pm_current_discovery_manager
07/17/25 -GAT Bug fixes on managed prospects and their officers to take account of updated COL with past officers
07/15/25 -GAT and GLB  Added in flag_business_owner
07/01/25 -GAT Added in 4 touchpoint fields flag_TP_parent, flag_TP_foundation, flag_TP_complex_assets, flag_TP_DAF
06/13/25 -GLB Reverted changes to flag_pgi_PG_VCU_future from 05/14/25 change log per Ann D request. Wanted to include supsects without fundraisers in tier 1.
05/14/25 -GAT Updated flag_pgi_planned_gift_active to include all active PG PGIs.  Also updated flag_pgi_PG_VCU_future to not include suspects without fundraisers
04/28/25 -GAT Added eval_vcu_connect_events_past3yrs_attended
04/14/25 -GAT Added mov_latest_completed_sig_all_interaction_cultivate 
04/10/25 -GAT Added flag_pgi_PG_referral as well as adding it to tier 1 criteria in the PG tiering in CHL code
03/13/25 -GAT Fixed constituency flags to use system IDs and not DIM IDs. Fixed a few other subqueries proactively similarly
03/06/25 -GAT Added pm_current_fundraiser_lead_unit
02/26/25 -GAT Added in affil_subdepartment1 (2-4)
02/25/25 -GAT Added spouse_sonstituency_list
02/24/25 -GAT Added bio_name_sans_D and spouse_name_sans_D so that we can show the name without the deceased modifier
02/24/25 -GAT Added affil_education_system_id1(2-4) to be able to join to the origin tables if needed
02/19/25 -GAT modified the definitions of flag_pgi_planned_gift_active, flag_pgi_PG_referral and flag_PGI_PG_VCU_future, flag_pgi_referral_active
02/12/25 -GAT Added bio_middlename and bio_middle_initial  -and the spouse equivalents
02/11/25 -GAT Tweaked connectedness score for events.
01/28/25 -GAT Added pm_latest_duediligence_author, title, text, added_date, changed_date
01/24/25 -GAT Added pm_current_team_unit_names; Also updated mpar references to FUD
01/14/25 -GAT Added gvg_latest_designation_name, gvg_latest_vcu_recognition_amount
01/14/25 -GAT Added MPAR alum/staffing flags - flag_SOM_alum, flag_physician etc...
01/10/25 -GAT flipped Cultivation and Stewardship in the pm_calculated_stage
01/09/25 -GAT added pm_current_team_system_ids and pm_current_team_lookup_ids (updated 1/20/25 to include (PM,TM etc)
12/19/24 -GAT Added pm_latest_duediligence_note_enter_date
12/19/24 -GAT Added pm_lagodeo_connectedness_list, pm_lagodeo_connectedness_num
12/19/24 -GAT Added pm_lagodeo_primary_campus, pm_lagodeo_primary_segment, pm_lagodeo_primary_connectedness, pm_lagodeo_primary_connectedness_score
--12/16/24 -GAT Added LAGODEO_Segmentation
12/13/24 -GAT Added pm_current_team_lead_spouse in order to look for PM assignment mismatches
12/12/24 -GAT Added PG Spring Appeal segmentation 'unit' - pg_AGAthMPAR_appeal_segmentation_ageclass
12/03/24 -GAT added in event counts for total and campaign to vcu connectedness score
11/27/24 -GAT added flag_campaign_primary_transaction_donor_hh
11/26/24 -GAT added pm_top_unit_campaign_name_hh
11/25/24 -GAT added gvg_campaign_donor_level_hh (Primary, Major, Principal, Non-Donor)
11/06/24 -GAT pm_servicearea_connectedness_list, pm_servicearea_connectedness_num for Wren
11/01/24 -GAT Added flag_di_vip after talking to Russell
10/31/24 -GAT Added pm_current_assignment_status
10/29/24 -GAT eval_bwf_acquisition_rating, eval_bwf_reactivation_rating, eval_bwf_retention_rating
10/24/24 -GAT Added in bio_birthday_next, flag_pgi_PG_referral, flag_pgi_PG_VCU_NAP, flag_pgi_PG_VCU_future, flag_pgi_PG_unit_NAP
10/17/24 -GAT Added PG Fall Appeal segmentation 'unit' - pg_AGMPAR_appeal_segmentation_ageclass
09/25/24 -GAT Updated flag_parent_current to be a blend of parent constituency and having a recent VChild; Created flag_is_parent_relationship
09/13/24 -GAT Started to update the PG Algorithm for eventual HH Tiers
09/12/24 -GAT Added flag_lgbtq_affinity, flag_donated_on_a_giving_day_hh, flag_50k_transaction_donor_hh, flag_has_given_stock_hh, flag_has_pg_vehicle_hh	
09/10/24 -GAT Added Gordons NoKids Python script table [flag_has_nokids_GB] - datamart.dbo.pg_nochildren_interactions_phrases
09/09/24 -GAT Added flag_parent_of_freshman
09/06/24 -GAT Added Vchild Parents two fields - flag and latest date.  Should allow us to identify new parents.
09/05/24 -GAT Added household_system_id to have a consistent ID over time
09/05/24 -GAT Added pm_stage_calculated_hh as a NULL placeholder that will get updated in a later SP that follows after the creation of the CHL table
09/04/24 -GAT Added flag_has_endowed_a_fund to use in the PG algorithm
08/15/24 -GAT prospect_status NULLs to 'No Prospect Status' -> Unassigned
08/06/24 -GAT added pm_unit_connectedness_num_all and  pm_unit_connectedness_list_all: which don't exclude NAPs and non-philanthropic units
07/29/24 -GAT Removed Key Influencer from sols_staging for plan participants.
07/26/24 -GAT Tweaked sol_staging to reduce Cultivations from old accepted docs.  changed to 2-5 years, living and not NAP.  Moved older ones to Qualification
07/22/24 -GAT Added mov_latest_completed_sig_interaction_orig and mov_earliest_completed_sig_interaction_orig
07/18/24 -GAT Tweaked sol_staging to put Deceased in the 3 spot but as * to be corret for HH stage.
07/16/24 -GAT Tweaked sol_staging cultivation definition and moved Stewardship into the 2nd tier dropping Cultivation to 3rd
07/15/24 -GAT Reordered automatic staging to put Qualification after stewardships
07/12/24 -GAT Updated query sols_staging to include certain plan participants on the opportunity
07/03/24 -GAT Added eval_default_segment_grid_rank
07/01/24 -GAT Added mov_latest_completed_sig_participant_interaction_cultivate, mov_latest_completed_sig_discovery_interaction_cultivate
06/24/24 -GAT Bug fix on Committees sub query to better catch those that are currently on boards and giving circles.
06/18/24 -GAT Added flag_vcu_facstaff_current and renamed flag_vcu_facstaff_retired.  33 people flagged as both.
06/06/24 -GAT Added geo_addr_pref_type
05/31/24 -GAT Added mov_latest_completed_sig_primary_interaction_cultivate & mov_latest_completed_sig_secondary_interaction_cultivate
05/17/24 -GAT Added flag_exclude_call_list_VCU
05/06/24 -GAT More changes to pm_stage_calculated - reordered priority
04/22/24 -GAT Removed the pd_hh subquery. and the prospect_status_hh deprecated field
04/19/24 -GAT took out flag_top_hh_member until work out duplicate row creation
04/19/24 -GAT Updated unit lists to better sort, remove NAPs and unconnected
04/17/24 -GAT Changed z_last_update to datetime to see when it is running from
04/16/24 -GAT Changed connected unit lists to only include the philanthropic MAIN units
04/16/24 -GAT Added in top main unit calcs to only pull the units we care about
04/15/24 -GAT Added pm_prospect_status_radar to look for inconsistencies
04/03/24 -GAT More changes to pm_stage_calculated
03/28/24 -GAT Made changes to pm_stage_calculated
03/15/24 -GAT Added in pm_stage_calculated
03/15/24 -GAT made life expectency gender default to female if gender is unknown or other per AnnD's instructions
03/06/24 -GAT Added sol_sum_expected_ask_rolling_365x2 & sol_sum_both_ask_rolling_365x2
02/29/24 -GAT Added in some latest not_LAGO interaction fields; added in nametags for primary unit member
02/23/24 -GAT Added in some latest LAGO interaction fields
02/16/24 -GAT Add bio_expected_death_FY
02/12/24 -GAT Add in flag_black_and_gold_loyalty_society
01/30/24 -GAT Added in eval_best_capacity min,max,mid
01/05/24 -GAT Added flag_any_completed_sig_interaction_last_365; updated topunits to account (remove) for PGI NAP-unit.
01/02/24 -GAT Removed Not A Prospect Unit PGIs from the Unit connectedness list fields.
12/21/23 -GAT Added in topunit12 fields for SME (Ashley) to choose the best CSU for everyone
12/06/23 -GAT Updated eval_VCU_connectedness score with Rachel.  Also created flag_strikezone_new to compare with BWF old.
01/30/23 -GAT Let's get this party started



**************************************************************************************************************************/
/*
BEGIN TRY
*/

declare 
		@destTable nvarchar(30),
		@startTime datetime,
		@rowsLoaded int,
		@errorMessage nvarchar(1000)
	
	set @startTime = getDate();
	set @errorMessage = N'';
	--set @fileprefix = 'gif';
	set @destTable = 'datamart.constituent_level';

	--select @filedatestring = convert(nchar(8), getDate(), 112)
/*
	exec analytics.dbo.sp_logTableLoad @destTable, N'start', @startTime, N'NoFileSource';
*/
	
	BEGIN
		IF  EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'datamart.constituent_level_temp') AND type in (N'U'))
			DROP TABLE datamart.constituent_level_temp

				
CREATE TABLE datamart.constituent_level_temp(

	z_last_update datetime NOT NULL,
	constituent_dim_id int NOT NULL,        
	constituent_system_id uniqueidentifier NOT NULL,
	constituent_lookup_id nvarchar(100) NULL,
	household_system_id uniqueidentifier NULL,
	household_id int NULL,  --
	household_lookup_id nvarchar(100) NULL,  --
	flag_is_primary_hh_member tinyint NULL,  --
	bio_name nvarchar(154) NOT NULL,
	bio_name_sans_D nvarchar(154) NOT NULL,
	bio_full_name_summary nvarchar(100) NULL,
	bio_lastname nvarchar(100) NULL,
	bio_firstname nvarchar(50) NULL,
	bio_nickname nvarchar(50) NULL,
	bio_middlename nvarchar(50) NULL,
	bio_middle_initial nvarchar(2) NULL,
    bio_lastcommafirstname nvarchar(155) NULL,
	bio_name_VCU_Standard_Joint nvarchar(255) NULL,
	bio_name_VCU_Standard_Individual nvarchar(255) NULL,
	bio_salutation nvarchar(50) NULL,
	bio_suffix nvarchar(100) NULL,
	bio_name_tag nvarchar(150) NULL,
--	bio_name_informal_hh nvarchar(700) NULL,
--	bio_name_informal_hh_last nvarchar(700) NULL,
--	bio_name_lastfirst_hh nvarchar(700) NULL,
	bio_record_type nvarchar(20) NULL,
--	bio_primary_record_type nvarchar(8) NULL,
	bio_record_status nvarchar(8)  NULL,
	bio_org_industry nvarchar(200) NULL,
	bio_org_parent_corp nvarchar(308) NULL,
	bio_org_is_primary_org tinyint NULL,
	bio_gender nvarchar(10) NULL,
	bio_race_desc nvarchar(500) NULL,
	bio_citizenship1 nvarchar(50) NULL,
	bio_citizenship2 nvarchar(50) NULL,
	bio_employer_name nvarchar(100) NULL,
	bio_employer_system_id uniqueidentifier NULL,
	bio_employer_lookup_id nvarchar(100) NULL,
	bio_employer_dim_id int NULL,
	bio_job_title nvarchar(154) NULL,
	bio_job_category nvarchar(100) NULL,
	bio_job_start_date date NULL,
	bio_job_end_date date NULL,
	flag_bio_job_current tinyint NULL,
	bio_job_career_level nvarchar(100) NULL,
	bio_job_department nvarchar(100) NULL,
	bio_job_division nvarchar(100) NULL,
	bio_job_schedule nvarchar(100) NULL,
	bio_job_relationship_type nvarchar(100) NULL,
	bio_age int NULL,
	bio_generation nvarchar(25) NULL,
	bio_birth_date_radar nvarchar(8) NULL,
	bio_birth_date date NULL,
	bio_birthday_next date NULL,
	bio_death_date date NULL,
	bio_expected_death_FY int NULL,
	bio_constituency_list nvarchar(4000)  NULL,
	bio_marital_status nvarchar(100) NULL,
	bio_num_living_children_in_radar smallint NULL,
	flag_has_nokids_GB	tinyint NOT NULL,
	flag_has_nokids_TP_hh	tinyint NULL,
	flag_has_nokids		tinyint NOT NULL,
	bio_date_added  date NULL,
	bio_date_changed date NULL,
	bio_parents_of_students_names nvarchar(200) NULL,
	bio_num_relationships_individuals int NULL,

	spouse_dim_id int NULL,
	spouse_system_id nvarchar(100) NULL,
	spouse_lookup_id nvarchar(100) NULL,
	spouse_name nvarchar(154) NULL,
	spouse_name_sans_D nvarchar(154) NULL,
	spouse_lastname nvarchar(100) NULL,
	spouse_firstname nvarchar(50) NULL,
	spouse_middlename nvarchar(50) NULL,
	spouse_middle_initial nvarchar(2) NULL,
    spouse_lastcommafirstname nvarchar(155) NULL,
	spouse_salutation nvarchar(50) NULL,
	spouse_suffix nvarchar(100) NULL,
	spouse_name_tag nvarchar(150) NULL,
	spouse_primary_record_type_desc nvarchar(50) NULL,
	spouse_primary_record_status nvarchar(1) NULL,
	spouse_gender nvarchar(10) NULL,
	spouse_employer_name nvarchar(150) NULL,
	spouse_job_title nvarchar(100) NULL,
	spouse_age int NULL,
	spouse_generation nvarchar(25) NULL,
	spouse_birth_date date NULL,
	spouse_death_date date NULL,
	spouse_constituency_list nvarchar(4000)  NULL,
	spouse_affil_preferred_class nvarchar(10) NULL,
	
	parent_constituency_start_date date NULL,

	inv_late_cur_commite_start_date date NULL,
	inv_early_cur_commite_start_date date NULL,
	inv_latest_cur_board_start_date date NULL,
	inv_early_cur_board_start_date date NULL,
	inv_latest_cur_board_primary_start_date date NULL,
	inv_early_cur_board_primary_start_date date NULL,
	inv_latest_committees_current nvarchar(MAX) NULL,
	inv_latest_boards_current nvarchar(MAX) NULL,

	inv_late_cur_commite_end_date date NULL,
	inv_early_cur_commite_end_date date NULL,
	inv_latest_cur_board_end_date date NULL,
	inv_early_cur_board_end_date date NULL,
	inv_latest_cur_board_primary_end_date date NULL,
	inv_early_cur_board_primary_end_date date NULL,
	inv_latest_committees_past nvarchar(MAX) NULL,
	inv_latest_boards_past nvarchar(MAX) NULL,



--	ila_latest_event_date date NULL,
--	ila_latest_committee_date_service date NULL,
--	ila_latest_gift_club_date date NULL,
--	ila_earliest_event_date date NULL,
--	ila_earliest_gift_club_date date NULL,
--	ila_latest_events nvarchar(255) NULL,
--	ila_latest_committees_former nvarchar(255) NULL,
--	ila_latest_boards_former nvarchar(255) NULL,
--	ila_latest_gift_clubs nvarchar(500) NULL,
--	ila_num_volunteer_records int NOT NULL,
--	ila_days_volunteer_service int NOT NULL,
--	flag_ila_network_login_tminus0 smallint NOT NULL,
--	flag_ila_network_login_tminus1 smallint NOT NULL,
--	flag_ila_network_login_tminus2 smallint NOT NULL,
--	flag_ila_network_login_tminus3 smallint NOT NULL,
--	flag_ila_network_login_tminus4 smallint NOT NULL,
--	flag_ila_network_login_tminus5 smallint NOT NULL,
--	comms_email_activity_tminus0 smallint NOT NULL,
--	comms_email_activity_tminus1 smallint NOT NULL,
--	comms_email_activity_tminus2 smallint NOT NULL,
--	comms_email_activity_tminus3 smallint NOT NULL,
--	comms_email_activity_tminus4 smallint NOT NULL,
--	comms_email_activity_tminus5 smallint NOT NULL,
--	flag_ila_season_tix_tminus0 smallint NOT NULL,
--	flag_ila_season_tix_tminus1 smallint NOT NULL,
--	flag_ila_season_tix_tminus2 smallint NOT NULL,
--	flag_ila_season_tix_tminus3 smallint NOT NULL,
--	flag_ila_season_tix_tminus4 smallint NOT NULL,
--	flag_ila_season_tix_tminus5 smallint NOT NULL,

	affil_preferred_school nvarchar(100) NULL,
	affil_preferred_class int NULL,
	affil_yrs_til_reunion tinyint NULL,
--	affil_vcu_schools nvarchar(255) NULL,
--	affil_vcu_majors nvarchar(255) NULL,
--	affil_vcu_degrees nvarchar(48) NULL,
--	affil_full_vcu_affils nvarchar(450) NULL,
	affil_ug_reunion_class nvarchar(4) NULL,
	affil_ug_yrs_til_reunion tinyint NULL,

	flag_current_reunion_class					tinyint NOT NULL,
	affil_list_of_current_reunion_schools		nvarchar(max) NULL,
	affil_list_of_current_reunion_class_years	nvarchar(max) NULL,
	affil_list_of_current_reunion_degrees		nvarchar(max) NULL,
	affil_list_of_current_reunion_departments	nvarchar(max) NULL,

	 affil_education_system_id1 uniqueidentifier NULL,
	 affil_institution1		nvarchar(100) NULL,
	 affil_school1			nvarchar(100) NULL,
     affil_department1		nvarchar(100) NULL,
     affil_major1			nvarchar(100) NULL,
	 affil_degree1			nvarchar(100) NULL,
     affil_class1			int NULL,
     affil_preferred_class1	int NULL,

	 affil_education_system_id2 uniqueidentifier NULL,
	 affil_institution2		nvarchar(100) NULL,
	 affil_school2			nvarchar(100) NULL,
     affil_department2		nvarchar(100) NULL,
     affil_major2			nvarchar(100) NULL,
	 affil_degree2			nvarchar(100) NULL,
     affil_class2			int NULL,
     affil_preferred_class2	int NULL,

	 affil_education_system_id3 uniqueidentifier NULL,
	 affil_institution3		nvarchar(100) NULL,
	 affil_school3			nvarchar(100) NULL,
     affil_department3		nvarchar(100) NULL,
     affil_major3			nvarchar(100) NULL,
	 affil_degree3			nvarchar(100) NULL,
     affil_class3			int NULL,
     affil_preferred_class3	int NULL,

 	 affil_education_system_id4 uniqueidentifier NULL,
	 affil_institution4		nvarchar(100) NULL,
	 affil_school4			nvarchar(100) NULL,
     affil_department4		nvarchar(100) NULL,
     affil_major4			nvarchar(100) NULL,
	 affil_degree4			nvarchar(100) NULL,
     affil_class4			int NULL,
     affil_preferred_class4	int NULL,

	 /* Hopefully these 4 will be replaced in VCU_RPT_CONSTITUENTLIST at some point after 2/26/25 */
	 affil_subdepartment1	nvarchar(100) NULL,
	 affil_subdepartment2	nvarchar(100) NULL,
	 affil_subdepartment3	nvarchar(100) NULL,
	 affil_subdepartment4	nvarchar(100) NULL,
	 affil_min_class_year	int NULL,

	 flag_vcu_alumni_ug_degree			tinyint NOT NULL,
	 flag_vcu_young_alumni_ug_degree	tinyint NOT NULL,
	 flag_vcu_alumni_grad_degree		tinyint NOT NULL,
	 flag_vcu_young_alumni_grad_degree	tinyint NOT NULL,
	 flag_vcu_recent_any_degree			tinyint NOT NULL,
	 list_of_education_colleges			nvarchar(750) NULL,

	 flag_has_non_vcu_education_record	tinyint NOT NULL,
	 flag_has_vcu_education_record		tinyint NOT NULL,

--	affil_grad_reunion_class nvarchar(4) NULL,
--	affil_grad_yrs_til_reunion tinyint NULL,
--	affil_other_schools nvarchar(255) NULL,
--	affil_other_degrees nvarchar(48) NULL,

--	bio_num_vcu_children smallint NULL,
     cntc_primary_phone nvarchar(100) NULL,
	 cntc_primary_phone_type nvarchar(100) NULL,
	 cntc_primary_email nvarchar(100) NULL,
	 cntc_facebook nvarchar(2047) NULL,
	 cntc_linkedin nvarchar(2047) NULL,
	 cntc_twitter nvarchar(2047) NULL,
	 cntc_spouse_primary_phone nvarchar(100) NULL,
	 cntc_spouse_primary_email nvarchar(100) NULL,
	flag_cntc_valid_phone tinyint NOT NULL,
	flag_cntc_valid_email tinyint NOT NULL,
	flag_cntc_valid_mail tinyint NOT NULL,
	flag_cntc_hbone tinyint NOT NULL,
	flag_cntc_engaged_email tinyint NOT NULL,
--	cntc_spouse_email nvarchar(127) NULL,
--	geo_addr_pref_addrnumber int NULL,
--	geo_addr_pref_primary nvarchar(255) NULL,
	geo_addr_pref_type nvarchar(100) NULL,
	geo_addr_pref_street nvarchar(150) NULL,
	geo_addr_pref_city nvarchar(50) NULL,
	geo_addr_pref_county nvarchar(100) NULL,
	geo_addr_pref_state nvarchar(50) NULL,
	geo_addr_pref_zip nvarchar(12) NULL,
	geo_addr_pref_zip_US5 nvarchar(5) NULL,
	geo_addr_pref_country nchar(5) NULL,
	geo_addr_pref_country_name nvarchar(100) NULL,
	geo_addr_pref_country_name2 nvarchar(100) NULL,
	geo_addr_pref_lat float NULL,
	geo_addr_pref_long float NULL,
	geo_addr_pref_msa_desc nchar(100) NULL,
	geo_addr_pref_msa_code nvarchar(5) NULL,
	geo_addr_pref_msa_desc_census nvarchar(100) NULL,
	geo_latest_address_change_date date NULL,
	geo_miles_from_richmond int NULL,

	eval_capacity_rating int NULL,
	eval_capacity_rating_desc nvarchar(50) NULL,
	eval_capacity_rating_desc_sort nvarchar(50) NULL,
	eval_capacity_rating_desc_short nvarchar(20) NULL,
	eval_capacity_rating_desc_short_sort nvarchar(20) NULL,
	eval_capacity_type_rank int NULL,
	eval_capacity_type_desc1 nvarchar(50) NULL,
	eval_capacity_type_desc2 nvarchar(50) NULL,

	eval_capacity_rating_date date NULL,
	eval_research_status_confirmer nvarchar(50) NULL,
	eval_research_status_confirm_date date NULL,
	eval_capacity_level_lower float NULL,
	eval_capacity_level_upper float NULL,
	eval_capacity_level_mid float NULL,

	eval_bwf_connectedness nvarchar(50) NULL,
	eval_vcu_connectedness_score int NULL,
	eval_vcu_connectedness_desc nvarchar(25) NULL,

	eval_vcu_connect_alum int NULL,
	eval_vcu_connect_double_alum_hh int NULL,
	eval_vcu_connect_parent_current	int NULL,
	eval_vcu_connect_volunteer int NULL,
	eval_vcu_connect_rel_count int NULL,
	eval_vcu_connect_managed int NULL,
	eval_vcu_connect_discovery_managed int NULL,
	eval_vcu_connect_contact_info int NULL, 
	eval_vcu_connect_gvg_10k int NULL, 
	eval_vcu_connect_gvg_2k_under30yo int NULL,  
	eval_vcu_connect_gvg_gift_cnt int NULL,	
	eval_vcu_connect_gvg_each5FYs int NULL,
	eval_vcu_connect_gvg_first_75 int NULL,
	eval_vcu_connect_has_job_info int NULL, 
	eval_vcu_connect_do_not_contact  int NULL, 
	eval_vcu_connect_pgi_not_unit_prospect int NULL,
	eval_vcu_connect_pgi_suspect_or_positive int NULL,  
	eval_vcu_connect_gvg_recency int NULL,
	eval_vcu_connect_num_boardsNcommittees int NULL,
	eval_vcu_connect_ed_count int NULL,
	eval_vcu_connect_facstaff int NULL,
	eval_vcu_connect_events_past3yrs_attended	 int NULL,
	eval_vcu_connect_survey_respondant int NULL,

	eval_bwf_major_gift_rating		nvarchar(50) NULL,
	eval_bwf_planned_gift_rating	nvarchar(50) NULL,
	eval_bwf_acquisition_rating		nvarchar(50) NULL,
	eval_bwf_reactivation_rating	nvarchar(50) NULL,
	eval_bwf_retention_rating		nvarchar(50) NULL,

	eval_vcu_planned_giving_score int NULL,
	eval_vcu_planned_giving_score_SQL int NULL,
	
	eval_PG_score_age				tinyint NULL,
	eval_PG_score_classyr 			tinyint NULL,
	eval_PG_score_clergy 			tinyint NULL,
	eval_PG_score_marstat			tinyint NULL,
	eval_PG_score_volunteer			tinyint NULL,
	eval_PG_score_retired_facstaff	tinyint NULL,
	eval_PG_score_ira_gift			tinyint NULL,
	eval_PG_score_has_daf_hh		tinyint NULL,
	eval_PG_score_used_ff			tinyint NULL,
	eval_PG_score_gvg_freq  		tinyint NULL,
	eval_PG_score_seasonal_property	tinyint NULL,
	eval_PG_score_FY_cash			tinyint NULL,
	eval_PG_score_FY22_New_Donor	tinyint NULL,		--This needs work - will incresingly become wrong
	eval_PG_score_200pct			tinyint NULL,

	eval_wf_enriched_date	date NULL,
	eval_wf_net_worth	bigint NULL,
	pm_unit_connectedness_list_all nvarchar(MAX) NULL,		--these 4 will be one day lagging - no restrictions on units
	pm_unit_connectedness_num_all smallint NOT NULL,
	pm_unit_connectedness_list nvarchar(MAX) NULL,		--these 4 will be one day lagging --excludes non-philanthropic units, NAPs, 
	pm_unit_connectedness_num smallint NOT NULL,
	pm_unit_connectedness_list_other nvarchar(MAX) NULL,
	pm_unit_connectedness_num_other smallint NOT NULL,
	pm_unit_connectedness_list_ltg_short_all nvarchar(MAX) NULL,
	pm_unit_connectedness_donated_num_all smallint NOT NULL,
	pm_servicearea_connectedness_list nvarchar(MAX) NULL,
	pm_servicearea_connectedness_num smallint NOT NULL,
	pm_lagodeo_connectedness_list nvarchar(MAX) NULL,
	pm_lagodeo_connectedness_num smallint NOT NULL,

	eval_default_segment_grid_rank smallint NULL,
	eval_default_segment_grid_rank_hh smallint NULL,
	eval_overall_prospect_rank			int NULL,
	eval_overall_prospect_rank_hh		int NULL,
	eval_overall_prospect_rank_cl_hh	int NULL,
	pm_mg_prioritization_score			smallint NULL,
	pm_mg_prioritization_score_list		nvarchar(200) NULL,

	pm_current_team varchar(500) NOT NULL,
	pm_current_team_system_ids varchar(500) NOT NULL,
	pm_current_team_lookup_ids varchar(500) NOT NULL,
	pm_current_team_unit_names varchar(500) NOT NULL,
	pm_current_fundraiser_lead varchar(127) NULL,
	pm_current_fundraiser_lead_unit varchar(50) NULL,
	pm_current_fundraiser_lead_avp varchar(50) NULL,
--	pm_current_team_size smallint NOT NULL,
	pm_current_team_lead varchar(127) NULL,
	pm_current_team_lead_spouse varchar(127) NULL,
--	pm_current_team_lead_email varchar(63) NULL,
--	pm_latest_team_member_date date NULL,
	pm_current_assignment_status nvarchar(25) NULL,
	pm_current_managing_unit_name varchar(63) NULL,
	pm_current_managing_unit_id nvarchar(3) NULL,
	pm_current_prospect_manager nvarchar(127) NULL,
	pm_current_stewardship_manager nvarchar(127) NULL,
	pm_current_team_member nvarchar(127) NULL,
	pm_current_discovery_manager nvarchar(127) NULL,
	pm_current_foundation_manager nvarchar(127) NULL,
	pm_current_development_staff nvarchar(127) NULL,

	pm_current_PM_system_id	uniqueidentifier NULL,
	pm_current_PM_lookup_id nvarchar(100) NULL,
	pm_current_PM_latest_unit_name nvarchar(100) NULL,
	pm_current_PM_latest_unit_name_short nvarchar(100) NULL,
	pm_current_PM_latest_unit_name_campaign nvarchar(100) NULL,
	pm_current_PM_latest_avp nvarchar(50) NULL,

	pm_prospect_status nvarchar(30) NULL,
--	pm_prospect_status_hh  nvarchar(30) NULL,
	pm_prospect_status_radar nvarchar(30) NULL,
	pm_stage_calculated nvarchar(30) NULL,
	pm_stage_calculated_hh nvarchar(30) NULL,
	
	pm_num_active_prospect_plans int NOT NULL,
    pm_prospect_plan_active_earliest_start_date date NULL,
	pm_prospect_plan_active_latest_start_date date NULL,
	pm_solicit_code_list nvarchar(max) NULL,

	pg_primary_campus nvarchar(30) NULL,
	pg_primary_unit nvarchar(40) NULL,
	pg_primary_unit_connectedness nvarchar(100) NULL,
	pg_primary_unit_connectedness_score int NULL,


	/*all 48 or so CSUs*/
	pm_top_unit_campus_allCSU nvarchar(30) NULL,
	pm_top_unit_allCSU nvarchar(40) NULL,
	pm_top_unit_short_allCSU nvarchar(40) NULL,
	pm_top_unit_system_id_allCSU uniqueidentifier NULL,
	pm_top_unit_connectedness_desc_allCSU nvarchar(100) NULL,
	pm_top_unit_connectedness_score_allCSU int NULL,

	/*29 or so Philanthropic CSUs*/
	pm_top_unit_campus_philanthropic nvarchar(30) NULL,
	pm_top_unit_philanthropic nvarchar(40) NULL,
	pm_top_unit_short_philanthropic nvarchar(40) NULL,
	pm_top_unit_system_id_philanthropic uniqueidentifier NULL,
	pm_top_unit_connectedness_desc_philanthropic nvarchar(100) NULL,
	pm_top_unit_connectedness_score_philanthropic int NULL,

	/*12 (14) or so Annual/Primary Giving CSUs*/
	pm_top_unit_campus_AG nvarchar(30) NULL,
	pm_top_unit_AG nvarchar(40) NULL,
	pm_top_unit_short_AG nvarchar(40) NULL,
	pm_top_unit_system_id_AG uniqueidentifier NULL,
	pm_top_unit_connectedness_desc_AG nvarchar(100) NULL,
	pm_top_unit_connectedness_score_AG int NULL,

	/*12 (14) or so Annual/Primary Giving CSUs + 4 MPAR CSUs*/
	pm_top_unit_campus_AG_MPAR nvarchar(30) NULL,
	pm_top_unit_AG_MPAR nvarchar(40) NULL,
	pm_top_unit_short_AG_MPAR nvarchar(40) NULL,
	pm_top_unit_system_id_AG_MPAR uniqueidentifier NULL,
	pm_top_unit_connectedness_desc_AG_MPAR nvarchar(100) NULL,
	pm_top_unit_connectedness_score_AG_MPAR int NULL,




	pg_fall_appeal_segmentation_ageclass nvarchar(40) NULL,
	pg_spring_appeal_segmentation_ageclass nvarchar(40) NULL,
	pg_spring_appeal_segmentation_campus nvarchar(25) NULL,
	pg_spring_appeal_segmentation_connectedness nvarchar(50) NULL,
	pg_spring_appeal_segmentation_connectedness_score smallint NULL,

	--pm_LAGODEO_segmentation nvarchar(40) NULL,
	pm_lagodeo_primary_campus nvarchar(30) NULL,
	pm_lagodeo_primary_segment nvarchar(40) NULL,
	pm_lagodeo_primary_connectedness nvarchar(100) NULL,
	pm_lagodeo_primary_connectedness_score int NULL,
	
	/*these should be retired by the ones pm_top_unit fields above*/
	pm_top_unit_connectedness_desc	nvarchar(25) NULL,
	pm_top_unit_connectedness_score int NULL,
	pm_top_unit_name				nvarchar(40) NULL,
	pm_top_unit_id					nvarchar(3) NULL,
	pm_top_unit_avp_officer_manager nvarchar(50) NULL,

	pm_top12_unit_connectedness_desc	nvarchar(25) NULL,
    pm_top12_unit_name_short			nvarchar(40) NULL,
	pm_top12_site_id					uniqueidentifier NULL,
	/*end of obsolete*/

	/*Do I keep the household versions of obsolete stuff??*/
	pm_top_unit_connectedness_desc_hh	nvarchar(25) NULL,
	pm_top_unit_connectedness_score_hh	int NULL,
    pm_top_unit_name_hh					nvarchar(40) NULL,
    pm_top_unit_campaign_name_hh		nvarchar(250) NULL,
	pm_top_unit_id_hh					nvarchar(3) NULL,
	pm_top_unit_avp_officer_manager_hh  nvarchar(50) NULL,

	pm_top_main_unit_connectedness_desc_hh	nvarchar(25) NULL,
	pm_top_main_unit_connectedness_score_hh	int NULL,
    pm_top_main_unit_name_hh				nvarchar(40) NULL,
	pm_top_main_unit_id_hh					nvarchar(3) NULL,
	pm_top_main_unit_avp_officer_manager_hh nvarchar(50) NULL,

	pm_parent_vchild_latest_start_date		date NULL,
	pm_flag_parent_has_vchild				tinyint NOT NULL,
	pm_flag_parent_of_freshman				tinyint NOT NULL,

	pm_latest_duediligence_note_enter_date		date NULL,
	pm_latest_duediligence_author				nvarchar(100) NULL,
	pm_latest_duediligence_note_added_date		date NULL,
	pm_latest_duediligence_note_changed_date	date NULL,
	pm_latest_duediligence_note_title			nvarchar(50) NULL,
	pm_latest_duediligence_note_text			nvarchar(MAX) NULL,
	pm_latest_duediligence_note_type			nvarchar(100) NULL,

	num_engagements_lifetime				int NOT NULL,
	num_engagements_campaign				int NOT NULL,
	max_engagement_date						date NULL,
	min_engagement_date						date NULL,
	num_email_n_interactions_last24months	smallint NOT NULL,
	num_social_media_engagement_last24months smallint NOT NULL,



	/* lifetime giving */
	gvg_life_cash money NOT NULL, 		
	gvg_life_cash_recog money NOT NULL, 
	gvg_life_ngp		money NOT NULL, 
	gvg_life_ngp_recog	money NOT NULL, 
	gvg_life_gift_count  int NOT NULL, 

	/*campaign 2030 giving */
	gvg_campaign2030_cash_recog_proxy money NOT NULL,

	/* gift timing fields */
	gvg_latest_cash_recog  date NULL, 
	gvg_latest_ngp_recog   date NULL, 

	/* total cash in past few years */
	gvg_tminus0_cash_recog   money NOT NULL, 
	gvg_tminus1_cash_recog money NOT NULL, 
	gvg_tminus2_cash_recog   money NOT NULL, 
	gvg_tminus3_cash_recog  money NOT NULL, 
	gvg_tminus4_cash_recog   money NOT NULL, 
	gvg_tminus5_cash_recog   money NOT NULL, 

				 /* Giving using new revenue tables */
gvg_lifetime_received   money NOT NULL, 
gvg_lifetime_raised   money NOT NULL, 
gvg_life_num_transactions int NOT NULL,
gvg_past5FY_received   money NOT NULL, 
gvg_past5FY_raised   money NOT NULL, 
				 
gvg_tminus0_received  money NOT NULL, 
gvg_tminus0_raised  money NOT NULL, 
gvg_tminus1_received  money NOT NULL, 
gvg_tminus1_raised  money NOT NULL, 
gvg_tminus2_received  money NOT NULL, 
gvg_tminus2_raised  money NOT NULL, 
gvg_tminus3_received  money NOT NULL, 
gvg_tminus3_raised  money NOT NULL, 
gvg_tminus4_received  money NOT NULL, 
gvg_tminus4_raised  money NOT NULL, 
gvg_tminus5_received  money NOT NULL, 
gvg_tminus5_raised  money NOT NULL, 

				 /* Giving using new revenue tables */
gvg_lifetime_received_hh   money NOT NULL, 
gvg_lifetime_raised_hh   money NOT NULL, 
gvg_life_num_transactions_hh int NOT NULL,
gvg_past5FY_received_hh   money NOT NULL, 
gvg_past5FY_raised_hh   money NOT NULL, 
				 
gvg_tminus0_received_hh  money NOT NULL, 
gvg_tminus0_raised_hh  money NOT NULL, 
gvg_tminus1_received_hh  money NOT NULL, 
gvg_tminus1_raised_hh  money NOT NULL, 
gvg_tminus2_received_hh  money NOT NULL, 
gvg_tminus2_raised_hh  money NOT NULL, 
gvg_tminus3_received_hh  money NOT NULL, 
gvg_tminus3_raised_hh  money NOT NULL, 
gvg_tminus4_received_hh  money NOT NULL, 
gvg_tminus4_raised_hh  money NOT NULL, 
gvg_tminus5_received_hh  money NOT NULL, 
gvg_tminus5_raised_hh  money NOT NULL, 

gvg_campaign_donor_level_hh nvarchar(30) NULL,

gvg_donor_category_live_hh	nvarchar(30)  NULL,
al_donor_category			nvarchar(100) NULL,
al_min_donor_category		nvarchar(100) NULL,
al_catgrouping				nvarchar(100) NULL,

flag_donated_on_a_giving_day_hh tinyint NULL,
flag_50k_transaction_donor_hh	tinyint NULL,
flag_campaign_primary_transaction_donor_hh tinyint NULL,
flag_has_given_stock_hh			tinyint NULL,
flag_has_pg_vehicle_hh			tinyint NULL,

gvg_latest_designation_name			nvarchar(500) NULL,
gvg_latest_vcu_recognition_amount	money NULL,
gvg_latest_vcu_recognition_txt		nvarchar(500) NULL,
gvg_latest_vcu_recognition_txt_hh	nvarchar(500) NULL,

commit_amount_5bin_highest_single_gift nvarchar(25) NULL,
gvg_life_total_non_VCU				money NOT NULL,
gvg_recog_first_hh					money NOT NULL,

/*Individual Recognition Giving using new recognition table - Don't think I need these other than for calculations. HH versions included in Tableau extract */
/*
gvg_life_vcu_recog			money NOT NULL, 
gvg_campaign_vcu_recog		money NOT NULL, 
gvg_tminus0_vcu_recog		money NOT NULL, 
gvg_tminus1_vcu_recog		money NOT NULL, 
gvg_tminus2_vcu_recog		money NOT NULL, 
gvg_tminus3_vcu_recog		money NOT NULL, 
gvg_tminus4_vcu_recog		money NOT NULL, 
gvg_tminus5_vcu_recog		money NOT NULL, 
gvg_tminus6_vcu_recog		money NOT NULL, 
gvg_tminus7_vcu_recog		money NOT NULL, 
gvg_tminus8_vcu_recog		money NOT NULL, 
gvg_tminus9_vcu_recog		money NOT NULL, 
gvg_tminus10_vcu_recog		money NOT NULL, 
flag_has_used_daf			tinyint NOT NULL,
flag_has_used_ff			tinyint NOT NULL,
gvg_5yr_vcu_recog			money NOT NULL, 
gvg_5yr_avg_vcu_recog		money NOT NULL, 
gvg_10yrs_num_yrs_vcu_recog int NOT NULL,
*/



/* Recognition Programs */
	flag_rp_foundersociety			tinyint NULL,
	flag_rp_heritagesociety			tinyint NULL,
	flag_rp_masseylawrencesociety	tinyint NULL,
	flag_rp_MCVsociety				tinyint NULL,
	flag_rp_legacysociety			tinyint NULL,
	rp_startdate_foundersociety			date NULL,
	rp_startdate_heritagesociety		date NULL,
	rp_startdate_masseylawrencesociety	date NULL,
	rp_startdate_MCVsociety				date NULL,
	rp_startdate_legacysociety			date NULL,
	rp_startFY_legacysociety			int NULL,
	rp_startqtr_legacysociety			tinyint NULL,
	flag_rp_atleastone_currentFY		tinyint NOT NULL,
	flag_rp_atleastone_ever				tinyint NOT NULL,
	flag_black_and_gold_loyalty_society tinyint NOT NULL,
	flag_presidents_club_society		tinyint NOT NULL,

/*Moves*/
	flag_any_completed_interaction_last_365 tinyint NULL,
	flag_any_completed_sig_interaction_last_365 tinyint NULL,
	flag_any_completed_SPV_last_365			tinyint NULL,
	mov_latest_completed_interaction		date NULL,
	mov_earliest_completed_interaction		date NULL,
	mov_latest_completed_sig_interaction_orig	date NULL,
	mov_earliest_completed_sig_interaction_orig	date NULL,
	mov_latest_completed_sig_interaction	date NULL,
	mov_earliest_completed_sig_interaction	date NULL,
	mov_latest_completed_SPV_interaction	date NULL,
	mov_earliest_completed_SPV_interaction	date NULL,
	mov_latest_completed_sig_all_interaction_cultivate			date NULL,
	mov_latest_completed_sig_primary_interaction_cultivate		date NULL,
	mov_latest_completed_sig_participant_interaction_cultivate	date NULL,
	mov_latest_completed_sig_secondary_interaction_cultivate	date NULL,
	mov_latest_completed_sig_discovery_interaction_cultivate	date NULL,

	mov_latest_lago_interaction_date		date NULL,
	mov_latest_lago_interaction_lago_name	nvarchar(100) NULL,
	mov_latest_lago_interaction_comment		nvarchar(MAX) NULL,
	mov_latest_lago_interaction_subcategory nvarchar(100) NULL,
    mov_latest_lago_interaction_category	nvarchar(100) NULL,
    mov_latest_lago_interaction_type		nvarchar(100) NULL,

	mov_latest_not_lago_interaction_date		date NULL,
	mov_latest_not_lago_interaction_lago_name	nvarchar(100) NULL,
	mov_latest_not_lago_interaction_comment		nvarchar(MAX) NULL,
	mov_latest_not_lago_interaction_subcategory nvarchar(100) NULL,
    mov_latest_not_lago_interaction_category	nvarchar(100) NULL,
    mov_latest_not_lago_interaction_type		nvarchar(100) NULL,

	--mov_latest_completed_sig_interaction2		date NULL,
	mov_latest_completed_sig_interaction_owner	nvarchar(1000) NULL,
	mov_latest_completed_sig_interaction_owner_system_id	uniqueidentifier NULL,
	mov_latest_completed_sig_interaction_type	nvarchar(200) NULL,
	mov_num_SPV_interactions_past_60_months		smallint NULL,  --added for principal gifts
	mov_num_SPV_interactions_with_Rao			smallint NULL,	--added for principal gifts
	mov_num_sig_interactions_non_DAR_leadership_past_60_months smallint NULL,	--added for principal gifts
	flag_mov_stewardship_SPV_interaction_last_365	tinyint NULL,
	flag_has_pending_interaction				tinyint NULL,
	flag_has_pending_plan_interaction			tinyint NULL,
	mov_earliest_pending_interaction_date		date NULL,
	mov_latest_pending_interaction_date			date NULL,
	mov_earliest_pending_interaction_type		nvarchar(200) NULL,
    mov_earliest_pending_interaction_objective	nvarchar(200) NULL,
    mov_earliest_pending_interaction_comment	nvarchar(MAX) NULL,
    mov_earliest_pending_interaction_date2		date NULL,
    mov_earliest_pending_interaction_concat_info nvarchar(MAX) NULL,
	mov_num_pending_interactions				smallint NULL,

/*Solicitations*/
	flag_ask_rolling_365x2					tinyint NOT NULL,
	sol_num_ask_rolling_365x2				int NOT NULL,
	sol_sum_ask_rolling_365x2				money NULL,
	sol_sum_expected_ask_rolling_365x2		money NULL,
	sol_sum_both_ask_rolling_365x2			money NULL,
	sol_min_opp_ask_amount_rolling_365x2	money NULL,
	sol_max_opp_ask_amount_rolling_365x2	money NULL,
	sol_ask_range_rolling_365x2				nvarchar(25) NULL,
	sol_ask_sum_range_rolling_365x2			nvarchar(25) NULL,

	sol_num_ask_campaign					int NOT NULL,
	sol_sum_ask_campaign					money NULL,
	sol_sum_documented_accepted_ask_last1825	money NULL,

/* Flags */
	flag_living tinyint NOT NULL,
	flag_spouse_living tinyint NOT NULL,
	flag_individual tinyint NOT NULL,
	flag_organization tinyint NOT NULL,
	flag_household tinyint NOT NULL,
	flag_alum tinyint NOT NULL,
	flag_spouse_alum tinyint NOT NULL,
	flag_managed_currently tinyint NOT NULL,
	flag_managed_currently_wo_FM tinyint NOT NULL,
	flag_managed_prospect_currently tinyint NOT NULL,
	flag_managed_team_currently tinyint NOT NULL,
	flag_managed_stewardship_currently tinyint NOT NULL,
	flag_managed_discovery_currently tinyint NOT NULL,
	flag_managed_foundation_currently tinyint NOT NULL,
	flag_managed_engagement_currently tinyint NOT NULL,
	flag_managed_alumni_rel_currently tinyint NOT NULL,
	flag_managed_ever tinyint NOT NULL,
	flag_is_principal_gift_prospect tinyint NOT NULL,
    flag_strikezone tinyint NOT NULL,
    flag_strikezone_new tinyint NULL,
	flag_available_prospect tinyint NOT NULL,
	flag_do_not_contact tinyint NOT NULL,
	flag_do_not_email tinyint NOT NULL,
	flag_do_not_mail tinyint NOT NULL,
	flag_do_not_call tinyint NOT NULL,
	flag_permanent_do_not_include tinyint NOT NULL,
	flag_exclude_call_list_VCU tinyint NOT NULL,
	flag_is_parent_relationship tinyint NOT NULL,
	flag_parent_current tinyint NOT NULL,
	flag_committee_member_current tinyint NOT NULL,
	flag_board_member_current tinyint NOT NULL,
	flag_board_primary_member_current tinyint NOT NULL,
	flag_rev_ira_gift tinyint NOT NULL,
	flag_daf tinyint NOT NULL,
	flag_has_daf_hh tinyint NOT NULL,
	flag_ff_individual tinyint NOT NULL,
	flag_ff_alumni tinyint NOT NULL,
	flag_parent_constituency tinyint NOT NULL,
	flag_parent_past_constituency tinyint NOT NULL,
	flag_parent_prospective_constituency tinyint NOT NULL,
	flag_VCUHS_trainee tinyint NOT NULL,
	flag_government_agency tinyint NOT NULL,
	flag_student tinyint NOT NULL,
	flag_any_engagement_last_365 tinyint NOT NULL,
	flag_any_engagement_campaign2030 tinyint NOT NULL,
	flag_has_identified_seasonal_property tinyint NOT NULL,
	flag_race_is_black tinyint NOT NULL,
	flag_vcu_facstaff_current tinyint NOT NULL,
	flag_vcu_facstaff_retired tinyint NOT NULL,
	flag_is_volunteer tinyint NOT NULL,
	flag_pgi_NAP_all_VCU_active tinyint NOT NULL,
	flag_pgi_NAP_unit_active tinyint NOT NULL,
	flag_pgi_NAP_unit_active_PG tinyint NOT NULL,
	flag_pgi_referral_active tinyint NOT NULL,
	flag_pgi_positive_active tinyint NOT NULL,
	flag_pgi_planned_gift_active tinyint NOT NULL,
	flag_pgi_PG_referral tinyint NOT NULL,
	flag_pgi_PG_positive tinyint NOT NULL,
	flag_pgi_PG_VCU_NAP tinyint NOT NULL,
	flag_pgi_PG_VCU_future tinyint NOT NULL,
	flag_pgi_PG_unit_NAP tinyint NOT NULL,
	--flag_pgi_af_gift_active tinyint NOT NULL,
	flag_pgi_leadership_gift_active tinyint NOT NULL,
	flag_pgi_major_gift_active tinyint NOT NULL,
	flag_pgi_top_parent_active tinyint NOT NULL,
	pgi_top_parent_active_latest_year smallint NULL,
	--flag_pgi_principal_gift_active tinyint NOT NULL,
	flag_lago_referral_active tinyint NOT NULL,
	flag_active_radar_user tinyint NOT NULL,
	flag_ever_radar_user tinyint NOT NULL,
	flag_solicitable_email tinyint NOT NULL,
	flag_solicitable_mail tinyint NOT NULL,
	flag_solicitable_phone tinyint NOT NULL,

	flag_contactable_email tinyint NOT NULL,
	flag_contactable_mail tinyint NOT NULL,
	flag_contactable_phone tinyint NOT NULL,
	flag_contactable_phone_business tinyint NOT NULL,
	flag_contactable_phone_cell tinyint NOT NULL,
	pm_contactable_by_text nvarchar(10) NOT NULL,
	flag_top_hh_member tinyint NULL,
	flag_has_endowed_a_fund tinyint NOT NULL,
	--flag_lgbtq_affinity tinyint NOT NULL,
	flag_di_vip tinyint NOT NULL,
	flag_attribute_mentor tinyint NOT NULL,
	flag_attribute_volunteer tinyint NOT NULL,
	flag_first_gen_student	tinyint NOT NULL,
	flag_award_recipient	tinyint NOT NULL,

	flag_SOM_alum tinyint NOT NULL,
	flag_physician tinyint NOT NULL,
	flag_bhs_degree tinyint NOT NULL,
	flag_publichealth_degree tinyint NOT NULL,
	flag_residency_degree tinyint NOT NULL,
	flag_SOM_2000plus_Alum tinyint NOT NULL,

	flag_TP_parent			tinyint NULL,
	flag_TP_foundation		tinyint NULL,
	flag_TP_complex_assets	tinyint NULL,
	flag_TP_DAF				tinyint NULL,
	flag_WF_DAF_indicator	tinyint NOT NULL,
	flag_rnl_interest_has_DAF tinyint NOT NULL,
	flag_business_owner		tinyint NOT NULL,

	flag_VCU_employees_to_exclude tinyint NULL,
	flag_VCU_employees_to_exclude_hh tinyint NULL,
	flag_prospect_managed_activation_hh tinyint NULL, 
	flag_assigned_activation_hh tinyint NULL,
	flag_legally_contactable_snap tinyint NULL,
	flag_legally_contactable_snap_FY26 tinyint NULL,
	flag_legally_contactable tinyint NULL,
	flag_has_picture_in_radar tinyint NULL,

	num_email_clicks_last365 int NULL,
	flag_platinum_board_member tinyint NULL,
	flag_currently_managed_by_vp tinyint NULL,
	engagement_latest_email_click_through_date date NULL,
	engagement_latest_event_attendance_date date NULL,

	z_date_record_added date NULL,
	z_exclude_groups nvarchar(20) NOT NULL,

	eval_vcu_primary_giving_connectedness_score smallint NULL,
	eval_VCU_principal_giving_points int NULL,
	eval_VCU_principal_giving_score int NULL,
	eval_VCU_principal_giving_rank  int NULL,

	eval_pringiv_1_highcapacity		tinyint NULL,				--#1
	eval_pringiv_2_daf_stock		tinyint NULL,				--#2 STOCKS AND DAF
	eval_pringiv_3_big_non_VCU_gvg	tinyint NULL,				--#3 500K+ non-VCU Charitable giving
	eval_pringiv_4_old				tinyint NULL,
	eval_pringiv_5_alum_fac			tinyint NULL,
	eval_pringiv_6_local			tinyint NULL,
	eval_pringiv_7_life_connection	tinyint NULL,				--#7 Deep, long-term non-development engagement
	eval_pringiv_8_managed			tinyint NULL,				--#8 Established development officer relationship
	eval_pringiv_9_campus_visit		tinyint NULL,				--#9 Campus visit
	eval_pringiv_10_interactions	tinyint NULL,				--#10 Three or more direct visits with a unit leader 
	eval_pringiv_11_bigmoney		tinyint NULL,				--#11 High level annual giving
	eval_pringiv_12_committee		tinyint NULL,				--#12 this may too broad and need to lower to top-level boards
	eval_pringiv_13_spouse_engagement tinyint NULL,				--#13 Meaningful engagement of key family stakeholders, especially the spouse. Only spouse for now
	eval_pringiv_14_majorgift		tinyint NULL,				--#14 Major Gift (50K/25K)
  --+ Stellar execution of test gift by program participants	--#15
  --+ Creative, customized stewardship of test gift				--#16 BESPOKE STEWARDSHIP - NOT USED?
	eval_pringiv_17_rao				tinyint NULL,				--#17 Interaction with Rao

	eval_record_standard_metal		nvarchar(100) NULL,
	eval_nyu_bin					tinyint NULL,				--changed to eval_nyu_bin
	pm_num_events_tminus0			smallint NULL,				--used in nyu_bin ownership
	pm_num_volunteer_tminus0		smallint NULL,				--used in nyu_bin ownership
	pm_num_volunteer_tminus1_5		smallint NULL,				--used in nyu_bin ownership
	pm_latest_past_committee_end_date date NULL,				--used in nyu_bin ownership

	pg_vehicle_list					nvarchar(255) NULL

) 


/* STEP 1. DELETE TABLE, IF ALREADY EXISTS */

	--IF OBJECT_ID('datamart.constituent_level', 'U') IS NOT NULL 
	--DROP TABLE datamart.constituent_level;

	--TRUNCATE TABLE datamart.constituent_level_test

/* STEP 2. LOAD DATA INTO TABLE */

INSERT INTO DARanalytics.datamart.constituent_level_temp


SELECT 
	
	/* date loaded */
	getdate() as z_last_update

/*******************************************************************************************************************/
   /***************************************** KEY ID VARIABLES AND DEDUPES ********************************************/
   /*******************************************************************************************************************/

	,b.constituentdimid				as constituent_dim_id
	,b.constituentsystemid			as constituent_system_id
	,b.constituentlookupid			as constituent_lookup_id
    ,hh_summary.household_system_id	as household_system_id
	,hh_summary.household_id		as household_id
	,hh_summary.household_lookup_id	as household_lookup_id			--should only exist for people in a household
    ,b.isprimary					as flag_is_primary_hh_member

  /*******************************************************************************************************************/
   /*********************************************** BIOGRAPHICAL VARIABLES ********************************************/
   /*******************************************************************************************************************/
 
	,case when b.ISDECEASED = 1 then trim(concat(b.fullname,' (D)')) else trim(b.fullname) end                 as bio_name
	,trim(b.fullname)					as bio_name_sans_D
	,hh_summary.FULLNAME_SUMMARY		as bio_full_name_summary
	,trim(b.lastname)					as bio_lastname
	,trim(b.firstname)					as bio_firstname
	,trim(dimc.nickname)				as bio_nickname
	,trim(b.middlename)					as bio_middlename
	,case when trim(b.middlename) <> '' then concat(left(trim(b.middlename),1),'.') else '' end	as bio_middle_initial
	,case when b.firstname <> '' and b.ISDECEASED = 1 then trim(concat(b.lastname,', ',b.firstname,' (D)'))
		  when b.firstname <> '' then trim(concat(b.lastname,', ',b.firstname))
		  else trim(b.lastname)
		  end as bio_lastcommafirstname
	,names.bio_name_VCU_Standard_Joint
	,names.bio_name_VCU_Standard_Individual
	,b.title					as bio_salutation
	,b.suffix					as bio_suffix
	,b.alumninametag            as bio_name_tag
--	,names.bio_name_informal_hh
--	,chl.bio_name_informal_hh_last	--includes deceased and orgs
	,case when b.ISINDIVIDUAL	= 1 then 'Individual'
	      when b.ISORGANIZATION = 1 then 'Organization'
		  else NULL end			as bio_record_type
--	,NULL						as bio_primary_record_type
	,case when b.ISACTIVE		= 1 then 'Active'				--this table is all active so this isn't really needed at this point.  Leaving it for future dev potentially.
	      else 'Inactive' end	as bio_primary_record_status
	,dimext.INDUSTRYCODE		as bio_org_industry
	,dimext.PARENTCORP			as bio_org_parent_corp
	,dimext.ISPRIMARYORG		as bio_org_is_primary_org
	,dimc.GENDER				as bio_gender
	,b.ETHNICITY				as bio_race_desc
	,czn.bio_citizenship1		as bio_citizenship1
	,czn.bio_citizenship2		as bio_citizenship2
	,b.currentemployername		as bio_employer_name
	,b.CURRENTEMPLOYERID		as bio_employer_system_id
	,job_cat.bio_employer_lookup_id
	,job_cat.bio_employer_dim_id
	,b.currentjobtitle			as bio_job_title
	,job_cat.job_category		as bio_job_category

	,job_cat.job_start_date		as bio_job_start_date
	,case when job_cat.job_end_date = '2099-01-01' then NULL else job_cat.job_end_date end 		as bio_job_end_date
	,job_cat.flag_job_current		as flag_bio_job_current
	,job_cat.job_career_level		as bio_job_career_level
	,job_cat.job_department			as bio_job_department
	,job_cat.job_division			as bio_job_division
	,job_cat.job_schedule			as bio_job_schedule
	,job_cat.job_relationship_type	as bio_job_relationship_type

	,case when b.age = 0 then NULL else b.age end      as bio_age

	,b.generation				as bio_generation
	,b.birthdate				as bio_birth_date_radar
	,convert(date,case when (b.birthdate = '00000000'
					  	  or left(b.birthdate,4) = '0000' 
	                        ) 
					   then NULL
					   when right(b.birthdate,4) = '0000' then datefromparts(left(b.birthdate,4),12,31)
					   when right(b.birthdate,2) = '00' then datefromparts(left(b.birthdate,4),substring(b.birthdate,5,2),1)
	                   else b.birthdate end)  as bio_birth_date
	,case when
				(case	when (b.birthdate = '00000000'
					  	  or left(b.birthdate,4) = '0000' 
	                        ) 
					   then NULL		--entire date is NULL
						when substring(b.birthdate,5,2) = '00' then datefromparts(year(getdate()),12,31)	--we have a year but no month
		  				when substring(b.birthdate,7,2) = '00' then datefromparts(year(getdate()),substring(b.birthdate,5,2),1)  --we have a month and year but no day
						when substring(b.birthdate,5,2) = '02' and SUBSTRING(b.birthdate,7,2) = '29' then datefromparts(year(getdate()),substring(b.birthdate,5,2),SUBSTRING(b.birthdate,7,2)-1) --Those Born on Feb 29 get a 28th birthday
						else datefromparts(year(getdate()),substring(b.birthdate,5,2),SUBSTRING(b.birthdate,7,2)) --everyone else with full birthdates
				end) >= getdate() then 
					(case	when (b.birthdate = '00000000'
					  	  or left(b.birthdate,4) = '0000' 
	                        ) 
					   then NULL			--entire date is NULL
						when substring(b.birthdate,5,2) = '00' then datefromparts(year(getdate()),12,31)	--we have a year but no month
		  				when substring(b.birthdate,7,2) = '00' then datefromparts(year(getdate()),substring(b.birthdate,5,2),1)  --we have a month and year but no day
						when substring(b.birthdate,5,2) = '02' and SUBSTRING(b.birthdate,7,2) = '29' then datefromparts(year(getdate()),substring(b.birthdate,5,2),SUBSTRING(b.birthdate,7,2)-1) --Those Born on Feb 29 get a 28th birthday
						else datefromparts(year(getdate()),substring(b.birthdate,5,2),SUBSTRING(b.birthdate,7,2)) --everyone else with full birthdates
						end)
						
			else dateadd(year,1,(case when (b.birthdate = '00000000'
					  					 or left(b.birthdate,4) = '0000' 
											) 
									then NULL			--entire date is NULL
									when substring(b.birthdate,5,2) = '00' then datefromparts(year(getdate()),12,31)	--we have a year but no month
		  							when substring(b.birthdate,7,2) = '00' then datefromparts(year(getdate()),substring(b.birthdate,5,2),1)  --we have a month and year but no day
									when substring(b.birthdate,5,2) = '02' and SUBSTRING(b.birthdate,7,2) = '29' then datefromparts(year(getdate()),substring(b.birthdate,5,2),SUBSTRING(b.birthdate,7,2)-1) --Those Born on Feb 29 get a 28th birthday
									else datefromparts(year(getdate()),substring(b.birthdate,5,2),SUBSTRING(b.birthdate,7,2)) --everyone else with full birthdates
									end)
						)
			end  as bio_birthday_next
	,convert(date,case when b.deceaseddate = '00000000' and b.isdeceased=1 then b.DECEASEDADDEDDATE
					   when (b.deceaseddate = '00000000' 
	                        ) 
					   then NULL
					   when right(b.deceaseddate,4) = '0000' then datefromparts(left(b.deceaseddate,4),7,15)
					   when right(b.deceaseddate,2) = '00' then datefromparts(left(b.deceaseddate,4),substring(b.deceaseddate,5,2),15)
	                   else b.deceaseddate end)  as bio_death_date
	,case when b.age is null then NULL
		  when b.age < 18 then NULL
		  when b.isdeceased=1 then NULL
	      else year(dateadd(month,6,getdate())) + round(le.years_left,1) 
		  end as bio_expected_death_FY  --current FY + ceiling of years_left
	,b.CONSTITUENCY		as bio_constituency_list
	,dimc.maritalstatus as bio_marital_status
	,isnull(kids.num_living_children_in_radar,0) as bio_num_living_children_in_radar
	,isnull(nokids_GB.flag_has_nokids_GB,0)		 as flag_has_nokids_GB
	,case when chl.flag_TP_parent_hh = 0 then 1 else 0 end as flag_has_nokids_TP_hh
	,isnull(case when chl.flag_has_nokids_GB_hh=1
	        or chl.flag_TP_parent_hh = 0 then 1 else 0 end,0) as flag_has_nokids 
	,convert(date,dimc.ADDEDDATE)			as bio_date_added
	,convert(date,dimc.CHANGEDDATE)			as bio_date_changed
	,par_students.bio_parents_of_students_names
	,isnull(rel_cnt.num_relationships_individuals,0)	as bio_num_relationships_individuals
  /*******************************************************************************************************************/
   /***************************************************** SPOUSE VARIABLES ********************************************/
   /*******************************************************************************************************************/

	,b_sp.constituentdimid		as spouse_dim_id
	,b_sp.constituentsystemid	as spouse_system_id
	,b_sp.constituentlookupid	as spouse_lookup_id
	,case when b_sp.ISDECEASED = 1 then concat(b_sp.fullname,' (D)') else b_sp.fullname end			as spouse_name
	,trim(b_sp.fullname)		as spouse_name_sans_D
	,b_sp.lastname				as spouse_lastname
	,b_sp.firstname				as spouse_firstname
	,trim(b_sp.middlename)      as spouse_middlename
	,case when trim(b_sp.middlename) <> '' then concat(left(trim(b_sp.middlename),1),'.') else '' end	as spouse_middle_initial
	,case when b_sp.firstname is not null and b_sp.ISDECEASED = 1 then trim(concat(b_sp.lastname,', ',b_sp.firstname,' (D)'))
		  when b_sp.firstname is not null then trim(concat(b_sp.lastname,', ',b_sp.firstname))
		  else trim(b_sp.lastname)
	  end as spouse_lastcommafirstname
	,b_sp.title					as spouse_salutation
	,b_sp.suffix				as spouse_suffix
	,b_sp.alumninametag			as spouse_name_tag
	,NULL						as spouse_primary_record_type_desc
	,NULL						as spouse_primary_record_status
	,dimc_sp.gender				as spouse_gender
	,b_sp.currentemployername	as spouse_employer_name
	,b_sp.currentjobtitle		as spouse_job_title
	,case when b_sp.age = 0 then NULL else b_sp.age end      as spouse_age
	,b_sp.generation			as spouse_generation
	,convert(date,case when (b_sp.birthdate = '00000000'
					  	  or left(b_sp.birthdate,4) = '0000' 
	                        ) 
					   then NULL
					   when right(b_sp.birthdate,4) = '0000' then datefromparts(left(b_sp.birthdate,4),7,15)
					   when right(b_sp.birthdate,2) = '00' then datefromparts(left(b_sp.birthdate,4),substring(b_sp.birthdate,5,2),15)
	                   else b_sp.birthdate end)  as spouse_birth_date 
	,convert(date,case when b_sp.deceaseddate = '00000000' and b_sp.isdeceased=1 then b_sp.DECEASEDADDEDDATE
					   when b_sp.deceaseddate = '00000000'						 then NULL
					   when right(b_sp.deceaseddate,4) = '0000' then datefromparts(left(b_sp.deceaseddate,4),7,15)
					   when right(b_sp.deceaseddate,2) = '00' then datefromparts(left(b_sp.deceaseddate,4),substring(b_sp.deceaseddate,5,2),15)
	                   else b_sp.deceaseddate end)  as spouse_death_date 
	,b_sp.CONSTITUENCY		as spouse_constituency_list

	,NULL			as spouse_affil_preferred_class

   /*******************************************************************************************************************/
   /***************************************************** CONSTITUENCIES ***********************************************/
   /*******************************************************************************************************************/


	,con.parent_constituency_start_date
   
   /*******************************************************************************************************************/
   /***************************************************** ILA VARIABLES ***********************************************/
   /************************************ events, gift clubs, committees,volunteerism **********************************/
   /*******************************************************************************************************************/
   

--	,convert(date,ila.latest_event_date) as ila_latest_event_date
	,convert(date,committees.latest_committee_start_date)	as inv_late_cur_commite_start_date
	,convert(date,committees.earliest_committee_start_date) as inv_early_cur_commite_start_date
	,convert(date,committees.latest_board_start_date)		as inv_latest_cur_board_start_date
	,convert(date,committees.earliest_board_start_date)		as inv_early_cur_board_start_date
	,convert(date,committees.latest_board_primary_start_date)		as inv_latest_cur_board_primary_start_date
	,convert(date,committees.earliest_board_primary_start_date)		as inv_early_cur_board_primary_start_date
	,replace(replace(replace(replace(committees.latest_committees_current,char(9),''),char(10),''),char(13),''),char(34),'') as inv_latest_committees_current
	,replace(replace(replace(replace(committees.latest_boards_current,char(9),''),char(10),''),char(13),''),char(34),'') as inv_latest_boards_current

	,convert(date,past_committees.latest_past_committee_end_date)	as inv_late_cur_commite_end_date
	,convert(date,past_committees.earliest_past_committee_end_date) as inv_early_cur_commite_end_date
	,convert(date,past_committees.latest_past_board_end_date)		as inv_latest_cur_board_end_date
	,convert(date,past_committees.earliest_past_board_end_date)		as inv_early_cur_board_end_date
	,convert(date,past_committees.latest_past_board_primary_end_date)		as inv_latest_cur_board_primary_end_date
	,convert(date,past_committees.earliest_past_board_primary_end_date)		as inv_early_cur_board_primary_end_date
	,replace(replace(replace(replace(past_committees.latest_committees_past,char(9),''),char(10),''),char(13),''),char(34),'') as inv_latest_committees_past
	,replace(replace(replace(replace(past_committees.latest_boards_past,char(9),''),char(10),''),char(13),''),char(34),'') as inv_latest_boards_past




--	,convert(date,ila.latest_committee_date_service) as ila_latest_committee_date_service
--	,convert(date,ila.latest_gift_club_date) as ila_latest_gift_club_date
--	,convert(date,ila.earliest_event_date) as ila_earliest_event_date
--	,convert(date,ila.earliest_gift_club_date) as ila_earliest_gift_club_date
--	,replace(replace(replace(replace(ila.latest_events,char(9),''),char(10),''),char(13),''),char(34),'') as ila_latest_events
--	,replace(replace(replace(replace(ila.latest_committees_former,char(9),''),char(10),''),char(13),''),char(34),'') as ila_latest_committees_former
--	,replace(replace(replace(replace(ila.latest_boards_former,char(9),''),char(10),''),char(13),''),char(34),'') as ila_latest_boards_former
--	,replace(replace(replace(replace(ila.latest_gift_clubs,char(9),''),char(10),''),char(13),''),char(34),'') as ila_latest_gift_clubs
--	,isnull(vol.vol_cnt,0) as ila_num_volunteer_records
--	,isnull(vol.days_of_vol_service,0) as ila_days_volunteer_service
--	,isnull(network.ila_network_login_tminus0,0) as flag_ila_network_login_tminus0
--	,isnull(network.ila_network_login_tminus1,0) as flag_ila_network_login_tminus1

--	,isnull(tix.season_tix_tminus0,0) as flag_season_tix_tminus0
--	,isnull(tix.season_tix_tminus1,0) as flag_season_tix_tminus1

   --,isnull(network.ila_network_num_logins_ever,0) as ila_network_num_logins_ever
  

   /*******************************************************************************************************************/
   /*************************************************** AFFIL VARIABLES ***********************************************/
   /******************************************* schools, majors, and degrees ******************************************/
   /*******************************************************************************************************************/

 
	,b.EDUCATIONSCHOOL1					as affil_preferred_school
	,case when b.EDUCATIONPREFERREDCLASSYEAR1 = 0 then NULL else b.EDUCATIONPREFERREDCLASSYEAR1 end		as affil_preferred_class
	,(5 - (year(dateadd(month,6,getdate())) - (case when b.EDUCATIONPREFERREDCLASSYEAR1 = 0 then NULL else b.EDUCATIONPREFERREDCLASSYEAR1 end)) % 5) % 5		as affil_yrs_til_reunion
--	,smd.schools_vcu as affil_vcu_schools
--	,smd.majors_vcu as affil_vcu_majors
--	,smd.degrees_vcu as affil_vcu_degrees
--	,smd.full_affils_vcu as affil_full_vcu_affils

	,NULL as affil_ug_reunion_class
	,NULL as affil_ug_yrs_til_reunion

	,isnull(reunion.flag_current_reunion_class,0)		as flag_current_reunion_class
	, reunion.list_of_current_reunion_schools			as list_of_current_reunion_schools
	, reunion.list_of_current_reunion_class_years		as list_of_current_reunion_class_years
	, reunion.list_of_current_reunion_degrees			as list_of_current_reunion_degrees
	, reunion.list_of_current_reunion_departments		as list_of_current_reunion_departments

	--,gradyr.alum_grad_year_latest as affil_grad_reunion_class
	--,case when b.primary_record_type in ('al','hs')
	--       and b.primary_record_status in ('a') 
	 --     then (5 - (year(dateadd(month,6,getdate())) - gradyr.alum_grad_year_latest) % 5) % 5 else null end as affil_grad_yrs_til_reunion

	  ,b.EDUCATIONSYSTEMID1					as affil_education_system_id1
	  ,b.EDUCATIONINSTITUTION1				as affil_institution1
	  ,b.EDUCATIONSCHOOL1					as affil_school1
      ,b.EDUCATIONDEPARTMENT1				as affil_department1
      ,b.EDUCATIONPRIMARYMAJOR1				as affil_major1
	  ,b.EDUCATIONDEGREE1					as affil_degree1
      ,case when b.EDUCATIONCLASSOF1 = 0 then NULL else b.EDUCATIONCLASSOF1 end								as affil_class1
      ,case when b.EDUCATIONPREFERREDCLASSYEAR1 = 0 then NULL else b.EDUCATIONPREFERREDCLASSYEAR1 end		as affil_preferred_class1

	  ,b.EDUCATIONSYSTEMID2					as affil_education_system_id2
	  ,b.EDUCATIONINSTITUTION2				as affil_institution2
	  ,b.EDUCATIONSCHOOL2					as affil_school2
      ,b.EDUCATIONDEPARTMENT2				as affil_department2
      ,b.EDUCATIONPRIMARYMAJOR2				as affil_major2
	  ,b.EDUCATIONDEGREE2					as affil_degree2
      ,case when b.EDUCATIONCLASSOF2 = 0 then NULL else b.EDUCATIONCLASSOF2 end								as affil_class2
      ,case when b.EDUCATIONPREFERREDCLASSYEAR2 = 0 then NULL else b.EDUCATIONPREFERREDCLASSYEAR2 end		as affil_preferred_class2

	  ,b.EDUCATIONSYSTEMID3					as affil_education_system_id3
	  ,b.EDUCATIONINSTITUTION3				as affil_institution3
	  ,b.EDUCATIONSCHOOL3					as affil_school3
      ,b.EDUCATIONDEPARTMENT3				as affil_department3
      ,b.EDUCATIONPRIMARYMAJOR3				as affil_major3
	  ,b.EDUCATIONDEGREE3					as affil_degree3
      ,case when b.EDUCATIONCLASSOF3 = 0 then NULL else b.EDUCATIONCLASSOF3 end								as affil_class3
      ,case when b.EDUCATIONPREFERREDCLASSYEAR3 = 0 then NULL else b.EDUCATIONPREFERREDCLASSYEAR3 end		as affil_preferred_class3

	  ,b.EDUCATIONSYSTEMID4					as affil_education_system_id4
	  ,b.EDUCATIONINSTITUTION4				as affil_institution4
	  ,b.EDUCATIONSCHOOL4					as affil_school4
      ,b.EDUCATIONDEPARTMENT4				as affil_department4
      ,b.EDUCATIONPRIMARYMAJOR4				as affil_major4
	  ,b.EDUCATIONDEGREE4					as affil_degree4
      ,case when b.EDUCATIONCLASSOF4 = 0 then NULL else b.EDUCATIONCLASSOF4 end								as affil_class4
      ,case when b.EDUCATIONPREFERREDCLASSYEAR4 = 0 then NULL else b.EDUCATIONPREFERREDCLASSYEAR4 end		as affil_preferred_class4

	  ,soe_sub_dept1.EDUCATIONALSUBDEPARTMENT as affil_subdepartment1
	  ,soe_sub_dept2.EDUCATIONALSUBDEPARTMENT as affil_subdepartment2
	  ,soe_sub_dept3.EDUCATIONALSUBDEPARTMENT as affil_subdepartment3
	  ,soe_sub_dept4.EDUCATIONALSUBDEPARTMENT as affil_subdepartment4

	  , min_educ.affil_min_class_year

	  , isnull(vcu_educ.flag_vcu_alumni_ug_degree,0)			as flag_vcu_alumni_ug_degree
	  , isnull(vcu_educ.flag_vcu_young_alumni_ug_degree,0)		as flag_vcu_young_alumni_ug_degree
	  , isnull(vcu_educ.flag_vcu_alumni_grad_degree,0)			as flag_vcu_alumni_grad_degree
	  , isnull(vcu_educ.flag_vcu_young_alumni_grad_degree,0)	as flag_vcu_young_alumni_grad_degree
	  , isnull(vcu_educ.flag_vcu_recent_any_degree,0)			as flag_vcu_recent_any_degree
	  , vcu_educ.list_of_education_colleges

	  , case when non_vcu_educ.constituent_lookup_id is not null	then 1 else 0 end as flag_has_non_vcu_education_record
	  , case when vcu_educ.constituent_lookup_id is not null		then 1 else 0 end as flag_has_vcu_education_record

   /*******************************************************************************************************************/
   /******************************************* CONTACT INFO VARIABLES ************************************************/
   /*******************************************************************************************************************/

    ,b.primaryphone as cntc_primary_phone
	,b.PRIMARYPHONETYPE as cntc_primary_phone_type
	--,contact.home_phones as cntc_home_phones
	--,contact.biz_phones as cntc_biz_phones
	,b.primaryemailaddress as cntc_email_addresses
	,contact.cntc_facebook as cntc_facebook
	,contact.cntc_linkedin as cntc_linkedin
	,contact.cntc_twitter  as cntc_twitter
	
    ,b_sp.primaryphone as cntc_spouse_primary_phone
	--,contact.home_phones as cntc_home_phones
	--,contact.biz_phones as cntc_biz_phones
	,b_sp.primaryemailaddress as cntc_spouse_email_addresses
	--,contact.facebook as cntc_facebook
	--,contact.linkedin as cntc_linkedin
	,isnull(valid.flag_cntc_valid_phone,0)	as flag_cntc_valid_phone
	,isnull(valid.flag_cntc_valid_email,0)	as flag_cntc_valid_email
	,isnull(valid.flag_cntc_valid_mail,0)	as flag_cntc_valid_mail
	,isnull(valid.flag_cntc_hbone,0)		as flag_cntc_hbone
	,isnull(dimext.HASENGAGEDEMAIL,0)		as flag_cntc_engaged_email

   /*******************************************************************************************************************/
   /******************************************* ADDRESS (GEO) VARIABLES ***********************************************/
   /*******************************************************************************************************************/

   /************************************************* preferred *******************************************************/
   
--	,addr.primary_address_pref_addrnumber as geo_addr_pref_addrnumber
--	,addr.primary_address_pref as geo_addr_pref_primary
	,b.PRIMARYADDRESSTYPE																							  as geo_addr_pref_type
	,replace(replace(replace(replace(case when b.primaryaddress = '' then NULL else b.primaryaddress end,char(9),''),char(10),''),char(13),''),char(34),'')	 as geo_addr_pref_street
	,case when b.primaryaddresscity	= '' then NULL else b.primaryaddresscity end									  as geo_addr_pref_city
	,case when b.county	= '' then NULL else b.county end								  							  as geo_addr_pref_county    --check if this primary
	,case when b.primaryaddressstateabbreviation = '' then NULL else b.primaryaddressstateabbreviation end			  as geo_addr_pref_state
	,case when b.primaryaddresspostcode	= '' then NULL else	b.primaryaddresspostcode end							  as geo_addr_pref_zip
	,case when dimc.PRIMARYADDRESSCOUNTRYABBREVIATION = 'USA' then left(b.primaryaddresspostcode,5) else NULL end     as geo_addr_pref_zip_US5
	,case when dimc.PRIMARYADDRESSCOUNTRYABBREVIATION = '' then NULL else dimc.PRIMARYADDRESSCOUNTRYABBREVIATION end  as geo_addr_pref_country
	,case when dimc.PRIMARYADDRESSCOUNTRYABBREVIATION = '' then NULL else dimc.PRIMARYADDRESSCOUNTRY end			  as geo_addr_pref_country_name
	,vcc.Country			as geo_addr_pref_country_name2
	,addr.latitude	 						as geo_addr_pref_lat
	,addr.longitude							as geo_addr_pref_long
--	,addr.primary_address_pref_bg_fips as geo_addr_pref_block_grp
--	,addr.primary_address_pref_msa as geo_addr_pref_msa
	,b.vcuregioncodemsa						as geo_addr_pref_msa_desc
	,msa.msa_code							as geo_addr_pref_msa_code
	,msa.MSA_name_Census					as geo_addr_pref_msa_desc_census
--	,addr.primary_address_pref_location_id as geo_addr_pref_location_id
--	,addr.primary_address_pref_location_desc as geo_addr_pref_location_desc
	,addr_chnge.latest_address_change_date	as geo_latest_address_change_date
	,cast(  case when addr.latitude is null or addr.longitude is null then null
				 else 2 * 3958.7613 * asin(
					  sqrt( power( sin( (radians(addr.latitude) - radians(37.546879)) / 2 ), 2 )
					+ cos(radians(37.5407)) * cos(radians(addr.latitude))
					* power( sin( (radians(addr.longitude) - radians(-77.450257)) / 2 ), 2 ) ) )
					end	as int) as geo_miles_from_richmond


/*   *********************************************** residential *******************************************************
	,addr.primary_address_res_addrnumber as geo_addr_res_addrnumber
	,addr.primary_address_res as geo_addr_res_primary
	,addr.primary_address_res_street as geo_addr_res_street
	,addr.primary_address_res_city as geo_addr_res_city
	,addr.primary_address_res_state as geo_addr_res_state
	,addr.primary_address_res_zip as geo_addr_res_zip
	,addr.primary_address_res_country as geo_addr_res_country
	,addr.primary_address_res_lat as geo_addr_res_lat
	,addr.primary_address_res_long as geo_addr_res_long
	,addr.primary_address_res_bg_fips as geo_addr_res_block_grp
	,addr.primary_address_res_msa as geo_addr_res_msa
	,addr.primary_address_res_msa_desc as geo_addr_res_msa_desc
	,addr.primary_address_res_location_id as geo_addr_res_location_id
	,addr.primary_address_res_location_desc as geo_addr_res_location_desc
	,addr.primary_address_res_intl_sub_region geo_addr_res_subregion
	,addr.secondary_address_res_intl_sub_region geo_addr_res_subregion2

   ************************************************** business *******************************************************
	,addr.primary_address_biz_addrnumber as geo_addr_biz_addrnumber
	,addr.primary_address_biz as geo_addr_biz
	,addr.primary_address_biz_street as geo_addr_biz_street
	,addr.primary_address_biz_city as geo_addr_biz_city
	,addr.primary_address_biz_state as geo_addr_biz_state
	,addr.primary_address_biz_zip as geo_addr_biz_zip
	,addr.primary_address_biz_country as geo_addr_biz_country
	,addr.primary_address_biz_lat as geo_addr_biz_lat
	,addr.primary_address_biz_long as geo_addr_biz_long
	,addr.primary_address_biz_bg_fips as geo_addr_biz_block_grp
	,addr.primary_address_biz_msa as geo_addr_biz_msa
	,addr.primary_address_biz_msa_desc as geo_addr_biz_msa_desc
	,addr.primary_address_biz_location_id as geo_addr_biz_location_id
	,addr.primary_address_biz_location_desc as geo_addr_biz_location_desc
	,addr.primary_address_biz_intl_sub_region geo_addr_biz_subregion
	,addr.secondary_address_biz_intl_sub_region geo_addr_biz_subregion2

	--,addr.top_pct_houseval_1m_plus   as geo_top_pct_houseval_1m_plus
	,0   as geo_top_pct_houseval_1m_plus       --stopped using this variable
	,addr.top_pct_200k_hh_income     as geo_top_pct_200k_hh_income
	,addr.top_pct_houseval_2m_plus   as geo_top_pct_houseval_2m_plus
	,addr.top_median_hh_income       as geo_top_median_hh_income
*/


	



   /*******************************************************************************************************************/
   /******************************************** EVALUATION VARIABLES *************************************************/
   /*******************************************************************************************************************/
 
	, eval.BESTCAPACITYVALUESORT	as eval_capacity_rating
	, eval.BESTCAPACITYVALUE		as eval_capacity_rating_desc
	, eval.BESTCAPACITYVALUESORTED	as eval_capacity_rating_desc_sort
	, eval.BESTCAPACITYVALUESHORT	as eval_capacity_rating_desc_short
	, eval.BESTCAPACITYVALUESHORTSORTED	as eval_capacity_rating_desc_short_sort
	, eval.BESTCAPACITYTYPERANK		as eval_capacity_type_rank
	, eval.BESTCAPACITYTYPE			as eval_capacity_type_desc1
	, eval.BESTCAPACITYTYPEDISPLAY	as eval_capacity_type_desc2


--	, eval.BESTCAPACITYDATECHANGED	as eval_capacity_rating_date_CY
	, eval.BESTCAPACITYDATECHANGED	as eval_capacity_rating_date
	--,RESEARCHSTATUSCONFIRMED
	--,RESEARCHSTATUSCONFIRMEDBY
	, eval.RESEARCHSTATUSCONFIRMER	as eval_research_status_confirmer
	, eval.RESEARCHSTATUSCONFIRMERDATE as eval_research_status_confirm_date
	, eval.BESTCAPACITYVALUEMIN as eval_capacity_level_lower
	, eval.BESTCAPACITYVALUEMAX as eval_capacity_level_upper
	, eval.BESTCAPACITYVALUEMID as eval_capacity_level_mid

	/*VCU connectedness*/
	, model.bwf_connectedness			as eval_bwf_connectedness

	, case when isnull(b.isalumni,0) = 1 then 7 else 0 end				  --VCU alums
	+ case when isnull(b.isalumni,0) = 1 and isnull(b_sp.isalumni,0) = 1 then 4 else 0 end				  --VCU spouse is alum lowered from 5 to 4 on 8/7/26
	+ case when con.flag_parent_constituency = 1 --handles most non-freshman parents
		     or vchild.pm_parent_vchild_latest_start_date >= datefromparts(year(dateadd(month,6,getdate()))-1,7,1) --handles freshmen parents prior to them receiving the parent constituency
	       then 5 else 0 end		  --VCU current parent
	+ case when vol_vol.num_volunteer_campaign >=1 then 5 else 0 end			--volunteer switched to use engagement data - removed board membership as that is handled below.
	+ case when rel_cnt.num_relationships_individuals >=4 then 4 else isnull(rel_cnt.num_relationships_individuals,0) end
	+ case when isnull(case when ( pd.flag_managed_currently = 1			--prospect manager  7
								or pt.flag_managed_team_current = 1			--7
								or pt.flag_managed_stewardship_current = 1  --7
								or pt.flag_managed_foundation_current = 1  --7
								or isnull(flag_pgi_referral_active,0) = 1		--added here so not double counted
								or isnull(flag_pgi_positive_active,0) = 1		--added here so not double counted
								--or pt.flag_managed_discovery_current = 1	--3
								--or pt.flag_managed_engagement_current = 1 --obsolete
					  ) then 1 else 0 end,0) = 1 then 3 else 0 end        --currently managed - moved to 3 on 8/7/26 - Carrie wants 0
	+ case when isnull(pt.flag_managed_discovery_current,0) = 1 then 0 else 0 end      --currently discovery managed  --dropped to avoid double counting

	+ case when isnull(b.primaryemailaddress,'') <> '' then 1 else 0 end            --contact_info
	+ case when isnull(b.primaryphone,'') <> '' then 1 else 0 end 
	+ case when isnull(replace(replace(replace(replace(b.primaryaddress,char(9),''),char(10),''),char(13),''),char(34),''),'') <> '' then 1 else 0 end 
			
	+ case when gvg_hh.gvg_recog_raised_tminus0_5_wo_certain_funds_hh >= 10000			--giving last 5 FYs
	         or gvg_hh.gvg_recog_received_tminus0_5_wo_certain_funds_hh >= 10000
		   then 10 
		   else 0 end
	+ case when (gvg_hh.gvg_recog_raised_tminus0_5_wo_certain_funds_hh >= 2000			--giving last 5 FYs
	         or gvg_hh.gvg_recog_received_tminus0_5_wo_certain_funds_hh >= 2000)
			and isnull(b.age,200) between 18 and 30 then 10 
		   else 0 end
	+ case when gvg_hh.gvg_recog_received_life_wo_certain_funds_hh >= 100000 then 5		--giving all time over 100k then 5 points....this is proposed by Gary 8/19/26 to align with NYU
		   else 0 end
	+ case when gvg_hh.gvg_recog_received_life_wo_certain_funds_hh >= 5000 then 2		--giving all time over 5k then 2 points....this is proposed by Gary 8/19/26 to align with NYU
		   else 0 end
	--+ case when g.gvg_life_gift_count > 20 then 5			--giving count lifetime to unit 
	--	   when g.gvg_life_gift_count > 10 then 3
	--	   when g.gvg_life_gift_count >  5 then 2
	--	   when g.gvg_life_gift_count >  0 then 1
	--	   else 0 end
	+ case when gvg_hh.gvg_recog_received_tminus0_hh > 0 then 2 else 0 end --a point for each year giving in past 5+
	+ case when	gvg_hh.gvg_recog_received_tminus1_hh > 0 then 2 else 0 end
	+ case when	gvg_hh.gvg_recog_received_tminus2_hh > 0 then 2 else 0 end
	+ case when	gvg_hh.gvg_recog_received_tminus3_hh > 0 then 2 else 0 end
	+ case when	gvg_hh.gvg_recog_received_tminus4_hh > 0 then 1 else 0 end
	+ case when	gvg_hh.gvg_recog_received_tminus5_hh > 0 then 1 else 0 end

	+ case when isnull(gvg_hh.gvg_recog_first_hh,0) >= 75 then 2 else 0 end
				
	+ case when b.currentjobtitle is not null
	        and b.currentemployername is not null then 0
		   else 0 end
	
	--May remove these
    --+ case when (isnull(convert(tinyint,dimc.DONOTEMAIL),0) 
	   --        + isnull(convert(tinyint,dimc.DONOTMAIL),0)
		  --     + isnull(convert(tinyint,dimc.DONOTCALL),0)) >= 1 then -2 else 0 end           --big neg for DO NOT CONTACT
		
		--LOOK into DO NOT INCLUDE and DO NOT CONTACT

	+ case when isnull(flag_pgi_NAP_all_VCU_active,0) =1 then 0 else 0 end   --not a prospect all of VCU  was -30 now 0
	--+ case when isnull(flag_pgi_referral_active,0) = 1
	--         or isnull(flag_pgi_positive_active,0) = 1 then 0 else 0 end		

	+ case when datediff(month,gvg_hh.gvg_recog_latest_date_wo_certain_funds_hh,getdate()) <= 3 then 6
	       when datediff(month,gvg_hh.gvg_recog_latest_date_wo_certain_funds_hh,getdate()) <= 6 then 5
		   when datediff(month,gvg_hh.gvg_recog_latest_date_wo_certain_funds_hh,getdate()) <= 12 then 4
		   when datediff(month,gvg_hh.gvg_recog_latest_date_wo_certain_funds_hh,getdate()) <= 18 then 3
		   when datediff(month,gvg_hh.gvg_recog_latest_date_wo_certain_funds_hh,getdate()) <= 24 then 2
		   when datediff(month,gvg_hh.gvg_recog_latest_date_wo_certain_funds_hh,getdate()) <= 36 then 1
		   else 0 end
	+ case when (isnull(committees.flag_committee_member_current,0)	
	           + isnull(committees.flag_board_member_current,0)	) >= 1 then 5 else 0 end  

	+ case when ed_involve.cnt_educational_involvements >=5 then 8
		   when ed_involve.cnt_educational_involvements >= 3 then 5
		   when ed_involve.cnt_educational_involvements >= 2 then 3
		   when ed_involve.cnt_educational_involvements = 1 then 1
		   else 0 end
	+ case when vcu_facstaff.flag_vcu_facstaff_current = 1
			 or vcu_facstaff.flag_vcu_facstaff_retired = 1 then 3 else 0 end  
	+ case when evnts_past3yrs.num_events_past3yrs_attended >=10 then 7
		   when evnts_past3yrs.num_events_past3yrs_attended >=3 then 5
		   when evnts_past3yrs.num_events_past3yrs_attended >=1 then 3
		   when evnts_past3yrs.num_events_attended >=1 then 0			--Removed on2/11/25 Ben/Rachel decision
		   else 0 end
	+ case when pm_num_events_tminus0_hh >=2 then 3 else 0 end			--Proposed 3 points for very recent HH event attendance to match NYU bin better
	+ case when surveyattributes.constituent_system_id is not null then 3 else 0 end --as eval_vcu_connect_survey_respondant
	+ case when eclick.num_email_clicks_last365 > 0 then 2 else 0 end				 --as number of email clicks
	
	as eval_vcu_connectedness_score
	, NULL as eval_vcu_connectedness_desc 

	
	, case when isnull(b.isalumni,0) = 1 then 7 else 0 end		as eval_vcu_connect_alum
	, case when isnull(b.isalumni,0) = 1 and isnull(b_sp.isalumni,0) = 1 then 4 else 0 end as eval_vcu_connect_double_alum_hh
	, case when con.flag_parent_constituency = 1 --handles most non-freshman parents
		     or vchild.pm_parent_vchild_latest_start_date >= datefromparts(year(dateadd(month,6,getdate()))-1,7,1) --handles freshmen parents prior to them receiving the parent constituency
	       then 5 else 0 end									as eval_vcu_connect_parent_current	  --VCU current parent
	, case when vol_vol.num_volunteer_campaign = 1 then 5 else 0 end		as eval_vcu_volunteer			--bad data
	, case when rel_cnt.num_relationships_individuals >=4 then 4 else isnull(rel_cnt.num_relationships_individuals,0) end as eval_vcu_rel_count
	, case when isnull(case when ( pd.flag_managed_currently = 1			--prospect manager
								or pt.flag_managed_team_current = 1
								or pt.flag_managed_stewardship_current = 1
								or isnull(flag_pgi_referral_active,0) = 1
								or isnull(flag_pgi_positive_active,0) = 1
					  ) then 1 else 0 end,0) = 1 then 3 else 0 end as eval_vcu_connect_managed 
	, case when isnull(pt.flag_managed_discovery_current,0) = 1 then 0 else 0 end as eval_vcu_connect_discovery_managed 
	,   case when isnull(b.primaryemailaddress,'') <> ''  then 1 else 0 end            --contact_info
	  + case when isnull(b.primaryphone,'') <> '' then 1 else 0 end
	  + case when isnull(replace(replace(replace(replace(b.primaryaddress,char(9),''),char(10),''),char(13),''),char(34),''),'') <> '' then 1 else 0 end
		    as eval_vcu_connect_contact_info 
	, case when gvg_hh.gvg_recog_raised_tminus0_5_wo_certain_funds_hh >= 10000			--giving last 5 FYs
	         or gvg_hh.gvg_recog_received_tminus0_5_wo_certain_funds_hh >= 10000
		   then 10 else 0 end as eval_vcu_connect_gvg_10k 
	, case when(gvg_hh.gvg_recog_raised_tminus0_5_wo_certain_funds_hh >= 20000			--giving last 5 FYs
	         or gvg_hh.gvg_recog_received_tminus0_5_wo_certain_funds_hh >= 2000)
			and isnull(b.age,200) between 18 and 30 
		   then 10 else 0 end as eval_vcu_connect_gvg_2k_under30yo   
	, case when gvg_hh.gvg_life_num_transactions_wo_certain_funds_hh > 20 then 5			--giving count lifetime to unit
		   when gvg_hh.gvg_life_num_transactions_wo_certain_funds_hh > 10 then 3
		   when gvg_hh.gvg_life_num_transactions_wo_certain_funds_hh >  5 then 2
		   when gvg_hh.gvg_life_num_transactions_wo_certain_funds_hh >  0 then 1
		   else 0 end as eval_vcu_connect_gvg_gift_cnt 	
	, case when gvg_hh.gvg_recog_received_tminus0_hh > 0 then 2 else 0 end --a point for each year giving in past 5+
	+ case when	gvg_hh.gvg_recog_received_tminus1_hh > 0 then 2 else 0 end
	+ case when	gvg_hh.gvg_recog_received_tminus2_hh > 0 then 2 else 0 end
	+ case when	gvg_hh.gvg_recog_received_tminus3_hh > 0 then 2 else 0 end
	+ case when	gvg_hh.gvg_recog_received_tminus4_hh > 0 then 1 else 0 end
	+ case when	gvg_hh.gvg_recog_received_tminus5_hh > 0 then 1 else 0	end as eval_vcu_connect_gvg_each5FYs 
	, case when gvg_sum.gvg_recog_first >= 75 then 2 else 0 end as eval_vcu_connect_gvg_first_75
	, case when b.currentjobtitle is not null
	        and b.currentemployername is not null then 0
		   else 0 end as eval_vcu_connect_has_job_info 
	, case when (isnull(convert(tinyint,dimc.DONOTEMAIL),0) 
	           + isnull(convert(tinyint,dimc.DONOTMAIL),0)
		       + isnull(convert(tinyint,dimc.DONOTCALL),0)) >= 1 then 0 else 0 end  as eval_vcu_connect_do_not_contact  --was -2 now 0
	, case when isnull(flag_pgi_NAP_all_VCU_active,0) =1 then 0 else 0 end as eval_vcu_connect_pgi_not_prospect     --was -30 now 0
	, case when isnull(flag_pgi_referral_active,0) = 1
	         or isnull(flag_pgi_positive_active,0) = 1 then 0 else 0 end as eval_vcu_connect_pgi_suspect_or_positive   
	, case when datediff(month,gvg_hh.gvg_recog_latest_date_wo_certain_funds_hh,getdate()) <= 3 then 6
	       when datediff(month,gvg_hh.gvg_recog_latest_date_wo_certain_funds_hh,getdate()) <= 6 then 5
		   when datediff(month,gvg_hh.gvg_recog_latest_date_wo_certain_funds_hh,getdate()) <= 12 then 4
		   when datediff(month,gvg_hh.gvg_recog_latest_date_wo_certain_funds_hh,getdate()) <= 18 then 3
		   when datediff(month,gvg_hh.gvg_recog_latest_date_wo_certain_funds_hh,getdate()) <= 24 then 2
		   when datediff(month,gvg_hh.gvg_recog_latest_date_wo_certain_funds_hh,getdate()) <= 36 then 1
		   else 0 end as eval_vcu_connect_gvg_recency 
	, case when (isnull(committees.flag_committee_member_current,0)	
	           + isnull(committees.flag_board_member_current,0)	) >= 1 then 5 else 0 end   as eval_vcu_connect_num_boardsNcommittees
	, case when ed_involve.cnt_educational_involvements >=10 then 8
		   when ed_involve.cnt_educational_involvements >= 5 then 5
		   when ed_involve.cnt_educational_involvements >= 2 then 3
		   when ed_involve.cnt_educational_involvements = 1 then 1
		   else 0 end as eval_vcu_educational_involvements
	, case when vcu_facstaff.flag_vcu_facstaff_current = 1
			 or vcu_facstaff.flag_vcu_facstaff_retired = 1  then 3 else 0 end as eval_vcu_connect_facstaff

	, case when evnts_past3yrs.num_events_past3yrs_attended >=10 then 7
		   when evnts_past3yrs.num_events_past3yrs_attended >=3 then 5
		   when evnts_past3yrs.num_events_past3yrs_attended >=1 then 3
		   when evnts_past3yrs.num_events_attended >=1 then 0 else 0 end as eval_vcu_connect_events_past3yrs_attended

	,case when surveyattributes.constituent_system_id is not null then 3 else 0 end as eval_vcu_connect_survey_respondant

	, model.bwf_major_gift_rating		as eval_bwf_major_gift_rating
    , model.bwf_planned_gift_rating		as eval_bwf_planned_gift_rating			--also obsolete at this point
	, model.bwf_acquisition_rating		as eval_bwf_acquisition_rating
	, model.bwf_reactivation_rating		as eval_bwf_reactivation_rating
	, model.bwf_retention_rating		as eval_bwf_retention_rating
    , model.vcu_planned_giving_score	as eval_vcu_planned_giving_score		--Gordons original now obsolete

	--Planned Giving Score
		--Age and demographics
	,  case when b.isdeceased=1 then NULL else 0 end			--dead people don't get scores
	 + case when b.age between 60 and 69 then 1 else 0 end
	 + case when b.age between 70 and 85 then 2 else 0 end
	 + case when b.age between 86 and 90 then 1 else 0 end
	 + case when (year(dateadd(month,6,getdate())) - b.EDUCATIONPREFERREDCLASSYEAR1 >=50   --reunion years 50-90
	         and  year(dateadd(month,6,getdate())) - b.EDUCATIONPREFERREDCLASSYEAR1 <=90) then 1
	        else 0 end
	-- + case when dimc.gender = dimc_sp.gender		      --finding same sex partners. Couldn't find LGBTQ groups in the data. Removed
	--	     and dimc.gender <> 'Unknown' then 1 else 0 end
	 + case when (b.title like '%Bishop%'
	          or  b.title like '%Brother%'
			  or  b.title like '%Canon%'
			  or  b.title like '%Deacon%'
			  or  b.title like '%Father%'
			  or  b.title like '%Minister%'
			  or  b.title like '%Rev%'
			  or  b.title like '%Pastor%'
			  or  b.title like '%Rabbi%'
			  or  b.title like '%Priest%'
			  or  b.title like '%Elder%' 
			  or  b.title like '%Preacher%'
			  or  b.title like '%Chaplain%'
			  or  b.title like '%Cardinal%'
			  or  b.title like '%Eminence%'
			  or  b.title like '%Cantor%'
			  ) then 2 else 0 end

	 + case when dimc.gender = 'Female' then 1 else 0 end			--Female

		--Marital Status and kids
	 + case when dimc.MARITALSTATUS = 'Single'								and (nokids_GB.flag_has_nokids_GB=1 or chl.flag_TP_parent_hh = 0) then 4 else 0 end
	 + case when dimc.MARITALSTATUS in ('Widowed','Surviving Spouse')		and (nokids_GB.flag_has_nokids_GB=1 or chl.flag_TP_parent_hh = 0) then 3 else 0 end
	 
	 + case when dimc.MARITALSTATUS in ('Separated','Divorced')				and (nokids_GB.flag_has_nokids_GB=1 or chl.flag_TP_parent_hh = 0)then 2 else 0 end
	 + case when dimc.MARITALSTATUS = 'Married'								and (nokids_GB.flag_has_nokids_GB=1 or chl.flag_TP_parent_hh = 0) then 2 else 0 end
	 + case when dimc.MARITALSTATUS in ('Companion','Civil Partnership')	and (nokids_GB.flag_has_nokids_GB=1 or chl.flag_TP_parent_hh = 0) then 2 else 0 end
	 + case when dimc.MARITALSTATUS = 'Unknown'								and (nokids_GB.flag_has_nokids_GB=1 or chl.flag_TP_parent_hh = 0) then 2 else 0 end
	 
	 + case when vcu_facstaff.flag_vcu_facstaff_retired = 1 then 2 else 0 end
	 + case when rels.flag_has_parent_child_or_spouse_in_radar = 1 and rels.num_non_parent_child_spouse_relatives_in_radar > 1 then 2 else 0 end
	 + case when rels.flag_has_parent_child_or_spouse_in_radar = 1 then 1 else 0 end
	 + case when rels.num_non_parent_child_spouse_relatives_in_radar > 1 then 1 else 0 end
	 + case when vol_vol.num_volunteer_campaign >=1  then 2 else 0 end
	
	--Giving

	 + case when gvg_recog.gvg_10yrs_num_yrs_vcu_recog >= 9 then 4   --This value could go up to 11 with current FY.  9 gives them a bit of a break for missing one year 
	        when (
			case when (ISNULL(gvg.gvg_tminus0_received,0)	> 0 or ISNULL(gvg.gvg_tminus0_raised,0)	> 0) then 1 else 0 end
		  + case when (ISNULL(gvg.gvg_tminus1_received,0)	> 0 or ISNULL(gvg.gvg_tminus1_raised,0)	> 0) then 1 else 0 end
		  +	case when (ISNULL(gvg.gvg_tminus2_received,0)	> 0 or ISNULL(gvg.gvg_tminus2_raised,0)	> 0) then 1 else 0 end
		  +	case when (ISNULL(gvg.gvg_tminus3_received,0)	> 0 or ISNULL(gvg.gvg_tminus3_raised,0)	> 0) then 1 else 0 end
		  + case when (ISNULL(gvg.gvg_tminus4_received,0)	> 0 or ISNULL(gvg.gvg_tminus4_raised,0)	> 0) then 1 else 0 end
		  + case when (ISNULL(gvg.gvg_tminus5_received,0)	> 0 or ISNULL(gvg.gvg_tminus5_raised,0)	> 0) then 1 else 0 end
				) >=3 then 2
			else 0 end
	 + case when ((ISNULL(addr2.flag_has_identified_seasonal_property,0) = 1) or wf.flag_multi_property_owner=1) then 1 else 0 end
	 + case when gvg_hh.flag_donated_on_a_giving_day_hh = 1 then 1 else 0 end			--Donated on the giving day (will need to update this every year)
	 + case when gvg_sum.flag_rev_ira_gift = 1 then 1 else 0 end						--has paid with an IRA
	 --+ case when (gvg_hh.flag_has_used_daf_hh = 1 
		--	  or flag_TP_DAF_hh = 1) then 1 else 0 end									--HH used a DAF OR has a DAF (via Touchpoints)

	 + case when isnull(chl.flag_TP_DAF_hh,0) = 1						--touchpoint flag
			  or isnull(gvg_hh.flag_has_used_daf_hh,0) = 1				--has donated via a DAF (soft credited on a DAF payment and constituent is living)
			  or isnull(gvg_hh.flag_has_daf_payment,0) = 1				--has donated via DAFPay (paid through GiftCampus)
			  or isnull(chl.flag_WF_DAF_indicator_hh,0) = 1				--windfall indicator flag
			  or isnull(chl.flag_rnl_interest_has_DAF_hh,0) = 1			--RNL survey indicates DAF.  Adds 104 possibly new peeps
	      then 1 else 0 end 


	 + case when gvg_hh.flag_has_used_ff_hh = 1 then 1 else 0 end						--used a Family Foundation
	 + case when gvg_hh.flag_has_given_stock_hh = 1 then 1 else 0 end					--has given in Stock
	 + case when flag_has_endowed_a_fund = 1 then 3 else 0 end							--Endowed fund donor
	 + case when gvg_hh.flag_50k_transaction_donor_hh = 1 then 2 else 0 end

	 + case when ISNULL(g.gvg_tminus0_cash_recog,0) between 1000 and 49999.99 then 2 else 0 end
	 + case when ISNULL(g.gvg_tminus0_cash_recog,0) between 500 and 999.99 then 1 else 0 end
	 + case when (ISNULL(g.gvg_tminus0_cash_recog,0) = ISNULL(g.gvg_life_cash_recog,0))			--New Donors
			 and ISNULL(g.gvg_life_cash_recog,0) > 0 then 1 else 0 end

	 + case when (gvg_recog.gvg_tminus0_vcu_recog >= gvg_recog.gvg_5yr_avg_vcu_recog * 3		--significant pop over previous giving
	          or  gvg_recog.gvg_tminus1_vcu_recog >= gvg_recog.gvg_5yr_avg_vcu_recog * 3)
			  and gvg_recog.gvg_5yr_avg_vcu_recog >= 250 then 1 else 0 end

		 --Capacity Rating
	 + case when left(eval_capacity_rating_desc_short_sort_hh,1) in ('D','E','F','G') then 1		--$500K-10M
			when left(eval_capacity_rating_desc_short_sort_hh,1) in ('A','B','C') then 2			--10M+
			else 0 end

	  as eval_vcu_planned_giving_score_SQL

	/*Parts of the PG Score*/
	,case when b.age between 60 and 69 then 1 
		  when b.age between 70 and 85 then 2
		  when b.age between 86 and 90 then 1 else 0 end as eval_PG_score_age
	,case when (year(dateadd(month,6,getdate())) - b.EDUCATIONPREFERREDCLASSYEAR1 >=50 
	       and  year(dateadd(month,6,getdate())) - b.EDUCATIONPREFERREDCLASSYEAR1 <=90) then 1
	      else 0 end as eval_PG_score_classyr
	,case when (b.title like '%Bishop%'
	          or  b.title like '%Brother%'
			  or  b.title like '%Canon%'
			  or  b.title like '%Deacon%'
			  or  b.title like '%Father%'
			  or  b.title like '%Minister%'
			  or  b.title like '%Rev%'
			  or  b.title like '%Pastor%'
			  or  b.title like '%Rabbi%'
			  or  b.title like '%Priest%'
			  or  b.title like '%Elder%' 
			  or  b.title like '%Preacher%'
			  or  b.title like '%Chaplain%'
			  or  b.title like '%Cardinal%'
			  or  b.title like '%Eminence%'
			  or  b.title like '%Cantor%'
			  ) then 2 else 0 end  as eval_PG_score_clergy

	,case when dimc.MARITALSTATUS = 'Single' and  (nokids_GB.flag_has_nokids_GB=1 or chl.flag_TP_parent_hh = 0)								then 4
		  when dimc.MARITALSTATUS in ('Widowed','Surviving Spouse') and (nokids_GB.flag_has_nokids_GB=1 or chl.flag_TP_parent_hh = 0)		then 3 

		  when dimc.MARITALSTATUS in ('Separated','Divorced') and (nokids_GB.flag_has_nokids_GB=1 or chl.flag_TP_parent_hh = 0)				then 2 
		  when dimc.MARITALSTATUS = 'Married' and (nokids_GB.flag_has_nokids_GB=1 or chl.flag_TP_parent_hh = 0)								then 2 
		  when dimc.MARITALSTATUS in ('Companion','Civil Partnership') and (nokids_GB.flag_has_nokids_GB=1 or chl.flag_TP_parent_hh = 0)	then 2 
		  when dimc.MARITALSTATUS = 'Unknown' and (nokids_GB.flag_has_nokids_GB=1 or chl.flag_TP_parent_hh = 0)								then 2 
		  else 0 end as eval_PG_score_marstat

	,case when vol_vol.num_volunteer_campaign >=1  then 2 else 0 end as eval_PG_score_volunteer
	,case when vcu_facstaff.flag_vcu_facstaff_retired = 1 then 2 else 0 end as eval_PG_score_retired_facstaff
	,case when gvg_sum.flag_rev_ira_gift = 1 then 1 else 0 end as eval_PG_score_ira_gift
	,case when isnull(chl.flag_TP_DAF_hh,0) = 1							--touchpoint flag
			or isnull(gvg_hh.flag_has_used_daf_hh,0) = 1				--has donated via a DAF (soft credited on a DAF payment and constituent is living)
			or isnull(gvg_hh.flag_has_daf_payment,0) = 1				--has donated via DAFPay (paid through GiftCampus)
			or isnull(chl.flag_WF_DAF_indicator_hh,0) = 1				--windfall DAF indicator
			or isnull(chl.flag_rnl_interest_has_DAF_hh,0) = 1			--RNL survey
	      then 1 else 0 end	as eval_PG_score_has_daf_hh					--renamed eval_PG_score_used_DAF to eval_PG_score_has_DAF_hh
	,case when gvg_hh.flag_has_used_ff_hh = 1 then 1 else 0 end as eval_PG_score_used_ff
	,case when gvg_recog.gvg_10yrs_num_yrs_vcu_recog >= 9 then 4 
		  when (
			case when (ISNULL(gvg.gvg_tminus0_received,0)	> 0 or ISNULL(gvg.gvg_tminus0_raised,0)	> 0) then 1 else 0 end
		  + case when (ISNULL(gvg.gvg_tminus1_received,0)	> 0 or ISNULL(gvg.gvg_tminus1_raised,0)	> 0) then 1 else 0 end
		  +	case when (ISNULL(gvg.gvg_tminus2_received,0)	> 0 or ISNULL(gvg.gvg_tminus2_raised,0)	> 0) then 1 else 0 end
		  +	case when (ISNULL(gvg.gvg_tminus3_received,0)	> 0 or ISNULL(gvg.gvg_tminus3_raised,0)	> 0) then 1 else 0 end
		  + case when (ISNULL(gvg.gvg_tminus4_received,0)	> 0 or ISNULL(gvg.gvg_tminus4_raised,0)	> 0) then 1 else 0 end
		  + case when (ISNULL(gvg.gvg_tminus5_received,0)	> 0 or ISNULL(gvg.gvg_tminus5_raised,0)	> 0) then 1 else 0 end
				) >=3 then 2
		  else 0 end  as eval_PG_score_gvg_freq  

	,case when ISNULL(addr2.flag_has_identified_seasonal_property,0) = 1 then 1 else 0 end as eval_PG_score_seasonal_property
	,case when ISNULL(g.gvg_tminus0_cash_recog,0) between 1000 and 49999.99 then 2
	      when ISNULL(g.gvg_tminus0_cash_recog,0) between 500 and 999.99 then 1 else 0 end eval_PG_score_FY_cash
	,case when (ISNULL(g.gvg_tminus1_cash_recog,0) = ISNULL(g.gvg_life_cash_recog,0)) 
			 and ISNULL(g.gvg_life_cash_recog,0) > 0 then 1 else 0 end eval_PG_score_FY22_New_Donor  --This needs work - will incresingly become wrong
	,case when (gvg_recog.gvg_tminus0_vcu_recog >= gvg_recog.gvg_5yr_avg_vcu_recog * 2
	          or  gvg_recog.gvg_tminus1_vcu_recog >= gvg_recog.gvg_5yr_avg_vcu_recog * 2) then 1 else 0 end eval_PG_score_200pct


	,wf.wf_date_enriched							as eval_wf_enriched_date
	,convert(money,wf.wf_net_worth)					as eval_wf_net_worth
	,units_all.unit_connectedness_list_all				as pm_unit_connectedness_list_all
	,isnull(units_all.unit_connectedness_num_all,0)		as pm_unit_connectedness_num_all
	,units.unit_connectedness_list						as pm_unit_connectedness_list
	,isnull(units.unit_connectedness_num,0)				as pm_unit_connectedness_num
	,units_other.unit_connectedness_list_other			as pm_unit_connectedness_list_other
	,isnull(units_other.unit_connectedness_num_other,0)	as pm_unit_connectedness_num_other
	,units_ltg.unit_connectedness_list_ltg_short_all	as pm_unit_connectedness_list_ltg_short_all
	,isnull(units_ltg.unit_connectedness_donated_num_all,0) as pm_unit_connectedness_donated_num_all
	--,units.unit_connectedness_list_short				as pm_unit_connectedness_list_short
	--,units.unit_connectedness_list_short_other		as pm_unit_connectedness_list_short_other
	,servicearea.servicearea_connectedness_list			as pm_servicearea_connectedness_list
	,isnull(servicearea.servicearea_connectedness_num,0) as pm_servicearea_connectedness_num
	,unit_lagodeo.unit_connectedness_list				as pm_lagodeo_connectedness_list
	,isnull(unit_lagodeo.unit_connectedness_num,0)		as pm_lagodeo_connectedness_num

	, NULL												as eval_default_segment_grid_rank		--placeholder NULL and updated in an UPDATE statement near the end of the SP
	, chl.eval_default_segment_grid_rank_hh
	, NULL												as eval_overall_prospect_rank			--placeholder NULL and updated in an UPDATE statement near the end of the SP
	, chl.eval_overall_prospect_rank_hh
	, chl.eval_overall_prospect_rank_cl_hh

	,case	  when wf.flag_boat_owner = 1 then 1 else 0 end
	   + case when wf.flag_plane_owner = 1 then 1 else 0 end
	   + case when wf.flag_multi_property_owner = 1 then 1 else 0 end
	   + case when wf.flag_trust_association = 1 then 1 else 0 end
	   + case when wf.flag_foundation_association = 1 then 1 else 0 end
	   + case when wf.flag_foundation_officer_trustee = 1 then 1 else 0 end
	   + case when wf.flag_nonprofit_board_member = 1 then 1 else 0 end
	   + case when wf.flag_money_in_motion = 1 then 1 else 0 end
	   + case when wf.flag_luxury_car_owner = 1 then 1 else 0 end
	   + case when wf.flag_imported_car_owner = 1 then 1 else 0 end
	   + case when chl.flag_WF_DAF_indicator_hh = 1 then 1 else 0 end
	   + case when wf.wf_job_level in ('Director', 'Owner', 'VP', 'CXO', 'Partner',
									   'Senior,VP', 'Manager,Senior', 'Senior,Director',
									   'Director,Owner', 'Director,CXO', 'CXO,Partner'
									   ) then 1 else 0 end
	   + case when wf.recent_promotion = 1 then 1 else 0 end
	   + case when touchpoint.TP_complex_assets = 'Yes' then 1 else 0 end
	   + case when touchpoint.TP_DAF = 'Yes' then 1 else 0 end
	   + case when touchpoint.TP_foundation = 'Yes' then 1 else 0 end
	   + case when touchpoint.TP_parent is NULL and touchpoint.record_id is not NULL then 1 else 0 end
	   as pm_mg_prioritization_score

	,concat(case when wf.flag_boat_owner = 1 then 'boat; ' else '' end
	   , case when wf.flag_plane_owner = 1 then 'place; ' else '' end
	   , case when wf.flag_multi_property_owner = 1 then 'multiprop; ' else '' end
	   , case when wf.flag_trust_association = 1 then 'trust; ' else '' end
	   , case when wf.flag_foundation_association = 1 then 'fndation_assoc; ' else '' end
	   , case when wf.flag_foundation_officer_trustee = 1 then 'fndation_trustee; ' else '' end
	   , case when wf.flag_nonprofit_board_member = 1 then 'nonprofit; ' else '' end
	   , case when wf.flag_money_in_motion = 1 then 'money_motion; ' else '' end
	   , case when wf.flag_luxury_car_owner = 1 then 'luxury_car; ' else '' end
	   , case when wf.flag_imported_car_owner = 1 then 'import_car; ' else '' end
	   , case when chl.flag_WF_DAF_indicator_hh = 1 then 'WF_DAF; ' else '' end
	   , case when wf.wf_job_level in ('Director', 'Owner', 'VP', 'CXO', 'Partner',
									   'Senior,VP', 'Manager,Senior', 'Senior,Director',
									   'Director,Owner', 'Director,CXO', 'CXO,Partner'
									   ) then 'WF_job_level' else '' end
	   , case when wf.recent_promotion = 1 then 'promotion; ' else '' end
	   , case when touchpoint.TP_complex_assets = 'Yes' then 'TP_complex_assets; ' else '' end
	   , case when touchpoint.TP_DAF = 'Yes' then 'TP_DAF; ' else '' end
	   , case when touchpoint.TP_foundation = 'Yes' then 'TP_foundation; ' else '' end
	   , case when touchpoint.TP_parent is NULL and touchpoint.record_id is not NULL then 'TP_no_kids;' else '' end
	   ) as pm_mg_prioritization_score_list

   
   -- , pgi_funding_type_code			as eval_pgi_funding_type_code
   -- , pgi_inclination_level_code	as eval_pgi_inclination_level_code
   -- , pgi_comment					as eval_pgi_comment
   -- , pgi_include_spouse			as eval_pgi_include_spouse
	
/*	

	,lsd.eval_latest_screening_date        as eval_latest_screening_date
	,curr_e.affinity_evaluation as eval_affinity
	,curr_e.affinity_evaluation_desc as eval_affinity_desc
	,affin.total_score as eval_affinity_score
	,log10(2.0+affin.total_score) as eval_affinity_score_log
	,convert(date,curr_e.affinity_evaluation_date) as eval_affinity_date
	,hha.eval_hh_affinity
	,hha.eval_hh_affinity_desc
	,convert(decimal(16,2),curr_e.rfv_score) as eval_rfv

*/

  /*******************************************************************************************************************/
   /************************************** PROSPECT DEVELOPMENT-RELATED VARIABLES **************************************/
   /*******************************************************************************************************************/
  
	,isnull(team.pm_management_team,'Unmanaged') as pm_current_team
	,isnull(team.pm_management_team_system_ids,'Unmanaged') as pm_current_team_system_ids
	,isnull(team.pm_management_team_lookup_ids,'Unmanaged') as pm_current_team_lookup_ids
	,isnull(team.pm_management_team_unit_names,'Unmanaged') as pm_current_team_unit_names
	,team.pm_lead_officer		as pm_current_fundraiser_lead
	,team.pm_lead_officer_unit_short	as pm_current_fundraiser_lead_unit
	,team.pm_lead_officer_avp			as pm_current_fundraiser_lead_avp
--	,isnull(t.current_team_size,0) as pm_current_team_size
	,pd.officer_name			as pm_current_team_lead
	,pd_spouse.officer_name		as pm_current_team_lead_spouse
--	,t.current_team_lead_email as pm_current_team_lead_email
--	,t.latest_team_member_date  as pm_latest_team_member_date
	,case   when pd.flag_managed_currently = 1					then 'Prospect Manager'
			when pt.flag_managed_team_current = 1				then 'Team Member'				
			when pt.flag_managed_stewardship_current = 1		then 'Stewardship Manager'
			when pt.flag_managed_discovery_current = 1			then 'Discovery Manager'
			when pt.flag_managed_foundation_current = 1			then 'Foundation Manager'
			when pt.flag_managed_engagement_current = 1			then 'Engagement Manager'
			when pt.flag_managed_alumni_relations_current = 1	then 'Alumni Relations Manager'
			else 'No Assignment' end as pm_current_assignment_status

	,pd.unit_name				as pm_current_managing_unit_name
	,pd.unit_id					as pm_current_managing_unit_id

	, team.pm_current_prospect_manager
	, team.pm_current_stewardship_manager
	, team.pm_current_team_member
	, team.pm_current_discovery_manager
	, team.pm_current_foundation_manager
	, team.pm_current_development_staff

	, team.pm_current_PM_system_id
	, team.pm_current_PM_lookup_id
	, team.pm_current_PM_latest_unit_name
	, team.pm_current_PM_latest_unit_name_short
	, team.pm_current_PM_latest_unit_name_campaign
	, team.pm_current_PM_latest_avp

	,case when pd.prospect_status = 'Assigned' then 'Assigned'
		  when pd.prospect_status = 'Spouse is Assigned' and b.ISDECEASED = 0 then 'Assigned'  --covers the situation where each HH member is on a different fundraiser... The Cabaniss couple
		  when b.ISDECEASED = 1 then 'Deceased' --if I move this below Stew then it would be easy to find the deceased people with Referrals or Stew...otherwise
		  when pd.prospect_status = 'Referred' then 'Referred'
		  when pd.prospect_status = 'Permanent Stewardship' then 'Permanent Stewardship'
		  when pd.prospect_status = 'Not a prospect' then 'Not a prospect'
		  when pd.constituent_id = 0 then 'No Prospect Status'  --this is the NULL record 00000000-0000-0000-0000-000000000000 (probably not in this DS)
		  when pd.prospect_status = 'No Prospect Status' then 'Unassigned' --the majority of people
		  when isnull(pd.prospect_status,'Unassigned') = 'Unassigned' then 'Unassigned'  --probably deprecated
		  else 'Undefined' end as pm_prospect_status

--	,pd_hh.prospect_status_hh	as pm_prospect_status_hh
	,pd.prospect_status			as pm_prospect_status_radar
	,case 
		  when sols_staging.flag_opp_past_qualified = 1		--active qualified asks in the past
		    or sols_staging.flag_opp_recent_qualified = 1	--opportunities from today up to 90 days in the future
			--or sols_staging.flag_opp_response_pending = 1	--response pending (moved to Negotiation on 12/6/25)
			--or sols_staging.flag_opp_verbal_accept = 1	--active qualified asks in the past (moved to Negotiation on 12/6/25)
			or sols_staging.flag_opp_recent_doc_accept = 1  --within last 30 days 
		  then '9. Solicitation'

		  when sols_staging.flag_opp_response_pending = 1	--response pending
			or sols_staging.flag_opp_verbal_accept = 1		--active qualified asks in the past
		  then '8. Negotiation'

		  when sols_staging.flag_opp_farfuture_qualified = 1	--Opportunity greater than 90 days in the future and no stewardship manager (stew man caught in 7 above)
		  then '7. Proposal Development'

		  -- flipped on 1/10/25 with stewardship (GAT for RBM)
		  when isnull(pd.flag_managed_currently,0) = 1			--active prospect manager but no opp (opps caught in 9.Solicitation above)
		--	or sols_staging.flag_opp_farfuture_qualified = 1	--Opportunity greater than 90 days in the future and no stewardship manager (moved to proposal development on 12/5/25)
			or isnull(pp.num_active_prospect_plans,0) > 0		--Plan, but no opportunity (opps caught in 9.Solicitation above)
			or (sols_staging.flag_opp_2_5yrs_doc_accept = 1 and b.ISDECEASED=0 and pd.prospect_status <> 'Not a prospect' )	--Accepted documented opportunity 2 years or older and has no stewardship manager (stew man caught in 7 above) and they have to be living
		  then '6. Cultivation'

		  when sols_staging.flag_opp_steward_doc_accept = 1   --Accepted-Documented Opportunity with a documented accepted date of more than 30 days and within the past 2 years.
		    or isnull(pt.flag_managed_stewardship_current,0) = 1  
		  then '5. Stewardship'

		  --should we flip this with 4. Qualification?
		  when pd.prospect_status = 'Permanent Stewardship' 
		  then '4. Permanent Stewardship'  -- eventually 'Perpetual Stewardship'

		  when pd.prospect_status = 'Referred'
			or isnull(pt.flag_managed_discovery_current,0) = 1	--has a discovery officer
			or isnull(pt.flag_managed_foundation_current,0) = 1	--has a foundation officer
			or isnull(pt.flag_managed_team_current,0) = 1		--has a team member
			or (sols_staging.flag_opp_old_doc_accept = 1 and b.ISDECEASED=0 and pd.prospect_status <> 'Not a prospect')  --accepted doc over 5 years old
		  then '3. Qualification'

		  when b.ISDECEASED = 1
		  then '*. Deceased'									--was *. Deceased.  by making it * when combined with other HH member it will come after the living person in 2/1/0 stage.
		  when pd.prospect_status = 'Not a prospect' 
		  then '2. Not a Prospect'
		  when eval.BESTCAPACITYTYPEDISPLAY = 'VCU verified capacity' 
		    or moves.latest_completed_sig_interaction_orig is not null
		  then '1. Identification'
		  else '0. No Stage Assigned'
	      end as pm_stage_calculated
	,NULL as pm_stage_calculated_hh			--this will get updated every day from the CHL table after the CHL table is updated
--	,t.days_managed as pm_days_managed

    ,isnull(pp.num_active_prospect_plans,0)			as pm_num_active_prospect_plans
    ,pp.prospect_plan_active_earliest_start_date	as pm_prospect_plan_active_earliest_start_date
	,pp.prospect_plan_active_latest_start_date		as pm_prospect_plan_active_latest_start_date
	,case when sc.SOLICITCODES = '' then NULL else sc.SOLICITCODES end		as pm_solicit_code_list

	/*make these 4 obsolete replaced by the ones below it*/
	,puf.CAMPUS										as pg_primary_campus
	,puf.UNIT										as pg_primary_unit
	,puf.CONNECTEDNESS								as pg_primary_unit_connectedness
	,puf.SCORE										as pg_primary_unit_connectedness_score

	/*all 48 or so CSUs*/
	,puf.CAMPUS										as pm_top_unit_campus_allCSU
	,puf.UNIT										as pm_top_unit_allCSU
	,puf.UNIT_SHORT									as pm_top_unit_short_allCSU
	,puf.UNIT_SYSTEM_ID								as pm_top_unit_system_id_allCSU
	,puf.CONNECTEDNESS								as pm_top_unit_connectedness_desc_allCSU
	,puf.SCORE										as pm_top_unit_connectedness_score_allCSU

	/*29 or so Philanthropic CSUs*/
	,puf.CAMPUS_Philanthropic						as pm_top_unit_campus_philanthropic
	,puf.UNIT_Philanthropic							as pm_top_unit_philanthropic
	,puf.UNIT_SHORT_Philanthropic					as pm_top_unit_short_philanthropic
	,puf.UNIT_SYSTEM_ID_Philanthropic				as pm_top_unit_system_id_philanthropic
	,puf.CONNECTEDNESS_Philanthropic				as pm_top_unit_connectedness_desc_philanthropic
	,puf.SCORE_Philanthropic						as pm_top_unit_connectedness_score_philanthropic

	/*12 (14) or so Annual/Primary Giving CSUs*/
	,puf.CAMPUS_AG									as pm_top_unit_campus_AG
	,puf.UNIT_AG									as pm_top_unit_AG
	,puf.UNIT_SHORT_AG								as pm_top_unit_short_AG
	,puf.UNIT_SYSTEM_ID_AG							as pm_top_unit_system_id_AG
	,puf.CONNECTEDNESS_AG							as pm_top_unit_connectedness_desc_AG
	,puf.SCORE_AG									as pm_top_unit_connectedness_score_AG

	/*12 (14) or so Annual/Primary Giving CSUs + 4 MPAR CSUs*/
	,puf.CAMPUS_AG_MPAR								as pm_top_unit_campus_AG_MPAR
	,puf.UNIT_AG_MPAR								as pm_top_unit_AG_MPAR
	,puf.UNIT_SHORT_AG_MPAR							as pm_top_unit_short_AG_MPAR
	,puf.UNIT_SYSTEM_ID_AG_MPAR						as pm_top_unit_system_id_AG_MPAR
	,puf.CONNECTEDNESS_AG_MPAR						as pm_top_unit_connectedness_desc_AG_MPAR
	,puf.SCORE_AG_MPAR								as pm_top_unit_connectedness_score_AG_MPAR


	,pgfa.PG_Fall_Segmentation						as pg_fall_appeal_segmentation_ageclass
	,pgsa.PG_Spring_Segmentation					as pg_spring_appeal_segmentation_ageclass
	,pgsa.appeal_campus								as pg_spring_appeal_segmentation_campus
    ,pgsa.appeal_unit_connectedness					as pg_spring_appeal_segmentation_connectedness
    ,pgsa.appeal_unit_connectedness_score			as pg_spring_appeal_segmentation_connectedness_score
	--,lagodeo.LAGODEO_Segmentation					as pm_lagodeo_segmentation
	,puf.CAMPUS_LAGODEO								as pm_lagodeo_primary_campus
	,puf.UNIT_LAGODEO								as pm_lagodeo_primary_segment
	,puf.CONNECTEDNESS_LAGODEO						as pm_lagodeo_primary_connectedness
	,puf.SCORE_LAGODEO								as pm_lagodeo_primary_connectedness_score
	
	, topunit.pm_top_unit_connectedness_desc
	, topunit.pm_top_unit_connectedness_score
	, topunit.pm_top_unit_name
	, topunit.pm_top_unit_id
	, topunit.pm_top_unit_avp_officer_manager

	--, topunit12.pm_top12_unit_connectedness_score
    , topunit12.pm_top12_unit_connectedness_desc
    , topunit12.pm_top12_unit_name_short
	--, topunit12.pm_top12_unit_id
	, topunit12.pm_top12_site_id
	--, topunit12.pm_top12_unit_avp_officer_manager

	, topunit_hh.pm_top_unit_connectedness_desc_hh
	, topunit_hh.pm_top_unit_connectedness_score_hh
    , topunit_hh.pm_top_unit_name_hh
	, topunit_hh.pm_top_unit_campaign_name_hh
	, topunit_hh.pm_top_unit_id_hh
	, topunit_hh.pm_top_unit_avp_officer_manager_hh

	, topmainunit_hh.pm_main_unit_connectedness_desc_hh
	, topmainunit_hh.pm_main_unit_connectedness_score_hh
    , topmainunit_hh.pm_main_unit_name_hh
	, topmainunit_hh.pm_main_unit_id_hh
	, topmainunit_hh.pm_main_unit_avp_officer_manager_hh

	, vchild.pm_parent_vchild_latest_start_date
	, isnull(vchild.flag_parent_has_vchild,0) as flag_parent_has_vchild
	, case when vchild.pm_parent_vchild_latest_start_date >= datefromparts(year(dateadd(month,6,getdate()))-1,7,1) then 1 
		   when con.parent_constituency_start_date >= datefromparts(year(dateadd(month,6,getdate()))-1,7,1) then 1
		   else 0 end as flag_parent_of_freshman

	, note.pm_latest_duediligence_note_enter_date
	, note.pm_latest_duediligence_author
	, note.pm_latest_duediligence_note_added_date
	, note.pm_latest_duediligence_note_changed_date
	, note.pm_latest_duediligence_note_title
	, note.pm_latest_duediligence_note_text
	, note.pm_latest_duediligence_note_type

	, isnull(ce.num_engagements_lifetime,0)			as num_engagements_lifetime
	, isnull(ce.num_engagements_campaign,0)			as num_engagements_campaign
	, ce.max_engagement_date
	, ce.min_engagement_date
	, isnull(ce.num_email_n_interactions_last24months,0) as num_email_n_interactions_last24months
	, isnull(ce.num_social_media_engagement_last24months,0) as num_social_media_engagement_last24months
/*
	/* strategy */
	,replace(replace(replace(replace(strat.strategy_comp,char(9),''),char(10),''),char(13),''),char(34),'') as pm_strategy_comprehensive
	,convert(date,strat.last_updated_date) as pm_strategy_last_update
	,strat.last_updated_by as pm_strategy_updated_by
	
	,affiliates.current_affiliates as pm_current_affiliates
	,affiliates.current_ateam as pm_current_ateam_affiliate
	,affiliates.current_af_staff as pm_current_af_staff
	,affiliates.current_af_volunteer as pm_current_af_volunteer

	,replace(replace(replace(replace(comment.latest_comment_text,char(9),''),char(10),''),char(13),''),char(34),'') as pm_latest_comment
	,convert(date,comment2.earliest_comment_date) as pm_earliest_comment_date
	,convert(date,comment2.latest_comment_date) as pm_latest_comment_date
*/
 
    /*******************************************************************************************************************/
    /******************************************** GIVING ***********************************************************/
    /*******************************************************************************************************************/

 

				 /* lifetime giving */
				 , ISNULL(g.gvg_life_cash,0)		as gvg_life_cash
				 , ISNULL(g.gvg_life_cash_recog,0)	as gvg_life_cash_recog
				 , ISNULL(g.gvg_life_ngp,0)			as gvg_life_ngp
				 , ISNULL(g.gvg_life_ngp_recog,0)	as gvg_life_ngp_recog	
				 , ISNULL(g.gvg_life_gift_count,0)  as gvg_life_gift_count   --cash recog

				 /*campaign 2030 giving - Proxy for now*/
				 , ISNULL(g.gvg_tminus0_cash_recog,0)
				  + ISNULL(g.gvg_tminus1_cash_recog,0) 
				  + ISNULL(g.gvg_tminus2_cash_recog,0) as gvg_campaign2030_cash_recog_proxy

				 /* gift timing fields */
				 , g.gvg_latest_cash_recog
				 , g.gvg_latest_ngp_recog

				 /* total cash in past few years */
				 , ISNULL(g.gvg_tminus0_cash_recog,0) as gvg_tminus0_cash_recog
				 , ISNULL(g.gvg_tminus1_cash_recog,0) as gvg_tminus1_cash_recog
				 , ISNULL(g.gvg_tminus2_cash_recog,0) as gvg_tminus2_cash_recog
				 , ISNULL(g.gvg_tminus3_cash_recog,0) as gvg_tminus3_cash_recog
				 , ISNULL(g.gvg_tminus4_cash_recog,0) as gvg_tminus4_cash_recog
				 , ISNULL(g.gvg_tminus5_cash_recog,0) as gvg_tminus5_cash_recog

				 /*Individual giving Using new Revenue Giving Tables */
        		 , ISNULL(gvg.gvg_lifetime_received,0)		as gvg_lifetime_received
   				 , ISNULL(gvg.gvg_lifetime_raised,0)		as gvg_lifetime_raised
				 , ISNULL(gvg.gvg_life_num_transactions,0) as gvg_life_num_transactions
   				 , ISNULL(gvg.gvg_past5FY_received,0)		as gvg_past5FY_received
   				 , ISNULL(gvg.gvg_past5FY_raised,0)			as gvg_past5FY_raised
				 
   				 , ISNULL(gvg.gvg_tminus0_received,0)		as gvg_tminus0_received
   				 , ISNULL(gvg.gvg_tminus0_raised,0)			as gvg_tminus0_raised
   				 , ISNULL(gvg.gvg_tminus1_received,0)		as gvg_tminus1_received
   				 , ISNULL(gvg.gvg_tminus1_raised,0)			as gvg_tminus1_raised
				 , ISNULL(gvg.gvg_tminus2_received,0)		as gvg_tminus2_received
   				 , ISNULL(gvg.gvg_tminus2_raised,0)			as gvg_tminus2_raised
				 , ISNULL(gvg.gvg_tminus3_received,0)		as gvg_tminus3_received
   				 , ISNULL(gvg.gvg_tminus3_raised,0)			as gvg_tminus3_raised
				 , ISNULL(gvg.gvg_tminus4_received,0)		as gvg_tminus4_received
   				 , ISNULL(gvg.gvg_tminus4_raised,0)			as gvg_tminus4_raised
				 , ISNULL(gvg.gvg_tminus5_received,0)		as gvg_tminus5_received
   				 , ISNULL(gvg.gvg_tminus5_raised,0)			as gvg_tminus5_raised

				 /*HH giving Using Revenue Giving Tables */
        		 , ISNULL(gvg_hh_old.gvg_life_received_hh,0)	as gvg_lifetime_received_hh
   				 , ISNULL(gvg_hh_old.gvg_life_raised_hh,0)		as gvg_lifetime_raised_hh
				 , ISNULL(gvg_hh_old.gvg_life_num_transactions_hh,0) as gvg_life_num_transactions_hh
   				 , ISNULL(gvg_hh_old.gvg_past5FY_received_hh,0)		as gvg_past5FY_received_hh
   				 , ISNULL(gvg_hh_old.gvg_past5FY_raised_hh,0)		as gvg_past5FY_raised_hh
				 
   				 , ISNULL(gvg_hh_old.gvg_tminus0_received_hh,0)		as gvg_tminus0_received_hh
   				 , ISNULL(gvg_hh_old.gvg_tminus0_raised_hh,0)		as gvg_tminus0_raised_hh
   				 , ISNULL(gvg_hh_old.gvg_tminus1_received_hh,0)		as gvg_tminus1_received_hh
   				 , ISNULL(gvg_hh_old.gvg_tminus1_raised_hh,0)		as gvg_tminus1_raised_hh
				 , ISNULL(gvg_hh_old.gvg_tminus2_received_hh,0)		as gvg_tminus2_received_hh
   				 , ISNULL(gvg_hh_old.gvg_tminus2_raised_hh,0)		as gvg_tminus2_raised_hh
				 , ISNULL(gvg_hh_old.gvg_tminus3_received_hh,0)		as gvg_tminus3_received_hh
   				 , ISNULL(gvg_hh_old.gvg_tminus3_raised_hh,0)		as gvg_tminus3_raised_hh
				 , ISNULL(gvg_hh_old.gvg_tminus4_received_hh,0)		as gvg_tminus4_received_hh
   				 , ISNULL(gvg_hh_old.gvg_tminus4_raised_hh,0)		as gvg_tminus4_raised_hh
				 , ISNULL(gvg_hh_old.gvg_tminus5_received_hh,0)		as gvg_tminus5_received_hh
   				 , ISNULL(gvg_hh_old.gvg_tminus5_raised_hh,0)		as gvg_tminus5_raised_hh

				 , case when chl.gvg_milestone_campaign_new_donor_hh_date is not null and chl.gvg_milestone_campaign_50k_hh_date is null then 'Primary'
						when chl.gvg_milestone_campaign_50k_hh_date is not null		  and chl.gvg_milestone_campaign_1M_hh_date is null then 'Major'
						when chl.gvg_milestone_campaign_1M_hh_date is not null then 'Principal'
						else 'Non-Donor'
					end as gvg_campaign_donor_level_hh
	--  ,pg.PG_Fall_Segmentation as pg_fall_segmentation
			--	 , case when b.ISINDIVIDUAL=1 and b.ISDECEASED = 0 then isnull(gvg_hh.gvg_donor_category_live_hh,'Never Donor') else NULL end as gvg_donor_category_live_hh  --old version
			     , case when b.ISDECEASED = 0 then isnull(gvg_hh.gvg_donor_category_live_hh,'Never Donor') else 'Deceased' end as  gvg_donor_category_live_hh  --changed to all constituents and not just individuals

				 --, lyb.DONORCATEGORY		as al_donor_category
				 --, lyb.MINDONORCATEGORY		as al_min_donor_category
				 --, lyb.CATGROUPING			as al_catgrouping
				 , NULL		as al_donor_category
				 , NULL		as al_min_donor_category
				 , NULL		as al_catgrouping

				 ,isnull(gvg_hh.flag_donated_on_a_giving_day_hh,0)	as flag_donated_on_a_giving_day_hh
				 ,isnull(gvg_hh.flag_50k_transaction_donor_hh,0)	as flag_50k_transaction_donor_hh
				 ,isnull(gvg_hh.flag_campaign_primary_transaction_donor_hh,0) as flag_campaign_primary_transaction_donor_hh
				 ,isnull(gvg_hh.flag_has_given_stock_hh,0)			as flag_has_given_stock_hh
				 ,isnull(gvg_hh.flag_has_pg_vehicle_hh,0)			as flag_has_pg_vehicle_hh

				 ,gvg_sum.gvg_latest_designation_name
				 ,gvg_sum.gvg_latest_vcu_recognition_amount
				 ,concat(isnull(convert(varchar(20),gvg_sum.gvg_recog_latest_date,101),'')
						,case when gvg_sum.gvg_recog_latest_date is null then '' else '- $' end
						,isnull(convert(varchar(20),gvg_sum.gvg_latest_vcu_recognition_amount,1),'')
						,case when gvg_sum.gvg_latest_vcu_recognition_amount is null then '' else ' (' end
						,isnull(gvg_sum.gvg_latest_designation_name,'')
						,case when gvg_sum.gvg_latest_designation_name is null then '' else ')' end
						) as gvg_latest_vcu_recognition_txt
				 ,concat(isnull(convert(varchar(20),gvg_hh.gvg_recog_latest_date_hh,101),'')
						,case when gvg_hh.gvg_recog_latest_date_hh is null then '' else '- $' end
						,isnull(convert(varchar(20),gvg_hh.gvg_latest_vcu_recognition_amount_hh,1),'')
						,case when gvg_hh.gvg_latest_vcu_recognition_amount_hh is null then '' else ' (' end
						,isnull(gvg_hh.gvg_latest_designation_name_hh,'')
						,case when gvg_hh.gvg_latest_designation_name_hh is null then '' else ')' end
						) as gvg_latest_vcu_recognition_txt_hh
				,gvg_sum.commit_amount_5bin_highest_single_gift
				,isnull(non_vcu_gvg.gvg_life_total_non_VCU,0)			as gvg_life_total_non_VCU
				,isnull(gvg_hh.gvg_recog_first_hh,0)					as gvg_recog_first_hh

				 /* individual giving using new recognition tables - Don't think I need the individual values and have included the hh fields in the Tableau extracts*/
				/*	,ISNULL(gvg_recog.gvg_life_vcu_recog,0)			as gvg_life_vcu_recog
					,ISNULL(gvg_recog.gvg_campaign_vcu_recog,0)		as gvg_campaign_vcu_recog
					,ISNULL(gvg_recog.gvg_tminus0_vcu_recog,0)		as gvg_tminus0_vcu_recog
					,ISNULL(gvg_recog.gvg_tminus1_vcu_recog,0)		as gvg_tminus1_vcu_recog
					,ISNULL(gvg_recog.gvg_tminus2_vcu_recog,0)		as gvg_tminus2_vcu_recog
					,ISNULL(gvg_recog.gvg_tminus3_vcu_recog,0)		as gvg_tminus3_vcu_recog
					,ISNULL(gvg_recog.gvg_tminus4_vcu_recog,0)		as gvg_tminus4_vcu_recog
					,ISNULL(gvg_recog.gvg_tminus5_vcu_recog,0)		as gvg_tminus5_vcu_recog
					,ISNULL(gvg_recog.gvg_tminus6_vcu_recog,0)		as gvg_tminus6_vcu_recog
					,ISNULL(gvg_recog.gvg_tminus7_vcu_recog,0)		as gvg_tminus7_vcu_recog
					,ISNULL(gvg_recog.gvg_tminus8_vcu_recog,0)		as gvg_tminus8_vcu_recog
					,ISNULL(gvg_recog.gvg_tminus9_vcu_recog,0)		as gvg_tminus9_vcu_recog
					,ISNULL(gvg_recog.gvg_tminus10_vcu_recog,0)		as gvg_tminus10_vcu_recog
					,ISNULL(gvg_recog.flag_has_used_daf,0)			as flag_has_used_daf
					,ISNULL(gvg_recog.flag_has_used_ff,0)			as flag_has_used_ff
					,ISNULL(gvg_recog.gvg_5yr_vcu_recog,0)			as gvg_5yr_vcu_recog
					,ISNULL(gvg_recog.gvg_5yr_avg_vcu_recog,0)		as gvg_5yr_avg_vcu_recog
					,ISNULL(gvg_recog.gvg_10yrs_num_yrs_vcu_recog,0)	as gvg_10yrs_num_yrs_vcu_recog
					*/
   /*******************************************************************************************************************/
   /******************************************** Recognition Programs *************************************************/
   /*******************************************************************************************************************/
	 , ISNULL(flag_rp_foundersociety,0)				as flag_rp_foundersociety
	 , ISNULL(flag_rp_heritagesociety,0)			as flag_rp_heritagesociety
	 , ISNULL(flag_rp_masseylawrencesociety,0)		as flag_rp_masseylawrencesociety
	 , ISNULL(flag_rp_MCVsociety,0)					as flag_rp_MCVsociety
	 , ISNULL(flag_rp_legacysociety,0)				as flag_rp_legacysociety

	 , rp_startdate_foundersociety
	 , rp_startdate_heritagesociety
	 , rp_startdate_masseylawrencesociety
	 , rp_startdate_MCVsociety
	 , rp_startdate_legacysociety
	 , rp_startFY_legacysociety
	 , rp_startqtr_legacysociety

	 , ISNULL(flag_rp_atleastone_currentFY,0)			as flag_rp_atleastone_currentFY
	 , ISNULL(flag_rp_atleastone_ever,0)				as flag_rp_atleastone_ever

	 , ISNULL(flag_black_and_gold_loyalty_society,0)	as flag_black_and_gold_loyalty_society
	 , ISNULL(flag_presidents_club_society,0)			as flag_presidents_club_society

   /*******************************************************************************************************************/
   /******************************************** MOVES ***********************************************************/
   /*******************************************************************************************************************/
      , isnull(moves.flag_any_completed_interaction_last_365,0)		as flag_any_completed_interaction_last_365
	  , isnull(moves.flag_any_completed_sig_interaction_last_365,0)	as flag_any_completed_sig_interaction_last_365
	  , isnull(moves.flag_any_completed_SPV_last_365,0)				as flag_any_completed_SPV_last_365

	  , moves.latest_completed_interaction							as mov_latest_completed_interaction
	  , moves.earliest_completed_interaction						as mov_earliest_completed_interaction
	  , moves.latest_completed_sig_interaction_orig					as mov_latest_completed_sig_interaction_orig
	  , moves.earliest_completed_sig_interaction_orig				as mov_earliest_completed_sig_interaction_orig
	  , moves.latest_completed_sig_interaction						as mov_latest_completed_sig_interaction
	  , moves.earliest_completed_sig_interaction					as mov_earliest_completed_sig_interaction
	  , moves.latest_completed_SPV_interaction						as mov_latest_completed_SPV_interaction
	  , moves.earliest_completed_SPV_interaction					as mov_earliest_completed_SPV_interaction
	  , moves.latest_completed_sig_all_interaction_cultivate		as mov_latest_completed_sig_all_interaction_cultivate
	  , moves.latest_completed_sig_primary_interaction_cultivate	as mov_latest_completed_sig_primary_interaction_cultivate
	  , moves.latest_completed_sig_participant_interaction_cultivate	as mov_latest_completed_sig_participant_interaction_cultivate
	  , moves.latest_completed_sig_secondary_interaction_cultivate	as mov_latest_completed_sig_secondary_interaction_cultivate
	  , moves.latest_completed_sig_discovery_interaction_cultivate	as mov_latest_completed_sig_discovery_interaction_cultivate

	  ,lago_moves.latest_lago_interaction_date						as mov_latest_lago_interaction_date
	  ,lago_moves.officer_name										as mov_latest_lago_interaction_lago_name
	  ,lago_moves.interaction_comment								as mov_latest_lago_interaction_comment
	  ,lago_moves.interaction_subcategory							as mov_latest_lago_interaction_subcategory
      ,lago_moves.interaction_category								as mov_latest_lago_interaction_category
      ,lago_moves.interaction_type									as mov_latest_lago_interaction_type

	  ,not_lago_moves.latest_not_lago_interaction_date				as mov_latest_not_lago_interaction_date
	  ,not_lago_moves.officer_name									as mov_latest_not_lago_interaction_lago_name
	  ,not_lago_moves.interaction_comment							as mov_latest_not_lago_interaction_comment
	  ,not_lago_moves.interaction_subcategory						as mov_latest_not_lago_interaction_subcategory
      ,not_lago_moves.interaction_category							as mov_latest_not_lago_interaction_category
      ,not_lago_moves.interaction_type								as mov_latest_not_lago_interaction_type	

	 -- ,last_sig2030_interaction.interaction_actual_date				as mov_latest_completed_sig_interaction2
	  ,last_sig2030_interaction.interaction_owner_name				as mov_latest_completed_sig_interaction_owner
	  ,last_sig2030_interaction.interaction_owner_system_id			as mov_latest_completed_sig_interaction_owner_system_id
	  ,last_sig2030_interaction.interaction_type					as mov_latest_completed_sig_interaction_type

	  ,moves.num_SPV_interactions_past_60_months					as mov_num_SPV_interactions_past_60_months		
	  ,moves.num_SPV_interactions_with_Rao							as mov_num_SPV_interactions_with_Rao
	  ,moves.num_sig_interactions_non_DAR_leadership_past_60_months	as mov_num_sig_interactions_non_DAR_leadership_past_60_months
	  , isnull(moves.flag_mov_stewardship_SPV_interaction_last_365,0)	as flag_mov_stewardship_SPV_interaction_last_365

	  ,isnull(pending_moves.flag_has_pending_interaction,0)			as flag_has_pending_interaction
	  ,isnull(pending_moves.flag_has_pending_plan_interaction,0)	as flag_has_pending_plan_interaction
	  ,pending_moves.mov_earliest_pending_interaction_date
	  ,pending_moves.mov_latest_pending_interaction_date	

	  ,earliest_pending.mov_earliest_pending_interaction_type
      ,earliest_pending.mov_earliest_pending_interaction_objective
      ,earliest_pending.mov_earliest_pending_interaction_comment
      ,earliest_pending.mov_earliest_pending_interaction_date2
      ,earliest_pending.mov_earliest_pending_interaction_concat_info
	  ,earliest_pending.mov_num_pending_interactions

   /*******************************************************************************************************************/
   /******************************************** SOLICITATIONS ***********************************************************/
   /*******************************************************************************************************************/

	  , isnull(sols.flag_ask_rolling_365x2,0)				as flag_ask_rolling_365x2
	  , isnull(sols.num_ask_rolling_365x2,0)				as sol_num_ask_rolling_365x2

	  , sols.sum_ask_rolling_365x2							as sol_sum_ask_rolling_365x2
	  , sols.sum_expected_ask_rolling_365x2					as sol_sum_expected_ask_rolling_365x2
	  , sols.sum_both_ask_rolling_365x2						as sol_sum_both_ask_rolling_365x2

	  , sols.min_opp_ask_amount_rolling_365x2				as sol_min_opp_ask_amount_rolling_365x2
	  , sols.max_opp_ask_amount_rolling_365x2				as sol_max_opp_ask_amount_rolling_365x2
	  , sols.ask_range_rolling_365x2						as sol_ask_range_rolling_365x2
	  , sols.ask_sum_range_rolling_365x2					as sol_ask_sum_range_rolling_365x2

	  , isnull(sols_campaign.num_ask_campaign,0)			as sol_num_ask_campaign
	  , sols_campaign.sum_ask_campaign						as sol_sum_ask_campaign
	  , sols_campaign.sum_documented_accepted_ask_last1825	as sol_sum_documented_accepted_ask_last1825


   /*******************************************************************************************************************/
   /******************************************** FLAG (1/0) VARIABLES *************************************************/
   /*******************************************************************************************************************/

	,case when b.isdeceased=0 then 1 else 0 end		as flag_living
	,case when b_sp.ISDECEASED=0 then 1 else 0 end	as flag_spouse_living
	,isnull(b.isindividual,0)						as flag_individual
	,isnull(b.isorganization,0)						as flag_organization
	,isnull(b.ishousehold,0)						as flag_household  	
	,isnull(b.isalumni,0)							as flag_alum
	,isnull(b_sp.ISALUMNI,0)						as flag_spouse_alum

	,isnull(case when (pd.flag_managed_currently = 1			--prospect manager
					or pt.flag_managed_team_current = 1
					or pt.flag_managed_stewardship_current = 1
					or pt.flag_managed_discovery_current = 1
					or pt.flag_managed_foundation_current = 1
					or pt.flag_managed_engagement_current = 1
					) then 1 else 0 end,0) as flag_managed_currently
	,isnull(case when (pd.flag_managed_currently = 1			--prospect manager
					or pt.flag_managed_team_current = 1
					or pt.flag_managed_stewardship_current = 1
					or pt.flag_managed_discovery_current = 1
					) then 1 else 0 end,0) as flag_managed_currently_wo_FM
	,isnull(pd.flag_managed_currently,0)				as flag_managed_prospect_currently
	,isnull(pt.flag_managed_team_current,0)				as flag_managed_team_currently
	,isnull(pt.flag_managed_stewardship_current,0)		as flag_managed_stewardship_currently
	,isnull(pt.flag_managed_discovery_current,0)		as flag_managed_discovery_currently
	,isnull(pt.flag_managed_foundation_current,0)		as flag_managed_foundation_currently
	,isnull(pt.flag_managed_engagement_current,0)		as flag_managed_engagement_currently
	,isnull(pt.flag_managed_alumni_relations_current,0) as flag_managed_alumni_rel_currently
	,case when em.constituentdimid is not null then 1 else 0 end as flag_managed_ever
	,isnull(team.flag_is_principal_gift_prospect,0)		as flag_is_principal_gift_prospect			--defined in COL and brought back into CL
	--,NULL											as flag_currently_managed_health
	,case 
	    when model.bwf_connectedness in ('A Very Connected','B Connected')
		 and eval.BESTCAPACITYVALUESORT between 5 and 15 then 1 else 0 end as flag_strikezone
	,NULL as flag_strikezone_new
    ,isnull(b.AVAILABLEPROSPECT,0)					as flag_available_prospect
	,case when dimc.DONOTEMAIL = 1 
	       and dimc.DONOTMAIL = 1
		   and dimc.DONOTCALL = 1 then 1 else 0 end as flag_do_not_contact
	,isnull(dimc.DONOTEMAIL,0)						as flag_do_not_email
	,isnull(dimc.DONOTMAIL,0)						as flag_do_not_mail
	,isnull(dimc.DONOTCALL,0)						as flag_do_not_call
	,isnull(dni.flag_permanent_do_not_include,0)	as flag_permanent_do_not_include
	,isnull(call_list_exclude_VCU.flag_exclude_from_call_lists_VCU,0)	 as flag_exclude_call_list_VCU
	,case when parent.parent_lookup_id is null then 0 else 1 end as	flag_is_parent_relationship
	,case when con.flag_parent_constituency = 1 --handles most non-freshman parents
		    or vchild.pm_parent_vchild_latest_start_date >= datefromparts(year(dateadd(month,6,getdate()))-1,7,1) --handles freshmen parents prior to them receiving the parent constituency
	      then 1 else 0 end as flag_parent_current
	,isnull(committees.flag_committee_member_current,0)		as flag_committee_member_current
	,isnull(committees.flag_board_member_current,0)			as flag_board_member_current
	,isnull(committees.flag_board_primary_member_current,0)	as flag_board_primary_member_current
    ,isnull(gvg_sum.flag_rev_ira_gift,0)					as flag_rev_ira_gift
	
	,isnull(con.flag_daf,0)								as flag_daf
	,case when isnull(chl.flag_TP_DAF_hh,0) = 1							--touchpoint flag
			or isnull(gvg_hh.flag_has_used_daf_hh,0) = 1				--has donated via a DAF (soft credited on a DAF payment and constituent is living)
			or isnull(gvg_hh.flag_has_daf_payment,0) = 1				--has donated via DAFPay (paid through GiftCampus)
			or isnull(chl.flag_WF_DAF_indicator_hh,0) = 1				--windfall DAF indicator
			or isnull(chl.flag_rnl_interest_has_DAF_hh,0) = 1			--RNL survey indicator
	      then 1 else 0 end as flag_has_a_daf_hh
	,isnull(con.flag_ff_individual,0)					as flag_ff_individual
	,isnull(con.flag_ff_alumni,0)						as flag_ff_alumni
	,isnull(con.flag_parent_constituency,0)				as flag_parent_constituency
	,isnull(con.flag_parent_past_constituency,0)		as flag_parent_past_constituency
	,isnull(con.flag_parent_prospective_constituency,0) as flag_parent_prospective_constituency
	,isnull(con.flag_VCUHS_trainee,0)					as flag_VCUHS_trainee
	,isnull(con.flag_government_agency,0)				as flag_government_agency
	,isnull(con.flag_student,0)							as flag_student
	,case when moves.flag_any_completed_interaction_last_365 = 1
	        or sols.flag_ask_rolling_365x2 = 1
			or gvg_tminus0_vcu_recog > 0   --asking for any engagement last 365 --using giving proxy dates for now
			or gvg_tminus1_vcu_recog > 0  
		--	or gvg_tminus2_cash_recog > 0   --FY21 Year 1 of campaign.  will replace this with better data
		  then 1 else 0 end as flag_any_engagement_last_365
	,case when moves.flag_any_completed_interaction_campaign2030 = 1
	        or sols_campaign.flag_ask_campaign = 1
			or gvg_campaign_vcu_recog > 0   
		  then 1 else 0 end as flag_any_engagement_campaign2030
    ,isnull(addr2.flag_has_identified_seasonal_property,0) as flag_has_identified_seasonal_property
	,case when b.ETHNICITY like '%Black%' then 1 else 0 end as flag_race_is_black
	,isnull(vcu_facstaff.flag_vcu_facstaff_current,0)			as flag_vcu_facstaff_current
	,isnull(vcu_facstaff.flag_vcu_facstaff_retired,0)			as flag_vcu_facstaff_retired
	,isnull(vol_vol.flag_is_volunteer,0)						as flag_is_volunteer

	,isnull(pgi.flag_pgi_NAP_all_VCU_active,0)		as flag_pgi_NAP_all_VCU_active
	,isnull(pgi.flag_pgi_NAP_unit_active,0)			as flag_pgi_NAP_unit_active
	,isnull(pgi.flag_pgi_NAP_unit_active_PG,0)		as flag_pgi_NAP_unit_active_PG
	,isnull(pgi.flag_pgi_referral_active,0)			as flag_pgi_referral_active
	,isnull(pgi.flag_pgi_positive_active,0)			as flag_pgi_positive_active
	,isnull(pgi.flag_pgi_planned_gift_active,0)	as flag_pgi_planned_gift_active
	,isnull(pgi.flag_pgi_PG_referral,0)			as flag_pgi_PG_referral
	,isnull(pgi.flag_pgi_PG_positive,0)			as flag_pgi_PG_positive
	,isnull(pgi.flag_pgi_PG_VCU_NAP,0)			as flag_pgi_PG_VCU_NAP
	,isnull(pgi.flag_pgi_PG_VCU_future,0)		as flag_pgi_PG_VCU_future
	,isnull(pgi.flag_pgi_PG_unit_NAP,0)			as flag_pgi_PG_unit_NAP
	--,isnull(pgi.flag_pgi_af_gift_active,0)			as flag_pgi_af_gift_active
	,isnull(pgi.flag_pgi_leadership_gift_active,0)	as flag_pgi_leadership_gift_active
	,isnull(pgi.flag_pgi_major_gift_active,0)		as flag_pgi_major_gift_active
	,isnull(pgi.flag_pgi_top_parent_active,0)		as flag_pgi_top_parent_active
	,pgi.pgi_top_parent_active_latest_year 
	--,isnull(flag_pgi_principal_gift_active,0)	as flag_pgi_principal_gift_active
	,case when lago.constituent_system_id is not null then 1 else 0 end as flag_lago_referral_active 

	,isnull(radar.flag_active_radar_user,0)		as flag_active_radar_user
	,case when radar.user_system_id is not null then 1 else 0 end as flag_ever_radar_user

	,isnull(cs_vcu.solicitable_email,1)			as flag_solicitable_email
	,isnull(cs_vcu.solicitable_mail,1)			as flag_solicitable_mail
	,isnull(cs_vcu.solicitable_email,1)			as flag_solicitable_phone

	 ,isnull(cs_vcu.Contactable_Email,1)			as flag_contactable_email
	 ,isnull(cs_vcu.Contactable_Mail,1)				as flag_contactable_mail
	 ,isnull(cs_vcu.Contactable_Phone,1)			as flag_contactable_phone
	 ,isnull(cs_vcu.Contactable_PhoneBusiness,1)	as flag_contactable_phone_business
	 ,isnull(cs_vcu.Contactable_PhoneCell,1)		as flag_contactable_phone_cell
	 ,cs_vcu.Contactable_text						as pm_contactable_by_text


	, NULL as flag_top_hh_member  --the code above is creating a duplicate constituent system id in this table...not sure why.
	,isnull(flag_has_endowed_a_fund,0)			as flag_has_endowed_a_fund
	--,case when dimc.gender = dimc_sp.gender		--finding same sex partners
	--	   and dimc.gender <> 'Unknown' then 1 else 0 end			as flag_lgbtq_affinity
	,isnull(attribs.flag_di_vip,0)					as flag_di_vip
	,isnull(attribs.flag_attribute_mentor,0)		as flag_attribute_mentor
	,isnull(attribs.flag_attribute_volunteer,0)		as flag_attribute_volunteer
	,isnull(attribs.flag_first_gen_student,0)		as flag_first_gen_student
	,isnull(attribs.flag_award_recipient,0)			as flag_award_recipient

	,isnull(mpar_deg.flag_SOM_alum,0)				as flag_SOM_alum
	,isnull(mpar_deg.flag_physician,0)				as flag_physician
	,isnull(mpar_deg.flag_bhs_degree,0)				as flag_bhs_degree
	,isnull(mpar_deg.flag_publichealth_degree,0)	as flag_publichealth_degree
	,isnull(mpar_deg.flag_residency_degree,0)		as flag_residency_degree
	,case when flag_SOM_alum = 1							
			and num_mpar_degrees = 1
			and flag_physician = 1									
			and flag_residency_degree = 0
			and flag_bhs_degree = 0							
			and flag_publichealth_degree = 0
			and class_year_max >= 2000
			then 1 else 0 
		end as flag_SOM_2000plus_Alum

	,case when touchpoint.TP_parent			= 'Yes' then 1 
		  when touchpoint.record_id is not NULL		then 0 else NULL end	as flag_TP_parent --1/0 for the 34k people sent to Touchpoints; NULL otherwise
	,case when touchpoint.TP_foundation		= 'Yes' then 1 
		  when touchpoint.record_id is not NULL		then 0 else NULL end	as flag_TP_foundation
	,case when touchpoint.TP_complex_assets = 'Yes' then 1 
		  when touchpoint.record_id is not NULL		then 0 else NULL end	as flag_TP_complex_assets
	,case when touchpoint.TP_DAF			= 'Yes' then 1 
		  when touchpoint.record_id is not NULL		then 0 else NULL end	as flag_TP_DAF
	,isnull(wf.flag_WF_DAF_indicator,0)		as flag_WF_DAF_indicator
	,isnull(rnl_interest.flag_rnl_interest_has_DAF,0) as flag_rnl_interest_has_DAF
	,isnull(bizowner.flag_business_owner,0) as flag_business_owner

	,case when (pd.flag_managed_currently = 1			--prospect manager
			or pt.flag_managed_team_current = 1
			or pt.flag_managed_stewardship_current = 1
			or pt.flag_managed_discovery_current = 1
			or pt.flag_managed_foundation_current = 1
			or pt.flag_managed_engagement_current = 1
		) then 0											--include if is managed (has some typ eof assignment
		  when pp.num_active_prospect_plans > 0 then 0		--include if has at least one active prospect plan
		  when con.flag_student = 1 then 1					--exclude current student
		  when vcu_facstaff.flag_vcu_facstaff_current = 1 then 1	--exclude current facstaff
		 else 0 end as flag_VCU_employees_to_exclude
	,isnull(chl.flag_VCU_employees_to_exclude_hh,0) as flag_VCU_employees_to_exclude_hh

	  , case when (chl.sol_num_ask_rolling_365x2_hh >=1
				or chl.mov_allofficers_latest_completed_sig_primary_interaction_cultivate_hh >= getdate() - 366
				or chl.mov_allofficers_latest_completed_sig_secondary_interaction_cultivate_hh >= getdate() - 366
				or chl.mov_allofficers_latest_completed_sig_discovery_interaction_cultivate_hh >= getdate() - 366
				--prob need to add other types - participant etc...
				  )
			and chl.flag_managed_prospect_currently_hh = 1
			and isnull(flag_government_agency,0) = 0
	    then 1 
			when chl.flag_managed_prospect_currently_hh = 1
			 and isnull(flag_government_agency,0) = 0
		then 0
		else NULL end as flag_prospect_managed_activation_hh

	  , case when (chl.sol_num_ask_rolling_365x2_hh >=1
				or chl.mov_allofficers_latest_completed_sig_primary_interaction_cultivate_hh >= getdate() - 366
				or chl.mov_allofficers_latest_completed_sig_secondary_interaction_cultivate_hh >= getdate() - 366
				or chl.mov_allofficers_latest_completed_sig_discovery_interaction_cultivate_hh >= getdate() - 366
				--prob need to add other types - participant etc...
				  )
			and pm_prospect_status_hh = 'Assigned'    --chl.flag_managed_currently_hh = 1  I think there is a 2 day lag when removing officers on the prospect_status
			and isnull(flag_government_agency,0) = 0
	    then 1 
			when pm_prospect_status_hh = 'Assigned'  --chl.flag_managed_currently_hh = 1  I think there is a 2 day lag when removing officers on the prospect_status
			 and isnull(flag_government_agency,0) = 0
		then 0
		else NULL end as flag_assigned_activation_hh







	,isnull(legalcontactsnap25.legallycontactable,1)							as flag_legally_contactable_snap
	,isnull(legalcontactsnap26.legallycontactable,1)							as flag_legally_contactable_snap_FY26
	,case when legalcontact.constituentsystemid is not null then 0 else 1 end	as flag_legally_contactable			--Wrens all encompassing solicit code gathering based on Al's snap...may be wrong

	,isnull(pic.flag_has_picture_in_radar,0)									as flag_has_picture_in_radar
	,isnull(eclick.num_email_clicks_last365,0)									as num_email_clicks_last365
	,isnull(committees2.flag_platinum_board_member,0)							as flag_platinum_board_member
	,isnull(team.flag_currently_managed_by_vp,0)								as flag_currently_managed_by_vp
	,engagements.engagement_latest_email_click_through							as engagement_latest_email_click_through_date
	,engagements.engagement_latest_event_attendance								as engagement_latest_event_attendance_date

	,dimc.ADDEDDATE									as z_date_record_added
	,isnull(weird.exclude_groups,'include')			as z_exclude_groups
   /*******************************************************************************************************************/
   /******************************************** ENGAGE PERSONA VARIABLES *********************************************/
   /*******************************************************************************************************************/

 	, --case when isnull(b.isalumni,0) = 1 then 7 else 0 end				  --VCU alums
	--+ case when isnull(b.isalumni,0) = 1 and isnull(b_sp.isalumni,0) = 1 then 5 else 0 end				  --VCU spouse is alum
	--+ case when flag_parent_constituency = 1 --handles most non-freshman parents
	--	     or vchild.pm_parent_vchild_latest_start_date >= datefromparts(year(dateadd(month,6,getdate()))-1,7,1) --handles freshmen parents prior to them receiving the parent constituency
	--       then 5 else 0 end		  --VCU current parent
	--+ case when vol.flag_is_volunteer = 1 then 5 else 0 end
	--+ case when rel_cnt.num_relationships_individuals >=4 then 4 else isnull(rel_cnt.num_relationships_individuals,0) end
	--+ case when isnull(case when ( pd.flag_managed_currently = 1			--prospect manager  7
	--							or pt.flag_managed_team_current = 1			--7
	--							or pt.flag_managed_stewardship_current = 1  --7
							
	--				  ) then 1 else 0 end,0) = 1 then 7 else 0 end        --currently managed
	--+ case when isnull(pt.flag_managed_discovery_current,0) = 1 then 3 else 0 end      --currently discovery managed  --look into whether someone is getting both 7 and 3 points

	--+ case when isnull(b.primaryemailaddress,'') <> '' then 1 else 0 end            --contact_info
	--+ case when isnull(b.primaryphone,'') <> '' then 1 else 0 end 
	--+ case when isnull(replace(replace(replace(replace(b.primaryaddress,char(9),''),char(10),''),char(13),''),char(34),''),'') <> '' then 1 else 0 end 
			
	--+ case when(g.gvg_tminus0_cash_recog +					--giving last 5 FYs
	--            g.gvg_tminus1_cash_recog +
	--			g.gvg_tminus2_cash_recog +
	--			g.gvg_tminus3_cash_recog +
	--			g.gvg_tminus4_cash_recog +
	--			g.gvg_tminus5_cash_recog 
	--			) >= 10000 then 10 
	--	   else 0 end
	--+ case when(g.gvg_tminus0_cash_recog +                --giving last 5 FYs for young alums 
	--            g.gvg_tminus1_cash_recog +
	--			g.gvg_tminus2_cash_recog +
	--			g.gvg_tminus3_cash_recog +
	--			g.gvg_tminus4_cash_recog +
	--			g.gvg_tminus5_cash_recog 
	--			) >= 2000 and isnull(b.age,200) between 18 and 30 then 10 
	--	   else 0 end
	--+ case when g.gvg_tminus0_cash_recog > 0 then 2 else 0 end --a point for each year giving in past 5+
	--+ case when	g.gvg_tminus1_cash_recog > 0 then 2 else 0 end
	--+ case when	g.gvg_tminus2_cash_recog > 0 then 2 else 0 end
	--+ case when	g.gvg_tminus3_cash_recog > 0 then 2 else 0 end
	--+ case when	g.gvg_tminus4_cash_recog > 0 then 1 else 0 end
	--+ case when	g.gvg_tminus5_cash_recog > 0 then 1 else 0	end

	--+ case when isnull(gvg_sum.gvg_recog_first,0) >= 75 then 2 else 0 end
				
	--+ case when b.currentjobtitle is not null
	--        and b.currentemployername is not null then 0
	--	   else 0 end

	--+ case when isnull(flag_pgi_NAP_all_VCU_active,0) =1 then 0 else 0 end   --not a prospect all of VCU  was -30 now 0
	--+ case when isnull(flag_pgi_referral_active,0) = 1
	--         or isnull(flag_pgi_positive_active,0) = 1 then 7 else 0 end		

		--Recency
	  case when datediff(month,g.gvg_latest_ngp_recog,getdate()) <= 6 then 5
		   when datediff(month,g.gvg_latest_ngp_recog,getdate()) <= 12 then 4
		   when datediff(month,g.gvg_latest_ngp_recog,getdate()) <= 24 then 3
		   when datediff(month,g.gvg_latest_ngp_recog,getdate()) <= 36 then 2
		   when g.gvg_latest_ngp_recog is not null then 1
		   else 0 end

		--Frequency
	+ case when gvg_hh_old.gvg_life_num_transactions_hh >= 20 then 5
		   when gvg_hh_old.gvg_life_num_transactions_hh >= 15 then 4
		   when gvg_hh_old.gvg_life_num_transactions_hh >= 10 then 3
		   when gvg_hh_old.gvg_life_num_transactions_hh >= 2  then 2
		   when gvg_hh_old.gvg_life_num_transactions_hh >= 1  then 1
		   else 0 end



		--+ case when (isnull(committees.flag_committee_member_current,0)	
	--           + isnull(committees.flag_board_member_current,0)	) >= 1 then 5 else 0 end  

	--+ case when ed_involve.cnt_educational_involvements >=5 then 8
	--	   when ed_involve.cnt_educational_involvements >= 3 then 5
	--	   when ed_involve.cnt_educational_involvements >= 2 then 3
	--	   when ed_involve.cnt_educational_involvements = 1 then 1
	--	   else 0 end
	--+ case when vcu_facstaff.flag_vcu_facstaff_current = 1
	--		 or vcu_facstaff.flag_vcu_facstaff_retired = 1 then 3 else 0 end  
	--+ case when evnts_past3yrs.num_events_past3yrs_attended >=10 then 7
	--	   when evnts_past3yrs.num_events_past3yrs_attended >=3 then 5
	--	   when evnts_past3yrs.num_events_past3yrs_attended >=1 then 3
	--	   when evnts_past3yrs.num_events_attended >=1 then 0			--Removed on2/11/25 Ben/Rachel decision
	--	   else 0 end
	--+ case when surveyattributes.constituent_system_id is not null then 3 else 0 end --as eval_vcu_connect_survey_respondant
	--+ case when eclick.num_email_clicks_last365 > 0 then 2 else 0 end				 --as number of email clicks
	
	as eval_vcu_primary_giving_connectedness_score

	, case when chl.eval_capacity_rating_desc_short_sort_hh < 'G' then 1 else 0 end			--#1
	+ case when num_dafgifts_10k_past10yrs_hh>=3 or num_stockgifts_10k_past10yrs_hh >=3 then 1 else 0 end			--#2 STOCKS AND DAF
	+ case when non_vcu_gvg.gvg_life_total_non_VCU >= 500000 then 1 else 0 end
	+ case when b.age > 50																	--#4 will be 55+ by End of Campaign (need to modify as time goes on)
		or (b.age is null and case when b.EDUCATIONCLASSOF1 = 0 then NULL else b.EDUCATIONCLASSOF1 end < 1990)		--class year 40 years from end of campaign
		or gvg_sum.flag_rev_ira_gift = 1
		or gvg_hh.gvg_recog_first_date_hh < '01-01-1993'
		   then 1 else 0 end
	+ case when chl.flag_alum_hh = 1														--#5				
			 or chl.flag_vcu_facstaff_current_hh = 1						
			 or chl.flag_vcu_facstaff_retired_hh = 1								
		   then 1 else 0 end		
	+ case when b.vcuregioncodemsa		in ( 'Richmond-Petersburg, VA'						--#6                                                             
											,'Washington, DC-MD-VA-WV'
											,'Norfolk-Virginia Beach-Newport News, VA-NC'
											,'Charlottesville, VA'
											,'Raleigh-Durham-Chapel Hill, NC'				--these two are 139 miles away
											,'Roanoke, VA'									--these two are 139 miles away. the rest are closer
											,'Lynchburg, VA'
											,'Rocky Mount, NC'
											,'Danville, VA'
											,'Baltimore, MD'
											,'Greenville, NC'                                                                                      
											) 
			or cast(  case when addr.latitude is null or addr.longitude is null then null
				 else 2 * 3958.7613 * asin(
					  sqrt( power( sin( (radians(addr.latitude) - radians(37.546879)) / 2 ), 2 )
					+ cos(radians(37.5407)) * cos(radians(addr.latitude))
					* power( sin( (radians(addr.longitude) - radians(-77.450257)) / 2 ), 2 ) ) )
					end	as int) < 140 then 1 else 0 end			

	+ case when (
					case when isnull(b.isalumni,0) = 1 and isnull(b_sp.isalumni,0) = 1	then 1 else 0 end	--#7 Lifeconnection		--double alum HH
				 +  case when committees.earliest_board_start_date is not null			then 1 else 0 end	--ever served on a board
				 +  case when engagements.engagement_flag_season_ticket_holder = 1		then 1 else 0 end	--ever had season tickets
				 +  case when rels.flag_has_radar_relation_alum_facstaff = 1			then 1 else 0 end	--has at least one relation in radar who is an alum or fac/staff
				 +	case when rels.flag_has_radar_friend_facstaff = 1					then 1 else 0 end	--has at least one friend/neighbor who is fac/staff
			  ) >= 3 then 1 else 0 end	
	+ case when chl.flag_managed_currently_hh = 1 
			and spvs.max_num_SPV_visits>=3 then 1 else 0 end								--#8 Established development officer relationship
	+ case when campus_visit.num_campus_visits >= 1 then 1 else 0 end						--#9 Campus visit
	+ case when moves.num_SPV_interactions_past_60_months >= 3 then 1 else 0 end			--#10 Three or more direct visits with a unit leader 
	+ case when gvg_hh.gvg_recog_raised_tminus0_10_hh >= 10000 then 1 else 0 end			--#11 High level annual giving
	+ case when (isnull(committees.flag_committee_member_current,0)	
	           + isnull(committees.flag_board_member_current,0)	) > 0 then 1 else 0 end		--#12 this may too broad and need to lower to top-level boards
 	+ case when SPV_wSpouse.constituent_system_id is not null then 1 else 0 end				--#13 Meaningful engagement of key family stakeholders, especially the spouse. Only Spouse for now
	+ case when gvg_hh.flag_majorgift_transaction_donor_hh = 1 then 1 else 0 end			--#14 Major Gift (50K/25K)
--+ Stellar execution of test gift by program participants									--#15
--+ Creative, customized stewardship of test gift											--#16 BESPOKE STEWARDSHIP - NOT USED?
	+ case when moves.num_SPV_interactions_with_Rao > 0 then 1 else 0 end					--#17 First meeting with the President

	  as eval_VCU_principal_giving_points

	, NULL as eval_VCU_principal_giving_score
	, NULL as eval_VCU_principal_giving_rank

	, case when chl.eval_capacity_rating_desc_short_sort_hh < 'G' then 1 else 0 end							as eval_pringiv_1_highcapacity		--#1
	, case when num_dafgifts_10k_past10yrs_hh>=3 or num_stockgifts_10k_past10yrs_hh >=3 then 1 else 0 end	as eval_pringiv_2_daf_stock			--#2 STOCKS AND DAF
	, case when non_vcu_gvg.gvg_life_total_non_VCU >= 500000 then 1 else 0 end								as eval_pringiv_3_big_non_VCU_gvg	--#3 big non-VCU giving
	, case when b.age > 50																	--#4 will be 55+ by End of Campaign (need to modify as time goes on)
		or (b.age is null and case when b.EDUCATIONCLASSOF1 = 0 then NULL else b.EDUCATIONCLASSOF1 end < 1990)		--class year 40 years from end of campaign
		or gvg_sum.flag_rev_ira_gift = 1
		or gvg_hh.gvg_recog_first_date_hh < '01-01-1993'
		   then 1 else 0 end		as eval_pringiv_4_old
	, case when chl.flag_alum_hh = 1														--#5				
			 or chl.flag_vcu_facstaff_current_hh = 1						
			 or chl.flag_vcu_facstaff_retired_hh = 1								
		   then 1 else 0 end		as eval_pringiv_5_alum_fac
	, case when b.vcuregioncodemsa		in ( 'Richmond-Petersburg, VA'						--#6                                                             
											,'Washington, DC-MD-VA-WV'
											,'Norfolk-Virginia Beach-Newport News, VA-NC'
											,'Charlottesville, VA'
											,'Raleigh-Durham-Chapel Hill, NC'				--these two are 139 miles away
											,'Roanoke, VA'									--these two are 139 miles away. the rest are closer
											,'Lynchburg, VA'
											,'Rocky Mount, NC'
											,'Danville, VA'
											,'Baltimore, MD'
											,'Greenville, NC'                                                                                      
											) 
			or cast(  case when addr.latitude is null or addr.longitude is null then null
				 else 2 * 3958.7613 * asin(
					  sqrt( power( sin( (radians(addr.latitude) - radians(37.546879)) / 2 ), 2 )
					+ cos(radians(37.5407)) * cos(radians(addr.latitude))
					* power( sin( (radians(addr.longitude) - radians(-77.450257)) / 2 ), 2 ) ) )
					end	as int) < 140 then 1 else 0 end		as eval_pringiv_6_local	

	, case when (
					case when isnull(b.isalumni,0) = 1 and isnull(b_sp.isalumni,0) = 1	then 1 else 0 end	--#7 Lifeconnection		--double alum HH
				 +  case when committees.earliest_board_start_date is not null			then 1 else 0 end	--ever served on a board
				 +  case when engagements.engagement_flag_season_ticket_holder = 1		then 1 else 0 end	--ever had season tickets
				 +  case when rels.flag_has_radar_relation_alum_facstaff = 1			then 1 else 0 end	--has at least one relation in radar who is an alum or fac/staff
				 +	case when rels.flag_has_radar_friend_facstaff = 1					then 1 else 0 end	--has at least one friend/neighbor who is fac/staff
			  ) >= 3 then 1 else 0 end  as eval_pringiv_7_life_connection								
	, case when chl.flag_managed_currently_hh = 1 
			and spvs.max_num_SPV_visits>=3 then 1 else 0 end as eval_pringiv_8_managed									--#8 Established development officer relationship
	, case when campus_visit.num_campus_visits >= 1 then 1 else 0 end as eval_pringiv_9_campus_visit					--#9 Campus visit (this is narrower than instructions)
	, case when moves.num_SPV_interactions_past_60_months >= 3 then 1 else 0 end as eval_pringiv_10_interactions			--#10 Three or more direct visits with a unit leader 
	, case when gvg_hh.gvg_recog_raised_tminus0_10_hh >= 10000 then 1 else 0 end as eval_pringiv_11_bigmoney			--#11 High level annual giving
	, case when (isnull(committees.flag_committee_member_current,0)	
	           + isnull(committees.flag_board_member_current,0)	) > 0 then 1 else 0 end	as eval_pringiv_12_committee	--#12 this may too broad and need to lower to top-level boards
	, case when SPV_wSpouse.constituent_system_id is not null then 1 else 0 end			as eval_pringiv_13_spouse_engagement	--#13 Meaningful engagement of key family stakeholders, especially the spouse.
	, case when gvg_hh.flag_majorgift_transaction_donor_hh = 1 then 1 else 0 end as eval_pringiv_14_majorgift			--#14 Major Gift (50K/25K)
--+ Stellar execution of test gift by program participants									--#15
--+ Creative, customized stewardship of test gift											--#16 BESPOKE STEWARDSHIP - NOT USED?
	, case when moves.num_SPV_interactions_with_Rao > 0 then 1 else 0 end	as eval_pringiv_17_rao				--#17 First meeting with the President

	,case --Data Strategy Project - constituent record standards 20260507
		when b.isdeceased = 1
			then '9 Deceased'
		
		when ( (chl.flag_managed_currently_hh = 1 and eval.BESTCAPACITYVALUESORTED in (
				'A. $50,000,000 and above', 'B. $25,000,000-$49,999,999', 
				'C. $10,000,000-$24,999,999', 'D. $5,000,000-$9,999,999' ) ) 
			or isnull(team.flag_currently_managed_by_vp,0) = 1 
			or isnull(committees2.flag_platinum_board_member,0)	 = 1 )
			then '1 Platinum'
		
		when ( (chl.flag_managed_currently_hh = 1 
			or isnull(committees.flag_board_member_current,0)	 = 1 
			or chl.pm_prospect_status_hh = 'Referred')
			and (eval.BESTCAPACITYVALUESORTED not in (
				'A. $50,000,000 and above', 'B. $25,000,000-$49,999,999', 
				'C. $10,000,000-$24,999,999', 'D. $5,000,000-$9,999,999' ) or eval.BESTCAPACITYVALUESORTED is null)
			and (team.pm_current_discovery_manager not like '%Givzey%' 
			or team.pm_current_discovery_manager is null) )
			then '2 Gold'
		
		when ( (team.pm_current_discovery_manager not like '%Givzey%' 
			or team.pm_current_discovery_manager is null)
			and (eval.BESTCAPACITYVALUESORTED not in (
				'A. $50,000,000 and above', 'B. $25,000,000-$49,999,999', 
				'C. $10,000,000-$24,999,999', 'D. $5,000,000-$9,999,999' ) or eval.BESTCAPACITYVALUESORTED is null)
			and ( (isnull(b.isalumni,0)	 = 0 and chl.gvg_recog_raised_campaign_hh >= 1000) 
			or (isnull(b.isalumni,0)	 = 1 and chl.gvg_recog_raised_life_hh >= 1) ) )
			then '3 Silver'
		
		when ( (team.pm_current_discovery_manager not like '%Givzey%' 
			or team.pm_current_discovery_manager is null)
			and (eval.BESTCAPACITYVALUESORTED not in (
				'A. $50,000,000 and above', 'B. $25,000,000-$49,999,999', 
				'C. $10,000,000-$24,999,999', 'D. $5,000,000-$9,999,999' ) or eval.BESTCAPACITYVALUESORTED is null)
			and (isnull(con.flag_parent_constituency,0)	 = 1 
			or isnull(flag_parent_past_constituency,0) = 1 
			or (isnull(b.isalumni,0)	 = 1 and chl.gvg_recog_raised_life_hh < 1)) )
			then '4 Bronze'
		
		else '5 Iron' end
	as eval_record_standard_metal

	--NYU BIN exercise
		--0. Pre-binning
		  , case when b.ISDECEASED = 1		 then 9						--deceased people in bin 9
				 when (dimc.DONOTEMAIL = 1 
				  and  dimc.DONOTMAIL = 1
				  and  dimc.DONOTCALL = 1
				  and  b.isalumni = 1)	 then 5							--do not contacts - moving alums up to 5s - distant alums. all alums are 1-5 unless deceased
				 when (dimc.DONOTEMAIL = 1 
				  and  dimc.DONOTMAIL = 1
				  and  dimc.DONOTCALL = 1)	 then 6						--do not contacts	
				-- when cl.soli = 1 then 5

			--1. Ownership (about 4.3K)
				 when isnull(committees.flag_committee_member_current,0) = 1 then 1		--current committee members  --need to check this in comparison to engagement volunteerism
				 when ea_fy.num_events >=2 then 1										--2+ event attendee (current FY)
				 when gvg_hh.gvg_recog_raised_tminus0_wo_certain_funds_hh >= 10000 
				   or gvg_hh.gvg_recog_received_tminus0_wo_certain_funds_hh  >= 10000 then 1				--Gave $10k+ (current FY)
				 when gvg_hh.gvg_recog_received_life_wo_certain_funds_hh >= 100000 then 1					--Gave $100K+ (lifetime)
				 when vol_vol.num_volunteer_currentFY>=1 then 1							--Volunteer current year

			--2. Participation
				 when isnull(chl.flag_vcu_facstaff_current_hh,0) = 1 then 2				--Current VCU Employee HH
				 when chl.flag_parent_current_hh = 1				 then 2				--Current Parent HH							--handles most non-freshman parents
					--or vchild.pm_parent_vchild_latest_start_date >= datefromparts(year(dateadd(month,6,getdate()))-1,7,1) then 2	--Current Parent
				 when isnull(con.flag_student,0)	 = 1 then 2							--Current Student
				 when chl.pm_num_events_tminus0_hh = 1 then 2							--1 Event attendee HH (current FY)
				 when gvg_hh.gvg_recog_raised_tminus0_hh >= 1 
				   or gvg_hh.gvg_recog_received_tminus0_hh >= 1 then 2					--Donor (current FY)
				 when gvg_hh.gvg_5yr_number_transactions_raised_hh > =3 then 2			--Gave 3+ times in last 5 yrs


			--3. Experience
				 when isnull(chl.flag_parent_past_constituency_hh,0) = 1 then 3
				 when (case when b.ISDECEASED = 0 then isnull(gvg_hh.gvg_donor_category_live_hh,'Never Donor') else 'Deceased' end) in ('Sybunt 2-5yr','Lybunt') then 3	--Lybunt, Sybunt
				 when gvg_hh.gvg_recog_raised_tminus0_5_hh>0
					or gvg_hh.gvg_recog_received_tminus0_5_hh>0 then 3
				 when vol_vol.num_volunteer_tminus1_5 >=1 then 3
				--  when datediff(day,inv_latest_committees_current,getdate()) < 365 then 3			--just put in 365 for grins
				 when datediff(day,convert(date,past_committees.latest_past_committee_end_date),getdate()) < 2000 then 3		--should pull people who have been on a past recent committee but not currently (level1)
				 when engagements.engagement_latest_event_attendance	 is not null then 3

			--4. Interest
				 when ce.num_email_n_interactions_last24months > 0 then 4
				 when ce.num_social_media_engagement_last24months > 0 then 4
				 when attribs.flag_award_recipient = 1 then 4
	

			--5. Distant Alums
				  when b.ISALUMNI = 1 then 5

			--6. Awareness
				  when gvg_hh.gvg_recog_raised_life_hh > 0 then 6
				  when (case when b.ISDECEASED = 0 then isnull(gvg_hh.gvg_donor_category_live_hh,'Never Donor') else 'Deceased' end) in ('Sybunt 6yr_plus') then 6		--Lybunt, Sybunt  
				  when gvg_hh.gvg_recog_latest_date_hh < dateadd(year,-5,getdate()) then 6		--Donor 5+ Years Ago  --should be redundant on above
				  when eval.BESTCAPACITYTYPEDISPLAY = 'VCU verified capacity' then 6

			--7. Ignorance
				  when b.ISDECEASED = 0 then 7

				 else 9											--should just be deceased people
			end  as eval_nyu_bin

			,isnull(ea_fy.num_events,0)							as pm_num_events_tminus0
			,isnull(vol_vol.num_volunteer_currentFY,0)			as pm_num_volunteer_tminus0
			,isnull(vol_vol.num_volunteer_tminus1_5,0)			as pm_num_volunteer_tminus1_5
			,past_committees.latest_past_committee_end_date		as pm_latest_past_committee_end_date
			,gvg_sum.pg_vehicle_list							

FROM 
  
   --( For these first 6 tables/views: time=7:17 ; n=710k  03/31/25)
   BBCRM_PROD_RPT_BBDW.BBDW.VCU_RPT_CONSTITUENTLIST b  --(time = 50s; n=710k)
   left join BBCRM_PROD_RPT_BBDW.BBDW.DIM_CONSTITUENT dimc on dimc.CONSTITUENTSYSTEMID = b.CONSTITUENTSYSTEMID --(time = 68s; n=710)
   left join BBCRM_PROD_RPT_BBDW.BBDW.VCU_DIM_CONSTITUENT_EXT dimext on dimext.CONSTITUENTDIMID = b.CONSTITUENTDIMID  --(time = 78s; n=710)
   left join DARanalytics.tableau.vcu_country_codes vcc on vcc.VCU_Country_Code = dimc.PRIMARYADDRESSCOUNTRYABBREVIATION  --(time = 78s; n=710)
   left join DARanalytics.datamart.gvg_revenue_history_summary_indiv gvg_sum on gvg_sum.constituent_system_id = b.CONSTITUENTSYSTEMID  --(solo time time=1:43; n=278k) 
   left join DARanalytics.ref.life_expectancy_2023 le on le.bio_age = b.age 
													 and le.bio_gender = case when dimc.GENDER in ('unknown','other') then 'female' else dimc.GENDER end
   left join DARanalytics.ref.msa_list msa on msa.MSA_name_RADAR = b.vcuregioncodemsa
   /* VCU_RPT_CONSTITUENTLIST is DIM_CONSTITUENT WITH THESE exclusions
        isgroup = 0
    and isactive = 1
	and isconstituent = 0
	*/

	/*spouse information  -could do this directly as this field exists in dim_constituent*/
	  left join BBCRM_PROD_RPT_BBDW.BBDW.VCU_RPT_CONSTITUENTLIST b_sp on b_sp.constituentsystemid = b.spousesystemid
	                                                                 and b.spousesystemid <> '00000000-0000-0000-0000-000000000000'
	  left join BBCRM_PROD_RPT_BBDW.BBDW.DIM_CONSTITUENT dimc_sp on dimc_sp.constituentsystemid = b.spousesystemid
	  	                                                        and b.spousesystemid <> '00000000-0000-0000-0000-000000000000'

	/*household information - has a handful of dupes*/
	left join (
	SELECT count(*) as cnt
         , MEMBERCONSTITUENTDIMID
         , max(GROUPCONSTITUENTDIMID)       as household_id
         , max(convert(tinyint,ISPRIMARY))	as flag_is_primary_hh_member
    --	,CONSTITUENTGROUPMEMBERSYSTEMID
    --  ,FROMDATE
    --  ,FROMDATEDIMID
    --  ,TODATE
    --  ,TODATEDIMID
    -- , ISCURRENT
    FROM BBCRM_PROD_RPT_BBDW.BBDW.V_QUERY_BBDW_HOUSEHOLDMEMBER
  where iscurrent = 1
  group by MEMBERCONSTITUENTDIMID
  ) hh on hh.memberconstituentdimid = b.constituentdimid

    /*Summary ID information no dupes - more rows than in constituentlist (about 80 more)*/
	left join (
SELECT -- ID
       max(cm.CONSTITUENTSYSTEMID_SUMMARY)  as household_system_id  --equivalent to the constituent_system_id when an individual household.  Otherwise it is unique to all members of the household
      ,max(cm.CONSTITUENTDIMID_SUMMARY)		as household_id
	  ,max(c.CONSTITUENTLOOKUPID)			as household_lookup_id  --should only exist for people with HH constituencies.  household_system_id should be used for matching HHs AND Individuals overtime
      ,max(cm.FULLNAME_SUMMARY)				as FULLNAME_SUMMARY
      ,max(convert(tinyint,cm.ISHOUSEHOLD))	as ISHOUSEHOLD
      ,cm.CONSTITUENTSYSTEMID				as CONSTITUENTSYSTEMID
      ,max(cm.CONSTITUENTDIMID)				as CONSTITUENTDIMID
      ,max(cm.FULLNAME)						as FULLNAME
      ,max(convert(tinyint,cm.ISINDIVIDUAL))				as ISINDIVIDUAL
      ,max(convert(tinyint,cm.ISDECEASED))					as ISDECEASED
      ,max(convert(tinyint,cm.ISACTIVE))					as ISACTIVE
   /*   ,BIRTHDATE
      ,CONSTITUENTSYSTEMID_SPOUSE
      ,CONSTITUENTDIMID_SPOUSE
      ,FULLNAME_SPOUSE
      ,ISDECEASED_SPOUSE
      ,ISACTIVE_SPOUSE
      ,BIRTHDATE_SPOUSE
      ,ETLCONTROLID
	  */
  FROM BBCRM_PROD_RPT_BBDW.BBDW.VCU_FACT_CONSTITUENTMARRIAGE cm
  left join BBCRM_PROD_RPT_BBDW.BBDW.DIM_CONSTITUENT c on c.CONSTITUENTSYSTEMID = cm.CONSTITUENTSYSTEMID_SUMMARY  --where there is a household constituent this links and gets the household_lookup_id
  group by cm.CONSTITUENTSYSTEMID
  ) hh_summary on hh_summary.CONSTITUENTSYSTEMID = b.CONSTITUENTSYSTEMID



  left join DARanalytics.datamart.gvg_revenue_history_summary_hh gvg_hh on gvg_hh.household_dim_id = hh_summary.household_id  --checked for dupes good on 10.3.2023

  /* Constituencies */
	left join (select count(*) as cnt
				  , max(CONSTITUENTDIMID)			as CONSTITUENTDIMID 
				  , CONSTITUENTSYSTEMID
				  , max(flag_daf)					as flag_daf
				  , max(flag_ff_individual)			as flag_ff_individual
				  , max(flag_ff_alumni)				as flag_ff_alumni
				  , max(flag_parent_constituency)	as flag_parent_constituency
				  , max(flag_parent_past)			as flag_parent_past_constituency
				  , max(flag_parent_prospective)	as flag_parent_prospective_constituency
				  , max(flag_VCUHS_trainee)			as flag_VCUHS_trainee
				  , max(flag_government_agency)		as flag_government_agency
				  , max(parent_constituency_start_date) as parent_constituency_start_date
				  , max(flag_student)				as flag_student

			from (

				SELECT fc.CONSTITUENTDIMID
					 , fc.CONSTITUENTSYSTEMID
					 , c.CONSTITUENCYCODESYSTEMID
					 , c.CONSTITUENCY
					 , case when c.CONSTITUENCYCODESYSTEMID = '7A1EFE1A-531F-4F19-86BB-4514609B674B' then isnull(max(fc.FROMDATE),'2000-01-01') else NULL end as parent_constituency_start_date
					 , case when c.CONSTITUENCYCODESYSTEMID = 'F68532ED-23FD-4FCA-8314-844A265058C1' then 1 else 0 end as flag_daf
					 , case when c.CONSTITUENCYCODESYSTEMID = 'E04CA216-DC62-478C-8951-21F838A9C5AE' then 1 else 0 end as flag_ff_individual
					 , case when c.CONSTITUENCYCODESYSTEMID = 'A3735DF0-C5CD-456B-9E4A-213F71A3052E' then 1 else 0 end as flag_ff_alumni
					 , case when c.CONSTITUENCYCODESYSTEMID = '7A1EFE1A-531F-4F19-86BB-4514609B674B' then 1 else 0 end as flag_parent_constituency		--do I trust this?
					 , case when c.CONSTITUENCYCODESYSTEMID = '52F77FE2-8611-442C-B3E2-1EBE27B17647' then 1 else 0 end as flag_VCUHS_trainee	
					 , case when c.CONSTITUENCYCODESYSTEMID = '7AD71505-4909-464B-9991-5A92CB914809' then 1 else 0 end as flag_government_agency
					 , case when c.CONSTITUENCYCODESYSTEMID = '133A9225-ED60-4246-A7F1-266E84D5456A' then 1 else 0 end as flag_parent_past
					 , case when c.CONSTITUENCYCODESYSTEMID = '4DB8F4FC-BC43-421D-B592-69BEF109B5FC' then 1 else 0 end as flag_student
					 , case when c.CONSTITUENCYCODESYSTEMID = '8BC3261A-6679-4AF3-BD16-07424747691A' then 1 else 0 end as flag_parent_prospective					
				
					/* CONSTITUENCYFACTID
					,CONSTITUENCYSYSTEMID
					,FROMDATEDIMID
					,FROMDATE
					,TODATEDIMID
					,TODATE
					,ISCURRENTCONSTITUENCY
					*/

				 FROM BBCRM_PROD_RPT_BBDW.BBDW.FACT_CONSTITUENCY fc
				 left join BBCRM_PROD_RPT_BBDW.BBDW.DIM_CONSTITUENCY c on c.CONSTITUENCYDIMID = fc.CONSTITUENCYDIMID  --Check this table for possibly other useful constituencies
				WHERE c.CONSTITUENCYCODESYSTEMID in
							( 'F68532ED-23FD-4FCA-8314-844A265058C1'	--DAF
							, 'A3735DF0-C5CD-456B-9E4A-213F71A3052E'	--Foundation - Family (Alumni)
							, 'E04CA216-DC62-478C-8951-21F838A9C5AE'	--Foundation - Family (Individual)
						--	, 'E805737D-7AE5-4DF2-9C83-30046407DE67'	--Foundation
							, '7A1EFE1A-531F-4F19-86BB-4514609B674B'	--Parent
							, '133A9225-ED60-4246-A7F1-266E84D5456A'	--Past Parent (only 2 of these - seems useless)
							, '52F77FE2-8611-442C-B3E2-1EBE27B17647'	--Housestaff Trainees
							, '7AD71505-4909-464B-9991-5A92CB914809'	--Government Agency
							, '4DB8F4FC-BC43-421D-B592-69BEF109B5FC'	--Student
							, '8BC3261A-6679-4AF3-BD16-07424747691A'	--Prospective Parent
							)
				 and getdate() between isnull(fc.fromdate,'2000-01-02') and isnull(fc.todate,'2099-12-31')
				 and fc.ISCURRENTCONSTITUENCY = 1
			group by fc.CONSTITUENTDIMID, fc.CONSTITUENTSYSTEMID, c.CONSTITUENCYCODESYSTEMID, c.CONSTITUENCY
			) t
          group by CONSTITUENTSYSTEMID  --CONSTITUENTDIMID, 
		  --order by cnt desc
			) con on con.CONSTITUENTSYSTEMID = b.CONSTITUENTSYSTEMID

	/* Employment */

	/* schools, majors, degrees (vcu) */

	/*double VCU degree - ugrad and grad alums */
	 	
	/*future double vcu degree - alums currently in VCU Grad School */

	/* schools, degrees (other) */
	
	/* current parents  */

	left join (
	--ONLY Current Parents (including deceased) -  NOTE: duplicated student records possible since, you know - 2 parents
SELECT distinct 
       par.primary_constituent_lookup_id		as parent_lookup_id
	 , par.primary_constituent_dim_id			as parent_dim_id
	 , par.primary_constituent_system_id		as parent_system_id
/*	 , dc.CONSTITUENTLOOKUPID					as student_lookup_id
	 , cr.CONSTITUENTDIMID						as student_dim_id
     , cr.CONSTITUENTSYSTEMID					as student_system_id
     , cr.CONSTITUENCYDIMID
     , cr.FROMDATE
     , cr.TODATE
*/
  FROM BBCRM_PROD_RPT_BBDW.BBDW.FACT_CONSTITUENCY cr  --students
    left join BBCRM_PROD_RPT_BBDW.BBDW.DIM_CONSTITUENCY cs on cs.CONSTITUENCYDIMID = cr.CONSTITUENCYDIMID
    left join BBCRM_PROD_RPT_BBDW.BBDW.DIM_CONSTITUENT dc on dc.CONSTITUENTSYSTEMID = cr.CONSTITUENTSYSTEMID
	 join ( --all parent child relationships - many to many
			SELECT cr.CONSTITUENTDIMID		as primary_constituent_dim_id
			     , cr.CONSTITUENTSYSTEMID	as primary_constituent_system_id
				 , dc.CONSTITUENTLOOKUPID
				 , c.CONSTITUENTLOOKUPID    as primary_constituent_lookup_id
				 , c.FULLNAME				as primary_constituent_full_name
				 , cr.CONSTITUENTRELATIONSHIPTYPEDIMID	as primary_relationship_type_id
				 , crt.CONSTITUENTRELATIONSHIPTYPE			as primary_relationship_type_desc
				 , cr.RECIPROCALCONSTITUENTDIMID    as secondary_constituent_dim_id
				 , cr.RECIPROCALCONSTITUENTSYSTEMID as secondary_constituent_system_id
				 , r.CONSTITUENTLOOKUPID			as secondary_constituent_lookup_id
				 , r.FULLNAME						as secondary_constituent_full_name
			     , cr.RECIPROCALCONSTITUENTRELATIONSHIPTYPEDIMID as secondary_relationship_type_id
			     , rrt.CONSTITUENTRELATIONSHIPTYPE	as secondary_relationship_type_desc
			     , convert(date,STARTDATE)			as start_date
			     , convert(date,ENDDATE)			as end_date

			  FROM BBCRM_PROD_RPT_BBDW.BBDW.FACT_CONSTITUENTRELATIONSHIP cr
			  left join BBCRM_PROD_RPT_BBDW.BBDW.DIM_CONSTITUENTRELATIONSHIPTYPE crt on crt.CONSTITUENTRELATIONSHIPTYPEDIMID = cr.CONSTITUENTRELATIONSHIPTYPEDIMID
			  left join BBCRM_PROD_RPT_BBDW.BBDW.DIM_CONSTITUENTRELATIONSHIPTYPE rrt on rrt.CONSTITUENTRELATIONSHIPTYPEDIMID = cr.RECIPROCALCONSTITUENTRELATIONSHIPTYPEDIMID
			  left join BBCRM_PROD_RPT_BBDW.BBDW.DIM_CONSTITUENT c on c.constituentdimid = cr.constituentdimid
			  left join BBCRM_PROD_RPT_BBDW.BBDW.DIM_CONSTITUENT r on r.constituentdimid = cr.reciprocalconstituentdimid
			  left join BBCRM_PROD_RPT_BBDW.BBDW.DIM_CONSTITUENT dc on dc.CONSTITUENTSYSTEMID = cr.CONSTITUENTSYSTEMID
			 where crt.CONSTITUENTRELATIONSHIPTYPESYSTEMID = 'C7768B84-4410-4EAF-B227-5564EB48FB80' --2
			   and c.ISACTIVE = 1
			   and r.isactive = 1
			 --  and c.ISDECEASED = 0
			 --  and r.ISDECEASED = 0
			) par on par.secondary_constituent_system_id = cr.CONSTITUENTSYSTEMID  --match up child (secondary) records to students to associate parents (primary)

  where cs.CONSTITUENCYCODESYSTEMID = '4DB8F4FC-BC43-421D-B592-69BEF109B5FC'       --student constituency
    and cr.ISCURRENTCONSTITUENCY = 1    --current student constituency (somewhat redundant)
   --order by fromdate
   ) parent on parent.parent_system_id = b.CONSTITUENTSYSTEMID

	/* call lists */

	/* evaluations no dupes*/
	left join (
	   SELECT max(HOUSEHOLDDIMID) as HOUSEHOLDDIMID
			 ,CONSTITUENTDIMID
			 ,CONSTITUENTSYSTEMID
    --  ,RFML_FYGIVINGCOUNT
    --  ,RFML_YEARSINEXISTENCE
    --  ,RFML_MAGNITUDE
    --  ,RFML_LIFETIME
    --  ,RECENCY_SCORE
    --  ,FREQUENCY_SCORE
    --  ,MAGNITUDE_SCORE
    --  ,LIFETIME_SCORE
    --  ,SCORE_TOTAL
			 ,max(BESTCAPACITYTYPE) as BESTCAPACITYTYPE
			 ,max(BESTCAPACITYTYPEDISPLAY) as BESTCAPACITYTYPEDISPLAY  --'VCU Verified capacity' would be max
			 ,max(BESTCAPACITYTYPERANK) as BESTCAPACITYTYPERANK
			 ,max(BESTCAPACITYVALUE) as BESTCAPACITYVALUE
			 ,max(case	when BESTCAPACITYVALUESORT =14	then 'A. $50,000,000 and above'
						when BESTCAPACITYVALUESORT =13	then 'B. $25,000,000-$49,999,999'
						when BESTCAPACITYVALUESORT =12	then 'C. $10,000,000-$24,999,999'
						when BESTCAPACITYVALUESORT =11	then 'D. $5,000,000-$9,999,999'
						when BESTCAPACITYVALUESORT =10	then 'E. $2,500,000-$4,999,999'
						when BESTCAPACITYVALUESORT =9	then 'F. $1,000,000-$2,499,999'
						when BESTCAPACITYVALUESORT =8	then 'G. $500,000-$999,999'
						when BESTCAPACITYVALUESORT =7	then 'H. $250,000-$499,999'
						when BESTCAPACITYVALUESORT =6	then 'I. $100,000-$249,999'
						when BESTCAPACITYVALUESORT =5	then 'J. $50,000-$99,999'
						when BESTCAPACITYVALUESORT =4	then 'K. $25,000-$49,999'
						when BESTCAPACITYVALUESORT =3	then 'L. $10,000-$24,999'
						when BESTCAPACITYVALUESORT =2	then 'M. $5,000-$9,999'
						when BESTCAPACITYVALUESORT =1	then 'N. Less than $5,000'
						when BESTCAPACITYVALUESORT =0	then 'O. Unrated'
						when BESTCAPACITYVALUESORT =99	then 'O. Unrated'
						when BESTCAPACITYVALUESORT is NULL	then 'O. Unrated'
						when BESTCAPACITYVALUESORT =98	then 'Z. Unable to rate'
						else 'Data Error' end) as BESTCAPACITYVALUESORTED
			 ,max(case	when BESTCAPACITYVALUESORT =14	then '$50M+'
						when BESTCAPACITYVALUESORT =13	then '$25M-$50M'
						when BESTCAPACITYVALUESORT =12	then '$10M-$25M'
						when BESTCAPACITYVALUESORT =11	then '$5M-$10M'
						when BESTCAPACITYVALUESORT =10	then '$2.5M-$5M'
						when BESTCAPACITYVALUESORT =9	then '$1M-$2.5M'
						when BESTCAPACITYVALUESORT =8	then '$500k-$1M'
						when BESTCAPACITYVALUESORT =7	then '$250k-$500k'
						when BESTCAPACITYVALUESORT =6	then '$100k-$250k'
						when BESTCAPACITYVALUESORT =5	then '$50k-$100k'
						when BESTCAPACITYVALUESORT =4	then '$25k-$50k'
						when BESTCAPACITYVALUESORT =3	then '$10k-$25k'
						when BESTCAPACITYVALUESORT =2	then '$5k-$10k'
						when BESTCAPACITYVALUESORT =1	then '<$5k'
						when BESTCAPACITYVALUESORT =0	then 'Unrated'
						when BESTCAPACITYVALUESORT =99	then 'O. Unrated'
						when BESTCAPACITYVALUESORT is NULL	then 'Unrated'
						when BESTCAPACITYVALUESORT =98	then 'Unable to rate'
						else 'Data Error' end) as BESTCAPACITYVALUESHORT
			 ,max(case	when BESTCAPACITYVALUESORT =14	then 'A. $50M+'
						when BESTCAPACITYVALUESORT =13	then 'B. $25M-$50M'
						when BESTCAPACITYVALUESORT =12	then 'C. $10M-$25M'
						when BESTCAPACITYVALUESORT =11	then 'D. $5M-$10M'
						when BESTCAPACITYVALUESORT =10	then 'E. $2.5M-$5M'
						when BESTCAPACITYVALUESORT =9	then 'F. $1M-$2.5M'
						when BESTCAPACITYVALUESORT =8	then 'G. $500k-$1M'
						when BESTCAPACITYVALUESORT =7	then 'H. $250k-$500k'
						when BESTCAPACITYVALUESORT =6	then 'I. $100k-$250k'
						when BESTCAPACITYVALUESORT =5	then 'J. $50k-$100k'
						when BESTCAPACITYVALUESORT =4	then 'K. $25k-$50k'
						when BESTCAPACITYVALUESORT =3	then 'L. $10k-$25k'
						when BESTCAPACITYVALUESORT =2	then 'M. $5k-$10k'
						when BESTCAPACITYVALUESORT =1	then 'N. <$5k'
						when BESTCAPACITYVALUESORT =0	then 'O. Unrated'
						when BESTCAPACITYVALUESORT =99	then 'O. Unrated'
						when BESTCAPACITYVALUESORT is NULL	then 'O. Unrated'
						when BESTCAPACITYVALUESORT =98	then 'Z. Unable to rate'
						else 'Data Error' end) as BESTCAPACITYVALUESHORTSORTED
			 ,max(BESTCAPACITYVALUESORT) as BESTCAPACITYVALUESORT
			 ,max(RESEARCHSTATUSCONFIRMED) as RESEARCHSTATUSCONFIRMED
			 ,max(RESEARCHSTATUSCONFIRMEDBY) as RESEARCHSTATUSCONFIRMEDBY
			 ,max(case when len(RESEARCHSTATUSCONFIRMEDBY) > 15 then substring(RESEARCHSTATUSCONFIRMEDBY,16,charindex(' on',RESEARCHSTATUSCONFIRMEDBY)-16)
			           else NULL end) as RESEARCHSTATUSCONFIRMER
			 ,max(convert(date,case when len(RESEARCHSTATUSCONFIRMEDBY) > 15 then substring(RESEARCHSTATUSCONFIRMEDBY,charindex(' on',RESEARCHSTATUSCONFIRMEDBY)+4,10)
			           else NULL end)) as RESEARCHSTATUSCONFIRMERDATE
    --  ,BESTCAPACITYUPDATEDBY
			 ,max(convert(date,BESTCAPACITYDATECHANGED)) as BESTCAPACITYDATECHANGED
    --  ,BESTCAPACITYDATEADDED
	--  ,QUADRANT
		,max(case	when BESTCAPACITYVALUESORT =14	then 50000000
			when BESTCAPACITYVALUESORT =13	then 25000000
			when BESTCAPACITYVALUESORT =12	then 10000000
			when BESTCAPACITYVALUESORT =11	then 5000000
			when BESTCAPACITYVALUESORT =10	then 2500000
			when BESTCAPACITYVALUESORT =9	then 1000000
			when BESTCAPACITYVALUESORT =8	then 500000
			when BESTCAPACITYVALUESORT =7	then 250000
			when BESTCAPACITYVALUESORT =6	then 100000
			when BESTCAPACITYVALUESORT =5	then 50000
			when BESTCAPACITYVALUESORT =4	then 25000
			when BESTCAPACITYVALUESORT =3	then 10000
			when BESTCAPACITYVALUESORT =2	then 5000
			when BESTCAPACITYVALUESORT =1	then 0
			when BESTCAPACITYVALUESORT =0	then NULL
			when BESTCAPACITYVALUESORT =99	then NULL
			when BESTCAPACITYVALUESORT is NULL	then NULL
			when BESTCAPACITYVALUESORT =98	then NULL
			else -1 end) as BESTCAPACITYVALUEMIN
		,max(case	when BESTCAPACITYVALUESORT =14	then 100000000
			when BESTCAPACITYVALUESORT =13	then 50000000
			when BESTCAPACITYVALUESORT =12	then 25000000
			when BESTCAPACITYVALUESORT =11	then 10000000
			when BESTCAPACITYVALUESORT =10	then 5000000
			when BESTCAPACITYVALUESORT =9	then 2500000
			when BESTCAPACITYVALUESORT =8	then 1000000
			when BESTCAPACITYVALUESORT =7	then 500000
			when BESTCAPACITYVALUESORT =6	then 250000
			when BESTCAPACITYVALUESORT =5	then 100000
			when BESTCAPACITYVALUESORT =4	then 50000
			when BESTCAPACITYVALUESORT =3	then 25000
			when BESTCAPACITYVALUESORT =2	then 10000
			when BESTCAPACITYVALUESORT =1	then 5000
			when BESTCAPACITYVALUESORT =0	then NULL
			when BESTCAPACITYVALUESORT =99	then NULL
			when BESTCAPACITYVALUESORT is NULL	then NULL
			when BESTCAPACITYVALUESORT =98	then NULL
			else -1 end) as BESTCAPACITYVALUEMAX
		,max(case	when BESTCAPACITYVALUESORT =14	then 75000000
			when BESTCAPACITYVALUESORT =13	then 37500000
			when BESTCAPACITYVALUESORT =12	then 17500000
			when BESTCAPACITYVALUESORT =11	then 7500000
			when BESTCAPACITYVALUESORT =10	then 3750000
			when BESTCAPACITYVALUESORT =9	then 1750000
			when BESTCAPACITYVALUESORT =8	then 750000
			when BESTCAPACITYVALUESORT =7	then 375000
			when BESTCAPACITYVALUESORT =6	then 175000
			when BESTCAPACITYVALUESORT =5	then 75000
			when BESTCAPACITYVALUESORT =4	then 37500
			when BESTCAPACITYVALUESORT =3	then 17500
			when BESTCAPACITYVALUESORT =2	then 7500
			when BESTCAPACITYVALUESORT =1	then 2500
			when BESTCAPACITYVALUESORT =0	then NULL
			when BESTCAPACITYVALUESORT =99	then NULL
			when BESTCAPACITYVALUESORT is NULL	then NULL
			when BESTCAPACITYVALUESORT =98	then NULL
			else -1 end) as BESTCAPACITYVALUEMID

  FROM BBCRM_PROD_RPT_BBDW.BBDW.VCU_V_QUERY_RFMLSCORE
  GROUP BY CONSTITUENTDIMID
		 , CONSTITUENTSYSTEMID

  ) eval on eval.CONSTITUENTSYSTEMID = b.CONSTITUENTSYSTEMID


  /* Prospect Development - Managed - No dupes*/
   left join (
		SELECT p.CONSTITUENTDIMID		as constituent_id
			 , p.CONSTITUENTSYSTEMID	as constituent_system_id
			 , FUNDRAISERDIMID
			 , goi.officer_name
			 , goi.unit_id
			 , sui.unit_name
			 , goi.date_from
			 , goi.date_to
   --   ,ISRESEARCHSTATUSCONFIRMED
			 , PROSPECTSTATUS			as prospect_status
			 , PROSPECTMANAGERSTARTDATE
			 , PROSPECTMANAGERENDDATE
			 , case when fundraiserdimid > 0 then 1 else 0 end as flag_managed_currently  --prospect managed only

   /*   ,PROSPECTMANAGERSTARTDATEDIMID
      ,PROSPECTMANAGERENDDATEDIMID
      ,ISINCLUDED
      ,ETLCONTROLID
      ,SOURCEDIMID
      ,FUNDRAISERSYSTEMID
      ,PROSPECTDIMID
      ,PROSPECTSYSTEMID
	  */
  FROM BBCRM_PROD_RPT_BBDW.BBDW.DIM_PROSPECT p
  left join DARanalytics.ref.gift_officer_info goi on goi.officer_system_id = p.FUNDRAISERSYSTEMID
												  and goi.position_order_desc = 1    --latest position
                                                  --and PROSPECTMANAGERSTARTDATE between goi.date_from and date_to  --seems many assignments are outside of the start and stop dates
												  --need to investigate fundraiser 655316 Sarah Noble
  left join DARanalytics.ref.school_unit_info sui on sui.unit_id = goi.unit_id                                             
  where getdate() between coalesce(p.PROSPECTMANAGERSTARTDATE,'1/1/1980') and coalesce(p.PROSPECTMANAGERENDDATE, '12/31/2099')
  --  and fundraiserdimid > 0
--	and p.FUNDRAISERDIMID not in ('607205')    --ignore those assigned to Prospect Development
  --  and PROSPECTMANAGERENDDATE is not null
  --group by CONSTITUENTSYSTEMID --seems like there can only be one person assigned in this table per constituent -might need to make this more bulletproof
  --order by unit_id, fundraiserdimid
		) pd on pd.constituent_system_id = b.CONSTITUENTSYSTEMID

 /* Prospect Development - Managed Spouse - No dupes*/
   left join (
		SELECT p.CONSTITUENTDIMID		as constituent_id
			 , p.CONSTITUENTSYSTEMID	as constituent_system_id
			 , FUNDRAISERDIMID
			 , goi.officer_name
			 , goi.unit_id
			 , sui.unit_name
			 , goi.date_from
			 , goi.date_to
			 , PROSPECTSTATUS			as prospect_status
			 , PROSPECTMANAGERSTARTDATE
			 , PROSPECTMANAGERENDDATE
			 , case when fundraiserdimid > 0 then 1 else 0 end as flag_managed_currently  --prospect managed only

  FROM BBCRM_PROD_RPT_BBDW.BBDW.DIM_PROSPECT p
  left join DARanalytics.ref.gift_officer_info goi on goi.officer_system_id = p.FUNDRAISERSYSTEMID
												  and goi.position_order_desc = 1    --latest position
  left join DARanalytics.ref.school_unit_info sui on sui.unit_id = goi.unit_id                                             
  where getdate() between coalesce(p.PROSPECTMANAGERSTARTDATE,'1/1/1980') and coalesce(p.PROSPECTMANAGERENDDATE, '12/31/2099')
		) pd_spouse on pd_spouse.constituent_system_id = b_sp.CONSTITUENTSYSTEMID

 /* Deprecated --Household Prospects*/
 --  left join (
	--	SELECT p.CONSTITUENTDIMID		as constituent_dim_id
	--		 , p.CONSTITUENTSYSTEMID	as constituent_system_id
	--		 , m.CONSTITUENTDIMID_SUMMARY  as household_id2
	--		 , c.CONSTITUENTLOOKUPID	as lookup_id
	--		-- , c.isactive
	--		 , c.isdeceased
	--		 , m.CONSTITUENTDIMID_SPOUSE
	--		 , p.PROSPECTSTATUS			as prospect_status
	--		 , p2.PROSPECTSTATUS		as spouse_prospect_status
	--		 , c2.ISACTIVE				as spouse_isactive
	--		 , c2.ISDECEASED			as spouse_isdeceased
	--		 , case when (p.PROSPECTSTATUS in ('Assigned', 'Spouse is assigned') or 
	--					  isnull(p2.PROSPECTSTATUS,p.PROSPECTSTATUS) in ('Assigned', 'Spouse is assigned'))	then 'Assigned'
					
	--				when p2.PROSPECTSTATUS is null then p.PROSPECTSTATUS
					
	--				when (p.PROSPECTSTATUS = 'Permanent Stewardship' or
	--					 (p2.PROSPECTSTATUS = 'Permanent Stewardship' and c2.ISDECEASED = 0 and c2.ISACTIVE=1)
	--					 )	then 'Permanent Stewardship'
	--				when (p.PROSPECTSTATUS = 'Referred' or 
	--					 (p2.PROSPECTSTATUS = 'Referred'  and c2.ISDECEASED = 0 and c2.ISACTIVE=1))	then 'Referred'
						 
	--				when ((p.PROSPECTSTATUS = 'Not a prospect' and c.ISDECEASED = 0 and c.ISACTIVE=1) or  
	--					 --((p.PROSPECTSTATUS = 'Not a prospect') or   --depends if we care about the deceased status of the primary
	--					  (p2.PROSPECTSTATUS = 'Not a prospect' and c2.ISDECEASED = 0 and c2.ISACTIVE=1) or
	--					  (p.PROSPECTSTATUS = 'Not a prospect' and p2.PROSPECTSTATUS = 'Not a prospect')
	--					 ) then 'Not a prospect'
					
	--				when (p.PROSPECTSTATUS = 'Unassigned' or 
	--					 (p2.PROSPECTSTATUS = 'Unassigned' and c2.ISDECEASED = 0 and c2.ISACTIVE=1))	then 'Unassigned'
	--				else 'BadLogic'
	--		   end as prospect_status_hh

	--	 FROM BBCRM_PROD_RPT_BBDW.BBDW.DIM_PROSPECT p
	--left join BBCRM_PROD_RPT_BBDW.BBDW.DIM_CONSTITUENT c on c.CONSTITUENTSYSTEMID = p.CONSTITUENTSYSTEMID
	--left join BBCRM_PROD_RPT_BBDW.BBDW.VCU_FACT_CONSTITUENTMARRIAGE m on m.CONSTITUENTDIMID = p.CONSTITUENTDIMID
	--left join BBCRM_PROD_RPT_BBDW.BBDW.DIM_PROSPECT p2 on p2.constituentdimid = c.SPOUSECONSTITUENTDIMID
	--												  and c.SPOUSECONSTITUENTDIMID <> 0
	--left join BBCRM_PROD_RPT_BBDW.BBDW.DIM_CONSTITUENT c2 on c2.CONSTITUENTSYSTEMID = p2.CONSTITUENTSYSTEMID
	--left join BBCRM_PROD_RPT_BBDW.BBDW.VCU_FACT_CONSTITUENTMARRIAGE m2 on m2.CONSTITUENTDIMID_SPOUSE = p2.CONSTITUENTDIMID

	--	WHERE p.CONSTITUENTDIMID <> 0  --get rid of the default record with dim ID = 0
	--	  and c.isactive = 1			--get rid of inactive prospect records
	--	  and m.CONSTITUENTDIMID_SUMMARY is not null --get rid of 2 records that are household records in the dim_prospect table for some reason
 
 -- --ORDER BY  prospect_status_hh, c.isdeceased desc, p.prospectstatus, p2.prospectstatus

	--	) pd_hh on pd_hh.constituent_system_id = b.CONSTITUENTSYSTEMID



	/*  PROSPECT TEAM  (n=8k t=1sec) */
	left join (
SELECT PROSPECTSYSTEMID as constituent_system_id
     , max(case when FUNDRAISERROLECODE = 'Team Member' then 1 else 0 end) as flag_managed_team_current  --people can be both team member and team member former so there is that
	 , max(case when FUNDRAISERROLECODE like '%stewardship%' then 1 else 0 end) as flag_managed_stewardship_current
	 , max(case when FUNDRAISERROLECODE like '%discovery%' then 1 else 0 end) as flag_managed_discovery_current
	 , max(case when FUNDRAISERROLECODE like '%foundation%' then 1 else 0 end) as flag_managed_foundation_current
	 , max(case when FUNDRAISERROLECODE like '%engagement%' then 1 else 0 end) as flag_managed_engagement_current
	 , max(case when FUNDRAISERROLECODE like '%alumni%' then 1 else 0 end) as flag_managed_alumni_relations_current
     , sum(case when FUNDRAISERROLECODE = 'Team Member' then 1 else 0 end
		+ case when FUNDRAISERROLECODE like '%stewardship%' then 1 else 0 end 
		+ case when FUNDRAISERROLECODE like '%discovery%' then 1 else 0 end
		+ case when FUNDRAISERROLECODE like '%foundation%' then 1 else 0 end
		+ case when FUNDRAISERROLECODE like '%engagement%' then 1 else 0 end
		+ case when FUNDRAISERROLECODE like '%alumni%' then 1 else 0 end) as pm_num_managed_types
  
  FROM (
		SELECT PROSPECTSYSTEMID
			 , FUNDRAISERROLECODE
			 , case when NULLIF(MAX(COALESCE(EndDate,'9999-12-31')),'9999-12-31') is null then 1 else 0 end as prospectteam_current
		--   , max(STARTDATE) as min_startdate
		--   , max(ENDDATE) as max_enddate

		  FROM BBCRM_PROD_RPT_BBDW.BBDW.VCU_DIM_PROSPECTTEAM
		 WHERE FUNDRAISERROLECODE <> 'Team Member - Former'   --Gets rid of situations where someone is both team member and team member - former
	  GROUP BY prospectsystemid, fundraiserrolecode
   -- ORDER BY fundraiserrolecode --prospectteam_current desc
	  ) pt

  where pt.prospectteam_current = 1
  group by prospectsystemid
 -- order by pm_num_managed_types desc
		) pt on pt.constituent_system_id = b.CONSTITUENTSYSTEMID


/* Ever Managed (n=39k t=1sec) */
 left join (
		 /*ever team member, discovery manager, foundation manager, stewardship manager*/
		select PROSPECTDIMID as CONSTITUENTDIMID
		  from BBCRM_PROD_RPT_BBDW.BBDW.VCU_DIM_PROSPECTTEAM
		 where FUNDRAISERROLECODE not in  ('Alumni Relations Staff','Engagement Manager')
		 group by prospectdimid

		union

		/*PM in the past*/
		select CONSTITUENTDIMID 
		  from BBCRM_PROD_RPT_BBDW.BBDW.VCU_FACT_PROSPECTMANAGERHISTORY
		 group by CONSTITUENTDIMID

		union

		/*current PM*/
		select CONSTITUENTDIMID
		  from BBCRM_PROD_RPT_BBDW.BBDW.DIM_PROSPECT p
		 where p.fundraiserdimid > 0
		   and getdate() between coalesce(p.PROSPECTMANAGERSTARTDATE,'1/1/1980') and coalesce(p.PROSPECTMANAGERENDDATE, '12/31/2099')
		 group by CONSTITUENTDIMID
		 ) em on em.CONSTITUENTDIMID = b.CONSTITUENTDIMID

	/* currently managed prospects and their officers 	 (n=11.5k t=1sec) */
  left join (  
		  select constituent_system_id
			   , string_agg(concat(pm_officer_role,'' ), ', ') within group (order by pm_management_team_order, officer_name) as pm_management_team
			   , string_agg(concat(pm_officer_role_lookup_id,'' ), ', ') within group (order by pm_management_team_order, officer_name) as pm_management_team_lookup_ids
			   , string_agg(concat(pm_officer_role_system_id,'' ), ', ') within group (order by pm_management_team_order, officer_name) as pm_management_team_system_ids
			   , string_agg(concat(pm_officer_role_unit,'' ), ', ') within group (order by pm_management_team_order, officer_name) as pm_management_team_unit_names

			   , max(case when pm_team_lead_rownumber = 1 then pm_officer_role else NULL end) as pm_lead_officer_with_role
			   , max(case when pm_team_lead_rownumber = 1 then officer_name else NULL end) as pm_lead_officer
			   , max(case when pm_team_lead_rownumber = 1 then officer_latest_unit_name_campaign else NULL end) as pm_lead_officer_unit_campaign
			   , max(case when pm_team_lead_rownumber = 1 then officer_latest_unit_name_short else NULL end) as pm_lead_officer_unit_short
			   , max(case when pm_team_lead_rownumber = 1 then officer_latest_avp else NULL end) as pm_lead_officer_avp

			   , max(case when flag_ofcr_current_prospect_manager =1 then officer_name else NULL end)	 as pm_current_prospect_manager
			   , max(case when flag_ofcr_current_stewardship_manager =1 then officer_name else NULL end) as pm_current_stewardship_manager
			   , max(case when flag_ofcr_current_team_member =1 then officer_name else NULL end)		 as pm_current_team_member
			   , max(case when flag_ofcr_current_discovery_manager =1 then officer_name else NULL end)   as pm_current_discovery_manager
			   , max(case when flag_ofcr_current_foundation_manager =1 then officer_name else NULL end)  as pm_current_foundation_manager
			   , max(case when flag_ofcr_current_development_staff =1 then officer_name else NULL end)   as pm_current_development_staff

			   , max(case when flag_ofcr_current_prospect_manager =1 then officer_system_id else NULL end)	as pm_current_PM_system_id
			   , max(case when flag_ofcr_current_prospect_manager =1 then officer_lookup_id else NULL end)	as pm_current_PM_lookup_id
			   , max(case when flag_ofcr_current_prospect_manager =1 then officer_latest_unit_name_campaign else NULL end)	as pm_current_PM_latest_unit_name
			   , max(case when flag_ofcr_current_prospect_manager =1 then officer_latest_unit_name_short else NULL end)	as pm_current_PM_latest_unit_name_short
			   , max(case when flag_ofcr_current_prospect_manager =1 then officer_latest_unit_name_campaign else NULL end)	as pm_current_PM_latest_unit_name_campaign
			   , max(case when flag_ofcr_current_prospect_manager =1 then officer_latest_avp else NULL end)	as pm_current_PM_latest_avp
			   , max(flag_currently_managed_by_vp) as flag_currently_managed_by_vp
			   , max(flag_is_principal_gift_prospect) as flag_is_principal_gift_prospect

			from (
					 SELECT
						    constituent_system_id
						  , case when flag_ofcr_current_prospect_manager = 1 then officer_name + ' (PM)' 
								 when flag_ofcr_current_team_member = 1 then officer_name + ' (TM)' 
								 when flag_ofcr_current_stewardship_manager = 1 then officer_name + ' (SM)' 
								 when flag_ofcr_current_discovery_manager = 1 then officer_name + ' (DM)'
								 when flag_ofcr_current_foundation_manager = 1 then officer_name + ' (FM)'
								 when flag_ofcr_current_development_staff = 1 then officer_name + ' (DS)'
								 else '' end
						    as pm_officer_role

						  , case when flag_ofcr_current_prospect_manager = 1 then convert(char(36),officer_system_id) + ' (PM)' 
								 when flag_ofcr_current_team_member = 1 then convert(char(36),officer_system_id) + ' (TM)' 
								 when flag_ofcr_current_stewardship_manager = 1 then convert(char(36),officer_system_id) + ' (SM)' 
								 when flag_ofcr_current_discovery_manager = 1 then convert(char(36),officer_system_id) + ' (DM)'
								 when flag_ofcr_current_foundation_manager = 1 then convert(char(36),officer_system_id) + ' (FM)'
								 when flag_ofcr_current_development_staff = 1 then convert(char(36),officer_system_id) + ' (DS)'
								 else '' end
						    as pm_officer_role_system_id

						  , case when flag_ofcr_current_prospect_manager = 1 then officer_lookup_id + ' (PM)' 
								 when flag_ofcr_current_team_member = 1 then officer_lookup_id + ' (TM)' 
								 when flag_ofcr_current_stewardship_manager = 1 then officer_lookup_id + ' (SM)' 
								 when flag_ofcr_current_discovery_manager = 1 then officer_lookup_id + ' (DM)'
								 when flag_ofcr_current_foundation_manager = 1 then officer_lookup_id + ' (FM)'
								 when flag_ofcr_current_development_staff = 1 then officer_lookup_id + ' (DS)'
								 else '' end
						    as pm_officer_role_lookup_id

						  , case when flag_ofcr_current_prospect_manager = 1 then officer_latest_unit_name + ' (PM)' 
								 when flag_ofcr_current_team_member = 1 then officer_latest_unit_name + ' (TM)' 
								 when flag_ofcr_current_stewardship_manager = 1 then officer_latest_unit_name + ' (SM)' 
								 when flag_ofcr_current_discovery_manager = 1 then officer_latest_unit_name + ' (DM)'
								 when flag_ofcr_current_foundation_manager = 1 then officer_latest_unit_name + ' (FM)'
								 when flag_ofcr_current_development_staff = 1 then officer_latest_unit_name + ' (DS)'
								 else '' end
						    as pm_officer_role_unit

						  , case when flag_ofcr_current_prospect_manager = 1 then 1
								 when flag_ofcr_current_team_member = 1 then 2
								 when flag_ofcr_current_stewardship_manager = 1 then 3
								 when flag_ofcr_current_discovery_manager = 1 then 4
								 when flag_ofcr_current_foundation_manager = 1 then 5
								 when flag_ofcr_current_development_staff = 1 then 6
								 else 0 end
						    as pm_management_team_order
						  , officer_name
						  , officer_lookup_id
						  , officer_system_id
						  , officer_latest_unit_name
						  , officer_latest_unit_name_short
						  , officer_latest_unit_name_campaign
						  , officer_latest_avp
						  , flag_ofcr_current_prospect_manager
						  , flag_ofcr_current_team_member 
						  , flag_ofcr_current_stewardship_manager
						  , flag_ofcr_current_discovery_manager
						  , flag_ofcr_current_foundation_manager
						  , flag_ofcr_current_development_staff
						  , flag_currently_managed_by_vp
						  , flag_is_principal_gift_prospect
						  , row_number() over(partition by constituent_system_id 
												  order by case when flag_ofcr_current_prospect_manager = 1 then 1
																when flag_ofcr_current_team_member = 1 then 2
																when flag_ofcr_current_stewardship_manager = 1 then 3
																when flag_ofcr_current_discovery_manager = 1 then 4
																when flag_ofcr_current_foundation_manager = 1 then 5
																when flag_ofcr_current_development_staff = 1 then 6				--should this be here or left out?
																else 0 end
														 , pm_ofcr_days_managed desc	 
											 ) 
								 as pm_team_lead_rownumber
					   FROM DARanalytics.datamart.constituent_officer_level
					  WHERE flag_ofcr_currently_managed = 1
						 or flag_ofcr_current_development_staff = 1		--not technically managed but we want them in the team list
					 -- group by constituent_system_id, constituent_lookup_id, constituent_dim_id, bio_lastcommafirstname
					 --  order by constituent_lookup_id
					 ) t
		   group by constituent_system_id
			) team on team.constituent_system_id = b.CONSTITUENTSYSTEMID

	/*Unit Connectedness All (n=472k t=10sec)*/
	   left join (
			select constituent_system_id
			   , string_agg(concat(t.unit_name,' (',t.pm_unit_connectedness_letter,')',''), ', ') within group (order by row_num) as unit_connectedness_list_all
			   , string_agg(concat(t.unit_name_short,' (',t.pm_unit_connectedness_letter,')',''), ', ') within group (order by row_num) as unit_connectedness_list_short_all
			   , count(*) as unit_connectedness_num_all
			from (select distinct constituent_system_id
					   , unit_name
					   , unit_name_short
					  -- , unit_connectedness_list
					   , pm_unit_connectedness_desc
					   , isnull(left(min(pm_unit_connectedness_desc),1),'X') as pm_unit_connectedness_letter
					   , row_number() over (partition by constituent_system_id order by isnull(left(min(pm_unit_connectedness_desc),1),'X'), max(pm_unit_connectedness_score) desc, min(unit_id)) as row_num
			        from DARanalytics.datamart.constituent_unit_level
				   where pm_unit_connectedness_desc is not null
					--  and flag_unit_philanthropic = 1		--get rid of units that we arent really interested in
					--  and flag_unit_pgi_not_unit_prospect = 0		--remove if there is a NAP unit PGI
				    group by constituent_system_id, unit_name, unit_name_short, pm_unit_connectedness_desc
				  ) t
		   group by constituent_system_id
			) units_all on units_all.constituent_system_id = b.CONSTITUENTSYSTEMID

	/*Unit Connectedness (n=467k t=12sec)*/
	   left join (
			select constituent_system_id
			   , string_agg(concat(t.unit_name,' (',t.pm_unit_connectedness_letter,')',''), ', ') within group (order by row_num) as unit_connectedness_list
			   , string_agg(concat(t.unit_name_short,' (',t.pm_unit_connectedness_letter,')',''), ', ') within group (order by row_num) as unit_connectedness_list_short
			   , count(*) as unit_connectedness_num
			from (select distinct constituent_system_id
					   , unit_name
					   , unit_name_short
					  -- , unit_connectedness_list
					   , pm_unit_connectedness_desc
					   , isnull(left(min(pm_unit_connectedness_desc),1),'X') as pm_unit_connectedness_letter
					   , row_number() over (partition by constituent_system_id order by isnull(left(min(pm_unit_connectedness_desc),1),'X'), max(pm_unit_connectedness_score) desc, min(unit_id)) as row_num
			        from DARanalytics.datamart.constituent_unit_level
					where flag_unit_philanthropic = 1		--get rid of units that we arent really interested in
					  and pm_unit_connectedness_desc is not null
					  and flag_unit_pgi_not_unit_prospect = 0		--remove if there is a NAP unit PGI
				    group by constituent_system_id, unit_name, unit_name_short, pm_unit_connectedness_desc
				  ) t
		   group by constituent_system_id
			) units on units.constituent_system_id = b.CONSTITUENTSYSTEMID

	/* Unit Other (n=467k t=10sec)*/
	   left join (
		  select t.constituent_system_id
			--   , string_agg(concat(unit_name,'' ), ', ') within group (order by unit_name) as unit_connectedness_list
			   , string_agg(concat(t.unit_name_other,' (',t.pm_unit_connectedness_letter,')',''), ', ') within group (order by row_num) as unit_connectedness_list_other
			   , count(*) as unit_connectedness_num_other  --treating Other as 1 unit
			--   , string_agg(concat(unit_name_short,'' ), ', ') within group (order by unit_name_short) as unit_connectedness_list_short
			--   , string_agg(concat(unit_name_short_other,'' ), ', ') within group (order by unit_name_short_other) as unit_connectedness_list_short_other
			--   , max(t.unit_connectedness_list) as unit_connectedness_list_old
			from (select distinct constituent_system_id
					   , unit_name_other
					  -- , unit_connectedness_list
					   , pm_unit_connectedness_desc
					   , isnull(left(min(pm_unit_connectedness_desc),1),'X') as pm_unit_connectedness_letter
					   , row_number() over (partition by constituent_system_id order by isnull(left(min(pm_unit_connectedness_desc),1),'X'), max(pm_unit_connectedness_score) desc, min(unit_id)) as row_num
			        from DARanalytics.datamart.constituent_unit_level
					where flag_unit_philanthropic = 1		--get rid of units that we arent really interested in
					  and pm_unit_connectedness_desc is not null
					  and flag_unit_pgi_not_unit_prospect = 0		--remove if there is a NAP unit PGI
				    group by constituent_system_id, unit_name_other, pm_unit_connectedness_desc
				  ) t
		   group by constituent_system_id
			) units_other on units_other.constituent_system_id = b.CONSTITUENTSYSTEMID
	
	/* Unit LTG (n=264k t=5sec)*/
	   left join (
		  select constituent_system_id
			   , string_agg(concat(t.unit_name_short,' (',format(t.gvg_unit_recog_raised_life_hh,'C0','en-US'),')',''), ', ') within group (order by row_num_gvg) as unit_connectedness_list_ltg_short_all
			   , count(*) as unit_connectedness_donated_num_all
			from (select distinct constituent_system_id
					   , unit_name
					   , unit_name_short
					   , gvg_unit_recog_raised_life_hh
			           , row_number() over (partition by constituent_system_id order by isnull(max(gvg_unit_recog_raised_life_hh),0) desc, max(pm_unit_connectedness_score) desc, min(unit_id)) as row_num_gvg
				    from DARanalytics.datamart.constituent_unit_level
				   where pm_unit_connectedness_desc is not null
					 and gvg_unit_recog_raised_life_hh>0
					--  and flag_unit_philanthropic = 1		--get rid of units that we arent really interested in
				   group by constituent_system_id, unit_name, unit_name_short, gvg_unit_recog_raised_life_hh
				  ) t
		   group by constituent_system_id
			) units_ltg on units_ltg.constituent_system_id = b.CONSTITUENTSYSTEMID

	/* Service Areas (n=193k t=4sec)*/
	   left join (
			select constituent_system_id
			   , string_agg(concat(t.fud_service_area,' (',t.pm_servicearea_connectedness_letter,')',''), ', ') within group (order by row_num) as servicearea_connectedness_list
			   , count(*) as servicearea_connectedness_num
			from (select distinct constituent_system_id
					   , fud_service_area
					   , pm_servicearea_connectedness_desc
					   , isnull(left(min(pm_servicearea_connectedness_desc),1),'X') as pm_servicearea_connectedness_letter
					   , row_number() over (partition by constituent_system_id order by isnull(left(min(pm_servicearea_connectedness_desc),1),'X'), max(pm_servicearea_connectedness_score) desc, min(fud_service_area_id)) as row_num
			        from DARanalytics.datamart.constituent_servicearea_level
					where pm_servicearea_connectedness_desc is not null
					 -- and flag_service_area_pgi_not_servicearea_prospect = 0		--remove if there is a NAP servicearea PGI
				    group by constituent_system_id, fud_service_area, pm_servicearea_connectedness_desc
				  ) t
		   group by constituent_system_id
			) servicearea on servicearea.constituent_system_id = b.CONSTITUENTSYSTEMID	

	/* unit LAGO-DEO (n=449k t=10sec) */
	   left join (
			select constituent_system_id
			   , string_agg(concat(t.unit_name,' (',t.pm_unit_connectedness_letter,')',''), ', ') within group (order by row_num) as unit_connectedness_list
			   , string_agg(concat(t.unit_name_short,' (',t.pm_unit_connectedness_letter,')',''), ', ') within group (order by row_num) as unit_connectedness_list_short
			   , count(*) as unit_connectedness_num
			from (select distinct constituent_system_id
					   , unit_name
					   , unit_name_short
					  -- , unit_connectedness_list
					   , pm_unit_connectedness_desc
					   , isnull(left(min(pm_unit_connectedness_desc),1),'X') as pm_unit_connectedness_letter
					   , row_number() over (partition by constituent_system_id order by isnull(left(min(pm_unit_connectedness_desc),1),'X'), max(pm_unit_connectedness_score) desc, min(unit_system_id)) as row_num
			        from DARanalytics.datamart.constituent_unit_servicearea_unioned 
					where flag_unit_lagodeo = 1		--get rid of units that we arent really interested in
					  and pm_unit_connectedness_desc is not null
					  and flag_unit_pgi_not_unit_prospect = 0		--remove if there is a NAP unit PGI
				    group by constituent_system_id, unit_name, unit_name_short, pm_unit_connectedness_desc
				  ) t
		   group by constituent_system_id
			) unit_lagodeo on unit_lagodeo.constituent_system_id = b.CONSTITUENTSYSTEMID


  /*  Attribute Model Scores  -No Dupes - This needs updating once we figure out how to handle the new 'BWF' ARR data  (n=757k t=19sec)*/
  left join (
select 
       CONSTITUENTSYSTEMID
      ,CONSTITUENTDIMID
      ,max(case when attributesystemid = 'BACD33C2-7AEF-4E84-A5B6-7F5C2E7F612A' then m.ATTRIBUTEVALUE else null end)  as bwf_connectedness --a.AttributeName = 'BWF Connection Score Range'
      ,max(case when attributesystemid = '0BEC7823-0238-4E22-8120-2939FD250575' then m.ATTRIBUTEVALUE else null end)  as bwf_major_gift_rating --a.AttributeName = 'BWF Major Gift Rating'
      ,max(case when attributesystemid = 'AF9D5798-D2D1-4E21-B657-984F3D4D2B5B' then m.ATTRIBUTEVALUE else null end)  as bwf_planned_gift_rating --a.AttributeName = 'BWF Planned Gift Rating'
      ,max(case when attributesystemid = '77365FF0-5A34-4FD5-A2CD-43E04956BCB2' then m.ATTRIBUTEVALUE else null end)  as vcu_planned_giving_score --a.AttributeName = 'VCU Internal Planned Giving Score'
	  ,max(case when attributesystemid = '2DB8C33E-CF69-479E-9952-B310D3CA4D86' then m.ATTRIBUTEVALUE else null end)  as bwf_acquisition_rating --a.AttributeName = 'BWF Acquisition Rating'
	  ,max(case when attributesystemid = '6455E14D-16BD-419A-9788-25A35B52B025'	then m.ATTRIBUTEVALUE else null end)  as bwf_reactivation_rating-- 'BWF Reactivation Rating'
	  ,max(case when attributesystemid = 'C4868778-98C2-405E-85D8-2DDF3E210317'	then m.ATTRIBUTEVALUE else null end)  as bwf_retention_rating -- 'BWF Retention Rating'
--    ,max(case when attributesystemid = 'FD3E8706-10DE-4CF5-B6A4-8A43912222FD' then m.ATTRIBUTEVALUE else null end)  as planned_gift_rank  --a.AttributeName = 'Planned Giving Rank'

 
 /*   
	   MODELINGANDPROPENSITYATTRIBUTEFACTID
      ,MODELINGANDPROPENSITYATTRIBUTESYSTEMID
      ,ATTRIBUTEDIMID
      ,ATTRIBUTESYSTEMID
      ,ATTRIBUTEVALUESYSTEMID
      ,ATTRIBUTESTARTDATE
      ,ATTRIBUTEENDDATE
	  ,ATTRIBUTEISCURRENT
      ,ISINCLUDED
      ,SOURCEDIMID
      ,ETLCONTROLID

      ,ATTRIBUTECOMMENT
      ,VALUEDATE
      ,VALUEDATEDIMID
      ,VALUEYESNO
      ,VALUECURRENCY
      ,VALUECONSTITUENTSYSTEMID
      ,VALUECONSTITUENTDIMID
      ,VALUEHOURMINUTE
      ,VALUEFUZZYDATE
      ,VALUENUMBER
	  */

from BBCRM_PROD_RPT_BBDW.BBDW.FACT_MODELINGANDPROPENSITYATTRIBUTE m
left join BBCRM_PROD_RPT_BBDW.BBDW.DIM_ATTRIBUTE a on a.ATTRIBUTEDIMID = m.ATTRIBUTEDIMID
where a.attributetype = 'Model Scores and Ratings'
    and (
			(m.attributesystemid in ( 'BACD33C2-7AEF-4E84-A5B6-7F5C2E7F612A'  --a.AttributeName = 'BWF Connection Score Range'
									, '0BEC7823-0238-4E22-8120-2939FD250575'  --a.AttributeName = 'BWF Major Gift Rating'
									, 'AF9D5798-D2D1-4E21-B657-984F3D4D2B5B'  --a.AttributeName = 'BWF Planned Gift Rating'
							--, '2DB8C33E-CF69-479E-9952-B310D3CA4D86'  --a.AttributeName = 'BWF Acquisition Rating'
							--, '6455E14D-16BD-419A-9788-25A35B52B025'  --a.AttributeName = 'BWF Reactivation Rating'
							--, 'C4868778-98C2-405E-85D8-2DDF3E210317'  --a.AttributeName = 'BWF Retention Rating'
							--, 'FD3E8706-10DE-4CF5-B6A4-8A43912222FD'  --a.AttributeName = 'Planned Giving Rank'       --old I'm told
							--, '77365FF0-5A34-4FD5-A2CD-43E04956BCB2'  --a.AttributeName = 'VCU Internal Planned Giving Score'
							)
			and getdate() between isnull(m.ATTRIBUTESTARTDATE,'1990-01-01') and isnull(m.ATTRIBUTEENDDATE,'2099-12-31')
			and m.ATTRIBUTEISCURRENT = 1
			)
		or ( m.attributesystemid = '77365FF0-5A34-4FD5-A2CD-43E04956BCB2'   --a.AttributeName = 'VCU Internal Planned Giving Score'
		    and isnull(ATTRIBUTEENDDATE,'2099-12-31') = '2023-06-30'		--the last run of Gordons score before switching to the SQL version
		   )
		or ( m.attributesystemid in ( '2DB8C33E-CF69-479E-9952-B310D3CA4D86'	--a.AttributeName = 'BWF Acquisition Rating'
									, '6455E14D-16BD-419A-9788-25A35B52B025'	--a.AttributeName = 'BWF Reactivation Rating'
									, 'C4868778-98C2-405E-85D8-2DDF3E210317'	--a.AttributeName = 'BWF Retention Rating'
									)
			and isnull(ATTRIBUTESTARTDATE,'2099-12-31') = '2026-05-04'			--the latest run of Gordons ARR scores
			and m.ATTRIBUTEISCURRENT = 1
			)
		)
	

group by CONSTITUENTSYSTEMID, CONSTITUENTDIMID
--ORDER BY PLANNED_GIFT_RANK DESC

  ) model on model.CONSTITUENTSYSTEMID = b.CONSTITUENTSYSTEMID

  /* Top Connected Unit - Definitive subquery*/
  left join DARanalytics.datamart.primary_unit_fields puf on puf.constituent_system_id = b.CONSTITUENTSYSTEMID

 /* VCU Top Connected Unit - Individual  (n=467k t=10sec) - Should be obsoleted by PUF above*/
 left join (
 select constituent_system_id
	 , pm_unit_connectedness_score		as pm_top_unit_connectedness_score
     , pm_unit_connectedness_desc		as pm_top_unit_connectedness_desc
     , unit_name						as pm_top_unit_name
	 , unit_id							as pm_top_unit_id
	 , avp_officer_manager				as pm_top_unit_avp_officer_manager
  from (

		SELECT constituent_system_id
			 , ROW_NUMBER() OVER(PARTITION BY constituent_system_id ORDER BY  pm_unit_connectedness_desc ASC
																			, pm_unit_connectedness_score DESC
																			, gvg_unit_life_cash_recog DESC
																			, gvg_unit_latest_date_cash_recog DESC
																			, gvg_unit_latest_date_ngp_recog DESC
																			, cul.unit_id DESC) AS Row#
			 , pm_unit_connectedness_score
			 , pm_unit_connectedness_desc
			 , cul.unit_name
			 , cul.unit_id
			 , sui.avp_officer_manager

		  FROM DARanalytics.datamart.constituent_unit_level cul
		  left join DARanalytics.ref.school_unit_info sui on sui.unit_id = cul.unit_id
		 WHERE cul.flag_unit_philanthropic = 1			--use only the main units
		   and pm_unit_connectedness_score > 0			--needs at least 1 on the scoring algo
		   and flag_unit_pgi_not_unit_prospect = 0		--can't be ruled out as not a prospect

      ) t where Row# = 1
	)  topunit on topunit.constituent_system_id = b.CONSTITUENTSYSTEMID


 /* VCU Top Connected Unit for the household (n=421k t=9sec) Not sure if this is needed by anyone*/
 left join (
 select household_id
	  , pm_unit_connectedness_score		as pm_top_unit_connectedness_score_hh
      , pm_unit_connectedness_desc		as pm_top_unit_connectedness_desc_hh
      , unit_name						as pm_top_unit_name_hh
	  , unit_name_campaign				as pm_top_unit_campaign_name_hh
	  , unit_id							as pm_top_unit_id_hh
	  , avp_officer_manager				as pm_top_unit_avp_officer_manager_hh
  from (

		SELECT household_id
			 , ROW_NUMBER() OVER(PARTITION BY household_id ORDER BY  pm_unit_connectedness_desc ASC
																   , pm_unit_connectedness_score DESC
																   , gvg_unit_life_cash_recog DESC
																   , gvg_unit_latest_date_cash_recog DESC
																   , gvg_unit_latest_date_ngp_recog DESC
																   , cul.unit_id DESC) AS Row#
			 , pm_unit_connectedness_score
			 , pm_unit_connectedness_desc
			 , cul.unit_name
			 , cul.unit_id
			 , cul.unit_name_campaign
			 , sui.avp_officer_manager

		  FROM DARanalytics.datamart.constituent_unit_level cul
		  left join DARanalytics.ref.school_unit_info sui on sui.unit_id = cul.unit_id
		 WHERE cul.flag_unit_philanthropic = 1
		   and pm_unit_connectedness_score > 0
		   and flag_unit_pgi_not_unit_prospect = 0

      ) t where Row# = 1
	)  topunit_hh on topunit_hh.household_id = hh_summary.household_id


 /* VCU Top Connected MAIN Unit - Ones with Philanthropy (n=467k t=10sec) - Obsoleted by PUF above??*/
 left join (
 select 
	   constituent_lookup_id
	 , constituent_system_id
	 , pm_unit_connectedness_score		as pm_main_unit_connectedness_score
     , pm_unit_connectedness_desc		as pm_main_unit_connectedness_desc
     , unit_name_short					as pm_main_unit_name_short
	 , unit_id							as pm_main_unit_id
	 , site_id							as pm_main_site_id
	 , avp_officer_manager				as pm_main_unit_avp_officer_manager
  from (

		SELECT constituent_system_id
			 , constituent_lookup_id
			 , ROW_NUMBER() OVER(PARTITION BY constituent_system_id ORDER BY  pm_unit_connectedness_desc ASC
																			, pm_unit_connectedness_score DESC
																			, gvg_unit_life_cash_recog DESC
																			, gvg_unit_latest_date_cash_recog DESC
																			, gvg_unit_latest_date_ngp_recog DESC
																			, cul.unit_id DESC) AS Row#
			 , pm_unit_connectedness_score
			 , pm_unit_connectedness_desc
			 , cul.unit_name_short
			 , cul.unit_id
			 , sui.avp_officer_manager
			 , sui.site_id

		  FROM DARanalytics.datamart.constituent_unit_level cul
		  left join DARanalytics.ref.school_unit_info sui on sui.unit_id = cul.unit_id
		 WHERE cul.pm_unit_connectedness_score > 0			--some people have scores 0 - should be few if any -track them down
		   and sui.flag_unit_philanthropic = 1
		   and cul.flag_unit_pgi_not_unit_prospect = 0

      ) t where Row# = 1
	)  topmainunit on topmainunit.constituent_system_id = b.CONSTITUENTSYSTEMID

	 /* VCU Top Connected Unit MAIN for the household (n=421k t=9sec) - Does anyone need household top unit?*/
 left join (
 select household_id
	  , pm_unit_connectedness_score		as pm_main_unit_connectedness_score_hh
      , pm_unit_connectedness_desc		as pm_main_unit_connectedness_desc_hh
      , unit_name_short					as pm_main_unit_name_short_hh
      , unit_name						as pm_main_unit_name_hh
	  , unit_id							as pm_main_unit_id_hh
	  , site_id							as pm_main_site_id_hh
	  , avp_officer_manager				as pm_main_unit_avp_officer_manager_hh
  from (

		SELECT household_id
			 , ROW_NUMBER() OVER(PARTITION BY household_id ORDER BY  pm_unit_connectedness_desc ASC
																   , pm_unit_connectedness_score DESC
																   , gvg_unit_life_cash_recog DESC
																   , gvg_unit_latest_date_cash_recog DESC
																   , gvg_unit_latest_date_ngp_recog DESC
																   , cul.unit_id DESC) AS Row#
			 , pm_unit_connectedness_score
			 , pm_unit_connectedness_desc
			 , cul.unit_name_short
			 , cul.unit_name
			 , cul.unit_id
			 , sui.avp_officer_manager
			 , sui.site_id

		  FROM DARanalytics.datamart.constituent_unit_level cul
		  left join DARanalytics.ref.school_unit_info sui on sui.unit_id = cul.unit_id
		 WHERE pm_unit_connectedness_score > 0
		   and sui.flag_unit_philanthropic = 1
		   and flag_unit_pgi_not_unit_prospect = 0

      ) t where Row# = 1
	)  topmainunit_hh on topmainunit_hh.household_id = hh_summary.household_id



 /* VCU Top Connected Unit amongst 12 CSUs (n=279k t=6sec) Obsoleted by PUF above*/
 left join (
 select 
	   constituent_lookup_id
	 , constituent_system_id
	 , pm_unit_connectedness_score		as pm_top12_unit_connectedness_score
     , pm_unit_connectedness_desc		as pm_top12_unit_connectedness_desc
     , unit_name_short					as pm_top12_unit_name_short
	 , unit_id							as pm_top12_unit_id
	 , site_id							as pm_top12_site_id
	 , avp_officer_manager				as pm_top12_unit_avp_officer_manager
  from (

		SELECT constituent_system_id
			 , constituent_lookup_id
			 , ROW_NUMBER() OVER(PARTITION BY constituent_system_id ORDER BY  pm_unit_connectedness_desc ASC
																			, pm_unit_connectedness_score DESC
																			, gvg_unit_life_cash_recog DESC
																			, gvg_unit_latest_date_cash_recog DESC
																			, gvg_unit_latest_date_ngp_recog DESC
																			, cul.unit_id DESC) AS Row#
			 , pm_unit_connectedness_score
			 , pm_unit_connectedness_desc
			 , cul.unit_name_short
			 , cul.unit_id
			 , sui.avp_officer_manager
			 , sui.site_id

		  FROM DARanalytics.datamart.constituent_unit_level cul
		  left join DARanalytics.ref.school_unit_info sui on sui.unit_id = cul.unit_id
		 WHERE pm_unit_connectedness_score > 0			--some people have scores 0 or negative because of how the unit score is created.  probably redo unit score
		   and sui.flag_unit_annual_giving = 1
		   and flag_unit_pgi_not_unit_prospect = 0

      ) t where Row# = 1
	)  topunit12 on topunit12.constituent_system_id = b.CONSTITUENTSYSTEMID




  /*PGI values This code shows people with an active PGI not a prospect - all of VCU.  
  Doesnt take into account the inclinationlevelcode which seems useful 
  (n=11.6k t=1sec)
  */
  left join (
  SELECT --pgi.PROSPECTGIVINGINTERESTSDIMID
     -- ,PROSPECTGIVINGINTERESTSSYSTEMID
	 -- ,pgis.SITEDIMID
	 -- ,pgis.PROSPECTGIVINGINTERESTSSITESYSTEMID
	 -- ,max(sui.unit_name)			as pgi_unit_name
	 -- ,max(sui.unit_id)				as pgi_unit_id
        pgi.CONSTITUENTDIMID
      , pgi.CONSTITUENTSYSTEMID
	--  , max(case when pgi.inclinationlevelcode like '%all of VCU%' then 1 else 0 end) as flag_pgi_NAP_all_VCU_active
	
	--Replaced on 9/29/25
	  , max(case when pgi.FUNDINGTYPECODE in ('All Levels','Principal/Major Gift') and pgi.inclinationlevelcode like '%all of VCU%' then 1 else 0 end) as flag_pgi_NAP_all_VCU_active
	  , max(case when pgi.FUNDINGTYPECODE = 'Leadership annual gift' and pgi.inclinationlevelcode like '%all of VCU%' then 1 else 0 end) as flag_pgi_NAP_all_VCU_leadership
	--  , max(case when pgi.FUNDINGTYPECODE = 'Principal/Major Gift' and pgi.inclinationlevelcode like '%all of VCU%' then 1 else 0 end) as flag_pgi_NAP_all_VCU_major
	

	  , max(case when pgi.inclinationlevelcode like '%unit%' then 1 else 0 end) as flag_pgi_NAP_unit_active
	  , max(case when pgi.inclinationlevelcode like '%unit%' and ds.sitesystemid='73DAE1C0-D2B9-4D35-997E-47FB14F1834E' then 1 else 0 end) as flag_pgi_NAP_unit_active_PG
	  , max(case when pgi.inclinationlevelcode = 'Suspect' and pgi.FUNDINGTYPECODE = 'planned gift prospect'  and FundraiserID is not null then 1
				 when pgi.inclinationlevelcode = 'Suspect' and pgi.FUNDINGTYPECODE <> 'planned gift prospect' then 1
				 else 0 end) as flag_pgi_referral_active
	  , max(case when pgi.inclinationlevelcode = 'Positive' then 1 else 0 end) as flag_pgi_positive_active

	--  , max(case when pgi.FUNDINGTYPECODE like '%annual fund%' then 1 else 0 end) as flag_pgi_af_gift_active
	  , max(case when pgi.FUNDINGTYPECODE like '%Principal/Major%' then 1 else 0 end) as flag_pgi_major_gift_active
	  , max(case when pgi.FUNDINGTYPECODE like '%leadership%' then 1 else 0 end) as flag_pgi_leadership_gift_active

	  --, max(case when pgi.FUNDINGTYPECODE like '%Principal%' then 1 else 0 end) as flag_pgi_principal_gift_active

	  /*Planned Giving*/

	  , max(case when pgi.FUNDINGTYPECODE = 'planned gift prospect' and pgi.inclinationlevelcode = 'Suspect' then 1  --and FundraiserID is not null  removed on 5/14/25
				 when pgi.FUNDINGTYPECODE = 'planned gift prospect' and pgi.inclinationlevelcode = 'Positive' then 1
				 when pgi.FUNDINGTYPECODE = 'planned gift prospect' and pgi.inclinationlevelcode = 'Not a prospect-all of VCU' then 1
				 when pgi.FUNDINGTYPECODE = 'planned gift prospect' and pgi.inclinationlevelcode = 'Not a prospect-unit based only' then 1
				 when pgi.FUNDINGTYPECODE = 'planned gift prospect' and pgi.inclinationlevelcode = 'Future prospect' then 1		--dont think they use this but for now these are 'not active'
				 else 0 end) as flag_pgi_planned_gift_active
	  , max(case when pgi.FUNDINGTYPECODE = 'planned gift prospect' and pgi.inclinationlevelcode = 'Suspect' and FundraiserID is not null then 1 else 0 end) as flag_pgi_PG_referral
	  , max(case when pgi.FUNDINGTYPECODE = 'planned gift prospect' and pgi.inclinationlevelcode = 'Positive' then 1 else 0 end) as flag_pgi_PG_positive
	  , max(case when pgi.FUNDINGTYPECODE = 'planned gift prospect' and pgi.inclinationlevelcode = 'Not a prospect-all of VCU' then 1 else 0 end) as flag_pgi_PG_VCU_NAP
	  , max(case when pgi.FUNDINGTYPECODE = 'planned gift prospect' and pgi.inclinationlevelcode = 'Not a prospect-unit based only' then 1 else 0 end) as flag_pgi_PG_unit_NAP
	  , max(case when pgi.FUNDINGTYPECODE = 'planned gift prospect' and pgi.inclinationlevelcode = 'Future prospect' then 1 
				 when pgi.FUNDINGTYPECODE = 'planned gift prospect' and pgi.inclinationlevelcode = 'Suspect' and FundraiserID is null then 1  --removed on 5/14/25 --added back per Ann D on 6/13/2025
				 else 0 end) as flag_pgi_PG_VCU_future

      , max(pgi.FUNDINGTYPECODE)			as pgi_funding_type_code
      , max(pgi.INCLINATIONLEVELCODE)		as pgi_inclination_level_code
      , max(pgi.COMMENT)					as pgi_comment
	  , max(case when pgi.comment like '%top parent%' then 1 else 0 end) flag_pgi_top_parent_active
	  , max(case when pgi.comment like '%top parent%' then substring(comment,charindex('2',comment,1),4) else NULL end) pgi_top_parent_active_latest_year  --doesn't take into account multi year top parents
     -- ,max(case when INCLUDESSPOUSE=1 then 1 else 0 end)			as pgi_include_spouse
     -- ,STARTDATE
     -- ,ENDDATE
     -- ,SUBMITTEDBYID
  FROM BBCRM_PROD_RPT_BBDW.BBDW.VCU_DIM_PROSPECTGIVINGINTERESTS pgi
  left join BBCRM_PROD_RPT_BBDW.BBDW.VCU_FACT_PROSPECTGIVINGINTERESTSSITE  pgis on pgis.PROSPECTGIVINGINTERESTSDIMID = pgi.PROSPECTGIVINGINTERESTSDIMID
  left join BBCRM_PROD_RPT_BBDW.BBDW.DIM_SITE ds on ds.SITEDIMID = pgis.SITEDIMID
 where getdate() between isnull(startdate,'2000-01-01') and isnull(enddate,'2099-12-31')
 group by constituentdimid, constituentsystemid
	) pgi on pgi.CONSTITUENTSYSTEMID = b.CONSTITUENTSYSTEMID


/*ACTIVE LAGO REFERRALS  (n=242 t =1 sec)*/
left join (
		select constituent_system_id
			 , constituent_lookup_id
			 , max(flag_ofcr_currently_managed) as flag_ofcr_currently_managed
			 , max(flag_unacted_referral_hh)	as flag_unacted_referral_hh
		  from DARanalytics.datamart.constituent_officer_level
		 where officer_latest_job_level = 'LAGO'
		   and flag_active_officer = 1
		   and flag_ofcr_referral_recipient_hh = 1
		 group by constituent_system_id, constituent_lookup_id
 ) lago on lago.constituent_system_id = b.CONSTITUENTSYSTEMID


    /* Individual Giving to VCU using new tables  (n=303702 t =9 sec)*/
  left join (
  select 
		 t.constituent_system_id
   		,sum(t.li_received_amount) as gvg_lifetime_received
   		,sum(t.li_raised_amount) as gvg_lifetime_raised
		,count(distinct case when t.li_received_amount>0 or t.li_raised_amount>0 then FINANCIALTRANSACTIONID end) as gvg_life_num_transactions		--not counting writeoffs
   		,sum(case when t.rev_FY between year(dateadd(month,6,getdate()))-5 and year(dateadd(month,6,getdate())) then t.li_received_amount else 0 end) as gvg_past5FY_received
   		,sum(case when t.rev_FY between year(dateadd(month,6,getdate()))-5 and year(dateadd(month,6,getdate())) then t.li_raised_amount else 0 end) as gvg_past5FY_raised
   
   		,sum(case when t.rev_FY = year(dateadd(month,6,getdate())) then t.li_received_amount else 0 end) as gvg_tminus0_received
   		,sum(case when t.rev_FY = year(dateadd(month,6,getdate())) then t.li_raised_amount else 0 end) as gvg_tminus0_raised
   		,sum(case when t.rev_FY = year(dateadd(month,6,getdate()))-1 then t.li_received_amount else 0 end) as gvg_tminus1_received
   		,sum(case when t.rev_FY = year(dateadd(month,6,getdate()))-1 then t.li_raised_amount else 0 end) as gvg_tminus1_raised
		,sum(case when t.rev_FY = year(dateadd(month,6,getdate()))-2 then t.li_received_amount else 0 end) as gvg_tminus2_received
   		,sum(case when t.rev_FY = year(dateadd(month,6,getdate()))-2 then t.li_raised_amount else 0 end) as gvg_tminus2_raised
		,sum(case when t.rev_FY = year(dateadd(month,6,getdate()))-3 then t.li_received_amount else 0 end) as gvg_tminus3_received
   		,sum(case when t.rev_FY = year(dateadd(month,6,getdate()))-3 then t.li_raised_amount else 0 end) as gvg_tminus3_raised
		,sum(case when t.rev_FY = year(dateadd(month,6,getdate()))-4 then t.li_received_amount else 0 end) as gvg_tminus4_received
   		,sum(case when t.rev_FY = year(dateadd(month,6,getdate()))-4 then t.li_raised_amount else 0 end) as gvg_tminus4_raised
		,sum(case when t.rev_FY = year(dateadd(month,6,getdate()))-5 then t.li_received_amount else 0 end) as gvg_tminus5_received
   		,sum(case when t.rev_FY = year(dateadd(month,6,getdate()))-5 then t.li_raised_amount else 0 end) as gvg_tminus5_raised
from (
SELECT --li.ID
       li.FINANCIALTRANSACTIONLINEITEMID
     , li.FINANCIALTRANSACTIONID

	 , c.constituentdimid			as constituent_dim_id
	 , rev.CONSTITUENTID			as constituent_system_id
	 , c.constituentlookupid		as constituent_lookup_id
	 , m.CONSTITUENTDIMID_SUMMARY	as household_id 
	 , c.fullname

   --   ,SOURCELINEITEMID
   --  , RECOGNITIONCOUNT
     , li.LINEITEMAMOUNT				as li_amount
     , li.LINEITEMBENEFITAMOUNT			as li_benefit_amount
     , li.LINEITEMWRITEOFFTOTALAMOUNT	as li_writeoff_total_amount
     , li.LINEITEMWRITEOFFNONDAFAMOUNT	as li_writeoff_nondaf_amount
     , li.LINEITEMWRITEOFFDAFAMOUNT		as li_writeoff_daf_amount
     , li.APPLICATIONCODE				as li_application_code
     , li.APPLICATIONTYPE				as li_application_type
     , li.REVENUETYPE					as li_revenue_type
     , li.REVENUECATEGORYID				as li_revenue_category_id
     , li.REVENUECATEGORYNAME			as li_revenue_category_name
     , li.DESIGNATIONID					as li_designation_id
     , li.DESIGNATIONNAME				as li_designation_name
     , li.DESIGNATIONPUBLICNAME			as li_designation_public_name
     , li.DESIGNATIONREPORTCODE1ID		as li_designation_report_code1_id
     , li.DESIGNATIONREPORTCODE2ID		as li_designation_report_code2_id
     , li.DESIGNATIONREPORTCODE1		as li_designation_report_code1
     , li.DESIGNATIONREPORTCODE2		as li_designation_report_code2
     , li.DESIGNATIONOWNER				as li_designation_owner
     , li.DESIGNATIONUSECODEID			as li_designation_use_code_id
     , li.DESIGNATIONUSECODE			as li_designation_use_code
     , li.REPORTCODEEXTENDED			as li_report_code_extended
     , li.SUBDEPARTMENT					as li_subdepartment
     , li.CENTER						as li_center
     , li.DAFPAYMENT					as li_daf_payment_flag
     , li.DAFPLEDGELOOKUPID				as li_daf_pledge_lookup_id

     , rcat.RAISEDAMOUNT				as li_raised_amount
     , rcat.RECEIVEDAMOUNT				as li_received_amount
     , rcat.CAMPAIGN2030RAISEDAMOUNT	as li_raised_amount_campaign2030
     , rcat.CAMPAIGN2030RECEIVEDAMOUNT	as li_received_amount_campaign2030
    --  ,rcat.MIRCAMPAIGNAMOUNT

	  ,rev.REVENUELOOKUPID		as rev_lookup_id

      ,rev.DATE					as rev_date
      ,rev.FISCALYEAR			as rev_FY
    --  ,rev.TYPECODE
      ,rev.TYPE					as rev_type
      ,rev.TRANSACTIONAMOUNT	as rev_total_transaction_amount
      ,rev.RECEIPTAMOUNT		as rev_total_receipt_amount
      ,rev.BENEFITTOTALVALUE	as rev_benefit_total_value
      ,rev.PLEDGEBALANCE		as rev_pledge_balance
      ,rev.PLEDGESUBTYPEID		as rev_pledge_subtype_id
      ,rev.PLEDGESUBTYPE		as rev_pledge_subtype
      ,rev.WRITEOFFAMOUNT		as rev_writeoff
      ,rev.GIVENANONYMOUSLY		as flag_rev_given_anonymously
   --   ,rev.PAYMENTMETHODCODEID
   --   ,rev.PAYMENTMETHOD
   --   ,rev.OTHERPAYMENTMETHODCODEID
   --   ,rev.OTHERPAYMENTMETHOD
   --   ,rev.INBOUNDCHANNELCODEID
   --   ,rev.INBOUNDCHANNEL
      ,rev.PGISREVOCABLE		as flag_rev_pg_is_revocable
      ,rev.PGVEHICLE			as rev_pg_vehicle
      ,rev.PGORIGINALORADDITION	as rev_pg_original_or_addition
      ,rev.SPLITCOUNT			as rev_num_line_items
  --    ,rev.SOURCECODE
   --   ,rev.FINDERNUMBER
      , row_number() over (partition by li.financialtransactionid order by li.lineitemamount, li.designationname desc) as transaction_line_item_row_num
	  , case when rcat.CAMPAIGN2030RAISEDAMOUNT > 0 or rcat.CAMPAIGN2030RECEIVEDAMOUNT > 0 then 1 else 0 end as flag_campaign2030
  FROM BBCRM_PROD_RPT_BBDW.BBDW.VCU_FACT_REVENUECOUNTINGLINEITEM li
  left join BBCRM_PROD_RPT_BBDW.BBDW.VCU_FACT_REVENUECOUNTINGCATEGORY rcat on rcat.FINANCIALTRANSACTIONLINEITEMID = li.FINANCIALTRANSACTIONLINEITEMID
  left join BBCRM_PROD_RPT_BBDW.BBDW.VCU_FACT_REVENUECOUNTING rev on rev.FINANCIALTRANSACTIONID = li.FINANCIALTRANSACTIONID
  left join BBCRM_PROD_RPT_BBDW.BBDW.DIM_CONSTITUENT c on c.constituentsystemid = rev.CONSTITUENTID
  left join BBCRM_PROD_RPT_BBDW.BBDW.VCU_FACT_CONSTITUENTMARRIAGE m on m.CONSTITUENTDIMID = c.CONSTITUENTDIMID
  ) t
  group by constituent_system_id
  ) gvg on gvg.constituent_system_id = b.CONSTITUENTSYSTEMID



  /* HH Giving to VCU using new tables (n=285k t =8 sec)*/
  left join (  
  select 
		 t.household_id
   		,sum(t.li_received_amount) as gvg_life_received_hh
   		,sum(t.li_raised_amount) as gvg_life_raised_hh
		,count(distinct case when t.li_received_amount>0 or t.li_raised_amount>0 then FINANCIALTRANSACTIONID end) as gvg_life_num_transactions_hh		--not counting writeoffs
   		,sum(case when t.rev_FY between year(dateadd(month,6,getdate()))-5 and year(dateadd(month,6,getdate())) then t.li_received_amount else 0 end) as gvg_past5FY_received_hh
   		,sum(case when t.rev_FY between year(dateadd(month,6,getdate()))-5 and year(dateadd(month,6,getdate())) then t.li_raised_amount else 0 end) as gvg_past5FY_raised_hh
   
   		,sum(case when t.rev_FY = year(dateadd(month,6,getdate())) then t.li_received_amount else 0 end) as gvg_tminus0_received_hh
   		,sum(case when t.rev_FY = year(dateadd(month,6,getdate())) then t.li_raised_amount else 0 end) as gvg_tminus0_raised_hh
   		,sum(case when t.rev_FY = year(dateadd(month,6,getdate()))-1 then t.li_received_amount else 0 end) as gvg_tminus1_received_hh
   		,sum(case when t.rev_FY = year(dateadd(month,6,getdate()))-1 then t.li_raised_amount else 0 end) as gvg_tminus1_raised_hh
		,sum(case when t.rev_FY = year(dateadd(month,6,getdate()))-2 then t.li_received_amount else 0 end) as gvg_tminus2_received_hh
   		,sum(case when t.rev_FY = year(dateadd(month,6,getdate()))-2 then t.li_raised_amount else 0 end) as gvg_tminus2_raised_hh
		,sum(case when t.rev_FY = year(dateadd(month,6,getdate()))-3 then t.li_received_amount else 0 end) as gvg_tminus3_received_hh
   		,sum(case when t.rev_FY = year(dateadd(month,6,getdate()))-3 then t.li_raised_amount else 0 end) as gvg_tminus3_raised_hh
		,sum(case when t.rev_FY = year(dateadd(month,6,getdate()))-4 then t.li_received_amount else 0 end) as gvg_tminus4_received_hh
   		,sum(case when t.rev_FY = year(dateadd(month,6,getdate()))-4 then t.li_raised_amount else 0 end) as gvg_tminus4_raised_hh
		,sum(case when t.rev_FY = year(dateadd(month,6,getdate()))-5 then t.li_received_amount else 0 end) as gvg_tminus5_received_hh
   		,sum(case when t.rev_FY = year(dateadd(month,6,getdate()))-5 then t.li_raised_amount else 0 end) as gvg_tminus5_raised_hh

from (
SELECT --li.ID
       li.FINANCIALTRANSACTIONLINEITEMID
     , li.FINANCIALTRANSACTIONID

	 , c.constituentdimid			as constituent_dim_id
	 , rev.CONSTITUENTID			as constituent_system_id
	 , c.constituentlookupid		as constituent_lookup_id
	 , m.CONSTITUENTDIMID_SUMMARY	as household_id 
	 , c.fullname

   --   ,SOURCELINEITEMID
   --  , RECOGNITIONCOUNT
     , li.LINEITEMAMOUNT				as li_amount
     , li.LINEITEMBENEFITAMOUNT			as li_benefit_amount
     , li.LINEITEMWRITEOFFTOTALAMOUNT	as li_writeoff_total_amount
     , li.LINEITEMWRITEOFFNONDAFAMOUNT	as li_writeoff_nondaf_amount
     , li.LINEITEMWRITEOFFDAFAMOUNT		as li_writeoff_daf_amount
     , li.APPLICATIONCODE				as li_application_code
     , li.APPLICATIONTYPE				as li_application_type
     , li.REVENUETYPE					as li_revenue_type
     , li.REVENUECATEGORYID				as li_revenue_category_id
     , li.REVENUECATEGORYNAME			as li_revenue_category_name
     , li.DESIGNATIONID					as li_designation_id
     , li.DESIGNATIONNAME				as li_designation_name
     , li.DESIGNATIONPUBLICNAME			as li_designation_public_name
     , li.DESIGNATIONREPORTCODE1ID		as li_designation_report_code1_id
     , li.DESIGNATIONREPORTCODE2ID		as li_designation_report_code2_id
     , li.DESIGNATIONREPORTCODE1		as li_designation_report_code1
     , li.DESIGNATIONREPORTCODE2		as li_designation_report_code2
     , li.DESIGNATIONOWNER				as li_designation_owner
     , li.DESIGNATIONUSECODEID			as li_designation_use_code_id
     , li.DESIGNATIONUSECODE			as li_designation_use_code
     , li.REPORTCODEEXTENDED			as li_report_code_extended
     , li.SUBDEPARTMENT					as li_subdepartment
     , li.CENTER						as li_center
     , li.DAFPAYMENT					as li_daf_payment_flag
     , li.DAFPLEDGELOOKUPID				as li_daf_pledge_lookup_id

     , rcat.RAISEDAMOUNT				as li_raised_amount
     , rcat.RECEIVEDAMOUNT				as li_received_amount
     , rcat.CAMPAIGN2030RAISEDAMOUNT	as li_raised_amount_campaign2030
     , rcat.CAMPAIGN2030RECEIVEDAMOUNT	as li_received_amount_campaign2030
    --  ,rcat.MIRCAMPAIGNAMOUNT

	  ,rev.REVENUELOOKUPID		as rev_lookup_id

      ,rev.DATE					as rev_date
      ,rev.FISCALYEAR			as rev_FY
    --  ,rev.TYPECODE
      ,rev.TYPE					as rev_type
      ,rev.TRANSACTIONAMOUNT	as rev_total_transaction_amount
      ,rev.RECEIPTAMOUNT		as rev_total_receipt_amount
      ,rev.BENEFITTOTALVALUE	as rev_benefit_total_value
      ,rev.PLEDGEBALANCE		as rev_pledge_balance
      ,rev.PLEDGESUBTYPEID		as rev_pledge_subtype_id
      ,rev.PLEDGESUBTYPE		as rev_pledge_subtype
      ,rev.WRITEOFFAMOUNT		as rev_writeoff
      ,rev.GIVENANONYMOUSLY		as flag_rev_given_anonymously
   --   ,rev.PAYMENTMETHODCODEID
   --   ,rev.PAYMENTMETHOD
   --   ,rev.OTHERPAYMENTMETHODCODEID
   --   ,rev.OTHERPAYMENTMETHOD
   --   ,rev.INBOUNDCHANNELCODEID
   --   ,rev.INBOUNDCHANNEL
      ,rev.PGISREVOCABLE		as flag_rev_pg_is_revocable
      ,rev.PGVEHICLE			as rev_pg_vehicle
      ,rev.PGORIGINALORADDITION	as rev_pg_original_or_addition
      ,rev.SPLITCOUNT			as rev_num_line_items
  --    ,rev.SOURCECODE
   --   ,rev.FINDERNUMBER
      , row_number() over (partition by li.financialtransactionid order by li.lineitemamount, li.designationname desc) as transaction_line_item_row_num
	  , case when rcat.CAMPAIGN2030RAISEDAMOUNT > 0 or rcat.CAMPAIGN2030RECEIVEDAMOUNT > 0 then 1 else 0 end as flag_campaign2030
  FROM BBCRM_PROD_RPT_BBDW.BBDW.VCU_FACT_REVENUECOUNTINGLINEITEM li
  left join BBCRM_PROD_RPT_BBDW.BBDW.VCU_FACT_REVENUECOUNTINGCATEGORY rcat on rcat.FINANCIALTRANSACTIONLINEITEMID = li.FINANCIALTRANSACTIONLINEITEMID
  left join BBCRM_PROD_RPT_BBDW.BBDW.VCU_FACT_REVENUECOUNTING rev on rev.FINANCIALTRANSACTIONID = li.FINANCIALTRANSACTIONID
  left join BBCRM_PROD_RPT_BBDW.BBDW.DIM_CONSTITUENT c on c.constituentsystemid = rev.CONSTITUENTID
  left join BBCRM_PROD_RPT_BBDW.BBDW.VCU_FACT_CONSTITUENTMARRIAGE m on m.CONSTITUENTDIMID = c.CONSTITUENTDIMID
  ) t
  group by household_id
  --order by gvg_life_num_transactions_hh
  ) gvg_hh_old on gvg_hh_old.household_id = hh_summary.household_id



  /* Giving to VCU (n=293k t=9 sec)*/
  left join (  
  	SELECT g.CONSTITUENTDIMID	
	     , g.CONSTITUENTSYSTEMID
				 /* lifetime giving */
				 , max(case when g.summarytypeid = 1 then isnull(g.lifetime_total,0) else 0 end) AS gvg_life_cash  		/* pp, gi, mc */
				 , max(case when g.summarytypeid = 2 then isnull(g.lifetime_total,0) else 0 end) AS gvg_life_cash_recog 	/* pp, gi, mc */
				 , max(case when g.summarytypeid = 3 then isnull(g.lifetime_total,0) else 0 end) AS gvg_life_ngp			/* pl, gi, mc */
				 , max(case when g.summarytypeid = 4 then isnull(g.lifetime_total,0) else 0 end) AS gvg_life_ngp_recog		/* pl, gi, mc */
				 , max(case when g.summarytypeid = 2 then isnull(g.lifetime_count,0) else 0 end) AS gvg_life_gift_count   --cash recog

				 /* gift timing fields */
				 , max(case when g.summarytypeid = 2 then convert(date,g.lastgiftdate) else NULL end) AS gvg_latest_cash_recog  --cash recog
				 , max(case when g.summarytypeid = 4 then convert(date,g.lastgiftdate) else NULL end) AS gvg_latest_ngp_recog   --ngp recog

				 /* total cash in past few years */
				 , max(case when g.summarytypeid = 2 then ISNULL(g.currentfy_total,0) else 0 end)	AS gvg_tminus0_cash_recog   --cash recog
				 , max(case when g.summarytypeid = 2 then ISNULL(g.onefyago_total,0) else 0 end)	AS gvg_tminus1_cash_recog   --cash recog
				 , max(case when g.summarytypeid = 2 then ISNULL(g.twofyago_total,0) else 0 end)	AS gvg_tminus2_cash_recog   --cash recog
				 , max(case when g.summarytypeid = 2 then ISNULL(g.threefyago_total,0) else 0 end)	AS gvg_tminus3_cash_recog   --cash recog
				 , max(case when g.summarytypeid = 2 then ISNULL(g.fourfyago_total,0) else 0 end)	AS gvg_tminus4_cash_recog   --cash recog
				 , max(case when g.summarytypeid = 2 then ISNULL(g.fivefyago_total,0) else 0 end)	AS gvg_tminus5_cash_recog   --cash recog

              FROM BBCRM_PROD_RPT_BBDW.BBDW.VCU_RPT_GIVINGSUMMARY g
          --    join DARanalytics.ref.school_unit_info sui on sui.report_code1_id = g.REPORTCODE1ID  --for unit report we only care about the units and not the higher summaries
             WHERE summarytypeid in (1   -- cash                       --this seems to catch all donors
			                        ,2   -- cash recognition
									,3   -- ngp
									,4)  -- ngp_recog  
               and unit = 'VCU'
		  GROUP BY g.CONSTITUENTDIMID, g.constituentsystemid
		  --order by gvg_latest_ngp_recog
	) g on g.CONSTITUENTSYSTEMID = b.CONSTITUENTSYSTEMID

	/*RECENT GIVING - since 2013  (n=157k t =3 sec)  obsoleted by giving_revenue_history_summary_indiv*/
	--left join (	
	--			SELECT constituent_dim_id
	--			     , constituent_system_id
	--				 , constituent_lookup_id
	--				 , max(flag_rev_ira_gift) as flag_rev_ira_gift

	--			  FROM DARanalytics.dbo.giving_line_item_hard_indiv_recent
	--		  GROUP BY constituent_system_id, constituent_dim_id, constituent_lookup_id
	--		 -- ORDER BY flag_rev_ira_gift desc
	--		  ) gvg_hard on gvg_hard.constituent_system_id = b.CONSTITUENTSYSTEMID


/* RECOGNITION GIVING BASED ON LATEST TABLE  (n=284k t =8 sec)*/
left join (	
 select RECOGNITION_CONSTITUENTID, RECOGNITION_CONSTITUENTLOOKUPID, RECOGNITION_CONSTITUENTDIMID
     , sum(VCURECOGNITIONAMOUNT)  as gvg_life_vcu_recog
	 , sum(case when rlih.CAMPAIGNDATE is not null then VCURECOGNITIONAMOUNT else 0 end) as gvg_campaign_vcu_recog
	 , sum(case when rlih.FISCALYEAR = year(dateadd(month,6,getdate())) then   rlih.VCURECOGNITIONAMOUNT else 0 end) as gvg_tminus0_vcu_recog
	 , sum(case when rlih.FISCALYEAR = year(dateadd(month,6,getdate()))-1 then rlih.VCURECOGNITIONAMOUNT else 0 end) as gvg_tminus1_vcu_recog
	 , sum(case when rlih.FISCALYEAR = year(dateadd(month,6,getdate()))-2 then rlih.VCURECOGNITIONAMOUNT else 0 end) as gvg_tminus2_vcu_recog
	 , sum(case when rlih.FISCALYEAR = year(dateadd(month,6,getdate()))-3 then rlih.VCURECOGNITIONAMOUNT else 0 end) as gvg_tminus3_vcu_recog
	 , sum(case when rlih.FISCALYEAR = year(dateadd(month,6,getdate()))-4 then rlih.VCURECOGNITIONAMOUNT else 0 end) as gvg_tminus4_vcu_recog
	 , sum(case when rlih.FISCALYEAR = year(dateadd(month,6,getdate()))-5 then rlih.VCURECOGNITIONAMOUNT else 0 end) as gvg_tminus5_vcu_recog
	 , sum(case when rlih.FISCALYEAR = year(dateadd(month,6,getdate()))-6 then rlih.VCURECOGNITIONAMOUNT else 0 end) as gvg_tminus6_vcu_recog
	 , sum(case when rlih.FISCALYEAR = year(dateadd(month,6,getdate()))-7 then rlih.VCURECOGNITIONAMOUNT else 0 end) as gvg_tminus7_vcu_recog
	 , sum(case when rlih.FISCALYEAR = year(dateadd(month,6,getdate()))-8 then rlih.VCURECOGNITIONAMOUNT else 0 end) as gvg_tminus8_vcu_recog
	 , sum(case when rlih.FISCALYEAR = year(dateadd(month,6,getdate()))-9 then rlih.VCURECOGNITIONAMOUNT else 0 end) as gvg_tminus9_vcu_recog
	 , sum(case when rlih.FISCALYEAR = year(dateadd(month,6,getdate()))-10 then rlih.VCURECOGNITIONAMOUNT else 0 end) as gvg_tminus10_vcu_recog
	 , max(case when HARDCREDITCONSTITUENCY = 'DONORADVISEDFUND' and REVENUE_CONSTITUENTLOOKUPID not in ('8-10028628') then 1 else 0 end) as flag_has_used_daf  --Benevity gone
	 , max(case when HARDCREDITCONSTITUENCY in ('FAMILYFOUNDATIONALUMNI','FAMILYFOUNDATIONINDIVIDUAL') then 1 else 0 end) as flag_has_used_ff
	 , sum(case when rlih.FISCALYEAR = year(dateadd(month,6,getdate()))-1 then rlih.VCURECOGNITIONAMOUNT else 0 end) 
	  + sum(case when rlih.FISCALYEAR = year(dateadd(month,6,getdate()))-2 then rlih.VCURECOGNITIONAMOUNT else 0 end)
	  + sum(case when rlih.FISCALYEAR = year(dateadd(month,6,getdate()))-3 then rlih.VCURECOGNITIONAMOUNT else 0 end) 
	  + sum(case when rlih.FISCALYEAR = year(dateadd(month,6,getdate()))-4 then rlih.VCURECOGNITIONAMOUNT else 0 end) 
	  + sum(case when rlih.FISCALYEAR = year(dateadd(month,6,getdate()))-5 then rlih.VCURECOGNITIONAMOUNT else 0 end) as gvg_5yr_vcu_recog
	 , (sum(case when rlih.FISCALYEAR = year(dateadd(month,6,getdate()))-1 then rlih.VCURECOGNITIONAMOUNT else 0 end) 
	  + sum(case when rlih.FISCALYEAR = year(dateadd(month,6,getdate()))-2 then rlih.VCURECOGNITIONAMOUNT else 0 end)
	  + sum(case when rlih.FISCALYEAR = year(dateadd(month,6,getdate()))-3 then rlih.VCURECOGNITIONAMOUNT else 0 end) 
	  + sum(case when rlih.FISCALYEAR = year(dateadd(month,6,getdate()))-4 then rlih.VCURECOGNITIONAMOUNT else 0 end) 
	  + sum(case when rlih.FISCALYEAR = year(dateadd(month,6,getdate()))-5 then rlih.VCURECOGNITIONAMOUNT else 0 end))/5 as gvg_5yr_avg_vcu_recog
	 , count(distinct(case when rlih.FISCALYEAR between year(dateadd(month,6,getdate()))-10 and year(dateadd(month,6,getdate())) and rlih.VCURECOGNITIONAMOUNT > 0 then rlih.FISCALYEAR else NULL end)) as gvg_10yrs_num_yrs_vcu_recog

	 --For UNIT reporting
	-- , DESIGNATIONREPORTCODE1
	-- , DESIGNATIONREPORTCODE2
	-- , REPORTCODEEXTENDED
	-- , SUBDEPARTMENT
	-- , CENTER


  from BBCRM_PROD_RPT_BBDW.BBDW.VCU_RPT_REVENUERECOGNITIONLINEITEMHISTORY rlih
 -- left join DARanalytics.datamart.constituent_household_level chl on chl.household_id = rlih.RECOGNITION_HOUSEHOLDDIMID 

 where RAISEDAMOUNT <> 0
  -- and RECOGNITION_HOUSEHOLDID = '691bb416-4611-4026-b364-1364edb4de04'
group by RECOGNITION_CONSTITUENTID, RECOGNITION_CONSTITUENTLOOKUPID, RECOGNITION_CONSTITUENTDIMID
) gvg_recog on gvg_recog.RECOGNITION_CONSTITUENTID = b.CONSTITUENTSYSTEMID

	/* Lybunt Sybunt from Al  (n=227k t=5 sec) - Al deprecated this table June 30 2026*/
--left join (	
--   select CONSTITUENTDIMID
--		, min(DONORCATEGORY) as donorcategory
--		, min(MINDONORCATEGORY) as mindonorcategory
--		, min(CATGROUPING) as CATGROUPING
--     from BBCRM_PROD_RPT_BBDW.BBDW.VCU_RPT_AG_DONORRETENTIONDETAIL
--    where CONSTITUENTMAPPEDUNIT = 'overall'
--      and fiscalyear = year(dateadd(month,6,getdate()))
--    group by CONSTITUENTDIMID
	
--	) lyb on lyb.CONSTITUENTDIMID = b.CONSTITUENTDIMID

   /* Latest Windfall Screening Info replaced with datamart to save a few minutes*/
left join DARanalytics.datamart.windfall_constituent_level_latest wf on wf.constituent_system_id = b.CONSTITUENTSYSTEMID

/*left join (  (n=580k t=75sec) 
SELECT 
       max(wf_date_enriched) as wf_date_enriched
      ,[constituent_lookup_id]
      ,[constituent_dim_id]
      ,[constituent_system_id]
      ,max(net_worth) as wf_net_worth
	  ,max(convert(tinyint,flag_multi_property_owner))	as flag_multi_property_owner
      ,max(convert(tinyint,flag_recent_death_in_family)) as flag_recent_death_in_family
      ,max(convert(tinyint,flag_plane_owner))			as flag_plane_owner
      ,max(convert(tinyint,flag_luxury_car_owner))		as flag_luxury_car_owner
	  , max(flag_WF_DAF_indicator) as flag_WF_DAF_indicator
  
  FROM DARanalytics.tableau.windfall_enriched_all
  where wf_latest_enriched_record = 1
  group by constituent_system_id, constituent_dim_id, constituent_lookup_id
 -- order by constituent_lookup_id
 ) wf on wf.constituent_system_id = b.CONSTITUENTSYSTEMID
 */
	/* Interactions/Moves (n=87k t=2sec)*/
	left join (

SELECT constituent_dim_id
      ,constituent_lookup_id
      ,constituent_system_id
	  , max(case when (interaction_actual_date between getdate()-365 and getdate()) and flag_sig_interaction_2030=1 then 1 else 0 end) as flag_any_completed_sig_interaction_last_365
	  , max(case when interaction_actual_date between getdate()-365 and getdate() then 1 else 0 end) as flag_any_completed_interaction_last_365
	  , max(case when interaction_actual_date between '2020-07-01' and '2030-06-30' then 1 else 0 end) as flag_any_completed_interaction_campaign2030
	  , max(case when interaction_actual_date between getdate()-365 and getdate() and interaction_type = 'SPV' then 1 else 0 end) as flag_any_completed_SPV_last_365
	  , max(interaction_actual_date) as latest_completed_interaction
	  , min(interaction_actual_date) as earliest_completed_interaction
	  , max(case when flag_sig_interaction_type=1 then interaction_actual_date else NULL end) as latest_completed_sig_interaction_orig
	  , min(case when flag_sig_interaction_type=1 then interaction_actual_date else NULL end) as earliest_completed_sig_interaction_orig
	  , max(case when flag_sig_interaction_2030=1 then interaction_actual_date else NULL end) as latest_completed_sig_interaction
	  , min(case when flag_sig_interaction_2030=1 then interaction_actual_date else NULL end) as earliest_completed_sig_interaction
	  , max(case when interaction_type = 'SPV' then interaction_actual_date else NULL end) as latest_completed_SPV_interaction
	  , min(case when interaction_type = 'SPV' then interaction_actual_date else NULL end) as earliest_completed_SPV_interaction
	  , max(case when flag_sig_interaction_cultivate=1 and officer_interaction_role in ('primary','participant', 'secondary', 'discovery')
				then interaction_actual_date else NULL end) as latest_completed_sig_all_interaction_cultivate
	  , max(case when flag_sig_interaction_cultivate=1 and officer_interaction_role = 'primary' then interaction_actual_date else NULL end) as latest_completed_sig_primary_interaction_cultivate
 	  , max(case when flag_sig_interaction_cultivate=1 and officer_interaction_role = 'participant' then interaction_actual_date else NULL end) as latest_completed_sig_participant_interaction_cultivate
	  , max(case when flag_sig_interaction_cultivate=1 and officer_interaction_role = 'secondary' then interaction_actual_date else NULL end) as latest_completed_sig_secondary_interaction_cultivate
	  , max(case when flag_sig_interaction_cultivate=1 and officer_interaction_role = 'discovery' then interaction_actual_date else NULL end) as latest_completed_sig_discovery_interaction_cultivate
	  , sum(case when interaction_type = 'SPV' and interaction_actual_date between dateadd(month,-60,getdate()) and getdate() then 1 else 0 end) as num_SPV_interactions_past_60_months		--added for principal gift
	  , sum(case when interaction_type = 'SPV' and officer_lookup_id = '8-10174539'  then 1 else 0 end) as num_SPV_interactions_with_Rao		--added for principal gift
	  , sum(case when flag_sig_interaction_2030=1 and flag_officer_is_non_DAR_leadership = 1 and interaction_actual_date between dateadd(month,-60,getdate()) and getdate() then 1 else 0 end) num_sig_interactions_non_DAR_leadership_past_60_months  --added for principal gift
	  , max(case when interaction_type = 'SPV' and interaction_category = 'Stewardship' and datediff(day,interaction_actual_date,getdate()) < 365 then 1 else 0 end) as flag_mov_stewardship_SPV_interaction_last_365

 /*  ,officer_dim_id
      ,officer_system_id
      ,officer_interaction_role
      ,bio_name
      ,bio_lastcommafirstname
      ,pm_ofcr_manage_status
      ,flag_ofcr_currently_managed
      ,officer_name
      ,full_name
      ,unit_id
      ,unit_name
      ,position_order_desc
      ,flag_active_officer
      ,flag_use_in_fundraiser_reports
      ,officer_campus
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
      ,flag_is_officer
	  */
   from DARanalytics.tableau.officer_unit_constituent_interactions_all		--this is a table
  where interaction_status = 'Completed'
  group by constituent_dim_id, constituent_lookup_id, constituent_system_id
  ) moves on moves.constituent_system_id = b.CONSTITUENTSYSTEMID

left join (
		SELECT constituent_system_id
			 , max(flag_ofcr_has_pending_interaction) as flag_has_pending_interaction
			 , max(flag_ofcr_has_pending_plan_interaction) as flag_has_pending_plan_interaction
			 , min(mov_ofcr_earliest_pending_interaction_date) as mov_earliest_pending_interaction_date
			 , max(mov_ofcr_latest_pending_interaction_date) as mov_latest_pending_interaction_date
     
		  FROM DARanalytics.datamart.constituent_officer_level col
		GROUP BY constituent_system_id
		  ) pending_moves on pending_moves.constituent_system_id = b.CONSTITUENTSYSTEMID

left join (


select [constituent_lookup_id]
      ,[constituent_system_id]
      ,[interaction_type]					as mov_earliest_pending_interaction_type
      ,[interaction_lookup_id]
      ,[interaction_objective]				as mov_earliest_pending_interaction_objective
      ,[interaction_comment]				as mov_earliest_pending_interaction_comment
      ,[interaction_actual_date]			as mov_earliest_pending_interaction_date2
      ,[flag_sig_interaction_type]
      ,[flag_sig_interaction_2030]
      ,[interaction_FY]
      ,[interaction_concat_info]			as mov_earliest_pending_interaction_concat_info
	  , row_latest_pending_is_1				as mov_num_pending_interactions
from 
(SELECT [z_last_update]
      ,[interaction_constituent_combo_id]
      ,[interaction_system_id]
      ,[constituent_dim_id]
      ,[constituent_lookup_id]
      ,[constituent_system_id]
      ,[household_id]
      ,[officer_dim_id]
      ,[officer_lookup_id]
      ,[officer_system_id]
      ,[officer_interaction_role]
      ,[officer_interaction_role_detail]
      ,[bio_name]
      ,[bio_lastcommafirstname]
      ,[pm_ofcr_manage_status]
      ,[flag_ofcr_currently_managed]
      ,[flag_ofcr_current_prospect_manager]
      ,[officer_name]
      ,[primary_fundraiser_name]
      ,[officer_name_morethanGOI]
      ,[primary_fundraiser_name_morethanGOI]
      ,[unit_id]
      ,[unit_name]
      ,[unit_name_campaign]
      ,[interaction_site_list_campaign]
      ,[position_order_desc]
      ,[flag_active_officer]
      ,[flag_officer_is_non_DAR_leadership]
      ,[flag_veo_exchange]
      ,[flag_use_in_fundraiser_reports]
      ,[officer_campus]
      ,[officer_job_level]
      ,[avp_officer_manager]
      ,[flag_full_tenure_current_FY]
      ,[flag_full_tenure_previous_FY]
      ,[interaction_subcategory]
      ,[interaction_category]
      ,[interaction_type]
      ,[interaction_status]
      ,[flag_is_contact_report]
      ,[flag_is_interaction]
      ,[prospect_plan_dim_id]
      ,[plan_outline_step_dim_id]
      ,[prospect_plan_status_dim_id]
      ,[prospect_plan_name]
      ,[prospect_plan_status]
      ,[prospect_plan_type]
      ,[prospect_plan_system_id]
      ,[prospect_plan_is_active]
      ,[interaction_lookup_id]
      ,[interaction_objective]
      ,[flag_is_first_interaction]
      ,[flag_is_last_interaction]
      ,[interaction_comment]
      ,[interaction_sequence]
      ,[interaction_actual_date]
      ,[interaction_change_date]
      ,[interaction_expected_date]
      ,[flag_officer_in_GOI_table]
      ,[flag_sig_interaction_type]
      ,[flag_sig_interaction_2030]
      ,[flag_sig_interaction_cultivate]
      ,[interaction_FY]
      ,[flag_FY_current]
      ,[flag_FY_previous]
      ,[flag_is_officer]
      ,[flag_same_time_last_FY]
      ,[current_prospect_manager]
      ,[current_prospect_manager_system_id]
      ,[current_prospect_manager_job_level]
      ,[current_prospect_manager_unit_name]
      ,[current_prospect_manager_avp]
      ,[mov_ofcr_latest_referral_receipt]
      ,[mov_ofcr_latest_referral_receipt_stop_date]
      ,[flag_interaction_during_referral]
      ,[flag_latest_referral_active]
      ,[interaction_participants]
      ,[interaction_owner_name]
      ,[interaction_owner_system_id]
      ,[bio_age]
      ,[bio_death_date]
      ,[spouse_lookup_id]
      ,[spouse_system_id]
      ,[gvg_recog_raised_life_hh]
      ,[eval_vcu_planned_giving_score_sql]
      ,[flag_has_pg_vehicle_hh]
      ,[pm_current_team]
      ,[eval_capacity_rating_desc_short_sort]
      ,[flag_individual]
      ,[flag_living]
      ,[flag_is_principal_gift_prospect]
      ,[flag_ofcr_has_pending_interaction]
      ,[interactions_on_plan_ordered_desc]
      ,[interaction_concat_info]
	  ,row_number() over (partition by constituent_system_id order by interaction_actual_date) as row_earliest_pending_is_1
	  ,row_number() over (partition by constituent_system_id order by interaction_actual_date desc) as row_latest_pending_is_1
  FROM [DARanalytics].[tableau].[officer_unit_constituent_interactions_notcompleted]
  where interaction_status = 'Pending'
  ) t
  where t.row_earliest_pending_is_1 = 1

) earliest_pending on earliest_pending.constituent_system_id = b.CONSTITUENTSYSTEMID

  	/* LAGO Interactions/Moves (n=48k t=2sec)*/
	left join (

select t.constituent_system_id
	 , t.bio_lastcommafirstname
	 , t.latest_lago_interaction_date
	 , t.officer_name
	 , t.officer_system_id
	 , t.unit_name
	 , t.interaction_comment
	 , t.interaction_subcategory
     , t.interaction_category
     , t.interaction_type
  from (

SELECT [constituent_dim_id]
      ,[constituent_lookup_id]
      ,i.[constituent_system_id]
      ,[officer_dim_id]
      ,[officer_system_id]
      ,[bio_name]
      ,[bio_lastcommafirstname]
      --,[pm_ofcr_manage_status]
      --,[flag_ofcr_currently_managed]
      ,[officer_name]
      --,[unit_id]
      ,[unit_name]
      --,[position_order_desc]
      --,[flag_active_officer]
      --,[flag_use_in_fundraiser_reports]
      --,[officer_campus]
      --,[job_level]
      ,[interaction_subcategory]
      ,[interaction_category]
      ,[interaction_type]
      --,[flag_is_contact_report]
      --,[flag_is_interaction]
      --,[prospect_plan_dim_id]
      --,[plan_outline_step_dim_id]
      --,[prospect_plan_status_dim_id]
      --,[interaction_lookup_id]
      --,[interaction_objective]
      --,[flag_is_first_interaction]
      --,[flag_is_last_interaction]
      ,interaction_comment
      ,interaction_sequence
      ,interaction_actual_date
	  ,latest_lago_interaction_date
	  ,row_number() over (partition by i.constituent_system_id, i.interaction_actual_date 
							  order by i.interaction_type desc, i.interaction_sequence desc) 
		as interaction_row_hierarchy
  FROM DARanalytics.tableau.officer_unit_constituent_interactions_all i		--this is a table
  join (
		SELECT constituent_system_id
			 , max(interaction_actual_date)		as latest_lago_interaction_date
			 , max(interaction_sequence)		as largest_sequence
		  FROM DARanalytics.tableau.officer_unit_constituent_interactions_all		--this is a table
		 where officer_job_level = 'LAGO'
		   and interaction_status = 'Completed'
		 group by constituent_system_id
		  ) li on li.constituent_system_id = i.constituent_system_id
			  and li.latest_lago_interaction_date = i.interaction_actual_date
			--  and li.largest_sequence= i.interaction_sequence
    where interaction_status = 'Completed'
   ) t
 where interaction_row_hierarchy = 1

  --group by constituent_dim_id, constituent_lookup_id, constituent_system_id
  ) lago_moves on lago_moves.constituent_system_id = b.CONSTITUENTSYSTEMID

    	/* LAGO Interactions/Moves (n=59k t=2sec)*/
	left join (

select t.constituent_system_id
	 , t.bio_lastcommafirstname
	 , t.latest_not_lago_interaction_date
	 , t.officer_name
	 , t.officer_system_id
	 , t.unit_name
	 , t.interaction_comment
	 , t.interaction_subcategory
     , t.interaction_category
     , t.interaction_type
  from (

SELECT [constituent_dim_id]
      ,[constituent_lookup_id]
      ,i.[constituent_system_id]
      ,[officer_dim_id]
      ,[officer_system_id]
      ,[bio_name]
      ,[bio_lastcommafirstname]
      --,[pm_ofcr_manage_status]
      --,[flag_ofcr_currently_managed]
      ,[officer_name]
      --,[unit_id]
      ,[unit_name]
      --,[position_order_desc]
      --,[flag_active_officer]
      --,[flag_use_in_fundraiser_reports]
      --,[officer_campus]
      --,[job_level]
      ,[interaction_subcategory]
      ,[interaction_category]
      ,[interaction_type]
      --,[flag_is_contact_report]
      --,[flag_is_interaction]
      --,[prospect_plan_dim_id]
      --,[plan_outline_step_dim_id]
      --,[prospect_plan_status_dim_id]
      --,[interaction_lookup_id]
      --,[interaction_objective]
      --,[flag_is_first_interaction]
      --,[flag_is_last_interaction]
      ,interaction_comment
      ,interaction_sequence
      ,interaction_actual_date
	  ,li.latest_not_lago_interaction_date
	  ,row_number() over (partition by i.constituent_system_id, i.interaction_actual_date 
							  order by i.interaction_type desc, i.interaction_sequence desc) 
		as interaction_row_hierarchy
  FROM DARanalytics.tableau.officer_unit_constituent_interactions_all i  --this is a table
  join (
		SELECT constituent_system_id
			 , max(interaction_actual_date)		as latest_not_lago_interaction_date
			 , max(interaction_sequence)		as largest_sequence
		  FROM DARanalytics.tableau.officer_unit_constituent_interactions_all  --this is a table
		 where officer_job_level <> 'LAGO'
		   and interaction_status = 'Completed'
		 group by constituent_system_id
		  ) li on li.constituent_system_id = i.constituent_system_id
			  and li.latest_not_lago_interaction_date = i.interaction_actual_date
			--  and li.largest_sequence= i.interaction_sequence
    where interaction_status = 'Completed'
   ) t
 where interaction_row_hierarchy = 1

  --group by constituent_dim_id, constituent_lookup_id, constituent_system_id
  ) not_lago_moves on not_lago_moves.constituent_system_id = b.CONSTITUENTSYSTEMID


  /*Solicitations +/-365 days (n=1900 t=5sec)*/
  left join (
SELECT --[opp_fact_id]
      --,[opp_prospect_plan_dim_id]
       [constituent_dim_id]
      ,[constituent_lookup_id]
      ,[constituent_system_id]
      ,[constituent_fullname]
	  , 1 as flag_ask_rolling_365x2
	  , count(opp_ask_amount) as num_ask_rolling_365x2

	  , sum(opp_ask_amount) as sum_ask_rolling_365x2
	  , sum(case when opp_status= 'Qualified' then opp_expected_ask_amount else 0 end) as sum_expected_ask_rolling_365x2
	  , sum(opp_expected_ask_amount) as sum_both_ask_rolling_365x2


	  , min(opp_ask_amount) as min_opp_ask_amount_rolling_365x2
	  , max(opp_ask_amount) as max_opp_ask_amount_rolling_365x2
	  , case when max(opp_ask_amount)>=50000 then 'ask_50k_plus'
	         when max(opp_ask_amount)>=0 then 'ask_less_than_50k'
			 else NULL end as ask_range_rolling_365x2
	  , case when sum(opp_ask_amount)>=50000 then 'ask_50k_plus'
	         when sum(opp_ask_amount)>=0 then 'ask_less_than_50k'
			 else NULL end as ask_sum_range_rolling_365x2

	--  , sum(opp_expected_ask_amount) as sum_expected_ask_rolling_365x2

   /*   ,[officer_dim_id]
      ,[primary_fundraiser_dim_id]
      ,[officer_name]
      ,[officer_unit_id]
      ,[officer_unit_name]
      ,[fundraiser_name]
      ,[primary_fundraiser_name_full]
      ,[primary_fundraiser_name]
      ,[primary_fundraiser_unit_id]
      ,[primary_fundraiser_unit_name]
      ,[prospect_manager_name]
      ,[secondary_fundraiser_name]
      ,[opp_status]
      ,[opp_type]
      ,[opp_likelihood]
      ,[opp_expected_ask_amount]
      ,[opp_expected_ask_date]
      ,[opp_ask_amount]
      ,[opp_ask_date]
      ,[opp_amount]
      ,[opp_response_date]
      ,[opp_anticipated_funding_date]
      ,[opp_accepted_type_code]
      ,[opp_verbal_accept_date]
      ,[opp_document_accept_date]
      ,[opp_date_added]
      ,[opp_date_changed]
      ,[opp_prospect_plan_start_date]
      ,[opp_prospect_plan_name]
      ,[opp_prospect_plan_type]
      ,[opp_prospect_plan_status]
      ,[flag_prospect_plan_active]
	  */
  FROM [DARanalytics].[tableau].[opportunities_all]

  where opp_status not in ('Canceled')
    and (opp_ask_date between getdate()-365 and getdate()+365
	 or opp_expected_ask_date between getdate()-365 and getdate()+365
	 or opp_response_date between getdate()-365 and getdate()+365
	    )
 group by constituent_dim_id, constituent_lookup_id, constituent_system_id, constituent_fullname
 --order by constituent_fullname --sum_ask_rolling_365x2
 ) sols on sols.constituent_system_id = b.CONSTITUENTSYSTEMID

   /*Solicitations during campaign (n=5700 t=5sec)*/
  left join (
SELECT --[opp_fact_id]
      --,[opp_prospect_plan_dim_id]
       [constituent_dim_id]
      ,[constituent_lookup_id]
      ,[constituent_system_id]
      ,[constituent_fullname]
	  , 1 as flag_ask_campaign
	  , count(opp_ask_amount) as num_ask_campaign
	  , sum(opp_ask_amount) as sum_ask_campaign
	  , min(opp_ask_amount) as min_opp_ask_amount_campaign
	  , max(opp_ask_amount) as max_opp_ask_amount_campaign
	  , case when max(opp_ask_amount)>=50000 then 'ask_50k_plus'
	         when max(opp_ask_amount)>=0 then 'ask_less_than_50k'
			 else NULL end as ask_range_campaign
	  , case when sum(opp_ask_amount)>=50000 then 'ask_50k_plus'
	         when sum(opp_ask_amount)>=0 then 'ask_less_than_50k'
			 else NULL end as ask_sum_range_campaign
	  , sum(case when datediff(day,opp_document_accept_date,getdate()) between 0 and 1825 then opp_ask_amount else 0 end) as sum_documented_accepted_ask_last1825



   /*   ,[officer_dim_id]
      ,[primary_fundraiser_dim_id]
      ,[officer_name]
      ,[officer_unit_id]
      ,[officer_unit_name]
      ,[fundraiser_name]
      ,[primary_fundraiser_name_full]
      ,[primary_fundraiser_name]
      ,[primary_fundraiser_unit_id]
      ,[primary_fundraiser_unit_name]
      ,[prospect_manager_name]
      ,[secondary_fundraiser_name]
      ,[opp_status]
      ,[opp_type]
      ,[opp_likelihood]
      ,[opp_expected_ask_amount]
      ,[opp_expected_ask_date]
      ,[opp_ask_amount]
      ,[opp_ask_date]
      ,[opp_amount]
      ,[opp_response_date]
      ,[opp_anticipated_funding_date]
      ,[opp_accepted_type_code]
      ,[opp_verbal_accept_date]
      ,[opp_document_accept_date]
      ,[opp_date_added]
      ,[opp_date_changed]
      ,[opp_prospect_plan_start_date]
      ,[opp_prospect_plan_name]
      ,[opp_prospect_plan_type]
      ,[opp_prospect_plan_status]
      ,[flag_prospect_plan_active]
	  */
  FROM [DARanalytics].[tableau].[opportunities_all]

  where opp_status not in ('Canceled')
    and (opp_ask_date between '2020-07-01' and '2030-06-30'
	 or opp_expected_ask_date between '2020-07-01' and '2030-06-30'
	 or opp_response_date between '2020-07-01' and '2030-06-30'
	 or opp_document_accept_date between '2020-07-01' and '2030-06-30'
	 or opp_verbal_accept_date between '2020-07-01' and '2030-06-30'
	    )
 group by constituent_dim_id, constituent_lookup_id, constituent_system_id, constituent_fullname
 ) sols_campaign on sols_campaign.constituent_system_id = b.CONSTITUENTSYSTEMID

   /*Solicitations for stages (n=11k t=1sec)*/
  left join (

select t.constituent_dim_id
     , t.constituent_lookup_id
     , t.constituent_system_id
	 , t.household_id
   --  , oa.constituent_fullname
	 -- , opp_prospect_plan_dim_id
	  ,max(case when t.opp_status = 'Qualified' and datediff(day, getdate(),t.opp_expected_ask_date) between 0 and 90  then 1 else 0 end)		as flag_opp_recent_qualified
	  ,max(case when t.opp_status = 'Qualified' and datediff(day, getdate(),t.opp_expected_ask_date) > 90  then 1 else 0 end)					as flag_opp_farfuture_qualified
	  ,max(case when t.opp_status = 'Qualified' and datediff(day, getdate(),t.opp_expected_ask_date) < 0  then 1 else 0 end)					as flag_opp_past_qualified
	  ,max(case when t.opp_status = 'Response pending' then 1 else 0 end)																		as flag_opp_response_pending
	  ,max(case when t.opp_verbal_accept_date is not null and t.opp_status in ('Qualified','Response Pending') then 1 else 0 end)				as flag_opp_verbal_accept
	  ,max(case when t.opp_status = 'Accepted' and datediff(day, t.opp_document_accept_date,getdate()) between 0 and 30 then 1 else 0 end)		as flag_opp_recent_doc_accept
	  ,max(case when t.opp_status = 'Accepted' and datediff(day, t.opp_document_accept_date,getdate()) between 31 and 730 then 1 else 0 end)	as flag_opp_steward_doc_accept
	  ,max(case when t.opp_status = 'Accepted' and datediff(day, t.opp_document_accept_date,getdate()) between 731 and 1825 then 1 else 0 end)	as flag_opp_2_5yrs_doc_accept  --changed to 2-5 years on 7/26/24
	  ,max(case when t.opp_status = 'Accepted' and datediff(day, t.opp_document_accept_date,getdate()) > 1825 then 1 else 0 end)				as flag_opp_old_doc_accept     --changed to 5+ years on 7/26/24
	  ,max(t.opp_system_id) as 	 opp_system_id

   from (
   --main opportunity constituents
SELECT oa.constituent_dim_id
     , oa.constituent_lookup_id
     , oa.constituent_system_id
	 , oa.household_id
	 , oa.opp_status
	 , oa.opp_expected_ask_date
	 , oa.opp_verbal_accept_date
	 , oa.opp_document_accept_date
	 , oa.opp_system_id
	 , oa.constituent_lookup_id  as main_constituent_lookup_id
	 , oa.opp_prospect_plan_name

  FROM DARanalytics.tableau.opportunities_all oa
  --where oa.constituent_lookup_id = '8-10350323' and oa.opp_status = 'Qualified' and datediff(day, getdate(),oa.opp_expected_ask_date) < 0

  union 

  --828 plan participants (1800 once we remove the 'No Plan Participant Role')
SELECT pp.plan_participant_constituent_dim_id		as constituent_dim_id
     , pp.plan_participant_constituent_lookup_id	as constituent_lookup_id
     , pp.plan_participant_constituent_system_id	as constituent_system_id
	 , pp.household_id
	 , oa.opp_status
	 , oa.opp_expected_ask_date
	 , oa.opp_verbal_accept_date
	 , oa.opp_document_accept_date
	 , oa.opp_system_id
	 , oa.constituent_lookup_id  as main_constituent_lookup_id
	 , oa.opp_prospect_plan_name
  
  FROM DARanalytics.tableau.opportunities_all oa
  left join (SELECT dpp.PROSPECTPLANDIMID
				  , dpp.CONSTITUENTDIMID		as plan_participant_constituent_dim_id
				  , dpp.CONSTITUENTSYSTEMID		as plan_participant_constituent_system_id
				  , dpp.PLANPARTICIPANTROLE		as plan_participant_role
				  , pp.PROSPECTPLANNAME
				  , cl.constituent_lookup_id	as plan_participant_constituent_lookup_id
				  , cl.household_id

			   FROM BBCRM_PROD_RPT_BBDW.BBDW.DIM_PLANPARTICIPANT dpp
		  left join BBCRM_PROD_RPT_BBDW.BBDW.DIM_PROSPECTPLAN pp on pp.prospectplandimid = dpp.PROSPECTPLANDIMID
		  left join DARanalytics.datamart.constituent_level cl on cl.constituent_system_id = dpp.CONSTITUENTSYSTEMID
			  where dpp.planparticipantrole in ('Decision maker') --,'Key Influencer') --,'No Plan Participant Role')
				and	cl.constituent_lookup_id is not null -- dpp.CONSTITUENTDIMID in ('705843','705844')
			) pp on pp.PROSPECTPLANDIMID = oa.opp_prospect_plan_dim_id
  where pp.plan_participant_constituent_system_id is not null
--  and pp.plan_participant_constituent_lookup_id = '8-10350323' and oa.opp_status = 'Qualified' and datediff(day, getdate(),oa.opp_expected_ask_date) < 0
 
  ) t 
   group by t.constituent_dim_id, t.constituent_lookup_id, t.constituent_system_id, t.household_id

 ) sols_staging on sols_staging.constituent_system_id = b.CONSTITUENTSYSTEMID

 /* standard names (n=697k t=15sec)*/
left join (  SELECT CONSTITUENTSYSTEMID
				  , max(case when nameformattype = 'VCU Standard Joint Addressee' then NAME else null end) as bio_name_VCU_Standard_Joint
				  , max(case when nameformattype = 'VCU Standard Individual Addressee' then NAME else null end) as bio_name_VCU_Standard_Individual
			   FROM BBCRM_PROD_RPT_BBDW.BBDW.VCU_CONSTITUENTNAMEFORMATS
			  WHERE nameformattype in ('VCU Standard Joint Addressee','VCU Standard Individual Addressee')
			  GROUP BY CONSTITUENTSYSTEMID
          ) names on names.CONSTITUENTSYSTEMID = b.CONSTITUENTSYSTEMID

	
/* primary address information (n=640k t=13sec) */
	left join (
			  SELECT distinct 
					 CONSTITUENTADDRESSDIMID
				   , CONSTITUENTSYSTEMID
				   , LATITUDE
				   , LONGITUDE

				FROM DARanalytics.geo.addresses_current
			   WHERE ISPRIMARY = 1
			) addr on addr.CONSTITUENTADDRESSDIMID = dimc.CONSTITUENTADDRESSDIMID
				  and addr.CONSTITUENTSYSTEMID = dimc.CONSTITUENTSYSTEMID
	
   /* Address flag for whether or not constituent has a certain type of address  (n=640k t=11sec)*/
   left join (
			SELECT CONSTITUENTSYSTEMID
				 , max(case when CONSTITUENTADDRESSTYPE in ('Identified Property','Seasonal Home') then 1 else 0 end) as flag_has_identified_seasonal_property

			  FROM DARanalytics.geo.addresses_current a
		  group by a.CONSTITUENTSYSTEMID
		  ) addr2 on addr2.CONSTITUENTSYSTEMID = b.CONSTITUENTSYSTEMID


	/* Any change to all addresses - data is problematic  (n=696k t=11sec)*/
	left join (
			select constituentsystemid
				 , CONSTITUENTDIMID
			--	 , max(historicalstartdate) as latest_start_date
			--	 , max(historicalenddate) as latest_end_date
				 , (select max(v) from (values (max(historicalstartdate)), (max(historicalenddate))) as value(v)) as latest_address_change_date  --this problaby could be better 
			  from BBCRM_PROD_RPT_BBDW.BBDW.FACT_CONSTITUENTADDRESS
			 group by constituentsystemid, CONSTITUENTDIMID
			 ) addr_chnge on addr_chnge.CONSTITUENTSYSTEMID = b.CONSTITUENTSYSTEMID

   /*Ugrad Reunion Class (n=1820 t=1sec)*/
	
	/* Committee group codes -- events, gift clubs, committees. 
	   For some reason there are a fair number of people with NULL start dates on these so we throw in 1959-12-31 as an obvious default.  
	   Gonna party like its 1959
	*/
	left join ( 

	select constituent_dim_id
	     , constituent_system_id
         , 1 as flag_committee_member_current
		 , max(case when board_group_type like '%board%' then 1 else 0 end)	 as flag_board_member_current
		 , max(case when flag_is_board_primary = 1 then 1 else 0 end)	 as flag_board_primary_member_current
		 , max(isnull(start_date,'1959-12-31')) as latest_committee_start_date
		 , min(isnull(start_date,'1959-12-31')) as earliest_committee_start_date
		 , max(case when board_group_type like '%board%' then isnull(start_date,'1959-12-31') else null end) as latest_board_start_date
		 , min(case when board_group_type like '%board%' then isnull(start_date,'1959-12-31') else null end) as earliest_board_start_date
		 , max(case when flag_is_board_primary = 1 then isnull(start_date,'1959-12-31') else null end) as latest_board_primary_start_date
		 , min(case when flag_is_board_primary = 1 then isnull(start_date,'1959-12-31') else null end) as earliest_board_primary_start_date
 		 , max(case when rownum = 1 then board_description + ' ' + '(' + convert(nvarchar(4),year(isnull(start_date,'1959-12-31'))) + ')' else null end)
     	  +max(case when rownum = 2 then isnull('; ' + board_description + ' (' + convert(nvarchar(4),year(isnull(start_date,'1959-12-31'))) + ')','') else '' end)
      	  +max(case when rownum = 3 then isnull('; ' + board_description + ' (' + convert(nvarchar(4),year(isnull(start_date,'1959-12-31'))) + ')','') else '' end) as latest_committees_current

      	 , max(case when board_group_type like '%board%' and rownum = 1 then board_description + ' ' + '(' + convert(nvarchar(4),year(isnull(start_date,'1959-12-31'))) + ')' else null end)
      	  +max(case when board_group_type like '%board%' and rownum = 2 then isnull('; ' + board_description + ' (' + convert(nvarchar(4),year(isnull(start_date,'1959-12-31'))) + ')','') else '' end)
      	  +max(case when board_group_type like '%board%' and rownum = 3 then isnull('; ' + board_description + ' (' + convert(nvarchar(4),year(isnull(start_date,'1959-12-31'))) + ')','') else '' end) as latest_boards_current

 from (
SELECT campw.constituent_group_dim_id
      ,campw.board_description
	  ,campw.constituent_group_lookup_id
	  ,campw.flag_is_board_primary			--this list of boards comes from PD and is their list they make sure the members are correct every Aug
      ,campw.board_group_type
      ,campw.constituent_dim_id
	  ,campw.constituent_system_id
	  ,campw.bio_name
	  ,campw.constituent_group_system_id
	  ,campw.start_date
	  ,campw.end_date
	  ,row_number() over ( 
      				partition by
      					campw.constituent_system_id
      				order by
      					 campw.end_date desc
      					,campw.start_date desc
      					,case when isnull(campw.board_DESCRIPTION,'') <> '' then campw.board_description
							  else campw.constituent_group_name
							   end ) as rownum

  FROM DARanalytics.ref.committees_member_prework campw
  														
  WHERE (campw.board_group_type like '%Board%' or campw.board_group_type like '%giving circle%')   -- gets rid of Presidential Leadership Donors and ICA group
	  and isnull(campw.end_date,'2099-12-31') >= getdate()		--current members only
	 -- and fcgm.MEMBERCONSTITUENTSYSTEMID is not NULL

 ) committee

 group by constituent_system_id, constituent_dim_id

 ) committees on committees.constituent_system_id = b.CONSTITUENTSYSTEMID

	/*contact information (n=600k t=11sec) */
 left join (
		   select constituentdimid
			    , max(VALIDPHONE)	as flag_cntc_valid_phone
			    , max(VALIDEMAIL)	as flag_cntc_valid_email
			    , max(VALIDMAIL)	as flag_cntc_valid_mail
			    , max(HBONE)		as flag_cntc_hbone
			    , max(ENGAGEDEMAIL)	as flag_cntc_engaged_email
			 from BBCRM_PROD_RPT_BBDW.BBDW.VCU_RPT_UNITMARKETING
			group by CONSTITUENTDIMID
  ) valid on valid.CONSTITUENTDIMID = b.CONSTITUENTDIMID


/* Prospect Plans (n=4k t=1sec) */
		left join (
			SELECT  count(*) as num_active_prospect_plans
				  , pp.CONSTITUENTSYSTEMID
				  , min(convert(date,ppe.PROSPECTPLANSTARTDATE)) as prospect_plan_active_earliest_start_date
				  , max(convert(date,ppe.PROSPECTPLANSTARTDATE)) as prospect_plan_active_latest_start_date
			  /*  ,CONSTITUENTDIMID
				  ,PROSPECTSTATUS
				  ,RESEARCHSTATUSCONFIRMED
				  ,PROSPECTPLANNAME
				  ,PROSPECTPLANSTATUS
				  ,PROSPECTPLANTYPE
				  ,PROSPECTMANAGERFUNDRAISERDIMID
				  ,PRIMARYFUNDRAISERDIMID
				  ,SECONDARYFUNDRAISERDIMID
				  ,PRIMARYFUNDRAISERSTARTDATE
				  ,PRIMARYFUNDRAISERSTARTDATEDIMID
				  ,PRIMARYFUNDRAISERENDDATE
				  ,PRIMARYFUNDRAISERENDDATEDIMID
				  ,SECONDARYFUNDRAISERSTARTDATE
				  ,SECONDARYFUNDRAISERSTARTDATEDIMID
				  ,SECONDARYFUNDRAISERENDDATE
				  ,SECONDARYFUNDRAISERENDDATEDIMID
				  ,NARRATIVE
				  ,PROSPECTPLANISACTIVE
				  ,ISINCLUDED
				  ,ETLCONTROLID
				  ,SOURCEDIMID
				  ,PRIMARYFUNDRAISERSYSTEMID
				  ,SECONDARYFUNDRAISERSYSTEMID
				*/  
			  FROM BBCRM_PROD_RPT_BBDW.BBDW.DIM_PROSPECTPLAN pp
			  left join BBCRM_PROD_RPT_BBDW.BBDW.VCU_DIM_PROSPECTPLAN_EXT ppe on ppe.PROSPECTPLANSYSTEMID = pp.PROSPECTPLANSYSTEMID
			 -- left join BBCRM_PROD_RPT_BBDW.BBDW.VCU_RPT_CONSTITUENTLIST c on c.CONSTITUENTSYSTEMID = pp.CONSTITUENTSYSTEMID
			 -- left join DARanalytics.ref.gift_officer_info goi on goi.officer_system_id = pp.PRIMARYFUNDRAISERSYSTEMID
			 --												  and goi.position_order_desc = 1
			  where PROSPECTPLANISACTIVE = 1
				--and prospectstatus = 'assigned' 
				group by pp.constituentsystemid
		  ) pp on pp.CONSTITUENTSYSTEMID = b.CONSTITUENTSYSTEMID

	
	/* Flag for Retired VCU Faculty/Staff  - some people have more than 1 column without the group by (n=25k t=1sec)*/
  left join (
                SELECT CONSTITUENTDIMID
					 , CONSTITUENTSYSTEMID
					 , CONSTITUENTLOOKUPID
					 , max(case when employeetype = 'Retiree' then 1 else 0 end)  as flag_vcu_facstaff_retired
					 , max(case when employeetype <> 'Retiree' then 1 else 0 end) as flag_vcu_facstaff_current

				  FROM BBCRM_PROD_RPT_BBDW.BBDW.VCU_RPT_FACULTYSTAFF_CURRENT
				 GROUP BY   CONSTITUENTDIMID
						  , CONSTITUENTSYSTEMID
						  , CONSTITUENTLOOKUPID
		) vcu_facstaff on vcu_facstaff.CONSTITUENTSYSTEMID = b.CONSTITUENTSYSTEMID

  
  /* Recognition Societies (n=34k t=1sec) */
  left join (
			 select --count(*) as cnt   --there are some duplicates in this table - ignoring for now - not in the legacy societies
				   rs.CONSTITUENTSYSTEMID
				 , rs.CONSTITUENTDIMID
				 , c.CONSTITUENTLOOKUPID
				-- , recognitionprogram
				 , max(case when enddate is null and RECOGNITIONPROGRAM = 'Founders'' Society' then 1 else 0 end) as flag_rp_foundersociety
				 , max(case when enddate is null and RECOGNITIONPROGRAM = 'Heritage Society' then 1 else 0 end) as flag_rp_heritagesociety
				 , max(case when enddate is null and RECOGNITIONPROGRAM = 'Massey Lawrence Society' then 1 else 0 end) as flag_rp_masseylawrencesociety
				 , max(case when enddate is null and RECOGNITIONPROGRAM = 'MCV Society' then 1 else 0 end) as flag_rp_MCVsociety
				 , max(case when enddate is null and RECOGNITIONPROGRAM in ('Heritage Society', 'Massey Lawrence Society', 'MCV Society') then 1 else 0 end) as flag_rp_legacysociety

				 , min(case when enddate is null and RECOGNITIONPROGRAM = 'Founders'' Society' then startdate else NULL end) as rp_startdate_foundersociety
				 , min(case when enddate is null and RECOGNITIONPROGRAM = 'Heritage Society' then startdate else NULL end) as rp_startdate_heritagesociety
				 , min(case when enddate is null and RECOGNITIONPROGRAM = 'Massey Lawrence Society' then startdate else NULL end) as rp_startdate_masseylawrencesociety
				 , min(case when enddate is null and RECOGNITIONPROGRAM = 'MCV Society' then startdate else NULL end) as rp_startdate_MCVsociety
				 , min(case when enddate is null and RECOGNITIONPROGRAM in ('Heritage Society', 'Massey Lawrence Society', 'MCV Society') then startdate else NULL end) as rp_startdate_legacysociety
				 , min(case when enddate is null and RECOGNITIONPROGRAM in ('Heritage Society', 'Massey Lawrence Society', 'MCV Society') then year(dateadd(month,6,startdate)) else NULL end) as rp_startFY_legacysociety
				 , min(case when enddate is null and RECOGNITIONPROGRAM in ('Heritage Society', 'Massey Lawrence Society', 'MCV Society') then (case when month(startdate) >=10 then 2
																																					when month(startdate) >=7 then 1
																																					when month(startdate) >=4 then 4
																																					when month(startdate) >=1 then 3
																																					else NULL end)
																																		  else NULL end) as rp_startqtr_legacysociety

				 , max(case when rs.fiscalyear=year(dateadd(month,6,getdate())) and rs.RECOGNITIONPROGRAM not in ('Founders'' Society', 'Heritage Society', 'Massey Lawrence Society', 'MCV Society') then 1 else 0 end) as flag_rp_atleastone_currentFY
				 , max(case when rs.RECOGNITIONPROGRAM not in ('Founders'' Society', 'Heritage Society', 'Massey Lawrence Society', 'MCV Society') then 1 else 0 end) as flag_rp_atleastone_ever
				 , max(case when rs.RECOGNITIONPROGRAMID = 'B0FE18FD-75A7-4940-BF10-19FE3423FD34'   --'Black & Gold Loyalty Society'
							 and ( dateadd(day,25,rs.ENDDATE) >= getdate()		--account for a 3 week delay in adding the next crop of names; better way?
							  or   year(dateadd(month,6,getdate())) = rs.fiscalyear 
							  )
							 then 1 else 0 end) as flag_black_and_gold_loyalty_society  
				 , max(case when rs.RECOGNITIONPROGRAMID = '2F9FE07C-497D-4B8E-92A0-F60B8B92DB95'   -- 'Presidents Club'
							 and ( dateadd(day,25,rs.ENDDATE) >= getdate()		--account for a 3 week delay in adding the next crop of names; better way?
							  or   year(dateadd(month,6,getdate())) = rs.fiscalyear 
							  )
							 then 1 else 0 end) as flag_presidents_club_society

			from BBCRM_PROD_RPT_BBDW.BBDW.VCU_FACT_CONSTITUENTRECOGNITIONSOCIETIES rs
			left join BBCRM_PROD_RPT_BBDW.BBDW.DIM_CONSTITUENT c on c.CONSTITUENTSYSTEMID = rs.CONSTITUENTSYSTEMID
			group by rs.CONSTITUENTSYSTEMID, rs.CONSTITUENTDIMID, c.CONSTITUENTLOOKUPID--, recognitionprogram

		) rs on rs.CONSTITUENTSYSTEMID = b.CONSTITUENTSYSTEMID
 
  /* Next Gen Philanthropy flag  */
 
  /* Radar User flag*/
	left join (
			SELECT user_dim_id
			  ,user_system_id
			  ,user_lookup_id
			  ,user_name
			  ,user_auth_name
			  ,date_from
			  ,date_to
			  ,flag_active_radar_user
			  ,job_title
			  ,unit_id
			  ,unit_name
			  ,unit_name_short
			  ,officer_campus
			  ,officer_campus_new
			  ,job_role
			  ,job_level
			  ,z_last_update
		  FROM DARanalytics.ref.radar_user_info
   ) radar on radar.user_system_id = b.CONSTITUENTSYSTEMID

  /* International Pool Flag */
 
   /* Volunteerism  replaced by vol_vol code on 8/6/26*/
	--left join (
	--			select distinct CONSTITUENTSYSTEMID
	--				 , 1 as flag_is_volunteer

	--			  from BBCRM_PROD_RPT_BBDW.BBDW.FACT_CONSTITUENCY fc
	--		 left join BBCRM_PROD_RPT_BBDW.BBDW.DIM_CONSTITUENCY dc on fc.CONSTITUENCYDIMID=dc.CONSTITUENCYDIMID

	--			 where isnull(todate,'2099-12-31') > getdate()
	--			   and dc.CONSTITUENCYCODESYSTEMID = 'e7489703-3d63-4017-a2bc-88c092563c5d'
	--		  ) vol on vol.CONSTITUENTSYSTEMID = b.CONSTITUENTSYSTEMID


  /* Relationship Count */
   left join ( /****** Script for SelectTopNRows command from SSMS  ******/
SELECT  r.CONSTITUENTDIMID
     , r.CONSTITUENTSYSTEMID
	 , c.CONSTITUENTLOOKUPID
	 , c.FULLNAME
     , count(distinct case when c2.ISINDIVIDUAL = 1 then RECIPROCALCONSTITUENTSYSTEMID else NULL end) as	num_relationships_individuals  --and c2.ISDECEASED=0
	--  CONSTITUENTRELATIONSHIPFACTID
	-- ,CONSTITUENTRELATIONSHIPSYSTEMID
	-- ,CONSTITUENTRELATIONSHIPSETDIMID
	-- ,rt.CONSTITUENTRELATIONSHIPTYPE
    -- ,r.CONSTITUENTRELATIONSHIPTYPEDIMID
    -- ,RECIPROCALCONSTITUENTDIMID
    -- ,RECIPROCALCONSTITUENTRELATIONSHIPTYPEDIMID
    -- ,CONSTITUENTRELATIONSHIPFLAGDIMID
    -- ,CONTACTTYPEDIMID
    -- ,STARTDATEDIMID
    -- ,STARTDATE
    -- ,ENDDATEDIMID
	-- ,ENDDATE
    -- ,POSITION
 
  FROM BBCRM_PROD_RPT_BBDW.BBDW.FACT_CONSTITUENTRELATIONSHIP r
  join BBCRM_PROD_RPT_BBDW.BBDW.VCU_RPT_CONSTITUENTLIST c on c.CONSTITUENTSYSTEMID = r.CONSTITUENTSYSTEMID
  left join BBCRM_PROD_RPT_BBDW.BBDW.VCU_RPT_CONSTITUENTLIST c2 on c2.constituentsystemid = r.RECIPROCALCONSTITUENTSYSTEMID
  left join BBCRM_PROD_RPT_BBDW.BBDW.DIM_CONSTITUENTRELATIONSHIPTYPE rt on rt.CONSTITUENTRELATIONSHIPTYPEDIMID = r.CONSTITUENTRELATIONSHIPTYPEDIMID
  where getdate() between isnull(r.startdate,'2000-01-01') and isnull(r.enddate,'2099-12-31')
    and rt.ISACTIVE = 1
	and c.ISINDIVIDUAL = 1
	and (c2.ISALUMNI = 1 or c2.LIFETIMEGIVINGOVERALL>=50000)		--people we care about counting
	--and rt.CONSTITUENTRELATIONSHIPTYPE not in ('Child','Parent','Step-Parent','Spouse','Unknown')
	group by r.CONSTITUENTSYSTEMID, r.CONSTITUENTDIMID, c.fullname, c.constituentlookupid
	) rel_cnt on rel_cnt.CONSTITUENTSYSTEMID = b.CONSTITUENTSYSTEMID

/* Relationship Count New  - need to straighten these up a bit - confusing field names*/
   left join ( /****** Script for SelectTopNRows command from SSMS  ******/
SELECT  r.CONSTITUENTDIMID
     , r.CONSTITUENTSYSTEMID
	 , c.CONSTITUENTLOOKUPID
	 , c.FULLNAME
     , count(distinct case when c2.ISINDIVIDUAL = 1 then RECIPROCALCONSTITUENTSYSTEMID else NULL end) as	num_alumni_relationships_individuals  --and c2.ISDECEASED=0
	--  CONSTITUENTRELATIONSHIPFACTID
	-- ,CONSTITUENTRELATIONSHIPSYSTEMID
	-- ,CONSTITUENTRELATIONSHIPSETDIMID
	-- ,rt.CONSTITUENTRELATIONSHIPTYPE
    -- ,r.CONSTITUENTRELATIONSHIPTYPEDIMID
    -- ,RECIPROCALCONSTITUENTDIMID
    -- ,RECIPROCALCONSTITUENTRELATIONSHIPTYPEDIMID
    -- ,CONSTITUENTRELATIONSHIPFLAGDIMID
    -- ,CONTACTTYPEDIMID
    -- ,STARTDATEDIMID
    -- ,STARTDATE
    -- ,ENDDATEDIMID
	-- ,ENDDATE
    -- ,POSITION
 
  FROM BBCRM_PROD_RPT_BBDW.BBDW.FACT_CONSTITUENTRELATIONSHIP r
  join BBCRM_PROD_RPT_BBDW.BBDW.VCU_RPT_CONSTITUENTLIST c on c.CONSTITUENTSYSTEMID = r.CONSTITUENTSYSTEMID
  left join BBCRM_PROD_RPT_BBDW.BBDW.VCU_RPT_CONSTITUENTLIST c2 on c2.constituentsystemid = r.RECIPROCALCONSTITUENTSYSTEMID
  left join BBCRM_PROD_RPT_BBDW.BBDW.DIM_CONSTITUENTRELATIONSHIPTYPE rt on rt.CONSTITUENTRELATIONSHIPTYPEDIMID = r.CONSTITUENTRELATIONSHIPTYPEDIMID
  where getdate() between isnull(r.startdate,'2000-01-01') and isnull(r.enddate,'2099-12-31')
    and rt.ISACTIVE = 1
	and c.ISINDIVIDUAL = 1
	and (c2.ISALUMNI = 1)		--people we care about counting
	--and rt.CONSTITUENTRELATIONSHIPTYPE not in ('Child','Parent','Step-Parent','Spouse','Unknown')
	group by r.CONSTITUENTSYSTEMID, r.CONSTITUENTDIMID, c.fullname, c.constituentlookupid
	) rel_cnt2 on rel_cnt2.CONSTITUENTSYSTEMID = b.CONSTITUENTSYSTEMID

 
   /* Citizenship based off Attribute Data*/
   left join (

SELECT t.CONSTITUENTDIMID
      ,t.CONSTITUENTSYSTEMID
      ,max(case when t.czn_order = 1 then t.ATTRIBUTEVALUE else NULL end) as bio_citizenship1
	  ,max(case when t.czn_order = 2 then t.ATTRIBUTEVALUE else NULL end) as bio_citizenship2
  FROM (
SELECT fca.CONSTITUENTDIMID
      ,fca.CONSTITUENTSYSTEMID
      ,case when fca.ATTRIBUTEVALUE = 'Korea - South' then 'South Korea' else fca.ATTRIBUTEVALUE end as ATTRIBUTEVALUE
	  ,row_number() over (partition by fca.CONSTITUENTSYSTEMID
	                      order by fca.ATTRIBUTESTARTDATE, fca.ATTRIBUTEDIMID) as czn_order
	--  ,fca.CONSTITUENTATTRIBUTEFACTID
    --  ,fca.CONSTITUENTATTRIBUTESYSTEMID
    --  ,fca.ATTRIBUTEDIMID
    --  ,fca.ATTRIBUTESYSTEMID
    --  ,fca.ATTRIBUTEVALUESYSTEMID
    --  ,fca.ATTRIBUTESTARTDATEDIMID
    --  ,fca.ATTRIBUTESTARTDATE
    --  ,fca.ATTRIBUTEENDDATEDIMID
    --  ,fca.ATTRIBUTEENDDATE
    --  ,fca.ATTRIBUTEISCURRENT
    --  ,fca.ISINCLUDED

  FROM BBCRM_PROD_RPT_BBDW.BBDW.FACT_CONSTITUENTATTRIBUTE fca
  join BBCRM_PROD_RPT_BBDW.BBDW.DIM_ATTRIBUTE da on da.ATTRIBUTEDIMID = fca.ATTRIBUTEDIMID
												and da.attributecategorysystemid = '7F77EB92-292D-42CF-A6EE-28931AB7DEEA'  --attributename = 'Citizenship Country'
 WHERE da.attributevaluesystemid <> '00000000-0000-0000-0000-000000000000'  --don't need missing citizenships
   and fca.attributeiscurrent = 1
     ) t
	 GROUP BY t.CONSTITUENTDIMID, t.CONSTITUENTSYSTEMID
  ) czn on czn.CONSTITUENTSYSTEMID = b.CONSTITUENTSYSTEMID

   /* Educational Involvement */
   left join (
   SELECT count(*) as cnt_educational_involvements 
        , CONSTITUENTDIMID
        , CONSTITUENTSYSTEMID
    --  , EDUCATIONALINVOLVEMENTTYPEDESCRIPTION
    --  , EDUCATIONALINVOLVEMENTNAME 
     FROM BBCRM_PROD_RPT_BBDW.BBDW.DIM_EDUCATIONALINVOLVEMENT
    where EDUCATIONALINVOLVEMENTTYPEDESCRIPTION in (
		--'Activities Programming Board Leader'
		--,'Alumni'
		--,'American Nuclear Society'
		 'Aspire'
		,'Athletics'
		,'Business Student Ambassador'
		,'Club Sports'
		--,'Commons Student Worker'
		,'Emerging Leader'
		--,'Focused Inquiry Teaching Assistant'
		--,'Formula SAE'
		,'Fraternity & Sorority Life'
		,'Fraternity & Sorority Presidents'
		,'Globe'
		,'Honors'
		,'Lavender Graduate'
		--,'Library Student Worker'
		,'Living Learning Community Members'
		,'MCV SGA'
		,'MCV Student Leader'
		,'MD-PhD Program'
		,'Media'
		,'Mentorship Program - Graduate School'
		,'MPC SGA'
		,'New Student and Family Programs'
		,'Orientation Leader'
		,'Other Student Clubs/Organizations'
		--,'Preparing Future Faculty Program'
		,'Rams in Recovery'
		,'Recreational Sports'
		,'Resident Assistant'
		,'Residential Life & Housing'
		,'RL&H Student/Peer Leader'
		,'Scholar/Endow/Intern/Stipend Recipient'
		,'Society of Women Engineers'
		,'STAT Student Leader'
		,'Study Abroad'
		,'USC&A'
		,'VCU LEAD')
 group by CONSTITUENTDIMID, CONSTITUENTSYSTEMID
			) ed_involve on ed_involve.CONSTITUENTSYSTEMID = b.CONSTITUENTSYSTEMID
  
   /*Children of parents */
left join ( SELECT count(*) as num_living_children_in_radar
				 , RECIPROCALCONSTITUENTSYSTEMID as constituent_system_id
				 , RECIPROCALCONSTITUENTDIMID  as constituent_dim_id
				 , parent_lookup_id  as constituent_lookup_id
			  FROM (
					SELECT CONSTITUENTRELATIONSHIPFACTID
						  ,CONSTITUENTRELATIONSHIPSYSTEMID
						  ,CONSTITUENTRELATIONSHIPSETDIMID
						  ,f.CONSTITUENTDIMID
						  ,f.CONSTITUENTSYSTEMID
						  ,dc.CONSTITUENTLOOKUPID  as child_lookup_id
						  ,dc2.CONSTITUENTLOOKUPID as parent_lookup_id
						  ,f.CONSTITUENTRELATIONSHIPTYPEDIMID
						  ,RECIPROCALCONSTITUENTDIMID
						  ,RECIPROCALCONSTITUENTSYSTEMID
						  ,RECIPROCALCONSTITUENTRELATIONSHIPTYPEDIMID
						  ,CONSTITUENTRELATIONSHIPFLAGDIMID
						  ,CONTACTTYPEDIMID
						  ,STARTDATEDIMID
						  ,STARTDATE
						  ,ENDDATEDIMID
						  ,ENDDATE
						  ,POSITION

					  FROM BBCRM_PROD_RPT_BBDW.BBDW.FACT_CONSTITUENTRELATIONSHIP f
					    left join BBCRM_PROD_RPT_BBDW.BBDW.DIM_CONSTITUENTRELATIONSHIPTYPE rt on rt.CONSTITUENTRELATIONSHIPTYPEDIMID = f.CONSTITUENTRELATIONSHIPTYPEDIMID
					    left join BBCRM_PROD_RPT_BBDW.BBDW.DIM_CONSTITUENT dc on dc.CONSTITUENTSYSTEMID = f.CONSTITUENTSYSTEMID
						left join BBCRM_PROD_RPT_BBDW.BBDW.DIM_CONSTITUENT dc2 on dc2.CONSTITUENTSYSTEMID = f.RECIPROCALCONSTITUENTSYSTEMID
					  where rt.CONSTITUENTRELATIONSHIPTYPESYSTEMID = '75DCE64A-8FFE-45EF-87C3-F3FAC5E10F02'  --this could be expanded to include step, god-children, grandchildren etc...  BBCRM_PROD_RPT_BBDW.BBDW.DIM_CONSTITUENTRELATIONSHIPTYPE
						and dc.ISACTIVE = 1
						and dc.ISDECEASED = 0
				) t
				group by RECIPROCALCONSTITUENTSYSTEMID, RECIPROCALCONSTITUENTDIMID, parent_lookup_id
				--order by num_living_children_in_radar
	) kids on kids.constituent_system_id = b.CONSTITUENTSYSTEMID

   /*Parents via vChild Attribute to account for new parents not yet flagged as Parent Constituents */
   left join (
				select CONSTITUENTSYSTEMID
					 , max(pm_vchild_start_date)	as pm_parent_vchild_latest_start_date
					 , max(pm_flag_has_vchild)		as flag_parent_has_vchild
				  from (
							select CONSTITUENTSYSTEMID
								 , case when ATTRIBUTESYSTEMID = '473fca33-d6b1-4ffc-a066-9bc91a1bbae5' then ATTRIBUTESTARTDATE else NULL end as pm_vchild_start_date
								 , case when ATTRIBUTESYSTEMID = '473fca33-d6b1-4ffc-a066-9bc91a1bbae5' then 1 else 0 end as pm_flag_has_vchild
							from BBCRM_PROD_RPT_BBDW.BBDW.FACT_CONSTITUENTATTRIBUTE
							where ATTRIBUTESYSTEMID in ('473fca33-d6b1-4ffc-a066-9bc91a1bbae5')
							  and ATTRIBUTEISCURRENT = 1
						) t
				 group by CONSTITUENTSYSTEMID
			) vchild on vchild.constituentsystemid = b.constituentsystemid

  /*Gordon's NoKids Python script - interaction key phrases*/
  left join (
SELECT constituent_system_id
	 , max(convert(tinyint,contains_phrase)) as flag_has_nokids_GB
--      ,[interaction_system_id]
--      ,[constituent_dim_id]

	  --,[flag_has_pg_vehicle_hh]
      --,[constituent_lookup_id]
      --,[interaction_lookup_id]
      --,[bio_name]
      --,[officer_name]
      --,[unit_name]
      --,[interaction_type]
      --,[interaction_actual_date]
      --,[interaction_FY]
      --,[interaction_comment]
      --,[contains_phrase]
      --,[matched_phrase]
      --,[interaction_comment_2]
      --,[bio_age]
      --,[bio_death_date]
      --,[gvg_recog_raised_life_hh]
      --,[eval_vcu_planned_giving_score_SQL]

  FROM DARanalytics.dbo.pg_nochildren_interactionphrases
  group by constituent_system_id
  ) nokids_GB on nokids_GB.constituent_system_id = b.CONSTITUENTSYSTEMID

   /*cheap and easy way to get latest grad year from a grad program */

   /*Season Tix to MBB, WBB or FB */
  
   /*Permanently do not include*/
   left join (
   SELECT CONSTITUENTDIMID
        , CONSTITUENTSYSTEMID
		, 1 as flag_permanent_do_not_include

     FROM BBCRM_PROD_RPT_BBDW.BBDW.FACT_CONSTITUENTSOLICITCODE fsc
	 left join BBCRM_PROD_RPT_BBDW.BBDW.DIM_SOLICITCODE sc on sc.SOLICITCODEDIMID = fsc.SOLICITCODEDIMID
    WHERE SOLICITCODESYSTEMID = '888E7FA9-8878-473B-BEB0-D16FDCE8E974'  --57   --Permanently do not include n=175 - in Mar 2025
 ) dni on dni.CONSTITUENTSYSTEMID = b.CONSTITUENTSYSTEMID
  
  /*grouped solicit codes*/
  left join (  select CONSTITUENTDIMID
					, SOLICITCODES
					, CONSTITUENCY
					, SPORTS
					, ACTIVITIES
              from BBCRM_PROD_RPT_BBDW.BBDW.VCU_RPT_CONSTITUENTLISTFIELDS
			  ) sc on sc.CONSTITUENTDIMID = b.CONSTITUENTDIMID

  /*Call list exclude codes at VCU level - designed for LAGO but could be applied elsewhere */
  left join (  select 1 as flag_exclude_from_call_lists_VCU
					, CONSTITUENTSYSTEMID
				 from (
  
			   select cs.constituentdimid
				    , cs.CONSTITUENTSYSTEMID
     			    , sum(case when sc.SOLICITCODESYSTEMID in	(  --just one of these will exclude you from the call list.
															 '888E7FA9-8878-473B-BEB0-D16FDCE8E974' --57-- PERMANENTLY DO NOT INCLUDE
															,'15039EA8-86F6-4097-8885-EEE208B6394E' --63-- Do Not Solicit
															,'24135D42-0733-451E-815C-52F15DCE6822' --79-- Do Not Contact
															--,83		-- OptOut VCU  --this one may not apply....hard to say
															) then 1
							  when sc.SOLICITCODESYSTEMID in	(		--ned both of these to be included in this exclusion flag
															 '6D0AE8F5-8409-4B6F-AC5D-4E6770906943' --71-- No solicit-email, any sch/dept
															,'CC20B756-13EF-47E6-8658-687E61854A89' --38-- No solicit-phone, any sch/dept
															) then .5
							  else 0 end) as score_exclude_call_list  --need 1 or more to be flagged.  Having just one of the no solicit codes doesn't cut it.

			   from BBCRM_PROD_RPT_BBDW.BBDW.v_FACT_CONSTITUENTSOLICITCODE as cs
			   left join BBCRM_PROD_RPT_BBDW.BBDW.DIM_SOLICITCODE sc on sc.SOLICITCODEDIMID = cs.SOLICITCODEDIMID
			  where isnull(CONSTITUENTSOLICITCODEENDDATE, getdate()) >= getdate()
			  group by cs.CONSTITUENTDIMID, cs.CONSTITUENTSYSTEMID
			--  order by cs.CONSTITUENTDIMID
			) t
			where t.score_exclude_call_list>=1	--need a least a score of 1 to be excluded		
			) call_list_exclude_VCU on call_list_exclude_VCU.CONSTITUENTSYSTEMID = b.CONSTITUENTSYSTEMID




	/* Gordon's solicit and contactable logic view */
	left join DARanalytics.ref.constituent_VCU_contact_solicitable cs_vcu on cs_vcu.constituent_system_id = b.CONSTITUENTSYSTEMID


  /* Weird constituent groups to exclude*/
left join ( SELECT case when fullname like '%anonymous%' then 'Anonymous'
						when fullname like '%employees of%' then 'Employee Group'
						when fullname like '%staff of%' then 'Staff Group'
						when fullname like '%class of%' then 'Class of'
						when fullname like '%VCU%school%' then 'VCU School'
						when fullname like '%VCU%department%' then 'VCU Department'
						when fullname like '%VCU%dept%' then 'VCU Department'
						when fullname like '%VCU%health%' then 'VCU Health'
						when fullname like '%Proceeds%VCU%' then 'VCU Proceeds'
						when fullname like '%VCU%committee%' then 'VCU Committee/Board'
						when fullname like '%VCU%board%' then 'VCU Committee/Board'
						when fullname like '%VCU%' then 'All other VCU'
						when CONSTITUENTLOOKUPID = '8-10867752' then 'PD test user'
						when fullname like '%Undefined%' then 'Undefined Individual'		--about 5 of these weirdos
						else NULL end as exclude_groups
				 , CONSTITUENTDIMID
				 , CONSTITUENTLOOKUPID
				 , CONSTITUENTSYSTEMID
				 , FULLNAME
			--	 , KEYNAMEPREFIX
			--	 , KEYNAME

			  FROM BBCRM_PROD_RPT_BBDW.BBDW.DIM_CONSTITUENT
			 where ( fullname like '%anonymous%'
				 or  fullname like '%employees of%'
				 or  fullname like '%staff of%'
				 or  fullname like '%class of%'
				 or  fullname like '%VCU%'
				 or  fullname like '%Undefined%'
				 or CONSTITUENTLOOKUPID = '8-10867752'
				   )
				and fullname not in ( 'Families Anonymous Intergroup'
									, 'Alcoholics Anonymous - Friday Night'
									)
			group by CONSTITUENTDIMID
				   , CONSTITUENTLOOKUPID
				   , CONSTITUENTSYSTEMID
				   , FULLNAME					
			--order by CONSTITUENTLOOKUPID
			) weird on weird.CONSTITUENTDIMID = b.CONSTITUENTDIMID

	/*tie in the household datamart*/
	left join DARanalytics.datamart.constituent_household_level chl on chl.household_id = hh_summary.household_id

	/*join in if constituent has an endowed fund*/
	left join (
				select ENDOWMENTRECIPIENT_ID
			 , max(ENDOWMENTRECIPIENT_FULLNAME) as ENDOWMENTRECIPIENT_FULLNAME
			 , max(DESIGNATIONSTARTDATE)		as latest_endowed_fund_start_date
			 , 1 as flag_has_endowed_a_fund
		  from (
					select
						 DESIGNATIONSYSTEMID
						,PURPOSEGUID
						,PURPOSELEVELDIMID
						,ACCOUNTNUMBER
						,DESIGNATIONPUBLICNAME
						--,UNIVERSITYBANNERINDEX
						--,LINKEDCURRENTFUND
						--,UNIT
						--,DEPARTMENT
						--,OWNER
						--,VSECATEGORY
						--,VSESUBCATEGORY
						,DESIGNATIONSTARTDATE
						--,BOTH_SPOUSES_INCLUDED
						,err.ENDOWMENTRECIPIENT_ID
						,ENDOWMENTRECIPIENT_FULLNAME
						--,ENDOWMENTRECIPIENT_NICKNAME
						--,ENDOWMENTRECIPIENT_ID_SPOUSE
						--,ENDOWMENTRECIPIENT_FULLNAME_SPOUSE
						--,ENDOWMENTRECIPIENT_FORMAL_ADDRESSEE
						--,ENDOWMENTRECIPIENT_FORMAL_SALUTATION
						--,ENDOWMENTRECIPIENT_INFORMAL_SALUTATION
						--,ENDOWMENTRECIPIENT_PROSPECTMANAGER
						--,ENDOWMENTRECIPIENT_STEWARDSHIPMANAGER
						--,ENDOWMENTRECIPIENT_DISCOVERYMANAGER
						--,REPRESENTATIVECONTACT
						--,COMPANYLOOKUPID
						--,COMPANYFULLNAME
						--,PRIMARYADDRESSLINE1
						--,PRIMARYADDRESSLINE2
						--,PRIMARYADDRESSLINE3
						--,PRIMARYADDRESSLINE4
						--,PRIMARYADDRESSLINE5
						--,PRIMARYADDRESSCITY
						--,PRIMARYADDRESSSTATEABBREVIATION
						--,PRIMARYADDRESSPOSTCODE
						--,PRIMARYEMAILADDRESS
						--,SPOUSEEMAILADDRESS
						--,FY5YEARSENDMARKETVALUE
						--,FY5YEARSAGO_EST_DISBURSEMENTS
						--,FY4YEARSENDMARKETVALUE
						--,FY4YEARSAGO_EST_DISBURSEMENTS
						--,FY3YEARSENDMARKETVALUE
						--,FY3YEARSAGO_EST_DISBURSEMENTS
						--,FY2YEARSENDMARKETVALUE
						--,FY2YEARSAGO_EST_DISBURSEMENTS
						--,FY1YEARSENDMARKETVALUE
						--,FY1YEARSAGO_EST_DISBURSEMENTS
						--,STEWARDSHIPSUMMARY
						--,NOENDOWMENTREPORT
						--,case when FUNDCOUNT is null then 0 else 1 end MORETHANONEFUND
						--,LASTGIFTDATETOFUND 
						--,LASTGIFTTOFUND 
						--,LIFETIMETOFUND 
						--,LIFETIMETOVCU 
						--,ALLGIFTSTOFUND
						--,PLANNEDGIFTS
						--,NONDONORTOFUND 
						--,NONDONORTOVCU 
						--,REPORTPREFERENCE
					from BBCRM_PROD_RPT_BBDW.BBDW.VCU_RPT_ENDOWMENTREPORTRECIPIENTS err
					left join (
								select ENDOWMENTRECIPIENT_ID
										, count(distinct DESIGNATIONPUBLICNAME) FUNDCOUNT
									from BBCRM_PROD_RPT_BBDW.bbdw.VCU_RPT_ENDOWMENTREPORTRECIPIENTS 
									where ENDOWMENTRECIPIENT_ID is not null
									group by ENDOWMENTRECIPIENT_ID
								having count(distinct DESIGNATIONPUBLICNAME) > 1
						) morethanone
							on morethanone.ENDOWMENTRECIPIENT_ID = err.ENDOWMENTRECIPIENT_ID
				where err.ENDOWMENTRECIPIENT_ID is not null
					) t
			group by t.ENDOWMENTRECIPIENT_ID
		) endow on endow.ENDOWMENTRECIPIENT_ID = b.CONSTITUENTLOOKUPID

/* Number of relatives and flag if spouse/child/parent in DB*/
left join (
	select primary_constituent_system_id
		 , primary_constituent_lookup_id
		 , primary_constituent_full_name

		 , max(case when (flag_has_parent_child_or_spouse_record = 1
					  or  flag_has_non_parent_child_or_spouse_relative = 1
						)
					 and (secondary_constituent_is_alum = 1
					  or  secondary_constituent_is_facstaff = 1) then 1 else 0 end) as flag_has_radar_relation_alum_facstaff

		 , max(case when (flag_has_friend_neighbor_record =1)
					 and (secondary_constituent_is_facstaff = 1) then 1 else 0 end) as flag_has_radar_friend_facstaff

		 , max(flag_is_parent_child_or_spouse_record) as flag_is_parent_child_or_spouse_in_radar
		 , max(flag_has_parent_child_or_spouse_record) as flag_has_parent_child_or_spouse_in_radar

		 , max(flag_is_non_parent_child_or_spouse_relative) as flag_is_non_parent_child_or_spouse_relative_in_radar
		 , max(flag_has_non_parent_child_or_spouse_relative) as flag_has_non_parent_child_or_spouse_relative_in_radar

		 , max(flag_is_friend_neighbor_record)			as flag_is_friend_neighbor_in_radar
		 , max(flag_has_friend_neighbor_record)			as flag_has_friend_neighbor_in_radar

		 , sum(flag_is_non_parent_child_or_spouse_relative) as num_non_parent_child_spouse_relatives_in_radar
	from (
			SELECT cr.CONSTITUENTDIMID		as primary_constituent_dim_id
			     , cr.CONSTITUENTSYSTEMID	as primary_constituent_system_id
				 , dc.CONSTITUENTLOOKUPID
				 , c.CONSTITUENTLOOKUPID    as primary_constituent_lookup_id
				 , c.FULLNAME				as primary_constituent_full_name
				 , cr.CONSTITUENTRELATIONSHIPTYPEDIMID	as primary_relationship_type_id
				 , crt.CONSTITUENTRELATIONSHIPTYPE			as primary_relationship_type_desc
				 , case when rt.CONSTITUENTRELATIONSHIPTYPESYSTEMID in ( 
																	  'DC919100-FCDD-48FE-B2FD-FAE11C79B2A2' --1	--spouse
																	, 'C7768B84-4410-4EAF-B227-5564EB48FB80' --2	--parent (has a child record)
																	, '75DCE64A-8FFE-45EF-87C3-F3FAC5E10F02' --3	--child (has a parent record)
																	, '71B719D3-9487-43C6-A2BB-A73C22017F26' --51	--deceased spouse
																	, 'F6EF2113-C1AD-4C3F-A1F9-4057621B1260' --66	--Fiancee
																	, 'F1824F9D-0377-4B73-BE3A-DBD73E53B63A' --103	--Step-parent
																	, 'ABD6138C-CFB2-4340-AFB9-E78CEC5C790E' --115	--surviving spouse
																	, '7CFCA0E1-31F6-4DD6-9A5C-9894CBF8C311' --123	--separated spouse
																	 ) then 1 else 0 end as flag_is_parent_child_or_spouse_record
				 , case when rrt.CONSTITUENTRELATIONSHIPTYPESYSTEMID in ( 
																	  'DC919100-FCDD-48FE-B2FD-FAE11C79B2A2' --1	--spouse
																	, 'C7768B84-4410-4EAF-B227-5564EB48FB80' --2	--parent (has a child record)
																	, '75DCE64A-8FFE-45EF-87C3-F3FAC5E10F02' --3	--child (has a parent record)
																	, '71B719D3-9487-43C6-A2BB-A73C22017F26' --51	--deceased spouse
																	, 'F6EF2113-C1AD-4C3F-A1F9-4057621B1260' --66	--Fiancee
																	, 'F1824F9D-0377-4B73-BE3A-DBD73E53B63A' --103	--Step-parent
																	, 'ABD6138C-CFB2-4340-AFB9-E78CEC5C790E' --115	--surviving spouse
																	, '7CFCA0E1-31F6-4DD6-9A5C-9894CBF8C311' --123	--separated spouse
																	 ) then 1 else 0 end as flag_has_parent_child_or_spouse_record
				 , case when rt.CONSTITUENTRELATIONSHIPTYPESYSTEMID in ( 
																	  '37BC0F8B-C92D-490B-BE75-3B0F7362E83F' --5	--sibling
																	, 'D75D2985-E3C6-491E-A790-0B1E3F487AF9' --6	--Grandchild
																	, '9FE5B6AF-1F3F-4249-971F-F9DC9BC07D0B' --7	--Grandparent
																	, 'F6752449-F426-4287-A8D1-2AE147F113D8' --8	--Godchild
																	, 'A75DB34A-F511-4F82-86B4-D02AA7FE7463' --9	--Godparent
																	, 'F6D4E450-9720-4050-9CA8-78F3C2CADAC2' --10	--Child-in-law
																	, '6B642FE1-8938-4EE6-BA9B-BC098BD2F979' --11	--Parent-in-law
																	, 'B587E55E-F56F-4444-BD0D-1001D99EB246' --12	--Sibling-in-law
																	, '1077BCDB-D89F-4471-A410-EBAB83749F93' --14	--Step-parent-in-law
																	, '4FD48F8A-939C-4478-99C1-93C19B21114A' --15	--Step-child-in-law
																	, '280C5376-30DB-428C-8AC2-273E7D963234' --17	--Companion
																	, '8F800E3D-810D-47BF-9746-D28317BD5C89' --22	--Significant Other
																	--,23 Friend
																	, '3638303A-147C-4BEB-AA50-F62843F5C371' --42	--Half Sibling
																	, '1F2E5D4E-22F9-4919-BD86-62D9E6E47349' --43	--Second Cousin
																	, 'B13C22FB-E09D-4137-BC16-D42E3B6BB66C' --45	--Step Niece/nephew
																	, '67355C33-EFCD-45DE-9CD7-515197C19CDA' --48	--Niece/Nephew-in-law
																	, '5439F90F-5159-4C80-AA1E-1DBFE51E6132' --55	--Niece/Nephew
																	, 'A0639A1C-73AD-4167-9423-282C95195398' --59    --aunt/uncle
																	-- , 60 Neighbor
																	, '42D26411-144F-4F23-AFE7-6C2603BA633B' --62	--Step grandparent
																	, '0A82BCBB-5CEA-40C3-BA8A-61E274A95C07' --63	--Life Partner
																	, 'B5C964E2-FFDE-4437-AA5C-CB0E6B4B7F80' --69	--step grandchild
																	, '5F2E8350-4907-41A6-A803-872F5049C799' --70	--great Niece/nephew
																	, 'B91C92AF-8822-46DE-8EDC-9FDD0BD9A083' --74	--Cousin-in-law
																	, '872C6318-2969-4BE0-820E-6291C0E1764E' --78	--Cousin
																	, '13D91693-BA64-4AA3-9924-19CB9B47FC05' --91	--Aunt/Uncle-in-law
																	, '097FCC34-7ED0-487F-B7D4-D2D44C6CD5E5' --96	--Great Aunt/Uncle
																	, '26685687-59DA-413D-90AB-3A28E5751366' --102	--Great grandchild
																	, '8B0F8EC4-4E80-4DB2-BCB1-9C97A831714E' --105	--relative
																	, '455232A8-47F6-4E2F-AA1B-30307F2DF374' --112	--step-sibling
																	, '3A9B8FAE-8108-4128-BB84-388A25926B3C' --119	--Great Gradparent
																	, 'CAA7E316-C3D5-46FC-916E-466E0191903A' --120	--step-child
																	, 'CF90750A-23EA-4937-8A2B-05CE0F47619E' --175	--Grandparent-in-law
																	, 'EFB2BC59-0327-4ACC-BE79-FF36A302AB8F' --176	--Grandchild-in-law

																	 ) then 1 else 0 end as flag_is_non_parent_child_or_spouse_relative
				 , case when rrt.CONSTITUENTRELATIONSHIPTYPESYSTEMID in ( 
																	  '37BC0F8B-C92D-490B-BE75-3B0F7362E83F' --5	--sibling
																	, 'D75D2985-E3C6-491E-A790-0B1E3F487AF9' --6	--Grandchild
																	, '9FE5B6AF-1F3F-4249-971F-F9DC9BC07D0B' --7	--Grandparent
																	, 'F6752449-F426-4287-A8D1-2AE147F113D8' --8	--Godchild
																	, 'A75DB34A-F511-4F82-86B4-D02AA7FE7463' --9	--Godparent
																	, 'F6D4E450-9720-4050-9CA8-78F3C2CADAC2' --10	--Child-in-law
																	, '6B642FE1-8938-4EE6-BA9B-BC098BD2F979' --11	--Parent-in-law
																	, 'B587E55E-F56F-4444-BD0D-1001D99EB246' --12	--Sibling-in-law
																	, '1077BCDB-D89F-4471-A410-EBAB83749F93' --14	--Step-parent-in-law
																	, '4FD48F8A-939C-4478-99C1-93C19B21114A' --15	--Step-child-in-law
																	, '280C5376-30DB-428C-8AC2-273E7D963234' --17	--Companion
																	, '8F800E3D-810D-47BF-9746-D28317BD5C89' --22	--Significant Other
																	--,23 Friend
																	, '3638303A-147C-4BEB-AA50-F62843F5C371' --42	--Half Sibling
																	, '1F2E5D4E-22F9-4919-BD86-62D9E6E47349' --43	--Second Cousin
																	, 'B13C22FB-E09D-4137-BC16-D42E3B6BB66C' --45	--Step Niece/nephew
																	, '67355C33-EFCD-45DE-9CD7-515197C19CDA' --48	--Niece/Nephew-in-law
																	, '5439F90F-5159-4C80-AA1E-1DBFE51E6132' --55	--Niece/Nephew
																	, 'A0639A1C-73AD-4167-9423-282C95195398' --59    --aunt/uncle
																	-- , 60 Neighbor
																	, '42D26411-144F-4F23-AFE7-6C2603BA633B' --62	--Step grandparent
																	, '0A82BCBB-5CEA-40C3-BA8A-61E274A95C07' --63	--Life Partner
																	, 'B5C964E2-FFDE-4437-AA5C-CB0E6B4B7F80' --69	--step grandchild
																	, '5F2E8350-4907-41A6-A803-872F5049C799' --70	--great Niece/nephew
																	, 'B91C92AF-8822-46DE-8EDC-9FDD0BD9A083' --74	--Cousin-in-law
																	, '872C6318-2969-4BE0-820E-6291C0E1764E' --78	--Cousin
																	, '13D91693-BA64-4AA3-9924-19CB9B47FC05' --91	--Aunt/Uncle-in-law
																	, '097FCC34-7ED0-487F-B7D4-D2D44C6CD5E5' --96	--Great Aunt/Uncle
																	, '26685687-59DA-413D-90AB-3A28E5751366' --102	--Great grandchild
																	, '8B0F8EC4-4E80-4DB2-BCB1-9C97A831714E' --105	--relative
																	, '455232A8-47F6-4E2F-AA1B-30307F2DF374' --112	--step-sibling
																	, '3A9B8FAE-8108-4128-BB84-388A25926B3C' --119	--Great Gradparent
																	, 'CAA7E316-C3D5-46FC-916E-466E0191903A' --120	--step-child
																	, 'CF90750A-23EA-4937-8A2B-05CE0F47619E' --175	--Grandparent-in-law
																	, 'EFB2BC59-0327-4ACC-BE79-FF36A302AB8F' --176	--Grandchild-in-law

																	 ) then 1 else 0 end as flag_has_non_parent_child_or_spouse_relative
 

 				 , case when rt.CONSTITUENTRELATIONSHIPTYPESYSTEMID in ( 
																	  'AAA3BB9A-4C91-4AF8-97AF-4D5BAE501165' --23	--friend
																	, 'C7768B84-4410-4EAF-B227-5564EB48FB80' --2	--neighbor

																	 ) then 1 else 0 end as flag_is_friend_neighbor_record
				 , case when rrt.CONSTITUENTRELATIONSHIPTYPESYSTEMID in ( 
																	  'AAA3BB9A-4C91-4AF8-97AF-4D5BAE501165' --23	--friend
																	, 'C7768B84-4410-4EAF-B227-5564EB48FB80' --2	--neighbor
																	 ) then 1 else 0 end as flag_has_friend_neighbor_record



				 , cr.RECIPROCALCONSTITUENTDIMID    as secondary_constituent_dim_id
				 , cr.RECIPROCALCONSTITUENTSYSTEMID as secondary_constituent_system_id
				 , r.CONSTITUENTLOOKUPID			as secondary_constituent_lookup_id
				 , r.FULLNAME						as secondary_constituent_full_name
			     , cr.RECIPROCALCONSTITUENTRELATIONSHIPTYPEDIMID as secondary_relationship_type_id
				 , r.ISALUMNI						as secondary_constituent_is_alum
				 , case when facstaff.CONSTITUENTSYSTEMID is not null then 1 else 0 end as secondary_constituent_is_facstaff
			     , rrt.CONSTITUENTRELATIONSHIPTYPE	as secondary_relationship_type_desc
			     , convert(date,STARTDATE)			as start_date
			     , convert(date,ENDDATE)			as end_date

			  FROM BBCRM_PROD_RPT_BBDW.BBDW.FACT_CONSTITUENTRELATIONSHIP cr
			  left join BBCRM_PROD_RPT_BBDW.BBDW.DIM_CONSTITUENTRELATIONSHIPTYPE rt on rt.CONSTITUENTRELATIONSHIPTYPEDIMID = cr.CONSTITUENTRELATIONSHIPTYPEDIMID
			  left join BBCRM_PROD_RPT_BBDW.BBDW.DIM_CONSTITUENTRELATIONSHIPTYPE crt on crt.CONSTITUENTRELATIONSHIPTYPEDIMID = cr.CONSTITUENTRELATIONSHIPTYPEDIMID
			  left join BBCRM_PROD_RPT_BBDW.BBDW.DIM_CONSTITUENTRELATIONSHIPTYPE rrt on rrt.CONSTITUENTRELATIONSHIPTYPEDIMID = cr.RECIPROCALCONSTITUENTRELATIONSHIPTYPEDIMID
			 -- left join BBCRM_PROD_RPT_BBDW.BBDW.DIM_CONSTITUENT c on c.constituentdimid = cr.constituentdimid
			  left join BBCRM_PROD_RPT_BBDW.BBDW.VCU_RPT_CONSTITUENTLIST c on c.CONSTITUENTSYSTEMID = cr.CONSTITUENTSYSTEMID
			 -- left join BBCRM_PROD_RPT_BBDW.BBDW.DIM_CONSTITUENT r on r.constituentdimid = cr.reciprocalconstituentdimid
			  left join BBCRM_PROD_RPT_BBDW.BBDW.VCU_RPT_CONSTITUENTLIST r on r.CONSTITUENTSYSTEMID = cr.reciprocalconstituentsystemid
			  left join (SELECT CONSTITUENTDIMID
							  , CONSTITUENTSYSTEMID
							  , CONSTITUENTLOOKUPID
							 -- , max(case when employeetype = 'Retiree' then 1 else 0 end)  as flag_vcu_facstaff_retired
							 -- , max(case when employeetype <> 'Retiree' then 1 else 0 end) as flag_vcu_facstaff_current

						   FROM BBCRM_PROD_RPT_BBDW.BBDW.VCU_RPT_FACULTYSTAFF_CURRENT
						  GROUP BY CONSTITUENTDIMID
								 , CONSTITUENTSYSTEMID
								 , CONSTITUENTLOOKUPID
						  ) facstaff on facstaff.CONSTITUENTSYSTEMID = cr.reciprocalconstituentsystemid
			  left join BBCRM_PROD_RPT_BBDW.BBDW.DIM_CONSTITUENT dc on dc.CONSTITUENTSYSTEMID = cr.CONSTITUENTSYSTEMID
			 where c.ISACTIVE = 1
			   and r.isactive = 1
			 --  and cr.CONSTITUENTRELATIONSHIPTYPEDIMID = 2  --primary relationship type = Parent
			 --  and c.ISDECEASED = 0
			 --  and r.ISDECEASED = 0
	) t
		group by primary_constituent_system_id
			   , primary_constituent_lookup_id
			   , primary_constituent_full_name
			-- order by num_non_parent_child_spouse_relatives_in_radar desc --primary_constituent_lookup_id


) rels on rels.primary_constituent_system_id = b.CONSTITUENTSYSTEMID

left join DARanalytics.tableau.pg_fall_appeal_segmentation pgfa on pgfa.constituent_system_id=b.CONSTITUENTSYSTEMID			--(View n=311k, t=8s)
left join DARanalytics.tableau.pg_spring_appeal_segmentation pgsa on pgsa.constituent_system_id=b.CONSTITUENTSYSTEMID		--(View n=150k, t=3s)
--left join DARanalytics.tableau.LAGO_DEO_segmentation lagodeo on lagodeo.constituent_system_id=b.CONSTITUENTSYSTEMID		--not needed anymore?

/* Bringing in Attribute data*/
left join
	(
		select constituentsystemid as constituent_system_id
			 , max(case when attributesystemid = '517CECA5-0D0C-426E-819F-90D46FEF5ABB' then fca.ATTRIBUTEVALUE else NULL end) as flag_di_vip
			 , max(case when attributesystemid = '47E08DF4-693F-4109-91D4-261008D1B319' then 1 else 0 end) as flag_attribute_mentor
			 , max(case when attributesystemid in ('72D9B94D-353C-4213-8CAA-74898D38C715' , '2DA50068-F8A5-4B92-8865-A83334768CC9' ) then 1 else 0 end) as flag_attribute_volunteer
			 , max(case when attributesystemid = '5F94A8B2-35CF-4906-B00C-C56063E2E835' then 1 else 0 end) as flag_first_gen_student
			 , max(case when  da.ATTRIBUTECATEGORYSYSTEMID in ('D7D8BABB-2D9C-45EE-80AB-0A27828D8428'		--10 Under 10 Alumni Recognition Award
															  ,'AAE74AA5-FC1E-47F4-A63D-71576575259A'		--Alumni Volunteer Service Award
															  ,'D67A7BB8-2D3F-4994-82D7-9931003F996B')	then 1 else 0 end) as flag_award_recipient
		  from BBCRM_PROD_RPT_BBDW.BBDW.FACT_CONSTITUENTATTRIBUTE fca
		  left join BBCRM_PROD_RPT_BBDW.BBDW.DIM_ATTRIBUTE da on da.ATTRIBUTEDIMID = fca.ATTRIBUTEDIMID
		 where attributesystemid in ('517CECA5-0D0C-426E-819F-90D46FEF5ABB'  --DI VIP Flag  N=18200 as of 11/24
									,'47E08DF4-693F-4109-91D4-261008D1B319'  --mentor
									,'72D9B94D-353C-4213-8CAA-74898D38C715'  --volunteer VCU
									,'2DA50068-F8A5-4B92-8865-A83334768CC9'  --event volunteer
									,'5F94A8B2-35CF-4906-B00C-C56063E2E835'	 --first gen student
									)
			or da.ATTRIBUTECATEGORYSYSTEMID in ('D7D8BABB-2D9C-45EE-80AB-0A27828D8428'		--10 Under 10 Alumni Recognition Award
											   ,'AAE74AA5-FC1E-47F4-A63D-71576575259A'		--Alumni Volunteer Service Award
											   ,'D67A7BB8-2D3F-4994-82D7-9931003F996B')		--awards
	  group by constituentsystemid
	) attribs on attribs.constituent_system_id = b.CONSTITUENTSYSTEMID

/* Bringing in Attribute data another way - for Surveys 
WW 20260310 - includes 2024 First Destination Survey, Alumni AEO survey 2024, Planned Giving QuestionPro Survey, 
RNL 2023 survey , RNL 2024 survey, RNL 2025 Survey */
left join (
SELECT
	fca.CONSTITUENTSYSTEMID as constituent_system_id
	,fca.constituentdimid as constituent_dim_id
	--,fca.ATTRIBUTESTARTDATE
	--,fca.ATTRIBUTEVALUE
FROM BBCRM_PROD_RPT_BBDW.BBDW.FACT_CONSTITUENTATTRIBUTE as fca
where fca.ATTRIBUTEVALUE like '%Survey%' and DATEDIFF ( day , fca.attributestartdate , getdate()) <= (365*3)
group by fca.CONSTITUENTSYSTEMID, fca.constituentdimid
) as surveyattributes
 on surveyattributes.constituent_system_id = b.CONSTITUENTSYSTEMID

/*Lets look at the new event data - Not needed now but keeping (n=11k, t=9s)*/
left join (
			SELECT count(*) as num_events_attended
				 , sum(case when start_date >= '2020-07-01' then 1 else 0 end) as num_events_campaign_attended
				 , constituent_system_id
			  FROM DARanalytics.tableau.event_registrants
			 where attend_status = 'Attended' --not in ('Unknown','Cancelled','Did Not Attend')
			   and constituent_system_id is not null
			 --and event_CSU_list is null
			 group by constituent_system_id
			-- order by num_events_attended desc
		) evnts on evnts.constituent_system_id = b.CONSTITUENTSYSTEMID

/*Lets look at the new event data (n=11k, t=9s) */
left join (
			SELECT count(*) as num_events_attended
				 , sum(case when start_date between dateadd(year,-3,getdate()) and getdate() then 1 else 0 end) as num_events_past3yrs_attended
				 , constituent_system_id
			  FROM DARanalytics.tableau.event_registrants
			 where attend_status = 'Attended' --not in ('Unknown','Cancelled','Did Not Attend')
			   and constituent_system_id is not null
			   and constituent_system_id <> '00000000-0000-0000-0000-000000000000'
			 --and event_CSU_list is null
			 group by constituent_system_id
			-- order by num_events_attended desc
		) evnts_past3yrs on evnts_past3yrs.constituent_system_id = b.CONSTITUENTSYSTEMID

/* Due Diligence Constituent Note  (n=59, t=0s)*/
left join (
		select * 
		  from (
				SELECT CONSTITUENTDIMID
					 , CONSTITUENTSYSTEMID
					 , convert(date,DATEENTERED)				as pm_latest_duediligence_note_enter_date
					 , convert(date,DATEADDED)					as pm_latest_duediligence_note_added_date
					 , convert(date,DATECHANGED)				as pm_latest_duediligence_note_changed_date
					 , TITLE									as pm_latest_duediligence_note_title
				  -- , AUTHORID
				 	 , TEXTNOTE									as pm_latest_duediligence_note_text
				     , CONSTITUENTNOTETYPE						as pm_latest_duediligence_note_type
				  -- , ADDEDBYID
					 , ROW_NUMBER() over (partition by constituentsystemid order by dateentered desc) as note_row
					 , rui.user_name  as pm_latest_duediligence_author

				  FROM BBCRM_PROD_RPT_BBDW.BBDW.VCU_FACT_CONSTITUENTNOTE cn
				  left join DARanalytics.ref.radar_user_info rui on rui.user_system_id = cn.AUTHORID
				 WHERE constituentnotetype = 'Research - Due Diligence and Reputational Risk'
			   ) t
		 where t.note_row = 1
		 ) note on note.CONSTITUENTSYSTEMID = b.CONSTITUENTSYSTEMID

/* MPAR Degrees --view (n=23k, t=1s)*/
left join DARAnalytics.ref.mpar_degrees_constituent_level mpar_deg on mpar_deg.constituent_system_id = b.CONSTITUENTSYSTEMID  

/* Education sub departments that don't exist in the VCU_report (n=431k, t=7s)*/
 left join (
		 SELECT de.EDUCATIONDIMID
			  ,de.EDUCATIONSYSTEMID
			  ,de.CONSTITUENTDIMID
			  ,de.CONSTITUENTSYSTEMID
			  ,deai.EDUCATIONALSUBDEPARTMENT
		  FROM BBCRM_PROD_RPT_BBDW.BBDW.DIM_EDUCATION de
		  left join (
				SELECT EDUCATIONDIMID
					 , EDUCATIONALSUBDEPARTMENT
				  FROM BBCRM_PROD_RPT_BBDW.BBDW.DIM_EDUCATIONADDITIONALINFORMATION
				 where EDUCATIONALSUBDEPARTMENT <> 'No Educational Sub Department'
				   and EDUCATIONALCOLLEGE = 'School of Education'
					) deai on deai.EDUCATIONDIMID = de.EDUCATIONDIMID 
			) soe_sub_dept1 on soe_sub_dept1.EDUCATIONSYSTEMID   = b.EDUCATIONSYSTEMID1
						   and soe_sub_dept1.CONSTITUENTSYSTEMID = b.CONSTITUENTSYSTEMID   --probably not needed

 left join (		--(n=431k, t=7s)
		 SELECT de.EDUCATIONDIMID
			  ,de.EDUCATIONSYSTEMID
			  ,de.CONSTITUENTDIMID
			  ,de.CONSTITUENTSYSTEMID
			  ,deai.EDUCATIONALSUBDEPARTMENT
		  FROM BBCRM_PROD_RPT_BBDW.BBDW.DIM_EDUCATION de
		  left join (
				SELECT EDUCATIONDIMID
					 , EDUCATIONALSUBDEPARTMENT
				  FROM BBCRM_PROD_RPT_BBDW.BBDW.DIM_EDUCATIONADDITIONALINFORMATION
				 where EDUCATIONALSUBDEPARTMENT <> 'No Educational Sub Department'
				   and EDUCATIONALCOLLEGE = 'School of Education'
					) deai on deai.EDUCATIONDIMID = de.EDUCATIONDIMID 
			) soe_sub_dept2 on soe_sub_dept2.EDUCATIONSYSTEMID   = b.EDUCATIONSYSTEMID2
						   and soe_sub_dept2.CONSTITUENTSYSTEMID = b.CONSTITUENTSYSTEMID   --probably not needed

 left join (	--(n=431k, t=8s)
		 SELECT de.EDUCATIONDIMID
			  ,de.EDUCATIONSYSTEMID
			  ,de.CONSTITUENTDIMID
			  ,de.CONSTITUENTSYSTEMID
			  ,deai.EDUCATIONALSUBDEPARTMENT
		  FROM BBCRM_PROD_RPT_BBDW.BBDW.DIM_EDUCATION de
		  left join (
				SELECT EDUCATIONDIMID
					 , EDUCATIONALSUBDEPARTMENT
				  FROM BBCRM_PROD_RPT_BBDW.BBDW.DIM_EDUCATIONADDITIONALINFORMATION
				 where EDUCATIONALSUBDEPARTMENT <> 'No Educational Sub Department'
				   and EDUCATIONALCOLLEGE = 'School of Education'
					) deai on deai.EDUCATIONDIMID = de.EDUCATIONDIMID 
			) soe_sub_dept3 on soe_sub_dept3.EDUCATIONSYSTEMID   = b.EDUCATIONSYSTEMID3
						   and soe_sub_dept3.CONSTITUENTSYSTEMID = b.CONSTITUENTSYSTEMID   --probably not needed

 left join (		--(n=431k, t=7s)
		 SELECT de.EDUCATIONDIMID
			  ,de.EDUCATIONSYSTEMID
			  ,de.CONSTITUENTDIMID
			  ,de.CONSTITUENTSYSTEMID
			  ,deai.EDUCATIONALSUBDEPARTMENT
		  FROM BBCRM_PROD_RPT_BBDW.BBDW.DIM_EDUCATION de
		  left join (
				SELECT EDUCATIONDIMID
					 , EDUCATIONALSUBDEPARTMENT
				  FROM BBCRM_PROD_RPT_BBDW.BBDW.DIM_EDUCATIONADDITIONALINFORMATION
				 where EDUCATIONALSUBDEPARTMENT <> 'No Educational Sub Department'
				   and EDUCATIONALCOLLEGE = 'School of Education'
					) deai on deai.EDUCATIONDIMID = de.EDUCATIONDIMID 
			) soe_sub_dept4 on soe_sub_dept4.EDUCATIONSYSTEMID   = b.EDUCATIONSYSTEMID4
						   and soe_sub_dept4.CONSTITUENTSYSTEMID = b.CONSTITUENTSYSTEMID   --probably not needed

left join DARanalytics.dbo.touchpoints_VCU_export_June2025_results4upload touchpoint on touchpoint.record_id = b.CONSTITUENTLOOKUPID		--table (n=37k, t=1s)

left join (	 --Business Owners (n=4k, t=0s)
			 SELECT fcr.CONSTITUENTSYSTEMID	
				  --, fcr.CONSTITUENTRELATIONSHIPTYPEDIMID
				  --, r.relationshiptype
				  --, attr.attributevalue
				  --, attr.ATTRIBUTEDIMID
				  , 1 as flag_business_owner
			   FROM BBCRM_PROD_RPT_BBDW.BBDW.FACT_CONSTITUENTRELATIONSHIP fcr --joining this table to grab dimid 28 for Owner/founder information
		  left join BBCRM_PROD_RPT_BBDW.BBDW.V_QUERY_BBDW_RELATIONSHIP r		on r.CONSTITUENTRELATIONSHIPSYSTEMID = fcr.CONSTITUENTRELATIONSHIPSYSTEMID --matching with systemid
	  	  left join BBCRM_PROD_RPT_BBDW.BBDW.FACT_CONSTITUENTATTRIBUTE attr	on attr.CONSTITUENTSYSTEMID = fcr.constituentsystemid

			  where (
					(r.relationshiptype = 'Owner/Founder' and getdate() between isnull(r.STARTDATE,'2020-07-01') and isnull(r.ENDDATE,'2099-01-01'))		--fcr.CONSTITUENTRELATIONSHIPTYPEDIMID = 28 and owner/founder dimid
				 or attr.ATTRIBUTEVALUESYSTEMID in ('7FA0F7FC-89B0-409D-B63F-DF5BD0588B02'		--NonEvent - VCU Alumni Alumni Owned Business
												  -- ,'7E6EBC9D-B7D5-4E99-8FE1-9884C1E6D964'		--Alumni-owned Business Series at Urban Hang Suite  (keep these???)
													)						
				    )		
		   group by fcr.constituentsystemid --, ATTRIBUTEVALUE, ATTRIBUTEDIMID, fcr.CONSTITUENTRELATIONSHIPTYPEDIMID,r.relationshiptype
		  -- order by r.RELATIONSHIPTYPE
		) bizowner on bizowner.constituentsystemid = b.CONSTITUENTSYSTEMID

left join (			--(n=359k, t=10s)
		
	select * from (
			 SELECT rel.CONSTITUENTSYSTEMID								--employee (general)
				  , rel.RECIPROCALCONSTITUENTSYSTEMID					--employer (general)
				  , c.CONSTITUENTLOOKUPID						as bio_employer_lookup_id
				  , c.CONSTITUENTDIMID							as bio_employer_dim_id
				  , emp.STARTDATE								as job_start_date			--latest start date with person at same company
				  , isnull(emp.enddate,'2099-01-01')			as job_end_date  --if they work for the same company more than once we want the latest start and end dates....and NULL would be latest.
				  , case when emp.enddate is null then 1 else 0 end as flag_job_current 
				  , isnull(emp.JOBCATEGORY,'No Job Category')	as job_category
				  , emp.careerlevel								as job_career_level
				  , emp.JOBDEPARTMENT							as job_department
				  , emp.JOBDIVISION								as job_division
				  , emp.JOBSCHEDULE								as job_schedule
				  , rel.CONSTITUENTRELATIONSHIPTYPEDIMID		as job_type
				  , reltype.CONSTITUENTRELATIONSHIPTYPE			as job_relationship_type
				  , row_number() over (partition by rel.CONSTITUENTSYSTEMID, rel.RECIPROCALCONSTITUENTSYSTEMID
										   order by isnull(emp.enddate,'2099-01-01') desc, emp.STARTDATE desc)
										as job_row_num
				  , row_number() over (partition by rel.CONSTITUENTSYSTEMID
										   order by isnull(emp.enddate,'2099-01-01') desc, emp.STARTDATE desc)
										as indiv_row_num
			  FROM BBCRM_PROD_RPT_BBDW.BBDW.FACT_CONSTITUENTRELATIONSHIP rel
			  left join BBCRM_PROD_RPT_BBDW.BBDW.DIM_CONSTITUENTRELATIONSHIPTYPE reltype on reltype.CONSTITUENTRELATIONSHIPTYPEDIMID = rel.CONSTITUENTRELATIONSHIPTYPEDIMID
			  left join BBCRM_PROD_RPT_BBDW.BBDW.DIM_CONSTITUENTRELATIONSHIPEMPLOYMENT emp on emp.CONSTITUENTRELATIONSHIPSETDIMID = rel.CONSTITUENTRELATIONSHIPSETDIMID
			  left join BBCRM_PROD_RPT_BBDW.BBDW.DIM_CONSTITUENT c on c.CONSTITUENTSYSTEMID = rel.RECIPROCALCONSTITUENTSYSTEMID
			 where rel.CONSTITUENTRELATIONSHIPTYPEDIMID in (
															 16		--Retiree
															,20		--Partner
															,25		--Employee
															,28		--Owner/Founder
															,40		--Secretary
															,90		--Teacher
															,98		--CEO
															,100	--Director
															,129	--President
															,134	--Housestaff
															,155	--Primary Contact
															,166	--Member
															,181	--Vice President
															,187	--Volunteer
												)

				--and emp.enddate is null			--this loses past job history
			) t
			where job_row_num = 1
			 -- order by bio_employer_lookup_id, CONSTITUENTSYSTEMID, RECIPROCALCONSTITUENTSYSTEMID, job_row_num
		) job_cat on job_cat.CONSTITUENTSYSTEMID = b.CONSTITUENTSYSTEMID
				 and job_cat.RECIPROCALCONSTITUENTSYSTEMID = b.CURRENTEMPLOYERID

	--update this in JULY of 2026 perhaps --table (n=770k, t=18s)
	left join BBCRM_PROD_RPT_BBDW.BBDW.VCU_VSE_STAGING_SNAPSHOT_FY25 legalcontactsnap25 on legalcontactsnap25.CONSTITUENTID = b.CONSTITUENTSYSTEMID
	left join BBCRM_PROD_RPT_BBDW.BBDW.VCU_VSE_STAGING_SNAPSHOT_FY26 legalcontactsnap26 on legalcontactsnap26.CONSTITUENTID = b.CONSTITUENTSYSTEMID		

	left join (		--(n=130k, t=2s)
			select fsc.CONSTITUENTSYSTEMID
			  from BBCRM_PROD_RPT_BBDW.bbdw.FACT_CONSTITUENTSOLICITCODE fsc --DARAnalytics would call this constituent_solicitcode_level
			  join BBCRM_PROD_RPT_BBDW.bbdw.DIM_SOLICITCODE dsc on dsc.SOLICITCODEDIMID = fsc.SOLICITCODEDIMID

			 where dsc.SOLICITCODESYSTEMID in 
				 ( '888E7FA9-8878-473B-BEB0-D16FDCE8E974'	--PERMANENTLY DO NOT INCLUDE
				 , 'E5B7C1F2-9745-476E-9CF7-54B05DF71AE1'	--Do Not Phone
				 , 'E4BE41F5-B0DE-448F-AF5F-E6A5096EBB13'	--Do not email
				 , '03079EF9-D35A-463B-B4CB-DA2441DAB7F4'	--E-Mail-DONT USE TO BROADCAST
				 , '034B2E30-F178-4EE3-9CF5-3ED1AA376D7F'	--do not mail
				 , '24135D42-0733-451E-815C-52F15DCE6822'	-- do not contact
				 )
			   and (fsc.CONSTITUENTSOLICITCODEENDDATE is null 
				 or fsc.CONSTITUENTSOLICITCODEENDDATE > getdate()
				   )
			 group by CONSTITUENTSYSTEMID
			 ) legalcontact on legalcontact.CONSTITUENTSYSTEMID = b.CONSTITUENTSYSTEMID

			 
	left join (		--(n=260k, t=5s)
				select dc.CONSTITUENTSYSTEMID
					 , min(case when PREFERREDCLASSYEAR = 0 then NULL else PREFERREDCLASSYEAR end) as affil_min_class_year
				  from BBCRM_PROD_RPT_BBDW.bbdw.DIM_EDUCATION e
				  join BBCRM_PROD_RPT_BBDW.bbdw.DIM_CONSTITUENT dc		on dc.CONSTITUENTDIMID = e.CONSTITUENTDIMID
				 where e.EDUCATIONINSTITUTIONISAFFLIATED = 1
				   and e.EDUCATIONCONSTITUENCYSTATUS = 'Graduated'
				 group by dc.CONSTITUENTSYSTEMID
				-- order by affil_min_class_year
			 ) min_educ on min_educ.CONSTITUENTSYSTEMID = b.CONSTITUENTSYSTEMID

	left join (		--(n=25k, t=0s)
				SELECT 1 as  flag_has_picture_in_radar
					 , CONSTITUENTDIMID
					--,[PICTURE]
					--,[PICTURETHUMBNAIL]
					--,[ETLCONTROLID]
				  FROM BBCRM_PROD_RPT_BBDW.BBDW.VCU_FACT_CONSTITUENTPICTURES
				 WHERE PICTURE is not null
			  GROUP BY CONSTITUENTDIMID
				) pic on pic.CONSTITUENTDIMID = b.CONSTITUENTDIMID

	left join (		--(n=181k, t=3s)
				select CONSTITUENTDIMID
				, max(case when SOCIALMEDIASERVICENAME = 'LinkedIn' then URL end) as cntc_linkedin
				, max(case when SOCIALMEDIASERVICENAME = 'Facebook' then URL end) as cntc_facebook
				, max(case when SOCIALMEDIASERVICENAME = 'Twitter'  then URL end) as cntc_twitter
			from BBCRM_PROD_RPT_BBDW.BBDW.VCU_FACT_SOCIALMEDIAACCOUNT
			group by CONSTITUENTDIMID
				) contact on contact.CONSTITUENTDIMID = b.CONSTITUENTDIMID

	left join (		--(n=301k, t=6s)
			SELECT constituent_system_id
				 , constituent_lookup_id
				 , max(constituent_dim_id) as constituent_dim_id
				 , max(CASE WHEN EDUCATIONPROGRAM = 'Undergraduate' and EDUCATIONCONSTITUENCYSTATUS = 'Graduated' THEN 1 ELSE 0 END) AS flag_vcu_alumni_ug_degree
				 , max(CASE WHEN CLASSOF >= YEAR(dateadd(month,6,GETDATE())) - 10 and EDUCATIONPROGRAM = 'Undergraduate' and EDUCATIONCONSTITUENCYSTATUS = 'Graduated'  THEN 1 ELSE 0 END) AS flag_vcu_young_alumni_ug_degree
				 , max(CASE WHEN EDUCATIONPROGRAM in ('Graduate','Doctorate') and EDUCATIONCONSTITUENCYSTATUS = 'Graduated' THEN 1 ELSE 0 END) AS flag_vcu_alumni_grad_degree
				 , max(CASE WHEN CLASSOF >= YEAR(dateadd(month,6,GETDATE())) - 10 and EDUCATIONPROGRAM = 'Graduate' and EDUCATIONCONSTITUENCYSTATUS = 'Graduated'  THEN 1 ELSE 0 END) AS flag_vcu_young_alumni_grad_degree
				 , max(CASE WHEN CLASSOF >= YEAR(dateadd(month,6,GETDATE())) - 10  and EDUCATIONCONSTITUENCYSTATUS = 'Graduated' THEN 1 ELSE 0 END) AS flag_vcu_recent_any_degree
				 , string_agg(EDUCATIONALCOLLEGE,'; ') as list_of_education_colleges  --if dedupe needed ....need a new subquery with distinct constituent & college.
				 --, len(string_agg(EDUCATIONALCOLLEGE,'; ')) as list_of_education_colleges_test
			  FROM DARanalytics.tableau.vcu_education_degrees
			  where constituent_system_id is not null
			 GROUP BY constituent_system_id
					, constituent_lookup_id
			--order by list_of_education_colleges_test desc
		 ) vcu_educ on vcu_educ.constituent_system_id = b.CONSTITUENTSYSTEMID

	left join (		--(n=41k, t=1s)
			SELECT constituent_system_id
				 , constituent_lookup_id
				 , constituent_dim_id
				 , max(CASE WHEN EDUCATIONPROGRAM = 'Undergraduate' and EDUCATIONCONSTITUENCYSTATUS = 'Graduated' THEN 1 ELSE 0 END) AS flag_non_vcu_alumni_ug_degree
				-- , max(CASE WHEN CLASSOF >= YEAR(dateadd(month,6,GETDATE())) - 10 and EDUCATIONPROGRAM = 'Undergraduate' and EDUCATIONCONSTITUENCYSTATUS = 'Graduated'  THEN 1 ELSE 0 END) AS flag_non_vcu_young_alumni_ug_degree
				 , max(CASE WHEN EDUCATIONPROGRAM in ('Graduate','Doctorate') and EDUCATIONCONSTITUENCYSTATUS = 'Graduated' THEN 1 ELSE 0 END) AS flag_non_vcu_alumni_grad_degree
				-- , max(CASE WHEN CLASSOF >= YEAR(dateadd(month,6,GETDATE())) - 10 and EDUCATIONPROGRAM = 'Graduate' and EDUCATIONCONSTITUENCYSTATUS = 'Graduated'  THEN 1 ELSE 0 END) AS flag_non_vcu_young_alumni_grad_degree
				 , max(CASE WHEN CLASSOF >= YEAR(dateadd(month,6,GETDATE())) - 10  and EDUCATIONCONSTITUENCYSTATUS = 'Graduated' THEN 1 ELSE 0 END) AS flag_non_vcu_recent_any_degree 
			  FROM DARanalytics.tableau.non_vcu_education_degrees
			  where constituent_system_id is not null
			 GROUP BY constituent_system_id
					, constituent_lookup_id
					, constituent_dim_id
		 ) non_vcu_educ on non_vcu_educ.constituent_system_id = b.CONSTITUENTSYSTEMID


	left join (		--(n=17kk, t=3s)
			SELECT constituentdimid
				 , count(*) as num_email_clicks_last365
    
			  FROM BBCRM_PROD_RPT_BBDW.BBDW.VCU_V_QUERY_COMMUNICATIONSHISTORY comm
			 where comm.response in ('E-mail clicked','eclick')
			   and comm.channel = 'Email'
			   and datediff(day,comm.datesent,getdate()) <= 365
			 group by constituentdimid

			) eclick on eclick.CONSTITUENTDIMID = b.CONSTITUENTDIMID

	left join ( --(n= 2031 t=1 sec)
			SELECT constituent_system_id
				 , max(flag_platinum_board_member) as flag_platinum_board_member
			  FROM DARanalytics.ref.committees_member_prework campw
			 WHERE isnull(campw.end_date,'2099-12-31') >= getdate()			--active members only
		  GROUP BY constituent_system_id
		  ) committees2 on committees2.constituent_system_id = b.CONSTITUENTSYSTEMID

	left join (		--(n=19k, t=1s)
			SELECT 
			   p.CONSTITUENTSYSTEMID  as parent_system_id
			 , p.CONSTITUENTDIMID     as parent_dim_id

			  -- This STRING_AGG combines all student names and units associated with a single parent
			  ,STRING_AGG(concat( edu.FULLNAME
								, ': ('
								, edu.unit_name 
								, ' ['
								, edu.education_program_short
								, ']'
								, ')'
								)
						 , '; '
						 ) as bio_parents_of_students_names
      
		  from (
				-- Subquery to get the latest education record for each current student
				select * from (
							  select ed.constituent_dim_id
								   , ed.constituent_system_id
								   , ed.EDUCATIONDIMID
								   , ed.bio_lastcommafirstname as FULLNAME
								  -- , ed.CONSTITUENCY
								   , ed.EDUCATIONALCOLLEGE
								   , ed.EDUCATIONALDEGREETYPE
								   , ed.EDUCATIONDEGREE
								   , ed.EDUCATIONPROGRAM
								   ,case when ed.EDUCATIONPROGRAM = 'Undergraduate' then 'UGrad'
										 when ed.EDUCATIONPROGRAM in ('Graduate','Doctorate') then 'Grad'
										 else ed.EDUCATIONPROGRAM
										 end as education_program_short
								  -- , ed.PROSPECTSTATUS
								   , COALESCE(sui.unit_name, 
										  CASE WHEN ed.EDUCATIONALCOLLEGE = 'Engineering & Pharmacy' THEN 'College of Engineering'
											   WHEN ed.EDUCATIONALCOLLEGE = 'Schools of Business & Engineer' THEN 'College of Engineering'
											   ELSE NULL END) as unit_name
								   , COALESCE(sui.unit_id, 
										  CASE WHEN ed.EDUCATIONALCOLLEGE = 'Engineering & Pharmacy' THEN '225'
											   WHEN ed.EDUCATIONALCOLLEGE = 'Schools of Business & Engineer' THEN '225'
											   ELSE NULL END) as unit_id
								   , row_number() over (partition by ed.CONSTITUENT_SYSTEM_ID order by ed.EDUCATIONSTARTDATE desc, ed.EDUCATIONINFORMATIONSOURCEDATE desc) as row_num
							from DARanalytics.tableau.vcu_education_degrees ed
							--from BBCRM_PROD_RPT_BBDW.BBDW.DIM_EDUCATION edu
						  -- left join BBCRM_PROD_RPT_BBDW.BBDW.VCU_RPT_CONSTITUENTLIST as cl on cl.constituentsystemid = edu.CONSTITUENTSYSTEMID --cl is student infomation
						  -- left join BBCRM_PROD_RPT_BBDW.BBDW.DIM_EDUCATIONADDITIONALINFORMATION ei on ei.CONSTITUENTSYSTEMID = edu.CONSTITUENTSYSTEMID 
								--																and ei.educationdimid = edu.educationdimid	
						   left join DARanalytics.ref.school_unit_info sui on sui.education_college = ed.EDUCATIONALCOLLEGE
							   where ed.EDUCATIONCONSTITUENCYSTATUS = 'Currently attending' 
								 and ed.EDUCATIONINSTITUTION = 'Virginia Commonwealth University (VCU)'
								 and ed.EDUCATIONALDEGREETYPE = 'Primary Major'
								 and ed.constituent_system_id is not null
							  ) t
				  where row_num = 1
				 -- order by unit_name, unit_id
				) as edu 
  
		  left join BBCRM_PROD_RPT_BBDW.BBDW.v_FACT_CONSTITUENTRELATIONSHIP as p on p.RECIPROCALCONSTITUENTSYSTEMID = edu.CONSTITUENT_SYSTEM_ID -- only keeping students with parents--grab all parents (not just parents of students)

		 where 1=1
		   and p.CONSTITUENTRELATIONSHIPTYPEDIMID in (2, 103) --added 103 for step-parent...there might be other parent options but probably smaller numbers

		-- Only group by the parent ids
		GROUP BY
			   p.CONSTITUENTSYSTEMID
			  ,p.CONSTITUENTDIMID
			) par_students on par_students.parent_system_id = b.CONSTITUENTSYSTEMID

left join (  --engagement by constituent as opposed to engagement by officer  (n=244k, t=17s)
			select constituent_system_id
				 , count (*) as num_engagements_lifetime
				 , sum (case when engagement_date_FY between 2021 and 2030 then 1 else 0 end ) as num_engagements_campaign
				 , max (engagement_date) as max_engagement_date
				 , min (engagement_date) as min_engagement_date
				 , sum (case when (engagement_point like '%email%' or engagement_point like '%interactions%') and datediff(month,engagement_date,getdate()) <= 24 then 1 else 0 end) as num_email_n_interactions_last24months
				 , sum (case when engagement_point ='Social media engagement' and datediff(month,engagement_date,getdate()) <= 24 then 1 else 0 end) as num_social_media_engagement_last24months
			  
			  from DARanalytics.tableau.constituent_engagement
			-- where case_bucket != 'Philanthropy'  --20251217 recent gifts foul the model  --GT thinks we can include this as an engagement point
			 group by constituent_system_id
		  ) as ce on ce.constituent_system_id = b.CONSTITUENTSYSTEMID

left join (  --latest significant 2030 interaction information - primary (n=22.6k, t=0s)
		select constituent_system_id
			 , constituent_lookup_id
			 , household_id
			 , interaction_actual_date
			 , interaction_owner_name
			 , interaction_owner_system_id
			 , interaction_type
		  from (
				SELECT -- [z_last_update]
					   [interaction_constituent_combo_id]
					  ,[interaction_system_id]
					  ,[constituent_lookup_id]
					  ,[constituent_system_id]
					  ,[household_id]
			 
					  --,[officer_lookup_id]
					  --,[officer_system_id]
					  ,[officer_interaction_role]
					  ,[officer_interaction_role_detail]
					  --,[bio_name]
					  ,[bio_lastcommafirstname]
					  --,[pm_ofcr_manage_status]
					  --,[flag_ofcr_currently_managed]
					  --,[flag_ofcr_current_prospect_manager]
					  ,[officer_name]
					  ,[primary_fundraiser_name]
					  ,[officer_name_morethanGOI]
					  ,[primary_fundraiser_name_morethanGOI]
					  --,[unit_id]
					  --,[unit_name]
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
					  ,[interaction_category]
					  ,[interaction_type]
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
					  ,[interaction_actual_date]
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
					  ,[interaction_owner_name]
					  ,[interaction_owner_system_id]
					  --,[bio_age]
					  --,[bio_death_date]
					  --,[gvg_recog_raised_life_hh]
					  --,[eval_vcu_planned_giving_score_sql]
					  --,[flag_has_pg_vehicle_hh]
					  --,[pm_current_team]
					  ,row_number() over( partition by constituent_system_id
											  order by interaction_actual_date desc
													 , interaction_sequence desc
													 , officer_interaction_role desc			--Primary, Participant, Additional
													 , officer_interaction_role_detail desc		--Primary -> Primary, Primary -> Participant, Additional
										) as rank_latest_completed_sig2030_interaction_primary
				  FROM DARanalytics.tableau.officer_unit_constituent_interactions_all
				  where interaction_status = 'completed'
					and flag_sig_interaction_2030 = 1
					) as late_inter
				where rank_latest_completed_sig2030_interaction_primary = 1

		) last_sig2030_interaction on last_sig2030_interaction.constituent_system_id = b.CONSTITUENTSYSTEMID

left join (		--(n=244k, t=9s)
			select CONSTITUENTID as constituent_system_id 
				 , max(case when engagementpoint = 'Email click through' then engagementdate else NULL end) as engagement_latest_email_click_through
				 , max(case when engagementpoint = 'Event Attendance' then engagementdate else NULL end) as engagement_latest_event_attendance
				 , max(case when engagementpoint like '%season ticket%' then 1 else 0 end) as engagement_flag_season_ticket_holder
			  from BBCRM_PROD_RPT_BBDW.BBDW.VCU_FACT_CONSTITUENTENGAGEMENT
			 where ENGAGEMENTDATE <= getdate()	--dont want future events
			 group by CONSTITUENTID
		 ) engagements on engagements.constituent_system_id = b.CONSTITUENTSYSTEMID

left join (		--(n=3234, t=0s)
		   select max(cnt) as max_num_SPV_visits
			 , constituent_lookup_id
			 , constituent_system_id
			 , bio_lastcommafirstname
		  from (

				SELECT count(*) as cnt
					 , bio_lastcommafirstname
					 , constituent_lookup_id
					 , constituent_system_id
					 , officer_lookup_id
					 , officer_system_id
					 , officer_name

				  FROM DARanalytics.tableau.officer_unit_constituent_interactions_all i
				  left join (	SELECT interaction_system_id
									 , max(flag_officer_is_non_DAR_leadership) as flag_interaction_includes_non_DAR_leadership

								  FROM DARanalytics.tableau.officer_unit_constituent_interactions_all
								 where interaction_type in ('SPV','Campus Visit','Presidential/Dean/Faculty/Volunteer Solicitor Interaction')--= 'SPV'
								   and interaction_actual_date between dateadd(month,-24,getdate()) and getdate()
								 group by interaction_system_id
							 ) i_lead on i_lead.interaction_system_id = i.interaction_system_id
				  where i.interaction_type in ('SPV','Campus Visit','Presidential/Dean/Faculty/Volunteer Solicitor Interaction') --= 'SPV'													--SPV interactions only
					and i.interaction_actual_date between dateadd(month,-24,getdate()) and getdate()	--interactions in the last 24 months
					and i.flag_officer_is_non_DAR_leadership = 0			--interactions by fundraisers (not non_DAR_leadership)
					--and officer_interaction_role <> 'Discovery'
					and i_lead.flag_interaction_includes_non_DAR_leadership = 0
				  group by officer_system_id, officer_lookup_id, constituent_system_id, constituent_lookup_id, bio_lastcommafirstname, officer_name
				) t

		   group by t.constituent_system_id, t.constituent_lookup_id, t.bio_lastcommafirstname

			--order by max_num_SPV_visits desc
	) spvs on spvs.constituent_system_id = b.CONSTITUENTSYSTEMID

left join (		--RNL survey interest attribute  (n=104, t=0s)
			select fca.constituentsystemid
				 , fca.constituentdimid
				 , max(case when fca.ATTRIBUTEVALUESYSTEMID = 'A28726CC-46FC-4365-8E84-265F61208219' then 1 else 0 end) as flag_rnl_interest_has_DAF 
			  from bbcrm_prod_rpt_bbdw.bbdw.fact_constituentattribute fca
			 where fca.ATTRIBUTEVALUESYSTEMID = 'A28726CC-46FC-4365-8E84-265F61208219'		--Self-reported Giving via DAF or Family Foundation
		  group by fca.constituentsystemid
				 , fca.constituentdimid
		  ) RNL_interest on RNL_interest.CONSTITUENTSYSTEMID = b.CONSTITUENTSYSTEMID

left join (		--lifetime non-VCU confirmed giving	(n=19k, t=1s)
			select CONSTITUENTID
				  ,sum(CVALUE) as gvg_life_total_non_VCU

			from BBCRM_PROD_RPT_BBDW.BBDW.VCU_FACT_WPPHILANTHROPICGIFT
			where ORGANIZATION not like '%Virginia Commonwealth University%'
			  and ORGANIZATION not in ('','Medical College of Virginia Foundation')
			  and ORGANIZATION not like '%VCU%'
			  and confirmed = 1
			group by CONSTITUENTID --, NAME  --too many variants
		  ) non_vcu_gvg on non_vcu_gvg.CONSTITUENTID = b.CONSTITUENTSYSTEMID


	/* PAST Committee group codes -- events, gift clubs, committees. 
	   For some reason there are a fair number of people with NULL start dates on these so we throw in 1959-12-31 as an obvious default.  
	   Gonna party like its 1959
	*/
	left join ( --(n=5356 t=1s)
	
		select constituent_dim_id
				 , constituent_system_id
				 , 1 as flag_committee_member_past
				 , max(case when board_group_type like '%board%' then 1 else 0 end)	 as flag_board_member_past
				 , max(case when flag_is_board_primary = 1 then 1 else 0 end)	 as flag_board_primary_member_past
				 , max(isnull(end_date,'1959-12-31')) as latest_past_committee_end_date
				 , min(isnull(end_date,'1959-12-31')) as earliest_past_committee_end_date
				 , max(case when board_group_type like '%board%' then isnull(end_date,'1959-12-31') else null end) as latest_past_board_end_date
				 , min(case when board_group_type like '%board%' then isnull(end_date,'1959-12-31') else null end) as earliest_past_board_end_date
				 , max(case when flag_is_board_primary = 1 then isnull(end_date,'1959-12-31') else null end) as latest_past_board_primary_end_date
				 , min(case when flag_is_board_primary = 1 then isnull(end_date,'1959-12-31') else null end) as earliest_past_board_primary_end_date
 				 , max(case when rownum = 1 then board_description + ' ' + '(' + convert(nvarchar(4),year(isnull(end_date,'1959-12-31'))) + ')' else null end)
     			  +max(case when rownum = 2 then isnull('; ' + board_description + ' (' + convert(nvarchar(4),year(isnull(end_date,'1959-12-31'))) + ')','') else '' end)
      			  +max(case when rownum = 3 then isnull('; ' + board_description + ' (' + convert(nvarchar(4),year(isnull(end_date,'1959-12-31'))) + ')','') else '' end) as latest_committees_past

				-- ,string_agg(committee.board_description + ' ' + '(' + convert(nvarchar(4),year(isnull(end_date,'1959-12-31'))) + ')',',') as latest_committees_past2
      			 , max(case when board_group_type like '%board%' and rownum = 1 then board_description + ' ' + '(' + convert(nvarchar(4),year(isnull(end_date,'1959-12-31'))) + ')' else null end)
      			  +max(case when board_group_type like '%board%' and rownum = 2 then isnull('; ' + board_description + ' (' + convert(nvarchar(4),year(isnull(end_date,'1959-12-31'))) + ')','') else '' end)
      			  +max(case when board_group_type like '%board%' and rownum = 3 then isnull('; ' + board_description + ' (' + convert(nvarchar(4),year(isnull(end_date,'1959-12-31'))) + ')','') else '' end) as latest_boards_past

		 from (
				SELECT campw.constituent_group_dim_id
					  ,campw.board_description
					  ,campw.constituent_group_lookup_id
					  ,campw.flag_is_board_primary			--this list of boards comes from PD and is their list they make sure the members are correct every Aug
					  ,campw.board_group_type
					  ,campw.constituent_dim_id
					  ,campw.constituent_system_id
					  ,campw.bio_name
					  ,campw.constituent_group_system_id
					  ,campw.start_date
					  ,campw.end_date
					  ,row_number() over ( 
      								partition by
      									campw.constituent_system_id
      								order by
      									 campw.end_date desc
      									,campw.start_date desc
      									,case when isnull(campw.board_DESCRIPTION,'') <> '' then campw.board_description
											  else campw.constituent_group_name
											   end ) as rownum

				  FROM DARanalytics.ref.committees_member_prework campw
  														
				  WHERE (campw.board_group_type like '%Board%' or campw.board_group_type like '%giving circle%')   -- gets rid of Presidential Leadership Donors and ICA group
					  and isnull(campw.end_date,'2099-12-31') < getdate()		--past members only
					--  and fcgm.MEMBERCONSTITUENTSYSTEMID is not NULL			--handled by prework
				 --order by group_type
				 ) committee

		 group by constituent_system_id, constituent_dim_id

 ) past_committees on past_committees.constituent_system_id = b.CONSTITUENTSYSTEMID

 	/* used by NYU Binning view event registration info for current FY (n=28k, t=0s) */
		left join DARanalytics.tableau.event_attendees_by_FY ea_fy on ea_fy.constituent_system_id = b.constituentsystemid
																	and ea_fy.fy = year(dateadd(month,6,getdate()))

	/* used by NYU Binning view event registration info for current FY (n=28k, t=0s)  - changed to attendees only....anyone can register....you gotta show*/
		--left join DARanalytics.tableau.event_registrants_by_FY er_fy on er_fy.constituent_system_id = b.constituentsystemid
		--															and er_fy.fy = year(dateadd(month,6,getdate()))
		
	/* used by NYU Binning (n=2186, t=0s)*/	
		left join (
					SELECT constituent_system_id
						 , 1 as flag_is_volunteer
						 , count(*) as num_volunteer_campaign
						 , sum(case when engagement_date_FY between year(dateadd(month,6,getdate()))-5 and year(dateadd(month,6,getdate()))-1 then 1 else 0 end) as num_volunteer_tminus1_5
						 , sum(case when engagement_date_FY = year(dateadd(month,6,getdate())) then 1 else 0 end)  as num_volunteer_currentFY
					  FROM DARanalytics.tableau.constituent_engagement
					 where case_bucket = 'Volunteerism'
					   and engagement_date between '2020-07-01' and getdate()		--campaign or later only
					   and engagement_point not like '%board member%'
					 group by constituent_system_id
					 --order by num_volunteer_currentFY desc
				  ) vol_vol on vol_vol.constituent_system_id = b.constituentsystemid
	
	left join (
				   SELECT bio_lastcommafirstname
						, constituent_system_id
						, constituent_lookup_id
						, count(*) as num_campus_visits
						, max(interaction_actual_date) latest_campus_visit
					 FROM DARanalytics.tableau.officer_unit_constituent_interactions_all
					WHERE interaction_type = 'Campus Visit'
					  and interaction_actual_date >= '2020-07-01'
				 GROUP BY bio_lastcommafirstname
						, constituent_system_id
						, constituent_lookup_id
			) campus_visit on campus_visit.constituent_system_id = b.CONSTITUENTSYSTEMID



	left join (		--for Principal Giving Checklist #13 Meaningful engagement with spouse
					SELECT i.constituent_system_id
					  FROM DARanalytics.tableau.officer_unit_constituent_interactions_all i
					  left join DARanalytics.tableau.officer_unit_constituent_interactions_all i2 on i.interaction_system_id = i2.interaction_system_id

					 where i.interaction_type in ('SPV','Campus Visit','Presidential/Dean/Faculty/Volunteer Solicitor Interaction')
					   and i.spouse_system_id = i2.constituent_system_id
					   and datediff(day,i.interaction_actual_date,getdate()) < 1825
					   and i.interaction_status = 'Completed'			--redundant
					 group by i.constituent_system_id
			) SPV_wSpouse on SPV_wSpouse.constituent_system_id = b.CONSTITUENTSYSTEMID


-- Reunion Eligible Peeps based on Al's Black Magic ugliness Reunion Code.  Will build over the years.

--'Current' Reunion Class only - Updated by Al each May/June to switch out to next class	(n=12.5k, t=0s)
	left join ( 
			select CONSTITUENTSYSTEMID
				 , 1 as flag_current_reunion_class
				 , min(reunionyear) as reunion_year
				 , string_agg(REUNIONSCHOOL,';') as list_of_current_reunion_schools
				 , string_agg(CLASSOF,';') as list_of_current_reunion_class_years
				 , string_agg(REUNIONDEGREE,';') as list_of_current_reunion_degrees
				 , string_agg(REUNIONDEPARTMENT,';') as list_of_current_reunion_departments
				 , count(*) as cnt
				 from BBCRM_PROD_RPT_BBDW.BBDW.VCU_RPT_REUNION
				 where reunionyear = (select max(reunionyear) as year 
										from BBCRM_PROD_RPT_BBDW.BBDW.VCU_RPT_REUNION)
				 group by CONSTITUENTSYSTEMID 
				-- order by cnt desc
			 ) reunion on reunion.CONSTITUENTSYSTEMID = b.CONSTITUENTSYSTEMID

/*Outer Where clause for entire constituent*/
--WHERE --b.ISCONSTITUENT = 1
  --and b.constituentsystemid <> '00000000-0000-0000-0000-000000000000'
 /*  b.constituent_id not in (
		select constituent_id
		from analytics.ref.entities_to_exclude EtoE 
		--where flag_training_record = 1  -- I think we want to exclude all these records, not just the testing ones. GT 10/19
		)
	--and right(b.constituent_id,2) = '66'   --testing take a small sample size
	and b.PRIMARY_RECORD_STATUS not in ('X','V')  --dropping 9k deleted records and 600 dissolved records

*/

/*ADJUSTMENTS */
--dead people have no connectedness
UPDATE datamart.constituent_level_temp  set
eval_vcu_connectedness_score = (case --when flag_living = 1 and flag_individual=1 and bio_constituency_list in ('','Individual')  then 0 --,'Prospect','Individual, Prospect') --not needed anymore - fixed in other ways
									 when flag_living = 1 then eval_vcu_connectedness_score 
									 else NULL end)			--deceased get NULL value

UPDATE datamart.constituent_level_temp  set
eval_vcu_connectedness_desc = (case --when bio_constituency_list in ('','Individual','Prospect','Individual, Prospect') then 'E Not Connected'  --this may be redundant given the above update. manually moving these people to Not Connected (from PD March 2026)
									when eval_vcu_connectedness_score >= 22 then 'A Very Connected'			--moved 20 and 21 to B on 7/24/26 to make A more elite
									when eval_vcu_connectedness_score >= 16 then 'B Connected'				--changed from 15 to 16 to lower the number of C2 HHs (was at 16.6K on 11/13/25)
									when eval_vcu_connectedness_score >= 10 then 'C Somewhat Connected'
									when eval_vcu_connectedness_score >= 5  then 'D Modestly Connected'
									when eval_vcu_connectedness_score  < 5  then 'E Not Connected'
									--when eval_vcu_connectedness_score <1  then 'F Not Connected'
									else NULL end)

/*Update new in-house eval_vcu_connectedness strikezone*/
UPDATE datamart.constituent_level_temp  set
  flag_strikezone_new = ( case when eval_vcu_connectedness_desc in ('A Very Connected','B Connected')
								and eval_capacity_rating between 5 and 15 then 1 else 0 end )


/* Update eval_default_segment_grid_rank*/
UPDATE datamart.constituent_level_temp  set
  eval_default_segment_grid_rank = (
		case when left(eval_vcu_connectedness_desc,1) = 'A' and left(eval_capacity_rating_desc_short_sort,1) = 'A' then 1
			 when left(eval_vcu_connectedness_desc,1) = 'B' and left(eval_capacity_rating_desc_short_sort,1) = 'A' then 2
			 when left(eval_vcu_connectedness_desc,1) = 'A' and left(eval_capacity_rating_desc_short_sort,1) = 'B' then 3
			 when left(eval_vcu_connectedness_desc,1) = 'B' and left(eval_capacity_rating_desc_short_sort,1) = 'B' then 4
			 when left(eval_vcu_connectedness_desc,1) = 'A' and left(eval_capacity_rating_desc_short_sort,1) = 'C' then 5
			 when left(eval_vcu_connectedness_desc,1) = 'B' and left(eval_capacity_rating_desc_short_sort,1) = 'C' then 6
			 when left(eval_vcu_connectedness_desc,1) = 'A' and left(eval_capacity_rating_desc_short_sort,1) = 'D' then 7
			 when left(eval_vcu_connectedness_desc,1) = 'B' and left(eval_capacity_rating_desc_short_sort,1) = 'D' then 8
			 when left(eval_vcu_connectedness_desc,1) = 'A' and left(eval_capacity_rating_desc_short_sort,1) = 'E' then 9
			 when left(eval_vcu_connectedness_desc,1) = 'B' and left(eval_capacity_rating_desc_short_sort,1) = 'E' then 10
			 when left(eval_vcu_connectedness_desc,1) = 'A' and left(eval_capacity_rating_desc_short_sort,1) = 'F' then 11
			 when left(eval_vcu_connectedness_desc,1) = 'B' and left(eval_capacity_rating_desc_short_sort,1) = 'F' then 12
			 when left(eval_vcu_connectedness_desc,1) = 'C' and left(eval_capacity_rating_desc_short_sort,1) = 'A' then 13
			 when left(eval_vcu_connectedness_desc,1) = 'C' and left(eval_capacity_rating_desc_short_sort,1) = 'B' then 14
			 when left(eval_vcu_connectedness_desc,1) = 'C' and left(eval_capacity_rating_desc_short_sort,1) = 'C' then 15
			 when left(eval_vcu_connectedness_desc,1) = 'C' and left(eval_capacity_rating_desc_short_sort,1) = 'D' then 16
			 when left(eval_vcu_connectedness_desc,1) = 'A' and left(eval_capacity_rating_desc_short_sort,1) = 'G' then 17
			 when left(eval_vcu_connectedness_desc,1) = 'B' and left(eval_capacity_rating_desc_short_sort,1) = 'G' then 18
			 when left(eval_vcu_connectedness_desc,1) = 'A' and left(eval_capacity_rating_desc_short_sort,1) = 'H' then 19
			 when left(eval_vcu_connectedness_desc,1) = 'B' and left(eval_capacity_rating_desc_short_sort,1) = 'H' then 20
			 when left(eval_vcu_connectedness_desc,1) = 'A' and left(eval_capacity_rating_desc_short_sort,1) = 'I' then 21
			 when left(eval_vcu_connectedness_desc,1) = 'B' and left(eval_capacity_rating_desc_short_sort,1) = 'I' then 22
			 when left(eval_vcu_connectedness_desc,1) = 'C' and left(eval_capacity_rating_desc_short_sort,1) = 'E' then 23
			 when left(eval_vcu_connectedness_desc,1) = 'C' and left(eval_capacity_rating_desc_short_sort,1) = 'F' then 24
			 when left(eval_vcu_connectedness_desc,1) = 'C' and left(eval_capacity_rating_desc_short_sort,1) = 'G' then 25
			 when left(eval_vcu_connectedness_desc,1) = 'D' and left(eval_capacity_rating_desc_short_sort,1) = 'A' then 26
			 when left(eval_vcu_connectedness_desc,1) = 'D' and left(eval_capacity_rating_desc_short_sort,1) = 'B' then 27
			 when left(eval_vcu_connectedness_desc,1) = 'D' and left(eval_capacity_rating_desc_short_sort,1) = 'C' then 28
			 when left(eval_vcu_connectedness_desc,1) = 'D' and left(eval_capacity_rating_desc_short_sort,1) = 'D' then 29
			 when left(eval_vcu_connectedness_desc,1) = 'D' and left(eval_capacity_rating_desc_short_sort,1) = 'E' then 30
			 when left(eval_vcu_connectedness_desc,1) = 'A' and left(eval_capacity_rating_desc_short_sort,1) = 'J' then 31
			 when left(eval_vcu_connectedness_desc,1) = 'B' and left(eval_capacity_rating_desc_short_sort,1) = 'J' then 32
			 when left(eval_vcu_connectedness_desc,1) = 'D' and left(eval_capacity_rating_desc_short_sort,1) = 'F' then 33
			 when left(eval_vcu_connectedness_desc,1) = 'D' and left(eval_capacity_rating_desc_short_sort,1) = 'G' then 34
			 when left(eval_vcu_connectedness_desc,1) = 'A' and left(eval_capacity_rating_desc_short_sort,1) = 'K' then 35
			 when left(eval_vcu_connectedness_desc,1) = 'B' and left(eval_capacity_rating_desc_short_sort,1) = 'K' then 36
			 when left(eval_vcu_connectedness_desc,1) = 'A' and left(eval_capacity_rating_desc_short_sort,1) = 'L' then 37
			 when left(eval_vcu_connectedness_desc,1) = 'B' and left(eval_capacity_rating_desc_short_sort,1) = 'L' then 38
			 when left(eval_vcu_connectedness_desc,1) = 'C' and left(eval_capacity_rating_desc_short_sort,1) = 'H' then 39
			 when left(eval_vcu_connectedness_desc,1) = 'C' and left(eval_capacity_rating_desc_short_sort,1) = 'I' then 40
			 when left(eval_vcu_connectedness_desc,1) = 'C' and left(eval_capacity_rating_desc_short_sort,1) = 'J' then 41
			 when left(eval_vcu_connectedness_desc,1) = 'C' and left(eval_capacity_rating_desc_short_sort,1) = 'K' then 42
			 when left(eval_vcu_connectedness_desc,1) = 'C' and left(eval_capacity_rating_desc_short_sort,1) = 'L' then 43
			 when left(eval_vcu_connectedness_desc,1) = 'D' and left(eval_capacity_rating_desc_short_sort,1) = 'H' then 44
			 when left(eval_vcu_connectedness_desc,1) = 'D' and left(eval_capacity_rating_desc_short_sort,1) = 'I' then 45
			 when left(eval_vcu_connectedness_desc,1) = 'D' and left(eval_capacity_rating_desc_short_sort,1) = 'J' then 46
			 when left(eval_vcu_connectedness_desc,1) = 'D' and left(eval_capacity_rating_desc_short_sort,1) = 'K' then 47
			 when left(eval_vcu_connectedness_desc,1) = 'D' and left(eval_capacity_rating_desc_short_sort,1) = 'L' then 48
			 when left(eval_vcu_connectedness_desc,1) = 'A' and left(eval_capacity_rating_desc_short_sort,1) = 'M' then 49
			 when left(eval_vcu_connectedness_desc,1) = 'B' and left(eval_capacity_rating_desc_short_sort,1) = 'M' then 50
			 when left(eval_vcu_connectedness_desc,1) = 'A' and left(eval_capacity_rating_desc_short_sort,1) in ('O','Z') then 51
			 when left(eval_vcu_connectedness_desc,1) = 'B' and left(eval_capacity_rating_desc_short_sort,1) in ('O','Z') then 52
			 when left(eval_vcu_connectedness_desc,1) = 'A' and left(eval_capacity_rating_desc_short_sort,1) = 'N' then 53
			 when left(eval_vcu_connectedness_desc,1) = 'B' and left(eval_capacity_rating_desc_short_sort,1) = 'N' then 54
			 when left(eval_vcu_connectedness_desc,1) = 'C' and left(eval_capacity_rating_desc_short_sort,1) = 'M' then 55
			 when left(eval_vcu_connectedness_desc,1) = 'C' and left(eval_capacity_rating_desc_short_sort,1) in ('O','Z') then 56
			 when left(eval_vcu_connectedness_desc,1) = 'C' and left(eval_capacity_rating_desc_short_sort,1) = 'N' then 57
			 when left(eval_vcu_connectedness_desc,1) = 'D' and left(eval_capacity_rating_desc_short_sort,1) = 'M' then 58
			 when left(eval_vcu_connectedness_desc,1) = 'D' and left(eval_capacity_rating_desc_short_sort,1) in ('O','Z') then 59
			 when left(eval_vcu_connectedness_desc,1) = 'D' and left(eval_capacity_rating_desc_short_sort,1) = 'N' then 60
			 when left(eval_vcu_connectedness_desc,1) = 'E' then 61
			 else NULL end
			 )


UPDATE datamart.constituent_level_temp 
set eval_overall_prospect_rank = case when prospect_rank_temp is not null then prospect_rank_temp else null end
		from				(select constituent_system_id
								  , constituent_lookup_id
								  ,	row_number() over(--partition by constituent_system_id 
													      order by eval_default_segment_grid_rank
												   			     , gvg_past5FY_raised			desc
															     , gvg_past5FY_received			desc
															     , gvg_lifetime_raised			desc
															     , gvg_lifetime_received		desc
																 , flag_is_primary_hh_member	desc
															     , constituent_lookup_id
														) as prospect_rank_temp
								from DARanalytics.datamart.constituent_level
								where eval_default_segment_grid_rank is not null		--must be in a grid
								  and flag_individual = 1								--no orgs for now
								  and z_exclude_groups = 'include'						--no ranking the weirdos
							) prospect_rank
		where prospect_rank.constituent_system_id = DARanalytics.datamart.constituent_level_temp.constituent_system_id	

UPDATE datamart.constituent_level_temp 
set flag_top_hh_member = case when top_member = 1 then 1 else 0 end
from					(select constituent_system_id
						  , row_number() over (partition by household_lookup_id
										order by
											 flag_living desc							--living before deceased
											,eval_vcu_connectedness_desc asc
											,eval_vcu_connectedness_score desc
											,gvg_life_ngp_recog desc					--lifetime giving
											,gvg_life_cash_recog desc
											,flag_is_primary_hh_member desc				--might as well use existing where there is no difference. Change this once RADAR uses this algorithm to avoid looping logic?
											,constituent_lookup_id asc	
											) as top_member
										from DARanalytics.datamart.constituent_level 
						) topHH
where topHH.constituent_system_id = DARanalytics.datamart.constituent_level_temp.constituent_system_id		

					--These are captured in the connectedness_score	
						--,case when flag_managed_currently = 1 then 1 else 2 end			--managed before unmanaged
						--,case when flag_alum = 1 then 1							--alums, parents, housestaff, others
						--	  when pm_flag_parent_has_vchild = 1 then 2
						--	  when pm_flag_parent_constituency = 1 then 3 
						--	  when flag_VCUHS_trainee = 1 then 4 
						--	  else 5 end
					 ----	,case when ila.ever_BOT_committee = '1' then 1 else 2 end           --board of trustee first
						--,case when flag_board_member_current = 1 then 1 else 2 end
						--,case when flag_committee_member_current = 1 then 1 else 2 end
					 ----	,case when ug.entity_id is not null then 1 else 0 end desc          --ugrad before grad
					--	,isnull(vol.days_of_vol_service,0) desc                             --the Jerry/Jessica Seinfeld rule

UPDATE datamart.constituent_level_temp				
set eval_VCU_principal_giving_score = eval_VCU_principal_giving_points * (case when eval_capacity_rating >20 then 2 else eval_capacity_rating end)		--handling 98 (cant rate) and 99 (data error) ratings

UPDATE datamart.constituent_level_temp				
set eval_VCU_principal_giving_rank = principal_giving_rank 
from	(  select constituent_system_id
				, row_number() over (order by eval_VCU_principal_giving_score	desc
				 						    , eval_VCU_connectedness_score		desc
											, gvg_past5FY_raised				desc
											, gvg_past5FY_received				desc
											, gvg_lifetime_raised				desc
											, gvg_lifetime_received				desc
											, eval_default_segment_grid_rank	asc
											, constituent_lookup_id				asc
											) as principal_giving_rank
				from DARanalytics.datamart.constituent_level 
			) pgr
			where pgr.constituent_system_id = DARanalytics.datamart.constituent_level_temp.constituent_system_id


END



/* STEP 4. CREATE INDEXES */

	/*clustered index must come first - before all nonclustered indexes - otherwise all nonclustered
	  indexes are deleted upon trying to run a clustered index
	  
	  If there is ever a problem with run time, comment out the indexes to rule them out.  Often they use up too much
	  temp space and bork the procedure*/

    --CREATE CLUSTERED INDEX ix_constituent_id
	--ON analytics.datamart.constituent_level (constituent_id);

	--changed online to ON so the underlying table is readable while index is being created.
	ALTER TABLE DARanalytics.datamart.constituent_level_temp
    ADD CONSTRAINT PK_Constituent_level_temp PRIMARY KEY (constituent_system_id);

/*	CREATE CLUSTERED INDEX ix_constituent_id ON DARanalytics.datamart.constituent_level_temp
	( constituent_system_id ASC
    ) WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, SORT_IN_TEMPDB = ON, 
	        DROP_EXISTING = OFF, ONLINE = ON, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON
			) ON PRIMARY;
*/
    CREATE NONCLUSTERED INDEX ix_constituent_dim_id
	ON DARanalytics.datamart.constituent_level_temp (constituent_dim_id);
    CREATE NONCLUSTERED INDEX ix_constituent_lookup_id
	ON DARanalytics.datamart.constituent_level_temp (constituent_lookup_id);
    CREATE NONCLUSTERED INDEX ix_constituent_system_id
	ON DARanalytics.datamart.constituent_level_temp (constituent_system_id);
    CREATE NONCLUSTERED INDEX ix_spouse_dim_id
	ON DARanalytics.datamart.constituent_level_temp (spouse_dim_id);
    CREATE NONCLUSTERED INDEX ix_spouse_system_id
	ON DARanalytics.datamart.constituent_level_temp (spouse_system_id);
    CREATE NONCLUSTERED INDEX ix_spouse_lookup_id
	ON DARanalytics.datamart.constituent_level_temp (spouse_lookup_id);
	CREATE NONCLUSTERED INDEX ix_household_id
	ON DARanalytics.datamart.constituent_level_temp (household_id);
	CREATE NONCLUSTERED INDEX ix_household_system_id
	ON DARanalytics.datamart.constituent_level_temp (household_system_id);
	CREATE NONCLUSTERED INDEX ix_household_lookup_id
	ON DARanalytics.datamart.constituent_level_temp (household_lookup_id);
	--CREATE NONCLUSTERED INDEX ix_firstname_id
	--ON DARanalytics.datamart.constituent_level_temp (bio_firstname);
	--CREATE NONCLUSTERED INDEX ix_lastname_id
	--ON DARanalytics.datamart.constituent_level_temp (bio_lastname);
	CREATE NONCLUSTERED INDEX ix_lastcommafirst_id
	ON DARanalytics.datamart.constituent_level_temp (bio_lastcommafirstname);
	--CREATE NONCLUSTERED INDEX ix_sp_firstname_id
	--ON DARanalytics.datamart.constituent_level_temp (spouse_firstname);
	--CREATE NONCLUSTERED INDEX ix_sp_lastname_id
	--ON DARanalytics.datamart.constituent_level_temp (spouse_lastname);
--	CREATE NONCLUSTERED INDEX ix_sp_lastcommafirst_id
--	ON DARanalytics.datamart.constituent_level_temp (spouse_lastcommafirstname);
	CREATE NONCLUSTERED INDEX ix_flag_is_primary_hh_member
	ON DARanalytics.datamart.constituent_level_temp (flag_is_primary_hh_member);
	CREATE NONCLUSTERED INDEX ix_flag_alum
	ON DARanalytics.datamart.constituent_level_temp (flag_alum);
--	CREATE NONCLUSTERED INDEX ix_flag_rated
--	ON DARanalytics.datamart.constituent_level_temp (flag_rated);
	CREATE NONCLUSTERED INDEX ix_flag_individual
	ON DARanalytics.datamart.constituent_level_temp (flag_individual);
	CREATE NONCLUSTERED INDEX ix_flag_living3
	ON DARanalytics.datamart.constituent_level_temp (flag_living);	
	CREATE NONCLUSTERED INDEX ix_eval_capacity_rating
	ON DARanalytics.datamart.constituent_level_temp (eval_capacity_rating);
	--CREATE NONCLUSTERED INDEX ix_flag_has_standard_enquire_opt_out
	--ON DARanalytics.datamart.constituent_level_temp (flag_has_standard_enquire_opt_out);
	--CREATE NONCLUSTERED INDEX ix_flag_constituent_to_exclude
	--ON DARanalytics.datamart.constituent_level_temp (flag_constituent_to_exclude);
	--CREATE NONCLUSTERED INDEX ix_flag_currently_managed
	--ON DARanalytics.datamart.constituent_level_temp (flag_currently_managed);
	CREATE NONCLUSTERED INDEX ix_bio_age
	ON DARanalytics.datamart.constituent_level_temp (bio_age);
	CREATE NONCLUSTERED INDEX ix_eval_record_standard_metal
	ON DARanalytics.datamart.constituent_level_temp (eval_record_standard_metal);

	/*SSMS Recommended Indexes*/
	CREATE NONCLUSTERED INDEX ix_affil_preferred_class
	ON DARanalytics.datamart.constituent_level_temp (affil_preferred_class);

	CREATE NONCLUSTERED INDEX ix_strikezone_new 
	ON DARanalytics.datamart.constituent_level_temp (flag_strikezone_new) 
	INCLUDE (eval_vcu_connectedness_score, eval_vcu_connectedness_desc);

	CREATE NONCLUSTERED INDEX ix_TP_parent
	ON DARanalytics.datamart.constituent_level_temp (flag_TP_parent) 
	INCLUDE (household_lookup_id, flag_TP_foundation, flag_TP_complex_assets, flag_TP_DAF);

	CREATE NONCLUSTERED INDEX ix_TP_parent2
	ON DARanalytics.datamart.constituent_level_temp (flag_TP_parent) 
	INCLUDE (constituent_lookup_id, flag_TP_foundation, flag_TP_complex_assets, flag_TP_DAF);

	CREATE NONCLUSTERED INDEX ix_flag_living
	ON DARanalytics.datamart.constituent_level_temp (flag_living) 
	INCLUDE (z_last_update, constituent_lookup_id, household_id, flag_is_primary_hh_member, bio_name, bio_lastcommafirstname, bio_gender, cntc_primary_phone, cntc_primary_email, cntc_spouse_primary_phone, cntc_spouse_primary_email, geo_addr_pref_type, geo_addr_pref_street, geo_addr_pref_city, geo_addr_pref_county, geo_addr_pref_state, geo_addr_pref_zip, geo_addr_pref_country, geo_addr_pref_lat, geo_addr_pref_long, geo_addr_pref_msa_desc, eval_capacity_rating_desc_sort, eval_capacity_rating_desc_short_sort, eval_bwf_connectedness, eval_vcu_connectedness_desc, pm_prospect_status, gvg_life_cash_recog, gvg_life_ngp_recog, flag_individual, flag_alum, flag_managed_currently, flag_managed_ever, flag_strikezone_new, flag_board_member_current, flag_contactable_email, flag_contactable_mail, flag_contactable_phone, flag_contactable_phone_business, flag_contactable_phone_cell, z_exclude_groups);

	CREATE NONCLUSTERED INDEX ix_flag_living2
	ON DARanalytics.datamart.constituent_level_temp (flag_living) 
	INCLUDE (constituent_dim_id, constituent_lookup_id, bio_lastcommafirstname, pm_prospect_status);

	CREATE INDEX ix_flag_living_individual
	ON DARanalytics.datamart.constituent_level_temp (flag_living, flag_individual)
	INCLUDE (household_id);

	--CREATE INDEX ix_bio_job_stuff2
	--ON DARanalytics.datamart.constituent_level_temp (bio_job_category, flag_living, bio_employer_name, bio_employer_system_id) 
	--INCLUDE (constituent_lookup_id, bio_job_title);

	CREATE INDEX ix_bio_job_stuff
	ON DARanalytics.datamart.constituent_level_temp (bio_job_category, flag_living, bio_employer_name, bio_employer_system_id)
	INCLUDE (constituent_lookup_id, bio_lastcommafirstname, bio_job_title, flag_individual);

	/*SolarWinds Recommended Indexes*/
	CREATE NONCLUSTERED INDEX ix_flag_is_primary_hh_member1
	ON DARanalytics.datamart.constituent_level_temp (flag_is_primary_hh_member) 
	INCLUDE (constituent_lookup_id,household_id,bio_name_tag,spouse_lookup_id,spouse_name,affil_school1
			,cntc_primary_phone,cntc_primary_email,geo_addr_pref_county,geo_addr_pref_state,geo_addr_pref_zip_US5
			,geo_addr_pref_country,geo_addr_pref_lat,geo_addr_pref_long,geo_addr_pref_msa_desc,eval_bwf_connectedness
			,gvg_latest_cash_recog,gvg_donor_category_live_hh);

	CREATE NONCLUSTERED INDEX ix_flag_is_primary_hh_member2
	ON DARanalytics.datamart.constituent_level_temp (flag_is_primary_hh_member,flag_living) 
	INCLUDE (constituent_dim_id,constituent_lookup_id,household_id,bio_lastcommafirstname,spouse_system_id
			,pm_current_team_lead,pm_prospect_status);

	CREATE NONCLUSTERED INDEX ix_flag_is_primary_hh_member3
	ON DARanalytics.datamart.constituent_level_temp (flag_is_primary_hh_member) 
	INCLUDE (household_system_id,household_id,spouse_lookup_id,spouse_name,geo_addr_pref_city,geo_addr_pref_county,geo_addr_pref_state,geo_addr_pref_zip_US5
			,geo_addr_pref_msa_desc,eval_bwf_connectedness);

	CREATE NONCLUSTERED INDEX ix_flag_is_primary_hh_member4
	ON DARanalytics.datamart.constituent_level_temp (flag_is_primary_hh_member) 
	INCLUDE (constituent_lookup_id,household_id,bio_name_tag,spouse_lookup_id,spouse_name,affil_school1,affil_preferred_class1,cntc_primary_phone,cntc_primary_email
			,geo_addr_pref_street,geo_addr_pref_city,geo_addr_pref_county,geo_addr_pref_state,geo_addr_pref_zip,geo_addr_pref_zip_US5,geo_addr_pref_country,geo_addr_pref_country_name
			,geo_addr_pref_country_name2,geo_addr_pref_lat,geo_addr_pref_long,geo_addr_pref_msa_desc,gvg_donor_category_live_hh);


   /*******************************************************************************************************************/
   /************************************************ SP LOAD TIME LOGGING *********************************************/
   /*******************************************************************************************************************/	
--CHECK IF TABLE IS NOT EMPTY or REDUCED


select  @rowsLoaded = count(*) from datamart.constituent_level_temp

if @rowsLoaded >= 500000
BEGIN
   IF  EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'datamart.constituent_level') AND type in (N'U'))
				 DROP TABLE datamart.constituent_level
	   exec sp_rename 'datamart.constituent_level_temp', 'constituent_level'
	--select @errorMessage = 'Successful overwrite of table ' + @destTable

	--exec analytics.dbo.sp_logTableLoad @destTable, N'finish', @startTime, @errorMessage, @rowsLoaded;
END
/*
ELSE

BEGIN
	select @errorMessage = 'constituent_level_temp seems off - go investigate: '
	exec analytics.dbo.sp_logTableLoad @destTable, N'finish', @startTime, @errorMessage, @rowsLoaded;
END
*/

	--rename the PK so the next time it is run the temp table won't have the same name and bomb.
	EXEC sp_rename N'datamart.PK_Constituent_level_temp', N'PK_Constituent_level'


END  --of stored procedure

GO

