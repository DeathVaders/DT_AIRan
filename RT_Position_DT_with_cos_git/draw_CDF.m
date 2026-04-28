clc; clear;

axisFontSize = 14;
labelFontSize = 16;
titleFontSize = 18;
legendFontSize = 12;

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

colors = [
    0.1216 0.4667 0.7059
    1.0000 0.4980 0.0549
    0.1725 0.6275 0.1725
    0.8392 0.1529 0.1569
    0.5804 0.4039 0.7412
    0.5490 0.3373 0.2941
    0.8902 0.4667 0.7608
    0.4980 0.4980 0.4980
    0.7373 0.7412 0.1333
    0.0902 0.7451 0.8118
];

for is = 1:size(scenario_keys, 1)
    bs_idx = scenario_keys(is, 1);
    ue_idx = scenario_keys(is, 2);
    NMSE_samples = cell(length(err_list), 1);
    SGCS_samples = cell(length(err_list), 1);

    for ie = 1:length(err_list)
        err = err_list(ie);
        matched = entries([entries.bs_idx] == bs_idx & ...
                          [entries.ue_idx] == ue_idx & ...
                          abs([entries.err_percent] - err) < 1e-12);
        if isempty(matched)
            warning("Missing result for BS%d UE%d at err = %s%%.", bs_idx, ue_idx, format_err_label(err));
            continue;
        end

        fprintf("Loading %s\n", matched(1).filename);
        S = load(matched(1).filename);
        NMSE_samples{ie} = S.data.NMSE_samples;
        SGCS_samples{ie} = S.data.SGCS_samples;
    end

    fig1 = figure; hold on;
    for ie = 1:length(err_list)
        if isempty(NMSE_samples{ie})
            continue;
        end
        [f, x] = ecdf(NMSE_samples{ie});
        plot(x, f, "LineWidth", 2, ...
            "Color", colors(ie, :), ...
            "DisplayName", sprintf("err = %s%%", format_err_label(err_list(ie))));
    end
    grid on;
    set(gca, "FontSize", axisFontSize);
    xlabel("NMSE", "FontSize", labelFontSize);
    ylabel("CDF", "FontSize", labelFontSize);
    title(sprintf("CDF of NMSE for BS%d UE%d", bs_idx, ue_idx), "FontSize", titleFontSize);
    legend("show", "FontSize", legendFontSize);
    saveas(fig1, fullfile(out_dir, sprintf("CDF_NMSE_BS%d_UE%d.png", bs_idx, ue_idx)));

    fig2 = figure; hold on;
    for ie = 1:length(err_list)
        if isempty(SGCS_samples{ie})
            continue;
        end
        [f, x] = ecdf(SGCS_samples{ie});
        plot(x, f, "LineWidth", 2, ...
            "Color", colors(ie, :), ...
            "DisplayName", sprintf("err = %s%%", format_err_label(err_list(ie))));
    end
    grid on;
    set(gca, "FontSize", axisFontSize);
    xlabel("SGCS", "FontSize", labelFontSize);
    ylabel("CDF", "FontSize", labelFontSize);
    title(sprintf("CDF of SGCS for BS%d UE%d", bs_idx, ue_idx), "FontSize", titleFontSize);
    legend("show", "FontSize", legendFontSize);
    saveas(fig2, fullfile(out_dir, sprintf("CDF_SGCS_BS%d_UE%d.png", bs_idx, ue_idx)));
end

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
    sort_table = [[entries.bs_idx]', [entries.ue_idx]', [entries.err_percent]'];
    [~, order] = sortrows(sort_table, [1, 2, 3]);
    entries = entries(order);
end
end

function label = format_err_label(err_pct)
label = sprintf("%.3g", err_pct);
end
