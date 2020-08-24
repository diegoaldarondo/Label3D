function data = load_multi_gpu_data(filepath)
%%
files = dir(fullfile(filepath,'*AVG*.mat'));
num = cellfun(@str2double, regexp({files.name},'\d*','Match'), 'uni', 0);
files(cellfun(@isempty, num)) = [];
num = cell2mat(num(~cellfun(@isempty, num)));
[~, I] = sort(num);
files = files(I);

clear data
for nFile = 1:numel(files)
    data(nFile) = load(fullfile(files(nFile).folder, files(nFile).name));
end

data = cat(1, data.pred);
