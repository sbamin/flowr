#' to_flowdet
#' @param x this is a wd
#' @param ... not used
#' @export
to_flowdet <- function(x, ...) {
	UseMethod("to_flowdet")
}


#' @rdname to_flowdet
#' @description
#' get a flow_details file from the directory structure. This has less information than the
#' one generated using a flow object. Lacks jobids etc...
#' @export
to_flowdet.rootdir <- function(x, ...){
	## --- get all the cmd files
	files_cmd <- list.files(x, pattern = "cmd", full.names = TRUE, recursive = TRUE)
	if(length(files_cmd) == 0)
		stop(error("no.shell"))
	files_cmd = grep("sh$", files_cmd, value = TRUE)
	## dirname, JOBNAME_cmd_JOBINDEX
	cmd_mat <- data.frame(do.call(rbind,
																strsplit(gsub(".*/(.*)/(.*)_cmd_([0-9]*).sh",
																							"\\1,\\2,\\3", files_cmd), split = ",")),
												file = files_cmd,
												stringsAsFactors = FALSE)
	colnames(cmd_mat) = c("jobname", "jobnm", "num", "file")
	cmd_mat$trigger = sprintf("%s/trigger/trigger_%s_%s.txt",
														 dirname(dirname(files_cmd)),
														 cmd_mat$jobname, cmd_mat$num)
	return(cmd_mat)
}

#' @rdname to_flowdet
#' @export
#' @details
#' if x is char. assumed a path, check if flow object exists in it and read it.
#' If there is no flow object, try using a simpler function
to_flowdet.character <- function(x, ...){
	x = read_fobj(x)
	if(is.character(x))
		return(to_flowdet.rootdir(x)) ## where x is a parent path
	to_flowdet(x) ## where x is a flow
}


#' @rdname to_flowdet
#' @export
to_flowdet.flow <- function(x, ...){
	fobj = x
	ret <- lapply(1:length(fobj@jobs), function(i){
		to_flowdet(fobj@jobs[[i]])
	})
	flow_details = do.call(rbind, ret)
	return(flow_details)
}

to_flowdet.job <- function(x){
	cmds = x@script
	triggers = x@trigger
	deps = x@dependency
	deps = sapply(deps, paste, collapse = ";")
	prev = x@previous_job ## works for single type jobs
	prev = paste(prev, collapse = ";")
	#ifelse(prev != "") prev = paste(prev, 1:length(fobj@jobs[[prev]]@id), sep = "_")
	job_no = 1:length(cmds)
	job_id = paste(x@jobname, job_no, sep = "_")

	## HPCC ids and exit codes
	ids = x@id ## jobid for submission
	if(length(ids) == 0)
		ids = NA
	exit_codes = x@exit_code
	exit_codes = ifelse(length(exit_codes) == 0, NA, exit_codes)

	job_det = data.frame(
		jobname = x@jobname,
		jobnm = x@name,
		job_no = job_no, job_sub_id = ids,
		job_id = job_id, prev = prev,
		dependency = ifelse(is.null(unlist(deps)), NA, unlist(deps)),
		status = x@status,
		exit_code = exit_codes,
		cmd = cmds,
		trigger = triggers, stringsAsFactors = FALSE)

	return(job_det)
}




summarize_flow_det <- function(x, out_format){
	## summarize
	nm <- tapply(x$jobnm, INDEX = x$jobname, unique)
	jobs_total <- tapply(x$jobname, INDEX = x$jobname, length)
	jobs_compl <- tapply(x$exit_code, INDEX = x$jobname,
											 function(z) sum(z > -1, na.rm = TRUE)) ## counts no. more than -1
	jobs_status <- tapply(x$exit_code, INDEX = x$jobname, function(z) sum(ifelse(z>0, 1, 0), na.rm = TRUE))
	jobs_started <- tapply(x$started, INDEX = x$jobname, function(z) sum(z))
	summ = data.frame(total = jobs_total, started = jobs_started,
										completed = jobs_compl, exit_status = jobs_status, stringsAsFactors = FALSE)
	status = sapply(1:nrow(summ), function(i){
		diff = summ$total[i] - summ$completed[i]
		if(diff == 0){
			return("completed")
		}else if(diff < "summ$total[i]"){
			return("processing")
		}else{
			return("waiting")
		}
	})
	summ$status = status
	tmp <- knitr::kable(summ, out_format, output = FALSE)
	print(tmp)
	summ = cbind(jobname = rownames(summ), jobnm = nm, summ)
	return(summ)
}