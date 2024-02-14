# Fatal police pursuits

Description of project TK.

The fields have the following definitions:

| Column name  | Data type | Description |
| ------------- | ------------- | ------------ |
| `unique_id`  | integer  | unique number for each person in data.             |
| `data_source`  | single-select. options: `nhtsa`, `airtable`, `nhtsa_airtable`, `nhtsa_airtable_fuzzy    | source of person and fatality information.              |
| `year_joined`  | integer  | the year the pursuit occurred.             |
| `date_joined`  | date  | the date the pursuit occurred; if pursuit takes place over multiple days, date of crash or end of pursuit.            |
| `number_dead_joined`  | integer  | number of people killed in the pursuit.             |
| `age_joined`  | float  | age of person killed. blank field indicates age is unknown.            |
| `gender_joined`  | single select. options: `male`, `female`, `nonbinary`, `unknown`  |  gender of person killed.             |
| `race_joined`  | multiple select. options: `black`, `white`, `latino`, `asian`, `other`, `unknown`.  | perceived race and/or ethnicity of the person killed.           |
| `racesource_combined`  | multiple select. options: `news reports`, `nhtsa`, `photo`, `original data`,  `other`  |source of perceived race and ethnicity information.             |
| `county_joined`  | string.  | county where fatality or fatal crash occurred.             |
| `state_joined`  | single select. options: 50 states plus D.C.  | state where fatality or fatal crash occurred.             |
| `lat_joined`  | float  | approximate latitude of fatality or fatal crash.             |
| `long_joined`  | float  | approximate longitude of fatality or fatal crash.             |
| `at_name`  | string  | name of person killed.             |
| `at_initial_reason`  | single-select. options: `traffic stop`, `suspected nonviolent`, `suspected violent`, `domestic incident`, `minor/no crime`, `other`, `unknown`  | the alleged incident that touched off officers' pursuit. even if a different crime is later confirmed (such as stolen vehicle) or it's confirmed that no crime has actually occurred, this column specifies the incident that touched off the chase according to news reports and other sources.             |
| `at_person_role`  | single select. options: `driver`, `passenger`, `bystander`, `officer`, `unclear`, `other`  | the role of the person killed as described in news reports and other records. Driver refers to the driver of the car being pursued; passenger refers to a passenger in the car being pursued. Bystander refers to a person (on foot or in another car) that was killed but not being pursued.           |
| `at_main_agency_responsible`  | string.  | the main agency responsible for the pursuit if in airtable, as described in news reports. if multiple agencies gave chase, defaults to the agency chasing closest to the fatality or fatal crash.             |
| `at_news_urls`  | urls | one or more links to a relevant story about the pursuit.             |
| `at_city`  | string  | city of crash if included in our detailed dataset.             |
| `at_zip`  | string  | ZIP code where fatality or fatal crash occurred if included in our detailed dataset. note: ZIP code is in a string format to avoid the deletion of leading zeroes.              |
| `centroid_geo`  | binary  |  if 1, indicates the coordinates of this crash are a) the centroid of the zip code where it occurred and not exact coordinates. If 0, indicates coordinates of this crash were entered by researchers and should be accurate to approximate location of crash.              |
| `in_nhtsa`  | Content Cell  |              |


Methodology - TK
