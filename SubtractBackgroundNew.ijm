//By Carolina Monteiro and Erik Späte @EM MPG Göttingen, 2020
//Input dirctory of split channels files and corresponding median filtered images.
//Subtracts the median filtered image from the original, resulting in an image with strongly reduced background.
//Saves the new image in the output folder.

#@ File (label="Select directory containing the .tiff images", style = "directory") inputDir
#@ File (label="Select background (Median filtered) image:", style = "directory") medianDir
#@ File (label="Select output directory", style = "directory") outputDir

startTime = getTime();
run("Close All");
//Sets up the output folders in designated directory.
imageList = getFileList(inputDir);

function masterFunction(filename, Nr){
	//Open image
	print("Opening:  " + filename + " - " + (getTime()-startTime)/1000);
	open(inputDir + File.separator + filename);
	open(medianDir + File.separator + "Filtered_" + filename);
	print("Removing background");
	imageCalculator("Subtract create", filename, "Filtered_" + filename);
	saveAs("Tiff", outputDir + File.separator + "NoBackground_" + filename);
	
	//Finished
	print("Finished:  " + filename + " - " + (getTime()-startTime)/1000);
	print(".");
	print(".");
	print(".");
	run("Close All");
}

setBatchMode(true);
for (Nr = 0; Nr < imageList.length; Nr++)
         masterFunction(imageList[Nr],Nr+1);
setBatchMode(false);
print("DONE!!!");
