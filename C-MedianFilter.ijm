//By Carolina Monteiro and Erik Späte @EM MPG Göttingen, 2020
//Input dirctory of single channel images.
//Filters the image with a median and a mean filter.
//This image will later serve as an estimation for the local background fluorescence.
//100 µm radius proved to be a good value in most cases.

#@ File (label="Select directory containing the single channel images", style = "directory") inputDir
#@ File (label="Select output directory", style = "directory") outputDir
#@ Integer (label="Median filter radius (in pixel).", value=100) pixelRadius
#@ Boolean (label = "Replace", style="Checkbox", value = true) replaceFile

function masterFunction(filename, Nr){
	if (!replaceFile && File.exists(outputDir + File.separator + "Filtered" + "_" + filename)) {
		print("Filtered" + "_" + filename + " aldready exists.");
	}else{
		//Close all & collect garbage
		run("Close All");
		call("java.lang.System.gc");
		
		//Log
		print(filename);
		print("Nr: " + Nr + "/" + imageList.length);
		getDateAndTime(year, month, dayOfWeek, dayOfMonth, hour, minute, second, msec);
		print("Time: " + hour + ":" + minute + ":" + second);
		startTime = getTime();
		
		//Open image
		open(inputDir + File.separator + filename);
		
		//Log
		getDimensions(width, height, channels, slices, frames);
		getPixelSize(unit, pixelWidth, pixelHeight);
		imageSizeMegaBytes = width*height*slices*bitDepth()/8/1024/1024;
		print("Size: " + imageSizeMegaBytes + " MB");
		print("Dimensions: " + width*pixelWidth + "x" + height*pixelHeight + " " + unit + " (" + width + "x" + height + " pixel)"); 
		print("Scale: " + 1/pixelWidth + " pixel/" + unit);
		
		//Run filters
		print("Start Median (radius = " + pixelRadius + " pixel)");
		run("Median...", "radius=" + pixelRadius);
		print("Start Mean (radius = " + pixelRadius + " pixel)");
		selectWindow(filename);
		run("Mean...", "radius=" + pixelRadius);
		print("Saving...");
		selectWindow(filename);
		saveAs("Tiff", outputDir + File.separator + "Filtered" + "_" + filename);

		//Log Time
		totalTime =  (getTime()-startTimeAll)/60000;
		timeMinutes = (getTime()-startTime)/60000;
		timeSeconds = timeMinutes/60;
		if (timeMinutes > 1){
			print("Duration: " + timeMinutes + " minutes");	
		}else {
			print("Duration: " + timeSeconds + " seconds");	
		}
		print("Speed: " + imageSizeMegaBytes/timeMinutes + " MB/min");
		print("Total time: " + totalTime + " minutes");
		print(".");
		print(".");
		print(".");
		getDateAndTime(year, month, dayOfWeek, dayOfMonth, hour, minute, second, msec);
		
		//Save Log
		selectWindow("Log");
		saveAs("Text", outputDir + File.separator + "Log_" + year + "-" + month + "-" + dayOfMonth + "_" + hour + "" + minute + "" + second);
	}
}

//Start script
run("Fresh Start");
imageList = getFileList(inputDir);

//Log
totalTime = 0;
startTimeAll = getTime();

//Loop over all images
for (Nr = 0; Nr < imageList.length; Nr++){
         masterFunction(imageList[Nr],Nr+1);
}

print("DONE!!!");
waitForUser("DONE!!!");
