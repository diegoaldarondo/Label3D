function data = load_multi_gpu_data(filepath)
%%
files = dir(fullfile(filepath,'*MAX*.mat'));
Num = cellfun(@str2double, regexp({files.name},'\d*','Match'));
[~, I] = sort(Num);
files = files(I);

for nFile = 1:numel(files)
    disp(nFile)
    data(nFile) = load(fullfile(files(nFile).folder, files(nFile).name));
end
out = zeros(size(data(end).pred));
for nFile = 1:numel(files)
    out(1+(nFile-1)*1000:nFile*1000,:,:) = data(nFile).pred(1:1000,:,:);
end


