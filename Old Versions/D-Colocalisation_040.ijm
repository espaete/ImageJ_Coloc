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
#@ String (label="Background Channel (can be any channel that has a visible background, used to quantify total area)", value=2) backgroundChannel
#@ Boolean (label="Do you want to quantify cells?", value=2) isCells


#@ String (visibility=MESSAGE, value="----SINGLE STAINING SETTINGS----", required=false) msgSingle
#@ String (visibility=MESSAGE, value="----Staining1----", required=false) msg1
#@ String (label="Name", value="DAPI") staining1
#@ String (label="Channel:", value="1") channel1
#@ Boolean (label = "Median filtered image?", style="Checkbox", value = true) filteredImage1
#@ Boolean (label = "Recursive thresholding?", style="Checkbox", value = true) recursive1
#@ Boolean (label = "Fill holes?", style="Checkbox", value = true) fillHoles1
#@ Boolean (label = "Dilate?", style="Checkbox", value = true) isDilate1
#@ Boolean (label = "Close?", style="Checkbox", value = true) isClose1
#@ Boolean (label = "Segment particles? (Note: Can take several minutes.):", style="Checkbox", value = true) segment1
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
#@ Boolean (label = "Segment particles? (Note: Can take several minutes.):", style="Checkbox", value = false) segment2
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
#@ Boolean (label = "Segment particles?:", style="Checkbox", value = false) segment3
#@ String (label="Rolling Ball Radius [µm]:", value="30") rbRadius3
#@ String (label="Minimum size [µm^2]:", value="0") minSize3
#@ String (label="Maximum size [µm^2]:", value="Infinity") maxSize3
#@ Float (label="Circularity (low = less stringent):", style="slider", min=0, max=1, stepSize=0.01) circularity3

#@ String (visibility=MESSAGE, value="----COLOCALISATION SETTINGS----", required=false) msgColoc
#@ String (visibility=MESSAGE, value="----Staining 1 X Staining 2----", required=false) msg1x2
#@ Float (label="Coloc Circularity (low = less stringent):", style="slider", min=0, max=1, stepSize=0.01) circularity1x2
#@ String (label="Minimum size [µm^2]:", value="30") minSize1x2
#@ String (label="Maximum size [µm^2]:", value="Infinity") maxSize1x2
#@ Boolean (label = "Coloc Cells?:", style="Checkbox", value = false) colocCells1x2
#@ String (label="Sensitivity [µm]:", value="2") sensitivity1x2
#@ Boolean (label = "Segment particles?:", style="Checkbox", value = false) segment1x2

#@ String (visibility=MESSAGE, value="----Staining 1 X Staining 3----", required=false) msg1x3
#@ Float (label="Coloc Circularity (low = less stringent):", style="slider", min=0, max=1, stepSize=0.01) circularity1x3
#@ String (label="Minimum size [µm^2]:", value="30") minSize1x3
#@ String (label="Maximum size [µm^2]:", value="Infinity") maxSize1x3
#@ Boolean (label = "Coloc Cells?:", style="Checkbox", value = false) colocCells1x3
#@ String (label="Sensitivity [µm]:", value= 2) sensitivity1x3
#@ Boolean (label = "Segment particles?:", style="Checkbox", value = false) segment1x3

#@ String (visibility=MESSAGE, value="----Staining 2 X Staining 3----", required=false) msg2x3
#@ Float (label="Coloc Circularity (low = less stringent):", style="slider", min=0, max=1, stepSize=0.01) circularity2x3
#@ String (label="Minimum size [µm^2]:", value="30") minSize2x3
#@ String (label="Maximum size [µm^2]:", value="Infinity") maxSize2x3
#@ Boolean (label = "Coloc Cells?:", style="Checkbox", value = false) colocCells2x3
#@ String (label="Sensitivity [µm]:", value="2") sensitivity2x3
#@ Boolean (label = "Segment particles?:", style="Checkbox", value = false) segment2x3

#@ String (visibility=MESSAGE, value="----Staining 1 X Staining 2 X Staining 3----", required=false) msg1x2x3
#@ Float (label="Coloc Circularity (low = less stringent):", style="slider", min=0, max=1, stepSize=0.01) circularity1x2x3
#@ String (label="Minimum size [µm^2]:", value="30") minSize1x2x3
#@ String (label="Maximum size [µm^2]:", value="Infinity") maxSize1x2x3
#@ Boolean (label = "Coloc Cells?:", style="Checkbox", value = false) colocCells1x2x3
#@ String (label="Sensitivity [µm]:", value="2") sensitivity1x2x3
#@ Boolean (label = "Segment particles?:", style="Checkbox", value = false) segment1x2x3

run("Fresh Start");
setOption("BlackBackground", true);
//Get number of stainings
stainingsInput = staining1 + "," + staining2 + "," + staining3;
allStainings = split(stainingsInput,",");
allStainings = Array.deleteValue(allStainings, "");

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
function duplicateROI(newName){
	if(roiManager("count") > 0){
		roiManager("Deselect");
		roiManager("Delete");
	}
	roiManager("Open", outputROI + areaName + "-ROI_" + fileNoExtension + ".zip");
	roiManager("Select", 0);
	run("Duplicate...", "title=" + newName);
	
}
//END --- Functions

//START --- Open image
run("Close All");
open(inputFile);
getPixelSize(unit, pixelWidth, pixelHeight);
filename = getTitle();
fileNoExtension = File.nameWithoutExtension
run("Threshold...");
//END

//START --- Log
print("\\Clear")
print(fileNoExtension);
print(areaName);
print("Nr. of stainings: " + allStainings.length);

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

for (i = 0; i < allStainings.length; i++) {
	print("Staining " + i+1 + ": " + allStainings[i]);
	print("Fill holes: " + fillHolesList[i]);
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

//Get negative region of interest selection
selectWindow(areaName);
run("Restore Selection");
run("Make Inverse");
if(selectionType() != -1){
	roiManager("add");
}

//Select artifacts to remove
roiManager("Show All");
waitForUser("Select artifacts and regions that you don't want to analzye and add them to the ROI manager [by pressing t]");
run("Select None");
if(roiManager("count") > 0){
	roiManager("save", outputROI + areaName + "-CutAreas-ROI_" + fileNoExtension + ".zip")
}else if(File.exists(outputROI + areaName + "-CutAreas-ROI_" + fileNoExtension + ".zip")){
	File.delete(outputROI + areaName + "-CutAreas-ROI_" + fileNoExtension + ".zip");
}


//Reset Summary
Table.create("Summary");

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
			run("Duplicate...","title=Outlines-" + staining);
			run("Outline");
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
			run("Clear Outside");
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
	
	while(true) {
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
		if(segment){
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
		if(selectionType() != -1){
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
			saveAs("Tiff", "/Users/erik/Documents/Output.tif");
			rename("Output");
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
	if(isDilate && fillHoles){
		run("Dilate");
		run("Fill Holes");
		run("Erode");
		run("Erode");
	}
	run("Duplicate...", "title=Outlines");
	run("Outline");
	run("16-bit");
	selectWindow("Output");
	run("16-bit");
	run("Invert");
	selectWindow(staining + "_" + areaName + "_raw");
	run("Duplicate...", "title=OG_Image");
	selectWindow(staining + "_" + areaName + "_raw");
	 run("Duplicate...", "title=NoBG");
	run("Merge Channels...", "c1=OG_Image c2=NoBG c3=Outlines create");
	Stack.setChannel(1);
	run("Enhance Contrast", "saturated=0.35");
	run("Grays");
	Stack.setChannel(2);
	run("Grays");
	Stack.setChannel(3);
	run("Red");
	Stack.setActiveChannels("011");
	run("Channels Tool...");
	setBackgroundColor(Math.pow(2,bitDepth()), Math.pow(2,bitDepth()), Math.pow(2,bitDepth()));
	waitForUser("Check for accuracy and modify accordingly");
	setBackgroundColor(0,0,0);
	run("Split Channels");
	close("C1-Composite");
	close("C2-Composite");
	selectWindow("C3-Composite");
	run("8-bit");
	run("Make Binary");
	run("Create Selection");
	run("Select None");
	run("Fill Holes");
	run("Restore Selection");
	run("Clear");
	run("Select None");
	close("Oversized");
	close("Outlines");
}

quantifyLabeling(staining1, recursive1, fillHoles1, isDilate1, isClose1, minSize1, maxSize1, circularity1, segment1);
quantifyLabeling(staining2, recursive2, fillHoles2, isDilate2, isClose2, minSize2, maxSize2, circularity2, segment2);
quantifyLabeling(staining3, recursive3, fillHoles3, isDilate3, isClose3, minSize3, maxSize3, circularity3, segment3);

//Quantify number of positive cells
function getPositiveCells(stainingA, stainingB, minSize, maxSize, circularity, sensitivity, segment, colocCells){
	//Overlays masks of two stainings, resulting in brighter shadings for the overlapped area.
	//Runs a maximum filter, which increases the area where the two masks overlapp.
	//Runs threshold with user set circularity, max and min size thresholds.
	//Will result in a mask that marks cells with significant overlapp
	//User can set the maximum radius value, higher value means higher sensitivity, but more false positives.
	if(colocCells && sensitivity != "" &&  matches(stainingA, "\\w+.*")&& matches(stainingB, "\\w+.*")){
		repeatLoop = true;
		while (repeatLoop) {
			print(repeatLoop);
			close("StainingA");
			close("StainingB");
			close(stainingA + "+" + stainingB + "_Positive-Cells");
			close("Outlines-" + stainingA + "+" + stainingB);
			

			getPixelSize(unit, pixelWidth, pixelHeight);
			selectWindow("Mask-" + stainingB);
			run("Select None");
			resetThreshold();
			run("Make Binary"); 
			run("Analyze Particles...", "size=" + minSize + "-" + maxSize + " show=Masks");
			run("Make Binary");
			rename("StainingB");
			selectWindow("Mask-" + stainingA);
			run("Select None");
			resetThreshold();
			run("Make Binary");
			resetThreshold();
			run("Analyze Particles...", "size=" + minSize + "-" + maxSize + " show=Masks");
			run("Make Binary");
			rename("StainingA");
			dilateTimes = getNumber("Dilate x times:", 3);
			for (i = 0; i < dilateTimes; i++) {
				run("Dilate");
			}
			selectWindow("Mask-" + stainingA);
			run("Find Maxima...", "prominence=1 output=[Segmented Particles]");
			run("Make Binary");
			run("Create Selection");
			selectWindow("StainingA");
			run("Restore Selection");
			run("Clear");
			run("Select None");
			run("Create Selection");
			run("Select None");
			run("Merge Channels...", "c1=StainingA c2=StainingB keep");
			rename(stainingA + "+" + stainingB + "_RGB");
			run("8-bit");
			run("Restore Selection");
			strictness = getString("Strictness=", "1");
			run("Median...", "radius=" + strictness);
			for (i = 0; i < 20; i++) {
				run("Maximum...", "radius=1");
				run("Clear Outside");
			}
			run("Select None");
			setThreshold(125, 255);
			rename(stainingA + "+" + stainingB + "_Cells");
			run("Analyze Particles...", "size=" + minSize + "-" + maxSize + " circularity=" + circularity + "-1.00 show=Masks");
			rename("Mask");
			run("Make Binary");
			run("Duplicate...", "title=Outlines-" + stainingA + "+" + stainingB);
			run("Outline");
			run("16-bit");
			run("Merge Channels...", "c1=" + stainingA + "_" + areaName + "_raw c2=" + stainingB + "_" + areaName + "_raw c3=Outlines-" + stainingA + "+" + stainingB + " create keep");
			rename(stainingA + "+" + stainingB + "_Positive-Cells");
			Stack.setActiveChannels("111");
			setForegroundColor(Math.pow(2,bitDepth()), Math.pow(2,bitDepth()), Math.pow(2,bitDepth()));
			Stack.setChannel(1);
			run("Enhance Contrast...", "saturated=0.35");
			Stack.setChannel(2);
			run("Enhance Contrast...", "saturated=0.35");
			Stack.setChannel(3);
			waitForUser("Check for accuracy and modify accordingly");
			setForegroundColor(0,0,0);
			repeatLoop = getBoolean("Repeat?");
			print(repeatLoop);
			if(!repeatLoop){
				run("Duplicate...", "title=QuantifiedCells duplicate channels=3");
				run("8-bit");
				run("Make Binary");
				run("Create Selection");
				run("Select None");
				run("Fill Holes");
				run("Restore Selection");
				run("Clear");
				run("Select None");
				
				getCellColocIntensity("QuantifiedCells", stainingA);
				rename("Cells_" + stainingA + "+" + stainingB);
				run("Analyze Particles...", "size= show=Masks summarize");
				getCellColocIntensity("QuantifiedCells", stainingB);
				rename("Cells_" + stainingB + "+" + stainingA);
				run("Analyze Particles...", "size= show=Masks summarize");
			}
			
			close("Cells-" + stainingA + "+" + stainingB);
			close("Cells-" + stainingB + "+" + stainingA);
			close(stainingA + "+" + stainingB + "_RGB");
			close("QuantifiedCells");
			close("StainingA");
			close("StainingB");
			print(repeatLoop);
		}
		
	}
}


function getCellColocIntensity(mask, stainingA){
	selectWindow(mask);	
	run("Create Selection");
	run("Select None");
	selectWindow(stainingA + "_" + areaName + "_raw");
	run("Duplicate...", "title=" + stainingA + "_" + areaName + "_raw duplicate");
	run("Restore Selection");
	run("Clear Outside");
	run("Select None");
	setThreshold(1, Math.pow(2,bitDepth()));
}

repeatLoop = true;
while (isCells && repeatLoop) {
	repeatLoop = false;
	getPositiveCells(staining1, staining2, minSize1x2, maxSize1x2, circularity1x2, sensitivity1x2, segment1x2, colocCells1x2);
	getPositiveCells(staining1, staining3, minSize1x3, maxSize1x3, circularity1x3, sensitivity1x3, segment1x3, colocCells1x3);
	getPositiveCells(staining2, staining3, minSize2x3, maxSize2x3, circularity2x3, sensitivity2x3, segment2x3, colocCells2x3);
	
	if(allStainings.length == 3){
		selectWindow("Mask of Cells_" + staining1 + "+" + staining2);
		run("Make Binary");
		run("Duplicate...", "title=" + staining1 + "+" + staining2 + "+" + staining3 + "_Cells");
		selectWindow("Mask of Cells_" + staining1 + "+" + staining3);
		run("Make Binary");
		run("Create Selection");
		selectWindow(staining1 + "+" + staining2 + "+" + staining3 + "_Cells");
		run("Restore Selection");
		run("Clear Outside");
		run("Analyze Particles...", "size=" + minSize1x2x3 + "-" + maxSize1x2x3 + " circularity=" + circularity1x2x3 + "-1.00 show=Masks");
		rename("TripleMask");
		run("Make Binary");
		run("Outline");
		run("16-bit");
		run("Merge Channels...", "c1=" + staining1 + "_" + areaName + "_raw c2=" + staining2 + "_" + areaName + "_raw c3=" + staining3 + "_" + areaName + "_raw" + " c4=Outlines-" + staining1 + "+" + staining2 + " c5=Outlines-" + staining1 + "+" + staining3 + " c6=Outlines-" + staining2 +  " c7=TripleMask create keep");
		rename("TripleColoc");
		Stack.setActiveChannels("1110001");
		Stack.setChannel(7);
		run("Yellow");
		
		waitForUser("Check Coloc");
		repeatLoop = getBoolean("Repeat?");
		if(repeatLoop){
			close(staining1 + "+" + staining2 + "+" + staining3 + "_Cells");
			close("TripleMask");
			close("TripleColoc");
			continue;
		}
		
		saveAs(outputTIFF + "TripleColoc_" + staining1 + "+" + staining2 + "+" + staining3);
		run("Duplicate...", "title=TripleStainingMask duplicate channels=7");
		run("8-bit");
		run("Make Binary");
		run("Fill Holes");
		run("Watershed");
		getCellColocIntensity("TripleStainingMask", staining1);
		rename("Cells_" + staining1 + "+" + staining2 + "+" + staining3);
		run("Analyze Particles...", "size= show=Masks summarize");
		getCellColocIntensity("TripleStainingMask", staining2);
		rename("Cells_" + staining2 + "+" + staining3 + "+" + staining1);
		run("Analyze Particles...", "size= show=Masks summarize");
		getCellColocIntensity("TripleStainingMask", staining3);
		rename("Cells_" + staining3 + "+" + staining2 + "+" + staining1);
		run("Analyze Particles...", "size= show=Masks summarize");
	}
}


//Quantify colocalisation
function quantifyColoc(stainingA, stainingB, minSize, maxSize, circularity, fillHoles, segment) { 
//Quantifies colocalisation by overlapping the corresponding masks created by "quantifyLabeling".
	if(matches(stainingA, "\\w+.*") && matches(stainingB, "\\w+.*")){
		selectWindow("Mask-" + stainingB);
		run("Select None");
		resetThreshold();
		run("Make Binary");
		selectWindow("Mask-" + stainingA);
		run("Select None");
		run("Make Binary");
		run("Create Selection");
		run("Select None");
		selectWindow("Mask-" + stainingB);

		if(isOpen("Mask-" + stainingA + stainingB)){
			selectWindow("Mask-" + stainingA + stainingB);
			run("Duplicate...", "Mask-" + stainingA + stainingB);
		}else{
			run("Duplicate...", "Mask-" + stainingA + stainingB);
			run("Restore Selection");
			run("Clear Outside");
			run("Select None");
			run("16-bit");
			run("Duplicate...", "title=Outlines");
			run("Merge Channels...", "c1=" + stainingA + "_" + areaName + "_raw c2=Outlines c3=Mask-" + stainingA + "+" + stainingB +  " create keep");
			Stack.setChannel(1);
			run("Enhance Contrast...", "saturated=0.35");
			Stack.setChannel(3);
			Stack.setActiveChannels("110");
			close("Mask-" + stainingA + stainingB);
			close("Outlines");
			waitForUser("Check quantification and modify accordingly.");
			run("Duplicate...", "title=Mask-" + stainingA + stainingB + " duplicate channels=3");
		}
		run("Create Selection");
		selectWindow(stainingA + "_" + areaName + "_raw");
		run("Duplicate...", "title=" + stainingA + "+" + stainingB);
		run("Restore Selection");
		run("Clear Outside");
		run("Select None");
		setThreshold(1, Math.pow(2,bitDepth()));
		run("Analyze Particles...", "size=" + minSize + "-" + maxSize + " circularity=" + circularity + "-1.00 show=Masks display clear summary");
		saveAs("Results", outputCSV + stainingA + "+" + stainingB + "_" + areaName + "_" + fileNoExtension + ".csv");
		rename("Mask-" + stainingA + "+" + stainingB);
		run("Duplicate...", "title=Outlines " + stainingA + "+" + stainingB);
		run("Outline");
		run("16-bit");
		if(isOpen(stainingA + "_" + areaName + "_raw") && isOpen(stainingB + "_" + areaName + "_raw")){
			run("Merge Channels...", "c1=" + stainingA + "_" + areaName + "_raw c2=" + stainingB + "_" + areaName + "_raw c3=Outlines " + stainingA + "+" + stainingB +  " create keep");
			rename("Composite_" + stainingA + "+" + stainingB);
		}
	}
}

quantifyColoc(staining1, staining2, minSize1x2, maxSize1x2, circularity1x2, fillHoles1, segment1);
quantifyColoc(staining2, staining1, minSize1x2, maxSize1x2, circularity1x2, fillHoles1, segment1);
quantifyColoc(staining1, staining3, minSize1x3, maxSize1x3, circularity1x3, fillHoles1, segment1);
quantifyColoc(staining3, staining1, minSize1x3, maxSize1x3, circularity1x3, fillHoles1, segment1);
quantifyColoc(staining2, staining3, minSize2x3, maxSize2x3, circularity2x3, fillHoles2, segment2);
quantifyColoc(staining3, staining2, minSize2x3, maxSize2x3, circularity2x3, fillHoles2, segment2);
quantifyColoc(staining1, staining2 + "+" + staining3, minSize1x2x3, maxSize1x2x3, circularity1x2x3, fillHoles1, segment1);
quantifyColoc(staining3, staining1 + "+" + staining2, minSize1x2x3, maxSize1x2x3, circularity1x2x3, fillHoles1, segment1);
quantifyColoc(staining2, staining3 + "+" + staining1, minSize1x2x3, maxSize1x2x3, circularity1x2x3, fillHoles1, segment1);


function backgroundIntensity(staining){
	//Quantifies background staining, ie. all areas that are previously not identified as part of the signal.
	if(staining != ""){
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

backgroundIntensity(staining1);
backgroundIntensity(staining2);
backgroundIntensity(staining3);

//Quantify total area
selectWindow(areaName);
run("Select None");
run("Duplicate...", "title=Area duplicate channels=" + backgroundChannel);
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

if (allStainings.length > 1) {
	selectWindow("Mask-" + allStainings[1] + "+" + allStainings[0]);
	run("Select None");
	run("Duplicate...","title=Outlines-" + allStainings[1] + "+" + allStainings[0]);
	run("Outline");
	run("16-bit");
}

if (allStainings.length > 2) {
	selectWindow("Mask-" + allStainings[2] + "+" + allStainings[1]);
	run("Select None");
	run("Duplicate...","title=Outlines-" + allStainings[1] + "+" + allStainings[0]);
	run("Outline");
	run("16-bit");
	selectWindow("Mask-" + allStainings[2] + "+" + allStainings[0]);
	run("Select None");
	run("Duplicate...","title=Outlines-" + allStainings[2] + "+" + allStainings[0]);
	run("Outline");
	run("16-bit");
	selectWindow("Mask-" + allStainings[0] + "+" + allStainings[1] + "+" + allStainings[2]);
	run("Select None");
	run("Duplicate...","title=Outlines-" + allStainings[0] + "+" + allStainings[1] + "+" + allStainings[2]);
	run("Outline");
	run("16-bit");
}

if(matches(staining1, ".+") && matches(staining2, "") && matches(staining3, "")){
	run("Merge Channels...", "c1=" + staining1 + "_" + areaName + "_raw c2=Outlines-"  + staining1 + " create keep");
	
}else if(matches(staining1, ".+") && matches(staining2, ".+") && matches(staining3, "")){
	run("Merge Channels...", "c1=" + staining1 + "_" + areaName + "_raw c2=" + staining2 +"_" + areaName + "_raw c3=Outlines-"  + staining1 +  " c4=Outlines-"  + staining2 + " c5=Outlines-"  + staining2 + "+" + staining1 + " create keep");
	
}else if(!isCells && matches(staining1, ".+") && matches(staining2, ".+") && matches(staining3, ".+")){
	run("Merge Channels...", "c1=" + staining1 + "_" + areaName + "_raw c2=" + staining2 +"_" + areaName + "_raw c3="  + staining3 + "_" + areaName + "_raw c4=Outlines-"  + staining1 +  " c5=Outlines-"  + staining2 +  " c6=Outlines-"  + staining3 + " c7=Outlines-"  + staining3 + "+" + staining2 + "+" + staining1 +  " create keep");
}else if(isCells && matches(staining1, ".+") && matches(staining2, ".+") && matches(staining3, ".+")){
	run("Merge Channels...", "c1=" + staining1 + "_" + areaName + "_raw c2=" + staining2 +"_" + areaName + "_raw c3="  + staining3 + "_" + areaName + "_raw c4=Outlines-"  + staining1 +  " c5=Outlines-"  + staining2 +  " c6=Outlines-"  + staining3 + " c7=TripleMask create keep");
}

saveAs("Tiff", outputTIFF + "Analyzed-" + filename);

Stack.getDimensions(width, height, channels, slices, frames);
for (i = 0; i < allStainings.length; i++) {
	Stack.setChannel(i);
	run("Enhance Contrast", "saturated=0.35");
}
Stack.setChannel(channels);
run("Yellow");
wait(100);
run("Invert", "slice");

selectWindow("Summary");
print("Quantification succesfull. Check results for accuracy!");
waitForUser("Quantification succesfull. Check results for accuracy!");