//By Erik Späte @NAT MPG Göttingen, Department of Neurogenetics, UG Sandra Goebbels, 2022
//Input original tiff file that contains all channels + median filtered channel tiff file
//Quantifies DAPI, cellular staining (First labeling) and colocalisation (First + Second staining).
//Outputs .csv files with number of cells (DAPI), number of labeled cells (eg. CA2), number of cells with coloc,
//and size of area that was quantified. Also saves the corresponding masks.
//Requires some manual input, eg. selecting ROI and setting thresholds.
//Good luck!!!

//User Prompt
#@ File (label="Select file:", style = "file") inputFile
#@ File (label="Select background (Median filtered) image:", style = "file") medianFilter
#@ File (label="Select output directory:", style = "directory") outputDir
#@ String (label="First labeling, eg. CA2:") cellType
#@ String (label="Second labeling, eg. LDHA:") protein
#@ String (label="Median filter radius (First labeling):", value="4") medianRadiusCell
#@ String (label="Rolling ball radius (First labeling):", value="10") rollingBallRadiusCell
#@ String (label="Minimum size in µm^2 (First labeling):", value="30") minCellSize
#@ Float   (label="Circularity (First labeling)", style="slider", min=0, max=1, stepSize=0.01) cellCircularity

//Set up new directories in output folder
newDir = newArray("csv", "tif")
for (i = 0; i < newDir.length; i++) {
	if (File.isDirectory(outputDir + File.separator + newDir[i]) == 0) {
		 File.makeDirectory(outputDir + File.separator + newDir[i]);
	}	
}

//Open image
run("Close All");
open(inputFile);
filename = getTitle();

//Set background & foreground colors
setForegroundColor(0, 0, 0);
setBackgroundColor(0, 0, 0);

//Select region of interest and save as .tiff
waitForUser("Draw a rectangle over region of interest");
areaName = getString("Enter the area name:", "");	
run("Duplicate...", "title=" + areaName + " duplicate");
saveAs("Tiff", outputDir + File.separator + areaName + "_" + filename);
rename(areaName);

//Identify autoflourescence
selectWindow(areaName);
run("Duplicate...", "title=AF_Raw duplicate channels=2");
run("Median...", "radius=" + medianRadiusCell);
run("Select None");
setAutoThreshold("Shanbhag dark");
run("ROI Manager...");
roiManager("Show All");
waitForUser("Adjust Threshold (Command+Shift+T), so it labels autofluorescence.");
selectWindow("AF_Raw");
run("Select None");
run("Create Mask");
rename("AF");
run("Create Selection");
roiManager("Add");

//Select regions to cut out
selectWindow(areaName);
waitForUser("Select regions to be cut out and add them to the ROI manager");

//Quantify DAPI
run("Select None");
run("Duplicate...", "title=DAPI_raw duplicate channels=1");
run("Median...", "radius=" + medianRadiusCell);
run("Subtract Background...", "rolling=" + rollingBallRadiusCell);

roiManager("Fill");
run("Select None");
while (true) {
	selectWindow("DAPI_raw");
	run("Grays");
	setAutoThreshold("Triangle dark");
	waitForUser("Adjust threhsold (DAPI).");
	selectWindow("DAPI_raw");
	run("Select None");
	run("Create Mask");
	rename("DAPI");
	run("Watershed");
	run("Analyze Particles...", "size=" + minCellSize + "-Infinity circularity=" + cellCircularity + "-1.00 show=Masks display exclude clear include summarize");
	rename("Mask-DAPI_" + areaName);
	close("DAPI");
	waitForUser("Check the segmentation.");
	repeatLoop = getBoolean("Do you want to repeat the thresholding?", "Repeat", "Continue");
	if (repeatLoop) {
		close("Mask-DAPI_" + areaName);
		continue		
	}else {
		break
	}
}

selectWindow("Results");
saveAs("Results", outputDir + File.separator + cellType + "_Cells_" + areaName + "_" + filename + ".csv");
close("DAPI_raw");

//Quantify cell bodies of cellType, eg. CA2
selectWindow(areaName);
run("Duplicate...", "title=" + cellType + "_raw duplicate channels=4");
run("Median...", "radius=" + medianRadiusCell);
run("Subtract Background...", "rolling=" + rollingBallRadiusCell);
roiManager("Fill");
run("Select None");
while (true) {
	selectWindow(cellType + "_raw");
	run("Grays");
	run("Enhance Contrast", "saturated=0.35");
	setAutoThreshold("Triangle dark");
	waitForUser("Adjust threhsold (" + cellType + ").");
	selectWindow(cellType + "_raw");
	run("Select None");
	run("Create Mask");
	rename(cellType);
	run("Watershed");
	run("Analyze Particles...", "size=" + minCellSize + "-Infinity circularity=" + cellCircularity +" -1.00 show=Masks display exclude clear include summarize");
	run("Invert");
	rename("Mask-" + cellType + "_" + areaName);
	selectWindow("Mask-DAPI_" + areaName);
	run("Invert");
	run("Create Selection");
	selectWindow("Mask-" + cellType + "_" + areaName);
	run("Restore Selection");
	run("Clear", "slice");
	run("Select None");
	run("Create Selection");
	selectWindow(areaName);
	run("Restore Selection");
	selectWindow("Mask-" + cellType + "_" + areaName);
	run("Select None");
	selectWindow(areaName);
	close(cellType);
	waitForUser("Check the segmentation.");
	repeatLoop = getBoolean("Do you want to repeat the thresholding?", "Repeat", "Continue");
	if (repeatLoop) {
		close("Mask-" + cellType + "-" + areaName);
		selectWindow(areaName);
		run("Select None");
		continue		
	}else {
		selectWindow(areaName);
		run("Select None");
		break
	}
}
selectWindow("Results");
saveAs("Results", outputDir + File.separator + cellType + "_Cells_" + areaName + "_" + filename + ".csv");
close(cellType + "_raw");


//Quanfiy protein labeling, eg. LDHA
selectWindow(areaName);
run("Select None");
run("Duplicate...", "title=" + protein + "_raw duplicate channels=3");
open(medianFilter);
rename("BackgroundAll");
selectWindow(filename);
selectWindow("BackgroundAll");
run("Restore Selection");
run("Duplicate...", "title=Background");
saveAs("Tiff", outputDir + File.separator + "MedianFilter-" + areaName + "-" + filename);
rename("Background");

//Subtract filtered image from original
imageCalculator("Subtract create", protein + "_raw", "Background");
roiManager("Fill");
setAutoThreshold("Percentile dark");
waitForUser("Adjust Threshold (" + protein + ")");
run("Select None");
selectWindow("Result of " + protein + "_raw");
run("Analyze Particles...", "size=10-Infinity pixels show=Masks display clear include");
run("Mean...", "radius=2");
setThreshold(1,65535);
run("Analyze Particles...", "size=10-Infinity pixels show=Masks display clear include");
rename("Mask-" + protein + "_" + areaName);

//Quantify staining 1 + DAPI colocalisation -> single positive cells
selectWindow("Mask-DAPI_" + areaName);
run("Select None");
run("Duplicate...", "title=" + protein + "+DAPI");
selectWindow("Mask-" + protein + "_" + areaName);
run("Invert");
run("Create Selection");
selectWindow(protein + "+DAPI");
run("Restore Selection");
run("Clear", "slice");

//Quanfiy staining 2 + staining 1 + DAPI colocalisation -> double positive cells
selectWindow("Mask-" + cellType + "_" + areaName);
run("Select None");
run("Duplicate...", "title=Mask_" + protein + "+" + cellType);
run("Restore Selection");
run("Clear");
run("Select None");
run("Invert");
rename("Mask" + protein + "+" + cellType);
run("Analyze Particles...", "size=" + minCellSize + "-Infinity show=Masks display clear include");
saveAs("Tiff", outputDir + File.separator + "Mask-" + protein + "+" + cellType + "_" + areaName + "_" + filename);
run("Invert");
run("Create Selection");
selectWindow(protein + "_raw");
rename(protein + "+" + cellType);
run("Restore Selection");
run("Clear", "slice");
run("Select None");
setThreshold(1, 65535);
run("Analyze Particles...", "  show=Nothing display clear summarize");
selectWindow("Results");
saveAs("Results", outputDir + File.separator + protein + "+" + cellType + "_Cells_" + areaName + "_" + filename + ".csv");

//Quantify ROI area
selectWindow(areaName);
run("Duplicate...", "title=" + areaName + "-Area duplicate channels=2");
roiManager("Fill");
run("Select None");
setAutoThreshold("IsoData dark");
waitForUser("Adjust Threshold (Area)");
run("Analyze Particles...", "size=1000-Infinity show=Masks display clear exclude summarize");
saveAs("Tiff", outputDir + File.separator + "Mask-totalArea_" + areaName + "_" + filename);
selectWindow("Results");
saveAs("Results", outputDir + File.separator + "totalArea_" + areaName + "_" + filename + ".csv");

//Save masks
selectWindow("Mask-" + cellType + "_" + areaName);
run("Invert");
run("Create Selection");
saveAs("Tiff", outputDir + File.separator + "Mask-" + cellType + "_" + areaName + "_" + filename);
selectWindow("Mask-" + protein + "_" + areaName);
run("Invert");
run("Create Selection");
saveAs("Tiff", outputDir + File.separator + "Mask-" + protein + "_" + areaName + "_" + filename);

//Save summary
selectWindow("Summary");
saveAs("Results", outputDir + File.separator + "Summary_" + areaName + "_" + filename + ".csv");

//Show quantification in original image
selectWindow("Mask-" + protein + "+" + cellType + "_" + areaName + "_" + filename);
run("Select None");
run("Invert");
run("Create Selection");
selectWindow(areaName);
run("Restore Selection");

print(filename);
print("DONE!!!");