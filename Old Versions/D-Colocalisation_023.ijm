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
#@ File (label="Select directory containing single channel images:", style = "directory") singleChannels
#@ File (label="Select directory containing background (Median filtered) images:", style = "directory") medianFilter
#@ File (label="Select output directory:", style = "directory") outputDir
#@ String (label="Background Channel (can be any channel that has a visible background, used to quantify total area)", value=2) backgroundChannel

#@ String (visibility=MESSAGE, value="----Staining1----", required=false) msg1
#@ String (label="Name", value="DAPI") staining1
#@ Boolean (label = "Median filtered image?", style="Checkbox", value = true) filteredImage1
#@ Boolean (label = "Fill holes?", style="Checkbox", value = true) fillHoles1
#@ Boolean (label = "Segment particles? (Note: Can take several minutes.):", style="Checkbox", value = true) segment1
#@ String (label="Rolling Ball Radius [µm]:", value="15") rbRadius1
#@ String (label="Minimum size [µm^2]:", value="30") minSize1
#@ String (label="Maximum size [µm^2]:", value="Infinity") maxSize1
#@ Float (label="Circularity (low = less stringent):", style="slider", min=0, max=1, stepSize=0.01) circularity1

#@ String (visibility=MESSAGE, value="----Staining2----", required=false) msg2
#@ String (label="Name", value="CA2") staining2
#@ Boolean (label = "Median filtered image?", style="Checkbox", value = true) filteredImage2
#@ Boolean (label = "Fill holes?", style="Checkbox", value = true) fillHoles2
#@ Boolean (label = "Segment particles? (Note: Can take several minutes.):", style="Checkbox", value = false) segment2
#@ String (label="Rolling Ball Radius [µm]:", value="15") rbRadius2
#@ String (label="Minimum size [µm^2]:", value="0") minSize2
#@ String (label="Maximum size [µm^2]:", value="Infinity") maxSize2
#@ Float (label="Circularity (low = less stringent):", style="slider", min=0, max=1, stepSize=0.01) circularity2

#@ String (visibility=MESSAGE, value="----Staining3----", required=false) msg3
#@ String (label="Name", value="LDHA") staining3
#@ Boolean (label = "Median filtered image?", style="Checkbox", value = true) filteredImage3
#@ Boolean (label = "Fill holes?", style="Checkbox", value = true) fillHoles3
#@ Boolean (label = "Segment particles? (Note: Can take several minutes.):", style="Checkbox", value = false) segment3
#@ String (label="Rolling Ball Radius [µm]:", value="30") rbRadius3
#@ String (label="Minimum size [µm^2]:", value="0") minSize3
#@ String (label="Maximum size [µm^2]:", value="Infinity") maxSize3
#@ Float (label="Circularity (low = less stringent):", style="slider", min=0, max=1, stepSize=0.01) circularity3

run("Fresh Start");
//Get number of stainings
stainingsInput = staining1 + "," + staining2 + "," + staining3;
allStainings = split(stainingsInput,",");
allStainings = Array.deleteValue(allStainings, "");
channelsNr = allStainings.length;

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
function removeBackground(staining, rbRadius, filteredImage){
	//Removes background by subtracting the median filtered image
	//Further removes background via imageJ function "Subtract Background".
	if(staining != ""){
		open(singleChannels + File.separator + staining + "-" + filename);
		rename(staining + "-All_raw");
		duplicateROI(staining + "_" + areaName + "_raw");
		if(filteredImage){ 
			print(staining + ": Yes");
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


function duplicateROI(newName){
	if(roiManager("count") > 0){
		roiManager("Deselect");
		roiManager("Delete");
	}
	roiManager("Open", outputROI + areaName + "-ROI_" + fileNoExtension + ".zip");
	roiManager("Select", 0);
	run("Duplicate...", "title=" + newName);
	
}

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

function quantifyLabeling(staining, fillHoles, minSize, maxSize, circularity, segment){
	//Quantifies labeling area and particles.
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
			run("Duplicate...", "title=" + staining + "_noBG");
			setAutoThreshold("Percentile dark");
			waitForUser("Adjust Threshold (" + staining + ").");
			getThreshold(lower, upper);
			while(lower == -1 && upper == -1){
				waitForUser("Adjust Threshold (" + staining + ").");
				getThreshold(lower, upper);
			}
			print(staining + ": " + lower + " - " + upper);
			if(is("binary")){
				waitForUser("Please only adjust the threshold, don't press 'Apply'!");
				continue
			}
			run("Create Mask");
			
			if(fillHoles){
				rename("Mask-" + staining + "noBG");
				run("Duplicate...", "title=" + staining + "_noBG");
				run("Median...","radius=0");
				run("Dilate");
				run("Close-");
				run("Fill Holes");
				run("Analyze Particles...", "size=" + maxSize + "-Infinity show=Masks");
				run("Create Selection");
				selectWindow("Mask-" + staining + "noBG");
				run("Restore Selection");
				run("Copy");
				selectWindow(staining + "_noBG");
				run("Restore Selection");
				run("Paste");
				run("Select None");
			}else{
				rename(staining + "_noBG");
			}
			
			if (segment) {
				segmentParticles(staining + "_noBG");
			}

			run("Analyze Particles...", "size=" + minSize + "-Infinity circularity=" + circularity + "-Infinity show=Masks");
			run("Create Selection");

			saveAs("Tiff", outputTIFF + "Mask-" + staining + "_" + areaName + "_" + filename);
			saveAs("Results", outputCSV + staining + "_" + areaName + "_" + fileNoExtension + ".csv");
			rename("Mask-" + staining);
			//Quantify intensity
			selectWindow(staining + "_" + areaName + "_raw");
			run("Duplicate...", "title=" + staining);
			run("Select None");
			selectWindow("Mask-" + staining);
			run("Create Selection");
			selectWindow(staining);
			run("Restore Selection");
			run("Clear", "slice");
			run("Select None");
			setThreshold(1, Math.pow(2,bitDepth()));
			run("Analyze Particles...", "display clear summarize");
			selectWindow("Mask-" + staining);
	
			waitForUser("Check the quantification.");
			run("Select None");
			repeatLoop = getBoolean("Is the quantification ok?", "No, repeat", "Yes, continue");
			if (repeatLoop) {
				close("Mask-" + staining);
				close("Raw-Mask-" + staining);
				close(staining + "_raw");
				Table.deleteRows(Table.size-1, Table.size-1, "Summary");	
			}
			
		}
	}
}

function quantifyColoc(stainingA, stainingB, minSize, maxSize, circularity, fillHoles, segment) { 
//Quantifies colocalisation by overlapping the corresponding labeling masks
	if(matches(stainingA, "\\w+.*") && matches(stainingB, "\\w+.*")){
		selectWindow("Mask-" + stainingB);
		run("Select None");
		selectWindow(stainingA + "_noBG");
		run("Create Selection");
		run("Select None");
		selectWindow("Mask-" + stainingB);
		run("Duplicate...", "title=RawMask-" + stainingB + "+" + stainingA);
		run("Invert");
		run("Restore Selection");
		run("Clear Outside");
		run("Select None");
		run("Invert");
		if(fillHoles){
			run("Analyze Particles...", "size=0-" + maxSize + " show=Masks display clear include");
		}else{
			run("Analyze Particles...", "size=0-" + maxSize + " show=Masks display clear");
		}
		if(segment){
			run("Close-");
			run("Watershed");
		}

		rename(stainingB + "+" + stainingA);
		run("Analyze Particles...", "size=" + minSize + "-" + maxSize + " circularity=" + circularity + "-1.00 show=Masks display clear");
		saveAs("Results", outputCSV + stainingB + "+" + stainingA + "_" + areaName + "_" + fileNoExtension + ".csv");
		rename("Mask-" + stainingB + "+" + stainingA);
	}
}
//END --- Functions

//START --- Open image
run("Close All");
open(inputFile);
filename = getTitle();
fileNoExtension = File.nameWithoutExtension
run("Threshold...");
//END

//START --- Log
print("\\Clear")
print(fileNoExtension);
print(areaName);
print("Nr. of stainings: " + channelsNr);

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
if(roiManager("count") > 0){
	roiManager("save", outputROI + areaName + "-CutAreas-ROI_" + fileNoExtension + ".zip")
}else if(File.exists(outputROI + areaName + "-CutAreas-ROI_" + fileNoExtension + ".zip")){
	File.delete(outputROI + areaName + "-CutAreas-ROI_" + fileNoExtension + ".zip");
}


//Reset Summary
Table.create("Summary");

//Remove Background and artifacts
print("Remove Background. Median filtered image?"); 
removeBackground(staining1, rbRadius1, filteredImage1);
removeBackground(staining2, rbRadius2, filteredImage2);
removeBackground(staining3, rbRadius3, filteredImage3);

//Quantify single labeling
print("Thresholds");
quantifyLabeling(staining1, fillHoles1, minSize1, maxSize1, circularity1, segment1);
quantifyLabeling(staining2, fillHoles2, minSize2, maxSize2, circularity2, segment2);
quantifyLabeling(staining3, fillHoles3, minSize3, maxSize3, circularity3, segment3);

//Quantify colocalisation
quantifyColoc(staining1, staining2, minSize1, maxSize1, circularity1, fillHoles1, segment1);
quantifyColoc(staining1, staining3, minSize1, maxSize1, circularity1, fillHoles1, segment1);
quantifyColoc(staining2, staining3, minSize2, maxSize2, circularity2, fillHoles2, segment2);
quantifyColoc(staining1, staining3 + "+" + staining2, minSize1, maxSize1, circularity1, fillHoles1, segment1);
finalMaskID = getImageID();

//Get Colocalisation Intensity
function colocIntensity(staining, stainingA, stainingB, minSize, maxSize, circularity){	
	selectWindow(staining + "_" + areaName + "_raw");
	run("Duplicate...", "title=" + staining + "-staining_of_" + stainingB + "+" + stainingA + "_Coloc");
	roiManager("fill");
	roiManager("Deselect");
	selectWindow("Mask-" + stainingB + "+" + stainingA);
	run("Create Selection");
	selectWindow(staining + "-staining_of_" + stainingB + "+" + stainingA + "_Coloc");
	run("Restore Selection");
	run("Clear", "slice");
	run("Select None");
	setThreshold(1, Math.pow(2,bitDepth()));
	run("Analyze Particles...", "size=" + minSize + "-" + maxSize + " circularity=" + circularity + "-1.00 show=Masks display clear summarize");
}

colocIntensity(staining1, staining1, staining2, minSize1, maxSize1, circularity1);
colocIntensity(staining2, staining1, staining2, minSize2, maxSize2, circularity2);


function nonColocIntensity(staining, stainingA, stainingB, minSize, maxSize, circularity){
	//Quantifies non-colocalised staining
	selectWindow(staining + "_" + areaName + "_raw");
	run("Duplicate...", "title=" + staining + "-nonColoc");
	roiManager("fill");
	roiManager("Deselect");
	selectWindow("Mask-" + stainingB + "+" + stainingA);
	run("Create Selection");
	selectWindow(staining + "-nonColoc");
	run("Restore Selection");
	run("Clear Outside");
	run("Select None");
	selectWindow("Mask-" + staining);
	run("Create Selection");
	selectWindow(staining + "-nonColoc");
	run("Restore Selection");
	run("Clear", "slice");
	run("Select None");
	setThreshold(1, Math.pow(2,bitDepth()));
	run("Analyze Particles...", "size=" + minSize + "-" + maxSize + " circularity=" + circularity + "-1.00 show=Masks display clear summarize");
	selectWindow("Results");
	saveAs("Results", outputCSV + "NonColoc-" + staining + "_" + areaName + "_" + fileNoExtension + ".csv");
}

nonColocIntensity(staining1, staining1, staining2, minSize1, maxSize1, circularity1);
nonColocIntensity(staining2, staining1, staining2, minSize2, maxSize2, circularity2);


function backgroundIntensity(staining){
	//Quantifies background staining
	selectWindow(staining + "_" + areaName + "_raw");
	run("Duplicate...", "title=" + staining + "_Background");
	roiManager("fill");
	roiManager("Deselect");
	selectWindow("Mask-" + staining);
	run("Create Selection");
	selectWindow(staining + "_Background");
	run("Restore Selection");
	run("Clear Outside");
	run("Select None");
	setThreshold(1, Math.pow(2,bitDepth()));
	run("Analyze Particles...", "show=Masks display clear summarize");
	selectWindow("Results");
	saveAs("Results", outputCSV + "Background-" + staining + "_" + areaName + "_" + fileNoExtension + ".csv");
	
}

backgroundIntensity(staining1);
backgroundIntensity(staining2);

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

for (i = 0; i < channelsNr; i++) {
	selectWindow("Mask-" + allStainings[i]);
	run("Select None");
	run("Duplicate...","title=Outlines-" + allStainings[i]);
	run("Outline");
	run("16-bit");
}

if (channelsNr > 1) {
	selectWindow("Mask-" + allStainings[1] + "+" + allStainings[0]);
	run("Select None");
	run("Duplicate...","title=Outlines-" + allStainings[1] + "+" + allStainings[0]);
	run("Outline");
	run("16-bit");
}


if(matches(staining1, ".+") && matches(staining2, "") && matches(staining3, "")){
	run("Merge Channels...", "c1=" + staining1 + "_" + areaName + "_raw c2=Outlines-"  + staining1 + " create keep");
	
}else if(matches(staining1, ".+") && matches(staining2, ".+") && matches(staining3, "")){
	run("Merge Channels...", "c1=" + staining1 + "_" + areaName + "_raw c2=" + staining2 +"_" + areaName + "_raw c3=Outlines-"  + staining1 +  " c4=Outlines-"  + staining2 + " c5=Outlines-"  + staining2 + "+" + staining1 + " create keep");
	
}else if(matches(staining1, ".+") && matches(staining2, ".+") && matches(staining3, ".+")){
	run("Merge Channels...", "c1=" + staining1 + "_" + areaName + "_raw c2=" + staining2 +"_" + areaName + "_raw c3="  + staining3 + "_" + areaName + "_raw c4=Outlines-"  + staining1 +  " c5=Outlines-"  + staining2 +  " c6=Outlines-"  + staining3 + " c7=Outlines-"  + staining3 + "+" + staining2 + "+" + staining1 +  " create keep");
}

saveAs("Tiff", outputTIFF + "Analyzed-" + filename);
if(channelsNr == 2){
	Stack.setActiveChannels("11001");
	Stack.setChannel(2);
	run("Enhance Contrast", "saturated=0.35");
	Stack.setChannel(1);
	run("Enhance Contrast", "saturated=0.35");
	Stack.setChannel(5);
	run("Invert", "slice");
	run("Yellow");
}else if(channelsNr == 3){
	Stack.setActiveChannels("1110001");
	Stack.setChannel(3);
	run("Enhance Contrast", "saturated=0.35");
	Stack.setChannel(2);
	run("Enhance Contrast", "saturated=0.35");
	Stack.setChannel(1);
	run("Enhance Contrast", "saturated=0.35");
}

selectWindow("Summary");
print("Quantification succesfull. Check results for accuracy!");
waitForUser("Quantification succesfull. Check results for accuracy!","` ` ` ` ` ` ` ` ` ` ` ` ` ` ` `'F'¯'''''L ` ` ` ` ` ` ` ` ` ` ` `\n"+ 
"` ` ` ` ` ` ` ` ` ` ` ` ` ` ` `'[``…'¾`` ``` ``` ``` ``` \n"+ 
"` ` ` ` ` ` ` ` ` ` ` ` ` ` ` `'[```…ʹ[` ` ` ` ``` ``` ``` \n"+ 
"` ` ` ` ` ` ` ` ` ` ` ` ` ` ` `#````ˆ[```` ``` ``` ``` ``\n"+ 
"` ` ` ` ` ` ` ` ` ` ` ` ` ` `'#``…``'[`… ` ` ` ` ` ` ` ` ` \n"+ 
"` ` ` ` ` ` ` ` ` ` ` ` ` ` #…`````'F`` ` ` ` `` ``` ``` \n"+ 
"` ` ` ` ` ` ` ` ` ` ` ` ` ƒ¯```````'[__` ` ` ` ` ` ` ``` ``\n"+ 
"` ` ` ` ` ` ` ` ` ` ` ` ƒ¯````````ʹ¯¯¯¯''''''''''''¯¯¯¯¯¯™[ ` \n"+ 
"gµµµµµµµµµµµµµµ_µ™`````````````````````````'# ` \n"+ 
"'₫₫₫₫₫₫₫₫₫₫₫₫₫F¯…`````````````````````` ` ²q[¯ ` `\n"+ 
"ʹ₫₫₫₫₫₫₫₫₫₫₫₫¾````````````````````````````ʹ} … `\n"+ 
"›₫₫₫₫₫₫₫₫₫₫₫₫#`````````````````````````__µr… ` `\n"+ 
"³₫₫₫₫₫₫₫₫₫₫₫₫₫…`````````````````````````¯[ … ` `\n"+ 
"`₫₫₫₫₫₫₫₫₫₫₫₫$``````````````````````````_F … ` `\n"+ 
"`]₫₫₫₫₫₫₫₫₫₫₫#````````````````````````ʹ''''[… … ` `\n"+ 
"`'₫₫₫₫₫₫₫F''''']₫#___`````````````````````` '# … ` ` \n"+ 
"…₫₫₫₫₫₫₫bµ₫₫₫₫$¯''''¹uuuuuɷuɷuɷuɷuɷuɷµ#¯ ` ` ` ` `\n"+ 
"…'''''''™''''™'''™''''™™ … … ` ` ` ` ` ` ` ` ` ` ` ` … … ` ` ` \n"+ 
"` … ` ` ` ` ` ` ` ` … ` … ` ` ` ` ` ` ` ` ` ` ` … ` ` ` ` `.\n");