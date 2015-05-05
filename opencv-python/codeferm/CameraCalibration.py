"""
Copyright (c) Steven P. Goldsmith. All rights reserved.

Created by Steven P. Goldsmith on March 30, 2015
sgoldsmith@codeferm.com
"""

import logging, sys, os, time, cv2, numpy, argparse, glob, pickle

"""Camera calibration.

You need at least 10 images that pass cv2.findChessboardCorners at varying
angles and distances from the camera. You must do this for each resolution you
wish to calibrate. Camera matrix and distortion coefficients are pickled to
files for later use with undistort.

--inmask = Input file mask
--outdir = Output dir for debug images
--pattern = cols,rows of chess board

@author: sgoldsmith

"""

def splitFileName(fileName):
    """Split full path into file name components"""  
    path, fileName = os.path.split(fileName)
    name, ext = os.path.splitext(fileName)
    return path, name, ext

def saveArray(fileName, array):
    """Pickle ndarray"""  
    output = open(fileName, 'wb')
    pickle.dump(array, output)
    output.close()

def loadArray(fileName, array):
    """Load pickled ndarray"""
    pklFile = open(fileName, 'rb')
    array = pickle.load(pklFile)
    pklFile.close()
    return array

def findCorners(image, patternSize):
    """Find chess board corners"""  
    squareSize = 1.0
    patternPoints = numpy.zeros((numpy.prod(patternSize), 3), numpy.float32)
    patternPoints[:,:2] = numpy.indices(patternSize).T.reshape(-1, 2)
    patternPoints *= squareSize
    found, corners = cv2.findChessboardCorners(image, patternSize)
    return found, corners, patternPoints

def getPoints(inMask, outDir, patternSize):
    """Process all images matching inMask and output debug images to outDir"""
    imageNames = glob.glob(inMask)
    objPoints = []
    imgPoints = []
    # Set the criteria for the cornerSubPix algorithm
    term = (cv2.TERM_CRITERIA_EPS+cv2.TERM_CRITERIA_COUNT, 30, 0.1)
    passed = 0
    # Process all images
    for fileName in imageNames:
        image = cv2.imread(fileName, 0)
        found, corners, patternPoints = findCorners(image, patternSize)
        # Found corners
        if found:
            logger.info("Chessboard found in: %s" % fileName)
            cv2.cornerSubPix(image, corners, (5, 5), (-1, -1), term)
            vis = cv2.cvtColor(image, cv2.COLOR_GRAY2BGR)
            # Draw the corners
            cv2.drawChessboardCorners(vis, patternSize, corners, found)
            path, name, ext = splitFileName(fileName)
            # Write off marked up images
            cv2.imwrite('%s/%s_output.bmp' % (outdir, name), vis)
            # Add image and object points to lists for calibrateCamera
            imgPoints.append(corners.reshape(-1, 2))
            objPoints.append(patternPoints)
            passed += 1          
        else:
            logger.error("Chessboard not found in: %s" % fileName)
    logger.info("Images passed cv2.findChessboardCorners: %d" % passed)
    # We assume all images the same size, so we use last one
    h, w = image.shape[:2]    
    return h, w, objPoints, imgPoints

def undistort(image, cameraMatrix, distCoefs):
    """Undistort image"""  
    h,  w = image.shape[:2]
    newCameraMtx, roi = cv2.getOptimalNewCameraMatrix(cameraMatrix, distCoefs, (w, h), 1, (w, h))
    # Undistort
    dst = cv2.undistort(image, cameraMatrix, distCoefs, None, newCameraMtx)
    # Crop the image
    x, y, w, h = roi
    dst = dst[y:y + h, x:x + w]
    return dst

def reprojectionError(objPoints, imgPoints, rVecs, tVecs, cameraMatrix, distCoefs):
    """Re-projection error gives a good estimation of just how exact the found parameters are. This should be as close to zero as possible."""
    totalError = 0
    totalPoints = 0  
    for i in xrange(len(objPoints)):
        reprojectedPoints, _ = cv2.projectPoints(objPoints[i], rVecs[i], tVecs[i], cameraMatrix, distCoefs)
        reprojectedPoints = reprojectedPoints.reshape(-1,2)
        totalError += numpy.sum(numpy.abs(imgPoints[i] - reprojectedPoints) **2)
        totalPoints += len(objPoints[i])        
    return numpy.sqrt(totalError / totalPoints)

def undistortAll(inMask, outDir, cameraMatrix, distCoefs):
    """Process all images matching inMask and output debug images to outDir"""
    imageNames = glob.glob(inMask)
    # Process all images
    for fileName in imageNames:
        image = cv2.imread(fileName, 0)
        dst = undistort(image, cameraMatrix, distCoefs)
        path, name, ext = splitFileName(fileName)
        cv2.imwrite('%s/%s_undistort_output.bmp' % (outDir, name), dst)
    
if __name__ == '__main__':
    # Configure logger
    logger = logging.getLogger("CameraCalibration")
    logger.setLevel("INFO")
    formatter = logging.Formatter("%(asctime)s %(levelname)-8s %(module)s %(message)s")
    handler = logging.StreamHandler(sys.stdout)
    handler.setFormatter(formatter)
    logger.addHandler(handler)
    parser = argparse.ArgumentParser(description='Calibrate camera using series of chessboards')
    # Add arguments
    parser.add_argument('-i', '--inmask', type=str, help='Mask used for input files', required=False)
    parser.add_argument('-o', '--outdir', type=str, help='Directory to send debug files', required=False)
    parser.add_argument('-p', '--pattern', type=str, help='Checcboard pattern cols,rows', required=False)
    # Array for all arguments passed to script
    args = parser.parse_args()
    inmask = args.inmask 
    outdir = args.outdir
    pattern = args.pattern
    # Handle defaults 
    if inmask == None:
        inmask = "../../resources/2015*.jpg"
    if outdir == None:
        outdir = "../../output/"
    if pattern == None:
        pattern = "7,5"
    logger.info("OpenCV %s" % cv2.__version__)
    logger.info("Input mask: %s" % inmask)
    logger.info("Output dir: %s" % outdir)
    patternSize = eval(pattern)
    start = time.time()
    h, w, objPoints, imgPoints = getPoints(inmask, outdir, patternSize)
    rms, cameraMatrix, distCoefs, rVecs, tVecs = cv2.calibrateCamera(objPoints, imgPoints, (w, h), None, None)
    error = reprojectionError(objPoints, imgPoints, rVecs, tVecs, cameraMatrix, distCoefs)
    logger.info("Mean reprojection error: %s" % error)
    undistortAll(inmask, outdir, cameraMatrix, distCoefs)
    # Pickle numpy arrays
    saveArray('%s/camera_matrix.pkl' % outdir, cameraMatrix)
    saveArray('%s/dist_coefs.pkl' % outdir, distCoefs)
    elapse = time.time() - start
    logger.info("RMS: %s" % rms)
    logger.info("Camera matrix: %s" % cameraMatrix)
    logger.info("Distortion coefficients: %s" % distCoefs.ravel())    
    logger.info("Elapse time: %4.2f seconds" % elapse)    