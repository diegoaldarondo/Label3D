function Label3DPostlabel(labelPaths, projectFolder, cameraNames)
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

% Pathing
matchedFramesPath = dir(fullfile(projectFolder,'*matchedframes.mat'));
matchedFramesFile = load(fullfile(matchedFramesPath.folder, matchedFramesPath.name));
imDirPath = fullfile(projectFolder, 'labeling','imDir');
fn = dir(fullfile(imDirPath,'*.png'));

% Get the sample IDs from the images in the imDir
nImages = numel(fn);

% Extract sampleId from image names
sampleIds = zeros(numel(fn),1);
for nFile = 1:nImages
    filename = fn(nFile).name;
    [startInd, endInd] = regexp(filename,'\d*');
    sampleIds(nFile) = str2num(filename(startInd:endInd));
end
[sIds, ~] = sort(sampleIds);

% Load the labeling files
labels = cellfun(@load, labelPaths);

% For each labels file, extract the labeled points and save metadata.
nCameras = numel(labelPaths);
for nCam = 1:nCameras
    % Find corresponding sampleIds
    isLabeled = any(~isnan(labels(nCam).data_2D), 2);
    isLabeled = find(isLabeled);
    indices = isLabeled*nCameras - (nCameras - nCam);
    data_sampleID = sIds(indices);
    
    % Save out the set of labeled images. 
    data_2d = labels(nCam).data_2D(isLabeled,:);
    data_3d = labels(nCam).data_3D(isLabeled,:);
    data_frame = matchedFramesFile.matched_frames_aligned{nCam}(data_sampleID);
    savePath = sprintf('%s_Label3D.mat', cameraNames{nCam});
    save(savePath,'data_2d','data_3d','data_frame','data_sampleID')
end
