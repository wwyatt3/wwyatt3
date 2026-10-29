USE [DARanalytics]
GO

/****** Object:  Table [ref].[gift_officer_level_goals]    Script Date: 10/29/2026 11:25:01 AM ******/
SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO

CREATE TABLE [ref].[gift_officer_level_goals](
	[level_name] [nvarchar](30) NULL,
	[goal_year] [nvarchar](10) NULL,
	[goal_portfolio_size] [nvarchar](10) NULL,
	[goal_num_50kplus_asks_ps] [smallint] NULL,
	[goal_num_50kplus_asks_ss] [smallint] NULL,
	[goal_num_50kplus_asks_closed_ps] [smallint] NULL,
	[goal_num_50kplus_asks_closed_ss] [smallint] NULL,
	[goal_avg_accepted_gift] [money] NULL,
	[goal_annual_minimum] [money] NULL,
	[goal_portfolio_activation_pct] [decimal](3, 2) NULL,
	[goal_hhs_cultivate] [smallint] NULL,
	[goal_referral_activity] [decimal](3, 2) NULL,
	[ask_range_minimum] [money] NULL,
	[ask_range_maximum] [money] NULL,
	[first_year_goal_portfolio_size] [nvarchar](10) NULL,
	[first_year_goal_num_50kplus_asks] [smallint] NULL,
	[first_year_goal_num_50kplus_asks_closed] [smallint] NULL,
	[first_year_goal_avg_accepted_gift] [money] NULL,
	[first_year_goal_annual_minimum] [money] NULL,
	[first_year_goal_portfolio_activation_pct] [decimal](3, 2) NULL,
	[first_year_goal_hhs_cultivate] [smallint] NULL,
	[first_year_goal_referral_activity] [decimal](3, 2) NULL,
	[goal_annual_top] [money] NULL,
	[goal_median_ask] [money] NULL,
	[goal_avg_ask] [money] NULL,
	[goal_discovery_plan_activity] [nvarchar](10) NULL,
	[goal_pct_time_fundraising] [decimal](3, 2) NULL,
	[goal_portfolio_ideal_pct_pm] [decimal](3, 2) NULL,
	[goal_portfolio_ideal_pct_team] [decimal](3, 2) NULL,
	[goal_portfolio_ideal_pct_stew] [decimal](3, 2) NULL,
	[goal_portfolio_ideal_pct_disc] [decimal](3, 2) NULL,
	[first_year_goal_hhs_qualify] [smallint] NULL
) ON [PRIMARY]
GO

