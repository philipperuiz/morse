reproDoseResponseCIGeneric <- function(x, conc_val, jittered_conc,
                                       transf_data_conc, display.conc) {
  plot(jittered_conc, x$resp,
       ylim = c(0, max(x$reproRateSup)),
       type = "n",
       xaxt = "n",
       yaxt = "n",
       xlab = "Concentration",
       ylab = "Reproduction rate")
  
  # axis
  axis(side = 2, at = pretty(c(0, max(x$resp))))
  axis(side = 1, at = transf_data_conc,
       labels = display.conc)
  
  x0 <- x[order(x$conc),]
  delta <- 0.01 * (max(conc_val) - min(conc_val))
  segments(jittered_conc, x0[, "reproRateInf"],
           jittered_conc, x0[, "reproRateSup"])
  segments(jittered_conc - delta, x0[, "reproRateInf"],
           jittered_conc + delta, x0[, "reproRateInf"])
  segments(jittered_conc - delta, x0[, "reproRateSup"],
           jittered_conc + delta, x0[, "reproRateSup"])
  
  points(jittered_conc, x0$resp, pch = 16)
}

reproDoseResponseCIGG <- function(x, conc_val, jittered_conc, transf_data_conc,
                                  display.conc) {

  x0 <- cbind(x[order(x$conc),], jittered_conc = as.vector(jittered_conc))
  gf <- ggplot(x0) + geom_segment(aes(x = jittered_conc, xend = jittered_conc,
                                      y = reproRateInf, yend = reproRateSup),
                                  data = x0,
                                  arrow = arrow(length = unit(0.1, "cm"),
                                                angle = 90, ends = "both")) +
    geom_point(aes(x = jittered_conc, y = resp), x0) +
    scale_x_continuous(breaks = transf_data_conc,
                       labels = display.conc) +
    expand_limits(y = 0) +
    labs(x = "Concentration", y = "Reproduction rate") +
    theme_minimal()
  
  return(gf)
}

#' Plotting method for \code{reproData} objects
#'
#' Plots the reproduction rate as a function of concentration (for a given target
#' time).
#'
#' @param x an object of class \code{reproData}
#' @param xlab a title for the \eqn{x}-axis (optional)
#' @param ylab a label for the \eqn{y}-axis
#' @param main main title for the plot
#' @param target.time a numeric value corresponding to some observed time in \code{data}
#' @param ci if \code{TRUE}, draws the 95 \% confidence interval
#' @param style graphical backend, can be \code{'generic'} or \code{'ggplot'}
#' @param log.scale if \code{TRUE}, displays \eqn{x}-axis in log scale
#' @param remove.someLabels if \code{TRUE}, removes 3/4 of X-axis labels in
#' \code{'ggplot'} style to avoid the label overlap
#' @param addlegend if \code{TRUE}, adds a default legend to the plot
#' @param \dots Further arguments to be passed to generic methods.
#' @note When \code{style = "ggplot"}, the function calls package
#' \code{\link[ggplot2]{ggplot}} and returns an object of class \code{ggplot}.
#'
#' @keywords plot
#'
#' @examples
#'
#' library(ggplot2)
#'
#' # (1) Load the data
#' data(zinc)
#' zinc <- reproData(zinc)
#'
#' # (2) Plot dose-response
#' plotDoseResponse(zinc)
#'
#' # (3) Plot dose-response with a ggplot style
#' plotDoseResponse(zinc, style = "ggplot")
#'
#' @import ggplot2
#' @import grDevices
#' @importFrom dplyr filter
#' @importFrom graphics plot axis lines points
#' title
#' @importFrom methods is
#' @importFrom stats aggregate
#' @importFrom epitools pois.exact
#'
#' @export
plotDoseResponse.reproData <- function(x,
                                       xlab = "Concentration",
                                       ylab = "Nb of offspring / Nb individual-days",
                                       main = NULL,
                                       target.time = NULL,
                                       ci = FALSE,
                                       style = "generic",
                                       log.scale = FALSE,
                                       remove.someLabels = FALSE,
                                       addlegend = TRUE,
                                       ...) {
  if (is.null(target.time)) target.time <- max(x$time)
  
  if (!target.time %in% x$time)
    stop("[target.time] is not one of the possible time !")
  
  x$resp <- x$Nreprocumul / x$Nindtime
  
  # select the target.time
  xf <- filter(x, x$time == target.time)
  
  # Selection of datapoints that can be displayed given the type of scale
  sel <- if(log.scale) xf$conc > 0 else TRUE
  x <- xf[sel, ]
  transf_data_conc <- optLogTransform(log.scale, x$conc)
  
  # Concentration values used for display in linear scale
  display.conc <- (function() {
    x <- optLogTransform(log.scale, x$conc)
    if(log.scale) exp(x) else x
  })()
  
  if (ci) {
    ICpois <- pois.exact(x$Nreprocumul, x$Nindtime)
    x$reproRateInf <- ICpois$lower
    x$reproRateSup <- ICpois$upper
    conc_val <- unique(transf_data_conc)
    x$Obs <- x$conc
    stepX <- stepCalc(conc_val)$stepX
    jittered_conc <- jitterObsGenerator(stepX, x, conc_val)$jitterObs
    
    if (style == "generic")
      reproDoseResponseCIGeneric(x, conc_val, jittered_conc, transf_data_conc,
                                 display.conc)
    else if (style == "ggplot")
      reproDoseResponseCIGG(x, conc_val, jittered_conc, transf_data_conc,
                            display.conc)
    else stop("Unknown style")
  } else {
    
    # Define visual parameters
    mortality <- c(0, 1) # code 0/1 mortality
    nomortality <- match(x$Nsurv == x$Ninit, c(TRUE, FALSE))
    
    # without mortality
    mortality <- mortality[nomortality] # vector of 0 and 1
    
    # encodes mortality empty dots (1) and not mortality solid dots (19)
    if (style == "generic") {
      mortality[which(mortality == 0)] <- 19
    }
    if (style == "ggplot") {
      mortality[which(mortality == 0)] <- "No"
      mortality[which(mortality == 1)] <- "Yes"
    }
    
    # default legend argument
    legend.position <- "right"
    legend.title <- "Mortality"
    legend.name.no <- "No"
    legend.name.yes <- "Yes"
    
    # generic
    if (style == "generic") {
      plot(transf_data_conc,
           x$resp,
           xlab = xlab,
           ylab = ylab,
           main = main,
           pch = mortality,
           yaxt = "n",
           xaxt = "n")
      # axis
      axis(side = 2, at = pretty(c(0, max(x$resp))))
      axis(side = 1, at = transf_data_conc,
           labels = display.conc)
      
      # legend
      if (addlegend) {
        legend(legend.position,title = legend.title, pch = c(19, 1), bty = "n",
               legend = c(legend.name.no, legend.name.yes))
      }
    }
    
    #ggplot2
    if (style == "ggplot") {
      df <- data.frame(x,
                       transf_data_conc,
                       display.conc,
                       Mortality = mortality)
      
      # plot
      gp <- ggplot(df, aes(transf_data_conc, resp,
                           fill = Mortality)) +
        geom_point(size = 3, pch = 21) +
        scale_fill_manual(values = c("black", "white")) +
        labs(x = xlab, y = ylab) +
        ggtitle(main) +
        theme_minimal() +
        scale_colour_hue(legend.title, breaks = c("No","Yes"),
                         labels = c(legend.name.no, legend.name.yes)) +
        scale_x_continuous(breaks = df$transf_data_conc,
                           labels = if (remove.someLabels) {
                             exclude_labels(df$display.conc)
                           } else {
                             df$display.conc
                           })
      
      if (addlegend) {
        return(gp)
      } else {
        gp <- gp + theme(legend.position = "none")
        return(gp)
      }
    }
  }
}