%% Summarize full locDT metric matrices across all BS-UE pairs
clc;
clear;

out_dir = "summary_locDT";
if ~isfolder(out_dir)
    mkdir(out_dir);
end

entries = collect_locdt_entries();
if isempty(entries)
    error("No locDT result files found. Expected files like BS1_UE1_locDT.mat.");
end

first_data = load(entries(1).filename, "data");
meta = first_data.data.meta;
d_list = meta.d_list(:);
err_levels = meta.err_levels(:);
err_percent = meta.err_percent(:);
num_d = numel(d_list);
num_err = numel(err_levels);
num_files = numel(entries);

metric_fields = ["NMSE_mean", "SGCS_mean", "PDP_COS_mean", "AZ_COS_mean", "EL_COS_mean"];
metric_labels = ["NMSE", "SGCS", "PDP_COS", "AZ_COS", "EL_COS"];
num_metrics = numel(metric_fields);

metrics_all = nan(num_files, num_err, num_d, num_metrics);

for i = 1:num_files
    fprintf("Loading %s\n", entries(i).filename);
    S = load(entries(i).filename, "data");
    validate_locdt_data(S.data, num_err, num_d, entries(i).filename, metric_fields);
    validate_meta_consistency(S.data.meta, d_list, err_levels, entries(i).filename);

    for im = 1:num_metrics
        metric_name = char(metric_fields(im));
        metrics_all(i, :, :, im) = S.data.(metric_name);
    end
end

metrics_mean = squeeze(mean(metrics_all, 1, "omitnan"));
metrics_mean = round(metrics_mean, 4);

excel_path = fullfile(out_dir, "locDT_summary_full.xlsx");
for im = 1:num_metrics
    metric_table = build_metric_table(metrics_mean(:, :, im), err_levels, err_percent, d_list);
    writetable(metric_table, excel_path, "Sheet", char(metric_labels(im)));
end

summary = struct();
summary.files = string({entries.filename})';
summary.metric_labels = metric_labels;
summary.metric_fields = metric_fields;
summary.d_list = round(d_list, 4);
summary.err_levels = round(err_levels, 4);
summary.err_percent = round(err_percent, 4);
summary.metric_rows = "ie = DT error levels";
summary.metric_columns = "id = distance error levels";
summary.NMSE_mean = metrics_mean(:, :, 1);
summary.SGCS_mean = metrics_mean(:, :, 2);
summary.PDP_COS_mean = metrics_mean(:, :, 3);
summary.AZ_COS_mean = metrics_mean(:, :, 4);
summary.EL_COS_mean = metrics_mean(:, :, 5);
summary.tables = struct();
for im = 1:num_metrics
    table_name = char(metric_labels(im));
    summary.tables.(table_name) = build_metric_table(metrics_mean(:, :, im), err_levels, err_percent, d_list);
end

mat_path = fullfile(out_dir, "locDT_summary_full.mat");
save(mat_path, "summary");

fprintf("\nSaved MAT summary to %s\n", mat_path);
fprintf("Saved Excel summary to %s\n", excel_path);
fprintf("Rows correspond to ie (DT error levels), columns correspond to id (distance error levels).\n");
disp("Average NMSE table:");
disp(summary.tables.NMSE);

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
    sort_keys = [[entries.bs_idx]', [entries.ue_idx]'];
    [~, order] = sortrows(sort_keys, [1, 2]);
    entries = entries(order);
end
end

function validate_locdt_data(data, num_err, num_d, filename, metric_fields)
if ~isfield(data, "meta")
    error("File %s is missing data.meta.", filename);
end

for i = 1:numel(metric_fields)
    metric_name = char(metric_fields(i));
    if ~isfield(data, metric_name)
        error("File %s is missing data.%s.", filename, metric_name);
    end

    if ~isequal(size(data.(metric_name)), [num_err, num_d])
        error("File %s has inconsistent size for data.%s.", filename, metric_name);
    end
end
end

function validate_meta_consistency(meta, d_list_ref, err_levels_ref, filename)
if ~isequal(meta.d_list(:), d_list_ref(:))
    error("File %s has inconsistent data.meta.d_list.", filename);
end

if ~isequal(meta.err_levels(:), err_levels_ref(:))
    error("File %s has inconsistent data.meta.err_levels.", filename);
end
end

function T = build_metric_table(values, err_levels, err_percent, d_list)
num_d = numel(d_list);
var_names = cell(1, num_d + 2);
var_names{1} = "DT_error_ratio";
var_names{2} = "DT_error_percent";

for id = 1:num_d
    var_names{id + 2} = matlab.lang.makeValidName(sprintf("d_%s_m", format_label(d_list(id))));
end

table_values = [round(err_levels, 4), round(err_percent, 4), round(values, 4)];
T = array2table(table_values, "VariableNames", string(var_names));
end

function label = format_label(value)
label = sprintf("%.6g", value);
label = strrep(label, "-", "neg_");
label = strrep(label, ".", "p");
end
