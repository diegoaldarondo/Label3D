function Label3DPostlabel_fromVideo(labelPaths, calibBasePath, cameraNames, frames)
%% Postlabeling script converting Label3D output to dannce formating.
%
% Inputs:
%   labelPaths: Cell array of character vectors with paths to Label3D
%               saved files. 
%   projectFolder: Path to DANNCE project folder.
%   cameraNames: Cell array of character vectors with names of the cameras
%
% Example:
%     projectFolder = 'X:\MotionAnalysisCaptures\Markerless_Recordings\20190701_2\RecordingP21Pup_one';
%     labelPaths = {'C:\code\Label3D\labels\P21_pup_01\2019_11_05_14_00_04Camera_1.mat', ...
%                   'C:\code\Label3D\labels\P21_pup_01\2019_11_05_14_00_04Camera_2.mat', ...
%                   'C:\code\Label3D\labels\P21_pup_01\2019_11_05_14_00_04Camera_3.mat'};
%     cameraNames = {'CameraL','CameraR','CameraS'};
%     Label3DPostlabel(labelPaths, projectFolder, cameraNames);

% Load the labeling files
labels = cellfun(@load, labelPaths);
matched = collectMatchedFramesPaths(calibBasePath);
matched = cellfun(@(X) {load(X)}, matched);
% For each labels file, extract the labeled points and save metadata.
nCameras = numel(labelPaths);
for nCam = 1:nCameras
    % Find corresponding sampleIds
    isLabeled = any(squeeze(~any(labels(nCam).status ~= 2, 2)),1);
    data_sampleID = matched{nCam}.data_sampleID(frames);
    data_frame = matched{nCam}.data_frame(frames);
    data_sampleID = data_sampleID(isLabeled);
    data_frame = data_frame(isLabeled)';
    
    % Save out the set of labeled images. 
    data_2d = labels(nCam).data_2D(isLabeled,:);
    data_3d = labels(nCam).data_3D(isLabeled,:);
    savePath = sprintf('%s_Label3D.mat', cameraNames{nCam});
    save(savePath,'data_2d','data_3d','data_frame','data_sampleID')
end
