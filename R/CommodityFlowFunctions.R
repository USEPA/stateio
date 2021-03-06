#' Calculate domestic/import/export commodity flow ratios by state
#' @param state State name.
#' @param year A numeric value between 2012 and 2017 specifying the year of interest.
#' @param flow_ratio_type Type of commodity flow, can be "domestic", "export", or "import".
#' @param ioschema A numeric value of either 2012 or 2007 specifying the io schema year.
#' @param iolevel BEA sector level of detail, can be "Detail", "Summary", or "Sector".
#' @return A data frame contains commodity flow ratios by BEA.
calculateCommodityFlowRatios <- function (state, year, flow_ratio_type, ioschema, iolevel) {
  # Load pre-saved FAF4 commodity flow data
  FAF <- get(paste("FAF", year, sep = "_"), as.environment("package:stateior"))
  # Load state FIPS and determine fips code for the state of interest (SoI)
  FIPS_STATE <- readCSV(system.file("extdata", "StateFIPS.csv", package = "stateior"))
  fips <- FIPS_STATE[FIPS_STATE$State==state, "State_FIPS"]
  value_col <- paste0("value_", year)
  # Generate FAF_2r
  if (flow_ratio_type=="domestic") {
    FAF <- FAF[FAF$trade_type==1, c("dms_origst", "dms_destst", "sctg2",
                                    "dms_mode", value_col)]
    colnames(FAF) <- c("ORIG", "DEST", "SCTG", "MODE", "VALUE")
    FAF$ORIG <- ifelse(FAF$ORIG==fips, "SoI", "RoUS")
    FAF$DEST <- ifelse(FAF$DEST==fips, "SoI", "RoUS") 
    # Aggregate to 2 regions 
    FAF_2r <- stats::aggregate(VALUE ~ ORIG + DEST + SCTG + MODE, FAF, sum)
    # Calculate commodity flow amount in warehousing & storage sector
    FAF_2r_ws <- stats::aggregate(VALUE ~ ORIG + DEST, FAF, sum)
  } else if (flow_ratio_type=="export") {
    FAF <- FAF[FAF$trade_type==3, c("dms_origst", "sctg2", "fr_outmode", value_col)]
    colnames(FAF) <- c("ORIG", "SCTG", "MODE", "VALUE")
    FAF$ORIG <- ifelse(FAF$ORIG==fips, "SoI", "RoUS")
    FAF$DEST <- "RoW"
    # Aggregate to 2 regions 
    FAF_2r <- stats::aggregate(VALUE ~ ORIG + SCTG + MODE, FAF, sum)
    # Calculate commodity flow amount in warehousing & storage sector
    FAF_2r_ws <- stats::aggregate(VALUE ~ ORIG, FAF, sum)
  } else if (flow_ratio_type=="import") {
    FAF <- FAF[FAF$trade_type==2, c("dms_destst", "sctg2", "fr_inmode", value_col)]
    colnames(FAF) <- c("DEST", "SCTG", "MODE", "VALUE")
    FAF$ORIG <- "RoW"
    FAF$DEST <- ifelse(FAF$DEST==fips, "SoI", "RoUS")
    # Aggregate to 2 regions 
    FAF_2r <- stats::aggregate(VALUE ~ DEST + SCTG + MODE, FAF, sum)
    # Calculate commodity flow amount in warehousing & storage sector
    FAF_2r_ws <- stats::aggregate(VALUE ~ DEST, FAF, sum)
  }
  ## Calculate commodity flow amount in transportation sectors
  filename <- "Crosswalk_FAFTransportationModetoBEA.csv"
  FAF_mode <- readCSV(system.file("extdata", filename, package = "stateior"))
  bea <- paste("BEA", ioschema, iolevel, "Code", sep = "_")
  FAF_2r_transportation <- merge(unique(FAF_mode[, c(bea, "Code", "Mode")]),
                                 FAF_2r, by.x = "Code", by.y = "MODE")
  
  ## Calculate commodity flow ratio
  # Load SCTGtoBEA mapping table
  SCTGtoBEA <- readCSV(system.file("extdata", "Crosswalk_SCTGtoBEA.csv",
                                   package = "stateior"))
  SCTGtoBEA <- unique(SCTGtoBEA[, c("SCTG", bea)])
  FAF_2r <- merge(FAF_2r, SCTGtoBEA, by = "SCTG")
  if (iolevel=="Detail") {
    # Use previous code and approach
  } else if (iolevel=="Summary") {
    # Determine BEA sectors that need allocation
    allocation_sectors <- SCTGtoBEA[duplicated(SCTGtoBEA$SCTG) |
                                      duplicated(SCTGtoBEA$SCTG, fromLast = TRUE), ]
    # Use State Emp to allocate
    StateEmp <- getStateEmploymentbyBEASummary(year)
    # Merge StateEmp with allocation_sectors
    Emp <- merge(StateEmp, allocation_sectors, by = "BEA_2012_Summary_Code")
    # Merge FAF_2r and Emp
    FAF_2r <- merge(FAF_2r, Emp[Emp$State==state, ],
                    by = c("SCTG", "BEA_2012_Summary_Code"), all.x = TRUE)
    FAF_2r[is.na(FAF_2r$State), "State"] <- state
    FAF_2r[is.na(FAF_2r$Emp), "Emp"] <- 1
    for (sctg in unique(FAF_2r$SCTG)) {
      # Calculate allocation factor
      weight_vector <- FAF_2r[FAF_2r$SCTG==sctg, "Emp"]
      allocation_factor <- weight_vector/sum(weight_vector/4, na.rm = TRUE)
      # Allocate Value
      value <- FAF_2r[FAF_2r$SCTG==sctg, "VALUE"]*allocation_factor
      FAF_2r[FAF_2r$SCTG==sctg, "VALUE"] <- value
      # Aggregate by BEA and ORIG/DEST
      if (flow_ratio_type=="domestic") {
        FAF_2r <- stats::aggregate(VALUE ~ ORIG + DEST + BEA_2012_Summary_Code,
                                   FAF_2r, sum, na.rm = TRUE)
      } else if (flow_ratio_type=="export") {
        FAF_2r <- stats::aggregate(VALUE ~ ORIG + BEA_2012_Summary_Code,
                                   FAF_2r, sum, na.rm = TRUE)
      } else if (flow_ratio_type=="import") {
        FAF_2r <- stats::aggregate(VALUE ~ DEST + BEA_2012_Summary_Code,
                                   FAF_2r, sum, na.rm = TRUE)
      }
    }
    # Combine FAF_2r with FAF_2r_transportation and FAF_2r_ws
    common_cols <- c("BEA_2012_Summary_Code", "ORIG", "DEST", "VALUE")
    FAF_2r_ws[, "BEA_2012_Summary_Code"] <- "493"
    FAF_2r_transportation <- stats::aggregate(VALUE ~ ORIG + DEST + BEA_2012_Summary_Code,
                                              FAF_2r_transportation, sum, na.rm = TRUE)
    FAF_2r <- rbind(FAF_2r[, common_cols], FAF_2r_ws[, common_cols],
                    FAF_2r_transportation[, common_cols])
    
    # Calculate commodity flow ratio
    if (flow_ratio_type=="domestic") {
      totalflow <- stats::aggregate(VALUE ~ ORIG + BEA_2012_Summary_Code, FAF_2r, sum)
      FAF_2r <- merge(FAF_2r, totalflow, by = c("ORIG", "BEA_2012_Summary_Code"))
      FAF_2r$ratio <- FAF_2r$VALUE.x / FAF_2r$VALUE.y
      FAF_2r <- FAF_2r[, c("ORIG", "DEST", "BEA_2012_Summary_Code", "ratio")]
    } else {
      totalflow <- stats::aggregate(VALUE ~ BEA_2012_Summary_Code, FAF_2r, sum)
      FAF_2r <- merge(FAF_2r, totalflow, by = "BEA_2012_Summary_Code")
      FAF_2r$ratio <- FAF_2r$VALUE.x / FAF_2r$VALUE.y
      if (flow_ratio_type=="export") {
        FAF_2r <- FAF_2r[, c("ORIG", "BEA_2012_Summary_Code", "ratio")]
      } else if (flow_ratio_type=="import") {
        FAF_2r <- FAF_2r[, c("DEST", "BEA_2012_Summary_Code", "ratio")]
      }
    }
  } else if (iolevel=="Sector") {
    # To be completed
  }
  return(FAF_2r)
}

#' Calculate Census import/export commodity flow ratios by BEA for all available states.
#' @param year A numeric value between 2012 and 2017 specifying the year of interest.
#' @param flow_ratio_type Type of commodity flow, can be "export" or "import".
#' @param ioschema A numeric value of either 2012 or 2007 specifying the io schema year.
#' @param iolevel BEA sector level of detail, can be "Detail", "Summary", or "Sector".
#' @return A data frame contains international commodity flow ratios by BEA for all available states.
calculateCensusForeignCommodityFlowRatios <- function (year, flow_ratio_type, ioschema, iolevel) {
  # Load pre-saved state export/import data
  if (year<2013) {
    trade <- get(paste0("Census_USATrade",
                        Hmisc::capitalize(flow_ratio_type), "_", year),
                 as.environment("package:stateior"))
  } else {
    trade <- get(paste0("Census_State",
                        Hmisc::capitalize(flow_ratio_type), "_", year),
                 as.environment("package:stateior"))
  }
  # Map from NAICS to BEA
  bea_code <- paste("BEA", ioschema, iolevel, "Code", sep = "_")
  trade <- merge(unique(useeior::MasterCrosswalk2012[, c("NAICS_2012_Code", bea_code)]),
                 trade, by.x = "NAICS_2012_Code", by.y = "NAICS")
  # Adjust the import data using the following logic:
  # For each BEA code, find all possible corresponding 4-digit NAICS (dig = 4)
  # and create a subset, then determine:
  # If nrow of the subset is larger than 0, keep the subset;
  # Otherwise, go to the corresponding 3-digit NAICS (dig = dig - 1)
  # and repeat the previous steps.
  trade_BEA <- data.frame()
  for (state in unique(trade$State)) {
    for (bea in unique(trade[, bea_code])) {
      dig <- 4
      ind <- FALSE
      while(ind==FALSE & dig>1) {
        tmp <- trade[trade$State==state & trade[, bea_code]==bea &
                       nchar(trade$NAICS)==dig, ]
        if (nrow(tmp)>0) {
          tmp$NAICS_digit <- dig # mark the NAICS digit used for this USEEIO code
          ind <- TRUE
        } else {
          dig <- dig - 1
        }
      }
      # If state trade table does not include bea, set Value to 0
      if (dig==1) {
        tmp[1, 2:4] <- c(bea, state, year)
        tmp$Value <- 0
        tmp$NAICS_digit <- ""
      }
      trade_BEA <- rbind.data.frame(trade_BEA, tmp)
    }
  }
  # Aggregate by BEA and State
  trade_BEA <- stats::aggregate(trade_BEA$Value,
                                by = list(trade_BEA[, bea_code],
                                          trade_BEA$State), sum)
  colnames(trade_BEA) <- c(bea_code, "State", "StateValue")
  # Calculate US_trade_BEA
  US_trade_BEA <- stats::aggregate(trade_BEA$StateValue,
                                   by = list(trade_BEA[, bea_code]), sum)
  colnames(US_trade_BEA) <- c(bea_code, "USValue")
  # Merge trade_BEA and US_trade_BEA
  state_US_trade_BEA <- merge(trade_BEA, US_trade_BEA, by = bea_code)
  # Calculate trade ratio
  ratio <- state_US_trade_BEA$StateValue/state_US_trade_BEA$USValue
  state_US_trade_BEA$SoITradeRatio <- ratio
  state_US_trade_BEA[, c("StateValue", "USValue")] <- NULL
  return(state_US_trade_BEA)
}
