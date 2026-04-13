clc; clear;

axisFontSize = 14;
labelFontSize = 16;
titleFontSize = 18;

err_list = [1, 5, 10, 15, 20];  % DT error in percent
A_list = 1:5;
speed = 0;
out_dir = "figs";
if ~exist(out_dir, "dir")
    mkdir(out_dir);
end

for ia = 1:length(A_list)
    A = A_list(ia);
    NMSE = zeros(length(err_list), 1);
    SGCS = zeros(length(err_list), 1);

    for idx = 1:length(err_list)
        err = err_list(idx);
        filename = sprintf("v%d_err%d_A%d.mat", speed, err, A);
        fprintf("Processing %s\n", filename);

        S = load(filename);
        nmse_k = S.data.NMSE_samples;
        sgcs_k = S.data.SGCS_samples;

        NMSE(idx) = mean(nmse_k);
        SGCS(idx) = mean(sgcs_k);
    end

    fig1 = figure;
    bar(err_list, NMSE);
    grid on;
    set(gca, "FontSize", axisFontSize);
    xlabel("DT error level (%)", "FontSize", labelFontSize);
    ylabel("NMMSE", "FontSize", labelFontSize);
    title(sprintf("NMMSE vs DT error (A%d)", A), "FontSize", titleFontSize);
    saveas(fig1, fullfile(out_dir, sprintf("NMSE_vs_DT_error_A%d.png", A)));

    fig2 = figure;
    bar(err_list, SGCS);
    grid on;
    set(gca, "FontSize", axisFontSize);
    xlabel("DT error level (%)", "FontSize", labelFontSize);
    ylabel("SGCS", "FontSize", labelFontSize);
    title(sprintf("Mean SGCS vs DT error (A%d)", A), "FontSize", titleFontSize);
    saveas(fig2, fullfile(out_dir, sprintf("SGCS_vs_DT_error_A%d.png", A)));
end
