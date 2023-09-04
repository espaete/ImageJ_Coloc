//By Erik Späte @NAT MPG Göttingen, Department of Neurogenetics, UG Sandra Goebbels, 2022
//Input original image + folder for single channels + folder for median filtered channels.
//Analyzes single or multi channel images.
//Segments image into particles using wide variaty of user set settings. 
//Recursive thresholding enables segmentation of similarly sized particles of widely varying fluorescence.
//Counts, measures and colocalizes particles automatically.
//Marks colocalized particles in image for user verification.
//Good luck!!!

//START --- General Settings
//User Prompt

#@ String (label="Area Name (no blanks):") areaName
#@ File (label="Select composite file (.tif):", style = "file") inputFile
#@ File (label="Select directory containing background (Median filtered) images:", style = "directory") medianFilter
#@ File (label="Select output directory:", style = "directory") outputDir

run("Fresh Start");
close("Summary_Coloc");
close("Summary_Background");
close("Summary_ParticleNumber");
Table.create("Summary");
setOption("BlackBackground", true);
setForegroundColor(0, 0, 0);
setBackgroundColor(0, 0, 0);

newDir = newArray("ROI", "csv", "masks", "Logs");

//Output variables, to reduce line length
outputROI = outputDir + File.separator + areaName + File.separator + newDir[0] + File.separator;
outputCSV = outputDir + File.separator + areaName + File.separator + newDir[1] + File.separator;
outputMASK = outputDir + File.separator + areaName + File.separator + newDir[2] + File.separator;
outputLogs = outputDir + File.separator + areaName + File.separator + newDir[3] + File.separator;

//Set up new directories in output folder
for (i = 0; i < newDir.length; i++) {
	if (File.isDirectory(outputDir + File.separator + areaName) == 0) {
		 File.makeDirectory(outputDir + File.separator + areaName);
	}
	if (File.isDirectory(outputDir + File.separator + areaName + File.separator + newDir[i]) == 0) {
		 File.makeDirectory(outputDir + File.separator + areaName + File.separator +  newDir[i]);
	}
}

//START --- Open image
open(inputFile);
getPixelSize(unit, pixelWidth, pixelHeight);
filename = getTitle();
fileNoExtension = File.nameWithoutExtension;
run("Threshold...");
//END

//START --- Log
print("\\Clear");
print(fileNoExtension);
print(areaName);
getDateAndTime(year, month, dayOfWeek, dayOfMonth, hour, minute, second, msec);
print("Time: " + hour + ":" + minute + ":" + second);
//END

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
		if(subtractImage){
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
		if(File.exists(outputROI + areaName + "-CutAreas-ROI_" + fileNoExtension + ".zip")){
			roiManager("Open", outputROI + areaName + "-CutAreas-ROI_" + fileNoExtension + ".zip");
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
	roiManager("Open", outputROI + areaName + "-ROI_" + fileNoExtension + ".zip");
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
	run("Cyan");
	run("Enhance Contrast", "saturated=0.35");
	Stack.setChannel(2);
	run("Cyan");
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
	roiManager("save", outputROI + areaName + "_" + staining + "-Particles_" + fileNoExtension + ".zip");
	roiManager("deselect");
	roiManager("delete");
	//close("Output");
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

//START --- Main Script
//Select region of interest and save as .tiff
run("Brightness/Contrast...");
run("Channels Tool...");
run("ROI Manager...");
roiManager("reset");

//waitForUser("Select the region of interest you want to analyze");

reuseROI = getBoolean("Reuse ROI?");

if (reuseROI) {
	roiManager("open", outputDir + File.separator + areaName + File.separator + "ROI" + File.separator + areaName + "-ROI_" + fileNoExtension + ".zip");
	roiManager("select", 0);
} else {
	while(selectionType() == -1){
		waitForUser("Select the region of interest you want to analyze");
	}
}

roiManager("add");
roiManager("save selected", outputROI + areaName + "-ROI_" + fileNoExtension + ".zip");
roiManager("delete");


run("Duplicate...", "title=" + areaName + " duplicate");
saveAs("Tiff", outputMASK + areaName + "_" + filename);
rename(areaName);
close(filename);

//Add negative of ROI selection
selectWindow(areaName);
run("Restore Selection");
run("Make Inverse");
if(selectionType() != -1){
	roiManager("add");
}

//Manually select artifacts to remove
if (reuseROI) {
	roiManager("reset");
	roiManager("open", outputDir + File.separator + areaName + File.separator + "ROI" + File.separator + areaName + "-CutAreas-ROI_" + fileNoExtension + ".zip");	
}
roiManager("Show All");
waitForUser("Select artifacts and regions that you don't want to analzye and add them to the ROI manager [by pressing t]");
run("Select None");

if(roiManager("count") > 0){
	roiManager("save", outputROI + areaName + "-CutAreas-ROI_" + fileNoExtension + ".zip")
}else if(File.exists(outputROI + areaName + "-CutAreas-ROI_" + fileNoExtension + ".zip")){
	File.delete(outputROI + areaName + "-CutAreas-ROI_" + fileNoExtension + ".zip");
}

selectWindow(areaName);
run("Duplicate...", "title=Staining duplicate");
getDimensions(width, height, channels, slices, frames);
if(channels > 1) {
	run("Split Channels");	
}

//Quantifies labeling area and particles.--
//Uses user input of minimal size and circularity to correctly identify particles.
//If selected, segments particles with "segmentParticles" function. Note: Can take up to several minutes.
//Can be repeated by user until quantification is aggreeable.
quantify = true;
stainingNr = 0;
while(quantify){
	stainingNr++;
	repeatLoop = true; 
	n = 0;
	while (repeatLoop) {
		n++;
		Dialog.create("Settings");
			Dialog.addString("Staining:", "");
			Dialog.addString("Channel:", "1");
			Dialog.addCheckbox("Subtract Image", false);
			Dialog.addCheckbox("Despeckle", false);
			Dialog.addCheckbox("Smooth", false);
			Dialog.addCheckbox("Sharpen", false);
			Dialog.addCheckbox("Median filter", false);
			Dialog.addCheckbox("Fill Holes", false);
			Dialog.addCheckbox("Segment", false);
			Dialog.addCheckbox("Close", false);
			Dialog.addCheckbox("Dilate", false);
			Dialog.addString("Minimum particle size", "0");
			Dialog.addString("Maximum particle size", "Infinity");
			//Dialog.addString("Circularity (x-1)", "0");
	   	Dialog.show();
	   	staining = Dialog.getString();
	   	channelID = Dialog.getString();
	   	subtractImage = Dialog.getCheckbox();
	   	despeckle = Dialog.getCheckbox();
	   	smoothFilter = Dialog.getCheckbox();
	   	sharpen = Dialog.getCheckbox();
	   	isMedian = Dialog.getCheckbox();
	   	fillHoles = Dialog.getCheckbox();
	   	segment = Dialog.getCheckbox();
	   	isClose = Dialog.getCheckbox();
	   	isDilate = Dialog.getCheckbox();
	   	minSize = Dialog.getString();
	   	maxSize = Dialog.getString();
	   	circularity = "0";
	   	
		rbSubtraction = getBoolean("Rolling ball BG subtraction?");
		subtractTimes = getString("Subtract x times:", "1");
		removeBackground(staining, channelID, rbSubtraction, subtractTimes);
		
		selectWindow(staining  + "_noBG");
		run("Duplicate...", "title=" + staining  + "_noBG-Double");
		run("Grays");
		
		if (despeckle){
			run("Despeckle");
		}
		if (smoothFilter){
			run("Smooth");			
		}
		if (sharpen){
			run("Sharpen");
		}
		
		if (isMedian){
			medianRadius = getString("Median filter (in px)", "0");
			run("Median...", "radius=" + medianRadius);
			
			
		}
		
		//Print Settings
		print(".");
		print(".");
		print(".");
		print(staining);
	   	print("Trail " + n);
	   	print("Channel: " + channelID);
		printBoolean("Despeckle", despeckle);
	   	printBoolean("Subtract background image", subtractImage);
	   	if(subtractImage){
	   		print("Background image file:");
	   		print(medianFilter + File.separator + "Filtered_" + staining + "-" + filename);
	   		print("Subtract Background: " + subtractTimes + " times");
	   	}
	   	printBoolean("Rolling Ball Subtraction", rbSubtraction);
	   	printBoolean("Smooth", smoothFilter);
	   	printBoolean("Sharpen", sharpen);
	   	printBoolean("Median", isMedian);
	   	if(isMedian){
	   		print("Median radius: " + medianRadius + " px");
	   	}
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
		if(File.exists(outputROI + areaName + "-CutAreas-ROI_" + fileNoExtension + ".zip")){
			roiManager("Open", outputROI + areaName + "-CutAreas-ROI_" + fileNoExtension + ".zip");
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
		
		recursiveThresholding(staining);
		
		repeatLoop = getBoolean("Is the quantification ok?", "No, repeat", "Yes, continue");
		if (repeatLoop) {
			close("Composite-" + staining);
			close("Mask-" + staining);
			close("Raw-Mask-" + staining);
			close(staining + "_raw");
			close(staining  + "_noBG-Double");
			continue;
		}
		//run("Duplicate...", "dupicate channels=3");
		run("8-bit");
		saveAs("Tiff", outputMASK + "Mask-" + staining  + "_" + filename);
		saveAs("Results", outputCSV + staining  + "_" + fileNoExtension + ".csv");
		rename("Mask-" + staining);
		run("Select None");
		
		run("Analyze Particles...", "size=0-Infinity show=[Bare Outlines]");
		//run("Make Binary");
		rename("Outlines-" + staining);
		run("16-bit");
		//Quantify intensity
		selectWindow(staining + "_raw");
		run("Duplicate...", "title=" + staining);
		run("Select None");
		selectWindow("Mask-" + staining);
		//run("Make Binary");
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
	if (stainingNr == 1){
		stainingsStr = staining;
	}else {
		stainingsStr = stainingsStr + "+" + staining;
	}
	selectWindow("Summary");
	saveAs("Results", outputCSV + "Summary_" + areaName + staining + "_ParticleNumber_" + fileNoExtension);
	Table.rename("Summary_" + areaName + staining + "_ParticleNumber_" + fileNoExtension, "Summary_ParticleNumber");
	Table.reset("Summary");
	quantify = getBoolean("Another staining?");
}

allStainings = split(stainingsStr,"+");

function quantifyParticular(stainingA, stainingB) {
	
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
	
	if (wholeCell) {
		run("Analyze Particles...", "size=" + minSize + "-" + maxSize + " show=Masks");
		close(stainingB + "-ParticlesOutlines");
		rename(stainingB + "-ParticlesOutlines");
		//run("Make Binary");
	}
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
	roiManager("open", outputROI + areaName + "_" + stainingA + "-Particles_" + fileNoExtension + ".zip");
	roiManager("show all");

	setBatchMode("hide");
	n = roiManager("count");
	run("Set Measurements...", "area mean redirect=None decimal=3");
	run("Clear Results");
	print(0 + "/" + n);
	for (i = 0; i < n; i++) {
		print("\\Update:" + i+1 + "/" + n);
	    roiManager("select", i);
	    roiManager("rename", "Cell " + i+1);
    	run("Enlarge...", "enlarge=" + enlargeA);
		roiManager("update");
		
		setThreshold(0,Math.pow(2,bitDepth()));
		run("Measure");
		if (!wholeCell){
			setThreshold(1,Math.pow(2,bitDepth()));
		    rename(stainingA + "-X-" + stainingB + " " + i+1);
		    run("Analyze Particles...", "size=" + minSize + "-" + maxSize + " summarize");	
		}
	}
	run("Select None");
	if (wholeCell){
		setThreshold(1,Math.pow(2,bitDepth()));
    	//run("Make Binary");

		run("Select None");
		print("Combine ROIs...");
		roiManager("combine");
		getDateAndTime(year, month, dayOfWeek, dayOfMonth, hour, minute, second, msec);
		print("Time: " + hour + ":" + minute + ":" + second);
		print("Dilate: 0");
		for (j = 0; j < 100; j++) {
			print("\\Update:Dilate: " + j);
			run("Dilate");
		}
		getDateAndTime(year, month, dayOfWeek, dayOfMonth, hour, minute, second, msec);
		print("Time: " + hour + ":" + minute + ":" + second);
		setForegroundColor(0, 0, 0);
		setBackgroundColor(255, 255, 255);
		run("Draw");
		run("Select None");
		setBackgroundColor(0, 0, 0);
		
	}
	
	
	setBatchMode("show");
	close("Particles");
	selectWindow("Summary");
	saveAs("Results", outputCSV + "Summary_" + areaName + "_" + stainingA + "+" + stainingB + "-Coloc_" + fileNoExtension + ".csv");
	Table.rename("Summary_" + areaName + "_" + stainingA + "+" + stainingB + "-Coloc_" + fileNoExtension + ".csv", "Summary_Coloc");
	Table.reset("Summary");
	selectWindow("Results");
	saveAs("Results", outputCSV + "Results_" + areaName + "_" + stainingA + "+" + stainingB + "-Coloc_" + fileNoExtension + ".csv");
	setBatchMode(false);
}
//Quantify colocalisation
function createCompoundImage(stainingA, stainingB){	
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
}

//Quantifies colocalisation by overlapping the corresponding masks created by "quantifyLabeling".
colocStainings = newArray(0);
doColoc = getBoolean("Do coloc quantification?");
colocNr = 0;
colocName = newArray(0);
while (doColoc){
	while (true){
		Dialog.create("Coloc Settings");
			Dialog.addChoice("Staining A", allStainings);
			Dialog.addChoice("Staining B", allStainings);
			Dialog.addChoice("Coloc-Type", newArray("Partial", "Whole"));
			Dialog.addCheckbox("Binary Quant", false);
			
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
		wholeCell = Dialog.getCheckbox();

		fillHoles = Dialog.getCheckbox();
	   	segment = Dialog.getCheckbox();
	   	isClose = Dialog.getCheckbox();
		
		enlargeA = Dialog.getString();
		enlargeB = Dialog.getString();
		minSize = Dialog.getString();
		maxSize = Dialog.getString();
		circularity = "0";

		if(stainingA == stainingB){
			waitForUser("Please select two different stainings to coloclize.");
			continue;
		}else{
			print(".");
			print(".");
			print(".");
			print("Coloc: " + stainingA + "+" + stainingB);
			print("Coloc-Type: " + colocType);
			printBoolean("Binary Quant", wholeCell);
			printBoolean("Fill Holes", fillHoles);
			printBoolean("Segment", segment);
			printBoolean("Close", isClose);
			print("Dilate A by", enlargeA);
			print("Dilate B by", enlargeB);
			print("Min particle size: " + minSize);
			print("Max particle size: " + maxSize);
			break;
		}
			
	}
	
	quantifyParticular(stainingA, stainingB);
	createCompoundImage(stainingA, stainingB);
	colocName[colocNr] = "Analyzed-" + stainingA + "+" + stainingB + "_" + filename;
	waitForUser("Check Quantification");
	doColoc = getBoolean("Do another coloc?");
	colocNr++;
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
		if(File.exists(outputROI + areaName + "-CutAreas-ROI_" + fileNoExtension + ".zip")){
			roiManager("Open", outputROI + areaName + "-CutAreas-ROI_" + fileNoExtension + ".zip");
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

quantifyBG = getBoolean("Quantify Background?");
if(quantifyBG) {
	Table.reset("Summary");
	for (i = 0; i < allStainings.length; i++) {
		backgroundIntensity(allStainings[i]);
	}
}

//Quantify total area
selectWindow(areaName);
run("Select None");
run("Duplicate...", "title=Area duplicate channels=1");

if(roiManager("count") > 0){
	roiManager("deselect");
	roiManager("delete");
}
if(File.exists(outputROI + areaName + "-CutAreas-ROI_" + fileNoExtension + ".zip")){
	roiManager("Open", outputROI + areaName + "-CutAreas-ROI_" + fileNoExtension + ".zip");
	setForegroundColor(0, 0, 0);
	roiManager("fill");
	roiManager("deselect");
	roiManager("delete");
}

run("Select None");
setAutoThreshold("Huang dark");
waitForUser("Adjust Threshold (Area)");
//run("Make Binary");
run("Analyze Particles...", "show=Masks display clear summarize");
saveAs("Tiff", outputMASK + "Mask-totalArea_" + areaName + "_" + filename);

selectWindow("Results");
saveAs("Results", outputCSV + "totalArea_" + areaName + "_" + fileNoExtension + ".csv");
Table.rename("TotalArea");

//Save summary
selectWindow("Summary");
saveAs("Results", outputCSV + "Summary_Background_" + areaName + "_" + fileNoExtension + ".csv");
Table.rename("Summary_Background_" + areaName + "_" + fileNoExtension + ".csv", "Summary_Background");
selectWindow("Log");
print("Quantification succesfull! Check results for accuracy.");
saveAs("Text", outputLogs + "Log_" + areaName + "_" + fileNoExtension + ".txt");

selectWindow("Summary");
for (i = 0; i < colocNr; i++) {
	selectWindow(colocName[i]);
}
waitForUser("Quantification succesfull! Check results for accuracy.");