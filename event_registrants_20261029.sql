USE [DARanalytics]
GO

/****** Object:  StoredProcedure [dbo].[uspBuildEventRegistrants]    Script Date: 10/29/2026 11:00:56 AM ******/
SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO









CREATE procedure [dbo].[uspBuildEventRegistrants] as



/*** OVERVIEW **********************************************************

**************************************************************************************************************************/

/*** CHANGE LOG (Newer changes at top) **********************************************************
20260727 / ww+gt / r=52322 / t=5s / add indexes
test 20260716 / ww / r=111393 / t=10s					/ Major row count increase due to request to look at all events 7/1/20 and after
20260706_2 / ww / r=51507 / t=5s				/ There, thats better!
20260706_1 / ww / r=51507 / t=5m53s		/ conversion from view to SP-DATAMART.  Current view r=51507 & t=5m53s.  Yikes! 
**************************************************************************************************************************/

begin

--no 1 row affected messages please
set nocount on;
--variable to hold row count for audit
declare 
	@rowcount_ww int,
	@rowcount_gt int,
	@errormessage nvarchar(1000),
	@destTable nvarchar(50)

/* STEP 1. DELETE TABLE, IF ALREADY EXISTS */
	IF OBJECT_ID('daranalytics.datamart.event_registrants_temp', 'U') IS NOT NULL 
	DROP TABLE daranalytics.datamart.event_registrants_temp;

/*STEP 2
Put a create table statement here to better control datatypes and sizes
we will initially create a temp table and then check
if that temp table is not empty, then write that table to actual.
if the temp table is empty, then take no action and alert me
*/
create table daranalytics.datamart.event_registrants_temp (
	
		z_last_update datetime not null
		,	start_date	date	null
		,	end_date date null
		,	start_date_dim_id	nvarchar(max)	null
		,	event_registrant_fact_id		int	null
		,	event_registrant_system_id	uniqueidentifier	not null
		,	event_registrant_lookup_id	nvarchar(200)	null
		,	event_registration_dim_id	int	null
		,	constituent_dim_id	int	null
		,	constituent_system_id	uniqueidentifier	null
		,	flag_nonconstituent_guest	tinyint	null
		,	attend_status	nvarchar(max)	null
		,	date_added	date	null
		,	registration_fee	nvarchar(max)	null
		,	registration_fee_received	nvarchar(max)	null
		,	modified_by	nvarchar(max)	null
		,	modified_date	date	null
		,	event_registation_codes_dim_id	nvarchar(max)	null
		,	event_price_fact_id	nvarchar(max)	null
		,	event_category	nvarchar(max)	null
		,	event_name	nvarchar(max)	null
		,	event_description	nvarchar(max)	null
		,	event_CSU_list	nvarchar(max)	null
		,	flag_event_is_active	tinyint	null
		,	event_lookup_id	nvarchar(100)	null
		,	event_dim_id	nvarchar(max)	null
		,	event_system_id	nvarchar(max)	null
		,	event_type	nvarchar(max)	null
		,	constituent_lookup_id	nvarchar(max)	null
		,	bio_lastcommafirstname	nvarchar(max)	null
		,	household_lookup_id	nvarchar(100)	null  --20260727
		,	household_system_id	nvarchar(max)	null
		,	household_id	nvarchar(max)	null
		,	bio_age	nvarchar(max)	null
		,	bio_generation	nvarchar(max)	null
		,	flag_alum	tinyint	null
		,	flag_individual	tinyint	null
		,	flag_living	tinyint	null
		,	flag_managed_currently	tinyint	null
		,	flag_strikezone_new	tinyint	null
		,	flag_VCU_employees_to_exclude_hh	tinyint	null
		,	gvg_donor_category_live_hh	nvarchar(max)	null
		,	num_events_attended_all	int	null
		,	num_events_attended_campaign	int	null
		,	num_events_attended_last_365 int	null
		,	num_events_attended_tminus0	int null
		,	num_events_attended_tminus1	int	null
		,	flag_managed_currently_hh	tinyint	null
		,	flag_living_hh	tinyint	null
		,	flag_strikezone_new_hh	tinyint	null
		,	eval_capacity_rating_desc_short_sort_hh	nvarchar(max)	null
		,	gvg_recog_raised_life_hh_6bin_desc	nvarchar(max)	null
		,	gvg_recog_raised_life_hh	nvarchar(max)	null
		,	bio_name_informal_hh_last	nvarchar(max)	null
		,	gvg_recog_raised_campaign_hh	nvarchar(max)	null
		,	gvg_recog_raised_tminus0_hh	nvarchar(max)	null
		,	flag_any_completed_interaction_last_365_hh	tinyint	null
		,	flag_any_completed_sig_interaction_last_365_hh	tinyint	null
		,	flag_any_completed_SPV_last_365_hh	tinyint	null
) on [PRIMARY];

/***********************************************************************************************/
/* STEP 3. Create CTEs */
with

fe as (  --FACT_EVENTREGISTRANT
	select
		cast ( de_cte.EVENTSTARTDATE as date) 		as start_date
		,cast ( de_cte.eventenddate as date )			as end_date
		,de_cte.EVENTENDDATEDIMID			as start_date_dim_id
		,EVENTREGISTRANTFACTID				as event_registrant_fact_id
		,EVENTREGISTRANTSYSTEMID			as event_registrant_system_id
		,EVENTREGISTRANTLOOKUPID			as event_registrant_lookup_id
		,EVENTREGISTRATIONDIMID				as event_registration_dim_id
		,CONSTITUENTDIMID							as constituent_dim_id
		,CONSTITUENTSYSTEMID					as constituent_system_id
		,cast(DATEADDED as date) 				as date_added
		,REGISTRATIONFEE							as registration_fee
		,REGISTRATIONFEERECEIVED			as registration_fee_received
		,MODIFIEDBYAPPUSERDIMID				as modified_by
		,MODIFIEDDATE									as modified_date
		,EVENTREGISTRATIONCODESDIMID	as event_registation_codes_dim_id
		,EVENTPRICEFACTID							as event_price_fact_id
		,fe_cte.EVENTDIMID							as event_dim_id
	FROM BBCRM_PROD_RPT_BBDW.BBDW.FACT_EVENTREGISTRANT fe_cte
	left join BBCRM_PROD_RPT_BBDW.BBDW.DIM_EVENT as de_cte on de_cte.EVENTDIMID = fe_cte.EVENTDIMID

	where 
		de_cte.EVENTSTARTDATE >= '07-01-2024'   --20260716 ju requests we move from 7/1/24 to 7/1/2020 and test
		and de_cte.EVENTSTARTDATE <= (GETDATE()+365)
		and fe_cte.EVENTDIMID != 352  --20251208 ww | this removes event_look_id 'evt-10002969', which is an DARIS-authored 'First Event' for GiveCampus testing
),

es as (
	select 
		count(*) as cnt
		, eventdimid
		, STRING_AGG(concat(sui.campaign_display_name,'' ), ', ') within group (order by sitedimid) as event_CSU_list
	from BBCRM_PROD_RPT_BBDW.BBDW.FACT_EVENTSITE es
	left join DARanalytics.ref.school_unit_info sui on sui.site_id = es.SITESYSTEMID
	group by eventdimid
),

de as (  --DIM_EVENT
	Select
		convert(date,EVENTSTARTDATE)	as start_date
		, convert(date,EVENTENDDATE)	as end_date
		,EVENTCATEGORY					as event_category
		,EVENTNAME						as event_name
		,EVENTDESCRIPTION				as event_description
		,EVENTISACTIVE					as flag_event_is_active
		,EVENTLOOKUPID					as event_lookup_id
		,EVENTDIMID					as event_dim_id
		,EVENTSYSTEMID					as event_system_id
		,EVENTTYPE						as event_type
	from BBCRM_PROD_RPT_BBDW.BBDW.DIM_EVENT
),

cl as (
	select
		constituent_lookup_id
		,constituent_system_id
		,bio_lastcommafirstname
		,household_lookup_id
		,household_system_id
		,household_id
		,bio_age
		,bio_generation
		,flag_alum
		,flag_individual
		,flag_living
		,flag_managed_currently
		,flag_strikezone_new
		,flag_VCU_employees_to_exclude_hh
		,gvg_donor_category_live_hh
	from  DARanalytics.datamart.constituent_level 
),

chl as (
	select
		household_system_id
		,flag_managed_currently_hh
		,flag_living_hh
		,flag_strikezone_new_hh
		,eval_capacity_rating_desc_short_sort_hh
		,gvg_recog_raised_life_hh_6bin_desc
		,gvg_recog_raised_life_hh
		,bio_name_informal_hh_last
		,gvg_recog_raised_campaign_hh
		,gvg_recog_raised_tminus0_hh
		,flag_any_completed_interaction_last_365_hh
		,flag_any_completed_sig_interaction_last_365_hh
		,flag_any_completed_SPV_last_365_hh
	from DARanalytics.datamart.constituent_household_level
),

dr as (
	select
		EVENTREGISTRATIONDIMID as event_registration_dim_id
		,case 
		when ATTENDED = 1 then 'Attended'
		when (iSCANCELLED = 1 or  WILLNOTATTEND = 1 ) then 'Did Not Attend'
		else 'Registration Only' end			as attend_status
	from BBCRM_PROD_RPT_BBDW.BBDW.DIM_EVENTREGISTRATION
),

num_events as (
	select distinct 
		FE.constituentsystemid as constituent_system_id
		,count( distinct 
			case when DE.EVENTSTARTDATE between getdate()-365 and getdate()
			then FE.EVENTSYSTEMID 
			else NULL end) 
		as num_events_attended_last_365
		,count(distinct case 
			when de.eventstartdate >= dateadd(month, 6, dateadd(year, difference(0, dateadd(month, -6, getdate())), 0)) 
			then fe.eventsystemid 
			else null end) 
		as num_events_attended_tminus0
		,count(distinct case 
			when de.eventstartdate >= dateadd(month, -6, dateadd(year, difference(0, dateadd(month, -6, getdate())), 0)) -- July 1st LAST year
			and de.eventstartdate <  dateadd(month, 6, dateadd(year, difference(0, dateadd(month, -6, getdate())), 0))  -- July 1st THIS year
			then fe.eventsystemid 
			else null end) 
		as num_events_attended_tminus1
		,count( distinct 
			case when DE.EVENTSTARTDATE >= '2020-07-01' 
			then FE.EVENTSYSTEMID 
			else NULL end) 
		as num_events_attended_campaign
		,count( distinct FE.EVENTSYSTEMID ) as num_events_attended_all
	from BBCRM_PROD_RPT_BBDW.BBDW.FACT_EVENTREGISTRANT as FE 
	inner join BBCRM_PROD_RPT_BBDW.BBDW.DIM_EVENT DE ON FE.EVENTDIMID = DE.EVENTDIMID
	where FE.constituentsystemid != '00000000-0000-0000-0000-000000000000'
	group by FE.constituentsystemid
)
/***********************************************************************************************/

/***********************************************************************************************/
/*STEP 4 - insert these tables into the temp table */
insert into daranalytics.datamart.event_registrants_temp
/***********************************************************************************************/

/*step 5 - FINAL ASSEMBLY */
select
	getdate() as z_last_update
	,fe.start_date
	,fe.end_date
	,fe.start_date_dim_id
	,fe.event_registrant_fact_id
	,fe.event_registrant_system_id
	,fe.event_registrant_lookup_id
	,fe.event_registration_dim_id
	,fe.constituent_dim_id
	,fe.constituent_system_id
	,case when fe.constituent_system_id = '00000000-0000-0000-0000-000000000000' then 1 else 0 end as flag_nonconstituent_guest
	,dr.attend_status
	,fe.date_added
	,fe.registration_fee
	,fe.registration_fee_received
	,fe.modified_by
	,fe.modified_date
	,fe.event_registation_codes_dim_id
	,fe.event_price_fact_id
	,de.event_category
	,de.event_name
	,de.event_description
	,es.event_CSU_list
	,de.flag_event_is_active
	,de.event_lookup_id
	,de.event_dim_id
	,de.event_system_id
	,de.event_type
	,cl.constituent_lookup_id
	,cl.bio_lastcommafirstname
	,cl.household_lookup_id
	,cl.household_system_id
	,cl.household_id
	,cl.bio_age
	,cl.bio_generation
	,cl.flag_alum
	,cl.flag_individual
	,cl.flag_living
	,cl.flag_managed_currently
	,cl.flag_strikezone_new
	,cl.flag_VCU_employees_to_exclude_hh
	,cl.gvg_donor_category_live_hh
	,num_events.num_events_attended_all
	,num_events.num_events_attended_campaign
	,num_events.num_events_attended_last_365
	,num_events.num_events_attended_tminus0
	,num_events.num_events_attended_tminus1
	,chl.flag_managed_currently_hh
	,chl.flag_living_hh
	,chl.flag_strikezone_new_hh
	,chl.eval_capacity_rating_desc_short_sort_hh
	,chl.gvg_recog_raised_life_hh_6bin_desc
	,chl.gvg_recog_raised_life_hh
	,chl.bio_name_informal_hh_last
	,chl.gvg_recog_raised_campaign_hh
	,chl.gvg_recog_raised_tminus0_hh
	,chl.flag_any_completed_interaction_last_365_hh
	,chl.flag_any_completed_sig_interaction_last_365_hh
	,chl.flag_any_completed_SPV_last_365_hh

from fe
inner join de on de.event_dim_id = fe.event_dim_id
inner join  DR on DR.event_registration_dim_id = FE.event_registration_dim_id

left join es on es.EVENTDIMID = de.event_dim_id

left join cl on cl.constituent_system_id = fe.constituent_system_id
left join chl on chl.household_system_id = cl.household_system_id
left join num_events on num_events.constituent_system_id = fe.constituent_system_id 


/**********************END OF SELECT INTO STATEMENT****************************************************/

/**optional step 6 - POINT IN TIME UPDATES 
commented out because I dont actually want to do this but do want to rememebr HOW to do  his
*/
--UPDATE daranalytics.datamart.event_registrants_temp
--set referral_to = 'Unknown'
--where referral_to is null or referral_to = 'N/A'

/** Index construction step 7
index wishlist
	constituent_system_id
	household_lookup_id
	event_registrant_system_id + event_lookup_id
**/
ALTER TABLE DARanalytics.datamart.event_registrants_temp
ADD CONSTRAINT pk_event_registrant_system_id_temp
PRIMARY KEY (event_registrant_system_id);

--CREATE NONCLUSTERED INDEX ix_constituent_system_id
--ON DARanalytics.datamart.event_registrants_temp (constituent_system_id);
--CREATE NONCLUSTERED INDEX ix_household_lookup_id
--ON DARanalytics.datamart.event_registrants_temp (household_lookup_id);
--CREATE NONCLUSTERED INDEX ix_event_registrant_system_id
--ON DARanalytics.datamart.event_registrants_temp (event_registrant_system_id);
--CREATE NONCLUSTERED INDEX ix_event_lookup_id
--ON DARanalytics.datamart.event_registrants_temp (event_lookup_id);

/* Step 8, set those variables I declared up in Step 0
Gotta happen here ebcause we have to actually run the table before getting these
constrast with something like 'Hello world' or getDATE() which can run anytime
*/
set @rowcount_ww = @@ROWCOUNT
set @destTable = 'daranalytics.datamart.event_registrants';

/*Step 9 - check if table is empty and either rewrite or flash error */
 select  @rowcount_gt = count(*) from daranalytics.datamart.event_registrants_temp

IF @rowcount_gt >= 1
BEGIN
    -- Drop the ACTUAL table if it exists so we can rename the temp one to take its place
    IF OBJECT_ID('daranalytics.datamart.event_registrants', 'U') IS NOT NULL 
        DROP TABLE daranalytics.datamart.event_registrants;
	
    EXEC sp_rename 'daranalytics.datamart.event_registrants_temp' , 'event_registrants';
    
    SET @errorMessage = 'Succesful overwrite of table ' + @destTable;
    PRINT 'Refreshed ' + CAST(@rowcount_ww AS VARCHAR(20)) + ' rows at ' + CAST(GETDATE() AS VARCHAR(50));

	end

  	--rename the PK so the next time it is run the temp table wont have the same name and bomb.
	EXEC sp_rename N'datamart.pk_event_registrant_system_id_temp', N'pk_event_registrant_system_id'

	end
GO

