function labeler = InitializedLabel3DWrapper(basePath, vidName, frames, comPath, danncePath, skeletonPath, smooth, comOnly)
%% View3DWrapper - Wrap view3d to look at video with reprojections
%
% Example: 
% basePath = '/home/diego/cluster/Jesse/P14_pups/RecordingP14Pup_one';
% vidName = '0.mp4';
% frames = 1:1000; % relative to first frame in vidName.
% comPath = fullfile(basePath, 'COM/predict_results_MAX_01152020/COM3D_undistorted_medfilt.mat');
% danncePath = fullfile(basePath, 'DANNCE/predict_results_MAX_01162020/save_data_MAX.mat');
% skeletonPath = 'skeletons/rat16.mat';
% comOnly = false;
% smooth = true;
% labeler = InitializedLabel3DWrapper(basePath, vidName, frames, comPath, danncePath, skeletonPath, smooth, comOnly)

%% Load in the calibration parameter data
calibPaths = collectCalibrationPaths(basePath);
params = cellfun(@(X) {load(X)}, calibPaths);
params = params([2 3 1]);

vid_paths = collectVideoPaths(basePath,vidName);
matched = collectMatchedFramesPaths(basePath);
matched = cellfun(@(X) {load(X)}, matched);
skeleton = load(skeletonPath);

%% Load the videos into memory
videos = cell(3,1);
for nVid = 1:numel(vid_paths)
    vid = readFrames(vid_paths{nVid}, frames);
    frameInds = matched{nVid}.data_frame(frames);
    V = cat(4, vid(:,:,:,frameInds+1));
    videos{nVid} = V;
end

%% Load in data
COMs = load(comPath);
pred = load(danncePath);
fn = split(vidName,'.');
start_frame = str2double(fn{1}) + 1;
com = COMs.com(frames+start_frame,:);
data_3d = pred.pred(frames+start_frame,:,:);
if comOnly
    data_3d = zeros(size(data_3d));
end
if smooth
    data_3d = smoothdata(smoothdata(data_3d + com,'movmedian',3),'gaussian',5);
else
    data_3d = data_3d + com;
end


%%
figure;
labeler = Label3D(params, videos, skeleton,'savePath','archive/');
labeler.loadFrom3D(data_3d)
