//By Erik Späte @NAT MPG Göttingen, Department of Neurogenetics, UG Sandra Goebbels, 2022
//Input original tiff file that contains all channels + median filtered channel tiff file
//Quantifies DAPI, cellular staining (First labeling) and colocalisation (First + Second staining).
//Outputs .csv files with number of cells (DAPI), number of labeled cells (eg. CA2), number of cells with coloc,
//and size of area that was quantified. Also saves the corresponding masks.
//Requires some manual input, eg. selecting ROI and setting thresholds.
//Good luck!!!

//User Prompt
#@ String (label="Area Name") areaName
#@ File (label="Select file:", style = "file") inputFile
#@ File (label="Select directory of background (Median filtered) images:", style = "directory") medianFilter
#@ File (label="Select output directory:", style = "directory") outputDir
#@ Boolean (label = "Empty channel for autofluorescence?", style="Checkbox", value = TRUE) autofluorescence
#@ String (label="First labeling, eg. CA2:") cellType
#@ Boolean (label = "Background subtraction with prefiltered image?", style="Checkbox", value = TRUE) firstBackground
#@ String (label="Second labeling, eg. LDHA:") protein
#@ Boolean (label = "Background subtraction with prefiltered image?", style="Checkbox", value = TRUE) secondBackground
#@ String (label="Median filter radius (First labeling):", value="4") medianRadiusCell
#@ String (label="Rolling ball radius (First labeling):", value="10") rollingBallRadiusCell
#@ String (label="Minimum size in µm^2 (First labeling):", value="30") minCellSize
#@ Float   (label="Circularity (First labeling)", style="slider", min=0, max=1, stepSize=0.01) cellCircularity

function subtractMedianFilter(staining, includeHoles){
	selectWindow(areaName);
	print(medianFilter + File.separator + "Filtered_" + staining + "-" + filename);
	open(medianFilter + File.separator + "Filtered_" + staining + "-" + filename);
	rename("BackgroundAll-" + staining);
	selectWindow(filename);
	selectWindow("BackgroundAll-" + staining);
	run("Restore Selection");
	waitForUser("Adjust ROI");
	run("Duplicate...", "title=Background-" + staining);
	
	//Subtract filtered image from original
	imageCalculator("Subtract create", staining + "_raw", "Background-" + staining);
	run("Subtract Background...", "rolling=" + rollingBallRadiusCell);
	roiManager("Fill");
	setAutoThreshold("Percentile dark");
	waitForUser("Adjust Threshold (" + staining + ")");
	run("Select None");
	selectWindow("Result of " + staining + "_raw");
	run("Analyze Particles...", "size=10-Infinity pixels show=Masks display clear " + includeHoles);
	//run("Mean...", "radius=2");
	//setThreshold(1,65535);
	//run("Analyze Particles...", "size=10-Infinity pixels show=Masks display clear " + includeHoles);
	rename("Mask-" + staining + "_" + areaName);
}

function subtractRollingBall(staining){
	
	run("Median...", "radius=" + medianRadiusCell);
	run("Subtract Background...", "rolling=" + rollingBallRadiusCell);
	roiManager("Fill");
	run("Select None");
	selectWindow(cellType + "_raw");
	run("Grays");
	run("Enhance Contrast", "saturated=0.35");
	setAutoThreshold("Triangle dark");
	waitForUser("Adjust threhsold (" + staining + ").");
	selectWindow(staining + "_raw");
	run("Select None");
	run("Create Mask");
	rename(staining);
	run("Watershed");
	run("Analyze Particles...", "size=" + minCellSize + "-Infinity circularity=" + cellCircularity +" -1.00 show=Masks display exclude clear include summarize");
}

//Set up new directories in output folder
newDir = newArray("ROI", "csv", "tiff")
for (i = 0; i < newDir.length; i++) {
	if (File.isDirectory(outputDir + File.separator + areaName) == 0) {
		 File.makeDirectory(outputDir + File.separator + areaName);
	}
	if (File.isDirectory(outputDir + File.separator + areaName + File.separator + newDir[i]) == 0) {
		 File.makeDirectory(outputDir + File.separator + areaName + File.separator +  newDir[i]);
	}
}
outputCSV = outputDir + File.separator + areaName + File.separator + "csv" + File.separator;
outputTIFF = outputDir + File.separator + areaName + File.separator + "tiff" + File.separator;

//Open image
run("Close All");
open(inputFile);
filename = getTitle();
fileNoExtension = File.nameWithoutExtension

//Set background & foreground colors
setForegroundColor(0, 0, 0);
setBackgroundColor(0, 0, 0);

//Select region of interest and save as .tiff
run("ROI Manager...");
deleteROIs = getBoolean("Do you want to delete ROIs from the ROI manager?", "Yes", "No");
if (deleteROIs) {
	roiManager("Deselect");
	roiManager("Delete");
}

waitForUser("Draw a rectangle over region of interest");
roiManager("add");
roiManager("save selected", outputDir + File.separator + "ROI" + File.separator + areaName + "_" + fileNoExtension + ".zip");

//areaName = getString("Enter the area name:", "");	
run("Duplicate...", "title=" + areaName + " duplicate");
saveAs("Tiff", outputTIFF + areaName + "_" + filename);
rename(areaName);

//Identify autoflourescence
if (autofluorescence) {
	selectWindow(areaName);
	run("Duplicate...", "title=AF_Raw duplicate channels=2");
	run("Median...", "radius=" + medianRadiusCell);
	run("Select None");
	setAutoThreshold("Shanbhag dark");
	roiManager("Show All");
	waitForUser("Adjust Threshold (Command+Shift+T), so it labels autofluorescence.");
	selectWindow("AF_Raw");
	run("Select None");
	run("Create Mask");
	rename("AF");
	run("Create Selection");
	roiManager("delete");
	roiManager("Add");
}


//Select regions to cut out
selectWindow(areaName);
waitForUser("Select regions to be cut out and add them to the ROI manager");
roiManager("save", outputDir + File.separator + "ROI"  + File.separator + areaName + "Cutouts_" + fileNoExtension + ".zip")

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
saveAs("Results", outputCSV + "DAPI_Cells_" + areaName + "_" + fileNoExtension + ".csv");
close("DAPI_raw");

//Quantify cellular labeling
selectWindow(areaName);
run("Select None");
run("Duplicate...", "title=" + cellType + "_raw duplicate channels=4");
if (firstBackground) {
	subtractMedianFilter(cellType, "");	
} else {
	subtractRollingBall(cellType)
}

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
selectWindow(areaName);
run("Select None");

selectWindow("Results");
saveAs("Results", outputCSV + cellType + "_Cells_" + areaName + "_" + fileNoExtension + ".csv");


//Quanfiy protein labeling, eg. LDHA
selectWindow(areaName);
run("Select None");
run("Duplicate...", "title=" + protein + "_raw duplicate channels=3");

if (secondBackground) {
	subtractMedianFilter(protein, "");	
} else {
	run("Median...", "radius=" + medianRadiusCell);
	run("Subtract Background...", "rolling=" + rollingBallRadiusCell);
	roiManager("Fill");
	run("Select None");
}

//Quantify colocalisation of first staining + DAPI -> single positive cells
selectWindow("Mask-DAPI_" + areaName);
run("Select None");
run("Duplicate...", "title=" + protein + "+DAPI");
selectWindow("Mask-" + protein + "_" + areaName);
run("Invert");
run("Create Selection");
selectWindow(protein + "+DAPI");
run("Restore Selection");
run("Clear", "slice");
setThreshold(1,65535);
run("Analyze Particles...", "size=10-Infinity pixels show=Masks display clear include summarize");
rename("Mask-" + protein + "+DAPI_" + areaName);

//Quanfiy Colocalisation of second staining +  first staining + DAPI -> double positive cells
selectWindow("Mask-" + cellType + "_" + areaName);
run("Select None");
run("Duplicate...", "title=Mask_" + protein + "+" + cellType);
run("Restore Selection");
run("Clear");
run("Select None");
run("Invert");
rename("Mask" + protein + "+" + cellType);
run("Analyze Particles...", "size=" + minCellSize + "-Infinity show=Masks display clear include");
saveAs("Tiff", outputTIFF + "Mask-" + protein + "+" + cellType + "+ DAPI_" + areaName + "_" + filename);
run("Invert");
run("Create Selection");
selectWindow(protein + "_raw");
rename(protein + "+" + cellType + "+DAPI");
run("Restore Selection");
run("Clear", "slice");
run("Select None");
setThreshold(1, 65535);
run("Analyze Particles...", "size=" + minCellSize + "-Infinity circularity=" + cellCircularity + "-1.00 show=Nothing display clear summarize");
selectWindow("Results");
saveAs("Results", outputCSV + protein + "+" + cellType + "+DAPI_" + areaName + "_" + fileNoExtension + ".csv");

//Quantify ROI area
selectWindow(areaName);
run("Duplicate...", "title=" + areaName + "-Area duplicate channels=2");
roiManager("Fill");
run("Select None");
setAutoThreshold("IsoData dark");
waitForUser("Adjust Threshold (Area)");
run("Analyze Particles...", "size=1000-Infinity show=Masks display clear exclude summarize");
saveAs("Tiff", outputTIFF + "Mask-totalArea_" + areaName + "_" + filename);
selectWindow("Results");
saveAs("Results", outputCSV + "totalArea_" + areaName + "_" + fileNoExtension + ".csv");

//Save masks
selectWindow("Mask-" + cellType + "_" + areaName);
run("Invert");
run("Create Selection");
saveAs("Tiff", outputTIFF + "Mask-" + cellType + "_" + areaName + "_" + filename);
selectWindow("Mask-" + protein + "_" + areaName);
run("Invert");
run("Create Selection");
saveAs("Tiff", outputTIFF + "Mask-" + protein + "_" + areaName + "_" + filename);

//Save summary
selectWindow("Summary");
saveAs("Results", outputCSV + "Summary_" + areaName + "_" + fileNoExtension + ".csv");

//Show quantification in original image
selectWindow("Mask-" + protein + "+" + cellType + "_" + areaName + "_" + filename);
run("Select None");
run("Invert");
run("Create Selection");
selectWindow(areaName);
roiManager("Show None");
run("Restore Selection");

print(filename);
print("DONE!!!");