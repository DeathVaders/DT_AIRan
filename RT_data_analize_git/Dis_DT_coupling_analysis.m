%% Analyze coupling deviation from summary MAT file
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

metric_names = {"NMSE", "SGCS", "PDP_COS", "AZ_COS", "EL_COS"};
metric_fields = {"NMSE_mean", "SGCS_mean", "PDP_COS_mean", "AZ_COS_mean", "EL_COS_mean"};
use_one_minus = [false, true, true, true, true];
num_metrics = numel(metric_names);

results = struct();
results.source_mat = mat_path;
results.source_dir = source_dir;
results.d_list = d_list;
results.err_levels = err_levels;
results.err_percent = err_percent;

for i = 1:num_metrics
    metric_name = metric_names{i};
    metric_field = metric_fields{i};
    E_joint = summary.(metric_field);
    validate_metric_matrix(E_joint, numel(err_levels), numel(d_list), metric_field);

    % NMSE is already an error metric; the other four metrics are similarity
    % scores where values closer to 1 are better, so convert them to error.
    if use_one_minus(i)
        E_joint = 1 - E_joint;
    end

    E_DT = E_joint(:, 1);
    E_dist = E_joint(1, :);
    E_base = E_joint(1, 1);
    E_plus = E_DT + E_dist - E_base;
    Delta_E = E_joint - E_plus;

    results.(metric_name) = struct( ...
        "E_joint", round(E_joint, 4), ...
        "E_DT", round(E_DT, 4), ...
        "E_dist", round(E_dist, 4), ...
        "E_base", round(E_base, 4), ...
        "E_plus", round(E_plus, 4), ...
        "Delta_E", round(Delta_E, 4) ...
    );

    fig = figure("Name", sprintf("%s coupling deviation", metric_name), ...
        "Position", [100, 100, 520, 420]);
    plot_heatmap(Delta_E, d_list, err_percent, sprintf("%s: Delta E", metric_name));
    saveas(fig, fullfile(out_dir, sprintf("%s_coupling_analysis.png", metric_name)));
end

save(fullfile(out_dir, "locDT_coupling_analysis.mat"), "results");
fprintf("Source directory: %s\n", source_dir);
fprintf("Saved coupling analysis MAT to %s\n", fullfile(out_dir, "locDT_coupling_analysis.mat"));

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

function plot_heatmap(values, d_list, err_percent, plot_title_text)
imagesc(d_list, err_percent, values);
set(gca, "YDir", "normal");
axis tight;
colorbar;
xlabel("Distance error (m)");
ylabel("DT error (%)");
title(plot_title_text, "Interpreter", "none");
end
