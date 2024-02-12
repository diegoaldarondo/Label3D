%% Example to resume labeling a previously saved labeling session
% This assumes you have a label file and a previously saved video file

clear all;
close all;
addpath(genpath('deps'));
addpath(genpath('skeletons'));


%% Configuration variables -- UPDATE THESE BEFORE RUNNING -- then run whole file

% Path to the DANNCE project folder
% This folder should contain at least the following folders: "videos", "calibration"
projectFolder = '~/olveczky/dannce_data/example_dannce_project_folder';

% Assume both these files exist inside of the labeling folder:
labelingFolder = fullfile(projectFolder, "labeling");
videoDataFilename = 'frameData.mat';
labelDataFilename = '20240131_144440_Label3D.mat';

%% Load video data

videoDataFilepath = fullfile(labelingFolder, videoDataFilename);
labelDataFilepath = fullfile(labelingFolder, labelDataFilename);

disp("Loading video file data, may take a few seconds...")
videoFile = load(videoDataFilepath);

framesToLabel = videoFile.framesToLabel;
videoPaths = videoFile.videoPaths;
videos = videoFile.videos;
clear videoFile; % release memeory (video files can be 2+gb!)

% disp("Loading previous labeling session data, should be quick...")
% labelFile = load(labelDataFilepath);
% 
% cameraParameters = labelFile.camParams;



%% Start Label3D
close all;
fprintf("Launching Label3D. May take a few seconds...\n")
labelGui = Label3D(calibrationParams, videos, skeleton, ...
    'savePath', labelingFolder);

