clc; clear;

speed = 0;

pattern = sprintf("v%d_err*_BS*UE*.mat", speed);
files = dir(pattern);
if isempty(files)
    error("No result files found for speed = %d.", speed);
end

nmse_all = [];
sgcs_all = [];

for i = 1:numel(files)
    fprintf("Loading %s\n", files(i).name);
    S = load(files(i).name);

    if ~isfield(S, "data") || ~isfield(S.data, "NMSE_samples") || ~isfield(S.data, "SGCS_samples")
        warning("Skipping invalid file: %s", files(i).name);
        continue;
    end

    nmse_all = [nmse_all; S.data.NMSE_samples(:)];
    sgcs_all = [sgcs_all; S.data.SGCS_samples(:)];
end

if isempty(nmse_all) || isempty(sgcs_all)
    error("No valid NMSE/SGCS samples were collected.");
end

NMSE_mean_all = mean(nmse_all);
SGCS_mean_all = mean(sgcs_all);

fprintf("\nAverage NMSE over all BS/UE result files = %.6f\n", NMSE_mean_all);
fprintf("Average SGCS over all BS/UE result files = %.6f\n", SGCS_mean_all);

save("global_mean_allBSUE.mat", "NMSE_mean_all", "SGCS_mean_all");
