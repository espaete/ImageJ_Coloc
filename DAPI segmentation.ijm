
//Segments particles via a combination of watershed, dilate, and find maxima.
//This helps when particles are close together and particle number is important.
//Can take several minutes, depending on particle number.

#@ String (label="Name:") image
#@ String (label="Minimum size [µm^2]", value="4") minSize
#@ String (label="Maximum size [µm^2]:", value="240") maxSize
n = 0;
selectWindow(image);
setAutoThreshold("Percentile dark");
run("Threshold...");
waitForUser("Set threshold");
run("Create Mask");
rename("Binary of " + image);
run("Watershed");
run("Analyze Particles...", "size=" + maxSize + "-Infinity show=Masks");
rename("Oversized-Particles");
run("Create Selection");
n++;
run("Select None");
selectWindow("Oversized-Particles");
run("Create Selection");
run("Select None");
selectWindow(image);
run("Duplicate...", "title=Oversized-Threshold");
run("Restore Selection");
run("Clear");
while(true){
	run("Select None");
	setAutoThreshold("Percentile dark");
	waitForUser("Set new threshold, to segment the remaining particles");
	run("Create Mask");
	close("Oversized-Particles");
	close("Oversized-Threshold");
	rename("Oversized-Particles");
	run("Watershed");
	run("Select None");
	run("Duplicate..." , "title=Oversized-Particles-Dilate");
	run("Dilate");
	run("Create Selection");
	close("Oversized-Particles-Dilate");
	selectWindow("Binary of " + image);
	run("Restore Selection");
	run("Clear");
	run("Select None");
	selectWindow("Oversized-Particles");
	run("Create Selection");
	run("Copy");
	run("Select None");
	selectWindow("Binary of " + image);
	run("Restore Selection");
	run("Paste");
	run("Select None");
	run("Analyze Particles...", "size=" + maxSize + "-Infinity show=Masks");
	close("Oversized-Particles");
	rename("Oversized-Particles");
	run("Make Binary");
	run("Watershed");
	run("Create Selection");
	run("Make Inverse");
	if (selectionType() == -1) {
		close("Oversized-Particles");
		break
	}else{
		run("Make Inverse");
	}
	run("Select None");
	selectWindow(image);
	close("Oversized-Threshold");
	run("Duplicate..." , "title=Oversized-Threshold");
	run("Restore Selection");
	run("Clear Outside");
}
selectWindow("Binary of " + image);
run("Median...","radius=0");
run("Analyze Particles...", "size=" + minSize + "-Infinity show=Masks");
close("Binary of " + image);
rename(image + " Segmented");
waitForUser("Done");
			


