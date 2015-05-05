/*
 * Copyright (c) Steven P. Goldsmith. All rights reserved.
 *
 * Created by Steven P. Goldsmith on April 4, 2015
 * sgoldsmith@codeferm.com
 */
package com.codeferm.opencv;

import java.io.File;
import java.io.IOException;
import java.nio.file.DirectoryStream;
import java.nio.file.Files;
import java.nio.file.Path;
import java.nio.file.Paths;
import java.util.ArrayList;
import java.util.List;
import java.util.logging.Level;
import java.util.logging.LogManager;
import java.util.logging.Logger;

import org.opencv.calib3d.Calib3d;
import org.opencv.core.Core;
import org.opencv.core.CvType;
import org.opencv.core.Mat;
import org.opencv.core.MatOfDouble;
import org.opencv.core.MatOfPoint2f;
import org.opencv.core.MatOfPoint3f;
import org.opencv.core.Point3;
import org.opencv.core.Size;
import org.opencv.core.TermCriteria;
import org.opencv.imgcodecs.Imgcodecs;
import org.opencv.imgproc.Imgproc;

/**
 * Camera calibration.
 *
 * You need at least 10 images that pass cv2.findChessboardCorners at varying
 * angles and distances from the camera. You must do this for each resolution
 * you wish to calibrate. Camera matrix and distortion coefficients are pickled
 * to files for later use with undistort.
 *
 * args[0] = input file mask or will default to "../resources/2015*.jpg" if no
 * args passed.
 *
 * args[1] = output dir or will default to "../output/" if no args passed.
 *
 * args[2] = cols,rows of chess board or will default to "7,5" if no args
 * passed.
 *
 * @author sgoldsmith
 * @version 1.0.0
 * @since 1.0.0
 */
final class CameraCalibration {
	/**
	 * Logger.
	 */
	// CHECKSTYLE:OFF ConstantName - Logger is static final, not a constant
	private static final Logger logger = Logger
			.getLogger(CameraCalibration.class.getName());
	// CHECKSTYLE:ON ConstantName
	/**
	 * Set the criteria for the cornerSubPix algorithm.
	 */
	private static final TermCriteria CRITERIA = new TermCriteria(
			TermCriteria.EPS + TermCriteria.COUNT, 30, 0.1);
	/* Load the OpenCV system library */
	static {
		System.loadLibrary(Core.NATIVE_LIBRARY_NAME);
	}

	/**
	 * Clean up Mat the right way.
	 * 
	 * @param mat Mat to delete.
	 */
	public void deleteMat(final Mat mat) {
		mat.release();
		mat.delete();
	}

	/**
	 * Find chess board corners.
	 * 
	 * @param gray
	 *            Gray image.
	 * @param patternSize
	 *            Chess board pattern size.
	 * @param winSize
	 *            Window size.
	 * @param zoneSize
	 *            Zone size.
	 * @param corners
	 *            This value is modified by JNI code.
	 * @return Value of findChessboardCorners.
	 */
	public boolean getCorners(final Mat gray, final Size patternSize,
			final Size winSize, final Size zoneSize, final MatOfPoint2f corners) {
		boolean found = false;
		if (Calib3d.findChessboardCorners(gray, patternSize, corners)) {
			Imgproc.cornerSubPix(gray, corners, winSize, zoneSize, CRITERIA);
			found = true;
		}
		return found;
	}

	/**
	 * MatOfPoint3f corners.
	 * 
	 * @param patternSize
	 *            Chess board pattern size.
	 * @return Corners.
	 */
	public MatOfPoint3f getCorner3f(final Size patternSize) {
		final MatOfPoint3f corners3f = new MatOfPoint3f();
		final double squareSize = 50;
		final Point3[] vp = new Point3[(int) (patternSize.height * patternSize.width)];
		int cnt = 0;
		for (int i = 0; i < patternSize.height; ++i) {
			for (int j = 0; j < patternSize.width; ++j, cnt++) {
				vp[cnt] = new Point3(j * squareSize, i * squareSize, 0.0d);
			}
		}
		corners3f.fromArray(vp);
		return corners3f;
	}

	/**
	 * Re-projection error gives a good estimation of just how exact the found
	 * parameters are. This should be as close to zero as possible.
	 * 
	 * @param objectPoints
	 *            Object points.
	 * @param rVecs
	 *            Rotation vectors.
	 * @param tVecs
	 *            Translation vectors.
	 * @param cameraMatrix
	 *            Camera matrix.
	 * @param distCoeffs
	 *            Input vector of distortion coefficients.
	 * @return Mean reprojection error.
	 */
	public double reprojectionError(List<Mat> objectPoints, List<Mat> rVecs,
			List<Mat> tVecs, Mat cameraMatrix, Mat distCoeffs,
			List<Mat> imagePoints) {
		double totalError = 0;
		double totalPoints = 0;
		final MatOfPoint2f cornersProjected = new MatOfPoint2f();
		final MatOfDouble distortionCoefficients = new MatOfDouble(distCoeffs);
		for (int i = 0; i < objectPoints.size(); i++) {
			Calib3d.projectPoints((MatOfPoint3f) objectPoints.get(i),
					rVecs.get(i), tVecs.get(i), cameraMatrix,
					distortionCoefficients, (MatOfPoint2f) cornersProjected);
			final double error = Core.norm(imagePoints.get(i),
					cornersProjected, Core.NORM_L2);
			final int n = objectPoints.get(i).rows();
			totalError += error * error;
			totalPoints += n;
		}
		deleteMat(cornersProjected);
		deleteMat(distortionCoefficients);
		return Math.sqrt(totalError / totalPoints);
	}

	/**
	 * Calibrate camera.
	 * 
	 * @param objectPoints
	 *            Object points.
	 * @param imagePoints
	 *            Image points.
	 * @param images
	 *            List of images to calibrate.
	 */
	public void calibrate(final List<Mat> objectPoints,
			final List<Mat> imagePoints, final List<Mat> images) {
		final Mat cameraMatrix = Mat.eye(3, 3, CvType.CV_64F);
		final Mat distCoeffs = Mat.zeros(8, 1, CvType.CV_64F);
		final List<Mat> rVecs = new ArrayList<Mat>();
		final List<Mat> tVecs = new ArrayList<Mat>();
		final double rms = Calib3d.calibrateCamera(objectPoints, imagePoints,
				images.get(0).size(), cameraMatrix, distCoeffs, rVecs, tVecs);
		final double error = reprojectionError(objectPoints, rVecs, tVecs,
				cameraMatrix, distCoeffs, imagePoints);
		logger.log(Level.INFO,
				String.format("Mean reprojection error: %s", error));
		logger.log(Level.INFO, String.format("RMS: %s", rms));
		logger.log(Level.INFO,
				String.format("Camera matrix: %s", cameraMatrix.dump()));
		logger.log(Level.INFO,
				String.format("Distortion coefficients: %s", distCoeffs.dump()));
		deleteMat(cameraMatrix);
		deleteMat(distCoeffs);
	}

	/**
	 * Process all images matching inMask and output debug images to outDir.
	 * 
	 * @param inMask
	 * @param patternSize
	 * @throws IOException
	 */
	public void getPoints(final String inMask, final Size patternSize)
			throws IOException {
		final List<Mat> images = new ArrayList<Mat>();
		final List<Mat> objectPoints = new ArrayList<Mat>();
		final List<Mat> imagePoints = new ArrayList<Mat>();
		final MatOfPoint3f corners3f = getCorner3f(patternSize);
		final File file = new File(inMask);
		// Get dir
		final File parentFile = new File(file.getParent());
		// Make it canonical
		final Path dir = Paths.get(parentFile.getCanonicalPath());
		try (final DirectoryStream<Path> stream = Files.newDirectoryStream(dir,
				file.getName())) {
			int passed = 0;
			for (final Path entry : stream) {
				final String fileName = String.format("%s/%s", dir,
						entry.getFileName());
				// Read in image as gray scale
				final Mat mat = Imgcodecs.imread(fileName,
						Imgcodecs.CV_LOAD_IMAGE_GRAYSCALE);
				final MatOfPoint2f corners = new MatOfPoint2f();
				final Size winSize = new Size(5, 5);
				final Size zoneSize = new Size(-1, -1);
				if (getCorners(mat, patternSize, winSize, zoneSize, corners)) {
					logger.log(Level.INFO,
							String.format("Chessboard found in: %s", fileName));
					objectPoints.add(corners3f);
					imagePoints.add(corners);
					images.add(mat);
					passed++;
				} else {
					logger.log(Level.INFO, String.format(
							"Chessboard not found in: %s", fileName));
				}
			}
			logger.log(Level.INFO, String.format(
					"Images passed cv2.findChessboardCorners: %d", passed));
			calibrate(objectPoints, imagePoints, images);
		} catch (IOException e) {
			logger.log(Level.SEVERE,
					String.format("IO error: %s", e.getMessage()));
		}
	}

	/**
	 * Process all images in mask and compute camera matrix, distortion
	 * coefficients, etc. Debug images are sent to output dir.
	 *
	 * @param args
	 *            String array of arguments.
	 * @throws IOException
	 *             Possible exception.
	 */
	public static void main(final String[] args) throws IOException {
		String inMask = null;
		String outDir = null;
		Size patternSize = null;
		// Check how many arguments were passed in
		if (args.length == 3) {
			inMask = args[0];
			outDir = args[1];
			// Split into cols and rows "cols,rows"
			final String[] parts = args[3].split(",");
			patternSize = new Size(Integer.parseInt(parts[0]),
					Integer.parseInt(parts[1]));
			// Go with defaults
		} else {
			inMask = "../resources/2015*.jpg";
			outDir = "../output/";
			patternSize = new Size(7, 5);
		}
		// Custom logging properties via class loader
		try {
			LogManager.getLogManager().readConfiguration(
					CameraCalibration.class.getClassLoader()
							.getResourceAsStream("logging.properties"));
		} catch (SecurityException | IOException e) {
			e.printStackTrace();
		}
		logger.log(Level.INFO, String.format("OpenCV %s", Core.VERSION));
		logger.log(Level.INFO, String.format("Input mask: %s", inMask));
		logger.log(Level.INFO, String.format("Output dir: %s", outDir));
		CameraCalibration cameraCalibration = new CameraCalibration();
		cameraCalibration.getPoints(inMask, patternSize);
	}
}
