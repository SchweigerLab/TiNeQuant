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
#@ Integer(label="Channel 1 particle exclusion size", value=30, min=0, max=100, style="slider") Vasculature_particle_exclusion_size
//Particles with circularity values outside the range are also ignored.
#@ Double(label="Channel 1 particle exclusion circularity (values above are ignored)", style="slider", value=0.9, min=0, max=1, stepSize=0.1) Vasculature_particle_exclusion_circularity_before_dilation_erosion
//Particles smaller than the value are excluded
#@ Integer(label="Channel 2 particle exclusion size in µm^2", value=30, min=0, max=100, style="slider") Neuron_particle_exclusion_size_before_dilation_erosion
//Particles with circularity values outside the range are also ignored.
#@ Double(label="Channel 2 particle exclusion circularity (values above are ignored)", style="slider",value=0.9, min=0, max=1, stepSize=0.1) Neuron_particle_exclusion_circularity_before_dilation_erosion
#@ File(label="Choose input .lif file", style="file") inputFile
#@ File(label="Choose output directory", style="directory") outputDir
#@ File(label="Choose Channel 1 classifier", style="file") classifier_vasculature
#@ File(label="Choose Channel 2 classifier", style="file") classifier_neuron
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
// With this command we gain access to the additional Bio-Formats macro commands
run("Bio-Formats Macro Extensions");
// Determine how many images are in the .lif file. Further used as the variable "seriesCount".
Ext.setId(inputFile);
Ext.getSeriesCount(seriesCount);
//Open one image stack after the other from a single .lif file.
for (i=0; i<seriesCount; i++){
	a=i+1;
	run("Bio-Formats Importer", "open="+inputFile+" autoscale color_mode=Default rois_import=[ROI manager] view=Hyperstack stack_order=XYCZT series_list="+a+"");
	//====================================================================
	//=======================STACK PREPARATION============================
	//====================================================================
	// Get the filename from the title of the image that's open to label the output image
	filename = getTitle();
	rename(a);
	run("Split Channels");
	selectImage("C1-"+a+"");
	run("Duplicate...", "duplicate");
	//Subtract channel 2 from channel 1 to get rid of most of the autofluorescence (Erythrozytes,...)
	imageCalculator("Subtract stack", "C1-"+a+"","C2-"+a+"");
	//Subtract channel 1 from channel 2 to get rid of most of the autofluorescence (Erythrozytes,...)
	imageCalculator("Subtract stack", "C2-"+a+"","C1-"+a+"-1");
	close("C1-"+a+"-1");
	selectImage("C2-"+a+"");
	rename("C2_subtracted_"+a+"");
	run("Duplicate...", "duplicate");
	selectImage("C1-"+a+"");
	rename("C1_subtracted_"+a+"");
	run("Duplicate...", "duplicate");
	//====================================================================
	//====================CHANNEL 1 QUANTIFICATION========================
	//====================================================================
	//Create the table where skeleton statistics are later saved in
	Table.create ("Skeleton Stats")
	//Write a blank value in total length section which is read in case the summarized skeleton has no signal
	Table.set ("Image", 0, "Vasculature_"+a+"");
	Table.set ("Total length", 0, 0);
	selectImage("C1_subtracted_"+a+"");
	//Segmentation
	run("Segment Image With Labkit", "C1_subtracted_"+a+", segmenter_file="+classifier_vasculature+" use_gpu="+Use_GPU_acceleration+"");
	close("C1_subtracted_"+a+"");
	selectImage("segmentation of C1_subtracted_"+a+"");
	//The created image stack from labkit is virtual (disk resident) we duplicate this stack to make it RAM resident again
	run("Duplicate...", "duplicate");
	rename("C1_subtracted_"+a+"");
	close("segmentation of C1_subtracted_"+a+"");
	selectImage("C1_subtracted_"+a+"");
	//Multiply pixel values with 255 to get 0-255segmentation and not 0-1
	run("Multiply...", "value=255 stack");
	//Removal of small particles (salt and pepper noise)
	run("Analyze Particles...", "size="+Vasculature_particle_exclusion_size+"-Infinity circularity=0.00-"+Vasculature_particle_exclusion_circularity_before_dilation_erosion+" show=Masks stack");
	close("C1_subtracted_"+a+"");
	selectImage("Mask of C1_subtracted_"+a+"");
	//The particle analyzer gives out an inverted LUT, the dilate/erode command does reacts LUT dependent not greyvalue dependent
	run("Invert LUT");
	//Dilate cycles followed by erode cylcles connect non connected neuron signal
	run("Options...", "iterations=1 count=1 black pad do=Dilate stack");
	run("Options...", "iterations=1 count=1 black pad do=Erode stack");
	File.makeDirectory(""+outputDir+"/Channel_1_stacks");
	saveAs("Tiff", ""+outputDir+"/Channel_1_stacks/"+filename+"_"+a+"");
	rename("Vasculature_"+a+"");
	//Duplicate the output for lobe volume quantification
	run("Duplicate...", "duplicate");
	rename("Lobe_Volume_Channel_1_"+a+"");
	selectImage("Vasculature_"+a+"");
	//When skeletonization is performed on a image stack the 2D/3D skeletonization actually skeletonizes in 3D space, so one does not have the issue of overlap that is there when dealing with singe images across the z-Axis
	run("Skeletonize (2D/3D)");
	//When skeleton summarization is performed on a image stack, branch length and total length is calculated in 3D space, so the µm total length is actually 3D total length
	run("Summarize Skeleton");
	run("Z Project...", "projection=[Max Intensity]");
	rename("Vasculature_MAX_Skeleton_"+a+"");
	run("Duplicate...", "duplicate");
	//Extract the total skeleton length to include the value in the output montage
	b=Table.get("Total length");
	close("Skeleton Stats");
	//====================================================================
	//===================CHANNEL 2 QUANTIFICATION=========================
	//====================================================================
	//Create the table where skeleton statistics are later saved in
	Table.create ("Skeleton Stats")
	//Write a blank value in total length section which is read in case the summarized skeleton has no signal
	Table.set ("Image", 0, "Neurons_"+a+"");
	Table.set ("Total length", 0, 0);
	selectImage("C2_subtracted_"+a+"");
	//Segmentation
	run("Segment Image With Labkit", "C2_subtracted_"+a+", segmenter_file="+classifier_neuron+" use_gpu="+Use_GPU_acceleration+"");
	close("C2_subtracted_"+a+"");
	selectImage("segmentation of C2_subtracted_"+a+"");
	//The created image stack from labkit is virtual (disk resident) we duplicate this stack to make it RAM resident again
	run("Duplicate...", "duplicate");
	rename("C2_subtracted_"+a+"");
	close("segmentation of C2_subtracted_"+a+"");
	selectImage("C2_subtracted_"+a+"");
	//Multiply pixel values with 255 to get 0-255segmentation and not 0-1
	run("Multiply...", "value=255 stack");
	//Removal of small particles (salt and pepper noise)
	run("Analyze Particles...", "size="+Neuron_particle_exclusion_size_before_dilation_erosion+"-Infinity circularity=0.00-"+Neuron_particle_exclusion_circularity_before_dilation_erosion+" show=Masks stack");
	close("C2_subtracted_"+a+"");
	selectImage("Mask of C2_subtracted_"+a+"");
	//The particle analyzer gives out an inverted LUT, the dilate/erode command does reacts LUT dependent not greyvalue dependent
	run("Invert LUT");
	//Dilate cycles followed by erode cylcles connect non connected neuron signal
	run("Options...", "iterations=1 count=1 black pad do=Dilate stack");
	run("Options...", "iterations=1 count=1 black pad do=Erode stack");
	//Save the Stack in the output directory
	File.makeDirectory(""+outputDir+"/Channel_2_stacks");
	saveAs("Tiff", ""+outputDir+"/Channel_2_stacks/"+filename+"_"+a+"");
	rename("Neurons_"+a+"");
	//Duplicate the output for lobe volume quantification
	run("Duplicate...", "duplicate");
	rename("Lobe_Volume_Channel_2_"+a+"");
	selectImage("Neurons_"+a+"");
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
	//===================LOBE VOLUME QUANTIFICATION=======================
	//====================================================================
	//Combine both segmented images for lobe volume quantification
	imageCalculator("Add create stack", "Lobe_Volume_Channel_1_"+a+"","Lobe_Volume_Channel_2_"+a+"");
	close("Lobe_Volume_Channel_1_"+a+"");
	close("Lobe_Volume_Channel_2_"+a+"");
	selectImage("Result of Lobe_Volume_Channel_1_"+a+"");
	//measure the volume of the lobe in µm^3
	run("Options...", "iterations=20 count=1 black pad do=Dilate stack");
	run("Fill Holes", "stack");
	run("Options...", "iterations=20 count=1 black pad do=Erode stack");
	//Initialize e as variable for adding up slice area measurements
	e=0;
	//Get the z-depth from metadata
	getVoxelSize(width, height, depth, unit);
	//Loop to measure the thresholded area in the Lobe volume image stack and then calculate the Lobevolume in µm^3
	for (n=1; n<=nSlices; n++) {  
	       run("Clear Results"); 
	       setSlice(n);
	       setThreshold(255, 255, "raw");
	       run("Measure");
	       Slicearea=getResult("Area", 0);
	       Totalarea=Slicearea+e;
	       e=Totalarea;
	}
	Lobevolume=Totalarea*depth;
	close("Result of Lobe_Volume_Channel_1_"+a+"");
	//====================================================================
	//===============EXPORT MONTAGE FOR OPTICAL EVALUATION================
	//====================================================================
	selectImage("C1_subtracted_"+a+"-1");
	run("Z Project...", "projection=[Max Intensity]");
	run("Duplicate...", "duplicate");
	//Prepare images for concatenation
	imageCalculator("Subtract", "MAX_C1_subtracted_"+a+"-1","Vasculature_MAX_Skeleton_"+a+"");
	rename("MAX_C1_subtracted_"+a+"-1");
	run("Merge Channels...", "c6=[Vasculature_MAX_Skeleton_"+a+"] c5=[MAX_C1_subtracted_"+a+"-1] create ignore");
	selectWindow("Vasculature_MAX_Skeleton_"+a+"-1");
	run("RGB Color");
	selectWindow("MAX_C1_subtracted_"+a+"-1-1");
	run("RGB Color");
	selectWindow("Composite");
	run("RGB Color");
	rename("Composite_Vasculature");
	close("C1_subtracted_"+a+"");
	close("C1_subtracted_"+a+"-1");
	close("Vasculature_"+a+"");
	close("Composite");
	close("Mask of C1_subtracted_1");
	selectImage("C2_subtracted_"+a+"-1");
	run("Z Project...", "projection=[Max Intensity]");
	run("Duplicate...", "duplicate");
	//Prepare images for concatenation
	imageCalculator("Subtract", "MAX_C2_subtracted_"+a+"-1","Neurons_MAX_Skeleton_"+a+"");
	rename("MAX_C2_subtracted_"+a+"-1");
	run("Merge Channels...", "c6=[Neurons_MAX_Skeleton_"+a+"] c5=[MAX_C2_subtracted_"+a+"-1] create ignore");
	selectWindow("Neurons_MAX_Skeleton_"+a+"-1");
	run("RGB Color");
	selectWindow("MAX_C2_subtracted_"+a+"-1-1");
	run("RGB Color");
	selectWindow("Composite");
	run("RGB Color");
	rename("Composite_Neurons");
	close("C2_subtracted_"+a+"");
	close("C2_subtracted_"+a+"-1");
	close("Neurons_"+a+"");
	close("Composite");
	close("Mask of C2_subtracted_1");
	//Concatenate images and create montage
	run("Concatenate...", "open image1=MAX_C1_subtracted_"+a+"-1-1 image2=Vasculature_MAX_Skeleton_"+a+"-1 image3=Composite_Vasculature image4=MAX_C2_subtracted_"+a+"-1-1 image5=Neurons_MAX_Skeleton_"+a+"-1 image6=Composite_Neurons");
	run("Make Montage...", "columns=3 rows=2 scale=1");
	close("Untitled");
	//Calculate a scaling factor to be able to label images independent of the image size
	widthscale = getWidth()/1536;
	heightscale = getHeight()/1024;
	//Annotate merged image
	makeRectangle(0, 0, 210*widthscale, 60*widthscale);
	run("Clear", "slice");
	setFont("Arial", 30*widthscale, " antialiased");
	setColor("white");
	drawString("Channel_1", 0, 30*widthscale);
	drawString(""+b+"µm", 0, 60*widthscale);
	makeRectangle(0, 512*heightscale, 210*widthscale, 60*widthscale);
	run("Clear", "slice");
	drawString("Channel_2", 0, 543*heightscale);
	drawString(""+c+"µm", 0, 573*heightscale);
	makeRectangle(0, 974*heightscale, 512*widthscale, 50*widthscale);
	run("Clear", "slice");
	makeRectangle(0, 0, 0, 0);
	drawString(filename, 0, 1014*heightscale);
	//====================================================================
	//====================Data sorting and Export=========================
	//====================================================================
	//Write the results table
	selectWindow("Skeleton results");
	//Channel 1 quantification
	Table.set ("Nr", i*3, a);
	Table.set ("Image", i*3, "Channel_1_"+filename+"_"+a+"");
	Table.set ("Total length",i*3, b);
	Table.set ("Unit", i*3, "µm");
	//Channel 2 quantification 
	Table.set ("Nr", i*3+1, seriesCount+a);
	Table.set ("Image", i*3+1, "Channel_2_"+filename+"_"+a+"");
	Table.set ("Total length", i*3+1, c);
	Table.set ("Unit", i*3+1, "µm");
	//Lobevolume quantification
	Table.set ("Nr", i*3+2, seriesCount*2+a);
	Table.set ("Image", i*3+2, "Lobevolume_"+filename+"_"+a+"");
	Table.set ("Total length", i*3+2, Lobevolume);
	Table.set ("Unit", i*3+2, "µm^3");
	File.makeDirectory(""+outputDir+"/Montages");
	saveAs("Jpeg", ""+outputDir+"/Montages/"+filename+"_"+a+"");
	close("Exception");
	// Closes all images
	close("*");
	close("Results");
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