#' add_osm_suface
#'
#' Adds a colour-coded surface of spatial objects (polygons, lines, or points
#' generated by \code{\link{extract_osm_objects}} to a graphics object
#' initialised with \code{\link{osm_basemap}}. The surface is spatially
#' interpolated between the values given in \code{dat}, which has to be a matrix or
#' \code{data.frame} of 3 columns (x, y, z), where (x,y) are (longitude,
#' latitude), and z are the values to be interpolated. Interpolation uses
#' \code{spatstat::Smoothing.ppp}, which applies a Gaussian kernel smoother
#' optimised to the given data, and is effectively non-parametric.
#'
#' @param map A \code{ggplot2} object to which the surface are to be added
#' @param obj An \code{sp} \code{SpatialPolygonsDataFrame} or
#' \code{SpatialLinesDataFrame} (list of polygons or lines) returned by
#' \code{\link{extract_osm_objects}}
#' @param dat A matrix or data frame of 3 columns (x, y, z), where (x, y) are
#' (longitude, latitude), and z are the values to be interpolated
#' @param method Either \code{idw} (Inverse Distance Weighting as
#' \code{spatstat::idw}; default), \code{Gaussian} for kernel
#' smoothing (as \code{spatstat::Smooth.ppp}), or any other value to avoid
#' interpolation. In this case, \code{dat} must be regularly spaced in \code{x}
#' and \code{y}.
#' @param grid_size size of interpolation grid 
#' @param cols Vector of colours for shading z-values (for example,
#' \code{terrain.colors (30)})
#' @param bg If specified, OSM objects outside the convex hull surrounding
#' \code{dat} are plotted in this colour, otherwise they are included in the
#' interpolation (which will generally be inaccurate for peripheral values)
#' @param size Size argument passed to \code{ggplot2} (polygon, path, point)
#' functions: determines width of lines for (polygon, line), and sizes of
#' points.  Respective defaults are (0, 0.5, 0.5). If \code{bg} is provided and
#' \code{size} has 2 elements, the second determines the \code{size} of the
#' background objects.
#' @param shape Shape of lines or points, for details of which see
#' \code{?ggplot::shape}. If \code{bg} is provided and \code{shape} has 2
#' elements, the second determines the \code{shape} of the background objects.
#' @return modified version of \code{map} to which surface has been added
#'
#' @note 
#' Points beyond the spatial boundary of \code{dat} are included in the surface
#' if \code{bg} is not given. In such cases, values for these points may exceed
#' the range of provided data because the surface will be extrapolated beyond
#' its domain.  Actual plotted values are therefore restricted to the range of
#' given values, so any extrapolated points greater or less than the range of
#' \code{dat} are simply set to the respective maximum or minimum values. This
#' allows the limits of \code{dat} to be used precisely when adding colourbars
#' with \code{\link{add_colourbar}}.
#'
#' @export
#'
#' @seealso \code{\link{osm_basemap}}, \code{\link{add_colourbar}}.
#'
#' @examples
#' # Get some data
#' bbox <- get_bbox (c (-0.13, 51.5, -0.11, 51.52))
#' # dat_B <- extract_osm_objects (key='building', bbox=bbox)
#' # These data are also provided in
#' dat_B <- london$dat_BNR
#' # Make a data surface across the map coordinates, and remove periphery
#' n <- 5
#' x <- seq (bbox [1,1], bbox [1,2], length.out=n)
#' y <- seq (bbox [2,1], bbox [2,2], length.out=n)
#' dat <- data.frame (
#'     x=as.vector (array (x, dim=c(n, n))),
#'     y=as.vector (t (array (y, dim=c(n, n)))),
#'     z=x * y
#'     )
#' map <- osm_basemap (bbox=bbox, bg='gray20')
#' map <- add_osm_surface (map, dat_B, dat=dat, cols=heat.colors (30))
#' print_osm_map (map)
#'
#' # If data do not cover the entire map region, then the peripheral remainder can
#' # be plotted by specifying the 'bg' colour. First remove periphery from
#' # 'dat':
#' d <- sqrt ((dat$x - mean (dat$x)) ^ 2 + (dat$y - mean (dat$y)) ^ 2)
#' dat <- dat [which (d < 0.01),]
#' map <- osm_basemap (bbox=bbox, bg='gray20')
#' map <- add_osm_surface (map, dat_B, dat=dat, cols=heat.colors (30), bg='gray40')
#' print_osm_map (map)
#'
#' # Polygons and (lines/points) can be overlaid as data surfaces with different
#' # colour schemes.
#' # dat_HP <- extract_osm_objects (key='highway', value='primary', bbox=bbox)
#' # These data are also provided in
#' dat_HP <- london$dat_HP
#' cols <- adjust_colours (heat.colors (30), adj=-0.2) # darken by 20%
#' map <- add_osm_surface (map, dat_HP, dat, cols=cols, bg='gray60', size=c(1.5,0.5))
#' print_osm_map (map)
#' 
#' # Adding multiple surfaces of either polygons or (lines/points) produces a
#' # 'ggplot2' warning, and forces the colour gradient to revert to the last given
#' # value.
#' dat_T <- london$dat_T # trees
#' map <- osm_basemap (bbox=bbox, bg='gray20')
#' map <- add_osm_surface (map, dat_B, dat=dat, cols=heat.colors (30), bg='gray40')
#' map <- add_osm_surface (map, dat_HP, dat, cols=heat.colors (30), bg='gray60', 
#'                         size=c(1.5,0.5))
#' map <- add_osm_surface (map, dat_T, dat, cols=topo.colors (30),
#'                         bg='gray70', size=c(5,2), shape=c(8, 1))
#' print_osm_map (map) # 'dat_HP' is in 'topo.colors' not 'heat.colors'
#' 
#' # Add axes and colourbar
#' map <- add_axes (map)
#' map <- add_colourbar (map, cols=heat.colors (100), zlims=range (dat$z),
#'                       barwidth=c(0.02), barlength=c(0.6,0.99), vertical=TRUE)
#' print_osm_map (map)


add_osm_surface <- function (map, obj, dat, method="idw", grid_size=100,
                              cols=heat.colors (30), bg, size, shape)
{
    # ---------------  sanity checks and warnings  ---------------
    # --------- map
    if (missing (map))
        stop ('map must be supplied to add_osm_surface')
    if (!is (map, 'ggplot'))
        stop ('map must be a ggplot2 object')
    # --------- obj
    if (missing (obj))
        stop ('object must be supplied to add_osm_surface')
    if (!inherits (obj, 'Spatial'))
        stop ('obj must be a spatial object')
    # --------- dat
    if (missing (dat))
        stop ('dat must be supplied to add_osm_surface')
    else if (is.null (dat))
        stop ('dat can not be NULL')
    if (!is.numeric (as.matrix (dat)))
        stop ('dat must be a numeric matrix or data.frame')
    else 
    {
        dat <- as.matrix (dat)
        if (ncol (dat) < 3) stop ('dat must have at least 3 columns')
        wtxt <- paste0 ('dat should have columns of x/y, lon/lat, or equivalent;',
                        'presuming first 2 columns are lon, lat')
        if (is.null (colnames (dat)))
        {
            warning ('dat has no column names; presming [lon, lat, z]')
            colnames (dat) [1:3] <- c ('lon', 'lat', 'z')
        } else
        {
            n2 <- sort (colnames (dat) [1:2])
            if (!(n2 [1] == 'x' | n2 [1] == 'lat') ||
                !(n2 [2] == 'y' | n2 [2] == 'lon'))
            {
                warning ('dat should have columns of x/y, lon/lat, or equivalent;',
                         ' presuming first 2 columns are lon, lat')
                colnames (dat) [1:2] <- c ('x', 'y')
            }
            if (!'z' %in% colnames (dat))
            {
                warning ('dat should have column named z; ',
                         'presuming that to be 3rd column')
                colnames (dat) [3] <- 'z'
            }
        }
    }
    # --------- cols
    if (!(is.character (cols) | is.numeric (cols)))
    {
        warning ("cols will be coerced to character")
        cols <- as.character (cols)
    }
    # ---------------  end sanity checks and warnings  ---------------

    if (class (obj) == 'SpatialPolygonsDataFrame')
        objtxt <- c ('polygons', 'Polygons')
    else if (class (obj) == 'SpatialLinesDataFrame')
        objtxt <- c ('lines', 'Lines')
    else if (class (obj) == 'SpatialPointsDataFrame')
        objtxt <- c ('points', '')

    xrange <- map$coordinates$limits$x
    yrange <- map$coordinates$limits$y

    if (class (obj) == 'SpatialPointsDataFrame')
    {
        xy0 <- sp::coordinates (obj)
    } else
    {
        xylims <- lapply (slot (obj, objtxt [1]), function (i)
                          {
                              xyi <- slot (slot (i, objtxt [2]) [[1]], 'coords')
                              c (apply (xyi, 2, min), apply (xyi, 2, max))
                          })
        xylims <- do.call (rbind, xylims)
        indx <- which (xylims [,1] > xrange [1] & xylims [,2] > yrange [1] &
                       xylims [,3] < xrange [2] & xylims [,4] < yrange [2])
        obj <- obj [indx,]
        xy0 <- lapply (slot (obj, objtxt [1]), function (x)
                        slot (slot (x, objtxt [2]) [[1]], 'coords'))
    }
    xy0 <- structure (xy0, class=c (class (xy0), objtxt [1]))
    xy0 <- list2df_with_data (map, xy0, dat, bg, grid_size=grid_size,
                              method=method)
    if (missing (bg))
        xy <- xy0
    else
        xy <- xy0 [xy0$inp > 0, ]


    if (class (obj) == 'SpatialPolygonsDataFrame')
    {
        # TODO: Add border to geom_polygon call
        lon <- lat <- id <- z <- NULL # suppress 'no visible binding' error
        aes <- ggplot2::aes (x=lon, y=lat, group=id, fill=z) 
        if (missing (size))
            size <- 0
        if (length (size) == 1)
            size <- rep (size, 2) # else size [2] specifies bg size
        map <- map + ggplot2::geom_polygon (data=xy, mapping=aes, size=size [1]) +
                        ggplot2::scale_fill_gradientn (colours=cols) 

        if (!missing (bg))
        {
            xy <- xy0 [xy0$inp == 0, ]
            aes <- ggplot2::aes (x=lon, y=lat, group=id) 
            map <- map + ggplot2::geom_polygon (data=xy, mapping=aes, 
                                                size=size [2], fill=bg)
        }
    } else if (class (obj) == 'SpatialLinesDataFrame')
    {
        if (missing (size))
            size <- 0.5
        if (length (size) == 1)
            size <- rep (size, 2) # else size [2] specifies bg size
        if (missing (shape))
            shape <- 1
        if (length (shape) == 1)
            shape <- rep (shape, 2)
        aes <- ggplot2::aes (x=lon, y=lat, group=id, colour=z)
        map <- map + ggplot2::geom_path (data=xy, mapping=aes, 
                                         size=size [1], linetype=shape [1]) +
                        ggplot2::scale_colour_gradientn (colours=cols)

        if (!missing (bg))
        {
            xy <- xy0 [xy0$inp == 0, ]
            aes <- ggplot2::aes (x=lon, y=lat, group=id) 
            map <- map + ggplot2::geom_path (data=xy, mapping=aes, col=bg,
                                             size=size [2], linetype=shape [2])
        }
    } else if (class (obj) == 'SpatialPointsDataFrame')
    {
        if (missing (size))
            size <- 0.5
        if (length (size) == 1)
            size <- rep (size, 2) # else size [2] specifies bg size
        if (missing (shape))
            shape <- 1
        if (length (shape) == 1)
            shape <- rep (shape, 2)
        aes <- ggplot2::aes (x=lon, y=lat, group=id, colour=z)
        map <- map + ggplot2::geom_point (data=xy, mapping=aes, 
                                          size=size [1], shape=shape [1]) +
                        ggplot2::scale_colour_gradientn (colours=cols)

        if (!missing (bg))
        {
            xy <- xy0 [xy0$inp == 0,]
            aes <- ggplot2::aes (x=lon, y=lat, group=id)
            map <- map + ggplot2::geom_point (data=xy, mapping=aes, col=bg,
                                              size=size [2], shape=shape [2])
        }
    }

    return (map)
}



#' list2df_with_data
#'
#' Converts a list of spatial objects to a single data frame, and adds a
#' corresponding 'z' column provided by mapping mean object coordinates onto a
#' spatially interpolated version of 'dat'
#'
#' @param map A ggplot2 object (used only to obtain plot limits)
#' @param xy List of coordinates of spatial objects
#' @param dat A Matrix representing the data surface (which may be irregular)
#' used to provide the z-values for the resultant data frame.
#' @param bg background colour from 'add_osm_surface()', passed here only to
#' confirm whether it is given or missing
#' @param grid_size Size of interpolation grid as taken from 'add_osm_surface()'
#' @param method Either 'idw' (Inverse Distance Weighting as spatstat::idw;
#' default), otherwise uses 'Gaussian' for kernel smoothing (as
#' spatstat::Smooth.ppp)
#' @return A single data frame of object IDs, coordinates, and z-values
list2df_with_data <- function (map, xy, dat, bg, grid_size=100, method="idw")
{
    if ('z' %in% colnames (dat))
        z <- dat [,'z']
    else
        z <- dat [,3]
    if ('x' %in% colnames (dat))
        x <- dat [,'x']
    else
        x <- dat [,pmatch ('lon', colnames (dat))]
    if ('y' %in% colnames (dat))
        y <- dat [,'y']
    else
        y <- dat [,pmatch ('lat', colnames (dat))]
    xlims <- range (x) # used below to convert to indices into z-matrix
    ylims <- range (y)
    indx <- which (!is.na (z))
    x <- x [indx]
    y <- y [indx]
    marks <- z [indx]
    xyp <- spatstat::ppp (x, y, xrange=range (x), yrange=range(y), marks=marks)
    if (method == 'idw')
        z <- spatstat::idw (xyp, at="pixels", dimyx=grid_size)$v
    else if (method == 'smooth')
        z <- spatstat::Smooth (xyp, at="pixels", dimyx=grid_size, diggle=TRUE)$v
    else
    {
        # x and y might not necessarily be regular, so grid has to be manually
        # filled with z-values
        nx <- length (unique (x))
        ny <- length (unique (y))
        arr <- array (NA, dim=c (nx, ny))
        indx_x <- as.numeric (cut (x, nx))
        indx_y <- as.numeric (cut (y, ny))
        arr [(indx_y - 1) * nx + indx_x] <- z
        z <- t (arr )
        # z here, as for interp methods above, has
        # (rows,cols)=(vert,horizont)=c(y,x) so is indexed (x, y). To yield a
        # figure with horizontal x-axis, this is transformed below.
    }
    z <- t (z)

    # Get mean coordinates of each object in xy. 
    # TODO: Colour lines continuously according to the coordinates of each
    # segment?
    if ('polygons' %in% class (xy) | 'lines' %in% class (xy))
        xymn <- do.call (rbind, lapply (xy, colMeans))
    else if ('points' %in% class (xy))
        xymn <- xy
    else
        stop ('xy must be a spatial object')

    # Then remove any objects not in the convex hull of provided data
    indx <- rep (NA, length (xy))
    if (!missing (bg))
    {
        xyh <- spatstat::ppp (x, y, xrange=range (x), yrange=range (y))
        ch <- spatstat::convexhull (xyh)
        bdry <- cbind (ch$bdry[[1]]$x, ch$bdry[[1]]$y)

        indx <- apply (xymn, 1, function (x)
                   sp::point.in.polygon (x [1], x [2], bdry [,1], bdry [,2]))
        # indx = 0 for outside polygon
    } 

    # Include only those objects within the limits of the map
    indx_xy <- which (xymn [,1] >= map$coordinates$limits$x [1] &
                      xymn [,1] <= map$coordinates$limits$x [2] &
                      xymn [,2] >= map$coordinates$limits$y [1] &
                      xymn [,2] <= map$coordinates$limits$y [2])
    xymn <- xymn [indx_xy,]
    indx <- indx [indx_xy]
    # And reduce xy to that index
    c2 <- class (xy) [2]
    if ('points' %in% class (xy))
        xy <- xy [indx_xy,]
    else
        xy <- xy [indx_xy]
    xy <- structure (xy, class=c (class (xy), c2))

    # Convert to integer indices into z. z spans the range of data, not
    # necessarily the bbox
    if (method == 'idw' | method == 'smooth')
        nx <- ny <- grid_size
    xymn [,1] <- ceiling (nx * (xymn [,1] - xlims [1]) / diff (xlims))
    xymn [,2] <- ceiling (ny * (xymn [,2] - ylims [1]) / diff (ylims))

    if (missing (bg))
    {
        xymn [,1] [xymn [,1] < 1] <- 1
        xymn [,1] [xymn [,1] > nx] <- nx
        xymn [,2] [xymn [,2] < 1] <- 1
        xymn [,2] [xymn [,2] > ny] <- ny
    } else
    {
        xymn [,1] [xymn [,1] < 1] <- NA
        xymn [,1] [xymn [,1] > nx] <- NA
        xymn [,2] [xymn [,2] < 1] <- NA
        xymn [,2] [xymn [,2] > ny] <- NA
    }

    if ('polygons' %in% class (xy) | 'lines' %in% class (xy))
    {
        for (i in seq (xy))
            xy [[i]] <- cbind (i, xy [[i]], z [xymn [i, 1], xymn [i, 2]],
                               indx [i])
        # And rbind them to a single matrix. 
        xy <-  do.call (rbind, xy)
    } else # can only be points
    {
        indx2 <- (xymn [,2] - 1) * grid_size + xymn [,1]
        xy <- cbind (seq (dim (xy)[1]), xy, z [indx2], indx)
    }
    # And then to a data.frame, for which duplicated row names flag warnings
    # which are not relevant, so are suppressed by specifying new row names
    data.frame (
                id=xy [,1],
                lon=xy [,2],
                lat=xy [,3],
                z=xy [,4], 
                inp=xy [,5],
                row.names=1:nrow (xy)
                )
}
