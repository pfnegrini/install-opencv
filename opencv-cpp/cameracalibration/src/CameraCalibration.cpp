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
	// Get list of files to process.
	vector<string> files = globVector(in_mask);
	for (size_t i = 0, max = files.size(); i != max; ++i) {
		cout << "File: " << files[i] << endl;
	}
	return return_val;
}
