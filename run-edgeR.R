#!/usr/bin/env Rscript

args <- commandArgs(TRUE)

## Default setting when no arguments passed
if(length(args) < 1) {
	  args <- c("--help")
}
 
## Help section
if("--help" %in% args) {
  cat("
      run-edgeR.R - Run edgeR method
 
      Arguments:
      --in=someValue   		- input file path
      --groups=someValue	- group file path
      --out=someValue   	- output file path
      --help            	- print this Help
 
      Example:
      ./run-edgeR.R --in=\"input.txt\" --out=\"output.txt\" 
      
      Daniel Guariz Pinheiro
      FCAV/UNESP - Univ Estadual Paulista
      dgpinheiro@gmail.com
      \n\n")

  q(save="no")
}
 

## Parse arguments (we expect the form --arg=value)
parseArgs <- function(x) strsplit(sub("^--", "", x), "=")
argsDF <- as.data.frame(do.call("rbind", parseArgs(args)))
argsL <- as.list(as.character(argsDF$V2))
names(argsL) <- argsDF$V1
	

if(is.null(argsL[['in']])) {
	sink(stderr())
	cat("\nERROR: Missing input file!\n\n")
	sink()
	q(save="no")
}
if(is.null(argsL[['out']])) {
	sink(stderr())
	cat("\nERROR: Missing output dir!\n\n")
	sink()
	q(save="no")
}
if(is.null(argsL[['groups']])) {
	sink(stderr())
	cat("\nERROR: Missing groups file!\n\n")
	sink()
	q(save="no")
}

if ( ! file.exists(argsL[['in']]) ) {
	sink(stderr())
	cat("\nERROR: Input file not found!\n\n")
	sink()
	q(save="no")
}
if ( (! file.exists(argsL[['out']]))|(! file.info(argsL[['out']])[1,"isdir"] ) ) {
	sink(stderr())
	cat("\nERROR: Output directory not found!\n\n")
	sink()
	q(save="no")
}
if ( ! file.exists(argsL[['groups']]) ) {
	sink(stderr())
	cat("\nERROR: Groups file not found!\n\n")
	sink()
	q(save="no")
}

suppressPackageStartupMessages( library('edgeR') )

x <-read.delim( argsL[['in']], header=TRUE )
samps <- setdiff(colnames(x), 'mirna')

g <-read.delim( argsL[['groups']], header=TRUE, stringsAsFactor=FALSE )

if ( any(! ( g$id %in% samps )) ) {
	sink(stderr())
	cat(paste("\nERROR: id(s) (", paste(c(g$id)[ ! ( g$id %in% samps )  ], collapse=","), ") not found in data!\n\n", sep=""))
	sink()
	q(save="no")
}


rownames(x) <- x$mirna

df <- x[ , c('mirna', g$id)]

rownames(g) <- g$id

colnames(df)[ colnames(df) %in% g$id ] <- g[g$id, 'name']

group <- factor( g$group )


y <- DGEList(counts=df[, g$name], group=group)

design <- model.matrix(~0+group, data=y$samples)
colnames(design) <- levels(y$samples$group)

y <- calcNormFactors(y)
y <- estimateGLMCommonDisp(y,design)
y <- estimateGLMTrendedDisp(y,design)
y <- estimateGLMTagwiseDisp(y,design)

## exactTest()
#y <- calcNormFactors(y)
#y <- estimateCommonDisp(y)
#y <- estimateTagwiseDisp(y)
#et <- exactTest(y)
#z <- et$table
#z$mirna <- rownames(z)
#z$logFC <- round(z$logFC, 3)
#z$PValue <- format(z$PValue, scientific=TRUE)


fit <- glmFit(y, design)

all.comb <- apply(t(combn(levels(group),2)), 1, function(x) { paste( x ,collapse="-") })

df.cpm <- as.data.frame(cpm(y, normalized.lib.sizes=TRUE))
df.cpm$mirna <- rownames(df.cpm)

lrt <- list()
for (c in 1:length(all.comb)) {
	print(all.comb[c])
	my.contrast <- makeContrasts(contrasts=all.comb[c], levels=design)
	lrt[[ all.comb[c] ]] <- glmLRT(fit, contrast=my.contrast)
	dgelrt.df <- as.data.frame(topTags(lrt[[ all.comb[c] ]],adjust.method="fdr", sort.by="logFC", n=NULL))
	
	dgelrt.df$mirna <- rownames(dgelrt.df)
	dge.res <- (merge(dgelrt.df, df.cpm, by='mirna'))[,c('mirna', g$name, 'logFC', 'PValue', 'FDR')]
	dge.res.sel <- apply(dge.res[, g$name], 1, sum) > 0
	write.table(file=paste(argsL[['out']],"/",all.comb[c],".txt",sep=""), x=dge.res[dge.res.sel,], row.names=FALSE, quote=FALSE, sep="\t")
}

#save(file="/tmp/lrt.RData", lrt)





