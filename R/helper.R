#' Low-level function to make counts from abundance using matrices
#'
#' Simple low-level function used within \link{tximport} to generate
#' \code{scaledTPM} or \code{lengthScaledTPM} counts, taking as input
#' the original counts, abundance and length matrices.
#' NOTE: This is a low-level function exported in case it is needed for some reason,
#' but the recommended way to generate counts-from-abundance is using
#' \link{tximport} with the \code{countsFromAbundance} argument.
#'
#' @param countsMat a matrix of original counts
#' @param abundanceMat a matrix of abundances (typically TPM)
#' @param lengthMat a matrix of effective lengths
#' @param countsFromAbundance the desired type of count-from-abundance output
#'
#' @return a matrix of count-scale data generated from abundances.
#' for details on the calculation see \link{tximport}.
#'
#' @export
makeCountsFromAbundance <- function(countsMat, abundanceMat, lengthMat,
                                    countsFromAbundance=c("scaledTPM","lengthScaledTPM")) {
  countsFromAbundance <- match.arg(countsFromAbundance)
  sparse <- is(countsMat, "dgCMatrix")
  colsumfun <- if (sparse) Matrix::colSums else colSums
  countsSum <- colsumfun(countsMat)
  if (countsFromAbundance == "lengthScaledTPM") {
    newCounts <- abundanceMat * rowMeans(lengthMat)
  } else if (countsFromAbundance == "scaledTPM") {
    newCounts <- abundanceMat
  } else {
    stop("expecting 'lengthScaledTPM' or 'scaledTPM'")
  }
  newSum <- colsumfun(newCounts)
  if (sparse) {
    countsMat <- Matrix::t(Matrix::t(newCounts) * (countsSum/newSum))
  } else {
    countsMat <- t(t(newCounts) * (countsSum/newSum))
  }
  countsMat
}

# function for replacing missing average transcript length values
replaceMissingLength <- function(lengthMat, aveLengthSampGene) {
  nanRows <- which(apply(lengthMat, 1, function(row) any(is.nan(row))))
  if (length(nanRows) > 0) {
    for (i in nanRows) {
      if (all(is.nan(lengthMat[i,]))) {
        # if all samples have 0 abundances for all tx, use the simple average
        lengthMat[i,] <- aveLengthSampGene[i]
      } else {
          # otherwise use the geometric mean of the lengths from the other samples
          idx <- is.nan(lengthMat[i,])
          lengthMat[i,idx] <-  exp(mean(log(lengthMat[i,!idx]), na.rm=TRUE))
        }
    }
  }
  lengthMat
}

medianLengthOverIsoform <- function(length, tx2gene, ignoreTxVersion, ignoreAfterBar) {
  txId <- rownames(length)
  if (ignoreTxVersion) {
    txId <- sub("\\..*", "", txId)
  } else if (ignoreAfterBar) {
    txId <- sub("\\|.*", "", txId)
  }
  tx2gene <- cleanTx2Gene(tx2gene)
  stopifnot(all(txId %in% tx2gene$tx))
  tx2gene <- tx2gene[match(txId, tx2gene$tx),]
  # average the lengths
  ave.len <- rowMeans(length)
  # median over isoforms
  med.len <- tapply(ave.len, tx2gene$gene, median)
  one.sample <- med.len[match(tx2gene$gene, names(med.len))]
  matrix(rep(one.sample, ncol(length)),
         ncol=ncol(length), dimnames=dimnames(length))
}

# code contributed from Andrew Morgan
read_kallisto_h5 <- function(fpath, ...) {
  if (!requireNamespace("rhdf5", quietly=TRUE)) {
    stop("reading kallisto results from hdf5 files requires Bioconductor package `rhdf5`")
  }
  counts <- rhdf5::h5read(fpath, "est_counts")
  ids <- rhdf5::h5read(fpath, "aux/ids")
  efflens <- rhdf5::h5read(fpath, "aux/eff_lengths")

  # as suggested by https://support.bioconductor.org/p/96958/#101090
  ids <- as.character(ids)
  
  stopifnot(length(counts) == length(ids)) 
  stopifnot(length(efflens) == length(ids))

  result <- data.frame(target_id = ids,
                       eff_length = efflens,
                       est_counts = counts,
                       stringsAsFactors = FALSE)
  normfac <- with(result, (1e6)/sum(est_counts/eff_length))
  result$tpm <- with(result, normfac*(est_counts/eff_length))
  return(result)
}

summarizeFail <- function() {
  stop("

  tximport failed at summarizing to the gene-level.
  Please see 'Solutions' in the Details section of the man page: ?tximport

")
}

# this is much faster than by(), a bit slower than dplyr summarize_each()
## fastby <- function(m, f, fun) {
##   idx <- split(1:nrow(m), f)
##   if (ncol(m) > 1) {
##     t(sapply(idx, function(i) fun(m[i,,drop=FALSE])))
##   } else {
##     matrix(vapply(idx, function(i) fun(m[i,,drop=FALSE], FUN.VALUE=numeric(ncol(m)))),
##            dimnames=list(levels(f), colnames(m)))
##   }
## }

