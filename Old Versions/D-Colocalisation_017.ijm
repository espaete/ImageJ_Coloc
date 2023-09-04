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
#@ File (label="Select directory containing single channel images:", style = "directory") singleChannels
#@ File (label="Select directory containing background (Median filtered) images:", style = "directory") medianFilter
#@ File (label="Select output directory:", style = "directory") outputDir
#@ String (label="Number of stainings:", value=3) channelsNr
#@ String (label="Background Channel (used to quantify total area)", value=2) backgroundChannel

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

function quantifyLabeling(staining, fillHoles, minSize, maxSize, circularity, segment){
	//Quantifies labeling area and particles.
	//Uses user input of minimal size and circularity to correctly identify particles.
	//If selected, segments particles with "segmentParticles" function. Note: Can take up to several minutes.
	//Can be repeated by user until quantification is aggreeable.
	if(staining != ""){
		repeatLoop = true;
		while (repeatLoop) {
			selectWindow(staining + "_" + areaName + "_raw");
			run("Duplicate...", "title=" + staining + "_raw");
			setAutoThreshold("Percentile dark");
			waitForUser("Adjust Threshold (" + staining + ").");
			run("Create Mask");
			
			if(fillHoles){
				rename("Raw-Mask-" + staining);
				run("Duplicate...", "title=" + staining);
				run("Median...","radius=0");
				run("Dilate");
				run("Close-");
				run("Fill Holes");
				run("Analyze Particles...", "size=" + maxSize + "-Infinity show=Masks");
				run("Create Selection");
				selectWindow("Raw-Mask-" + staining);
				run("Restore Selection");
				run("Copy");
				selectWindow(staining);
				run("Restore Selection");
				run("Paste");
				run("Select None");
			}else{
				rename(staining);
			}
			
			if (segment) {
				segmentParticles(staining);
			}

			run("Analyze Particles...", "size=" + minSize + "-Infinity circularity=" + circularity + "-Infinity show=Masks display clear summarize");	

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
}

function removeBackground(staining, rbRadius, filteredImage){
	//Removes background by subtracting the median filtered image
	//Further removes background via imageJ function "Subtract Background".
	if(staining != ""){
		open(singleChannels + File.separator + staining + "-" + filename);
		rename(staining + "-All_raw");
		if(filteredImage){
			open(medianFilter + File.separator + "Filtered_" + staining + "-" + filename);
			rename("Background-" + staining);
			
			//Subtract filtered image from original
			imageCalculator("Subtract create", staining + "-All_raw", "Background-" + staining);
		}

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
}

function quantifyColoc(stainingA, stainingB, minSize, maxSize, circularity, fillHoles) { 
//Quantifies colocalisation by overlapping the corresponding labeling masks
	if(matches(stainingA, "\\w+.*") && matches(stainingB, "\\w+.*")){
		selectWindow("Mask-" + stainingB);
		run("Select None");
		selectWindow("" + stainingA);
		run("Select None");
		run("Invert");
		run("Create Selection");
		run("Select None");
		run("Invert");
		selectWindow("Mask-" + stainingB);
		run("Duplicate...", "title=RawMask-" + stainingB + "+" + stainingA);
		run("Invert");
		run("Restore Selection");
		run("Clear", "slice");
		run("Select None");
		run("Invert");
		if(fillHoles){
			run("Analyze Particles...", "size=0-" + maxSize + " show=Masks display clear include");
		}else{
			run("Analyze Particles...", "size=0-" + maxSize + " show=Masks display clear");
		}
		
		run("Close-");
		run("Watershed");
		rename(stainingB + "+" + stainingA);
		run("Analyze Particles...", "size=" + minSize + "-" + maxSize + " circularity=" + circularity + "-1.00 show=Masks display clear summarize");
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
//END

//START --- Log
print("\\Clear")
print(fileNoExtension);
print(areaName);
print("Staining 1: " + staining1);
print("Rolling ball radius: " + rbRadius1);
print("Minimum size [µm^2]: " + minSize1);
print("Maximum size [µm^2]: " + maxSize1);
print("Circularity: " + circularity1);
print("Staining 2: " + staining2);
print("Rolling ball radius: " + rbRadius2);
print("Minimum size [µm^2]: " + minSize2);
print("Maximum size [µm^2]: " + maxSize2);
print("Circularity: " + circularity2);
print("Staining 3: " + staining3);
print("Rolling ball radius: " + rbRadius3);
print("Minimum size [µm^2]: " + minSize3);
print("Maximum size [µm^2]: " + maxSize3);
print("Circularity: " + circularity3);
//END

//START --- Main Script
//Select region of interest and save as .tiff
run("Brightness/Contrast...");
run("Channels Tool...");
run("ROI Manager...");
roiManager("reset");
waitForUser("Select the region of interest you want to analyze");
roiManager("add");
roiManager("save selected", outputROI + areaName + "-ROI_" + fileNoExtension + ".zip");
roiManager("delete");

run("Duplicate...", "title=" + areaName + " duplicate");
saveAs("Tiff", outputTIFF + areaName + "_" + filename);
rename(areaName);
close(filename);

//Get negative region of interest selection
selectWindow(areaName);
roiManager("Show All");
run("Restore Selection");
run("Copy");
run("Clear", "slice");
run("Select None");
setThreshold(1, 65535, "raw");
run("Create Selection");
resetThreshold();
roiManager("Add");
run("Select None");
run("Paste");
run("Make Inverse");
run("Threshold...");

//Select artifacts to remove
waitForUser("Select artifacts and regions that you don't want to analzye and add them to the ROI manager [by pressing t]");
roiManager("save", outputROI + areaName + "-CutAreas-ROI_" + fileNoExtension + ".zip")

//Reset Summary
Table.create("Summary");

//Remove Background and artifacts
removeBackground(staining1, rbRadius1, filteredImage1);
removeBackground(staining2, rbRadius2, filteredImage2);
removeBackground(staining3, rbRadius3, filteredImage3);

//Quantify single labeling
quantifyLabeling(staining1, fillHoles1, minSize1, maxSize1, circularity1, segment1);
quantifyLabeling(staining2, fillHoles2, minSize2, maxSize2, circularity2, segment2);
quantifyLabeling(staining3, fillHoles3, minSize3, maxSize3, circularity3, segment3);

//Quantify colocalisation
quantifyColoc(staining1, staining2, minSize1, maxSize1, circularity1, fillHoles1);
quantifyColoc(staining1, staining3, minSize1, maxSize1, circularity1, fillHoles1);
quantifyColoc(staining2, staining3, minSize2, maxSize2, circularity2, fillHoles2);
quantifyColoc(staining1, staining3 + "+" + staining2, minSize1, maxSize1, circularity1, fillHoles1);
finalMaskID = getImageID();

//Quantify total area
selectWindow(areaName);
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

//Show double positive cells in original image
stainingList = staining1 + "," + staining2 + "," + staining3;
allStainings= split(stainingList,",");

for (i = 0; i < channelsNr; i++) {
	selectWindow("Mask-" + allStainings[i]);
	run("Duplicate...","title=Outlines-" + allStainings[i]);
	run("Outline");
	run("16-bit");
	run("Invert");
}

if (channelsNr > 1) {
	selectWindow("Mask-" + allStainings[1] + "+" + allStainings[0]);
	run("Duplicate...","title=Outlines-" + allStainings[1] + "+" + allStainings[0]);
	run("Outline");
	run("16-bit");
	run("Invert");
}


if(matches(staining1, ".+") && matches(staining2, "") && matches(staining3, "")){
	run("Merge Channels...", "c1=" + staining1 + "_" + areaName + "_raw c2=Outlines-"  + staining1 + " create keep");
	
}else if(matches(staining1, ".+") && matches(staining2, ".+") && matches(staining3, "")){
	run("Merge Channels...", "c1=" + staining1 + "_" + areaName + "_raw c2=" + staining2 +"_" + areaName + "_raw c3=Outlines-"  + staining1 +  " c4=Outlines-"  + staining2 + " c5=Outlines-"  + staining2 + "+" + staining1 + " create keep");
	
}else if(matches(staining1, ".+") && matches(staining2, ".+") && matches(staining3, ".+")){
	run("Merge Channels...", "c1=" + staining1 + "_" + areaName + "_raw c2=" + staining2 +"_" + areaName + "_raw c3="  + staining3 + "_" + areaName + "_raw c4=Outlines-"  + staining1 +  " c5=Outlines-"  + staining2 +  " c6=Outlines-"  + staining3 + " c7=Outlines-"  + staining3 + "+" + staining2 + "+" + staining1 +  " create keep");
}

saveAs("Tiff", "Analyzed-" + filename);
if(channelsNr == 2){
	Stack.setActiveChannels("11001");
	Stack.setChannel(2);
	run("Enhance Contrast", "saturated=0.35");
	Stack.setChannel(1);
	run("Enhance Contrast", "saturated=0.35");
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
print(filename);
waitForUser("DONE!!!","` ` ` ` ` ` ` ` ` ` ` ` ` ` ` `'F'¯'''''L ` ` ` ` ` ` ` ` ` ` ` `\n"+ 
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