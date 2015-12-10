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
#' @param style graphical backend, can be \code{'generic'} or \code{'ggplot'}
#' @param log.scale if \code{TRUE}, displays \eqn{x}-axis in log scale
#' @param \dots Further arguments to be passed to generic methods.
#' @note When \code{style = "ggplot"}, the function calls package
#' \code{\link[ggplot2]{ggplot2}} and returns an object of class \code{ggplot}.
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
#' @importFrom dplyr %>% filter
#' @importFrom graphics plot axis lines par points polygon
#' title
#' @importFrom methods is
#' @importFrom stats aggregate
#'
#' @export
plotDoseResponse.reproData <- function(x,
                                       xlab = "Concentration",
                                       ylab = "Nb of offspring / Nb individual-days",
                                       main = NULL,
                                       target.time = NULL,
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