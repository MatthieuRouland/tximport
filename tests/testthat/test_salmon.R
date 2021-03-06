context("salmon")
test_that("import salmon works", {

  library(readr)
  dir <- system.file("extdata", package="tximportData")
  samples <- read.table(file.path(dir,"samples.txt"), header=TRUE)
  files <- file.path(dir,"salmon", samples$run, "quant.sf.gz")
  names(files) <- paste0("sample",1:6)

  tx2gene <- read_csv(file.path(dir, "tx2gene.gencode.v27.csv"))

  txi <- tximport(files, type="salmon", tx2gene=tx2gene)
  expect_true(ncol(txi$counts) == length(files))

  # also test txOut here
  txi.txout <- tximport(files, type="salmon", txOut=TRUE)
  expect_true(ncol(txi.txout$counts) == length(files))

  # test error for txOut and not txIn
  expect_error(tximport(files, type="salmon", txIn=FALSE, txOut=TRUE))

  # test ignore tx version
  tx2gene$TXNAME <- sub("\\..*","",tx2gene$TXNAME)
  tx2gene$GENEID <- sub("\\..*","",tx2gene$GENEID)
  txi.ign.ver <- tximport(files, type="salmon", tx2gene=tx2gene, ignoreTxVersion=TRUE)
  
  # test wrong tx2gene
  tx2gene.bad <- data.frame(letters,letters)
  expect_error(tximport(files, type="salmon", tx2gene=tx2gene.bad))
})
