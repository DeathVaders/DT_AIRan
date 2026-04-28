%% Analyze average contribution percentages of DT, distance and coupling errors
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
required_fields = ["d_list", "err_levels", ...
    "NMSE_mean", "SGCS_mean", "PDP_COS_mean", "AZ_COS_mean", "EL_COS_mean"];
for i = 1:numel(required_fields)
    field_name = char(required_fields(i));
    if ~isfield(summary, field_name)
        error("summary is missing field '%s'.", field_name);
    end
end

d_list = summary.d_list(:);
err_levels = summary.err_levels(:);

metric_names = {"NMSE", "SGCS", "PDP_COS", "AZ_COS", "EL_COS"};
metric_fields = {"NMSE_mean", "SGCS_mean", "PDP_COS_mean", "AZ_COS_mean", "EL_COS_mean"};
use_one_minus = [false, true, true, true, true];
num_metrics = numel(metric_names);

metric_results = struct();
contribution_table = nan(num_metrics, 3);

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
    E_distance = E_joint(1, :);
    E_base = E_joint(1, 1);

    % Total added error is decomposed into DT-only, distance-only and
    % coupling terms relative to the common baseline.
    E_DT_only = E_DT - E_base;
    E_distance_only = E_distance - E_base;
    E_couple = E_joint - E_DT - E_distance + E_base;
    E_total = E_joint - E_base;

    E_DT_grid = repmat(E_DT_only, 1, numel(d_list));
    E_distance_grid = repmat(E_distance_only, numel(err_levels), 1);

    valid_mask = abs(E_total) > 1e-12;

    dt_percent = nan(size(E_total));
    dist_percent = nan(size(E_total));
    couple_percent = nan(size(E_total));

    dt_percent(valid_mask) = 100 * E_DT_grid(valid_mask) ./ E_total(valid_mask);
    dist_percent(valid_mask) = 100 * E_distance_grid(valid_mask) ./ E_total(valid_mask);
    couple_percent(valid_mask) = 100 * E_couple(valid_mask) ./ E_total(valid_mask);

    metric_results.(metric_name) = struct( ...
        "avg_DT_percent", mean(dt_percent(valid_mask), "omitnan"), ...
        "avg_distance_percent", mean(dist_percent(valid_mask), "omitnan"), ...
        "avg_couple_percent", mean(couple_percent(valid_mask), "omitnan") ...
    );

    contribution_table(i, :) = [ ...
        metric_results.(metric_name).avg_DT_percent, ...
        metric_results.(metric_name).avg_distance_percent, ...
        metric_results.(metric_name).avg_couple_percent ...
    ];
end

results = struct();
results.source_mat = mat_path;
results.source_dir = source_dir;
results.metric_results = metric_results;
results.metric_names = metric_names;
results.contribution_table = contribution_table;
results.contribution_table_columns = {'DT_percent', 'distance_percent', 'coupling_percent'};

save(fullfile(out_dir, "locDT_contribution_analysis.mat"), "results");

fprintf("Source directory: %s\n", source_dir);
disp("Average contribution table (%):");
metric_row_names = cellfun(@char, metric_names, 'UniformOutput', false);
disp(array2table(contribution_table, ...
    'VariableNames', {'DT_percent', 'distance_percent', 'coupling_percent'}, ...
    'RowNames', metric_row_names));
for i = 1:num_metrics
    metric_name = metric_names{i};
    fprintf("%s average DT contribution: %.4f%%\n", ...
        metric_name, metric_results.(metric_name).avg_DT_percent);
    fprintf("%s average distance contribution: %.4f%%\n", ...
        metric_name, metric_results.(metric_name).avg_distance_percent);
    fprintf("%s average coupling contribution: %.4f%%\n", ...
        metric_name, metric_results.(metric_name).avg_couple_percent);
end
fprintf("Saved contribution analysis MAT to %s\n", fullfile(out_dir, "locDT_contribution_analysis.mat"));

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
