%% plot_W_vs_SNR.m
% 功能：
%   从 RESULT_3DFFT_Wasserstein.mat 读取数据
%   画出每个误差半径 d 下 W 随 SNR 的变化曲线

clear
clc

%load("RESULT_3DFFT_Wasserstein.mat","RESULT")
load("RESULT_3DFFT_manual.mat","RESULT")

%% 读取基本信息
numA = length(RESULT);                 % raytracing真实点数量
numD = length(RESULT(1).err);          % d数量
numSNR = length(RESULT(1).err(1).points(1).snr);

snr_dB_list = zeros(1,numSNR);
for is = 1:numSNR
    snr_dB_list(is) = RESULT(1).err(1).points(1).snr(is).snr_dB;
end

d_list = zeros(1,numD);
for id = 1:numD
    d_list(id) = RESULT(1).err(id).d;
end

%% 计算平均 Wasserstein
W_mean = zeros(numD,numSNR);

for id = 1:numD
    for is = 1:numSNR

        W_pool = [];

        for a = 1:numA

            numPoints = length(RESULT(a).err(id).points);

            for it = 1:numPoints

                W = RESULT(a).err(id).points(it).snr(is).W;

                if ~isnan(W) && ~isinf(W)
                    W_pool = [W_pool; W];
                end
                %if isnan(W) || isinf(W)
                %    W = 2.0;   % 或者一个足够大的惩罚值
                %end
                %W_pool = [W_pool; W];

            end
        end

        W_mean(id,is) = mean(W_pool);

    end
end

%% 画图
figure
hold on

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

for id = 1:numD

    plot(snr_dB_list, W_mean(id,:),'-o',...
        'LineWidth',2,...
        'Color',colors(id,:),...
        'DisplayName',sprintf('d = %d m',d_list(id)));

end

grid on
xlabel('SNR (dB)','FontSize',12)
ylabel('Wasserstein Distance','FontSize',12)
title('Parameter Estimation Error vs SNR','FontSize',14)

legend('Location','northeast')

set(gca,'FontSize',12)
