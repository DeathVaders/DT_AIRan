%% Plot only-DT and only-distance slices from summary MAT file
clc;
clear;

out_dir = "summary_locDT";
if ~isfolder(out_dir)
    mkdir(out_dir);
end

[mat_path, source_dir] = locate_summary_mat();
fprintf("Using summary file: %s\n", mat_path);

S = load(mat_path, "summary");
if ~isfield(S, "summary")
    error("File %s does not contain variable 'summary'.", mat_path);
end

summary = S.summary;
required_fields = ["d_list", "err_levels", "err_percent", ...
    "NMSE_mean", "SGCS_mean", "PDP_COS_mean", "AZ_COS_mean", "EL_COS_mean"];
for i = 1:numel(required_fields)
    field_name = char(required_fields(i));
    if ~isfield(summary, field_name)
        error("summary is missing field '%s'.", field_name);
    end
end

d_list = summary.d_list(:);
err_levels = summary.err_levels(:);
err_percent = summary.err_percent(:);

NMSE_mean = summary.NMSE_mean;
SGCS_mean = summary.SGCS_mean;
PDP_COS_mean = summary.PDP_COS_mean;
AZ_COS_mean = summary.AZ_COS_mean;
EL_COS_mean = summary.EL_COS_mean;

num_err = numel(err_levels);
num_d = numel(d_list);
validate_metric_matrix(NMSE_mean, num_err, num_d, "NMSE_mean");
validate_metric_matrix(SGCS_mean, num_err, num_d, "SGCS_mean");
validate_metric_matrix(PDP_COS_mean, num_err, num_d, "PDP_COS_mean");
validate_metric_matrix(AZ_COS_mean, num_err, num_d, "AZ_COS_mean");
validate_metric_matrix(EL_COS_mean, num_err, num_d, "EL_COS_mean");

only_dt_table = table( ...
    round(err_levels, 4), ...
    round(err_percent, 4), ...
    round(NMSE_mean(:, 1), 4), ...
    round(SGCS_mean(:, 1), 4), ...
    round(PDP_COS_mean(:, 1), 4), ...
    round(AZ_COS_mean(:, 1), 4), ...
    round(EL_COS_mean(:, 1), 4), ...
    'VariableNames', {'DT_error_ratio', 'DT_error_percent', 'NMSE', 'SGCS', 'PDP_COS', 'AZ_COS', 'EL_COS'} ...
);

only_distance_table = table( ...
    round(d_list, 4), ...
    round(NMSE_mean(1, :)', 4), ...
    round(SGCS_mean(1, :)', 4), ...
    round(PDP_COS_mean(1, :)', 4), ...
    round(AZ_COS_mean(1, :)', 4), ...
    round(EL_COS_mean(1, :)', 4), ...
    'VariableNames', {'distance_error_m', 'NMSE', 'SGCS', 'PDP_COS', 'AZ_COS', 'EL_COS'} ...
);

only_dt_xlsx = fullfile(out_dir, "only_DT_from_summary.xlsx");
only_distance_xlsx = fullfile(out_dir, "only_distance_from_summary.xlsx");
writetable(only_dt_table, only_dt_xlsx, "Sheet", "only_DT");
writetable(only_distance_table, only_distance_xlsx, "Sheet", "only_distance");

plot_metric_group( ...
    err_percent, ...
    only_dt_table{:, 3:end}, ...
    ["NMSE", "SGCS", "PDP COS", "AZ COS", "EL COS"], ...
    "DT error (%)", ...
    sprintf("only DT analysis (distance error = %.4g m)", d_list(1)), ...
    fullfile(out_dir, "only_DT_metrics.png") ...
);

plot_metric_group( ...
    d_list, ...
    only_distance_table{:, 2:end}, ...
    ["NMSE", "SGCS", "PDP COS", "AZ COS", "EL COS"], ...
    "Distance error (m)", ...
    sprintf("only distance analysis (DT error = %.4g%%)", err_percent(1)), ...
    fullfile(out_dir, "only_distance_metrics.png") ...
);

fprintf("Source directory: %s\n", source_dir);
fprintf("Saved only DT Excel to %s\n", only_dt_xlsx);
fprintf("Saved only distance Excel to %s\n", only_distance_xlsx);

function [mat_path, source_dir] = locate_summary_mat()
candidates = { ...
    fullfile(pwd, "locDT_summary_full.mat"), ...
    fullfile(pwd, "locDT_summary_tables.mat"), ...
    fullfile(pwd, "summary_locDT", "locDT_summary_full.mat"), ...
    fullfile(pwd, "summary_locDT", "locDT_summary_tables.mat") ...
};

for i = 1:numel(candidates)
    if isfile(candidates{i})
        mat_path = candidates{i};
        source_dir = fileparts(mat_path);
        return;
    end
end

error(["No summary MAT file found. Expected one of these files:" newline, ...
    strjoin(candidates, newline)]);
end

function validate_metric_matrix(values, num_err, num_d, field_name)
if ~isequal(size(values), [num_err, num_d])
    error("summary.%s must have size (%d, %d).", field_name, num_err, num_d);
end
end

function plot_metric_group(x_values, metric_values, metric_names, x_label_text, figure_title, save_path)
fig = figure("Position", [100, 100, 1200, 700]);
tiledlayout(2, 3, "TileSpacing", "compact", "Padding", "compact");

for i = 1:numel(metric_names)
    nexttile;
    plot(x_values, metric_values(:, i), "-o", "LineWidth", 1.8, "MarkerSize", 6);
    grid on;
    xlabel(x_label_text);
    ylabel(metric_names(i));
    title(metric_names(i), "Interpreter", "none");
end

sgtitle(figure_title, "Interpreter", "none");
saveas(fig, save_path);
end
