# Contains functions to produce a clean/easy to process dataframe from the input and 
# output csv files.
# authors: Xavier Devroey, and Mozhan Soltani

require(dplyr)

# ------------------------------
# Functions definition
# ------------------------------

# Adds full name for applications
#
addApplicationName <- function(df){
  df$application_name[df$application == "lang"] <- "Commons-lang"
  df$application_name[df$application == "math"] <- "Commons-math"
  df$application_name[df$application == "mockito"] <- "Mockito"
  df$application_name[df$application == "time"] <- "Joda-Time"
  df$application_name[df$application == "chart"] <- "JFreechart"
  df$application_name[df$application == "closure"] <- "Closure comp."
  df$application_name[df$application == "xwiki"] <- "XWiki"
  df$application_name[df$application == "es"] <- "Elasticsearch"
  df$application_factor <- factor(df$application_name, levels = c("Commons-lang", "Commons-math", "Mockito", "Joda-Time", "JFreechart", "Closure comp.", "XWiki", "Elasticsearch"))
  return(df)
}


# Adds application kind
#
addApplicationKind <- function(df){
  df$application_kind[df$application == "lang"] <- "Defects4J"
  df$application_kind[df$application == "math"] <- "Defects4J"
  df$application_kind[df$application == "mockito"] <- "Defects4J"
  df$application_kind[df$application == "time"] <- "Defects4J"
  df$application_kind[df$application == "chart"] <- "Defects4J"
  df$application_kind[df$application == "closure"] <- "Defects4J"
  df$application_kind[df$application == "xwiki"] <- "XWiki"
  df$application_kind[df$application == "es"] <- "Elasticsearch"
  df$application_kind_factor <- factor(df$application_kind, levels = c("Defects4J", "XWiki", "Elasticsearch"))
  return(df)
}

# Adds accronyms for exceptions 
#
addExceptionShortName <- function(df){
  df$exception <- "Other"
  df$exception[df$exception_name == "java.lang.NullPointerException"] <- "NPE"
  df$exception[df$exception_name == "java.lang.IllegalArgumentException"] <- "IAE"
  df$exception[df$exception_name == "java.lang.ArrayIndexOutOfBoundsException"] <- "AIOOBE"
  df$exception[df$exception_name == "java.lang.ClassCastException"] <- "CCE"
  df$exception[df$exception_name == "java.lang.StringIndexOutOfBoundsException"] <- "SIOOBE"
  df$exception[df$exception_name == "java.lang.IllegalStateException"] <- "ISE"
  df$exception_factor <- factor(df$exception, levels = c("NPE", "IAE", "AIOOBE", "CCE", "SIOOBE", "ISE", "Other"))
  return(df)
}

# Produces an easy to process dataframe from the given benchmark description csv file.
# csvFile: a csv file describing the benchmark 
#
getCleanBenchmarkDf <- function(csvFile){
  df <- read.csv(csvFile, stringsAsFactors = FALSE)
  # Add name of the applications
  df$application <- tolower(df$application)
  df <- addApplicationName(df)
  df <- addApplicationKind(df)
  # Add short name for exceptions
  df <- addExceptionShortName(df)
  return(df)
}

getBenchmark <- function(){
  df <- getCleanBenchmarkDf('../csv/benchmark.csv') %>%
    filter(!(case == "LANG-27b" & frame_level == 2))
  return(df)
}


# Produces an easy to process dataframe from the given results csv file.
# csvFile: a csv file produced by the experimentation framework
#
getCleanResultsDf <- function(csvFile){
  df <- read.csv(csvFile, stringsAsFactors = FALSE)
  # Add name of the applications
  df <- addApplicationName(df)
  df <- addApplicationKind(df)
  # Add short name for exceptions
  df <- addExceptionShortName(df)
  # Set the global result of the execution
  df$result[is.na(df$fitness_function_value) | !is.numeric(df$fitness_function_value)] <- "aborted"
  df$result[is.numeric(df$fitness_function_value) & df$fitness_function_value > 3] <- "line not reached"
  df$result[is.numeric(df$fitness_function_value) & df$fitness_function_value == 3] <- "line reached"
  df$result[is.numeric(df$fitness_function_value) & df$fitness_function_value != 0 & df$fitness_function_value <= 1] <- "ex. thrown"
  df$result[is.numeric(df$fitness_function_value) & df$fitness_function_value == 0] <- "reproduced"
  # Set the order of exceptions
  df$result_factor <- factor(df$result, levels = c("aborted", "line not reached", "line reached", "ex. thrown", "reproduced"), ordered = TRUE)
  # Check if isKilled factor is present 
  if(!("iskilled" %in% colnames(df))){
    df$iskilled <- NA
  }
  return(df)
}

getResults <- function(){
  # Get results dataframe
  results <- getCleanResultsDf('../csv/results.csv') %>%
    filter(!(case == "LANG-27b" & frame_level == 2)) # That frame points to a JUnit class, it has been removed in JCrashPack
  return(results)
}

getMostFrequentResult <- function(){
  majority <- getResults() %>%
    group_by(application_name, application_factor, application_kind, application_kind_factor, case, exception, exception_factor, frame_level) %>%
    summarise(majority_result = names(which.max(table(result_factor))),
              majority_result_factor = factor(names(which.max(table(result_factor))), levels = c("aborted", "line not reached", "line reached", "ex. thrown", "reproduced")))
  df <- data.frame(majority)
  return(df)
}


STATUS_LEVELS = c("not reproduced", "reproduced")

getReproduceStatus <- function(results){
  df <- results %>%
    group_by(case, majority_result) %>%
    mutate(max_reproduced = ifelse(majority_result == 'reproduced', max(frame_level), 0)) %>%
    ungroup() %>%
    group_by(case) %>%
    mutate(max_reproduced = max(max_reproduced)) %>%
    ungroup() %>%
    distinct(application_name, application_factor, case, exception, exception_factor, max_reproduced)
  df <- data.frame(df) %>%
    group_by(case) %>%
    mutate(highest = max(max_reproduced)) %>%
    ungroup() %>%
    mutate(status = ifelse(max_reproduced > 0 & max_reproduced >= highest, STATUS_LEVELS[2], STATUS_LEVELS[1]))
  df <- data.frame(df)
  df$status_factor <- factor(df$status, levels = STATUS_LEVELS, ordered = TRUE)
  return(df)
}


