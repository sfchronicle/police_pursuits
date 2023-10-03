library(tidyverse)
library(janitor)
library(lubridate)
library(random)

####if new mpv data comes out, then APPEND IT - DONT MESS WITH THE INDEX!!!!

fatalencounters <- read_csv("fatal_encounters.csv") %>%
  row_to_names(row_number = 1)

names(fatalencounters) <- tolower(names(fatalencounters))
names(fatalencounters) <- gsub(x = names(fatalencounters), pattern = "\\s|\\/", replacement = "_") 
names(fatalencounters) <- gsub(x = names(fatalencounters), pattern = "\\)|\\(|\\,|\\?", replacement = "") 

mapping_police_violence <- read_csv("mapping_police_violence.csv") %>%
  mutate(dataset = "mapping_police_violence")


#first, get all data into one spreadsheet. note which columns are NA. i guess we can deal with that later
#maybe the way to do this is by filtering the data in fatal encounters for 'pursuit, pursued, chase'


#WARNING: I RENAMED THESE COLUMNS TO MATCH OUR MAPPING POLICE VIOLENCE AS CLOSE AS POSSIBLE BUT THEIR MEANINGS CAN BE DIFFERENT.
#IE DISPOSITION_OFFICIAL IS MAYBE NOT NECESSARILY THE OFFICIAL DISPO.
fatalencounters_cleaned <- fatalencounters %>%
  select(unique_id:foreknowledge_of_mental_illness_internal_use_not_for_analysis) %>%
  rename(date = date_of_injury_resulting_in_death_month_day_year, agency_responsible = agency_or_agencies_involved, 
         street_address = location_of_injury_address, victim_image = url_of_image_pls_no_hotlinks, city = location_of_death_city,
         zip = location_of_death_zip_code, county = location_of_death_county, allegedly_armed = armed_unarmed, circumstances = brief_description,
         cause_of_death = highest_level_of_force, signs_of_mental_illness = foreknowledge_of_mental_illness_internal_use_not_for_analysis, 
         wapo_flee = fleeing_not_fleeing, disposition_official = dispositions_exclusions_internal_use_not_for_analysis, news_urls = supporting_document_link) %>%
  select(-race_with_imputations, -imputation_probability, -uid_temporary, -name_temporary) %>%
  mutate(age = as.numeric(age), latitude = as.numeric(latitude), longitude = as.numeric(longitude)) %>%
  mutate(dataset = "fatal_encounters") 


#as a test, let's try binding the dataframes together.
#it appears to have worked ok
test <- bind_rows(mapping_police_violence, fatalencounters_cleaned) %>%
  select(-c(pop_total_census_tract:prosecutor_url))

#look at duplicates briefly
testgrouped <- test %>%
  group_by(name, age, date) %>%
  filter(name != "Name withheld by police"&name != "name withheld" & name != "Name Withheld") %>%
  summarize(dupes = n())

#clean data to prep for a deduplication
test_dedupe_prep <- test %>%
  mutate(name = tolower(name)) %>%
  mutate(name = gsub('[[:punct:] ]+',' ',name)) %>%
  mutate(name = gsub('by\\spolice|by\\spolice\\sdupe|\\sdupe\\b','',name)) %>%
  mutate(race = gsub('African\\-American\\/|European\\-American\\/|Hispanic\\/|\\/Pacific\\sIslander|european-American\\/', '',race)) %>%
  mutate(race = gsub('Hispanic', 'Latino', race)) %>%
  mutate(name = str_trim(name)) %>%
  mutate(street_address = tolower(street_address)) %>%
  mutate(street_address = gsub('[[:punct:] ]+',' ',street_address)) %>%
  mutate(date2 = as.Date(date, "%m/%d/%Y")) %>%
  relocate(date2, .before = date)
  
#deduplicate on selected columns. note that we might alter this process later but so far it appears to have worked okay
test_dedupe <- distinct(test_dedupe_prep, name,date2,zip, .keep_all= TRUE)


race <- test_dedupe %>%
  group_by(dataset) %>%
  summarize(count = n())

#filter for just pursuits/chases/etc
#abdul note: gunshot deaths could be in there so look a little more carefully at the descriptions of gunshot deaths
#apply stricter terms to the car wapo_flee case
fatal_pursuits <- test_dedupe %>%
  filter(grepl("vehicle|car\\scrash|drowned", cause_of_death, ignore.case =TRUE) & grepl("pursue|pursuit|chase|vehicle|\\scar\\s|crash|chased|PIT\\smaneuver", circumstances, ignore.case = TRUE)) %>%
  mutate(year = year(date2)) %>%
  relocate(year, .before = date2) %>%
  filter(year >= 2016)
  
fatal_pursuits <- fatal_pursuits %>%
  mutate(randomindex = randomSequence(min = 1, max = nrow(fatal_pursuits), col = 1)) %>%
  relocate(randomindex, .before = year) 

##prepare to upload into airtable

obj <- c("gender", "race", "city","county", "agency_responsible", "circumstances", "disposition_official",
         "officer_charged", "signs_of_mental_illness", "allegedly_armed", "wapo_flee", "initial_reason",
         "wapo_body_camera", "call_for_service")

fatal_pursuits_export <- fatal_pursuits %>%
  mutate_at(vars(obj), funs(tolower(.))) %>%
  mutate(entered_by = ifelse(randomindex >= 1110, "sn", "jg")) %>%
  rename(oris = ori, main_agency_responsible = agency_responsible, crim_disposition = officer_charged,
         index = randomindex) %>%
  select(-date, -cause_of_death, -wapo_armed, -wapo_id, -off_duty_killing,
         -geography, -mpv_id, -fe_id, -encounter_type, -officer_names, -officer_races, 
         -officer_known_past_shootings, -tract, -urban_rural_uspsai, -urban_rural_nchs,
         -hhincome_median_census_tract, -full_address, -aggressive_physical_movement, 
         -description_temp, -url_temp, -intended_use_of_force_developing, -wapo_threat_level) %>%
  mutate(other_agencies = "", discipline = "",
     unique_id = "", notes = "", settlement_id = "", reviewed_by = "", person_role = "") %>%
  mutate(wapo_flee = gsub("NA", "not fleeing", wapo_flee), wapo_flee = gsub("car|car,\\sfoot|fleeing[^\\/]+$", "fleeing",wapo_flee)) %>%
  mutate(allegedly_armed = gsub("\\bunarmed\\/did\\snot\\shave\\sactual\\sweapon", "unarmed", allegedly_armed)) %>%
  mutate(signs_of_mental_illness = gsub("na", "no", signs_of_mental_illness),
        wapo_body_camera = gsub("na","no", wapo_body_camera), call_for_service = gsub("na|unavailable", "no", call_for_service))


write.csv(fatal_pursuits, "ROUGHDRAFT_fatal_pursuits.csv", na="")

write.csv(fatal_pursuits_export, "draft_airtable_pursuits.csv")


##### you already did this and dont do again!!!!

#merged <- read_csv("merged-form entries.csv") %>%
 # mutate(person_number = ave(number_dead, circumstances, FUN = seq_along)) %>%
  # mutate(case_id = NA)

#create_new_column <- function(df) {
 # for (i in 1:nrow(df)) {
  #  if (df$person_number[i] > 1) {
   #   df$case_id[i] <- df$case_id[i - 1]  # Set value to previous value
  #  } else {
   #   df$case_id[i] <- ifelse(i == 1, 1, df$case_id[i - 1] + 1)  # Increment by 1
  #  }
#  }
 # return(df)
#}

# merged <- create_new_column(merged)

# write.csv(merged,"case-ids.csv")

merged <- read_csv("merged-form entries.csv")

mergedgrouped <- merged %>%
  group_by(person_role) %>%
  summarize(count =n()) %>%
  mutate(prop = count/sum(count))


length(unique(merged$case_id))

