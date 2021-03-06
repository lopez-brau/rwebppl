# Determine the shell/scripts to use based on user OS
system_os <- function() Sys.info()["sysname"]

# Path to rwebppl R package
rwebppl_path <- function() system.file(package = "rwebppl")

# Path to local webppl install
webppl_install = function() file.path(rwebppl_path(), 'js', 'webppl')
webppl_executable = function() file.path(webppl_install(), 'webppl')

# Path to where webppl looks for webppl npm packages
global_pkg_path <- function() path.expand("~/.webppl")

# Internal function that checks whether a file exists
file_exists <- function(path) {
  if (system_os() == "Windows") {
    args <- c(path)
    existsFlag <- suppressWarnings(
      system(paste("powershell -ExecutionPolicy ByPass -Command Test-Path",
                   paste("\"'", args, "'\"", sep="")), intern = T))
    existsFlag <- ifelse(existsFlag == "True", 1, 0)
    return(existsFlag == 1)
  }
  else {
    args <- c("!", "-e", path, ";", "echo", "$?")
    existsFlag <- suppressWarnings(system2("test", args = args, stdout = T))
    return(existsFlag == 1)  
  }
}

# Internal function that cleans the local webppl install
clean_webppl <- function() {
  message("cleaning old version... ", appendLF = FALSE)
  if (system_os() == "Windows") {
    system(paste("powershell -ExecutionPolicy ByPass -Command rm -r", webppl_install()))
  }
  else {
    system2("rm", args = c('-r', webppl_install()))  
  }
}

#' Installs webppl locally
#'
#' Supports both official npm release versions (e.g. '0.9.6') and
#' also commit hashes from the github repository for custom configurations
#' @param webppl_version official npm tag or commit hash
#' @return NULL
#' @export
#'
#' @examples
#' \dontrun{install_webppl('0.9.6')}
#' \dontrun{install_webppl('4bd2452333d24c122aee98c3206584bc39c6096a')}
install_webppl <- function(webppl_version) {
  # First, clean up any webppl version that might already exist
  if(file_exists(webppl_executable())) {
    clean_webppl()
  }
  message("installing webppl ...", appendLF = FALSE)
  if (system_os() == "Windows") {
    npm_info <- system("npm info webppl versions --json", intern = TRUE)
  }
  else { 
    npm_info <- system2("npm", args = c("info", "webppl", "versions", "--json"),
                        stdout = TRUE)
  }
  npm_versions <- jsonlite::fromJSON(paste(npm_info, collapse = ""))
  if (webppl_version %in% npm_versions) {
    rwebppl_json <- file.path(rwebppl_path(), "json", "rwebppl.json")
    rwebppl_meta <- jsonlite::fromJSON(readLines(rwebppl_json))
    rwebppl_meta$dependencies$webppl <- webppl_version
    webppl_json <- file.path(rwebppl_path(), "js", "package.json")
    writeLines(jsonlite::toJSON(rwebppl_meta, auto_unbox = TRUE, pretty = TRUE),
               webppl_json)
    if (system_os() == "Windows") {
      system(paste("powershell -ExecutionPolicy ByPass -File", 
                   paste("\"", file.path(rwebppl_path(), "powershell", "install-webppl.ps1"), "\"", sep=""), 
                   paste("\"", rwebppl_path(), "\"", sep="")))
      system(paste("powershell -ExecutionPolicy ByPass -File", 
                   paste("\"", file.path(rwebppl_path(), "powershell", "rearrange-webppl.ps1"), "\"", sep=""), 
                   paste("\"", rwebppl_path(), "\"", sep="")))
    }
    else {
      system2(file.path(rwebppl_path(), "bash", "install-webppl.sh"),
              args = rwebppl_path())
      system2(file.path(rwebppl_path(), "bash", "rearrange-webppl.sh"),
              args = rwebppl_path())
    }
    
  } else {
    # This doesn't work for Windows yet
    if (system_os() == "Windows") {
      system(paste("powershell -ExecutionPolicy ByPass -File", 
                   paste("\"", file.path(rwebppl_path(), "powershell", "install-dev-webppl.ps1"), "\"", sep=""), 
                   paste("\"", rwebppl_path(), "\"", sep=""), webppl_version))
    }
    else {
      system2(file.path(rwebppl_path(), "bash", "install-dev-webppl.sh"),
              args = c(rwebppl_path(), webppl_version))
    }
    
  }
  message(" done")
}

# Internal function to ensure the user already has webppl installed on load
# Installs default version in DESCRIPTION if it doesn't already exist
check_webppl <- function() {
  if (!file_exists(webppl_executable())) {
    webppl_version <- utils::packageDescription("rwebppl", fields = "WebPPLVersion")
    install_webppl(webppl_version)
  }
}

#' Prints out version of webppl
#'
#' @return NULL
#' @export
#'
#' @examples
#' \dontrun{get_webppl_version()}
get_webppl_version <- function() {
  if (file_exists(webppl_executable())) {
    if (system_os() == "Windows") {
      version_str <- system(paste("node", paste("\"", webppl_executable(), "\"", sep=""), "--version"), intern = T) 
    }
    else {
      version_str <- system2(webppl_executable(), args = c("--version"), stdout = T)  
    }
    message(paste("using webppl version:", version_str))
  } 
  else {
    warning("couldn't find local webppl install")
  }
}

.onLoad <- function(libname, pkgname) {
  check_webppl()
  get_webppl_version()
}

#' Install webppl package
#'
#' Install an npm package to webppl's global installation.
#'
#' @param package_name Name of package to be installed
#' @param path Path to package install location (defaults to webppl's global
#'   package directory)
#' @return NULL
#' @export
#'
#' @examples
#' \dontrun{install_webppl_package("babyparse")}
install_webppl_package <- function(package_name, path = global_pkg_path()) {
  if (system_os() == "Windows") {
    system(paste("powershell -ExecutionPolicy ByPass -File", 
                 paste("\"", file.path(rwebppl_path(), "powershell", "install-package.ps1"), "\"", sep=""), 
                 paste("\"", path, "\"", sep=""), package_name, 
                 paste("\"", rwebppl_path(), "\"", sep="")))
  }
  else {
    system2(file.path(rwebppl_path(), "bash", "install_package.sh"),
            args = c(path, package_name, rwebppl_path()))
  }
}

#' Uninstall webppl package
#'
#' Uninstall an npm package from webppl's global installation.
#'
#' @inheritParams install_webppl_package
#' @return NULL
#' @export
#'
#' @examples
#' \dontrun{uninstall_webppl_package("babyparse")}
uninstall_webppl_package <- function(package_name, path = global_pkg_path()) {
  if (system_os == "Windows") {
    system(paste("powershell -ExecutionPolicy ByPass -File", 
                 paste("\"", file.path(rwebppl_path(), "powershell", "uninstall-package.ps1"), "\"", sep=""), 
                 paste("\"", path, "\"", sep=""), package_name))
  }
  else {
    system2(file.path(rwebppl_path(), "bash", "uninstall_package.sh"),
            args = c(path, package_name))
  }
  
}

#' Get samples
#'
#' Turn webppl "histogram" output into samples.
#'
#' @param df A data frame of webppl "histogram" output (has a column called
#'   `prob` with probabilities, remaining columns are parameter values).
#' @param num_samples A number of samples to reconstruct.
#' @return Data frame of parameter values with number of rows equal to
#'   `num_samples`.
#' @export
#'
#' @examples
#' num_samples <- 10
#' df <- data.frame(prob = c(0.1, 0.3, 0.5, 0.1), support = c("a","b","c","d"))
#' get_samples(df, num_samples)
get_samples <- function(df, num_samples) {
  rows <- rep.int(seq_len(nrow(df)), times = round(df$prob * num_samples))
  cols <- names(df) != "prob"
  df[rows, cols, drop = FALSE]
}

is_mcmc <- function(output) {
  ((names(output)[1] == "score") &
     all(grepl("value", names(output)[2:length(names(output))])))
}

is_rejection <- function(output) {
  all(grepl("value", names(output)))
}

is_sampleList <- function(output) {
  is_mcmc(output) || is_rejection(output)
}

is_probTable <- function(output){
  all(names(output) %in% c("probs", "support"))
}

isOptimizeParams <- function(output){
  (all(c("dims", "length") %in% names(output[[1]])) &&
     all(c("dims", "length") %in% names(output[[length(output)]])))
}

# Try to use inference_opts to determine # samples; otherwise use size of list
countSamples <- function(output, inference_opts) {
  if(!(is.null(inference_opts[["samples"]]))) {
    return(inference_opts[["samples"]])
  } else if (!(is.null(inference_opts[["particles"]]))) {
    return(inference_opts[["particles"]])
  } else {
    return(nrow(output))
  }
}

tidy_probTable <- function(output) {
  if (class(output$support) == "data.frame") {
    support <- output$support
  } else {
    support <- data.frame(support = output$support)
  }
  return(cbind(support, data.frame(prob = output$probs)))
}

tidy_sampleList <- function(output, chains, chain, inference_opts) {
  names(output) <- gsub("value.", "", names(output))
  num_samples <- countSamples(output, inference_opts)
  # as of webppl v0.9.6, samples come out in the order they were collected
  output$Iteration <- 1:num_samples
  ggmcmc_samples <- tidyr::gather_(
    output, key_col = "Parameter", value_col = "value",
    gather_cols = names(output)[names(output) != "Iteration"],
    factor_key = TRUE
  )
  ggmcmc_samples$Chain <- chain
  ggmcmc_samples <- ggmcmc_samples[,c("Iteration", "Chain", "Parameter", "value")] # reorder columns
  attr(ggmcmc_samples, "nChains") <- chains
  attr(ggmcmc_samples, "nParameters") <- ncol(output) - 1
  attr(ggmcmc_samples, "nIterations") <- num_samples
  attr(ggmcmc_samples, "nBurnin") <- ifelse(is.null(inference_opts[["burn"]]), 0, inference_opts[["burn"]])
  attr(ggmcmc_samples, "nThin") <- ifelse(is.null(inference_opts[["thin"]]), 1, inference_opts[["thin"]])
  attr(ggmcmc_samples, "description") <- ifelse(is.null(inference_opts[["method"]]), "", inference_opts[["method"]])
  return(ggmcmc_samples)
}

tidy_output <- function(output, chains = NULL, chain = NULL, inference_opts = NULL) {
  if (is_probTable(output)) {
    return(tidy_probTable(output))
  } else if (is_sampleList(output)) {
    # Drop redundant score column, if it exists
    if ("score" %in% names(output)) {
      output <- output[, names(output) != 'score', drop = F]
    }
    return(tidy_sampleList(output, chains, chain, inference_opts))
  } else {
    return(output)
  }
}

#' webppl
#'
#' Runs a webppl program.
#'
#' @param program_code A string of a webppl program.
#' @param program_file A file containing a webppl program.
#' @param data A data frame (or other serializable object) that can be
#'   referenced in the program.
#' @param data_var A name by which data can be referenced in the program.
#' @param packages A character vector of external package names to use.
#' @param model_var The name by which the model be referenced in the program.
#' @param inference_opts Options for inference
#' (see http://webppl.readthedocs.io/en/master/inference.html)
#' @param chains Number of chains (this run is one chain).
#' @param chain Chain number of this run.
run_webppl <- function(program_code = NULL, program_file = NULL, data = NULL,
                       data_var = NULL, packages = NULL, model_var = NULL,
                       inference_opts = NULL, chains = NULL,
                       chain = 1) {

  # Get OS
  system_os <- Sys.info()["sysname"]
  
  # Find location of rwebppl JS script, within rwebppl R package
  script_path <- file.path(rwebppl_path(), "js/rwebppl")

  # If data supplied, create a webppl package that exports the data as data_var
  if (!is.null(data)) {
    if (is.null(data_var)) {
      warning("ignoring data (supplied without data_var)")
    } 
    else {
      tmp_dir <- tempdir()
      dir.create(file.path(tmp_dir, data_var), showWarnings = FALSE)
      cat(sprintf('{"name":"%s","main":"index.js"}', data_var),
          file = file.path(tmp_dir, data_var, "package.json"))
      data_string <- jsonlite::toJSON(data, digits = NA)
      cat(sprintf("module.exports = JSON.parse('%s')", data_string),
          file = file.path(tmp_dir, data_var, "index.js"))
      packages <- c(packages, file.path(tmp_dir, data_var))
    }
  }

  # Set modified_program_code to program_code or to contents of program_file
  if (!is.null(program_code)) {
    if (!is.null(program_file)) {
      warning("both program_code and program_file supplied, using program_code")
    }
    modified_program_code <- program_code
  } 
  else if (!is.null(program_file)) {
    if (!file.exists(program_file)) {
      stop("program_file does not exist")
    }
    modified_program_code <- paste(readLines(program_file, warn = FALSE),
                                   collapse = "\n")
  }
  else {
    stop("supply one of program_code or program_file")
  }

  # If inference_opts and model_var supplied, add an Infer call to the program
  if (!is.null(inference_opts)) {
    if (is.null(model_var)) {
      stop("when supplying inference_opts, you must also supply model_var")
    }
    infer <- sprintf("Infer(JSON.parse('%s'), %s)",
                     jsonlite::toJSON(inference_opts, auto_unbox = TRUE),
                     model_var)
    modified_program_code <- paste(modified_program_code, infer, sep = "\n")
  }

  # Create tmp files for program code, program output, and finish signal
  uid <- uuid::UUIDgenerate()
  if (system_os == "Windows") {
    program_file <- paste("", tempdir(), sprintf("\\webppl_program_%s", uid), "", sep="")
    output_file <- paste("", tempdir(), sprintf("\\webppl_output_%s", uid), "", sep="")
    finish_file <- paste("", tempdir(), sprintf("\\webppl_finished_%s", uid), "", sep="")
  }
  else {
    program_file <- sprintf("/tmp/webppl_program_%s", uid)
    output_file <- sprintf("/tmp/webppl_output_%s", uid)
    finish_file <- sprintf("/tmp/webppl_finished_%s", uid)
  }
  
  # Create args to pass to rwebppl js, including packages
  program_arg <- sprintf("--programFile %s", program_file)
  output_arg <- sprintf("--outputFile %s", output_file)
  finish_arg <- sprintf("--finishFile %s", finish_file)
  if (!is.null(packages)) {
    package_args <- unlist(lapply(packages,
                                  function(x){ return( paste('--require', x) ) }))
  }
  else {
    package_args <- ""
  }

  # Write modified_program_code to temporary program_file
  cat(modified_program_code, file = program_file)

  # Run rwebppl JS script with model file and packages as arguments
  # Any output to stdout gets sent to the R console while command runs
  if (system_os == "Windows") {
    system(paste("node", paste("\"", script_path, "\"", sep=""), program_arg, output_arg, finish_arg, package_args), wait = F)
  }
  else {
    system2(script_path, args = c(program_arg, output_arg, finish_arg, package_args),
            stdout = "", stderr = "", wait = FALSE)
  }
  
  # Wait for finish file to exist
  while (!(file.exists(finish_file))) {
    Sys.sleep(0.25)
  }
  
  # If the command produced non-empty output, collect and tidy the results
  if (file.exists(output_file)) {
    output_string <- paste(readLines(output_file, warn = F),
                           collapse = "\n")
    if (output_string != "") {
      output <- jsonlite::fromJSON(output_string, flatten = TRUE)
      if (!is.null(names(output))) {
        return(tidy_output(output, chains = chains,
                           chain = chain, inference_opts = inference_opts))
      }
      else {
        return(output)
      }
    }
  }
}

# Declare i as a global variable to avoid NOTE from foreach using NSE
globalVariables("i")

#' webppl
#'
#' Runs a webppl program.
#'
#' @importFrom foreach "%dopar%"
#' @inheritParams run_webppl
#' @param chains Number of times to run the program (defaults to 1).
#' @param cores Number of cores to use when running multiple chains (defaults to
#'   1).
#'
#' @return The program's return value(s).
#' @export
#'
#' @examples
#' \dontrun{
#' program_code <- "flip(0.5)"
#' webppl(program_code)
#' }
webppl <- function(program_code = NULL, program_file = NULL, data = NULL,
                   data_var = NULL, packages = NULL, model_var = NULL,
                   inference_opts = NULL, chains = 1, cores = 1) {

  run_fun <- function(k) run_webppl(program_code = program_code,
                                    program_file = program_file,
                                    data = data,
                                    data_var = data_var,
                                    packages = packages,
                                    model_var = model_var,
                                    inference_opts = inference_opts,
                                    chains = chains,
                                    chain = k)
  if (chains == 1) {
    run_fun(1)
  } else {
    doParallel::registerDoParallel(cores = cores)
    chain_outputs <- foreach::foreach(i = 1:chains) %dopar% run_fun(i)
    Reduce(rbind, chain_outputs)
  }
}

#' Kill rwebppl processes
#'
#' @param pid (optional) Vector of process IDs to kill (defaults to killing all
#'   rwebppl processes)
#'
#' @export
#'
#' @examples
#' \dontrun{kill_webppl()}
#' \dontrun{kill_webppl(6939)}
kill_webppl <- function(pids = NULL) {
  if (is.null(pids)) {
    if (system_os() == "Windows")
    {
      pids <- system("powershell -ExecutionPolicy ByPass -Command Get-Process webppl_program | Select -Expand id")
    }
    else {
      pids <- system2("pgrep", args = c("-f", "webppl_program"), stdout = T)
    }
  }
  tools::pskill(pids)
}
