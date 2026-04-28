%% Plot distance + DT stacked error results
clc;
clear;

axisFontSize = 14;
labelFontSize = 16;
titleFontSize = 18;

out_dir = "figures_locDT";
if ~isfolder(out_dir)
    mkdir(out_dir);
end

entries = collect_locdt_entries();
if isempty(entries)
    error("No locDT result files found. Expected files like BS1_UE1_locDT.mat.");
end

first_data = load(entries(1).filename, "data");
d_list = first_data.data.meta.d_list;
err_percent = first_data.data.meta.err_percent;
num_scenarios = numel(entries);
num_err = numel(err_percent);
num_d = numel(d_list);

NMSE_all = nan(num_scenarios, num_err, num_d);
SGCS_all = nan(num_scenarios, num_err, num_d);
PDP_COS_all = nan(num_scenarios, num_err, num_d);
AZ_COS_all = nan(num_scenarios, num_err, num_d);
EL_COS_all = nan(num_scenarios, num_err, num_d);

for i = 1:num_scenarios
    fprintf("Loading %s\n", entries(i).filename);
    S = load(entries(i).filename, "data");
    validate_metric_size(S.data, num_err, num_d, entries(i).filename);

    NMSE_all(i, :, :) = reshape(S.data.NMSE_mean, 1, num_err, num_d);
    SGCS_all(i, :, :) = reshape(S.data.SGCS_mean, 1, num_err, num_d);
    PDP_COS_all(i, :, :) = reshape(S.data.PDP_COS_mean, 1, num_err, num_d);
    AZ_COS_all(i, :, :) = reshape(S.data.AZ_COS_mean, 1, num_err, num_d);
    EL_COS_all(i, :, :) = reshape(S.data.EL_COS_mean, 1, num_err, num_d);
end

NMSE_mean = squeeze(mean(NMSE_all, 1, "omitnan"));
SGCS_mean = squeeze(mean(SGCS_all, 1, "omitnan"));
PDP_COS_mean = squeeze(mean(PDP_COS_all, 1, "omitnan"));
AZ_COS_mean = squeeze(mean(AZ_COS_all, 1, "omitnan"));
EL_COS_mean = squeeze(mean(EL_COS_all, 1, "omitnan"));

disp("Rows are DT error levels, columns are distance error levels.");
disp("Average NMSE:");
disp(NMSE_mean);
disp("Average SGCS:");
disp(SGCS_mean);
disp("Average PDP cosine:");
disp(PDP_COS_mean);
disp("Average azimuth cosine:");
disp(AZ_COS_mean);
disp("Average elevation cosine:");
disp(EL_COS_mean);

excel_path = fullfile(out_dir, "locDT_plot_data.xlsx");
write_metric_table(excel_path, "Average_NMSE", d_list, err_percent, NMSE_mean);
write_metric_table(excel_path, "Average_SGCS", d_list, err_percent, SGCS_mean);
write_metric_table(excel_path, "Average_PDP_COS", d_list, err_percent, PDP_COS_mean);
write_metric_table(excel_path, "Average_AZ_COS", d_list, err_percent, AZ_COS_mean);
write_metric_table(excel_path, "Average_EL_COS", d_list, err_percent, EL_COS_mean);
fprintf("Saved Excel plot data to %s\n", excel_path);

plot_metric_vs_distance(d_list, err_percent, NMSE_mean, "NMSE", ...
    "Average NMSE", "NMSE vs distance under fixed DT error", ...
    fullfile(out_dir, "NMSE_vs_distance_by_DT.png"), axisFontSize, labelFontSize, titleFontSize);
plot_metric_vs_distance(d_list, err_percent, SGCS_mean, "SGCS", ...
    "Average SGCS", "SGCS vs distance under fixed DT error", ...
    fullfile(out_dir, "SGCS_vs_distance_by_DT.png"), axisFontSize, labelFontSize, titleFontSize);
plot_metric_vs_distance(d_list, err_percent, PDP_COS_mean, "PDP cosine", ...
    "Average PDP cosine", "Time power spectrum similarity vs distance under fixed DT error", ...
    fullfile(out_dir, "PDP_COS_vs_distance_by_DT.png"), axisFontSize, labelFontSize, titleFontSize);
plot_metric_vs_distance(d_list, err_percent, AZ_COS_mean, "Azimuth cosine", ...
    "Average azimuth cosine", "Azimuth power spectrum similarity vs distance under fixed DT error", ...
    fullfile(out_dir, "AZ_COS_vs_distance_by_DT.png"), axisFontSize, labelFontSize, titleFontSize);
plot_metric_vs_distance(d_list, err_percent, EL_COS_mean, "Elevation cosine", ...
    "Average elevation cosine", "Elevation power spectrum similarity vs distance under fixed DT error", ...
    fullfile(out_dir, "EL_COS_vs_distance_by_DT.png"), axisFontSize, labelFontSize, titleFontSize);

summary = struct();
summary.d_list = d_list;
summary.err_percent = err_percent;
summary.NMSE_mean = NMSE_mean;
summary.SGCS_mean = SGCS_mean;
summary.PDP_COS_mean = PDP_COS_mean;
summary.AZ_COS_mean = AZ_COS_mean;
summary.EL_COS_mean = EL_COS_mean;
summary.entries = entries;
save(fullfile(out_dir, "locDT_summary.mat"), "summary");

function entries = collect_locdt_entries()
files = dir("BS*_UE*_locDT.mat");
entries = repmat(struct("filename", "", "bs_idx", 0, "ue_idx", 0), 0, 1);

for i = 1:numel(files)
    tokens = regexp(files(i).name, '^BS(?<bs>\d+)_UE(?<ue>\d+)_locDT\.mat$', "names");
    if isempty(tokens)
        continue;
    end

    entry.filename = files(i).name;
    entry.bs_idx = str2double(tokens.bs);
    entry.ue_idx = str2double(tokens.ue);
    entries(end + 1, 1) = entry; 
end

if ~isempty(entries)
    sort_table = [[entries.bs_idx]', [entries.ue_idx]'];
    [~, order] = sortrows(sort_table, [1, 2]);
    entries = entries(order);
end
end

function validate_metric_size(data, num_err, num_d, filename)
metric_names = ["NMSE_mean", "SGCS_mean", "PDP_COS_mean", "AZ_COS_mean", "EL_COS_mean"];

for i = 1:numel(metric_names)
    metric_name = char(metric_names(i));
    if ~isfield(data, metric_name)
        error("File %s is missing data.%s.", filename, metric_name);
    end

    if ~isequal(size(data.(metric_name)), [num_err, num_d])
        error("File %s has inconsistent size for data.%s.", filename, metric_name);
    end
end
end

function plot_metric_vs_distance(d_list, err_percent, values, legend_prefix, y_label, plot_title, save_path, axisFontSize, labelFontSize, titleFontSize)
fig = figure;
hold on;
markers = ["-o", "-s", "-^", "-d", "-p", "-x", "-v"];

for ie = 1:numel(err_percent)
    marker = markers(mod(ie - 1, numel(markers)) + 1);
    plot(d_list, values(ie, :), marker, "LineWidth", 2, ...
        "DisplayName", sprintf("DT %s%%", format_err_label(err_percent(ie))));
end

hold off;
grid on;
set(gca, "FontSize", axisFontSize);
xlabel("Localization error distance d (m)", "FontSize", labelFontSize);
ylabel(y_label, "FontSize", labelFontSize);
title(plot_title, "FontSize", titleFontSize);
legend("Location", "best");
saveas(fig, save_path);
fprintf("Saved %s (%s)\n", save_path, legend_prefix);
end

function write_metric_table(excel_path, sheet_name, d_list, err_percent, values)
rounded_values = round(values, 4);
col_names = cell(1, numel(d_list));
for id = 1:numel(d_list)
    col_names{id} = matlab.lang.makeValidName(sprintf('d_%s_m', format_err_label(d_list(id))));
end
table_data = [round(err_percent(:), 4), rounded_values];
var_names = [{'DT_error_percent'}, col_names];
T = array2table(table_data, 'VariableNames', var_names);
writetable(T, excel_path, 'Sheet', sheet_name);
end

function label = format_err_label(err_pct)
label = sprintf("%.3g", err_pct);
end
