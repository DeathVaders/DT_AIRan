clc; clear;

axisFontSize = 14;
labelFontSize = 16;
titleFontSize = 18;
legendFontSize = 12;

% err_list = [0.1, 0.2, 0.3, 0.4, 0.5, 0.6, 0.7, 0.8, 0.9, 1.0];   % DT error in percent
err_list = [1, 5, 10, 15, 20];
A_list = 1:5;
speed = 0;
out_dir = "figs";
if ~exist(out_dir, "dir")
    mkdir(out_dir);
end

NMSE_samples_allA = cell(length(err_list),1);
SGCS_samples_allA = cell(length(err_list),1);
for ie = 1:length(err_list)
    err = err_list(ie);
    fprintf("Processing err = %s%%\n", format_err_label(err));

    nmse_pool = [];
    sgcs_pool = [];
    for ia = 1:length(A_list)
        A = A_list(ia);
        err_token = format_err_token(err);
        filename = sprintf("v%d_err%s_A%d.mat", speed, err_token, A);
        if ~isfile(filename)
            warning("Missing %s, skip", filename);
            continue;
        end
        S = load(filename);
        nmse_pool = [nmse_pool; S.data.NMSE_samples]; %#ok<AGROW>
        sgcs_pool = [sgcs_pool; S.data.SGCS_samples]; %#ok<AGROW>
    end

    NMSE_samples_allA{ie} = nmse_pool;
    SGCS_samples_allA{ie} = sgcs_pool;
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

fig1 = figure; hold on;
for ie = 1:length(err_list)
    [f, x] = ecdf(NMSE_samples_allA{ie});
    plot(x, f, "LineWidth", 2, ...
         "Color", colors(ie,:), ...
         "DisplayName", sprintf("err = %s%%", format_err_label(err_list(ie))));
end
grid on;
set(gca, "FontSize", axisFontSize);
xlabel("NMSE", "FontSize", labelFontSize);
ylabel("CDF", "FontSize", labelFontSize);
title("CDF of NMSE (All A combined) under DT errors", "FontSize", titleFontSize);
xlim([0 12]);
legend("show", "FontSize", legendFontSize);
saveas(fig1, fullfile(out_dir, "CDF_NMSE_allA.png"));

fig2 = figure; hold on;
for ie = 1:length(err_list)
    [f, x] = ecdf(SGCS_samples_allA{ie});
    plot(x, f, "LineWidth", 2, ...
         "Color", colors(ie,:), ...
         "DisplayName", sprintf("err = %s%%", format_err_label(err_list(ie))));
end
grid on;
set(gca, "FontSize", axisFontSize);
xlabel("SGCS", "FontSize", labelFontSize);
ylabel("CDF", "FontSize", labelFontSize);
title("CDF of SGCS (All A combined) under DT errors", "FontSize", titleFontSize);
xlim([0 1]);
legend("show", "FontSize", legendFontSize);
saveas(fig2, fullfile(out_dir, "CDF_SGCS_allA.png"));

function token = format_err_token(err_pct)
token = format_err_label(err_pct);
token = strrep(token, ".", "p");
end

function label = format_err_label(err_pct)
label = sprintf("%.3g", err_pct);
end
