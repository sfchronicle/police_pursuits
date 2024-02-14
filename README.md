# Fatal police pursuits database

In late February 2024, the San Francisco Chronicle published **Fast and Fatal,** a yearlong investigation into police car chases across the country. Central to the investigation was a dataset reporters built of people killed in pursuits from 2017 through 2022.

This repository houses the public-facing version of our data, which we invite researchers, other journalists and anyone else interested in fatal police pursuits to download and explore.

<h3> Data Dictionary </h3>

The fields have the following definitions:

| Column name  | Data type | Description |
| ------------- | ------------- | ------------ |
| `unique_id`  | integer  | unique number for each person in data.             |
| `data_source`  | single-select. options: `nhtsa`, `airtable`, `nhtsa_airtable`, `nhtsa_airtable_fuzzy`    | source of person and fatality information. airtable refers to our detailed dataset sourced from news reports, public records and datasets compiled by other research organizations. nhtsa refers to NHTSA's Fatality Analysis Reporting System, specifically if the death is reported as stemming from a "police pursuit-involved" fatal crash.            |
| `year_joined`  | integer  | the year the pursuit occurred.             |
| `date_joined`  | date  | the date the pursuit occurred; if pursuit takes place over multiple days, date of crash or end of pursuit.            |
| `number_dead_joined`  | integer  | number of people killed in the pursuit.             |
| `age_joined`  | float  | age of person killed. blank field indicates age is unknown.            |
| `gender_joined`  | single select. options: `male`, `female`, `nonbinary`, `unknown`  |  gender of person killed.             |
| `race_joined`  | multiple select. options: `black`, `white`, `latino`, `asian`, `other`, `unknown`.  | perceived race and/or ethnicity of the person killed.           |
| `racesource_combined`  | multiple select. options: `news reports`, `nhtsa`, `photo`, `original data`,  `other`  |source of perceived race and ethnicity information.             |
| `county_joined`  | string  | county where fatality or fatal crash occurred.             |
| `state_joined`  | single select. options: 50 states plus D.C.  | state where fatality or fatal crash occurred.             |
| `lat_joined`  | float  | approximate latitude of fatality or fatal crash.             |
| `long_joined`  | float  | approximate longitude of fatality or fatal crash.             |
| `at_name`  | string  | name of person killed.             |
| `at_initial_reason`  | single-select. options: `traffic stop`, `suspected nonviolent`, `suspected violent`, `domestic incident`, `minor/no crime`, `other`, `unknown`  | the alleged incident that touched off officers' pursuit. even if a different crime is later confirmed (such as stolen vehicle) or it's confirmed that no crime has actually occurred, this column specifies the incident that touched off the chase according to news reports and other sources.             |
| `at_person_role`  | single select. options: `driver`, `passenger`, `bystander`, `officer`, `unclear`, `other`  | the role of the person killed as described in news reports and other records. Driver refers to the driver of the car being pursued; passenger refers to a passenger in the car being pursued. Bystander refers to a person (on foot or in another car) that was killed but not being pursued.           |
| `at_main_agency_responsible`  | string  | the main agency responsible for the pursuit if in airtable, as described in news reports. if multiple agencies gave chase, defaults to the agency chasing closest to the fatality or fatal crash.             |
| `at_news_urls`  | url(s) | one or more links to a relevant story about the pursuit.             |
| `at_city`  | string  | city of crash if included in our detailed dataset.             |
| `at_zip`  | string  | ZIP code where fatality or fatal crash occurred if included in our detailed dataset. note: ZIP code is in a string format to avoid the deletion of leading zeroes.              |
| `centroid_geo`  | binary  |  if 1, indicates the coordinates of this crash are a) the centroid of the zip code where it occurred and not exact coordinates. If 0, indicates coordinates of this crash were entered by researchers and should be accurate to approximate location of crash.              |
| `in_nhtsa`  | binary  | if 1, indicates the death is included in NHTSA's Fatality Analysis Reporting System as stemming from a "police pursuit-involved" fatal crash. If 0, indicates reporters could not find this death in FARS pursuit data.             |


<h3> Methodology </h3>

To build the Chronicle’s national dataset of at least 3,335 people killed in police vehicle pursuits from 2017 through 2022, we used information from three primary sources: the federal government, private research organizations and our reporting.

While no government agency counts every police pursuit death, the National Highway Traffic Safety Administration (NHTSA) comes closest. We used data published by NHTSA via its Fatality Analysis Reporting system (FARS) to produce a list of people killed in police pursuits recorded by the federal agency. Specifically, we drew from the <a href="https://www.google.com/url?q=https://www.nhtsa.gov/file-downloads?p%3Dnhtsa/downloads/FARS/&sa=D&source=docs&ust=1707950128293481&usg=AOvVaw3yGTlZcoPLLxf2aajfmSu3">FARS global </a> person, vehicle and accident files, as well as its auxiliary accident file.

In a separate database, we gathered, cleaned and analyzed information about pursuit deaths from research organizations <a href="https://mappingpoliceviolence.org/?gclid=CjwKCAiA1-6sBhAoEiwArqlGPt8vRmx1gVoNh3hiy4sTXeucxJQRKykgfZjm83yjFOT_4uDFqFNWBxoCGEEQAvD_BwE">Mapping Police Violence</a>, <a href="https://fatalencounters.org/">Fatal Encounters</a> and <a href="https://incarcernation.com/">Incarcernation</a>, manually reviewing each row entered by researchers to ensure accuracy.

To obtain a more robust count, we identified hundreds of additional deaths by searching for news reports on LexisNexis and Google using targeted search terms such as “pursuit,” “chase” and “death.” We also  examined lawsuits and government documents obtained via public records requests. 

The Chronicle followed the <a href="https://portal.cops.usdoj.gov/resourcecenter/Home.aspx?item=cops-r1134"> Police Executive Research Forum's definition</a> of a pursuit: "(1) an active attempt by the officer to apprehend the occupant of the vehicle and (2) the driver refusing to submit to the detention and taking actions to avoid apprehension." We excluded hundreds of vehicle-related deaths that did not meet this definition, such as cases in which officers struck people while responding to emergency calls unrelated to pursuits. We excluded fatalities identified by other research organizations if a) we could not find news reports or other public records indicating a pursuit occurred, and b) we could not find a match in NHTSA’s “pursuit-involved” fatal crash data in FARS. We included several dozen deaths tied to pursuits but not caused directly by a crash, such as when drivers or passengers drowned in a body of water following a chase. However, we excluded people fatally shot by police during or after a pursuit, as those deaths fall into the category of a fatal police shooting. 

The next step was to create one dataset, while avoiding the duplication of cases.

We merged the FARS data with the information from the research groups and our own reporting — comparing them not once but multiple times, using different combinations of date, county and state variables. When a person in FARS matched multiple people in the non-FARS data, we assigned a quality index to each match based on the demographic similarities between the two people (close in age, same gender, etc.), and filtered for the top-quality match in each case.

In dozens of cases, the best-quality (or only) match was imperfect; FARS data listed a death as occurring in a bordering county, for example, or on a date that was up to seven days before or after a similar death record in our data. Most of these cases listed the same number of people killed with consistent genders and the same or similar ages. Given this, and the relative unlikelihood of multiple fatal pursuits occurring within several days of each other in all but the most populous areas, we concluded most of them were likely actual matches and the inconsistencies were due to minor issues with data entry by FARS analysts, researchers or ourselves.

Still, we manually reviewed each imperfect match and identified several that we could not confirm were the same pursuit or person. In these cases we considered them separate pursuits.

To calculate the minimum undercount of pursuit-related fatalities by NHTSA, we produced a list of deaths from 2017 through 2021 that were included in the data from research groups and our reporting but missing from FARS. As of late February, when this project was published, FARS data for 2022 was not publicly available. We manually reviewed news reports associated with each case to determine the most likely reason the death was excluded from FARS’ pursuit-involved death data. 

To understand why police initiated pursuits that ended with fatalities and who died, we relied on the subset of our pursuit fatalities data — roughly two-thirds of the total — that included additional details about the causes and circumstances of each chase and the people involved, gathered from Mapping Police Violence, Fatal Encounters and Incarcernation, plus news reports and public records.

Within this subset, we categorized people killed in pursuits by their role (driver, passenger, officer or bystander) and the alleged violation that led to the fatal pursuit (traffic stop, suspected nonviolent crime, suspected violent crime, domestic incident, minor or no crime or unclear). We manually reviewed each row of data multiple times to ensure that we and other researchers accurately recorded public information. 

Limitations:
<li> Data for 2022 is less comprehensive than prior years because NHTSA had not released its 2022 FARS file by February 2024, and Fatal Encounters researchers stopped collecting data after 2021. To mitigate this issue, we gathered data from the online database Incarcernation for 2022.
<li> FARS collects data similar to our “person role” variable, specifying whether the person killed was in the fleeing vehicle and whether they were a driver, passenger or pedestrian. However, when we compared a subset of their categorizations to ours, we found enough discrepancies that we chose to exclude the FARS data and rely solely on what we could verify through news reports and other public records.
<li> For the race column, we relied heavily on FARS categorizations as well as categorizations made by Mapping Police Violence and Fatal Encounters. We collapsed some racial categories with smaller populations into an “other” category because their numbers were too few to reach reliable conclusions. Additionally, about 11% of the people in our data are categorized as having an “unknown” race. In entering or confirming the race or ethnicity of a person from non-FARS sources, we gauged the person’s “perceived race” based on a combination of the person’s name, photograph(s) and other cues from their obituary or social media profiles. Perceived race is used in police agency datasets, including traffic stop data collected by <a href="https://oag.ca.gov/ab953/board/reports">the California Department of Justice</a> as part of its Racial Identity and Profiling Act.
<li> Our gender variable largely consists of a simple binary — male or female — and includes very little information on people who identify as nonbinary or trans, largely because it was unavailable for all but one case. 
<li> Many news stories did not include the initial reason officers said they initiated a traffic stop or pursuit. Therefore, among our data subset of over 2,000 people replete with additional details about the pursuits associated with their deaths, 207 were killed during chases that police initiated for reasons we were unable to determine.
<li> While this dataset is the fullest accounting of recent police pursuit deaths in the United States, scores of additional deaths could still be missing, due to the limitations of NHTSA data and local press reports. 
We may have overlooked some errors in individual rows during our review. If you spot an error, please email us at <a href="mailto:policerecords@sfchronicle.com">policerecords@sfchronicle.com </a>.

<h3> Acknowledgments </h3>

This dataset would not have been possible without the work of many other researchers, most notably D. Brian Burghart, the creator of Fatal Encounters. We would also like to thank the thousands of journalists who covered the fatal pursuits included in our data. Without their stories, hundreds of chase-related deaths would have remained hidden and the true toll of police pursuits would still be vastly understated. 

We would also like to thank, in no particular order:  Geoffrey Alpert, Thomas Gleason, John P. Gross, Sylvia Germek, Abdul Nasser Rad, Albert L. Liebno, Jr., Lisa Pickoff-White, Lisa Fernandez, NHTSA's FARS analyst team, Alexis Piquero, and others.
