/*===========================================================================
   PROJECT  : Clinical Data Analysis for Cardiovascular Risk Prediction
   AUTHOR   : Priyanka Patil
   TOOL     : SAS (Base SAS, PROC SQL, SAS Macros, ODS)
   DOMAIN   : Pharma / Clinical Analytics
   DATASET  : Framingham Heart Study-style cardiovascular data
   PURPOSE  : End-to-end clinical data pipeline — ingestion, transformation,
              statistical analysis, visualization, and automated reporting
===========================================================================*/


/*---------------------------------------------------------------------------
  SECTION 1: LIBRARY SETUP
  Creating a permanent library "mylib" to store all datasets
---------------------------------------------------------------------------*/

options dlcreatedir;

libname mylib "/home/u64270073/Pharma";
/* NOTE: Update this path to match your SAS environment directory */


/*---------------------------------------------------------------------------
  SECTION 2: DATA INGESTION
  Reading cl_main.csv → pharma_data
  Reading data_2.csv  → data_weight
---------------------------------------------------------------------------*/

/* Primary clinical dataset */
data mylib.pharma_data;
   infile "/home/u64270073/Pharma/cl_main.csv"
      firstobs = 2    /* skip header row */
      dlm      = ','  /* comma-delimited */
   ;
   input
      Cust_id
      gender
      age
      education
      currentSmoker
      cigsPerDay
      BPMeds
      prevalentStroke
      prevalentHyp
      diabetes
      totChol
      sysBP
      diaBP
      BMI
      heartRate
      glucose
      TenYearCHD
   ;
run;

/* Secondary dataset — patient weight and number of dependents */
data mylib.data_weight;
   infile "/home/u64270073/Pharma/data_2.csv"
      firstobs = 2
      dlm      = ","
   ;
   input cust_id dependents weight;
run;


/*---------------------------------------------------------------------------
  SECTION 3: METADATA UPDATE
  Updating labels and informats using PROC DATASETS
  (modifies only metadata — no raw data reprocessing)
---------------------------------------------------------------------------*/

proc datasets lib=mylib nolist;
   modify pharma_data (label = "Input for Clinical Data Analysis");
      informat gender 1.
               age    1.
               totchol 3.
               sysbp   3.
      ;
      label
         totchol = "Total Cholesterol"
         glucose = "Glucose Content"
      ;
run;
quit;


/*---------------------------------------------------------------------------
  SECTION 4: SUBSETTING
  Creating three analytical subsets from pharma_data
---------------------------------------------------------------------------*/

data smokers         /* patients who currently smoke        */
     chol_198_200    /* patients with cholesterol 198–200   */
     bmi_gt_25       /* patients with BMI greater than 25   */
;
   set mylib.pharma_data;

   if currentsmoker = 1                          then output smokers;
   if totchol >= 198 and totchol <= 200          then output chol_198_200;
   if bmi > 25                                   then output bmi_gt_25;
run;


/*---------------------------------------------------------------------------
  SECTION 5: EDUCATION CATEGORISATION — FORMAT-BASED LOOK-UP
  1 & 2 → "Low"
  3 & 4 → "High"
  New variable: education_cat
---------------------------------------------------------------------------*/

proc format;
   value edu_level
      1, 2 = "Low"
      3, 4 = "High"
   ;
run;

data mylib.pharma_data;
   set mylib.pharma_data;
   education_cat = put(education, edu_level.);
run;


/*---------------------------------------------------------------------------
  SECTION 6: GENDER CATEGORISATION — HASH JOIN LOOK-UP
  0 → "Female"
  1 → "Male"
  New variable: gender_cat
  Method: Hash Join (industry-standard in-memory look-up)
---------------------------------------------------------------------------*/

/* Step 1: Create the mapping table */
data gender_mapping;
   gender = 0; gender_cat = "Female"; output;
   gender = 1; gender_cat = "Male";   output;
run;

/* Step 2: Apply hash join */
data mylib.pharma_data;
   set mylib.pharma_data;

   /* Load hash table into memory only on first iteration */
   if 0 then set gender_mapping;
   if _n_ = 1 then do;
      declare hash hash_gender (dataset: "gender_mapping");
         hash_gender.definekey("gender");
         hash_gender.definedata("gender_cat");
         hash_gender.definedone();
   end;

   /* Look up gender_cat for each row */
   if hash_gender.find() = 0;
run;

/* Verify gender categorisation */
proc freq data = mylib.pharma_data;
   table gender_cat;
run;


/*---------------------------------------------------------------------------
  SECTION 7: CHD DISTRIBUTION ANALYSIS
  Cross-tabulation of TenYearCHD against all categorical variables
---------------------------------------------------------------------------*/

proc freq data = mylib.pharma_data;
   table gender_cat    * tenyearchd;
   table education_cat * tenyearchd;
run;


/*---------------------------------------------------------------------------
  SECTION 8: DESCRIPTIVE STATISTICS
  Mean, Median, Std Deviation for all continuous variables
---------------------------------------------------------------------------*/

proc means data = mylib.pharma_data;
   var _numeric_;
run;


/*---------------------------------------------------------------------------
  SECTION 9: BAR CHARTS
  Distribution of categorical variables
---------------------------------------------------------------------------*/

/* Gender distribution */
proc sgplot data = mylib.pharma_data;
   vbar gender_cat;
   title "Patient Distribution by Gender";
run;

/* Education distribution */
proc sgplot data = mylib.pharma_data;
   vbar education_cat;
   title "Patient Distribution by Education Level";
run;


/*---------------------------------------------------------------------------
  SECTION 10: LINE GRAPHS
  Trend of Glucose and Diastolic BP across patient IDs
---------------------------------------------------------------------------*/

proc sgplot data = mylib.pharma_data;
   where cust_id < 11300;
   series x = cust_id y = glucose / legendlabel = "Glucose Content";
   series x = cust_id y = diaBP   / legendlabel = "Diastolic BP";
   title "Glucose Content and Diastolic BP Trend (CustID < 11300)";
run;


/*---------------------------------------------------------------------------
  SECTION 11: UNIVARIATE ANALYSIS
  Detailed distributional diagnostics for BMI by gender
---------------------------------------------------------------------------*/

proc univariate data = mylib.pharma_data;
   var bmi;
   class gender_cat;
   title "Univariate Analysis — BMI by Gender";
run;


/*---------------------------------------------------------------------------
  SECTION 12: BOX PLOT
  BMI distribution by gender — detects spread and outliers
---------------------------------------------------------------------------*/

proc sgplot data = mylib.pharma_data;
   hbox bmi / group = gender_cat;
   title "BMI Distribution by Gender";
run;


/*---------------------------------------------------------------------------
  SECTION 13: DATA ENRICHMENT
  Merging pharma_data with data_weight (weight + dependents)
---------------------------------------------------------------------------*/

data mylib.pharma_data;
   merge mylib.pharma_data (in = a)
         mylib.data_weight  (in = b);
   by cust_id;
   if a;  /* keep all pharma_data records; match weight where available */
run;

/* Verify enrichment */
proc freq data = mylib.pharma_data;
   table dependents;
   title "Distribution of Dependents after Enrichment";
run;

proc means data = mylib.pharma_data;
   var weight;
   title "Weight Statistics after Enrichment";
run;


/*---------------------------------------------------------------------------
  SECTION 14: DERIVED VARIABLE
  Combined risk score: Cholesterol + BMI + Glucose
---------------------------------------------------------------------------*/

data mylib.pharma_data;
   set mylib.pharma_data;
   chol_bmi_glu = sum(totchol, bmi, glucose);
run;


/*---------------------------------------------------------------------------
  SECTION 15: CUMULATIVE BMI
  Running cumulative total of BMI across all records
  Uses + statement (implicit RETAIN)
---------------------------------------------------------------------------*/

data mylib.pharma_data;
   set mylib.pharma_data;
   cum_bmi + bmi;
run;


/*---------------------------------------------------------------------------
  SECTION 16: CUMULATIVE GLUCOSE BY EDUCATION CATEGORY
  BY-group cumulative sum using FIRST. and LAST. automatic variables
---------------------------------------------------------------------------*/

proc sql;
   create table work.glu_edu as
      select cust_id, education_cat, glucose
      from mylib.pharma_data;
quit;

proc sort data = glu_edu;
   by education_cat glucose;
run;

data glu_edu;
   set glu_edu;
   by education_cat;
   if first.education_cat then glucose_cum = glucose;
   else glucose_cum + glucose;
run;


/*---------------------------------------------------------------------------
  SECTION 17: CHOLESTEROL PROJECTION — DO LOOP + POINT= (DIRECT ACCESS)
  Question: At 1% annual growth, what is cholesterol after 10 years
            for observations 1, 4, 5?
---------------------------------------------------------------------------*/

/* Extract observations 1, 4, 5 using direct access (POINT=) */
data subset145;
   do i = 1, 4, 5;
      set mylib.pharma_data (keep = cust_id totchol) point = i;
      output;
   end;
   stop;
run;

/* Project cholesterol over 10 years at 1% annual growth */
data subset145;
   set subset145;
   totchol_orig = totchol;
   do i = 1 to 10;
      totchol = totchol + totchol * 0.01;
   end;
run;

proc print data = subset145;
   title "Cholesterol after 10 Years (Obs 1, 4, 5) — 1% Annual Growth";
run;


/*---------------------------------------------------------------------------
  SECTION 18: YEARS TO DANGER THRESHOLD — GOTO STATEMENT
  Question: How many years to exceed cholesterol = 350 at 1% growth
            for observations 7, 10, 12?
---------------------------------------------------------------------------*/

/* Extract observations 7, 10, 12 using _N_ */
data subset71012;
   set mylib.pharma_data (keep = cust_id totchol);
   if _n_ in (7, 10, 12);
run;

proc print data = subset71012;
   title "Starting Cholesterol for Obs 7, 10, 12";
run;

/* Calculate years to reach danger threshold using GOTO */
data subset71;
   set subset71012;
   do i = 1 to 100;
      totchol = totchol + totchol * 0.01;
      years   = i;
      if totchol > 350 then goto endofpro;
   end;
   endofpro:
run;

proc print data = subset71;
   title "Years to Exceed Cholesterol = 350 (Obs 7, 10, 12)";
run;


/*---------------------------------------------------------------------------
  SECTION 19: YEAR-WISE CHOLESTEROL PROJECTION — SAS ARRAY
  Question: At 1% annual growth, show cholesterol value for each of
            10 years for observations 7, 10, 12
            (one variable per year: years1 to years10)
---------------------------------------------------------------------------*/

data subset8;
   array years {10};   /* creates 10 variables: years1 to years10 */
   set subset71012;
   do j = 1 to 10;
      totchol  = totchol + totchol * 0.01;
      years{j} = totchol;
   end;
run;

proc print data = subset8;
   title "Year-wise Cholesterol Projection (Obs 7, 10, 12)";
run;


/*---------------------------------------------------------------------------
  SECTION 20: BMI CATEGORY REPORT — ODS PDF OUTPUT
  BMI classified as:
     0–25      → LOW
     26–40     → FIT
     41+       → Overweight
---------------------------------------------------------------------------*/

/* Create BMI format */
proc format;
   value bmi_cat
      0  -  25   = "LOW"
      25 <-  40  = "FIT"
      40 <- high = "Overweight"
   ;
run;

/* Create categorised dataset */
proc sql;
   create table bmi_cat as
      select cust_id,
             put(bmi, bmi_cat.) as bmi_cat
      from mylib.pharma_data;
quit;

/* Write frequency report to PDF */
ods pdf file = "/home/u64270073/Pharma/bmi_cat.pdf";
   proc freq data = bmi_cat;
      table bmi_cat;
      title "BMI Category Distribution Report";
   run;
ods pdf close;


/*---------------------------------------------------------------------------
  SECTION 21: CONDITIONAL REPORT GENERATION — SAS MACRO
  Report generates only on Thursdays using &SYSDAY automatic variable
---------------------------------------------------------------------------*/

%macro gen_rep;
   %if &sysday. = Thursday %then %do;
      ods pdf file = "/home/u64270073/Pharma/bmi_cat.pdf";
         proc freq data = bmi_cat;
            table bmi_cat;
            title "BMI Category Report — Auto Generated on Thursday";
         run;
      ods pdf close;
      %put NOTE: Report generated successfully on &sysday.;
   %end;
   %else %do;
      %put NOTE: Report not generated. Today is &sysday., not Thursday.;
   %end;
%mend gen_rep;

%gen_rep;


/*---------------------------------------------------------------------------
  SECTION 22: PARAMETERISED MACRO — SUM TWO NUMBERS
  Demonstrates dynamic computation using %SYSEVALF
---------------------------------------------------------------------------*/

%macro sum_vars (num1 = 2, num2 = 8);
   %let var_add = %sysevalf(&num1. + &num2.);
   %put NOTE: Sum of &num1. and &num2. = &var_add.;
%mend sum_vars;

/* Test with custom values */
%sum_vars(num1 = 1, num2 = 1);
%sum_vars(num1 = 15, num2 = 27);


/*---------------------------------------------------------------------------
  SECTION 23: PROC SQL — CASE-WHEN EDUCATION CATEGORISATION
---------------------------------------------------------------------------*/

proc sql;
   create table edu_sql as
      select
         cust_id,
         education,
         case
            when education between 1 and 2 then "Low"
            when education between 3 and 4 then "High"
            else "Unknown"
         end as edu_cat_sql
      from mylib.pharma_data;
quit;


/*---------------------------------------------------------------------------
  SECTION 24: PROC SQL — DROP AND RE-ENRICH COLUMNS
  Remove dependents and weight from pharma_data,
  then re-add via LEFT JOIN with data_weight
---------------------------------------------------------------------------*/

/* Remove columns */
proc sql;
   alter table mylib.pharma_data
   drop dependents, weight;
quit;

/* Re-enrich via LEFT JOIN */
proc sql;
   create table sql_left as
      select
         a.*,
         b.dependents,
         b.weight
      from mylib.pharma_data    as a
      left join mylib.data_weight as b
         on a.cust_id = b.cust_id;
quit;

proc print data = sql_left (obs = 10);
   title "Enriched Dataset via PROC SQL LEFT JOIN (First 10 Rows)";
run;

/*===========================================================================
   END OF PROGRAM
===========================================================================*/
