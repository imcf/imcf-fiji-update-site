// an auto-run script with some sanity checking (which is basically impossible
// with the macro language as it doesn't allow for catching errors/exceptions)

importClass(Packages.ij.IJ);
importClass(Packages.ij.Prefs);

importClass(Packages.java.io.File);
importClass(Packages.java.util.Arrays);


function locateJar() {
	ijRoot = IJ.getDirectory("imagej");
	jarsDir = new File(ijRoot, "jars");
	filelist = jarsDir.list();
	Arrays.sort(filelist);
	location = new String();
	for (i = 0; i < filelist.length; i++) {
	    fname = filelist[i];
	    if (fname.startsWith('imcf-fiji-toolbars')) {
	    	// print(fname);
	    	location = fname;
	    }
	}
	if (location == "" || location == null) {
 		log_debug("Unable to locate 'imcf-fiji-toolbars' JAR!");
 		return location;
	}
	location = "jar:file:../jars/" + location + "!/bars/IMCF_Toolbar.bar";
	log_debug("Located 'imcf-fiji-toolbars' JAR: " + location);
	return location;
}


function log_debug(msg) {
    if (debug)
        print(msg);
}


debug = Prefs.get("imcf.debugging", false);

if (Prefs.get("imcf.show_toolbar", true)) {
    log_debug("IMCF Toolbar is enabled in preferences.");

    // make sure we only launch the bar if the ActionBar plugin is installed:
    try {
        log_debug("Trying to launch the IMCF toolbar...")
        importClass(Packages.Action_Bar);

        // CAUTION: calling "IMCF Toolbar" from this script works fine on Linux
        // and Windows, but fails with an "Unrecognized command" popup message
        // on MacOS, so we have to take a more complex approach here...
        // IJ.run("IMCF Toolbar", ""); // <- fails on MacOS //
        
        jarLocation = locateJar();
        if (location != "" && location != null) {
			IJ.run("Action Bar", jarLocation);
        }
    }
    catch(e) {
        log_debug("Toolbar failed, is the 'ActionBar' plugin installed?");
    }
} else {
    log_debug("IMCF Toolbar is DISABLED in preferences.");
}



null
