//Erik Späte, MPI NAT 2022, Göttingen
//Converts a czi to a tif, sets channel colors, and adjusts contrast.

//#@ String (visibility=MESSAGE, value="Input directory must not have a blank!!!", required=false) msg
#@ File (label="Input directory (path must not have blanks)", style = "directory") czi_input
#@ File (label="Output directory", style = "directory") tif_output
#@ String (label= "Type in channel colors, separated by a comma.", value = "Blue,Grays,Green,Red") color

color = split(color,",");

function ConvertToTif(input, output, filename) {
	call("java.lang.System.gc");
	run("Collect Garbage");
	print("Opening: " + filename);
	run("Bio-Formats Windowless Importer", "open=" + input + File.separator + filename);
    //Change color and adjust contrast
    Stack.getDimensions(width, height, channels, slices, frames);
    Stack.setDisplayMode("composite");
    print(channels + " channels");

	for (i = 0; i < channels; i++) {
		print(color[i]);
		Stack.setChannel(i+1);  
		run(color[i]);
		run("Enhance Contrast", "saturated=0.35");
	}
	//Save as .tif in output folder
	print("Saving...");
    saveAs("Tiff", output + File.separator + filename);
    run("Close All");
}

run("Fresh Start");
setBatchMode(true); 
list = getFileList(czi_input);
for (i = 0; i < list.length; i++)
        ConvertToTif(czi_input, tif_output, list[i]);
setBatchMode(false);
run("Fresh Start");
print("DONE!!!")
waitForUser("DONE!!!");