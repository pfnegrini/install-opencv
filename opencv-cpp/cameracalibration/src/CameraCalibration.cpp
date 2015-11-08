/*
 * Copyright (c) Steven P. Goldsmith. All rights reserved.
 *
 * Created by Steven P. Goldsmith on November 6, 2015
 * sgoldsmith@codeferm.com
 */

#include <glob.h>
#include <iostream>
#include <sys/time.h>
#include <sstream>
#include <vector>
#include <opencv2/opencv.hpp>

using namespace std;
using namespace cv;

/**
 * Set the criteria for the cornerSubPix algorithm.
 */
static const TermCriteria CRITERIA = TermCriteria(
		TermCriteria::EPS + TermCriteria::COUNT, 30, 0.1);
/**
 * Return vector of sting containing list of files names matching pattern.
 */
vector<string> globVector(const string& pattern) {
	glob_t glob_result;
	glob(pattern.c_str(), GLOB_TILDE, NULL, &glob_result);
	vector<string> files;
	for (unsigned int i = 0; i < glob_result.gl_pathc; ++i) {
		files.push_back(string(glob_result.gl_pathv[i]));
	}
	globfree(&glob_result);
	return files;
}

/**
 * Find chess board corners.
 */
vector<Point2f> getCorners(Mat gray, Size pattern_size, Size win_size, Size zone_size) {
	vector<Point2f> corners;
	if (findChessboardCorners(gray, pattern_size, corners)) {
		cornerSubPix(gray, corners, win_size, zone_size, CRITERIA);
	}
	return corners;
}

/**
 * Point3f corners.
 */
vector<Point3f> getCorner3f(Size pattern_size) {
	vector<Point3f> corners3f(pattern_size.height * pattern_size.width);
	double squareSize = 50;
	int cnt = 0;
	for (int i = 0; i < pattern_size.height; ++i) {
		for (int j = 0; j < pattern_size.width; ++j, cnt++) {
			corners3f[cnt] = Point3f(j * squareSize, i * squareSize, 0.0);
		}
	}
	return corners3f;
}

/**
 * Process all images matching inMask and output debug images to outDir.
 */
void getPoints(string in_mask, string out_dir, Size pattern_size) {
	vector<Point3f> corners3f = getCorner3f(pattern_size);
	// Get list of files to process.
	vector<string> files = globVector(in_mask);
	vector<vector<Point3f> > object_points(files.size());
	vector<vector<Point2f> > image_points(files.size());
	vector<Mat> images(files.size());
	int passed = 0;
	for (size_t i = 0, max = files.size(); i != max; ++i) {
		Mat mat = imread(files[i], CV_LOAD_IMAGE_GRAYSCALE);
		vector<Point2f> corners;
		Size win_size = Size(5, 5);
		Size zone_size = Size(-1, -1);
		corners = getCorners(mat, pattern_size, win_size, zone_size);
		// Process only images that pass getCorners
		if (!corners.empty()) {
			cout << "Chessboard found in: " << files[i] << endl;
			Mat vis;
			// Convert to color for drawing
			cvtColor(mat, vis, COLOR_GRAY2BGR);
			drawChessboardCorners(vis, pattern_size, corners, true);
			// Get just file name from path
			string just_file_name = files[i].substr(
					files[i].find_last_of("/") + 1, files[i].length());
			// File name to write to
			string write_file_name = out_dir
					+ just_file_name.substr(0, just_file_name.find_last_of("."))
					+ "-cpp.bmp";
			imwrite(write_file_name, vis);
			object_points[i] = corners3f;
			image_points[i] = corners;
			images[i] = mat;
			passed++;
		} else {
			cout << "Chessboard not found in: " << files[i] << endl;
		}
	}
}

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
 * argv[1] = input file mask or will default to "../../resources/2015*.jpg" if no
 * args passed.
 *
 * argv[2] = output dir or will default to "../../output/" if no args passed.
 *
 * argv[3]] = cols,rows of chess board or will default to "7,5" if no args
 * passed.
 *
 * @author sgoldsmith
 * @version 1.0.0
 * @since 1.0.0
 */
int main(int argc, char *argv[]) {
	cout << CV_VERSION << endl;
	int return_val = 0;
	string in_mask;
	string out_dir;
	Size pattern_size;
	// Parse args
	if (argc == 4) {
		in_mask = argv[1];
		out_dir = argv[2];
		stringstream ss(argv[3]);
		vector<int> result(2);
		int i = 0;
		// Parse width and height "7,5" for example
		while (ss.good()) {
			string substr;
			getline(ss, substr, ',');
			result[i++] = atoi(substr.c_str());
		}
		pattern_size = Size(result[0], result[1]);
	} else {
		in_mask = "../../resources/2015*.jpg";
		out_dir = "../../output/";
		pattern_size = Size(7, 5);
	}
	cout << "Input mask: " << in_mask << endl;
	cout << "Output dir: " << out_dir << endl;
	cout << "Pattern size: " << pattern_size << endl;
	getPoints(in_mask, out_dir, pattern_size);
	return return_val;
}
