#' Make EML metadata for a DWcA occurrence from an ecocomDP data package
#'
#' @param path 
#'     (character) Path to the directory containing ecocomDP data tables, conversion scripts, and where EML metadata will be written. This \code{path}, when defined on a web server, also serves as the publicly accessible URL from which the data objects can be downloaded.
#' @param core.name
#'     (character) The Darwin Core central table of the package. Can be: "occurence" (occurrence core) or "event" (event core).
#' @param parent.package.id
#'     (character) ID of an ecocomDP data package. Only EDI Data Repository package IDs are currently supported.
#' @param child.package.id
#'     (character) ID of DWcA occurrence data package being created.
#' @param user.id
#'     (character; optional) Repository user identifier. If more than one, then enter as a vector of character strings (e.g. \code{c("user_id_1", "user_id_2")}). \code{user.id} sets the /eml/access/principal element for all \code{user.domain} except "KNB", "ADC", and if \code{user.domain = NULL}.
#' @param user.domain
#'     (character; optional) Repository domain associated with \code{user.id}. Currently supported values are "EDI" (Environmental Data Initiative), "LTER" (Long-Term Ecological Research Network), "KNB" (The Knowledge Network for Biocomplexity), "ADC" (The Arctic Data Center). If you'd like your system supported please contact maintainers of the EMLassemblyline R package. If using more than one \code{user.domain}, then enter as a vector of character strings (e.g. \code{c("user_domain_1", "user_domain_2")}) in the same order as corresponding \code{user.id}. If \code{user.domain} is missing then a default value "unknown" is assigned. \code{user.domain} sets the EML header "system" attribute and for all \code{user.domain}, except "KNB" and "ADC", sets the /eml/access/principal element attributes and values.
#' @param url
#'     (character) URL to the publicly accessible directory containing DwC-A tables and meta.xml. This argument supports direct download of the data entities by a data repository and is used within the scope of the ecocomDP project for automated revision and upload of ecocomDP data packages and derived products.
#'
#' @return 
#'     An EML metadata record for the DWcA table defined by \code{data.table}.
#'
#' @details 
#'     This function creates an EML record for an Darwin Core Archive record
#'     (DwC-A) combining metadata from the parent data package and
#'     boiler-plate metadata describing the DwC-A tables. Changes to the 
#'     parent EML include:
#'     \itemize{
#'         \item \strong{<access>} Adds the \code{user.id} to the list of 
#'         principals granted read and write access to the DwC-A data 
#'         package this EML describes.
#'         \item \strong{<title>} Appends "Darwin Core Archive: " to the title.
#'         \item \strong{<pubDate>} Adds the date when this EML record is 
#'         created.
#'         \item \strong{<abstract>} Adds a note that this is a derived data 
#'         package in a DwC-A format.
#'         \item \strong{<keywordSet>} Essential Biodiversity Variables: 
#'         "Population Abundance" and Darwin Core Terms: 
#'         "BasisofRecord: HumanObservation", "Occurrence: OrganismQuantity",
#'         "Taxon: ScientificName".
#'         \item \strong{<intellectualRights>} Keeps intact the intellectual
#'         rights license of the parent data package, or replaces it with
#'         "CCO" (https://creativecommons.org/publicdomain/zero/1.0/legalcode).
#'         \item \strong{<methodStep>} Adds a note that this data package was
#'         created by methods within the ecocomDP R package and adds provenance 
#'         metadata noting that this is a derived data and describing where 
#'         the parent data package can be accessed.
#'         \item \strong{<dataTables>} Replaces the parent data package data
#'         tables metadata with boiler-plate metadata for the DwC-A tables.
#'         \item \strong{<otherEntity>} Describes the meta.xml accompanying 
#'         each DwC-A. Any other entities listed in the parent EML are removed.
#'     }
#'
#' @export
#' 
#' @examples 
#' \dontrun{
#' 
#' }
#'
make_eml_dwca <- function(path, 
                          core.name, 
                          parent.package.id, 
                          child.package.id, 
                          user.id, 
                          user.domain,
                          url = NULL) {
  
  message(
    "Creating Darwin Core ", stringr::str_to_title(core.name), " Core EML ",
    "for L1 data package ", parent.package.id)
  
  # Validate inputs -----------------------------------------------------------
  
  # The parent data package should exist
  missing_parent_data_package <- suppressWarnings(
    stringr::str_detect(
      suppressMessages(
        EDIutils::api_read_metadata(parent.package.id)), 
      "Unable to access metadata for packageId:"))
  if (missing_parent_data_package) {
    stop(
      "The L1 data package '", parent.package.id, "' does not exist.",
      call. = FALSE)
  }
  
  # The child data package should not exist since it's being created here, but
  # could in a non-production environment
  child_data_package_exists <- suppressWarnings(
    !stringr::str_detect(
      suppressMessages(
        EDIutils::api_read_metadata(child.package.id)), 
      "Unable to access metadata for packageId:"))
  if (child_data_package_exists) {
    warning(
      "The L0 data package '", child.package.id, "' already exists.",
      call. = FALSE)
  }
  
  # A "user.id" is required for each "user.domain"
  if (length(user.id) != length(user.domain)) {
    stop(
      "The number of items listed under the 'user.id' and 'user.domain' ",
      "arguments must match.", call. = FALSE)
  }
  
  # TODO: Check "url"
  
  # Parameterize --------------------------------------------------------------
  
  # Table names, types, and descriptions are standardized for the input 
  # "core.name"
  if (core.name == "event") {
    data.table <- c(
      "event.csv", 
      "occurrence.csv",
      "extendedmeasurementorfact.csv")
    data.table.description <- c(
      "DwC-A Event Table", 
      "DwC-A Occurrence Table",
      "DwC-A Extended Measurement Or Fact Table")
  } else if (core.name == "occurrence") {
    data.table <- "occurrence.csv"
    data.table.description <- "DwC-A Occurrence Table"
  }
  
  # Other entity name, type, and description is standardized for the input 
  # "core.name"
  other.entity <- "meta.xml"
  other.entity.description <- "The meta file associated with this dataset"
  
  # Error if the expected standards required by this function are not followed
  missing_data_objects <- c(
    !(data.table %in% dir(path)),
    !("meta.xml" %in% dir(path)))
  if (any(missing_data_objects)) {
    stop(
      "Missing data objects: ",
      paste(c(data.table, "meta.xml")[missing_data_objects], collapse = ","),
      call. = FALSE)
  }
  
  # Expand url for each data object of this L1 for use in 
  # EMLassemblyline: make_eml()
  
  if (!is.null(url)) {
    data.table.url <- paste0(url, "/", data.table)
    other.entity.url <- paste0(url, "/", other.entity)
  }
  
  # Read L1 EML ---------------------------------------------------------------
  
  message("Reading EML of L1 data package ", parent.package.id)
  
  # Create two objects of the same metadata, eml_L1 (emld list object) for
  # editing, and xml_L1 (xml_document) for easy parsing
  url_parent <- paste0(
    "https://pasta.lternet.edu/package/metadata/eml/", 
    stringr::str_replace_all(parent.package.id, "\\.", "/"))
  eml_L1 <- EML::read_eml(url_parent)
  xml_L1 <- suppressMessages(
    EDIutils::api_read_metadata(parent.package.id))
  
  # Read L0 EML ---------------------------------------------------------------
  
  # Some metadata from the L0 is required by the L2 and simpler to get from the
  # L0 than parsing from the L1
  url_grandparent <- xml2::xml_text(
    xml2::xml_find_all(
      xml_L1,
      ".//methodStep/dataSource/distribution/online/url"))
  grandparent.package.id <- stringr::str_replace_all(
    stringr::str_extract(
      url_grandparent,
      "(?<=eml/).*"),
    "/",
    ".")
  
  # Create two objects of the same metadata, eml_L0 (emld list object) for
  # editing, and xml_L0 (xml_document) for easy parsing
  message("Reading EML of L0 data package ", grandparent.package.id)
  xml_L0 <- suppressMessages(
    EDIutils::api_read_metadata(grandparent.package.id))
  eml_L0 <- suppressMessages(
    EML::read_eml(url_grandparent))

  # Create L2 EML -------------------------------------------------------------
  # This is not a full EML record, it is only the sections of EML that will be 
  # added to the parent EML.
  
  message("Creating EML of L2 data package ", child.package.id)
  
  # Create list of inputs to EMLassemblyline::make_eml()
  eal_inputs <- EMLassemblyline::template_arguments(
    path = system.file("/dwca_event_core", package = "ecocomDP"), 
    data.path = path, 
    data.table = data.table,
    other.entity = "meta.xml")
  eal_inputs$path <- system.file("/dwca_event_core", package = "ecocomDP")
  eal_inputs$data.path <- path
  eal_inputs$eml.path <- path
  eal_inputs$dataset.title <- "placeholder"
  eal_inputs$data.table <- data.table
  eal_inputs$data.table.description <- data.table.description
  eal_inputs$data.table.url <- data.table.url
  eal_inputs$data.table.quote.character <- rep('"', length(data.table))
  eal_inputs$other.entity <- other.entity
  eal_inputs$other.entity.description <- other.entity.description
  eal_inputs$other.entity.url <- other.entity.url
  eal_inputs$provenance <- parent.package.id
  eal_inputs$package.id <- child.package.id
  eal_inputs$user.id <- user.id
  eal_inputs$user.domain <- user.domain
  eal_inputs$return.obj <- TRUE
  
  # Get date and time format string from the L1 EML and add to the event table 
  # attributes template (attributes_event.txt) of the L2 since this 
  # information can vary with the L1.
  data_table_nodes_parent <- xml2::xml_find_all(
    xml_L1,
    ".//dataTable")
  observation_table_node_parent <- data_table_nodes_parent[
    stringr::str_detect(
      xml2::xml_text(
        xml2::xml_find_all(
          xml_L1, 
          ".//physical/objectName")), 
      "observation\\..*$")]
  format_string <- xml2::xml_text(
    xml2::xml_find_all(
      observation_table_node_parent, 
      ".//formatString"))
  use_i <- eal_inputs$x$template$attributes_event.txt$content$attributeName == 
    "eventDate"
  eal_inputs$x$template$attributes_event.txt$content$dateTimeFormatString[
    use_i] <- format_string
  
  # All annotations in the annotations template used by 
  # EMLassemblyline::template_arguments() are used here since the DwC-A format
  # is constant (i.e. the table attributes don't change). Some annotations
  # in this template may not yet have definition, so incomplete cases will be
  # dropped.
  
  eal_inputs$x$template$annotations.txt$content[
    eal_inputs$x$template$annotations.txt$content == ""] <- NA_character_
  
  eal_inputs$x$template$annotations.txt$content <- 
    eal_inputs$x$template$annotations.txt$content[
      complete.cases(eal_inputs$x$template$annotations.txt$content), ]
  
  # Create child EML
  eml_L2 <- suppressWarnings(
    suppressMessages(
      do.call(
        EMLassemblyline::make_eml, 
        eal_inputs[
          names(eal_inputs) %in% names(formals(EMLassemblyline::make_eml))])))

  # Update <eml> --------------------------------------------------------------
  
  message("Updating:")
  message("<eml>")
  eml_L1$schemaLocation <- paste0(
    "https://eml.ecoinformatics.org/eml-2.2.0  ",
    "https://nis.lternet.edu/schemas/EML/eml-2.2.0/xsd/eml.xsd")
  eml_L1$packageId <- child.package.id
  eml_L1$system <- "edi"
  
  # Update <access> of parent -------------------------------------------------
  
  message("  <access>")
  
  # Access control rules are used by some repositories to manage 
  # editing, viewing, downloading permissions. Adding the user.id and 
  # user.domain here expands editing permission to the creator of the DwC-A 
  # data package this EML will be apart of.
  eml_L1$access$allow <- unique(
    c(eml_L1$access$allow, 
      eml_L2$access$allow))
  
  # Update <dataset> ----------------------------------------------------------
  
  # For purposes of annotation references, the <dataset> attribute (which may
  # have been set by the L1 creator) needs to be set to "dataset", which is 
  # expected by the L2 dataset annotation.
  
  eml_L1$dataset$id <- "dataset"
  
  # Update <alternateIdentifier> ----------------------------------------------
  
  message("  <dataset>")
  message("    <alternateIdentifier>")
  
  # Some repositories assign a DOI to this element. Not removing it here 
  # an error when uploading to the repository.
  
  eml_L1$dataset$alternateIdentifier <- NULL
  
  # Update <title> ------------------------------------------------------------
  
  message("    <title>")
  
  # Add notification to indicate this is a Darwin Core Archive
  eml_L1$dataset$title <- paste(
    eml_L0$dataset$title, "(Reformatted to a Darwin Core Archive)")
  
  # Update <pubDate> ----------------------------------------------------------
  
  message("    <pubDate>")
  eml_L1$dataset$pubDate <- format(Sys.time(), "%Y-%m-%d")
  
  # Update <abstract> ---------------------------------------------------------
  
  message("    <abstract>")
  
  # Add links to L0 and L1 data packages
  eml_L2$dataset$abstract$para[[1]] <- stringr::str_replace(
    eml_L2$dataset$abstract$para[[1]], 
    "L0_PACKAGE_URL", 
    url_grandparent)
  eml_L2$dataset$abstract$para[[1]] <- stringr::str_replace(
    eml_L2$dataset$abstract$para[[1]], 
    "L1_PACKAGE_URL", 
    url_parent)
  
  # Parse para from xml object because emld parsing is irregular
  L2_para <- eml_L2$dataset$abstract$para[[1]]
  L0_para <- xml2::xml_text(
    xml2::xml_find_all(xml_L0, ".//abstract//para"))
  eml_L1$dataset$abstract <- NULL
  
  # Create L2 abstract
  eml_L1$dataset$abstract$para <- c(
    list(L2_para),
    list(L0_para))

  # Update <keywordSet> -------------------------------------------------------
  
  message("    <keywordSet>")
  
  # Preserve the L0 keywords, all L1 keywords except "ecocomDP" (since this is 
  # no longer an ecocomDP data package), and add L2 keywords.
  
  keywords_L1_to_keep <- lapply(
    eml_L1$dataset$keywordSet, 
    function(x) {
      if (!("EDI Controlled Vocabulary" %in% x$keywordThesaurus)) {
        x
      }
    })
  
  eml_L1$dataset$keywordSet <- c(
    eml_L2$dataset$keywordSet, 
    keywords_L1_to_keep)
  
  # TODO: Add measurement variable in a standardized and human readable way.
  
  # TODO: Add GBIF terms at /eml/dataset (first) and /eml/dataset/dataTable (second)
  
  # Update <intellectualRights> -----------------------------------------------
  
  # Use parent intellectual rights or CC0 if none exists
  if (is.null(eml_L1$dataset$intellectualRights)) {
    message("    <intellectualRights>")
    eml_L1$dataset$intellectualRights <- eml_L2$dataset$intellectualRights
  }
  
  # Update <methods> ----------------------------------------------------------
  
  message("    <methods>")
  
  # Parse components to be reordered and recombined. Parse para from xml 
  # object because emld parsing is irregular
  methods_L2 <- eml_L2$dataset$methods$methodStep[[1]]
  eml_L2$dataset$methods$methodStep[[1]] <- NULL
  provenance_L1 <- eml_L2$dataset$methods$methodStep
  L0_para <- xml2::xml_text(
    xml2::xml_find_all(xml_L0, ".//methods//para"))
  eml_L1$dataset$methods <- NULL
  
  # Combine L2 methods, L0 methods, and L1 provenance
  eml_L1$dataset$methods$methodStep <- c(
    list(methods_L2),
    list(list(description = list(para = L0_para))), # should be a methodStep - $description$para
    list(provenance_L1))
  
  # Update <dataTable> --------------------------------------------------------
  
  message("    <dataTable>")
  eml_L1$dataset$dataTable <- eml_L2$dataset$dataTable

  # Add <otherEntity> ---------------------------------------------------------
  
  message("    <otherEntity>")
  eml_L1$dataset$otherEntity <- eml_L2$dataset$otherEntity
  
  # Update <annotations> ------------------------------------------------------
  
  message("    <annotations>")
  eml_L1$annotations <- eml_L2$annotations
  
  # Write EML -----------------------------------------------------------------
  
  message("</eml>")
  message("Writing EML")
  
  emld::eml_version("eml-2.2.0")
  EML::write_eml(
    eml_L1, 
    paste0(path, "/", child.package.id, ".xml"))
  
  # Validate EML --------------------------------------------------------------
  
  message("Validating EML")
  
  r <- EML::eml_validate(eml_L1)
  if (isTRUE(r)) {
    message("  Validation passed :)")
  } else {
    message("  Validation failed :(")
  }
  message("Done.")
  
  # Return --------------------------------------------------------------------
  
  return(eml_L1)
  
}