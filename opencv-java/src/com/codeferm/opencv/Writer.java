/*
 * Copyright (c) Steven P. Goldsmith. All rights reserved.
 *
 * Created by Steven P. Goldsmith on December 29, 2013
 * sgoldsmith@codeferm.com
 */
package com.codeferm.opencv;

import java.io.IOException;
import java.util.logging.Level;
import java.util.logging.LogManager;
import java.util.logging.Logger;

import org.opencv.core.Core;
import org.opencv.core.Mat;
import org.opencv.core.Size;
import org.opencv.videoio.VideoCapture;
import org.opencv.videoio.VideoWriter;
import org.opencv.videoio.Videoio;

/**
 * Example of VideoWriter class.
 *
 * args[0] = source file or will default to "../resources/traffic.mp4" if no
 * args passed.
 *
 * The following codecs were tested using Gstreamer OpenCV backend (FourCC
 * value):
 *
 * Codec DIVX (avi), XVID (avi)
 *
 * @author sgoldsmith
 * @version 1.0.0
 * @since 1.0.0
 */
final class Writer {
	/**
	 * Logger.
	 */
	// CHECKSTYLE:OFF ConstantName - Logger is static final, not a constant
	private static final Logger logger = Logger.getLogger(Writer.class // NOPMD
			.getName());
	// CHECKSTYLE:ON ConstantName
	/* Load the OpenCV system library */
	static {
		System.loadLibrary(Core.NATIVE_LIBRARY_NAME); // NOPMD
	}

	/**
	 * Suppress default constructor for noninstantiability.
	 */
	private Writer() {
		throw new AssertionError();
	}

	/**
	 * Main method.
	 *
	 * args[0] = source file or will default to "../resources/traffic.mp4" if no
	 * args passed.
	 *
	 * @param args
	 *            Arguments passed.
	 */
	public static void main(final String[] args) {
		String url = null;
		final String outputFile = "../output/writer-java.avi";
		// Check how many arguments were passed in
		if (args.length == 0) {
			// If no arguments were passed then default to
			// ../resources/traffic.mp4
			url = "../resources/traffic.mp4";
		} else {
			url = args[0];
		}
		// Custom logging properties via class loader
		try {
			LogManager.getLogManager().readConfiguration(
					Writer.class.getClassLoader().getResourceAsStream(
							"logging.properties"));
		} catch (SecurityException | IOException e) {
			e.printStackTrace();
		}
		logger.log(Level.INFO, String.format("OpenCV %s", Core.VERSION));
		logger.log(Level.INFO, String.format("Input file: %s", url));
		logger.log(Level.INFO, String.format("Output file: %s", outputFile));
		VideoCapture videoCapture = new VideoCapture(url);
		final Size frameSize = new Size(
				(int) videoCapture.get(Videoio.CAP_PROP_FRAME_WIDTH),
				(int) videoCapture.get(Videoio.CAP_PROP_FRAME_HEIGHT));
		logger.log(Level.INFO, String.format("Resolution: %s", frameSize));
		final FourCC fourCC = new FourCC("XVID");
		VideoWriter videoWriter = new VideoWriter(outputFile, fourCC.toInt(),
				videoCapture.get(Videoio.CAP_PROP_FPS), frameSize, true);
		final Mat mat = new Mat();
		int frames = 0;
		final long startTime = System.currentTimeMillis();
		while (videoCapture.read(mat)) {
			videoWriter.write(mat);
			frames++;
		}
		final long estimatedTime = System.currentTimeMillis() - startTime;
		logger.log(Level.INFO, String.format("%d frames", frames));
		// CHECKSTYLE:OFF MagicNumber - Magic numbers here for illustration
		logger.log(Level.INFO, String.format("Elipse time: %4.2f seconds",
				(double) estimatedTime / 1000));
		// CHECKSTYLE:ON MagicNumber
		// Release native memory
		videoCapture.free();
		videoWriter.free();
		mat.free();
	}
}
