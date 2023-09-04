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
#@ String (visibility=MESSAGE, value="----Nucleus----", required=false) msg1
#@ String (label="Nuclear labeling:", value="DAPI") nucleus
#@ String (label= "Include holes?", choices={" include ", " "}, style = "listBox") holes1
#@ String (label="Rolling Ball Radius [µm^2] (~largest structure):", value="15") rbRadius1
#@ String (label="Minimum size [µm^2]:", value="30") minNucleusSize
#@ Float (label="Circularity (low = less stringent):", style="slider", min=0, max=1, stepSize=0.01) nucleusCircularity
#@ String (visibility=MESSAGE, value="----Cell----", required=false) msg2
#@ String (label="Cell type labeling", value="CA2") cellType
#@ String (label= "Include holes?", choices={" ", " include "}, style = "listBox") holes2
#@ String (label="Rolling Ball Radius [µm^2] (~largest structure):", value="15") rbRadius2
#@ String (label="Minimum size [µm^2]:", value="0") minCellSize
#@ Float (label="Circularity (low = less stringent):", style="slider", min=0, max=1, stepSize=0.01) cellCircularity
#@ String (visibility=MESSAGE, value="----Colabeling----", required=false) msg3
//#@ String (label= "Labeling form", choices={"Round", "Complex", "Punctuated"}, style = "listBox") cellForm
#@ String (label="Colocalisation labeling", value="LDHA") protein
#@ String (label= "Include holes?", choices={" ", " include "}, style = "listBox") holes3
#@ String (label="Rolling Ball Radius [µm^2] (~largest structure):", value="30") rbRadius3
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

//Set background & foreground colors
setForegroundColor(0, 0, 0);
setBackgroundColor(0, 0, 0);


//END --- General Settings

//START --- Functions
function segmentParticles(image){
	//Segments particles via a combination of watershed, dilate, and find maxima
	run("Duplicate...", "title=Segmenting...");
	run("Watershed");
	run("Median...", "radius=1");
	run("Watershed");
	run("Invert");
	run("Find Maxima...", "prominence=10 output=[Segmented Particles]");
	run("Invert");
	run("Create Selection");
	close("Segmenting");
	selectWindow(image);
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

function quantifyLabeling(staining, minSize, circularity, holes){
	//Set threshold, repeat if results are not agreeable
	repeatLoop = true;
	while (repeatLoop) {
		selectWindow(staining + "_" + areaName + "_raw");
		run("Duplicate...", "title=" + staining + "_raw");
		setAutoThreshold("Percentile dark");
		waitForUser("Adjust Threshold (" + staining + ").");
		run("Create Mask");
		rename(staining);
		
		segment=getBoolean("Segment particles? Note: Takes several minutes.", "Yes", "No");
		if (segment) {
			segmentParticles(staining);
		}
		
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

function removeBackground(staining, rbRadius){
	//Removes background by subtracting the median filtered image plus a rolling ball background subtraction
	print("Open: " + singleChannels + File.separator + staining + "-" + filename);
	open(singleChannels + File.separator + staining + "-" + filename);
	rename(staining + "-All_raw");
	selectWindow(areaName);
	open(medianFilter + File.separator + "Filtered_" + staining + "-" + filename);
	print("Open: " + medianFilter + File.separator + "Filtered_" + staining + "-" + filename);
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
	run("Subtract Background...", "rolling=" + rbRadius);
	
	//Cut out outside areas and artifacts
	roiManager("Deselect");
	roiManager("Delete");
	roiManager("Open", outputROI + areaName + "-CutAreas-ROI_" + fileNoExtension + ".zip");
	roiManager("Fill");
}


function quantifyColoc(staining1, staining2, minSize, circularity) { 
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
	saveAs("Results", outputCSV + staining2 + "+" + staining1 + "_" + areaName + "_" + fileNoExtension + ".csv"
	rename("Mask-" + staining2 + "+" + staining1);
}

//END --- Functions

//START --- Main Script
run("Close All");

//Open image
open(inputFile);
filename = getTitle();
fileNoExtension = File.nameWithoutExtension

//Select region of interest and save as .tiff
run("ROI Manager...");
roiManager("reset");

//
//roiManager("Open", "/Volumes/Erik-MPI/LDHA+LDHB/IHC/CA2/LDHA/Overview/Quantification/0811/BrainStem/ROI/BrainStem-ROI_0811_LDHA-555_CAII-633_001_Overview-10x.zip");
//roiManager("Select", 0);
//
waitForUser("Draw a rectangle over region of interest");
roiManager("add");
roiManager("save selected", outputROI + areaName + "-ROI_" + fileNoExtension + ".zip");
roiManager("delete");

run("Duplicate...", "title=" + areaName + " duplicate");
saveAs("Tiff", outputTIFF + areaName + "_" + filename);
rename(areaName);
close(filename);

//Select irrelevant regions to remove
selectWindow(areaName);
//
//roiManager("Open", "/Volumes/Erik-MPI/LDHA+LDHB/IHC/CA2/LDHA/Overview/Quantification/0811/BrainStem/ROI/BrainStemcutAreas-ROI_0811_LDHA-555_CAII-633_001_Overview-10x.zip");
//
roiManager("Show All");
waitForUser("Select all regions that you don't(!) want to analzye and add them to the ROI manager [press t]");
roiManager("save", outputROI + areaName + "-CutAreas-ROI_" + fileNoExtension + ".zip")

//Remove Background and irrelevant regions
removeBackground(nucleus, rbRadius1);
removeBackground(cellType, rbRadius2);
removeBackground(protein, rbRadius3);

//Quantify single labeling
quantifyLabeling(nucleus, minNucleusSize, nucleusCircularity, holes1);
quantifyLabeling(cellType, minCellSize, cellCircularity, holes2);
quantifyLabeling(protein, minLabelingSize, labelingCircularity, holes3);

//Quantify colocalisation
quantifyColoc(nucleus, cellType, minNucleusSize, nucleusCircularity);
quantifyColoc(nucleus, protein, minNucleusSize, nucleusCircularity);
quantifyColoc(cellType, protein, minCellSize, cellCircularity);
quantifyColoc(nucleus, protein + "+" + cellType, minNucleusSize, nucleusCircularity);

//Quantify total area
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