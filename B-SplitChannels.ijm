//By Erik Späte @EM NAT Göttingen, 2022
//Splits mulit-channel images and saves each individual channel.

#@ File (label="Select directory containing the .tiff images", style = "directory") inputDir
#@ File (label="Select output directory", style = "directory") outputDir
#@ String (label= "Names of channel (separated by comma, no blank)", value = "DAPI,LF,LDHA,CA2") channelName
channelName= split(channelName,",");

startTime = getTime();
run("Close All");
imageList = getFileList(inputDir);

function masterFunction(filename, Nr){
	call("java.lang.System.gc");
	for (i = 0; i < channelName.length; i++) {
		if(!File.exists(outputDir + File.separator + channelName[i] + "-" + filename)){
			runFunction = true;
			break;
		}else{
			runFunction = false;
		}
	}
	if(!runFunction){
		print("Already split: " + filename);
	}else{
		print("Opening: " + filename + " - " + (getTime()-startTime)/1000);
		open(inputDir + File.separator + filename);
		Stack.getDimensions(width, height, channels, slices, frames);
		if (!is("composite")) {
			print("Make composite");
			Stack.setDisplayMode("composite");
		}
		print("Split Channels");
		run("Split Channels");
		for (i = 0; i < channels; i++) {
			selectWindow("C" + i+1 + "-" + filename);
			saveAs("Tif", outputDir + File.separator + channelName[i] + "-" + filename);
			print("Save: " + channelName[i]);
			close();
		}
		print("Finished - " + (getTime()-startTime)/1000);
		print(".");
		print(".");
		print(".");
	}
	
}

setBatchMode(true);
for (Nr = 0; Nr < imageList.length; Nr++)
         masterFunction(imageList[Nr],Nr+1);
setBatchMode(false);
waitForUser("DONE!!!");
