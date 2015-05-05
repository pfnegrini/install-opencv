/*
 * Copyright (c) Steven P. Goldsmith. All rights reserved.
 *
 * Created by Steven P. Goldsmith on December 23, 2013
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
import org.opencv.imgproc.Imgproc;
import org.opencv.videoio.VideoCapture;
import org.opencv.videoio.VideoWriter;
import org.opencv.videoio.Videoio;

/**
 * Canny Edge Detector.
 *
 * args[0] = source file or will default to "../resources/traffic.mp4" if no
 * args passed.
 *
 * @author sgoldsmith
 * @version 1.0.0
 * @since 1.0.0
 */
final class Canny {
    /**
     * Logger.
     */
    // CHECKSTYLE:OFF ConstantName - Logger is static final, not a constant
    private static final Logger logger = Logger
            .getLogger(Canny.class.getName());
    // CHECKSTYLE:ON ConstantName
    /* Load the OpenCV system library */
    static {
        System.loadLibrary(Core.NATIVE_LIBRARY_NAME);
    }

    /**
     * Suppress default constructor for noninstantiability.
     */
    private Canny() {
        throw new AssertionError();
    }

    /**
     * Run Canny edge detection on all frames.
     *
     * args[0] = source file or will default to "../resources/traffic.mp4" if no
     * args passed.
     *
     * @param args
     *            String array of arguments.
     */
    public static void main(final String[] args) {
        String url = null;
        final String outputFile = "../output/canny-java.avi";
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
                    Canny.class.getClassLoader().getResourceAsStream(
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
        final FourCC fourCC = new FourCC("DIVX");
        VideoWriter videoWriter = new VideoWriter(outputFile, fourCC.toInt(),
                videoCapture.get(Videoio.CAP_PROP_FPS), frameSize, true);
        final Mat mat = new Mat();
        int frames = 0;
        final Mat gray = new Mat();
        final Mat blur = new Mat();
        final Mat edges = new Mat();
        final Mat dst = new Mat();
        final Size kSize = new Size(3, 3);
        final long startTime = System.currentTimeMillis();
        while (videoCapture.read(mat)) {
            // Convert the image to grayscale
            Imgproc.cvtColor(mat, gray, Imgproc.COLOR_BGR2GRAY);
            // Reduce noise with a kernel 3x3
            Imgproc.GaussianBlur(gray, blur, kSize, 0);
            // Canny detector
            // CHECKSTYLE:OFF MagicNumber - Magic numbers here for illustration
            Imgproc.Canny(blur, edges, 100, 200, 3, false);
            // CHECKSTYLE:ON MagicNumber
            // Add some colors to edges from original image
            Core.bitwise_and(mat, mat, dst, edges);
            videoWriter.write(dst);
            dst.release();
            frames++;
        }
        final long estimatedTime = System.currentTimeMillis() - startTime;
        logger.log(Level.INFO, String.format("%d frames", frames));
        // CHECKSTYLE:OFF MagicNumber - Magic numbers here for illustration
        logger.log(Level.INFO, String.format("Elipse time: %4.2f seconds",
                (double) estimatedTime / 1000));
        // CHECKSTYLE:ON MagicNumber
        // Release native memory
        mat.release();
        mat.delete();
        gray.release();
        gray.delete();
        blur.release();
        blur.delete();
        edges.release();
        edges.delete();
        dst.release();
        dst.delete();
    }
}
