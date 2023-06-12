clear all
close all;
addpath(genpath('deps'))
addpath(genpath('skeletons'))
danncePath = 'Y:/Diego/code/DANNCE';

%% Load in the calibration parameter data
projectFolder = "./2022_10_17_M1_M2";
% projectFolder = "./2022_10_17_M3_M4";
calibPaths = collectCalibrationPaths(projectFolder);
params = cellfun(@(X) {load(X)}, calibPaths);

%% Load the videos into memory
vidName = '0.mp4';
vidPaths = collectVideoPaths(projectFolder,vidName);
videos = cell(6,1);
sync = collectSyncPaths(projectFolder, '*.mat');
sync = cellfun(@(X) {load(X)}, sync);

% In case the demo folder uses the dannce.mat data format. 
if isempty(sync)
    dannce_file = dir(fullfile(projectFolder, '*dannce.mat'));
    dannce = load(fullfile(dannce_file(1).folder, dannce_file(1).name));
    sync = dannce.sync;
    params = dannce.params;
end

pts3d1 = load(fullfile(projectFolder, 'SDANNCE_x2\bsl0.5_FM_rat1\save_data_AVG0.mat'));
pts3d2 = load(fullfile(projectFolder, 'SDANNCE_x2\bsl0.5_FM_rat2\save_data_AVG0.mat'));
com1 = mean(pts3d1.pred, 3);
com2 = mean(pts3d2.pred, 3);
dist = sqrt(sum((com1 - com2).^2,2));
K = 100;
social_close_ids = find(dist>30 & dist < 150);
rng(10)
rand_ids = randperm(length(social_close_ids), K);
framesToLabel = social_close_ids(rand_ids);
framesToLabel = sort(framesToLabel);

for nVid = 1:numel(vidPaths)
    disp(nVid)
    frameInds = sync{nVid}.data_frame(framesToLabel);
    vid = VideoReader(vidPaths{nVid});
    for i = 1:numel(frameInds)
        vid.CurrentTime = (frameInds(i)+1)/50;
        frame = readFrame(vid);
        disp(i)
        if i == 1
            videos{nVid} = zeros(size(frame,1), size(frame,2), size(frame,3), numel(frameInds), 'uint8');
        end
        videos{nVid}(:,:,:,i) = frame*2.5;
    end
    delete(vid)
end

%% Get the skeleton
% skeleton = load('skeletons/rat16');
skeleton = load('skeletons/rat23');
skeleton.joints_idx = cat(1, skeleton.joints_idx, skeleton.joints_idx + 23 );
skeleton.color = cat(1, skeleton.color, skeleton.color*.6);
skeleton.joint_names = cat(2, skeleton.joint_names, skeleton.joint_names);

%% Start Label3D
close all
labelGui = Label3D(params, videos, skeleton, 'sync', sync, 'framesToLabel', framesToLabel);
pts3d1 = load(fullfile(projectFolder, 'SDANNCE_x2\bsl0.5_FM_rat1\save_data_AVG0.mat'));
pts3d2 = load(fullfile(projectFolder, 'SDANNCE_x2\bsl0.5_FM_rat2\save_data_AVG0.mat'));
pts3d = cat(4, pts3d1.pred, pts3d2.pred);
% pts3d = load('save_data_AVG.mat');
% pts3d = permute(pts3d.pred, [1, 3, 4, 2]);
pts3d = reshape(pts3d, size(pts3d, 1), 3, []);
pts3d = pts3d(framesToLabel,:,:);
labelGui.loadFrom3D(pts3d)