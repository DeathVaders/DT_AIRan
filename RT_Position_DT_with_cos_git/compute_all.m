%% 
clc; clear;

axisFontSize = 14;
labelFontSize = 16;
titleFontSize = 18;

speed = 0;
out_dir = "figs";
if ~exist(out_dir, "dir")
    mkdir(out_dir);
end

entries = collect_result_entries(speed);
if isempty(entries)
    error("No result files found for speed = %d.", speed);
end

err_list = unique([entries.err_percent]);
scenario_keys = unique([[entries.bs_idx]', [entries.ue_idx]'], "rows");

NMSE_Ad = nan(size(scenario_keys, 1), length(err_list));
SGCS_Ad = nan(size(scenario_keys, 1), length(err_list));
PDP_COS_Ad = nan(size(scenario_keys, 1), length(err_list));
AZ_COS_Ad = nan(size(scenario_keys, 1), length(err_list));
EL_COS_Ad = nan(size(scenario_keys, 1), length(err_list));

for i = 1:numel(entries)
    entry = entries(i);
    err_col = find(abs(err_list - entry.err_percent) < 1e-12, 1);
    scenario_row = find(scenario_keys(:, 1) == entry.bs_idx & scenario_keys(:, 2) == entry.ue_idx, 1);

    fprintf("Loading %s\n", entry.filename);
    S = load(entry.filename);
    NMSE_Ad(scenario_row, err_col) = mean(S.data.NMSE_samples);
    SGCS_Ad(scenario_row, err_col) = mean(S.data.SGCS_samples);
    PDP_COS_Ad(scenario_row, err_col) = mean(S.data.PDP_COS_samples);
    AZ_COS_Ad(scenario_row, err_col) = mean(S.data.AZ_COS_samples);
    EL_COS_Ad(scenario_row, err_col) = mean(S.data.EL_COS_samples);
end

NMSE_e_mean = mean_columns_ignore_nan(NMSE_Ad);
SGCS_e_mean = mean_columns_ignore_nan(SGCS_Ad);
PDP_COS_e_mean = mean_columns_ignore_nan(PDP_COS_Ad);
AZ_COS_e_mean = mean_columns_ignore_nan(AZ_COS_Ad);
EL_COS_e_mean = mean_columns_ignore_nan(EL_COS_Ad);

disp("Average NMSE over all BS/UE scenarios for each DT error level:");
disp(NMSE_e_mean);
disp("Average SGCS over all BS/UE scenarios for each DT error level:");
disp(SGCS_e_mean);
disp("Average PDP cosine over all BS/UE scenarios for each DT error level:");
disp(PDP_COS_e_mean);
disp("Average azimuth cosine over all BS/UE scenarios for each DT error level:");
disp(AZ_COS_e_mean);
disp("Average elevation cosine over all BS/UE scenarios for each DT error level:");
disp(EL_COS_e_mean);

fig1 = figure;
bar(err_list, NMSE_e_mean);
grid on;
set(gca, "FontSize", axisFontSize);
set(gca, "XTick", err_list, "XTickLabel", arrayfun(@format_err_label, err_list, "UniformOutput", false));
xlabel("DT error level (%)", "FontSize", labelFontSize);
ylabel("Average NMSE (averaged over all BS/UE scenarios)", "FontSize", labelFontSize);
title("NMSE vs DT error (all BS/UE scenarios)", "FontSize", titleFontSize);
saveas(fig1, fullfile(out_dir, "NMSE_vs_DT_error_allBSUE.png"));

fig2 = figure;
bar(err_list, SGCS_e_mean);
grid on;
set(gca, "FontSize", axisFontSize);
set(gca, "XTick", err_list, "XTickLabel", arrayfun(@format_err_label, err_list, "UniformOutput", false));
xlabel("DT error level (%)", "FontSize", labelFontSize);
ylabel("Average SGCS (averaged over all BS/UE scenarios)", "FontSize", labelFontSize);
title("SGCS vs DT error (all BS/UE scenarios)", "FontSize", titleFontSize);
saveas(fig2, fullfile(out_dir, "SGCS_vs_DT_error_allBSUE.png"));

fig3 = figure;
bar(err_list, PDP_COS_e_mean);
grid on;
set(gca, "FontSize", axisFontSize);
set(gca, "XTick", err_list, "XTickLabel", arrayfun(@format_err_label, err_list, "UniformOutput", false));
xlabel("DT error level (%)", "FontSize", labelFontSize);
ylabel("Average PDP cosine (averaged over all BS/UE scenarios)", "FontSize", labelFontSize);
title("PDP cosine vs DT error (all BS/UE scenarios)", "FontSize", titleFontSize);
saveas(fig3, fullfile(out_dir, "PDP_COS_vs_DT_error_allBSUE.png"));

fig4 = figure;
bar(err_list, AZ_COS_e_mean);
grid on;
set(gca, "FontSize", axisFontSize);
set(gca, "XTick", err_list, "XTickLabel", arrayfun(@format_err_label, err_list, "UniformOutput", false));
xlabel("DT error level (%)", "FontSize", labelFontSize);
ylabel("Average azimuth cosine (averaged over all BS/UE scenarios)", "FontSize", labelFontSize);
title("Azimuth cosine vs DT error (all BS/UE scenarios)", "FontSize", titleFontSize);
saveas(fig4, fullfile(out_dir, "AZ_COS_vs_DT_error_allBSUE.png"));

fig5 = figure;
bar(err_list, EL_COS_e_mean);
grid on;
set(gca, "FontSize", axisFontSize);
set(gca, "XTick", err_list, "XTickLabel", arrayfun(@format_err_label, err_list, "UniformOutput", false));
xlabel("DT error level (%)", "FontSize", labelFontSize);
ylabel("Average elevation cosine (averaged over all BS/UE scenarios)", "FontSize", labelFontSize);
title("Elevation cosine vs DT error (all BS/UE scenarios)", "FontSize", titleFontSize);
saveas(fig5, fullfile(out_dir, "EL_COS_vs_DT_error_allBSUE.png"));

function entries = collect_result_entries(speed)
pattern = sprintf("v%d_err*_BS*_UE*.mat", speed);
files = dir(pattern);
entries = repmat(struct("filename", "", "err_percent", 0, "bs_idx", 0, "ue_idx", 0), 0, 1);

for i = 1:numel(files)
    tokens = regexp(files(i).name, ...
        '^v\d+_err(?<err>[0-9p]+)_BS(?<bs>\d+)_UE(?<ue>\d+)\.mat$', ...
        "names");
    if isempty(tokens)
        continue;
    end

    entry.filename = files(i).name;
    entry.err_percent = str2double(strrep(tokens.err, "p", "."));
    entry.bs_idx = str2double(tokens.bs);
    entry.ue_idx = str2double(tokens.ue);
    entries(end + 1, 1) = entry; %#ok<AGROW>
end

if ~isempty(entries)
    sort_table = [[entries.err_percent]', [entries.bs_idx]', [entries.ue_idx]'];
    [~, order] = sortrows(sort_table, [1, 2, 3]);
    entries = entries(order);
end
end

function label = format_err_label(err_pct)
label = sprintf("%.3g", err_pct);
end

function col_mean = mean_columns_ignore_nan(data)
col_mean = nan(1, size(data, 2));
for col = 1:size(data, 2)
    values = data(:, col);
    values = values(~isnan(values));
    if ~isempty(values)
        col_mean(col) = mean(values);
    end
end
end
