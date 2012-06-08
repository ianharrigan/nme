package installers;


import data.Asset;
import neko.io.File;
import neko.io.Path;
import neko.io.Process;
import neko.FileSystem;
import neko.Lib;
import neko.Sys;


class AndroidInstaller extends InstallerBase {
	
	
	override function build ():Void {
		
		var destination:String = buildDirectory + "/android/bin";
		var hxml:String = buildDirectory + "/android/haxe/" + (debug ? "debug" : "release") + ".hxml";
		
		var arm5 = buildDirectory + "/android/bin/libs/armeabi/libApplicationMain.so";
		var arm7 = buildDirectory + "/android/bin/libs/armeabi-v7a/libApplicationMain.so";
		
		if (!defines.exists ("ARM7-only")) {
			
			runCommand ("", "haxe", [ hxml ] );
			copyIfNewer (buildDirectory + "/android/obj/libApplicationMain" + (debug ? "-debug" : "") + ".so", arm5);
			
		} else {
			
			if (FileSystem.exists (arm5)) {
				
				FileSystem.deleteFile (arm5);
				
			}
			
		}
		
		if (defines.exists ("ARM7") || defines.exists ("ARM7-only")) {
			
			runCommand ("", "haxe", [ hxml, "-D", "HXCPP_ARM7" ] );
			copyIfNewer (buildDirectory + "/android/obj/libApplicationMain-7" + (debug ? "-debug" : "") + ".so", arm7);
			
		} else {
			
			if (FileSystem.exists (arm7)) {
				
				FileSystem.deleteFile (arm7);
				
			}
			
		}
		
		if (defines.exists ("JAVA_HOME")) {
			
			Sys.putEnv ("JAVA_HOME", defines.get ("JAVA_HOME"));
			
		}
		
		if (defines.exists ("ANDROID_SDK")) {
			
			Sys.putEnv ("ANDROID_SDK", defines.get ("ANDROID_SDK"));
			
		}
		
		var ant:String = defines.get ("ANT_HOME");
		
		if (ant == null || ant == "") {
			
			ant = "ant";
			
		} else {
			
			ant += "/bin/ant";
			
		}
		
		var build:String = "debug";
		
		if (defines.exists ("KEY_STORE")) {
			
			build = "release";
			
		}
		
		// Fix bug in Android build system, force compile
		
		var buildProperties = destination + "/bin/build.prop";
		
		if (FileSystem.exists (buildProperties)) {
			
			FileSystem.deleteFile (buildProperties);
			
		}
		
		runCommand (destination, ant, [ build ]);
		
	}
	
	
	override function clean ():Void {
		
		var targetPath = buildDirectory + "/android";
		
		if (FileSystem.exists (targetPath)) {
			
			removeDirectory (targetPath);
			
		}
		
	}
	
	
	private function getADB ():Dynamic {
		
		var path:String = defines.get ("ANDROID_SDK") + "/tools/";
		var name:String = "adb";
		
		if (defines.get ("HOST") == "windows") {
			
			name += ".exe";
			
		}
		
		if (!FileSystem.exists (path + name)) {
			
			path = defines.get ("ANDROID_SDK") + "/platform-tools/";
			
		}
		
		if (!InstallTool.isWindows) {
			
			name = "./" + name;
			
		}
		
		return { path: path, name: name };
		
	}
	
	
	override function generateContext ():Void {
		
		super.generateContext ();
		
		context.CPP_DIR = buildDirectory + "/android/obj";
		
		if (defines.exists ("KEY_STORE")) {
			
			context.KEY_STORE = FileSystem.fullPath (defines.get ("KEY_STORE"));
			
		}
		
		updateIcon();
		
	}
	
	
	override function onCreate ():Void {
		
		if (!defines.exists ("ANDROID_SETUP")) {
			
			throw "You need to run \"nme setup android\" before you can use the Android target";
			
		}
		
	}
	
	
	override function run ():Void {
		
		var pack:String = defines.get ("APP_PACKAGE");
		var adb:Dynamic = getADB ();
		
		runCommand (adb.path, adb.name, [ "shell", "am start -a android.intent.action.MAIN -n " + pack + "/" + pack + ".MainActivity" ]);
		
	}
	
	
	override function traceMessages ():Void {
		
		var adb:Dynamic = getADB ();
		
		// Use -DFULL_LOGCAT or  <set name="FULL_LOGCAT" /> if you do not want to filter log messages
		
		if (defines.exists("FULL_LOGCAT")) {
			
			runCommand (adb.path, adb.name, [ "logcat", "-c" ]);
			runCommand (adb.path, adb.name, [ "logcat" ]);
			
		} else if (debug) {
			
			var filter = "*:E";
			var includeTags = [ "NME", "Main", "GameActivity", "GLThread", "trace" ];
			
			for (tag in includeTags) {
				
				filter += " " + tag + ":D";
				
			}
			
			Lib.println (filter);
			
			runCommand (adb.path, adb.name, [ "logcat", filter ]);
			
		} else {
			
			runCommand (adb.path, adb.name, [ "logcat", "*:S trace:I" ]);
			
		}
		
	}
	
	
	override function uninstall ():Void {
		
		var adb:Dynamic = getADB ();
		var pack:String = defines.get ("APP_PACKAGE");
		
		runCommand (adb.path, adb.name, [ "uninstall", pack ]);
		
	}
	

	private function updateIcon () {
		
		var destination:String = buildDirectory + "/android/bin";
		mkdir (destination);
		mkdir (destination + "/res/drawable-ldpi/");
		mkdir (destination + "/res/drawable-mdpi/");
		mkdir (destination + "/res/drawable-hdpi/");
		
		var orig = allFiles.length;
		
		if (icons.updateIcon (36, 36, destination + "/res/drawable-ldpi/icon.png"))
			allFiles.push(destination + "/res/drawable-ldpi/icon.png");
		if (icons.updateIcon (48, 48, destination + "/res/drawable-mdpi/icon.png"))
			allFiles.push(destination + "/res/drawable-mdpi/icon.png");
		if (icons.updateIcon (72, 72, destination + "/res/drawable-hdpi/icon.png"))
			allFiles.push(destination + "/res/drawable-hdpi/icon.png");
		if (icons.updateIcon (96, 96, destination + "/res/drawable-xhdpi/icon.png"))
			allFiles.push(destination + "/res/drawable-xhdpi/icon.png");
		
		if (orig != allFiles.length)
			context.HAS_ICON = true;
		
	}
	
	
	override function update ():Void {
		
		var destination:String = buildDirectory + "/android/bin/";
		mkdir (destination);
		
		var packageDirectory:String = defines.get ("APP_PACKAGE");
		packageDirectory = destination + "/src/" + packageDirectory.split (".").join ("/");
		mkdir (packageDirectory);
		
		generateSWFClasses (buildDirectory + "/android/haxe");
		
		for (ndll in ndlls) {
			
			var ndllPath = ndll.getSourcePath ("Android", "lib" + ndll.name + "-debug.so");
			var debugExists = FileSystem.exists (ndllPath);
			
			if (!debug || !debugExists) {
				
				ndllPath = ndll.getSourcePath ("Android", "lib" + ndll.name + ".so");
				
			}
			
			if (debugExists) {
				
				mkdir (destination + "/libs/armeabi/");
				File.copy (ndllPath, destination + "/libs/armeabi/lib" + ndll.name + ".so");
				
			} else {
				
				copyIfNewer (ndllPath, destination + "/libs/armeabi/lib" + ndll.name + ".so");
				
			}
			
		}
		
		for (javaPath in javaPaths) {
			
			try {
				
				if (FileSystem.isDirectory (javaPath)) {
					
					recursiveCopy (javaPath, destination + "/src", true);
					
				} else {
					
					copyIfNewer (javaPath, destination + "/src/" + Path.withoutDirectory (javaPath));
					
				}
				
			} catch (e:Dynamic) {
				
				throw"Could not find javaPath " + javaPath +" required by extension."; 
				
			}
			
		}
		
		for (asset in assets) {
			
			if (asset.type != Asset.TYPE_TEMPLATE) {
				
				var targetPath:String = "";
				
				switch (asset.type) {
					
					case Asset.TYPE_SOUND, Asset.TYPE_MUSIC:
						
						asset.resourceName = asset.id;
						targetPath = destination + "/res/raw/" + asset.flatName + "." + Path.extension (asset.targetPath);
					
					default:
						
						asset.resourceName = asset.flatName;
						targetPath = destination + "/assets/" + asset.resourceName;
					
				}
				
				copyIfNewer (asset.sourcePath, targetPath);
				
			}
			
		}
		
		recursiveCopy (NME + "/tools/command-line/android/template", destination);
		copyFile (NME + "/tools/command-line/android/MainActivity.java", packageDirectory + "/MainActivity.java");
		recursiveCopy (NME + "/tools/command-line/haxe", buildDirectory + "/android/haxe");
		recursiveCopy (NME + "/tools/command-line/android/hxml", buildDirectory + "/android/haxe");
		
		for (asset in assets) {
			
			if (asset.type == Asset.TYPE_TEMPLATE) {
				
				mkdir (Path.directory (destination + asset.targetPath));
				copyFile (asset.sourcePath, destination + asset.targetPath);
				
			}
			
		}
		
	}
	
	
	override function updateDevice ():Void {
		
		var build:String = "debug";
		
		if (defines.exists ("KEY_STORE")) {
			
			build = "release";
			
		}
		
		var apk:String = FileSystem.fullPath (buildDirectory) + "/android/bin/bin/" + defines.get ("APP_FILE") + "-" + build + ".apk";
		var adb:Dynamic = getADB ();
		
		runCommand (adb.path, adb.name, [ "install", "-r", apk ]);
		
   }
	
	
}
