

layerName = newArray("2", "3a", "3b", "4", "5", "6a", "6b");
for (i = 0; i < 7; i++) {
	selectWindow("Image");
	run("Select None");
	run("Duplicate...", "title=Layer" + layerName[i]);
	if (i > 0) {
		for (k = 0; k < i; k++) {
			roiManager("Select", k);
			setBackgroundColor(0, 0, 0);
			run("Clear", "slice");
		}
	}

	roiManager("Select", i);
	roiManager("rename", "Layer" + layerName[i]);
	setBackgroundColor(0, 0, 0);
	run("Clear Outside");
	setThreshold(1, 65535, "raw");
	roiManager("Select", i);
	run("Create Selection");
	roiManager("Update");
	close();
}