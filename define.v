//define of pixel formats.

/**
 * 4:4:4 chrominance subsampling (no chrominance subsampling).  The JPEG or
 * YUV image will contain one chrominance component for every pixel in the
 * source image.
 */
`define SAMP_444 0
//0 2 1 3 1 3

/**
  * 4:2:2 chrominance subsampling.  The JPEG or YUV image will contain one
  * chrominance component for every 2x1 block of pixels in the source image.
  */
`define SAMP_422 1
//0 2 0 2 1 3 1 3

/**
  * 4:2:0 chrominance subsampling.  The JPEG or YUV image will contain one
  * chrominance component for every 2x2 block of pixels in the source image.
  */
`define SAMP_420 2
//0 2 0 2 0 2 0 2 1 3 1 3

/**
 * Grayscale.  The JPEG or YUV image will contain no chrominance components.
 */
`define SAMP_GRAY 3
//0 2
