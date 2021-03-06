% Generated by roxygen2: do not edit by hand
% Please edit documentation in R/UtilityFunctions.R
\name{calculateRegionalPurchaseCoefficient}
\alias{calculateRegionalPurchaseCoefficient}
\title{Calculate regional purchase coefficient for specified state and year}
\usage{
calculateRegionalPurchaseCoefficient(SoI2SoIUse, RoUS2SoIUse, iolevel)
}
\arguments{
\item{state}{Name of desired state, like "Georgia".}

\item{year}{A numeric value between 2007 and 2017 specifying the year of interest.}
}
\value{
A data.frame contains by-commodity RPC and overall RPC
}
\description{
Calculate regional purchase coefficient for specified state and year
}
