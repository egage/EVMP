/*This program creates data found in table 4 of Zeigenfuss and Johnson (2015)--Least squares means of aspen sapling (plants with height less than or equal 
  to 2.5 meters) density at all aspen monitoring sites in Rocky Mountain National Park, Colorado. The first step of the code reads
 in data from a file with tallies of live aspen stems by dbh size class. Then the code reads a file with information for each aspen monitoring site. In the
 third step, these two files are merged.*/

data aspen;
    infile 'c:\RMNP veg monitoring\5_yr_analysis\data\Aspen live stem tallies.csv' delimiter=',' firstobs=2;
    input sitetype $ sitenum siteid $ year dbh0_2 dbh2_4 dbh4_6 dbh6_8 dbh8_10 dbh10_12 dbh12_14 dbh14_16 dbh16_18 dbh18_20
        dbh20_22 dbh22_24 dbh24_26 dbh26_28 dbh28_30 dbh30_32 dbh32_34 dbh34plus ht0_50 ht51_100 ht101_150 ht151_200 ht201_250;
proc sort;
        by sitetype sitenum siteid;

data site_info;
    infile 'c:\RMNP veg monitoring\5_yr_analysis\data\Aspen monitoring site info.csv' delimiter=',' firstobs=2;
    input sitetype $ sitenum siteid $ fenced $ burned $ burnyear fence2013 $ distfence $ estab2013 $ slope aspect $ elev R_U $ barkscar
        ansign $ antype $;
        drop burnyear fence2013 distfence estab2013 ansign antype;
        proc sort;
            by sitetype sitenum siteid;

data aspenall;
    merge  site_info aspen;
    by sitetype sitenum siteid;
	*if siteid='AC1' or siteid='AC14' then delete;

/*Now, all tree-size stems (those with dbh classes--these are all stems >250 cm in height) are removed from the merged file and the file is now transposed 
  to provide an identifier for the first sampling period (time of site establishment--usually 2008) and the second sampling period (2013).*/ 


data aspensapling;
    set aspenall;
    drop dbh0_2 dbh2_4 dbh4_6 dbh6_8 dbh8_10 dbh10_12 dbh12_14 dbh14_16 dbh16_18 dbh18_20
        dbh20_22 dbh22_24 dbh24_26 dbh26_28 dbh28_30 dbh30_32 dbh32_34 dbh34plus;
    if year lt 2013 then sample=0;
    if year=2013 then sample=1;
    proc sort;
        by sitetype sitenum siteid fenced burned slope aspect elev R_U barkscar;
    proc transpose out=tran1;
        by sitetype sitenum siteid fenced burned slope aspect elev R_U barkscar;
        id sample;


/*This step performs some cleanup work is done on the remaining dataset with sapling-sized stems. Sites listed with the potential to be fenced "P" are now 
  designated as "N" for not fenced. The assumption is that the data files will be maintained such that potentially fenced sites will be updated to fenced 
  ("Y") if they are indeed fenced in the future. Also in this step, saplings are broken into two groups: short (ht > 150 cm) and tall (ht <=150 cm). The
  naming is explained in Zeigenfuss and Johnson (2015) and Zeigenfuss and others (2011).The stem density per acre is calculated (per acre numbers are used
 

data aspen2;
    set tran1;
    if fenced='P' then fenced='N';
    if _name_='year' then delete;
    if _name_='ht151_200' or _name_='ht201_250' then type='recruit';
    if _name_='ht0_50' or _name_='ht51_100' or _name_='ht101_150' then type='regen';
    stems_per_acre_base=_0*161.94;
    stems_per_acre_samp1=_1*161.94;
    proc sort;
        by  fenced burned type sitetype sitenum siteid;
    proc univariate noprint;
        by  fenced burned type sitetype sitenum siteid;
        var stems_per_acre_base stems_per_acre_samp1;
        output out=outsamp sum=totbase totsamp1;


/* Dataset is transposed again, then variable names reassigned at the beginning of the next step (because transposing process generated variable names).*/ 


data aspen2a;
    set outsamp;
	*if totbase=. or totsamp1=. then delete;
	proc sort;
        by fenced burned sitetype sitenum type siteid;
    proc transpose out=tran2;
       by fenced burned sitetype sitenum type siteid;


/*A new variable that combines groupings (fenced, core/non-core/Kawuneeche) as a single variable is created. Missing data points are removed. The log of 
  density is used for statistical tests between years. Mean density for both recruitment (tall) and regeneration (short) groups for each newtype variable 
  and each sampling period is calculated and output to screen. */


data aspen2b;
    set tran2;
	sample=_name_;
    density=col1;
      ldens=log(density+0.0001);
 	if sitetype='AC' and fenced='Y'  then newtype='ACF';
	if sitetype='AC' and fenced='N'  then newtype='ACG';
	 	if sitetype='ANC'  then newtype='ANC';
	if sitetype='AK' then delete;
	if density=. then delete;
  drop _name_  col1;
    proc sort;
        by  type  sample newtype;
    proc univariate noprint;
		by type sample newtype;
		var density;
		output out=outmeans mean=avdensity stdmean=se n=n;
		proc print data=outmeans;
	


/* This step produces the information used to determine what proportion of sites meets the various targets for recruitment (tall) and regeneration (short),
   information on statistical tests, and mean densities. LSMeans for table 4 are produced here. */

   
data aspen3;
    set tran2;
    if recrit=0 then recruit_class=1;
    if recruit gt 0 and recruit lt 324 then recruit_class=2;
    if recruit ge 324 then recruit_class=3;
    if regen le 1700 then regen_class=1;
    if regen gt 1700 and regen le 4500 then regen_class=2;
    if regen gt 4500 then regen_class=3;
    sample=_name_;
    proc sort;
        by sample sitetype fenced burned;
    proc freq;
        by sample sitetype fenced burned;
        tables regen_class*recruit_class;

data aspen3a;
    set aspen2b;
   
proc sort;
		by   newtype type ;
		proc glimmix;
		*by  loc cond;
		class sample siteid newtype;
		by  newtype type ;
		model density= sample /ddfm=satterth;
		random siteid;
		lsmeans sample /pdiff;	
		/*	proc univariate noprint;
		by type sample newtype;
		var density;
		output out=finalavg mean=avdens stdmean=se n=n;
		proc print data=finalavg;*/
		run;
  


