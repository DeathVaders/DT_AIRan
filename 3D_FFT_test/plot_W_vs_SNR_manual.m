%% plot_W_vs_SNR_manual.m
% 适配手动数据库实验结果的 Wasserstein 曲线绘图脚本
% 仅绘制平均 Wasserstein distance vs SNR

clc;
clear;

load("RESULT_3DFFT_manual.mat", "RESULT");
% load("RESULT_3DFFT_rt.mat", "RESULT");
numA = length(RESULT);
numSNR = length(RESULT(1).snr);

snr_dB_list = zeros(1, numSNR);
W_mean = zeros(1, numSNR);

for is = 1:numSNR
    snr_dB_list(is) = RESULT(1).snr(is).snr_dB;

    W_pool = [];
    for a = 1:numA
        W = RESULT(a).snr(is).W;
        if ~isnan(W) && ~isinf(W)
            W_pool = [W_pool; W];
        end
    end

    W_mean(is) = mean(W_pool, "omitnan");
end

figure;
plot(snr_dB_list, W_mean, "-o", ...
    "LineWidth", 2, ...
    "MarkerSize", 7, ...
    "Color", [0.0000 0.4470 0.7410]);

grid on;
xlabel("SNR (dB)", "FontSize", 12);
ylabel("Wasserstein Distance", "FontSize", 12);
title("Wasserstein Distance vs SNR", "FontSize", 14);
set(gca, "FontSize", 12);

