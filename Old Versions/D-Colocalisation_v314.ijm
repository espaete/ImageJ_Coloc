//By Erik Späte @NAT MPG Göttingen, Department of Neurogenetics, UG Sandra Goebbels, 2022
//Input original image + folder for single channels + folder for median filtered channels.
//Analyzes single or multi channel images.
//Segments image into particles using wide variaty of user set settings. 
//Recursive thresholding enables segmentation of similarly sized particles of widely varying fluorescence.
//Counts, measures and colocalizes particles automatically.
//Marks colocalized particles in image for user verification.
//Good luck!!!

//---FUNCTIONS---
//Remove Background and artifacts
function removeBackground(staining, channelNr, rbSubtraction, subtractTimes){
	//Removes background by subtracting the median filtered image
	//Further removes background via imageJ function "Subtract Background".
	if(staining != ""){
		close(staining  + "_raw");
		close("Background-" + staining);
		selectWindow("C" + channelNr + "-Staining");
		run("Select None");
		run("Duplicate...", "title=" + staining  + "_raw");
		if (rbSubtraction){
			Dialog.create("BackgroundRemoval Settings");
				Dialog.addString("Rolling ball radius", "0");
			Dialog.show();
			rbRadius = Dialog.getString();
		}
		close(staining + "_noBG");
		run("Duplicate...","title=" + staining + "_noBG");
		if(subtractTimes){
			open(medianFilter + File.separator + "Filtered_" + staining + "-" + filename);
			duplicateROI("Background-" + staining);
			
			//Subtract filtered image from original
			for (i = 0; i < subtractTimes; i++) {
				imageCalculator("Subtract ", staining + "_noBG", "Background-" + staining);
			}
			close("Filtered_" + staining + "-" + filename);
		}

		//Further reduce background
		if (rbSubtraction){
			run("Subtract Background...", "rolling=" + rbRadius);
		}
		//rename(staining + "_noBG");
		if(roiManager("count") > 0){
			roiManager("deselect");
			roiManager("delete");
		}
		//Cut out outside areas and artifacts
		if(File.exists(outputROI + subfolder + "-CutAreas-ROI_" + fileNoExtension + ".zip")){
			roiManager("Open", outputROI + subfolder + "-CutAreas-ROI_" + fileNoExtension + ".zip");
			setForegroundColor(0, 0, 0);
			roiManager("Fill");
			run("Select None");
			roiManager("deselect");
			roiManager("delete");
		}
	}
}

function duplicateROI(newName){
	if(roiManager("count") > 0){
		roiManager("deselect");
		roiManager("delete");
	}
	roiManager("Open", outputROI + subfolder + "-ROI_" + fileNoExtension + ".zip");
	roiManager("Select", 0);
	run("Duplicate...", "title=" + newName);	
	run("Select None");
	roiManager("deselect");
	roiManager("delete");
}

//Quantify single labeling
function recursiveThresholding(staining){	
	setForegroundColor(Math.pow(2,bitDepth()), Math.pow(2,bitDepth()), Math.pow(2,bitDepth()));
	getDateAndTime(year, month, dayOfWeek, dayOfMonth, hour, minute, second, msec);
	print("Start Time: " + hour + ":" + minute + ":" + second);
	
	ogImage = staining  + "_raw";
	noBG = staining  + "_noBG";
	close("Output");
	close("C3-Composite");
	close("Oversized");
	getThreshold(lower, upper);
	resetMinAndMax();
	setThreshold(lower, upper);
	print("Start Threshold: " + lower);
	print("Last Threshold: " + lower);
	if(maxSize == "Infinity"){
		stepSize = 1;
	}else{
		stepSize = getString("Step Size:", "1");
	}
	run("Select None");
	close("Image");
	run("Duplicate...", "title=Image");
	run("Duplicate...", "title=Output");
	run("Select All");
	run("Clear");
	run("Select None");
	run("8-bit");
	run("Duplicate...", "title=Oversized");
	run("Invert");	
	n = 0;
	
	newImage("Close-to-stop", "8-bit white", 200, 100, 1);
	run("Red");
	setFont("SansSerif", 24, " bold");
	makeText("Close to stop!", 10, 30);
	run("Add Selection...", "stroke=white new");
	run("Select None");
	setBatchMode(true);
	while (true) {
		n++;
		close("OversizedMask");
		close("OversizedOG");
		close("ThresholdMask");
		
		selectWindow("Image");
		setThreshold(lower, upper);
		print("\\Update:Last Threshold: " + lower);
		lower = lower + stepSize;
		
		//Get correct sized particles
		run("Create Mask");
		rename("ThresholdMask");
		if (segment){
			run("Watershed");
		}
		if (isDilate) {
			run("Dilate");
		}
		if (isClose) {
			run("Close-");
		}
		if (fillHoles) {
			run("Fill Holes");
		}
		if (!isOpen("Close-to-stop")) {
			print("Manually aborted");
			maxSize = "Infinity";
		}
		run("Analyze Particles...", "size=" + minSize + "-" + maxSize + " show=Masks");
		run("Invert");
		run("Create Selection");

		if (selectionType() > -1){
			//Checks if there are any new particles
			//Copies them into the output image
			selectWindow("Output");
			run("Restore Selection");
			run("Fill");
			run("Select None");
		}
		close("Mask of ThresholdMask");
		
		//Mark oversized particles
		selectWindow("ThresholdMask");
		run("Analyze Particles...", "size=" + maxSize + "-Infinity show=Masks");
		close("OversizedMask");
		rename("OversizedMask");
		run("Create Selection");
		selectWindow("Image");
		run("Duplicate...", "title=OversizedOG");
		run("Restore Selection");
		run("Make Inverse");
		if (selectionType() == -1) {
			print("No more oversized particles");
			abortLoop();
		}else if (!isOpen("Oversized")){
			print("Oversized window was closed");
			abortLoop();
		}else if (lower >= upper){
			print("lower >= upper");
			close("Close-to-stop");
		}else {
			//If there are still oversized particles,
			//Continue loop with reduced threshold 
			run("Clear Outside");
			run("Select None");
			close("Image");
			rename("Image");
			selectWindow("Oversized");
			run("Restore Selection");
			run("Clear Outside");
			run("Create Selection");
			run("Select None");
			close("ThresholdMask");
			continue
		}	
	}
	setBatchMode(false);
	selectWindow("Output");
	run("16-bit");
	run("Merge Channels...", "c1=" + ogImage + " c2=" + noBG + " c3=Output create keep");
	rename("Composite-" + staining);
	Stack.setChannel(1);
	run("Enhance Contrast", "saturated=0.35");
	Stack.setChannel(2);
	run("Enhance Contrast", "saturated=0.35");
	Stack.setChannel(3);
	setForegroundColor(Math.pow(2,bitDepth()), Math.pow(2,bitDepth()), Math.pow(2,bitDepth()));
	waitForUser("Manually add missed signals");
	Stack.setChannel(2);
	run("Select None");
	run("Duplicate...", "duplicate channels=3");
	run("8-bit");
	close("Output");
	rename("Output");
	run("Select None");
	
	close("Outlines");
	
	if(roiManager("count") > 0) {
		roiManager("deselect");
		roiManager("delete");
	}
	run("Analyze Particles...", "add");
	roiManager("save", outputROI + subfolder + "_" + staining + "-Particles_" + fileNoExtension + ".zip");
	roiManager("deselect");
	roiManager("delete");
}

function abortLoop(){
	print("Threshold steps: " + n);
	getDateAndTime(year, month, dayOfWeek, dayOfMonth, hour, minute, second, msec);
	print("Time: " + hour + ":" + minute + ":" + second);
	close("Close-to-stop");
	close("Oversized");
	close("Image");
	run("Select None");
	rename("Image");
	break
}

function printBoolean(setting, bool){
	//Prints the boolean settings as "Yes" or "No" instead of "1" or "0"
	if (bool){
		print(setting + ": " + "Yes");
	}else {
		print(setting + ": " + "No");
	}
}

function colocSettings(){
	Dialog.create("Coloc Settings");
		Dialog.addChoice("Staining A", allStainings);
		Dialog.addChoice("Staining B", allStainings);
		Dialog.addChoice("Coloc-Type", newArray("Partial", "Whole"));
		Dialog.addMessage("Whole: Overlapps A with B and quantifes the fluorescence per particle (fast)");
		Dialog.addMessage("Partial: Differentiate between partial and whole overlapp based on particle size (slow)");
		
		Dialog.addCheckbox("Fill Holes", false);
		Dialog.addCheckbox("Segment", false);
		Dialog.addCheckbox("Close", false);
		
		Dialog.addString("Dilate A by", "0");
		Dialog.addString("Dilate B by", "0");
		Dialog.addString("Minumum coloc size", "0");
		Dialog.addString("Maximum coloc size", "Infinity");
	Dialog.show();
	stainingA =  Dialog.getChoice();
	stainingB =  Dialog.getChoice();
	colocType = Dialog.getChoice();	
	
	fillHoles = Dialog.getCheckbox();
		segment = Dialog.getCheckbox();
		isClose = Dialog.getCheckbox();
	
	enlargeA = Dialog.getString();
	enlargeB = Dialog.getString();
	
	//Set boundaries for partial overlapp
	if (colocType == "partial"){
		Dialog.create("Partial Overlapp");
			Dialog.addString("Minumum coloc size", "0");
			Dialog.addString("Maximum coloc size", "Infinity");
		Dialog.show();
		minSize = Dialog.getString();
		maxSize = Dialog.getString();

	//Check for error
	if(stainingA == stainingB){
		waitForUser("Please select two different stainings to coloclize.");
		continue;
	}else{
		//Log
		print(".");
		print(".");
		print(".");
		print("Coloc: " + stainingA + "+" + stainingB);
		print("Coloc-Type: " + colocType);
		printBoolean("Find double positive cells", colocType);
		printBoolean("Fill Holes", fillHoles);
		printBoolean("Segment", segment);
		printBoolean("Close", isClose);
		print("Dilate A by", enlargeA);
		print("Dilate B by", enlargeB);
		print("Min particle size: " + minSize);
		print("Max particle size: " + maxSize);
		return true;
		}
	}
}

function backgroundIntensity(staining){
	//Quantifies background staining, ie. all areas that are previously not identified as part of the signal.
	if (staining != ""){
		selectWindow(staining  + "_raw");
		run("Duplicate...", "title=" + staining + "_Background");
		if(roiManager("count") > 0){
			roiManager("deselect");
			roiManager("delete");
		}
		if(File.exists(outputROI + subfolder + "-CutAreas-ROI_" + fileNoExtension + ".zip")){
			roiManager("Open", outputROI + subfolder + "-CutAreas-ROI_" + fileNoExtension + ".zip");
			setForegroundColor(0, 0, 0);
			roiManager("fill");
			roiManager("deselect");
			roiManager("delete");
		}
		selectWindow("Mask-" + staining);
		//run("Make Binary");
		run("Create Selection");
		run("Select None");
		selectWindow(staining + "_Background");
		run("Restore Selection");
		run("Clear");
		run("Select None");
		setThreshold(1, Math.pow(2,bitDepth()));
		waitForUser("Check Threshold: Background " + staining);
		
		run("Analyze Particles...", "show=Masks display clear summarize");
		selectWindow("Results");
		saveAs("Results", outputCSV + "Background-" + staining  + "_" + fileNoExtension + ".csv");
		close(staining + "_Background");
		
	}
}
//START --- General Settings
//Prompt User

#@ String (label="Name (no blanks):") subfolder
#@ File (label="Select composite file (.tif):", style = "file") inputFile
#@ File (label="Select directory containing background (Median filtered) images:", style = "directory") medianFilter
#@ File (label="Select output directory:", style = "directory") outputDir

// Fresh Start
run("Fresh Start");
close("Summary_Coloc");
close("Summary_Background");
close("Summary_ParticleNumber");
Table.create("Summary");
setOption("BlackBackground", true);
setForegroundColor(0, 0, 0);
setBackgroundColor(0, 0, 0);

// Open Image
open(inputFile);
getPixelSize(unit, pixelWidth, pixelHeight);
filename = getTitle();
fileNoExtension = File.nameWithoutExtension;

//Create new directories
outputDir = outputDir + File.separator + fileNoExtension;
newDir = newArray("ROI", "csv", "masks", "Logs");

//Output variables, to reduce line length
outputROI = outputDir + File.separator + subfolder + File.separator + newDir[0] + File.separator;
outputCSV = outputDir + File.separator + subfolder + File.separator + newDir[1] + File.separator;
outputMASK = outputDir + File.separator + subfolder + File.separator + newDir[2] + File.separator;
outputLogs = outputDir + File.separator + subfolder + File.separator + newDir[3] + File.separator;

//Loop through new directoreis

for (i = 0; i < newDir.length; i++) {
	if (File.isDirectory(outputDir) == 0) {
		 File.makeDirectory(outputDir);
	}
	if (File.isDirectory(outputDir + File.separator + subfolder) == 0) {
		 File.makeDirectory(outputDir + File.separator + subfolder);
	}
	if (File.isDirectory(outputDir + File.separator + subfolder + File.separator + newDir[i]) == 0) {
		 File.makeDirectory(outputDir + File.separator + subfolder + File.separator +  newDir[i]);
	}
}

// Log
print("\\Clear");
print(fileNoExtension);
print(subfolder);
getDateAndTime(year, month, dayOfWeek, dayOfMonth, hour, minute, second, msec);
print("Time: " + hour + ":" + minute + ":" + second);

//START --- Main Script
//Open methods windows
run("Threshold...");
run("Brightness/Contrast...");
run("Channels Tool...");
run("ROI Manager...");
roiManager("reset");

//Promt for ROI creation
newRoi = getBoolean("Select new region of interest (ROI)?");

//Create new ROI
if (newRoi) {
	while(selectionType() == -1){
		waitForUser("Select the region of interest you want to analyze");
	}
} else {
	roiManager("open", outputDir + File.separator + subfolder + File.separator + "ROI" + File.separator + subfolder + "-ROI_" + fileNoExtension + ".zip");
	roiManager("select", 0);
}

//Saves ROI
roiManager("add");
roiManager("save selected", outputROI + subfolder + "-ROI_" + fileNoExtension + ".zip");
roiManager("delete");

run("Duplicate...", "title=" + subfolder + " duplicate");
saveAs("Tiff", outputMASK + subfolder + "_" + filename);
rename(subfolder);
close(filename);

//Create negative of ROI, which will be removed later, ie. the area not selected will be cut
selectWindow(subfolder);
run("Restore Selection");
run("Make Inverse");
if(selectionType() != -1){
	roiManager("add");
}

//Manually select artifacts to remove
cutAreasROI = outputDir + File.separator + subfolder + File.separator + "ROI" + File.separator + subfolder + "-CutAreas-ROI_" + fileNoExtension + ".zip";
if (newRoi == false && File.isDirectory(cutAreasROI)) {
	roiManager("reset");
	roiManager("open", cutAreasROI);	
}
roiManager("Show All");
waitForUser("Select artifacts and regions that you don't want to analzye and add them to the ROI manager [by pressing t]");
run("Select None");

//Checks if any regions have been selected and saves them as "-CutArea-ROI"
if(roiManager("count") > 0){
	roiManager("save", outputROI + subfolder + "-CutAreas-ROI_" + fileNoExtension + ".zip")
}else if(File.exists(outputROI + subfolder + "-CutAreas-ROI_" + fileNoExtension + ".zip")){
	File.delete(outputROI + subfolder + "-CutAreas-ROI_" + fileNoExtension + ".zip");
}

selectWindow(subfolder);
run("Duplicate...", "title=Staining duplicate");
getDimensions(width, height, channels, slices, frames);
if(channels > 1) {
	run("Split Channels");	
}

//Quantifies labeling area and particles.--
//Uses defines minimal and maximal size of particles.
//If selected, segments particles with "segmentParticles" function. Note: Can take up to several minutes.

//Repeats until user all quantifications are done
quantify = true;
stainingNr = 0;
while(quantify){
	stainingNr++;
	
	//Repeats until user is satisfied with current quantification
	notSatisfied = true; 
	n = 0;
	while (notSatisfied) {
		n++;
		
		//Prompts user for minimum and maximum particle sizes
		waitForUser("Select minimum particle size");
		if (selectionType != -1){
			getStatistics(area);
			minSize = area;
		}else if(""+minSize == ""){
			minSize = 0;
		}
		waitForUser("Select maximum particle size");
		if (selectionType != -1){
			getStatistics(area);
			maxSize = area;
		}else if(""+maxSize == ""){
			maxSize = 0;
		}
		run("Select None");
		
		//General quantification settings
		Dialog.create("Settings");
			Dialog.addString("Staining:", "");
			Dialog.addString("Channel:", "1");
			Dialog.addCheckbox("Segment", false);
			Dialog.addCheckbox("Fill Holes", false);
			Dialog.addCheckbox("Close", false);
			Dialog.addCheckbox("Dilate", false);
			Dialog.addString("Minimum particle size", minSize);
			Dialog.addString("Maximum particle size", maxSize);
	   	Dialog.show();
	   	staining = Dialog.getString();
	   	channelID = Dialog.getString();
		segment = Dialog.getCheckbox();
	   	fillHoles = Dialog.getCheckbox();
	   	isClose = Dialog.getCheckbox();
	   	isDilate = Dialog.getCheckbox();
	   	minSize = Dialog.getString();
	   	maxSize = Dialog.getString();
		
		//More settings
		subtractTimes = getString("Subtract (filtered) background image  x times:", "1");
		rbSubtraction = getBoolean("Rolling ball BG subtraction?");
		removeBackground(staining, channelID, rbSubtraction, subtractTimes);
		
		//Creates a duplicate of the image from which the background has been removed
		selectWindow(staining  + "_noBG");
		run("Duplicate...", "title=" + staining  + "_noBG-Double");
		run("Grays");
				
		//Print Settings
		print(".");
		print(".");
		print(".");
		print(staining);
	   	print("Trail " + n);
	   	print("Channel: " + channelID);
	   	printBoolean("Subtract background image", subtractTimes);
	   	if(subtractTimes){
	   		print("Background image file:");
	   		print(medianFilter + File.separator + "Filtered_" + staining + "-" + filename);
	   		print("Subtract Background: " + subtractTimes + " times");
	   	}
	   	printBoolean("Rolling Ball Subtraction", rbSubtraction);

	   	printBoolean("Fill Holes", fillHoles);
	   	printBoolean("Segment", segment);
	   	printBoolean("Close", isClose);
	   	printBoolean("Dilate", isDilate);
	   	print("Min particle size: " + minSize);
	   	print("Max particle size: " + maxSize);

		if(roiManager("count") > 0){
			roiManager("deselect");
			roiManager("delete");
		}
		if(File.exists(outputROI + subfolder + "-CutAreas-ROI_" + fileNoExtension + ".zip")){
			roiManager("Open", outputROI + subfolder + "-CutAreas-ROI_" + fileNoExtension + ".zip");
			setForegroundColor(0, 0, 0);
			roiManager("fill");
			if(roiManager("count") > 0){
				roiManager("deselect");
				roiManager("delete");
			}
		}

		resetMinAndMax();
		run("Enhance Contrast", "saturated=0.35");
		setAutoThreshold("Li dark");
		waitForUser("Adjust Threshold (" + staining + ").");
		getThreshold(lower, upper);
		while(lower == -1 && upper == -1){
			waitForUser("Adjust Threshold (" + staining + ").");
			getThreshold(lower, upper);
		}
		print("Threshold " + staining + ": " + lower + " - " + upper);
		if(is("binary")){
			waitForUser("Please only adjust the threshold, don't press 'Apply'!");
			continue
		}
		
		//Function that applies the previously created settings
		//Reduces the thresholding step by step until it quantified all possible particles
		recursiveThresholding(staining);
		
		//Check if user is satisfied with the quantification
		notSatisfied = getBoolean("Is the quantification ok?", "No, repeat", "Yes, continue");
		if (notSatisfied) {
			close("Composite-" + staining);
			close("Mask-" + staining);
			close("Raw-Mask-" + staining);
			close(staining + "_raw");
			close(staining  + "_noBG-Double");
			close("Image");
			close("Output");
			continue;
		}
		
		//Save masks
		run("8-bit");
		saveAs("Tiff", outputMASK + "Mask-" + staining  + "_" + filename);
		saveAs("Results", outputCSV + staining  + "_" + fileNoExtension + ".csv");
		rename("Mask-" + staining);
		run("Select None");
		
		//Create Outlines
		run("Analyze Particles...", "size=0-Infinity show=[Bare Outlines]");
		rename("Outlines-" + staining);
		run("16-bit");
		
		//Applies the previously created masks to measure the fluorescence
		selectWindow(staining + "_raw");
		run("Duplicate...", "title=" + staining);
		run("Select None");
		selectWindow("Mask-" + staining);
		run("Create Selection");
		run("Select None");
		selectWindow(staining);
		run("Restore Selection");
		run("Clear Outside");
		run("Select None");
		setThreshold(1, Math.pow(2,bitDepth()));
		run("Analyze Particles...", "display clear summarize");
		selectWindow("Mask-" + staining);
	}
	
	//Create string of analyzed stainings (eg. "staining1 + staining2 + staining3""
	//Used later to name the output files
	if (stainingNr == 1){
		stainingsStr = staining;
	}else {
		stainingsStr = stainingsStr + "+" + staining;
	}
	
	//Save Results
	selectWindow("Summary");
	saveAs("Results", outputCSV + "Summary_" + subfolder + staining + "_ParticleNumber_" + fileNoExtension);
	Table.rename("Summary_" + subfolder + staining + "_ParticleNumber_" + fileNoExtension, "Summary_ParticleNumber");
	Table.reset("Summary");
	quantify = getBoolean("Another staining?");
}

allStainings = split(stainingsStr,"+");

//Check if user wants to do colocalisations
colocStainings = newArray(0);
doColoc = getBoolean("Do coloc quantification?");
colocNr = 0;
colocName = newArray(0);

//Loops until user has done all colocalisations
while (doColoc){
	//Loops through function 'colocSettings' until it returns true
	repeatColocSettings = true;
	while (repeatColocSettings){
		repeatColocSettings = colocSettings();
	}
	
	//Quantify Particles
	selectWindow("Mask-" + stainingA);
	run("Create Selection");
	run("Select None");
	selectWindow("Mask-" + stainingB);
	close(stainingB + "-ParticlesOutlines");
	run("Duplicate...", "title=" + stainingB + "-ParticlesOutlines");
	
	for (i = 0; i < enlargeB; i++) {
		run("Dilate");
	}
	if (segment){
		run("Watershed");
	}
	if (isClose) {
		run("Close-");
	}
	if (fillHoles) {
		run("Fill Holes");
	}

	run("Restore Selection");
	getVoxelSize(width, height, depth, unit);
	run("Enlarge...", "enlarge=" + enlargeA);

	run("Clear Outside");
	
	run("Create Selection");
	run("Select None");
	selectWindow(stainingB + "_raw");
	close(stainingB + "-ParticlesOG");
	run("Duplicate...", "title=" + stainingB + "-ParticlesOG");
	run("Restore Selection");
	run("Clear Outside");
	run("Select None");
	selectWindow("Log");
	
	setBatchMode(true);
	selectWindow(stainingB + "-ParticlesOG");
	close(stainingB + "-Particles");
	run("Duplicate...", "title=" + stainingB + "-Particles");
	
	if(roiManager("count") > 0){
		roiManager("deselect");
		roiManager("delete");
	}
	roiManager("open", outputROI + subfolder + "_" + stainingA + "-Particles_" + fileNoExtension + ".zip");
	roiManager("show all");

	setBatchMode("hide");
	n = roiManager("count");
	run("Set Measurements...", "area mean redirect=None decimal=3");
	run("Clear Results");
	if (overlapp == "whole"){
		roiManager("combine");
		run("Clear Outside");
		run("Select None");
		rename(stainingA + "-X-" + stainingB + " " + i+1);
		setThreshold(1,Math.pow(2,bitDepth()));
		run("Analyze Particles...", "dispaly clear summarize");
	} else if(overlapp == "partial");{
		print(0 + "/" + n);
		for (i = 0; i < n; i++) {
			print("\\Update:" + i+1 + "/" + n);
		    roiManager("select", i);
		    roiManager("rename", "Cell " + i+1);
			run("Enlarge...", "enlarge=" + enlargeA);
			roiManager("update");
			
			setThreshold(0,Math.pow(2,bitDepth()));
			run("Measure");
			setThreshold(1,Math.pow(2,bitDepth()));
		    rename(stainingA + "-X-" + stainingB + " " + i+1);
		    run("Analyze Particles...", "size=" + minSize + "-" + maxSize + " summarize");	
			}
		}
	}
	run("Select None");	
	
	setBatchMode("show");
	close("Particles");
	selectWindow("Summary");
	saveAs("Results", outputCSV + "Summary_" + subfolder + "_" + stainingA + "+" + stainingB + "-Coloc_" + fileNoExtension + ".csv");
	Table.rename("Summary_" + subfolder + "_" + stainingA + "+" + stainingB + "-Coloc_" + fileNoExtension + ".csv", "Summary_Coloc");
	Table.reset("Summary");
	selectWindow("Results");
	saveAs("Results", outputCSV + "Results_" + subfolder + "_" + stainingA + "+" + stainingB + "-Coloc_" + fileNoExtension + ".csv");
	setBatchMode(false);
	
	//Create compound image
	mergingString = "c1=" + stainingA  + "_raw c2=" + stainingB  + "_raw c3=Outlines-" + stainingA + " c4=Outlines-" + stainingB + " c5=" + stainingB + "-ParticlesOutlines";

	selectWindow("Mask-" + stainingA);
	run("16-bit");
	run("Select None");
	close("Outlines-" + stainingA);
	run("Duplicate...", "title=Outlines-" + stainingA);
	run("8-bit");
	run("Outline");
	run("16-bit");
	
	selectWindow("Mask-" + stainingB);
	run("Select None");
	close("Outlines-" + stainingB);
	run("Duplicate...", "title=Outlines-" + stainingB);
	run("Outline");
	run("16-bit");

	selectWindow(stainingB + "-ParticlesOutlines");
	run("8-bit");
	run("Outline");
	run("16-bit");

	run("Merge Channels...", "c1=" + stainingA  + "_raw c2=" + stainingB  + "_raw c3=Outlines-" + stainingA + " c4=Outlines-" + stainingB + " c5=" + stainingB + "-ParticlesOutlines c6=Mask-" + stainingA + " create keep");
	close("Analyzed-" + stainingA + "+" + stainingB + "_" + filename);
	saveAs("Tiff", outputMASK + "Analyzed-" + stainingA + "+" + stainingB + "_" + filename);
	Stack.setDisplayMode("color");
	for (i = 0; i < 6; i++) {
		Stack.setChannel(i);
		run("Enhance Contrast", "saturated=0.35");
	}
	run("Yellow");
	Stack.setDisplayMode("composite")
	colocName[colocNr] = "Analyzed-" + stainingA + "+" + stainingB + "_" + filename;
	
	//Check Quantification
	waitForUser("Check Quantification");
	doColoc = getBoolean("Do another coloc?");
	colocNr++;
}

//Background quantification
quantifyBG = getBoolean("Quantify Background?");
if(quantifyBG) {
	Table.reset("Summary");
	for (i = 0; i < allStainings.length; i++) {
		backgroundIntensity(allStainings[i]);
	}
}

//Quantify total area
selectWindow(subfolder);
run("Select None");
run("Duplicate...", "title=Area duplicate channels=1");

if(roiManager("count") > 0){
	roiManager("deselect");
	roiManager("delete");
}
if(File.exists(outputROI + subfolder + "-CutAreas-ROI_" + fileNoExtension + ".zip")){
	roiManager("Open", outputROI + subfolder + "-CutAreas-ROI_" + fileNoExtension + ".zip");
	setForegroundColor(0, 0, 0);
	roiManager("fill");
	roiManager("deselect");
	roiManager("delete");
}

run("Select None");
setAutoThreshold("Huang dark");
waitForUser("Adjust Threshold (Area)");
run("Analyze Particles...", "show=Masks display clear summarize");
saveAs("Tiff", outputMASK + "Mask-totalArea_" + subfolder + "_" + filename);

selectWindow("Results");
saveAs("Results", outputCSV + "totalArea_" + subfolder + "_" + fileNoExtension + ".csv");
Table.rename("TotalArea");

//Save final results
selectWindow("Summary");
saveAs("Results", outputCSV + "Summary_Background_" + subfolder + "_" + fileNoExtension + ".csv");
Table.rename("Summary_Background_" + subfolder + "_" + fileNoExtension + ".csv", "Summary_Background");
selectWindow("Log");
print("Quantification succesfull! Check results for accuracy.");
saveAs("Text", outputLogs + "Log_" + subfolder + "_" + fileNoExtension + ".txt");

//Selects the final coloc window
selectWindow("Summary");
for (i = 0; i < colocNr; i++) {
	selectWindow(colocName[i]);
}
waitForUser("Quantification succesfull! Check results for accuracy.");