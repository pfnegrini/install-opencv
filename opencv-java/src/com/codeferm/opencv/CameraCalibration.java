/*
 * Copyright (c) Steven P. Goldsmith. All rights reserved.
 *
 * Created by Steven P. Goldsmith on April 4, 2015
 * sgoldsmith@codeferm.com
 */
package com.codeferm.opencv;

import java.io.DataInputStream;
import java.io.DataOutputStream;
import java.io.File;
import java.io.FileInputStream;
import java.io.FileOutputStream;
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
 * you wish to calibrate. Camera matrix and distortion coefficients are written
 * to files for later use with undistort. This code is based on
 * http://computervisionandjava.blogspot.com/2013/10/camera-cailbration.html,
 * but follows Python code closely (hence the identical values returned).
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
	 * @param mat
	 *            Mat to delete.
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
	 * @param imagePoints
	 *            Image points.
	 * @return Mean reprojection error.
	 */
	public double reprojectionError(final List<Mat> objectPoints,
			final List<Mat> rVecs, final List<Mat> tVecs,
			final Mat cameraMatrix, final Mat distCoeffs,
			final List<Mat> imagePoints) {
		double totalError = 0;
		double totalPoints = 0;
		final MatOfPoint2f cornersProjected = new MatOfPoint2f();
		final MatOfDouble distortionCoefficients = new MatOfDouble(distCoeffs);
		for (int i = 0; i < objectPoints.size(); i++) {
			Calib3d.projectPoints((MatOfPoint3f) objectPoints.get(i),
					rVecs.get(i), tVecs.get(i), cameraMatrix,
					distortionCoefficients, cornersProjected);
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
	 * Undistort image.
	 * 
	 * @param image
	 *            Distorted image.
	 * @param cameraMatrix
	 *            Camera matrix.
	 * @param distCoeffs
	 *            Input vector of distortion coefficients.
	 * @return Undistorted image.
	 */
	public Mat undistort(final Mat image, final Mat cameraMatrix,
			final Mat distCoeffs) {
		final Mat newCameraMtx = Calib3d.getOptimalNewCameraMatrix(
				cameraMatrix, distCoeffs, image.size(), 0);
		final Mat mat = new Mat();
		Imgproc.undistort(image, mat, cameraMatrix, distCoeffs, newCameraMtx);
		return mat;
	}

	/**
	 * Process all images matching inMask and output undistorted images to
	 * outDir.
	 * 
	 * @param inMask
	 *            Mask used for input files.
	 * @param outDir
	 *            Output dir.
	 * @param cameraMatrix
	 *            Camera matrix.
	 * @param distCoeffs
	 *            Input vector of distortion coefficients.
	 * @throws IOException
	 *             Possible exception.
	 */
	public void undistortAll(final String inMask, final String outDir,
			final Mat cameraMatrix, final Mat distCoeffs) throws IOException {
		final File file = new File(inMask);
		// Get dir
		final File parentFile = new File(file.getParent());
		// Make it canonical
		final Path dir = Paths.get(parentFile.getCanonicalPath());
		// Get matching names from inMask
		try (final DirectoryStream<Path> stream = Files.newDirectoryStream(dir,
				file.getName())) {
			// Undistort all files
			for (final Path entry : stream) {
				final String fileName = String.format("%s/%s", dir,
						entry.getFileName());
				logger.log(Level.FINE,
						String.format("Reading image: %s", fileName));
				// Read in image unchanged
				final Mat mat = Imgcodecs.imread(fileName,
						Imgcodecs.CV_LOAD_IMAGE_UNCHANGED);
				final Mat undistort = undistort(mat, cameraMatrix, distCoeffs);
				// Get file name without extension
				final String[] tokens = Paths.get(fileName).getFileName()
						.toString().split("\\.");
				final String writeFileName = String.format(
						"%s%s-java-undistort.bmp", outDir, tokens[0]);
				logger.log(Level.FINE,
						String.format("Writing image: %s", writeFileName));
				// Write debug Mat to output dir
				Imgcodecs.imwrite(writeFileName, undistort);
				// Clean up
				deleteMat(mat);
				deleteMat(undistort);
			}
		}
	}

	/**
	 * Save Mat of type Double. This has to be done since FileStorage is not
	 * being generated with the OpenCV Java bindings. This method will be slow
	 * with large arrays, but since the calibration parameters are small it's no
	 * big deal.
	 * 
	 * @param mat
	 *            Mat to save.
	 * @param fileName
	 *            File to write.
	 */
	public void saveDoubleMat(final Mat mat, final String fileName) {
		logger.log(Level.FINE, String.format("Saving double Mat: %s", fileName));
		final long count = mat.total() * mat.channels();
		final double[] buff = new double[(int) count];
		mat.get(0, 0, buff);
		try (final DataOutputStream out = new DataOutputStream(
				new FileOutputStream(fileName))) {
			for (int i = 0; i < buff.length; ++i) {
				out.writeDouble(buff[i]);
			}
		} catch (IOException e) {
			logger.log(Level.SEVERE,
					String.format("Exception: %s", e.getMessage()));
		}
	}

	/**
	 * Load pre-configured Mat from a file.
	 * 
	 * @param mat
	 *            Mat configured the same as the saved Mat. This Mat will be
	 *            overwritten with the data in the file. This value is modified
	 *            by JNI code.
	 * @param fileName
	 *            File to read.
	 */
	public void loadDoubleMat(final Mat mat, final String fileName) {
		logger.log(Level.FINE,
				String.format("Loading double Mat: %s", fileName));
		final long count = mat.total() * mat.channels();
		final List<Double> list = new ArrayList<>();
		try (final DataInputStream in = new DataInputStream(
				new FileInputStream(fileName))) {
			// Read all Doubles into List
			for (int i = 0; i < count; ++i) {
				logger.log(Level.FINE, String.format("%d", i));
				list.add(in.readDouble());
			}
		} catch (IOException e) {
			if (e.getMessage() == null) {
				logger.log(Level.FINE,
						String.format("EOF reached for: %s", fileName));
			} else {
				logger.log(Level.SEVERE,
						String.format("Exception: %s", e.getMessage()));
			}
		}
		// Set byte array to size of List
		final double[] buff = new double[list.size()];
		// Convert to primitive array
		for (int i = 0; i < buff.length; i++) {
			buff[i] = list.get(i);
		}
		mat.put(0, 0, buff);
	}

	/**
	 * Load calibration Mats.
	 * 
	 * @param camMtxFileName
	 *            Camera matrix file name.
	 * @param distCoFileName
	 *            Distortion coefficients file name.
	 * @return Mat array consisting of cameraMatrix and distCoeffs.
	 */
	public Mat[] loadCalibrate(final String camMtxFileName,
			final String distCoFileName) {
		final Mat cameraMatrix = Mat.eye(3, 3, CvType.CV_64F);
		loadDoubleMat(cameraMatrix, camMtxFileName);
		final Mat distCoeffs = Mat.zeros(5, 1, CvType.CV_64F);
		loadDoubleMat(distCoeffs, distCoFileName);
		return new Mat[] { cameraMatrix, distCoeffs };
	}

	/**
	 * Calibrate camera. Caller needs to clean up cameraMatrix and distCoeffs
	 * Mats.
	 * 
	 * @param objectPoints
	 *            Object points.
	 * @param imagePoints
	 *            Image points.
	 * @param images
	 *            List of images to calibrate.
	 * @return Mat array consisting of cameraMatrix and distCoeffs.
	 */
	public Mat[] calibrate(final List<Mat> objectPoints,
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
		// Clean up lists
		for (final Mat mat : tVecs) {
			deleteMat(mat);
		}
		for (final Mat mat : rVecs) {
			deleteMat(mat);
		}
		return new Mat[] { cameraMatrix, distCoeffs };
	}

	/**
	 * Process all images matching inMask and output debug images to outDir. All
	 * Mats are deleted at the end, thus freeing native memory right away.
	 * 
	 * @param inMask
	 *            Mask used for input files.
	 * @param outDir
	 *            Output dir.
	 * @param patternSize
	 *            Checkerboard pattern cols,rows.
	 * @throws IOException
	 *             Possible exception.
	 */
	public void getPoints(final String inMask, final String outDir,
			final Size patternSize) throws IOException {
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
				// Process only images that pass getCorners
				if (getCorners(mat, patternSize, winSize, zoneSize, corners)) {
					logger.log(Level.FINE,
							String.format("Chessboard found in: %s", fileName));
					final Mat vis = new Mat();
					// Convert to color for drawing
					Imgproc.cvtColor(mat, vis, Imgproc.COLOR_GRAY2BGR);
					Calib3d.drawChessboardCorners(vis, patternSize, corners,
							true);
					// Get file name without extension
					final String[] tokens = Paths.get(fileName).getFileName()
							.toString().split("\\.");
					final String writeFileName = String.format(
							"%s/%s-java.bmp", outDir, tokens[0]);
					logger.log(Level.FINE, String.format(
							"Writing debug image: %s", writeFileName));
					// Write debug Mat to output dir
					Imgcodecs.imwrite(writeFileName, vis);
					// Clean up
					deleteMat(vis);
					// Add data collected to Lists
					objectPoints.add(corners3f);
					imagePoints.add(corners);
					images.add(mat);
					passed++;
				} else {
					logger.log(Level.WARNING, String.format(
							"Chessboard not found in: %s", fileName));
				}
			}
			logger.log(Level.INFO, String.format(
					"Images passed cv2.findChessboardCorners: %d", passed));
			// Calibrate camera
			final Mat[] params = calibrate(objectPoints, imagePoints, images);
			logger.log(Level.INFO, "Saving calibration parameters to file");
			// Save off camera matrix
			saveDoubleMat(params[0],
					String.format("%scamera-matrix.bin", outDir));
			// Save off distortion coefficients
			saveDoubleMat(params[1], String.format("%sdist-coefs.bin", outDir));
			// Clean up
			deleteMat(params[0]);
			deleteMat(params[1]);
			deleteMat(corners3f);
			// Clean up imagePoints
			for (Mat imagePoint : imagePoints) {
				deleteMat(imagePoint);
			}
			// Clean up images
			for (Mat image : images) {
				deleteMat(image);
			}
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
		logger.log(Level.INFO, "Calibrate camera from files");
		final long startTime = System.currentTimeMillis();
		cameraCalibration.getPoints(inMask, outDir, patternSize);
		logger.log(Level.INFO, "Restoring calibration parameters from file");
		final Mat[] calibrateArr = cameraCalibration.loadCalibrate(
				String.format("%scamera-matrix.bin", outDir),
				String.format("%sdist-coefs.bin", outDir));
		logger.log(Level.INFO,
				String.format("Camera matrix: %s", calibrateArr[0].dump()));
		logger.log(
				Level.INFO,
				String.format("Distortion coefficients: %s",
						calibrateArr[1].dump()));
		logger.log(Level.INFO, "Undistorting images");
		// Undistort all images
		cameraCalibration.undistortAll(inMask, outDir, calibrateArr[0],
				calibrateArr[1]);
		// Clean up
		cameraCalibration.deleteMat(calibrateArr[0]);
		cameraCalibration.deleteMat(calibrateArr[1]);
		final long estimatedTime = System.currentTimeMillis() - startTime;
		// CHECKSTYLE:OFF MagicNumber - Magic numbers here for illustration
		logger.log(Level.INFO, String.format("Elipse time: %4.2f seconds",
				(double) estimatedTime / 1000));
		// CHECKSTYLE:ON MagicNumber
	}
}
