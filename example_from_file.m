%% Resume a labeling session given a saved label3D session and a frame cache file

clear all;
close all;
addpath(genpath('deps'));
addpath(genpath('skeletons'));

%% Configuration variables -- SET THESE BEFORE RUNNING

% Path to the DANNCE project folder
% This folder should contain at least the following folders: "videos", "calibration"
projectFolder = "C:\data\F5-F7_openfield_photometry\alone\day1\240116_151948_F7";
labelDataFilename = '20240423_170638_Label3D.mat';
frameCacheFilename = 'frameCache_f75.mat';

labelingFolder = fullfile(projectFolder, "labeling");

% if this is true, automatically export the data after launching the gui
exportData = true;

% total number of frames in the video files. Important for exporting.
% this is not the number of frames to label. Usually a large # like 90000
% or 180000.
vidSourceTotalFrames = 90000;

%% Load frames from cache

% load label data to check for framesToLabel

labelDataFilePath = fullfile(labelingFolder, labelDataFilename);
frameCacheFilePath = fullfile(labelingFolder, frameCacheFilename);

labelDataFileInfo = who ('-file', labelDataFilePath);

tmp = load(frameCacheFilePath, "framesToLabel");
frameCacheFramesToLabel = tmp.framesToLabel;

framesToLabel = 0;

if ismember('framesToLabel', labelDataFileInfo)
    tmp = load(labelDataFilePath, "framesToLabel");
    labelDataFramesToLabel = tmp.framesToLabel;


    if isequaln(labelDataFramesToLabel, frameCacheFramesToLabel)
        disp("Frame cache appears to be accurate. Loading cached data ..." + ...
            " may take a few seconds")
        framesToLabel = labelDataFramesToLabel;
    else
        disp("Frame cache frameToLabel not equal to labelData frameToLabel." + ...
            " Try a different " + ...
            "frame cache file, or generate a new frame cache using example.m")
        fprintf("Did you forget to update 'frameCacheFilename'? E.g. 100 vs 75 frames.\n")
        fprintf("\nExiting script\n");
        return;
    end
else
    disp("Label data is missing frames to label. Attempting to generate" + ...
        " framesToLabel using uniform sampling")

    nFramesWholeVideo = input("Enter the # of frames in the entire video" + ...
        " (integer) and press return: ");
    fprintf("\n")
    nFramesToLabel = input("Enter the original # of frames to label" + ...
        " (integer) and press return: ");
    fprintf("\n")
    maybeFramesToLabel = round(linspace(1, nFramesWholeVideo, nFramesToLabel));
    
    if isequaln(maybeFramesToLabel, frameCacheFramesToLabel)
        disp("Evenly spaced frames appears to match cache frame numbers." + ...
            " Loading cached data ..." + ...
            " may take a few seconds")
        framesToLabel = maybeFramesToLabel;
    else
        disp("Evenly spaced frames is not accurate. Try creating a " + ...
            "framesToLabel array in the labelData file with the same list " + ...
            "of frames as the original labeling session" + ...
            "\nExiting script")
        return;
    end
end


%% Load cached video frames

frameCacheData = load(frameCacheFilePath, "videos");
videos = frameCacheData.videos;


%% Start Label3D

close all;
fprintf("Launching Label3D. May take a few seconds...\n")
labelGui = Label3D(labelDataFilePath, videos, 'savePath', labelingFolder, ...
    'framesToLabel', framesToLabel );

%% Optionally export the data to the dannce data format and close the GUI

if exportData
    if numel(labelGui.skeleton.joint_names) > 3
        % DANNCE label3d export 
        exportFilename=sprintf("%sDANNCE_Label3D_dannce.mat", ...
            labelGui.sessionDatestr);
    else
        % COM label3d export
        exportFilename=sprintf("%sCOM_Label3D_dannce.mat", ...
            labelGui.sessionDatestr);
    end
    exportFolder=fullfile(projectFolder, "export");
    mkdir(exportFolder)
    fprintf("Exporting to folder %s\n", exportFolder);
    labelGui.exportDannce('basePath' , projectFolder, ...
        'totalFrames', vidSourceTotalFrames, ...
        'makeSync', true, ...
        'saveFolder' , exportFolder, ...
        'saveFilename', exportFilename)
    close all;
end
