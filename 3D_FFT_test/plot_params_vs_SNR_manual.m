%% plot_params_vs_SNR_manual.m
% 适配手动数据库实验结果的参数误差绘图脚本
% 绘制 theta RMSE、phi RMSE、tau RMSE、alpha NMSE 随 SNR 的变化

clc;
clear;

load("RESULT_3DFFT_manual.mat", "RESULT");
% load("RESULT_3DFFT_rt.mat", "RESULT");
numA = length(RESULT);
numSNR = length(RESULT(1).snr);

snr_dB_list = zeros(1, numSNR);
theta_rmse_mean = zeros(1, numSNR);
phi_rmse_mean = zeros(1, numSNR);
tau_rmse_mean = zeros(1, numSNR);
alpha_nmse_mean = zeros(1, numSNR);

for is = 1:numSNR
    snr_dB_list(is) = RESULT(1).snr(is).snr_dB;

    theta_pool = [];
    phi_pool = [];
    tau_pool = [];
    alpha_pool = [];

    for a = 1:numA
        s = RESULT(a).snr(is);

        if isfield(s, "theta_rmse")
            theta_pool = [theta_pool; s.theta_rmse];
        end

        if isfield(s, "phi_rmse")
            phi_pool = [phi_pool; s.phi_rmse];
        end

        if isfield(s, "tau_rmse")
            tau_pool = [tau_pool; s.tau_rmse];
        end

        if isfield(s, "alpha_nmse")
            alpha_pool = [alpha_pool; s.alpha_nmse];
        end
    end

    theta_rmse_mean(is) = mean(theta_pool, "omitnan");
    phi_rmse_mean(is) = mean(phi_pool, "omitnan");
    tau_rmse_mean(is) = mean(tau_pool, "omitnan");
    alpha_nmse_mean(is) = mean(alpha_pool, "omitnan");
end

figure;
tiledlayout(2, 2, "Padding", "compact", "TileSpacing", "compact");

nexttile;
plot(snr_dB_list, theta_rmse_mean, "-o", ...
    "LineWidth", 2, ...
    "MarkerSize", 7, ...
    "Color", [0.0000 0.4470 0.7410]);
grid on;
xlabel("SNR (dB)");
ylabel("\theta RMSE (deg)");
title("\theta RMSE vs SNR");
set(gca, "FontSize", 12);

nexttile;
plot(snr_dB_list, phi_rmse_mean, "-o", ...
    "LineWidth", 2, ...
    "MarkerSize", 7, ...
    "Color", [0.8500 0.3250 0.0980]);
grid on;
xlabel("SNR (dB)");
ylabel("\phi RMSE (deg)");
title("\phi RMSE vs SNR");
set(gca, "FontSize", 12);

nexttile;
plot(snr_dB_list, tau_rmse_mean * 1e9, "-o", ...
    "LineWidth", 2, ...
    "MarkerSize", 7, ...
    "Color", [0.9290 0.6940 0.1250]);
grid on;
xlabel("SNR (dB)");
ylabel("\tau RMSE (ns)");
title("\tau RMSE vs SNR");
set(gca, "FontSize", 12);

nexttile;
plot(snr_dB_list, 10 * log10(max(alpha_nmse_mean, 1e-12)), "-o", ...
    "LineWidth", 2, ...
    "MarkerSize", 7, ...
    "Color", [0.4940 0.1840 0.5560]);
grid on;
xlabel("SNR (dB)");
ylabel("\alpha NMSE (dB)");
title("\alpha NMSE vs SNR");
set(gca, "FontSize", 12);
