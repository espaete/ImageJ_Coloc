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

#@ String (visibility=MESSAGE, value="----SINGLE STAINING SETTINGS----", required=false) msgSingle
#@ String (visibility=MESSAGE, value="----Staining1----", required=false) msg1
#@ String (label="Name", value="DAPI") staining1
#@ String (label="Channel:", value="1") channel1
#@ Boolean (label = "Median filtered image?", style="Checkbox", value = true) filteredImage1
#@ Boolean (label = "Recursive thresholding?", style="Checkbox", value = true) recursive1
#@ Boolean (label = "Fill holes?", style="Checkbox", value = true) fillHoles1
#@ Boolean (label = "Dilate?", style="Checkbox", value = true) isDilate1
#@ Boolean (label = "Close?", style="Checkbox", value = true) isClose1
#@ Boolean (label = "Segment?:", style="Checkbox", value = true) segment1
#@ String (label="Rolling Ball Radius [µm]:", value="15") rbRadius1
#@ String (label="Minimum size [µm^2]:", value="30") minSize1
#@ String (label="Maximum size [µm^2]:", value="Infinity") maxSize1
#@ Float (label="Circularity (low = less stringent):", style="slider", min=0, max=1, stepSize=0.01) circularity1

#@ String (visibility=MESSAGE, value="----Staining2----", required=false) msg2
#@ String (label="Name", value="CA2") staining2
#@ String (label="Channel:", value="4") channel2
#@ Boolean (label = "Median filtered image?", style="Checkbox", value = true) filteredImage2
#@ Boolean (label = "Recursive thresholding?", style="Checkbox", value = true) recursive2
#@ Boolean (label = "Fill holes?", style="Checkbox", value = true) fillHoles2
#@ Boolean (label = "Dilate?", style="Checkbox", value = true) isDilate2
#@ Boolean (label = "Close?", style="Checkbox", value = true) isClose2
#@ Boolean (label = "Segment?:", style="Checkbox", value = false) segment2
#@ String (label="Rolling Ball Radius [µm]:", value="15") rbRadius2
#@ String (label="Minimum size [µm^2]:", value="0") minSize2
#@ String (label="Maximum size [µm^2]:", value="Infinity") maxSize2
#@ Float (label="Circularity (low = less stringent):", style="slider", min=0, max=1, stepSize=0.01) circularity2

#@ String (visibility=MESSAGE, value="----Staining3----", required=false) msg3
#@ String (label="Name", value="LDHA") staining3
#@ String (label="Channel:", value="3") channel3
#@ Boolean (label = "Median filtered image?", style="Checkbox", value = true) filteredImage3
#@ Boolean (label = "Recursive thresholding?", style="Checkbox", value = true) recursive3
#@ Boolean (label = "Fill holes?", style="Checkbox", value = true) fillHoles3
#@ Boolean (label = "Dilate?", style="Checkbox", value = true) isDilate3
#@ Boolean (label = "Close?", style="Checkbox", value = true) isClose3
#@ Boolean (label = "Segment?:", style="Checkbox", value = false) segment3
#@ String (label="Rolling Ball Radius [µm]:", value="30") rbRadius3
#@ String (label="Minimum size [µm^2]:", value="0") minSize3
#@ String (label="Maximum size [µm^2]:", value="Infinity") maxSize3
#@ Float (label="Circularity (low = less stringent):", style="slider", min=0, max=1, stepSize=0.01) circularity3

#@ String (visibility=MESSAGE, value="----COLOCALISATION SETTINGS----", required=false) msgColoc
#@ String (visibility=MESSAGE, value="----Staining 1 X Staining 2----", required=false) msg1x2
#@ Float (label="Coloc Circularity (low = less stringent):", style="slider", min=0, max=1, stepSize=0.01) circularity1x2
#@ String (label="Minimum size [µm^2]:", value="30") minSize1x2
#@ String (label="Maximum size [µm^2]:", value="Infinity") maxSize1x2
#@ Boolean (label = "Segment ?:", style="Checkbox", value = false) segment1x2

#@ String (visibility=MESSAGE, value="----Staining 1 X Staining 3----", required=false) msg1x3
#@ Float (label="Coloc Circularity (low = less stringent):", style="slider", min=0, max=1, stepSize=0.01) circularity1x3
#@ String (label="Minimum size [µm^2]:", value="30") minSize1x3
#@ String (label="Maximum size [µm^2]:", value="Infinity") maxSize1x3
#@ Boolean (label = "Segment ?:", style="Checkbox", value = false) segment1x3

#@ String (visibility=MESSAGE, value="----Staining 2 X Staining 3----", required=false) msg2x3
#@ Float (label="Coloc Circularity (low = less stringent):", style="slider", min=0, max=1, stepSize=0.01) circularity2x3
#@ String (label="Minimum size [µm^2]:", value="30") minSize2x3
#@ String (label="Maximum size [µm^2]:", value="Infinity") maxSize2x3
#@ Boolean (label = "Segment?:", style="Checkbox", value = false) segment2x3

#@ String (visibility=MESSAGE, value="----Staining 1 X Staining 2 X Staining 3----", required=false) msg1x2x3
#@ Float (label="Coloc Circularity (low = less stringent):", style="slider", min=0, max=1, stepSize=0.01) circularity1x2x3
#@ String (label="Minimum size [µm^2]:", value="30") minSize1x2x3
#@ String (label="Maximum size [µm^2]:", value="Infinity") maxSize1x2x3
#@ Boolean (label = "Segment particles?:", style="Checkbox", value = false) segment1x2x3

fillHolesList = toString(fillHoles1) + "," + toString(fillHoles2) + "," + toString(fillHoles3);
fillHolesList= split(fillHolesList,",");
segmentList = toString(segment1) + "," + toString(segment2) + "," + toString(segment3);
segmentList= split(segmentList,",");
minSizeList = minSize1 + "," + minSize2 + "," + minSize3;
minSizeList= split(minSizeList,",");
rbRadiusList = rbRadius1 + "," + rbRadius2 + "," + rbRadius3;
rbRadiusList= split(rbRadiusList,",");
minSizeList = minSize1 + "," + minSize2 + "," + minSize3;
minSizeList= split(minSizeList,",");
maxSizeList = maxSize1 + "," + maxSize2 + "," + maxSize3;
maxSizeList= split(maxSizeList,",");
circularityList = toString(circularity1) + "," + toString(circularity2) + "," + toString(circularity3);
circularityList = split(circularityList,",");
channelList = toString(channel1) + "," + toString(channel1) + "," + toString(channel1);
channelList = split(channelList,",");
recursiveList = toString(recursive1) + "," + toString(recursive2) + "," + toString(recursive3);
recursiveList = split(recursiveList,",");
isCloseList = toString(isClose1) + "," + toString(isClose2) + "," + toString(isClose3);
isCloseList = split(isCloseList,",");
isDilateList = toString(isDilate1) + "," + toString(isDilate2) + "," + toString(isDilate3);
isDilateList = split(isDilateList,",");

run("Fresh Start");
Table.create("Summary");
setOption("BlackBackground", true);
setForegroundColor(0, 0, 0);
setBackgroundColor(0, 0, 0);

//Get number of stainings
stainingsStr = staining1;
if(staining2 != ""){
	if(staining1 != ""){
		stainingsStr = stainingsStr + "+";
	}
	stainingsStr = stainingsStr + staining2;
}
if(staining3 != ""){
	if(staining1 != ""){
		stainingsStr = stainingsStr + "+";
	}
	stainingsStr = stainingsStr + staining3;
}

allStainings = split(stainingsStr,"+");

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
print("Nr. of stainings: " + allStainings.length);

for (i = 0; i < allStainings.length; i++) {
	print("Staining " + i+1 + ": " + allStainings[i]);
	print("Channel: " + channelList[i]);
	print("Fill holes: " + fillHolesList[i]);
	print("Is close: " + isCloseList[i]);
	print("Is dilate: " + isDilateList[i]);
	print("Recursive thresholding: " + recursiveList[i]);
	print("Segment particles: " + segmentList[i]);
	print("Rolling ball radius: " + rbRadiusList[i]);
	print("Minimum size [µm^2]: " + minSizeList[i]);
	print("Maximum size [µm^2]: " + maxSizeList[i]);
	print("Circularity: " + circularityList[i] + " - 1");
}
//END

//START --- Main Script
//Select region of interest and save as .tiff
run("Brightness/Contrast...");
run("Channels Tool...");
run("ROI Manager...");
roiManager("reset");

waitForUser("Select the region of interest you want to analyze");
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
function removeBackground(staining, channelNr, rbRadius, filteredImage){
	//Removes background by subtracting the median filtered image
	//Further removes background via imageJ function "Subtract Background".
	if(staining != ""){
		selectWindow("C" + channelNr + "-Staining"); 
		rename(staining + "_" + areaName + "_raw");
		if(filteredImage){
			print("Median filtered " + staining + ": Yes");
			print(medianFilter + File.separator + "Filtered_" + staining + "-" + filename);
			open(medianFilter + File.separator + "Filtered_" + staining + "-" + filename);
			duplicateROI("Background-" + staining);
			
			//Subtract filtered image from original
			imageCalculator("Subtract create", staining + "_" + areaName + "_raw", "Background-" + staining);
			close("Filtered_" + staining + "-" + filename);
		}else{
			print(staining + ": No");
		}

		//Further reduce background
		run("Subtract Background...", "rolling=" + rbRadius);
		rename(staining + "_" + areaName + "_noBG");
		
		//Cut out outside areas and artifacts
		if(roiManager("count") > 0 && File.exists(outputROI + areaName + "-CutAreas-ROI_" + fileNoExtension + ".zip")){
			roiManager("Deselect");
			roiManager("Delete");
			roiManager("Open", outputROI + areaName + "-CutAreas-ROI_" + fileNoExtension + ".zip");
			roiManager("Fill");
		}
		
	}
}

function duplicateROI(newName){
	if(roiManager("count") > 0){
		roiManager("Deselect");
		roiManager("Delete");
	}
	roiManager("Open", outputROI + areaName + "-ROI_" + fileNoExtension + ".zip");
	roiManager("Select", 0);
	run("Duplicate...", "title=" + newName);
	
}

selectWindow(areaName);
run("Duplicate...", "title=Staining duplicate");
run("Split Channels");

removeBackground(staining1, channel1, rbRadius1, filteredImage1);
removeBackground(staining2, channel2, rbRadius2, filteredImage2);
removeBackground(staining3, channel3, rbRadius3, filteredImage3);

//Quantify single labeling

function quantifyLabeling(staining, recursive, fillHoles, isDilate, isClose, minSize, maxSize, circularity, segment){
	//Quantifies labeling area and particles.--
	//Uses user input of minimal size and circularity to correctly identify particles.
	//If selected, segments particles with "segmentParticles" function. Note: Can take up to several minutes.
	//Can be repeated by user until quantification is aggreeable.
	if(staining != ""){
		repeatLoop = true;
		n = 0;
		while (repeatLoop) {
			n++;
			print("Trail " + n);
			selectWindow(staining + "_" + areaName + "_noBG");
			run("Duplicate...", "title=" + staining + "_" + areaName + "_noBG-Double");
			run("Despeckle");
			run("Median...", "radius=4");
			run("Mean...", "radius=4");
			setAutoThreshold("Percentile dark");
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
			
			if(recursive){
				recursiveThresholding(staining);
			}else{
				run("Analyze Particles...", "size=" + minSize + "-Infinity circularity=" + circularity + "-Infinity show=Masks");
				rename("Mask-" + staining);
				run("Create Selection");
				waitForUser("Check the quantification.");
				run("Select None");
			}
			
			repeatLoop = getBoolean("Is the quantification ok?", "No, repeat", "Yes, continue");
			if (repeatLoop) {
				close("Mask-" + staining);
				close("Raw-Mask-" + staining);
				close(staining + "_raw");
				close(staining + "_" + areaName + "_noBG-Double");
				continue;
			}
			
			saveAs("Tiff", outputTIFF + "Mask-" + staining + "_" + areaName + "_" + filename);
			saveAs("Results", outputCSV + staining + "_" + areaName + "_" + fileNoExtension + ".csv");
			rename("Mask-" + staining);
			run("Select None");
			
			run("Analyze Particles...", "size=0-Infinity show=[Bare Outlines]");
			run("Make Binary");
			rename("Outlines-" + staining);
			run("16-bit");
			//Quantify intensity
			selectWindow(staining + "_" + areaName + "_raw");
			run("Duplicate...", "title=" + staining);
			run("Select None");
			selectWindow("Mask-" + staining);
			run("Make Binary");
			run("Create Selection");
			selectWindow(staining);
			run("Restore Selection");
			run("Clear");
			run("Select None");
			setThreshold(1, Math.pow(2,bitDepth()));
			run("Analyze Particles...", "display clear summarize");
			selectWindow("Mask-" + staining);
		}
	}
}

function recursiveThresholding(staining){
	close("C3-Composite");
	getThreshold(lower, upper);
	stepSize = getString("Step Size:", "1");
	run("Duplicate...", "title=Image");
	run("Duplicate...", "title=Output");
	
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
	
	while (true) {
		close("OversizedMask");
		selectWindow("Image");
		setThreshold(lower, upper);
		lower = lower + stepSize;
		print(lower);
		
		//Get correct sized particles
		run("Create Mask");
		close("OversizedOG");
		run("Make Binary");
		rename("ThresholdMask");
		if (segment){
			run("Watershed");
		}
		if (isDilate) {
			run("Median...", "radius=0");
			run("Dilate");
			run("Dilate");
		}
		if (isClose) {
			run("Close-");
		}
		if (fillHoles) {
			run("Fill Holes");
		}
		if (isDilate) {
			run("Erode");
		}
		run("Analyze Particles...", "size=" + minSize + "-" + maxSize + " show=Masks");
		run("Make Binary");
		run("Create Selection");
		run("Make Inverse");
		if (selectionType() != -1){
			//Checks if there are any new particles
			//Copies them into the output
			run("Make Inverse");
			run("Copy");
			selectWindow("Output");
			run("Restore Selection");
			run("Paste");
			run("Select None");
		}
		
		close("Mask of ThresholdMask");
		//Get oversized particles
		selectWindow("ThresholdMask");
		run("Analyze Particles...", "size=" + maxSize + "-Infinity show=Masks");
		rename("OversizedMask");
		run("Create Selection");
		selectWindow("Image");
		run("Duplicate...", "title=OversizedOG");
		run("Restore Selection");
		run("Make Inverse");
		if (selectionType() == -1 || lower >= upper) {
			//Checks there are still any oversized particles, or if the threshold is maxed out
			//If true, exits loop
			run("Select None");
			close("Image");
			rename("Image");
			selectWindow("Output");
			break
		}else{
			//If there are still oversized particles, 
			run("Clear Outside");
		}
		run("Select None");
		close("Image");
		rename("Image");
		selectWindow("Oversized");
		run("Restore Selection");
		run("Clear Outside");
		run("Select None");
		close("ThresholdMask");
	}
	setBatchMode(false);
	selectWindow("Output");
	if (isDilate && fillHoles){
		run("Dilate");
		run("Fill Holes");
		run("Erode");
		run("Erode");
	}
	selectWindow(staining + "_" + areaName + "_noBG");
	run("Duplicate...", "title=NoBG");
	selectWindow(staining + "_" + areaName + "_raw");
	run("Duplicate...", "title=OG_Image");
	run("Duplicate...", "title=ManualMask");
	selectWindow("Output");
	run("Select None");
	run("Create Selection");
	run("Select None");
	selectWindow("ManualMask");
	run("Restore Selection");
	run("Clear");
	run("Select None");
	waitForUser("Manually add missed signals");
	setThreshold(0, 1);
	run("Convert to Mask");
	close("Output");
	selectWindow("ManualMask");
	rename("Output");
	
	run("Analyze Particles...", "size=0-Infinity show=[Bare Outlines]");
	run("Make Binary");
	rename("Outlines");
	run("16-bit");
	selectWindow("Output");
	run("16-bit");
	run("Invert");
	run("Merge Channels...", "c1=OG_Image c2=NoBG c3=Outlines create");
	rename("Composite-" + staining);
	Stack.setChannel(1);
	run("Enhance Contrast", "saturated=0.35");
	run("Grays");
	Stack.setChannel(2);
	run("Grays");
	Stack.setChannel(3);
	run("Red");
	Stack.setActiveChannels("011");
	run("Channels Tool...");
	setForegroundColor(Math.pow(2,bitDepth()), Math.pow(2,bitDepth()), Math.pow(2,bitDepth()));
	waitForUser("Check for accuracy and modify accordingly");
	getDimensions(width, height, channels, slices, frames);
	makeRectangle(0, 0, width-1, height-1);
	run("Draw", "slice");
	makeRectangle(0, 0,2, 2);
	run("Clear", "slice");
	run("Select None");
	setForegroundColor(0,0,0);
	run("Duplicate...", "duplicate channels=3");
	rename("C3-Composite");
	run("8-bit");
	run("Make Binary");
	run("Create Selection");
	run("Select None");
	run("Close-");
	run("Fill Holes");
	run("Restore Selection");
	run("Clear");
	run("Select None");
	close("Oversized");
	close("Outlines");
	close("Output");
}

for (i = 0; i < allStainings.length; i++) {
	quantifyLabeling(allStainings[i], recursiveList[i], fillHolesList[i], isDilateList[i], isCloseList[i], minSizeList[i], maxSizeList[i], circularityList[i], segmentList[i]);
}

//Quantify colocalisation
function quantifyColoc(stainingString, minSize, maxSize, circularity, fillHoles, segment) { 
//Quantifies colocalisation by overlapping the corresponding masks created by "quantifyLabeling".
	stainings = split(stainingString,"+");
	if (stainings.length > 1){
		mask = "Mask-" + stainingString;
		if (isOpen("Mask-" + stainings[1] + "+" + stainings[0])){
			mask = "Mask-" + stainings[1] + "+" + stainings[0];
			selectWindow(mask);
		}else{
			for (i = 0; i < stainings.length; i++) {
				selectWindow("Mask-" + stainings[i]);
				run("Select None");
				resetThreshold();
				run("Make Binary");
			}
			selectWindow("Mask-" + stainings[0]);
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
			run("Analyze Particles...", "size=" + minSize + "-Infinity show=Masks");
			
			rename(mask);
			run("Make Binary");
			if (isOpen(stainings[0] + "_" + areaName + "_raw") && isOpen(stainings[1] + "_" + areaName + "_raw")){
				run("Analyze Particles...", "size=0-Infinity show=[Bare Outlines]");
				run("Make Binary");
				rename("Outlines-" + stainings[0] + "+" + stainings[1]);
				run("16-bit");
				run("Merge Channels...", "c1=" + stainings[0] + "_" + areaName + "_noBG c2=" + stainings[1] + "_" + areaName + "_noBG c3=" + stainings[0] + "_" + areaName + "_raw c4=" + stainings[1] + "_" + areaName + "_raw c5=Outlines-" + stainings[0] + "+" + stainings[1] + " create keep");
				rename(stainings[0] + "+" + stainings[1] + "_Composite");
				Stack.setChannel(1);
				run("Enhance Contrast...", "saturated=0.35");
				Stack.setChannel(2);
				run("Enhance Contrast...", "saturated=0.35");
				Stack.setChannel(5);
				Stack.setActiveChannels("11001");
				close(mask);
				close("Outlines-" + stainings[0] + "+" + stainings[1]);
				setForegroundColor(255, 255, 255);
				waitForUser("Check quantification and modify accordingly.");
				run("Select None");
				getDimensions(width, height, channels, slices, frames);
				makeRectangle(0, 0, width-1, height-1);
				run("Draw", "slice");
				makeRectangle(0, 0,2, 2);
				run("Clear", "slice");
				run("Select None");
				setForegroundColor(0, 0, 0);
				run("Duplicate...", "title=" + mask + " duplicate channels=5");
				
				//Refill Outlines
				run("8-bit");
				run("Create Selection");
				
				run("Select None");
				run("Fill Holes");
				run("Restore Selection");
				
				run("Clear");
				run("Select None");
			}
		}
			
		run("Create Selection");
		run("Select None");
		selectWindow(stainings[0] + "_" + areaName + "_raw");
		run("Duplicate...", "title=" + stainingString);
		run("Restore Selection");
		
		run("Clear Outside");
		run("Select None");
		setThreshold(1, Math.pow(2,bitDepth()));
		run("Analyze Particles...", "size=" + minSize + "-" + maxSize + " circularity=" + circularity + "-1.00 show=Masks display clear summarize");
		saveAs("Results", outputCSV + stainingString + "_" + areaName + "_" + fileNoExtension + ".csv");
		rename(mask);
		run("Analyze Particles...", "size=0-Infinity show=[Bare Outlines]");
		run("Make Binary");
		rename("Outlines-" + stainingString);
		
		run("16-bit");
		if (stainings.length < 3){
			run("Merge Channels...", "c1=" + stainings[0] + "_" + areaName + "_raw c2=" + stainings[1] + "_" + areaName + "_raw c3=Outlines-" + stainings[0] + "+" + stainings[1] +  " create keep");
			rename("Composite_" + stainings[0] + "+" + stainings[1]);
		}
	}
}

if (allStainings.length > 1){	
	quantifyColoc(staining1 + "+" + staining2, minSize1x2, maxSize1x2, circularity1x2, fillHoles1, segment1);
	quantifyColoc(staining2 + "+" + staining1, minSize1x2, maxSize1x2, circularity1x2, fillHoles1, segment1);
	quantifyColoc(staining1 + "+" + staining3, minSize1x3, maxSize1x3, circularity1x3, fillHoles1, segment1);
	quantifyColoc(staining3 + "+" + staining1, minSize1x3, maxSize1x3, circularity1x3, fillHoles1, segment1);
	quantifyColoc(staining2 + "+" + staining3, minSize2x3, maxSize2x3, circularity2x3, fillHoles2, segment2);
	quantifyColoc(staining3 + "+" + staining2, minSize2x3, maxSize2x3, circularity2x3, fillHoles2, segment2);
}
if (allStainings.length > 2){
	quantifyColoc(staining1 + "+" + staining2 + "+" + staining3, minSize1x2x3, maxSize1x2x3, circularity1x2x3, fillHoles1, segment1);
	quantifyColoc(staining3 + "+" + staining1 + "+" + staining2, minSize1x2x3, maxSize1x2x3, circularity1x2x3, fillHoles1, segment1);
	quantifyColoc(staining2 + "+" + staining3 + "+" + staining1, minSize1x2x3, maxSize1x2x3, circularity1x2x3, fillHoles1, segment1);
}

function backgroundIntensity(staining){
	//Quantifies background staining, ie. all areas that are previously not identified as part of the signal.
	if (staining != ""){
		selectWindow(staining + "_" + areaName + "_raw");
		run("Duplicate...", "title=" + staining + "_Background");
		roiManager("fill");
		roiManager("Deselect");
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
		saveAs("Results", outputCSV + "Background-" + staining + "_" + areaName + "_" + fileNoExtension + ".csv");
	}
}

for (i = 0; i < allStainings.length; i++) {
	backgroundIntensity(allStainings[i]);
}

//Quantify total area
selectWindow(areaName);
run("Select None");
run("Duplicate...", "title=Area duplicate channels=1");
roiManager("Fill");
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
saveAs("Results", outputCSV + "Summary_" + areaName + "_" + fileNoExtension + ".csv");
Table.rename("Summary_" + areaName + "_" + fileNoExtension + ".csv", "Summary");
selectWindow("Log");
saveAs("Text", outputLogs + "Log_" + areaName + "_" + fileNoExtension + ".txt");

for (i = 0; i < allStainings.length-1; i++) {
	selectWindow("Mask-" + allStainings[i] + "+" + allStainings[i+1]);
	run("Select None");
	run("Make Binary");
	run("Analyze Particles...", "size=0-Infinity show=[Bare Outlines]");
	run("Make Binary");
	rename("Outlines-" + allStainings[i] + "+" + allStainings[i+1]);
	run("16-bit");
}

if (allStainings.length > 2) {
	selectWindow("Mask-" + allStainings[0] + "+" + allStainings[2]);
	run("Select None");
	run("Make Binary");
	
	run("Analyze Particles...", "size=0-Infinity show=[Bare Outlines]");
	run("Make Binary");
	rename("Outlines-" + allStainings[0] + "+" + allStainings[2]);
	run("16-bit");
	selectWindow("Mask-" + allStainings[0] + "+" + allStainings[1] + "+" + allStainings[2]);
	run("Select None");
	run("Make Binary");
	
	run("Analyze Particles...", "size=0-Infinity show=[Bare Outlines]");
	run("Make Binary");
	rename("Outlines-" + allStainings[0] + "+" + allStainings[1] + "+" + allStainings[2]);
	run("16-bit");
}

mergingString = "";
ci = 0; //Channel Index
for (i = 0; i < allStainings.length; i++) {
	ci++;
	mergingString = mergingString + "c" + ci + "=" + allStainings[i] + "_" + areaName + "_raw ";
}
for (i = 0; i < allStainings.length; i++) {
	ci++;
	mergingString = mergingString + "c" + ci + "=Outlines-" + allStainings[i] + " ";
}

ci++;
mergingString = mergingString + "c" + ci + "=Outlines-" + stainingsStr;
run("Merge Channels...", mergingString +  " create keep");
saveAs("Tiff", outputTIFF + "Analyzed-" + filename);

Stack.getDimensions(width, height, channels, slices, frames);
for (i = 0; i < allStainings.length; i++) {
	Stack.setChannel(i);
	run("Enhance Contrast", "saturated=0.35");
}
Stack.setChannel(channels);
run("Yellow");
wait(1000);
run("Invert", "slice");

selectWindow("Summary");
waitForUser("Quantification succesfull. Check results for accuracy!");
run("Invert", "slice");
print("Quantification succesfull. Check results for accuracy!");
