# M&NEM

  Single cell RNA-seq data sets from pooled CrispR screens provide the possibility to analyzse heterogeneous cell populations. We extended the original Nested Effects Models (NEM) to Mixture Nested Effects Models (M&NEM) to identify not but several causal signaling graphs, each based on the information of a sub-population of cells.

Install:
--------

Open R and input:

```{r}
install.packages("devtools")

library(devtools)

install_github("cbg-ethz/mnem")

library(mnem)
```

Small toy example with five S-genes and 1000 simulated cells. Each S-gene has two E-genes. The two components have weights 40 and 60 percent. The simulated data set consists of log ratios for effects (1) and no effects (-1). We add Gaussian noise with mean 0 and standard deviation 1. We learn an optimum with components set to two and ten random starts for the EM algorithm.

```{r}
sim <- simData(Sgenes = 5, Egenes = 2, Nems = 2, mw = c(0.4,0.6))
data <- (sim$data - 0.5)/0.5
data <- data + rnorm(length(data), 0, 1)
result <- mnem(data, k = 2, starts = 10)
plot(result)
```

## References:

Single cell network analysis with a mixture of Nested Effects Models
Martin Pirkl, Niko Beerenwinkel
bioRxiv 258202; doi: https://doi.org/10.1101/258202