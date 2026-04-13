clc; clear;

axisFontSize = 14;
labelFontSize = 16;
titleFontSize = 18;

A_list = 1:5;
% err_list = [0.1, 0.2, 0.3, 0.4, 0.5, 0.6, 0.7, 0.8, 0.9, 1.0];   % DT error in percent
err_list = [1, 5, 10, 15, 20];
speed = 0;
out_dir = "figs";
if ~exist(out_dir, "dir")
    mkdir(out_dir);
end

NMSE_Ad = zeros(length(A_list), length(err_list));
SGCS_Ad = zeros(length(A_list), length(err_list));

for ia = 1:length(A_list)
    A = A_list(ia);
    for ie = 1:length(err_list)
        err = err_list(ie);
        err_token = format_err_token(err);
        filename = sprintf("v%d_err%s_A%d.mat", speed, err_token, A);
        fprintf("Loading %s\n", filename);

        S = load(filename);
        nmse_k = S.data.NMSE_samples;
        sgcs_k = S.data.SGCS_samples;

        NMSE_Ad(ia, ie) = mean(nmse_k);
        SGCS_Ad(ia, ie) = mean(sgcs_k);
    end
end

NMSE_e_mean = mean(NMSE_Ad, 1);
SGCS_e_mean = mean(SGCS_Ad, 1);

disp("Average NMMSE over A points for each DT error level:");
disp(NMSE_e_mean);
disp("Average SGCS over A points for each DT error level:");
disp(SGCS_e_mean);

fig1 = figure;
bar(err_list, NMSE_e_mean);
grid on;
set(gca, "FontSize", axisFontSize);
set(gca, "XTick", err_list, "XTickLabel", arrayfun(@format_err_label, err_list, "UniformOutput", false));
xlabel("DT error level (%)", "FontSize", labelFontSize);
ylabel("Average NMSE (averaged over UE locations)", "FontSize", labelFontSize);
title("NMMSE vs DT error (averaged over UE locations)", "FontSize", titleFontSize);
saveas(fig1, fullfile(out_dir, "NMSE_vs_DT_error_allA.png"));

fig2 = figure;
bar(err_list, SGCS_e_mean);
grid on;
set(gca, "FontSize", axisFontSize);
set(gca, "XTick", err_list, "XTickLabel", arrayfun(@format_err_label, err_list, "UniformOutput", false));
xlabel("DT error level (%)", "FontSize", labelFontSize);
ylabel("Average SGCS (averaged over UE locations)", "FontSize", labelFontSize);
title("M-SGCS vs DT error (averaged over UE locations)", "FontSize", titleFontSize);
saveas(fig2, fullfile(out_dir, "SGCS_vs_DT_error_allA.png"));

function token = format_err_token(err_pct)
token = format_err_label(err_pct);
token = strrep(token, ".", "p");
end

function label = format_err_label(err_pct)
label = sprintf("%.3g", err_pct);
end
