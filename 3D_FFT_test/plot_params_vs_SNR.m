%% plot_params_vs_SNR.m
% 画四个参数随 SNR 的变化
% θ RMSE
% φ RMSE
% τ RMSE
% α NMSE
% 四个子图在同一个 figure

clear
clc

%load("RESULT_3DFFT_Wasserstein.mat","RESULT")
load("RESULT_3DFFT_manual.mat","RESULT")

%% ===== 基本信息 =====

numA = length(RESULT);
numD = length(RESULT(1).err);
numSNR = length(RESULT(1).err(1).points(1).snr);

snr_dB_list = zeros(1,numSNR);
for is = 1:numSNR
    snr_dB_list(is) = RESULT(1).err(1).points(1).snr(is).snr_dB;
end

d_list = zeros(1,numD);
for id = 1:numD
    d_list(id) = RESULT(1).err(id).d;
end


%% ===== 初始化 =====

theta_rmse_mean = zeros(numD,numSNR);
phi_rmse_mean   = zeros(numD,numSNR);
tau_rmse_mean   = zeros(numD,numSNR);
alpha_nmse_mean = zeros(numD,numSNR);


%% ===== 汇总数据 =====

for id = 1:numD
    for is = 1:numSNR

        theta_pool = [];
        phi_pool   = [];
        tau_pool   = [];
        alpha_pool = [];

        for a = 1:numA
            numPoints = length(RESULT(a).err(id).points);

            for it = 1:numPoints

                s = RESULT(a).err(id).points(it).snr(is);

                if isfield(s,'theta_rmse')
                    theta_pool = [theta_pool; s.theta_rmse];
                end

                if isfield(s,'phi_rmse')
                    phi_pool = [phi_pool; s.phi_rmse];
                end

                if isfield(s,'tau_rmse')
                    tau_pool = [tau_pool; s.tau_rmse];
                end

                if isfield(s,'alpha_nmse')
                    alpha_pool = [alpha_pool; s.alpha_nmse];
                end

            end
        end

        theta_rmse_mean(id,is) = mean(theta_pool,'omitnan');
        phi_rmse_mean(id,is)   = mean(phi_pool,'omitnan');
        tau_rmse_mean(id,is)   = mean(tau_pool,'omitnan');
        alpha_nmse_mean(id,is) = mean(alpha_pool,'omitnan');

    end
end


%% ===== 颜色 =====

colors = [
0.0000 0.4470 0.7410
0.8500 0.3250 0.0980
0.9290 0.6940 0.1250
0.4940 0.1840 0.5560
0.4660 0.6740 0.1880
0.3010 0.7450 0.9330
0.6350 0.0780 0.1840
0.0000 0.5000 0.5000
0.7500 0.7500 0.0000
0.7500 0.0000 0.7500
];


%% ===== 画图 =====

figure
tiledlayout(2,2,'Padding','compact','TileSpacing','compact')


%% ===== θ RMSE =====

nexttile
hold on

for id = 1:numD

    plot(snr_dB_list, theta_rmse_mean(id,:), '-o', ...
        'LineWidth',2, ...
        'Color',colors(id,:), ...
        'DisplayName',sprintf('d = %d m', d_list(id)));

end

grid on
xlabel('SNR (dB)')
ylabel('\theta RMSE (deg)')
title('\theta RMSE vs SNR')
set(gca,'FontSize',12)



%% ===== φ RMSE =====

nexttile
hold on

for id = 1:numD

    plot(snr_dB_list, phi_rmse_mean(id,:), '-o', ...
        'LineWidth',2, ...
        'Color',colors(id,:));

end

grid on
xlabel('SNR (dB)')
ylabel('\phi RMSE (deg)')
title('\phi RMSE vs SNR')
set(gca,'FontSize',12)



%% ===== τ RMSE =====

nexttile
hold on

for id = 1:numD

    plot(snr_dB_list, tau_rmse_mean(id,:)*1e9, '-o', ...
        'LineWidth',2, ...
        'Color',colors(id,:));

end

grid on
xlabel('SNR (dB)')
ylabel('\tau RMSE (ns)')
title('\tau RMSE vs SNR')
set(gca,'FontSize',12)



%% ===== α NMSE =====

nexttile
hold on

for id = 1:numD

    plot(snr_dB_list, 10*log10(max(alpha_nmse_mean(id,:),1e-12)), '-o', ...
        'LineWidth',2, ...
        'Color',colors(id,:));

end

grid on
xlabel('SNR (dB)')
ylabel('\alpha NMSE (dB)')
title('\alpha NMSE vs SNR')
set(gca,'FontSize',12)



%% ===== 图例 =====

lgd = legend(arrayfun(@(x)sprintf('d = %d m',x), d_list, 'UniformOutput', false));
lgd.Layout.Tile = 'east';