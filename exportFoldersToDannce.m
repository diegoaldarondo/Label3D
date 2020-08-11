function exportFoldersToDannce(baseDir, varargin)
% exportFoldersToDannce - Convert dance folder structure to dannce.mat
% format
% Optional arguments:
%   order: Array of whole numbers. Specifies order of files in directory.
%          Default order is alphanumeric. 
%          Ex. sync = dir(fullfile(baseDir, 'sync', '*.mat'));
%              sync = sync(order)
% Syntax: exportFoldersToDannce(baseDir)
%         exportFoldersToDannce(baseDir, 'order', order)
sync = dir(fullfile(baseDir, 'sync', '*.mat'));
labeling = dir(fullfile(baseDir, 'labeling', '*.mat'));
calibration = dir(fullfile(baseDir, 'calibration', '*.mat'));

p = inputParser;
defaultOrder = 1:numel(sync);
validOrder = @(X) isnumeric(X) && (sum(mod(X,1)) == 0);
addParameter(p, 'order', defaultOrder, validOrder)
parse(p, varargin{:})
p = p.Results;

sync = arrayfun(@(X) {load(fullfile(X.folder, X.name))}, sync(p.order));
labelData = arrayfun(@(X) {load(fullfile(X.folder, X.name))}, labeling(p.order));
params = arrayfun(@(X) {load(fullfile(X.folder, X.name))}, calibration(p.order));
path = fullfile(baseDir, 'label3d_dannce.mat');
save(path, 'sync','labelData','params')
