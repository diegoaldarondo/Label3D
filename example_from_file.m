%% Resume a labeling session given a saved label3D session and a frame cache file

clear all;
close all;
addpath(genpath('deps'));
addpath(genpath('skeletons'));

%% Configuration variables -- SET THESE BEFORE RUNNING

% Path to the DANNCE project folder
% This folder should contain at least the following folders: "videos", "calibration"
projectFolder = '~/olveczky/dannce_data/example_dannce_project_folder';
labelDataFilename = '20240205_150914_Label3D';
frameCacheFilename = 'frameCache_f12.mat';

labelingFolder = fullfile(projectFolder, "labeling");

%% Load frames from cache

% load label data to check for framesToLabel

labelDataFilePath = fullfile(labelingFolder, labelDataFilename);
frameCacheFilePath = fullfile(labelingFolder, frameCacheFilename);

labelDataFileInfo = who ('-file', labelDataFilePath);

tmp = load(frameCacheFilePath, "framesToLabel");
frameCacheFramesToLabel = tmp.framesToLabel;

if ismember('framesToLabel', labelDataFileInfo)
    tmp = load(labelDataFilePath, "framesToLabel");
    labelDataFramesToLabel = tmp.framesToLabel;


    if isequaln(labelDataFramesToLabel, frameCacheFramesToLabel)
        disp("Frame cache appears to be accurate. Loading cached data ..." + ...
            " may take a few seconds")
    else
        disp("Frame cache frameToLabel not equal to labelData frameToLabel." + ...
            " Try a different " + ...
            "frame cache file, or generate a new frame cache using example.m" + ...
            "\nExiting script")
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
labelGui = Label3D(labelDataFilePath, videos, 'savePath', labelingFolder);
