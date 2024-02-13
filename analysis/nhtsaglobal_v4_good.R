library(tidyverse)
library(fuzzyjoin)

#notes from dan: ADD AT/NHTSA to columns of origin √√√
#maneuver file interesting
#do they keep info on weapons in data? good folo question
#add latitude and longitude to the checks √
#expand ranges of matches √
#take 20 matches in airtable and not nhtsa and try to find them in nhtsa not as pursuits - do a 'perfect match'

###read in nhtsa data - extremely annoying because a bunch of the files don't have years attached so we cannot read them in a list

#2021
aux_acc_21 <- read_csv("national21/fars2021acc.csv")
person_21 <- read_csv("national21/person.csv", col_types = cols(.default = "c")) %>%
  mutate(YEAR = 2021)
race_21 <- read_csv("national21/race.csv", col_types = cols(.default = "c")) %>%
  mutate(YEAR = 2021)
vehicle_21 <- read_csv("national21/vehicle.csv", col_types = cols(.default = "c")) %>%
  mutate(YEAR = 2021)
accident_21 <- read_csv("national21/accident.csv", col_types = cols(.default = "c"))

#2020
aux_acc_20 <- read_csv("national20/fars2020acc.csv")
person_20 <- read_csv("national20/person.csv", col_types = cols(.default = "c")) %>%
  mutate(YEAR = 2020)
race_20 <- read_csv("national20/race.csv", col_types = cols(.default = "c")) %>%
  mutate(YEAR = 2020)
vehicle_20 <- read_csv("national20/vehicle.csv", col_types = cols(.default = "c")) %>%
  mutate(YEAR = 2020)
accident_20 <- read_csv("national20/accident.csv", col_types = cols(.default = "c"))

#2019
aux_acc_19 <- read_csv("national19/fars2019acc.csv")
person_19 <- read_csv("national19/person.csv", col_types = cols(.default = "c")) %>%
  mutate(YEAR = 2019)
race_19 <- read_csv("national19/race.csv", col_types = cols(.default = "c")) %>%
  mutate(YEAR = 2019)
vehicle_19 <- read_csv("national19/vehicle.csv", col_types = cols(.default = "c")) %>%
  mutate(YEAR = 2019)
accident_19 <- read_csv("national19/accident.csv", col_types = cols(.default = "c"))

#2018
aux_acc_18 <- read_csv("national18/fars2018acc.csv")
person_18 <- read_csv("national18/person.csv", col_types = cols(.default = "c")) %>%
  mutate(YEAR = 2018)
vehicle_18 <- read_csv("national18/vehicle.csv", col_types = cols(.default = "c")) %>%
  mutate(YEAR = 2018)
accident_18 <- read_csv("national18/accident.csv", col_types = cols(.default = "c"))

#2017
aux_acc_17 <- read_csv("national17/fars2017acc.csv")
person_17 <- read_csv("national17/person.csv", col_types = cols(.default = "c")) %>%
  mutate(YEAR = 2017)
vehicle_17 <- read_csv("national17/vehicle.csv", col_types = cols(.default = "c")) %>%
  mutate(YEAR = 2017)
accident_17 <- read_csv("national17/accident.csv", col_types = cols(.default = "c"))

### create lists of auxiliary, person, vehicle, race and accident files and bind the separate year files together
### create accident and person id columns, because the st case numbers and person numbers are not unique over the different years
person_17_21 <- bind_rows(list(person_17, person_18, person_19, person_20, person_21)) %>%
  readr::type_convert() %>%
  select(-MAK_MODNAME:-GVWR_TONAME) %>%
  mutate(accident_id = str_c(ST_CASE,"_",YEAR)) %>%
  mutate(person_id = str_c(ST_CASE,"_",YEAR,"_",VEH_NO, PER_NO))

vehicle_17_21 <- bind_rows(list(vehicle_17, vehicle_18, vehicle_19, vehicle_20, vehicle_21)) %>%
  readr::type_convert() %>%
  mutate(accident_id = str_c(ST_CASE,"_",YEAR))

accident_17_21 <- bind_rows(list(accident_17, accident_18, accident_19, accident_20, accident_21)) %>%
  readr::type_convert() %>%
  mutate(accident_id = str_c(ST_CASE,"_",YEAR))

aux_acc_17_21 <- bind_rows(list(aux_acc_17, aux_acc_18, aux_acc_19, aux_acc_20, aux_acc_21)) %>%
  mutate(accident_id = str_c(ST_CASE,"_",YEAR))

#race is tricky because NHTSA just started adding these as separate files in 2019. 
#we will join this data via a left-join, keeping both the new race column contained in this data as well as the old race column.
#no rows should have data filled in for both columns. some have no data for either.
#the person files have Hispanic origin for all years, which we will also keep
#we are also adding the same accident id and person id columns
race_19_21 <- bind_rows(list(race_19, race_20, race_21)) %>%
  mutate(accident_id = str_c(ST_CASE,"_",YEAR)) %>%
  mutate(person_id = str_c(ST_CASE,"_",YEAR,"_",VEH_NO, PER_NO)) %>%
  readr::type_convert() %>%
  filter(RACENAME != "Not a Fatality (not Applicable)") 

#filter the person data to just fatalities, i.e. INJ_SEV == 4
person_17_21_fatalities <- person_17_21 %>%
  filter(INJ_SEV == 4)

#filter auxiliary accident file to just accidents involving police pursuits, i.e. A_POLPUR == 1
pursuits_accidents_17_21 <- aux_acc_17_21 %>%
  filter(A_POLPUR == 1)

#join the accident global file to the auxiliary accidents file
pursuits_accidents_joined <- inner_join(accident_17_21, pursuits_accidents_17_21, by = "accident_id")

#right-join the accident file to the person file so that all the people are connected to their respective accident
person_accident <- right_join(person_17_21_fatalities, pursuits_accidents_joined, by = "accident_id") 

#join the person-accident df to the race df
person_accident_race <- left_join(person_accident, race_19_21, by = c("YEAR","ST_CASE", "STATE",
                                                                      "PER_NO","VEH_NO", "accident_id")) %>%
  #figure out why we need to deduplicate?!?!?!?! or if we should?!?!?!
 distinct(STATE, ST_CASE, VEH_NO, PER_NO, AGE, RACENAME.x, .keep_all = TRUE) %>%
  mutate(latino = ifelse(HISPANICNAME == "Non-Hispanic"|HISPANICNAME == "Redacted"|
                           HISPANICNAME == "Unknown", "", "latino")) %>%
  relocate(latino, 
           .after = HISPANICNAME) %>%
  unite(col="race_combined", c(RACENAME.x, RACENAME.y)) %>%
  mutate(race_combined = gsub("_NA|NA_|\\sor\\sAfrican\\sAmerican","",race_combined)) %>%
  mutate(race_combined = tolower(race_combined)) %>%
  mutate(race_combined = gsub("chinese|vietnamese|asian\\sindian|other\\sindian","asian",race_combined)) %>%
  mutate(race_forATjoin = ifelse(latino != "", paste(race_combined, latino, sep=","), race_combined))

person_grouped <- person_accident_race %>%
  group_by(YEAR) %>% summarize(count = n())

###the df which should now roughly be a dataset of pursuit fatalities, but we need to do some cleaning before we join.
###rename/relocate/clean columnse, prep for joining
### description of filters here: https://www.automotivesafetycouncil.org/wp-content/uploads/2018/10/2008-2017-Fatality-Analysis-Reporting-System-FARS-Auxiliary-Datasets-Analytical-User’s-Manual.pdf
nhtsa_fatalities <- person_accident_race %>%
  mutate(date2 = str_c(MONTH.x,"/",DAY.x,"/",YEAR.x)) %>%
  relocate(date2, .after = YEAR.x) %>%
  mutate(date = as.Date(date2, format = "%m/%d/%Y")) %>%
  relocate(date, .after = date2) %>%
  mutate(county = tolower(COUNTYNAME)) %>%
  mutate(county = gsub("[0-9]|\\(|\\)", "", county)) %>%
  relocate(county, .before = COUNTYNAME) %>%
  mutate(county = str_trim(county)) %>%
  mutate(state_abb = state.abb[match(STATENAME.x,state.name)]) %>%
  relocate(state_abb, .before = date) %>%
  mutate(age = as.double(AGE)) %>%
  mutate(race_source = "nhtsa")

nhtsa_fatalities <- nhtsa_fatalities %>%
  mutate(index = 1:nrow(nhtsa_fatalities), nhtsa_fatalities)

#read in data from airtable
#airtable_fatalities <- read_csv("merged5.csv") %>%
airtable_fatalities <- read_csv("merged9_dec8_v1_2023.csv") %>%
  mutate(date = as.Date(date2, format =  "%m/%d/%Y")) %>%
  relocate(date, .after = date2)%>%
  mutate(state_abb = toupper(state)) %>%
  relocate(state_abb, .after = county) %>%
  mutate(state_abb = sub("ARIZONA","AZ",state_abb), state_abb = sub("VIRGINIA","VA", state_abb)) %>%
  mutate(county = tolower(county)) %>%
  mutate(county = str_replace_all(county,"county|parish|city|[[:punct:]]", "")) %>%
  mutate(county = str_trim(county)) %>%
  mutate(age = as.double(age))


#create a subset of NHTSA data just for joining with airtable
nhtsa_select_global <- nhtsa_fatalities %>%
  select(accident_id, county, date, state_abb, age, SEXNAME, race_forATjoin, race_source, index, PER_TYPNAME, FATALS.y, YEAR, LATITUDE, LONGITUD, PER_TYP) %>%
  mutate(SEXNAME = tolower(SEXNAME)) %>%
  rename(gender = SEXNAME) %>%
  mutate(county = str_replace_all(county,"county|parish|city|[[:punct:]]", ""))

colnames(nhtsa_select_global) <- paste("nhtsa",colnames(nhtsa_select_global),sep="_") 


colnames(airtable_fatalities) <- paste("at",colnames(airtable_fatalities),sep="_") 

#create a subset of airtable data just for joining with NHTSA
airtable_fatalities_select <- airtable_fatalities %>%
 # select(at_date, at_county, at_year, at_Name, at_age, at_gender, at_race, at_race_source, at_person_role, 
  #       at_initial_reason, at_notes, at_circumstances, at_victim_image, at_news_urls, at_state_abb, 
   #      at_number_dead, at_case_id, at_latitude, at_longitude, at_zip, at_index, at_is_match) %>%
  filter(at_year != 2022, at_is_match != 1|is.na(at_is_match))


#also new
airtable_fatalities_select_filtered <- airtable_fatalities %>% 
 # select(at_date, at_county, at_year, at_Name, at_age, at_gender, at_race, at_race_source, at_person_role, 
  #       at_initial_reason, at_notes, at_circumstances, at_victim_image, at_news_urls, at_state_abb, 
   #      at_number_dead, at_case_id, at_latitude, at_longitude, at_zip, at_index, at_is_match) %>%
  filter(at_year== 2022 | at_is_match == 1) %>%
  mutate(data_source = "airtable")




#join the airtable and the nhtsa datasets together
joined <- inner_join(airtable_fatalities_select, nhtsa_select_global, by = c("at_date" = "nhtsa_date", "at_county" = "nhtsa_county", "at_state_abb" = "nhtsa_state_abb"), relationship = "many-to-many") 

#relocate columns and rename for easier reading of df
joined1 <- joined %>%
  relocate(nhtsa_FATALS.y, .after=at_number_dead) %>%
  mutate(nhtsa_state_abb = at_state_abb) %>%
  mutate(nhtsa_date = at_date) %>%
  mutate(nhtsa_county = at_county) %>%
  relocate(nhtsa_age, .after = at_age) %>%
  relocate(nhtsa_gender, .after = at_gender) %>%
  relocate(nhtsa_race_forATjoin, .after = at_race) 

###create a filter that conditionally filters out duplicates based on their proximity to each other  
#for duplicates, the closest matches to each other in gender and age stay in
#for non-dupes, the original match stays in
slice_joined1 <- joined1 %>%
  mutate(at_gender = trimws(at_gender, which = c("both"))) %>%
  mutate(nhtsa_gender = trimws(nhtsa_gender, which = c("both"))) %>%
  group_by(at_index) %>% mutate(countatindex = n()) %>% ungroup %>%
  group_by(nhtsa_index) %>% mutate(countnhtsaindex = n()) %>% ungroup %>%
  mutate(nhtsa_at_index = paste(nhtsa_index, at_index, sep = "_")) %>%
  mutate(quality = case_when((countatindex > 1 |countnhtsaindex > 1) & at_age == nhtsa_age & at_gender == nhtsa_gender ~ 4,
                             (countatindex >1.0 |countnhtsaindex > 1.0) & ((round(at_age) <= nhtsa_age+1.0&round(at_age)>=nhtsa_age-1.0)|is.na(at_age)|nhtsa_age == 998) & at_gender == nhtsa_gender ~ 3,
                             (countatindex == 1 | countnhtsaindex == 1) ~ 3,
                             (countatindex >1 |countnhtsaindex > 1) & ((round(at_age) <= nhtsa_age+4&round(at_age)>=nhtsa_age-4)|is.na(at_age) & at_gender == nhtsa_gender) ~ 2,
                             ((nhtsa_age+4&round(at_age)>=nhtsa_age-4) & at_gender=="unknown"|nhtsa_gender=="unknown"|is.na(at_gender)|is.na(nhtsa_gender)) ~ 2,
                             .default = 1)) %>%
  relocate(quality, .before = at_Name) %>%
  group_by(at_Name, at_date) %>%
  slice(which.max(quality))


#find rows that have unique dates + counties but didn't make it through our filtering above bc they are 'name withheld'
namelessjoined <- anti_join(joined1, slice_joined1, by = c("at_date", "at_county", "at_Name")) 

#dedupe further and add a column for data source for the joined data.
#set aside for now.
joineddistinct2 <- slice_joined1 %>%
  distinct(at_Name, nhtsa_at_index, .keep_all = TRUE) %>%
  mutate(data_source = "nhtsa_airtable")

#an aside - there are a few cases where nhtsa's death counts differ from ours in airtable. 
#important to look at those later.
differing_death_counts <- joineddistinct2 %>%
  filter(at_number_dead != nhtsa_FATALS.y)

#ok onto the next - finding a) fuzzy matches/possible matches
#b) cases that appear only in airtable or only in nhtsa
#first we anti-join the airtable data to find possible deaths missing from NHTSA - the first iteration of our 'undercount' figure
nonjoined_airtable <- anti_join(airtable_fatalities_select, nhtsa_select_global,by = c("at_date"="nhtsa_date", "at_county"="nhtsa_county", "at_state_abb"="nhtsa_state_abb")) 

#anti-join to find possible deaths missing from airtable
nonjoined_nhtsa <- anti_join(nhtsa_select_global, airtable_fatalities_select,by = c("nhtsa_date" = "at_date", "nhtsa_county" = "at_county", "nhtsa_state_abb" = "at_state_abb")) 

#Before we get an undercount figure we have to ID and name all 'fuzzy matches.'
#our undercount figure will be conservative, meaning if the match appears to be close, we will consider it a match.
#We will run the airtable data against the nhtsa data, testing each row to see if it matches: 
#a) date and state, and b) county, state and date +- 3 days

#first, the date fuzzy matches!

# Add date ranges to both data frames
nonjoined_airtable <- nonjoined_airtable %>%
  mutate(start_date = as.numeric(at_date - 7),
         end_date = as.numeric(at_date + 7)) %>%
  filter(!is.na(start_date) & !is.na(end_date))

nonjoined_nhtsa <- nonjoined_nhtsa %>%
  mutate(start_date = as.numeric(nhtsa_date - 7),
         end_date = as.numeric(nhtsa_date + 7)) %>%
  filter(!is.na(start_date) & !is.na(end_date))

#I did this via a genome join, which checks both for one exact match (county) and then a rough match within a small range
#This one was within 3 days on either side. When I did my manual review, the vast majority of possible matches looked between 1-2
#days difference.
#this join will result in duplicates because i'm looking at a number of different possible nhtsa rows for 
#every row in airtable and vice-versa. Going forward, i will filter out rows with non-matching genders, ages, etc.
#and i will dedupe on name as well, ending up only with unique matches that have lots of other matching or similar variables.

possible_datefuzzies <- genome_inner_join(nonjoined_nhtsa, nonjoined_airtable,
                                          by = c("nhtsa_county" = "at_county", "start_date", "end_date")) 


possible_datefuzziesorg <- possible_datefuzzies %>%
  mutate(nhtsa_county = at_county) %>%
  relocate(at_state_abb, .after = nhtsa_state_abb) %>%
  relocate(nhtsa_FATALS.y, .after=at_number_dead) %>%
  relocate(at_age, .before = nhtsa_YEAR) %>%
  relocate(nhtsa_age, .after = at_age) %>%
  relocate(nhtsa_gender, .after = at_gender) %>%
  relocate(nhtsa_race_forATjoin, .after = at_race) %>%
  relocate(nhtsa_PER_TYPNAME, .after = at_person_role) %>%
  mutate(agediff = at_age - nhtsa_age, datediff = at_date - nhtsa_date, gendermatch = ifelse(at_gender == nhtsa_gender, "1", "0")) %>%
  relocate(datediff, .after = at_date) %>%
  relocate(agediff, .after = nhtsa_age) %>%
  relocate(nhtsa_county, .after = at_county) %>%
  relocate(gendermatch, .after = nhtsa_gender) %>%
  filter(nhtsa_state_abb == at_state_abb, gendermatch != 0, (abs(agediff) <= 7)) %>%
  distinct(at_Name, nhtsa_date, at_county, .keep_all = TRUE) 

possible_datefuzziesorg_grouped <- possible_datefuzziesorg  %>%
  group_by(at_year) %>%
  summarize(count = n())

### now we will join the nonjoined data by date and state to see if there are matches where we labeled counties differently
datestate <- inner_join(nonjoined_airtable, nonjoined_nhtsa, by = c("at_date"="nhtsa_date", "at_state_abb"="nhtsa_state_abb"), relationship = "many-to-many") 

##compare and relocate a bunch of the columns to test whether each matches
##this list feels pretty comprehensively like a list of actual matches!
possiblefuzzies_datestate <- datestate %>%
  mutate(nhtsa_state_abb = at_state_abb) %>%
  mutate(nhtsa_date = at_date) %>%
  relocate(at_age, .before = nhtsa_YEAR) %>%
  relocate(nhtsa_age, .after = at_age) %>%
  relocate(nhtsa_gender, .after = at_gender) %>%
  relocate(nhtsa_race_forATjoin, .after = at_race) %>%
  relocate(nhtsa_PER_TYPNAME, .after = at_person_role) %>%
  mutate(agediff = at_age - nhtsa_age) %>%
  relocate(nhtsa_county, .after = at_county) %>%
  mutate(gendermatch = ifelse(at_gender == nhtsa_gender, "1", "0")) %>%
  relocate(gendermatch, .after = nhtsa_gender) %>%
  #filtering the fuzzy matches to cases where gender matches and the age difference is within three years on either side
  filter(gendermatch != 0, abs(agediff) <= 4) %>%
  distinct(at_Name, at_date, at_county, .keep_all = TRUE) %>%
  #kept both counties, but am using NHTSA's county as the default
  mutate(latdiff = nhtsa_LATITUDE-at_latitude)

#####create dataframe with fuzzies added to joineddistinct

#####bind_rows of the two dataframes of fuzzy matches to get a comprehensive dataframe of joined_distinct
#but first create a column in the fuzzy match dataframe to categorize each row as a fuzzy match
fuzzies <- bind_rows(possible_datefuzziesorg, possiblefuzzies_datestate) %>%
  mutate(data_source = "nhtsa_airtable_fuzzy")

joineddistinct2_plusfuzzies <- bind_rows(joineddistinct2, fuzzies)

#create a true dataframe of airtable rows not in nhtsa by taking our earlier nonjoined_airtable df 
#and anti-joining it with the fuzzies:
nonjoined_airtable2 <- anti_join(nonjoined_airtable, fuzzies, by = c("at_Name", "at_index")) %>%
  mutate(data_source = "airtable")

#create a true dataframe of nhtsa rows not in airtable by taking our earlier nonjoined_nhtsa df 
#and anti-joining it with the fuzzies:
nonjoined_nhtsa2 <- anti_join(nonjoined_nhtsa, fuzzies, by = c("nhtsa_accident_id", "start_date" = "start_date.x", "nhtsa_age", "nhtsa_LATITUDE", "nhtsa_LONGITUD", "nhtsa_PER_TYP")) %>%
  mutate(data_source = "nhtsa") %>%
  distinct()

#add the nameless matches 
namelessjoined <- namelessjoined %>%
  mutate(data_source = "nhtsa_airtable_namelessweird")


# Define replacement patterns and replacement string
replacement_patterns <- c("all other races", "american indian \\(includes alaska native\\)",
                          "guamanian or chamorro", "filipino", "other race",
                          "multiple races unspecified", "multiple races \\(individual races not specified\\; ex\\. \"mixed\"\\)",
                          "north american indian or alaska native")

replacement_string <- "other"

#the mega-join...bind the rows of fuzzy-joined data, well-joined ata and nonjoined airtable and nhtsa data plus those few errant rows
#of nameless joins that slipped through the cracks.
#also create columns for use in final dataset
v1_allpursuitdeaths <- bind_rows(list(joineddistinct2_plusfuzzies, nonjoined_airtable2, nonjoined_nhtsa2, namelessjoined, airtable_fatalities_select_filtered)) %>%
  relocate(nhtsa_race_source, .after = at_race_source) %>%
  mutate(year_joined = ifelse(!is.na(nhtsa_YEAR), nhtsa_YEAR, at_year)) %>%
  mutate(age_joined = ifelse(!is.na(at_age), at_age, nhtsa_age)) %>%
  mutate(gender_joined = ifelse(!is.na(at_gender), at_gender, nhtsa_gender)) %>%
  mutate(date_joined = ifelse(!is.na(nhtsa_date), as.Date(nhtsa_date), as.Date(at_date))) %>%
  mutate(date_joined = as.Date(date_joined)) %>%
  mutate(county_joined = ifelse(!is.na(nhtsa_county), nhtsa_county, at_county)) %>%
  mutate(lat_joined = ifelse(!is.na(nhtsa_LATITUDE), nhtsa_LATITUDE, at_latitude)) %>%
  mutate(long_joined = ifelse(!is.na(nhtsa_LONGITUD), nhtsa_LONGITUD, at_longitude)) %>%
  mutate(state_joined = ifelse(!is.na(nhtsa_state_abb), nhtsa_state_abb, at_state_abb)) %>%
  mutate(racesource_combined = paste(at_race_source, nhtsa_race_source, sep=", ")) %>%
  mutate(racesource_combined = str_replace_all(racesource_combined, ", NA|NA, ", "")) %>%
  relocate(racesource_combined, .after = nhtsa_race_source) %>%
  relocate(year_joined, .before = at_year) %>%

  mutate(number_dead_joined = ifelse(!is.na(nhtsa_FATALS.y), nhtsa_FATALS.y, at_number_dead)) %>%
  #mutate(number_dead_joined = pmax(nhtsa_FATALS.y, at_number_dead)) %>%
  relocate(number_dead_joined, .after = year_joined) %>%
  mutate(race_joined = ifelse(!is.na(nhtsa_race_forATjoin) & nhtsa_race_forATjoin != "unknown|Unknown", nhtsa_race_forATjoin, 
                              ifelse(at_race != "unknown|Unknown" & !is.na(at_race), at_race, "unknown"))) %>%
  mutate(race_joined = recode(race_joined, "all other races" = "other", 
                              "american indian (includes alaska native)" = "other",
                              "guamanian or chamorro" = "asian",
                              "filipino" = "asian",
                              "other race" = "other",
                              "other race,latino" = "other,latino",
                              "multiple races unspecified" = "other",
                              "multiple races (individual races not specified; ex. \"mixed\")" = "other",
                              "multiple races (individual races not specified; ex. \"mixed\"),latino" = "other",
                              "multiple races unspecified,latino" = "other,latino",
                              "north american indian or alaska native" = "other",
                              "north american indian or alaska native,latino" = "other,latino",
                              "japanese" = "asian",
                              "asian (includes south and central america, any other, except american or asians)" = "asian",
                              "asian (includes south and central america, any other, except american or asians),latino" = "asian,latino",
                              "asian or pacific islander, no specific (individual) race" = "asian",
                              "asian or pacific islander, no specific (individual) race,latino" = "asian,latino",
                              "other asian or pacific islander" = "asian",
                              "redacted" = "unknown",
                              "NA" = "unknown")) %>%
  relocate(race_joined, .before = at_race) %>%
  relocate(data_source, .before = at_date) 

#check pursuits by year and state to make sure they roughly match up with priors
countyandstate <- v1_allpursuitdeaths %>%
  group_by(state_joined) %>% mutate(count_state = n()) %>%
  ungroup %>%
  group_by(county_joined, state_joined, count_state) %>% summarize(count_county = n()) 

yearly <- v1_allpursuitdeaths %>%
  mutate(year = ifelse(!is.na(nhtsa_YEAR), nhtsa_YEAR, at_year)) %>%
  group_by(year) %>% summarize(count = n()) 

#anything missing? answer:not from a numeric standpoint...nhtsa's missing stuff appear to be mostly filtered-out dupes 
#(which we can use to manually replace the less good matches later)
anything_missing_nhtsa <- anti_join(nhtsa_select_global, v1_allpursuitdeaths, by = "nhtsa_index")

#check if missing in airtable - 2 rows missing - add back in
anything_missing_airtable <- anti_join(airtable_fatalities_select, v1_allpursuitdeaths, by = "at_index") %>%
  mutate(data_source = "airtable")

v2_allpursuitdeaths <- bind_rows(v1_allpursuitdeaths, anything_missing_airtable) 

#now we are at one too many airtable rows. so we will split the data into airtable and nhtsa and dedupe on at index...

#just airtable (has an index that isn't NA)
at_allpursuitdeaths_final <- v2_allpursuitdeaths %>% filter(!is.na(at_index)) %>%
  distinct(at_index, .keep_all = TRUE)

#just nhtsa (has an NA index value)
noat_allpursuitdeaths_final <- v2_allpursuitdeaths %>% filter(is.na(at_index)) 

#combined - the final join
#there are a perfect number of airtable rows with no dupes so we have everything in airtable
#HOWEVER...NHTSA still has a few small issues. there appear to be six missing rows and 5 erroneous matches. 
#i will happily take an error rate of 0.4% in my script (notwithstanding some of the other rows that may have matched erroneously
#or to the wrong row because the joining info is identical across two or more rows.) 
#Plus we will go through all of those and fix them manually. won't be exhaustive
v3_allpursuitdeaths <- bind_rows(at_allpursuitdeaths_final, noat_allpursuitdeaths_final) %>%
  arrange(date_joined, county_joined)

grouped <- v3_allpursuitdeaths %>%
  group_by(year_joined, data_source) %>% summarize(count = n())

#we are close but still need to do a manual review and locate the additional 10 nhtsa rows!

nhtsa_superfluous_rows <- v3_allpursuitdeaths %>%
  filter(data_source == "nhtsa") %>%
  arrange(nhtsa_index, nhtsa_date) %>%
  group_by(nhtsa_accident_id) %>% mutate(count_nhtsa_acc_id = n()) %>% ungroup() %>%
  filter(count_nhtsa_acc_id != nhtsa_FATALS.y)


v4_allpursuitdeaths <- anti_join(v3_allpursuitdeaths, nhtsa_superfluous_rows) 

v4_allpursuitdeaths$joined_id <- 1:nrow(v4_allpursuitdeaths)

race_breakdown <- v4_allpursuitdeaths %>%
  filter(grepl("airtable", data_source, ignore.case = TRUE)) %>%
  group_by(at_person_role, race_joined) %>%
  summarize(count =n())

#now we are done

write.csv(v4_allpursuitdeaths, "allpursuitdeaths_final1208v1.csv", na="")
write.csv(race_breakdown, "race_breakdown128.csv")


susieview0130 <- read_csv("susieview_0130.csv") %>%
  filter(data_source != "airtable")

missingnhtsa <- anti_join(nhtsa_select_global, susieview0130, by = c("nhtsa_accident_id", "nhtsa_PER_TYP", "nhtsa_date"))


 

airtabledeaths <- read_csv("susieview_0130.csv") %>%
  filter(data_source != "airtable", year_joined != 2022)
                         