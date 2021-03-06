library(igraph)
library(reshape2)
library(stringr)
library(RColorBrewer)


dep.data <- available.packages(contriburl = "http://cran.at.r-project.org/bin/windows/contrib/3.0")
dep.data[1:5, 1:5]


# Get a subset of variables of interest.
dep.data <- dep.data[, c("Package", "Depends", "Imports", "Suggests", "Enhances")]

# Some (most?) packages depends/import to multiple packages. Let's tease
# those packages apart.  This function will make a 'long' list of
# relationships for each package (where applicable). If there's no
# relationship, the output is 'none'.
make.data <- apply(dep.data, 1, FUN = function(x) {
	
	if (all(is.na(x[-1]))) 
		return(data.frame(from = x[1], to = x[1], relation = "none"))
	
	x2 <- na.omit(x[-1])
	x2 <- sapply(x2, strsplit, ",")
	
	out <- data.frame(from = rep(x[1], length(unlist(x2))), to = unlist(x2), 
		relation = rep(names(x2), times = sapply(x2, length)))
	rownames(out) <- 1:nrow(out)
	out
})
done.data <- do.call("rbind", make.data)
rownames(done.data) <- 1:nrow(done.data)

# We clean the data.
clean.data <- done.data  # make a copy
# remove version numbers
clean.data$to <- sub("\\((.*?)\\)", "", x = clean.data$to, perl = TRUE)
# remove newlines
clean.data$to <- sub("\\\n", "", x = clean.data$to, perl = TRUE)
# remove dependency on R (*)
clean.data[clean.data$to == "R" | clean.data$to == "R ", "to"] <- as.character(clean.data[clean.data$to == 
		"R" | clean.data$to == "R ", "from"])
# clean whitespace
clean.data$to <- as.factor(str_trim(clean.data$to, "both"))
# remove loops
clean.data <- clean.data[!apply(clean.data[, c("from", "to")], 1, function(x) x[1] == 
		x[2]), ]






#' Draws a subset of a data.frame as a network graph.
#' @param x data.frame. Has at least three columns, from, to and relation.
#' @param relation Character vector of length one. Rows with what relation from column relation (see x) should be used?
#' @param pkg Character. Package name to be subsetted.
#' @param ... Arguments passed to plot function that plots igraph object.
#' @return \code{igraph} object with the possible side effect of plotting the object.

plotGraph <- function(x, relation = NULL, pkg.to = NULL, pkg.from = NULL, plot = TRUE, 
	...) {
		
		# prepare the data to be plotted
		if (!is.null(relation)) {
			gd <- droplevels(x[x$relation %in% relation, ])
		} else {
			gd <- x
		}
		if (!is.null(pkg.to)) 
			gd <- gd[gd$to %in% pkg.to, ]
		if (!is.null(pkg.from)) 
			gd <- gd[gd$from %in% pkg.from, ]
		
		# make the data an igraph object and plot it (if specified)
		g <- graph.data.frame(gd, directed = TRUE)
		
		cc <- E(g)$relation
		if (any(unique(cc) == "Imports")) 
			cc[cc == "Imports"] <- "#E41A1C"
		if (any(unique(cc) == "Suggests")) 
			cc[which(cc == "Suggests")] <- "#984EA3"
		if (any(unique(cc) == "Enhances")) 
			cc[which(cc == "Enhances")] <- "#4DAF4A"
		if (any(unique(cc) == "Depends")) 
			cc[which(cc == "Depends")] <- "#377EB8"
		E(g)$color <- cc
		
		if (plot) 
			plot(g, ...)
		# see ?igraph:::layout for possible layout options
		g
	}




graph.somepara.all <- plotGraph(x = clean.data, pkg.to = c("snowfall", "snow", 
	"foreach", "Rmpi", "multicore", "sprint", "biopara", "bigrf", "doMPI", "doRedis", 
	"nws", "snowFT"), vertex.label.color = "black", edge.width = 1, edge.arrow.size = 0.2, 
	vertex.label.cex = 0.9, vertex.size = 0, vertex.color = "white", layout = layout.kamada.kawai)