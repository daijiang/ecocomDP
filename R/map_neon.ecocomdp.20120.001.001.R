##############################################################################################
#' @examples 
#' \dontrun{
#' my_result <- map_neon.ecocomDP.20120.001.001(site= c('COMO','LECO'),
#'                                                          startdate = "2019-06", 
#'                                                          enddate = "2019-09")
#' }

#' @describeIn map_neon_data_to_ecocomDP This method will retrieve density data for MACROINVERTEBRATE from neon.data.product.id DP1.20120.001 from the NEON data portal and map to the ecocomDP format
#' @export

# changelog and author contributions / copyrights
#   Eric R Sokol & Ruvi Jaimes (2020-06-08)
#     original creation
##############################################################################################

##### my version ----
# updated by Eric on 6/9/2020 ~5:10pm
map_neon.ecocomdp.20120.001.001 <- function(
  neon.data.product.id ="DP1.20120.001",
  ...){
  
  #NEON target taxon group is MACROINVERTEBRATE
  neon_method_id <- "neon.ecocomdp.20120.001.001"
 
  # get all tables for this data product for the specified sites in my_site_list, store them in a list called all_tabs
  all_tabs <- neonUtilities::loadByProduct(
    dpID = neon.data.product.id,
    ...)
   
  
  # extract the table with the field data from the all_tabs list of tables
  if("inv_fieldData" %in% names(all_tabs)){
    inv_fielddata <- all_tabs$inv_fieldData %>%
      dplyr::filter(!is.na(sampleID))
    
    # known problem with dupes published in the inv_fieldData table as of 2021-02-18
    # this anticipated to be fixed in data release next year (Jan 2022)
    # use sampleID as primary key, keep the first uid associated with any sampleID that has multiple uids

    de_duped_uids <- inv_fielddata %>% 
      dplyr::group_by(sampleID) %>%
      dplyr::summarise(n_recs = length(uid),
                       n_unique_uids = length(unique(uid)),
                       uid = dplyr::first(uid))
    
    inv_fielddata <- de_duped_uids %>%
      dplyr::select(uid, sampleID) %>%
      dplyr::left_join(inv_fielddata)

  }else{
    # if no data, return an empty list
    warning(paste0(
      "WARNING: No field data available for NEON data product ",
      neon.data.product.id, " for the dates and sites selected."))
    return(list())
  }
 
  
  # extract the table with the taxonomy data from all_tabls list of tables
  if("inv_taxonomyProcessed" %in% names(all_tabs)){
    inv_taxonomyProcessed <- all_tabs$inv_taxonomyProcessed
  }else{
    # if no data, return an empty list
    warning(paste0(
      "WARNING: No taxon count data available for NEON data product ",
      neon.data.product.id, " for the dates and sites selected."))
    return(list())
  }
 

  # location ----
  # get relevant location info from the data
  table_location_raw <- inv_fielddata %>%
    dplyr::select(domainID, siteID, namedLocation, decimalLatitude, decimalLongitude, elevation) %>%
    dplyr::distinct() 
  # create a location table, which has the lat long for each NEON site included in the data set
  # start with the inv_fielddata table and pull out latitude, longitude, and elevation for each NEON site that occurs in the data
  

  table_location <- ecocomDP::make_neon_location_table(
    loc_info = table_location_raw,
    loc_col_names = c("domainID", "siteID", "namedLocation"))
  
  table_location_ancillary <- ecocomDP::make_neon_ancillary_location_table(
    loc_info = table_location_raw,
    loc_col_names = c("domainID", "siteID", "namedLocation"))
  

  

  
  # taxon ----
  # create a taxon table, which describes each taxonID that appears in the data set
  # start with inv_taxonomyProcessed
  table_taxon <- inv_taxonomyProcessed %>%
    
    # keep only the coluns listed below
    dplyr::select(acceptedTaxonID, taxonRank, scientificName, identificationReferences) %>%
    
    # remove rows with duplicate information
    dplyr::distinct() %>%
    
    # rename some columns
    dplyr::rename(taxon_id = acceptedTaxonID,
           taxon_rank = taxonRank,
           taxon_name = scientificName,
           authority_system = identificationReferences) %>%
    # concatenate different references for same taxonID
    dplyr::group_by(taxon_id, taxon_rank, taxon_name) %>%
    dplyr::summarize(
      authority_system = paste(authority_system, collapse = "; "))
  
  

  
  
  # observation ----
  # Make the observation table.
  # start with inv_taxonomyProcessed
  # NOTE: the observation_id = uuid for record in NEON's inv_taxonomyProcessed table 
  table_observation <- inv_taxonomyProcessed %>% 
    dplyr::filter(targetTaxaPresent == "Y") %>%
    # select a subset of columns from inv_taxonomyProcessed
    dplyr::select(uid,
                  sampleID,
                  namedLocation, 
                  collectDate,
                  subsamplePercent,
                  individualCount,
                  estimatedTotalCount,
                  acceptedTaxonID, 
                  domainID, 
                  siteID) %>%
    dplyr::distinct() %>% 
    
    # suppressMessages(ecocomDP::make_location(cols = c("domainID", "siteID", "namedLocation"))) %>% 
    
    # Join the columns selected above with two columns from inv_fielddata (the two columns are sampleID and benthicArea)
    dplyr::left_join(inv_fielddata %>% dplyr::select(sampleID, benthicArea)) %>%
    
    # some new columns called 'variable_name', 'value', and 'unit', and assign values for all rows in the table.
    # variable_name and unit are both assigned the same text strint for all rows. 
    dplyr::mutate(variable_name = 'density',
                  value = estimatedTotalCount / benthicArea,
                  unit = 'count per square meter') %>% 
    
    # rename some columns
    dplyr::rename(observation_id = uid,
                  event_id = sampleID,
                  observation_datetime = collectDate,
                  taxon_id = acceptedTaxonID) %>%
    
    # make a new column called package_id, assign it NA for all rows
    dplyr::mutate(package_id = paste0(neon_method_id, ".", format(Sys.time(), "%Y%m%d%H%M%S"))) %>% 
    dplyr::left_join(table_location, by = c("namedLocation" = "location_name")) %>% 
    dplyr::select(observation_id, 
                  event_id, 
                  package_id, 
                  location_id, 
                  observation_datetime, 
                  taxon_id, 
                  variable_name, 
                  value,
                  unit)
  
  
  
  

  # ancillary observation table ----
  

  table_observation_ancillary_wide <- inv_fielddata %>% 
    dplyr::select(eventID, sampleID) %>% 
    dplyr::filter(!is.na(sampleID)) %>%
    dplyr::rename(neon_sample_id = sampleID,
           neon_event_id = eventID) %>% 
    dplyr::mutate(event_id = neon_sample_id) %>%
    dplyr::distinct()
  

  table_observation_ancillary <- ecocomDP::make_neon_ancillary_observation_table(
    obs_wide = table_observation_ancillary_wide,
    ancillary_var_names = names(table_observation_ancillary_wide))
  
  # table_observation_ancillary <- table_observation_ancillary_wide %>%
  #   tidyr::pivot_longer(
  #     cols = -event_id,
  #     names_to = "variable_name",
  #     values_to = "value") %>% 
  #   dplyr::mutate(
  #     observation_ancillary_id = paste0(variable_name, "_for_", event_id))
  #   
  


  # make dataset_summary -- required table
  years_in_data <- table_observation$observation_datetime %>% lubridate::year()
  years_in_data %>% ordered()
  
  table_dataset_summary <- data.frame(
    package_id = table_observation$package_id[1],
    original_package_id = neon.data.product.id,
    length_of_survey_years = max(years_in_data) - min(years_in_data) + 1,
    number_of_years_sampled	= years_in_data %>% unique() %>% length(),
    std_dev_interval_betw_years = years_in_data %>% 
      unique() %>% sort() %>% diff() %>% stats::sd(),
    max_num_taxa = table_taxon$taxon_id %>% unique() %>% length()
  )
  
  

  # return ----
  # list of tables to be returned, with standardized names for elements
  out_list <- list(
    location = table_location,
    location_ancillary = table_location_ancillary,
    taxon = table_taxon,
    observation = table_observation,
    observation_ancillary = table_observation_ancillary,
    dataset_summary = table_dataset_summary)
  
  # return out_list -- this is output from this function
  return(out_list)
  
} #END of function

# my_result <- map_neon_data_to_ecocomDP.MACROINVERTEBRATE(site= c('COMO','LECO'), startdate = "2019-06",enddate = "2019-09")
# my_result <- map_neon_data_to_ecocomDP.MACROINVERTEBRATE(site= c('COMO','LECO'),check.size = FALSE)
# my_result <- map_neon_data_to_ecocomDP(neon.data.product.id = "DP1.20120.001", site= c('COMO','LECO'), check.size = FALSE, token = Sys.getenv("NEON_TOKEN"))
# my_result <- read_data(id = "DP1.20120.001", site= c('COMO','LECO'), check.size = FALSE, token = Sys.getenv("NEON_TOKEN"))


