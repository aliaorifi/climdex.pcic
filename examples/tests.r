library(RUnit)

source('../climdex.r', chdir=T)

make.temperature.fixture <- function() {
  list(
       list(-5:5,         as.factor(rep('2010', 11))),
       list(c(-5:5,5:-5), as.factor(c(rep('2010', 11), rep('2011', 11)))),
       ## All are negative
       list(rep(-10, 20), as.factor(c(rep('2010', 10), rep('2011', 10)))),
       ## All are positive
       list(rep(10, 20), as.factor(c(rep('2010', 10), rep('2011', 10))))
       )
}

mk.rv <- function(a, names)
  array(a, dimnames=list(names))

test.can.load.data <- function() {
  station <- '1098D90'
  data.dir <- '/home/data/projects/data_cleanup/CDCD_2007/new_data/'
  vars <- c(tmax='MAX_TEMP', tmin='MIN_TEMP', prec='ONE_DAY_PRECIPITATION')
  data.files <- file.path(data.dir, vars, paste(station, '_', vars, '.csv', sep=''))
  args <- append(data.files, list(data.column=as.list(vars)))
  clim.in <- do.call(climdexInput, args)
  checkTrue(inherits(clim.in, 'climdexInput'))
}

test.get.date.field <- function() {
  f <- get.date.field
  ## A period that goes over 2/29 on a leap year and then a 10 day period over the year boundary
  fixture <- c(seq(as.POSIXct("2008/02/01", tz="GMT"), length.out=30, by="day"), seq(as.POSIXct("2010/12/27", tz="GMT"), length.out=10, by="day"))
  ## Format #1: year, jday
  input <- data.frame(year=as.numeric(strftime(fixture, "%Y", tz="GMT")), jday=as.numeric(strftime(fixture, "%j", tz="GMT")))
  checkTrue(all(f(input) - fixture == 0))
  ## Format #2: year, mon, day
  input <- data.frame(year=as.numeric(strftime(fixture, "%Y", tz="GMT")), month=as.numeric(strftime(fixture, "%m", tz="GMT")), day=as.numeric(strftime(fixture, "%d", tz="GMT")))
  checkTrue(all(f(input) - fixture == 0))

  ## Check that it errors if it can't find the date
  input$year <- NULL
  bad.data <- list(input)
  invalid.data <- list(data.frame(year=2010, month=2, day=29), # 2/29 on a non leap year
                       data.frame(year=2010, month=4, day=31)) # out of range day
  for (bad in bad.data) {
    checkException(f(bad))
  }
  for (invalid in invalid.data) {
    checkTrue(is.na(f(invalid)))
  }
}

old.test.CSDI <- function() {
  f <- CSDI
  cases <- list(list(args=list(n=3, v=c(F, T, T, T, T, F), years=as.factor(rep('2008', 6))),
                     expected=mk.rv(4, '2008')),
                list(args=list(n=3, v=c(F, T, T, T, T, F), years=as.factor(c(rep('2008', 2), rep('2009', 4)))),
                     expected=mk.rv(c(1, 3), c('2008', '2009'))),
                list(args=list(n=3, v=c(F, rep(T, 4), rep(F, 2), rep(T, 4)), years=as.factor(c(rep('2008', 6), rep('2009', 5)))),
                     expected=mk.rv(c(4, 4), c('2008', '2009'))),
                list(args=list(n=0, v=c(T, F, T, F, T, F), years=as.factor(rep('2008', 6))),
                     expected=mk.rv(3, '2008'))
                )
  for (case in cases) {
    checkEquals(do.call(f, case$args), case$expected)
  }
  checkException(f(n=-1, v=rep(T, 10)))
}

test.number.days.below.threshold <- function() {
  f <- number.days.op.threshold
  fix <- make.temperature.fixture()
  thresh <- 0
  expected <- list(mk.rv(5, '2010'),
                   mk.rv(c(5, 5), c('2010', '2011')),
                   mk.rv(c(10, 10), c('2010', '2011')),
                   mk.rv(c(0, 0), c('2010', '2011'))
                   )
  do.check <- function(args, y) {
    args <- append(append(args, f, after=0), list(threshold=thresh, op="<"))
    cl <- as.call(args)
    checkEquals(eval(cl), y)
  }
  mapply(do.check, fix, expected)

  ## Should raise exception
  ex.checks <- list(list(f, NULL),
                    ## Lengths don't match
                    list(f, 1:5, as.factor(rep('2010', 4)), 0),
                    ## Not numeric
                    list(f, 'blah stuff', as.factor('2010'), 0)
                    )
  rv <- lapply(ex.checks, as.call)
  lapply(rv, checkException)
}

test.number.days.over.threshold <- function() {
  f <- number.days.op.threshold
  fix <- make.temperature.fixture()
  thresh <- 0
  expected <- list(mk.rv(5, '2010'),
                   mk.rv(c(5, 5), c('2010', '2011')),
                   mk.rv(c(0, 0), c('2010', '2011')),
                   mk.rv(c(10, 10), c('2010', '2011'))
                   )
  do.check <- function(args, y) {
    args <- append(append(args, f, after=0), list(threshold=thresh, op=">"))
    cl <- as.call(args)
    checkEquals(eval(cl), y)
  }
  mapply(do.check, fix, expected)

  ## Should raise exception
  ex.checks <- list(list(f, NULL),
                    ## Lengths don't match
                    list(f, 1:5, as.factor(rep('2010', 4)), 0),
                    ## Not numeric
                    list(f, 'blah stuff', as.factor('2010'), 0)
                    )
  rv <- lapply(ex.checks, as.call)
  lapply(rv, checkException)
}

## 'case' should be list containg all the arguments to be passed to f,
## plus one element named 'expected' which is the expected result
check.one.case <- function(case, f) {
  args <- append(case[- which(names(case) == 'expected')], f, after=0)
  cl <- as.call(args)
  print(eval(cl))
  checkEquals(eval(cl), case$expected)
}

## 'case' should be list containg all the arguments to be passed to f
check.one.bad.case <- function(case, f) {
  args <- append(case, f, after=0)
  cl <- as.call(args)
  checkException(eval(cl))
} 

test.growing.season.length <- function() {
  f <- growing.season.length

  fac <- as.factor(c(rep('2010', 366), rep('2011', 365), rep('2012', 365)))

  cases <- list()

  ## First and easiest case: a 6 day season beginning well into the second half of the year
  twenty.o.nine <- seq(as.POSIXct("2009/01/01", tz="GMT"), by="day", length.out=365)
  x <- my.ts(rep(0, 365), twenty.o.nine)
  x[seq(as.POSIXct("2009/08/01", tz="GMT"), by="day", length.out=6)] <- rep(5.1, 6)
  expected <- mk.rv(6, '2009')  ## GSL presently returns -30
  cases <- append(cases, list(list(x, as.factor(rep('2009', 365)), expected=expected)))

  ## Season starts at the beginning of the year, ends after July 1
  x <- my.ts(rep(10, 365), twenty.o.nine)
  fac <- as.factor(rep('2009', 365))
  x[seq(as.POSIXct("2009/07/02", tz="GMT"), by="day", length.out=6)] <- rep(0)
  expected <- mk.rv(as.POSIXlt("2009/07/01", tz="GMT")$yday, '2009') ## GSL presently returns -183
  cases <- append(cases, list(list(x, as.factor(rep('2009', 365)), expected=expected)))

  ## Simple case: 1,2,3 day seasons starting right after July 1
  ## wedged in between a 6 day series of 5.1 and zeros
  x <- my.ts(rep(0, 365*3+1), seq(as.POSIXct("2010/01/01", tz="GMT"), by="day", length.out=365*3+1))
  for (year in 2010:2012) {
    x[seq(as.POSIXct(paste(year, "/07/01", sep=""), tz="GMT"), length.out=6, by=as.difftime(-1, units="days"))] <- rep(5.1, 6)
    x[seq(as.POSIXct(paste(year, "/07/02", sep=""), tz="GMT"), length.out=year-2009, by=as.difftime(1, units="days"))] <- rep(10, year-2009)
  }
  expected <- mk.rv(7:9, c('2010', '2011', '2012'))  ## GSL presently fails
  cases <- append(cases, list(list(x, fac, expected=expected)))

  lapply(cases, check.one.case, f)
}

## These are simple enough definitions, that I don't think they need testing
test.max.min.daily.temp <- function() {
}

test.threshold.exceedance.duration.index <- function() {
  f <- threshold.exceedance.duration.index
  cases <- list(# temp, factor, threshold, operation, length, expected
                list(rep(1, 5), factor(rep(2010, 5)), 0, ">", 4, expected=mk.rv(5, 2010)), # make sure > op works
                list(rep(0, 5), factor(rep(2010, 5)), 0, ">=", 4, expected=mk.rv(5, 2010)), # check >= op
                list(rep(0, 5), factor(rep(2010, 5)), 0, "==", 4, expected=mk.rv(5, 2010)), # check == op
                ## Ensure that it can detect multiple sequences in the same year
                list(c(0, 0, 1, 1, 0, 0, 1, 1), factor(rep(2010, 8)), 0, ">", 2, expected=mk.rv(4, 2010)),
                ## Ensure that it can detect sequences in multiple years
                list(c(0, 0, 1, 1, 0, 0, 1, 1), factor(c(rep(2010, 4), rep(2011, 4))), 0, ">", 2, expected=mk.rv(c(2, 2), c(2010, 2011))),
                ## sequences over year boundaries should have their days counted in respective years
                list(c(0, 0, 1, 1, 1, 0, 0, 0), factor(c(rep(2010, 4), rep(2011, 4))), 0, ">", 2, expected=mk.rv(c(2, 1), c(2010, 2011)))
                )
  lapply(cases, check.one.case, f)

  error.cases <- list(
                      list("text", factor(), 0, ">", 2),
                      list(0:5, "not.a.factor", 0, ">", 2),
                      list(0:5, factor(), "text", ">", 2),
                      list(0:5, factor(), 0, "not.a.function", 2),
                      list(0:5, factor(), 0, ">", 0)
                      )
  lapply(error.cases, check.one.bad.case, f)
}

test.select.blocks.gt.length <- function() {
  f <- select.blocks.gt.length
  cases <- list( # boolean vector, length,               expected
                list(c(T, F, T, F), 0,                   expected=c(T, F, T, F)),
                list(c(T, F, T, F), -1,                  expected=c(T, F, T, F)),
                list(c(T, F, T, F), 1,                   expected=c(T, F, T, F)),
                list(c(T, T), 2,                         expected=c(F, F)),
                list(c(T, T, F, T), 2,                   expected=rep(F, 4)),
                list(c(T, T, T, F, T, T), 2,             expected=c(T, T, T, F, F ,F)),
                list(c(F, rep(T, 10), rep(F, 10), T), 4, expected=c(F, rep(T, 10), rep(F, 11)))
                )
  lapply(cases, check.one.case, f)
  error.cases <- list(
                      list(1:10, 5), # Not logical param 1
                      list(rep(T, 5), "not numeric")
                      )
  lapply(error.cases, check.one.bad.case, f)
}

## Utility timeseries class
## Carries around a POSIXct vector as an attribute that describes the
## timeseries.  Allows subsetting and subset replacement by passing in
## POSIX types as indicies
my.ts <- function(x, t) {
  stopifnot(length(x) == length(t))
  stopifnot(inherits(t, "POSIXt"))
  class(x) <- append(after=0, class(x), "my.ts")
  attr(x, 'time') <- t
  x
}

'[.my.ts' <- function(obj, ti) {
  if (is.numeric(ti)) {
    f <- '['
    x <- eval(call(f, as.numeric(obj), ti))
    return(my.ts(x, attr(obj, 'time')[ti]))
  } else if (inherits(ti, 'POSIXt')) {
    ## This will be really slow for long arrays... but it's simple
    i <- sapply(ti, function(x) {which(attr(obj, 'time') == x)})
    return(obj[i])
  }

}

'[<-.my.ts' <- function(obj, ti, value) {
  if (is.numeric(ti)) {
    f <- '[<-'
    x <- eval(call(f, as.numeric(obj), ti, value))
    return(my.ts(x, attr(obj, 'time')))
  } else if (inherits(ti, 'POSIXt')) {
    ## This will be really slow for long arrays... but it's simple
    i <- sapply(ti, function(x) {which(attr(obj, 'time') == x)})
    obj[i] <- value
    return(obj)
  }
}
