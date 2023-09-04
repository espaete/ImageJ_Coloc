//Erik Späte, MPI NAT 2022 Göttingen
//Recursive thresholding
//Script starts with a user set threshold and then sequentially lowers it, while checking if particles of the
//specified size can be found. If particles of the correct size are found, they are copied into the output mask.
//Each time the threshold is reduced, a new mask is created. All particles that are larger than the specified size
//are thresholded again in the next round. Each time the threshold is lowered, the oversized particles will reduce
//in size, until they ultimately fit the user specified value.
//If no particles remain or the lower threshold becomes equal to the upper threshold, the loop ends.
//As an output a composite image is generated, which the user can check for accuracy and modify accordingly.
#@ File (label="File:", "type=File") input
#@ File (label="OG_File:", "type=File") inputOG
#@ String (label="Area Name (no blanks):") areaName
#@ String (label="Name", value="LDHB") staining
#@ String (label="Minimum size [µm^2]:", value="10") minSize
#@ String (label="Maximum size [µm^2]:", value="1200") maxSize
#@ boolean (label="Fill Holes:", checkbox=false) fillHoles
#@ boolean (label="Dilate:", checkbox=false) isDilate
#@ boolean (label="Close-:", checkbox=false) isClose
setForegroundColor(0, 0, 0);
setBackgroundColor(0, 0, 0);

close("Output");
open(input);
rename("Image");
setAutoThreshold();
waitForUser("Set Threshold");
getThreshold(lower, upper);
stepSize = getString("Step Size:", "200");
run("Duplicate...", "title=Output");

setBatchMode(true); 
selectWindow("Output");
run("Select All");
run("Clear");
run("Select None");
run("Make Binary");
run("Invert")
selectWindow("Image");

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
	if (isDilate) {
		run("Median...", "radius=0");
		run("Dilate");
	}
	if (isClose) {
		run("Close-");
	}
	if (fillHoles) {
		run("Fill Holes");
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
		run("Make Inverse");
		run("Clear");
	}
	run("Select None");
	close("Image");
	rename("Image");
	close("ThresholdMask");
}
setBatchMode(false);
selectWindow("Output");
if(isDilate && fillHoles){
	run("Dilate");
	run("Fill Holes");
	run("Erode");
}
run("Duplicate...", "title=Outlines");
run("Outline");
run("16-bit");
selectWindow("Output");
run("16-bit");
run("Invert");
open(inputOG);
rename("OG_Image");
run("Merge Channels...", "c1=OG_Image c2=Outlines c3=Output create keep");
Stack.setChannel(3);
Stack.setActiveChannels("110");
run("Channels Tool...");

//run("Analyze Particles...", "size=" + minSize + "-Infinity show=Masks include");
//run("Make Binary");
//run("Restore Selection");
//run("Paste");


