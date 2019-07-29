/******************************************************
* Macro to calculate ISS Score using ICD9 or ICD10
* Based on the work of Clark, Osler, Hahn
* Written by: Dan Sturgeon
* Date: 7/29/2019
* Last Update: 7/29/2019
******************************************************/
/*****************************************************
* Data: Your dataset
* Date: Date variable of set for injury
* Key: Unique Identifier
* Ver: Either 9,10 OR a variable name that contains ICD version (9,10)
* DX_PRE: Prefix for DX variable
* Num_DX: Number of DX codes per row
* Out: Output dataset name
********************************************************/


/*Referenced table is cdlst.ISS_DATA*/


%macro ISS(data=,date=,key=,ver=,dx_pre=,num_dx=,out=);

%if &num_dx ne 1 %then %do;
	data _tmp1;
	set &data;
		array dx[&num_dx] &dx_pre.1-&dx_pre.&num_dx.;
			do i = 1 to &num_dx;
				if dx[i] ne ' ' then do;
					code = dx[i];
					output;
				end;
			end;
	drop &dx_pre.1-&dx_pre.&num_dx. i;
	run;
%end;

%else %do;
	data _tmp1;
	set &data;
	run;
%end;


%if &ver = 9 %then %do;

	proc sql;
	create table _tmp2 as
	select distinct 
       		a.*,
       		c.severity,
	   		c.issbr
  	  from _tmp1 a,
	   	   cdlst.ISS_DATA c
 	 where a.code = c.code;
	quit;

%end;

%else %if &ver = 10 %then %do;
	proc sql;
	create table _tmp2 as
	select distinct 
	       a.*,
 	       c.severity,
		   c.issbr
  	  from _tmp1 a,
	   	  cdlst.ISS_DATA c
 	 where a.compress(catx(' ',substr(a.code,1,1),compress(a.code,,'a'))) = c.code/*<-Code is saying when its ICD10 strip off the suffix*/;
	quit; 

%end;

%else %do;
	proc sql;
	create table _tmp2 as
	select distinct 
       	a.&key.,
		a.&date.,
       	c.severity,
	   	c.issbr
  	from _tmp1 a,
	   	cdlst.ISS_DATA c
 	where case when a.&ver = 10 then compress(catx(' ',substr(a.code,1,1),compress(a.code,,'a'))) else a.code end = c.code
   	  and a.&ver. = c.ver;
	quit; 
%end;

/*Logic with ISS is you have all of these body parts. You take only the highest of each, then the top 3 of those. Square them and add them
 *If any of the parts has severity >= 6 then you assign the max, which depending on methodology can be a couple of things. Here we use 48*/
proc sql;
create table _tmp3 as
select &key.,
       &date.,
	   max(case when issbr = 1 then severity else 0 end) as head_neck,	
	   max(case when issbr = 2 then severity else 0 end) as face,
	   max(case when issbr = 3 then severity else 0 end) as chest,
	   max(case when issbr = 4 then severity else 0 end) as abdomen_and_Pelvic_contents,
	   max(case when issbr = 5 then severity else 0 end) as extremities_or_pelvic_girdle,
	   max(case when issbr = 6 then severity else 0 end) as external,
	   max(case when issbr = 9 then severity else 0 end) as unknown
  from _tmp2
group by &key.,
         &date.
order by 1,2;
quit;

proc sql;
create table _tmp4 as
select a.*,
       b.head_neck,
	   b.face,
	   b.chest,
	   b.abdomen_and_Pelvic_contents,
	   b.extremities_or_pelvic_girdle,
	   b.external
  from &data a
left join _tmp3 b on a.&key. = b.&key. and a.&date. = b.&date.;
quit;


data _tmp5;
set _tmp4;

if max(head_neck,face,chest,abdomen_and_Pelvic_contents,extremities_or_pelvic_girdle,external) = 6 then ISS = 48;

array ISSBR[6] head_neck face chest abdomen_and_Pelvic_contents extremities_or_pelvic_girdle external;

	do I = 1 to 6;
		if issbr[i] = . then issbr[i] = 0;
	end;
drop i;
run;


data &out.;
set _tmp5;

first = 0;
second = 0;
third = 0;

array parts[6] head_neck face chest abdomen_and_Pelvic_contents extremities_or_pelvic_girdle external;

do I = 1 to 6;
	if parts[i] GE first then do;		
		third = second;
		second = first;
		first = parts[i];
	end;

	else if parts[i] ge second then do;
		third = second;
		second = parts[i];
	end;

	else if parts[i] ge third then do;
		third = parts[i];
	end;
end;


iss2 = first**2+second**2+third**2;

if iss2 gt 48 then iss2 = 48;

if first = 6 then iss2 = 48;

iss=iss2;

IF ISS LT 9 THEN ISS4CAT = '<9   ';
ELSE IF ISS LE 15 THEN ISS4CAT = '9-15';
ELSE IF ISS LE 25 THEN ISS4CAT = '16-25';
ELSE ISS4CAT = '>25   ';

drop i first second third iss2;
run;

proc datasets;
delete _tmp:;
run;

%mend;















