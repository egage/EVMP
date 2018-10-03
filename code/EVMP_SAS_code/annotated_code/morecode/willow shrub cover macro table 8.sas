/*This program creates willow cover data found in table 8 of Zeigenfuss and Johnson (2015)--Average and maximum 
  willow height and percent willow cover on the elk winter range of Rocky Mountain National Park, Colorado, at
  baseline measurement (2008–9) and at first 5-yr sampling (2013). Estimates are for the macroplot methods described 
  in Zeigenfuss and others (2011) and include sites that were burned in 2013. The first step of the code reads in 
  data from a file contaning the baseline data from willow macroplots and calculates canopy area for
  each plot and assigns the baseline year (2008) to these data and sorts the data down to willow and non-willow 
  species groups. Then, total canopy area for each group (willow and non-willow) is calculated.*/ 


data shrubcover;
	infile 'c:\RMNP veg monitoring\data\willow macroplots.prn' firstobs=2;
	input date $ site_type $ site_number site_id $ sp $ pc_in_plot diam1 diam2 ht bud_scar_ht
		microplot $ stems_in_micro $ group $;
		if diam1=. then diam1=diam2;
		if diam2=. then diam2=diam1;
		area=(((diam1/100)*(diam2/100)*3.14159)/4)*(pc_in_plot/100);
		year=2008;
proc sort;
		by year site_type site_number site_id group;
	proc univariate noprint;
		by year site_type site_number site_id group;
		var area ;
		output out=out2008c sum=totareagenus   ;

/*Next,the code reads a file with information for 2013 cover measurements and performs the same steps as above 
  for these data.*/

data shrubcover1;
	infile 'c:\RMNP veg monitoring\5_yr_analysis\data\willow macro 2013.prn' firstobs=2;
	input  site_type $ site_number site_id $ sp $ pc_in_plot diam1 diam2 ht bud_scar_ht
		microplot $ stems_in_micro $ pcdead group $;
		if diam1=. then diam1=diam2;
		if diam2=. then diam2=diam1;
		area=(((diam1/100)*(diam2/100)*3.14159)/4)*(pc_in_plot/100);
		year=2013;
proc sort;
		by year site_type site_number site_id group;
	proc univariate noprint;
		by year site_type site_number site_id group;
		var area ;
		output out=out2013c sum=totareagenus   ;


/* Here the data are merged into a single dataset and proportion of willow cover per square meter from these
   16 sq. m plot is calculated*/


data shrubcover2;
	set out2008c out2013c;
	proc sort;
		by year site_type site_number site_id;
	proc transpose out=tranwilco;
		by year site_type site_number site_id;
		id group;
	
data shrubcover2a;
	set tranwilco;
	proc sort;
		by year site_type site_number site_id;
	proc transpose out=tranwilco2;
		by year site_type site_number site_id;
		
data shrubcover2b;
	set tranwilco2;
	if totareagenus=. then totareagenus=0;
	prop_cover=totareagenus/16;
	if prop_cover gt 1 then prop_cover=1;
	proc sort;
	by site_type site_number site_id;

/*Now, information on site characteristics for each plot are added read and then merged with the cover data from 
  2008 and 2013. Measurements on non-willows are removed from the dataset. Individual codes are assigned to group 
  the data by their "condition" into burned-grazed, burned-fenced, unburnd-grazed, and unburned-fenced groups. 
  A condition code of 'WN' is given to non-core sites.*/



data shrub;
	infile 'c:\RMNP veg monitoring\5_yr_analysis\data\willow site info 2013 revised 2015.prn' firstobs=2;
	input site_type $ site_number fence $ burn $;
	proc sort;
		by site_type site_number;

data shrubcover3;
	merge shrubcover2b shrub;
	by site_type site_number;
	title "willow macroplot cover";
	group=_name_;
	if group='nonwillo' then delete;
	if burn='Y' and fence='N'  then cond='BG';
	if burn='Y' and fence='Y'  then cond='BF';
	if burn='N' and fence='N' then cond='UG';
	if burn='N' and fence='Y'  then cond='UF';
	
	if site_type='WNC' then cond='WN';
	*proc print;


/*In this step, location codes are added to the data for some tests we did based on whether there were differences
  between Moraine Park, Horseshoe Park, Beaver Meadows, and non-core winter range sites. The mininum non-zero 
  proportion of shrub cover is substituted for areas with no shrub cover and (1 - this minimum) is used for sites
  with a proportion of 1. This transformation is done so that a log of proportion of cover can be tested 
  statistically.*/


data shrubcover_nb;
	set shrubcover3;
	*if year=2008 and  (cond='BG' or cond='BF') then cond='B';
if site_type='WC' and (site_number ge 76 or site_number=74 or (site_number ge 64 and site_number le 72) or site_number=62 or (site_number ge 52 and site_number
		le 57) or (site_number ge 24 and site_number le 35) or (site_number ge 37 and site_number le 39)) then loc='MP';
if site_type='WC' and (site_number=36 or (site_number ge 40 and site_number le 44) or (site_number ge 49 and site_number le 51) or (site_number ge 58 and
		site_number le 61) or site_number=63 or site_number=75)then loc='BM';
if site_type='WC' and (site_number le 23 or (site_number ge 45 and site_number le 48) or site_number=73) then loc='HP';
if site_type='WNC' then loc='WNC';
if prop_cover=0 then prop_cover1=0.00088;
if prop_cover=1 then prop_cover1=1-0.00088;
if prop_cover1=. then prop_cover1=prop_cover;
	*if burn='Y' then delete;
	*if fence='Y' then delete;
	if cond='BF' or cond='UF' then fencegroup='Y  ';
	if cond='UG' or cond='BG' then fencegroup='N  ';
	if site_type='WNC' then fencegroup='WNC';
	trancover=log(prop_cover1/(1-prop_cover1));
	proc sort;
		by  fencegroup ;
		proc  mixed;
		by fencegroup;
		*by  loc cond;
		class year site_id cond loc fencegroup;
	
		model trancover= year /ddfm=satterth;
		random site_id;
		lsmeans year /pdiff;

/*In this final step, weights are assigned for 2013 to account for the amount of willow falling into each condition
  group for each year. These weights are used to calculate weighted averages for willow coverin order to assess
  progress toward EVMP willow cover objectives.*/


data shrubcover_nb2;
	set shrubcover_nb;
	*if burn='Y' then delete;
	if year=2013 and cond='BF' or cond='UF' then areawt=0.202;
	if year=2013 and cond='UG' or cond='BG' then areawt=0.669;	
	if year=2008 and site_type='WC' then areawt=0.871;
if cond='BF' or cond='UF' then fencegroup='Y  ';
	if cond='UG' or cond='BG' then fencegroup='N  ';

	/*if year=2013 and cond='BF' then areawt=8.5;
	if year=2013 and cond='BG' then areawt=45;
	if year=2013 and cond='UG' then areawt=21.9;
	if year=2013 and cond='UF' then areawt=11.7;*/
	if site_type='WNC' then areawt=0.129;
	
	
	proc sort;	
	by year ;
	proc univariate noprint;
		by year  ;
		var prop_cover;
		weight areawt;
		output out=outcover mean=avpropcov stdmean=se n=n;
		proc print data=outcover;

		


run;
