//Erik Späte, MPI NAT 2022, Göttingen
//Converts a czi to a tif, sets channel colors, and adjusts contrast.

//#@ String (visibility=MESSAGE, value="Input directory must not have a blank!!!", required=false) msg
#@ File (label="Input directory (path must not have blanks)", style = "directory") tiff
#@ String (label= "New Channel names", value = "DAPI,LF,Iba1") newNames
newNames = split(newNames,",");

function ConvertToTif(input, filename) {
	open(input + File.separator + filename);
	Stack.getDimensions(width, height, channels, slices, frames);
	filename = getTitle();
	for (i = 0; i < channels; i++) {
		print("Change channel name " + i+1);
		print("New name = " + newNames[i]);
		Stack.setChannel(i+1);  
		setMetadata("Label", newNames[i]);
	}
	print("Saving...");
    saveAs("Tiff", input + File.separator + filename);
    run("Close All");
}

run("Fresh Start");
setBatchMode(true); 
list = getFileList(tiff);
for (i = 0; i < list.length; i++)
        ConvertToTif(tiff, list[i]);
setBatchMode(false);
run("Fresh Start");
print("DONE!!!")
waitForUser("DONE!!!");