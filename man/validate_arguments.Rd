% Generated by roxygen2: do not edit by hand
% Please edit documentation in R/validate_arguments.R
\name{validate_arguments}
\alias{validate_arguments}
\title{Validate arguments of ecocomDP functions}
\usage{
validate_arguments(fun.name, fun.args)
}
\arguments{
\item{fun.name}{(character) Name of function from which \code{validate_arguments()} is
called.}

\item{fun.args}{(named list) Arguments passed to calling function and formatted as 
\code{as.list(environment())}.}
}
\description{
Validate input arguments to ecocomDP functions.
}
\details{
Validation checks are function specific.
}
