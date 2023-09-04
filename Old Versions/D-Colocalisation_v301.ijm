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
#@ File (label="Select composite file (.tif):", style = "file") inputFile
#@ File (label="Select directory containing background (Median filtered) images:", style = "directory") medianFilter
#@ File (label="Select output directory:", style = "directory") outputDir

run("Fresh Start");
Table.create("Summary");
setOption("BlackBackground", true);
setForegroundColor(0, 0, 0);
setBackgroundColor(0, 0, 0);

//Output variables, to reduce line length
outputCSV = outputDir + File.separator + areaName + File.separator + "csv" + File.separator;
outputTIFF = outputDir + File.separator + areaName + File.separator + "tiff" + File.separator;
outputROI = outputDir + File.separator + areaName + File.separator + "ROI" + File.separator;
outputLogs = outputDir + File.separator + areaName + File.separator + "Logs" + File.separator;

//Set up new directories in output folder
newDir = newArray("ROI", "csv", "tiff", "Logs");
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
//END

//START --- Main Script
//Select region of interest and save as .tiff
run("Brightness/Contrast...");
run("Channels Tool...");
run("ROI Manager...");
roiManager("reset");

//waitForUser("Select the region of interest you want to analyze");
while(selectionType() == -1){
	waitForUser("Select the region of interest you want to analyze");
}

roiManager("add");
roiManager("save selected", outputROI + areaName + "-ROI_" + fileNoExtension + ".zip");
roiManager("delete");

run("Duplicate...", "title=" + areaName + " duplicate");
saveAs("Tiff", outputTIFF + areaName + "_" + filename);
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
roiManager("Show All");
waitForUser("Select artifacts and regions that you don't want to analzye and add them to the ROI manager [by pressing t]");
run("Select None");
if(roiManager("count") > 0){
	roiManager("save", outputROI + areaName + "-CutAreas-ROI_" + fileNoExtension + ".zip")
}else if(File.exists(outputROI + areaName + "-CutAreas-ROI_" + fileNoExtension + ".zip")){
	File.delete(outputROI + areaName + "-CutAreas-ROI_" + fileNoExtension + ".zip");
}

//Remove Background and artifacts
function removeBackground(staining, channelNr){
	//Removes background by subtracting the median filtered image
	//Further removes background via imageJ function "Subtract Background".
	if(staining != ""){
		close(staining  + "_raw");
		selectWindow("C" + channelNr + "-Staining");
		run("Select None");
		run("Duplicate...", "title=" + staining  + "_raw");
		subtraction = getBoolean("Rolling ball BG subtraction?");
		if (subtraction){
			Dialog.create("BackgroundRemoval Settings");
				Dialog.addString("Rolling ball radius", "0");
			Dialog.show();
			rbRadius = Dialog.getString();
		}
		
		
		if(subtractImage){
			print("Median filtered " + staining + ": Yes");
			print(medianFilter + File.separator + "Filtered_" + staining + "-" + filename);
			open(medianFilter + File.separator + "Filtered_" + staining + "-" + filename);
			duplicateROI("Background-" + staining);
			
			//Subtract filtered image from original
			imageCalculator("Subtract create", staining  + "_raw", "Background-" + staining);
			close("Filtered_" + staining + "-" + filename);
		}else{
			run("Duplicate...","title=" + staining + "_noBG");
			print(staining + ": No");
		}

		//Further reduce background
		if (subtraction){
			run("Subtract Background...", "rolling=" + rbRadius);
		}
		rename(staining + "_noBG");
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

selectWindow(areaName);
run("Duplicate...", "title=Staining duplicate");
run("Split Channels");


//Quantify single labeling

function recursiveThresholding(staining){
	getDateAndTime(year, month, dayOfWeek, dayOfMonth, hour, minute, second, msec);
	print("Start Time: " + hour + ":" + minute + ":" + second);
	
	ogImage = staining  + "_raw";
	noBG = staining  + "_noBG";
	close("C3-Composite");
	close("Oversized");
	getThreshold(lower, upper);
	resetMinAndMax();
	setThreshold(lower, upper);
	if(maxSize == "Infinity"){
		stepSize = 1;
	}else{
		stepSize = getString("Step Size:", "1");
	}
	run("Select None");
	
	run("Duplicate...", "title=Image");
	run("Duplicate...", "title=Output");
	
	newImage("Close-to-stop", "8-bit white", 200, 100, 1);
	run("Red");
	setFont("SansSerif", 24, " bold");
	makeText("Close to stop!", 10, 30);
	run("Add Selection...", "stroke=white new");
	run("Select None");
	
	selectWindow("Output");
	run("Select All");
	run("Clear");
	run("Select None");
	run("Make Binary");
	run("Invert");
	run("Duplicate...", "title=Oversized");
	run("Invert");
	selectWindow("Image");
	setBatchMode(true);
	n = 0;
	while (true) {
		n++;
		close("OversizedMask");
		
		selectWindow("Image");
		setThreshold(lower, upper);
		lower = lower + stepSize;

		print(lower);
		
		//Get correct sized particles
		run("Create Mask");
		close("OversizedOG");
		run("Make Binary");
		close("ThresholdMask");
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
			maxSize = "Infinity";
			close("Close-to-stop");
		}
		run("Analyze Particles...", "size=" + minSize + "-" + maxSize + " show=Masks");
		run("Make Binary");
		run("Create Selection");
		selection = getValue("selection.size");
		run("Make Inverse");
		if (selectionType() != -1){
			//Checks if there are any new particles
			//Copies them into the output image
			run("Make Inverse");
			run("Copy");
			selectWindow("Output");
			run("Restore Selection");
			run("Paste");
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
		getSelectionBounds(x, y, selectionWidth, selectionHeight);
		getDimensions(width, height, channels, slices, frames);
		selectionSize = selectionWidth * selectionHeight;
		imageSize = width * height;
		if (selectionType() == -1) {
			abortLoop();
		}else if (!isOpen("Oversized")){
			abortLoop();
		}else if (lower >= upper){
			abortLoop();
		}else {
			//If there are still oversized particles, 
			run("Clear Outside");
			run("Select None");
			close("Image");
			rename("Image");
			selectWindow("Oversized");
			run("Restore Selection");
			run("Clear Outside");
			run("Create Selection");
		}
		
		if (selectionType() == -1) {
			abortLoop();
		}else if (lower >= upper){
			abortLoop();
		}else{
			run("Select None");
			close("ThresholdMask");			
		}
	}
	setBatchMode(false);
	selectWindow("Output");
	run("16-bit");
	run("Merge Channels...", "c1=" + noBG + " c2=Output create keep");
	rename("Composite-" + staining);
	run("Enhance Contrast", "saturated=0.35");
	Stack.setChannel(2);
	setForegroundColor(Math.pow(2,bitDepth()), Math.pow(2,bitDepth()), Math.pow(2,bitDepth()));
	waitForUser("Manually add missed signals");
	Stack.setChannel(2);  
	run("Select None");
	run("Duplicate...", "duplicate channels=2");
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
	close("Output");
}

function abortLoop(){
	getDateAndTime(year, month, dayOfWeek, dayOfMonth, hour, minute, second, msec);
	print("Time: " + hour + ":" + minute + ":" + second);
	close("Close-to-stop");
	close("Oversized");
	run("Select None");
	close("Image");
	rename("Image");
	selectWindow("Output");
	break
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
		print("Trail " + n);

		Dialog.create("Settings");
			Dialog.addString("Staining:", "");
			Dialog.addString("Channel:", "1");
			Dialog.addCheckbox("Despeckle", false);
			Dialog.addCheckbox("Subtract Image", false);
			Dialog.addCheckbox("Smooth", false);
			Dialog.addCheckbox("Sharpen", false);
			Dialog.addCheckbox("Median filter", false);
			Dialog.addCheckbox("Fill Holes", false);
			Dialog.addCheckbox("Segment", false);
			Dialog.addCheckbox("Close", false);
			Dialog.addCheckbox("Dilate", false);
			Dialog.addString("Minimum particle size", "0");
			Dialog.addString("Maximum particle size", "Infinity");
			Dialog.addString("Circularity (0-1)", "0");
	   	Dialog.show();
	   	staining = Dialog.getString();
	   	channelID = Dialog.getString();
	   	despeckle = Dialog.getCheckbox();
	   	subtractImage = Dialog.getCheckbox();
	   	smoothFilter = Dialog.getCheckbox();
	   	sharpen = Dialog.getCheckbox();
	   	isMedian = Dialog.getCheckbox();
	   	fillHoles = Dialog.getCheckbox();
	   	segment = Dialog.getCheckbox();
	   	isClose = Dialog.getCheckbox();
	   	isDilate = Dialog.getCheckbox();
	   	minSize = Dialog.getString();
	   	maxSize = Dialog.getString();
	   	circularity = Dialog.getString();
		
		removeBackground(staining, channelID);
		
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
		run("Duplicate...", "dupicate channels=2");
		run("8-bit");
		saveAs("Tiff", outputTIFF + "Mask-" + staining  + "_" + filename);
		saveAs("Results", outputCSV + staining  + "_" + fileNoExtension + ".csv");
		rename("Mask-" + staining);
		run("Select None");
		
		run("Analyze Particles...", "size=0-Infinity show=[Bare Outlines]");
		run("Make Binary");
		rename("Outlines-" + staining);
		run("16-bit");
		//Quantify intensity
		selectWindow(staining + "_raw");
		run("Duplicate...", "title=" + staining);
		run("Select None");
		selectWindow("Mask-" + staining);
		run("Make Binary");
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
	quantify = getBoolean("Another staining?");
}
allStainings = split(stainingsStr,"+");
selectWindow("Summary");
saveAs("Results", "Summary_" + areaName + "_totalNumbers_" + fileNoExtension);
Table.rename("Summary_" + areaName + "_totalNumbers_" + fileNoExtension, "Summary");
Table.reset("Summary");


function quantifyWhole(stainingA, stainingB){
	stainings = newArray(stainingA, stainingB);
		if (stainingA != "" && stainingB != ""){
		for (r = 0; r < stainings.length; r++) {
			mask = "ColocMask";
			stainingString = String.join(stainings, "+");
			
			if (r == 0){
				for (i = 0; i < stainings.length; i++) {
					selectWindow("Mask-" + stainings[i]);
					run("Select None");
					resetThreshold();
					run("Make Binary");
				}
				selectWindow("Mask-" + stainingA);
				run("Select None");
				run("Make Binary");
				run("Create Selection");
				run("Select None");
				for (i = 1; i < stainings.length; i++) {
					selectWindow("Mask-" + stainings[i]);
					run("Duplicate...", "title=Double_Mask-" + stainings[i]);
					run("Restore Selection");
					run("Clear Outside");
					run("Create Selection");
					run("Select None");
				}
				run("Analyze Particles...", "size=" + minSize + "-Infinity circularity=" + circularity + "-1.00 show=Masks");
				run("Make Binary");
				
				rename("Mask-" + stainingA + "+" + stainingB);
				run("16-bit");
				run("Merge Channels...", "c1=" + stainingA + "_noBG c2=" + stainingB + "_noBG c3=" + stainingA  + "_raw c4=" + stainingB  + "_raw c5=Mask-" + stainingA + "+" + stainingB + " create keep");
				rename(stainingA + "+" + stainingB + "_Composite");
				Stack.setChannel(1);
				run("Enhance Contrast...", "saturated=0.35");
				Stack.setChannel(2);
				run("Enhance Contrast...", "saturated=0.35");
				Stack.setChannel(5);
				Stack.setActiveChannels("11001");
				close("Mask-" + stainingA + "+" + stainingB);
				setForegroundColor(255, 255, 255);
				waitForUser("Check quantification and modify accordingly.");
				run("Select None");
				setForegroundColor(0, 0, 0);
				run("Duplicate...", "title=" + mask + " duplicate channels=5");
				run("8-bit");
				run("Select None");
				
				run("Duplicate...", "title=Outlines-" + stainingA + "+" + stainingB);
				run("Outline");
	
	
			}
			selectWindow(mask);
			run("Create Selection");
			run("Select None");
			selectWindow(stainingA  + "_raw");
			run("Duplicate...", "title=" + stainingString);
			run("Restore Selection");
			
			run("Clear Outside");
			run("Select None");
			setThreshold(1, Math.pow(2,bitDepth()));
			run("Analyze Particles...", "size=" + minSize + "-" + maxSize + " circularity=" + circularity + "-1.00 show=Masks display clear summarize");
			saveAs("Results", outputCSV + stainingString  + "_" + fileNoExtension + ".csv");
			run("Duplicate...", "title=Mask-" + stainingString);
			run("Analyze Particles...", "size=0-Infinity show=[Bare Outlines]");
			run("Make Binary");
			rename("Outlines-" + stainingString + "New");
			
			run("16-bit");
			if (stainings.length < 3 && r == 0){
				run("Merge Channels...", "c1=" + stainingA + "_raw c2=" + stainingB + "_raw c3=Outlines-" + stainingA + "+" + stainingB + "New create keep");
				rename("Composite_" + stainingA + "+" + stainingB);
			}
			//Shift stainings list one step
			stainingsShift = newArray(stainings.length);
			for (i = 0; i < stainings.length; i++) {
				stainingsShift[i] = stainings[stainings.length-1-i];
			}
			stainings = stainingsShift;
		}
	}
}

function quantifyParticular(stainingA, stainingB) {
	
	selectWindow("Mask-" + stainingA);
	run("Create Selection");
	run("Select None");
	selectWindow("Mask-" + stainingB);
	run("Duplicate...", "title=" + stainingB + "-ParticlesOutlines");
	run("Restore Selection");
	getVoxelSize(width, height, depth, unit);
	run("Enlarge...", "enlarge=" + enlargeBy);

	run("Clear Outside");
	run("Create Selection");
	run("Select None");
	selectWindow(stainingB + "_raw");
	run("Duplicate...", "title=" + stainingB + "-ParticlesOG");
	run("Restore Selection");
	run("Clear Outside");
	run("Select None");
	setBatchMode(true);
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
	for (i = 0; i < n; i++) {
		print(i+1 + "/" + n);
	    roiManager("select", i);
	    roiManager("rename", "Cell " + i+1);
    	run("Enlarge...", "enlarge=" + enlargeBy);
		roiManager("update");
		
		setThreshold(0,Math.pow(2,bitDepth()));
		run("Measure");
	    setThreshold(1,Math.pow(2,bitDepth()));
	    rename(stainingA + "-X-" + stainingB + " " + i+1);
	    run("Analyze Particles...", "size=0-Infinity summarize");
	    run("Clear");
	    
	}
	setBatchMode("show");
	close("Particles");
	selectWindow("Summary");
	saveAs("Results", outputCSV + "Summary_" + areaName + "_" + stainingA + "+" + stainingB + "-Coloc_" + fileNoExtension + ".csv");
	Table.rename("Summary_" + areaName + "_" + stainingA + "+" + stainingB + "-Coloc_" + fileNoExtension + ".csv", "Summary");
	Table.reset("Summary");
	
	selectWindow("Results");
	saveAs("Results", outputCSV + "Results_" + areaName + "_" + stainingA + "+" + stainingB + "-Coloc_" + fileNoExtension + ".csv");
	setBatchMode(false);
}
//Quantify colocalisation
function createCompoundImage(stainingA, stainingB){	
	mergingString = "c1=" + stainingA  + "_raw c2=" + stainingB  + "_raw c3=Outlines-" + stainingA + " c4=Outlines-" + stainingB + " c5=" + stainingB + "-ParticlesOutlines";

	selectWindow("Mask-" + stainingA);
	run("Select None");
	run("Duplicate...", "title=Outlines-" + stainingA);
	run("Outline");
	run("16-bit");
	
	selectWindow("Mask-" + stainingB);
	run("Select None");
	run("Duplicate...", "title=Outlines-" + stainingB);
	run("Outline");
	run("16-bit");

	selectWindow(stainingB + "-ParticlesOutlines");
	run("8-bit");
	run("Outline");
	run("16-bit");
	
	run("Merge Channels...", "c1=" + stainingA  + "_raw c2=" + stainingB  + "_raw c3=Outlines-" + stainingA + " c4=Outlines-" + stainingB + " c5=" + stainingB + "-ParticlesOutlines create keep");
	saveAs("Tiff", outputTIFF + "Analyzed-" + stainingA + "+" + stainingB + "_" + filename);
	
	for (i = 0; i < 6; i++) {
		Stack.setChannel(i);
		run("Enhance Contrast", "saturated=0.35");
	}
	run("Yellow");	
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
			Dialog.addString("Dilate A by", "0");
			Dialog.addString("Minumum coloc size", "0");
			Dialog.addString("Maximum coloc size", "Infinity");
			Dialog.addString("Circularity (0-1)", "0");
		Dialog.show();
		stainingA =  Dialog.getChoice();
		stainingB =  Dialog.getChoice();
		colocType = Dialog.getChoice();
		enlargeBy = Dialog.getString();
		minSize = Dialog.getString();
		maxSize = Dialog.getString();
		circularity = Dialog.getString();
		
		if(stainingA == stainingB){
			waitForUser("Please select two different stainings to coloclize.");
			continue;
		}
		break;
	}
	if (colocType == "Whole"){
		quantifyWhole(stainingA, stainingB);
	}else if (colocType == "Partial"){
		quantifyParticular(stainingA, stainingB);
	}
	createCompoundImage(stainingA, stainingB);
	colocName[colocNr] = "Analyzed-" + stainingA + "+" + stainingB + "_" + filename;
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
		run("Make Binary");
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
run("Make Binary");
run("Analyze Particles...", "show=Masks display clear summarize");
saveAs("Tiff", outputTIFF + "Mask-totalArea_" + areaName + "_" + filename);

selectWindow("Results");
saveAs("Results", outputCSV + "totalArea_" + areaName + "_" + fileNoExtension + ".csv");


//Save summary
selectWindow("Summary");
saveAs("Results", outputCSV + "Summary_Background_" + areaName + "_" + fileNoExtension + ".csv");
Table.rename("Summary_Background_" + areaName + "_" + fileNoExtension + ".csv", "Summary");
selectWindow("Log");
saveAs("Text", outputLogs + "Log_" + areaName + "_" + fileNoExtension + ".txt");

selectWindow("Summary");
for (i = 0; i < colocNr; i++) {
	selectWindow(colocName[i]);
}

waitForUser("Quantification succesfull. Check results for accuracy!");
print("Quantification succesfull. Check results for accuracy!");
