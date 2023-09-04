
//#@ File (label="Select composite file (.tif):", style = "file") inputFile
//#@ File (label="Select ROI file:", style = "file") roiInput

//run("Fresh Start");
Table.create("Summary");
layerName = newArray("2", "3a", "3b", "4", "5", "6a", "6b");

selectWindow("LDHA");
run("Select None");
setThreshold(1, 255);
run("Create Selection");
selectWindow("NeuN");
run("Duplicate...", "title=intermediate");
run("Restore Selection");
run("Clear Outside");
run("Select None");
setThreshold(1, 255);
run("Analyze Particles...", "size=15-Infinity show=Masks");
close("intermediate");
rename("NeuN+LDHA+");

Table.create("Summary");
layerName = newArray("2", "3a", "3b", "4", "5", "6a", "6b");
//roiManager("Open", roiInput);
name = newArray("NeuN", "NeuN+LDHA+");
for (n = 0; n < 2; n++) {
	for (i = 0; i < 7; i++) {
		selectWindow(name[n]);
		run("Duplicate...", "title=Layer" + layerName[i] + "_" + name[n]);
		roiManager("Select", i);
		run("Clear Outside");
		run("Select None");
		setThreshold(1, 65535, "raw");
		run("Analyze Particles...", "size=15-Infinity summarize");
		close();
	}
}
