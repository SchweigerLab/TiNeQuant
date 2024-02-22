//====================================================================
//=========================Schweiger Lab==============================
//==================Tina.Schweiger@uni-graz.at========================
//====================================================================

//====================================================================
//=======================Thomas Rauchenwald===========================
//==================Thomas.Rauchenwald@uni-graz.at====================
//====================================================================

//====================================================================
//=========Script for 3D quantification of Neurons/Vasculature========
//=================of whole mount-cleared tissue scans================
//====================================================================

//====================================================================
//============================LICENSE=================================
//====================================================================
/*
	This program is free software: you can redistribute it and/or modify
    it under the terms of the GNU General Public License as published by
    the Free Software Foundation, version 3 of the License.

    This program is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY.  
    
    See the GNU General Public License for more details.

    <https://www.gnu.org/licenses/gpl-3.0>.
*/
//====================================================================
//============================SETTINGS================================
//====================================================================
#@ String(choices={"true", "false"}, style="radioButtonHorizontal", value=false ) Use_GPU_acceleration
//Particles smaller than the value are excluded
#@ Integer(label="Particle exclusion size in µm^2", value=15, min=0, max=100, style="slider") Neuron_particle_exclusion_size_before_dilation_erosion
//Particles with circularity values outside the range are also ignored
#@ Double(label="Particle exclusion circularity (values above are ignored)", style="slider",value=0.9, min=0, max=1, stepSize=0.1) Neuron_particle_exclusion_circularity_before_dilation_erosion
#@ File(label="Choose input directory", style="directory") inputDirectory
#@ File(label="Choose output directory", style="directory") outputDir
#@ File(label="Choose classifier", style="file") classifier_neuron
setBatchMode(true);
// Retrieve the value of the "BlackBackground" option,if the background is not set correctly the script does not function as intended
black_background_option = eval("js","Prefs.blackBackground");
// Check the value of the "BlackBackground" option, if set correctly, continue, if not print that one needs to set the option correctly
if (black_background_option == "true") {
//Create result table
Table.create ("Skeleton results");
//Set the foreground and background color for correct annotation of the evaluation images
setForegroundColor(255, 255, 255);
setBackgroundColor(0, 0, 0);
//====================================================================
//==============================Loop==================================
//====================================================================
//Loop to process all images in the chosen input directory
fileList = getFileList(inputDirectory);
for (i = 0; i < fileList.length; i++)
{
	a=i+1;
	//Open the next image from the generated filelist
	open(""+inputDirectory+"/"+fileList[i]+"");
	// Get the filename from the title of the image that's open to label the output image
	//====================================================================
	//=======================STACK PREPARATION============================
	//====================================================================
	filename = getTitle();
	rename("Image_"+a+"");
	run("Duplicate...", "duplicate");
	//====================================================================
	//=======================QUANTIFICATION===============================
	//====================================================================
	///Create the table where skeleton statistics are later saved in
	Table.create ("Skeleton Stats")
	//Write a blank value in total length section which is read in case the summarized skeleton has no signal
	Table.set ("Image", 0, "Neurons_"+a+"");
	Table.set ("Total length", 0, 0);
	selectImage("Image_"+a+"");
	//Segmentation
	run("Segment Image With Labkit", "Image_"+a+", segmenter_file="+classifier_neuron+" use_gpu="+Use_GPU_acceleration+"");
	close("Image_"+a+"");
	selectImage("segmentation of Image_"+a+"");
	//The created image stack from labkit is virtual (disk resident) we duplicate this stack to make it RAM resident again
	run("Duplicate...", "duplicate");
	rename("Image_"+a+"");
	close("segmentation of Image_"+a+"");
	selectImage("Image_"+a+"");
	//Multiply pixel values with 255 to get 0-255segmentation and not 0-1
	run("Multiply...", "value=255 stack");
	//Removal of small particles (salt and pepper noise)
	run("Analyze Particles...", "size="+Neuron_particle_exclusion_size_before_dilation_erosion+"-Infinity circularity=0.00-"+Neuron_particle_exclusion_circularity_before_dilation_erosion+" show=Masks stack");
	close("Image_"+a+"");
	selectImage("Mask of Image_"+a+"");
	//The particle analyzer gives out an inverted LUT, the dilate/erode command does reacts LUT dependent not greyvalue dependent
	run("Invert LUT");
	//Dilate cycles followed by erode cylcles connect non connected neuron signal
	run("Options...", "iterations=1 count=1 black pad do=Dilate stack");
	run("Options...", "iterations=1 count=1 black pad do=Erode stack");
	//Save the Stack in the output directory
	File.makeDirectory(""+outputDir+"/Stacks")
	saveAs("Tiff", ""+outputDir+"/Stacks/"+filename+"");
	rename("Neurons_"+a+"");
	//When skeletonization is performed on a image stack the 2D/3D skeletonization actually skeletonizes in 3D space, so one does not have the issue of overlap that is there when dealing with singe images across the z-Axis
	run("Skeletonize (2D/3D)");
	//When skeleton summarization is performed on a image stack, branch length and total length is calculated in 3D space, so the µm total length is actually 3D total length
	run("Summarize Skeleton");
	run("Z Project...", "projection=[Max Intensity]");
	rename("Neurons_MAX_Skeleton_"+a+"");
	run("Duplicate...", "duplicate");
	//Extract the total skeleton length to include the value in the output montage
	c=Table.get("Total length");
	close("Skeleton Stats");
	//====================================================================
	//===============EXPORT MONTAGE FOR OPTICAL EVALUATION================
	//====================================================================
	selectImage("Image_"+a+"-1");
	run("Z Project...", "projection=[Max Intensity]");
	run("Duplicate...", "duplicate");
	//Prepare images for concatenation
	imageCalculator("Subtract", "MAX_Image_"+a+"-1","Neurons_MAX_Skeleton_"+a+"");
	rename("MAX_Image_"+a+"-1");
	run("Merge Channels...", "c6=[Neurons_MAX_Skeleton_"+a+"] c5=[MAX_Image_"+a+"-1] create ignore");
	selectWindow("Neurons_MAX_Skeleton_"+a+"-1");
	run("RGB Color");
	selectWindow("MAX_Image_"+a+"-1-1");
	run("RGB Color");
	selectWindow("Composite");
	run("RGB Color");
	rename("Composite_Neurons");
	close("Image_"+a+"");
	close("Image_"+a+"-1");
	close("Neurons_"+a+"");
	close("Composite");
	close("Mask of Image_1");
	//Concatenate the images and create an image-montage
	run("Concatenate...", "open image1=MAX_Image_"+a+"-1-1 image2=Neurons_MAX_Skeleton_"+a+"-1 image3=Composite_Neurons");
	run("Make Montage...", "columns=3 rows=1 scale=1");
	close("Untitled");
	//Calculate a scaling factor to be able to label images independent of the image size
	widthscale = getWidth()/1536;
	heightscale = getHeight()/512;
	//Annotate montage
	makeRectangle(0, 0, 512*widthscale, 40*widthscale);
	run("Clear", "slice");
	setFont("Arial", 20*widthscale, " antialiased");
	setColor("white");
	drawString(filename, 0, 20*widthscale);
	drawString(""+c+"µm", 0, 40*widthscale);
	makeRectangle(0, 0, 0, 0);
	//====================================================================
	//====================Data sorting and Export=========================
	//====================================================================
	//Write the results table
	selectWindow("Skeleton results");
	Table.set ("Nr", i, a);
	Table.set ("Image", i, filename);
	Table.set ("Total length",i, c);
	Table.set ("Unit", i, "µm");
	//Save the created montage
	File.makeDirectory(""+outputDir+"/Montages");
	saveAs("Jpeg", ""+outputDir+"/Montages/"+filename+"");
	// Closes all images
	close("*");
}
//Sort and save the results table
selectWindow("Skeleton results");
Table.sort("Nr");
saveAs("Results", ""+outputDir+"/Results.csv");
showMessage("Done");
} 
else {
print("Background setting is not set correctly for this script to work, please go to process-->binary-->options-->BlackBackground");
};