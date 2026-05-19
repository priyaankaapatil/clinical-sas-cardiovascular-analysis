# 🫀 Clinical Data Analysis for Cardiovascular Risk Prediction

> **Tools:** Base SAS · PROC SQL · SAS Macro Language · ODS PDF  
> **Domain:** Pharma / Clinical Analytics  
> **Dataset:** Framingham Heart Study–style cardiovascular dataset (4,240 patient records)

---

## 📌 Project Overview

End-to-end clinical data analysis pipeline on a cardiovascular health dataset to explore risk factors associated with **10-Year Coronary Heart Disease (CHD)** prediction - covering data ingestion, transformation, statistical analysis, visualization, and automated PDF reporting in **SAS**.

This project simulates a real-world pharma data analyst workflow: raw CSV files are ingested into a permanent SAS library, cleaned and enriched through multiple transformation techniques (Hash Join, PROC FORMAT, MERGE, PROC SQL), analyzed using standard statistical procedures, and finally summarized into an automated PDF report triggered by a scheduled SAS Macro.

**Key finding:** Gender was identified as a significant CHD risk factor - males showed 18.85% CHD incidence vs. 12.44% in females, a ~50% higher relative risk.

---

## 📂 Repository Structure

```
sas-clinical-cardiovascular-analysis/
│
├── code/
│   └── pharma_project.sas        # Complete annotated SAS program (24 sections)
│
├── data/
│   ├── cl_main.csv               # Primary clinical dataset (17 variables, 4240 records)
│   └── data_2.csv                # Secondary dataset (weight, dependents)
│
├── output/
│   └── bmi_cat.pdf               # Auto-generated BMI category report
│
├── screenshots/                  # SAS procedure outputs and visualizations
│
└── README.md
```

---

## 📊 Dataset Details

| Feature | Description |
|---|---|
| **Source** | Framingham Heart Study–style clinical data |
| **Records** | 4,240 patients · 21 final columns after enrichment |
| **Target Variable** | `TenYearCHD` - 10-Year Coronary Heart Disease risk (0/1) |
| **Key Variables** | Age, Gender, BMI, Systolic/Diastolic BP, Total Cholesterol, Glucose, Smoking status, Diabetes, Education level |

---

## ⚙️ Analysis Pipeline

### 1. Data Ingestion & Library Management
- Imported two raw CSV files into a permanent SAS library (`LIBNAME`, `INFILE`, `FIRSTOBS`, `DLM`)
- Updated dataset metadata - labels and informats - using `PROC DATASETS` without reprocessing raw data

> 💡 **Insight:** Using `PROC DATASETS` for metadata changes is a performance-conscious approach - it avoids a full data step pass over 4,240 records just to relabel variables, which matters at scale in production pharma pipelines.

---

### 2. Data Transformation - Look-up Operations

**Education Categorisation (`PROC FORMAT`)**  
1, 2 → *Low* | 3, 4 → *High*

**Gender Categorisation (Hash Join)**  
0 → *Female* | 1 → *Male*

> 💡 **Insight:** Hash Join loads the mapping table entirely into memory, making gender look-up an O(1) operation regardless of dataset size - far more efficient than a sort-based `MERGE` for large clinical datasets. This is the preferred technique in industry when one dataset is small (a mapping table) and the other is large (patient records).

---

### 3. Subsetting & Filtering

| Subset Dataset | Filter Condition |
|---|---|
| `smokers` | `currentSmoker = 1` |
| `chol_198_200` | `totChol BETWEEN 198 AND 200` |
| `bmi_gt_25` | `BMI > 25` |

> 💡 **Insight:** Creating pre-filtered subsets early in the pipeline reduces processing overhead for all downstream analysis steps. In a real clinical trial setting, the `bmi_gt_25` subset would directly feed into patient stratification or eligibility screening.

---

### 4. Data Enrichment
- Merged primary dataset with secondary (weight, dependents) using Data Step `MERGE` with `IN=`
- Replicated using `PROC SQL LEFT JOIN` for comparison
- Derived combined risk metric: `chol_bmi_glu = SUM(totchol, bmi, glucose)`

> 💡 **Insight:** 59 patients (out of 4,240) had missing dependents data after the merge - flagged via `PROC FREQ`. In a clinical context, unmatched records after a join are critical to investigate as they may represent data entry errors or patients who dropped out of the study.

---

### 5. Cholesterol Projection - DO Loop + POINT= + ARRAY

Projected cholesterol at **1% annual growth** for target observations.  
Computed years to reach danger threshold (350 mg/dL) using `GOTO`.  
Stored year-wise values in a 10-element `ARRAY`.

> 💡 **Insight:** Patients with initial cholesterol of 205, 225, and 247 require 54, 45, and 36 years respectively to breach the danger threshold at 1% annual growth. This demonstrates that even modest starting cholesterol differences translate to significantly different clinical risk timelines - reinforcing the importance of early intervention.

---

### 6. Cumulative Calculations
- Cumulative BMI across all records using `+` statement (implicit `RETAIN`)
- Cumulative Glucose by Education Category using `BY`-group processing with `FIRST.` / `LAST.`

> 💡 **Insight:** Segmenting cumulative glucose by education category reveals whether glucose burden is disproportionately distributed across socioeconomic groups - a relevant question in population health and pharma targeting.

---

## 📈 Key Findings & Insights

| Metric | Value |
|---|---|
| Dataset size | 4,240 patients · 21 variables |
| Gender split | 57.08% Female · 42.92% Male |
| Overall 10-Year CHD rate | **15.19%** |
| CHD rate - Male | **18.85%** |
| CHD rate - Female | **12.44%** |
| Mean Total Cholesterol | 236.70 mg/dL |
| Mean BMI | 25.80 |
| Mean Glucose | 81.96 mg/dL |
| BMI distribution | 45.45% LOW · 53.49% FIT · 0.61% Overweight |
| Female BMI - Mean / Skewness | 25.51 / 1.26 (right-skewed) |
| Male BMI - Mean / Skewness | 26.19 / 0.35 (near-normal) |

> 💡 **Insight:** Males show ~50% higher CHD incidence than females (18.85% vs 12.44%), identifying **gender as a significant cardiovascular risk factor** in this cohort. The low-education group accounts for 70% of the dataset and 73% of all CHD cases - suggesting education level (a proxy for socioeconomic status) correlates strongly with cardiovascular risk.

---

## 📊 Visualizations & Interpretation

| Chart | Tool | Finding |
|---|---|---|
| Bar - Gender | `PROC SGPLOT` | Female-skewed cohort (57%); representative of real-world Framingham study demographics |
| Bar - Education | `PROC SGPLOT` | 70% of patients have low education - signals a socioeconomically skewed sample |
| Line - Glucose vs diaBP | `PROC SGPLOT` | Sharp glucose spikes near IDs 11,270–11,280 suggest outlier patients possibly with uncontrolled diabetes |
| Box Plot - BMI by Gender | `PROC SGPLOT` | Females have wider BMI spread (IQR 5.18, max 56.8) vs males (IQR 4.39, max 40.38); female extreme outliers may disproportionately affect BMI-based risk models |
| Univariate - BMI Female | `PROC UNIVARIATE` | Skewness = 1.26 confirms right-skewed distribution; mean (25.51) > median (24.75), pulled up by high-BMI outliers |
| Univariate - BMI Male | `PROC UNIVARIATE` | Skewness = 0.35 - near-normal; mean ≈ median, suggesting a more homogeneous BMI profile in male patients |

*See `/screenshots` folder for all output images.*

---

## 📄 Automated Reporting - ODS PDF + SAS Macro

BMI classified into three groups (LOW / FIT / Overweight) using `PROC FORMAT`.  
Report output via `ODS PDF`. A `%MACRO` with `%IF-%THEN` and `&SYSDAY` triggers generation **only on Thursdays** - simulating real-world scheduled reporting logic used in clinical trial monitoring environments.

> 💡 **Insight:** 53.49% of patients fall in the FIT category (BMI 26–40), while only 0.61% are classified as Overweight (BMI > 40). However, the "FIT" upper boundary of 40 is unusually high by standard WHO classification - in practice this format would be refined to align with clinical BMI cutoffs (underweight <18.5, normal 18.5–24.9, overweight 25–29.9, obese 30+).

---

## 🛠️ SQL in SAS

Used `PROC SQL` for `CASE-WHEN` categorisation, `LEFT JOIN` enrichment, `ALTER TABLE` column drops, and subquery-based table creation.

> 💡 **Insight:** Running identical enrichment logic in both Data Step `MERGE` and `PROC SQL LEFT JOIN` provides a useful validation cross-check - if row counts differ between the two approaches, it signals a data quality issue (e.g. duplicate keys in the secondary dataset).

---

## 🧰 Technical Skills

| Category | Skills |
|---|---|
| Data Access | `INFILE`, `LIBNAME`, `POINT=` direct access |
| Data Manipulation | DATA Step, `MERGE`, Hash Join, Arrays, DO Loops, `RETAIN`, `GOTO` |
| Procedures | `PROC MEANS`, `PROC FREQ`, `PROC UNIVARIATE`, `PROC SGPLOT`, `PROC DATASETS`, `PROC SORT`, `PROC FORMAT` |
| SQL | `PROC SQL` - SELECT, LEFT JOIN, CASE-WHEN, ALTER TABLE |
| Reporting | ODS PDF |
| Automation | `%MACRO`, `%IF-%THEN`, `%SYSEVALF`, Macro Variables, `&SYSDAY` |
| Domain | Clinical data · Cardiovascular risk factors · Pharma analytics |

---

## 🚀 How to Run

1. Clone this repository
2. Upload `cl_main.csv` and `data_2.csv` to your SAS environment (SAS OnDemand for Academics works)
3. Update the `LIBNAME` path and all `INFILE` paths in `pharma_project.sas` to match your directory
4. Run the full program in SAS Studio
5. PDF report will be generated at the path specified in the ODS statement

---

## 👩‍💻 Author

**Priyanka Patil**  
LinkedIn: https://www.linkedin.com/in/priyanka--patil  
GitHub: https://github.com/priyaankaapatil

---

> *Developed as part of a clinical SAS analytics curriculum, simulating real-world pharma data analyst workflows on cardiovascular patient data.*
