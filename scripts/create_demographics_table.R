#!/usr/bin/env Rscript
# Create demographics table for Chapter 3 report

library(dplyr)
library(readr)

# Load included participants
included <- read_csv('output/publish/qa_subject_inclusion.csv', show_col_types = FALSE)
included_ids <- included$subject_id

# Load demographics
demo <- read_csv('/Users/mohdasti/Documents/LC-BAP/BAP/Nov2025/LC Aging Subject Data master spreadsheet - demographics.csv', 
                 skip = 1, show_col_types = FALSE, 
                 col_names = c('study', 'subject_id', 'subject_id2', 'demo_comments', 'completion', 
                              'bap_ses1_date', 'bap_ses2_date', 'bap_ses3_date', 'bap_ses_order',
                              'bap_tablet_date', 'blank1', 'bam_ses1', 'bam_ses2', 'bam_ses3', 'bam_order',
                              'bam_tablet', 'blank2', 'dob', 'age', 'sex', 'edu', 'hand', 'race', 
                              'ethnicity', 'first_lang', 'blank3', 'vision', 'prescription', 'blank4',
                              'neuropsych_comments', 'adt_comments', 'vdt_comments', 'stx_comments',
                              'future_contact', 'blank5', 'days_ses1_2', 'days_ses2_3'))

# Filter for included participants and clean data
demo_filtered <- demo %>%
  filter(subject_id %in% included_ids) %>%
  mutate(
    age = as.numeric(age),
    sex = trimws(tolower(sex)),
    edu = case_when(
      edu == '<12' ~ '11',
      edu == 'less than 12' ~ '11',
      TRUE ~ as.character(edu)
    ),
    edu = as.numeric(edu),
    race = trimws(race),
    ethnicity = trimws(ethnicity)
  ) %>%
  filter(!is.na(age))  # Remove rows with missing age

# Load neuropsych data for MoCA scores
neuropsych <- read_csv('/Users/mohdasti/Documents/LC-BAP/BAP/Nov2025/LC Aging Subject Data master spreadsheet - neuropsych.csv', 
                       skip = 1, show_col_types = FALSE)
# Column name for MoCA (check actual column name)
moca_col <- grep('MoCA|moca', names(neuropsych), ignore.case = TRUE, value = TRUE)[1]
if (!is.na(moca_col)) {
  neuropsych <- neuropsych %>%
    mutate(
      subject_id = `SUBJECT NUMBER`,
      moca = as.numeric(!!sym(moca_col))
    ) %>%
    select(subject_id, moca)
} else {
  neuropsych <- data.frame(subject_id = character(), moca = numeric())
}

# Load behavioral data to determine task participation
beh <- read_csv('/Users/mohdasti/Documents/LC-BAP/BAP/Nov2025/bap_beh_trialdata_v2.csv', show_col_types = FALSE)

# Get task participation
task_participation <- beh %>%
  filter(subject_id %in% included_ids) %>%
  mutate(task = case_when(
    task_modality == 'aud' ~ 'ADT',
    task_modality == 'vis' ~ 'VDT',
    TRUE ~ NA_character_
  )) %>%
  filter(!is.na(task)) %>%
  distinct(subject_id, task) %>%
  group_by(subject_id) %>%
  summarise(
    has_adt = any(task == 'ADT'),
    has_vdt = any(task == 'VDT'),
    .groups = 'drop'
  )

# Merge with demographics and MoCA
demo_with_tasks <- demo_filtered %>%
  left_join(task_participation, by = 'subject_id') %>%
  left_join(neuropsych, by = 'subject_id')

# Create task-specific datasets
adt_demo <- demo_with_tasks %>% filter(has_adt == TRUE & !is.na(age))
vdt_demo <- demo_with_tasks %>% filter(has_vdt == TRUE & !is.na(age))

# Function to calculate demographics for a dataset
calc_demographics <- function(data, task_name) {
  # N
  n <- nrow(data)
  
  # Age
  age_mean <- mean(data$age, na.rm = TRUE)
  age_sd <- sd(data$age, na.rm = TRUE)
  age_str <- sprintf('%.1f (%.1f)', age_mean, age_sd)
  
  # Gender
  female_count <- sum(data$sex == 'female', na.rm = TRUE)
  female_pct <- round(100 * female_count / n, 1)
  gender_str <- sprintf('%d (%.1f%%)', female_count, female_pct)
  
  # Education
  edu_mean <- mean(data$edu, na.rm = TRUE)
  edu_sd <- sd(data$edu, na.rm = TRUE)
  edu_str <- sprintf('%.1f (%.1f)', edu_mean, edu_sd)
  
  # MoCA
  if ('moca' %in% names(data)) {
    moca_mean <- mean(data$moca, na.rm = TRUE)
    moca_sd <- sd(data$moca, na.rm = TRUE)
    moca_str <- sprintf('%.1f (%.1f)', moca_mean, moca_sd)
  } else {
    moca_str <- 'N/A'
  }
  
  # Race - fix categorization
  race_clean <- data$race
  # Check if contains "White" (case insensitive)
  has_white <- grepl('white', race_clean, ignore.case = TRUE)
  has_black <- grepl('black|african', race_clean, ignore.case = TRUE)
  has_asian <- grepl('^asian$|^asian,', race_clean, ignore.case = TRUE) & !has_white
  has_other <- grepl('other', race_clean, ignore.case = TRUE) & !has_white & !has_black & !has_asian
  
  # Categorize: prioritize White, then Black, then Asian, then Other
  race_cat <- rep(NA_character_, length(race_clean))
  race_cat[has_white] <- 'White/Caucasian'
  race_cat[has_black & !has_white] <- 'Black/African American'
  race_cat[has_asian & !has_white & !has_black] <- 'Asian'
  race_cat[has_other & !has_white & !has_black & !has_asian] <- 'Other'
  race_cat[is.na(race_clean)] <- NA_character_
  
  white_count <- sum(race_cat == 'White/Caucasian', na.rm = TRUE)
  white_pct <- round(100 * white_count / n, 1)
  white_str <- sprintf('%d (%.1f%%)', white_count, white_pct)
  
  black_count <- sum(race_cat == 'Black/African American', na.rm = TRUE)
  black_pct <- round(100 * black_count / n, 1)
  black_str <- sprintf('%d (%.1f%%)', black_count, black_pct)
  
  asian_count <- sum(race_cat == 'Asian', na.rm = TRUE)
  asian_pct <- round(100 * asian_count / n, 1)
  asian_str <- sprintf('%d (%.1f%%)', asian_count, asian_pct)
  
  other_count <- sum(race_cat == 'Other', na.rm = TRUE)
  other_pct <- round(100 * other_count / n, 1)
  other_str <- sprintf('%d (%.1f%%)', other_count, other_pct)
  
  # Hispanic/Latino
  hispanic_count <- sum(grepl('hispanic|latino', data$ethnicity, ignore.case = TRUE), na.rm = TRUE)
  hispanic_pct <- round(100 * hispanic_count / n, 1)
  hispanic_str <- sprintf('%d (%.1f%%)', hispanic_count, hispanic_pct)
  
  return(list(
    n = n,
    age = age_str,
    gender = gender_str,
    edu = edu_str,
    moca = moca_str,
    white = white_str,
    black = black_str,
    asian = asian_str,
    other = other_str,
    hispanic = hispanic_str
  ))
}

adt_stats <- calc_demographics(adt_demo, 'ADT')
vdt_stats <- calc_demographics(vdt_demo, 'VDT')

# Create table data frame
demographics_table <- data.frame(
  Characteristic = c(
    'N',
    'Age (sd)',
    'Gender, female (%)',
    'Education, years (sd)',
    'MoCA, score* (sd)',
    'Race, count (%)',
    '  White/Caucasian',
    '  Black/African American',
    '  Asian',
    '  Other',
    'Hispanic/Latino, count (%)'
  ),
  Auditory = c(
    as.character(adt_stats$n),
    adt_stats$age,
    adt_stats$gender,
    adt_stats$edu,
    adt_stats$moca,
    '',
    adt_stats$white,
    adt_stats$black,
    adt_stats$asian,
    adt_stats$other,
    adt_stats$hispanic
  ),
  Visual = c(
    as.character(vdt_stats$n),
    vdt_stats$age,
    vdt_stats$gender,
    vdt_stats$edu,
    vdt_stats$moca,
    '',
    vdt_stats$white,
    vdt_stats$black,
    vdt_stats$asian,
    vdt_stats$other,
    vdt_stats$hispanic
  ),
  stringsAsFactors = FALSE
)

# Print table
cat('\nDemographics Table:\n\n')
print(demographics_table)

# Save to CSV for reference
write_csv(demographics_table, 'output/demographics_table_ch3.csv')
cat('\n\nTable saved to: output/demographics_table_ch3.csv\n')
