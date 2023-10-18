library(tidyverse)
library(fuzzyjoin)

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
  distinct(STATE, ST_CASE, VEH_NO, PER_NO, AGE, RACENAME.x, .keep_all = TRUE) %>%
  mutate(latino = ifelse(HISPANICNAME == "Non-Hispanic"|HISPANICNAME == "Redacted"|
                           HISPANICNAME == "Unknown", "", "latino")) %>%
  relocate(latino, .after = HISPANICNAME) %>%
  unite(col="race_combined", c(RACENAME.x, RACENAME.y)) %>%
  mutate(race_combined = gsub("_NA|NA_|\\sor\\sAfrican\\sAmerican","",race_combined)) %>%
  mutate(race_combined = tolower(race_combined)) %>%
  mutate(race_combined = gsub("chinese|vietnamese|asian\\sindian|other\\sindian","asian",race_combined)) %>%
  mutate(race_forATjoin = ifelse(latino != "", paste(race_combined, latino, sep=","), race_combined))


racecats <- person_accident_race %>%
  select(race_forATjoin, race_combined, HISPANICNAME)
#join the person-accident df to the race df
person_accident_race <- left_join(person_accident, race_19_21, by = c("YEAR","ST_CASE", "STATE",
                                                                      "PER_NO","VEH_NO", "accident_id")) %>%
  distinct(STATE, ST_CASE, VEH_NO, PER_NO, AGE, RACENAME.x, .keep_all = TRUE) %>%
  mutate(latino = ifelse(HISPANICNAME == "Non-Hispanic"|HISPANICNAME == "Redacted"|
                           HISPANICNAME == "Unknown", "", "latino")) %>%
  relocate(latino, .after = HISPANICNAME) %>%
  unite(col="race_combined", c(RACENAME.x, RACENAME.y)) %>%
  mutate(race_combined = gsub("_NA|NA_|\\sor\\sAfrican\\sAmerican","",race_combined)) %>%
  mutate(race_combined = tolower(race_combined)) %>%
  mutate(race_combined = gsub("chinese|vietnamese|asian\\sindian|other\\sindian","asian",race_combined)) %>%
  mutate(race_forATjoin = ifelse(latino != "", paste(race_combined, latino, sep=","), race_combined))


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
  mutate(age_nhtsa = as.double(AGE)) %>%
  mutate(race_source_nhtsa = "nhtsa")

nhtsa_fatalities <- nhtsa_fatalities %>%
  mutate(nhtsa_index = 1:nrow(nhtsa_fatalities), nhtsa_fatalities)

#read in data from airtable
airtable_fatalities <- read_csv("merged5.csv") %>%
  mutate(date = as.Date(date2, format =  "%m/%d/%Y")) %>%
  relocate(date, .after = date2)%>%
  mutate(state_abb = toupper(state)) %>%
  relocate(state_abb, .after = county) %>%
  mutate(state_abb = sub("ARIZONA","AZ",state_abb), state_abb = sub("VIRGINIA","VA", state_abb)) %>%
  mutate(county = tolower(county)) %>%
  mutate(county = str_replace_all(county,"county|parish|city|[[:punct:]]", "")) %>%
  mutate(county = str_trim(county)) %>%
  rename(AT_race = race) %>%
  mutate(age_airtable = as.double(age))

#create a subset of NHTSA data just for joining with airtable
nhtsa_select_global <- nhtsa_fatalities %>%
  select(accident_id, county, date, state_abb, age_nhtsa, SEXNAME, race_forATjoin, race_source_nhtsa, nhtsa_index, PER_TYPNAME, FATALS.y, YEAR, LATITUDE, LONGITUD, PER_TYP) %>%
  mutate(SEXNAME = tolower(SEXNAME)) %>%
  rename(gender = SEXNAME) %>%
  mutate(county = str_replace_all(county,"county|parish|city|[[:punct:]]", ""))

#create a subset of airtable data just for joining with NHTSA
airtable_fatalities_select <- airtable_fatalities %>%
  select(date, county, year, Name, age_airtable, gender, AT_race, race_source, person_role, initial_reason, notes, circumstances, state_abb, number_dead, case_id, latitude, longitude, zip, index) %>%
  filter(year != 2022)

#join the airtable and the nhtsa datasets together
joined <- inner_join(airtable_fatalities_select, nhtsa_select_global, by = c("date", "county", "state_abb"), relationship = "many-to-many") 

#filter to just distinct rows, because the above join resulted in dupes
#this data will have some inconsistencies with ages, names, genders etc. still figuring out how to make that work
joined1 <- joined %>%
  relocate(FATALS.y, .after=number_dead) %>%
  relocate(age_nhtsa, .after = age_airtable) %>%
  relocate(gender.y, .after = gender.x) %>%
  rename(gender_airtable = gender.x, gender_nhtsa = gender.y) %>%
  relocate(race_forATjoin, .after = AT_race) 

###create a filter that conditionally filters out duplicates based on their proximity to each other  
#for duplicates, the closest matches to each other in gender and age stay in
#for non-dupes, the original match stays in
ATT_joined1 <- joined1 %>%
  mutate(gender.x = trimws(gender_airtable , which = c("both"))) %>%
  mutate(gender.y = trimws(gender_nhtsa, which = c("both"))) %>%
  group_by(index) %>% mutate(countindex = n()) %>% ungroup %>%
  group_by(nhtsa_index) %>% mutate(countnhtsaindex = n()) %>% ungroup %>%
  mutate(nhtsa_at_index = paste(nhtsa_index, index, sep = "_")) %>%
  mutate(quality = case_when((countindex > 1 |countnhtsaindex > 1) & age_airtable == age_nhtsa & gender_airtable == gender_nhtsa ~ 4,
                             (countindex >1.0 |countnhtsaindex > 1.0) & ((round(age_airtable) <= age_nhtsa+1.0&round(age_airtable)>=age_nhtsa-1.0)|is.na(age_airtable)|age_nhtsa == 998) & gender.x == gender.y ~ 3,
                             (countindex == 1 | countnhtsaindex == 1) ~ 3,
                             (countindex >1 |countnhtsaindex > 1) & ((round(age_airtable) <= age_nhtsa+4&round(age_airtable)>=age_nhtsa-4)|is.na(age_airtable) & gender.x == gender.y) ~ 2,
                             ((age_nhtsa+4&round(age_airtable)>=age_nhtsa-4) & gender_airtable=="unknown"|gender_nhtsa=="unknown"|is.na(gender_airtable)|is.na(gender_nhtsa)) ~ 2,
                              .default = 1)) %>%
  relocate(quality, .before = Name) %>%
  group_by(Name, date) %>%
  slice(which.max(quality))
 

#find rows that have unique dates + counties + names but didn't make it through our filtering above
namelessnonjoined <- anti_join(joined1, ATT_joined1, by = c("date", "county", "Name")) 

#dedupe further and add a column for data source for the joined data
joineddistinct2 <- ATT_joined1 %>%
  distinct(Name, index, .keep_all = TRUE) %>%
  mutate(data_source = "nhtsa_airtable")

#anti-join to find data only in airtable - the first iteration of our 'undercount' figure
nonjoined_airtable <- anti_join(airtable_fatalities_select, nhtsa_select_global,by = c("date", "county", "state_abb")) %>%
  rename(gender_airtable = gender)

#anti-join to find data only in nhtsa
nonjoined_nhtsa <- anti_join(nhtsa_select_global, airtable_fatalities_select,by = c("date", "county", "state_abb")) %>%
  rename(gender_nhtsa = gender)

#for later...gotta check our data against nhtsa's.
differing_death_counts <- joineddistinct2 %>%
  filter(number_dead != FATALS.y)

#do what I did in sheets. 
#run the airtable data through nhtsa data, testing each row to see if it matches: 
#a) date and state, and b) county, state and date +- 7 days
#once I get all of those, examine each one manually - maybe in an excel or google spreadsheet
#in final dataset, create column that's like appears_in - 0, nhtsa only, 1, airtable only, 2, nhtsa and 
#airtable automatic match, 3, nhtsa/airtable fuzzy/manual match
#also compare every row in nhtsa to airtable to see the number dead in each instance

#First I checked to see whether the non-joined airtable and nhtsa data had matches.

# Add date ranges to both data frames
nonjoined_airtable <- nonjoined_airtable %>%
  mutate(start_date = as.numeric(date - 3),
         end_date = as.numeric(date + 3))

nonjoined_nhtsa <- nonjoined_nhtsa %>%
  mutate(start_date = as.numeric(date - 3),
         end_date = as.numeric(date + 3))

#i did this via a genome join, which checks both for one exact match (county) and then a rough match within a small range
#This one was within 3 days on either side. When I did my manual review, the vast majority of possible matches looked between 1-2
#days difference.
#this join will result in duplicates because i'm looking at a number of different possible nhtsa rows for 
#every row in airtable and vice-versa. Going forward, i will filter out rows with non-matching genders, ages, etc.
#and i will dedupe on name as well, ending up only with unique matches that have lots of other matching or similar variables.
possible_datefuzzies <- genome_inner_join(nonjoined_nhtsa, nonjoined_airtable,
                                          by = c("county" = "county", "start_date", "end_date")) 

possible_datefuzziesorg <- possible_datefuzzies %>%
  relocate(state_abb.y, .after = state_abb.x) %>%
  relocate(FATALS.y, .after=number_dead) %>%
  relocate(age_airtable, .before = YEAR) %>%
  relocate(age_nhtsa, .after = age_airtable) %>%
  mutate(date = date.y) %>%
  relocate(gender_nhtsa, .after = gender_airtable) %>%
  relocate(race_forATjoin, .after = AT_race) %>%
  relocate(PER_TYPNAME, .after = person_role) %>%
  mutate(agediff = age_airtable - age_nhtsa, datediff = date.y - date.x, gendermatch = ifelse(gender_airtable == gender_nhtsa, "1", "0")) %>%
  relocate(datediff, .after = date.y) %>%
  relocate(agediff, .after = age_nhtsa) %>%
  relocate(county.y, .after = county.x) %>%
  relocate(gendermatch, .after = gender_nhtsa) %>%
  filter(state_abb.x == state_abb.y, gendermatch != 0, (agediff <= 4 & agediff >= -3)) %>%
  distinct(Name, date.x, county.x, .keep_all = TRUE) %>%
  rename(county = county.y)

possible_datefuzziesorg_grouped <- possible_datefuzziesorg  %>%
  group_by(year) %>%
  summarize(count = n())

### now we will join the nonjoined data by date and state to see if there are matches where we labeled counties differently
datestate <- inner_join(nonjoined_airtable, nonjoined_nhtsa, by = c("date", "state_abb"), relationship = "many-to-many") 

##compare and relocate a bunch of the columns to test whether each matches
##this list feels pretty comprehensively like a list of actual matches!
possiblefuzzies_datestate <- datestate %>%
  relocate(age_airtable, .before = YEAR) %>%
  relocate(age_nhtsa, .after = age_airtable) %>%
  relocate(gender_nhtsa, .after = gender_airtable) %>%
  relocate(race_forATjoin, .after = AT_race) %>%
  relocate(PER_TYPNAME, .after = person_role) %>%
  mutate(agediff = age_airtable - age_nhtsa) %>%
  relocate(county.y, .after = county.x) %>%
  mutate(gendermatch = ifelse(gender_airtable == gender_nhtsa, "1", "0")) %>%
  relocate(gendermatch, .after = gender_nhtsa) %>%
  filter(gendermatch != 0, (agediff <= 3 & agediff >= -3)) %>%
  distinct(Name, date, county.x, .keep_all = TRUE) %>%
  rename(county = county.y) %>%
  mutate(latdiff = LATITUDE-latitude)


#####NEXT STEP: examine the NHTSA data to determine whether its summary stats vary dramatically from ours

joineddistinct_year <- joineddistinct2 %>%
  group_by(year) %>%
  summarize(count_join = n())

nonjoined_airtable_year <- nonjoined_airtable %>%
  group_by(year) %>%
  summarize(count_at = n())

nonjoined_nhtsa_year <- nonjoined_nhtsa %>%
  group_by(YEAR) %>%
  rename(year = YEAR) %>%
  summarize(count_nhtsa=n())

#####create dataframe with fuzzies added to joineddistinct

#####bind_rows of the following to get total of joined_distinct:

fuzzies <- bind_rows(possible_datefuzziesorg, possiblefuzzies_datestate) %>%
  mutate(data_source = "nhtsa_airtable_fuzzy")

joineddistinct2_plusfuzzies <- bind_rows(joineddistinct2, fuzzies)
#joineddistinct2 - 979
#possiblefuzzies_datestate - 36
#possible_datefuzziesorg - 55
#add column "orig_data_source" 

#add nonjoined_airtable and anti-join it with the fuzzies:

nonjoined_airtable2 <- anti_join(nonjoined_airtable, fuzzies, by = c("Name", "index")) %>%
  mutate(data_source = "airtable")

#add nonjoined_nhtsa and anti-join it with the fuzzies:
##there are 6 additional ones here....hmmm...or three once you add the distinct thing
nonjoined_nhtsa2 <- anti_join(nonjoined_nhtsa, fuzzies, by = c("accident_id", "start_date" = "start_date.x", "age_nhtsa", "LATITUDE", "LONGITUD", "PER_TYP")) %>%
  mutate(data_source = "nhtsa") %>%
  distinct()

#add weirdagematch - these are not matchy, gotta figure out what is up with that...
namelessnonjoined <- namelessnonjoined %>%
  mutate(data_source = "nhtsa_airtable_namelessweird")

##once we standardize columns to a good-enough degree...then it should be time for manual review, i think
#(5 more entries labeled nhtsa than pursuit deaths in our filtered nhtsa data)....check those out/find them
#the mega-join...bind the rows of fuzzy joined data, well joined ata and nonjoined airtable and nhtsa data plus those few errant rows
#that slipped through the cracks.
allpursuitdeaths_final <- bind_rows(list(joineddistinct2_plusfuzzies, nonjoined_airtable2, nonjoined_nhtsa2, namelessnonjoined)) %>%
  relocate(race_source_nhtsa, .after = race_source) %>%
  mutate(year_joined = ifelse(!is.na(year), year, YEAR)) %>%
  mutate(racesource_combined = ifelse(race_source=="nhtsa", "nhtsa",
                                      ifelse(data_source == "airtable", race_source,
                                             paste(race_source, race_source_nhtsa, sep=",")))) %>%
  relocate(racesource_combined, .after = race_source_nhtsa) %>%
  relocate(year_joined, .before = year) %>%
  mutate(number_dead_joined = ifelse(!is.na(FATALS.y), FATALS.y, number_dead)) %>%
  mutate(number_dead_joined = pmax(FATALS.y, number_dead)) %>%
  relocate(number_dead_joined, .after = year_joined) %>%
  mutate(race_joined = ifelse(!is.na(race_forATjoin) & race_forATjoin != "unknown|Unknown", race_forATjoin, 
                              ifelse(AT_race != "unknown|Unknown" & !is.na(AT_race), AT_race, "unknown"))) %>%
  relocate(race_joined, .before = AT_race) %>%
  relocate(data_source, .before = date) 

#check pursuits by year and state to make sure they roughly match up with priors
countyandstate <- allpursuitdeaths_final %>%
  group_by(state_abb) %>% mutate(count_state = n()) %>%
  ungroup %>%
  group_by(county, state_abb, count_state) %>% summarize(count_county = n()) 

yearly <- allpursuitdeaths_final %>%
  mutate(year = ifelse(!is.na(year), year, YEAR)) %>%
  group_by(year) %>% summarize(count = n()) 

#anything missing? answer:not from a numeric standpoint...nhtsa's missing stuff appear to be mostly filtered-out dupes 
#(which we can use to manually replace the less good matches later)
anything_missing_nhtsa <- anti_join(nhtsa_select_global, allpursuitdeaths_final, by = "nhtsa_index")

##Orange - 75
##Nhtsa Index 219
##St Louis, nhtsa index 661
##Dickson county, nhtsa 763
##Maybe Hennepin county nhtsa index 1570 but looks like nhtsa inaccuracy or something
##2279 - maybe missing (there is another fatal pursuit on the same date and county but recording 3 fatalities instead of 1)


#check if missing in airtable - 2 rows missing - add back in
anything_missing_airtable <- anti_join(airtable_fatalities_select, allpursuitdeaths_final, by = "index") %>%
  mutate(data_source = "airtable")

allpursuitdeaths_final2 <- bind_rows(allpursuitdeaths_final, anything_missing_airtable) 

#now we are at one too many airtable rows. so we will split the data into airtable and nhtsa and dedupe on at index...
allpursuitdeaths_finalat <- allpursuitdeaths_final2 %>% filter(!is.na(index)) %>%
  distinct(index, .keep_all = TRUE)

#just nhtsa
allpursuitdeaths_finalnoat <- allpursuitdeaths_final %>% filter(is.na(index)) 

#combined - the final, true join
#there are a perfect number of airtable rows with no dupes so we have everything in airtable
#HOWEVER...NHTSA still has a few small issues. there appear to be six missing rows and 5 erroneous matches. 
#i will happily take an error rate of 0.4% in my script (notwithstanding some of the other rows that may have matched erroneously
#or to the wrong row because the joining info is identical across two or more rows.) 
#Plus we will go through all of those and fix them manually. won't be exhaustive
allpursuitdeaths_final3 <- bind_rows(allpursuitdeaths_finalat, allpursuitdeaths_finalnoat) %>%
  arrange(date, county)

#we are close but still need to do a manual review and locate the additional six nhtsa rows!

write.csv(allpursuitdeaths_final3, "allpursuitdeaths_final1002v2.csv", na="")

