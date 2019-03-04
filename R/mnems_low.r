#' @noRd
#' @importFrom methods is
bigphi <- function(x) {
  if (is(x, "mnemsim")) {
    resfull <- NULL
    for (l in seq_len(length(x$Nem))) {
      tmp <- transitive.closure(x$Nem[[l]], mat = TRUE)
      resfull <- cbind(resfull, t(tmp))
    }
  } else {
    resfull <- NULL
    for (l in seq_len(length(x$comp))) {
      tmp <- transitive.closure(x$comp[[l]]$phi, mat = TRUE)
      colnames(tmp) <- rownames(tmp) <- seq_len(nrow(tmp))
      resfull <- cbind(resfull, t(tmp))
    }
  }
  return(resfull)
}
#' @noRd
Kratio <- function(x, y) {
  xn <- uniques(x)
  yn <- length(y$Nem)
  if (xn >= yn) {
    z <- yn/xn
  } else {
    z <- xn/yn
  }
  return(z)
}
#' @noRd
uniques <- function(x) {
  for (i in seq_len(length(x$comp))) {
    x$comp[[i]]$theta <- NULL
  }
  y <- length(unique(x$comp))
  return(y)
}
#' @noRd
mnemh.rec <- function(data, k = 2, logtype = 2, ...) {
  tmp <- mnemk(data, ks=seq_len(k), logtype = logtype, ...)
  cluster <- apply(getAffinity(tmp$best$probs,
                               logtype = logtype,
                               mw = tmp$best$mw), 2, which.max)
  if (length(tmp$best$comp) == 1) {
    return(tmp$best)
  } else {
    tmp1 <- NULL
    for (i in seq_len(length(tmp$best$comp))) {
      if (length(unique(colnames(data[, which(cluster == i)]))) > 1) {
        tmp2 <- mnemh.rec(data[, which(cluster == i)],
                          k=k, logtype=logtype, ...)
      } else {
        tmp2 <- NULL
      }
      tmp1 <- c(tmp1, tmp2)
    }
    return(tmp1)
  }
}
#' @noRd
random_probs <- function(k, data, full = FALSE, logtype = 2) {
  samplefun <- function(n,p) {
    x <- sample(c(0,1), n,
                replace = TRUE,
                prob = p)
    
    return(x)
  }
  probs <- matrix(log(samplefun(k*ncol(data),
                                c(0.9, 0.1)))/log(logtype), k,
                  ncol(data))
  if (full) {
    for (i in seq_len(k)) {
      if (i == 1) { next() }
      infcells <- which(apply(probs, 2, function(x) {
        bad <- FALSE
        if (all(is.infinite(x))) {
          bad <- TRUE
        }
        return(bad)
      }))
      if (i == k) {
        probs[i, infcells] <- log(1)/log(logtype)
      } else {
        probs[i, infcells] <-
          log(samplefun(length(infcells),
                        c(1-1/k, 1/k)))/log(logtype)
      }
    }
  }
  while(any(apply(probs, 1, function(x) {
    bad <- FALSE
    if (all(is.infinite(x)) | all(x == 0)) {
      bad <- TRUE
    }
    return(bad)
  }))) {
    probs <- matrix(log(samplefun(k*ncol(data),
                                  c(0.9, 0.1)))/log(logtype), k,
                    ncol(data))
    if (full) {
      for (i in seq_len(k)) {
        if (i == 1) { next() }
        infcells <- which(apply(probs, 2, function(x) {
          bad <- FALSE
          if (all(is.infinite(x))) {
            bad <- TRUE
          }
          return(bad)
        }))
        if (i == k) {
          probs[i, infcells] <- log(1)/log(logtype)
        } else {
          probs[i, infcells] <-
            log(samplefun(length(infcells),
                          c(1-1/k, 1/k)))/log(logtype)
        }
      }
    }
  }
  return(probs)
}
#' @noRd
random_probs2 <- function(k, data, full = FALSE, logtype = 2) {
  samplefun <- function(n,p) {
    x <- sample(c(0,1), n,
                replace = TRUE,
                prob = p)
    
    return(x)
  }
  probs <- matrix(0, k, ncol(data))
  for (i in seq_len(k)) {
    if (i == 1) {
      probs[i, ] <- samplefun(ncol(data), c(1-1/k,1/k))
    } else {
      probs[i, which(probs[i-1, ] == 0)] <-
        samplefun(sum(probs[i-1, ] == 0), c(1-1/(k+1-i),1/(k+1-i)))
    }
  }
  return(probs)
}
#' @noRd
sortAdj <- function(res, list = FALSE) {
  resmat <- NULL
  for (i in seq_len(length(res))) {
    if (list) {
      resmat <-
        rbind(resmat,
              as.vector(mytc(res[[i]])))
    } else {
      resmat <-
        rbind(resmat,
              as.vector(mytc(res[[i]]$adj)))
    }
  }
  d <- as.matrix(dist(resmat))
  dsum <- apply(d, 1, sum)
  resorder <- which.max(dsum)
  d[resorder, resorder] <- Inf
  for (i in 2:length(dsum)) {
    resorder <- c(resorder, which.min(d[, resorder[length(resorder)]]))
    d[resorder, resorder] <- Inf
  }
  res2 <- list()
  for (i in seq_len(length(res))) {
    res2[[i]] <- res[[resorder[i]]]
  }
  return(list(res = res2, order = resorder))
}
#' @noRd
calcEvopen <- function(res, list = TRUE) {
  evopen <- 0
  for (i in seq_len(length(res)-1)) {
    if (list) {
      evopen <- evopen + sum(abs(res[[i]] -
                                   res[[(i+1)]]))/length(res[[i]])
    } else {
      evopen <- evopen + sum(abs(res[[i]]$adj -
                                   res[[(i+1)]]$adj))/length(res[[i]]$adj)
    }
  }
  evopen <- -evopen#/(k-1)
  return(evopen)
}
#' @noRd
transProb <- function(x, y, lambda = 0.5) {
  n <- nrow(x)
  exp <- sum(abs(x-y))
  enum <- lambda*(1-lambda)^(exp-1)
  denom <- 0
  ne <- (n*(n-1))
  for (i in 0:ne) {
    denom <- denom + choose(ne, i)*lambda*(1-lambda)^(i-1)
  }
  p <- enum/denom
  return(p)
}
#' @noRd
fullTransProb <- function(x, ...) {
  p <- 1
  for (i in seq_len(length(x)-1)) {
    p <- p*transProb(x[[i]], x[[i+1]], ...)
  }
  return(p)
}
#' @noRd
modAdj <- function(adj, D) {
  Sgenes <- getSgenes(D)
  SgeneN <- getSgeneN(D)
  for (i in seq_len(SgeneN)) {
    colnames(adj) <- rownames(adj) <- gsub(i, Sgenes[i], colnames(adj))
  }
  return(adj)
}
#' @noRd
getRho <- function(data) {
  
  Sgenes <- getSgenes(data)
  
  Rho <- matrix(0, length(Sgenes), ncol(data))
  
  for (i in seq_len(length(Sgenes))) {
    Rho[i, grep(paste0("^", Sgenes[i], "_|_", Sgenes[i],
                       "$|_", Sgenes[i], "_|^", Sgenes[i], "$"),
                colnames(data))] <- 1
  }
  
  rownames(Rho) <- Sgenes
  colnames(Rho) <- colnames(data)
  Rho <- Rho[naturalsort(rownames(Rho)), ]
  return(Rho)
}
#' @noRd
#' @importFrom nem sampleRndNetwork
initComps <- function(data, k=2, starts=1, verbose = FALSE, meanet = NULL) {
  n <- getSgeneN(data)
  init <- list()
  for (i in seq_len(starts)) {
    init[[i]] <- list()
    for (j in seq_len(k)) {
      tmp <- sampleRndNetwork(seq_len(n), DAG = TRUE)
      init[[i]][[j]] <- tmp
    }
  }
  return(init)
}
#' @noRd
initps <- function(data, ks, k, starts = 3, ksel = "dist") {
  clusters <- list()
  multi <- grep("_", colnames(data))
  if (length(multi) > 0) {
    data2 <- data[, -multi]
  } else {
    data2 <- data
  }
  for (i in seq_len(length(unique(colnames(data2))))) {
    if ("cor" %in% ksel) {
      d <- (1 - cor(data[, which(colnames(data) %in% i)]))/2
      d <- as.dist(d)
    } else {
      d <- dist(t(data[, which(colnames(data) %in% i)]))
    }
    if (length(d) > 1) {
      hc <- hclust(d)
      clusters[[i]] <- cutree(hc, min(ks[i], length(hc$labels)))
    } else {
      clusters[[i]] <- 1
    }
  }
  probscl <- list()
  
  n <- getSgeneN(data)
  
  count <- 0
  llstr <- NULL
  resstr <- NULL
  counter <- 0
  takes <- NULL
  takesdone <- NULL
  while(count < starts & counter < prod(ks)) {
    counter <- counter + 1
    tmp <- matrix(0, k, ncol(data))
    if (ks[1] < k) {
      takes <- as.matrix(sample(seq_len(ks[1]), k, replace = TRUE), k, 1)
    } else {
      takes <- as.matrix(sample(seq_len(ks[1]), k), k, 1)
    }
    for (i in 2:length(unique(colnames(data)))) {
      if (ks[i] < k) {
        takes <- cbind(takes, sample(seq_len(ks[i]), k, replace = TRUE))
      } else {
        takes <- cbind(takes, sample(seq_len(ks[i]), k))
      }
    }
    for (i in seq_len(k)) {
      for (j in seq_len(n)) {
        tmp[i, which(colnames(data) == j)[
          which(clusters[[j]] == takes[i, j])]] <- 1
      }
    }
    takestmp <- paste(takes, collapse = "")
    if (!(takestmp %in% takesdone)) {
      count <- count + 1
      takesdone <- c(takesdone, takestmp)
      probscl[[count]] <- log2(tmp)
    }
  }
  return(probscl)
}
#' @noRd
modData <- function(D) {
  SgeneN <- getSgeneN(D)
  Sgenes <- getSgenes(D)
  if (!all(is.numeric(Sgenes))) {
    colnamesD <- colnames(D)
    for (i in seq_len(SgeneN)) {
      colnamesD <- gsub(Sgenes[i], i, colnamesD)
    }
    colnames(D) <- colnamesD
  }
  rownames(D) <- as.numeric(seq_len(nrow(D)))
  return(D)
}
#' @noRd
#' @importFrom cluster silhouette
#' @importFrom stats kmeans
learnk <- function(data, kmax = 10, ksel = c("hc", "silhouette", "cor"),
                   starts = 10, mono = TRUE, verbose = FALSE) {
  ks <- numeric(length(unique(colnames(data))))
  lab <- list()
  index <- numeric(ncol(data))
  for (i in naturalsort(as.numeric(unique(colnames(data))))) {
    if (verbose) {
      print(i)
    }
    if (sum(colnames(data) %in% i) <= 1) { k <- 1; next() }
    if ("cor" %in% ksel) {
      d <- (1 - cor(data[, which(colnames(data) %in% i)]))/2
      d <- as.dist(d)
    } else {
      d <- dist(t(data[, which(colnames(data) %in% i)]))
    }
    if ("hc" %in% ksel) {
      hc <- hclust(d)
      ks[i] <- 2
      lab[[i]] <- rep(1, sum(colnames(data) %in% i))
      if (length(d) > 1) {
        silavg <- 0
        silavgs <- numeric(length(hc$order)-1)
        clusters <- list()
        for (j in 2:(length(hc$order)-1)) {
          cluster <- cutree(hc, j)
          clusters[[j]] <- cluster
          if ("BIC" %in% ksel | "AIC" %in% ksel) {
            m <- nrow(data)
            n <- length(cluster)
            k <- length(table(cluster))
            D <- log(mean(silhouette(cluster, d)[, 3]))
            if ("AIC" %in% ksel) {
              silavgs[j] <- 2*m*k - 2*D
            } else {
              silavgs[j] <- log(n)*m*k - 2*D
            }
          }
          if ("silhouette" %in% ksel) {
            silavgs[j] <- mean(silhouette(cluster, d)[, 3])
          }
          if (verbose) {
            print(silavgs[j])
          }
          if (silavgs[j] < silavgs[(j-1)]) {
            break()
          }
          if (silavg < silavgs[j]) {
            silavg <- silavgs[j]
            ks[i] <- j
            lab[[i]] <- cluster
          }
        }
      }
      index[which(colnames(data) %in% i)] <- lab[[i]]
    }
    if ("kmeans" %in% ksel) {
      silavg <- 0
      silavgs <- numeric(kmax)
      clusters <- list()
      for (j in seq_len(kmax)) {
        if (j == 1) { next() }
        kc <- kmeans(d, centers = j, nstart = starts)
        if ("BIC" %in% ksel | "AIC" %in% ksel) {
          m <- ncol(kc$centers)
          n <- length(kc$cluster)
          k <- nrow(kc$centers)
          D <- kc$tot.withinss
          if ("AIC" %in% ksel) {
            silavgs[j] <- 2*m*k + D
          } else {
            silavgs[j] <- log(n)*m*k + D
          }
        }
        if ("silhouette" %in% ksel) {
          silavgs[j] <- mean(silhouette(kc$cluster, d)[, 3])
        }
        if (verbose) {
          print(silavgs[j])
        }
        if (j == 1) {
          j2 <- j
        } else {
          j2 <- j - 1
        }
        if (silavgs[j] < silavgs[j] & mono) {
          break()
        }
        if (silavg < silavgs[j]) {
          silavg <- silavgs[j]
          ks[i] <- j
          lab[[i]] <- kc$clusters
        }
      }
    }
  }
  k <- min(kmax, max(ks))
  return(list(ks = ks, k = k, lab = lab, cluster = index))
}
#' @noRd
getLL <- function(x, logtype = 2, mw = NULL, data = NULL) {
  if (is.null(mw)) { mw = rep(1, nrow(x))/nrow(x) }
  complete <- FALSE
  if (complete) {
    Z <- getAffinity(x, logtype = logtype, mw = mw, data = data)
    l <- sum(apply(Z*(x + log(mw)/log(logtype)), 2, sum))
  } else {
    x <- logtype^x
    x <- x*mw
    l <- sum(log(rep(1,nrow(x))%*%x)/log(logtype))
  }
  return(l)
}
#' @noRd
estimateSubtopo <- function(data, fun = which.max) {
  if (length(grep("_", colnames(data))) > 0) {
    data <- data[, -grep("_", colnames(data))]
  }
  effectsums <- effectsds <- matrix(0, nrow(data),
                                    length(unique(colnames(data))))
  n <- getSgeneN(data)
  for (i in seq_len(n)) {
    if (length(grep(i, colnames(data))) > 1) {
      effectsds[, i] <- apply(data[, grep(i, colnames(data))], 1, sd)
      effectsums[, i] <- apply(data[, grep(i, colnames(data))], 1, sum)
    } else {
      effectsds[, i] <- 1
      effectsums[, i] <- data[, grep(i, colnames(data))]
    }
  }
  subtopoX <- as.numeric(apply(effectsums/effectsds, 1, fun))
  subtopoX[which(is.na(subtopoX) == TRUE)] <- 1
  return(subtopoX)
}
#' @noRd
getProbs <- function(probs, k, data, res, method = "llr", n, affinity = 0,
                     converged = 10^-2, subtopoX = NULL, ratio = TRUE,
                     logtype = 2, mw = NULL, fpfn = fpfn, Rho = NULL) {
  if (is.null(subtopoX)) {
    subtopoX <- estimateSubtopo(data)
  }
  subtopoY <- bestsubtopoY <- subtopoX
  bestprobs <- probsold <- probs
  time0 <- TRUE
  count <- 0
  if (ncol(data) <= 100) {
    max_count <- 100
  } else {
    max_count <- 1
  }
  ll0 <- llold <- -Inf
  stop <- FALSE
  mw <- apply(getAffinity(probsold, affinity = affinity, norm = TRUE,
                          mw = mw, logtype = logtype, data = data), 1, sum)
  mw <- mw/sum(mw)
  if (any(is.na(mw))) { mw <- rep(1, k)/k }
  while((!stop | time0) & count < max_count) {
    time0 <- FALSE
    probsold <- probs
    subtopo0 <- matrix(0, k, nrow(data))
    subweights0 <- matrix(0, nrow(data), n+1)
    postprobsold <- getAffinity(probsold, affinity = affinity, norm = TRUE,
                                logtype = logtype, mw = mw, data = data)
    probs0 <- probsold*0
    for (i in seq_len(k)) {
      adj1 <- mytc(res[[i]]$adj)
      if (is.null(Rho)) {
        adj1 <- adj1[colnames(data), ]
      } else {
        adj1 <- t(Rho)%*%adj1
        adj1[which(adj1 > 1)] <- 1
      }
      adj1 <- cbind(adj1, "0" = 0)
      if (is.null(res[[i]]$subtopo)) {
        subtopo <- maxCol_row(t(t(data)*postprobsold[i, ])%*%adj1)
      } else {
        subtopo <- res[[i]]$subtopo
        subtopo[which(subtopo == 0)] <- ncol(adj1)
      }
      adj2 <- adj1[, subtopo]
      if (method %in% "llr") {
        tmp <- colSums(data*t(adj2))
      }
      probs0[i, ] <- tmp
    }
    ll0 <- getLL(probs0, logtype = logtype, mw = mw,
                 data = data)
    if (max(ll0) - llold > 0) {
      bestprobs <- probs0
    }
    probs <- probs0
    if (max(ll0) - llold <= converged) {
      stop <- TRUE
    }
    mw <- apply(getAffinity(probs, affinity = affinity, norm = TRUE,
                            logtype = logtype, mw = mw, data = data), 1,
                sum)
    mw <- mw/sum(mw)
    llold <- max(ll0)
    count <- count + 1
  }
  return(list(probs = bestprobs, subtopoX = subtopoX,
              mw = mw, ll = llold))
}
#' @noRd
annotAdj <- function(adj, data) {
  Sgenes <- getSgenes(data)
  colnames(adj) <- rownames(adj) <- naturalsort(Sgenes)
  return(adj)
}
#' @noRd
nemEst <- function(data, maxiter = 100, start = "null",
                   sumf = mean, alpha = 1, cut = 0,
                   monoton = FALSE, logtype = 2,
                   useF = FALSE, method = "llr",
                   weights = NULL, fpfn = c(0.1, 0.1), Rho = NULL,
                   close = FALSE, domean = TRUE, modified = FALSE, ...) {
  if (method %in% "disc") {
    D <- data
    D[which(D == 1)] <- log((1-fpfn[2])/fpfn[1])/log(logtype)
    D[which(D == 0)] <- log(fpfn[2]/(1-fpfn[1]))/log(logtype)
    method <- "llr"
    data <- D
  }
  if (!modified) {
    data <- modData(data)
  }
  if (sum(duplicated(colnames(data)) == TRUE) > 0 &
      method %in% "llr" & domean) {
    if (!is.null(weights)) {
      D <- data
      data <- data*rep(weights, rep(nrow(data), ncol(data)))
    }
    data2 <- doMean(data, weights = weights, Rho = Rho, logtype = logtype)
    data <- D
  } else {
    data2 <- data
  }
  if (is.null(weights)) { weights <- rep(1, ncol(data2)) }
  R <- data2[, naturalsort(colnames(data2))]
  R2 <- R
  if (!is.null(Rho)) {
    combs <- which(apply(Rho, 2, sum) > 1)
    if (length(combs) > 0) {
      R <- R[, -combs]
    }
  }
  n <- length(unique(colnames(R)))
  Cp <- 1
  Cz <- 0
  phibest <- phi <- matrix(0, n, n)
  rownames(phi) <- colnames(phi) <- colnames(R)
  E0 <- apply(R, 2, sum)
  phi <- phi[order(E0, decreasing = TRUE), order(E0, decreasing = TRUE)]
  phi[upper.tri(phi)] <- 1
  phi <- phi[naturalsort(rownames(phi)), naturalsort(colnames(phi))]
  E <- phi
  E <- E*Cp
  if ("full" %in% start) {
    phi <- phi
  } else if ("rand" %in% start) {
    phi <- phi*0
    diag(phi) <- 1
    phi[seq_len(length(phi))] <- sample(c(0,1), length(phi), replace = TRUE)
    phi[lower.tri(phi)] <- 0
    phi <- phi[sample(seq_len(nrow(phi)), nrow(phi)),
               sample(seq_len(nrow(phi)), nrow(phi))]
    phi <- phi[naturalsort(rownames(phi)), naturalsort(colnames(phi))]
  } else if ("null" %in% start) {
    phi <- phi*0
    diag(phi) <- 1
  } else {
    phi <- start
  }
  O <- phi*0
  iter <- Oold <- 0
  lls <- NULL
  llbest <- -Inf
  stop <- FALSE
  while(!stop & iter < maxiter) {
    iter <- iter + 1
    if (is.null(Rho)) {
      phi2 <- phi
    } else {
      phi2 <- t(Rho)%*%phi
      phi2[which(phi2 > 1)] <- 1
    }
    P <- llrScore(R2, phi2, weights = weights)
    P[, grep("_", colnames(phi))] <- min(P)
    subtopo <- as.numeric(gsub(ncol(phi)+1, 0, maxCol_row(P)))
    theta <- t(R2)*0
    theta[cbind(subtopo, seq_len(ncol(theta)))] <- 1
    Oold <- O
    ll <- llrScore(theta, P)
    ll <- sum(diag(ll))
    if (ll %in% lls | all(phi == phibest)) {
      stop <- TRUE
    }
    if (monoton & iter > 1) {
      if (ll < lls[length(lls)]) { stop <- TRUE }
    }
    if (llbest < ll) {
      phibest <- phi
      thetabest <- theta
      llbest <- ll
      numbest <- iter
      Obest <- O
    }
    lls <- c(lls, ll)
    nogenes <- which(apply(theta, 1, sum) == 0)
    nozeros <- which(t(P) > 0, arr.ind = TRUE)
    nozeros <- nozeros[which(nozeros[, 1] %in% nogenes), ]
    theta[nozeros] <- 1
    theta[grep("_", colnames(phi)), ] <- 0
    if (is.null(Rho)) {
      theta2 <- theta
    } else {
      theta2 <- t(Rho)%*%theta
    }
    if (useF) {
      O <- (t(R2)*weights)%*%t(mytc(phi2)%*%theta)
    } else {
      O <- (t(R2)*weights)%*%t(theta2)
    }
    cutoff <- cut*max(abs(O))
    if (!is.null(Rho)) {
      Rho%*%(O%*%t(Rho))
    }
    phi[which(O > cutoff & E == 1)] <- 1
    phi[which(O <= cutoff | E == 0)] <- 0
    if (close) {
      phi <- mytc(phi)
    }
  }
  phintc <- phibest
  phibest <- mytc(phibest)
  if (is.null(Rho)) {
    phibest2 <- phibest
  } else {
    phibest2 <- t(Rho)%*%phibest
    phibest2[which(phibest2 > 1)] <- 1
  }
  P <- llrScore(R2, phibest2, weights = weights)
  P[, grep("_", colnames(phibest2))] <- min(P)
  subtopo <- as.numeric(gsub(
    ncol(phibest2)+1, 0, apply(P, 1, which.max)))
  thetabest <- t(R)*0
  thetabest[cbind(subtopo, seq_len(ncol(thetabest)))] <- 1
  llbest <- llrScore(thetabest, P)
  llbest <- sum(diag(llbest))
  nem <- list(phi = phibest, theta = thetabest, iter = iter,
              ll = llbest, lls = lls, num = numbest, C = Cz,
              O = Obest, E = E0, phintc = phintc)
  class(nem) <- "nemEst"
  return(nem)
}
#' @noRd
doMean <- function(D, weights = NULL, Rho = NULL, logtype = 2) {
  man <- FALSE
  if (man) {
    mD <- matrix(0, nrow(D), length(unique(colnames(D))))
    if (!is.null(weights)) {
      doodds <- FALSE
      if (doodds) {
        A <- exp(D)/(1+exp(D))
        D <- log(t(t(A)*weights +
                     (1-weights)*0.5)/t(t(1 - A)*weights +
                                          (1-weights)*0.5))/log(logtype)
      } else {
        D <- D*rep(weights, rep(nrow(D), ncol(D)))
      }
    }
    for (i in seq_len(length(unique(colnames(D))))) {
      mD[, i] <-
        apply(D[, which(colnames(D) %in% unique(colnames(D))[i]),
                drop = FALSE], 1, mean)
    }
    colnames(mD) <- unique(colnames(D))
  } else {
    if (!is.null(weights)) {
      D <- D*rep(weights, rep(nrow(D), ncol(D)))
    }
    global <- TRUE
    if (global) {
      mD <- t(rowsum(t(D), colnames(D)))/ncol(D)
    } else {
      mD <- t(rowsum(t(D), colnames(D))/as.numeric(table(colnames(D))))
    }
  }
  mD <- mD[, naturalorder(colnames(mD))]
  return(mD)
}
#' @noRd
modules <- function(D, method = "llr", weights = NULL, reduce = FALSE,
                    start = NULL,
                    verbose = FALSE, trans.close = TRUE, redSpace = NULL,
                    subtopo = NULL, ratio = TRUE, parallel = NULL,
                    prior = NULL, fpfn = c(0.1, 0.1),
                    modulesize = 4, search = "exhaustive", domean = TRUE,
                    Rho = NULL, logtype = 2) {
  D <- data <- modData(D)
  n <- getSgeneN(D)
  Sgenes <- getSgenes(D)
  if (domean) {
    D <- doMean(D, weights = weights, Rho = Rho, logtype = logtype)
    weights <- rep(1, ncol(D))
    sumdata <- data <- D
  } else {
    sumdata <- matrix(0, nrow(data), n)
    if (!is.null(weights)) {
      D <- D*rep(weights, rep(nrow(D), ncol(D)))
      weights <- rep(1, ncol(sumdata))
    }
    for (i in seq_len(n)) {
      sumdata[, i] <-
        apply(D[, which(colnames(D) %in% i), drop = FALSE], 1, sum)
    }
    colnames(sumdata) <- seq_len(n)
    rownames(sumdata) <- rownames(D)
  }
  D <- NULL
  n <- getSgeneN(data)
  cordata <- cor(sumdata)
  cordata[is.na(cordata)] <- -1
  d <- as.dist((1 - cordata)/2)
  for (i in 2:n) {
    hc <- hclust(d)
    hcut <- cutree(hc, i)
    if (max(table(hcut)) <= modulesize) {
      break()
    }
  }
  groups <- table(hcut)
  fullnet <- NULL
  for (i in seq_len(length(groups))) {
    subset <- which(hcut == i)
    if (verbose) {
      print(paste(c("calculating module", subset), collapse = " "))
    }
    if (length(subset) > 1) {
      subdata <- data[, which(colnames(data) %in% subset)]
      if (is.null(start)) {
        start2 <- start
      } else {
        start2 <- start[which(rownames(start) %in% subset),
                        which(colnames(start) %in% subset)]
      }
      if (!is.null(Rho)) { Rho <- getRho(subdata) }
      tmp <- mynem(subdata, search = search, method = method,
                   start = start2,
                   parallel = parallel, reduce = reduce,
                   weights = weights[which(colnames(data) %in% subset)],
                   verbose = verbose,
                   redSpace = redSpace, trans.close = trans.close,
                   subtopo = subtopo, prior = prior, ratio = ratio,
                   domean = FALSE, fpfn = fpfn, Rho = Rho,
                   logtype = logtype)
      if (is.null(fullnet)) {
        fullnet <- tmp$adj
      } else {
        tmpnames <- c(colnames(fullnet), colnames(tmp$adj))
        fullnet <-
          rbind(cbind(fullnet,
                      matrix(0, nrow(fullnet), ncol(tmp$adj))),
                cbind(matrix(0, nrow(tmp$adj), ncol(fullnet)),
                      tmp$adj))
        colnames(fullnet) <- rownames(fullnet) <- as.numeric(tmpnames)
      }
    } else {
      if (is.null(dim(fullnet))) {
        fullnet <- matrix(1, 1, 1)
        colnames(fullnet) <- rownames(fullnet) <- subset
      } else {
        fullnet <- rbind(cbind(fullnet, 0), 0)
        colnames(fullnet)[ncol(fullnet)] <-
          rownames(fullnet)[nrow(fullnet)] <-
          subset
      }
    }
  }
  fullnet <- transitive.reduction(fullnet)
  fullnet <- fullnet[order(as.numeric(rownames(fullnet))),
                     order(as.numeric(colnames(fullnet)))]
  return(fullnet)
}
#' @noRd
getSgeneN <- function(data) {
  Sgenes <- length(unique(unlist(strsplit(colnames(data), "_"))))
  return(Sgenes)
}
#' @noRd
getSgenes <- function(data) {
  Sgenes <- naturalsort(unique(unlist(strsplit(colnames(data), "_"))))
  return(Sgenes)
}
#' @noRd
get.rev.tc <-function (Phi) {
  idx = which(Phi + t(Phi) == 1, arr.ind = TRUE)
  models = list()
  nn <- dim(Phi)
  if (NROW(idx) > 0) {
    for (i in seq_len(NROW(idx))) {
      Phinew = Phi
      Phinew[idx[i, 1], idx[i, 2]] = 1 - Phinew[idx[i, 1], idx[i, 2]]
      Phinew[idx[i, 2], idx[i, 1]] = 1 - Phinew[idx[i, 2], idx[i, 1]]
      diag(Phinew) = 1
      if (Phinew[idx[i, 1], idx[i, 2]] == 1) {
        uv <- idx[i, ]
      } else {
        uv <- rev(idx[i, ])
      }
      Phinew <- mytc(Phinew, uv[1], uv[2])
      models[[i]] <- Phinew
    }
  }
  models
}
#' @noRd
get.ins.fast <- function (Phi, trans.close = TRUE) {
  idx = which(Phi == 0)
  models = list()
  nn <- dim(Phi)
  if (length(idx) > 0) {
    for (i in seq_len(length(idx))) {
      uv <- arrayInd(idx[i], nn)
      Phinew = Phi
      Phinew[idx[i]] = 1
      if (trans.close) {
        Phinew = mytc(Phinew, uv[1], uv[2])
      }
      models[[i]] <- Phinew
    }
  }
  models
}
#' @noRd
get.del.tc <- function (Phi) {
  Phi = Phi - diag(ncol(Phi))
  Phi2 <- transitive.reduction(Phi)
  idx = which(Phi2 == 1)
  models = list()
  if (length(idx) > 0) {
    for (i in seq_len(length(idx))) {
      Phinew = Phi
      Phinew[idx[i]] = 0
      diag(Phinew) = 1
      models[[i]] <- Phinew
    }
  }
  models
}
#' @noRd
#' @importFrom nem enumerate.models transitive.reduction
#' @importFrom utils getFromNamespace
mynem <- function(D, search = "greedy", start = NULL, method = "llr",
                  parallel = NULL, reduce = FALSE, weights = NULL, runs = 1,
                  verbose = FALSE, redSpace = NULL,
                  trans.close = TRUE, subtopo = NULL, prior = NULL,
                  ratio = TRUE, domean = TRUE, modulesize = 5,
                  fpfn = c(0.1, 0.1), Rho = NULL, logtype = 2,
                  modified = FALSE, Sgenes = NULL, ...) {
  if (method %in% "disc") {
    D[which(D == 1)] <- log((1-fpfn[2])/fpfn[1])/log(logtype)
    D[which(D == 0)] <- log(fpfn[2]/(1-fpfn[1]))/log(logtype)
    method <- "llr"
  }
  get.insertions <- get.ins.fast
  get.reversions <- get.rev.tc
  get.deletions <- get.del.tc
  if ("modules" %in% search) {
    if (length(search) > 1) {
      search <- search[-which(search %in% "modules")]
    } else {
      search <- "greedy"
    }
    if (length(unique(colnames(D))) > modulesize) {
      start <- modules(D, method = method, weights = weights,
                       reduce = reduce, verbose = verbose, start = start,
                       trans.close = trans.close, redSpace = redSpace,
                       subtopo = subtopo, fpfn = fpfn,
                       ratio = ratio, parallel = parallel, prior = prior,
                       modulesize = modulesize, search = search,
                       domean = domean, Rho = Rho, logtype = logtype)
    }
    if (search %in% "exhaustive") {
      search <- "greedy"
    }
  }
  D.backup <- D
  if (!modified) {
    D <- modData(D)
    colnames(D) <- gsub("\\..*", "", colnames(D))
  }
  if (!is.null(Rho)) { Rho <- getRho(D) }
  if (domean) {
    D <- doMean(D, weights = weights, Rho = Rho, logtype = logtype)
    weights <- NULL
    if (!is.null(Rho)) { Rho <- getRho(D) }
    domean <- FALSE
  }
  if (!is.null(Rho)) {
    colnames(D) <-
      c(unique(unlist(strsplit(colnames(D), "_"))),
        sample(seq_len(length(unique(unlist(strsplit(colnames(D),
                                                     "_"))))),
               ncol(D) -
                 length(unique(unlist(strsplit(colnames(D), "_")))),
               replace = TRUE))
  }
  if (is.null(Sgenes)) {
    Sgenes <- getSgenes(D)
  }
  if (is.null(start)) {
    start2 <- "null"
    start <- better <- matrix(0, length(Sgenes), length(Sgenes))
    diag(start) <- 1
    colnames(start) <- rownames(start) <- Sgenes
  } else {
    if (length(start) == 1) {
      if (!(search %in% "estimate")) {
        start2 <- start
        start <- better <- matrix(0, length(Sgenes), length(Sgenes))
        diag(start) <- 1
        colnames(start) <- rownames(start) <- Sgenes
      } else {
        better <- matrix(0, length(Sgenes), length(Sgenes))
        start2 <- start
      }
    } else {
      better <- start2 <- start
      diag(start) <- 1
      colnames(start) <- rownames(start) <- Sgenes
    }
  }
  diag(better) <- 1
  colnames(better) <- rownames(better) <- Sgenes
  score <- scoreAdj(D, better, method = method, weights = weights,
                    subtopo = subtopo,
                    prior = prior, ratio = ratio, fpfn = fpfn,
                    Rho = Rho)
  score <- score$score
  oldscore <- score
  allscores <- score
  
  if (!is.null(parallel)) {
    get.insertions <- get.ins.fast
    get.reversions <- get.rev.tc
    get.deletions <- get.del.tc
    naturalsort <- naturalsort::naturalsort
    transitive.reduction <- nem::transitive.reduction
    sfInit(parallel = TRUE, cpus = parallel)
    sfExport("modules", "D", "start", "better", "transitive.reduction",
             "method", "scoreAdj", "weights", "mytc",
             "llrScore", "get.deletions", "get.insertions",
             "get.reversions", "getRho", "doMean")
  }
  
  if (search %in% "small") {
    search <- "greedy"
    max_iter <- 1
  } else {
    max_iter <- Inf
  }
  
  guess <- FALSE
  if (search %in% "fast") {
    search <- "greedy"
    guess <- TRUE
  }
  
  if (search %in% "greedy") {
    P <- oldadj <- NULL
    if (guess) {
      better <- mynem(D, search = "estimate", start = start,
                      method = method, parallel = parallel,
                      reduce = reduce, weights = weights, runs = runs,
                      verbose = verbose, redSpace = redSpace,
                      trans.close = trans.close, subtopo = subtopo,
                      prior = prior, ratio = ratio, domean = domean,
                      fpfn = fpfn, Rho = Rho, logtype = logtype,
                      modified = modified, Sgenes = Sgenes)$adj
      better <- mytc(better)
    }
    for (iter in seq_len(runs)) {
      if (iter > 1) {
        better <- matrix(sample(c(0,1),nrow(better)*ncol(better),
                                replace = TRUE, prob = c(0.9,0.1)),
                         nrow(better),
                         ncol(better))
        colnames(better) <- rownames(better) <-
          sample(Sgenes, length(Sgenes))
        better[lower.tri(better)] <- 0
        diag(better) <- 1
        better <- better[order(as.numeric(rownames(better))),
                         order(as.numeric(colnames(better)))]
        score <- scoreAdj(D, better, method = method,
                          weights = weights,
                          subtopo = subtopo, prior = prior,
                          ratio = ratio, fpfn = fpfn,
                          Rho = Rho)
        P <- score$subweights
        oldadj <- better
        score <- score$score
        oldscore <- score
        allscores <- score
      }
      stop <- FALSE
      count <- 0
      while(!stop) {
        oldadj <- better
        doScores <- function(i) {
          new <- models[[i]]
          score <- scoreAdj(D, new, method = method,
                            weights = weights,
                            subtopo = subtopo, prior = prior,
                            ratio = ratio, fpfn = fpfn,
                            Rho = Rho, P = P, oldadj = oldadj,
                            trans.close = FALSE)
          P <- score$subweights
          score <- score$score
          return(list(score, P))
        }
        models <- unique(c(get.insertions(better),
                           get.reversions(better),
                           get.deletions(better)))
        if (is.null(parallel)) {
          scores <- unlist(lapply((seq_len(length(models))),
                                  doScores), recursive = FALSE)
        } else {
          scores <- unlist(sfLapply((seq_len(length(models))),
                                    doScores), recursive = FALSE)
        }
        Ps <- scores[seq_len(length(models))*2]
        scores <- unlist(scores[seq_len(length(models))*2 - 1])
        scores[is.na(scores)] <- 0
        bestidx <- which.max(scores)
        best <- models[[bestidx]]
        if ((max(scores, na.rm = TRUE) > oldscore |
             ((max(scores, na.rm = TRUE) == oldscore &
               sum(better == 1) > sum(best == 1))))
            & count < max_iter) {
          better <- best
          oldscore <- max(scores)
          allscores <- c(allscores, oldscore)
          P <- Ps[[which.max(scores)]]
        } else {
          stop <- TRUE
        }
        count <- count + 1
      }
      if (iter > 1) {
        if (oldscore > oldscore2) {
          better2 <- better
          allscores2 <- allscores
          oldscore2 <- oldscore
        }
      } else {
        better2 <- better
        allscores2 <- allscores
        oldscore2 <- oldscore
      }
    }
    better <- better2
    allscores <- allscores2
    oldscore <- oldscore2
  }
  
  if (search %in% "exhaustive") {
    models <- enumerate.models(length(Sgenes), Sgenes,
                               trans.close = trans.close,
                               verbose = verbose)
    doScores <- function(i) {
      adj <- models[[i]]
      score <- scoreAdj(D, adj, method = method, weights = weights,
                        subtopo = subtopo, prior = prior,
                        ratio = ratio, fpfn = fpfn,
                        Rho = Rho)
      score <- score$score
      return(score)
    }
    if (is.null(parallel)) {
      scores <- unlist(lapply(seq_len(length(models)), doScores))
    } else {
      scores <- unlist(sfLapply(seq_len(length(models)), doScores))
    }
    best <- which.max(scores)
    better <- mytc(models[[best]])
    diag(better) <- 1
  }
  
  if (search %in% "estimate") {
    if (!is.null(weights)) {
      Dw <- D*rep(weights, rep(nrow(D), ncol(D)))
      weights <- NULL
    } else {
      Dw <- D
    }
    tmp <- nemEst(Dw, start = "null", method = method, fpfn = fpfn,
                  Rho = Rho, domean = domean, modified = TRUE, ...)
    tmp1 <- nemEst(Dw, start = "full", method = method, fpfn = fpfn,
                   Rho = Rho, domean = domean, modified = TRUE, ...)
    if (tmp1$ll > tmp$ll) { tmp <- tmp1 }
    if (is.matrix(start2)) {
      tmp2 <- nemEst(Dw, start = start2, method = method, fpfn = fpfn,
                     Rho = Rho, domean = domean, modified = TRUE, ...)
      if (tmp2$ll > tmp$ll) { tmp <- tmp2 }
    }
    better <- tmp$phi
    oldscore <- tmp$ll
    allscores <- tmp$lls
    subweights <- Dw%*%cbind(tmp$phi[colnames(Dw), ], 0)
  }
  
  if (!is.null(parallel)) {
    sfStop()
  }
  
  if (is.null(subtopo)) {
    subtopo <- scoreAdj(D, better, method = method, weights = weights,
                        prior = prior,
                        ratio = ratio, fpfn = fpfn,
                        Rho = Rho, dotopo = TRUE)
    subweights <- subtopo$subweights
    subtopo <- subtopo$subtopo
  } else {
    subweights <- P
  }
  
  better <- transitive.reduction(better)
  better <- better[order(as.numeric(rownames(better))),
                   order(as.numeric(colnames(better)))]
  nem <- list(adj = better, score = oldscore, scores = allscores,
              redSpace = redSpace, subtopo = subtopo, D = D.backup,
              subweights = subweights)
  return(nem)
}
#' @noRd
adj2dnf <- function(A) {
  
  dnf <- NULL
  
  for (i in seq_len(ncol(A))) {
    for (j in seq_len(nrow(A))) {
      if (i %in% j) { next() }
      if (A[i, j] == 1) {
        dnf <- c(dnf, paste(colnames(A)[i], rownames(A)[j], sep = "="))
      }
      if (A[i, j] == -1) {
        dnf <- c(dnf, paste("!", colnames(A)[i], "=",
                            rownames(A)[j], sep = ""))
      }
    }
  }
  
  dnf <- unique(dnf)
  
  return(dnf)
  
}
#' @noRd
#' @importFrom methods new
plot.adj <- function(x, ...) {
  adj2graph <- function(adj.matrix) {
    V   <- rownames(adj.matrix)
    edL <- vector("list", length=nrow(adj.matrix))
    names(edL) <- V
    for (i in seq_len(nrow(adj.matrix))) {
      edL[[i]] <- list(edges=which(!adj.matrix[i,]==0),
                       weights=adj.matrix[i,!adj.matrix[i,]==0])
    }
    gR <- new("graphNEL",nodes=V,edgeL=edL,edgemode="directed")
    return(gR)
  }
  g <- adj2graph(x)
  plot(g)
}
#' @noRd
graph2adj <- function(gR) {
  adj.matrix <- matrix(0,
                       length(nodes(gR)),
                       length(nodes(gR))
  )
  rownames(adj.matrix) <- nodes(gR)
  colnames(adj.matrix) <- nodes(gR)
  for (i in seq_len(length(nodes(gR)))) {
    adj.matrix[nodes(gR)[i],adj(gR,nodes(gR)[i])[[1]]] <- 1
  }
  return(adj.matrix)
}
#' @noRd
#' @importFrom flexclust dist2
#' @import Rcpp
#' @import RcppEigen
llrScore <- function(data, adj, weights = NULL, ratio = TRUE) {
  if (is.null(weights)) {
    weights <- rep(1, ncol(data))
  }
  if (ratio) {
    score <- eigenMapMatMult(data, adj*weights)
  } else {
    if (max(data) == 1) {
      score <- -dist2(data, t(adj)*weights)
    } else {
      score <- -dist2(data, t((adj*mean(data))*weights))
    }
  }
  return(score)
}
#' @noRd
#' @importFrom matrixStats rowMaxs
scoreAdj <- function(D, adj, method = "llr", weights = NULL,
                     trans.close = TRUE, subtopo = NULL,
                     prior = NULL, ratio = TRUE, fpfn = c(0.1, 0.1),
                     Rho = NULL, dotopo = FALSE,
                     P = NULL, oldadj = NULL) {
  if (trans.close) {
    adj <- mytc(adj)
  }
  if (is.null(Rho)) {
    adj1 <- adj[colnames(D), ]
  } else {
    adj1 <- t(Rho)%*%adj
    adj1[which(adj1 > 1)] <- 1
  }
  if (method %in% "llr") {
    ll <- "max"
    if (is.null(P) | is.null(oldadj)) {
      score <- llrScore(D, adj1, weights = weights, ratio = ratio)
    } else {
      changeidx <- unique(floor(which(adj != oldadj)/nrow(adj)+0.99))
      Q <- llrScore(D, adj1[, changeidx],
                    weights = weights, ratio = ratio)
      score <- P
      score[, changeidx] <- Q
    }
  }
  if (is.null(subtopo) & dotopo) {
    subtopo <- maxCol_row(cbind(0, score))
    subtopo <- subtopo - 1
  }
  subweights <- score
  if (ll %in% "max") {
    if (is.null(subtopo)) {
      score <- sum(rowMaxs(score))
    } else {
      score <- sum(score[cbind(seq_len(nrow(score)),
                               as.numeric(subtopo))])
    }
  }
  if (ll %in% "marg") {
    score <- sum(score)
  }
  if (!is.null(prior)) {
    prior <- transitive.reduction(prior)
    adj <- transitive.reduction(adj)
    score <- score - sum(abs(prior - adj))/length(prior)
  }
  return(list(score = score, subtopo = subtopo, subweights = subweights))
}
#' @noRd
adj2dnf <- function(A) {
  dnf <- NULL
  for (i in seq_len(ncol(A))) {
    dnf <- c(dnf, rownames(A))
    for (j in seq_len(nrow(A))) {
      if (A[i, j] == 1) {
        dnf <- c(dnf, paste(colnames(A)[i], rownames(A)[j], sep = "="))
      }
      if (A[i, j] == -1) {
        dnf <- c(dnf, paste("!", colnames(A)[i], "=", rownames(A)[j],
                            sep = ""))
      }
    }
  }
  
  dnf <- unique(dnf)
  
  return(dnf)
  
}
#' @noRd
#' @useDynLib mnem
#' @importFrom Rcpp sourceCpp
mytc <- function(x, u = NULL, v = NULL) {
  diag(x) <- 1
  if (is.null(u) | is.null(v)) {
    y <- matrix(transClose_W(x), nrow(x), ncol(x))
  } else {
    if (x[u,v] == 1) {
      y <- matrix(transClose_Ins(x, u, v), nrow(x), ncol(x))
    }
    if (x[u,v] == 0) {
      y <- matrix(transClose_Del(x, u, v), nrow(x), ncol(x))
    }
  }
  y[which(y != 0)] <- 1
  rownames(y) <- rownames(x)
  colnames(y) <- colnames(x)
  return(y)
}
#' @noRd
simulateDnf <- function(dnf, stimuli = NULL, inhibitors = NULL) {
  getStateDnf <- function(node, signalStates, graph, children = NULL) {
    graphCut <- graph[grep(paste("=", node, "$", sep = ""), graph)]
    if (length(graphCut) == 0) {
      signalStates[, node] <- 0
    } else {
      sop <- numeric(nrow(signalStates))
      children2 <- gsub("!", "", children)
      for (i in graphCut) {
        parents <- gsub("=.*$", "", unlist(strsplit(i, "\\+")))
        pob <- rep(1, nrow(signalStates))
        for (j in parents) {
          j2 <- gsub("!", "", j)
          if (sum(is.na(signalStates[, j2]) == TRUE) ==
              length(signalStates[, j2])) {
            if (j %in% j2) {
              node2 <- node
              add1 <- 0
            } else {
              node2 <- paste("!", node, sep = "")
              add1 <- 1
            }
            if (j2 %in% children2) {
              subGraph <- graph[
                -grep(paste(".*=", node, "|.*",
                            j2, ".*=.*", sep = ""), graph)]
              signalStatesTmp <- getStateDnf(
                node = j2,
                signalStates = signalStates,
                graph = subGraph,
                children = NULL)
              ifa <- children[
                which(children2 %in% j2):length(children2)]
              ifb <- (length(grep("!", ifa)) + add1)/2
              ifc <- children[
                which(children2 %in% j2):length(children2)]
              if (ifb != ceiling((length(grep("!", ifc)) +
                                  add1)/2)) {
              } else {
              }
              if (add1 == 0) {
                pobMult <- signalStatesTmp[, j2]
              } else {
                pobMult <- add1 - signalStatesTmp[, j2]
              }
            } else {
              signalStates <-
                getStateDnf(node = j2,
                            signalStates = signalStates,
                            graph = graph,
                            children = unique(c(children,
                                                node2)))
              if (add1 == 0) {
                pobMult <- signalStates[, j2]
              } else {
                pobMult <- add1 - signalStates[, j2]
              }
            }
            pob <- pob*pobMult
          } else {
            if (j %in% j2) {
              add1 <- 0
            } else {
              add1 <- 1
            }
            if (add1 == 0) {
              pobMult <- signalStates[, j2]
            } else {
              pobMult <- add1 - signalStates[, j2]
            }
            pob <- pob*pobMult
          }
          if (max(pob, na.rm = TRUE) == 0) { break() }
        }
        sop <- sop + pob
        if (min(sop, na.rm = TRUE) > 0) { break() }
      }
      sop[sop > 0] <- 1
      if (node %in% inhibitors) {
        sop <- sop*0
      }
      if (node %in% stimuli) {
        sop <- max(sop, 1)
      }
      signalStates[, node] <- sop
    }
    return(signalStates)
  }
  signals <-
    unique(gsub("!", "",
                unlist(strsplit(
                  unlist(strsplit(dnf, "=")), "\\+"))))
  graph <- dnf
  signalStates <- matrix(NA, nrow = 1, ncol = length(signals))
  rownames(signalStates) <- paste(c("stimuli:", stimuli, "inhibitors:",
                                    inhibitors), collapse = " ")
  colnames(signalStates) <- signals
  signalStates[which(signals %in% stimuli)] <- 1
  for (k in signals) {
    if (is.na(signalStates[, k]) == TRUE) {
      signalStates <- getStateDnf(node = k, signalStates = signalStates,
                                  graph = graph, children = NULL)
    }
  }
  namestmp <- colnames(signalStates)
  signalStates <- as.vector(signalStates)
  names(signalStates) <- namestmp
  return(signalStates = signalStates)
}
#' @noRd
#' @importFrom gtools permutations
dimJac <- function(x){
  library(Matrix)
  library(gtools)
  
  K <- length(x$comp) # extract number of mixture components K
  
  for (i in 1:K){     # define phis and thetas
    tmp <- nem::transitive.closure(x$comp[[i]]$phi, mat = TRUE) # the output graphs of the mnem function are not transitively closed
    tmp2 <- matrix(0, nrow = nrow(tmp),
                   ncol = length(x$comp[[i]]$theta))            # the output of the mnem function for the thetas is not a matrix
    # but only an assignment of E-genes to S-genes. Transform to a matrix
    tmp3 <- x$comp[[i]]$theta
    tmp3[which(tmp3 > nrow(tmp2))] <- 0
    tmp2[cbind(tmp3, seq_len(ncol(tmp2)))] <- 1
    assign(paste("phi", i, sep=""), tmp)
    assign(paste("theta", i, sep=""), tmp2)
  }
  
  ns <- nrow(phi1) # number of S-genes (=number of knockdowns)
  ne <- ncol(theta1) # number of E-genes
  
  ## Create all network states, namely 2^ne-1 states
  
  network.states <- permutations(2,ne,0:1,repeats.allowed=TRUE)[-1,] # The state of only 0 for all E-genes isn't possible and therefore left out
  
  ## Create all network parameters
  
  # Mixture weights: (K-1) parameters
  if (K==1){ #Special case if MNEM is only a NEM : #mixture components=1
    lamdas.p <- "1"
  } else {
    lamdas.p <- paste("l", 1:K, sep="")
    lamdas.p[K] <- paste("(1-(", paste(lamdas.p[1:K-1], collapse="+"), "))") # the last mixture weight can be expressed by 
                                                                               # all others as they must sum up to 1.
  }
  
  
  # Knockdown parameters: (ns-1) parameters, knockdown probabilities are the same for all mixture components
  knockdowns.p <- paste("k", rep(1:ns, K), sep="")
  for (i in 1:K){
    knockdowns.p[i*ns] <- paste("(1-(", paste(knockdowns.p[(ns*i-(ns-1)):(ns*i-1)], collapse="+"), "))")}
  
  # Conditional parameters for the observed E-genes given the E-gene states:
  # These are created below as they are needed and must be "collected" (not all of them have to be used)
  
  ## Calculation of the likelihood functions for every single network state given the phi and theta matrices:
  
  unique.cond.probs <- c() # Here, we "collect" the conditional probabilities
  
  # Go through all network states:
  for (state in 1:nrow(network.states)){
    
    net.state <- network.states[state,]
    joint.probs <- c() # Here we extend every iteration (going through mixture components) with the calculated joint probability 
    # for said mixture component (without the mixture weights)
    
    # Go through all mixture components:
    for (mixcomp in 1:K){
      phi <- eval(parse(text=paste('phi', mixcomp, sep="")))     # phi of current mixture component
      theta <- eval(parse(text=paste('theta', mixcomp, sep=""))) # theta of current mixture component
      F <- phi%*%theta # F represents the expected states of the E-genes given phi and theta of the current mixture component
      
      # For all knockdowns in one mixture component: Start with constructing cond. probabilities.
      probs.mixcomp <- matrix(paste("p", 1:ne, mixcomp, net.state, t(F), sep=""), ns, ne, byrow=T) 
      # This creates a matrix of expressions for conditional probabilities, where rows are knockdowns and columns E-genes.
      # E.g.: p1101 is the conditional probability that E-gene 1 in mixture component 1 has state 0 if the expected state is 1
      
      # Conditional probabilities are pairwise dependent. E.g.: p1111 = 1-p1101 or p1100 = 1-p1110
      for (pp in 1:length(probs.mixcomp)){ 
        if (substr(probs.mixcomp[pp], nchar(probs.mixcomp[pp])-1, nchar(probs.mixcomp[pp]))=="11"){
          probs.mixcomp[pp] <- paste("(1-", substr(probs.mixcomp[pp], 1, nchar(probs.mixcomp[pp])-2), "01)", sep="")
        } else if (substr(probs.mixcomp[pp], nchar(probs.mixcomp[pp])-1, nchar(probs.mixcomp[pp]))=="00"){
          probs.mixcomp[pp] <- paste("(1-", substr(probs.mixcomp[pp], 1, nchar(probs.mixcomp[pp])-2), "10)", sep="")
        }
      }
      
      ## Now we have to create the joint probability for one mixture component for all knockdowns
      
      # this generates a vector of ns characters, a precursor of the joint likelihood (consisting only of the conditional parameters)
      joint.probs.mixcomp <- apply(probs.mixcomp, 1, function(x) paste(x, collapse="*")) 
      
      # adding the knockdown parameters
      joint.probs.mixcomp <- paste(paste(knockdowns.p[(ns*(mixcomp-1)+1):(ns*mixcomp)], joint.probs.mixcomp, sep="*"), collapse="+") 
      
      # Adding brackets
      joint.probs.mixcomp <- paste("(", joint.probs.mixcomp, ")", sep="")
      
      # Save the expression for the likelihood for one mixture components:
      joint.probs <- c(joint.probs, joint.probs.mixcomp) 
      
      # "Collect" all conditional parameters for the observed E-genes:
      unique.cond.probs <- unique(c(as.vector(probs.mixcomp), unique.cond.probs))
    }
    
    # Until now, we have calculated the joint probability for our all mixture components. They are saved as lf1 : lfK and look like: 
    # ( *(k1*p1101+k2*p2110+...)
    # In this step, we have to bring them together, weighted by the mixture weights
    assign(paste("joint.l", state, sep=""), as.formula(paste("~",paste(paste(lamdas.p, joint.probs, sep="*"), collapse=" + "))))  
  }
  
  # The result so far are formulas for the likelihood for each possible network state
  
  #Group all network parameters: Combine all used network parameters into one list, then filter out expressions in brackets
  if (K==1){ #Special case if MNEM is only a NEM : #mixture components=1
    network.params <- c(knockdowns.p[1:ns], unique.cond.probs)
  } else {
  network.params <- c(lamdas.p, knockdowns.p[1:ns], unique.cond.probs)
  }
  network.params <- network.params[substr(network.params,1,1)!="("]
  
  # Create empty Jacobian matrix: rows: number of states, columns: number of parameters
  n.row.J <- nrow(network.states)
  n.col.J <- length(network.params)
  Jacobian.matrix <- matrix(rep(NA, n.row.J*n.col.J), n.row.J, n.col.J)
  
  # Derive the joint likelihoods for all states after all network parameters
  for ( j in 1:n.row.J){
    assign(paste("deriv", j, sep=""), deriv(eval(parse(text=paste('joint.l', j, sep=""))), network.params, cache.exp=FALSE))
  }
  
  # Caluclate the rank five times for different randomly chosen probabilities for the network parameters
  ranks <- c() # here, the ranks will be saved
  
  for (j in 1:5){
    # Assign random probabilities to the network parameters
    for (i in 1:n.col.J){
      assign(network.params[i], runif(1, 0, 1))}
    # Calculate ranks
    for (nr in 1:n.row.J){
      Jacobian.matrix[nr,] <- attributes(eval(eval(parse(text=paste('deriv', nr, sep="")))))$gradient
    }
    ranks[j] <- rankMatrix(Jacobian.matrix)
  }
  
  fpar <- max(ranks)
  
  return(fpar) 
}
