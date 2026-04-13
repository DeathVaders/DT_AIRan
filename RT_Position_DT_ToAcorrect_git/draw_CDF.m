clc; clear;

axisFontSize = 14;
labelFontSize = 16;
titleFontSize = 18;
legendFontSize = 12;

A_list = 1:5;
err_list = [1, 5, 10, 15, 20];   % DT error in percent
speed = 0;
out_dir = "figs";
if ~exist(out_dir, "dir")
    mkdir(out_dir);
end

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

for ia = 1:length(A_list)
    A_idx = A_list(ia);
    NMSE_samples = cell(length(err_list),1);
    SGCS_samples = cell(length(err_list),1);
    for ie = 1:length(err_list)
        err = err_list(ie);
        filename = sprintf("v%d_err%d_A%d.mat", speed, err, A_idx);
        fprintf("Loading %s\n", filename);
        S = load(filename);
        NMSE_samples{ie} = S.data.NMSE_samples;
        SGCS_samples{ie} = S.data.SGCS_samples;
    end

    fig1 = figure; hold on;
    for ie = 1:length(err_list)
        [f, x] = ecdf(NMSE_samples{ie});
        plot(x, f, "LineWidth", 2, ...
            "Color", colors(ie,:), ...
            "DisplayName", sprintf("err = %d%%", err_list(ie)));
    end
    grid on;
    set(gca, "FontSize", axisFontSize);
    xlabel("NMSE", "FontSize", labelFontSize);
    ylabel("CDF", "FontSize", labelFontSize);
    title(sprintf("CDF of NMSE for Point A%d under DT errors", A_idx), "FontSize", titleFontSize);
    legend("show", "FontSize", legendFontSize);
    saveas(fig1, fullfile(out_dir, sprintf("CDF_NMSE_A%d.png", A_idx)));

    fig2 = figure; hold on;
    for ie = 1:length(err_list)
        [f, x] = ecdf(SGCS_samples{ie});
        plot(x, f, "LineWidth", 2, ...
            "Color", colors(ie,:), ...
            "DisplayName", sprintf("err = %d%%", err_list(ie)));
    end
    grid on;
    set(gca, "FontSize", axisFontSize);
    xlabel("SGCS", "FontSize", labelFontSize);
    ylabel("CDF", "FontSize", labelFontSize);
    title(sprintf("CDF of SGCS for Point A%d under DT errors", A_idx), "FontSize", titleFontSize);
    legend("show", "FontSize", legendFontSize);
    saveas(fig2, fullfile(out_dir, sprintf("CDF_SGCS_A%d.png", A_idx)));
end
