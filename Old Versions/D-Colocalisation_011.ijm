//By Erik Späte @NAT MPG Göttingen, Department of Neurogenetics, UG Sandra Goebbels, 2022
//Input original image + folder for single channels + folder for median filtered channels.
//Quantifies DAPI, cellular staining and colocalisation with another staining.
//Outputs .csv files with number of cells (DAPI), number of labeled cells (eg. CA2), number of cells with coloc,
//and size of area that was quantified. Also saves the corresponding masks and ROIs.
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
//#@ String (label= "Include holes?", choices={" include ", " "}, style = "listBox") holes1
#@ Boolean (label = "Segment particles? (Note: Can take several minutes.);", style="Checkbox", value = true) segment1
#@ String (label="Rolling Ball Radius [µm^2] (~largest structure):", value="15") rbRadius1
#@ String (label="Minimum size [µm^2]:", value="30") minNucleusSize
#@ String (label="Maximum size [µm^2]:", value="Infinity") maxNucleusSize
#@ Float (label="Circularity (low = less stringent):", style="slider", min=0, max=1, stepSize=0.01) nucleusCircularity
#@ String (visibility=MESSAGE, value="----Cell----", required=false) msg2
#@ String (label="Cell type labeling", value="CA2") cellType
//#@ String (label= "Include holes?", choices={" ", " include "}, style = "listBox") holes2
#@ Boolean (label = "Segment particles? (Note: Can take several minutes.);", style="Checkbox", value = false) segment2
#@ String (label="Rolling Ball Radius [µm^2] (~largest structure):", value="15") rbRadius2
#@ String (label="Minimum size [µm^2]:", value="0") minCellSize
#@ String (label="Maximum size [µm^2]:", value="Infinity") maxCellSize
#@ Float (label="Circularity (low = less stringent):", style="slider", min=0, max=1, stepSize=0.01) cellCircularity
#@ String (visibility=MESSAGE, value="----Colabeling----", required=false) msg3
//#@ String (label= "Labeling form", choices={"Round", "Complex", "Punctuated"}, style = "listBox") cellForm
#@ String (label="Colocalisation labeling", value="LDHA") protein
//#@ String (label= "Include holes?", choices={" ", " include "}, style = "listBox") holes3
#@ Boolean (label = "Segment particles? (Note: Can take several minutes.);", style="Checkbox", value = false) segment3
#@ String (label="Rolling Ball Radius [µm^2] (~largest structure):", value="30") rbRadius3
#@ String (label="Minimum size [µm^2]:", value="0") minLabelingSize
#@ String (label="Maximum size [µm^2]:", value="Infinity") maxLabelingSize
#@ Float (label="Circularity (low = less stringent):", style="slider", min=0, max=1, stepSize=0.01) labelingCircularity
//#@ String (label= "Labeling form", choices={"Complex", "Round", "Punctuated"}, style = "listBox") labelingForm

holes1 = " inculde ";
holes2 = " inculde ";
holes3 = " inculde ";

//Output variables, to reduce line length
outputCSV = outputDir + File.separator + areaName + File.separator + "csv" + File.separator;
outputTIFF = outputDir + File.separator + areaName + File.separator + "tiff" + File.separator;
outputROI = outputDir + File.separator + areaName + File.separator + "ROI" + File.separator;
outputLogs = outputDir + File.separator + areaName + File.separator + "Logs" + File.separator;

//Set up new directories in output folder
newDir = newArray("ROI", "csv", "tiff", "Logs")
for (i = 0; i < newDir.length; i++) {
	if (File.isDirectory(outputDir + File.separator + areaName) == 0) {
		 File.makeDirectory(outputDir + File.separator + areaName);
	}
	if (File.isDirectory(outputDir + File.separator + areaName + File.separator + newDir[i]) == 0) {
		 File.makeDirectory(outputDir + File.separator + areaName + File.separator +  newDir[i]);
	}
}

//Set background & foreground colors to black
setForegroundColor(0, 0, 0);
setBackgroundColor(0, 0, 0);
//END --- General Settings

//START --- Functions
function segmentParticles(image){
	//Segments particles via a combination of watershed, dilate, and find maxima.
	//This helps when particles are close together and particle number is important.
	//Can take several minutes, depending on particle number.
	run("Duplicate...", "title=Segmenting...");
	run("Watershed");
	run("Median...", "radius=1");
	run("Watershed");
	run("Invert");
	run("Find Maxima...", "prominence=10 output=[Segmented Particles]");
	run("Invert");
	run("Create Selection");
	close("Segmenting...");
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

function quantifyLabeling(staining, minSize, maxSize, circularity, holes, segment){
	//Quantifies labeling area and particles.
	//Uses user input of minimal size and circularity to correctly identify particles.
	//If selected, segments particles with "segmentParticles" function. Note: Can take up to several minutes.
	//Can be repeated by user until quantification is aggreeable.
	repeatLoop = true;
	while (repeatLoop) {
		selectWindow(staining + "_" + areaName + "_raw");
		run("Duplicate...", "title=" + staining + "_raw");
		setAutoThreshold("Percentile dark");
		waitForUser("Adjust Threshold (" + staining + ").");
		run("Create Mask");
		rename(staining);
		
		if (segment) {
			segmentParticles(staining);
		}
		
		run("Analyze Particles...", "size=" + minSize + "-" + maxSize + " circularity=" + circularity + "-Infinity show=Masks display clear " + holes + "summarize");
		saveAs("Tiff", outputTIFF + "Mask-" + staining + "_" + areaName + "_" + filename);
		saveAs("Results", outputCSV + staining + "_" + areaName + "_" + fileNoExtension + ".csv");
		rename("Mask-" + staining);

		waitForUser("Check the segmentation.");
		run("Select None");
		repeatLoop = getBoolean("Is the quantification ok?", "No, repeat", "Yes, continue");
		if (repeatLoop) {
			close("Mask-" + staining);	
		}
	}
}

function removeBackground(staining, rbRadius){
	//Removes background by subtracting the median filtered image
	//Further removes background via imageJ function "Subtract Background".
	print("Open: " + singleChannels + File.separator + staining + "-" + filename);
	open(singleChannels + File.separator + staining + "-" + filename);
	rename(staining + "-All_raw");
	selectWindow(areaName);
	open(medianFilter + File.separator + "Filtered_" + staining + "-" + filename);
	print("Open: " + medianFilter + File.separator + "Filtered_" + staining + "-" + filename);
	rename("Background-" + staining);
	
	//Subtract filtered image from original
	imageCalculator("Subtract create", staining + "-All_raw", "Background-" + staining);
	
	//Select region for quantification
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


function quantifyColoc(staining1, staining2, minSize, maxSize, circularity) { 
//Quantifies colocalisation by overlapping the corresponding labeling masks
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
	run("Analyze Particles...", "size=0-" + maxSize + " show=Masks display clear include");
	run("Close-");
	run("Watershed");
	run("Analyze Particles...", "size=" + minSize + "-" + maxSize + " circularity=" + circularity + "-1.00 show=Masks display clear include summarize");
	saveAs("Results", outputCSV + staining2 + "+" + staining1 + "_" + areaName + "_" + fileNoExtension + ".csv");
	rename("Mask-" + staining2 + "+" + staining1);
}
//END --- Functions

//START --- Open image
run("Close All");
open(inputFile);
filename = getTitle();
fileNoExtension = File.nameWithoutExtension
//END

//START --- Log
print("\\Clear")
print(fileNoExtension);
print(areaName);
print("Nuclear Labeling: " + nucleus);
print("Rolling ball radius: " + rbRadius1);
print("Minimum size [µm^2]: " + minNucleusSize);
print("Circularity: " + nucleusCircularity);
print("Cellular Labeling: " + cellType);
print("Rolling ball radius: " + rbRadius2);
print("Minimum size [µm^2]: " + minCellSize);
print("Circularity: " + cellCircularity);
print("Coloc labeling: " + protein);
print("Rolling ball radius: " + rbRadius3);
print("Minimum size [µm^2]: " + minLabelingSize);
print("Circularity: " + labelingCircularity);
//END

//START --- Main Script
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
quantifyLabeling(nucleus, minNucleusSize, maxNucleusSize, nucleusCircularity, holes1, segment1);
quantifyLabeling(cellType, minCellSize, maxCellSize, cellCircularity, holes2, segment2);
quantifyLabeling(protein, minLabelingSize, maxLabelingSize, labelingCircularity, holes3, segment3);

//Quantify colocalisation
quantifyColoc(nucleus, cellType, minNucleusSize, maxNucleusSize, nucleusCircularity);
quantifyColoc(nucleus, protein, minNucleusSize, maxNucleusSize, nucleusCircularity);
quantifyColoc(cellType, protein, minCellSize, maxCellSize, cellCircularity);
quantifyColoc(nucleus, protein + "+" + cellType, minNucleusSize, maxNucleusSize, nucleusCircularity);

//Quantify total area
selectWindow(areaName);
run("Duplicate...", "title=Area duplicate channels=2");
roiManager("Fill");
run("Select None");
setAutoThreshold("Huang dark");
waitForUser("Adjust Threshold (Area)");
run("Make Binary");
run("Analyze Particles...", "show=Masks display clear exclude summarize");
saveAs("Tiff", outputTIFF + "Mask-totalArea_" + areaName + "_" + filename);
selectWindow("Results");
saveAs("Results", outputCSV + "totalArea_" + areaName + "_" + fileNoExtension + ".csv");

//Save summary
selectWindow("Summary");
saveAs("Results", outputCSV + "Summary_" + areaName + "_" + fileNoExtension + ".csv");
selectWindow("Log");
saveAs("Text", outputLogs + "Log_" + areaName + "_" + fileNoExtension + ".txt");

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