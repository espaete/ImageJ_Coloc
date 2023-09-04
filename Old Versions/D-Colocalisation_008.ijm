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
#@ String (visibility=MESSAGE, value="----Nucleus----", required=false) msg1
#@ String (label="Nuclear labeling:", value="DAPI") nucleus
#@ String (label="High frequency filter:", value="4") highFreq1
#@ Boolean (label = "Watershed?", style="Checkbox", value = true) watershed1
#@ String (label= "Include holes?", choices={" include ", " "}, style = "listBox") holes1
#@ String (label="Average size [µm^2]:", value="100") avgNucleusSize
#@ String (label="Minimum size [µm^2]:", value="30") minNucleusSize
#@ Float (label="Circularity (low = less stringent):", style="slider", min=0, max=1, stepSize=0.01) nucleusCircularity
#@ String (visibility=MESSAGE, value="----Cell----", required=false) msg2
#@ String (label="Cell type labeling", value="CA2") cellType
#@ String (label="High frequency filter:", value="0") highFreq2
#@ Boolean (label = "Watershed?", style="Checkbox", value = false) watershed2
#@ String (label= "Include holes?", choices={" ", " include "}, style = "listBox") holes2
#@ String (label="Average size [µm^2]:", value="100") avgCellSize
#@ String (label="Minimum size [µm^2]:", value="0") minCellSize
#@ Float (label="Circularity (low = less stringent):", style="slider", min=0, max=1, stepSize=0.01) cellCircularity
#@ String (visibility=MESSAGE, value="----Colabeling----", required=false) msg3
//#@ String (label= "Labeling form", choices={"Round", "Complex", "Punctuated"}, style = "listBox") cellForm
#@ String (label="Colocalisation labeling", value="LDHA") protein
#@ String (label="High frequency filter:", value="0") highFreq3
#@ Boolean (label = "Watershed?", style="Checkbox", value = false) watershed3
#@ String (label= "Include holes?", choices={" ", " include "}, style = "listBox") holes3
#@ String (label="Average size [µm^2]:", value="100") avgLabelingSize
#@ String (label="Minimum size [µm^2]:", value="0") minLabelingSize
#@ Float (label="Circularity (low = less stringent):", style="slider", min=0, max=1, stepSize=0.01) labelingCircularity
//#@ String (label= "Labeling form", choices={"Complex", "Round", "Punctuated"}, style = "listBox") labelingForm

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
function subtractMedianFilter(staining, minSize, avgSize, circularity, highFreq, watershed, holes){
	open(singleChannels + File.separator + staining + "-" + filename);
	rename(staining + "-All_raw");
	selectWindow(areaName);
	open(medianFilter + File.separator + "Filtered_" + staining + "-" + filename);
	rename("Background-" + staining);
	
	//Subtract filtered image from original
	imageCalculator("Subtract create", staining + "-All_raw", "Background-" + staining);
	
	//Select region of interest
	roiManager("Deselect");
	roiManager("Delete");
	roiManager("Open", outputROI + areaName + "-ROI_" + fileNoExtension + ".zip");
	roiManager("Select", 0);
	run("Duplicate...", "title=" + staining + "_" + areaName + "_raw");
	
	//Further reduce background
	rollRadius = parseInt(avgSize)/6;
	run("Subtract Background...", "rolling=" + rollRadius);
	
	//Cut out outside areas and artifacts
	roiManager("Deselect");
	roiManager("Delete");
	roiManager("Open", outputROI + areaName + "cutAreas-ROI_" + fileNoExtension + ".zip");
	roiManager("Fill");
	
	//Set threshold, repeat if results are not agreeable
	repeatLoop = true;
	while (repeatLoop) {
		selectWindow(staining + "_" + areaName + "_raw");
		run("Duplicate...", "title=" + staining + "_raw");
		setAutoThreshold("Percentile dark");
		waitForUser("Adjust Threshold (" + staining + ").");
		if(AF_True){
			run("Create Selection");
			roiManager("Add");
			AF_True = false;
			break
		}
		run("Select None");
		if (watershed) {
			selectWindow(staining + "_raw");
			run("Create Mask");
			run("Watershed");
			run("Median...", "radius=1");
			run("Watershed");
			run("Invert");
			waitForUser("Note: Next step (Segmentation), will take some time. Press OK to start.");
			run("Find Maxima...", "prominence=10 output=[Segmented Particles]");
			run("Invert");
			run("Create Selection");
			selectWindow(staining + "_raw");
			run("Create Mask");
			run("Close-");
			run("Dilate");
			run("Close-");
			run("Restore Selection");
			setBackgroundColor(255, 255, 255);
			run("Clear","slice");
			run("Select None");
			setBackgroundColor(0, 0, 0);
			run("Median...", "radius=1");
			run("Watershed");
		}
		rename(staining);
		run("Analyze Particles...", "size=" + minSize + "-Infinity circularity=" + circularity + "-Infinity show=Masks display clear " + holes + "summarize");
		saveAs("Tiff", outputTIFF + "Mask-" + staining + "_" + areaName + "_" + filename);
		saveAs("Results", outputCSV + staining + "_" + areaName + "_" + fileNoExtension + ".csv");
		rename("Mask-" + staining);

		waitForUser("Check the segmentation.");
		run("Select None");
		repeatLoop = getBoolean("Do you want to repeat the thresholding?", "Yes, repeat.", "No, go to next step.");
		if (repeatLoop) {
			close("Mask-" + staining);	
		}
	}
}


function colocMask(staining1,staining2, minSize, circularity) { 
// Creates cololacisation mask
	selectWindow("Mask-" + staining2);
	run("Select None");
	selectWindow("Mask-" + staining1);
	run("Select None");
	run("Invert");
	run("Create Selection");
	run("Select None");
	run("Invert");
	selectWindow("Mask-" + staining2);
	run("Duplicate...", "title=" + staining2 + "+" + staining1);
	run("Invert");
	run("Restore Selection");
	run("Clear", "slice");
	run("Select None");
	run("Invert");
	run("Analyze Particles...", "size=" + minSize + "-Infinity circularity=" + circularity + "-1.00 show=Masks display clear include summarize");	
	rename("Mask-" + staining2 + "+" + staining1);
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
if (AF_True) {
	subtractMedianFilter("LF");
}

//Select regions to cut out
selectWindow(areaName);
//
roiManager("Open", "/Volumes/Erik-MPI/LDHA+LDHB/IHC/CA2/LDHA/Overview/Quantification/0811/BrainStem/ROI/BrainStemcutAreas-ROI_0811_LDHA-555_CAII-633_001_Overview-10x.zip");
//
roiManager("Show All");
waitForUser("Select all regions that you don't(!) want to analzye and add them to the ROI manager [press t]");
roiManager("save", outputROI + areaName + "cutAreas-ROI_" + fileNoExtension + ".zip")

//Subtract Background and quantify stainings
subtractMedianFilter(nucleus, minNucleusSize,avgNucleusSize, nucleusCircularity, highFreq1, watershed1, holes1);
subtractMedianFilter(cellType, minCellSize, avgCellSize, cellCircularity, highFreq2, watershed2, holes2);
subtractMedianFilter(protein, minLabelingSize, minLabelingSize, labelingCircularity, highFreq3, watershed3, holes2);

//Quantify colocalisation
colocMask(nucleus, cellType, minNucleusSize, nucleusCircularity);
colocMask(nucleus, protein, minNucleusSize, nucleusCircularity);
colocMask(cellType, protein, minCellSize, cellCircularity);
colocMask(nucleus, protein + "+" + cellType, minNucleusSize, nucleusCircularity);

//Quantify size of ROI
selectWindow(areaName);
run("Duplicate...", "title=Area duplicate channels=2");
roiManager("Fill");
run("Select None");
setAutoThreshold("Huang dark");
waitForUser("Adjust Threshold (Area)");
run("Make Binary");
run("Analyze Particles...", "size=1000-Infinity show=Masks display clear exclude summarize");
saveAs("Tiff", outputTIFF + "Mask-totalArea_" + areaName + "_" + filename);
selectWindow("Results");
saveAs("Results", outputCSV + "totalArea_" + areaName + "_" + fileNoExtension + ".csv");

//Save summary
selectWindow("Summary");
saveAs("Results", outputCSV + "Summary_" + areaName + "_" + fileNoExtension + ".csv");

//Show double positive cells in original image
selectWindow("Mask-" + protein + "+" + cellType + "+" + nucleus);
run("Select None");
run("Create Selection");
selectWindow(areaName);
roiManager("Show None");
run("Restore Selection");

selectWindow("Summary_" + areaName + "_" + fileNoExtension + ".csv");

print(filename);
print("DONE!!!");