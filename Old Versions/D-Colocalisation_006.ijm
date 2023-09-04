//By Erik Späte @NAT MPG Göttingen, Department of Neurogenetics, UG Sandra Goebbels, 2022
//Input original tiff file that contains all channels + median filtered channel tiff file
//Quantifies DAPI, cellular staining and colocalisation with another staining.
//Outputs .csv files with number of cells (DAPI), number of labeled cells (eg. CA2), number of cells with coloc,
//and size of area that was quantified. Also saves the corresponding masks.
//Requires some manual input, eg. selecting ROIs and setting thresholds.
//End result should be checked for false positives!
//Good luck!!!

//START --- General Settings
//User Prompt
#@ String (label="Area Name (no blanks):") areaName
#@ File (label="Select file:", style = "file") inputFile
#@ File (label="Select directory containing background (Median filtered) images:", style = "directory") medianFilter
#@ File (label="Select directory containing single channel images:", style = "directory") singleChannels
#@ File (label="Select output directory:", style = "directory") outputDir
#@ Boolean (label = "Empty channel for autofluorescence?", style="Checkbox", value = TRUE) AF_True
#@ String (label="Cell type labeling, eg. CA2:") cellType
#@ String (label="Colocalisation labeling, eg. LDHA:") protein
#@ String (label="Minimum size in pixels (nucleus):", value="30") minCellSize
#@ Float (label="Circularity (low = less stringent):", style="slider", min=0, max=1, stepSize=0.01) cellCircularity

//Output variables, to reduce line length
outputCSV = outputDir + File.separator + areaName + File.separator + "csv" + File.separator;
outputTIFF = outputDir + File.separator + areaName + File.separator + "tiff" + File.separator;
outputROI = outputDir + File.separator + areaName + File.separator + "ROI" + File.separator;

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

//Open image
run("Close All");
open(inputFile);
filename = getTitle();
fileNoExtension = File.nameWithoutExtension

//Set background & foreground colors
setForegroundColor(0, 0, 0);
setBackgroundColor(0, 0, 0);

//END --- General Settings

//START --- Functions
function subtractMedianFilter(staining){
	open(singleChannels + File.separator + staining + "-" + filename);
	rename(staining + "_raw");
	selectWindow(areaName);
	open(medianFilter + File.separator + "Filtered_" + staining + "-" + filename);
	rename("Background-" + staining);
	
	//Subtract filtered image from original
	imageCalculator("Subtract create", staining + "_raw", "Background-" + staining);
	roiManager("Deselect");
	roiManager("Delete");
	roiManager("Open", outputROI + areaName + "-ROI_" + fileNoExtension + ".zip");
	roiManager("Select", 0);
	run("Duplicate...", "title=" + staining + "_" + areaName + "_raw");
	run("Subtract Background...", "rolling=4");
	roiManager("Deselect");
	roiManager("Delete");
	roiManager("Open", outputROI + areaName + "cutAreas-ROI_" + fileNoExtension + ".zip");
	roiManager("Fill");
	repeatLoop = true;
	while (repeatLoop) {
		selectWindow(staining + "_" + areaName + "_raw");
		run("Duplicate...", "title=" + staining + "_" + areaName);
		setAutoThreshold("Percentile dark");
		waitForUser("Adjust Threshold (" + staining + ").");
		if(AF_True){
			run("Create Selection");
			roiManager("Add");
			AF_True = false;
			break
		}
		run("Select None");
		selectWindow(staining + "_" + areaName);
		run("Analyze Particles...", "size=10-Infinity pixels show=Masks display clear");
		saveAs("Tiff", "Mask-" + staining + "_" + areaName + "_" + filename);
		rename("Mask-" + staining + "_" + areaName);
		
		waitForUser("Check the segmentation.")
		repeatLoop = getBoolean("Do you want to repeat the thresholding?", "Repeat", "Continue");
		if (repeatLoop) {
			close("Mask-" + staining + "_" + areaName);		
		}
	}
}

function colocMask(staining1,staining2) { 
// Creates cololacisation mask
	selectWindow("Mask-" + staining1 + "_" + areaName);
	run("Invert");
	run("Create Selection");
	run("Select None");
	run("Invert");
	selectWindow("Mask-" + staining2 + "_" + areaName);
	run("Duplicate...", "title=" + staining2 + "+" + staining1 + "_" + areaName);
	run("Invert");
	run("Restore Selection");
	run("Clear", "slice");
	run("Select None");
	run("Invert");
	rename(staining2 + "+" + staining1);
	run("Analyze Particles...", "size=" + minCellSize + "-Infinity circularity=" + cellCircularity + "-1.00 pixels show=Masks display clear include summarize");	
	rename("Mask-" + staining2 + "+" + staining1 + "_" + areaName);
}

//END --- Functions

//START --- Main Script
//Select region of interest and save as .tiff
run("ROI Manager...");
roiManager("reset");

//
roiManager("Open", "/Volumes/Erik-MPI/LDHA+LDHB/IHC/CA2/LDHA/Overview/Quantification/0811/BrainStem/ROI/BrainStem-ROI_0811_LDHA-555_CAII-633_001_Overview-10x.zip");
roiManager("Select", 0);
//
//waitForUser("Draw a rectangle over region of interest");
//roiManager("add");
roiManager("save selected", outputROI + areaName + "-ROI_" + fileNoExtension + ".zip");

//areaName = getString("Enter the area name:", "");	
run("Duplicate...", "title=" + areaName + " duplicate");
saveAs("Tiff", outputTIFF + areaName + "_" + filename);
rename(areaName);
close(filename);

//Identify autoflourescence
subtractMedianFilter("LF");


//Select regions to cut out
selectWindow(areaName);
//
roiManager("Open", "/Volumes/Erik-MPI/LDHA+LDHB/IHC/CA2/LDHA/Overview/Quantification/0811/BrainStem/ROI/BrainStemcutAreas-ROI_0811_LDHA-555_CAII-633_001_Overview-10x.zip");
//
roiManager("Show All");
waitForUser("Select all regions that you don't(!) want to analzye and add them to the ROI manager [press t]");
roiManager("save", outputROI + areaName + "cutAreas-ROI_" + fileNoExtension + ".zip")

//Quantify DAPI
subtractMedianFilter("DAPI");
run("Make Binary");
run("Watershed");
rename("DAPI");
run("Analyze Particles...", "size=" + minCellSize + "-Infinity circularity=" + cellCircularity + "-1.00 pixels show=Masks display clear include summarize");
saveAs("Results", outputCSV + "DAPI-" + areaName + "_" + fileNoExtension + ".csv");
saveAs("Tiff", outputTIFF + "Mask-" + "DAPI_" + areaName + "_" + filename);
rename("Mask-" + "DAPI_" + areaName);

subtractMedianFilter(cellType);
subtractMedianFilter(protein);

//Quantify colocalisation
colocMask("DAPI", cellType);
colocMask("DAPI", protein);
colocMask(protein + "+DAPI", cellType);

//Quantify area
selectWindow(areaName);
run("Duplicate...", "title=Area duplicate channels=2");
roiManager("Fill");
run("Select None");
setAutoThreshold("IsoData dark");
waitForUser("Adjust Threshold (Area)");
run("Analyze Particles...", "size=1000-Infinity show=Masks display clear exclude summarize");
saveAs("Tiff", outputTIFF + "Mask-totalArea_" + areaName + "_" + filename);
selectWindow("Results");
saveAs("Results", outputCSV + "totalArea_" + areaName + "_" + fileNoExtension + ".csv");

//Save masks
selectWindow("Mask-" + cellType + "+DAPI_" + areaName);
run("Invert");
run("Create Selection");
saveAs("Tiff", outputTIFF + "Mask-" + cellType + "+DAPI_" + areaName + "_" + filename);
selectWindow("Mask-" + protein + "_" + areaName);
run("Invert");
run("Create Selection");
saveAs("Tiff", outputTIFF + "Mask-" + protein + "_" + areaName + "_" + filename);

//Save summary
selectWindow("Summary");
saveAs("Results", outputCSV + "Summary_" + areaName + "_" + fileNoExtension + ".csv");

//Show double positive cells in original image
selectWindow("Mask-" + cellType + "+" + protein + "+DAPI_" + areaName);
run("Select None");
run("Create Selection");
selectWindow(areaName);
roiManager("Show None");
run("Restore Selection");

selectWindow("Summary_" + areaName + "_" + fileNoExtension + ".csv");

print(filename);
print("DONE!!!");